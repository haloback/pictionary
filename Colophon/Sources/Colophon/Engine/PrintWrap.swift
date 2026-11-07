import CoreGraphics
import CoreImage
import CoreText
import Foundation
import ImageIO

/// The printed book: back cover, spine and front cover as one sheet.
/// Paperback: bleed + back | spine | front + bleed. Hardcover (case laminate): the same panels are the
/// boards (trim + 1/8 in overhang) and a 0.75 in wrap replaces the bleed on every edge.
/// Panels are laid out left to right in inches.
enum PrintWrap {
    struct Geometry {
        let settings: PrintSettings
        let dpi: Double

        var bleed: Double { PrintSettings.bleed }
        /// Inches from the sheet edge to the trim (paperback) or to the board edge (hardcover).
        var edge: Double { settings.edgeMargin }
        var isHardcover: Bool { settings.binding == .hardcover }
        var size: CGSize { CGSize(width: px(settings.fullWidth), height: px(settings.fullHeight)) }
        var backRect: CGRect { rect(0, settings.panelWidth + edge) }
        var spineRect: CGRect { rect(edge + settings.panelWidth, settings.spineWidth) }
        var frontRect: CGRect { rect(edge + settings.panelWidth + settings.spineWidth, settings.panelWidth + edge) }
        /// What survives: inside the bleed (paperback) or on the boards (hardcover).
        var trimRect: CGRect { CGRect(x: px(edge), y: px(edge), width: size.width - 2 * px(edge), height: size.height - 2 * px(edge)) }
        /// Back-cover safe area: 0.25 in from the trim, 0.375 in from the spine.
        var backSafe: CGRect {
            let s = px(0.25), e = px(edge)
            return CGRect(x: e + s, y: e + s, width: spineRect.minX - px(0.375) - e - s, height: size.height - 2 * e - 2 * s)
        }
        var frontSafe: CGRect {
            let s = px(0.25), e = px(edge)
            return CGRect(x: spineRect.maxX + s, y: e + s, width: frontRect.width - e - 2 * s, height: size.height - 2 * e - 2 * s)
        }
        /// Hinge grooves either side of the spine on a case-bound book (x positions).
        var hingeLines: [CGFloat] {
            guard isHardcover else { return [] }
            return [spineRect.minX - px(PrintSettings.hingeWidth), spineRect.maxX + px(PrintSettings.hingeWidth)]
        }

        func px(_ inches: Double) -> CGFloat { CGFloat((inches * dpi).rounded()) }
        /// Points to pixels at this dpi.
        func pt(_ points: Double) -> CGFloat { CGFloat(points * dpi / 72) }

        /// Top-left-origin rect spanning the full height.
        private func rect(_ x: Double, _ w: Double) -> CGRect {
            CGRect(x: px(x), y: 0, width: px(w), height: px(settings.fullHeight))
        }
    }

    // MARK: Fonts

    static let headingFont = FontCatalog.resolve(["CormorantGaramond-SemiBold", "Baskerville-SemiBold", "Georgia-Bold", "Helvetica-Bold"])
    static let quoteFont = FontCatalog.resolve(["CormorantGaramond-MediumItalic", "Baskerville-Italic", "Georgia-Italic", "Helvetica-Oblique"])
    static let blurbFont = FontCatalog.resolve(["JosefinSans-Light", "Helvetica", "Baskerville"])
    static let smallFont = FontCatalog.resolve(["JosefinSans-Bold", "Helvetica-Bold"])

    // MARK: Render

    /// Renders the wrap. Coordinates in the returned image are standard (bottom-left origin).
    static func render(_ doc: CoverDocument, dpi: Double, guides: Bool = false) -> CGImage? {
        let g = Geometry(settings: doc.paperback, dpi: dpi)
        let W = Int(g.size.width), H = Int(g.size.height)
        guard W > 0, H > 0, let ctx = Gfx.context(W, H) else { return nil }
        let palette = PaletteRoles(doc.palette)
        let quality: CoverRenderer.Quality = dpi >= 200 ? .full : .preview
        // Helper to draw a top-left rect in this bottom-left context.
        func bl(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: CGFloat(H) - r.maxY, width: r.width, height: r.height) }

        // Front: the cover itself, re-flowed to the panel shape plus its edge margin.
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

