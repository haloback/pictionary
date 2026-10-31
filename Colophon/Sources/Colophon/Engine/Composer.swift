import CoreGraphics
import Foundation

/// Proven cover compositions. Every frame below is placed on golden-section or thirds lines.
enum Archetype: String, CaseIterable, Codable, Identifiable {
    case fullBleedTop, fullBleedBottom, behindSubject, framedWindow, arch, medallion, splitBand
    case diagonal, typographic, minimal, duotonePoster, cinematic, collage, ghostSubject, goldenGrid
    case doubleExposure, blendedPair

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fullBleedTop: return "Full Bleed, Title High"
        case .fullBleedBottom: return "Full Bleed, Title Low"
        case .behindSubject: return "Title Behind Subject"
        case .framedWindow: return "Framed Window"
        case .arch: return "Arch Window"
        case .medallion: return "Medallion"
        case .splitBand: return "Golden Split"
        case .diagonal: return "Diagonal Cut"
        case .typographic: return "Typographic"
        case .minimal: return "Quiet Minimal"
        case .duotonePoster: return "Duotone Poster"
        case .cinematic: return "Cinematic"
        case .collage: return "Two-Piece Collage"
        case .ghostSubject: return "Depth Cutout"
        case .goldenGrid: return "Golden Grid"
        case .doubleExposure: return "Double Exposure"
        case .blendedPair: return "Blended Pair"
        }
    }

    /// Compositions that work with no photo at all (colors and shapes only).
    var worksWithoutImage: Bool {
        switch self {
        case .typographic, .goldenGrid, .minimal, .arch, .medallion, .framedWindow, .splitBand: return true
        default: return false
        }
    }
}

struct DesignContext {
    var book: BookInfo
    var style: GenreStyle
    var treatment: TypeTreatment
    var palette: PaletteRoles
    var images: [UUID]
    var focus: NRect
    var effect: String?
    var fill: FillStyle
    var aspect: Double
    var seed: Int
    /// Whether the ground behind the title is dark (decides light or dark type).
    var darkGround = true
}

enum CoverComposer {
    static let margin = 0.075

    /// A diversified set of complete covers from one brief.
    static func variations(base: CoverDocument, count: Int, seed: Int, only archetype: Archetype? = nil) -> [CoverDocument] {
        let style = GenreStyle.of(base.book.genre)
        let images = base.assetOrder.filter { base.assets[$0.uuidString] != nil }
        let first = images.first
        let imagePalette = first.map { AssetStore.shared.palette($0, data: base.assetData($0)) } ?? []
        let focus = first.map { AssetStore.shared.focus($0, data: base.assetData($0)) } ?? NRect(0.25, 0.25, 0.5, 0.5)
        if let first { _ = AssetStore.shared.mask(first, data: base.assetData(first)) }

        var order: [Archetype] = []
        let preferred = style.archetypes + Archetype.allCases
        for a in preferred where !order.contains(a) {
            if images.isEmpty && !a.worksWithoutImage { continue }
            order.append(a)
        }
        if let archetype { order = [archetype] }

        var rng = SeededRNG(seed: seed)
        var docs: [CoverDocument] = []
        // Generated styles that suit the genre, minus the loudest families for photo covers.
        let genrePool = StyleLibrary.shared.search("", family: nil, genre: base.book.genre)
            .filter { !["gen.pattern", "gen.sticker", "gen.balloon", "gen.glitch"].contains(where: $0.id.hasPrefix) || images.isEmpty }
            .map(\.id)
        for i in 0..<count {
            let arch = order[i % order.count]
            let round = i / order.count
            let treatment = style.treatments[(i + round + seed) % style.treatments.count]

            // Rotate palette strategies: user's colors, photo colors, the opposite twist, genre mood.
            var palette: PaletteRoles
            let strategy = (i + round) % 3
            if !base.palette.isEmpty && (strategy != 2 || images.isEmpty) {
                palette = PaletteRoles(base.palette)
            } else if !imagePalette.isEmpty && strategy == 0 {
                palette = PaletteRoles(imagePalette)
            } else if !imagePalette.isEmpty && strategy == 1 {
                palette = PaletteRoles(imagePalette).complementary
            } else {
                palette = PaletteRoles(style.moods[(i + round) % style.moods.count])
            }

            var ctx = DesignContext(
                book: base.book, style: style, treatment: treatment, palette: palette, images: images, focus: focus,
                effect: style.effects.isEmpty ? nil : style.effects[(i * 3 + round + seed) % style.effects.count],
                fill: style.fills[(i + round * 2 + seed) % style.fills.count],
                aspect: base.canvas.aspect, seed: rng.int(1_000_000))
            var doc = base
            doc.layers = build(arch, &ctx)
            doc.palette = palette.colors
            doc.archetypeName = arch.label
            doc.background = palette.dark
            // Two of every three ideas get a genre title style, so the set stays varied.
            // Alternate hand-tuned genre styles with picks from the full library for the genre.
            let curatedIDs = TextStylePreset.forGenre(base.book.genre)
            let pool = genrePool
            let styles = (i % 2 == 0 || pool.isEmpty) ? curatedIDs : pool
            if !styles.isEmpty, (i + seed) % 3 != 2,
               let preset = TextStylePreset.preset(styles[(i * 7 + round + seed) % styles.count]),
               let ti = doc.layers.firstIndex(where: { $0.textContent?.role == .title }), var t = doc.layers[ti].textContent {
                // Keep the treatment's font and colors; the style adds material and depth.
                let keepColor = t.color
                preset.apply(to: &t, palette: palette)
                if preset.category != "Light" && preset.category != "Genre" { t.color = keepColor }
                doc.layers[ti].textContent = t
            }
            Polisher.polish(&doc, palette: palette)
            docs.append(doc)
        }
        return docs
    }

