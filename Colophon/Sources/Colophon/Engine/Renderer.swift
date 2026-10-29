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
        var clip: ShapeKind?
        var fade: FadeEdge
        var fadeAmount: Double
        var quality: Int
        var cutout: Cutout?
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

        for (i, layer) in doc.layers.enumerated() where layer.isVisible && !excluding.contains(layer.id) {
            guard let r = rasterize(layer, doc: doc, canvas: canvas, quality: quality) else { continue }
            composite(r, layer: layer, in: ctx, canvas: canvas)

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
        return ctx.makeImage()
    }

    private func composite(_ r: LayerRaster, layer: Layer, in ctx: CGContext, canvas: CGSize) {
        ctx.saveGState()
        ctx.setAlpha(CGFloat(layer.opacity.clamped01))
        ctx.setBlendMode(layer.blend.cg)
        if let s = layer.shadow {
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
                            effects: layer.effects, clip: layer.clipShape, fade: layer.fade, fadeAmount: layer.fadeAmount,
                            quality: quality.rawValue, cutout: cutoutOverride)
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
        case .text(let t):
            if case let (img, p)? = TextRenderer.render(t, box: CGSize(width: w, height: h), canvasHeight: canvas.height) {
                image = img
                pad = p
            }
        }
        guard var img = image else { return nil }

        if !layer.effects.isEmpty {
            img = applyEffects(layer.effects, to: img, canvas: canvas, seed: Int(layer.id.uuid.0) << 8 | Int(layer.id.uuid.1)) ?? img
        }
        if let clip = layer.clipShape {
            img = clipImage(img, to: clip, pad: pad) ?? img
        }
        if layer.fade != .none {
            img = fadeImage(img, edge: layer.fade, amount: layer.fadeAmount) ?? img
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
        guard let src = AssetStore.shared.cutout(ic.assetID, data: data, mode: cutout, resolution: quality.assetResolution),
              let ctx = Gfx.context(w, h) else { return nil }
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

    private func applyEffects(_ effects: [EffectInstance], to img: CGImage, canvas: CGSize, seed: Int) -> CGImage? {
        let original = CIImage(cgImage: img)
        var ci = original
        let ec = EffectContext(scale: canvas.height / 1000, seed: seed)
        for e in effects {
            guard let p = EffectLibrary.shared.preset(e.presetID) else { continue }
            let processed = p.apply(ci, ec).cropped(to: original.extent)
            ci = FX.mix(ci, processed, e.amount.clamped01)
        }
        // Keep the layer's own transparency (cutouts, text).
        ci = ci.cropped(to: original.extent).applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: original])
        return Gfx.render(ci, extent: original.extent)
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
