import CoreGraphics
import Foundation
import ImageIO

// MARK: - Model

enum PaintTool: String, Codable, CaseIterable, Identifiable {
    case paint, smudge, blend, lift
    var id: String { rawValue }
    var label: String {
        switch self {
        case .paint: return "Paint"
        case .smudge: return "Smudge"
        case .blend: return "Blend"
        case .lift: return "Lift"
        }
    }
    var symbol: String {
        switch self {
        case .paint: return "paintbrush.pointed"
        case .smudge: return "hand.point.up.left"
        case .blend: return "drop"
        case .lift: return "eraser.line.dashed"
        }
    }
}

/// One brush stroke. Points are normalized to the layer (0...1), size is a fraction of the layer width.
struct PaintStroke: Codable, Hashable {
    var tool: PaintTool
    var color: RGBA
    var size: Double
    /// How much paint goes down (paint), how far colors are dragged (smudge), how much they melt (blend).
    var strength: Double
    /// Wet brushes pick up the colors they pass over and mix them in.
    var wetness: Double
    var points: [NPoint]
}

/// A layer of mixed, smudged paint. It can start from a copy of the cover beneath it,
/// so smudging pushes the photo's own colors around.
struct PaintContent: Codable, Hashable {
    var strokes: [PaintStroke] = []
    var baseAssetID: UUID?
}

// MARK: - Spectral pixels

/// Paint is stored per pixel as 12 bands of Kubelka-Munk absorption/scattering (K/S), so mixing, smudging
/// and diffusing are plain weighted averages and come out the way pigments do (blue + yellow = green).
/// A small residual per pixel keeps unmixed colors and photos exactly as they were.
enum Spectral {
    static let bands = 12
    /// White, cyan, magenta, yellow, red, green, blue reflectance in 12 bands.
    static let primaries: [[Float]] = {
        func bandsOf(_ rgb: RGBA) -> [Float] {
            let R = PigmentMixer.reflectance(rgb)
            let per = R.count / bands
            return (0..<bands).map { b in Float(R[(b * per)..<((b + 1) * per)].reduce(0, +) / Double(per)) }
        }
        return [[Float](repeating: 1, count: bands),
                bandsOf(RGBA(0, 1, 1)), bandsOf(RGBA(1, 0, 1)), bandsOf(RGBA(1, 1, 0)),
                bandsOf(RGBA(1, 0, 0)), bandsOf(RGBA(0, 1, 0)), bandsOf(RGBA(0, 0, 1))]
    }()
    /// Linear RGB per band.
    static let toRGB: [[Float]] = PigmentMixer.bandMatrix(bands: bands).map { $0.map(Float.init) }

    /// Luminance contribution of each band (for tinting-strength weighting).
    static let yWeights: [Float] = toRGB.map { 0.2126 * $0[0] + 0.7152 * $0[1] + 0.0722 * $0[2] }

    /// Luminance of a K/S pixel.
    static func luminance(_ ks: [Float], at offset: Int) -> Float {
        var y: Float = 0
        for b in 0..<bands { y += km(ks[offset + b]) * yWeights[b] }
        return max(0.0005, y)
    }

    @inline(__always) static func ks(_ r: Float) -> Float {
        let R = min(0.999, max(0.001, r))
        return (1 - R) * (1 - R) / (2 * R)
    }

    @inline(__always) static func km(_ k: Float) -> Float {
        let kk = max(0, k)
        return 1 + kk - (kk * kk + 2 * kk).squareRoot()
    }

    static func decode(_ v: Float) -> Float { v <= 0.04045 ? v / 12.92 : powf((v + 0.055) / 1.055, 2.4) }
    static func encode(_ v: Float) -> Float {
        let c = min(1, max(0, v))
        return c <= 0.0031308 ? 12.92 * c : 1.055 * powf(c, 1 / 2.4) - 0.055
    }

