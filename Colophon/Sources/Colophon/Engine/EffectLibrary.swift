import CoreImage
import Foundation

enum EffectFamily: String, CaseIterable, Identifiable {
    case looks = "Signature Looks"
    case duotone = "Duotones"
    case gradientMap = "Gradient Maps"
    case grade = "Color Grades"
    case tone = "Tone & Film"
    case blur = "Blur & Motion"
    case wash = "Color Washes"
    case light = "Light Leaks"
    case atmosphere = "Atmosphere"
    case print = "Print & Halftone"
    case paint = "Paint & Art"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .looks: return "sparkles"
        case .duotone: return "circle.lefthalf.filled"
        case .gradientMap: return "slider.horizontal.below.rectangle"
        case .grade: return "camera.filters"
        case .tone: return "film"
        case .blur: return "wind"
        case .wash: return "drop.halffull"
        case .light: return "sun.max"
        case .atmosphere: return "cloud.fog"
        case .print: return "circle.grid.3x3"
        case .paint: return "paintbrush"
        }
    }
}

struct EffectPreset: Identifiable {
    let id: String
    let name: String
    let family: EffectFamily
    /// Colors that characterize the preset, for swatches and palette matching.
    let swatch: [RGBA]
    let apply: (CIImage, EffectContext) -> CIImage
}

/// Named colors that seed the effect library.
enum ColorBook {
    typealias Named = (name: String, color: RGBA)

    static func named(_ list: [(String, String)]) -> [Named] { list.map { ($0.0, RGBA(hex: $0.1)) } }

    static let inks: [Named] = named([
        ("Midnight", "0B1D3A"), ("Prussian", "0F2E4C"), ("Navy Ink", "1B2A4A"), ("Indigo", "2A2F6B"),
        ("Ink Black", "121417"), ("Charcoal", "2B2D31"), ("Graphite", "3A3D42"), ("Slate", "34495E"),
        ("Deep Teal", "0B4F55"), ("Pine", "1E3D2F"), ("Forest", "22442A"), ("Moss", "3F4F24"),
        ("Olive", "4B4A1E"), ("Oxblood", "4A0E17"), ("Crimson", "7A0F1E"), ("Wine", "5B1A2E"),
        ("Plum", "4A1942"), ("Aubergine", "3B1F3A"), ("Burgundy", "641B2B"), ("Rust", "7A2E12"),
        ("Umber", "4A2C17"), ("Espresso", "2E1C12"), ("Sepia Brown", "5A3A1F"), ("Bronze", "6B4A1C"),
        ("Storm", "2F3E4E"), ("Petrol", "13404A"), ("Cobalt", "1B3B8A"), ("Ultramarine", "23308C"),
        ("Violet Ink", "3A1F6B"), ("Jade", "0E5143"), ("Deep Emerald", "0B4A33"), ("Smoke", "3B3B44")
    ])

    static let vivid: [Named] = named([
        ("Vermilion", "E4572E"), ("Scarlet", "D7263D"), ("Coral", "FF6F59"), ("Tangerine", "F28C28"),
        ("Amber", "F2A541"), ("Saffron", "F4C430"), ("Lemon", "F2E863"), ("Chartreuse", "B5D33D"),
        ("Lime", "8BC34A"), ("Mint", "7FD8BE"), ("Seafoam", "4FB99F"), ("Teal", "1B998B"),
        ("Turquoise", "2EC4B6"), ("Aqua", "48CAE4"), ("Sky", "7EC8E3"), ("Azure", "2D7DD2"),
        ("Royal Blue", "2B59C3"), ("Periwinkle", "7B83EB"), ("Lavender", "B39DDB"), ("Violet", "8E44AD"),
        ("Orchid", "C77DFF"), ("Magenta", "D81E5B"), ("Fuchsia", "E0479E"), ("Rose", "F28AB2"),
        ("Blush", "F4C2C2"), ("Peach", "FFB38A"), ("Apricot", "FBB474"), ("Gold", "D4A017"),
        ("Brass", "B5A642"), ("Copper", "B87333"), ("Terracotta", "C8553D"), ("Brick", "B23A2E"),
        ("Cherry", "9E1B32"), ("Ruby", "9B111E"), ("Sand", "D8C3A5"), ("Bone", "EDE6D6"),
        ("Ivory", "F4F1E8"), ("Pearl", "E8E6E1"), ("Silver", "BFC5CC"), ("Steel", "7A8B99"),
        ("Ice", "D6EAF8"), ("Glacier", "A7D3E8"), ("Sage", "A3B18A"), ("Lichen", "8A9A5B"),
        ("Fern", "6B8E4E"), ("Ember", "FF5E3A"), ("Hot Pink", "FF2E88"), ("Electric Blue", "2F6BFF")
    ])

