import CoreGraphics
import CoreImage
import Foundation

/// Marketing images built from the finished cover: a 3D book, a social post, a phone and a square.
enum MockupKind: String, CaseIterable, Identifiable {
    case book3D, social, phone, tablet, duo, square
    case physicalFront, physicalBack, physicalFlat, physicalStack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .book3D: return "3D Book (transparent PNG)"
        case .social: return "Social Post 1080 x 1080"
        case .phone: return "Phone Mockup (transparent PNG)"
        case .tablet: return "Tablet Mockup (transparent PNG)"
        case .duo: return "Book and Phone Scene 2400 x 1600"
        case .square: return "Square Cover 3000 x 3000"
        case .physicalFront: return "Paperback, front"
        case .physicalBack: return "Paperback, back"
        case .physicalFlat: return "Cover wrap, flat"
        case .physicalStack: return "Stack of three"
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
        case .physicalFront: return "Paperback Front"
        case .physicalBack: return "Paperback Back"
        case .physicalFlat: return "Wrap Flat"
        case .physicalStack: return "Stack"
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
        case .physicalFront, .physicalBack: return CGSize(width: 1600, height: 1600)
        case .physicalFlat: return CGSize(width: 2000, height: 1400)
        case .physicalStack: return CGSize(width: 1600, height: 1600)
        }
    }

    /// Transparent mockups must be PNG; the rest can follow the export format.
    var needsAlpha: Bool { self == .book3D || self == .phone || self == .tablet }
}

