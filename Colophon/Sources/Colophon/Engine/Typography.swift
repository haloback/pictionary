import AppKit
import CoreImage
import CoreText

/// Fonts that ship with macOS, grouped the way a cover designer thinks about them.
enum FontCatalog {
    enum Mood: String, CaseIterable, Identifiable {
        case fantasy = "Fantasy & Medieval"
        case horror = "Horror & Grunge"
        case scifi = "Sci-Fi & Tech"
        case deco = "Art Deco & Retro"
        case brush = "Brush & Marker"
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

    static var curated: [Entry] { BundledFonts.entries + systemCurated }

    static let systemCurated: [Entry] = [
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

    static func isAvailable(_ name: String) -> Bool {
        _ = BundledFonts.registered
        return NSFont(name: name, size: 12) != nil
    }

    static func ctFont(_ name: String, size: CGFloat) -> CTFont {
        _ = BundledFonts.registered
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
    /// Words a line should not end on ("the", "of"...): the reader expects what follows on the same line.
    static let connectives: Set<String> = ["the", "of", "a", "an", "and", "in", "to", "for", "or", "at", "on", "by", "with"]

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

    static func isConnective(_ word: String) -> Bool {
        let clean = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        return connectives.contains(clean)
    }

    /// Letters in a word, ignoring quotes and punctuation.
    static func letterCount(_ word: String) -> Int {
        word.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
    }

    /// Balanced breaking scored by real measured widths. Lines never end on a connective and the last
    /// line is never one short word, unless every split would have to.
    static func balanced(_ title: String, lines n: Int, measure: (String) -> Double) -> String {
        let words = title.split(separator: " ").map(String.init)
        guard n > 1, words.count > 1 else { return words.joined(separator: " ") }
        let lines = min(n, words.count)
        var best: [[String]] = [words]
        var bestScore = Double.greatestFiniteMagnitude
        var widthCache: [String: Double] = [:]
        func width(_ s: String) -> Double {
            if let w = widthCache[s] { return w }
            let w = max(0, measure(s))
            widthCache[s] = w
            return w
        }
        func search(_ start: Int, _ remaining: Int, _ acc: [[String]]) {
            if remaining == 1 {
                let candidate = acc + [Array(words[start...])]
                let widths = candidate.map { width($0.joined(separator: " ")) }
                let longest = widths.max()!, shortest = widths.min()!
                var score = longest * 2 + (longest - shortest)
                // A line ending on "the" or "of" reads as a mistake: push it out unless nothing else works.
                for line in candidate.dropLast() where isConnective(line.last!) { score += longest * 2 }
                if let last = candidate.last, last.count == 1, letterCount(last[0]) < 4 { score += longest * 0.4 }
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
        /// Baseline-to-baseline distance at the uniform size.
        var advance: CGFloat
        var width: CGFloat
        var height: CGFloat
        var top: CGFloat
        var fontSize: CGFloat
        /// Each line's own size (all equal unless the text uses block fit).
        var sizes: [CGFloat] = []
        /// Each line's baseline measured down from the top of the block.
        var baselines: [CGFloat] = []
        /// Horizontal shift per line that hangs leading/trailing punctuation outside the text edge.
        var hang: [CGFloat] = []

        func lineSize(_ line: Int) -> CGFloat { line < sizes.count ? sizes[line] : fontSize }
        func baselineOffset(_ line: Int) -> CGFloat { line < baselines.count ? baselines[line] : top + CGFloat(line) * advance }
        func hangOffset(_ line: Int) -> CGFloat { line < hang.count ? hang[line] : 0 }
    }

    static func applyCase(_ s: String, _ c: LetterCase) -> String {
        switch c {
        case .asTyped, .smallCaps: return s
        case .upper: return s.uppercased()
        case .lower: return s.lowercased()
        case .title: return s.capitalized
        }
    }

    static func displayString(_ t: TextContent) -> String {
        applyCase(t.text, t.letterCase)
    }

    // MARK: - Tracking

    /// Tracking in ems after the optical adjustment: display sizes tighten, small caps open up.
    /// `canvasHeight` 0 means no adjustment.
    static func effectiveTracking(_ t: TextContent, size: CGFloat, canvasHeight: CGFloat) -> Double {
        guard t.opticalTracking, canvasHeight > 0, size > 0 else { return t.tracking }
        let cap = CTFontGetCapHeight(FontCatalog.ctFont(t.fontName, size: size))
        let ratio = Double(cap / canvasHeight)
        var adjustment = 0.0
        if ratio >= 0.14 {
            adjustment = -0.025
        } else if ratio >= 0.09 {
            adjustment = -0.015
        } else if ratio <= 0.016, t.letterCase == .upper || t.letterCase == .smallCaps {
            adjustment = 0.03
        }
        let lowest = min(t.tracking, -0.06)
        return max(lowest, t.tracking + adjustment)
    }

    // MARK: - Small caps

    private static let smallCapsLock = NSLock()
    private static var smallCapsSupport: [String: Bool] = [:]
    /// Synthesized small caps draw converted lowercase letters at this share of the size.
    static let synthesizedSmallCapScale: CGFloat = 0.78

    private static func firstGlyph(_ s: String, _ font: CTFont) -> CGGlyph {
        let attr = NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(attr)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun], let run = runs.first, CTRunGetGlyphCount(run) > 0 else { return 0 }
        var glyph: CGGlyph = 0
        CTRunGetGlyphs(run, CFRange(location: 0, length: 1), &glyph)
        return glyph
    }

    /// The font with its small-caps feature switched on, or nil when the face has no such feature.
    static func nativeSmallCapsFont(_ name: String, size: CGFloat) -> CTFont? {
        let base = FontCatalog.ctFont(name, size: size)
        let feature: [String: Any] = [
            kCTFontFeatureTypeIdentifierKey as String: kLowerCaseType,
            kCTFontFeatureSelectorIdentifierKey as String: kLowerCaseSmallCapsSelector
        ]
        let attrs: [String: Any] = [kCTFontFeatureSettingsAttribute as String: [feature]]
        let descriptor = CTFontDescriptorCreateWithAttributes(attrs as CFDictionary)
        let font = CTFontCreateCopyWithAttributes(base, size, nil, descriptor)
        smallCapsLock.lock()
        defer { smallCapsLock.unlock() }
        if let known = smallCapsSupport[name] { return known ? font : nil }
        // The feature only counts if it changes the glyph a lowercase letter shapes to.
        let supported = firstGlyph("a", font) != firstGlyph("a", base)
        smallCapsSupport[name] = supported
        return supported ? font : nil
    }

    static func hasNativeSmallCaps(_ name: String) -> Bool {
        nativeSmallCapsFont(name, size: 24) != nil
    }

    private static func attributes(_ font: CTFont, kern: Double) -> [NSAttributedString.Key: Any] {
        [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTKernAttributeName as String): NSNumber(value: kern),
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): NSNumber(value: true)
        ]
    }

    /// Small caps built by hand: lowercase letters become capitals at a reduced size, kerning kept.
    private static func synthesizedSmallCaps(_ s: String, _ t: TextContent, size: CGFloat, tracking: Double) -> NSAttributedString {
        let fullFont = FontCatalog.ctFont(t.fontName, size: size)
        let smallSize = size * synthesizedSmallCapScale
        let smallFont = FontCatalog.ctFont(t.fontName, size: smallSize)
        let out = NSMutableAttributedString()
        var run = ""
        var runIsSmall = false
        func flush() {
            guard !run.isEmpty else { return }
            if runIsSmall {
                out.append(NSAttributedString(string: run.uppercased(), attributes: attributes(smallFont, kern: tracking * Double(smallSize))))
            } else {
                out.append(NSAttributedString(string: run, attributes: attributes(fullFont, kern: tracking * Double(size))))
            }
            run = ""
        }
        for ch in s {
            let small = ch.isLowercase
            if small != runIsSmall { flush(); runIsSmall = small }
            run.append(ch)
        }
        flush()
        if out.length == 0 {
            out.append(NSAttributedString(string: " ", attributes: attributes(fullFont, kern: tracking * Double(size))))
        }
        return out
    }

    static func attributed(_ s: String, _ t: TextContent, size: CGFloat, canvasHeight: CGFloat = 0) -> NSAttributedString {
        let tracking = effectiveTracking(t, size: size, canvasHeight: canvasHeight)
        if t.letterCase == .smallCaps {
            if let font = nativeSmallCapsFont(t.fontName, size: size) {
                return NSAttributedString(string: s, attributes: attributes(font, kern: tracking * Double(size)))
            }
            return synthesizedSmallCaps(s, t, size: size, tracking: tracking)
        }
        let font = FontCatalog.ctFont(t.fontName, size: size)
        return NSAttributedString(string: s, attributes: attributes(font, kern: tracking * Double(size)))
    }

    static func lineWidth(_ s: String, _ t: TextContent, _ size: CGFloat, canvasHeight: CGFloat = 0) -> CGFloat {
        let line = CTLineCreateWithAttributedString(attributed(s, t, size: size, canvasHeight: canvasHeight))
        let b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        return b.isNull || b.isInfinite ? 0 : b.width
    }

    // MARK: - Hanging punctuation

    private static let openers: Set<Character> = ["\u{201C}", "\"", "\u{2018}", "'"]
    private static let closers: Set<Character> = ["\u{201D}", "\"", "\u{2019}", "'", ".", ","]

    /// Advance of the punctuation that opens and closes the line, from the same attributed string.
    static func hangingAdvances(_ s: String, _ attr: NSAttributedString) -> (leading: CGFloat, trailing: CGFloat) {
        guard attr.length > 0, let first = s.first, let last = s.last else { return (0, 0) }
        func advance(_ range: NSRange) -> CGFloat {
            guard range.location >= 0, range.location + range.length <= attr.length else { return 0 }
            let sub = attr.attributedSubstring(from: range)
            let line = CTLineCreateWithAttributedString(sub)
            return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        }
        var leading: CGFloat = 0, trailing: CGFloat = 0
        if openers.contains(first) {
            leading = advance(NSRange(location: 0, length: String(first).utf16.count))
        }
        if closers.contains(last), s.count > 1 {
            let n = String(last).utf16.count
            trailing = advance(NSRange(location: attr.length - n, length: n))
        }
        return (leading, trailing)
    }

    /// Horizontal shift that hangs the line's punctuation outside the measured text edge.
    static func hangShift(_ s: String, _ attr: NSAttributedString, alignment: TextAlign) -> CGFloat {
        let (leading, trailing) = hangingAdvances(s, attr)
        switch alignment {
        case .left: return -leading
        case .center: return (trailing - leading) / 2
        case .right: return trailing
        }
    }

    // MARK: - Wrapping and measuring

    /// Greedy wrap of a paragraph, then a widow pass: a lone short last word pulls the word above it down.
    static func wrap(_ para: String, _ t: TextContent, size: CGFloat, width wrap: CGFloat, canvasHeight: CGFloat = 0) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in para.split(separator: " ", omittingEmptySubsequences: true) {
            let w = String(word)
            let candidate = current.isEmpty ? w : current + " " + w
            if !current.isEmpty && lineWidth(candidate, t, size, canvasHeight: canvasHeight) > wrap {
                lines.append(current)
                current = w
            } else {
                current = candidate
            }
        }
        lines.append(current)
        guard lines.count >= 2, let last = lines.last else { return lines }
        let lastWords = last.split(separator: " ")
        var prevWords = lines[lines.count - 2].split(separator: " ").map(String.init)
        if lastWords.count == 1, TitleBreaker.letterCount(last) <= 5, prevWords.count >= 3 {
            let moved = prevWords.removeLast()
            let newLast = moved + " " + last
            if lineWidth(newLast, t, size, canvasHeight: canvasHeight) <= wrap {
                lines[lines.count - 2] = prevWords.joined(separator: " ")
                lines[lines.count - 1] = newLast
            }
        }
        return lines
    }