    /// Reflectance bands of a linear-RGB color, by the seven-primary decomposition.
    static func reflectance(_ r0: Float, _ g0: Float, _ b0: Float, into out: inout [Float]) {
        let w = min(r0, min(g0, b0))
        let r = r0 - w, g = g0 - w, b = b0 - w
        let c = min(g, b), m = min(r, b), y = min(r, g)
        let rr = max(0, min(r - b, r - g)), gg = max(0, min(g - b, g - r)), bb = max(0, min(b - g, b - r))
        let weights: [Float] = [w, c, m, y, rr, gg, bb]
        for i in 0..<bands {
            var v: Float = 0
            for p in 0..<7 where weights[p] > 0 { v += weights[p] * primaries[p][i] }
            out[i] = min(1, max(0.001, v))
        }
    }

    static func linearRGB(fromReflectance R: [Float]) -> (Float, Float, Float) {
        var r: Float = 0, g: Float = 0, b: Float = 0
        for i in 0..<bands {
            r += R[i] * toRGB[i][0]
            g += R[i] * toRGB[i][1]
            b += R[i] * toRGB[i][2]
        }
        return (r, g, b)
    }

    /// K/S bands plus the residual that makes the round trip exact.
    static func pigment(_ c: RGBA) -> (ks: [Float], residual: [Float]) {
        let lr = decode(Float(c.r)), lg = decode(Float(c.g)), lb = decode(Float(c.b))
        var R = [Float](repeating: 1, count: bands)
        reflectance(lr, lg, lb, into: &R)
        let back = linearRGB(fromReflectance: R)
        return (R.map(ks), [lr - back.0, lg - back.1, lb - back.2])
    }
}

/// A canvas of spectral paint pixels.
final class PaintSurface {
    let w: Int
    let h: Int
    var ks: [Float]
    var res: [Float]
    var cov: [Float]

    init(w: Int, h: Int) {
        self.w = w
        self.h = h
        ks = [Float](repeating: 0, count: w * h * Spectral.bands)
        res = [Float](repeating: 0, count: w * h * 3)
        cov = [Float](repeating: 0, count: w * h)
    }

    init(copy o: PaintSurface) {
        w = o.w; h = o.h; ks = o.ks; res = o.res; cov = o.cov
    }

