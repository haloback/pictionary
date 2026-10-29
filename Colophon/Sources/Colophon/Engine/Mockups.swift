import CoreGraphics
import CoreImage
import Foundation

/// Marketing images built from the finished cover: a 3D book, a social post, a phone and a square.
enum MockupKind: String, CaseIterable, Identifiable {
    case book3D, social, phone, tablet, duo, square

    var id: String { rawValue }

    var label: String {
        switch self {
        case .book3D: return "3D Book (transparent PNG)"
        case .social: return "Social Post 1080 x 1080"
        case .phone: return "Phone Mockup (transparent PNG)"
        case .tablet: return "Tablet Mockup (transparent PNG)"
        case .duo: return "Book and Phone Scene 2400 x 1600"
        case .square: return "Square Cover 3000 x 3000"
        }
    }

    var fileSuffix: String {
        switch self {
        case .book3D: return "3D Book"
        case .social: return "Social Post"
        case .phone: return "Phone Mockup"
        case .tablet: return "Tablet Mockup"
        case .duo: return "Book and Phone"
        case .square: return "Square"
        }
    }

    var pixelSize: CGSize {
        switch self {
        case .book3D: return CGSize(width: 2000, height: 2000)
        case .social: return CGSize(width: 1080, height: 1080)
        case .phone: return CGSize(width: 1600, height: 1600)
        case .tablet: return CGSize(width: 2000, height: 2000)
        case .duo: return CGSize(width: 2400, height: 1600)
        case .square: return CGSize(width: 3000, height: 3000)
        }
    }

    /// Transparent mockups must be PNG; the rest can follow the export format.
    var needsAlpha: Bool { self == .book3D || self == .phone || self == .tablet }
}

enum MockupRenderer {
    static func render(_ kind: MockupKind, doc: CoverDocument) -> CGImage? {
        let coverW = 1000
        let coverH = Int((Double(coverW) * doc.canvas.aspect).rounded())
        var d = doc
        d.canvas = CanvasSpec(width: d.canvas.width, height: d.canvas.height)
        guard let cover = CoverRenderer.shared.render(d, size: CGSize(width: coverW, height: coverH), quality: .full) else { return nil }
        let spine = spineImage(doc, coverHeight: coverH)
        switch kind {
        case .book3D: return book3D(cover, size: kind.pixelSize, spine: spine)
        case .social: return onBlurredGround(cover, size: kind.pixelSize, coverHeightFraction: 0.8, useBook: true, spine: spine)
        case .phone: return device(cover, size: kind.pixelSize, aspect: 0.49, cornerFactor: 0.15, island: true)
        case .tablet: return device(cover, size: kind.pixelSize, aspect: 0.72, cornerFactor: 0.06, island: false)
        case .duo: return duo(cover, size: kind.pixelSize, spine: spine, palette: PaletteRoles(doc.palette))
        case .square: return onBlurredGround(cover, size: kind.pixelSize, coverHeightFraction: 0.86, useBook: false, spine: spine)
        }
    }

    /// The real paperback spine (title and author), cut from the print wrap at cover height.
    static func spineImage(_ doc: CoverDocument, coverHeight: Int) -> CGImage? {
        let dpi = Double(coverHeight) / doc.paperback.trimHeight
        guard let wrap = PrintWrap.render(doc, dpi: dpi) else { return nil }
        let g = PrintWrap.Geometry(settings: doc.paperback, dpi: dpi)
        let bleed = g.px(PrintSettings.bleed)
        let r = CGRect(x: g.spineRect.minX, y: bleed, width: max(1, g.spineRect.width), height: g.spineRect.height - 2 * bleed)
        return wrap.cropping(to: r.integral)
    }

    // MARK: 3D book

