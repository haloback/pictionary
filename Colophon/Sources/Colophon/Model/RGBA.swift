import AppKit
import CoreImage
import SwiftUI

/// An sRGB color with the color-science helpers a cover designer needs:
/// HSL edits, WCAG contrast, perceptual distance and harmonies.
struct RGBA: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r.clamped01
        self.g = g.clamped01
        self.b = b.clamped01
        self.a = a.clamped01
    }

    init(hex: String, alpha: Double = 1) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255, alpha)
    }

    init(nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.sRGB) ?? NSColor.black
        self.init(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent))
    }

    init(color: Color) {
        self.init(nsColor: NSColor(color))
    }

    init(h: Double, s: Double, l: Double, a: Double = 1) {
        let hh = ((h.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 360
        let s = s.clamped01, l = l.clamped01
        if s == 0 {
            self.init(l, l, l, a)
            return
        }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func hue(_ t0: Double) -> Double {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6.0 { return p + (q - p) * 6 * t }
            if t < 0.5 { return q }
            if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6 }
            return p
        }
        self.init(hue(hh + 1.0 / 3.0), hue(hh), hue(hh - 1.0 / 3.0), a)
    }

    static let white = RGBA(1, 1, 1)
    static let black = RGBA(0, 0, 0)
    static let clear = RGBA(0, 0, 0, 0)
    /// Off-white and off-black: pure values look flat on covers.
    static let nearWhite = RGBA(hex: "F7F4EE")
    static let nearBlack = RGBA(hex: "111214")
    static let paper = RGBA(hex: "F2ECDF")
    static let ink = RGBA(hex: "15171A")

    var hex: String {
        String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    var ciColor: CIColor { CIColor(cgColor: cgColor) }

    // MARK: HSL

    var hsl: (h: Double, s: Double, l: Double) {
        let mx = max(r, g, b), mn = min(r, g, b)
        let l = (mx + mn) / 2
        guard mx != mn else { return (0, 0, l) }
        let d = mx - mn
        let s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var h: Double
        if mx == r {
            h = (g - b) / d + (g < b ? 6 : 0)
        } else if mx == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        h *= 60
        return (h, s, l)
    }

    func adjusting(hue dh: Double = 0, saturation ds: Double = 0, lightness dl: Double = 0) -> RGBA {
        let c = hsl
        return RGBA(h: c.h + dh, s: c.s + ds, l: c.l + dl, a: a)
    }

    func withLightness(_ l: Double) -> RGBA {
        let c = hsl
        return RGBA(h: c.h, s: c.s, l: l, a: a)
    }

    func withSaturation(_ s: Double) -> RGBA {
        let c = hsl
        return RGBA(h: c.h, s: s, l: c.l, a: a)
    }

    func withAlpha(_ alpha: Double) -> RGBA { RGBA(r, g, b, alpha) }

    func mixed(with o: RGBA, _ t: Double) -> RGBA {
        RGBA(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t)
    }

    var complement: RGBA { adjusting(hue: 180) }

    /// Tints and shades from deep to pale at constant hue.
    func shades(_ n: Int) -> [RGBA] {
        (0..<n).map { i in withLightness(0.1 + 0.8 * Double(i) / Double(max(1, n - 1))) }
    }

    // MARK: Contrast (WCAG 2.x)

    var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    func contrast(with o: RGBA) -> Double {
        let l1 = luminance, l2 = o.luminance
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    var isDark: Bool { luminance < 0.2 }
    var chroma: Double { max(r, g, b) - min(r, g, b) }

    // MARK: Perceptual (CIELAB, D65)

    var lab: (l: Double, a: Double, b: Double) {
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let R = lin(r), G = lin(g), B = lin(b)
        let x = (R * 0.4124 + G * 0.3576 + B * 0.1805) / 0.95047
        let y = (R * 0.2126 + G * 0.7152 + B * 0.0722) / 1.0
        let z = (R * 0.0193 + G * 0.1192 + B * 0.9505) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? pow(t, 1.0 / 3.0) : 7.787 * t + 16.0 / 116.0 }
        let fx = f(x), fy = f(y), fz = f(z)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    /// Delta E (CIE76). Below ~10 reads as "the same color family".
    func distance(to o: RGBA) -> Double {
        let p = lab, q = o.lab
        return sqrt(pow(p.l - q.l, 2) + pow(p.a - q.a, 2) + pow(p.b - q.b, 2))
    }
}