    /// Lines the text sets as: explicit breaks, wrapped to `wrapWidth` when given.
    static func lineStrings(_ t: TextContent, size: CGFloat, wrapWidth: CGFloat?, canvasHeight: CGFloat = 0) -> [String] {
        var out: [String] = []
        for para in displayString(t).components(separatedBy: "\n") {
            guard let w = wrapWidth, w > 0 else { out.append(para); continue }
            out.append(contentsOf: wrap(para, t, size: size, width: w, canvasHeight: canvasHeight))
        }
        return out
    }

    /// Typesets the text. `sizes` gives each line its own size (block fit); otherwise every line uses `size`.
    static func measure(_ t: TextContent, size: CGFloat, wrapWidth: CGFloat?, canvasHeight: CGFloat = 0, sizes: [CGFloat]? = nil) -> Metrics {
        let strings = lineStrings(t, size: size, wrapWidth: wrapWidth, canvasHeight: canvasHeight)
        var lineSizes: [CGFloat] = []
        if let sizes, sizes.count == strings.count {
            lineSizes = sizes.map { max(1, $0) }
        } else {
            lineSizes = Array(repeating: size, count: strings.count)
        }
        var lines: [CTLine] = []
        var bounds: [CGRect] = []
        var hang: [CGFloat] = []
        for (i, s) in strings.enumerated() {
            let attr = attributed(s.isEmpty ? " " : s, t, size: lineSizes[i], canvasHeight: canvasHeight)
            let line = CTLineCreateWithAttributedString(attr)
            lines.append(line)
            var b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            if s.trimmingCharacters(in: .whitespaces).isEmpty || b.isNull || b.isInfinite { b = .zero }
            bounds.append(b)
            hang.append(b.width > 0 ? hangShift(s, attr, alignment: t.alignment) : 0)
        }
        let advance = size * CGFloat(t.lineHeight)
        let width = bounds.map(\.width).max() ?? 0
        let font = FontCatalog.ctFont(t.fontName, size: lineSizes.first ?? size)
        let first = bounds.first ?? .zero, last = bounds.last ?? .zero
        let top = first.height > 0 ? first.maxY : CTFontGetCapHeight(font)
        let bottom = last.height > 0 ? last.minY : 0
        // Each line advances by its own size, so a smaller line sits closer under the one above.
        var baselines: [CGFloat] = []
        var y = top
        for (i, s) in lineSizes.enumerated() {
            if i > 0 { y += s * CGFloat(t.lineHeight) }
            baselines.append(y)
        }
        let height = (baselines.last ?? top) - bottom
        return Metrics(lines: lines, bounds: bounds, advance: advance, width: width, height: max(1, height), top: top,
                       fontSize: size, sizes: lineSizes, baselines: baselines, hang: hang)
    }