enum MockupRenderer {
    static func render(_ kind: MockupKind, doc: CoverDocument) -> CGImage? {
        // The physical mockups work from the print wrap, not the flat cover.
        switch kind {
        case .physicalFront: return physicalFront(doc, size: kind.pixelSize)
        case .physicalBack: return physicalBack(doc, size: kind.pixelSize)
        case .physicalFlat: return physicalFlat(doc, size: kind.pixelSize)
        case .physicalStack: return physicalStack(doc, size: kind.pixelSize)
        default: break
        }
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
        case .physicalFront, .physicalBack, .physicalFlat, .physicalStack: return nil
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

    static func warp(_ img: CIImage, _ tl: CGPoint, _ tr: CGPoint, _ br: CGPoint, _ bl: CGPoint) -> CIImage {
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

// MARK: - Physical book mockups, built from the print wrap

extension MockupRenderer {
    /// The three printed panels of the wrap, trimmed to size (no bleed): what the reader holds.
    static func wrapParts(_ doc: CoverDocument, dpi: Double = 60) -> (front: CGImage, spine: CGImage, back: CGImage)? {
        guard let wrap = PrintWrap.render(doc, dpi: dpi) else { return nil }
        let g = PrintWrap.Geometry(settings: doc.paperback, dpi: dpi)
        let bleed = g.px(PrintSettings.bleed)
        let h = max(1, g.size.height - 2 * bleed)
        // Every panel spans the full height, so the top-left rects read the same in the image's bottom-left space.
        let backR = CGRect(x: bleed, y: bleed, width: max(1, g.backRect.width - bleed), height: h)
        let spineR = CGRect(x: g.spineRect.minX, y: bleed, width: max(1, g.spineRect.width), height: h)
        let frontR = CGRect(x: g.frontRect.minX, y: bleed, width: max(1, g.frontRect.width - bleed), height: h)
        guard let front = wrap.cropping(to: frontR.integral),
              let spine = wrap.cropping(to: spineR.integral),
              let back = wrap.cropping(to: backR.integral) else { return nil }
        return (front, spine, back)
    }

    /// A standing paperback at a three-quarter angle: the real front and spine, pages showing at the fore-edge.
    static func physicalFront(_ doc: CoverDocument, size: CGSize) -> CGImage? {
        physicalStanding(doc, size: size, back: false)
    }

    /// The same book turned around: back cover and spine, so the blurb and barcode read.
    static func physicalBack(_ doc: CoverDocument, size: CGSize) -> CGImage? {
        physicalStanding(doc, size: size, back: true)
    }

    /// Wrap resolution for a book whose cover will stand `coverHeight` pixels tall.
    private static func wrapDPI(_ doc: CoverDocument, coverHeight: CGFloat) -> Double {
        min(130, max(24, Double(coverHeight) / max(0.5, doc.paperback.trimHeight)))
    }

    private static func physicalStanding(_ doc: CoverDocument, size: CGSize, back: Bool) -> CGImage? {
        let W = Int(size.width), H = Int(size.height)
        let dpi = wrapDPI(doc, coverHeight: size.height * 0.7)
        guard W > 0, H > 0, let parts = wrapParts(doc, dpi: dpi), let ctx = Gfx.context(W, H) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: W, height: H)
        if let ground = onBlurredGround(parts.front, size: size, coverHeightFraction: 0, useBook: false) { ctx.draw(ground, in: rect) }
        let ratio = CGFloat(doc.paperback.spineWidth / max(0.1, doc.paperback.trimWidth))
        let book = standingBook(face: back ? parts.back : parts.front, spine: parts.spine, spineRatio: ratio, size: size, spineOnLeft: !back)
        if let img = Gfx.render(book, W, H) { ctx.draw(img, in: rect) }
        return ctx.makeImage()
    }

    /// The page block's cut edge: cream stock with a fine line per leaf. Lines run vertically for a standing book.
    static func pageEdge(width: Int, height: Int, vertical: Bool) -> CIImage {
        let w = max(2, width), h = max(2, height)
        let extent = CGRect(x: 0, y: 0, width: w, height: h)
        let cream = RGBA(hex: "F1EAD9")
        guard let ctx = Gfx.context(w, h) else { return FX.solid(cream, extent) }
        ctx.setFillColor(cream.cgColor)
        ctx.fill(extent)
        ctx.setFillColor(RGBA(hex: "C9BFA8").withAlpha(0.75).cgColor)
        let across = vertical ? w : h
        var rng = SeededRNG(seed: 11)
        var p = 1
        while p < across - 1 {
            if vertical {
                ctx.fill(CGRect(x: p, y: 0, width: 1, height: h))
            } else {
                ctx.fill(CGRect(x: 0, y: p, width: w, height: 1))
            }
            p += rng.unit() < 0.5 ? 2 : 3
        }
        guard let img = ctx.makeImage() else { return FX.solid(cream, extent) }
        return CIImage(cgImage: img)
    }

    /// The standing book as a transparent composite: contact shadow, page block, spine, then the lit face.
    /// `spineOnLeft` is the front view; the back view mirrors the layout without mirroring the artwork.
    private static func standingBook(face: CGImage, spine: CGImage, spineRatio: CGFloat, size: CGSize, spineOnLeft: Bool) -> CIImage {
        let aspect = CGFloat(face.height) / CGFloat(max(1, face.width))
        let faceH = size.height * 0.70
        let fullW = faceH / aspect
        let faceW = fullW * 0.88
        let spineW = max(6, fullW * spineRatio * 0.62)
        let pagesW = max(3, spineW * 0.38)
        let bottom = size.height * 0.16
        let top = bottom + faceH
        let faceLeft = (size.width - (faceW + spineW)) / 2 + spineW
        let faceRight = faceLeft + faceW
        let tilt = faceH * 0.04
        let tiltS = faceH * 0.018

        func m(_ p: CGPoint) -> CGPoint { spineOnLeft ? p : CGPoint(x: size.width - p.x, y: p.y) }
        func quad(_ img: CIImage, _ tl: CGPoint, _ tr: CGPoint, _ br: CGPoint, _ bl: CGPoint) -> CIImage {
            spineOnLeft ? warp(img, tl, tr, br, bl) : warp(img, m(tr), m(tl), m(bl), m(br))
        }

        let tl = CGPoint(x: faceLeft, y: top)
        let tr = CGPoint(x: faceRight, y: top - tilt)
        let br = CGPoint(x: faceRight, y: bottom + tilt)
        let bl = CGPoint(x: faceLeft, y: bottom)
        let faceCI = CIImage(cgImage: face)
        let spineCI = CIImage(cgImage: spine).applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -0.4])

        // Contact shadow on the ground.
        let shadowX = m(CGPoint(x: faceLeft + faceW * 0.4, y: 0)).x
        let shadowExtent = CGRect(x: -faceW, y: -faceW, width: faceW * 2, height: faceW * 2)
        let shadowMove = CGAffineTransform(scaleX: 1, y: 0.1).concatenating(CGAffineTransform(translationX: shadowX, y: bottom + size.height * 0.005))
        var out = FX.radial(center: .zero, r0: 0, r1: faceW * 0.7, c0: RGBA(0, 0, 0, 0.6), c1: RGBA(0, 0, 0, 0), extent: shadowExtent)
            .transformed(by: shadowMove)

        // Page block peeking out at the fore-edge, behind the face, darker as it turns away.
        let pages = pageEdge(width: Int(pagesW.rounded(.up)) + 2, height: Int(faceH), vertical: true)
        let pageShade = FX.linear(CGPoint(x: 0, y: 0), CGPoint(x: pages.extent.width, y: 0), RGBA(0, 0, 0, 0), RGBA(0, 0, 0, 0.35), extent: pages.extent)
        let pagesShaded = pageShade.composited(over: pages)
        let pTL = CGPoint(x: faceRight - 1, y: top - tilt - 1)
        let pTR = CGPoint(x: faceRight + pagesW, y: top - tilt - pagesW * 0.6)
        let pBR = CGPoint(x: faceRight + pagesW, y: bottom + tilt + pagesW * 0.6)
        let pBL = CGPoint(x: faceRight - 1, y: bottom + tilt + 1)
        out = quad(pagesShaded, pTL, pTR, pBR, pBL).composited(over: out)

        // Spine, turned toward the viewer.
        let sTL = CGPoint(x: faceLeft - spineW, y: top - tiltS)
        let sBL = CGPoint(x: faceLeft - spineW, y: bottom + tiltS)
        out = quad(spineCI, sTL, tl, bl, sBL).composited(over: out)

        // Face: a hinge shadow and a curl highlight where the cover bends round the spine, then a soft sheen.
        let fw = faceCI.extent.width, fh = faceCI.extent.height
        let hingeX: CGFloat = spineOnLeft ? 0 : fw
        let dir: CGFloat = spineOnLeft ? 1 : -1
        let hinge = FX.linear(CGPoint(x: hingeX, y: 0), CGPoint(x: hingeX + dir * fw * 0.06, y: 0), RGBA(0, 0, 0, 0.35), RGBA(0, 0, 0, 0), extent: faceCI.extent)
        let curl = FX.linear(CGPoint(x: hingeX + dir * fw * 0.04, y: 0), CGPoint(x: hingeX + dir * fw * 0.14, y: 0), RGBA(1, 1, 1, 0.32), RGBA(1, 1, 1, 0), extent: faceCI.extent)
        let sheen = FX.linear(CGPoint(x: 0, y: fh), CGPoint(x: fw, y: 0), RGBA(1, 1, 1, 0.16), RGBA(1, 1, 1, 0), extent: faceCI.extent)
        var lit = hinge.composited(over: faceCI)
        lit = FX.blend(curl, over: lit, mode: "CIScreenBlendMode")
        lit = FX.blend(sheen, over: lit, mode: "CIScreenBlendMode")
        out = quad(lit, tl, tr, br, bl).composited(over: out)
        return out.cropped(to: CGRect(origin: .zero, size: size))
    }