    static func book3D(_ cover: CGImage, size: CGSize, spine spineArt: CGImage? = nil) -> CGImage? {
        let ext = CGRect(origin: .zero, size: size)
        let aspect = CGFloat(cover.height) / CGFloat(cover.width)
        let faceH = size.height * 0.74
        let faceW = faceH / aspect * 0.92
        let left = (size.width - faceW) / 2 + size.width * 0.03
        let bottom = (size.height - faceH) / 2 + size.height * 0.02
        let top = bottom + faceH
        let tilt = faceH * 0.035
        let spineW = spineArt.map { faceW * CGFloat($0.width) / CGFloat(cover.width) * 0.55 } ?? faceW * 0.09

        let face = CIImage(cgImage: cover)
        let tl = CGPoint(x: left, y: top), bl = CGPoint(x: left, y: bottom)
        let tr = CGPoint(x: left + faceW, y: top - tilt), br = CGPoint(x: left + faceW, y: bottom + tilt)
        let warpedFace = warp(face, tl, tr, br, bl)

        // Spine: the printed spine when there is one, else the cover's edge, shaded as it turns away.
        let strip: CIImage
        if let spineArt {
            strip = CIImage(cgImage: spineArt).applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -0.45])
        } else {
            strip = face.cropped(to: CGRect(x: 0, y: 0, width: face.extent.width * 0.06, height: face.extent.height))
                .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -1.1])
        }
        let spine = warp(strip, CGPoint(x: left - spineW, y: top - tilt * 0.8), tl, bl, CGPoint(x: left - spineW, y: bottom + tilt * 0.8))

        // Soft sheen across the face.
        let sheen = FX.linear(CGPoint(x: 0, y: face.extent.height), CGPoint(x: face.extent.width, y: 0),
                              RGBA(1, 1, 1, 0.22), RGBA(1, 1, 1, 0), extent: face.extent)
        let warpedSheen = warp(sheen, tl, tr, br, bl)

        // Contact shadow.
        let shadowCenter = CGPoint(x: left + faceW * 0.45, y: bottom - size.height * 0.01)
        let shadow = FX.radial(center: .zero, r0: 0, r1: faceW * 0.62, c0: RGBA(0, 0, 0, 0.55), c1: RGBA(0, 0, 0, 0),
                               extent: CGRect(x: -faceW, y: -faceW, width: faceW * 2, height: faceW * 2))
            .transformed(by: CGAffineTransform(scaleX: 1, y: 0.12).concatenating(CGAffineTransform(translationX: shadowCenter.x, y: shadowCenter.y)))

        var out = shadow
        out = spine.composited(over: out)
        out = warpedFace.composited(over: out)
        out = warpedSheen.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: out])
        // Thin page edge highlight on the right.
        let edge = FX.solid(RGBA(0.95, 0.93, 0.88), CGRect(x: 0, y: 0, width: 6, height: faceH))
        let warpedEdge = warp(edge, CGPoint(x: tr.x, y: tr.y), CGPoint(x: tr.x + 6, y: tr.y - 4), CGPoint(x: br.x + 6, y: br.y + 4), CGPoint(x: br.x, y: br.y))
        out = warpedEdge.composited(over: out)
        return Gfx.render(out.cropped(to: ext), extent: ext)
    }

    private static func warp(_ img: CIImage, _ tl: CGPoint, _ tr: CGPoint, _ br: CGPoint, _ bl: CGPoint) -> CIImage {
        img.applyingFilter("CIPerspectiveTransform", parameters: [
            "inputTopLeft": CIVector(cgPoint: tl), "inputTopRight": CIVector(cgPoint: tr),
            "inputBottomRight": CIVector(cgPoint: br), "inputBottomLeft": CIVector(cgPoint: bl)
        ])
    }

    // MARK: Cover on its own blurred colors

    static func onBlurredGround(_ cover: CGImage, size: CGSize, coverHeightFraction: CGFloat, useBook: Bool, spine: CGImage? = nil) -> CGImage? {
        let W = Int(size.width), H = Int(size.height)
        guard let ctx = Gfx.context(W, H) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: W, height: H)
        // Ground: the cover itself, aspect-filled, heavily blurred and darkened.
        let src = CIImage(cgImage: cover)
        let s = max(size.width / src.extent.width, size.height / src.extent.height)
        var ground = src.transformed(by: CGAffineTransform(scaleX: s, y: s))
        ground = ground.transformed(by: CGAffineTransform(translationX: (size.width - ground.extent.width) / 2, y: (size.height - ground.extent.height) / 2))
        ground = FX.controls(FX.blur(ground.cropped(to: rect), size.width * 0.04), saturation: 1.1, brightness: -0.18, contrast: 0.9)
        if let g = Gfx.render(ground, W, H) { ctx.draw(g, in: rect) }

        if useBook, let book = book3D(cover, size: CGSize(width: H, height: H), spine: spine) {
            let side = size.height * 0.98
            ctx.draw(book, in: CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side))
        } else if coverHeightFraction > 0 {
            let h = size.height * coverHeightFraction
            let w = h * CGFloat(cover.width) / CGFloat(cover.height)
            let r = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -size.height * 0.012), blur: size.height * 0.04, color: CGColor(gray: 0, alpha: 0.6))
            ctx.draw(cover, in: r)
            ctx.restoreGState()
        }
        return ctx.makeImage()
    }

    // MARK: Devices

    /// A phone or tablet showing the cover on a reading-app screen.
    static func device(_ cover: CGImage, size: CGSize, aspect: CGFloat, cornerFactor: CGFloat, island: Bool) -> CGImage? {
        let W = Int(size.width), H = Int(size.height)
        guard let ctx = Gfx.context(W, H) else { return nil }
        let bodyH = size.height * 0.88
        let bodyW = bodyH * aspect
        let body = CGRect(x: (size.width - bodyW) / 2, y: (size.height - bodyH) / 2, width: bodyW, height: bodyH)
        let r = bodyW * cornerFactor
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -size.height * 0.015), blur: size.height * 0.05, color: CGColor(gray: 0, alpha: 0.5))
        ctx.addPath(CGPath(roundedRect: body, cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.setFillColor(RGBA(hex: "1A1A1C").cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        // Frame highlight
        ctx.addPath(CGPath(roundedRect: body.insetBy(dx: 2, dy: 2), cornerWidth: r - 2, cornerHeight: r - 2, transform: nil))
        ctx.setStrokeColor(RGBA(1, 1, 1, 0.18).cgColor)
        ctx.setLineWidth(3)
        ctx.strokePath()
        // Screen
        let screen = body.insetBy(dx: bodyW * 0.045, dy: bodyW * 0.045)
        let sr = max(4, r * 0.8)
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: screen, cornerWidth: sr, cornerHeight: sr, transform: nil))
        ctx.clip()
        ctx.setFillColor(RGBA(hex: "0E0E10").cgColor)
        ctx.fill(screen)
        let ch = screen.height * 0.82
        let cw = min(screen.width * 0.86, ch * CGFloat(cover.width) / CGFloat(cover.height))
        let chFit = cw * CGFloat(cover.height) / CGFloat(cover.width)
        let coverRect = CGRect(x: screen.midX - cw / 2, y: screen.midY - chFit / 2 + screen.height * 0.02, width: cw, height: chFit)
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 24, color: CGColor(gray: 0, alpha: 0.7))
        ctx.draw(cover, in: coverRect)
        ctx.restoreGState()
        guard island else { return ctx.makeImage() }
        // Dynamic island
        let islandRect = CGRect(x: body.midX - bodyW * 0.16, y: screen.maxY - bodyW * 0.1, width: bodyW * 0.32, height: bodyW * 0.065)
        ctx.addPath(CGPath(roundedRect: islandRect, cornerWidth: islandRect.height / 2, cornerHeight: islandRect.height / 2, transform: nil))
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fillPath()
        return ctx.makeImage()
    }
}