    /// How far an arched line bends beyond its straight height, per unit of line width.
    static func sagFactor(_ arc: Double) -> CGFloat {
        let a = abs(arc)
        guard a > 0.001 else { return 0 }
        return CGFloat((1 - cos(a * .pi / 2)) / (a * .pi))
    }

    /// Size that makes the text exactly fill the box (glyph bounds scale linearly with size).
    /// With a canvas height the optical tracking at the final size is taken into account.
    static func fittedSize(_ t: TextContent, box: CGSize, canvasHeight: CGFloat = 0) -> CGFloat {
        let ref: CGFloat = 100
        let m = measure(t, size: ref, wrapWidth: nil)
        guard m.width > 0, m.height > 0 else { return max(2, box.height * 0.5) }
        let sag = m.width * sagFactor(t.arc)
        let size = max(2, min(box.width / m.width, box.height / (m.height + sag)) * ref * 0.995)
        guard canvasHeight > 0, t.opticalTracking else { return size }
        // Tracking changes the width but not the height, so one refinement pass settles it.
        let m2 = measure(t, size: size, wrapWidth: nil, canvasHeight: canvasHeight)
        guard m2.width > 0 else { return size }
        let sag2 = m2.width * sagFactor(t.arc)
        return max(2, min(box.width / m2.width, box.height / (m2.height + sag2)) * size * 0.995)
    }

