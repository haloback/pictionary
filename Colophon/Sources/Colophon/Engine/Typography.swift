import AppKit
import CoreImage
import CoreText

/// Fonts that ship with macOS, grouped the way a cover designer thinks about them.
enum FontCatalog {
    enum Mood: String, CaseIterable, Identifiable {
        case didone = "Didone & High Contrast"
        case oldstyle = "Classic Serif"
        case slab = "Slab & Wedge"
        case sans = "Modern Sans"
        case condensed = "Condensed & Impact"
        case script = "Script & Hand"
        case display = "Display & Ornamental"
        var id: String { rawValue }
    }

    struct Entry: Identifiable, Hashable {
        let id: String
        let label: String
        let mood: Mood
    }

    static let curated: [Entry] = [
        Entry(id: "Didot", label: "Didot", mood: .didone),
        Entry(id: "Didot-Bold", label: "Didot Bold", mood: .didone),
        Entry(id: "Didot-Italic", label: "Didot Italic", mood: .didone),
        Entry(id: "BodoniSvtyTwoITCTT-Book", label: "Bodoni 72", mood: .didone),
        Entry(id: "BodoniSvtyTwoITCTT-Bold", label: "Bodoni 72 Bold", mood: .didone),
        Entry(id: "BodoniSvtyTwoSCITCTT-Book", label: "Bodoni 72 Small Caps", mood: .didone),
        Entry(id: "BigCaslon-Medium", label: "Big Caslon", mood: .didone),
        Entry(id: "Baskerville", label: "Baskerville", mood: .oldstyle),
        Entry(id: "Baskerville-SemiBold", label: "Baskerville Semibold", mood: .oldstyle),
        Entry(id: "Baskerville-Italic", label: "Baskerville Italic", mood: .oldstyle),
        Entry(id: "HoeflerText-Regular", label: "Hoefler Text", mood: .oldstyle),
        Entry(id: "HoeflerText-Black", label: "Hoefler Text Black", mood: .oldstyle),
        Entry(id: "HoeflerText-Italic", label: "Hoefler Text Italic", mood: .oldstyle),
        Entry(id: "Cochin", label: "Cochin", mood: .oldstyle),
        Entry(id: "Cochin-Bold", label: "Cochin Bold", mood: .oldstyle),
        Entry(id: "Palatino-Roman", label: "Palatino", mood: .oldstyle),
        Entry(id: "Palatino-Bold", label: "Palatino Bold", mood: .oldstyle),
        Entry(id: "Charter-Roman", label: "Charter", mood: .oldstyle),
        Entry(id: "Charter-Black", label: "Charter Black", mood: .oldstyle),
        Entry(id: "Optima-Regular", label: "Optima", mood: .oldstyle),
        Entry(id: "Optima-ExtraBlack", label: "Optima Extra Black", mood: .oldstyle),
        Entry(id: "Copperplate", label: "Copperplate", mood: .display),
        Entry(id: "Copperplate-Bold", label: "Copperplate Bold", mood: .display),
        Entry(id: "Superclarendon-Regular", label: "Superclarendon", mood: .slab),
        Entry(id: "Superclarendon-Black", label: "Superclarendon Black", mood: .slab),
        Entry(id: "Rockwell-Regular", label: "Rockwell", mood: .slab),
        Entry(id: "Rockwell-Bold", label: "Rockwell Bold", mood: .slab),
        Entry(id: "AmericanTypewriter-Bold", label: "American Typewriter", mood: .slab),
        Entry(id: "Futura-Medium", label: "Futura", mood: .sans),
        Entry(id: "Futura-Bold", label: "Futura Bold", mood: .sans),
        Entry(id: "AvenirNext-UltraLight", label: "Avenir Next Ultra Light", mood: .sans),
        Entry(id: "AvenirNext-Regular", label: "Avenir Next", mood: .sans),
        Entry(id: "AvenirNext-DemiBold", label: "Avenir Next Demi", mood: .sans),
        Entry(id: "AvenirNext-Heavy", label: "Avenir Next Heavy", mood: .sans),
        Entry(id: "GillSans-Light", label: "Gill Sans Light", mood: .sans),
        Entry(id: "GillSans", label: "Gill Sans", mood: .sans),
        Entry(id: "GillSans-Bold", label: "Gill Sans Bold", mood: .sans),
        Entry(id: "HelveticaNeue-Thin", label: "Helvetica Neue Thin", mood: .sans),
        Entry(id: "Futura-CondensedExtraBold", label: "Futura Condensed Extra Bold", mood: .condensed),
        Entry(id: "Futura-CondensedMedium", label: "Futura Condensed", mood: .condensed),
        Entry(id: "AvenirNextCondensed-Heavy", label: "Avenir Next Condensed Heavy", mood: .condensed),
        Entry(id: "AvenirNextCondensed-Bold", label: "Avenir Next Condensed Bold", mood: .condensed),
        Entry(id: "AvenirNextCondensed-UltraLight", label: "Avenir Next Condensed Ultra Light", mood: .condensed),
        Entry(id: "HelveticaNeue-CondensedBlack", label: "Helvetica Neue Condensed Black", mood: .condensed),
        Entry(id: "HelveticaNeue-CondensedBold", label: "Helvetica Neue Condensed Bold", mood: .condensed),
        Entry(id: "DINCondensed-Bold", label: "DIN Condensed", mood: .condensed),
        Entry(id: "DINAlternate-Bold", label: "DIN Alternate", mood: .condensed),
        Entry(id: "Impact", label: "Impact", mood: .condensed),
        Entry(id: "SnellRoundhand", label: "Snell Roundhand", mood: .script),
        Entry(id: "SnellRoundhand-Bold", label: "Snell Roundhand Bold", mood: .script),
        Entry(id: "Zapfino", label: "Zapfino", mood: .script),
        Entry(id: "SavoyeLetPlain", label: "Savoye", mood: .script),
        Entry(id: "BradleyHandITCTT-Bold", label: "Bradley Hand", mood: .script),
        Entry(id: "Trattatello", label: "Trattatello", mood: .display),
        Entry(id: "Luminari-Regular", label: "Luminari", mood: .display),
        Entry(id: "Herculanum", label: "Herculanum", mood: .display),
        Entry(id: "Phosphate-Inline", label: "Phosphate Inline", mood: .display),
        Entry(id: "Phosphate-Solid", label: "Phosphate Solid", mood: .display),
        Entry(id: "Skia-Regular", label: "Skia", mood: .display)
    ]

