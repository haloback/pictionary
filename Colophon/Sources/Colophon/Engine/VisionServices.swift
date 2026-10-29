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
}
