import CoreGraphics
import Foundation

/// Object removal: exemplar-based inpainting (PatchMatch nearest-neighbor fields with weighted
/// voting) over a coarse-to-fine pyramid. Works at ≤ 768 px and composites the fill back into the
/// full-resolution picture with a 2 px feather.
enum Inpainter {
    static let workSide = 768
    static let patchHalf = 3
    static let iterations = 5

    /// Removes everything under the mask (white = remove) and fills it from the surroundings.
    static func remove(from image: CGImage, mask: CGImage) -> CGImage? {
        let W = image.width, H = image.height
        guard W > 8, H > 8 else { return nil }
        let opaque = [CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)

        // Full-resolution pixels and the (dilated) removal mask.
        guard let srcCtx = Gfx.context(W, H), let maskCtx = Gfx.grayContext(W, H) else { return nil }
        srcCtx.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H))
        maskCtx.draw(mask, in: CGRect(x: 0, y: 0, width: W, height: H))
        guard let sp = srcCtx.data?.assumingMemoryBound(to: UInt8.self),
              let mp = maskCtx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let sbpr = srcCtx.bytesPerRow, mbpr = maskCtx.bytesPerRow
        var hole = [UInt8](repeating: 0, count: W * H)
        var any = false
        for y in 0..<H {
            for x in 0..<W where mp[y * mbpr + x] > 127 {
                hole[y * W + x] = 1
                any = true
            }
        }
        guard any else { return image }
        hole = dilate(hole, W, H, by: 3)

        // Working copy.
        let s = min(1, Double(workSide) / Double(max(W, H)))
        let w0 = max(8, Int((Double(W) * s).rounded())), h0 = max(8, Int((Double(H) * s).rounded()))
        guard let workCtx = Gfx.context(w0, h0), let wp = workCtx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        workCtx.draw(image, in: CGRect(x: 0, y: 0, width: w0, height: h0))
        let wbpr = workCtx.bytesPerRow
        var rgb = [Float](repeating: 0, count: w0 * h0 * 3)
        for y in 0..<h0 {
            for x in 0..<w0 {
                let p = wp + y * wbpr + x * 4
                let i = (y * w0 + x) * 3
                rgb[i] = Float(p[0]); rgb[i + 1] = Float(p[1]); rgb[i + 2] = Float(p[2])
            }
        }
        var holeW = [UInt8](repeating: 0, count: w0 * h0)
        for y in 0..<h0 {
            let y0 = Int(Double(y) / s), y1 = min(H - 1, Int(Double(y + 1) / s))
            for x in 0..<w0 {
                let x0 = Int(Double(x) / s), x1 = min(W - 1, Int(Double(x + 1) / s))
                var hit = false
                var yy = y0
                while yy <= y1 && !hit {
                    var xx = x0
                    while xx <= x1 {
                        if hole[yy * W + xx] != 0 { hit = true; break }
                        xx += 1
                    }
                    yy += 1
                }
                if hit { holeW[y * w0 + x] = 1 }
            }
        }
        if s < 1 { holeW = dilate(holeW, w0, h0, by: 1) }

        // Pyramid: level 0 is the working size; each level halves.
        var levels: [Level] = [Level(w: w0, h: h0, rgb: rgb, hole: holeW)]
        let long = max(w0, h0)
        let count = long / 16 >= 48 ? 5 : 4
        while levels.count < count {
            let prev = levels[levels.count - 1]
            guard prev.w >= 16, prev.h >= 16 else { break }
            levels.append(prev.halved())
        }
        var rng = XorShift(seed: 0x9E37_79B9)
        let coarsest = levels.count - 1
        levels[coarsest].seedHole()
        for li in stride(from: coarsest, through: 0, by: -1) {
            if li < coarsest {
                let coarse = levels[li + 1]
                levels[li].inherit(from: coarse)
            }
            levels[li].solve(rng: &rng)
        }
        let filled = levels[0]

        // Back to full resolution: the fill is upsampled and feathered into the original.
        guard let fillImage = filled.makeImage(), let upCtx = Gfx.context(W, H),
              let up = upCtx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        upCtx.draw(fillImage, in: CGRect(x: 0, y: 0, width: W, height: H))
        let ubpr = upCtx.bytesPerRow
        let feather = featherMask(hole, W, H, radius: 2)
        let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
        guard let outCtx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: Gfx.sRGB, bitmapInfo: info),
              let op = outCtx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let obpr = outCtx.bytesPerRow
        for y in 0..<H {
            for x in 0..<W {
                let i = y * W + x
                let o = op + y * obpr + x * 4
                let sPix = sp + y * sbpr + x * 4
                let t = feather[i]
                if t <= 0 {
                    o[0] = sPix[0]; o[1] = sPix[1]; o[2] = sPix[2]; o[3] = sPix[3]
                    continue
                }
                let u = up + y * ubpr + x * 4
                let inv = 1 - t
                o[0] = UInt8(min(255, max(0, (Float(sPix[0]) * inv + Float(u[0]) * t).rounded())))
                o[1] = UInt8(min(255, max(0, (Float(sPix[1]) * inv + Float(u[1]) * t).rounded())))
                o[2] = UInt8(min(255, max(0, (Float(sPix[2]) * inv + Float(u[2]) * t).rounded())))
                o[3] = max(sPix[3], UInt8(min(255, (t * 255).rounded())))
            }
        }
        return outCtx.makeImage()
    }

    /// Rasterizes brush strokes (image space, 0...1, top-left) to a removal mask: white where painted.
    static func strokeMask(_ strokes: [MaskStroke], width w: Int, height h: Int) -> CGImage? {
        guard let ctx = Gfx.grayContext(w, h) else { return nil }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(gray: 1, alpha: 1)
        ctx.setFillColor(gray: 1, alpha: 1)
        let unit = CGFloat(min(w, h))
        for s in strokes {
            let r = CGFloat(s.radius) * unit
            let pts = s.points.map { CGPoint(x: CGFloat($0.x) * CGFloat(w), y: CGFloat(1 - $0.y) * CGFloat(h)) }
            guard let first = pts.first else { continue }
            if pts.count == 1 {
                ctx.fillEllipse(in: CGRect(x: first.x - r, y: first.y - r, width: 2 * r, height: 2 * r))
                continue
            }
            ctx.setLineWidth(2 * r)
            ctx.move(to: first)
            for p in pts.dropFirst() { ctx.addLine(to: p) }
            ctx.strokePath()
        }
        return ctx.makeImage()
    }

    // MARK: Mask helpers

    /// Binary dilation with a square structuring element (separable max filter).
    static func dilate(_ m: [UInt8], _ w: Int, _ h: Int, by r: Int) -> [UInt8] {
        guard r > 0 else { return m }
        var tmp = [UInt8](repeating: 0, count: w * h)
        var out = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            let row = y * w
            for x in 0..<w where m[row + x] != 0 {
                let x0 = max(0, x - r), x1 = min(w - 1, x + r)
                for xx in x0...x1 { tmp[row + xx] = 1 }
            }
        }
        for y in 0..<h {
            let row = y * w
            for x in 0..<w where tmp[row + x] != 0 {
                let y0 = max(0, y - r), y1 = min(h - 1, y + r)
                for yy in y0...y1 { out[yy * w + x] = 1 }
            }
        }
        return out
    }

    /// 0...1 blend weights: the binary mask softened by a box blur of the given radius.
    static func featherMask(_ m: [UInt8], _ w: Int, _ h: Int, radius r: Int) -> [Float] {
        var f = [Float](repeating: 0, count: w * h)
        for i in 0..<(w * h) { f[i] = m[i] != 0 ? 1 : 0 }
        guard r > 0 else { return f }
        var tmp = [Float](repeating: 0, count: w * h)
        let span = Float(2 * r + 1)
        for y in 0..<h {
            let row = y * w
            var acc: Float = 0
            for x in 0..<(min(w, r + 1)) { acc += f[row + x] }
            // Clamped edges: missing samples repeat the edge value.
            for x in 0..<w {
                let lo = x - r, hi = x + r
                var v = acc
                if lo < 0 { v += f[row] * Float(-lo) }
                if hi >= w { v += f[row + w - 1] * Float(hi - w + 1) }
                tmp[row + x] = v / span
                if lo >= 0 { acc -= f[row + lo] }
                if hi + 1 < w { acc += f[row + hi + 1] }
            }
        }
        for x in 0..<w {
            var acc: Float = 0
            for y in 0..<(min(h, r + 1)) { acc += tmp[y * w + x] }
            for y in 0..<h {
                let lo = y - r, hi = y + r
                var v = acc
                if lo < 0 { v += tmp[x] * Float(-lo) }
                if hi >= h { v += tmp[(h - 1) * w + x] * Float(hi - h + 1) }
                f[y * w + x] = v / span
                if lo >= 0 { acc -= tmp[lo * w + x] }
                if hi + 1 < h { acc += tmp[(hi + 1) * w + x] }
            }
        }
        return f
    }

    // MARK: Pyramid level

    struct XorShift {
        var state: UInt32
        init(seed: UInt32) { state = seed == 0 ? 1 : seed }
        mutating func next() -> UInt32 {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            return state
        }
        /// Uniform in 0..<n.
        mutating func below(_ n: Int) -> Int { n <= 1 ? 0 : Int(next() % UInt32(n)) }
        /// Uniform in -r...r.
        mutating func signed(_ r: Int) -> Int { below(2 * r + 1) - r }
    }

    /// One level of the pyramid: the picture (interleaved RGB floats), the hole, and the
    /// nearest-neighbor field for every pixel near the hole.
    struct Level {
        let w: Int
        let h: Int
        var rgb: [Float]
        /// 1 where pixels must be invented.
        var hole: [UInt8]
        /// 1 where a 7×7 source patch centered here is fully known and inside the picture.
        var validCenter: [UInt8] = []
        /// 1 for hole pixels and the half-patch ring around them (where the field is defined).
        var region: [UInt8] = []
        /// Field: index of the source patch center for each region pixel (-1 elsewhere).
        var nnf: [Int32] = []
        var dist: [Float] = []
        var sources: [Int32] = []

        init(w: Int, h: Int, rgb: [Float], hole: [UInt8]) {
            self.w = w; self.h = h; self.rgb = rgb; self.hole = hole
        }

        /// The next coarser level: 2× box downsample; a coarse pixel is hole if any child is.
        func halved() -> Level {
            let nw = max(4, w / 2), nh = max(4, h / 2)
            var nrgb = [Float](repeating: 0, count: nw * nh * 3)
            var nhole = [UInt8](repeating: 0, count: nw * nh)
            for y in 0..<nh {
                for x in 0..<nw {
                    var r: Float = 0, g: Float = 0, b: Float = 0, n: Float = 0
                    var anyHole = false
                    for dy in 0..<2 {
                        let sy = min(h - 1, y * 2 + dy)
                        for dx in 0..<2 {
                            let sx = min(w - 1, x * 2 + dx)
                            let i = (sy * w + sx) * 3
                            r += rgb[i]; g += rgb[i + 1]; b += rgb[i + 2]; n += 1
                            if hole[sy * w + sx] != 0 { anyHole = true }
                        }
                    }
                    let o = (y * nw + x) * 3
                    nrgb[o] = r / n; nrgb[o + 1] = g / n; nrgb[o + 2] = b / n
                    if anyHole { nhole[y * nw + x] = 1 }
                }
            }
            return Level(w: nw, h: nh, rgb: nrgb, hole: nhole)
        }

        mutating func prepare() {
            let half = Inpainter.patchHalf
            validCenter = [UInt8](repeating: 0, count: w * h)
            // A patch centered within half a patch of the hole touches it; everything else is a source.
            region = Inpainter.dilate(hole, w, h, by: half)
            sources = []
            for y in half..<(h - half) {
                for x in half..<(w - half) where region[y * w + x] == 0 {
                    validCenter[y * w + x] = 1
                    sources.append(Int32(y * w + x))
                }
            }
            if nnf.count != w * h {
                nnf = [Int32](repeating: -1, count: w * h)
                dist = [Float](repeating: .greatestFiniteMagnitude, count: w * h)
            }
        }

        /// Coarsest level only: start the hole from the average of its rim, then diffuse.
        mutating func seedHole() {
            let rim = Inpainter.dilate(hole, w, h, by: 2)
            var r: Float = 0, g: Float = 0, b: Float = 0, n: Float = 0
            for i in 0..<(w * h) where rim[i] != 0 && hole[i] == 0 {
                r += rgb[i * 3]; g += rgb[i * 3 + 1]; b += rgb[i * 3 + 2]; n += 1
            }
            if n == 0 {
                for i in 0..<(w * h) { r += rgb[i * 3]; g += rgb[i * 3 + 1]; b += rgb[i * 3 + 2]; n += 1 }
            }
            for i in 0..<(w * h) where hole[i] != 0 {
                rgb[i * 3] = r / n; rgb[i * 3 + 1] = g / n; rgb[i * 3 + 2] = b / n
            }
            for _ in 0..<40 {
                var next = rgb
                for y in 1..<(h - 1) {
                    for x in 1..<(w - 1) where hole[y * w + x] != 0 {
                        let i = y * w + x
                        for c in 0..<3 {
                            let sum = rgb[(i - 1) * 3 + c] + rgb[(i + 1) * 3 + c] + rgb[(i - w) * 3 + c] + rgb[(i + w) * 3 + c]
                            next[i * 3 + c] = sum / 4
                        }
                    }
                }
                rgb = next
            }
        }

        /// Finer level: hole pixels take the coarse fill (bilinear) and the field is upsampled.
        mutating func inherit(from coarse: Level) {
            prepare()
            for y in 0..<h {
                let fy = min(Float(coarse.h - 1), max(0, (Float(y) + 0.5) / 2 - 0.5))
                let y0 = Int(fy), y1 = min(coarse.h - 1, y0 + 1)
                let ty = fy - Float(y0)
                for x in 0..<w where hole[y * w + x] != 0 {
                    let fx = min(Float(coarse.w - 1), max(0, (Float(x) + 0.5) / 2 - 0.5))
                    let x0 = Int(fx), x1 = min(coarse.w - 1, x0 + 1)
                    let tx = fx - Float(x0)
                    for c in 0..<3 {
                        let a = coarse.rgb[(y0 * coarse.w + x0) * 3 + c] * (1 - tx) + coarse.rgb[(y0 * coarse.w + x1) * 3 + c] * tx
                        let b = coarse.rgb[(y1 * coarse.w + x0) * 3 + c] * (1 - tx) + coarse.rgb[(y1 * coarse.w + x1) * 3 + c] * tx
                        rgb[(y * w + x) * 3 + c] = a * (1 - ty) + b * ty
                    }
                }
            }
            for y in 0..<h {
                for x in 0..<w where region[y * w + x] != 0 {
                    let cx = min(coarse.w - 1, x / 2), cy = min(coarse.h - 1, y / 2)
                    let src = coarse.nnf[cy * coarse.w + cx]
                    guard src >= 0 else { continue }
                    let sx = Int(src) % coarse.w * 2 + (x - cx * 2)
                    let sy = Int(src) / coarse.w * 2 + (y - cy * 2)
                    if sx >= 0, sx < w, sy >= 0, sy < h, validCenter[sy * w + sx] != 0 {
                        nnf[y * w + x] = Int32(sy * w + sx)
                    }
                }
            }
        }

        /// Alternating PatchMatch passes and votes until the fill settles.
        mutating func solve(rng: inout XorShift) {
            if validCenter.count != w * h { prepare() }
            guard !sources.isEmpty else { return }
            let half = Inpainter.patchHalf
            let W = w, H = h
            let n = W * H
            // Random init for anything the coarser level didn't hand down.
            for i in 0..<n where region[i] != 0 && nnf[i] < 0 {
                nnf[i] = sources[rng.below(sources.count)]
            }
            for i in 0..<n where region[i] != 0 { dist[i] = patchDistance(i, Int(nnf[i]), limit: .greatestFiniteMagnitude) }

            for iter in 0..<Inpainter.iterations {
                let forward = iter % 2 == 0
                let maxRadius = max(W, H)
                let ys = forward ? Array(0..<H) : Array((0..<H).reversed())
                let xs = forward ? Array(0..<W) : Array((0..<W).reversed())
                for y in ys {
                    for x in xs {
                        let i = y * W + x
                        if region[i] == 0 { continue }
                        var best = Int(nnf[i])
                        var bestD = dist[i]
                        // A perfect match cannot improve.
                        if bestD <= 0 { continue }
                        // Propagation from the neighbor just visited.
                        let step = forward ? -1 : 1
                        let nx = x + step, ny = y + step
                        if nx >= 0, nx < W, region[y * W + nx] != 0 {
                            let c = Int(nnf[y * W + nx]) - step
                            if c >= 0, c < n, validCenter[c] != 0, c % W == (Int(nnf[y * W + nx]) % W) - step {
                                let d = patchDistance(i, c, limit: bestD)
                                if d < bestD { bestD = d; best = c }
                            }
                        }
                        if ny >= 0, ny < H, region[ny * W + x] != 0 {
                            let c = Int(nnf[ny * W + x]) - step * W
                            if c >= 0, c < n, validCenter[c] != 0 {
                                let d = patchDistance(i, c, limit: bestD)
                                if d < bestD { bestD = d; best = c }
                            }
                        }
                        // Random search around the current best, radius halving each try.
                        var radius = maxRadius
                        let bx = best % W, by = best / W
                        while radius >= 1 {
                            let cx = bx + rng.signed(radius), cy = by + rng.signed(radius)
                            if cx >= half, cx < W - half, cy >= half, cy < H - half {
                                let c = cy * W + cx
                                if validCenter[c] != 0 {
                                    let d = patchDistance(i, c, limit: bestD)
                                    if d < bestD { bestD = d; best = c }
                                }
                            }
                            radius /= 2
                        }
                        nnf[i] = Int32(best)
                        dist[i] = bestD
                    }
                }
                vote()
                // Distances change once the hole is repainted.
                for i in 0..<n where region[i] != 0 { dist[i] = patchDistance(i, Int(nnf[i]), limit: .greatestFiniteMagnitude) }
            }
        }

        /// Sum of squared RGB differences between the patch at `a` and the source patch at `b`,
        /// giving up early once it exceeds `limit`.
        func patchDistance(_ a: Int, _ b: Int, limit: Float) -> Float {
            let half = Inpainter.patchHalf
            let ax = a % w, ay = a / w, bx = b % w, by = b / w
            var sum: Float = 0
            return rgb.withUnsafeBufferPointer { p -> Float in
                for dy in -half...half {
                    let sy = ay + dy
                    guard sy >= 0, sy < h else { sum += 3 * 255 * 255 * Float(2 * half + 1); continue }
                    let ra = (sy * w) * 3, rb = ((by + dy) * w) * 3
                    for dx in -half...half {
                        let sx = ax + dx
                        guard sx >= 0, sx < w else { sum += 3 * 255 * 255; continue }
                        let ia = ra + (sx) * 3, ib = rb + (bx + dx) * 3
                        let dr = p[ia] - p[ib], dg = p[ia + 1] - p[ib + 1], db = p[ia + 2] - p[ib + 2]
                        sum += dr * dr + dg * dg + db * db
                    }
                    if sum > limit { return sum }
                }
                return sum
            }
        }

        /// Repaints every hole pixel as the weighted mean of what the patches covering it propose.
        mutating func vote() {
            let half = Inpainter.patchHalf
            var acc = [Float](repeating: 0, count: w * h * 3)
            var weight = [Float](repeating: 0, count: w * h)
            var meanD: Float = 0, cnt: Float = 0
            for i in 0..<(w * h) where region[i] != 0 { meanD += dist[i]; cnt += 1 }
            let sigma = max(1, meanD / max(1, cnt))
            for qy in 0..<h {
                for qx in 0..<w {
                    let q = qy * w + qx
                    if region[q] == 0 { continue }
                    let src = Int(nnf[q])
                    guard src >= 0 else { continue }
                    let sx = src % w, sy = src / w
                    let wgt = expf(-dist[q] / sigma)
                    for dy in -half...half {
                        let py = qy + dy
                        guard py >= 0, py < h else { continue }
                        for dx in -half...half {
                            let px = qx + dx
                            guard px >= 0, px < w else { continue }
                            let p = py * w + px
                            if hole[p] == 0 { continue }
                            let s = ((sy + dy) * w + (sx + dx)) * 3
                            acc[p * 3] += rgb[s] * wgt
                            acc[p * 3 + 1] += rgb[s + 1] * wgt
                            acc[p * 3 + 2] += rgb[s + 2] * wgt
                            weight[p] += wgt
                        }
                    }
                }
            }
            for p in 0..<(w * h) where hole[p] != 0 && weight[p] > 0 {
                rgb[p * 3] = acc[p * 3] / weight[p]
                rgb[p * 3 + 1] = acc[p * 3 + 1] / weight[p]
                rgb[p * 3 + 2] = acc[p * 3 + 2] / weight[p]
            }
        }

        /// The level as an opaque RGBA8 image.
        func makeImage() -> CGImage? {
            guard let ctx = Gfx.context(w, h), let p = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
            let bpr = ctx.bytesPerRow
            for y in 0..<h {
                for x in 0..<w {
                    let i = (y * w + x) * 3
                    let o = p + y * bpr + x * 4
                    o[0] = UInt8(min(255, max(0, rgb[i].rounded())))
                    o[1] = UInt8(min(255, max(0, rgb[i + 1].rounded())))
                    o[2] = UInt8(min(255, max(0, rgb[i + 2].rounded())))
                    o[3] = 255
                }
            }
            return ctx.makeImage()
        }
    }
}
