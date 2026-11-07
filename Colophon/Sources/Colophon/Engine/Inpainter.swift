import CoreGraphics
import Foundation

/// Object removal: exemplar-based inpainting (PatchMatch nearest-neighbor fields with weighted
/// voting) over a coarse-to-fine pyramid. Works at ≤ 640 px and composites the fill back into the
/// full-resolution picture with a 2 px feather.
///
/// The nearest-neighbor field is only solved for hole pixels and the half-patch ring around them;
/// everything else is a fixed source. PatchMatch sweeps run in parallel over stripes of rows
/// (even stripes, then odd), each row with its own seeded generator, so results are deterministic.
enum Inpainter {
    static let workSide = 640
    static let patchHalf = 3
    static let levelCount = 4
    /// PatchMatch iterations per pyramid level, finest first: the coarse levels do the hard work.
    static let iterationsPerLevel = [2, 3, 5, 5]
    /// Cost of a target patch pixel that falls outside the picture.
    static let missingPenalty: Float = 3 * 255 * 255

    /// Removes everything under the mask (white = remove) and fills it from the surroundings.
    static func remove(from image: CGImage, mask: CGImage) -> CGImage? {
        let W = image.width, H = image.height
        guard W > 8, H > 8 else { return nil }
        let opaque = [CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)

        // Full-resolution pixels and the removal mask's bounding box.
        guard let srcCtx = Gfx.context(W, H), let maskCtx = Gfx.grayContext(W, H) else { return nil }
        srcCtx.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H))
        maskCtx.draw(mask, in: CGRect(x: 0, y: 0, width: W, height: H))
        guard let sp = srcCtx.data?.assumingMemoryBound(to: UInt8.self),
              let mp = maskCtx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let sbpr = srcCtx.bytesPerRow, mbpr = maskCtx.bytesPerRow
        var bx0 = W, by0 = H, bx1 = -1, by1 = -1
        for y in 0..<H {
            let row = mp + y * mbpr
            var x = 0
            while x < W {
                if row[x] > 127 {
                    if x < bx0 { bx0 = x }
                    if x > bx1 { bx1 = x }
                    if y < by0 { by0 = y }
                    if y > by1 { by1 = y }
                }
                x += 1
            }
        }
        guard bx1 >= 0 else { return image }

        // Everything at full resolution happens inside a crop around the mask: the 16 px margin
        // is wider than the 3 px dilation plus the feather, so the crop sees exactly what the whole
        // picture would.
        let margin = 16
        let cx0 = max(0, bx0 - margin), cy0 = max(0, by0 - margin)
        let cx1 = min(W - 1, bx1 + margin), cy1 = min(H - 1, by1 + margin)
        let cw = cx1 - cx0 + 1, ch = cy1 - cy0 + 1
        var holeC = [UInt8](repeating: 0, count: cw * ch)
        holeC.withUnsafeMutableBufferPointer { hb in
            let hp = hb.baseAddress!
            for y in 0..<ch {
                let row = mp + (cy0 + y) * mbpr + cx0
                let o = hp + y * cw
                var x = 0
                while x < cw {
                    if row[x] > 127 { o[x] = 1 }
                    x += 1
                }
            }
        }
        holeC = dilate(holeC, cw, ch, by: 3)

        // Working copy.
        let s = min(1, Double(workSide) / Double(max(W, H)))
        let w0 = max(8, Int((Double(W) * s).rounded())), h0 = max(8, Int((Double(H) * s).rounded()))
        guard let workCtx = Gfx.context(w0, h0), let wp = workCtx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        workCtx.draw(image, in: CGRect(x: 0, y: 0, width: w0, height: h0))
        let wbpr = workCtx.bytesPerRow
        let rgb = Buf<Float>(count: w0 * h0 * 3, fill: 0)
        let rp = rgb.p
        for y in 0..<h0 {
            let row = wp + y * wbpr
            let o = rp + y * w0 * 3
            var x = 0
            while x < w0 {
                let p = row + x * 4
                let i = x * 3
                o[i] = Float(p[0]); o[i + 1] = Float(p[1]); o[i + 2] = Float(p[2])
                x += 1
            }
        }
        // A work pixel is hole if any full-resolution pixel under it is.
        var holeW = [UInt8](repeating: 0, count: w0 * h0)
        let wx0 = max(0, Int(Double(cx0) * s) - 1), wx1 = min(w0 - 1, Int(Double(cx1 + 1) * s) + 1)
        let wy0 = max(0, Int(Double(cy0) * s) - 1), wy1 = min(h0 - 1, Int(Double(cy1 + 1) * s) + 1)
        holeC.withUnsafeBufferPointer { hb in
            holeW.withUnsafeMutableBufferPointer { wb in
                let hc = hb.baseAddress!, hw = wb.baseAddress!
                guard wy0 <= wy1, wx0 <= wx1 else { return }
                for y in wy0...wy1 {
                    let y0 = max(cy0, Int(Double(y) / s)), y1 = min(cy1, Int(Double(y + 1) / s))
                    guard y0 <= y1 else { continue }
                    for x in wx0...wx1 {
                        let x0 = max(cx0, Int(Double(x) / s)), x1 = min(cx1, Int(Double(x + 1) / s))
                        guard x0 <= x1 else { continue }
                        var hit = false
                        var yy = y0
                        while yy <= y1 && !hit {
                            let row = hc + (yy - cy0) * cw - cx0
                            var xx = x0
                            while xx <= x1 {
                                if row[xx] != 0 { hit = true; break }
                                xx += 1
                            }
                            yy += 1
                        }
                        if hit { hw[y * w0 + x] = 1 }
                    }
                }
            }
        }
        if s < 1 { holeW = dilate(holeW, w0, h0, by: 1) }

        // Pyramid: level 0 is the working size; each level halves.
        var levels: [Level] = [Level(w: w0, h: h0, rgb: rgb, hole: Buf(holeW))]
        while levels.count < levelCount {
            let prev = levels[levels.count - 1]
            guard prev.w >= 16, prev.h >= 16 else { break }
            levels.append(prev.halved())
        }
        let seed: UInt32 = 0x9E37_79B9
        let coarsest = levels.count - 1
        levels[coarsest].seedHole()
        for li in stride(from: coarsest, through: 0, by: -1) {
            if li < coarsest { levels[li].inherit(from: levels[li + 1]) }
            let iters = li < iterationsPerLevel.count ? iterationsPerLevel[li] : iterationsPerLevel[iterationsPerLevel.count - 1]
            levels[li].solve(level: li, iterations: iters, seed: seed)
        }
        let filled = levels[0]

        // Back to full resolution: the fill is upsampled (only the crop is rendered) and feathered
        // into the original.
        guard let fillImage = filled.makeImage(), let upCtx = Gfx.context(cw, ch),
              let up = upCtx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        upCtx.draw(fillImage, in: CGRect(x: -cx0, y: cy1 + 1 - H, width: W, height: H))
        let ubpr = upCtx.bytesPerRow
        let feather = featherMask(holeC, cw, ch, radius: 2)
        let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
        guard let outCtx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: Gfx.sRGB, bitmapInfo: info),
              let op = outCtx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let obpr = outCtx.bytesPerRow
        for y in 0..<H { memcpy(op + y * obpr, sp + y * sbpr, W * 4) }
        feather.withUnsafeBufferPointer { fb in
            let fp = fb.baseAddress!
            for y in 0..<ch {
                let Y = cy0 + y
                let oRow = op + Y * obpr + cx0 * 4
                let sRow = sp + Y * sbpr + cx0 * 4
                let uRow = up + y * ubpr
                let fRow = fp + y * cw
                var x = 0
                while x < cw {
                    let t = fRow[x]
                    if t > 0 {
                        let o = oRow + x * 4, sPix = sRow + x * 4, u = uRow + x * 4
                        let inv = 1 - t
                        o[0] = UInt8(min(255, max(0, (Float(sPix[0]) * inv + Float(u[0]) * t).rounded())))
                        o[1] = UInt8(min(255, max(0, (Float(sPix[1]) * inv + Float(u[1]) * t).rounded())))
                        o[2] = UInt8(min(255, max(0, (Float(sPix[2]) * inv + Float(u[2]) * t).rounded())))
                        o[3] = max(sPix[3], UInt8(min(255, (t * 255).rounded())))
                    }
                    x += 1
                }
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

    // MARK: Random numbers

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

    /// A well-mixed seed for one row of one sweep, so rows can run in parallel yet deterministically.
    static func rowSeed(_ base: UInt32, level: Int, iteration: Int, row: Int) -> UInt32 {
        let a = UInt32(truncatingIfNeeded: level + 1) &* 0x9E37_79B9
        let b = UInt32(truncatingIfNeeded: iteration + 2) &* 0x85EB_CA6B
        let c = UInt32(truncatingIfNeeded: row + 1) &* 0xC2B2_AE35
        var s = base &+ a
        s = s &+ b
        s = s &+ c
        s ^= s >> 16
        s = s &* 0x7FEB_352D
        s ^= s >> 15
        s = s &* 0x846C_A68B
        s ^= s >> 16
        return s
    }

    // MARK: Buffers

    /// A fixed-size heap buffer addressed through a raw pointer: no bounds checks, no copy-on-write,
    /// shared by reference between the pyramid levels that own it.
    final class Buf<T> {
        let p: UnsafeMutablePointer<T>
        let count: Int

        init(count: Int, fill: T) {
            self.count = max(0, count)
            p = UnsafeMutablePointer<T>.allocate(capacity: max(1, self.count))
            p.initialize(repeating: fill, count: self.count)
        }

        init(_ array: [T]) {
            count = array.count
            p = UnsafeMutablePointer<T>.allocate(capacity: max(1, count))
            let dst = p
            array.withUnsafeBufferPointer { b in
                if let base = b.baseAddress, b.count > 0 { dst.initialize(from: base, count: b.count) }
            }
        }

        deinit {
            p.deinitialize(count: count)
            p.deallocate()
        }

        /// A copy as an array.
        var array: [T] { Array(UnsafeBufferPointer(start: p, count: count)) }
    }

    // MARK: Patch distance

    /// Sum of squared RGB differences between the patch at `a` and the source patch at `b`
    /// (which is fully inside the picture), giving up early once it exceeds `limit`. Pixels of the
    /// target patch outside the picture cost `missingPenalty` each.
    @inline(__always)
    static func patchDistance(_ p: UnsafePointer<Float>, _ w: Int, _ h: Int, _ half: Int, _ a: Int, _ b: Int, limit: Float) -> Float {
        let ay = a / w, ax = a - ay * w
        let by = b / w, bx = b - by * w
        let dy0 = max(-half, -ay), dy1 = min(half, h - 1 - ay)
        let dx0 = max(-half, -ax), dx1 = min(half, w - 1 - ax)
        let cols = dx1 - dx0 + 1, rows = dy1 - dy0 + 1
        let side = 2 * half + 1
        var sum = Float(side * side - rows * cols) * missingPenalty
        if sum > limit { return sum }
        let n = cols * 3
        var dy = dy0
        while dy <= dy1 {
            let pa = p + ((ay + dy) * w + ax + dx0) * 3
            let pb = p + ((by + dy) * w + bx + dx0) * 3
            var k = 0
            while k < n {
                let d = pa[k] - pb[k]
                sum += d * d
                k += 1
            }
            if sum > limit { return sum }
            dy += 1
        }
        return sum
    }

    // MARK: Pyramid level

    /// One level of the pyramid: the picture (interleaved RGB floats), the hole, and the
    /// nearest-neighbor field for every pixel near the hole.
    final class Level {
        let w: Int
        let h: Int
        let rgb: Buf<Float>
        /// 1 where pixels must be invented.
        let hole: Buf<UInt8>
        /// 1 where a 7×7 source patch centered here is fully known and inside the picture.
        var validCenter: Buf<UInt8>
        /// 1 for hole pixels and the half-patch ring around them (where the field is defined).
        var region: Buf<UInt8>
        /// Field: index of the source patch center for each region pixel (-1 elsewhere).
        var nnf: Buf<Int32>
        var dist: Buf<Float>
        /// Vote weight per region pixel.
        var weight: Buf<Float>
        /// All valid source centers.
        var sources: [Int32] = []
        /// Region pixels in raster order, and where each region row starts in that list
        /// (`rowStart[r]..<rowStart[r + 1]` for row `ry0 + r`).
        var regionIdx: [Int32] = []
        var rowStart: [Int] = [0]
        /// Bounding box of the region (inclusive; empty when ry1 < ry0).
        var rx0 = 0, ry0 = 0, rx1 = -1, ry1 = -1
        var prepared = false

        init(w: Int, h: Int, rgb: Buf<Float>, hole: Buf<UInt8>) {
            self.w = w; self.h = h; self.rgb = rgb; self.hole = hole
            validCenter = Buf<UInt8>(count: 1, fill: 0)
            region = Buf<UInt8>(count: 1, fill: 0)
            nnf = Buf<Int32>(count: 1, fill: -1)
            dist = Buf<Float>(count: 1, fill: 0)
            weight = Buf<Float>(count: 1, fill: 0)
        }

        /// The next coarser level: 2× box downsample; a coarse pixel is hole if any child is.
        func halved() -> Level {
            let nw = max(4, w / 2), nh = max(4, h / 2)
            let nrgb = Buf<Float>(count: nw * nh * 3, fill: 0)
            let nhole = Buf<UInt8>(count: nw * nh, fill: 0)
            let src = UnsafePointer(rgb.p), hp = UnsafePointer(hole.p)
            let dst = nrgb.p, dh = nhole.p
            for y in 0..<nh {
                for x in 0..<nw {
                    var r: Float = 0, g: Float = 0, b: Float = 0, n: Float = 0
                    var anyHole = false
                    for dy in 0..<2 {
                        let sy = min(h - 1, y * 2 + dy)
                        for dx in 0..<2 {
                            let sx = min(w - 1, x * 2 + dx)
                            let i = sy * w + sx
                            r += src[i * 3]; g += src[i * 3 + 1]; b += src[i * 3 + 2]; n += 1
                            if hp[i] != 0 { anyHole = true }
                        }
                    }
                    let o = (y * nw + x) * 3
                    dst[o] = r / n; dst[o + 1] = g / n; dst[o + 2] = b / n
                    if anyHole { dh[y * nw + x] = 1 }
                }
            }
            return Level(w: nw, h: nh, rgb: nrgb, hole: nhole)
        }

        /// Builds the region, the source list and the (empty) field. Idempotent.
        func prepare() {
            if prepared { return }
            prepared = true
            let half = Inpainter.patchHalf
            let n = w * h
            // A patch centered within half a patch of the hole touches it; everything else is a source.
            region = Buf(Inpainter.dilate(hole.array, w, h, by: half))
            validCenter = Buf<UInt8>(count: n, fill: 0)
            nnf = Buf<Int32>(count: n, fill: -1)
            dist = Buf<Float>(count: n, fill: .greatestFiniteMagnitude)
            weight = Buf<Float>(count: n, fill: 0)
            let regP = UnsafePointer(region.p), validP = validCenter.p
            sources = []
            sources.reserveCapacity(n)
            regionIdx = []
            rx0 = w; ry0 = h; rx1 = -1; ry1 = -1
            for y in 0..<h {
                let inY = y >= half && y < h - half
                for x in 0..<w {
                    let i = y * w + x
                    if regP[i] != 0 {
                        regionIdx.append(Int32(i))
                        if x < rx0 { rx0 = x }
                        if x > rx1 { rx1 = x }
                        if y < ry0 { ry0 = y }
                        if y > ry1 { ry1 = y }
                    } else if inY && x >= half && x < w - half {
                        validP[i] = 1
                        sources.append(Int32(i))
                    }
                }
            }
            let rows = max(0, ry1 - ry0 + 1)
            rowStart = [Int](repeating: regionIdx.count, count: rows + 1)
            var r = 0
            for (k, i) in regionIdx.enumerated() {
                let y = Int(i) / w - ry0
                while r <= y { rowStart[r] = k; r += 1 }
            }
        }

        /// Coarsest level only: start the hole from the average of its rim, then diffuse.
        func seedHole() {
            let n = w * h
            let holeA = hole.array
            let rim = Inpainter.dilate(holeA, w, h, by: 2)
            var cur = rgb.array
            var r: Float = 0, g: Float = 0, b: Float = 0, cnt: Float = 0
            for i in 0..<n where rim[i] != 0 && holeA[i] == 0 {
                r += cur[i * 3]; g += cur[i * 3 + 1]; b += cur[i * 3 + 2]; cnt += 1
            }
            if cnt == 0 {
                for i in 0..<n { r += cur[i * 3]; g += cur[i * 3 + 1]; b += cur[i * 3 + 2]; cnt += 1 }
            }
            for i in 0..<n where holeA[i] != 0 {
                cur[i * 3] = r / cnt; cur[i * 3 + 1] = g / cnt; cur[i * 3 + 2] = b / cnt
            }
            guard w >= 3, h >= 3 else {
                rgb.p.update(from: cur, count: n * 3)
                return
            }
            var next = cur
            for _ in 0..<40 {
                for y in 1..<(h - 1) {
                    for x in 1..<(w - 1) where holeA[y * w + x] != 0 {
                        let i = y * w + x
                        for c in 0..<3 {
                            let sum = cur[(i - 1) * 3 + c] + cur[(i + 1) * 3 + c] + cur[(i - w) * 3 + c] + cur[(i + w) * 3 + c]
                            next[i * 3 + c] = sum / 4
                        }
                    }
                }
                swap(&cur, &next)
            }
            rgb.p.update(from: cur, count: n * 3)
        }

        /// Finer level: hole pixels take the coarse fill (bilinear) and the field is upsampled.
        func inherit(from coarse: Level) {
            prepare()
            guard ry1 >= ry0, rx1 >= rx0 else { return }
            let cw = coarse.w, chh = coarse.h
            let crgb = UnsafePointer(coarse.rgb.p), cnnf = UnsafePointer(coarse.nnf.p)
            let rp = rgb.p, holeP = UnsafePointer(hole.p), regP = UnsafePointer(region.p)
            let validP = UnsafePointer(validCenter.p), nnfP = nnf.p
            for y in ry0...ry1 {
                let fy = min(Float(chh - 1), max(0, (Float(y) + 0.5) / 2 - 0.5))
                let y0 = Int(fy), y1 = min(chh - 1, y0 + 1)
                let ty = fy - Float(y0)
                for x in rx0...rx1 where holeP[y * w + x] != 0 {
                    let fx = min(Float(cw - 1), max(0, (Float(x) + 0.5) / 2 - 0.5))
                    let x0 = Int(fx), x1 = min(cw - 1, x0 + 1)
                    let tx = fx - Float(x0)
                    let i00 = (y0 * cw + x0) * 3, i01 = (y0 * cw + x1) * 3
                    let i10 = (y1 * cw + x0) * 3, i11 = (y1 * cw + x1) * 3
                    let o = (y * w + x) * 3
                    for c in 0..<3 {
                        let a = crgb[i00 + c] * (1 - tx) + crgb[i01 + c] * tx
                        let b = crgb[i10 + c] * (1 - tx) + crgb[i11 + c] * tx
                        rp[o + c] = a * (1 - ty) + b * ty
                    }
                }
            }
            for y in ry0...ry1 {
                let cy = min(chh - 1, y / 2)
                for x in rx0...rx1 where regP[y * w + x] != 0 {
                    let cx = min(cw - 1, x / 2)
                    let src = Int(cnnf[cy * cw + cx])
                    guard src >= 0 else { continue }
                    let csy = src / cw, csx = src - csy * cw
                    let sx = csx * 2 + (x - cx * 2)
                    let sy = csy * 2 + (y - cy * 2)
                    if sx >= 0, sx < w, sy >= 0, sy < h, validP[sy * w + sx] != 0 {
                        nnfP[y * w + x] = Int32(sy * w + sx)
                    }
                }
            }
        }

        /// Alternating PatchMatch sweeps and votes until the fill settles.
        func solve(level li: Int, iterations: Int, seed: UInt32) {
            prepare()
            guard !sources.isEmpty, !regionIdx.isEmpty, ry1 >= ry0 else { return }
            let half = Inpainter.patchHalf
            let W = w, H = h
            let n = W * H
            let rgbP = UnsafePointer(rgb.p)
            let nnfP = nnf.p, distP = dist.p
            let regP = UnsafePointer(region.p), validP = UnsafePointer(validCenter.p)
            let rows = ry1 - ry0 + 1
            let rowBase = ry0
            let maxRadius = max(W, H)
            let idx = regionIdx, starts = rowStart, srcs = sources
            idx.withUnsafeBufferPointer { ib in
                starts.withUnsafeBufferPointer { sb in
                    srcs.withUnsafeBufferPointer { srcb in
                        let ip = ib.baseAddress!, stp = sb.baseAddress!, srcp = srcb.baseAddress!
                        let srcCount = srcb.count

                        // Random init for anything the coarser level didn't hand down, then distances.
                        DispatchQueue.concurrentPerform(iterations: rows) { r in
                            var rng = XorShift(seed: Inpainter.rowSeed(seed, level: li, iteration: -1, row: r))
                            var k = stp[r]
                            let end = stp[r + 1]
                            while k < end {
                                let i = Int(ip[k])
                                if nnfP[i] < 0 { nnfP[i] = srcp[rng.below(srcCount)] }
                                distP[i] = Inpainter.patchDistance(rgbP, W, H, half, i, Int(nnfP[i]), limit: .greatestFiniteMagnitude)
                                k += 1
                            }
                        }

                        // Rows are swept in stripes: even stripes in parallel, then odd ones, so the
                        // neighbor row a stripe border reads is never being written at the same time.
                        let band = max(4, rows / 32)
                        let stripes = (rows + band - 1) / band
                        for iter in 0..<iterations {
                            let forward = iter % 2 == 0
                            // Offset to the neighbor visited just before this pixel.
                            let step = forward ? -1 : 1
                            for parity in 0..<2 {
                                let count = (stripes - parity + 1) / 2
                                if count <= 0 { continue }
                                DispatchQueue.concurrentPerform(iterations: count) { j in
                                    let stripe = parity + 2 * j
                                    let r0 = stripe * band, r1 = min(rows, r0 + band)
                                    for t in 0..<(r1 - r0) {
                                        let r = forward ? r0 + t : r1 - 1 - t
                                        var rng = XorShift(seed: Inpainter.rowSeed(seed, level: li, iteration: iter, row: r))
                                        let y = rowBase + r
                                        let kStart = stp[r], kEnd = stp[r + 1]
                                        for u in 0..<(kEnd - kStart) {
                                            let k = forward ? kStart + u : kEnd - 1 - u
                                            let i = Int(ip[k])
                                            let x = i - y * W
                                            var best = Int(nnfP[i])
                                            var bestD = distP[i]
                                            // A perfect match cannot improve.
                                            if bestD <= 0 { continue }
                                            // Propagation from the horizontal neighbor just visited.
                                            let nx = x + step
                                            if nx >= 0, nx < W, regP[i + step] != 0 {
                                                let src = Int(nnfP[i + step])
                                                let srcY = src / W, srcX = src - srcY * W
                                                let cx = srcX - step
                                                if cx >= half, cx < W - half {
                                                    let c = src - step
                                                    if validP[c] != 0 {
                                                        let d = Inpainter.patchDistance(rgbP, W, H, half, i, c, limit: bestD)
                                                        if d < bestD { bestD = d; best = c }
                                                    }
                                                }
                                            }
                                            // ... and from the vertical neighbor.
                                            let ny = y + step
                                            if ny >= 0, ny < H, regP[i + step * W] != 0 {
                                                let c = Int(nnfP[i + step * W]) - step * W
                                                if c >= 0, c < n, validP[c] != 0 {
                                                    let d = Inpainter.patchDistance(rgbP, W, H, half, i, c, limit: bestD)
                                                    if d < bestD { bestD = d; best = c }
                                                }
                                            }
                                            // Random search around the current best, radius halving each try.
                                            var radius = maxRadius
                                            let by = best / W, bx = best - by * W
                                            while radius >= 1 {
                                                let cx = bx + rng.signed(radius), cy = by + rng.signed(radius)
                                                if cx >= half, cx < W - half, cy >= half, cy < H - half {
                                                    let c = cy * W + cx
                                                    if validP[c] != 0 {
                                                        let d = Inpainter.patchDistance(rgbP, W, H, half, i, c, limit: bestD)
                                                        if d < bestD { bestD = d; best = c }
                                                    }
                                                }
                                                radius /= 2
                                            }
                                            nnfP[i] = Int32(best)
                                            distP[i] = bestD
                                        }
                                    }
                                }
                            }
                            vote(ip, stp, rows: rows)
                            // Distances change once the hole is repainted (not needed after the last sweep).
                            if iter + 1 < iterations {
                                DispatchQueue.concurrentPerform(iterations: rows) { r in
                                    var k = stp[r]
                                    let end = stp[r + 1]
                                    while k < end {
                                        let i = Int(ip[k])
                                        distP[i] = Inpainter.patchDistance(rgbP, W, H, half, i, Int(nnfP[i]), limit: .greatestFiniteMagnitude)
                                        k += 1
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        /// Repaints every hole pixel as the weighted mean of what the patches covering it propose.
        /// Gathers per hole pixel, so rows run in parallel; sources never overlap the hole, so the
        /// picture can be repainted in place.
        func vote(_ ip: UnsafePointer<Int32>, _ stp: UnsafePointer<Int>, rows: Int) {
            let half = Inpainter.patchHalf
            let W = w, H = h
            let rp = rgb.p
            let rgbP = UnsafePointer(rp)
            let nnfP = UnsafePointer(nnf.p), distP = UnsafePointer(dist.p)
            let regP = UnsafePointer(region.p), holeP = UnsafePointer(hole.p)
            let wgtP = weight.p
            let rowBase = ry0
            let total = stp[rows]
            var meanD: Float = 0
            var k = 0
            while k < total {
                meanD += distP[Int(ip[k])]
                k += 1
            }
            let sigma = max(1, meanD / Float(max(1, total)))
            DispatchQueue.concurrentPerform(iterations: rows) { r in
                var k = stp[r]
                let end = stp[r + 1]
                while k < end {
                    let i = Int(ip[k])
                    wgtP[i] = expf(-distP[i] / sigma)
                    k += 1
                }
            }
            DispatchQueue.concurrentPerform(iterations: rows) { r in
                let y = rowBase + r
                let dy0 = max(-half, -y), dy1 = min(half, H - 1 - y)
                var k = stp[r]
                let end = stp[r + 1]
                while k < end {
                    let i = Int(ip[k])
                    k += 1
                    if holeP[i] == 0 { continue }
                    let x = i - y * W
                    let dx0 = max(-half, -x), dx1 = min(half, W - 1 - x)
                    var sr: Float = 0, sg: Float = 0, sb: Float = 0, sw: Float = 0
                    var dy = dy0
                    while dy <= dy1 {
                        let qRow = i + dy * W
                        var dx = dx0
                        while dx <= dx1 {
                            let q = qRow + dx
                            if regP[q] != 0 {
                                let wq = wgtP[q]
                                // The source patch at nnf[q] proposes its pixel at the same offset.
                                let s = (Int(nnfP[q]) - dy * W - dx) * 3
                                sr += rgbP[s] * wq
                                sg += rgbP[s + 1] * wq
                                sb += rgbP[s + 2] * wq
                                sw += wq
                            }
                            dx += 1
                        }
                        dy += 1
                    }
                    if sw > 0 {
                        rp[i * 3] = sr / sw
                        rp[i * 3 + 1] = sg / sw
                        rp[i * 3 + 2] = sb / sw
                    }
                }
            }
        }

        /// The level as an opaque RGBA8 image.
        func makeImage() -> CGImage? {
            guard let ctx = Gfx.context(w, h), let p = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
            let bpr = ctx.bytesPerRow
            let src = UnsafePointer(rgb.p)
            for y in 0..<h {
                let row = p + y * bpr
                let s = src + y * w * 3
                var x = 0
                while x < w {
                    let i = x * 3
                    let o = row + x * 4
                    o[0] = UInt8(min(255, max(0, s[i].rounded())))
                    o[1] = UInt8(min(255, max(0, s[i + 1].rounded())))
                    o[2] = UInt8(min(255, max(0, s[i + 2].rounded())))
                    o[3] = 255
                    x += 1
                }
            }
            return ctx.makeImage()
        }
    }
}