    // MARK: - Building blocks

    private static func titleText(_ c: DesignContext) -> String {
        let t = c.book.title.isEmpty ? "Untitled" : c.book.title
        return TitleBreaker.auto(t, stacked: c.treatment.stacked, maxChars: c.treatment.stacked ? 10 : 14)
    }

    static func title(_ c: DesignContext, _ f: NRect, color: RGBA? = nil, behind: Bool = false, align: TextAlign? = nil) -> Layer {
        var l = Layer.text(titleText(c), role: .title, frame: f, font: c.treatment.titleFont,
                           color: color ?? (c.darkGround ? c.palette.light : c.palette.dark))
        l.textContent?.letterCase = c.treatment.titleCase
        l.textContent?.tracking = c.treatment.titleTracking
        l.textContent?.lineHeight = c.treatment.titleLineHeight
        l.textContent?.alignment = align ?? c.treatment.align
        l.textContent?.behindSubject = behind
        l.name = "Title"
        return l
    }

    static func author(_ c: DesignContext, _ f: NRect, color: RGBA? = nil, align: TextAlign? = nil) -> Layer {
        var l = Layer.text(c.book.author.isEmpty ? "Author Name" : c.book.author, role: .author, frame: f,
                           font: c.treatment.authorFont, color: color ?? (c.darkGround ? c.palette.light : c.palette.dark))
        l.textContent?.letterCase = c.treatment.authorCase
        l.textContent?.tracking = c.treatment.authorTracking
        l.textContent?.alignment = align ?? c.treatment.align
        l.name = "Author"
        return l
    }

    /// Subtitle, series or tagline: small supporting lines, only if the brief has them.
    static func supporting(_ c: DesignContext, _ f: NRect, role: TextRole, align: TextAlign? = nil, color: RGBA? = nil) -> Layer? {
        let text: String
        switch role {
        case .subtitle: text = c.book.subtitle
        case .series: text = c.book.series
        case .tagline: text = c.book.tagline
        default: text = ""
        }
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var l = Layer.text(text, role: role, frame: f, font: c.treatment.authorFont,
                           color: color ?? (c.darkGround ? c.palette.light : c.palette.dark).withAlpha(0.92))
        l.textContent?.letterCase = role == .series ? .upper : .asTyped
        l.textContent?.tracking = role == .series ? 0.3 : 0.04
        l.textContent?.alignment = align ?? c.treatment.align
        l.name = role.label
        return l
    }

