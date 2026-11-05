import CoreImage
import Vision

/// Subject lifting and attention analysis via the Vision framework.
enum VisionServices {
    /// A mask (subject in the red channel) for the most prominent foreground objects.
    static func foregroundMask(for image: CGImage) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let obs = request.results?.first else { return nil }
            let buffer = try obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler)
            // Spread the single mask channel into gray so every consumer reads the same value.
            let ci = FX.matrix(CIImage(cvPixelBuffer: buffer), r: (1, 0, 0), g: (1, 0, 0), b: (1, 0, 0))
            return Gfx.ci.createCGImage(ci, from: ci.extent, format: .RGBA8, colorSpace: Gfx.sRGB)
        } catch {
            return nil
        }
    }

    /// When Vision finds no clear subject, fall back to a soft oval around the salient area.
    static func fallbackMask(for image: CGImage, focus: NRect) -> CGImage? {
        let w = image.width, h = image.height
        guard let ctx = Gfx.context(w, h) else { return nil }
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let rect = CGRect(x: focus.x * Double(w), y: (1 - focus.maxY) * Double(h),
                          width: focus.w * Double(w), height: focus.h * Double(h)).insetBy(dx: -Double(w) * 0.05, dy: -Double(h) * 0.05)
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fillEllipse(in: rect)
        guard let hard = ctx.makeImage() else { return nil }
        return Gfx.render(FX.blur(CIImage(cgImage: hard), CGFloat(min(w, h)) * 0.05), w, h)
    }

    static func applyMask(_ mask: CGImage, to image: CGImage, invert: Bool) -> CGImage? {
        let src = CIImage(cgImage: image)
        var m = CIImage(cgImage: mask)
        m = m.transformed(by: CGAffineTransform(scaleX: src.extent.width / m.extent.width,
                                                y: src.extent.height / m.extent.height))
        if invert { m = m.applyingFilter("CIColorInvert") }
        let out = src.applyingFilter("CIBlendWithRedMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: m
        ])
        return Gfx.render(out, extent: src.extent)
    }

    /// Where eyes go first: Vision's attention map as a heat image (transparent where nothing draws the eye,
    /// warm where it does), plus the normalized map itself (row-major, top-left) for measurements.
    static func attention(for image: CGImage) -> (heat: CGImage, map: [Float], width: Int, height: Int)? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let obs = request.results?.first else { return nil }
            let pb = obs.pixelBuffer
            CVPixelBufferLockBaseAddress(pb, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
            let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
            let stride = CVPixelBufferGetBytesPerRow(pb) / MemoryLayout<Float>.size
            guard let base = CVPixelBufferGetBaseAddress(pb)?.assumingMemoryBound(to: Float.self) else { return nil }
            var map = [Float](repeating: 0, count: w * h)
            var peak: Float = 1e-6
            for y in 0..<h { for x in 0..<w { let v = base[y * stride + x]; map[y * w + x] = v; peak = max(peak, v) } }
            for i in map.indices { map[i] /= peak }
            var rgba = [UInt8](repeating: 0, count: w * h * 4)
            for i in 0..<(w * h) {
                let v = map[i]
                // Cool to warm: faint blue, then orange, then yellow-white at the peak.
                let r = min(1, v * 1.6), g = max(0, v - 0.35) * 1.4, b = max(0, 0.5 - v) * 0.9
                let a = v * v * 0.9
                rgba[i * 4] = UInt8(min(255, r * 255)); rgba[i * 4 + 1] = UInt8(min(255, g * 255))
                rgba[i * 4 + 2] = UInt8(min(255, b * 255)); rgba[i * 4 + 3] = UInt8(min(255, a * 255))
            }
            guard let provider = CGDataProvider(data: Data(rgba) as CFData),
                  let heat = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: Gfx.sRGB,
                                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                                     decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
            return (heat, map, w, h)
        } catch {
            return nil
        }
    }

    /// Union of salient objects, normalized with a top-left origin.
    static func saliency(for image: CGImage) -> NRect? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let obs = request.results?.first, let objects = obs.salientObjects, !objects.isEmpty else { return nil }
            var u = objects[0].boundingBox
            for o in objects.dropFirst() { u = u.union(o.boundingBox) }
            return NRect(Double(u.minX), Double(1 - u.maxY), Double(u.width), Double(u.height))
        } catch {
            return nil
        }
    }

    /// Face rectangles, normalized with a top-left origin, largest first.
    static func faces(for image: CGImage) -> [NRect] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let results = request.results else { return [] }
            let rects = results.map { obs -> NRect in
                let b = obs.boundingBox
                return NRect(Double(b.minX), Double(1 - b.maxY), Double(b.width), Double(b.height))
            }
            return rects.sorted { $0.area > $1.area }
        } catch {
            return []
        }
    }
}