    static let shadowTints: [Named] = named([
        ("Teal", "0E5E6F"), ("Navy", "1B2A4A"), ("Indigo", "2A2F6B"), ("Forest", "1E4D2B"),
        ("Plum", "4A1942"), ("Crimson", "6B0F1A"), ("Umber", "4A2C17"), ("Slate", "34495E"),
        ("Petrol", "13404A"), ("Cyan", "0B6E8A"), ("Violet", "3A1F6B"), ("Olive", "4B4A1E"),
        ("Rust", "7A2E12"), ("Ink", "121417"), ("Emerald", "0B4A33"), ("Storm", "2F3E4E")
    ])

    static let highlightTints: [Named] = named([
        ("Amber", "F2A541"), ("Peach", "FFB38A"), ("Cream", "F3E9D2"), ("Rose", "F4C2C2")
    ])
}

/// 2,000+ presets generated from hand-tuned recipes crossed with a curated color book.
final class EffectLibrary {
    static let shared = EffectLibrary()

    let presets: [EffectPreset]
    private let index: [String: EffectPreset]

    static let strengthNames = ["Whisper", "Light", "Medium", "Strong", "Full"]
    static let strengthValues = [0.2, 0.4, 0.6, 0.8, 1.0]

    private init() {
        var list: [EffectPreset] = []
        EffectLibrary.buildDuotones(&list)
        EffectLibrary.buildGradientMaps(&list)
        EffectLibrary.buildGrades(&list)
        EffectLibrary.buildTones(&list)
        EffectLibrary.buildLeaks(&list)
        EffectLibrary.buildAtmosphere(&list)
        EffectLibrary.buildPrint(&list)
        EffectLibrary.buildPaint(&list)
        EffectLibrary.buildWashes(&list)
        EffectLibrary.buildLooks(&list)
        presets = list
        var idx: [String: EffectPreset] = [:]
        for p in list { idx[p.id] = p }
        index = idx
    }

    func preset(_ id: String) -> EffectPreset? { index[id] }

