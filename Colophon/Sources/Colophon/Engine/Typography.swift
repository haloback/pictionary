import AppKit
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

    /// Size that makes the text exactly fill the box (glyph bounds scale linearly with size).
    static func fittedSize(_ t: TextContent, box: CGSize) -> CGFloat {
        let ref: CGFloat = 100
        let m = measure(t, size: ref, wrapWidth: nil)
        guard m.width > 0, m.height > 0 else { return max(2, box.height * 0.5) }
        return max(2, min(box.width / m.width, box.height / m.height) * ref * 0.995)
    }

    static func resolvedSize(_ t: TextContent, box: CGSize, canvasHeight: CGFloat) -> CGFloat {
        t.autoFit ? fittedSize(t, box: box) : max(2, CGFloat(t.fontSize) * canvasHeight)
    }

    /// Returns the rendered text and the padding added around the box for strokes and glows.
    static func render(_ t: TextContent, box: CGSize, canvasHeight: CGFloat) -> (CGImage, CGFloat)? {
        guard box.width >= 1, box.height >= 1 else { return nil }
        let size = resolvedSize(t, box: box, canvasHeight: canvasHeight)
        let m = measure(t, size: size, wrapWidth: t.autoFit ? nil : box.width)
        var pad: CGFloat = 2
        if t.glowColor != nil { pad += size * CGFloat(t.glowRadius) * 1.6 }
        if t.strokeColor != nil { pad += size * CGFloat(t.strokeWidth) * 2 }
        let W = Int(ceil(box.width + 2 * pad)), H = Int(ceil(box.height + 2 * pad))
        guard let maskCtx = Gfx.grayContext(W, H), let fillCtx = Gfx.context(W, H), let out = Gfx.context(W, H) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: W, height: H)

        let blockTop = pad + (box.height - m.height) / 2
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
        func drawLines(_ ctx: CGContext) {
            ctx.textMatrix = .identity
            for (i, l) in m.lines.enumerated() {
                ctx.textPosition = positions[i]
                CTLineDraw(l, ctx)
            }
        }

        maskCtx.setFillColor(gray: 0, alpha: 1)
        maskCtx.fill(rect)
        maskCtx.setFillColor(gray: 1, alpha: 1)
        drawLines(maskCtx)
        guard let mask = maskCtx.makeImage() else { return nil }

        fillCtx.saveGState()
        fillCtx.clip(to: rect, mask: mask)
        if let g = t.gradientTo {
            // Top of the type to its bottom.
            let topY = CGFloat(H) - blockTop, bottomY = topY - m.height
            if let grad = CGGradient(colorsSpace: Gfx.sRGB, colors: [t.color.cgColor, g.cgColor] as CFArray, locations: nil) {
                fillCtx.drawLinearGradient(grad, start: CGPoint(x: 0, y: topY), end: CGPoint(x: 0, y: bottomY),
                                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
        } else {
            fillCtx.setFillColor(t.color.cgColor)
            fillCtx.fill(rect)
        }
        fillCtx.restoreGState()
        guard let fill = fillCtx.makeImage() else { return nil }

        if let s = t.strokeColor {
            out.setTextDrawingMode(.stroke)
            out.setLineWidth(size * CGFloat(t.strokeWidth) * 2)
            out.setLineJoin(.round)
            out.setStrokeColor(s.cgColor)
            drawLines(out)
            out.setTextDrawingMode(.fill)
        }
        if let glow = t.glowColor {
            out.saveGState()
            out.setShadow(offset: .zero, blur: size * CGFloat(t.glowRadius), color: glow.cgColor)
            out.draw(fill, in: rect)
            out.draw(fill, in: rect)
            out.restoreGState()
        }
        out.draw(fill, in: rect)
        guard let img = out.makeImage() else { return nil }
        return (img, pad)
    }
}