extension MockupRenderer {
    /// The 3D book in front of a phone, on a soft ground in the cover's own colors.
    static func duo(_ cover: CGImage, size: CGSize, spine: CGImage?, palette: PaletteRoles) -> CGImage? {
        let W = Int(size.width), H = Int(size.height)
        guard let ctx = Gfx.context(W, H) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: W, height: H)
        Gfx.linearGradient(ctx, rect, [palette.dark.withLightness(0.2), palette.dark.withLightness(0.08)], angle: 90)
        if let g = CGGradient(colorsSpace: Gfx.sRGB, colors: [palette.accent.withAlpha(0.35).cgColor, palette.accent.withAlpha(0).cgColor] as CFArray, locations: nil) {
            let c = CGPoint(x: size.width * 0.62, y: size.height * 0.55)
            ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: size.height * 0.7, options: [])
        }
        if let ph = device(cover, size: CGSize(width: H, height: H), aspect: 0.49, cornerFactor: 0.15, island: true) {
            ctx.draw(ph, in: CGRect(x: size.width * 0.5, y: 0, width: size.height, height: size.height))
        }
        if let book = book3D(cover, size: CGSize(width: H, height: H), spine: spine) {
            let side = size.height * 1.02
            ctx.draw(book, in: CGRect(x: size.width * 0.08, y: -size.height * 0.02, width: side, height: side))
        }
        return ctx.makeImage()
    }
}

