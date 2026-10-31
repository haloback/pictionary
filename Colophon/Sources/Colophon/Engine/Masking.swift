import CoreGraphics
import CoreImage

/// Layer masks: gradient fades and Blend If (computed per layer and cached), plus masks that
/// come from another layer: another photo's subject, or the layer below (clipping).
enum Masking {
    /// Gradient fade and tonal Blend If, in the layer's own space.
    static func applyLocal(_ m: LayerMask, to img: CGImage) -> CGImage? {
        let w = img.width, h = img.height
        let ext = CGRect(x: 0, y: 0, width: w, height: h)
        var mask: CIImage?

        if m.gradient != .none, let ctx = Gfx.context(w, h) {
            let show = m.invert ? RGBA.black : RGBA.white, hide = m.invert ? RGBA.white : RGBA.black
            let a = CGFloat(m.start.clamped01), b = CGFloat(max(m.start, m.end).clamped01)
            switch m.gradient {
            case .linear:
                Gfx.linearGradient(ctx, ext, [show, show, hide, hide], angle: m.angle, locations: [0, a, max(a + 0.001, b), 1])
            case .radial:
                ctx.setFillColor(hide.cgColor)
                ctx.fill(ext)
                if let g = CGGradient(colorsSpace: Gfx.sRGB, colors: [show.cgColor, show.cgColor, hide.cgColor] as CFArray,
                                      locations: [0, a, max(a + 0.001, b)]) {
                    let c = CGPoint(x: ext.midX, y: ext.midY)
                    ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: hypot(ext.width, ext.height) / 2,
                                           options: [.drawsAfterEndLocation])
                }
            case .none:
                break
            }
            mask = ctx.makeImage().map { CIImage(cgImage: $0) }
        }

        if m.keepDarks > 0 || m.keepLights > 0 {
            let lum = FX.mono(CIImage(cgImage: img))
            func ramp(_ slope: Double, _ bias: Double) -> CIImage {
                FX.matrix(lum, r: (slope, 0, 0), g: (slope, 0, 0), b: (slope, 0, 0), bias: (bias, bias, bias))
                    .applyingFilter("CIColorClamp", parameters: [
                        "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 1), "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                    ])
            }
            // Keep darks: fully visible below (1 - k - 0.2), gone at (1 - k). Keep lights mirrors it.
            if m.keepDarks > 0 {
                let r = ramp(-5, 5 * (1 - m.keepDarks))
                mask = mask.map { r.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: $0]) } ?? r
            }
            if m.keepLights > 0 {
                let r = ramp(5, -5 * m.keepLights + 1)
                mask = mask.map { r.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: $0]) } ?? r
            }
        }

        if let tid = m.textureID, MaterialLibrary.shared.material(tid) != nil, m.textureAmount > 0 {
            var tex = FX.mono(MaterialLibrary.shared.render(tid, extent: ext, palette: [.black, .white], seed: 3))
            if m.textureInvert { tex = tex.applyingFilter("CIColorInvert") }
            // Amount lifts the texture toward white: 0 leaves the layer whole, 1 applies it fully.
            tex = FX.mix(FX.solid(.white, ext), tex, m.textureAmount.clamped01).cropped(to: ext)
            mask = mask.map { tex.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: $0]) } ?? tex
        }

        guard let mask else { return nil }
        let out = CIImage(cgImage: img).applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: mask.cropped(to: ext)
        ])
        return Gfx.render(out, extent: ext)
    }

    /// Keeps the part of `r` that overlaps the pixels of `other` (both placed in canvas space),
    /// or the part outside them when inverted.
    static func mask(_ r: LayerRaster, by other: LayerRaster, invert: Bool) -> CGImage? {
        let w = r.image.width, h = r.image.height
        guard let ctx = Gfx.context(w, h) else { return nil }
        let dx = other.rect.minX - r.rect.minX
        let dyTop = other.rect.minY - r.rect.minY
        ctx.draw(other.image, in: CGRect(x: dx, y: CGFloat(h) - dyTop - other.rect.height, width: other.rect.width, height: other.rect.height))
        guard let placed = ctx.makeImage() else { return nil }
        let ext = CGRect(x: 0, y: 0, width: w, height: h)
        let out = CIImage(cgImage: r.image).applyingFilter(invert ? "CISourceOutCompositing" : "CISourceInCompositing", parameters: [
            kCIInputBackgroundImageKey: CIImage(cgImage: placed)
        ])
        return Gfx.render(out, extent: ext)
    }
}
