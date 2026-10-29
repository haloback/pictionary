import CoreImage
import Foundation

/// Context handed to every effect so results scale with the canvas (preview and export match).
struct EffectContext {
    /// Pixels per 1000 canvas pixels.
    var scale: CGFloat
    var seed: Int
}

/// Core Image building blocks used by the effect library and generators.
enum FX {
    private static var gradientCache: [String: CIImage] = [:]
    private static let lock = NSLock()

    static func center(_ i: CIImage) -> CIVector { CIVector(x: i.extent.midX, y: i.extent.midY) }

    static func mono(_ i: CIImage) -> CIImage {
        i.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
    }

    static func controls(_ i: CIImage, saturation: Double = 1, brightness: Double = 0, contrast: Double = 1) -> CIImage {
        i.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: saturation, kCIInputBrightnessKey: brightness, kCIInputContrastKey: contrast
        ])
    }

    static func matrix(_ i: CIImage, r: (Double, Double, Double), g: (Double, Double, Double), b: (Double, Double, Double),
                       bias: (Double, Double, Double) = (0, 0, 0)) -> CIImage {
        i.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: r.0, y: r.1, z: r.2, w: 0),
            "inputGVector": CIVector(x: g.0, y: g.1, z: g.2, w: 0),
            "inputBVector": CIVector(x: b.0, y: b.1, z: b.2, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: bias.0, y: bias.1, z: bias.2, w: 0)
        ])
    }

    static func curve(_ i: CIImage, _ p: [(Double, Double)]) -> CIImage {
        var params: [String: Any] = [:]
        for (n, pt) in p.prefix(5).enumerated() { params["inputPoint\(n)"] = CIVector(x: pt.0, y: pt.1) }
        return i.applyingFilter("CIToneCurve", parameters: params)
    }

    static func blur(_ i: CIImage, _ r: CGFloat) -> CIImage {
        guard r > 0.05 else { return i }
        return i.clampedToExtent().applyingGaussianBlur(sigma: Double(r)).cropped(to: i.extent)
    }

    static func blend(_ top: CIImage, over base: CIImage, mode: String) -> CIImage {
        top.applyingFilter(mode, parameters: [kCIInputBackgroundImageKey: base]).cropped(to: base.extent)
    }

    /// t = 0 returns a, t = 1 returns b.
    static func mix(_ a: CIImage, _ b: CIImage, _ t: Double) -> CIImage {
        if t >= 0.999 { return b }
        if t <= 0.001 { return a }
        return a.applyingFilter("CIDissolveTransition", parameters: [kCIInputTargetImageKey: b, kCIInputTimeKey: t])
    }

    static func solid(_ c: RGBA, _ extent: CGRect) -> CIImage {
        CIImage(color: c.ciColor).cropped(to: extent)
    }

    static func radial(center: CGPoint, r0: CGFloat, r1: CGFloat, c0: RGBA, c1: RGBA, extent: CGRect) -> CIImage {
        guard let f = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(cgPoint: center), "inputRadius0": r0, "inputRadius1": r1,
            "inputColor0": c0.ciColor, "inputColor1": c1.ciColor
        ]), let out = f.outputImage else { return CIImage.empty() }
        return out.cropped(to: extent)
    }

    static func linear(_ p0: CGPoint, _ p1: CGPoint, _ c0: RGBA, _ c1: RGBA, extent: CGRect) -> CIImage {
        guard let f = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(cgPoint: p0), "inputPoint1": CIVector(cgPoint: p1),
            "inputColor0": c0.ciColor, "inputColor1": c1.ciColor
        ]), let out = f.outputImage else { return CIImage.empty() }
        return out.cropped(to: extent)
    }

    /// A 256x1 lookup strip for CIColorMap.
    static func gradientImage(_ stops: [RGBA]) -> CIImage {
        let key = stops.map(\.hex).joined(separator: "-")
        lock.lock()
        if let c = gradientCache[key] { lock.unlock(); return c }
        lock.unlock()
        let cols = stops.count == 1 ? [stops[0], stops[0]] : stops
        guard let ctx = Gfx.context(256, 1),
              let g = CGGradient(colorsSpace: Gfx.sRGB, colors: cols.map(\.cgColor) as CFArray, locations: nil) else {
            return CIImage.empty()
        }
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 256, y: 0), options: [])
        guard let cg = ctx.makeImage() else { return CIImage.empty() }
        let img = CIImage(cgImage: cg)
        lock.lock(); gradientCache[key] = img; lock.unlock()
        return img
    }

    /// Maps the image's tones onto a gradient (duotones, tritones, smoke coloring).
    static func gradientMap(_ i: CIImage, _ stops: [RGBA], contrast: Double = 1) -> CIImage {
        var m = mono(i)
        if contrast != 1 { m = controls(m, contrast: contrast) }
        // Lift into perceptual space so mid-grays land mid-gradient.
        m = m.applyingFilter("CIGammaAdjust", parameters: ["inputPower": 0.4545])
        return m.applyingFilter("CIColorMap", parameters: ["inputGradientImage": gradientImage(stops)]).cropped(to: i.extent)
    }

    static func noise(_ extent: CGRect, seed: Int, grainSize: CGFloat, strength: Double) -> CIImage {
        guard let base = CIFilter(name: "CIRandomGenerator")?.outputImage else { return CIImage.empty() }
        let off = CGFloat((seed &* 7919) % 4000)
        var n = base.transformed(by: CGAffineTransform(translationX: off, y: off))
        if grainSize > 1.05 { n = n.transformed(by: CGAffineTransform(scaleX: grainSize, y: grainSize)) }
        let k = strength
        n = n.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: k, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: k, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: k, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0.5 - k / 2, y: 0.5 - k / 2, z: 0.5 - k / 2, w: 1)
        ])
        return n.cropped(to: extent)
    }

    static func grain(_ i: CIImage, seed: Int, strength: Double, size: CGFloat) -> CIImage {
        blend(noise(i.extent, seed: seed, grainSize: size, strength: strength), over: i, mode: "CIOverlayBlendMode")
    }

    static func vignette(_ i: CIImage, intensity: Double, radiusFactor: CGFloat = 0.75) -> CIImage {
        let r = max(i.extent.width, i.extent.height) * radiusFactor
        return i.applyingFilter("CIVignetteEffect", parameters: [
            "inputCenter": center(i), "inputRadius": r, "inputIntensity": intensity
        ]).cropped(to: i.extent)
    }

    static func tint(_ i: CIImage, _ c: RGBA, intensity: Double) -> CIImage {
        i.applyingFilter("CIColorMonochrome", parameters: ["inputColor": c.ciColor, "inputIntensity": intensity])
    }

    /// Split toning: tint shadows and highlights separately, blended softly over the original.
    static func splitTone(_ i: CIImage, shadows: RGBA, highlights: RGBA) -> CIImage {
        let map = gradientMap(i, [shadows.withLightness(min(shadows.hsl.l, 0.18)), RGBA(0.5, 0.5, 0.5), highlights.withLightness(max(highlights.hsl.l, 0.78))])
        return blend(map, over: i, mode: "CISoftLightBlendMode")
    }

    static func bloom(_ i: CIImage, radius: CGFloat, intensity: Double) -> CIImage {
        i.clampedToExtent().applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: radius, kCIInputIntensityKey: intensity]).cropped(to: i.extent)
    }

    static func displace(_ i: CIImage, by map: CIImage, scale: CGFloat) -> CIImage {
        i.clampedToExtent().applyingFilter("CIDisplacementDistortion", parameters: [
            "inputDisplacementImage": map, kCIInputScaleKey: scale
        ]).cropped(to: i.extent)
    }

    static func smoothNoise(_ extent: CGRect, seed: Int, cells: Int = 6) -> CIImage {
        guard let cg = Gfx.valueNoise(max(8, Int(extent.width / 4)), max(8, Int(extent.height / 4)), cells: cells, seed: seed) else {
            return solid(RGBA(0.5, 0.5, 0.5), extent)
        }
        let img = CIImage(cgImage: cg)
        return img.transformed(by: CGAffineTransform(scaleX: extent.width / img.extent.width, y: extent.height / img.extent.height))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
            .cropped(to: extent)
    }
}