/// Ad and promo sizes, laid out automatically: the 3D book beside (or above) a headline and a call to action.
enum AdKind: String, CaseIterable, Identifiable {
    case facebookFeed, instagramStory, xPost, pinterest, bookbub, amazonAPlus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .facebookFeed: return "Facebook Feed 1200 x 628"
        case .instagramStory: return "Instagram / TikTok Story 1080 x 1920"
        case .xPost: return "X / Bluesky Post 1600 x 900"
        case .pinterest: return "Pinterest Pin 1000 x 1500"
        case .bookbub: return "BookBub Ad 300 x 250"
        case .amazonAPlus: return "Amazon A+ Banner 970 x 600"
        }
    }

    var fileSuffix: String {
        switch self {
        case .facebookFeed: return "Ad Facebook"
        case .instagramStory: return "Ad Story"
        case .xPost: return "Ad X"
        case .pinterest: return "Ad Pinterest"
        case .bookbub: return "Ad BookBub"
        case .amazonAPlus: return "A+ Banner"
        }
    }

    var pixelSize: CGSize {
        switch self {
        case .facebookFeed: return CGSize(width: 1200, height: 628)
        case .instagramStory: return CGSize(width: 1080, height: 1920)
        case .xPost: return CGSize(width: 1600, height: 900)
        case .pinterest: return CGSize(width: 1000, height: 1500)
        case .bookbub: return CGSize(width: 300, height: 250)
        case .amazonAPlus: return CGSize(width: 970, height: 600)
        }
    }
}

enum AdRenderer {
    static func defaultHeadline(_ doc: CoverDocument) -> String {
        if !doc.book.tagline.isEmpty && doc.book.tagline.lowercased() != "a novel" { return doc.book.tagline }
        if !doc.paperback.quote.isEmpty { return doc.paperback.quote }
        return doc.book.author.isEmpty ? "The new novel" : "The new novel from \(doc.book.author)"
    }

    static func render(_ kind: AdKind, doc: CoverDocument, headline: String, cta: String) -> CGImage? {
        let size = kind.pixelSize
        let W = Int(size.width), H = Int(size.height)
        let coverH = 1000
        let coverW = Int((Double(coverH) / doc.canvas.aspect).rounded())
        guard let ctx = Gfx.context(W, H),
              let cover = CoverRenderer.shared.render(doc, size: CGSize(width: coverW, height: coverH), quality: .full),
              let ground = MockupRenderer.onBlurredGround(cover, size: size, coverHeightFraction: 0, useBook: false) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: W, height: H)
        ctx.draw(ground, in: rect)
        let p = PaletteRoles(doc.palette)
        let spine = MockupRenderer.spineImage(doc, coverHeight: coverH)
        let portrait = size.height > size.width * 1.15
        let titleFont = doc.textLayer(role: .title)?.textContent?.fontName ?? "Didot"
        let ctaFont = doc.textLayer(role: .author)?.textContent?.fontName ?? "AvenirNext-DemiBold"

        // Book
        let bookSide = portrait ? size.width * 1.0 : size.height * 1.05
        let bookRect = portrait
            ? CGRect(x: (size.width - bookSide) / 2, y: size.height - bookSide * 0.98, width: bookSide, height: bookSide)
            : CGRect(x: size.width * 0.01, y: (size.height - bookSide) / 2, width: bookSide, height: bookSide)
        let bookPx = max(200, Int(bookSide))
        if let book = MockupRenderer.book3D(cover, size: CGSize(width: bookPx, height: bookPx), spine: spine) {
            ctx.draw(book, in: bookRect)
        }

