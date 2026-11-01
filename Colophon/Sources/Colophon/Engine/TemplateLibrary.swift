import Foundation

/// A ready-made cover design: layout, type pairing, palette, title style, ground and trim.
/// Applying it rebuilds the cover around the author's own title, names and photos.
struct CoverTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let genre: Genre
    let archetype: Archetype
    let pairing: String
    let paletteName: String
    let palette: [RGBA]
    let styleID: String?
    let fill: FillStyle
    let effect: String?
    let borderID: String?
    let flourish: TextFlourish
    let tags: [String]
    var needsPhoto: Bool { !archetype.worksWithoutImage }

    static func == (a: CoverTemplate, b: CoverTemplate) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

final class TemplateLibrary {
    static let shared = TemplateLibrary()

    struct NamedPalette {
        let name: String
        let colors: [RGBA]   // dark, mid, accent, light
        let moods: [Genre]
    }

    struct Pairing {
        let treatment: TypeTreatment
        let moods: [Genre]
    }

    let templates: [CoverTemplate]
    private let index: [String: CoverTemplate]

    func template(_ id: String) -> CoverTemplate? { index[id] }

    func search(_ query: String, genre: Genre?, photoOnly: Bool? = nil) -> [CoverTemplate] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        return templates.filter { t in
            if let genre, t.genre != genre { return false }
            if let photoOnly, t.needsPhoto != photoOnly { return false }
            guard !words.isEmpty else { return true }
            let hay = (t.name + " " + t.tags.joined(separator: " ")).lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
    }

    /// The template applied to `base`: keeps its book details, photos, fonts and canvas.
    func apply(_ t: CoverTemplate, to base: CoverDocument) -> CoverDocument {
        let treatment = TemplateLibrary.pairing(named: t.pairing, genre: t.genre)
        var doc = CoverComposer.make(base: base, archetype: t.archetype, treatment: treatment, palette: PaletteRoles(t.palette),
                                     fill: t.fill, effect: t.effect, styleID: t.styleID, seed: TemplateLibrary.seed(t.id))
        for i in doc.layers.indices {
            guard let role = doc.layers[i].textContent?.role, role == .subtitle || role == .series else { continue }
            doc.layers[i].textContent?.flourish = role == .series ? .rules : t.flourish
        }
        if let bid = t.borderID, let item = DecorLibrary.shared.item(bid) {
            let (a, b) = DecorLibrary.shared.colors(for: item, palette: PaletteRoles(t.palette))
            let border = Layer.decor(bid, color: a, color2: b, frame: .full)
            let i = doc.layers.firstIndex { $0.textContent != nil } ?? doc.layers.count
            doc.layers.insert(border, at: i)
        }
        doc.templateID = t.id
        return doc
    }

    static func seed(_ s: String) -> Int {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Int(h % 1_000_000)
    }

    // MARK: Building

    private init() {
        var list: [CoverTemplate] = []
        let palettes = TemplateLibrary.palettes
        let archetypes = Archetype.allCases
        for genre in Genre.allCases {
            let style = GenreStyle.of(genre)
            var pairings: [Pairing] = style.treatments.map { Pairing(treatment: $0, moods: [genre]) }
            pairings += TemplateLibrary.extraPairings.filter { $0.moods.contains(genre) }
            var pals: [NamedPalette] = palettes.filter { $0.moods.contains(genre) }
            for (k, mood) in style.moods.enumerated() {
                pals.append(NamedPalette(name: "\(genre.label) Classic \(k + 1)", colors: mood, moods: [genre]))
            }
            var stylePool: [String] = TextStylePreset.forGenre(genre)
            stylePool += StyleLibrary.shared.search("", family: nil, genre: genre).map(\.id).filter { id in
                !["gen.pattern", "gen.sticker", "gen.balloon", "gen.glitch", "gen.drips"].contains(where: id.hasPrefix)
            }
            let borders: [String] = TemplateLibrary.borderPool(for: genre)
            let flourishes: [TextFlourish] = [.none, .rules, .none, .diamonds, .underline, .none, .box, .dots]
            for (ai, arch) in archetypes.enumerated() {
                for v in 0..<12 {
                    let pairing = pairings[(v + ai) % pairings.count]
                    let pal = pals[(v * 5 + ai * 3) % pals.count]
                    let styleID: String? = (v % 4 == 3 || stylePool.isEmpty) ? nil : stylePool[(v * 7 + ai * 11) % stylePool.count]
                    let fill = style.fills[(v + ai) % style.fills.count]
                    let effect: String? = style.effects.isEmpty ? nil : style.effects[(v * 3 + ai) % style.effects.count]
                    let framed = arch.worksWithoutImage ? (v % 3 == 0) : (v % 6 == 0)
                    let borderID: String? = (framed && !borders.isEmpty) ? borders[(v * 13 + ai) % borders.count] : nil
                    let id = "tpl.\(genre.rawValue).\(arch.rawValue).\(v)"
                    let font = FontCatalog.displayName(pairing.treatment.titleFont)
                    let name = "\(pal.name) \(arch.label), \(font)"
                    var tags: [String] = [genre.label.lowercased(), arch.label.lowercased(), pal.name.lowercased(), font.lowercased(), pairing.treatment.name.lowercased()]
                    if borderID != nil { tags.append("border") }
                    if arch.worksWithoutImage { tags.append("no photo") } else { tags.append("photo") }
                    list.append(CoverTemplate(id: id, name: name, genre: genre, archetype: arch, pairing: pairing.treatment.name,
                                              paletteName: pal.name, palette: pal.colors, styleID: styleID, fill: fill, effect: effect,
                                              borderID: borderID, flourish: flourishes[(v + ai) % flourishes.count], tags: tags))
                }
            }
        }
        templates = list
        var idx: [String: CoverTemplate] = [:]
        for t in list { idx[t.id] = t }
        index = idx
    }

