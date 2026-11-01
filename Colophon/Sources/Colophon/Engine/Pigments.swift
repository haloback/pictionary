import CoreGraphics
import CoreImage
import Foundation

/// Mixes colors the way paint does, not the way light does: blue and yellow make green, not gray.
///
/// Each color is lifted to a smooth reflectance spectrum (a sigmoid of a quadratic in wavelength, fitted so it
/// reproduces the color exactly), the spectra are mixed with Kubelka-Munk theory (absorption and scattering add
/// by concentration), and the result is turned back into sRGB. Concentrations are weighted by each paint's
/// lightness, a stand-in for tinting strength, so a dark blue doesn't swallow a yellow. A residual term makes
/// mixing a color with itself return exactly that color.
enum PigmentMixer {
    private static let count = 36
    private static let wavelengths: [Double] = (0..<36).map { 380.0 + 10.0 * Double($0) }

    // CIE 1931 color matching functions, multi-lobe Gaussian fit (Wyman, Sloan & Shirley 2013).
    private static func g(_ l: Double, _ mu: Double, _ s1: Double, _ s2: Double) -> Double {
        let s: Double = l < mu ? s1 : s2
        let t: Double = (l - mu) / s
        return exp(-0.5 * t * t)
    }
    private static let cmfX: [Double] = wavelengths.map { l in
        1.056 * g(l, 599.8, 37.9, 31.0) + 0.362 * g(l, 442.0, 16.0, 26.7) - 0.065 * g(l, 501.1, 20.4, 26.2)
    }
    private static let cmfY: [Double] = wavelengths.map { l in 0.821 * g(l, 568.8, 46.9, 40.5) + 0.286 * g(l, 530.9, 16.3, 31.1) }
    private static let cmfZ: [Double] = wavelengths.map { l in 1.217 * g(l, 437.0, 11.8, 36.0) + 0.681 * g(l, 459.0, 26.0, 13.8) }
    private static let xs: [Double] = wavelengths.map { ($0 - 555.0) / 175.0 }

    private static func rawLinear(_ R: [Double]) -> (Double, Double, Double) {
        var x = 0.0, y = 0.0, z = 0.0
        for i in 0..<count {
            x += R[i] * cmfX[i]
            y += R[i] * cmfY[i]
            z += R[i] * cmfZ[i]
        }
        let r: Double = 3.2406 * x - 1.5372 * y - 0.4986 * z
        let gg: Double = -0.9689 * x + 1.8758 * y + 0.0415 * z
        let b: Double = 0.0557 * x - 0.2040 * y + 1.0570 * z
        return (r, gg, b)
    }
    /// White balance: a perfect reflector maps to white.
    private static let white: (Double, Double, Double) = rawLinear([Double](repeating: 1, count: 36))

    private static func linear(_ R: [Double]) -> [Double] {
        let v = rawLinear(R)
        return [v.0 / white.0, v.1 / white.1, v.2 / white.2]
    }

    private static func sigmoid(_ z: Double) -> Double { 0.5 + z / (2 * (1 + z * z).squareRoot()) }

    private static func curve(_ c: [Double]) -> [Double] {
        xs.map { x in sigmoid(c[0] * x * x + c[1] * x + c[2]) }
    }