    static func resolvedSize(_ t: TextContent, box: CGSize, canvasHeight: CGFloat) -> CGFloat {
        t.autoFit ? fittedSize(t, box: box, canvasHeight: canvasHeight) : max(2, CGFloat(t.fontSize) * canvasHeight)
    }

    /// Largest ratio allowed between the biggest and smallest line in a block-fitted stack.
    static let blockRatioCap: CGFloat = 2.4

    /// One size per line. Uniform fit repeats the resolved size; block fit scales each line to the box width,
    /// caps the spread at `blockRatioCap`, then shrinks the stack uniformly if it is taller than the box.
    static func resolvedSizes(_ t: TextContent, box: CGSize, canvasHeight: CGFloat) -> [CGFloat] {
        let size = resolvedSize(t, box: box, canvasHeight: canvasHeight)
        guard t.fit == .block else {
            let n = lineStrings(t, size: size, wrapWidth: t.autoFit ? nil : box.width, canvasHeight: canvasHeight).count
            return Array(repeating: size, count: max(1, n))
        }
        let strings = lineStrings(t, size: size, wrapWidth: nil)
        guard box.width > 0, box.height > 0 else { return Array(repeating: size, count: max(1, strings.count)) }
        let ref: CGFloat = 100
        var sizes: [CGFloat] = []
        for s in strings {
            let w0 = lineWidth(s, t, ref)
            guard w0 > 0 else { sizes.append(0); continue }
            var fitted = box.width / w0 * ref
            // Optical tracking depends on the size, so measure once more at the size it produced.
            let w1 = lineWidth(s, t, fitted, canvasHeight: canvasHeight)
            if w1 > 0 { fitted = fitted * box.width / w1 }
            sizes.append(max(2, fitted * 0.995))
        }
        let positive = sizes.filter { $0 > 0 }
        guard let smallest = positive.min() else { return Array(repeating: size, count: max(1, strings.count)) }
        let cap = smallest * blockRatioCap
        sizes = sizes.map { $0 > 0 ? min($0, cap) : smallest }
        let m = measure(t, size: sizes.max() ?? size, wrapWidth: nil, canvasHeight: canvasHeight, sizes: sizes)
        let total = m.height + m.width * sagFactor(t.arc)
        if total > box.height, total > 0 {
            let k = box.height / total * 0.995
            sizes = sizes.map { max(2, $0 * k) }
        }
        return sizes
    }