    static func pairing(named name: String, genre: Genre) -> TypeTreatment {
        if let t = GenreStyle.of(genre).treatments.first(where: { $0.name == name }) { return t }
        if let p = extraPairings.first(where: { $0.treatment.name == name }) { return p.treatment }
        for g in Genre.allCases {
            if let t = GenreStyle.of(g).treatments.first(where: { $0.name == name }) { return t }
        }
        return GenreStyle.of(genre).treatments[0]
    }

    /// Borders that suit a genre, looked up by keyword in the decor library.
    private static func borderPool(for genre: Genre) -> [String] {
        let words: [String]
        switch genre {
        case .fantasy, .historical: words = ["gold", "deco", "filigree", "victorian", "double", "greek"]
        case .romance: words = ["curl", "double", "scallop", "beads", "rounded"]
        case .cozy: words = ["stitched", "scallop", "wave", "rounded", "dotted"]
        case .youngAdult: words = ["dashed", "zigzag", "chevron", "dotted", "checker"]
        case .literary, .memoir: words = ["single", "thin", "double", "film"]
        case .mystery: words = ["deco", "double", "thick", "brackets"]
        case .thriller, .horror: words = ["grunge", "torn", "brush", "brackets"]
        case .scienceFiction: words = ["brackets", "viewfinder", "single", "chamfered"]
        case .nonfiction: words = ["single", "thick", "brackets", "double"]
        }
        var ids: [String] = []
        for w in words {
            for item in DecorLibrary.shared.search(w, kind: .border).prefix(24) where !ids.contains(item.id) { ids.append(item.id) }
        }
        return ids
    }

    private static func pal(_ name: String, _ hex: [String], _ moods: [Genre]) -> NamedPalette {
        NamedPalette(name: name, colors: hex.map { RGBA(hex: $0) }, moods: moods)
    }

