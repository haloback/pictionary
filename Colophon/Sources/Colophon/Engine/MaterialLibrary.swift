import CoreGraphics
import CoreImage
import Foundation

/// Thousands of procedural materials. Each is a grayscale structure (marble veins, wood grain,
/// linen, scratches...) printed in a colorway, at a fine or bold scale. The same structures,
/// left gray, double as texture masks. The "Cover Palette" colorway prints in the cover's colors.
final class MaterialLibrary {
    static let shared = MaterialLibrary()

    enum MaskMode: String { case soft, hard, inverted }

    struct Structure {
        let id: String
        let name: String
        let category: String
        let tags: [String]
        let make: (CGRect, CGFloat, Int) -> CIImage
    }

    struct Colorway {
        let id: String
        let name: String
        /// Dark to light. nil prints in the cover palette.
        let stops: [RGBA]?
        let tags: [String]
    }

    struct Material: Identifiable, Hashable {
        let id: String
        let name: String
        let category: String
        let tags: [String]
        let structureID: String
        let colorwayID: String?
        let bold: Bool
        let mask: MaskMode?

        static func == (a: Material, b: Material) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    let structures: [Structure]
    let colorways: [Colorway]
    let materials: [Material]
    let categories: [String]
    private let structureIndex: [String: Structure]
    private let colorwayIndex: [String: Colorway]
    private let index: [String: Material]

    func material(_ id: String) -> Material? { index[id] }

    func search(_ query: String, category: String?, masksOnly: Bool = false) -> [Material] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        return materials.filter { m in
            if masksOnly != (m.mask != nil) { return false }
            if let category, m.category != category { return false }
            guard !words.isEmpty else { return true }
            let hay = (m.name + " " + m.category + " " + m.tags.joined(separator: " ")).lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
    }

    /// The material as an image filling `extent` (origin at zero).
    func render(_ id: String, extent e: CGRect, palette: [RGBA], seed: Int = 1, scale: CGFloat = 1) -> CIImage {
        guard let m = index[id], let s = structureIndex[m.structureID] else { return FX.solid(RGBA(0.5, 0.5, 0.5), e) }
        let unit = max(4, min(e.width, e.height) * (m.bold ? 0.14 : 0.055) * max(0.2, scale))
        let gray = FX.mono(s.make(e, unit, seed)).cropped(to: e)
        if let mode = m.mask {
            switch mode {
            case .soft: return gray
            case .hard: return FX.controls(gray, contrast: 6).cropped(to: e)
            case .inverted: return gray.applyingFilter("CIColorInvert").cropped(to: e)
            }
        }
        var stops: [RGBA]
        if let cw = m.colorwayID.flatMap({ colorwayIndex[$0] }), let fixed = cw.stops {
            stops = fixed
        } else {
            let p = palette.isEmpty ? [RGBA.ink, RGBA(hex: "E4572E"), RGBA.paper] : palette
            stops = p.sorted { $0.luminance < $1.luminance }
            if stops.count == 1 { stops.append(stops[0].withLightness(0.9)) }
        }
        return FX.gradientMap(gray, stops).cropped(to: e)
    }

    func renderImage(_ id: String, size: CGSize, palette: [RGBA], seed: Int = 1) -> CGImage? {
        let e = CGRect(x: 0, y: 0, width: max(1, Int(size.width.rounded())), height: max(1, Int(size.height.rounded())))
        return Gfx.render(render(id, extent: e, palette: palette, seed: seed), extent: e)
    }

    // MARK: Building

    private init() {
        let s = MaterialLibrary.makeStructures()
        let c = MaterialLibrary.makeColorways()
        var list: [Material] = []
        for st in s {
            for cw in c {
                for bold in [false, true] {
                    list.append(Material(id: "mat.\(st.id).\(cw.id).\(bold ? "b" : "f")",
                                         name: "\(st.name), \(cw.name)\(bold ? ", Bold" : "")",
                                         category: st.category, tags: st.tags + cw.tags + [cw.name.lowercased()],
                                         structureID: st.id, colorwayID: cw.id, bold: bold, mask: nil))
                }
            }
        }
        for st in s {
            for (mode, label) in [(MaskMode.soft, "Soft"), (.hard, "Hard"), (.inverted, "Inverted")] {
                for bold in [false, true] {
                    list.append(Material(id: "mask.\(st.id).\(mode.rawValue).\(bold ? "b" : "f")",
                                         name: "\(st.name) Mask, \(label)\(bold ? ", Bold" : "")",
                                         category: "Masks", tags: st.tags + ["mask", label.lowercased(), st.category.lowercased()],
                                         structureID: st.id, colorwayID: nil, bold: bold, mask: mode))
                }
            }
        }
        structures = s
        colorways = c
        materials = list
        var cats: [String] = []
        for m in list where !cats.contains(m.category) { cats.append(m.category) }
        categories = cats
        structureIndex = Dictionary(uniqueKeysWithValues: s.map { ($0.id, $0) })
        colorwayIndex = Dictionary(uniqueKeysWithValues: c.map { ($0.id, $0) })
        var idx: [String: Material] = [:]
        for m in list { idx[m.id] = m }
        index = idx
    }

