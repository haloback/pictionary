import Foundation

/// Parts of a cover the randomizer can re-roll or keep.
enum RandomAspect: String, CaseIterable, Codable, Identifiable {
    case layout, colors, fonts, titleStyle, background, photoLook, decorations

    var id: String { rawValue }
    var label: String {
        switch self {
        case .layout: return "Layout"
        case .colors: return "Colors"
        case .fonts: return "Fonts"
        case .titleStyle: return "Title Style"
        case .background: return "Background"
        case .photoLook: return "Photo Look"
        case .decorations: return "Borders & Trim"
        }
    }
    var symbol: String {
        switch self {
        case .layout: return "rectangle.3.group"
        case .colors: return "paintpalette"
        case .fonts: return "textformat"
        case .titleStyle: return "wand.and.stars"
        case .background: return "photo.on.rectangle"
        case .photoLook: return "camera.filters"
        case .decorations: return "rectangle.dashed"
        }
    }
}

/// Re-rolls the unlocked parts of a cover, choosing like a designer would:
/// layouts and type that suit the genre, colors drawn from the photo and its harmonies, styles that
/// stay legible on the ground they land on, and never a recipe it showed recently.
/// Locked layers (the padlock in the layer list) come through untouched.
enum SmartRandomizer {
    struct Options {
        var locks: Set<RandomAspect> = []
        /// 0 stays close to the genre's conventions; 1 borrows from anywhere.
        var creativity: Double = 0.35
    }

    /// The cover's recipe, or a best guess for covers made by hand.
    static func currentRecipe(_ doc: CoverDocument) -> CoverRecipe {
        if let r = doc.recipe { return r }
        let genre = doc.book.genre
        let style = GenreStyle.of(genre)
        let arch = Archetype.allCases.first { $0.label == doc.archetypeName } ?? style.archetypes.first ?? .typographic
        let titleFont = doc.textLayer(role: .title)?.textContent?.fontName ?? ""
        var pairing = style.treatments[0].name
        let allTreatments = style.treatments + TemplateLibrary.extraPairings.map(\.treatment)
        if let t = allTreatments.first(where: { $0.titleFont == titleFont }) { pairing = t.name }
        let presetName = doc.textLayer(role: .title)?.textContent?.style.presetName ?? ""
        let styleID = presetName.isEmpty ? nil : StyleLibrary.shared.all.first { $0.name == presetName }?.id
        let fill = doc.layers.compactMap { $0.fillContent?.style }.first { $0 != .scrim && $0 != .material } ?? style.fills[0]
        let effect = doc.layers.first { $0.imageContent != nil }?.effects.first?.presetID
        let border = doc.layers.compactMap { $0.decorContent?.itemID }.first { $0.hasPrefix("border.") }
        let flourish = doc.textLayer(role: .subtitle)?.textContent?.flourish ?? .none
        let palette = doc.palette.isEmpty ? style.moods[0] : doc.palette
        return CoverRecipe(genre: genre, archetype: arch, pairing: pairing, paletteName: "Current", palette: palette, styleID: styleID,
                           fill: fill, effect: effect, borderID: border, flourish: flourish, seed: Int.random(in: 1...999_999))
    }

    /// A new cover with the unlocked parts re-rolled. `recent` holds signatures not to repeat.
    static func randomize(_ doc: CoverDocument, options: Options, recent: [Int], seed: Int) -> CoverDocument {
        var rng = SeededRNG(seed: seed)
        if var sig = signatureRoll(doc, options: options, recent: recent, rng: &rng) {
            restoreLockedLayers(from: doc, into: &sig)
            return sig
        }
        let old = currentRecipe(doc)
        // Several fresh recipes, built and judged; the best-scoring one wins. Like a designer
        // sketching a few directions and keeping the strongest.
        var candidates: [CoverDocument] = []
        var tried = Set<Int>()
        var attempts = 0
        while candidates.count < 3 && attempts < 14 {
            attempts += 1
            let r = roll(old, doc: doc, options: options, rng: &rng)
            if tried.contains(r.signature) { continue }
            if (recent.contains(r.signature) || r.signature == old.signature) && attempts < 12 { continue }
            tried.insert(r.signature)
            var out = TemplateLibrary.build(r, base: doc)
            restoreLockedLayers(from: doc, into: &out)
            candidates.append(out)
        }
        if let w = Critic.best(candidates) { return w.0 }
        var out = TemplateLibrary.build(old, base: doc)
        restoreLockedLayers(from: doc, into: &out)
        return out
    }