    static let palettes: [NamedPalette] = {
        var p: [NamedPalette] = []
        p.append(pal("Ember", ["1A0E0A", "5C2A1A", "E4572E", "F4E3D0"], [.thriller, .fantasy, .horror, .historical]))
        p.append(pal("Midnight Gold", ["0B1026", "1F2A5A", "E7C877", "F2ECDF"], [.fantasy, .historical, .mystery, .literary]))
        p.append(pal("Forest Lantern", ["0E1F17", "2E4A3A", "F2A541", "EFE8D8"], [.fantasy, .cozy, .mystery, .memoir]))
        p.append(pal("Rose Quartz", ["2B1A22", "7A4458", "F2A6B8", "FBEFF2"], [.romance, .youngAdult, .memoir]))
        p.append(pal("Arctic", ["0C1B2A", "3F6C8C", "9FD3F0", "F2F8FC"], [.thriller, .scienceFiction, .literary, .nonfiction]))
        p.append(pal("Noir Red", ["0B0B0D", "2A2A2E", "D7263D", "F2F2F2"], [.thriller, .mystery, .horror]))
        p.append(pal("Sepia Archive", ["2A1E14", "6B5137", "C99A5B", "F3E9D2"], [.historical, .memoir, .literary, .mystery]))
        p.append(pal("Violet Hour", ["1A1030", "4A2C7A", "F28FB1", "F5EEFA"], [.romance, .fantasy, .youngAdult, .scienceFiction]))
        p.append(pal("Teal Amber", ["0B2A30", "13505A", "F2A541", "F2ECDF"], [.thriller, .literary, .scienceFiction, .nonfiction]))
        p.append(pal("Desert", ["3A2416", "A0522D", "E9C46A", "F7EFE2"], [.historical, .literary, .memoir, .fantasy]))
        p.append(pal("Ocean Deep", ["06141F", "0E3D5C", "2EC4B6", "E8F6F5"], [.scienceFiction, .thriller, .nonfiction, .literary]))
        p.append(pal("Citrus Pop", ["1D1D35", "3B3B98", "FFD23F", "FFF8E7"], [.youngAdult, .nonfiction, .cozy]))
        p.append(pal("Mint Cream", ["1E2D2F", "4C7A6E", "9ED8C6", "F6FBF8"], [.cozy, .memoir, .nonfiction, .romance]))
        p.append(pal("Blood Moon", ["120607", "4A0D12", "B3001B", "F0D9C8"], [.horror, .thriller, .fantasy]))
        p.append(pal("Copper Smoke", ["1C1A19", "4D4743", "C8733A", "EDE6DF"], [.thriller, .mystery, .scienceFiction, .historical]))
        p.append(pal("Lavender Field", ["2C2340", "6A5A8C", "C9B6E4", "F7F3FB"], [.romance, .cozy, .memoir, .literary]))
        p.append(pal("Bronze Age", ["241A10", "5E4524", "B9894A", "EFE3CC"], [.historical, .fantasy, .nonfiction]))
        p.append(pal("Neon Night", ["07070F", "1B1B3A", "FF2E88", "E8F8FF"], [.scienceFiction, .youngAdult, .thriller]))
        p.append(pal("Sage Linen", ["2F3A33", "7D8F7A", "C8D5B9", "F4F1E8"], [.literary, .memoir, .cozy, .nonfiction]))
        p.append(pal("Royal", ["0D1333", "26357A", "D4AF37", "F5F1E4"], [.fantasy, .historical, .romance]))
        p.append(pal("Crimson Ivory", ["2A0A0F", "8E1020", "D94F4F", "F8F1E5"], [.romance, .horror, .historical, .thriller]))
        p.append(pal("Storm", ["13181F", "3A4654", "8FA3B8", "E9EEF2"], [.thriller, .mystery, .literary, .scienceFiction]))
        p.append(pal("Sunset", ["2B1033", "8C2F5A", "F28C38", "FFE9C7"], [.romance, .youngAdult, .fantasy, .cozy]))
        p.append(pal("Moss", ["1A2414", "4B5F2E", "A3B565", "EEF0DC"], [.fantasy, .cozy, .literary, .horror]))
        p.append(pal("Ink and Paper", ["121417", "3A3D42", "8A8F98", "F4F1E8"], [.literary, .nonfiction, .memoir, .mystery]))
        p.append(pal("Coral Reef", ["1C2B3A", "2E8B8B", "FF7F6E", "FFF4EC"], [.youngAdult, .cozy, .romance, .nonfiction]))
        p.append(pal("Plum Gold", ["25101F", "5E1F4B", "E2B35A", "F7ECDF"], [.fantasy, .romance, .historical, .mystery]))
        p.append(pal("Slate Blue", ["1B2430", "425B76", "9DB4CC", "EEF2F6"], [.nonfiction, .literary, .thriller, .memoir]))
        p.append(pal("Terracotta", ["2E1A14", "9C4A2E", "E2995E", "F6E9DC"], [.memoir, .historical, .cozy, .literary]))
        p.append(pal("Honey", ["2A1C0B", "7A5320", "F2B134", "FFF6E0"], [.cozy, .youngAdult, .historical, .nonfiction]))
        p.append(pal("Glacier", ["0F2230", "5C8FA8", "D7EEF7", "FFFFFF"], [.scienceFiction, .thriller, .literary, .fantasy]))
        p.append(pal("Cherry Blossom", ["2D1B24", "B85C7A", "F7C6D6", "FFF5F8"], [.romance, .youngAdult, .cozy]))
        p.append(pal("Emerald", ["0A2018", "1B5E46", "2ECC8F", "ECF8F2"], [.fantasy, .scienceFiction, .nonfiction]))
        p.append(pal("Charcoal Mustard", ["1E1F21", "46484C", "E1AD01", "F1EFEA"], [.nonfiction, .thriller, .mystery, .youngAdult]))
        p.append(pal("Wine", ["1E0B12", "5A1A2E", "A63D57", "F2E4E8"], [.romance, .mystery, .horror, .literary]))
        p.append(pal("Dusk Teal", ["14212B", "285E61", "E3B23C", "F0EAD6"], [.mystery, .literary, .fantasy, .historical]))
        p.append(pal("Smoke Rose", ["24201F", "6D5A5C", "D8A7A7", "F4ECEB"], [.memoir, .romance, .literary]))
        p.append(pal("Electric", ["050A30", "0A2472", "00F5D4", "F8F9FA"], [.scienceFiction, .youngAdult, .thriller]))
        p.append(pal("Harvest", ["2B1B0E", "8A4F1C", "E0A458", "F5EBDD"], [.cozy, .historical, .memoir, .horror]))
        p.append(pal("Graphite", ["0E0F11", "2B2E33", "F2F2F2", "C9CCD1"], [.thriller, .nonfiction, .scienceFiction, .horror]))
        return p
    }()