    static func decode(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    static func encode(_ v: Double) -> Double {
        let c = min(1, max(0, v))
        return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    private struct Fit {
        let reflectance: [Double]
        let fitted: [Double]
        let target: [Double]
    }

    private static var cache: [RGBA: Fit] = [:]
    private static let lock = NSLock()

    /// Levenberg-Marquardt fit of the three sigmoid coefficients to the color.
    private static func fit(_ color: RGBA) -> Fit {
        let key = RGBA(color.r, color.g, color.b)
        lock.lock()
        if let hit = cache[key] { lock.unlock(); return hit }
        lock.unlock()
        let target: [Double] = [color.r, color.g, color.b].map { min(0.995, max(0.005, decode($0))) }
        func err(_ c: [Double]) -> [Double] {
            let v = linear(curve(c))
            return [v[0] - target[0], v[1] - target[1], v[2] - target[2]]
        }
        var c: [Double] = [0, 0, 0]
        var e = err(c)
        var E: Double = e[0] * e[0] + e[1] * e[1] + e[2] * e[2]
        var lambda = 1e-3
        for _ in 0..<60 where E > 1e-12 {
            var J = [[Double]](repeating: [0, 0, 0], count: 3)
            for j in 0..<3 {
                var cc = c
                cc[j] += 1e-4
                let ej = err(cc)
                for i in 0..<3 { J[i][j] = (ej[i] - e[i]) / 1e-4 }
            }
            var A = [[Double]](repeating: [0, 0, 0], count: 3)
            var b: [Double] = [0, 0, 0]
            for i in 0..<3 {
                for j in 0..<3 {
                    var s = 0.0
                    for k in 0..<3 { s += J[k][i] * J[k][j] }
                    A[i][j] = s + (i == j ? lambda : 0)
                }
                var s = 0.0
                for k in 0..<3 { s += J[k][i] * e[k] }
                b[i] = -s
            }
            guard let d = solve3(A, b) else { break }
            let cn: [Double] = [c[0] + d[0], c[1] + d[1], c[2] + d[2]]
            let en = err(cn)
            let En: Double = en[0] * en[0] + en[1] * en[1] + en[2] * en[2]
            if En < E {
                c = cn; e = en; E = En
                lambda *= 0.3
            } else {
                lambda *= 10
            }
        }
        let R = curve(c)
        let result = Fit(reflectance: R, fitted: linear(R), target: target)
        lock.lock()
        if cache.count > 4000 { cache.removeAll() }
        cache[key] = result
        lock.unlock()
        return result
    }

    private static func solve3(_ A: [[Double]], _ b: [Double]) -> [Double]? {
        var a = A, bb = b
        for i in 0..<3 {
            var p = i
            for r in i..<3 where abs(a[r][i]) > abs(a[p][i]) { p = r }
            a.swapAt(i, p)
            bb.swapAt(i, p)
            guard abs(a[i][i]) > 1e-12 else { return nil }
            for r in (i + 1)..<3 {
                let f = a[r][i] / a[i][i]
                for k in i..<3 { a[r][k] -= f * a[i][k] }
                bb[r] -= f * bb[i]
            }
        }
        var d: [Double] = [0, 0, 0]
        for i in stride(from: 2, through: 0, by: -1) {
            var s = bb[i]
            for k in (i + 1)..<3 { s -= a[i][k] * d[k] }
            d[i] = s / a[i][i]
        }
        return d
    }

    private static func ks(_ r: Double) -> Double {
        let R = min(0.999, max(0.001, r))
        return (1 - R) * (1 - R) / (2 * R)
    }

    private static func km(_ k: Double) -> Double { 1 + k - (k * k + 2 * k).squareRoot() }

    /// Paint-like mix of colors in the given proportions (weights needn't sum to 1).
    static func mix(_ colors: [RGBA], weights: [Double]) -> RGBA {
        guard !colors.isEmpty else { return .white }
        if colors.count == 1 { return colors[0] }
        let fits = colors.map(fit)
        var conc: [Double] = []
        for (f, w) in zip(fits, weights) {
            let y: Double = 0.2126 * f.target[0] + 0.7152 * f.target[1] + 0.0722 * f.target[2]
            conc.append(w * w * max(y, 1e-4))
        }
        let total = max(1e-9, conc.reduce(0, +))
        var mixed = [Double](repeating: 0, count: count)
        for (f, k) in zip(fits, conc) {
            let share = k / total
            for i in 0..<count { mixed[i] += share * ks(f.reflectance[i]) }
        }
        var v = linear(mixed.map(km))
        let wsum = max(1e-9, weights.reduce(0, +))
        for (f, w) in zip(fits, weights) {
            for i in 0..<3 { v[i] += (w / wsum) * (f.target[i] - f.fitted[i]) }
        }
        var alpha = 0.0
        for (c, w) in zip(colors, weights) { alpha += c.a * w / wsum }
        return RGBA(encode(v[0]), encode(v[1]), encode(v[2]), alpha)
    }

    /// The fitted reflectance spectrum of a color (36 samples, 380–730 nm).
    static func reflectance(_ c: RGBA) -> [Double] { fit(c).reflectance }

    /// Linear-sRGB contribution of each wavelength band at full reflectance (white-balanced),
    /// for `bands` equal groups of the 36 samples. Summing band reflectance × column gives the color.
    static func bandMatrix(bands: Int) -> [[Double]] {
        let per = count / bands
        var cols: [[Double]] = []
        for b in 0..<bands {
            var R = [Double](repeating: 0, count: count)
            for i in (b * per)..<min(count, (b + 1) * per) { R[i] = 1 }
            let v = rawLinear(R)
            cols.append([v.0 / white.0, v.1 / white.1, v.2 / white.2])
        }
        return cols
    }

    /// `t` of the way from `a` to `b`, mixed like paint.
    static func mix(_ a: RGBA, _ b: RGBA, _ t: Double) -> RGBA {
        let k = min(1, max(0, t))
        if k <= 0.0001 { return a }
        if k >= 0.9999 { return b }
        return mix([a, b], weights: [1 - k, k])
    }

    /// Evenly spaced paint mixes from a to b (inclusive), for gradients and maps.
    static func ramp(_ a: RGBA, _ b: RGBA, steps: Int = 9) -> [RGBA] {
        let n = max(2, steps)
        return (0..<n).map { mix(a, b, Double($0) / Double(n - 1)) }
    }

    /// A gradient through several colors with paint mixes inserted between neighbors.
    static func expand(_ colors: [RGBA], between: Int = 6) -> [RGBA] {
        guard colors.count > 1 else { return colors }
        var out: [RGBA] = []
        for i in 0..<(colors.count - 1) {
            let r = ramp(colors[i], colors[i + 1], steps: between + 2)
            out.append(contentsOf: i == 0 ? r : Array(r.dropFirst()))
        }
        return out
    }
}

/// Real watercolor pigments (color index names in the tags), as they look in a mid-strength wash.
enum Pigments {
    struct Pigment: Hashable {
        let name: String
        let color: RGBA
        let index: String
        /// Granulating pigments settle into the paper's tooth.
        let granulates: Bool
    }

    static let watercolor: [Pigment] = [
        Pigment(name: "Hansa Yellow", color: RGBA(hex: "F7D917"), index: "PY97", granulates: false),
        Pigment(name: "Cadmium Yellow", color: RGBA(hex: "FFC20E"), index: "PY35", granulates: false),
        Pigment(name: "Yellow Ochre", color: RGBA(hex: "C99A3B"), index: "PY43", granulates: true),
        Pigment(name: "Raw Sienna", color: RGBA(hex: "B9763A"), index: "PBr7", granulates: true),
        Pigment(name: "Pyrrole Orange", color: RGBA(hex: "F2661C"), index: "PO73", granulates: false),
        Pigment(name: "Cadmium Red", color: RGBA(hex: "D7263D"), index: "PR108", granulates: false),
        Pigment(name: "Alizarin Crimson", color: RGBA(hex: "8E1A2E"), index: "PR83", granulates: false),
        Pigment(name: "Permanent Rose", color: RGBA(hex: "D8457A"), index: "PV19", granulates: false),
        Pigment(name: "Quinacridone Magenta", color: RGBA(hex: "9C2A6B"), index: "PR122", granulates: false),
        Pigment(name: "Opera Pink", color: RGBA(hex: "F2449A"), index: "PR122+", granulates: false),
        Pigment(name: "Dioxazine Violet", color: RGBA(hex: "4B2A7A"), index: "PV23", granulates: false),
        Pigment(name: "Ultramarine Blue", color: RGBA(hex: "2A3B9E"), index: "PB29", granulates: true),
        Pigment(name: "Cobalt Blue", color: RGBA(hex: "2F5BB7"), index: "PB28", granulates: true),
        Pigment(name: "Cerulean Blue", color: RGBA(hex: "3C8DC5"), index: "PB35", granulates: true),
        Pigment(name: "Phthalo Blue", color: RGBA(hex: "0F3D7A"), index: "PB15", granulates: false),
        Pigment(name: "Indigo", color: RGBA(hex: "26304A"), index: "PB60", granulates: false),
        Pigment(name: "Phthalo Green", color: RGBA(hex: "0B6E5A"), index: "PG7", granulates: false),
        Pigment(name: "Viridian", color: RGBA(hex: "2E8B74"), index: "PG18", granulates: true),
        Pigment(name: "Sap Green", color: RGBA(hex: "5C7A2E"), index: "PG36", granulates: false),
        Pigment(name: "Burnt Sienna", color: RGBA(hex: "9C4A2E"), index: "PBr7", granulates: true),
        Pigment(name: "Burnt Umber", color: RGBA(hex: "5A3A24"), index: "PBr7", granulates: true),
        Pigment(name: "Sepia", color: RGBA(hex: "3E2C20"), index: "PBr7", granulates: false),
        Pigment(name: "Payne's Gray", color: RGBA(hex: "3A4654"), index: "PB15+PBk6", granulates: false),
        Pigment(name: "Lamp Black", color: RGBA(hex: "1E1F21"), index: "PBk6", granulates: true)
    ]
}

/// Paints watercolor: pigments that bloom into each other wet-in-wet, dilute toward the paper,
/// darken where the wash dried at its edges, and settle into the paper's grain.
enum Watercolor {
    /// Smooth noise lifted so its mid-gray sits at 0.5 in Core Image's working space.
    private static func field(_ e: CGRect, seed: Int, cells: Int) -> CIImage {
        FX.smoothNoise(e, seed: seed, cells: max(2, cells)).applyingFilter("CIGammaAdjust", parameters: ["inputPower": 0.4545]).cropped(to: e)
    }

    private static func remap(_ i: CIImage, _ k: Double, _ c: Double) -> CIImage {
        FX.matrix(i, r: (k, 0, 0), g: (k, 0, 0), b: (k, 0, 0), bias: (c - 0.5 * k, c - 0.5 * k, c - 0.5 * k))
            .applyingFilter("CIColorClamp", parameters: [
                "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 1), "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
            ]).cropped(to: i.extent)
    }

    /// `pigments`: 1–4 paints. `wetness` 0...1 (crisp glazes to soft blooms). `strength` 0...1 (pale to saturated).
    static func paint(extent e: CGRect, pigments: [RGBA], paper: RGBA = RGBA(hex: "FBF7EE"), seed: Int,
                      scale: CGFloat, wetness: Double = 0.6, strength: Double = 0.7, granulation: Double = 0.4) -> CIImage {
        let inks: [RGBA] = pigments.isEmpty ? [RGBA(hex: "2A3B9E")] : Array(pigments.prefix(4))
        let unit: CGFloat = max(8, scale)
        let cellsBig = max(2, Int(e.width / (unit * CGFloat(2.4 + 2 * wetness))))
        let cellsSmall = max(3, Int(e.width / (unit * 0.7)))
        // Which paint where: a soft field, swept through a paint-mixed ramp of the inks.
        let blend = FX.blend(field(e, seed: seed &+ 5, cells: cellsSmall), over: field(e, seed: seed, cells: cellsBig), mode: "CISoftLightBlendMode")
        var ramp: [RGBA] = []
        if inks.count == 1 {
            ramp = PigmentMixer.ramp(PigmentMixer.mix(inks[0], paper, 0.35), inks[0], steps: 6)
        } else {
            ramp = PigmentMixer.expand(inks, between: 6)
        }
        let hue = FX.gradientMap(remap(blend, 2.6, 0.5), ramp)
        // How much pigment: thinner washes show more paper.
        // Steep enough that washes end in shapes, with bare paper between them.
        let density = remap(field(e, seed: seed &+ 11, cells: max(3, cellsBig)), 4.0, 0.2 + 0.5 * strength)
        let paperImg = FX.solid(paper, e)
        var wash = hue.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: paperImg, kCIInputMaskImageKey: density]).cropped(to: e)
        // Tide lines: pigment pools where a bloom dried.
        // Smooth first, so only the real bloom edges show, not every ripple in the noise.
        let smooth = FX.blur(density, unit * 0.06)
        let shifted = smooth.clampedToExtent().transformed(by: CGAffineTransform(translationX: unit * 0.03, y: unit * 0.03)).cropped(to: e)
        let edge = FX.mono(FX.blend(shifted, over: smooth, mode: "CIDifferenceBlendMode"))
        let k: Double = 5 * (0.4 + wetness)
        let tide = remap(edge, -k * 2, 1 - k)   // 1 - 2k * edge
        wash = FX.blend(FX.mix(FX.solid(.white, e), tide, 0.5), over: wash, mode: "CIMultiplyBlendMode")
        // Soft bleeding edges between paints.
        wash = FX.displace(wash, by: field(e, seed: seed &+ 21, cells: cellsSmall * 2), scale: unit * CGFloat(0.03 + 0.08 * wetness))
        // Granulation last, so the paper's tooth stays put while the paint moves.
        if granulation > 0 {
            let tooth = remap(FX.blur(FX.noise(e, seed: seed &+ 3, grainSize: 1, strength: 1), 0.6), 0.22 * granulation, 1 - 0.1 * granulation)
            wash = FX.blend(tooth, over: wash, mode: "CIMultiplyBlendMode")
        }
        return wash.cropped(to: e)
    }
}