    static func photo(_ c: DesignContext, _ f: NRect, index: Int = 0, effect: Bool = true) -> Layer {
        guard !c.images.isEmpty else {
            // No photo: a generative ground stands in so every composition still works.
            var l = Layer.fill(c.fill, colors: [c.palette.dark, c.palette.accent, c.palette.dominant, c.palette.light], frame: f, seed: c.seed)
            l.name = "Artwork"
            return l
        }
        var l = Layer.image(c.images[index % c.images.count], frame: f)
        if let e = c.effect, effect { l.effects = [EffectInstance(presetID: e, amount: 0.85)] }
        return l
    }

    static func scrim(_ c: DesignContext, _ f: NRect, darkAt angle: Double, strength: Double = 0.8, color: RGBA? = nil) -> Layer {
        var l = Layer.fill(.scrim, colors: [color ?? c.palette.dark], frame: f, angle: angle, intensity: strength)
        l.name = "Legibility Scrim"
        return l
    }

    static func ground(_ c: DesignContext, light: Bool) -> Layer {
        let base = light ? c.palette.light : c.palette.dark
        var l = Layer.fill(.grain, colors: [base], intensity: 0.25)
        l.name = "Ground"
        return l
    }

    // MARK: - Archetypes

    static func build(_ a: Archetype, _ c: inout DesignContext) -> [Layer] {
        let m = margin
        let wide = 1 - 2 * m
        // Keep circles circular regardless of store aspect ratio.
        func square(_ widthFrac: Double) -> Double { widthFrac / c.aspect }
        var L: [Layer] = []
        func add(_ l: Layer?) { if let l { L.append(l) } }

        switch a {
        case .fullBleedTop, .fullBleedBottom:
            // Put the title where the subject is not.
            let titleHigh = a == .fullBleedTop ? c.focus.midY >= 0.35 : c.focus.midY > 0.62
            c.darkGround = true
            add(photo(c, .full))
            if titleHigh {
                add(scrim(c, NRect(0, 0, 1, 0.52), darkAt: 270, strength: 0.85))
                add(scrim(c, NRect(0, 0.78, 1, 0.22), darkAt: 90, strength: 0.7))
                add(supporting(c, NRect(m, 0.035, wide, 0.026), role: .series))
                add(title(c, NRect(m, 0.07, wide, Golden.minor - 0.1)))
                add(supporting(c, NRect(m, Golden.minor - 0.015, wide, 0.034), role: .subtitle))
                add(author(c, NRect(m, 0.885, wide, 0.05)))
            } else {
                add(scrim(c, NRect(0, 0.42, 1, 0.58), darkAt: 90, strength: 0.9))
                add(scrim(c, NRect(0, 0, 1, 0.2), darkAt: 270, strength: 0.6))
                add(author(c, NRect(m, 0.05, wide, 0.048)))
                add(supporting(c, NRect(m, 0.575, wide, 0.03), role: .tagline))
                add(title(c, NRect(m, Golden.major, wide, 0.235)))
                add(supporting(c, NRect(m, 0.865, wide, 0.034), role: .subtitle))
                add(supporting(c, NRect(m, 0.925, wide, 0.026), role: .series))
            }

        case .behindSubject:
            c.darkGround = true
            add(photo(c, .full))
            add(scrim(c, NRect(0, 0, 1, 0.45), darkAt: 270, strength: 0.55))
            add(scrim(c, NRect(0, 0.8, 1, 0.2), darkAt: 90, strength: 0.75))
            add(supporting(c, NRect(m, 0.03, wide, 0.024), role: .series))
            var t = title(c, NRect(0.04, 0.055, 0.92, Golden.minor - 0.06), behind: !c.images.isEmpty, align: .center)
            t.textContent?.tracking = min(c.treatment.titleTracking, 0.04)
            add(t)
            add(supporting(c, NRect(m, 0.825, wide, 0.03), role: .subtitle))
            add(author(c, NRect(m, 0.88, wide, 0.052)))

        case .framedWindow:
            let lightGround = c.seed % 2 == 0
            c.darkGround = !lightGround
            add(ground(c, light: lightGround))
            let win = NRect(0.1, 0.09, 0.8, 0.5)
            add(photo(c, win))
            add(.shape(.frame, fill: nil, stroke: c.palette.accent, strokeWidth: 0.003, frame: win.insetBy(dx: -0.018, dy: -0.018 / c.aspect)))
            add(title(c, NRect(0.08, Golden.major + 0.02, 0.84, 0.17), align: .center))
            add(supporting(c, NRect(0.1, 0.81, 0.8, 0.028), role: .subtitle, align: .center))
            add(.shape(.rule, fill: c.palette.accent, frame: NRect(0.44, 0.855, 0.12, 0.0025)))
            add(author(c, NRect(0.12, 0.875, 0.76, 0.045), align: .center))
            add(supporting(c, NRect(0.1, 0.035, 0.8, 0.024), role: .series, align: .center))

        case .arch:
            let lightGround = c.seed % 3 != 0
            c.darkGround = !lightGround
            add(ground(c, light: lightGround))
            let win = NRect(0.17, 0.12, 0.66, 0.5)
            var p = photo(c, win)
            p.clipShape = .arch
            add(p)
            add(.shape(.arch, fill: nil, stroke: c.palette.accent, strokeWidth: 0.0028, frame: NRect(0.15, 0.108, 0.7, 0.522)))
            add(supporting(c, NRect(0.1, 0.04, 0.8, 0.026), role: .series, align: .center))
            add(title(c, NRect(0.08, 0.66, 0.84, 0.15), align: .center))
            add(supporting(c, NRect(0.1, 0.82, 0.8, 0.028), role: .subtitle, align: .center))
            add(author(c, NRect(0.12, 0.88, 0.76, 0.042), align: .center))

        case .medallion:
            c.darkGround = true
            var bg = Layer.fill(.meshBlend, colors: [c.palette.dark, c.palette.accent.withLightness(0.3), c.palette.dominant.withLightness(0.25), c.palette.dark], seed: c.seed, intensity: 0.6)
            bg.name = "Blended Ground"
            add(bg)
            let d = 0.62, h = square(d)
            let circle = NRect(0.19, Golden.minor - h / 2, d, h)
            var p = photo(c, circle)
            p.clipShape = .ellipse
            p.shadow = ShadowStyle(color: RGBA(0, 0, 0, 0.5), radius: 0.02, dx: 0, dy: 0.008)
            add(p)
            add(.shape(.ring, fill: nil, stroke: c.palette.accent.withLightness(0.7), strokeWidth: 0.003, frame: circle.insetBy(dx: -0.02, dy: -0.02 / c.aspect)))
            add(title(c, NRect(0.08, 0.63, 0.84, 0.17), align: .center))
            add(supporting(c, NRect(0.1, 0.81, 0.8, 0.028), role: .subtitle, align: .center))
            add(author(c, NRect(0.12, 0.875, 0.76, 0.045), align: .center))

        case .splitBand:
            c.darkGround = true
            var band = Layer.fill(.grain, colors: [c.palette.dark], intensity: 0.2)
            band.name = "Color Band"
            add(band)
            var p = photo(c, NRect(0, 0, 1, 0.66))
            p.fade = .bottom
            p.fadeAmount = 0.3
            add(p)
            add(.shape(.rule, fill: c.palette.accent, frame: NRect(m, 0.655, 0.16, 0.004)))
            add(title(c, NRect(m, 0.675, wide, 0.17), align: c.treatment.align == .center ? .center : .left))
            add(supporting(c, NRect(m, 0.85, wide, 0.026), role: .subtitle, align: c.treatment.align == .center ? .center : .left))
            add(author(c, NRect(m, 0.895, wide, 0.042), align: c.treatment.align == .center ? .center : .left))

        case .diagonal:
            c.darkGround = true
            add(photo(c, .full))
            add(scrim(c, NRect(0, 0, 1, 0.5), darkAt: 270, strength: 0.7))
            var band = Layer.shape(.diagonalBand, fill: c.palette.accent.withAlpha(0.9), frame: NRect(-0.05, 0.52, 1.1, 0.36))
            band.blend = .multiply
            add(band)
            add(title(c, NRect(m, 0.06, 0.8, 0.31), align: .left))
            add(supporting(c, NRect(m, 0.38, 0.8, 0.03), role: .subtitle, align: .left))
            add(scrim(c, NRect(0, 0.82, 1, 0.18), darkAt: 90, strength: 0.75))
            add(author(c, NRect(m, 0.9, wide, 0.045), align: .left))

        case .typographic:
            let light = c.seed % 4 == 0
            c.darkGround = !light
            let colors = light
                ? [c.palette.light, c.palette.accent.withLightness(0.82), c.palette.light.withLightness(0.86)]
                : [c.palette.dark, c.palette.accent.withLightness(0.35), c.palette.dominant.withLightness(0.22), c.palette.dark]
            var bg = Layer.fill(c.fill, colors: colors, seed: c.seed, intensity: 0.5)
            bg.name = "Artwork"
            add(bg)
            let align = c.treatment.align
            add(supporting(c, NRect(m, 0.06, wide, 0.026), role: .series, align: align))
            var t = title(c, NRect(m, 0.12, wide, 0.55), align: align)
            if t.textContent?.text.contains("\n") == false {
                t.textContent?.text = TitleBreaker.auto(c.book.title.isEmpty ? "Untitled" : c.book.title, stacked: true)
            }
            add(t)
            add(.shape(.rule, fill: c.palette.accent, frame: NRect(align == .left ? m : 0.43, 0.71, 0.14, 0.004)))
            add(supporting(c, NRect(m, 0.735, wide, 0.034), role: .subtitle, align: align))
            add(author(c, NRect(m, 0.86, wide, 0.055), align: align))

        case .minimal:
            let light = c.seed % 3 != 1
            c.darkGround = !light
            var bg = Layer.fill(.linear, colors: light ? [c.palette.light, c.palette.light.withLightness(0.88)] : [c.palette.dark, c.palette.dark.withLightness(0.16)], angle: 90)
            bg.name = "Ground"
            add(bg)
            if c.images.isEmpty {
                let d = 0.36, h = square(d)
                add(.shape(.ring, fill: nil, stroke: c.palette.accent, strokeWidth: 0.006, frame: NRect(0.32, Golden.minor - h / 2, d, h)))
                add(.shape(.ellipse, fill: c.palette.accent, frame: NRect(0.47, Golden.minor - square(0.06) / 2, 0.06, square(0.06))))
            } else {
                var p = Layer.image(c.images[0], frame: NRect(0.2, 0.14, 0.6, 0.42), name: "Subject")
                p.imageContent?.cutout = .subject
                p.shadow = ShadowStyle(color: RGBA(0, 0, 0, 0.35), radius: 0.015, dx: 0, dy: 0.006)
                add(p)
            }
            var t = title(c, NRect(0.14, Golden.major, 0.72, 0.1), align: .center)
            t.textContent?.text = TitleBreaker.auto(c.book.title.isEmpty ? "Untitled" : c.book.title, stacked: false, maxChars: 18)
            add(t)
            add(supporting(c, NRect(0.18, 0.735, 0.64, 0.026), role: .subtitle, align: .center))
            add(author(c, NRect(0.2, 0.88, 0.6, 0.032), align: .center))

        case .duotonePoster:
            c.darkGround = true
            var p = photo(c, .full, effect: false)
            if let duo = EffectLibrary.shared.closestDuotone(to: c.palette.dark) {
                p.effects = [EffectInstance(presetID: duo.id, amount: 1)]
            }
            p.effects.append(EffectInstance(presetID: "print.dot-screen.1.color", amount: 0.45))
            add(p)
            add(scrim(c, NRect(0, 0.45, 1, 0.55), darkAt: 90, strength: 0.75))
            add(author(c, NRect(m, 0.05, wide, 0.04), align: .left))
            add(title(c, NRect(m, 0.6, wide, 0.27), align: .left))
            add(supporting(c, NRect(m, 0.885, wide, 0.03), role: .subtitle, align: .left))

        case .cinematic:
            c.darkGround = true
            var p = photo(c, .full)
            p.effects.append(EffectInstance(presetID: "tone.vignette.3", amount: 1))
            add(p)
            add(scrim(c, NRect(0, 0.5, 1, 0.5), darkAt: 90, strength: 0.85))
            add(scrim(c, NRect(0, 0, 1, 0.16), darkAt: 270, strength: 0.6))
            var au = author(c, NRect(0.12, 0.055, 0.76, 0.03), align: .center)
            au.textContent?.tracking = 0.45
            add(au)
            add(supporting(c, NRect(0.15, 0.56, 0.7, 0.026), role: .tagline, align: .center))
            var t = title(c, NRect(0.08, Golden.major, 0.84, 0.13), align: .center)
            t.textContent?.text = TitleBreaker.auto(c.book.title.isEmpty ? "Untitled" : c.book.title, stacked: false, maxChars: 16)
            t.textContent?.tracking = max(c.treatment.titleTracking, 0.12)
            add(t)
            add(supporting(c, NRect(0.15, 0.77, 0.7, 0.026), role: .subtitle, align: .center))
            add(supporting(c, NRect(0.15, 0.92, 0.7, 0.024), role: .series, align: .center))

        case .collage:
            c.darkGround = true
            var top = photo(c, NRect(0, 0, 1, 0.5), index: 0)
            var bottom = photo(c, NRect(0, 0.5, 1, 0.5), index: 1)
            if c.images.count < 2 {
                // One photo, two pieces: a wide view on top, a tight crop of the subject below.
                top.imageContent?.focusY = max(0, c.focus.y - 0.1)
                bottom.imageContent?.zoom = 1.8
                bottom.imageContent?.focusX = c.focus.midX
                bottom.imageContent?.focusY = c.focus.midY
            }
            add(top)
            add(bottom)
            var band = Layer.shape(.rectangle, fill: c.palette.dark, frame: NRect(0, 0.43, 1, 0.14))
            band.shadow = ShadowStyle(color: RGBA(0, 0, 0, 0.45), radius: 0.01, dx: 0, dy: 0)
            add(band)
            add(title(c, NRect(m, 0.445, wide, 0.11), align: .center))
            add(scrim(c, NRect(0, 0.82, 1, 0.18), darkAt: 90, strength: 0.8))
            add(author(c, NRect(m, 0.89, wide, 0.045), align: .center))

        case .ghostSubject:
            c.darkGround = true
            var bg = photo(c, .full, effect: false)
            bg.effects = [EffectInstance(presetID: "tone.background-blur.4", amount: 1), EffectInstance(presetID: "tone.darken.2", amount: 1)]
            if let e = c.effect { bg.effects.append(EffectInstance(presetID: e, amount: 0.7)) }
            add(bg)
            add(scrim(c, NRect(0, 0, 1, 0.45), darkAt: 270, strength: 0.6))
            add(title(c, NRect(m, 0.06, wide, Golden.minor - 0.08), align: .center))
            if let img = c.images.first {
                var s = Layer.image(img, frame: .full, name: "Subject (lifted)")
                s.imageContent?.cutout = .subject
                s.shadow = ShadowStyle(color: RGBA(0, 0, 0, 0.6), radius: 0.02, dx: 0, dy: 0.006)
                if let e = c.effect { s.effects = [EffectInstance(presetID: e, amount: 0.7)] }
                add(s)
            }
            add(scrim(c, NRect(0, 0.8, 1, 0.2), darkAt: 90, strength: 0.8))
            add(supporting(c, NRect(m, Golden.minor - 0.01, wide, 0.03), role: .subtitle, align: .center))
            add(author(c, NRect(m, 0.885, wide, 0.05), align: .center))

        case .doubleExposure:
            // A second scene inside the first photo's subject, on a pale ground.
            c.darkGround = false
            var ground = Layer.fill(.linear, colors: [c.palette.light, c.palette.light.withLightness(0.86)], angle: 90)
            ground.name = "Ground"
            add(ground)
            if let first = c.images.first {
                var subject = Layer.image(first, frame: .full, name: "Subject")
                subject.imageContent?.cutout = .subject
                subject.effects = [EffectInstance(presetID: "tone.desaturate.4", amount: 1)]
                var scene = Layer.image(c.images.count > 1 ? c.images[1] : first, frame: .full, name: "Exposed Scene")
                if c.images.count < 2 {
                    scene.imageContent?.zoom = 1.8
                    scene.imageContent?.flipped = true
                }
                scene.mask.subjectOf = subject.id
                if let e = c.effect { scene.effects = [EffectInstance(presetID: e, amount: 0.7)] }
                var detail = subject
                detail.id = UUID()
                detail.name = "Subject Detail"
                detail.blend = .multiply
                detail.opacity = 0.45
                add(subject)
                add(scene)
                add(detail)
            }
            add(title(c, NRect(m, 0.06, wide, Golden.minor - 0.1), align: .center))
            add(supporting(c, NRect(m, Golden.minor - 0.03, wide, 0.03), role: .subtitle, align: .center))
            add(author(c, NRect(m, 0.89, wide, 0.045), align: .center))

        case .blendedPair:
            c.darkGround = true
            let top = photo(c, NRect(0, 0, 1, 0.64), index: 0)
            var bottom = photo(c, NRect(0, 0.36, 1, 0.64), index: 1)
            if c.images.count < 2 {
                bottom.imageContent?.zoom = 1.7
                bottom.imageContent?.focusX = c.focus.midX
                bottom.imageContent?.focusY = c.focus.midY
            }
            bottom.mask.gradient = .linear
            bottom.mask.angle = 270
            bottom.mask.start = 0.45
            bottom.mask.end = 1
            add(top)
            add(bottom)
            add(scrim(c, NRect(0, 0.42, 1, 0.3), darkAt: 90, strength: 0.5))
            add(title(c, NRect(m, 0.47, wide, 0.2), align: .center))
            add(scrim(c, NRect(0, 0.82, 1, 0.18), darkAt: 90, strength: 0.8))
            add(author(c, NRect(m, 0.89, wide, 0.045), align: .center))

        case .goldenGrid:
            c.darkGround = true
            var bg = Layer.fill(.goldenBlocks, colors: [c.palette.dark, c.palette.accent, c.palette.dominant, c.palette.light.withLightness(0.8), c.palette.accent.withLightness(0.35)], seed: c.seed, intensity: 0.5)
            bg.name = "Golden Blocks"
            add(bg)
            if !c.images.isEmpty {
                var p = photo(c, NRect(0, 0, Golden.major, 0.45))
                p.opacity = 0.95
                add(p)
            }
            var plate = Layer.shape(.rectangle, fill: c.palette.dark.withAlpha(0.94), frame: NRect(0.07, 0.56, 0.86, 0.33))
            plate.shadow = ShadowStyle(color: RGBA(0, 0, 0, 0.35), radius: 0.012, dx: 0, dy: 0.005)
            add(plate)
            add(title(c, NRect(0.11, 0.59, 0.78, 0.18), align: c.treatment.align))
            add(supporting(c, NRect(0.11, 0.775, 0.78, 0.026), role: .subtitle, align: c.treatment.align))
            add(author(c, NRect(0.11, 0.82, 0.78, 0.04), align: c.treatment.align))
        }
        return L
    }
}