    /// The open wrap lying flat on a table at a slight perspective: no guides, a paper texture and a soft shadow.
    static func physicalFlat(_ doc: CoverDocument, size: CGSize) -> CGImage? {
        let W = Int(size.width), H = Int(size.height)
        let pb = doc.paperback
        let dpi = min(130, max(24, Double(size.width) * 0.9 / max(0.5, pb.fullWidth)))
        guard W > 0, H > 0, let wrap = PrintWrap.render(doc, dpi: dpi, guides: false), let ctx = Gfx.context(W, H) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: W, height: H)

        // Table: a dark ground in the cover's own ink, lit from above.
        let p = PaletteRoles(doc.palette)
        Gfx.linearGradient(ctx, rect, [p.dark.withLightness(0.22), p.dark.withLightness(0.1)], angle: 90)
        let lampColors = [RGBA(1, 1, 1, 0.1).cgColor, RGBA(1, 1, 1, 0).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: Gfx.sRGB, colors: lampColors, locations: nil) {
            let c = CGPoint(x: size.width * 0.5, y: size.height * 0.62)
            ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: size.width * 0.6, options: [])
        }

        // The wrap, textured like uncoated stock, receding slightly toward the top.
        let src = CIImage(cgImage: wrap)
        let paper = FX.grain(src, seed: 5, strength: 0.14, size: 1.5)
        let aspect = src.extent.height / max(1, src.extent.width)
        let bottomW = size.width * 0.86
        let topW = bottomW * 0.9
        let h = min(size.height * 0.78, bottomW * aspect * 0.82)
        let cx = size.width / 2, cy = size.height / 2
        let tl = CGPoint(x: cx - topW / 2, y: cy + h / 2)
        let tr = CGPoint(x: cx + topW / 2, y: cy + h / 2)
        let br = CGPoint(x: cx + bottomW / 2, y: cy - h / 2)
        let bl = CGPoint(x: cx - bottomW / 2, y: cy - h / 2)

        let drop = size.height * 0.025
        let shTL = CGPoint(x: tl.x - drop * 0.3, y: tl.y - drop)
        let shTR = CGPoint(x: tr.x + drop * 0.3, y: tr.y - drop)
        let shBR = CGPoint(x: br.x + drop * 0.5, y: br.y - drop)
        let shBL = CGPoint(x: bl.x - drop * 0.5, y: bl.y - drop)
        var out = warp(FX.solid(RGBA(0, 0, 0, 0.55), src.extent), shTL, shTR, shBR, shBL)
            .applyingGaussianBlur(sigma: Double(size.height * 0.015))
        out = warp(paper, tl, tr, br, bl).composited(over: out)
        // Light falling across the sheet from the top left.
        let light = FX.linear(CGPoint(x: 0, y: src.extent.height), CGPoint(x: src.extent.width, y: 0), RGBA(1, 1, 1, 0.12), RGBA(0, 0, 0, 0.12), extent: src.extent)
        out = warp(light, tl, tr, br, bl).composited(over: out)
        if let img = Gfx.render(out.cropped(to: rect), W, H) { ctx.draw(img, in: rect) }
        return ctx.makeImage()
    }

    /// Three copies stacked and fanned on a table, fronts up and spines toward the viewer's left: the bookstore table.
    static func physicalStack(_ doc: CoverDocument, size: CGSize) -> CGImage? {
        let W = Int(size.width), H = Int(size.height)
        let pb = doc.paperback
        let dpi = min(130, max(24, Double(size.width) * 0.55 / max(0.5, pb.trimWidth)))
        guard W > 0, H > 0, let parts = wrapParts(doc, dpi: dpi), let ctx = Gfx.context(W, H) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: W, height: H)
        if let ground = onBlurredGround(parts.front, size: size, coverHeightFraction: 0, useBook: false) { ctx.draw(ground, in: rect) }

        // Table-plane projection: u across the book (spine at u = 0), v away from the viewer (tail at v = 0), z up.
        let w = size.width * 0.5
        let d = w * CGFloat(pb.trimHeight / max(0.1, pb.trimWidth))
        let t = max(4, w * CGFloat(pb.spineWidth / max(0.1, pb.trimWidth)) * 0.95)
        let k: CGFloat = 0.5
        let sx: CGFloat = 0.55
        let angles: [CGFloat] = [-0.12, 0.03, 0.15]
        let shifts: [CGPoint] = [CGPoint(x: 0, y: 0), CGPoint(x: w * 0.05, y: d * 0.03), CGPoint(x: w * 0.1, y: -d * 0.02)]
        func project(_ u: CGFloat, _ v: CGFloat, _ z: CGFloat, _ i: Int) -> CGPoint {
            let a = angles[i]
            let x = u * cos(a) - v * sin(a) + shifts[i].x + sx * z
            let y = k * (u * sin(a) + v * cos(a) + shifts[i].y) + z
            return CGPoint(x: x, y: y)
        }
        // Centre the whole stack in the frame.
        var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        let corners: [(CGFloat, CGFloat)] = [(0, 0), (w, 0), (w, d), (0, d)]
        for i in 0..<3 {
            for (u, v) in corners {
                for z in [CGFloat(i) * t, CGFloat(i + 1) * t] {
                    let q = project(u, v, z, i)
                    minX = min(minX, q.x); maxX = max(maxX, q.x)
                    minY = min(minY, q.y); maxY = max(maxY, q.y)
                }
            }
        }
        let off = CGPoint(x: (size.width - (minX + maxX)) / 2, y: (size.height - (minY + maxY)) / 2)
        func P(_ u: CGFloat, _ v: CGFloat, _ z: CGFloat, _ i: Int) -> CGPoint {
            let q = project(u, v, z, i)
            return CGPoint(x: q.x + off.x, y: q.y + off.y)
        }

        let face = CIImage(cgImage: parts.front)
        let spine = CIImage(cgImage: parts.spine).applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -0.5])
        let pages = pageEdge(width: Int(w), height: Int(t.rounded(.up)) + 2, vertical: false)
            .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -0.25])
        let sheen = FX.linear(CGPoint(x: 0, y: face.extent.height), CGPoint(x: face.extent.width, y: 0), RGBA(1, 1, 1, 0.14), RGBA(1, 1, 1, 0), extent: face.extent)
        let lit = FX.blend(sheen, over: face, mode: "CIScreenBlendMode")

        // Shadow under the bottom copy.
        let shadowDrop = size.height * 0.012
        func down(_ q: CGPoint) -> CGPoint { CGPoint(x: q.x, y: q.y - shadowDrop) }
        let s0 = down(P(-w * 0.03, d * 1.03, 0, 0)), s1 = down(P(w * 1.03, d * 1.03, 0, 0))
        let s2 = down(P(w * 1.03, -d * 0.03, 0, 0)), s3 = down(P(-w * 0.03, -d * 0.03, 0, 0))
        var out = warp(FX.solid(RGBA(0, 0, 0, 0.6), face.extent), s0, s1, s2, s3)
            .applyingGaussianBlur(sigma: Double(size.height * 0.012))

        for i in 0..<3 {
            let z0 = CGFloat(i) * t, z1 = z0 + t
            // Fore-edge pages along the tail.
            out = warp(pages, P(0, 0, z1, i), P(w, 0, z1, i), P(w, 0, z0, i), P(0, 0, z0, i)).composited(over: out)
            // Spine along the left side, head away from the viewer.
            out = warp(spine, P(0, d, z0, i), P(0, d, z1, i), P(0, 0, z1, i), P(0, 0, z0, i)).composited(over: out)
            // Front cover on top.
            out = warp(lit, P(0, d, z1, i), P(w, d, z1, i), P(w, 0, z1, i), P(0, 0, z1, i)).composited(over: out)
        }
        if let img = Gfx.render(out.cropped(to: rect), W, H) { ctx.draw(img, in: rect) }
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
        // A supporting line typed into the brief appears on the cover; clearing it removes the line.
        for role in SupportingText.roles where SupportingText.text(role, b) != SupportingText.text(role, old) {
            if SupportingText.text(role, b).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                d.layers.removeAll { $0.textContent?.role == role }
            } else {
                SupportingText.ensure(role, in: &d)
            }
        }
    }
}
