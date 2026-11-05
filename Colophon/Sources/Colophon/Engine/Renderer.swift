import CoreGraphics
import CoreImage
import Foundation

struct LayerRaster {
    var image: CGImage
    /// Where the raster lands, in top-left canvas pixels (may extend past the frame for glows).
    var rect: CGRect
}

/// Composites a CoverDocument into pixels. Thread-safe; layer rasters are cached so moving
/// a layer only re-composites.
final class CoverRenderer {
    static let shared = CoverRenderer()

    enum Quality: Int {
        case preview, full
        var assetResolution: AssetStore.Resolution { self == .full ? .full : .preview }
    }

    private struct RasterKey: Hashable {
        var content: LayerContent
        var w: Int
        var h: Int
        var canvasW: Int
        var canvasH: Int
        var effects: [EffectInstance]
        var adjust: Adjustments
        var mask: LayerMask
        var clip: ShapeKind?
        var fade: FadeEdge
        var fadeAmount: Double
        var quality: Int
        var cutout: Cutout?
        var gradientMap: [RGBA]?
        var feather: Double
        var innerShadow: ShadowStyle?
    }

    private var cache: [RasterKey: LayerRaster] = [:]
    private var cacheOrder: [RasterKey] = []
    private let lock = NSLock()

    func render(_ doc: CoverDocument, size: CGSize, quality: Quality = .preview, excluding: Set<UUID> = []) -> CGImage? {
        let W = max(1, Int(size.width.rounded())), H = max(1, Int(size.height.rounded()))
        guard let ctx = Gfx.context(W, H) else { return nil }
        let canvas = CGSize(width: W, height: H)
        ctx.setFillColor(doc.background.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        // Work in a top-left space from here on.
        ctx.translateBy(x: 0, y: CGFloat(H))
        ctx.scaleBy(x: 1, y: -1)

        var below: LayerRaster?
        for (i, layer) in doc.layers.enumerated() where layer.isVisible && !excluding.contains(layer.id) {
            guard var r = rasterize(layer, doc: doc, canvas: canvas, quality: quality) else { continue }
            // Masks that depend on other layers: another photo's subject, or the layer below.
            if let sid = layer.mask.subjectOf, sid != layer.id, let source = doc.layer(sid), source.imageContent != nil,
               let sr = rasterize(source, doc: doc, canvas: canvas, quality: quality, cutoutOverride: .subject),
               let masked = Masking.mask(r, by: sr, invert: layer.mask.invertSubject) {
                r.image = masked
            }
            if layer.clipToBelow, let b = below, let clipped = Masking.mask(r, by: b, invert: false) {
                r.image = clipped
            }
            let ownRaster = r
            // Scene passes read what is already on the cover under the type.
            if let t = layer.textContent, t.style.needsScene, let soFar = ctx.makeImage(),
               let patch = backgroundPatch(soFar, rect: r.rect, width: r.image.width, height: r.image.height) {
                let size = TextRenderer.resolvedSize(t, box: layer.frame.pixels(in: canvas).size, canvasHeight: canvas.height)
                if let blended = TextStyler.blendIntoScene(r.image, background: patch, style: t.style, fontSize: size) {
                    r.image = blended
                }
            }
            if layer.knockout {
                // Punch the layer's shape out of the canvas; the background returns underneath at the end.
                composite(r, layer: layer, in: ctx, canvas: canvas, blendOverride: .destinationOut)
            } else if layer.linearBlend, layer.blend != .normal, let soFar = ctx.makeImage() {
                compositeLinear(r, layer: layer, below: soFar, in: ctx, canvas: canvas)
            } else {
                composite(r, layer: layer, in: ctx, canvas: canvas)
            }
            // A clipped layer clips to the same base as the layer it sits on.
            if !layer.clipToBelow { below = ownRaster }

            // Type behind the subject: draw the nearest photo's lifted subject back over the text.
            if let t = layer.textContent, t.behindSubject,
               let j = doc.layers[..<i].lastIndex(where: { $0.isVisible && $0.imageContent?.cutout == Cutout.none }) {
                let photo = doc.layers[j]
                if let sr = rasterize(photo, doc: doc, canvas: canvas, quality: quality, cutoutOverride: .subject) {
                    var subjectLayer = photo
                    subjectLayer.blend = .normal
                    composite(sr, layer: subjectLayer, in: ctx, canvas: canvas)
                }
            }
        }
        // Knockouts leave holes; the background shows through them and the export stays opaque.
        ctx.saveGState()
        ctx.setBlendMode(.destinationOver)
        ctx.setFillColor(doc.background.withAlpha(1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.restoreGState()
        return ctx.makeImage()
    }

    /// Blends a layer in linear light: the layer (with its rotation and drop shadow) is drawn
    /// alone onto a transparent canvas, blended over the snapshot of the cover so far in
    /// `Compositor`, and the result copied back over the region it touched.
    private func compositeLinear(_ r: LayerRaster, layer: Layer, below: CGImage, in ctx: CGContext, canvas: CGSize) {
        let W = Int(canvas.width), H = Int(canvas.height)
        guard let top = Gfx.context(W, H) else {
            composite(r, layer: layer, in: ctx, canvas: canvas)
            return
        }
        top.translateBy(x: 0, y: CGFloat(H))
        top.scaleBy(x: 1, y: -1)
        var plain = layer
        plain.opacity = 1
        plain.blend = .normal
        composite(r, layer: plain, in: top, canvas: canvas)
        let canvasRect = CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height)
        // Rotation and shadows spill past the raster's rect; compute the whole canvas then.
        let region = (layer.rotation != 0 || layer.shadow != nil) ? canvasRect : r.rect.integral.intersection(canvasRect)
        guard let topImage = top.makeImage(),
              let blended = Compositor.blendLinear(topImage, over: below, mode: layer.blend, opacity: layer.opacity.clamped01,
                                                   in: region, canvas: canvas) else {
            composite(r, layer: layer, in: ctx, canvas: canvas)
            return
        }
        let target = region.integral.intersection(canvasRect)
        ctx.saveGState()
        ctx.setBlendMode(.copy)
        Gfx.drawUpright(blended, in: target, ctx)
        ctx.restoreGState()
    }

    /// The part of the cover under a raster, padded with transparency where it runs off the edge.
    private func backgroundPatch(_ full: CGImage, rect: CGRect, width: Int, height: Int) -> CGImage? {
        let canvasRect = CGRect(x: 0, y: 0, width: full.width, height: full.height)
        let inter = rect.integral.intersection(canvasRect)
        guard !inter.isNull, inter.width >= 1, inter.height >= 1, let crop = full.cropping(to: inter),
              let ctx = Gfx.context(width, height) else { return nil }
        let x = inter.minX - rect.minX
        let yTop = inter.minY - rect.minY
        ctx.draw(crop, in: CGRect(x: x, y: CGFloat(height) - yTop - inter.height, width: inter.width, height: inter.height))
        return ctx.makeImage()
    }

    private func composite(_ r: LayerRaster, layer: Layer, in ctx: CGContext, canvas: CGSize, blendOverride: CGBlendMode? = nil) {
        ctx.saveGState()
        ctx.setAlpha(CGFloat(layer.opacity.clamped01))
        ctx.setBlendMode(blendOverride ?? layer.blend.cg)
        // A knockout erases; its drop shadow would only erase more.
        if let s = layer.shadow, blendOverride == nil {
            ctx.setShadow(offset: CGSize(width: s.dx * canvas.height, height: -s.dy * canvas.height),
                          blur: s.radius * canvas.height, color: s.color.cgColor)
        }
        if layer.rotation != 0 {
            let fr = layer.frame.pixels(in: canvas)
            ctx.translateBy(x: fr.midX, y: fr.midY)
            ctx.rotate(by: CGFloat(layer.rotation) * .pi / 180)
            ctx.translateBy(x: -fr.midX, y: -fr.midY)
        }
        Gfx.drawUpright(r.image, in: r.rect, ctx)
        ctx.restoreGState()
    }

    func rasterize(_ layer: Layer, doc: CoverDocument, canvas: CGSize, quality: Quality, cutoutOverride: Cutout? = nil) -> LayerRaster? {
        let frame = layer.frame.pixels(in: canvas)
        let w = max(1, Int(frame.width.rounded())), h = max(1, Int(frame.height.rounded()))
        let key = RasterKey(content: layer.content, w: w, h: h, canvasW: Int(canvas.width), canvasH: Int(canvas.height),
                            effects: layer.effects, adjust: layer.adjust, mask: layer.mask, clip: layer.clipShape, fade: layer.fade, fadeAmount: layer.fadeAmount,
                            quality: quality.rawValue, cutout: cutoutOverride,
                            gradientMap: layer.gradientMap, feather: layer.feather, innerShadow: layer.innerShadow)
        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            // Cached rasters are position-independent; re-anchor to the current frame.
            let pad = (hit.rect.width - CGFloat(w)) / 2
            return LayerRaster(image: hit.image, rect: CGRect(x: frame.minX - pad, y: frame.minY - pad, width: hit.rect.width, height: hit.rect.height))
        }
        lock.unlock()

        var pad: CGFloat = 0
        var image: CGImage?
        switch layer.content {
        case .image(let ic):
            image = renderImage(ic, doc: doc, w: w, h: h, quality: quality, cutout: cutoutOverride ?? ic.cutout)
        case .fill(let f):
            image = Generators.render(f, size: CGSize(width: w, height: h))
        case .shape(let s):
            image = ShapeRenderer.render(s, size: CGSize(width: w, height: h), canvasWidth: canvas.width)
        case .paint(let p):
            image = PaintEngine.shared.render(p, size: CGSize(width: w, height: h), layerID: layer.id, doc: doc)
        case .decor(let x):
            image = DecorLibrary.shared.render(x, size: CGSize(width: w, height: h), canvasHeight: canvas.height)
        case .text(let t):
            if case let (img, p)? = TextRenderer.render(t, box: CGSize(width: w, height: h), canvasHeight: canvas.height) {
                image = img
                pad = p
            }
        }
        guard var img = image else { return nil }

        if !layer.adjust.isIdentity {
            img = applyAdjustments(layer.adjust, to: img, canvas: canvas) ?? img
        }
        if !layer.effects.isEmpty {
            img = applyEffects(layer.effects, to: img, canvas: canvas, seed: Int(layer.id.uuid.0) << 8 | Int(layer.id.uuid.1), palette: doc.palette) ?? img
        }
        if let stops = layer.gradientMap, !stops.isEmpty {
            img = gradientMapImage(img, stops: stops) ?? img
        }
        if let clip = layer.clipShape {
            img = clipImage(img, to: clip, pad: pad) ?? img
        }
        if layer.fade != .none {
            img = fadeImage(img, edge: layer.fade, amount: layer.fadeAmount) ?? img
        }
        if layer.mask.gradient != .none || layer.mask.keepDarks > 0 || layer.mask.keepLights > 0 || layer.mask.textureID != nil {
            img = Masking.applyLocal(layer.mask, to: img) ?? img
        }
        if layer.feather > 0 {
            img = featherImage(img, amount: layer.feather) ?? img
        }
        if let s = layer.innerShadow {
            img = innerShadowImage(img, style: s, canvas: canvas) ?? img
        }

        let raster = LayerRaster(image: img, rect: CGRect(x: frame.minX - pad, y: frame.minY - pad,
                                                          width: CGFloat(img.width), height: CGFloat(img.height)))
        lock.lock()
        cache[key] = raster
        cacheOrder.append(key)
        if cacheOrder.count > 96 {
            let drop = cacheOrder.removeFirst()
            if !cacheOrder.contains(drop) { cache[drop] = nil }
        }
        lock.unlock()
        return raster
    }

    private func renderImage(_ ic: ImageContent, doc: CoverDocument, w: Int, h: Int, quality: Quality, cutout: Cutout) -> CGImage? {
        let data = doc.assetData(ic.assetID)
        guard var src = AssetStore.shared.cutout(ic.assetID, data: data, mode: cutout, resolution: quality.assetResolution),
              let ctx = Gfx.context(w, h) else { return nil }
        if !ic.maskEdits.isEmpty,
           let full = AssetStore.shared.image(ic.assetID, data: data, resolution: quality.assetResolution),
           let edited = MaskPainter.apply(ic.maskEdits, to: full,
                                          base: cutout == .none ? nil : AssetStore.shared.mask(ic.assetID, data: data),
                                          invertBase: cutout == .background) {
            src = edited
        }
        let iw = CGFloat(src.width), ih = CGFloat(src.height)
        let W = CGFloat(w), H = CGFloat(h)
        let s = max(W / iw, H / ih) * CGFloat(max(1, ic.zoom))
        let dw = iw * s, dh = ih * s
        let ox = -(dw - W) * CGFloat(ic.focusX.clamped01)
        let oyTop = -(dh - H) * CGFloat(ic.focusY.clamped01)
        let y = H - (oyTop + dh)
        if ic.flipped {
            ctx.translateBy(x: W, y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }
        ctx.draw(src, in: CGRect(x: ox, y: y, width: dw, height: dh))
        return ctx.makeImage()
    }

    private func applyEffects(_ effects: [EffectInstance], to img: CGImage, canvas: CGSize, seed: Int, palette: [RGBA]) -> CGImage? {
        let original = CIImage(cgImage: img)
        var ci = original
        let ec = EffectContext(scale: canvas.height / 1000, seed: seed, palette: palette)
        for e in effects {
            guard let p = EffectLibrary.shared.preset(e.presetID) else { continue }
            let processed = p.apply(ci, ec).cropped(to: original.extent)
            ci = FX.mix(ci, processed, e.amount.clamped01)
        }
        // Keep the layer's own transparency (cutouts, text).
        ci = ci.cropped(to: original.extent).applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: original])
        return Gfx.render(ci, extent: original.extent)
    }