        drawSpine(doc, g, ctx: ctx, H: H, palette: palette)
        let barcode = drawBack(doc, g, ctx: ctx, H: H, palette: palette)

        if guides { drawGuides(ctx, g, H: H, barcode: barcode) }
        return ctx.makeImage()
    }

    // MARK: Spine

    private static func drawSpine(_ doc: CoverDocument, _ g: Geometry, ctx: CGContext, H: Int, palette: PaletteRoles) {
        func bl(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: CGFloat(H) - r.maxY, width: r.width, height: r.height) }
        let s = doc.paperback
        // A slightly deeper band.
        ctx.setFillColor(palette.dark.withAlpha(0.55).cgColor)
        ctx.fill(bl(g.spineRect))
        guard s.spineHasText else { return }

        let titleFont = doc.textLayer(role: .title)?.textContent?.fontName ?? "Didot"
        let publisher = s.publisher.trimmingCharacters(in: .whitespacesAndNewlines)
        let across = g.spineRect.width - g.px(0.125)
        let endPad = g.px(0.3 + g.edge)
        // The publisher mark takes the bottom of the spine; the title runs above it.
        let markLength: CGFloat = publisher.isEmpty ? 0 : g.px(1.1)
        let along = g.spineRect.height - 2 * endPad - markLength
        guard along > 10, across > 4 else { return }

        /// Draws a horizontally set text image rotated to read top to bottom, centered on `center`.
        func drawRotated(_ t: TextContent, box: CGSize, center: CGPoint) {
            guard case let (img, _)? = TextRenderer.render(t, box: box, canvasHeight: g.size.height) else { return }
            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: -.pi / 2)
            let w = CGFloat(img.width), h = CGFloat(img.height)
            ctx.draw(img, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
            ctx.restoreGState()
        }

        let author = doc.book.author.isEmpty ? "" : "   \(doc.book.author.uppercased())"
        var t = TextContent(text: doc.book.title.uppercased() + author, role: .custom, fontName: titleFont, color: palette.light)
        t.tracking = 0.08
        let titleArea = CGRect(x: g.spineRect.minX, y: endPad, width: g.spineRect.width, height: along)
        let c = bl(titleArea)
        drawRotated(t, box: CGSize(width: along, height: across * 0.75), center: CGPoint(x: c.midX, y: c.midY))

        if !publisher.isEmpty {
            var p = TextContent(text: publisher.uppercased(), role: .custom, fontName: smallFont, color: palette.light.withAlpha(0.85))
            p.tracking = 0.18
            p.autoFit = false
            p.fontSize = 6.5 / 72 / s.fullHeight
            let m = TextRenderer.measure(p, size: CGFloat(p.fontSize) * g.size.height, wrapWidth: nil)
            let length = min(markLength - g.px(0.1), m.width + g.px(0.1))
            let markArea = CGRect(x: g.spineRect.minX, y: g.spineRect.maxY - endPad - markLength, width: g.spineRect.width, height: markLength)
            let mc = bl(markArea)
            drawRotated(p, box: CGSize(width: max(4, length), height: min(across * 0.6, m.height * 1.3)), center: CGPoint(x: mc.midX, y: mc.midY))
        }
    }

    // MARK: Back cover

    /// Paragraph type for the back cover, set with CoreText.
    struct Para {
        var font: String
        var size: CGFloat
        var color: RGBA
        var alignment: CTTextAlignment = .left
        /// Baseline-to-baseline in ems.
        var lineHeight: CGFloat = 1.42
        /// Space after a paragraph in ems.
        var paragraphSpacing: CGFloat = 0.55
        /// Letter spacing in ems.
        var tracking: CGFloat = 0
    }

    static func attributed(_ text: String, _ p: Para) -> NSAttributedString {
        let font = FontCatalog.ctFont(p.font, size: p.size)
        var lineHeight = p.size * p.lineHeight
        var spacing = p.size * p.paragraphSpacing
        var alignment = p.alignment
        var style: CTParagraphStyle?
        withUnsafeMutablePointer(to: &lineHeight) { lh in
            withUnsafeMutablePointer(to: &spacing) { sp in
                withUnsafeMutablePointer(to: &alignment) { al in
                    let settings = [
                        CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: al),
                        CTParagraphStyleSetting(spec: .minimumLineHeight, valueSize: MemoryLayout<CGFloat>.size, value: lh),
                        CTParagraphStyleSetting(spec: .maximumLineHeight, valueSize: MemoryLayout<CGFloat>.size, value: lh),
                        CTParagraphStyleSetting(spec: .paragraphSpacing, valueSize: MemoryLayout<CGFloat>.size, value: sp)
                    ]
                    style = CTParagraphStyleCreate(settings, settings.count)
                }
            }
        }
        var attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): p.color.cgColor
        ]
        if let style { attrs[NSAttributedString.Key(kCTParagraphStyleAttributeName as String)] = style }
        if p.tracking != 0 { attrs[NSAttributedString.Key(kCTKernAttributeName as String)] = p.size * p.tracking }
        return NSAttributedString(string: text, attributes: attrs)
    }

    /// Height the text needs at `width`.
    static func measure(_ text: String, _ p: Para, width: CGFloat) -> CGFloat {
        guard !text.isEmpty, width > 1 else { return 0 }
        let fs = CTFramesetterCreateWithAttributedString(attributed(text, p))
        var fit = CFRange()
        let size = CTFramesetterSuggestFrameSizeWithConstraints(fs, CFRange(location: 0, length: 0), nil, CGSize(width: width, height: 100_000), &fit)
        return ceil(size.height)
    }

    /// Sets `text` from the top of `rect` (top-left pixel coordinates) into the bottom-left context. Returns the height used.
    @discardableResult
    static func draw(_ text: String, _ p: Para, in rect: CGRect, ctx: CGContext, H: Int) -> CGFloat {
        guard !text.isEmpty, rect.width > 1, rect.height > 1 else { return 0 }
        let attr = attributed(text, p)
        let fs = CTFramesetterCreateWithAttributedString(attr)
        let path = CGPath(rect: CGRect(x: rect.minX, y: CGFloat(H) - rect.maxY, width: rect.width, height: rect.height), transform: nil)
        let frame = CTFramesetterCreateFrame(fs, CFRange(location: 0, length: 0), path, nil)
        ctx.saveGState()
        ctx.textMatrix = .identity
        CTFrameDraw(frame, ctx)
        ctx.restoreGState()
        return min(rect.height, measure(text, p, width: rect.width))
    }

    /// Lays out the back cover per `backLayout` and returns the barcode box (top-left coordinates).
    private static func drawBack(_ doc: CoverDocument, _ g: Geometry, ctx: CGContext, H: Int, palette: PaletteRoles) -> CGRect {
        func bl(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: CGFloat(H) - r.maxY, width: r.width, height: r.height) }
        let s = doc.paperback
        let S = g.backSafe
        let light = palette.light
        let soft = palette.light.withAlpha(0.82)
        let accent = palette.accent.withLightness(0.78)
        let isbn = Barcode.isbn13(from: s.isbn)
        let addOn = Barcode.isValidAddOn(s.priceCode) ? s.priceCode : nil
        let barcode = barcodeRect(g, addOn: addOn != nil)
        let gap = g.px(0.25)

        // Bottom zone: category above the barcode, publisher beside it.
        let category = s.category.trimmingCharacters(in: .whitespacesAndNewlines)
        var catHeight: CGFloat = 0
        if !category.isEmpty {
            var cp = Para(font: smallFont, size: g.pt(7.5), color: soft)
            cp.alignment = .right
            cp.tracking = 0.14
            cp.lineHeight = 1.2
            catHeight = g.pt(7.5) * 1.3
            draw(category.uppercased(), cp, in: CGRect(x: S.minX, y: barcode.minY - catHeight - g.px(0.06), width: barcode.maxX - S.minX, height: catHeight), ctx: ctx, H: H)
            catHeight += g.px(0.06)
        }
        let publisher = s.publisher.trimmingCharacters(in: .whitespacesAndNewlines)
        if !publisher.isEmpty {
            var pp = Para(font: smallFont, size: g.pt(8), color: soft)
            pp.tracking = 0.16
            pp.lineHeight = 1.2
            let h = g.pt(8) * 1.3
            draw(publisher.uppercased(), pp, in: CGRect(x: S.minX, y: barcode.maxY - h, width: max(10, barcode.minX - gap - S.minX), height: h), ctx: ctx, H: H)
        }
        let bottomTop = barcode.minY - catHeight - gap

        let quote = s.quote.trimmingCharacters(in: .whitespacesAndNewlines)
        let blurbText = backBlurb(doc)
        var blurbPara = Para(font: blurbFont, size: g.pt(11), color: light)
        blurbPara.alignment = .justified
        blurbPara.lineHeight = 1.42

        switch s.backLayout {
        case .minimal:
            // Blurb only, a narrow centered column with plenty of air.
            let colW = S.width * 0.74
            var bp = blurbPara
            bp.size = g.pt(11.5)
            bp.alignment = .center
            bp.lineHeight = 1.5
            let region = CGRect(x: S.minX + (S.width - colW) / 2, y: S.minY + g.px(0.75), width: colW, height: bottomTop - S.minY - g.px(1.5))
            let h = min(region.height, measure(blurbText, bp, width: colW))
            draw(blurbText, bp, in: CGRect(x: region.minX, y: region.minY + max(0, (region.height - h) / 2), width: colW, height: h), ctx: ctx, H: H)

        case .classic, .quoteFirst:
            var cursor = S.minY
            if !quote.isEmpty {
                var qp = Para(font: quoteFont, size: g.pt(s.backLayout == .quoteFirst ? 21 : 15), color: accent)
                qp.lineHeight = 1.22
                qp.alignment = s.backLayout == .quoteFirst ? .center : .left
                if s.backLayout == .quoteFirst {
                    // The quote is the hero: centered in the top third.
                    let hero = CGRect(x: S.minX, y: S.minY, width: S.width, height: S.height / 3)
                    let h = min(hero.height, measure(quote, qp, width: hero.width * 0.9))
                    draw(quote, qp, in: CGRect(x: hero.minX + hero.width * 0.05, y: hero.minY + (hero.height - h) / 2, width: hero.width * 0.9, height: h), ctx: ctx, H: H)
                    // A short rule under the hero.
                    ctx.setFillColor(accent.withAlpha(0.7).cgColor)
                    ctx.fill(bl(CGRect(x: S.midX - g.px(0.4), y: hero.maxY - g.px(0.02), width: g.px(0.8), height: max(1, g.px(0.012)))))
                    cursor = hero.maxY + gap
                } else {
                    let h = min(S.height * 0.3, measure(quote, qp, width: S.width))
                    draw(quote, qp, in: CGRect(x: S.minX, y: cursor, width: S.width, height: h), ctx: ctx, H: H)
                    cursor += h + gap
                }
            }

            // Bio block above the bottom zone: optional round photo, author name, bio.
            let bio = s.authorBio.trimmingCharacters(in: .whitespacesAndNewlines)
            let photo = s.authorPhotoAssetID.flatMap { id in AssetStore.shared.image(id, data: doc.assetData(id), resolution: .preview) }
            var bioTop = bottomTop
            if !bio.isEmpty || photo != nil {
                let d = photo == nil ? 0 : g.px(0.9)
                let textX = S.minX + (d > 0 ? d + g.px(0.2) : 0)
                let textW = S.maxX - textX
                var np = Para(font: headingFont, size: g.pt(10.5), color: light)
                np.tracking = 0.06
                np.lineHeight = 1.2
                var bp = Para(font: blurbFont, size: g.pt(8.5), color: soft)
                bp.lineHeight = 1.4
                let name = doc.book.author.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let nameH: CGFloat = name.isEmpty ? 0 : g.pt(10.5) * 1.35
                let bioH = min(g.px(1.4), measure(bio, bp, width: textW))
                let blockH = max(d, nameH + bioH)
                bioTop = bottomTop - gap - blockH
                if let photo {
                    let circle = CGRect(x: S.minX, y: bioTop, width: d, height: d)
                    drawCircular(photo, in: bl(circle), ctx: ctx)
                }
                var y = bioTop + max(0, (d - (nameH + bioH)) / 2)
                if nameH > 0 {
                    draw(name, np, in: CGRect(x: textX, y: y, width: textW, height: nameH), ctx: ctx, H: H)
                    y += nameH
                }
                if bioH > 0 { draw(bio, bp, in: CGRect(x: textX, y: y, width: textW, height: bioH), ctx: ctx, H: H) }
            }

            // Blurb between the quote and the bio.
            let blurbRect = CGRect(x: S.minX, y: cursor, width: S.width, height: max(10, bioTop - gap - cursor))
            draw(blurbText, blurbPara, in: blurbRect, ctx: ctx, H: H)
        }

        // Barcode: the real Bookland EAN when the ISBN validates, else a clear white box for the printer.
        if let isbn {
            Barcode.draw(isbn13: isbn, addOn: addOn, in: bl(barcode), ctx: ctx, dpi: g.dpi, hint: s.isbn)
        } else if s.keepBarcodeArea {
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fill(bl(barcode))
            var ph = Para(font: smallFont, size: g.pt(8), color: RGBA(0.55, 0.55, 0.55, 1))
            ph.alignment = .center
            ph.tracking = 0.12
            let h = g.pt(8) * 1.3
            draw("ISBN BARCODE", ph, in: CGRect(x: barcode.minX, y: barcode.midY - h / 2, width: barcode.width, height: h), ctx: ctx, H: H)
        }
        return barcode
    }

    /// Aspect-fills an image into a circle (bottom-left rect).
    private static func drawCircular(_ img: CGImage, in r: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.addEllipse(in: r)
        ctx.clip()
        let iw = CGFloat(img.width), ih = CGFloat(img.height)
        let scale = max(r.width / iw, r.height / ih)
        let w = iw * scale, h = ih * scale
        ctx.draw(img, in: CGRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h))
        ctx.restoreGState()
    }

    /// The back-cover copy: the paperback's own text, or the blurb drafted in the Book panel when that's empty.
    static func backBlurb(_ doc: CoverDocument) -> String {
        let own = doc.paperback.blurb.trimmingCharacters(in: .whitespacesAndNewlines)
        return own.isEmpty ? doc.book.blurb.trimmingCharacters(in: .whitespacesAndNewlines) : own
    }

    /// About 11 pt body type as a fraction of the sheet height.
    static func blurbSize(for s: PrintSettings) -> Double { (11.0 / 72.0) / s.fullHeight }

    /// Whether the blurb fits in the room the chosen layout leaves it, for a warning in the editor.
    static func blurbFits(_ doc: CoverDocument) -> Bool {
        let text = backBlurb(doc)
        if text.isEmpty { return true }
        let s = doc.paperback
        let g = Geometry(settings: s, dpi: 72)
        let S = g.backSafe
        let barcode = barcodeRect(g, addOn: Barcode.isValidAddOn(s.priceCode))
        let gap = g.px(0.25)
        var available = barcode.minY - gap - S.minY
        if !s.category.isEmpty { available -= g.pt(7.5) * 1.3 + g.px(0.06) }
        var p = Para(font: blurbFont, size: g.pt(11), color: .nearWhite)
        var width = S.width
        switch s.backLayout {
        case .minimal:
            width = S.width * 0.74
            p.size = g.pt(11.5)
            p.lineHeight = 1.5
            available -= g.px(1.5)
        case .classic, .quoteFirst:
            let quote = s.quote.trimmingCharacters(in: .whitespacesAndNewlines)
            if !quote.isEmpty {
                if s.backLayout == .quoteFirst {
                    available -= S.height / 3 + gap
                } else {
                    var qp = Para(font: quoteFont, size: g.pt(15), color: .nearWhite)
                    qp.lineHeight = 1.22
                    available -= min(S.height * 0.3, measure(quote, qp, width: S.width)) + gap
                }
            }
            let bio = s.authorBio.trimmingCharacters(in: .whitespacesAndNewlines)
            if !bio.isEmpty || s.authorPhotoAssetID != nil {
                let d: CGFloat = s.authorPhotoAssetID == nil ? 0 : g.px(0.9)
                var bp = Para(font: blurbFont, size: g.pt(8.5), color: .nearWhite)
                bp.lineHeight = 1.4
                let nameH: CGFloat = doc.book.author.isEmpty ? 0 : g.pt(10.5) * 1.35
                let bioH = min(g.px(1.4), measure(bio, bp, width: S.width - (d > 0 ? d + g.px(0.2) : 0)))
                available -= gap + max(d, nameH + bioH)
            }
            available -= gap
        }
        return measure(text, p, width: width) <= available
    }

    /// The barcode box in the lower right of the back, inside the safe area: 2 x 1.2 in, or 2.3 in wide with a price add-on.
    static func barcodeRect(_ g: Geometry, addOn: Bool = false) -> CGRect {
        let w = g.px(addOn ? 2.3 : 2), h = g.px(1.2)
        let S = g.backSafe
        return CGRect(x: S.maxX - w, y: S.maxY - h, width: w, height: h)
    }

    private static func drawGuides(_ ctx: CGContext, _ g: Geometry, H: Int, barcode: CGRect) {
        func bl(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: CGFloat(H) - r.maxY, width: r.width, height: r.height) }
        let line = max(1, g.dpi / 72)
        ctx.setLineWidth(line)
        // Trim (or board edge).
        ctx.setStrokeColor(RGBA(hex: "E4572E").cgColor)
        ctx.stroke(bl(g.trimRect))
        // Spine folds.
        ctx.setStrokeColor(RGBA(1, 1, 1, 0.8).cgColor)
        for x in [g.spineRect.minX, g.spineRect.maxX] {
            ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: CGFloat(H)))
        }
        ctx.strokePath()
        // Safe areas.
        ctx.setStrokeColor(RGBA(1, 1, 1, 0.45).cgColor)
        ctx.setLineDash(phase: 0, lengths: [6, 5])
        ctx.stroke(bl(g.backSafe))
        ctx.stroke(bl(g.frontSafe))
        // Hardcover hinges.
        if !g.hingeLines.isEmpty {
            ctx.setStrokeColor(RGBA(hex: "7FD1FF").withAlpha(0.9).cgColor)
            ctx.setLineDash(phase: 0, lengths: [10, 6])
            for x in g.hingeLines {
                ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: CGFloat(H)))
            }
            ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setStrokeColor(RGBA(0.3, 0.3, 0.3, 0.9).cgColor)
        ctx.stroke(bl(barcode))
    }

    // MARK: Checks

    /// Pre-upload checks for the printed book, plain sentences for the editor to list.
    static func printChecks(_ doc: CoverDocument) -> [String] {
        let s = doc.paperback
        var out: [String] = []
        let isbnText = s.isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        if isbnText.isEmpty {
            out.append("No ISBN: the barcode box is left white for the printer to fill.")
        } else if Barcode.isbn13(from: isbnText) == nil {
            out.append("The ISBN isn't valid (wrong length or check digit), so no barcode is drawn.")
        }
        if !s.priceCode.isEmpty && !Barcode.isValidAddOn(s.priceCode) {
            out.append("The price code must be five digits, such as 51499 for $14.99 or 90000 for no price.")
        }
        if !s.spineHasText {
            out.append("Under 80 pages the spine is too thin for text, so it stays blank.")
        } else if s.spineWidth < 0.35 && !doc.book.title.isEmpty {
            out.append(String(format: "The spine is narrow (%.2f in); keep its text short.", s.spineWidth))
        }
        if !backBlurb(doc).isEmpty && !blurbFits(doc) {
            out.append("The blurb doesn't fit the back cover with this layout. Trim it or choose another layout.")
        }
        if s.binding == .hardcover {
            out.append("Hardcover spine width is an approximation (pages x paper + 0.125 in). Check it against the printer's hardcover calculator before uploading.")
        }
        if s.printer == .ingramSpark {
            out.append("IngramSpark spine uses its Standard paper figures; premium stocks differ, so compare with its cover template generator.")
        }
        // Photo resolution on the front panel at 300 dpi.
        let g = Geometry(settings: s, dpi: PrintSettings.dpi)
        let panelW = Double(g.frontRect.width) / PrintSettings.dpi
        let panelH = Double(g.frontRect.height) / PrintSettings.dpi
        for layer in doc.layers where layer.isVisible {
            guard let img = layer.imageContent else { continue }
            guard let size = sourcePixelSize(doc.assetData(img.assetID)) ?? AssetStore.shared.imageSize(img.assetID, data: doc.assetData(img.assetID)) else { continue }
            let frameW = layer.frame.w * panelW, frameH = layer.frame.h * panelH
            guard frameW > 0, frameH > 0, size.width > 0, size.height > 0 else { continue }
            let inchesPerPixel = max(frameW / Double(size.width), frameH / Double(size.height)) * max(1, img.zoom)
            let ppi = 1 / inchesPerPixel
            if ppi < 250 {
                out.append(String(format: "\"%@\" prints at about %.0f ppi on the front; 300 is ideal and under 250 may look soft.", layer.name, ppi))
            }
        }
        if s.category.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append("No shelf category set (e.g. FICTION / THRILLER). Bookshops expect one above the barcode.")
        }
        if s.publisher.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append("No publisher name: the spine foot and back cover leave it out.")
        }
        return out
    }

    /// Pixel size from the encoded image's header, without decoding it.
    static func sourcePixelSize(_ data: Data?) -> CGSize? {
        guard let data, let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Double, let h = props[kCGImagePropertyPixelHeight] as? Double else { return nil }
        return CGSize(width: w, height: h)
    }

    // MARK: Export

    /// Converts a rendered RGB image to 8-bit CMYK (generic CMYK profile), no alpha.
    static func cmykImage(_ img: CGImage) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.genericCMYK),
              let ctx = CGContext(data: nil, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        let whole = CGRect(x: 0, y: 0, width: img.width, height: img.height)
        ctx.setFillColor(CGColor(genericCMYKCyan: 0, magenta: 0, yellow: 0, black: 0, alpha: 1))
        ctx.fill(whole)
        ctx.interpolationQuality = .none
        ctx.draw(img, in: whole)
        return ctx.makeImage()
    }

    /// One-page PDF at the exact sheet size with media, bleed and trim boxes; the raster at `dpi`
    /// (CMYK when the settings ask for it) and the barcode drawn on top as vectors.
    static func exportPDF(_ doc: CoverDocument, to url: URL, dpi: Double = PrintSettings.dpi) -> Bool {
        guard let rendered = render(doc, dpi: dpi) else { return false }
        let s = doc.paperback
        let img = s.cmykExport ? (cmykImage(rendered) ?? rendered) : rendered
        var media = CGRect(x: 0, y: 0, width: s.fullWidth * 72, height: s.fullHeight * 72)
        let trim = media.insetBy(dx: s.edgeMargin * 72, dy: s.edgeMargin * 72)
        func boxData(_ r: CGRect) -> CFData {
            var r = r
            return Data(bytes: &r, count: MemoryLayout<CGRect>.size) as CFData
        }
        let title = doc.book.title.isEmpty ? "Cover" : doc.book.title
        let info: [CFString: Any] = [
            kCGPDFContextTitle: "\(title) - \(s.binding.label) wrap",
            kCGPDFContextCreator: "Colophon",
            kCGPDFContextMediaBox: boxData(media)
        ]
        guard let pdf = CGContext(url as CFURL, mediaBox: &media, info as CFDictionary) else { return false }
        let page: [CFString: Any] = [
            kCGPDFContextMediaBox: boxData(media),
            kCGPDFContextBleedBox: boxData(media),
            kCGPDFContextTrimBox: boxData(trim)
        ]
        pdf.beginPDFPage(page as CFDictionary)
        pdf.interpolationQuality = .high
        pdf.draw(img, in: media)
        // The barcode again, as vectors, so scanners read crisp bars.
        if let isbn = Barcode.isbn13(from: s.isbn) {
            let g = Geometry(settings: s, dpi: 72)
            let r = barcodeRect(g, addOn: Barcode.isValidAddOn(s.priceCode))
            let box = CGRect(x: r.minX, y: media.height - r.maxY, width: r.width, height: r.height)
            Barcode.draw(isbn13: isbn, addOn: Barcode.isValidAddOn(s.priceCode) ? s.priceCode : nil, in: box, ctx: pdf, dpi: 72, hint: s.isbn)
        }
        pdf.endPDFPage()
        pdf.closePDF()
        return true
    }

    /// The flattened wrap as a PNG at `dpi` (300 by default), tagged with its resolution.
    static func exportPNG(_ doc: CoverDocument, to url: URL, dpi: Double = PrintSettings.dpi) -> Bool {
        guard let img = render(doc, dpi: dpi) else { return false }
        return Exporter.write(img, to: url, format: .png, quality: 1)
    }
}
