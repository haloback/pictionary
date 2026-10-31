import Foundation

/// Thousands of title styles, generated from style families crossed with materials, relief,
/// finishes, wear, colorways and photo blending. Taste rules drop combinations that clash,
/// and every style draws its neutral colors from the cover's palette.
final class StyleLibrary {
    static let shared = StyleLibrary()

    struct Family {
        let id: String
        let name: String
        let tags: [String]
        let genres: [Genre]
    }

    let all: [TextStylePreset]
    let families: [Family]
    private let index: [String: TextStylePreset]
    private let familyOf: [String: String]

    func preset(_ id: String) -> TextStylePreset? { index[id] }
    func family(of id: String) -> String? { familyOf[id] }

    func search(_ query: String, family: String?, genre: Genre?) -> [TextStylePreset] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        return all.filter { p in
            if let family, familyOf[p.id] != family { return false }
            if let genre, !p.tags.contains(genre.rawValue) { return false }
            guard !words.isEmpty else { return true }
            let hay = (p.name + " " + p.category + " " + p.tags.joined(separator: " ")).lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
    }

    /// Styles from the same family that share the most words with the given one.
    func similar(to id: String, limit: Int = 60) -> [TextStylePreset] {
        guard let p = index[id] else { return [] }
        let fam = familyOf[id]
        let words = Set(p.name.lowercased().split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init))
        return all.filter { $0.id != id && familyOf[$0.id] == fam }
            .map { q -> (TextStylePreset, Int) in
                let w = Set(q.name.lowercased().split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init))
                return (q, w.intersection(words).count)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    private init() {
        var list: [TextStylePreset] = []
        var fams: [Family] = []
        var famOf: [String: String] = [:]

        func family(_ id: String, _ name: String, tags: [String], genres: [Genre], build: (_ add: (String, String, [String], [String], @escaping (PaletteRoles, RGBA) -> (TextStyle, RGBA?)) -> Void) -> Void) {
            fams.append(Family(id: id, name: name, tags: tags, genres: genres))
            build { key, name, fonts, extraTags, make in
                let pid = "gen.\(id).\(key)"
                let t = tags + extraTags + genres.map(\.rawValue)
                list.append(TextStylePreset(id: pid, name: name, category: fams.last!.name, fonts: fonts, tags: t, make: make))
                famOf[pid] = id
            }
        }

        let vivid = ColorBook.vivid
        func slug(_ s: String) -> String { EffectLibrary.slug(s) }
        func rotate(_ f: [String], _ i: Int) -> [String] { f.isEmpty ? f : Array(f[(i % f.count)...] + f[..<(i % f.count)]) }

        // MARK: Metals
        let metals: [(SurfaceTexture, String)] = [(.gold, "Gold"), (.goldLeaf, "Gold Leaf"), (.silver, "Silver"), (.chrome, "Chrome"), (.copper, "Copper"), (.bronze, "Bronze")]
        let metalReliefs: [(String, BevelStyle, Double, Double)] = [("Soft", .smooth, 0.35, 0.3), ("Chiseled", .chisel, 0.65, 0.45), ("Inflated", .inflated, 0.6, 0.8)]
        let metalFinishes = ["Clean", "Dark Edge", "Glow", "Raised", "Sticker"]
        let metalWear: [(String, WearKind, Double)] = [("", .none, 0), ("Scratched", .scratched, 0.4), ("Aged", .grunge, 0.35)]
        let metalScene: [(String, Double, Double)] = [("", 0, 0), ("Light Wrapped", 0.4, 0), ("Photo Grain", 0, 0.35)]
        let metalFonts = ["Cinzel-Bold", "CinzelDecorative-Black", "PlayfairDisplay-Black", "BodoniModa-Black", "Anton-Regular", "MarcellusSC-Regular"]
        family("metal", "Metal", tags: ["metal", "shiny", "luxury", "foil", "premium"], genres: [.fantasy, .historical, .thriller, .romance, .scienceFiction]) { add in
            var n = 0
            for (mat, mName) in metals {
                for (rName, rStyle, depth, gloss) in metalReliefs {
                    for finish in metalFinishes {
                        for (wName, wear, wAmt) in metalWear {
                            if rStyle == .inflated && wear != .none { continue }
                            if mat == .chrome && wear == .grunge { continue }
                            for (sName, wrap, grain) in metalScene {
                                if wear != .none && grain > 0 { continue }
                                let name = [mName, rName, finish == "Clean" ? "" : finish, wName, sName].filter { !$0.isEmpty }.joined(separator: ", ")
                                let key = [slug(mName), slug(rName), slug(finish), slug(wName), slug(sName)].filter { !$0.isEmpty }.joined(separator: "-")
                                add(key, name, rotate(metalFonts, n), [mName.lowercased(), rName.lowercased()]) { p, _ in
                                    var s = TextStyle(); s.surface = mat; s.bevel = depth; s.bevelStyle = rStyle; s.gloss = gloss
                                    switch finish {
                                    case "Dark Edge": s.outline = 0.02; s.outlineColor = p.dark
                                    case "Glow": s.outerGlow = 0.35; s.outerGlowColor = p.accent.withAlpha(0.7)
                                    case "Raised": s.extrude = 0.14; s.extrudeColor = p.dark
                                    case "Sticker": s.outline2 = 0.05; s.outline2Color = .nearWhite; s.dropShadow = 0.5
                                    default: break
                                    }
                                    s.wear = wear; s.wearAmount = wAmt; s.lightWrap = wrap; s.photoTexture = grain
                                    return (s, nil)
                                }
                                n += 1
                            }
                        }
                    }
                }
            }
        }

        // MARK: Stone & Earth
        let earths: [(SurfaceTexture, String)] = [(.stone, "Stone"), (.marble, "Marble"), (.concrete, "Concrete"), (.wood, "Wood"), (.leather, "Leather"), (.rust, "Rust"), (.charred, "Burnt Wood")]
        let earthRelief: [(String, BevelStyle?, Double, Double)] = [("Carved", .chisel, 0.75, 0.45), ("Raised", .smooth, 0.45, 0), ("Flat", nil, 0, 0)]
        let earthWear: [(String, WearKind, Double)] = [("", .none, 0), ("Cracked", .cracked, 0.5), ("Eroded", .eroded, 0.5), ("Weathered", .grunge, 0.35)]
        let earthFonts = ["Cinzel-Bold", "IM_FELL_English_SC", "Anton-Regular", "Rye-Regular", "MarcellusSC-Regular", "UncialAntiqua-Regular"]
        family("earth", "Stone & Earth", tags: ["stone", "earthy", "ancient", "rough", "natural"], genres: [.fantasy, .historical, .horror, .mystery]) { add in
            var n = 0
            for (mat, mName) in earths {
                for (rName, rStyle, depth, inner) in earthRelief {
                    for (wName, wear, wAmt) in earthWear {
                        if mat == .marble && wear == .eroded { continue }
                        for grain in [0.0, 0.35] {
                            let name = [mName, rName, wName, grain > 0 ? "Photo Grain" : ""].filter { !$0.isEmpty }.joined(separator: ", ")
                            let key = [slug(mName), slug(rName), slug(wName), grain > 0 ? "grain" : ""].filter { !$0.isEmpty }.joined(separator: "-")
                            add(key, name, rotate(earthFonts, n), [mName.lowercased(), rName.lowercased(), wName.lowercased()]) { _, _ in
                                var s = TextStyle(); s.surface = mat
                                if let rStyle { s.bevel = depth; s.bevelStyle = rStyle }
                                s.innerShadow = inner; s.wear = wear; s.wearAmount = wAmt; s.photoTexture = grain
                                if mat == .charred { s.outerGlow = 0.15; s.outerGlowColor = RGBA(hex: "F2661C", alpha: 0.5) }
                                return (s, nil)
                            }
                            n += 1
                        }
                    }
                }
            }
        }

        // MARK: Elements
        let elements: [(SurfaceTexture, String, RGBA)] = [(.ice, "Ice", RGBA(hex: "9CD3F0")), (.fire, "Fire", RGBA(hex: "F2661C")), (.smoke, "Smoke", RGBA(hex: "C8C8D0")),
                                                          (.galaxy, "Galaxy", RGBA(hex: "C0399A")), (.glitter, "Glitter", RGBA(hex: "F2E8FF"))]
        let elementFonts = ["Cinzel-Bold", "Orbitron-Black", "Anton-Regular", "Unbounded-ExtraBold", "PlayfairDisplay-Black"]
        family("elements", "Elements", tags: ["magic", "elemental", "glowing"], genres: [.fantasy, .scienceFiction, .youngAdult, .horror]) { add in
            var n = 0
            for (mat, mName, glowColor) in elements {
                for (gName, glow) in [("", 0.0), ("Soft Glow", 0.3), ("Blazing", 0.7)] {
                    for (rName, bevel) in [("", 0.0), ("Sculpted", 0.4)] {
                        for (sName, wrap) in [("", 0.0), ("Light Wrapped", 0.4)] {
                            let name = [mName, gName, rName, sName].filter { !$0.isEmpty }.joined(separator: ", ")
                            let key = [slug(mName), slug(gName), slug(rName), slug(sName)].filter { !$0.isEmpty }.joined(separator: "-")
                            add(key, name, rotate(elementFonts, n), [mName.lowercased()]) { p, _ in
                                var s = TextStyle(); s.surface = mat; s.bevel = bevel; s.outerGlow = glow; s.outerGlowColor = glowColor.withAlpha(0.8); s.lightWrap = wrap
                                if mat == .glitter { s.patternColor = p.accent; s.gloss = 0.4 }
                                return (s, nil)
                            }
                            n += 1
                        }
                    }
                }
            }
        }

        // MARK: Neon
        let neonFonts = ["Monoton-Regular", "Audiowide-Regular", "KaushanScript-Regular", "Righteous-Regular", "Sacramento-Regular", "PoiretOne-Regular"]
        family("neon", "Neon & Light", tags: ["neon", "light", "night", "retro", "glow", "sign"], genres: [.scienceFiction, .youngAdult, .thriller, .romance]) { add in
            var n = 0
            for c in vivid.prefix(37) {
                for (zName, glow) in [("Tight", 0.45), ("", 0.75), ("Wide", 1.0)] {
                    for kind in ["Tube", "Outline Tube"] {
                        let name = ["\(c.name) Neon", kind == "Tube" ? "" : "Outline", zName].filter { !$0.isEmpty }.joined(separator: ", ")
                        let key = [slug(c.name), slug(kind), slug(zName)].filter { !$0.isEmpty }.joined(separator: "-")
                        let tube = c.color.withSaturation(max(0.7, c.color.hsl.s))
                        add(key, name, rotate(neonFonts, n), [c.name.lowercased()]) { p, _ in
                            var s = TextStyle(); s.outerGlow = glow; s.outerGlowColor = tube.withLightness(0.55)
                            if kind == "Tube" {
                                s.innerGlow = 0.6; s.innerGlowColor = .white
                                return (s, tube.withLightness(0.82))
                            }
                            s.outline = 0.018; s.outlineColor = tube.withLightness(0.8)
                            return (s, p.dark)
                        }
                        n += 1
                    }
                }
            }
            for c in vivid.prefix(36) {
                for (zName, glow) in [("Halo", 0.6), ("Eclipse", 0.95)] {
                    add("backlit-\(slug(c.name))-\(slug(zName))", "\(c.name) Backlit, \(zName)", rotate(["BebasNeue-Regular", "Anton-Regular", "Cinzel-Bold"], n), ["backlit", c.name.lowercased()]) { p, _ in
                        var s = TextStyle(); s.outerGlow = glow; s.outerGlowColor = c.color.withLightness(0.7); s.innerShadow = 0.2
                        return (s, p.dark)
                    }
                    n += 1
                }
            }
        }

        // MARK: Pattern fills
        let patterns: [(SurfaceTexture, String)] = [(.stripes, "Stripes"), (.polkaDots, "Polka Dots"), (.checker, "Checkerboard"), (.plaid, "Plaid")]
        let patternFonts = ["Bungee-Regular", "ArchivoBlack-Regular", "Montserrat-Black", "Righteous-Regular", "Anton-Regular"]
        family("pattern", "Pattern Fill", tags: ["pattern", "playful", "fun", "bold", "kids"], genres: [.youngAdult, .cozy, .nonfiction]) { add in
            var n = 0
            for (mat, mName) in patterns {
                for i in 0..<12 {
                    let a = vivid[i], b = vivid[(i + 12) % vivid.count]
                    for edge in ["", "Outlined", "Sticker"] {
                        let name = ["\(a.name) & \(b.name) \(mName)", edge].filter { !$0.isEmpty }.joined(separator: ", ")
                        add("\(slug(mName))-\(slug(a.name))-\(slug(b.name))\(edge.isEmpty ? "" : "-" + slug(edge))", name, rotate(patternFonts, n), [mName.lowercased(), a.name.lowercased(), b.name.lowercased()]) { p, _ in
                            var s = TextStyle(); s.surface = mat; s.patternColor = a.color; s.patternColor2 = b.color
                            if edge == "Outlined" { s.outline = 0.03; s.outlineColor = p.dark }
                            if edge == "Sticker" { s.roundness = 0.3; s.outline2 = 0.06; s.outline2Color = .nearWhite; s.dropShadow = 0.45 }
                            return (s, nil)
                        }
                        n += 1
                    }
                }
            }
        }

        // MARK: Print & paper
        let prints = ["Letterpress", "Ink Bleed", "Woodcut", "Halftone", "Risograph", "Screen Print", "Chalkboard"]
        let printFonts = ["LibreCaslonDisplay-Regular", "SpecialElite-Regular", "UnifrakturMaguntia", "BebasNeue-Regular", "Syne-ExtraBold", "LeagueGothic-Regular"]
        family("print", "Print & Paper", tags: ["print", "paper", "vintage", "ink", "handmade"], genres: [.literary, .mystery, .memoir, .historical, .nonfiction]) { add in
            var n = 0
            for kind in prints {
                for (iName, k) in [("Light", 0.3), ("Medium", 0.55), ("Heavy", 0.8)] {
                    for grain in [0.0, 0.5] {
                        let name = [kind, iName, grain > 0 ? "Photo Grain" : ""].filter { !$0.isEmpty }.joined(separator: ", ")
                        add("\(slug(kind))-\(slug(iName))\(grain > 0 ? "-grain" : "")", name, rotate(printFonts, n), [kind.lowercased()]) { p, _ in
                            var s = TextStyle(); s.photoTexture = grain
                            var color: RGBA? = nil
                            switch kind {
                            case "Letterpress": s.innerShadow = 0.3 + 0.4 * k; s.wear = .grunge; s.wearAmount = k * 0.5; color = p.dark
                            case "Ink Bleed": s.wear = .inkBleed; s.wearAmount = k; color = p.dark
                            case "Woodcut": s.wear = .distressed; s.wearAmount = k; s.halftone = 0.3
                            case "Halftone": s.halftone = k; s.outline = 0.03; s.outlineColor = p.dark
                            case "Risograph": s.glitch = 0.2 + 0.3 * k; s.wear = .grunge; s.wearAmount = k * 0.5; color = p.accent
                            case "Screen Print": s.wear = .scratched; s.wearAmount = k
                            default: s.surface = .chalk; s.wear = .distressed; s.wearAmount = k * 0.6
                            }
                            return (s, color)
                        }
                        n += 1
                    }
                }
            }
        }

        // MARK: 3D
        let faces: [(String, SurfaceTexture)] = [("Flat", .none), ("Gold", .gold), ("Chrome", .chrome), ("Glitter", .glitter)]
        let dirs: [(String, Double)] = [("Down Right", 300), ("Down Left", 240), ("Down", 270), ("Up Right", 45)]
        let blockFonts = ["Bungee-Regular", "ArchivoBlack-Regular", "Anton-Regular", "Montserrat-Black", "BigShouldersDisplay-Black"]
        family("3d", "3D & Depth", tags: ["3d", "depth", "bold", "block", "pop"], genres: [.youngAdult, .nonfiction, .thriller, .cozy]) { add in
            var n = 0
            for (dName, depth) in [("Shallow", 0.12), ("Deep", 0.24), ("Towering", 0.4)] {
                for (aName, angle) in dirs {
                    for (fName, face) in faces {
                        for extra in ["", "Outlined", "Long Shadow"] {
                            let name = ["\(dName) 3D", fName == "Flat" ? "" : fName, aName, extra].filter { !$0.isEmpty }.joined(separator: ", ")
                            let key = [slug(dName), slug(fName), slug(aName), slug(extra)].filter { !$0.isEmpty }.joined(separator: "-")
                            add(key, name, rotate(blockFonts, n), ["extrude", fName.lowercased()]) { p, _ in
                                var s = TextStyle(); s.extrude = depth; s.extrudeAngle = angle; s.extrudeColor = p.dark.withLightness(0.18); s.surface = face
                                if face == .glitter { s.patternColor = p.accent }
                                if face != .none { s.bevel = 0.3 }
                                if extra == "Outlined" { s.outline = 0.025; s.outlineColor = p.dark }
                                if extra == "Long Shadow" { s.longShadow = 0.4; s.longShadowColor = p.dark.withAlpha(0.5) }
                                return (s, nil)
                            }
                            n += 1
                        }
                    }
                }
            }
        }

        // MARK: Retro stacked
        family("retro", "Retro Stacked", tags: ["retro", "70s", "stacked", "offset", "groovy", "vintage"], genres: [.youngAdult, .cozy, .nonfiction, .romance]) { add in
            var n = 0
            for (cName, echo) in [("Single", 0.25), ("Double", 0.5), ("Triple", 0.75)] {
                for i in 0..<12 {
                    let a = vivid[i], b = vivid[(i + 6) % vivid.count]
                    for (dName, angle) in [("Down Right", 300.0), ("Down Left", 240.0), ("Down", 270.0)] {
                        add("\(slug(cName))-\(slug(a.name))-\(slug(b.name))-\(slug(dName))", "\(cName) Stack, \(a.name) & \(b.name), \(dName)",
                            rotate(["Righteous-Regular", "Bungee-Regular", "Limelight-Regular", "Monoton-Regular", "Syne-ExtraBold"], n), [a.name.lowercased(), b.name.lowercased()]) { _, _ in
                            var s = TextStyle(); s.echo = echo; s.echoColor = a.color; s.echoColor2 = b.color; s.extrudeAngle = angle
                            return (s, nil)
                        }
                        n += 1
                    }
                }
            }
        }

        // MARK: Stickers
        let borders: [(String, RGBA)] = [("White", RGBA.nearWhite), ("Cream", RGBA(hex: "FFF4DC")), ("Black", RGBA.nearBlack)] + vivid.prefix(9).map { ($0.name, $0.color) }
        family("sticker", "Sticker & Cutout", tags: ["sticker", "cutout", "paper", "fun", "playful"], genres: [.youngAdult, .cozy, .nonfiction, .romance]) { add in
            var n = 0
            for (bName, border) in borders {
                for (sName, shadow) in [("Soft Shadow", 0.4), ("Hard Shadow", 0.9)] {
                    for (fName, face) in [("", SurfaceTexture.none), ("Glitter", .glitter), ("Stripes", .stripes)] {
                        let name = ["\(bName) Sticker", fName, sName].filter { !$0.isEmpty }.joined(separator: ", ")
                        add("\(slug(bName))-\(slug(sName))\(fName.isEmpty ? "" : "-" + slug(fName))", name, rotate(["Bungee-Regular", "Righteous-Regular", "PermanentMarker-Regular", "Montserrat-Black"], n), [bName.lowercased()]) { p, _ in
                            var s = TextStyle(); s.roundness = 0.35; s.outline2 = 0.07; s.outline2Color = border; s.dropShadow = shadow; s.surface = face
                            s.patternColor = p.accent; s.patternColor2 = p.light
                            return (s, nil)
                        }
                        n += 1
                    }
                }
            }
        }

        // MARK: Drips
        let dripKinds: [(String, RGBA?, SurfaceTexture)] = [("Paint", nil, .none), ("Blood", RGBA(hex: "8E1020"), .none), ("Slime", RGBA(hex: "8BC34A"), .none),
                                                           ("Molten Gold", nil, .gold), ("Chocolate", RGBA(hex: "4A2C17"), .none), ("Ink", RGBA(hex: "121417"), .none)]
        family("drips", "Drips", tags: ["drip", "dripping", "liquid", "paint", "spooky"], genres: [.horror, .youngAdult, .thriller]) { add in
            var n = 0
            for (kName, color, face) in dripKinds {
                for (lName, amount) in [("Short", 0.35), ("Long", 0.75)] {
                    for (wName, wear) in [("", WearKind.none), ("Grunge", .grunge)] {
                        let name = ["\(kName) Drips", lName, wName].filter { !$0.isEmpty }.joined(separator: ", ")
                        add("\(slug(kName))-\(slug(lName))\(wName.isEmpty ? "" : "-grunge")", name, rotate(["Creepster-Regular", "Nosifer-Regular", "PermanentMarker-Regular", "Anton-Regular"], n), [kName.lowercased()]) { p, _ in
                            var s = TextStyle(); s.drips = amount; s.surface = face; s.wear = wear; s.wearAmount = 0.3
                            if face == .none { s.bevel = 0.2; s.gloss = 0.3 }
                            return (s, color ?? (face == .none ? p.accent : nil))
                        }
                        n += 1
                    }
                }
            }
        }

        // MARK: Embroidery
        family("stitch", "Embroidery", tags: ["embroidery", "stitched", "patch", "thread", "craft", "cozy"], genres: [.cozy, .youngAdult, .romance, .memoir]) { add in
            var n = 0
            for c in vivid.prefix(24) {
                for (rName, style) in [("Patch", BevelStyle.pillow), ("Puffy", .inflated)] {
                    add("\(slug(c.name))-\(slug(rName))", "\(c.name) Embroidery, \(rName)", rotate(["KaushanScript-Regular", "Righteous-Regular", "Bungee-Regular", "GreatVibes-Regular"], n), [c.name.lowercased()]) { _, _ in
                        var s = TextStyle(); s.surface = .thread; s.patternColor = c.color; s.stitch = 0.6; s.stitchColor = c.color.withLightness(0.9)
                        s.bevel = 0.35; s.bevelStyle = style; s.roundness = 0.2; s.dropShadow = 0.3
                        return (s, nil)
                    }
                    n += 1
                }
            }
        }

        // MARK: Glitch
        family("glitch", "Glitch & Digital", tags: ["glitch", "digital", "cyber", "tech", "rgb"], genres: [.scienceFiction, .thriller, .youngAdult]) { add in
            var n = 0
            for (gName, g) in [("Subtle", 0.25), ("Split", 0.5), ("Broken", 0.85)] {
                for (hName, h) in [("", 0.0), ("Halftone", 0.35)] {
                    for c in vivid.prefix(12) {
                        let name = ["\(gName) Glitch", c.name, hName].filter { !$0.isEmpty }.joined(separator: ", ")
                        add("\(slug(gName))-\(slug(c.name))\(hName.isEmpty ? "" : "-halftone")", name, rotate(["Orbitron-Black", "Michroma-Regular", "Syncopate-Bold", "Exo2-ExtraBold"], n), [c.name.lowercased()]) { _, _ in
                            var s = TextStyle(); s.glitch = g; s.halftone = h
                            return (s, c.color.withLightness(0.7))
                        }
                        n += 1
                    }
                }
            }
        }

        // MARK: Into the photo
        family("photo", "Into the Photo", tags: ["photo", "blend", "atmospheric", "cinematic", "subtle"], genres: [.thriller, .mystery, .literary, .horror, .memoir]) { add in
            var n = 0
            for kind in ["Window", "Light Wrapped", "Painted On", "Fog", "In Shadows", "Ghost"] {
                for (sName, k) in [("Gentle", 0.6), ("", 0.85), ("Full", 1.0)] {
                    for edge in ["", "Outlined"] {
                        let name = [kind, sName, edge].filter { !$0.isEmpty }.joined(separator: ", ")
                        let key = [slug(kind), slug(sName), slug(edge)].filter { !$0.isEmpty }.joined(separator: "-")
                        add(key, name, rotate(["Anton-Regular", "PlayfairDisplay-Bold", "CormorantGaramond-SemiBold", "BebasNeue-Regular", "Cinzel-Bold"], n), [kind.lowercased()]) { p, _ in
                            var s = TextStyle()
                            var color: RGBA? = nil
                            switch kind {
                            case "Window": s.photoFill = k
                            case "Light Wrapped": s.lightWrap = 0.75 * k; s.colorMatch = 0.4 * k
                            case "Painted On": s.photoDisplace = 0.6 * k; s.photoTexture = 0.65 * k
                            case "Fog": s.photoErode = 0.45 * k; s.lightWrap = 0.5 * k; s.outerGlow = 0.3; s.outerGlowColor = p.light.withAlpha(0.45); color = p.light
                            case "In Shadows": s.photoErode = 0.75 * k; s.photoTexture = 0.4 * k
                            default: s.photoTexture = 0.5 * k; s.colorMatch = 0.6 * k; s.outerGlow = 0.25; s.outerGlowColor = p.light.withAlpha(0.4); color = p.light.withAlpha(0.85)
                            }
                            if edge == "Outlined" { s.outline = 0.015; s.outlineColor = p.light }
                            return (s, color)
                        }
                        n += 1
                    }
                }
            }
        }

        // MARK: Two-tone gradients
        family("gradient", "Two-Tone", tags: ["gradient", "two-tone", "color", "modern", "vibrant"], genres: [.youngAdult, .romance, .scienceFiction, .nonfiction, .cozy]) { add in
            var n = 0
            for i in 0..<24 {
                let a = vivid[i], b = vivid[(i + 5) % vivid.count]
                for finish in metalFinishes {
                    for (rName, bevel) in [("", 0.0), ("Soft", 0.3)] {
                        let name = ["\(a.name) to \(b.name)", rName, finish == "Clean" ? "" : finish].filter { !$0.isEmpty }.joined(separator: ", ")
                        let key = [slug(a.name), slug(b.name), slug(rName), slug(finish)].filter { !$0.isEmpty }.joined(separator: "-")
                        add(key, name, rotate(["Montserrat-Black", "PlayfairDisplay-Black", "Unbounded-ExtraBold", "AbrilFatface-Regular", "Anton-Regular"], n), [a.name.lowercased(), b.name.lowercased()]) { p, _ in
                            var s = TextStyle(); s.surface = .gradient; s.patternColor = a.color; s.patternColor2 = b.color; s.bevel = bevel; s.gloss = bevel > 0 ? 0.3 : 0
                            switch finish {
                            case "Dark Edge": s.outline = 0.02; s.outlineColor = p.dark
                            case "Glow": s.outerGlow = 0.35; s.outerGlowColor = b.color.withAlpha(0.7)
                            case "Raised": s.extrude = 0.14; s.extrudeColor = p.dark
                            case "Sticker": s.outline2 = 0.05; s.outline2Color = .nearWhite; s.dropShadow = 0.5
                            default: break
                            }
                            return (s, nil)
                        }
                        n += 1
                    }
                }
            }
        }

        // MARK: Shattered, smoke, balloon, burn, chalk
        family("shattered", "Shattered Glass", tags: ["glass", "shattered", "broken", "crime", "sharp"], genres: [.thriller, .mystery, .horror, .scienceFiction]) { add in
            for c in vivid.prefix(12) {
                for (aName, a) in [("Cracked", 0.3), ("Shattered", 0.55), ("Exploded", 0.8)] {
                    add("\(slug(c.name))-\(slug(aName))", "\(aName) Glass, \(c.name)", ["Anton-Regular", "BebasNeue-Regular", "Orbitron-Black"], [c.name.lowercased()]) { _, _ in
                        var s = TextStyle(); s.surface = .ice; s.surfaceTint = 0.5; s.wear = .shattered; s.wearAmount = a; s.bevel = 0.4; s.bevelStyle = .chisel; s.gloss = 0.5
                        return (s, c.color.withLightness(0.75))
                    }
                }
            }
        }
        family("smoke", "Smoke Trails", tags: ["smoke", "mist", "spooky", "rising", "atmospheric"], genres: [.horror, .mystery, .fantasy, .thriller]) { add in
            for c in vivid.prefix(12) {
                for (lName, l) in [("Wisp", 0.35), ("Plume", 0.65), ("Column", 0.95)] {
                    add("\(slug(c.name))-\(slug(lName))", "\(c.name) Smoke, \(lName)", ["CormorantGaramond-Bold", "Cinzel-Bold", "IM_FELL_English_SC"], [c.name.lowercased()]) { p, _ in
                        var s = TextStyle(); s.smokeTrail = l; s.smokeColor = c.color.withLightness(0.8).withAlpha(0.6)
                        return (s, p.light)
                    }
                }
            }
        }
        family("balloon", "Balloon", tags: ["balloon", "inflated", "puffy", "glossy", "party", "fun"], genres: [.youngAdult, .cozy, .romance]) { add in
            for c in vivid.prefix(24) {
                for (gName, gloss) in [("Satin", 0.6), ("Glossy", 0.9)] {
                    add("\(slug(c.name))-\(slug(gName))", "\(c.name) Balloon, \(gName)", ["Bungee-Regular", "Righteous-Regular", "Montserrat-Black", "Unbounded-ExtraBold"], [c.name.lowercased()]) { _, _ in
                        var s = TextStyle(); s.roundness = 0.6; s.bevel = 0.6; s.bevelStyle = .inflated; s.gloss = gloss; s.dropShadow = 0.4
                        return (s, c.color)
                    }
                }
            }
        }
        family("burn", "Wood Burn & Chalk", tags: ["burnt", "chalk", "rustic", "handmade", "western"], genres: [.historical, .cozy, .fantasy, .literary]) { add in
            for (iName, k) in [("Light", 0.3), ("Medium", 0.5), ("Deep", 0.7), ("Scorched", 0.9)] {
                for grain in [0.0, 0.4] {
                    add("burn-\(slug(iName))\(grain > 0 ? "-grain" : "")", "Wood Burn, \(iName)\(grain > 0 ? ", Photo Grain" : "")", ["Rye-Regular", "Cinzel-Bold", "IM_FELL_English_SC"], ["burnt", "wood"]) { _, _ in
                        var s = TextStyle(); s.surface = .charred; s.innerShadow = 0.3 + 0.4 * k; s.wear = .eroded; s.wearAmount = k * 0.6
                        s.outerGlow = 0.1 + 0.2 * k; s.outerGlowColor = RGBA(hex: "F2661C", alpha: 0.5); s.photoTexture = grain
                        return (s, nil)
                    }
                }
            }
            for c in [("White", RGBA.nearWhite)] + vivid.prefix(8).map({ ($0.name, $0.color) }) {
                for (wName, w) in [("Fresh", 0.3), ("Smudged", 0.6)] {
                    add("chalk-\(slug(c.0))-\(slug(wName))", "\(c.0) Chalk, \(wName)", ["PermanentMarker-Regular", "CaveatBrush-Regular", "RockSalt-Regular"], ["chalk", c.0.lowercased()]) { _, _ in
                        var s = TextStyle(); s.surface = .chalk; s.surfaceTint = c.0 == "White" ? 0 : 0.55; s.wear = .distressed; s.wearAmount = w
                        return (s, c.1)
                    }
                }
            }
        }

        // Hand-tuned presets come first.
        let curated = TextStylePreset.all
        for p in curated { famOf[p.id] = "curated" }
        fams.insert(Family(id: "curated", name: "Signature", tags: [], genres: Genre.allCases), at: 0)
        all = curated.map { p in
            var q = p
            q.tags = [p.category.lowercased()] + Genre.allCases.filter { TextStylePreset.forGenre($0).contains(p.id) }.map(\.rawValue)
            return q
        } + list
        families = fams
        var idx: [String: TextStylePreset] = [:]
        for p in all { idx[p.id] = p }
        index = idx
        familyOf = famOf
    }
}