    /// The Signature design and palette a cover was made from, if any ("sig.<design>.<palette>").
    static func signatureOf(_ doc: CoverDocument) -> (SignatureDesign, Int)? {
        guard let id = doc.templateID, id.hasPrefix("sig.") else { return nil }
        let parts = id.split(separator: ".")
        guard parts.count == 3, let d = SignatureLibrary.design(String(parts[1])), let pi = Int(parts[2]) else { return nil }
        return (d, pi)
    }

    /// Hand-composed Signature layouts join the mix: on a Signature cover with the layout locked, its other palettes;
    /// with the layout free, sometimes a whole Signature design for the genre. Nil means roll a recipe instead.
    private static func signatureRoll(_ doc: CoverDocument, options o: Options, recent: [Int], rng: inout SeededRNG) -> CoverDocument? {
        let layoutFree = !o.locks.contains(.layout)
        let colorsFree = !o.locks.contains(.colors)
        let current = signatureOf(doc)
        if let cur = current, !layoutFree {
            let design = cur.0
            let pi = cur.1
            guard colorsFree, design.palettes.count > 1 else { return nil }
            var next = rng.int(design.palettes.count - 1)
            if next >= pi { next += 1 }
            return SignatureLibrary.build(design, palette: next, base: doc)
        }
        // A Signature design brings its own palette and type, so only when those may change.
        guard layoutFree, colorsFree, !o.locks.contains(.fonts) else { return nil }
        let c = min(1, max(0, o.creativity))
        let chance = current == nil ? 0.3 : 0.55
        guard rng.unit() < chance else { return nil }
        let genre = doc.book.genre
        var pool = SignatureLibrary.all.filter { $0.genre == genre }
        if pool.isEmpty || rng.unit() < c * 0.5 { pool = SignatureLibrary.all }
        let currentID = current?.0.id
        var fresh: [SignatureDesign] = []
        for d in pool where d.id != currentID && !recent.contains(TemplateLibrary.seed("sig." + d.id)) { fresh.append(d) }
        guard let design = pick(fresh.isEmpty ? pool : fresh, &rng) else { return nil }
        return SignatureLibrary.build(design, palette: rng.int(design.palettes.count), base: doc)
    }

    private static func pick<T>(_ items: [T], _ rng: inout SeededRNG) -> T? {
        items.isEmpty ? nil : items[rng.int(items.count)]
    }