        // Copy block: top-left rect in a bottom-left context.
        let textArea: CGRect = portrait
            ? CGRect(x: size.width * 0.1, y: size.height * 0.08, width: size.width * 0.8, height: size.height - bookSide * 0.98 - size.height * 0.1)
            : CGRect(x: bookRect.maxX - size.width * 0.04, y: size.height * 0.16, width: size.width - bookRect.maxX - size.width * 0.02, height: size.height * 0.68)
        guard textArea.width > 20, textArea.height > 20 else { return ctx.makeImage() }
        let headH = textArea.height * 0.58
        var head = TextContent(text: TitleBreaker.balanced(headline, lines: headline.count > 28 ? 3 : 2), role: .custom, fontName: titleFont, color: p.light)
        head.lineHeight = 1.08
        if case let (img, pad)? = TextRenderer.render(head, box: CGSize(width: textArea.width, height: headH), canvasHeight: size.height) {
            ctx.draw(img, in: CGRect(x: textArea.minX - pad, y: textArea.maxY - headH - pad, width: CGFloat(img.width), height: CGFloat(img.height)))
        }
        // Call-to-action pill
        let pillH = min(textArea.height * 0.2, size.height * 0.11)
        let pillW = min(textArea.width, pillH * 5.2)
        let pill = CGRect(x: textArea.minX + (textArea.width - pillW) / 2, y: textArea.minY + textArea.height * 0.06, width: pillW, height: pillH)
        ctx.addPath(CGPath(roundedRect: pill, cornerWidth: pillH / 2, cornerHeight: pillH / 2, transform: nil))
        ctx.setFillColor(p.accent.cgColor)
        ctx.fillPath()
        var label = TextContent(text: cta.uppercased(), role: .custom, fontName: ctaFont,
                                color: ColorAdvisor.bestText(on: p.accent, candidates: [RGBA.nearWhite, p.dark], minimum: 4.5))
        label.tracking = 0.12
        let labelBox = CGSize(width: pillW * 0.78, height: pillH * 0.42)
        if case let (img, pad)? = TextRenderer.render(label, box: labelBox, canvasHeight: size.height) {
            ctx.draw(img, in: CGRect(x: pill.midX - labelBox.width / 2 - pad, y: pill.midY - labelBox.height / 2 - pad, width: CGFloat(img.width), height: CGFloat(img.height)))
        }
        return ctx.makeImage()
    }
}

/// Re-titles a design for another book in the same series, keeping every design decision.
enum SeriesKit {
    static func retitle(_ doc: CoverDocument, title: String, number: Int) -> CoverDocument {
        var d = doc
        var b = d.book
        let old = b
        b.title = title
        if !b.series.trimmingCharacters(in: .whitespaces).isEmpty {
            let base = b.series.replacingOccurrences(of: #",?\s*Book\s+\d+$"#, with: "", options: .regularExpression)
            b.series = "\(base), Book \(number)"
        }
        BookSync.apply(b, old: old, to: &d)
        return d
    }

    /// Side-by-side image of the whole series on a soft ground.
    static func lineup(_ docs: [CoverDocument], coverHeight: Int = 960) -> CGImage? {
        guard let first = docs.first else { return nil }
        let coverW = Int((Double(coverHeight) / first.canvas.aspect).rounded())
        let gap = coverHeight / 12
        let W = docs.count * coverW + (docs.count + 1) * gap
        let H = coverHeight + gap * 2
        guard let ctx = Gfx.context(W, H) else { return nil }
        ctx.setFillColor(RGBA(hex: "EEEBE5").cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        for (i, d) in docs.enumerated() {
            guard let img = CoverRenderer.shared.render(d, size: CGSize(width: coverW, height: coverHeight), quality: .full) else { continue }
            let r = CGRect(x: gap + i * (coverW + gap), y: gap, width: coverW, height: coverHeight)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 30, color: CGColor(gray: 0, alpha: 0.35))
            ctx.draw(img, in: r)
            ctx.restoreGState()
        }
        return ctx.makeImage()
    }
}

/// Keeps a cover's text layers in step with its brief.
enum BookSync {
    static func apply(_ b: BookInfo, old: BookInfo, to d: inout CoverDocument) {
        d.book = b
        for i in d.layers.indices {
            guard let t = d.layers[i].textContent else { continue }
            switch t.role {
            case .title where b.title != old.title:
                let stacked = t.text.contains("\n") && t.text.split(separator: "\n").count == old.title.split(separator: " ").count
                d.layers[i].textContent?.text = TitleBreaker.auto(b.title, stacked: stacked)
            case .author where b.author != old.author: d.layers[i].textContent?.text = b.author
            case .subtitle where b.subtitle != old.subtitle: d.layers[i].textContent?.text = b.subtitle
            case .series where b.series != old.series: d.layers[i].textContent?.text = b.series
            case .tagline where b.tagline != old.tagline: d.layers[i].textContent?.text = b.tagline
            default: break
            }
        }
    }
}