    /// Best line breaks for a title measured with its real font: tries 1...maxLines lines and keeps the
    /// layout that sets largest in the box with lines within 1.9x of each other.
    static func bestBreaks(_ t: TextContent, box: CGSize, maxLines: Int = 4) -> String {
        let flat = t.text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let words = flat.split(separator: " ").map(String.init)
        guard words.count > 1, box.width > 0, box.height > 0 else { return flat }
        let measureLine: (String) -> Double = { Double(lineWidth(applyCase($0, t.letterCase), t, 100)) }
        var candidates: [(text: String, size: CGFloat, ratio: Double)] = []
        for n in 1...max(1, min(maxLines, words.count)) {
            let text = n == 1 ? words.joined(separator: " ") : TitleBreaker.balanced(flat, lines: n, measure: measureLine)
            if candidates.contains(where: { $0.text == text }) { continue }
            var probe = t
            probe.text = text
            probe.fit = .uniform
            let size = fittedSize(probe, box: box)
            let widths = text.components(separatedBy: "\n").map(measureLine).filter { $0 > 0 }
            let ratio = (widths.max() ?? 1) / max(1, widths.min() ?? 1)
            candidates.append((text, size, ratio))
        }
        let balancedOnes = candidates.filter { $0.ratio <= 1.9 }
        let pool = balancedOnes.isEmpty ? candidates : balancedOnes
        return pool.max(by: { $0.size < $1.size })?.text ?? flat
    }

