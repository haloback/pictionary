import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import Vision

/// Instance-aware subject detection (people and objects, each on its own), per-instance masks,
/// and edge-aware matte refinement.
enum SubjectSegmentation {
    struct Subject: Identifiable {
        enum Kind { case person, object }
        /// Instance index in Vision's foreground instance mask (1-based; 0 is background).
        let id: Int
        let kind: Kind
        /// Normalized, top-left origin.
        let bounds: NRect
        /// Fraction of the picture the instance covers (0...1).
        let area: Double
        /// A small masked crop of the instance, for pickers.
        let thumbnail: CGImage?

        var label: String { kind == .person ? "Person \(id)" : "Object \(id)" }
    }

    /// Raw label buffer: one byte per pixel, row 0 at the top, value = instance index (0 = none).
    private struct Labels {
        var w: Int
        var h: Int
        var bytes: [UInt8]

        func at(_ nx: Double, _ ny: Double) -> Int {
            let x = min(w - 1, max(0, Int(nx * Double(w))))
            let y = min(h - 1, max(0, Int(ny * Double(h))))
            return Int(bytes[y * w + x])
        }
    }

    // MARK: Detection

    /// Every foreground instance (people flagged by the person segmenter), largest first, plus a
    /// per-pixel label image: the instance index sits in the red channel (0 = background). The label
    /// image is at Vision's mask resolution; look pixels up by normalized position (`instance(at:labels:)`).
    static func subjects(in image: CGImage) -> (subjects: [Subject], labels: CGImage?) {
        guard let fg = instanceLabels(in: image, people: false) else { return ([], nil) }
        let people = instanceLabels(in: image, people: true)
        var found: [Subject] = []
        var maxLabel = 0
        for v in fg.bytes where Int(v) > maxLabel { maxLabel = Int(v) }
        guard maxLabel > 0 else { return ([], labelImage(fg)) }

        var minX = [Int](repeating: Int.max, count: maxLabel + 1)
        var minY = [Int](repeating: Int.max, count: maxLabel + 1)
        var maxX = [Int](repeating: -1, count: maxLabel + 1)
        var maxY = [Int](repeating: -1, count: maxLabel + 1)
        var count = [Int](repeating: 0, count: maxLabel + 1)
        var personHits = [Int](repeating: 0, count: maxLabel + 1)
        for y in 0..<fg.h {
            let row = y * fg.w
            let ny = (Double(y) + 0.5) / Double(fg.h)
            for x in 0..<fg.w {
                let l = Int(fg.bytes[row + x])
                if l == 0 { continue }
                count[l] += 1
                if x < minX[l] { minX[l] = x }
                if x > maxX[l] { maxX[l] = x }
                if y < minY[l] { minY[l] = y }
                if y > maxY[l] { maxY[l] = y }
                if let people, people.at((Double(x) + 0.5) / Double(fg.w), ny) != 0 { personHits[l] += 1 }
            }
        }
        let total = Double(fg.w * fg.h)
        for l in 1...maxLabel where count[l] > 0 {
            let b = NRect(Double(minX[l]) / Double(fg.w), Double(minY[l]) / Double(fg.h),
                          Double(maxX[l] - minX[l] + 1) / Double(fg.w), Double(maxY[l] - minY[l] + 1) / Double(fg.h))
            let isPerson = Double(personHits[l]) > Double(count[l]) * 0.5
            let thumb = thumbnail(of: image, instance: l, bounds: b, labels: fg)
            found.append(Subject(id: l, kind: isPerson ? .person : .object, bounds: b, area: Double(count[l]) / total, thumbnail: thumb))
        }
        found.sort { $0.area > $1.area }
        return (found, labelImage(fg))
    }