    static func isAvailable(_ name: String) -> Bool { NSFont(name: name, size: 12) != nil }

    static func ctFont(_ name: String, size: CGFloat) -> CTFont {
        if let f = NSFont(name: name, size: size) { return f as CTFont }
        return NSFont.systemFont(ofSize: size, weight: .bold) as CTFont
    }

    /// First installed font from a list of candidates.
    static func resolve(_ candidates: [String]) -> String {
        candidates.first(where: isAvailable) ?? "Helvetica-Bold"
    }

    static func displayName(_ postscript: String) -> String {
        curated.first { $0.id == postscript }?.label ?? (NSFont(name: postscript, size: 12)?.displayName ?? postscript)
    }

    static var installed: [String] { NSFontManager.shared.availableFonts }

    /// Makes an imported font file usable by this app. Returns its PostScript name.
    @discardableResult
    static func register(_ data: Data) -> String? {
        guard let provider = CGDataProvider(data: data as CFData), let cg = CGFont(provider),
              let name = cg.postScriptName as String? else { return nil }
        if NSFont(name: name, size: 12) == nil {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterGraphicsFont(cg, &error)
        }
        return name
    }

    static func family(_ postscript: String) -> String {
        NSFont(name: postscript, size: 12)?.familyName ?? postscript
    }
}

/// Splits a title into lines a designer would choose: balanced, never leaving a lonely short word.
enum TitleBreaker {
    static func balanced(_ title: String, lines n: Int) -> String {
        let words = title.split(separator: " ").map(String.init)
        guard n > 1, words.count > 1 else { return words.joined(separator: " ") }
        let lines = min(n, words.count)
        var best: [[String]] = [words]
        var bestScore = Double.greatestFiniteMagnitude
        func search(_ start: Int, _ remaining: Int, _ acc: [[String]]) {
            if remaining == 1 {
                let candidate = acc + [Array(words[start...])]
                let lens = candidate.map { Double($0.joined(separator: " ").count) }
                // Penalize the longest line, and short trailing lines (widows).
                let score = lens.max()! * 2 + (lens.max()! - lens.min()!) + (lens.last! < 4 ? 6 : 0)
                if score < bestScore { bestScore = score; best = candidate }
                return
            }
            guard start < words.count - remaining + 1 else { return }
            for end in (start + 1)...(words.count - remaining + 1) {
                search(end, remaining - 1, acc + [Array(words[start..<end])])
            }
        }
        search(0, lines, [])
        return best.map { $0.joined(separator: " ") }.joined(separator: "\n")
    }

