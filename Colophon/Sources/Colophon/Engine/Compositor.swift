import CoreGraphics
import CoreImage
import Foundation

/// Compositing operations the renderer can't get from CGContext alone: blends performed in
/// linear light, and the optical backing that keeps type readable on a busy photo.
enum Compositor {
    /// A context whose working space is gamma-encoded sRGB, so pixel values pass through
    /// unchanged and the linearization below is explicit (and happens exactly once).
    private static let gammaContext = CIContext(options: [
        .workingColorSpace: Gfx.sRGB,
        .outputColorSpace: Gfx.sRGB,
        .cacheIntermediates: false
    ])

    /// Blends `top` over `bottom` in linear light. Both images are canvas-sized and share the
    /// canvas' top-left pixel space; `rect` is the region (top-left canvas pixels) to compute.
    /// Returns an image of `rect`'s size, first row at the top, or nil when nothing overlaps.
    static func blendLinear(_ top: CGImage, over bottom: CGImage, mode: BlendMode, opacity: Double,
                            in rect: CGRect, canvas: CGSize) -> CGImage? {
        let canvasRect = CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height)
        let region = rect.integral.intersection(canvasRect)
        guard !region.isNull, region.width >= 1, region.height >= 1 else { return nil }
        // Core Image's origin is bottom-left; flip the region.
        let ciRect = CGRect(x: region.minX, y: canvas.height - region.maxY, width: region.width, height: region.height)

        let topCI = placed(top, canvas: canvas).cropped(to: ciRect)
        let bottomCI = placed(bottom, canvas: canvas).cropped(to: ciRect)
        let topLin = topCI.applyingFilter("CISRGBToneCurveToLinear")
        let bottomLin = bottomCI.applyingFilter("CISRGBToneCurveToLinear")
        let blended = FX.blend(topLin, over: bottomLin, mode: mode.ciFilterName)
        let mixed = FX.mix(bottomLin, blended, opacity.clamped01).cropped(to: ciRect)
        let out = mixed.applyingFilter("CILinearToSRGBToneCurve").cropped(to: ciRect)
        return gammaContext.createCGImage(out, from: ciRect, format: .RGBA8, colorSpace: Gfx.sRGB)
    }

    /// A CIImage of a canvas-space CGImage, stretched to the canvas if its size differs.
    private static func placed(_ img: CGImage, canvas: CGSize) -> CIImage {
        let ci = CIImage(cgImage: img)
        guard img.width != Int(canvas.width) || img.height != Int(canvas.height) else { return ci }
        let sx = canvas.width / CGFloat(max(1, img.width)), sy = canvas.height / CGFloat(max(1, img.height))
        return ci.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
    }

    /// The region under a text layer, measured on the rendered cover beneath it, and a
    /// soft-edged backing layer when the type would struggle there: a solid fill in the text
    /// color's opposite, faded as a soft oval, no stronger than 60% opacity. Nil when the
    /// ground is plain and the contrast is already 7:1 or better.
    static func autoContrastBacking(for text: Layer, background: CGImage, canvas: CGSize) -> Layer? {
        guard let t = text.textContent else { return nil }
        let stats = PixelSampler.stats(background, region: text.frame)
        let contrast = t.color.contrast(with: stats.mean)
        // 7:1 needs nothing; 1:1 needs everything. Busy grounds need a backing even at good mean contrast.
        let contrastNeed = ((7 - contrast) / 6).clamped01
        let busyNeed = ((stats.busyness - 0.08) / 0.2).clamped01
        let need = max(contrastNeed, busyNeed)
        let opacity = 0.6 * need
        guard opacity >= 0.06 else { return nil }

        let opposite = ColorAdvisor.opposite(t.color)
        let fillColor: RGBA
        if t.color.chroma < 0.15 {
            // Neutral type: a neutral backing reads cleaner than a tinted one.
            fillColor = t.color.luminance > 0.5 ? RGBA.nearBlack : RGBA.nearWhite
        } else {
            fillColor = opposite.withSaturation(min(opposite.hsl.s, 0.35))
        }

        // The oval fade eats the edges, so the backing extends past the text frame.
        let f = text.frame
        let x0 = (f.x - f.w * 0.2).clamped01, y0 = (f.y - f.h * 0.35).clamped01
        let x1 = (f.maxX + f.w * 0.2).clamped01, y1 = (f.maxY + f.h * 0.35).clamped01
        let frame = NRect(x0, y0, max(0.01, x1 - x0), max(0.01, y1 - y0))

        var backing = Layer.fill(.solid, colors: [fillColor], frame: frame)
        backing.name = "Backing"
        backing.fade = .vignette
        backing.fadeAmount = 0.85
        backing.opacity = opacity
        return backing
    }
}
