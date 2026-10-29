import CoreGraphics
import Foundation

// MARK: - Pixel sampling

struct RegionStats {
    var mean: RGBA
    /// Standard deviation of luminance. Above ~0.18 the area reads as "busy".
    var busyness: Double
}

enum PixelSampler {
    /// RGBA8 pixels, first row = top of the image.
    static func pixels(_ img: CGImage, maxSide: Int = 160) -> (data: [UInt8], w: Int, h: Int) {
        let scale = min(1, Double(maxSide) / Double(max(img.width, img.height)))
        let w = max(1, Int(Double(img.width) * scale)), h = max(1, Int(Double(img.height) * scale))
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        buf.withUnsafeMutableBytes { ptr in
            guard let ctx = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: Gfx.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.interpolationQuality = .medium
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return (buf, w, h)
    }

    static func stats(_ img: CGImage, region: NRect) -> RegionStats {
        let p = pixels(img)
        let x0 = Int((region.x.clamped01 * Double(p.w)).rounded(.down))
        let x1 = max(x0 + 1, Int((region.maxX.clamped01 * Double(p.w)).rounded(.up)))
        let y0 = Int((region.y.clamped01 * Double(p.h)).rounded(.down))
        let y1 = max(y0 + 1, Int((region.maxY.clamped01 * Double(p.h)).rounded(.up)))
        var sr = 0.0, sg = 0.0, sb = 0.0, n = 0.0
        var lums: [Double] = []
        for y in y0..<min(y1, p.h) {
            for x in x0..<min(x1, p.w) {
                let i = (y * p.w + x) * 4
                let r = Double(p.data[i]) / 255, g = Double(p.data[i + 1]) / 255, b = Double(p.data[i + 2]) / 255
                sr += r; sg += g; sb += b; n += 1
                lums.append(RGBA(r, g, b).luminance)
            }
        }
        guard n > 0 else { return RegionStats(mean: .black, busyness: 0) }
        let mean = RGBA(sr / n, sg / n, sb / n)
        let ml = lums.reduce(0, +) / Double(lums.count)
        let variance = lums.reduce(0) { $0 + pow($1 - ml, 2) } / Double(lums.count)
        return RegionStats(mean: mean, busyness: sqrt(variance))
    }
}

// MARK: - Palette extraction

struct PaletteRoles {
    var colors: [RGBA]
    var dominant: RGBA
    /// Deep enough for scrims and dark grounds.
    var dark: RGBA
    /// Pale enough for type on dark grounds.
    var light: RGBA
    /// The most vivid color, tuned to read as an accent.
    var accent: RGBA

    init(_ colors: [RGBA]) {
        let cols = colors.isEmpty ? [RGBA.ink, RGBA.paper, RGBA(hex: "E4572E")] : colors
        self.colors = cols
        dominant = cols[0]
        let byLum = cols.sorted { $0.luminance < $1.luminance }
        let d = byLum.first!.hsl
        dark = RGBA(h: d.h, s: min(d.s, 0.55), l: min(d.l, 0.1))
        let l = byLum.last!.hsl
        light = RGBA(h: l.h, s: min(l.s, 0.35), l: max(l.l, 0.93))
        let vivid = cols.max { ($0.hsl.s * (1 - abs($0.hsl.l - 0.5))) < ($1.hsl.s * (1 - abs($1.hsl.l - 0.5))) }!.hsl
        accent = RGBA(h: vivid.h, s: max(vivid.s, 0.55), l: vivid.l.clamped(0.45, 0.62))
    }