    private static func seed(_ s: String) -> Int {
        s.unicodeScalars.reduce(17) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    /// Returns the rendered text and the padding added around the box for strokes and glows.
    static func render(_ t: TextContent, box: CGSize, canvasHeight: CGFloat) -> (CGImage, CGFloat)? {
        guard box.width >= 1, box.height >= 1 else { return nil }
        // Decorations need room beside or around the type, so it fits a smaller box.
        let fitBox = CGSize(width: box.width * t.flourish.textWidthShare, height: box.height * t.flourish.textHeightShare)
        let m: Metrics
        let size: CGFloat
        if t.fit == .block {
            let sizes = resolvedSizes(t, box: fitBox, canvasHeight: canvasHeight)
            size = sizes.reduce(0, +) / CGFloat(max(1, sizes.count))
            m = measure(t, size: max(2, size), wrapWidth: nil, canvasHeight: canvasHeight, sizes: sizes)
        } else {
            size = resolvedSize(t, box: fitBox, canvasHeight: canvasHeight)
            m = measure(t, size: size, wrapWidth: t.autoFit ? nil : fitBox.width, canvasHeight: canvasHeight)
        }
        let padSize = m.sizes.max() ?? size
        let neon = t.texture == .neon
        let glowColor: RGBA? = neon ? t.color : t.glowColor
        let glowRadius = neon ? max(t.glowRadius, 0.35) : t.glowRadius
        var pad: CGFloat = 2
        if glowColor != nil { pad += padSize * CGFloat(glowRadius) * 1.6 }
        if t.strokeColor != nil { pad += padSize * CGFloat(t.strokeWidth) * 2 }
        if t.style.isActive { pad += padSize * CGFloat(t.style.paddingFactor) }
        // Hanging punctuation reaches past the box edge.
        let maxHang = m.hang.map { abs($0) }.max() ?? 0
        if maxHang > 0 { pad += ceil(maxHang) }
        let W = Int(ceil(box.width + 2 * pad)), H = Int(ceil(box.height + 2 * pad))
        guard let maskCtx = Gfx.grayContext(W, H), let fillCtx = Gfx.context(W, H), let out = Gfx.context(W, H) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: W, height: H)

        let sag = m.width * sagFactor(t.arc)
        let blockTop = pad + (box.height - (m.height + sag)) / 2 + (t.arc < 0 ? sag : 0)
        var positions: [CGPoint] = []
        for (i, b) in m.bounds.enumerated() {
            let baselineFromTop = blockTop + m.baselineOffset(i)
            var x: CGFloat
            switch t.alignment {
            case .left: x = pad - b.minX
            case .center: x = pad + (box.width - b.width) / 2 - b.minX
            case .right: x = pad + box.width - b.width - b.minX
            }
            x += m.hangOffset(i)
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
            stops = t.paintMix ? PigmentMixer.ramp(t.color, g, steps: 9) : [t.color, g]
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

        if t.flourish != .none, !m.bounds.isEmpty {
            var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
            for (i, b) in m.bounds.enumerated() {
                minX = min(minX, positions[i].x + b.minX)
                maxX = max(maxX, positions[i].x + b.minX + b.width)
            }
            let textRect = CGRect(x: minX, y: bottomY, width: max(1, maxX - minX), height: max(1, topY - bottomY))
            let boxRect = CGRect(x: pad, y: pad, width: box.width, height: box.height)
            let deco = t.flourishColor ?? t.color
            let band = t.flourishColor ?? (t.color.hsl.l > 0.5 ? RGBA.nearBlack.withAlpha(0.82) : RGBA.nearWhite.withAlpha(0.88))
            t.flourish.draw(in: out, text: textRect, box: boxRect, size: size, color: deco, bandColor: band)
        }

        // The layered style engine takes over the face, outlines, depth and wear.
        if t.style.isActive, let styled = TextStyler.compose(mask: mask, fill: fill, style: t.style, color: t.color, fontSize: size, seed: seed(t.text)) {
            if let s = t.strokeColor {
                out.setTextDrawingMode(.stroke)
                out.setLineWidth(size * CGFloat(t.strokeWidth) * 2)
                out.setLineJoin(.round)
                out.setStrokeColor(s.cgColor)
                drawLines(out)
                out.setTextDrawingMode(.fill)
            }
            if let glow = glowColor {
                out.saveGState()
                out.setShadow(offset: .zero, blur: size * CGFloat(glowRadius), color: glow.cgColor)
                out.draw(styled, in: rect)
                out.restoreGState()
            }
            out.draw(styled, in: rect)
            guard let img = out.makeImage() else { return nil }
            return (img, pad)
        }

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