    private static func roll(_ old: CoverRecipe, doc: CoverDocument, options o: Options, rng: inout SeededRNG) -> CoverRecipe {
        var r = old
        let genre = doc.book.genre
        let style = GenreStyle.of(genre)
        let c = min(1, max(0, o.creativity))
        func wander() -> Bool { rng.unit() < c * 0.7 }
        let hasPhoto = !doc.assetOrder.filter { doc.assets[$0.uuidString] != nil }.isEmpty
        func free(_ a: RandomAspect) -> Bool { !o.locks.contains(a) }

        if free(.layout) {
            var pool = style.archetypes
            if wander() { pool = Archetype.allCases }
            if !hasPhoto { pool = pool.filter(\.worksWithoutImage) }
            if pool.isEmpty { pool = Archetype.allCases.filter { hasPhoto || $0.worksWithoutImage } }
            let others = pool.filter { $0 != old.archetype }
            r.archetype = pick(others.isEmpty ? pool : others, &rng) ?? old.archetype
        }
        if free(.colors) {
            let roam = wander()
            r.palette = smartPalette(doc: doc, genre: genre, wander: roam, rng: &rng, name: &r.paletteName)
        }
        if free(.fonts) {
            var pool = style.treatments + TemplateLibrary.extraPairings.filter { $0.moods.contains(genre) }.map(\.treatment)
            if wander() { pool += TemplateLibrary.extraPairings.map(\.treatment) }
            let others = pool.filter { $0.name != old.pairing }
            r.pairing = pick(others.isEmpty ? pool : others, &rng)?.name ?? old.pairing
        }
        if free(.titleStyle) {
            // Sometimes the best style is none: clean type.
            if rng.unit() < 0.22 * (1 - c) {
                r.styleID = nil
            } else {
                var pool = TextStylePreset.forGenre(genre)
                pool += StyleLibrary.shared.search("", family: nil, genre: genre).map(\.id).filter { id in
                    c > 0.6 || !["gen.pattern", "gen.sticker", "gen.balloon", "gen.glitch", "gen.drips"].contains(where: id.hasPrefix)
                }
                if wander() { pool += StyleLibrary.shared.all.map(\.id) }
                r.styleID = pick(pool.filter { $0 != old.styleID }, &rng) ?? old.styleID
            }
        }
        if free(.background) {
            var fills = style.fills
            if wander() { fills += [.wetInWet, .meshBlend, .watercolor, .smoke, .bokeh, .marble, .paintSmear, .sunburst, .goldenBlocks] }
            r.fill = pick(fills.filter { $0 != old.fill }, &rng) ?? old.fill
            r.seed = rng.int(1_000_000)
        }
        if free(.photoLook) {
            var effects = style.effects
            if wander() { effects += EffectLibrary.shared.search("", family: nil).prefix(400).map(\.id) }
            r.effect = rng.unit() < 0.15 ? nil : (pick(effects.filter { $0 != old.effect }, &rng) ?? old.effect)
        }
        if free(.decorations) {
            let chance = 0.3 + 0.35 * c
            let roam = wander()
            let borderGenre: Genre = roam ? Genre.allCases[rng.int(Genre.allCases.count)] : genre
            let borders = TemplateLibrary.borderPool(for: borderGenre)
            r.borderID = rng.unit() < chance ? pick(borders, &rng) : nil
            r.flourish = pick([TextFlourish.none, .none, .rules, .diamonds, .dots, .box, .underline, .brackets], &rng) ?? .none
        }
        if free(.layout) && free(.background) { r.seed = rng.int(1_000_000) }
        return r
    }

    /// Palettes a designer would reach for: the photo's own colors and their harmonies, the genre's moods,
    /// named palettes; only ones with strong light/dark contrast for the type.
    private static func smartPalette(doc: CoverDocument, genre: Genre, wander: Bool, rng: inout SeededRNG, name: inout String) -> [RGBA] {
        var candidates: [(String, [RGBA])] = []
        if let first = doc.assetOrder.first(where: { doc.assets[$0.uuidString] != nil }) {
            let p = AssetStore.shared.palette(first, data: doc.assetData(first))
            if !p.isEmpty {
                candidates.append(("From the Photo", p))
                candidates.append(("Photo Complement", PaletteRoles(p).complementary.colors))
                candidates.append(("From the Photo", p))
            }
        }
        for (k, mood) in GenreStyle.of(genre).moods.enumerated() { candidates.append(("\(genre.label) Classic \(k + 1)", mood)) }
        let named = TemplateLibrary.palettes.filter { wander || $0.moods.contains(genre) }
        for p in named { candidates.append((p.name, p.colors)) }
        // Keep palettes whose light and dark read well together.
        let legible = candidates.filter { c in
            let roles = PaletteRoles(c.1)
            return roles.light.contrast(with: roles.dark) >= 7
        }
        let pool = legible.isEmpty ? candidates : legible
        let current = doc.palette
        let fresh = pool.filter { $0.1 != current }
        let chosen = pick(fresh.isEmpty ? pool : fresh, &rng) ?? ("Current", current)
        name = chosen.0
        return chosen.1
    }

    /// Puts the locked layers of `doc` back: text by role, pictures by kind, the rest where they were.
    static func restoreLockedLayers(from doc: CoverDocument, into out: inout CoverDocument) {
        for (oldIndex, locked) in doc.layers.enumerated() where locked.isLocked {
            if let role = locked.textContent?.role, role != .custom,
               let j = out.layers.firstIndex(where: { $0.textContent?.role == role }) {
                out.layers[j] = locked
            } else if locked.imageContent != nil, let j = out.layers.firstIndex(where: { $0.imageContent?.assetID == locked.imageContent?.assetID }) {
                out.layers[j] = locked
            } else {
                let at = min(out.layers.count, Int(Double(oldIndex) / Double(max(1, doc.layers.count)) * Double(out.layers.count + 1)))
                out.layers.insert(locked, at: at)
            }
        }
    }
}