    /// The complementary twist: keep the dark ground, swap the accent for its opposite.
    var complementary: PaletteRoles {
        var p = self
        p.accent = ColorAdvisor.opposite(accent)
        p.light = RGBA(h: p.accent.hsl.h, s: 0.25, l: 0.93)
        return p
    }
}

enum PaletteExtractor {
    /// k-means over a small downsample, sorted by how much of the image each color covers.
    static func extract(_ img: CGImage, k: Int = 6) -> [RGBA] {
        let p = PixelSampler.pixels(img, maxSide: 72)
        var pts: [(Double, Double, Double)] = []
        pts.reserveCapacity(p.w * p.h)
        for i in stride(from: 0, to: p.data.count, by: 4) where p.data[i + 3] > 32 {
            pts.append((Double(p.data[i]) / 255, Double(p.data[i + 1]) / 255, Double(p.data[i + 2]) / 255))
        }
        guard pts.count >= k else { return pts.map { RGBA($0.0, $0.1, $0.2) } }

        // Deterministic k-means++ style seeding: spread centers by distance.
        var centers = [pts[pts.count / 2]]
        while centers.count < k {
            var best = pts[0], bestD = -1.0
            for (i, q) in pts.enumerated() where i % 3 == 0 {
                let d = centers.map { dist($0, q) }.min()!
                if d > bestD { bestD = d; best = q }
            }
            centers.append(best)
        }
        var counts = [Int](repeating: 0, count: k)
        for _ in 0..<10 {
            var sums = [(Double, Double, Double)](repeating: (0, 0, 0), count: k)
            counts = [Int](repeating: 0, count: k)
            for q in pts {
                var bi = 0, bd = Double.greatestFiniteMagnitude
                for (ci, c) in centers.enumerated() {
                    let d = dist(c, q)
                    if d < bd { bd = d; bi = ci }
                }
                sums[bi].0 += q.0; sums[bi].1 += q.1; sums[bi].2 += q.2
                counts[bi] += 1
            }
            for i in 0..<k where counts[i] > 0 {
                let n = Double(counts[i])
                centers[i] = (sums[i].0 / n, sums[i].1 / n, sums[i].2 / n)
            }
        }
        let ranked = zip(centers, counts).sorted { $0.1 > $1.1 }.map { RGBA($0.0.0, $0.0.1, $0.0.2) }
        // Drop near-duplicates so the palette has distinct voices.
        var out: [RGBA] = []
        for c in ranked where !out.contains(where: { $0.distance(to: c) < 9 }) { out.append(c) }
        return out
    }

    private static func dist(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let dr = a.0 - b.0, dg = a.1 - b.1, db = a.2 - b.2
        return 0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db
    }
}

// MARK: - Harmony and advice

enum Harmony: String, CaseIterable, Identifiable {
    case complementary = "Complementary"
    case splitComplementary = "Split Complementary"
    case analogous = "Analogous"
    case triadic = "Triadic"
    case tetradic = "Tetradic"
    case monochromatic = "Monochromatic"

    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .complementary: return "Opposites on the wheel. Maximum tension and pop."
        case .splitComplementary: return "One color against the two beside its opposite. Vivid but calmer."
        case .analogous: return "Neighbors on the wheel. Cohesive, moody, cinematic."
        case .triadic: return "Three evenly spaced hues. Playful and balanced."
        case .tetradic: return "Two complementary pairs. Rich; let one color lead."
        case .monochromatic: return "One hue, many values. Elegant and always safe."
        }
    }

    func colors(from base: RGBA) -> [RGBA] {
        switch self {
        case .complementary:
            return [base.adjusting(lightness: -0.25), base, base.complement, base.complement.adjusting(lightness: 0.25)]
        case .splitComplementary:
            return [base, base.adjusting(hue: 150), base.adjusting(hue: 210)]
        case .analogous:
            return [base.adjusting(hue: -30), base, base.adjusting(hue: 30), base.adjusting(hue: 60)]
        case .triadic:
            return [base, base.adjusting(hue: 120), base.adjusting(hue: 240)]
        case .tetradic:
            return [base, base.adjusting(hue: 90), base.adjusting(hue: 180), base.adjusting(hue: 270)]
        case .monochromatic:
            return base.shades(5)
        }
    }
}

enum ColorAdvisor {
    /// The opposite color tuned for type: complementary hue, lightness flipped for contrast.
    static func opposite(_ c: RGBA) -> RGBA {
        let h = c.hsl
        return RGBA(h: h.h + 180, s: max(0.45, h.s), l: h.l < 0.5 ? 0.78 : 0.24)
    }

    /// First candidate meeting the contrast floor wins (candidates are in taste order),
    /// otherwise the highest-contrast option including off-white and off-black.
    static func bestText(on bg: RGBA, candidates: [RGBA], minimum: Double) -> RGBA {
        if let ok = candidates.first(where: { $0.contrast(with: bg) >= minimum }) { return ok }
        let all = candidates + [RGBA.nearWhite, RGBA.nearBlack]
        return all.max { $0.contrast(with: bg) < $1.contrast(with: bg) }!
    }

    static func textCandidates(_ p: PaletteRoles, onDark: Bool) -> [RGBA] {
        onDark ? [p.light, p.accent.withLightness(0.75), RGBA.nearWhite] : [p.dark, p.accent.withLightness(0.28), RGBA.nearBlack]
    }
}