    private static func makeColorways() -> [Colorway] {
        func cw(_ id: String, _ name: String, _ hex: [String], _ tags: [String]) -> Colorway {
            Colorway(id: id, name: name, stops: hex.map { RGBA(hex: $0) }, tags: tags)
        }
        return [
            Colorway(id: "palette", name: "Cover Palette", stops: nil, tags: ["palette", "matching"]),
            cw("ink", "Ink", ["0E0F12", "2B2D31", "8A8D93", "E8E6E1"], ["black", "mono", "dark"]),
            cw("charcoal", "Charcoal", ["1A1A1C", "3E3E42", "6E6E74"], ["dark", "gray", "moody"]),
            cw("paper", "Cream Paper", ["C9BFA8", "E6DCC6", "F4EEE0", "FBF8F1"], ["paper", "light", "cream"]),
            cw("kraft", "Kraft", ["6E4F2E", "9C7A52", "C4A579"], ["brown", "kraft", "paper"]),
            cw("parchment", "Parchment", ["7A5A30", "C9A86A", "EAD8AE", "F6EBCF"], ["old", "vintage", "parchment"]),
            cw("gold", "Gold", ["5E4210", "B8862B", "F2D27A", "FFF1C1"], ["gold", "metal", "luxury"]),
            cw("silver", "Silver", ["3E4348", "8D9399", "D7DBDF", "FAFBFC"], ["silver", "metal", "cool"]),
            cw("copper", "Copper", ["4A230E", "A8592A", "E39A6A", "FFD2AE"], ["copper", "metal", "warm"]),
            cw("bronze", "Bronze", ["3A2810", "7A5A26", "B88E4A", "D9B06A"], ["bronze", "metal", "antique"]),
            cw("walnut", "Walnut", ["2A1A0E", "4A2E18", "6E4626", "8A5E36"], ["wood", "brown", "dark"]),
            cw("oak", "Oak", ["7A5A30", "A7804E", "C9A06A", "E2C38E"], ["wood", "light", "warm"]),
            cw("slate", "Slate", ["1E252B", "34495E", "6C7A89", "A3AFBB"], ["stone", "blue", "cool"]),
            cw("sandstone", "Sandstone", ["8A6A44", "C49A68", "E2C49A", "F2E2C4"], ["stone", "desert", "warm"]),
            cw("terracotta", "Terracotta", ["5A2214", "9A3E24", "C8553D", "E8A080"], ["clay", "warm", "earthy"]),
            cw("rose", "Rose", ["5A1A2E", "A8466A", "E08AA6", "F8D2DE"], ["pink", "romantic", "soft"]),
            cw("blush", "Blush", ["C89A92", "E2BEB6", "F2D8D2", "FBEEEA"], ["pink", "pastel", "soft"]),
            cw("sage", "Sage", ["3E4A36", "6B7A5A", "A3B18A", "D8E0C8"], ["green", "calm", "natural"]),
            cw("forest", "Forest", ["0E1E14", "1E3D2F", "3F6A4A", "7FA06A"], ["green", "dark", "nature"]),
            cw("ocean", "Ocean", ["06202E", "0B4F6C", "1B998B", "8FE0D8"], ["blue", "teal", "sea"]),
            cw("midnight", "Midnight", ["05070F", "0B1D3A", "23308C", "7B83EB"], ["blue", "night", "dark"]),
            cw("violet", "Violet", ["12082A", "3A1F6B", "8E44AD", "D8B8F2"], ["purple", "mystic", "night"]),
            cw("ember", "Ember", ["1A0604", "6B1A0A", "D24A12", "FFB43A", "FFF2B0"], ["fire", "warm", "glow"]),
            cw("neonpink", "Neon Pink", ["12041A", "5A0A4A", "FF2E88", "FFD6EE"], ["neon", "pink", "retro"]),
            cw("tealglow", "Teal Glow", ["02141A", "0B4F55", "2EC4B6", "D6FFF8"], ["neon", "teal", "sci-fi"]),
            cw("arctic", "Arctic", ["4A6E8A", "9CC4E0", "DCEEF8", "FFFFFF"], ["ice", "cold", "light"])
        ]
    }

    // MARK: Structures