    private func applyAdjustments(_ a: Adjustments, to img: CGImage, canvas: CGSize) -> CGImage? {
        let original = CIImage(cgImage: img)
        var ci = original
        let scale = canvas.height / 1000
        if a.exposure != 0 { ci = ci.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: a.exposure * 1.5]) }
        // Lift / gamma / gain work on gamma-encoded values so "shadows" and "highlights" mean what they say.
        if a.lift != 0 || a.gamma != 0 || a.gain != 0 {
            var t = FX.toPerceptual(ci)
            let lift = (a.lift * 0.3).clamped(-0.3, 0.3)
            let gainScale = 1 + (a.gain * 0.3).clamped(-0.3, 0.3)
            if lift != 0 || gainScale != 1 {
                // out = lift + (1 - lift) * gain * in: lift raises the blacks, gain scales the whites.
                let a1 = (1 - lift) * gainScale
                t = t.applyingFilter("CIColorPolynomial", parameters: [
                    "inputRedCoefficients": CIVector(x: lift, y: a1, z: 0, w: 0),
                    "inputGreenCoefficients": CIVector(x: lift, y: a1, z: 0, w: 0),
                    "inputBlueCoefficients": CIVector(x: lift, y: a1, z: 0, w: 0),
                    "inputAlphaCoefficients": CIVector(x: 0, y: 1, z: 0, w: 0)
                ])
            }
            if a.gamma != 0 {
                t = t.applyingFilter("CIGammaAdjust", parameters: ["inputPower": pow(2, -a.gamma.clamped(-1, 1))])
            }
            ci = FX.fromPerceptual(t)
        }
        if a.saturation != 0 { ci = FX.controls(ci, saturation: 1 + a.saturation) }
        if a.contrast != 0 {
            // Contrast pivots at mid-gray only on gamma-encoded values; in linear light it crushes the shadows.
            ci = FX.fromPerceptual(FX.controls(FX.toPerceptual(ci), contrast: 1 + a.contrast * 0.6))
        }
        if a.vibrance != 0 {
            ci = ci.applyingFilter("CIVibrance", parameters: ["inputAmount": a.vibrance.clamped(-1, 1)])
        }
        if a.warmth != 0 {
            let w = a.warmth * 0.12
            ci = FX.matrix(ci, r: (1 + w, 0, 0), g: (0, 1 + w * 0.2, 0), b: (0, 0, 1 - w))
        }
        if (a.shadowTint != nil || a.highlightTint != nil) && a.tintAmount > 0 {
            ci = splitTone(ci, shadows: a.shadowTint, highlights: a.highlightTint, amount: a.tintAmount.clamped01)
        }
        if a.fade > 0 {
            // Matte look: the blacks come up to a soft gray while the whites stay put.
            let f = a.fade.clamped01 * 0.2
            let t = FX.toPerceptual(ci).applyingFilter("CIColorPolynomial", parameters: [
                "inputRedCoefficients": CIVector(x: f, y: 1 - f, z: 0, w: 0),
                "inputGreenCoefficients": CIVector(x: f, y: 1 - f, z: 0, w: 0),
                "inputBlueCoefficients": CIVector(x: f, y: 1 - f, z: 0, w: 0),
                "inputAlphaCoefficients": CIVector(x: 0, y: 1, z: 0, w: 0)
            ])
            ci = FX.fromPerceptual(t)
        }
        if a.sharpness > 0 {
            ci = ci.applyingFilter("CISharpenLuminance", parameters: ["inputSharpness": a.sharpness * 1.5])
        } else if a.sharpness < 0 {
            ci = FX.blur(ci, CGFloat(-a.sharpness) * 2 * scale)
        }
        if a.blur > 0 { ci = FX.blur(ci, CGFloat(a.blur) * 30 * scale) }
        if a.grain > 0 {
            let size = max(1, 1.4 * scale)
            ci = FX.grain(ci, seed: 23, strength: a.grain.clamped01 * 0.18, size: size)
        }
        if a.vignette > 0 {
            ci = FX.vignette(ci, intensity: a.vignette.clamped01 * 1.4, radiusFactor: 0.8)
        }
        ci = ci.cropped(to: original.extent).applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: original])
        return Gfx.render(ci, extent: original.extent)
    }

    /// Multiplies a color into the darks and screens another into the lights, each through a luminance mask.
    private func splitTone(_ ci: CIImage, shadows: RGBA?, highlights: RGBA?, amount: Double) -> CIImage {
        let extent = ci.extent
        // Perceptual luminance so mid-gray lands mid-mask.
        let lum = FX.toPerceptual(FX.mono(ci)).settingAlphaOne(in: extent)
        var out = ci
        // The tints lend their hue and saturation (Color blend keeps the photo's own luminance), so
        // shadows turn teal or plum without filling in and highlights warm up without blowing out.
        if let s = shadows {
            let shadowMask = FX.matrix(lum, r: (-amount, 0, 0), g: (0, -amount, 0), b: (0, 0, -amount), bias: (amount, amount, amount))
            let tinted = FX.blend(FX.solid(s, extent), over: ci, mode: "CIColorBlendMode")
            out = FX.blendWithMask(tinted, over: out, mask: shadowMask)
        }
        if let h = highlights {
            let highlightMask = FX.matrix(lum, r: (amount, 0, 0), g: (0, amount, 0), b: (0, 0, amount))
            let tinted = FX.blend(FX.solid(h, extent), over: out, mode: "CIColorBlendMode")
            out = FX.blendWithMask(tinted, over: out, mask: highlightMask)
        }
        return out.cropped(to: extent)
    }

    /// Maps the layer's luminance onto `stops` (dark to light), keeping its transparency.
    private func gradientMapImage(_ img: CGImage, stops: [RGBA]) -> CGImage? {
        let original = CIImage(cgImage: img)
        let cols = Array(stops.prefix(4))
        var ci = FX.gradientMap(original, cols.count == 1 ? [cols[0], cols[0]] : cols)
        ci = ci.cropped(to: original.extent).applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: original])
        return Gfx.render(ci, extent: original.extent)
    }

    /// Softens the alpha edge: the alpha is blurred (without clamping, so the raster's own
    /// border softens too) and intersected with the original so nothing spreads outward.
    private func featherImage(_ img: CGImage, amount: Double) -> CGImage? {
        let original = CIImage(cgImage: img)
        let ext = original.extent
        let sigma = Double(amount.clamped01) * Double(min(ext.width, ext.height)) * 0.08
        guard sigma > 0.05 else { return nil }
        let soft = original.applyingGaussianBlur(sigma: sigma).cropped(to: ext)
        let out = original.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: soft
        ])
        return Gfx.render(out, extent: ext)
    }

    /// Inner shadow: the inverted alpha is offset and blurred, kept only where the layer is
    /// opaque, and that region is darkened with the shadow color.
    private func innerShadowImage(_ img: CGImage, style s: ShadowStyle, canvas: CGSize) -> CGImage? {
        let original = CIImage(cgImage: img)
        let ext = original.extent
        let blur = CGFloat(s.radius) * canvas.height
        let dx = CGFloat(s.dx) * canvas.height
        // Core Image's y runs up; a positive dy in the model runs down.
        let dy = -CGFloat(s.dy) * canvas.height
        let pad = blur * 3 + abs(dx) + abs(dy) + 2
        // Outside the raster counts as outside the shape, so edges of full-frame layers shade too.
        let big = ext.insetBy(dx: -pad, dy: -pad)
        var inverted = FX.solid(.white, big).applyingFilter("CISourceOutCompositing", parameters: [kCIInputBackgroundImageKey: original])
        inverted = inverted.transformed(by: CGAffineTransform(translationX: dx, y: dy))
        if blur > 0.05 { inverted = inverted.applyingGaussianBlur(sigma: Double(blur)) }
        let shadowMask = inverted.cropped(to: ext).applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: original])
        let shadow = FX.solid(s.color, ext).applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: shadowMask
        ])
        let out = shadow.applyingFilter("CISourceOverCompositing", parameters: [kCIInputBackgroundImageKey: original]).cropped(to: ext)
        return Gfx.render(out, extent: ext)
    }

    private func clipImage(_ img: CGImage, to kind: ShapeKind, pad: CGFloat) -> CGImage? {
        guard let ctx = Gfx.context(img.width, img.height) else { return nil }
        let full = CGRect(x: 0, y: 0, width: img.width, height: img.height)
        ctx.addPath(ShapeRenderer.path(kind, in: full.insetBy(dx: pad, dy: pad), corner: 0.08))
        ctx.clip()
        ctx.draw(img, in: full)
        return ctx.makeImage()
    }

    private func fadeImage(_ img: CGImage, edge: FadeEdge, amount: Double) -> CGImage? {
        let w = img.width, h = img.height
        guard let mask = Gfx.grayContext(w, h), let out = Gfx.context(w, h) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        let a = CGFloat(amount.clamped(0.02, 1))
        mask.setFillColor(gray: 1, alpha: 1)
        mask.fill(rect)
        guard let grad = CGGradient(colorSpace: Gfx.gray, colorComponents: [0, 1, 1, 1], locations: [0, 1], count: 2) else { return nil }
        let W = CGFloat(w), H = CGFloat(h)
        func band(_ start: CGPoint, _ end: CGPoint, _ clipRect: CGRect) {
            mask.saveGState()
            mask.clip(to: clipRect)
            mask.drawLinearGradient(grad, start: start, end: end, options: [])
            mask.restoreGState()
        }
        switch edge {
        case .none: break
        case .bottom: band(CGPoint(x: 0, y: 0), CGPoint(x: 0, y: H * a), CGRect(x: 0, y: 0, width: W, height: H * a))
        case .top: band(CGPoint(x: 0, y: H), CGPoint(x: 0, y: H * (1 - a)), CGRect(x: 0, y: H * (1 - a), width: W, height: H * a))
        case .left: band(CGPoint(x: 0, y: 0), CGPoint(x: W * a, y: 0), CGRect(x: 0, y: 0, width: W * a, height: H))
        case .right: band(CGPoint(x: W, y: 0), CGPoint(x: W * (1 - a), y: 0), CGRect(x: W * (1 - a), y: 0, width: W * a, height: H))
        case .topAndBottom:
            band(CGPoint(x: 0, y: 0), CGPoint(x: 0, y: H * a / 2), CGRect(x: 0, y: 0, width: W, height: H * a / 2))
            band(CGPoint(x: 0, y: H), CGPoint(x: 0, y: H * (1 - a / 2)), CGRect(x: 0, y: H * (1 - a / 2), width: W, height: H * a / 2))
        case .vignette:
            mask.setFillColor(gray: 0, alpha: 1)
            mask.fill(rect)
            if let rg = CGGradient(colorSpace: Gfx.gray, colorComponents: [1, 1, 1, 1, 0, 1], locations: [0, 1 - a * 0.8, 1], count: 3) {
                let c = CGPoint(x: W / 2, y: H / 2)
                mask.saveGState()
                mask.translateBy(x: c.x, y: c.y)
                mask.scaleBy(x: W / max(W, H), y: H / max(W, H))
                mask.drawRadialGradient(rg, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: max(W, H) / 2, options: [])
                mask.restoreGState()
            }
        }
        guard let m = mask.makeImage() else { return nil }
        out.clip(to: rect, mask: m)
        out.draw(img, in: rect)
        return out.makeImage()
    }
}


/// Applies brush strokes on top of the automatic subject mask.
enum MaskPainter {
    static func apply(_ strokes: [MaskStroke], to image: CGImage, base: CGImage?, invertBase: Bool) -> CGImage? {
        let w = image.width, h = image.height
        guard let ctx = Gfx.grayContext(w, h) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        if let base {
            ctx.draw(base, in: rect)
            if invertBase {
                ctx.setBlendMode(.difference)
                ctx.setFillColor(gray: 1, alpha: 1)
                ctx.fill(rect)
                ctx.setBlendMode(.normal)
            }
        } else {
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.fill(rect)
        }
        let unit = CGFloat(min(w, h))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for s in strokes {
            ctx.setStrokeColor(gray: s.restore ? 1 : 0, alpha: 1)
            ctx.setFillColor(gray: s.restore ? 1 : 0, alpha: 1)
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
        guard let mask = ctx.makeImage() else { return nil }
        // Feather the brushed edge slightly so it blends like a real cutout.
        let soft = FX.blur(CIImage(cgImage: mask), max(1, unit * 0.002))
        let out = CIImage(cgImage: image).applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: soft
        ])
        return Gfx.render(out, extent: CGRect(x: 0, y: 0, width: w, height: h))
    }
}