    private static func tt(_ name: String, _ title: [String], _ author: [String], case c: LetterCase = .upper, tracking: Double = 0.02,
                           lineHeight: Double = 1.0, authorTracking: Double = 0.22, stacked: Bool = false, align: TextAlign = .center) -> TypeTreatment {
        var t = TypeTreatment(name: name, title: title, author: author)
        t.titleCase = c
        t.titleTracking = tracking
        t.titleLineHeight = lineHeight
        t.authorTracking = authorTracking
        t.stacked = stacked
        t.align = align
        return t
    }

    static let extraPairings: [Pairing] = {
        var p: [Pairing] = []
        func add(_ t: TypeTreatment, _ g: [Genre]) { p.append(Pairing(treatment: t, moods: g)) }
        add(tt("Didone & Geometric", ["PlayfairDisplay-Black"], ["Montserrat-Black"], tracking: 0.01), [.romance, .literary, .mystery, .memoir, .historical])
        add(tt("Bodoni Fashion", ["BodoniModa-Black"], ["JosefinSans-Bold"], tracking: 0.04, authorTracking: 0.3), [.romance, .literary, .nonfiction])
        add(tt("Fatface Poster", ["AbrilFatface-Regular"], ["Oswald-Bold"], case: .asTyped, tracking: 0), [.literary, .cozy, .memoir, .youngAdult])
        add(tt("Italic Romance", ["DMSerifDisplay-Italic"], ["JosefinSans-Light"], case: .asTyped, tracking: 0, authorTracking: 0.35), [.romance, .memoir, .literary])
        add(tt("Garamond Quiet", ["CormorantGaramond-Bold"], ["CormorantGaramond-SemiBold"], case: .asTyped, tracking: 0.01, authorTracking: 0.25), [.literary, .memoir, .historical, .mystery])
        add(tt("Caslon Bookish", ["LibreCaslonDisplay-Regular"], ["Montserrat-Black"], tracking: 0.03), [.literary, .historical, .mystery, .nonfiction])
        add(tt("Fraunces Soft", ["Fraunces-Black"], ["JosefinSans-Bold"], case: .asTyped, tracking: 0), [.cozy, .memoir, .nonfiction, .youngAdult])
        add(tt("Roman Inscription", ["Cinzel-Bold"], ["Cinzel-Regular"], tracking: 0.06, authorTracking: 0.3), [.fantasy, .historical, .thriller])
        add(tt("Decorative Epic", ["CinzelDecorative-Black"], ["MarcellusSC-Regular"], tracking: 0.03), [.fantasy, .historical])
        add(tt("Uncial Legend", ["UncialAntiqua-Regular"], ["Cinzel-Regular"], case: .asTyped, tracking: 0.02), [.fantasy, .historical])
        add(tt("Blackletter", ["UnifrakturMaguntia"], ["IM_FELL_English_SC"], case: .asTyped, tracking: 0), [.horror, .fantasy, .historical])
        add(tt("Pirate Script", ["PirataOne-Regular"], ["MarcellusSC-Regular"], case: .asTyped, tracking: 0.02), [.fantasy, .horror])
        add(tt("Condensed Shout", ["Anton-Regular"], ["Oswald-Bold"], tracking: 0.02, stacked: true), [.thriller, .nonfiction, .mystery, .youngAdult])
        add(tt("Bebas Billboard", ["BebasNeue-Regular"], ["Montserrat-Black"], tracking: 0.06, stacked: true), [.thriller, .nonfiction, .scienceFiction, .youngAdult])
        add(tt("League Gothic Tall", ["LeagueGothic-Regular"], ["JosefinSans-Bold"], tracking: 0.04, lineHeight: 0.92, stacked: true), [.thriller, .horror, .mystery])
        add(tt("Six Caps Skyline", ["SixCaps"], ["Oswald-Bold"], tracking: 0.08, lineHeight: 0.9, stacked: true), [.thriller, .literary, .nonfiction])
        add(tt("Big Shoulders", ["BigShouldersDisplay-Black"], ["Teko-SemiBold"], tracking: 0.03, stacked: true), [.thriller, .scienceFiction, .nonfiction])
        add(tt("Archivo Bold", ["ArchivoBlack-Regular"], ["Montserrat-Black"], tracking: 0.0), [.nonfiction, .youngAdult, .thriller])
        add(tt("Syne Modern", ["Syne-ExtraBold"], ["JosefinSans-Bold"], tracking: 0.0), [.nonfiction, .literary, .scienceFiction])
        add(tt("Unbounded Wide", ["Unbounded-ExtraBold"], ["Montserrat-Black"], tracking: 0.0), [.youngAdult, .scienceFiction, .nonfiction])
        add(tt("Deco Thin", ["PoiretOne-Regular"], ["JosefinSans-Bold"], tracking: 0.12, authorTracking: 0.4), [.mystery, .romance, .historical, .literary])
        add(tt("Limelight Noir", ["Limelight-Regular"], ["JosefinSans-Light"], tracking: 0.04), [.mystery, .historical, .thriller])
        add(tt("Monoton Retro", ["Monoton-Regular"], ["Righteous-Regular"], tracking: 0.04), [.youngAdult, .scienceFiction, .cozy])
        add(tt("Bungee Signage", ["Bungee-Regular"], ["Righteous-Regular"], tracking: 0.02), [.youngAdult, .cozy, .nonfiction])
        add(tt("Western Rye", ["Rye-Regular"], ["Oswald-Bold"], tracking: 0.04), [.historical, .thriller, .cozy])
        add(tt("Orbitron Future", ["Orbitron-Black"], ["Michroma-Regular"], tracking: 0.08, authorTracking: 0.4), [.scienceFiction, .thriller])
        add(tt("Audiowide Signal", ["Audiowide-Regular"], ["Exo2-ExtraBold"], tracking: 0.04), [.scienceFiction, .youngAdult])
        add(tt("Syncopate Space", ["Syncopate-Bold"], ["Michroma-Regular"], tracking: 0.12, authorTracking: 0.4), [.scienceFiction, .nonfiction])
        add(tt("Creepy", ["Creepster-Regular"], ["SpecialElite-Regular"], case: .asTyped, tracking: 0.02), [.horror, .youngAdult])
        add(tt("Typewriter Case", ["SpecialElite-Regular"], ["SpecialElite-Regular"], case: .asTyped, tracking: 0.02, authorTracking: 0.1), [.mystery, .thriller, .memoir, .literary])
        add(tt("Script & Caps", ["GreatVibes-Regular"], ["Cinzel-Regular"], case: .asTyped, tracking: 0), [.romance, .historical, .memoir])
        add(tt("Pinyon Elegance", ["PinyonScript-Regular"], ["CormorantGaramond-SemiBold"], case: .asTyped, tracking: 0), [.romance, .historical])
        add(tt("Parisienne Letter", ["Parisienne-Regular"], ["JosefinSans-Light"], case: .asTyped, tracking: 0), [.romance, .cozy, .memoir])
        add(tt("Brush Marker", ["PermanentMarker-Regular"], ["Oswald-Bold"], case: .asTyped, tracking: 0), [.youngAdult, .cozy, .nonfiction, .thriller])
        add(tt("Hand Lettered", ["KaushanScript-Regular"], ["JosefinSans-Bold"], case: .asTyped, tracking: 0), [.cozy, .romance, .youngAdult])
        add(tt("Rough Salt", ["RockSalt-Regular"], ["SpecialElite-Regular"], case: .asTyped, tracking: 0), [.horror, .thriller, .youngAdult])
        return p
    }()
}