    /// Picks a line count for the title. Stacked styles put each short word on its own line.
    static func auto(_ title: String, stacked: Bool, maxChars: Int = 13) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.contains("\n") { return clean }
        let words = clean.split(separator: " ")
        if words.isEmpty { return clean }
        if stacked && words.count <= 4 { return words.joined(separator: "\n") }
        for n in 1...4 {
            let t = balanced(clean, lines: n)
            if t.split(separator: "\n").allSatisfy({ $0.count <= maxChars }) { return t }
        }
        return balanced(clean, lines: 4)
    }
}

/// Typesets text with optical (glyph-bound) fitting, then renders fills, gradients, strokes and glows.
enum TextRenderer {
    struct Metrics {
        var lines: [CTLine]
        var bounds: [CGRect]
        var advance: CGFloat
        var width: CGFloat
        var height: CGFloat
        var top: CGFloat
        var fontSize: CGFloat
    }

    static func displayString(_ t: TextContent) -> String {
        switch t.letterCase {
        case .asTyped: return t.text
        case .upper: return t.text.uppercased()
        case .lower: return t.text.lowercased()
        case .title: return t.text.capitalized
        }
    }

    static func attributed(_ s: String, _ t: TextContent, size: CGFloat) -> NSAttributedString {
        let font = FontCatalog.ctFont(t.fontName, size: size)
        return NSAttributedString(string: s, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTKernAttributeName as String): NSNumber(value: t.tracking * Double(size)),
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): NSNumber(value: true)
        ])
    }

    private static func lineWidth(_ s: String, _ t: TextContent, _ size: CGFloat) -> CGFloat {
        let line = CTLineCreateWithAttributedString(attributed(s, t, size: size))
        return CTLineGetBoundsWithOptions(line, .useGlyphPathBounds).width
    }

    static func measure(_ t: TextContent, size: CGFloat, wrapWidth: CGFloat?) -> Metrics {
        let text = displayString(t)
        var lineStrings: [String] = []
        for para in text.components(separatedBy: "\n") {
            guard let wrap = wrapWidth, wrap > 0 else { lineStrings.append(para); continue }
            var current = ""
            for word in para.split(separator: " ", omittingEmptySubsequences: true) {
                let w = String(word)
                let candidate = current.isEmpty ? w : current + " " + w
                if !current.isEmpty && lineWidth(candidate, t, size) > wrap {
                    lineStrings.append(current)
                    current = w
                } else {
                    current = candidate
                }
            }
            lineStrings.append(current)
        }
        var lines: [CTLine] = []
        var bounds: [CGRect] = []
        for s in lineStrings {
            let line = CTLineCreateWithAttributedString(attributed(s.isEmpty ? " " : s, t, size: size))
            lines.append(line)
            var b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            if s.trimmingCharacters(in: .whitespaces).isEmpty || b.isNull || b.isInfinite { b = .zero }
            bounds.append(b)
        }
        let advance = size * CGFloat(t.lineHeight)
        let width = bounds.map(\.width).max() ?? 0
        let font = FontCatalog.ctFont(t.fontName, size: size)
        let first = bounds.first ?? .zero, last = bounds.last ?? .zero
        let top = first.height > 0 ? first.maxY : CTFontGetCapHeight(font)
        let bottom = last.height > 0 ? last.minY : 0
        let height = CGFloat(max(0, lines.count - 1)) * advance + top - bottom
        return Metrics(lines: lines, bounds: bounds, advance: advance, width: width, height: max(1, height), top: top, fontSize: size)
    }

    /// How far an arched line bends beyond its straight height, per unit of line width.
    static func sagFactor(_ arc: Double) -> CGFloat {
        let a = abs(arc)
        guard a > 0.001 else { return 0 }
        return CGFloat((1 - cos(a * .pi / 2)) / (a * .pi))
    }

    /// Size that makes the text exactly fill the box (glyph bounds scale linearly with size).
    static func fittedSize(_ t: TextContent, box: CGSize) -> CGFloat {
        let ref: CGFloat = 100
        let m = measure(t, size: ref, wrapWidth: nil)
        guard m.width > 0, m.height > 0 else { return max(2, box.height * 0.5) }
        let sag = m.width * sagFactor(t.arc)
        return max(2, min(box.width / m.width, box.height / (m.height + sag)) * ref * 0.995)
    }

    static func resolvedSize(_ t: TextContent, box: CGSize, canvasHeight: CGFloat) -> CGFloat {
        t.autoFit ? fittedSize(t, box: box) : max(2, CGFloat(t.fontSize) * canvasHeight)
    }

    private static func seed(_ s: String) -> Int {
        s.unicodeScalars.reduce(17) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    /// Returns the rendered text and the padding added around the box for strokes and glows.
    static func render(_ t: TextContent, box: CGSize, canvasHeight: CGFloat) -> (CGImage, CGFloat)? {
        guard box.width >= 1, box.height >= 1 else { return nil }
        let size = resolvedSize(t, box: box, canvasHeight: canvasHeight)
        let m = measure(t, size: size, wrapWidth: t.autoFit ? nil : box.width)
        let neon = t.texture == .neon
        let glowColor: RGBA? = neon ? t.color : t.glowColor
        let glowRadius = neon ? max(t.glowRadius, 0.35) : t.glowRadius
        var pad: CGFloat = 2
        if glowColor != nil { pad += size * CGFloat(glowRadius) * 1.6 }
        if t.strokeColor != nil { pad += size * CGFloat(t.strokeWidth) * 2 }
        let W = Int(ceil(box.width + 2 * pad)), H = Int(ceil(box.height + 2 * pad))
        guard let maskCtx = Gfx.grayContext(W, H), let fillCtx = Gfx.context(W, H), let out = Gfx.context(W, H) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: W, height: H)

        let sag = m.width * sagFactor(t.arc)
        let blockTop = pad + (box.height - (m.height + sag)) / 2 + (t.arc < 0 ? sag : 0)
        var positions: [CGPoint] = []
        for (i, b) in m.bounds.enumerated() {
            let baselineFromTop = blockTop + m.top + CGFloat(i) * m.advance
            let x: CGFloat
            switch t.alignment {
            case .left: x = pad - b.minX
            case .center: x = pad + (box.width - b.width) / 2 - b.minX
            case .right: x = pad + box.width - b.width - b.minX
            }
            positions.append(CGPoint(x: x, y: CGFloat(H) - baselineFromTop))
        }

        func drawLine(_ ctx: CGContext, _ i: Int) {
            let line = m.lines[i], pos = positions[i], b = m.bounds[i]
            guard abs(t.arc) > 0.001, b.width > 1 else {
                ctx.textPosition = pos
                CTLineDraw(line, ctx)
                return
            }
            // Set each glyph on a circle so the line arches.
            let R = b.width / (CGFloat(abs(t.arc)) * .pi)
            let sgn: CGFloat = t.arc > 0 ? 1 : -1
            let cx = pos.x + b.minX + b.width / 2
            let center = CGPoint(x: cx, y: pos.y - sgn * R)
            guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return }
            for run in runs {
                let count = CTRunGetGlyphCount(run)
                guard count > 0 else { continue }
                var glyphs = [CGGlyph](repeating: 0, count: count)
                var points = [CGPoint](repeating: .zero, count: count)
                var advances = [CGSize](repeating: .zero, count: count)
                CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
                CTRunGetPositions(run, CFRange(location: 0, length: 0), &points)
                CTRunGetAdvances(run, CFRange(location: 0, length: 0), &advances)
                let attrs = CTRunGetAttributes(run) as NSDictionary
                guard let fontValue = attrs[kCTFontAttributeName as String] else { continue }
                let font = fontValue as! CTFont
                for g in 0..<count {
                    let gx = pos.x + points[g].x + advances[g].width / 2
                    let phi = (gx - cx) / R
                    let p = CGPoint(x: center.x + R * sin(phi), y: center.y + sgn * R * cos(phi))
                    ctx.saveGState()
                    ctx.translateBy(x: p.x, y: p.y)
                    ctx.rotate(by: -sgn * phi)
                    var glyph = glyphs[g]
                    var origin = CGPoint(x: -advances[g].width / 2, y: points[g].y)
                    CTFontDrawGlyphs(font, &glyph, &origin, 1, ctx)
                    ctx.restoreGState()
                }
            }
        }
        func drawLines(_ ctx: CGContext) {
            ctx.textMatrix = .identity
            for i in m.lines.indices { drawLine(ctx, i) }
        }

        maskCtx.setFillColor(gray: 0, alpha: 1)
        maskCtx.fill(rect)
        maskCtx.setFillColor(gray: 1, alpha: 1)
        drawLines(maskCtx)
        guard let mask = maskCtx.makeImage() else { return nil }

        // Fill: flat, gradient, metal ramp or a hot neon core.
        let topY = CGFloat(H) - blockTop, bottomY = topY - m.height - sag
        var stops: [RGBA]?
        if let metal = t.texture.metalStops {
            stops = metal
        } else if neon {
            stops = [t.color.mixed(with: .white, 0.75), t.color.mixed(with: .white, 0.55)]
        } else if let g = t.gradientTo {
            stops = [t.color, g]
        }
        fillCtx.saveGState()
        fillCtx.clip(to: rect, mask: mask)
        if let stops, let grad = CGGradient(colorsSpace: Gfx.sRGB, colors: stops.map(\.cgColor) as CFArray, locations: nil) {
            fillCtx.drawLinearGradient(grad, start: CGPoint(x: 0, y: topY), end: CGPoint(x: 0, y: bottomY),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        } else {
            fillCtx.setFillColor(t.color.cgColor)
            fillCtx.fill(rect)
        }
        fillCtx.restoreGState()
        guard var fill = fillCtx.makeImage() else { return nil }
        fill = texture(fill, t.texture, size: size, seed: seed(t.text)) ?? fill

        if let s = t.strokeColor {
            out.setTextDrawingMode(.stroke)
            out.setLineWidth(size * CGFloat(t.strokeWidth) * 2)
            out.setLineJoin(.round)
            out.setStrokeColor(s.cgColor)
            drawLines(out)
            out.setTextDrawingMode(.fill)
        } else if t.texture.metalStops != nil {
            // A hairline edge gives foil its pressed-in look.
            out.setTextDrawingMode(.stroke)
            out.setLineWidth(max(1, size * 0.012))
            out.setStrokeColor(t.texture.metalStops!.last!.withAlpha(0.8).cgColor)
            drawLines(out)
            out.setTextDrawingMode(.fill)
        }
        if let glow = glowColor {
            out.saveGState()
            out.setShadow(offset: .zero, blur: size * CGFloat(glowRadius), color: glow.cgColor)
            out.draw(fill, in: rect)
            out.draw(fill, in: rect)
            if neon {
                out.setShadow(offset: .zero, blur: size * CGFloat(glowRadius) * 0.35, color: glow.cgColor)
                out.draw(fill, in: rect)
            }
            out.restoreGState()
        }
        out.draw(fill, in: rect)
        guard let img = out.makeImage() else { return nil }
        return (img, pad)
    }

    /// Surface treatments applied to the filled type.
    private static func texture(_ img: CGImage, _ tex: TextTexture, size: CGFloat, seed: Int) -> CGImage? {
        let ci = CIImage(cgImage: img)
        let e = ci.extent
        switch tex {
        case .none, .neon:
            return nil
        case .gold, .silver, .roseGold, .copper:
            // Fine sparkle in the foil.
            let sparkle = FX.noise(e, seed: seed, grainSize: max(1, size * 0.01), strength: 0.18)
            let out = FX.blend(sparkle, over: ci, mode: "CIOverlayBlendMode")
                .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: ci])
            return Gfx.render(out, extent: e)
        case .distressed, .wornPrint, .chalk:
            let fine = FX.noise(e, seed: seed, grainSize: max(1, size * (tex == .chalk ? 0.008 : 0.025)), strength: 1)
            let blotches = FX.smoothNoise(e, seed: seed &+ 7, cells: max(6, Int(e.width / max(1, size * 0.6))))
            let speckCut: Double = tex == .wornPrint ? 0.25 : (tex == .chalk ? 0.45 : 0.4)
            // Push noise to mostly white with dark holes, then multiply the two.
            let specks = FX.controls(fine, brightness: speckCut, contrast: 6)
            let wear = FX.controls(blotches, brightness: tex == .wornPrint ? 0.35 : 0.2, contrast: 4)
            let mask = FX.blend(specks, over: wear, mode: "CIMultiplyBlendMode")
            var out = ci.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: mask
            ])
            if tex == .chalk { out = FX.blur(out, max(0.5, size * 0.004)) }
            return Gfx.render(out.cropped(to: e), extent: e)
        }
    }
}
