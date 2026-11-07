import CoreGraphics
import CoreText
import Foundation

/// Bookland EAN-13 barcodes (ISBN) with the optional 5-digit price add-on, drawn as vector bars.
enum Barcode {
    // MARK: ISBN

    /// Normalizes an ISBN-10 or ISBN-13 (hyphens and spaces allowed) to a validated 13-digit string.
    /// ISBN-10s are converted with the 978 prefix. Returns nil when the check digit is wrong.
    static func isbn13(from input: String) -> String? {
        let cleaned = input.uppercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "." }
        if cleaned.count == 13 {
            guard cleaned.allSatisfy(\.isNumber) else { return nil }
            return ean13CheckDigit(String(cleaned.prefix(12))) == String(cleaned.suffix(1)) ? cleaned : nil
        }
        if cleaned.count == 10 {
            let body = String(cleaned.prefix(9))
            guard body.allSatisfy(\.isNumber), let last = cleaned.last else { return nil }
            let digits = body.compactMap { $0.wholeNumberValue }
            var sum = 0
            for (i, d) in digits.enumerated() { sum += (10 - i) * d }
            let checkValue = last == "X" ? 10 : (last.wholeNumberValue ?? -1)
            guard checkValue >= 0, (sum + checkValue) % 11 == 0 else { return nil }
            let twelve = "978" + body
            return twelve + ean13CheckDigit(twelve)
        }
        return nil
    }

    /// The EAN-13 check digit for 12 digits.
    static func ean13CheckDigit(_ twelve: String) -> String {
        let digits = twelve.compactMap { $0.wholeNumberValue }
        var sum = 0
        for (i, d) in digits.enumerated() { sum += d * (i % 2 == 0 ? 1 : 3) }
        return String((10 - sum % 10) % 10)
    }

    /// Human-readable form: "978-0-306-40615-7". Uses the hyphenation the user typed when it has one
    /// (registration-group tables aren't bundled), otherwise splits off the prefix and check digit.
    static func formatted(_ isbn13: String, hint: String) -> String {
        let hintDigits = hint.filter { $0.isNumber || $0 == "X" || $0 == "x" }
        let groups = hint.split(whereSeparator: { $0 == "-" || $0 == " " }).map(String.init)
        if groups.count >= 3 {
            if hintDigits.count == 13 {
                return groups.dropLast().joined(separator: "-") + "-" + String(isbn13.suffix(1))
            }
            if hintDigits.count == 10 {
                return "978-" + groups.dropLast().joined(separator: "-") + "-" + String(isbn13.suffix(1))
            }
        }
        let s = Array(isbn13)
        return String(s[0..<3]) + "-" + String(s[3..<12]) + "-" + String(s[12])
    }

    /// Whether a price add-on is five digits.
    static func isValidAddOn(_ code: String) -> Bool { code.count == 5 && code.allSatisfy(\.isNumber) }

    // MARK: Patterns

    // L-codes for digits 0...9; G is the reverse of R, R the complement of L.
    private static let lCodes: [[Bool]] = [
        "0001101", "0011001", "0010011", "0111101", "0100011", "0110001", "0101111", "0111011", "0110111", "0001011"
    ].map { $0.map { $0 == "1" } }

    private static func code(_ digit: Int, _ set: Character) -> [Bool] {
        let l = lCodes[digit]
        switch set {
        case "L": return l
        case "R": return l.map { !$0 }
        default: return l.map { !$0 }.reversed()
        }
    }

    /// Parity of the six left digits, indexed by the first (number system) digit.
    private static let ean13Parity = ["LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG", "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"]

    /// 95 modules: start guard, six left digits, center guard, six right digits, end guard.
    static func ean13Pattern(_ digits: String) -> [Bool] {
        let d = digits.compactMap { $0.wholeNumberValue }
        guard d.count == 13 else { return [] }
        var out: [Bool] = []
        out.append(contentsOf: [true, false, true])
        let parity = Array(ean13Parity[d[0]])
        for i in 0..<6 { out.append(contentsOf: code(d[1 + i], parity[i])) }
        out.append(contentsOf: [false, true, false, true, false])
        for i in 0..<6 { out.append(contentsOf: code(d[7 + i], "R")) }
        out.append(contentsOf: [true, false, true])
        return out
    }

    /// EAN-5 parity indexed by the add-on checksum.
    private static let addOnParity = ["GGLLL", "GLGLL", "GLLGL", "GLLLG", "LGGLL", "LLGGL", "LLLGG", "LGLGL", "LGLLG", "LLGLG"]

    /// 47 modules: start guard 1011, five digits with 01 separators.
    static func addOnPattern(_ five: String) -> [Bool] {
        let d = five.compactMap { $0.wholeNumberValue }
        guard d.count == 5 else { return [] }
        let checksum = (3 * (d[0] + d[2] + d[4]) + 9 * (d[1] + d[3])) % 10
        let parity = Array(addOnParity[checksum])
        var out: [Bool] = [true, false, true, true]
        for i in 0..<5 {
            if i > 0 { out.append(contentsOf: [false, true]) }
            out.append(contentsOf: code(d[i], parity[i]))
        }
        return out
    }

    // MARK: Drawing

    /// Nominal module width at 100% magnification: 0.33 mm.
    static let moduleInches = 0.33 / 25.4
    /// Quiet zones in modules: left of the symbol, between symbol and add-on, right of the add-on.
    static let leftQuiet = 11, gap = 9, rightQuiet = 7

    /// Total width in modules of the symbol with its quiet zones.
    static func totalModules(addOn: Bool) -> Int {
        leftQuiet + 95 + (addOn ? gap + 47 + 5 : rightQuiet)
    }

    /// Draws a complete Bookland barcode filling `rect` (standard bottom-left coordinates of `ctx`):
    /// white ground, "ISBN 978-..." above, bars, digits below, and the add-on with its digits above.
    /// Bars are filled rectangles so the PDF stays vector-sharp. The module stays at 100% (0.33 mm)
    /// unless the rect is too narrow for it.
    static func draw(isbn13: String, addOn: String?, in rect: CGRect, ctx: CGContext, dpi: Double, hint: String = "") {
        let main = ean13Pattern(isbn13)
        guard main.count == 95 else { return }
        let extra = addOn.flatMap { isValidAddOn($0) ? addOnPattern($0) : nil }
        let hasAddOn = extra != nil

        ctx.saveGState()
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(rect)

        let nominal = CGFloat(moduleInches * dpi)
        let modules = CGFloat(totalModules(addOn: hasAddOn))
        let module = min(nominal, (rect.width - CGFloat(dpi) * 0.1) / modules)
        let pt = CGFloat(dpi / 72)
        let labelSize = 8.5 * pt
        let digitSize = 9 * pt
        let topBand = labelSize * 1.9
        let bottomBand = digitSize * 1.45
        let inset = CGFloat(dpi) * 0.05
        let barTop = rect.maxY - inset - topBand
        let barBottom = rect.minY + inset + bottomBand
        guard barTop - barBottom > module * 10 else { ctx.restoreGState(); return }
        let guardDrop = digitSize * 0.55
        let symbolWidth = module * modules
        let x0 = rect.minX + (rect.width - symbolWidth) / 2 + module * CGFloat(leftQuiet)

        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        // Guard bars (indices 0-2, 45-49, 92-94) reach down into the digit band.
        func isGuard(_ i: Int) -> Bool { i < 3 || (i >= 45 && i < 50) || i >= 92 }
        for (i, on) in main.enumerated() where on {
            let bottom = isGuard(i) ? barBottom - guardDrop : barBottom
            ctx.fill(CGRect(x: x0 + CGFloat(i) * module, y: bottom, width: module, height: barTop - bottom))
        }

        let font = CTFontCreateWithName("Helvetica" as CFString, digitSize, nil)
        let labelFont = CTFontCreateWithName("Helvetica" as CFString, labelSize, nil)
        let digits = Array(isbn13)
        // Leading digit sits in the left quiet zone; the two groups of six are spread under their halves.
        drawText(String(digits[0]), font: font, at: CGPoint(x: x0 - module * 6, y: barBottom - guardDrop), ctx: ctx, align: .center)
        for i in 0..<6 {
            let cx = x0 + module * (3 + 7 * CGFloat(i) + 3.5)
            drawText(String(digits[1 + i]), font: font, at: CGPoint(x: cx, y: barBottom - guardDrop), ctx: ctx, align: .center)
            let cx2 = x0 + module * (50 + 7 * CGFloat(i) + 3.5)
            drawText(String(digits[7 + i]), font: font, at: CGPoint(x: cx2, y: barBottom - guardDrop), ctx: ctx, align: .center)
        }
        drawText("ISBN " + formatted(isbn13, hint: hint), font: labelFont,
                 at: CGPoint(x: x0 + module * 47.5, y: barTop + labelSize * 0.45), ctx: ctx, align: .center)

        if let extra, let addOn {
            let ax = x0 + module * CGFloat(95 + gap)
            let addTop = barTop - labelSize * 1.3
            for (i, on) in extra.enumerated() where on {
                ctx.fill(CGRect(x: ax + CGFloat(i) * module, y: barBottom, width: module, height: addTop - barBottom))
            }
            drawText(addOn.map { String($0) }.joined(separator: " "), font: font,
                     at: CGPoint(x: ax + module * 23.5, y: addTop + labelSize * 0.3), ctx: ctx, align: .center)
        }
        ctx.restoreGState()
    }

    private enum Align { case left, center }

    private static func drawText(_ s: String, font: CTFont, at p: CGPoint, ctx: CGContext, align: Align) {
        let attr = NSAttributedString(string: s, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
        ])
        let line = CTLineCreateWithAttributedString(attr)
        let w = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: align == .center ? p.x - w / 2 : p.x, y: p.y)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