    /// The instance index under a normalized point of a label image from `subjects(in:)`, nil for background.
    static func instance(at x: Double, _ y: Double, labels: CGImage) -> Int? {
        guard labels.bitsPerPixel == 32, let data = labels.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return nil }
        let px = min(labels.width - 1, max(0, Int(x * Double(labels.width))))
        let py = min(labels.height - 1, max(0, Int(y * Double(labels.height))))
        let v = Int(ptr[py * labels.bytesPerRow + px * 4])
        return v == 0 ? nil : v
    }

    /// A soft mask (gray, subject white) covering only the given foreground instances, at the image's size.
    static func mask(for instances: IndexSet, in image: CGImage) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let obs = request.results?.first else { return nil }
            let wanted = instances.intersection(obs.allInstances)
            guard !wanted.isEmpty else { return nil }
            let buffer = try obs.generateScaledMaskForImage(forInstances: wanted, from: handler)
            let ci = FX.matrix(CIImage(cvPixelBuffer: buffer), r: (1, 0, 0), g: (1, 0, 0), b: (1, 0, 0))
            return Gfx.ci.createCGImage(ci, from: ci.extent, format: .RGBA8, colorSpace: Gfx.sRGB)
        } catch {
            return nil
        }
    }

    // MARK: Matting

    /// Edge-aware refinement of a mask against the picture it came from: a guided filter (the image
    /// luminance guides the matte, so hair and fine edges follow the photo) and a light contrast curve.
    /// `amount` 0...1 sets the radius (4–12 px) and how strongly edges are trusted. Output is a gray
    /// RGBA8 mask at the working size (the guide scaled to at most 1024 px on its long side).
    static func refine(mask: CGImage, guide image: CGImage, amount: Double) -> CGImage? {
        let a = amount.clamped01
        let scale = min(1, 1024 / Double(max(image.width, image.height)))
        let w = max(2, Int(Double(image.width) * scale)), h = max(2, Int(Double(image.height) * scale))
        guard let guideCtx = Gfx.context(w, h), let maskCtx = Gfx.context(w, h) else { return nil }
        guideCtx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        maskCtx.draw(mask, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let gp = guideCtx.data?.assumingMemoryBound(to: UInt8.self),
              let mp = maskCtx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let gbpr = guideCtx.bytesPerRow, mbpr = maskCtx.bytesPerRow
        let n = w * h
        var I = [Float](repeating: 0, count: n)
        var P = [Float](repeating: 0, count: n)
        for y in 0..<h {
            for x in 0..<w {
                let g = gp + y * gbpr + x * 4
                let lum = 0.299 * Float(g[0]) + 0.587 * Float(g[1]) + 0.114 * Float(g[2])
                I[y * w + x] = lum / 255
                P[y * w + x] = Float(mp[y * mbpr + x * 4]) / 255
            }
        }
        let radius = Int((4 + 8 * a).rounded())
        let eps = Float(0.01 * pow(0.1, a))
        var q = guidedFilter(I, P, w, h, radius: radius, eps: eps)
        // Light contrast curve: crisp where the matte is decided, soft where hair is.
        let k = Float(0.6 * a)
        for i in 0..<n {
            let t = min(1, max(0, q[i]))
            let s = t * t * (3 - 2 * t)
            q[i] = t + k * (s - t)
        }
        guard let out = Gfx.context(w, h), let op = out.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let obpr = out.bytesPerRow
        for y in 0..<h {
            for x in 0..<w {
                let v = UInt8(min(255, max(0, (q[y * w + x] * 255).rounded())))
                let o = op + y * obpr + x * 4
                o[0] = v; o[1] = v; o[2] = v; o[3] = 255
            }
        }
        return out.makeImage()
    }

    /// He et al.'s guided filter on Float planes; box sums come from summed-area tables.
    static func guidedFilter(_ I: [Float], _ P: [Float], _ w: Int, _ h: Int, radius: Int, eps: Float) -> [Float] {
        let n = w * h
        var II = [Float](repeating: 0, count: n)
        var IP = [Float](repeating: 0, count: n)
        for i in 0..<n {
            II[i] = I[i] * I[i]
            IP[i] = I[i] * P[i]
        }
        let meanI = boxMean(I, w, h, radius)
        let meanP = boxMean(P, w, h, radius)
        let corrI = boxMean(II, w, h, radius)
        let corrIP = boxMean(IP, w, h, radius)
        var A = [Float](repeating: 0, count: n)
        var B = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let varI = corrI[i] - meanI[i] * meanI[i]
            let covIP = corrIP[i] - meanI[i] * meanP[i]
            let a = covIP / (varI + eps)
            A[i] = a
            B[i] = meanP[i] - a * meanI[i]
        }
        let meanA = boxMean(A, w, h, radius)
        let meanB = boxMean(B, w, h, radius)
        var q = [Float](repeating: 0, count: n)
        for i in 0..<n { q[i] = meanA[i] * I[i] + meanB[i] }
        return q
    }

    /// Mean over a (2r+1)² window clamped to the image, via a summed-area table.
    static func boxMean(_ src: [Float], _ w: Int, _ h: Int, _ r: Int) -> [Float] {
        let sw = w + 1
        var sat = [Double](repeating: 0, count: sw * (h + 1))
        src.withUnsafeBufferPointer { s in
            sat.withUnsafeMutableBufferPointer { t in
                for y in 0..<h {
                    var rowSum = 0.0
                    let row = y * w
                    let trow = (y + 1) * sw
                    let prow = y * sw
                    for x in 0..<w {
                        rowSum += Double(s[row + x])
                        t[trow + x + 1] = t[prow + x + 1] + rowSum
                    }
                }
            }
        }
        var out = [Float](repeating: 0, count: w * h)
        sat.withUnsafeBufferPointer { t in
            out.withUnsafeMutableBufferPointer { o in
                for y in 0..<h {
                    let y0 = max(0, y - r), y1 = min(h - 1, y + r)
                    let r0 = y0 * sw, r1 = (y1 + 1) * sw
                    let dy = Double(y1 - y0 + 1)
                    for x in 0..<w {
                        let x0 = max(0, x - r), x1 = min(w - 1, x + r)
                        let sum = t[r1 + x1 + 1] - t[r0 + x1 + 1] - t[r1 + x0] + t[r0 + x0]
                        o[y * w + x] = Float(sum / (dy * Double(x1 - x0 + 1)))
                    }
                }
            }
        }
        return out
    }

    // MARK: Internals

    private static func instanceLabels(in image: CGImage, people: Bool) -> Labels? {
        let request: VNImageBasedRequest = people ? VNGeneratePersonInstanceMaskRequest() : VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let obs = request.results?.first as? VNInstanceMaskObservation else { return nil }
            return readLabels(obs.instanceMask)
        } catch {
            return nil
        }
    }

    private static func readLabels(_ buffer: CVPixelBuffer) -> Labels? {
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent8 else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
        let bpr = CVPixelBufferGetBytesPerRow(buffer)
        let p = base.assumingMemoryBound(to: UInt8.self)
        var bytes = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w { bytes[y * w + x] = p[y * bpr + x] }
        }
        return Labels(w: w, h: h, bytes: bytes)
    }

    /// RGBA8 image with the label in every color channel, opaque.
    private static func labelImage(_ l: Labels) -> CGImage? {
        guard let ctx = Gfx.context(l.w, l.h), let p = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let bpr = ctx.bytesPerRow
        for y in 0..<l.h {
            for x in 0..<l.w {
                let v = l.bytes[y * l.w + x]
                let o = p + y * bpr + x * 4
                o[0] = v; o[1] = v; o[2] = v; o[3] = 255
            }
        }
        return ctx.makeImage()
    }

    /// A ≤ 96 px crop of the instance, transparent outside it.
    private static func thumbnail(of image: CGImage, instance: Int, bounds b: NRect, labels: Labels) -> CGImage? {
        let iw = Double(image.width), ih = Double(image.height)
        let crop = CGRect(x: (b.x * iw).rounded(.down), y: (b.y * ih).rounded(.down),
                          width: max(1, (b.w * iw).rounded(.up)), height: max(1, (b.h * ih).rounded(.up)))
            .intersection(CGRect(x: 0, y: 0, width: iw, height: ih))
        guard !crop.isNull, crop.width >= 1, crop.height >= 1 else { return nil }
        let scale = min(1, 96 / max(crop.width, crop.height))
        let tw = max(1, Int(crop.width * scale)), th = max(1, Int(crop.height * scale))
        guard let ctx = Gfx.context(tw, th) else { return nil }
        // The crop rect is top-left; the context is bottom-left.
        let dx = -crop.minX * scale, dyTop = -crop.minY * scale
        let dh = ih * scale
        ctx.draw(image, in: CGRect(x: dx, y: CGFloat(th) - dyTop - dh, width: iw * scale, height: dh))
        guard let p = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let bpr = ctx.bytesPerRow
        for y in 0..<th {
            let ny = (crop.minY + (Double(y) + 0.5) / scale) / ih
            for x in 0..<tw {
                let nx = (crop.minX + (Double(x) + 0.5) / scale) / iw
                if labels.at(nx, ny) != instance {
                    let o = p + y * bpr + x * 4
                    o[0] = 0; o[1] = 0; o[2] = 0; o[3] = 0
                }
            }
        }
        return ctx.makeImage()
    }
}
