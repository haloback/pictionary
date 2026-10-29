import CoreGraphics
import CoreImage
import Foundation

/// The printed paperback: back cover, spine and front cover as one sheet with bleed.
/// Panels are laid out left to right in inches: bleed + back | spine | front + bleed.
enum PrintWrap {
    struct Geometry {
        let settings: PrintSettings
        let dpi: Double

        var bleed: Double { PrintSettings.bleed }
        var size: CGSize { CGSize(width: px(settings.fullWidth), height: px(settings.fullHeight)) }
        var backRect: CGRect { rect(0, settings.trimWidth + bleed) }
        var spineRect: CGRect { rect(bleed + settings.trimWidth, settings.spineWidth) }
        var frontRect: CGRect { rect(bleed + settings.trimWidth + settings.spineWidth, settings.trimWidth + bleed) }

        func px(_ inches: Double) -> CGFloat { CGFloat((inches * dpi).rounded()) }

        /// Top-left-origin rect spanning the full height.
        private func rect(_ x: Double, _ w: Double) -> CGRect {
            CGRect(x: px(x), y: 0, width: px(w), height: px(settings.fullHeight))
        }
    }

    /// Renders the wrap. Coordinates in the returned image are standard (bottom-left origin).
    static func render(_ doc: CoverDocument, dpi: Double, guides: Bool = false) -> CGImage? {
        let g = Geometry(settings: doc.paperback, dpi: dpi)
        let W = Int(g.size.width), H = Int(g.size.height)
        guard W > 0, H > 0, let ctx = Gfx.context(W, H) else { return nil }
        let palette = PaletteRoles(doc.palette)
        let quality: CoverRenderer.Quality = dpi >= 200 ? .full : .preview
        // Helper to draw a top-left rect in this bottom-left context.
        func bl(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: CGFloat(H) - r.maxY, width: r.width, height: r.height) }

        // Front: the cover itself, re-flowed to the trim shape plus bleed.
        var front = doc
        front.canvas = CanvasSpec(width: Int(g.frontRect.width), height: Int(g.frontRect.height))
        if let img = CoverRenderer.shared.render(front, size: g.frontRect.size, quality: quality) {
            ctx.draw(img, in: bl(g.frontRect))
        }