    /// Fills the surface from an image (fully covered), e.g. a copy of the cover to smudge.
    func load(_ img: CGImage) {
        guard let ctx = Gfx.context(w, h) else { return }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return }
        let bpr = ctx.bytesPerRow
        let px = data.bindMemory(to: UInt8.self, capacity: bpr * h)
        var R = [Float](repeating: 1, count: Spectral.bands)
        let B = Spectral.bands
        for y in 0..<h {
            for x in 0..<w {
                // Memory rows run top-down for a bitmap context; store top-down too.
                let src = y * bpr + x * 4
                let a = Float(px[src + 3]) / 255
                guard a > 0.001 else { continue }
                let lr = Spectral.decode(Float(px[src]) / 255 / a), lg = Spectral.decode(Float(px[src + 1]) / 255 / a)
                let lb = Spectral.decode(Float(px[src + 2]) / 255 / a)
                Spectral.reflectance(lr, lg, lb, into: &R)
                let back = Spectral.linearRGB(fromReflectance: R)
                let i = y * w + x
                for k in 0..<B { ks[i * B + k] = Spectral.ks(R[k]) }
                res[i * 3] = lr - back.0
                res[i * 3 + 1] = lg - back.1
                res[i * 3 + 2] = lb - back.2
                cov[i] = a
            }
        }
    }

    func image() -> CGImage? {
        guard let ctx = Gfx.context(w, h), let data = ctx.data else { return nil }
        let bpr = ctx.bytesPerRow
        let px = data.bindMemory(to: UInt8.self, capacity: bpr * h)
        let B = Spectral.bands
        var R = [Float](repeating: 1, count: B)
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let a = min(1, max(0, cov[i]))
                let dst = y * bpr + x * 4
                guard a > 0.002 else {
                    px[dst] = 0; px[dst + 1] = 0; px[dst + 2] = 0; px[dst + 3] = 0
                    continue
                }
                for k in 0..<B { R[k] = Spectral.km(ks[i * B + k]) }
                let c = Spectral.linearRGB(fromReflectance: R)
                let r = Spectral.encode(c.0 + res[i * 3]), g = Spectral.encode(c.1 + res[i * 3 + 1]), b = Spectral.encode(c.2 + res[i * 3 + 2])
                px[dst] = UInt8(min(255, max(0, r * a * 255)))
                px[dst + 1] = UInt8(min(255, max(0, g * a * 255)))
                px[dst + 2] = UInt8(min(255, max(0, b * a * 255)))
                px[dst + 3] = UInt8(min(255, max(0, a * 255)))
            }
        }
        return ctx.makeImage()
    }

    // MARK: Brush

    /// Average paint (K/S, residual, coverage) in a small square around a point.
    func sample(_ cx: Int, _ cy: Int, radius: Int) -> (ks: [Float], res: [Float], cov: Float) {
        let B = Spectral.bands
        var k = [Float](repeating: 0, count: B), r: [Float] = [0, 0, 0]
        var c: Float = 0, wsum: Float = 0
        let rr = max(1, radius)
        var y = max(0, cy - rr)
        while y <= min(h - 1, cy + rr) {
            var x = max(0, cx - rr)
            while x <= min(w - 1, cx + rr) {
                let i = y * w + x
                let wt = max(0.0001, cov[i])
                for b in 0..<B { k[b] += ks[i * B + b] * wt }
                r[0] += res[i * 3] * wt; r[1] += res[i * 3 + 1] * wt; r[2] += res[i * 3 + 2] * wt
                c += cov[i]
                wsum += wt
                x += max(1, rr / 3)
            }
            y += max(1, rr / 3)
        }
        let n = max(1, Float(((2 * rr) / max(1, rr / 3) + 1) * ((2 * rr) / max(1, rr / 3) + 1)))
        return (k.map { $0 / wsum }, r.map { $0 / wsum }, min(1, c / n))
    }

    /// Applies one dab. `apply` gets the pixel index and the brush weight (0...1) at that pixel.
    func dab(_ cx: Float, _ cy: Float, radius: Float, hardness: Float, _ apply: (Int, Float) -> Void) {
        let r = max(1, radius)
        let x0 = max(0, Int(cx - r)), x1 = min(w - 1, Int(cx + r))
        let y0 = max(0, Int(cy - r)), y1 = min(h - 1, Int(cy + r))
        guard x0 <= x1, y0 <= y1 else { return }
        let inv: Float = 1 / (r * r)
        for y in y0...y1 {
            let dy = Float(y) - cy
            for x in x0...x1 {
                let dx = Float(x) - cx
                let d2 = (dx * dx + dy * dy) * inv
                guard d2 < 1 else { continue }
                // Soft round falloff; harder brushes keep a flatter middle.
                let t = 1 - d2
                let f = hardness > 0.5 ? min(1, t * (1 + 4 * (hardness - 0.5))) : t * t
                apply(y * w + x, f)
            }
        }
    }

    func stroke(_ s: PaintStroke) {
        guard let first = s.points.first else { return }
        let B = Spectral.bands
        let radius = Float(max(0.002, s.size) * Double(w)) / 2
        let strength = Float(min(1, max(0.01, s.strength)))
        let wet = Float(min(1, max(0, s.wetness)))
        let spacing = max(1, radius * 0.22)
        // Brush load.
        let pig = Spectral.pigment(s.color)
        var brushKS = pig.ks, brushRes = pig.residual
        var brushCov: Float = 1
        var brushY: Float = max(0.0005, 0.2126 * Spectral.decode(Float(s.color.r)) + 0.7152 * Spectral.decode(Float(s.color.g)) + 0.0722 * Spectral.decode(Float(s.color.b)))
        func px(_ p: NPoint) -> (Float, Float) { (Float(p.x) * Float(w), Float(p.y) * Float(h)) }
        if s.tool == .smudge {
            let (sx, sy) = px(first)
            let smp = sample(Int(sx), Int(sy), radius: Int(radius * 0.5))
            brushKS = smp.ks; brushRes = smp.res; brushCov = smp.cov
        }
        var points: [(Float, Float)] = [px(first)]
        for p in s.points.dropFirst() {
            let (x, y) = px(p)
            let (lx, ly) = points[points.count - 1]
            let d = ((x - lx) * (x - lx) + (y - ly) * (y - ly)).squareRoot()
            let n = Int(d / spacing)
            if n >= 1 {
                for k in 1...n {
                    let t = Float(k) / Float(n)
                    points.append((lx + (x - lx) * t, ly + (y - ly) * t))
                }
            }
        }
        var scratchKS = [Float](repeating: 0, count: B)
        // A stroke lays its paint down once: overlapping dabs only add what the stroke hasn't given a pixel yet,
        // so a half-strength glaze stays half-strength however many dabs cross a pixel.
        var given = [Float](repeating: 0, count: s.tool == .paint || s.tool == .lift ? w * h : 0)
        for (cx, cy) in points {
            switch s.tool {
            case .paint:
                // A wet brush picks up what's on the canvas and mixes it into its load.
                if wet > 0.01 {
                    let under = sample(Int(cx), Int(cy), radius: Int(radius * 0.4))
                    let pick = wet * 0.12 * under.cov
                    for b in 0..<B { brushKS[b] += (under.ks[b] - brushKS[b]) * pick }
                    brushY = Spectral.luminance(brushKS, at: 0)
                    for c in 0..<3 { brushRes[c] += (under.res[c] - brushRes[c]) * pick }
                }
                dab(cx, cy, radius: radius, hardness: 1 - wet * 0.6) { i, f in
                    let target = f * strength
                    let prev = given[i]
                    guard target > prev + 0.0005 else { return }
                    given[i] = target
                    let a = (target - prev) / max(0.0001, 1 - prev)
                    // Weight each paint by its tinting strength (lightness), as real pigments behave.
                    let pxY = self.cov[i] > 0.01 ? Spectral.luminance(self.ks, at: i * B) : brushY
                    let old = self.cov[i] * (1 - a) * pxY
                    let new = a * brushY
                    let total = old + new
                    guard total > 0.0000001 else { return }
                    let wn = new / total, wo = old / total
                    for b in 0..<B { self.ks[i * B + b] = self.ks[i * B + b] * wo + brushKS[b] * wn }
                    for c in 0..<3 { self.res[i * 3 + c] = self.res[i * 3 + c] * wo + brushRes[c] * wn }
                    self.cov[i] = self.cov[i] + a * (1 - self.cov[i])
                }
            case .smudge:
                let carry = brushKS, carryRes = brushRes, carryCov = brushCov
                dab(cx, cy, radius: radius, hardness: 0.3) { i, f in
                    let a = f * strength * 0.55
                    for b in 0..<B { self.ks[i * B + b] += (carry[b] - self.ks[i * B + b]) * a }
                    for c in 0..<3 { self.res[i * 3 + c] += (carryRes[c] - self.res[i * 3 + c]) * a }
                    self.cov[i] += (carryCov - self.cov[i]) * a
                }
                // The finger slowly takes on the colors it drags through.
                let under = sample(Int(cx), Int(cy), radius: Int(radius * 0.4))
                // A finger mostly carries what it just touched: colors smear along the stroke and fade out.
                let take = 0.45 + 0.35 * (1 - strength)
                for b in 0..<B { brushKS[b] += (under.ks[b] - brushKS[b]) * take }
                for c in 0..<3 { brushRes[c] += (under.res[c] - brushRes[c]) * take }
                brushCov += (under.cov - brushCov) * take
            case .blend:
                // Water: each pixel moves toward the average around it, so neighboring colors melt together.
                let local = sample(Int(cx), Int(cy), radius: Int(radius * 0.7))
                scratchKS = local.ks
                let avg = scratchKS, avgRes = local.res, avgCov = local.cov
                dab(cx, cy, radius: radius, hardness: 0.2) { i, f in
                    let a = f * strength * 0.5
                    for b in 0..<B { self.ks[i * B + b] += (avg[b] - self.ks[i * B + b]) * a }
                    for c in 0..<3 { self.res[i * 3 + c] += (avgRes[c] - self.res[i * 3 + c]) * a }
                    self.cov[i] += (avgCov - self.cov[i]) * a * 0.5
                }
            case .lift:
                dab(cx, cy, radius: radius, hardness: 0.4) { i, f in
                    let target = f * strength
                    let prev = given[i]
                    guard target > prev + 0.0005 else { return }
                    given[i] = target
                    self.cov[i] *= 1 - (target - prev) / max(0.0001, 1 - prev)
                }
            }
        }
    }
}