    private static func makeStructures() -> [Structure] {
        func cells(_ e: CGRect, _ unit: CGFloat, _ k: CGFloat) -> Int { max(2, Int(e.width / max(1, unit * k))) }
        func stripes(_ e: CGRect, _ width: CGFloat, _ angle: CGFloat, sharp: Double = 0) -> CIImage {
            (CIFilter(name: "CIStripesGenerator", parameters: [
                "inputColor0": CIColor(red: 1, green: 1, blue: 1), "inputColor1": CIColor(red: 0, green: 0, blue: 0),
                kCIInputWidthKey: max(1, width), kCIInputSharpnessKey: sharp
            ])?.outputImage ?? CIImage.empty()).transformed(by: CGAffineTransform(rotationAngle: angle)).cropped(to: e)
        }
        func noise(_ e: CGRect, _ seed: Int, _ grain: CGFloat) -> CIImage { FX.mono(FX.noise(e, seed: seed, grainSize: max(1, grain), strength: 1)) }
        func smooth(_ e: CGRect, _ seed: Int, _ n: Int) -> CIImage { FX.smoothNoise(e, seed: seed, cells: n) }
        func gen(_ style: FillStyle, _ e: CGRect, _ seed: Int, _ k: Double = 0.5) -> CIImage {
            let f = FillContent(style: style, colors: [RGBA(0.08, 0.08, 0.08), RGBA(0.55, 0.55, 0.55), RGBA(0.9, 0.9, 0.9), RGBA(0.3, 0.3, 0.3)], seed: seed, intensity: k)
            return Generators.render(f, size: e.size).map { CIImage(cgImage: $0) } ?? FX.solid(RGBA(0.5, 0.5, 0.5), e)
        }
        func drawn(_ e: CGRect, _ draw: (CGContext, CGFloat, CGFloat) -> Void) -> CIImage {
            guard let ctx = Gfx.context(Int(e.width), Int(e.height)) else { return FX.solid(.white, e) }
            draw(ctx, e.width, e.height)
            return ctx.makeImage().map { CIImage(cgImage: $0) } ?? FX.solid(.white, e)
        }
        func crystal(_ e: CGRect, _ seed: Int, _ r: CGFloat) -> CIImage {
            noise(e, seed, 1).applyingFilter("CICrystallize", parameters: [kCIInputRadiusKey: max(2, r), kCIInputCenterKey: CIVector(x: e.midX, y: e.midY)]).cropped(to: e)
        }
        func edges(_ i: CIImage, _ intensity: Double) -> CIImage { FX.mono(i.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: intensity])).cropped(to: i.extent) }
        func streaks(_ e: CGRect, _ seed: Int, _ radius: CGFloat, _ angle: Double) -> CIImage {
            noise(e, seed, 1).clampedToExtent().applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: radius, kCIInputAngleKey: angle]).cropped(to: e)
        }

        return [
            // Stone & Mineral
            Structure(id: "marble", name: "Marble Veins", category: "Stone & Mineral", tags: ["marble", "veins", "luxury", "stone"]) { e, u, s in
                FX.controls(FX.displace(stripes(e, u * 0.7, 0.6), by: smooth(e, s, cells(e, u, 3)), scale: u * 4), contrast: 1.3)
            },
            Structure(id: "granite", name: "Granite", category: "Stone & Mineral", tags: ["granite", "speckle", "stone"]) { e, u, s in
                FX.controls(FX.blend(noise(e, s, u * 0.06), over: smooth(e, s &+ 1, cells(e, u, 1)), mode: "CIOverlayBlendMode"), contrast: 1.4)
            },
            Structure(id: "terrazzo", name: "Terrazzo", category: "Stone & Mineral", tags: ["terrazzo", "chips", "modern"]) { e, u, s in
                FX.controls(crystal(e, s, u * 0.35), brightness: 0.15, contrast: 3)
            },
            Structure(id: "slate", name: "Layered Slate", category: "Stone & Mineral", tags: ["slate", "layers", "stone"]) { e, u, s in
                FX.blend(noise(e, s, 1), over: FX.displace(stripes(e, u * 0.25, 0.05), by: smooth(e, s, cells(e, u, 4)), scale: u), mode: "CISoftLightBlendMode")
            },
            Structure(id: "cracked", name: "Cracked Earth", category: "Stone & Mineral", tags: ["cracked", "dry", "earth", "desert"]) { e, u, s in
                FX.controls(edges(crystal(e, s, u * 0.9), 10).applyingFilter("CIColorInvert"), contrast: 2.5)
            },
            Structure(id: "concrete", name: "Concrete", category: "Stone & Mineral", tags: ["concrete", "urban", "rough"]) { e, u, s in
                FX.blend(FX.controls(noise(e, s &+ 4, u * 0.05), brightness: 0.35, contrast: 4), over: FX.controls(smooth(e, s, cells(e, u, 1)), contrast: 0.6), mode: "CIMultiplyBlendMode")
            },
            Structure(id: "agate", name: "Agate Bands", category: "Stone & Mineral", tags: ["agate", "bands", "geode", "crystal"]) { e, u, s in
                drawn(e) { ctx, w, h in
                    var rng = SeededRNG(seed: s)
                    let c = CGPoint(x: w * CGFloat(rng.range(0.3, 0.7)), y: h * CGFloat(rng.range(0.3, 0.7)))
                    var r = max(w, h)
                    var i = 0
                    while r > 2 {
                        ctx.setFillColor(CGColor(gray: i % 2 == 0 ? 0.25 + CGFloat(rng.unit()) * 0.5 : 0.75 + CGFloat(rng.unit()) * 0.25, alpha: 1))
                        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r * 0.7, width: 2 * r, height: 1.4 * r))
                        r -= u * CGFloat(rng.range(0.1, 0.5))
                        i += 1
                    }
                }
            },
            // Wood
            Structure(id: "woodgrain", name: "Wood Grain", category: "Wood & Paper", tags: ["wood", "grain", "rustic"]) { e, u, s in
                let grain = FX.displace(stripes(e, u * 0.22, 0), by: smooth(e, s, cells(e, u, 6)), scale: u * 2.5)
                return FX.blend(streaks(e, s, u * 0.8, .pi / 2), over: grain, mode: "CISoftLightBlendMode")
            },
            Structure(id: "planks", name: "Wood Planks", category: "Wood & Paper", tags: ["wood", "planks", "floor"]) { e, u, s in
                let grain = FX.displace(stripes(e, u * 0.12, 0), by: smooth(e, s, cells(e, u, 4)), scale: u * 1.5)
                let seams = FX.controls(stripes(e, u * 1.6, 0, sharp: 1), contrast: 1)
                return FX.blend(FX.controls(seams, brightness: 0.4, contrast: 0.6), over: grain, mode: "CIMultiplyBlendMode")
            },
            Structure(id: "crumpled", name: "Crumpled Paper", category: "Wood & Paper", tags: ["paper", "crumpled", "creased"]) { e, u, s in
                let n = FX.blur(smooth(e, s, cells(e, u, 1.2)), u * 0.05)
                let shifted = n.transformed(by: CGAffineTransform(translationX: 2, y: 2))
                return FX.controls(FX.blend(shifted, over: n, mode: "CIDifferenceBlendMode").applyingFilter("CIColorInvert"), contrast: 3)
            },
            Structure(id: "fibers", name: "Paper Fibers", category: "Wood & Paper", tags: ["paper", "fibers", "handmade"]) { e, u, s in
                FX.blend(FX.controls(streaks(e, s &+ 3, u * 0.4, 0.8), contrast: 2), over: FX.controls(noise(e, s, 1), brightness: 0.3, contrast: 0.4), mode: "CIMultiplyBlendMode")
            },
            Structure(id: "linen", name: "Linen Weave", category: "Fabric & Leather", tags: ["linen", "fabric", "weave", "cloth"]) { e, u, s in
                FX.blend(noise(e, s, 1), over: FX.blend(stripes(e, u * 0.07, 0), over: stripes(e, u * 0.07, .pi / 2), mode: "CIMultiplyBlendMode"), mode: "CISoftLightBlendMode")
            },
            Structure(id: "canvas", name: "Canvas", category: "Fabric & Leather", tags: ["canvas", "fabric", "artist"]) { e, u, s in
                let weave = (CIFilter(name: "CICheckerboardGenerator", parameters: [
                    kCIInputCenterKey: CIVector(x: 0, y: 0), "inputColor0": CIColor(red: 0.7, green: 0.7, blue: 0.7), "inputColor1": CIColor(red: 0.45, green: 0.45, blue: 0.45),
                    kCIInputWidthKey: max(1.5, u * 0.05), kCIInputSharpnessKey: 0.4
                ])?.outputImage ?? CIImage.empty()).cropped(to: e)
                return FX.blend(noise(e, s, 1), over: FX.blur(weave, 0.6), mode: "CIOverlayBlendMode")
            },
            Structure(id: "denim", name: "Denim Twill", category: "Fabric & Leather", tags: ["denim", "twill", "fabric"]) { e, u, s in
                FX.blend(FX.controls(streaks(e, s, u * 0.3, .pi / 2), contrast: 2), over: stripes(e, u * 0.05, .pi / 4), mode: "CISoftLightBlendMode")
            },
            Structure(id: "leather", name: "Leather Grain", category: "Fabric & Leather", tags: ["leather", "grain", "luxury"]) { e, u, s in
                FX.blur(edges(crystal(e, s, u * 0.12), 4).applyingFilter("CIColorInvert"), 0.8)
            },
            Structure(id: "felt", name: "Felt", category: "Fabric & Leather", tags: ["felt", "soft", "fabric"]) { e, u, s in
                FX.controls(FX.blur(noise(e, s, 1), u * 0.02), contrast: 2.2)
            },
            // Paint & Ink
            Structure(id: "watercolor", name: "Watercolor Wash", category: "Paint & Ink", tags: ["watercolor", "wash", "soft", "paint"]) { e, _, s in gen(.watercolor, e, s) },
            Structure(id: "smear", name: "Paint Smear", category: "Paint & Ink", tags: ["paint", "smear", "streaks", "bold"]) { e, _, s in gen(.paintSmear, e, s) },
            Structure(id: "brush", name: "Brush Strokes", category: "Paint & Ink", tags: ["brush", "strokes", "paint", "expressive"]) { e, u, s in
                FX.controls(streaks(e, s, u * 1.2, Double(s % 7) * 0.45), contrast: 2.4)
            },
            Structure(id: "splatter", name: "Ink Splatter", category: "Paint & Ink", tags: ["splatter", "ink", "drops", "grunge"]) { e, u, s in
                drawn(e) { ctx, w, h in
                    ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                    var rng = SeededRNG(seed: s)
                    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
                    for _ in 0..<Int(6 + w / u) {
                        let c = CGPoint(x: w * CGFloat(rng.unit()), y: h * CGFloat(rng.unit()))
                        let r = u * CGFloat(pow(rng.unit(), 2.5) * 1.2 + 0.05)
                        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                        for _ in 0..<Int(rng.range(3, 14)) {
                            let a = rng.range(0, 2 * .pi), d = r * CGFloat(rng.range(1.1, 3))
                            let dr = r * CGFloat(rng.range(0.04, 0.22))
                            ctx.fillEllipse(in: CGRect(x: c.x + cos(a) * d - dr, y: c.y + sin(a) * d - dr, width: 2 * dr, height: 2 * dr))
                        }
                    }
                }
            },
            Structure(id: "spray", name: "Spray Paint", category: "Paint & Ink", tags: ["spray", "graffiti", "urban"]) { e, u, s in
                let haze = FX.radial(center: CGPoint(x: e.midX, y: e.midY), r0: 0, r1: max(e.width, e.height) * 0.6, c0: .black, c1: .white, extent: e)
                return FX.controls(FX.blend(noise(e, s, 1), over: haze, mode: "CIOverlayBlendMode"), contrast: 3)
            },
            Structure(id: "pour", name: "Acrylic Pour", category: "Paint & Ink", tags: ["pour", "fluid", "swirl", "marble"]) { e, u, s in
                FX.displace(FX.displace(stripes(e, u * 0.5, 1.1), by: smooth(e, s, cells(e, u, 5)), scale: u * 6), by: smooth(e, s &+ 9, cells(e, u, 2)), scale: u * 2)
            },
            Structure(id: "inkwash", name: "Ink Wash", category: "Paint & Ink", tags: ["ink", "sumi", "wash", "calm"]) { e, u, s in
                FX.displace(FX.controls(smooth(e, s, cells(e, u, 4)), contrast: 2), by: smooth(e, s &+ 2, cells(e, u, 0.8)), scale: u * 0.4)
            },
            // Grunge
            Structure(id: "grunge", name: "Grunge", category: "Grunge & Wear", tags: ["grunge", "dirty", "worn", "texture"]) { e, u, s in
                FX.blend(FX.controls(noise(e, s, u * 0.04), brightness: 0.4, contrast: 5), over: FX.controls(smooth(e, s &+ 1, cells(e, u, 1)), contrast: 2.5), mode: "CIMultiplyBlendMode")
            },
            Structure(id: "scratches", name: "Scratches", category: "Grunge & Wear", tags: ["scratches", "worn", "metal", "distressed"]) { e, u, s in
                FX.controls(streaks(e, s, u * 2.5, 0.25 + Double(s % 3) * 0.6), brightness: -0.42, contrast: 14).applyingFilter("CIColorInvert")
            },
            Structure(id: "dust", name: "Dust & Specks", category: "Grunge & Wear", tags: ["dust", "film", "specks", "vintage"]) { e, u, s in
                FX.controls(noise(e, s, u * 0.03), brightness: 0.47, contrast: 16)
            },
            Structure(id: "rust", name: "Rust Pitting", category: "Grunge & Wear", tags: ["rust", "corroded", "metal", "decay"]) { e, u, s in
                FX.blend(noise(e, s, u * 0.03), over: FX.controls(smooth(e, s, cells(e, u, 0.8)), contrast: 3), mode: "CIOverlayBlendMode")
            },
            Structure(id: "distressed", name: "Distressed Print", category: "Grunge & Wear", tags: ["distressed", "print", "worn", "vintage"]) { e, u, s in
                FX.blend(FX.controls(noise(e, s, u * 0.02), brightness: 0.45, contrast: 12), over: FX.controls(smooth(e, s, cells(e, u, 0.6)), brightness: 0.25, contrast: 4), mode: "CIMultiplyBlendMode")
            },
            Structure(id: "burnedges", name: "Burned Edges", category: "Grunge & Wear", tags: ["burn", "edges", "vintage", "fire"]) { e, u, s in
                let v = FX.radial(center: CGPoint(x: e.midX, y: e.midY), r0: min(e.width, e.height) * 0.3, r1: max(e.width, e.height) * 0.62, c0: .white, c1: .black, extent: e)
                return FX.controls(FX.blend(smooth(e, s, cells(e, u, 1)), over: v, mode: "CIOverlayBlendMode"), contrast: 3)
            },
            // Sky & Elements
            Structure(id: "clouds", name: "Clouds", category: "Sky & Elements", tags: ["clouds", "sky", "soft", "dreamy"]) { e, u, s in FX.controls(smooth(e, s, cells(e, u, 4)), contrast: 1.5) },
            Structure(id: "smoke", name: "Smoke", category: "Sky & Elements", tags: ["smoke", "mist", "mystery"]) { e, u, s in
                FX.controls(FX.displace(smooth(e, s, cells(e, u, 3)), by: smooth(e, s &+ 5, cells(e, u, 2)), scale: u * 2), contrast: 1.8)
            },
            Structure(id: "nebula", name: "Nebula", category: "Sky & Elements", tags: ["nebula", "space", "cosmic", "sci-fi"]) { e, u, s in
                let gas = FX.controls(FX.blend(smooth(e, s, cells(e, u, 2)), over: smooth(e, s &+ 7, cells(e, u, 5)), mode: "CIScreenBlendMode"), brightness: -0.2, contrast: 2.2)
                return FX.blend(FX.controls(noise(e, s, 1), brightness: -0.48, contrast: 20), over: gas, mode: "CIScreenBlendMode")
            },
            Structure(id: "stars", name: "Starfield", category: "Sky & Elements", tags: ["stars", "night", "space"]) { e, _, s in gen(.starfield, e, s) },
            Structure(id: "bokeh", name: "Bokeh Lights", category: "Sky & Elements", tags: ["bokeh", "lights", "festive", "romantic"]) { e, _, s in gen(.bokeh, e, s) },
            Structure(id: "aurora", name: "Aurora", category: "Sky & Elements", tags: ["aurora", "northern lights", "glow"]) { e, u, s in
                let curtains = FX.displace(FX.controls(streaks(e, s, u * 3, .pi / 2), contrast: 3), by: smooth(e, s, cells(e, u, 4)), scale: u * 3)
                return FX.blend(FX.linear(CGPoint(x: 0, y: e.maxY), CGPoint(x: 0, y: e.minY), .white, .black, extent: e), over: curtains, mode: "CIMultiplyBlendMode")
            },
            Structure(id: "fire", name: "Flames", category: "Sky & Elements", tags: ["fire", "flames", "heat"]) { e, u, s in
                FX.displace(FX.linear(CGPoint(x: 0, y: e.minY), CGPoint(x: 0, y: e.maxY), .white, .black, extent: e), by: smooth(e, s, cells(e, u, 1.5)), scale: u * 3)
            },
            Structure(id: "ripples", name: "Water Ripples", category: "Sky & Elements", tags: ["water", "ripples", "calm", "sea"]) { e, u, s in
                let rings = FX.solid(RGBA(0.5, 0.5, 0.5), e).applyingFilter("CICircularScreen", parameters: [
                    kCIInputCenterKey: CIVector(x: e.midX, y: e.midY * 0.8), kCIInputWidthKey: max(3, u * 0.5), kCIInputSharpnessKey: 0.2
                ]).cropped(to: e)
                return FX.displace(rings, by: smooth(e, s, cells(e, u, 3)), scale: u * 0.8)
            },
            Structure(id: "dunes", name: "Sand Dunes", category: "Sky & Elements", tags: ["sand", "dunes", "desert", "waves"]) { e, u, s in
                FX.displace(stripes(e, u * 0.45, 0.15), by: smooth(e, s, cells(e, u, 5)), scale: u * 2.5)
            },
            Structure(id: "frost", name: "Frost", category: "Sky & Elements", tags: ["frost", "ice", "winter", "cold"]) { e, u, s in
                FX.blend(edges(crystal(e, s, u * 0.1), 4), over: FX.controls(crystal(e, s &+ 1, u * 0.25), contrast: 0.6), mode: "CIScreenBlendMode")
            },
            Structure(id: "lightleak", name: "Light Leaks", category: "Sky & Elements", tags: ["light", "leak", "film", "warm"]) { e, u, s in
                FX.blur(drawn(e) { ctx, w, h in
                    ctx.setFillColor(CGColor(gray: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                    var rng = SeededRNG(seed: s)
                    for _ in 0..<5 {
                        let r = max(w, h) * CGFloat(rng.range(0.1, 0.35))
                        ctx.setFillColor(CGColor(gray: CGFloat(rng.range(0.5, 1)), alpha: 1))
                        ctx.fillEllipse(in: CGRect(x: w * CGFloat(rng.unit()) - r, y: h * CGFloat(rng.unit()) - r, width: 2 * r, height: 2 * r))
                    }
                }, max(e.width, e.height) * 0.08)
            },
            // Metal
            Structure(id: "brushedmetal", name: "Brushed Metal", category: "Metal", tags: ["metal", "brushed", "steel"]) { e, u, s in
                FX.blend(streaks(e, s, u * 2, 0), over: FX.linear(CGPoint(x: 0, y: e.maxY), CGPoint(x: 0, y: e.minY), RGBA(0.75, 0.75, 0.75), RGBA(0.35, 0.35, 0.35), extent: e), mode: "CIOverlayBlendMode")
            },
            Structure(id: "hammered", name: "Hammered Metal", category: "Metal", tags: ["metal", "hammered", "craft"]) { e, u, s in
                FX.blur(FX.controls(crystal(e, s, u * 0.25), contrast: 0.8), u * 0.04)
            },
            Structure(id: "diamondplate", name: "Diamond Plate", category: "Metal", tags: ["metal", "industrial", "tread"]) { e, u, _ in
                drawn(e) { ctx, w, h in
                    ctx.setFillColor(CGColor(gray: 0.45, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                    let step = max(6, u * 0.6)
                    var y: CGFloat = 0, row = 0
                    while y < h + step {
                        var x: CGFloat = row % 2 == 0 ? 0 : step / 2
                        while x < w + step {
                            ctx.saveGState()
                            ctx.translateBy(x: x, y: y)
                            ctx.rotate(by: row % 2 == 0 ? .pi / 4 : -.pi / 4)
                            ctx.setFillColor(CGColor(gray: 0.85, alpha: 1))
                            ctx.fill(CGRect(x: -step * 0.32, y: -step * 0.07, width: step * 0.64, height: step * 0.14))
                            ctx.restoreGState()
                            x += step
                        }
                        y += step / 2
                        row += 1
                    }
                }
            },
            // Pattern & Geometry
            Structure(id: "stripes", name: "Diagonal Stripes", category: "Pattern & Geometry", tags: ["stripes", "pattern", "bold"]) { e, u, _ in stripes(e, u * 0.35, .pi / 4, sharp: 1) },
            Structure(id: "polka", name: "Polka Dots", category: "Pattern & Geometry", tags: ["dots", "polka", "playful"]) { e, u, s in
                SurfaceGen.make(.polkaDots, extent: e, size: u * 2, seed: s, a: .white, b: .black)
            },
            Structure(id: "checker", name: "Checkerboard", category: "Pattern & Geometry", tags: ["checker", "pattern", "retro"]) { e, u, s in
                SurfaceGen.make(.checker, extent: e, size: u * 2.5, seed: s, a: .white, b: .black)
            },
            Structure(id: "plaid", name: "Plaid", category: "Pattern & Geometry", tags: ["plaid", "tartan", "cozy"]) { e, u, s in
                SurfaceGen.make(.plaid, extent: e, size: u * 2.5, seed: s, a: RGBA(0.75, 0.75, 0.75), b: .black)
            },
            Structure(id: "chevron", name: "Chevron", category: "Pattern & Geometry", tags: ["chevron", "zigzag", "pattern"]) { e, u, _ in
                drawn(e) { ctx, w, h in
                    ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
                    ctx.setLineWidth(max(2, u * 0.25))
                    let step = max(6, u * 0.8)
                    var y: CGFloat = -step
                    while y < h + step {
                        ctx.move(to: CGPoint(x: 0, y: y))
                        var x: CGFloat = 0, up = true
                        while x < w + step { x += step; ctx.addLine(to: CGPoint(x: x, y: y + (up ? step * 0.6 : 0))); up.toggle() }
                        ctx.strokePath()
                        y += step
                    }
                }
            },
            Structure(id: "hexgrid", name: "Hex Grid", category: "Pattern & Geometry", tags: ["hexagon", "grid", "tech", "honeycomb"]) { e, u, _ in
                drawn(e) { ctx, w, h in
                    ctx.setFillColor(CGColor(gray: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                    ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
                    ctx.setLineWidth(max(1, u * 0.06))
                    let r = max(5, u * 0.6), dx = r * 1.732, dy = r * 1.5
                    var row = 0
                    var y: CGFloat = 0
                    while y < h + r {
                        var x: CGFloat = row % 2 == 0 ? 0 : dx / 2
                        while x < w + r {
                            let pts = (0..<6).map { k -> CGPoint in let a = CGFloat(k) * .pi / 3 + .pi / 6; return CGPoint(x: x + cos(a) * r, y: y + sin(a) * r) }
                            ctx.addLines(between: pts + [pts[0]])
                            x += dx
                        }
                        ctx.strokePath()
                        y += dy
                        row += 1
                    }
                }
            },
            Structure(id: "triangles", name: "Triangle Mosaic", category: "Pattern & Geometry", tags: ["triangles", "geometric", "low poly", "modern"]) { e, u, s in
                drawn(e) { ctx, w, h in
                    var rng = SeededRNG(seed: s)
                    let step = max(8, u * 1.1)
                    var y: CGFloat = 0
                    while y < h + step {
                        var x: CGFloat = 0
                        while x < w + step {
                            for up in [true, false] {
                                ctx.setFillColor(CGColor(gray: CGFloat(rng.range(0.2, 0.95)), alpha: 1))
                                ctx.move(to: CGPoint(x: x, y: y))
                                ctx.addLine(to: up ? CGPoint(x: x + step, y: y) : CGPoint(x: x + step, y: y + step))
                                ctx.addLine(to: up ? CGPoint(x: x + step, y: y + step) : CGPoint(x: x, y: y + step))
                                ctx.closePath()
                                ctx.fillPath()
                            }
                            x += step
                        }
                        y += step
                    }
                }
            },
            Structure(id: "herringbone", name: "Herringbone", category: "Pattern & Geometry", tags: ["herringbone", "parquet", "classic"]) { e, u, _ in
                drawn(e) { ctx, w, h in
                    ctx.setFillColor(CGColor(gray: 0.2, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                    let l = max(10, u * 1.2), t = l / 3
                    var y: CGFloat = -l, row = 0
                    while y < h + l {
                        var x: CGFloat = -l
                        while x < w + l {
                            ctx.saveGState()
                            ctx.translateBy(x: x, y: y)
                            ctx.rotate(by: row % 2 == 0 ? .pi / 4 : -.pi / 4)
                            ctx.setFillColor(CGColor(gray: row % 2 == 0 ? 0.85 : 0.65, alpha: 1))
                            ctx.fill(CGRect(x: 0, y: 0, width: l - 1.5, height: t - 1.5))
                            ctx.restoreGState()
                            x += t * 1.414
                        }
                        y += l * 0.707
                        row += 1
                    }
                }
            },
            Structure(id: "waves", name: "Wave Lines", category: "Pattern & Geometry", tags: ["waves", "lines", "flow", "calm"]) { e, u, s in
                drawn(e) { ctx, w, h in
                    ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
                    ctx.setLineWidth(max(1, u * 0.08))
                    let gap = max(4, u * 0.35), amp = gap * 0.8
                    var y: CGFloat = -amp
                    while y < h + amp {
                        ctx.move(to: CGPoint(x: 0, y: y))
                        var x: CGFloat = 0
                        while x <= w { ctx.addLine(to: CGPoint(x: x, y: y + sin(x / (gap * 2.5) + y * 0.05) * amp)); x += 3 }
                        ctx.strokePath()
                        y += gap
                    }
                }
            },
            Structure(id: "topo", name: "Topographic Lines", category: "Pattern & Geometry", tags: ["topographic", "map", "contour", "adventure"]) { e, u, s in
                let levels = smooth(e, s, cells(e, u, 4)).applyingFilter("CIColorPosterize", parameters: ["inputLevels": 9])
                return edges(levels, 6).applyingFilter("CIColorInvert")
            },
            Structure(id: "halftone", name: "Halftone Fade", category: "Pattern & Geometry", tags: ["halftone", "dots", "print", "comic"]) { e, _, s in gen(.halftone, e, s) },
            Structure(id: "sunburst", name: "Sunburst", category: "Pattern & Geometry", tags: ["sunburst", "rays", "retro", "vintage"]) { e, _, s in gen(.sunburst, e, s) },
            Structure(id: "goldenblocks", name: "Golden Blocks", category: "Pattern & Geometry", tags: ["golden", "blocks", "geometric", "modern"]) { e, _, s in gen(.goldenBlocks, e, s) },
            Structure(id: "bauhaus", name: "Bauhaus", category: "Pattern & Geometry", tags: ["bauhaus", "shapes", "modernist"]) { e, _, s in gen(.bauhaus, e, s) }
        ]
    }
}