    func search(_ query: String, family: EffectFamily?) -> [EffectPreset] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return presets.filter { p in
            (family == nil || p.family == family) && (q.isEmpty || p.name.lowercased().contains(q) || p.family.rawValue.lowercased().contains(q))
        }
    }

    /// The duotone whose dark ink is closest to a given color (used by suggestions).
    func closestDuotone(to color: RGBA) -> EffectPreset? {
        presets.filter { $0.family == .duotone && $0.id.hasSuffix(".1") }
            .min { ($0.swatch.first?.distance(to: color) ?? 999) < ($1.swatch.first?.distance(to: color) ?? 999) }
    }

    static func slug(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "&", with: "and")
    }

    // MARK: Families

    private static func buildDuotones(_ list: inout [EffectPreset]) {
        let variants: [(String, Double, Double)] = [("Soft", 1.0, 0.75), ("Classic", 1.15, 1.0), ("Punchy", 1.45, 1.0)]
        for ink in ColorBook.inks {
            let h = ink.color.hsl
            let partners: [(String, String, RGBA)] = [
                ("bone", "Bone", RGBA(hex: "F3ECDD")),
                ("complement", "Opposite", RGBA(h: h.h + 180, s: 0.6, l: 0.84)),
                ("analogous", "Neighbor", RGBA(h: h.h + 35, s: 0.55, l: 0.8))
            ]
            for (pk, pn, light) in partners {
                for (vi, v) in variants.enumerated() {
                    let dark = ink.color, contrast = v.1, mixAmt = v.2
                    list.append(EffectPreset(
                        id: "duo.\(slug(ink.name)).\(pk).\(vi)",
                        name: "\(ink.name) on \(pn), \(v.0)",
                        family: .duotone, swatch: [dark, light],
                        apply: { i, _ in FX.mix(i, FX.gradientMap(i, [dark, light], contrast: contrast), mixAmt) }))
                }
            }
        }
    }

    private static func buildGradientMaps(_ list: inout [EffectPreset]) {
        let variants: [(String, Double, Double)] = [("Soft", 1.0, 0.7), ("Classic", 1.1, 1.0), ("Punchy", 1.4, 1.0)]
        for (n, ink) in ColorBook.inks.enumerated() {
            let mid = ColorBook.vivid[(n * 5) % ColorBook.vivid.count]
            let maps: [(String, String, [RGBA])] = [
                ("a", "\(ink.name), \(mid.name) & Light", [ink.color, mid.color, mid.color.withLightness(0.92)]),
                ("b", "Night, \(ink.name) & Opposite", [RGBA.nearBlack, ink.color.withLightness(0.3), ColorAdvisor.opposite(ink.color).withLightness(0.85)])
            ]
            for (mk, mn, stops) in maps {
                for (vi, v) in variants.enumerated() {
                    let contrast = v.1, amt = v.2
                    list.append(EffectPreset(
                        id: "gmap.\(slug(ink.name)).\(mk).\(vi)", name: "\(mn), \(v.0)",
                        family: .gradientMap, swatch: stops,
                        apply: { i, _ in FX.mix(i, FX.gradientMap(i, stops, contrast: contrast), amt) }))
                }
            }
        }
    }

    private static func buildGrades(_ list: inout [EffectPreset]) {
        let strengths: [(String, Double)] = [("Subtle", 0.35), ("Gentle", 0.55), ("Bold", 0.75), ("Full", 1.0)]
        for s in ColorBook.shadowTints {
            for hi in ColorBook.highlightTints {
                for (si, st) in strengths.enumerated() {
                    let sc = s.color, hc = hi.color, amt = st.1
                    list.append(EffectPreset(
                        id: "grade.\(slug(s.name))-\(slug(hi.name)).\(si)",
                        name: "\(s.name) Shadows, \(hi.name) Highlights, \(st.0)",
                        family: .grade, swatch: [sc, hc],
                        apply: { i, _ in FX.mix(i, FX.splitTone(i, shadows: sc, highlights: hc), amt) }))
                }
            }
        }
    }

    private typealias Recipe = (name: String, family: EffectFamily, run: (CIImage, EffectContext) -> CIImage)

    private static let toneRecipes: [Recipe] = [
        ("Noir", .tone, { i, _ in i.applyingFilter("CIPhotoEffectNoir") }),
        ("Chrome", .tone, { i, _ in i.applyingFilter("CIPhotoEffectChrome") }),
        ("Faded Print", .tone, { i, _ in i.applyingFilter("CIPhotoEffectFade") }),
        ("Instant", .tone, { i, _ in i.applyingFilter("CIPhotoEffectInstant") }),
        ("Process", .tone, { i, _ in i.applyingFilter("CIPhotoEffectProcess") }),
        ("Transfer", .tone, { i, _ in i.applyingFilter("CIPhotoEffectTransfer") }),
        ("Tonal", .tone, { i, _ in i.applyingFilter("CIPhotoEffectTonal") }),
        ("Mono", .tone, { i, _ in i.applyingFilter("CIPhotoEffectMono") }),
        ("Sepia", .tone, { i, _ in i.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 1.0]) }),
        ("High Contrast", .tone, { i, _ in FX.controls(i, contrast: 1.45) }),
        ("Matte", .tone, { i, _ in FX.curve(i, [(0, 0.12), (0.25, 0.3), (0.5, 0.52), (0.75, 0.76), (1, 0.94)]) }),
        ("Crushed Blacks", .tone, { i, _ in FX.curve(i, [(0, 0), (0.25, 0.1), (0.5, 0.46), (0.75, 0.8), (1, 1)]) }),
        ("Bleach Bypass", .tone, { i, _ in FX.controls(FX.blend(FX.mono(i), over: i, mode: "CIOverlayBlendMode"), saturation: 0.55, contrast: 1.2) }),
        ("Cross Process", .tone, { i, _ in FX.controls(FX.matrix(i, r: (1.1, 0, 0), g: (0, 1.05, 0), b: (0, 0, 0.78), bias: (0, 0, 0.1)), saturation: 1.15, contrast: 1.15) }),
        ("Warm", .tone, { i, _ in FX.matrix(i, r: (1.08, 0, 0), g: (0, 1.0, 0), b: (0, 0, 0.86), bias: (0.02, 0.01, 0)) }),
        ("Cool", .tone, { i, _ in FX.matrix(i, r: (0.9, 0, 0), g: (0, 1.0, 0), b: (0, 0, 1.1), bias: (0, 0.01, 0.03)) }),
        ("Desaturate", .tone, { i, _ in FX.controls(i, saturation: 0.35) }),
        ("Vibrant", .tone, { i, _ in i.applyingFilter("CIVibrance", parameters: ["inputAmount": 0.9]) }),
        ("Punch", .tone, { i, _ in FX.controls(i, saturation: 1.25, contrast: 1.2) }),
        ("Dream", .tone, { i, c in FX.controls(FX.bloom(i, radius: 14 * c.scale, intensity: 0.9), saturation: 1.1, brightness: 0.02) }),
        ("Gloom", .tone, { i, c in i.clampedToExtent().applyingFilter("CIGloom", parameters: [kCIInputRadiusKey: 12 * c.scale, kCIInputIntensityKey: 0.9]).cropped(to: i.extent) }),
        ("Sharpen", .tone, { i, _ in i.applyingFilter("CISharpenLuminance", parameters: ["inputSharpness": 0.9]) }),
        ("Clarity", .tone, { i, c in i.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: 24 * c.scale, kCIInputIntensityKey: 0.7]).cropped(to: i.extent) }),
        ("Vignette", .tone, { i, _ in FX.vignette(i, intensity: 0.7) }),
        ("Heavy Vignette", .tone, { i, _ in FX.vignette(i, intensity: 1.0, radiusFactor: 0.55) }),
        ("Lift Shadows", .tone, { i, _ in i.applyingFilter("CIHighlightShadowAdjust", parameters: ["inputShadowAmount": 0.9, "inputHighlightAmount": 1.0]) }),
        ("Recover Highlights", .tone, { i, _ in i.applyingFilter("CIHighlightShadowAdjust", parameters: ["inputShadowAmount": 0.0, "inputHighlightAmount": 0.35]) }),
        ("Brighten", .tone, { i, _ in i.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.6]) }),
        ("Darken", .tone, { i, _ in i.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -0.8]) }),
        ("Invert", .tone, { i, _ in i.applyingFilter("CIColorInvert") }),
        ("Posterize", .tone, { i, _ in i.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 5]) }),
        ("Fine Grain", .tone, { i, c in FX.grain(i, seed: c.seed, strength: 0.16, size: max(1, 1.2 * c.scale)) }),
        ("Coarse Grain", .tone, { i, c in FX.grain(i, seed: c.seed, strength: 0.28, size: max(1, 2.6 * c.scale)) }),
        ("Dusty Film", .tone, { i, c in FX.grain(FX.matrix(i.applyingFilter("CIPhotoEffectFade"), r: (1.05, 0, 0), g: (0, 1, 0), b: (0, 0, 0.9)), seed: c.seed, strength: 0.2, size: max(1, 1.8 * c.scale)) }),
        ("Moonlight", .tone, { i, _ in FX.controls(FX.tint(FX.mono(i), RGBA(hex: "7FA7D9"), intensity: 0.75), brightness: -0.06, contrast: 1.1) }),
        ("Infrared", .tone, { i, _ in FX.matrix(i, r: (0, 1, 0), g: (1, 0, 0), b: (0, 0, 1)) }),
        ("Motion Smear", .blur, { i, c in i.clampedToExtent().applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: 40 * c.scale, kCIInputAngleKey: 0.0]).cropped(to: i.extent) }),
        ("Vertical Smear", .blur, { i, c in i.clampedToExtent().applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: 40 * c.scale, kCIInputAngleKey: Double.pi / 2]).cropped(to: i.extent) }),
        ("Zoom Burst", .blur, { i, c in i.clampedToExtent().applyingFilter("CIZoomBlur", parameters: [kCIInputCenterKey: FX.center(i), "inputAmount": 24 * c.scale]).cropped(to: i.extent) }),
        ("Bokeh", .blur, { i, c in i.clampedToExtent().applyingFilter("CIBokehBlur", parameters: [kCIInputRadiusKey: 14 * c.scale, "inputRingAmount": 0.0, "inputRingSize": 0.1, "inputSoftness": 1.0]).cropped(to: i.extent) }),
        ("Soft Focus", .blur, { i, c in FX.blend(FX.blur(i, 10 * c.scale), over: i, mode: "CIScreenBlendMode") }),
        ("Background Blur", .blur, { i, c in FX.blur(i, 18 * c.scale) }),
        ("Tilt Shift", .blur, { i, c in
            let e = i.extent
            let top = FX.linear(CGPoint(x: 0, y: e.maxY), CGPoint(x: 0, y: e.midY + e.height * 0.12), .white, .black, extent: e)
            let bottom = FX.linear(CGPoint(x: 0, y: e.minY), CGPoint(x: 0, y: e.midY - e.height * 0.12), .white, .black, extent: e)
            let mask = top.applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: bottom])
            return FX.blur(i, 16 * c.scale).applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: i, kCIInputMaskImageKey: mask])
        }),
        ("Twirl", .blur, { i, _ in i.clampedToExtent().applyingFilter("CITwirlDistortion", parameters: [kCIInputCenterKey: FX.center(i), kCIInputRadiusKey: min(i.extent.width, i.extent.height) * 0.55, kCIInputAngleKey: 1.6]).cropped(to: i.extent) }),
        ("Ripple Smear", .blur, { i, c in FX.displace(i, by: FX.smoothNoise(i.extent, seed: c.seed, cells: 5), scale: 60 * c.scale) })
    ]

    private static func buildTones(_ list: inout [EffectPreset]) {
        for r in toneRecipes {
            for (si, sv) in strengthValues.enumerated() {
                let run = r.run
                list.append(EffectPreset(
                    id: "tone.\(slug(r.name)).\(si)", name: "\(r.name), \(strengthNames[si])",
                    family: r.family, swatch: [],
                    apply: { i, c in FX.mix(i, run(i, c), sv) }))
            }
        }
    }

    private static func buildLeaks(_ list: inout [EffectPreset]) {
        let positions: [(String, String, CGFloat, CGFloat)] = [
            ("tl", "Top Left", 0, 1), ("tr", "Top Right", 1, 1), ("bl", "Bottom Left", 0, 0), ("br", "Bottom Right", 1, 0), ("top", "Top Edge", 0.5, 1.1)
        ]
        for v in ColorBook.vivid {
            for p in positions {
                let col = v.color, px = p.2, py = p.3
                list.append(EffectPreset(
                    id: "leak.\(slug(v.name)).\(p.0)", name: "\(v.name) Leak, \(p.1)",
                    family: .light, swatch: [col],
                    apply: { i, _ in
                        let e = i.extent
                        let c = CGPoint(x: e.minX + e.width * px, y: e.minY + e.height * py)
                        let glow = FX.radial(center: c, r0: 0, r1: max(e.width, e.height) * 0.85, c0: col.withAlpha(0.95), c1: col.withAlpha(0), extent: e)
                        return FX.blend(glow, over: i, mode: "CIScreenBlendMode")
                    }))
            }
        }
    }

    private static func buildAtmosphere(_ list: inout [EffectPreset]) {
        let kinds: [(String, String)] = [("fog", "Low Fog"), ("haze", "High Haze"), ("mist", "Mist"), ("smoke", "Drifting Smoke")]
        for v in ColorBook.vivid.prefix(24) {
            for k in kinds {
                let col = v.color.withLightness(max(v.color.hsl.l, 0.7)), kind = k.0
                list.append(EffectPreset(
                    id: "atmo.\(slug(v.name)).\(kind)", name: "\(v.name) \(k.1)",
                    family: .atmosphere, swatch: [col],
                    apply: { i, c in
                        let e = i.extent
                        switch kind {
                        case "fog":
                            let g = FX.linear(CGPoint(x: 0, y: e.minY), CGPoint(x: 0, y: e.minY + e.height * 0.55), col.withAlpha(0.85), col.withAlpha(0), extent: e)
                            return g.applyingFilter("CISourceOverCompositing", parameters: [kCIInputBackgroundImageKey: i])
                        case "haze":
                            let g = FX.linear(CGPoint(x: 0, y: e.maxY), CGPoint(x: 0, y: e.maxY - e.height * 0.6), col.withAlpha(0.7), col.withAlpha(0), extent: e)
                            return FX.blend(g, over: i, mode: "CIScreenBlendMode")
                        case "mist":
                            return FX.mix(i, FX.blend(FX.solid(col.withAlpha(0.5), e), over: FX.blur(i, 4 * c.scale), mode: "CISourceOverCompositing"), 0.6)
                        default:
                            let n = FX.smoothNoise(e, seed: c.seed, cells: 4)
                            let smoke = FX.tint(n, col, intensity: 1).applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.6])
                            return FX.blend(smoke, over: i, mode: "CIScreenBlendMode")
                        }
                    }))
            }
        }
    }

    private static func buildPrint(_ list: inout [EffectPreset]) {
        let screens = ["Dot Screen", "Line Screen", "Hatched Screen", "Circular Screen", "Pixel Mosaic", "Hex Mosaic"]
        let sizes: [CGFloat] = [3, 4.5, 6, 8, 11, 15, 20, 28]
        for s in screens {
            for (zi, z) in sizes.enumerated() {
                for color in [false, true] {
                    let name = s
                    list.append(EffectPreset(
                        id: "print.\(slug(s)).\(zi).\(color ? "color" : "mono")",
                        name: "\(s) \(zi + 1)\(color ? ", Overprint" : "")",
                        family: .print, swatch: [],
                        apply: { i, c in
                            let w = z * c.scale
                            let src = color ? i : FX.mono(i)
                            var out: CIImage
                            switch name {
                            case "Dot Screen": out = src.applyingFilter("CIDotScreen", parameters: [kCIInputCenterKey: FX.center(i), kCIInputAngleKey: 0.4, kCIInputWidthKey: w, kCIInputSharpnessKey: 0.7])
                            case "Line Screen": out = src.applyingFilter("CILineScreen", parameters: [kCIInputCenterKey: FX.center(i), kCIInputAngleKey: 0.8, kCIInputWidthKey: w, kCIInputSharpnessKey: 0.7])
                            case "Hatched Screen": out = src.applyingFilter("CIHatchedScreen", parameters: [kCIInputCenterKey: FX.center(i), kCIInputAngleKey: 0.5, kCIInputWidthKey: w, kCIInputSharpnessKey: 0.7])
                            case "Circular Screen": out = src.applyingFilter("CICircularScreen", parameters: [kCIInputCenterKey: FX.center(i), kCIInputWidthKey: w, kCIInputSharpnessKey: 0.7])
                            case "Pixel Mosaic": out = src.applyingFilter("CIPixellate", parameters: [kCIInputCenterKey: FX.center(i), kCIInputScaleKey: w * 1.5])
                            default: out = src.applyingFilter("CIHexagonalPixellate", parameters: [kCIInputCenterKey: FX.center(i), kCIInputScaleKey: w * 1.5])
                            }
                            out = out.cropped(to: i.extent)
                            if color && name.hasSuffix("Screen") { out = FX.blend(out, over: i, mode: "CIMultiplyBlendMode") }
                            return out
                        }))
                }
            }
        }
    }

    private static let paintRecipes: [(String, (CIImage, EffectContext, Double) -> CIImage)] = [
        ("Crystallize", { i, c, k in i.clampedToExtent().applyingFilter("CICrystallize", parameters: [kCIInputRadiusKey: (8 + 30 * k) * c.scale, kCIInputCenterKey: FX.center(i)]).cropped(to: i.extent) }),
        ("Pointillism", { i, c, k in i.clampedToExtent().applyingFilter("CIPointillize", parameters: [kCIInputRadiusKey: (3 + 12 * k) * c.scale, kCIInputCenterKey: FX.center(i)]).cropped(to: i.extent) }),
        ("Comic", { i, _, k in FX.mix(i, i.applyingFilter("CIComicEffect"), k) }),
        ("Line Art", { i, _, k in FX.mix(i, i.applyingFilter("CILineOverlay").composited(over: FX.solid(.paper, i.extent)), k) }),
        ("Pop Poster", { i, _, k in FX.controls(i.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 8 - 5 * k]), saturation: 1.3, contrast: 1.15) }),
        ("Oil Paint", { i, c, k in
            var o = i
            for _ in 0..<(1 + Int(k * 3)) { o = o.applyingFilter("CIMedianFilter") }
            return o.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: 6 * c.scale, kCIInputIntensityKey: 1.2]).cropped(to: i.extent)
        }),
        ("Watercolor", { i, c, k in
            let soft = FX.blur(i.applyingFilter("CIMedianFilter").applyingFilter("CIMedianFilter"), (1 + 2 * k) * c.scale)
            let edges = i.applyingFilter("CILineOverlay").composited(over: FX.solid(.white, i.extent))
            return FX.controls(FX.mix(soft, FX.blend(edges, over: soft, mode: "CIMultiplyBlendMode"), 0.5), saturation: 1.15, brightness: 0.04)
        }),
        ("Charcoal", { i, _, k in
            let lines = i.applyingFilter("CILineOverlay").composited(over: FX.solid(.paper, i.extent))
            return FX.mix(i, FX.blend(FX.controls(FX.mono(i), brightness: 0.1, contrast: 0.8), over: lines, mode: "CIMultiplyBlendMode"), k)
        }),
        ("Pastel", { i, c, k in FX.controls(FX.bloom(i, radius: 10 * c.scale, intensity: 0.6), saturation: 1 - 0.4 * k, brightness: 0.08 * k, contrast: 0.9) }),
        ("Stained Glass", { i, c, k in
            let cr = i.clampedToExtent().applyingFilter("CICrystallize", parameters: [kCIInputRadiusKey: (14 + 26 * k) * c.scale, kCIInputCenterKey: FX.center(i)]).cropped(to: i.extent)
            let edges = FX.controls(cr.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 6.0]), saturation: 0).applyingFilter("CIColorInvert")
            return FX.blend(edges, over: FX.controls(cr, saturation: 1.3), mode: "CIMultiplyBlendMode")
        }),
        ("Neon Edges", { i, _, k in FX.blend(i.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 2 + 8 * k]), over: FX.controls(i, brightness: -0.35), mode: "CIScreenBlendMode") }),
        ("Woodcut", { i, c, k in
            let m = FX.controls(FX.mono(i), contrast: 2.5 + 2 * k)
            return FX.grain(m.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 3]), seed: c.seed, strength: 0.15, size: max(1, 2 * c.scale))
        })
    ]

    private static func buildPaint(_ list: inout [EffectPreset]) {
        let levels: [(String, Double)] = [("Fine", 0.15), ("Medium", 0.45), ("Bold", 0.75), ("Heavy", 1.0)]
        for r in paintRecipes {
            for (li, l) in levels.enumerated() {
                let run = r.1, k = l.1
                list.append(EffectPreset(id: "paint.\(slug(r.0)).\(li)", name: "\(r.0), \(l.0)", family: .paint, swatch: [],
                                         apply: { i, c in run(i, c, k) }))
            }
        }
    }

    private static func buildWashes(_ list: inout [EffectPreset]) {
        let kinds: [(String, String)] = [("tint", "Tint"), ("color", "Color Wash"), ("multiply", "Ink Wash")]
        for v in ColorBook.vivid {
            for k in kinds {
                let col = v.color, kind = k.0
                list.append(EffectPreset(
                    id: "wash.\(slug(v.name)).\(kind)", name: "\(v.name) \(k.1)", family: .wash, swatch: [col],
                    apply: { i, _ in
                        switch kind {
                        case "tint": return FX.tint(i, col, intensity: 0.65)
                        case "color": return FX.mix(i, FX.blend(FX.solid(col, i.extent), over: i, mode: "CIColorBlendMode"), 0.7)
                        default: return FX.mix(i, FX.blend(FX.solid(col, i.extent), over: i, mode: "CIMultiplyBlendMode"), 0.75)
                        }
                    }))
            }
        }
    }

    private static func buildLooks(_ list: inout [EffectPreset]) {
        let finishes: [(String, String, (CIImage, EffectContext) -> CIImage)] = [
            ("grain", "Film Grain", { i, c in FX.grain(i, seed: c.seed, strength: 0.18, size: max(1, 1.5 * c.scale)) }),
            ("vignette", "Vignette", { i, _ in FX.vignette(i, intensity: 0.8) }),
            ("bloom", "Bloom", { i, c in FX.bloom(i, radius: 12 * c.scale, intensity: 0.7) }),
            ("matte", "Matte", { i, _ in FX.curve(i, [(0, 0.1), (0.25, 0.28), (0.5, 0.52), (0.75, 0.77), (1, 0.95)]) }),
            ("halftone", "Fine Halftone", { i, c in FX.mix(i, FX.blend(i.applyingFilter("CIDotScreen", parameters: [kCIInputCenterKey: FX.center(i), kCIInputAngleKey: 0.4, kCIInputWidthKey: 4 * c.scale, kCIInputSharpnessKey: 0.6]).cropped(to: i.extent), over: i, mode: "CIMultiplyBlendMode"), 0.45) }),
            ("clarity", "Clarity", { i, c in i.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: 20 * c.scale, kCIInputIntensityKey: 0.6]).cropped(to: i.extent) }),
            ("glow", "Soft Glow", { i, c in FX.mix(i, FX.blend(FX.blur(i, 12 * c.scale), over: i, mode: "CISoftLightBlendMode"), 0.8) }),
            ("cinematic", "Cinematic", { i, c in FX.grain(FX.vignette(FX.controls(i, saturation: 0.9, contrast: 1.18), intensity: 0.9), seed: c.seed, strength: 0.12, size: max(1, 1.2 * c.scale)) })
        ]
        for s in ColorBook.shadowTints {
            for hi in ColorBook.highlightTints {
                for f in finishes {
                    let sc = s.color, hc = hi.color, finish = f.2
                    list.append(EffectPreset(
                        id: "look.\(slug(s.name))-\(slug(hi.name)).\(f.0)",
                        name: "\(s.name) & \(hi.name), \(f.1)",
                        family: .looks, swatch: [sc, hc],
                        apply: { i, c in finish(FX.mix(i, FX.splitTone(i, shadows: sc, highlights: hc), 0.7), c) }))
                }
            }
        }
    }
}