// MARK: - Rendering with an incremental cache

final class PaintEngine {
    static let shared = PaintEngine()
    private let lock = NSLock()

    private struct Cached {
        var w: Int
        var h: Int
        var base: UUID?
        var strokes: [PaintStroke]
        var surface: PaintSurface
    }
    private var cache: [UUID: Cached] = [:]

    /// Paint pixels are simulated at a working resolution and scaled to the layer.
    static func workSize(for size: CGSize) -> (Int, Int) {
        let maxSide: CGFloat = 820
        let s = min(1, maxSide / max(size.width, size.height))
        return (max(8, Int(size.width * s)), max(8, Int(size.height * s)))
    }

    func render(_ p: PaintContent, size: CGSize, layerID: UUID, doc: CoverDocument) -> CGImage? {
        let (w, h) = PaintEngine.workSize(for: size)
        // Reuse the surface painted so far when the new content only adds to the last state.
        lock.lock()
        let hit = cache[layerID]
        lock.unlock()
        var surface: PaintSurface
        var done = 0
        if let hit, hit.w == w, hit.h == h, hit.base == p.baseAssetID, hit.strokes.count <= p.strokes.count,
           Array(p.strokes.prefix(hit.strokes.count)) == hit.strokes {
            surface = PaintSurface(copy: hit.surface)
            done = hit.strokes.count
        } else {
            surface = PaintSurface(w: w, h: h)
            if let id = p.baseAssetID, let data = doc.assetData(id),
               let src = CGImageSourceCreateWithData(data as CFData, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                surface.load(img)
            }
        }
        // Keep the state before the last stroke cached: while it is being drawn, only that stroke replays.
        let settled = max(done, p.strokes.count - 1)
        if done < settled {
            for s in p.strokes[done..<settled] { surface.stroke(s) }
            lock.lock()
            cache[layerID] = Cached(w: w, h: h, base: p.baseAssetID, strokes: Array(p.strokes.prefix(settled)), surface: PaintSurface(copy: surface))
            if cache.count > 8 { cache.removeValue(forKey: cache.keys.first { $0 != layerID } ?? layerID) }
            lock.unlock()
        }
        if settled < p.strokes.count { surface.stroke(p.strokes[settled]) }
        guard let img = surface.image() else { return nil }
        guard let ctx = Gfx.context(Int(size.width), Int(size.height)) else { return img }
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return ctx.makeImage()
    }
}