        // Back and spine ground: the front's artwork, mirrored, softened and darkened so it
        // continues around the book without competing with the blurb.
        let groundRect = CGRect(x: 0, y: 0, width: g.backRect.width + g.spineRect.width, height: g.backRect.height)
        let textIDs = Set(doc.layers.filter { $0.textContent != nil }.map(\.id))
        var groundDoc = doc
        groundDoc.canvas = CanvasSpec(width: Int(groundRect.width), height: Int(groundRect.height))
        if let art = CoverRenderer.shared.render(groundDoc, size: groundRect.size, quality: .preview, excluding: textIDs) {
            var ci = CIImage(cgImage: art)
            ci = ci.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -ci.extent.width, y: 0))
            ci = FX.blur(ci, groundRect.height * 0.02)
            ci = FX.blend(FX.solid(palette.dark.withAlpha(0.62), ci.extent), over: ci, mode: "CISourceOverCompositing")
            if let ground = Gfx.render(ci, extent: ci.extent) {
                ctx.draw(ground, in: bl(CGRect(x: 0, y: 0, width: groundRect.width, height: groundRect.height)))
            }
        } else {
            ctx.setFillColor(palette.dark.cgColor)
            ctx.fill(bl(groundRect))
        }

        // Spine: a slightly deeper band with the title and author running top to bottom.
        ctx.setFillColor(palette.dark.withAlpha(0.55).cgColor)
        ctx.fill(bl(g.spineRect))
        if doc.paperback.spineHasText {
            let titleFont = doc.textLayer(role: .title)?.textContent?.fontName ?? "Didot"
            let author = doc.book.author.isEmpty ? "" : "   \(doc.book.author.uppercased())"
            var t = TextContent(text: doc.book.title.uppercased() + author, role: .custom, fontName: titleFont, color: palette.light)
            t.tracking = 0.08
            let along = g.spineRect.height - g.px(0.6 + 2 * PrintSettings.bleed)
            let across = g.spineRect.width - g.px(0.125)
            if along > 10, across > 4, case let (img, pad)? = TextRenderer.render(t, box: CGSize(width: along, height: across * 0.75), canvasHeight: g.size.height) {
                ctx.saveGState()
                let c = bl(g.spineRect)
                ctx.translateBy(x: c.midX, y: c.midY)
                ctx.rotate(by: -.pi / 2)
                let w = CGFloat(img.width), h = CGFloat(img.height)
                ctx.draw(img, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                ctx.restoreGState()
                _ = pad
            }
        }

        // Back cover copy.
        let margin = g.px(0.6)
        let backInner = CGRect(x: g.px(PrintSettings.bleed) + margin, y: g.px(PrintSettings.bleed) + margin,
                               width: g.px(doc.paperback.trimWidth) - 2 * margin, height: g.px(doc.paperback.trimHeight) - 2 * margin)
        let titleFont = doc.textLayer(role: .title)?.textContent?.fontName ?? "Didot"
        var cursor = backInner.minY
        if !doc.paperback.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var q = TextContent(text: doc.paperback.quote, role: .custom, fontName: titleFont, color: palette.accent.withLightness(0.78))
            q.autoFit = false
            q.fontSize = 0.024
            q.lineHeight = 1.25
            let m = TextRenderer.measure(q, size: CGFloat(q.fontSize) * g.size.height, wrapWidth: backInner.width)
            let box = CGSize(width: backInner.width, height: m.height + CGFloat(q.fontSize) * g.size.height * 0.4)
            if case let (img, pad)? = TextRenderer.render(q, box: box, canvasHeight: g.size.height) {
                ctx.draw(img, in: bl(CGRect(x: backInner.minX - pad, y: cursor - pad, width: CGFloat(img.width), height: CGFloat(img.height))))
            }
            cursor += box.height + g.px(0.3)
        }
        if !doc.paperback.blurb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var b = TextContent(text: doc.paperback.blurb, role: .custom, fontName: blurbFont, color: palette.light)
            b.autoFit = false
            b.fontSize = blurbSize(for: doc.paperback)
            b.lineHeight = 1.42
            b.alignment = .left
            let box = CGSize(width: backInner.width, height: max(10, backInner.maxY - g.px(1.6) - cursor))
            if case let (img, pad)? = TextRenderer.render(b, box: box, canvasHeight: g.size.height) {
                // Top-align the blurb: TextRenderer centers vertically, so shift by the slack.
                let m = TextRenderer.measure(b, size: CGFloat(b.fontSize) * g.size.height, wrapWidth: box.width)
                let slack = max(0, (box.height - m.height) / 2)
                ctx.draw(img, in: bl(CGRect(x: backInner.minX - pad, y: cursor - pad - slack, width: CGFloat(img.width), height: CGFloat(img.height))))
            }
        }

        // Barcode area: left clear for the printer's ISBN barcode, lower right of the back.
        let barcode = barcodeRect(g)
        if doc.paperback.keepBarcodeArea {
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fill(bl(barcode))
        }

        if guides { drawGuides(ctx, g, H: H, barcode: barcode) }
        return ctx.makeImage()
    }

    static let blurbFont = FontCatalog.resolve(["Baskerville", "HoeflerText-Regular", "Palatino-Roman", "Georgia"])

    /// About 11 pt body type at the trim height.
    static func blurbSize(for s: PrintSettings) -> Double { (11.0 / 72.0) / s.fullHeight }

    /// Whether the blurb fits above the barcode area, for a warning in the editor.
    static func blurbFits(_ doc: CoverDocument) -> Bool {
        let g = Geometry(settings: doc.paperback, dpi: 72)
        var b = TextContent(text: doc.paperback.blurb, role: .custom, fontName: blurbFont)
        b.autoFit = false
        b.fontSize = blurbSize(for: doc.paperback)
        b.lineHeight = 1.42
        let width = g.px(doc.paperback.trimWidth - 1.2)
        let m = TextRenderer.measure(b, size: CGFloat(b.fontSize) * g.size.height, wrapWidth: width)
        let available = g.px(doc.paperback.trimHeight - 1.2 - 1.6) - (doc.paperback.quote.isEmpty ? 0 : g.px(1.1))
        return m.height <= available
    }

    /// 2 x 1.2 in, a quarter inch in from the trim and the spine.
    static func barcodeRect(_ g: Geometry) -> CGRect {
        let w = g.px(2), h = g.px(1.2), inset = g.px(0.25)
        return CGRect(x: g.spineRect.minX - inset - w, y: g.size.height - g.px(PrintSettings.bleed) - inset - h, width: w, height: h)
    }

    private static func drawGuides(_ ctx: CGContext, _ g: Geometry, H: Int, barcode: CGRect) {
        func bl(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: CGFloat(H) - r.maxY, width: r.width, height: r.height) }
        let b = g.px(PrintSettings.bleed)
        let trim = CGRect(x: b, y: b, width: g.size.width - 2 * b, height: g.size.height - 2 * b)
        ctx.setLineWidth(max(1, g.dpi / 72))
        ctx.setStrokeColor(RGBA(hex: "E4572E").cgColor)
        ctx.stroke(bl(trim))
        ctx.setStrokeColor(RGBA(1, 1, 1, 0.8).cgColor)
        for x in [g.spineRect.minX, g.spineRect.maxX] {
            ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: CGFloat(H)))
        }
        ctx.strokePath()
        let safe = g.px(0.25)
        ctx.setStrokeColor(RGBA(1, 1, 1, 0.45).cgColor)
        ctx.setLineDash(phase: 0, lengths: [6, 5])
        ctx.stroke(bl(CGRect(x: b + safe, y: b + safe, width: g.spineRect.minX - b - 2 * safe, height: trim.height - 2 * safe)))
        ctx.stroke(bl(CGRect(x: g.frontRect.minX + safe, y: b + safe, width: g.frontRect.width - b - 2 * safe, height: trim.height - 2 * safe)))
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setStrokeColor(RGBA(0.3, 0.3, 0.3, 0.9).cgColor)
        ctx.stroke(bl(barcode))
    }

    /// One-page PDF at the exact sheet size, image at 300 DPI.
    static func exportPDF(_ doc: CoverDocument, to url: URL) -> Bool {
        guard let img = render(doc, dpi: PrintSettings.dpi) else { return false }
        var box = CGRect(x: 0, y: 0, width: doc.paperback.fullWidth * 72, height: doc.paperback.fullHeight * 72)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return false }
        pdf.beginPDFPage(nil)
        pdf.interpolationQuality = .high
        pdf.draw(img, in: box)
        pdf.endPDFPage()
        pdf.closePDF()
        return true
    }
}