// MARK: - Watercolor simulation

extension Watercolor {
    /// Simulated wet-in-wet watercolor: irregular wet blooms receive pigment, pigment diffuses and mixes
    /// (spectrally) inside the wet areas, collects at the edges as the wash dries, and granulates in the
    /// paper's tooth. Bare paper shows between blooms.
    static func simulate(size: CGSize, pigments: [RGBA], paper: RGBA, seed: Int, bloomScale: CGFloat = 1,
                         wetness: Double = 0.6, strength: Double = 0.7, coverage: Double = 0.6, granulation: Double = 0.4) -> CGImage? {
        let (w, h) = PaintEngine.workSize(for: CGSize(width: min(size.width, 700), height: min(size.height, 700 * size.height / max(1, size.width))))
        let B = Spectral.bands
        let n = w * h
        var ks = [Float](repeating: 0, count: n * B)
        let paperPig = Spectral.pigment(paper)
        for i in 0..<n { for b in 0..<B { ks[i * B + b] = paperPig.ks[b] } }
        var wetAll = [Float](repeating: 0, count: n)
        var rng = SeededRNG(seed: seed)
        let inks: [RGBA] = pigments.isEmpty ? [RGBA(hex: "2A3B9E"), RGBA(hex: "F7D917")] : pigments
        let inkKS: [[Float]] = inks.map { Spectral.pigment($0).ks }
        let unit = Float(min(w, h)) * Float(bloomScale)
        let blooms = Int(4 + 12 * coverage)
        guard let mctx = Gfx.grayContext(w, h), let mdata = mctx.data else { return nil }
        let mbpr = mctx.bytesPerRow
        let mpx = mdata.bindMemory(to: UInt8.self, capacity: mbpr * h)
        for k in 0..<blooms {
            // An irregular wet shape.
            mctx.setFillColor(gray: 0, alpha: 1)
            mctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let cx = CGFloat(rng.range(-0.1, 1.1)) * CGFloat(w), cy = CGFloat(rng.range(-0.1, 1.1)) * CGFloat(h)
            let r = CGFloat(unit) * CGFloat(rng.range(0.12, 0.34))
            let path = CGMutablePath()
            // Ragged, fractal edge: a few big lobes plus fine jitter, like water spreading into paper fibers.
            let verts = 90
            let lobes = Int(rng.range(2, 5))
            let phase = rng.range(0, 6.28)
            var radii: [CGFloat] = []
            for v in 0..<verts {
                let t = Double(v) / Double(verts) * 2 * Double.pi
                let big = 1 + 0.22 * sin(Double(lobes) * t + phase) + 0.1 * sin(Double(lobes * 2 + 1) * t + phase * 1.7)
                radii.append(r * CGFloat(big) * CGFloat(rng.range(0.94, 1.06)))
            }
            for v in 0..<verts {
                let a = CGFloat(v) / CGFloat(verts) * 2 * .pi
                let rr = (radii[v] * 2 + radii[(v + 1) % verts] + radii[(v + verts - 1) % verts]) / 4
                let p = CGPoint(x: cx + cos(a) * rr * 1.15, y: cy + sin(a) * rr)
                if v == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            mctx.setFillColor(gray: 1, alpha: 1)
            mctx.addPath(path)
            mctx.fillPath()
            // Pigment drops: one or two paints per bloom, concentration varies across it.
            let a = inkKS[k % inkKS.count]
            let b = inkKS[(k + 1 + rng.int(max(1, inkKS.count))) % inkKS.count]
            let conc = Float(0.25 + 0.6 * strength) * Float(rng.range(0.6, 1.1))
            let tilt = Float(rng.range(-1, 1))
            // Uneven pigment inside the wash: a coarse random grid, smoothly interpolated.
            let gridN = 6
            var grid: [Float] = []
            for _ in 0..<(gridN * gridN) { grid.append(Float(rng.range(0.45, 1.35))) }
            func uneven(_ x: Int, _ y: Int) -> Float {
                let gx = Float(x) / Float(max(1, w - 1)) * Float(gridN - 1), gy = Float(y) / Float(max(1, h - 1)) * Float(gridN - 1)
                let x0 = min(gridN - 2, Int(gx)), y0 = min(gridN - 2, Int(gy))
                let fx = gx - Float(x0), fy = gy - Float(y0)
                let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
                let a0 = grid[y0 * gridN + x0] * (1 - sx) + grid[y0 * gridN + x0 + 1] * sx
                let a1 = grid[(y0 + 1) * gridN + x0] * (1 - sx) + grid[(y0 + 1) * gridN + x0 + 1] * sx
                return a0 * (1 - sy) + a1 * sy
            }
            for y in 0..<h {
                let rowSrc = y * mbpr
                for x in 0..<w {
                    let m = Float(mpx[rowSrc + x]) / 255
                    guard m > 0.01 else { continue }
                    let i = y * w + x
                    // A gradient of the two paints across the bloom: wet-in-wet charge.
                    let t = min(1, max(0, 0.5 + tilt * (Float(x) - Float(cx)) / max(1, Float(r) * 2)))
                    let cc = conc * uneven(x, y)
                    for c in 0..<B {
                        ks[i * B + c] += m * cc * (a[c] * (1 - t) + b[c] * t)
                    }
                    wetAll[i] = max(wetAll[i], m)
                }
            }
            // Tide line: pigment carried to the rim of this bloom as it dries.
            let edgeBlur = max(1, Int(r * 0.07))
            var maskF = [Float](repeating: 0, count: n)
            for y in 0..<h { for x in 0..<w { maskF[y * w + x] = Float(mpx[y * mbpr + x]) / 255 } }
            // Separable box blur, both directions, so the rim forms all the way round.
            var horiz = [Float](repeating: 0, count: n)
            for y in 0..<h {
                var acc: Float = 0
                for x in 0..<min(w, edgeBlur) { acc += maskF[y * w + x] }
                for x in 0..<w {
                    let add = x + edgeBlur, sub = x - edgeBlur - 1
                    if add < w { acc += maskF[y * w + add] }
                    if sub >= 0 { acc -= maskF[y * w + sub] }
                    horiz[y * w + x] = acc / Float(2 * edgeBlur + 1)
                }
            }
            var blurred = [Float](repeating: 0, count: n)
            for x in 0..<w {
                var acc: Float = 0
                for y in 0..<min(h, edgeBlur) { acc += horiz[y * w + x] }
                for y in 0..<h {
                    let add = y + edgeBlur, sub = y - edgeBlur - 1
                    if add < h { acc += horiz[add * w + x] }
                    if sub >= 0 { acc -= horiz[sub * w + x] }
                    blurred[y * w + x] = acc / Float(2 * edgeBlur + 1)
                }
            }
            let rim = Float(0.5 + 0.9 * wetness) * conc
            for y in 0..<h {
                let rowSrc = y * mbpr
                for x in 0..<w {
                    let m = Float(mpx[rowSrc + x]) / 255
                    guard m > 0.5 else { continue }
                    let e = max(0, m - blurred[y * w + x]) * 3.2
                    guard e > 0.01 else { continue }
                    let i = y * w + x
                    for c in 0..<B { ks[i * B + c] += e * rim * (a[c] + b[c]) * 0.5 }
                }
            }
        }
        // Diffusion inside the wet areas: neighboring paints flow into each other and mix.
        let iterations = Int(4 + 10 * wetness)
        var tmp = ks
        for _ in 0..<iterations {
            for y in 1..<(h - 1) {
                for x in 1..<(w - 1) {
                    let i = y * w + x
                    let wv = wetAll[i]
                    guard wv > 0.05 else { continue }
                    let flow = 0.2 * wv
                    for c in 0..<B {
                        let j = i * B + c
                        let avg = (ks[j - B] + ks[j + B] + ks[j - w * B] + ks[j + w * B]) * 0.25
                        tmp[j] = ks[j] + (avg - ks[j]) * flow
                    }
                }
            }
            swap(&ks, &tmp)
        }
        // Granulation: paint settles into the paper's tooth.
        var grng = SeededRNG(seed: seed &+ 77)
        for i in 0..<n where wetAll[i] > 0.05 {
            let g = 1 + Float(granulation) * 0.35 * Float(grng.range(-1, 1))
            for c in 0..<B { ks[i * B + c] *= g }
        }
        // To pixels.
        guard let ctx = Gfx.context(w, h), let data = ctx.data else { return nil }
        let bpr = ctx.bytesPerRow
        let px = data.bindMemory(to: UInt8.self, capacity: bpr * h)
        var R = [Float](repeating: 1, count: B)
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                for c in 0..<B { R[c] = Spectral.km(ks[i * B + c]) }
                let col = Spectral.linearRGB(fromReflectance: R)
                let dst = y * bpr + x * 4
                px[dst] = UInt8(min(255, max(0, Spectral.encode(col.0 + paperPig.residual[0]) * 255)))
                px[dst + 1] = UInt8(min(255, max(0, Spectral.encode(col.1 + paperPig.residual[1]) * 255)))
                px[dst + 2] = UInt8(min(255, max(0, Spectral.encode(col.2 + paperPig.residual[2]) * 255)))
                px[dst + 3] = 255
            }
        }
        guard let small = ctx.makeImage() else { return nil }
        let W = max(1, Int(size.width)), H = max(1, Int(size.height))
        guard let big = Gfx.context(W, H) else { return small }
        big.interpolationQuality = .high
        big.draw(small, in: CGRect(x: 0, y: 0, width: W, height: H))
        return big.makeImage()
    }
}
