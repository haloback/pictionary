import Foundation

/// A typographic voice: which faces, what case, how much air.
struct TypeTreatment {
    let name: String
    let title: [String]
    let author: [String]
    var titleCase: LetterCase = .upper
    var titleTracking: Double = 0.02
    var titleLineHeight: Double = 1.0
    var authorCase: LetterCase = .upper
    var authorTracking: Double = 0.22
    /// Each short word on its own line, filling the width.
    var stacked: Bool = false
    var align: TextAlign = .center

    var titleFont: String { FontCatalog.resolve(title) }
    var authorFont: String { FontCatalog.resolve(author) }
}

/// Genre conventions readers recognize at thumbnail size.
struct GenreStyle {
    let genre: Genre
    let treatments: [TypeTreatment]
    let moods: [[RGBA]]
    let archetypes: [Archetype]
    let effects: [String]
    let fills: [FillStyle]

    static func of(_ g: Genre) -> GenreStyle { all[g] ?? all[.literary]! }

    private static func p(_ hex: String...) -> [RGBA] { hex.map { RGBA(hex: $0) } }

    // Shared treatments
    private static let condensedImpact = TypeTreatment(name: "Condensed Impact", title: ["BebasNeue-Regular", "AvenirNextCondensed-Heavy", "HelveticaNeue-CondensedBlack", "Impact"], author: ["AvenirNextCondensed-Bold", "DINCondensed-Bold"], titleTracking: 0.01, titleLineHeight: 0.92, stacked: true)
    private static let wideSans = TypeTreatment(name: "Wide Tracked Sans", title: ["Michroma-Regular", "Futura-Medium", "AvenirNext-Regular"], author: ["Futura-Medium", "AvenirNext-Regular"], titleTracking: 0.32, titleLineHeight: 1.15, authorTracking: 0.4)
    private static let didone = TypeTreatment(name: "Didone Elegance", title: ["BodoniModa-Bold", "Didot", "BodoniSvtyTwoITCTT-Book"], author: ["Didot", "BodoniSvtyTwoITCTT-Book"], titleTracking: 0.04, titleLineHeight: 1.0, authorTracking: 0.3)
    private static let didoneItalic = TypeTreatment(name: "Didone Italic", title: ["PlayfairDisplay-BoldItalic", "Didot-Italic", "BodoniSvtyTwoITCTT-BookIta", "Baskerville-Italic"], author: ["Didot", "Baskerville"], titleCase: .asTyped, titleTracking: 0, titleLineHeight: 1.02, authorTracking: 0.3)
    private static let classicSerif = TypeTreatment(name: "Classic Serif", title: ["Baskerville-SemiBold", "HoeflerText-Regular"], author: ["Baskerville", "HoeflerText-Regular"], titleTracking: 0.06, titleLineHeight: 1.05, authorTracking: 0.28)
    private static let bigCaslon = TypeTreatment(name: "Big Caslon", title: ["LibreCaslonDisplay-Regular", "BigCaslon-Medium", "Baskerville"], author: ["GillSans-Light", "AvenirNext-Regular"], titleCase: .asTyped, titleTracking: 0, titleLineHeight: 1.0, authorTracking: 0.3)
    private static let futuraBold = TypeTreatment(name: "Geometric Bold", title: ["Montserrat-Black", "Futura-Bold", "AvenirNext-Heavy"], author: ["Futura-Medium", "AvenirNext-Regular"], titleTracking: 0.02, titleLineHeight: 0.95, stacked: true, align: .left)
    private static let slab = TypeTreatment(name: "Slab Poster", title: ["Superclarendon-Black", "Rockwell-Bold"], author: ["Rockwell-Regular", "Superclarendon-Regular"], titleTracking: 0.0, titleLineHeight: 0.98, stacked: true)
    private static let script = TypeTreatment(name: "Romantic Script", title: ["GreatVibes-Regular", "PinyonScript-Regular", "SnellRoundhand-Bold", "SavoyeLetPlain"], author: ["Didot", "Baskerville"], titleCase: .asTyped, titleTracking: 0, titleLineHeight: 1.0, authorTracking: 0.32)
    private static let fantasyCaps = TypeTreatment(name: "Engraved Capitals", title: ["Cinzel-Bold", "CinzelDecorative-Bold", "Trattatello", "Copperplate-Bold"], author: ["Copperplate", "Optima-Regular"], titleTracking: 0.06, titleLineHeight: 1.05, authorTracking: 0.3)
    private static let optimaEpic = TypeTreatment(name: "Epic Optima", title: ["CinzelDecorative-Black", "Optima-ExtraBlack", "Optima-Bold"], author: ["Optima-Regular"], titleTracking: 0.12, titleLineHeight: 1.0, authorTracking: 0.35)
    private static let thinSans = TypeTreatment(name: "Ultralight Minimal", title: ["AvenirNext-UltraLight", "HelveticaNeue-Thin"], author: ["AvenirNext-DemiBold", "Futura-Medium"], titleTracking: 0.18, titleLineHeight: 1.1, authorTracking: 0.35)
    private static let gill = TypeTreatment(name: "Humanist", title: ["GillSans-Bold", "GillSans"], author: ["GillSans-Light"], titleCase: .asTyped, titleTracking: -0.01, titleLineHeight: 1.0, authorCase: .asTyped, authorTracking: 0.05, align: .left)
    private static let typewriter = TypeTreatment(name: "Typewriter", title: ["SpecialElite-Regular", "AmericanTypewriter-Bold", "Courier-Bold"], author: ["AmericanTypewriter", "Courier"], titleTracking: 0.04, titleLineHeight: 1.05, authorTracking: 0.2)
    private static let dinStack = TypeTreatment(name: "DIN Stack", title: ["Antonio-Bold", "DINCondensed-Bold", "AvenirNextCondensed-Bold"], author: ["DINAlternate-Bold", "AvenirNext-DemiBold"], titleTracking: 0.03, titleLineHeight: 0.9, stacked: true, align: .left)

    private static let horrorDisplay = TypeTreatment(name: "Horror Display", title: ["Creepster-Regular", "Nosifer-Regular", "Butcherman-Regular"], author: ["SpecialElite-Regular", "AmericanTypewriter"], titleTracking: 0.02, titleLineHeight: 1.0, authorTracking: 0.2)
    private static let medieval = TypeTreatment(name: "Medieval", title: ["UncialAntiqua-Regular", "PirataOne-Regular", "MedievalSharp"], author: ["MarcellusSC-Regular", "Cinzel-Regular"], titleCase: .asTyped, titleTracking: 0.02, titleLineHeight: 1.02, authorTracking: 0.25)
    private static let tech = TypeTreatment(name: "Tech Display", title: ["Orbitron-Black", "Audiowide-Regular", "Exo2-ExtraBold"], author: ["Michroma-Regular", "Futura-Medium"], titleTracking: 0.06, titleLineHeight: 1.0, authorTracking: 0.35)
    private static let deco = TypeTreatment(name: "Art Deco", title: ["Limelight-Regular", "PoiretOne-Regular"], author: ["JosefinSans-Light", "Futura-Medium"], titleTracking: 0.08, titleLineHeight: 1.05, authorTracking: 0.35)
    private static let marker = TypeTreatment(name: "Hand Lettered", title: ["PermanentMarker-Regular", "KaushanScript-Regular", "CaveatBrush-Regular"], author: ["JosefinSans-Bold", "AvenirNext-DemiBold"], titleCase: .asTyped, titleTracking: 0, titleLineHeight: 1.0, authorTracking: 0.2)
    private static let fatface = TypeTreatment(name: "Fat Face", title: ["AbrilFatface-Regular", "RozhaOne-Regular", "YesevaOne-Regular"], author: ["JosefinSans-Light", "GillSans-Light"], titleCase: .asTyped, titleTracking: 0, titleLineHeight: 0.98, authorTracking: 0.3)

    static let all: [Genre: GenreStyle] = [
        .thriller: GenreStyle(genre: .thriller,
            treatments: [condensedImpact, wideSans, dinStack, futuraBold, typewriter],
            moods: [p("0B0C10", "1F2833", "C5C6C7", "D7263D"), p("111214", "3A3D42", "F2A541", "F7F4EE"), p("0B1D3A", "13404A", "E4572E", "F2ECDF")],
            archetypes: [.behindSubject, .doubleExposure, .fullBleedBottom, .cinematic, .diagonal, .duotonePoster, .ghostSubject, .collage, .splitBand],
            effects: ["look.teal-amber.cinematic", "tone.bleach-bypass.3", "tone.noir.3", "look.storm-amber.grain", "grade.navy-peach.2", "look.ink-amber.vignette", "duo.ink-black.complement.2"],
            fills: [.smoke, .grain, .stripes, .paintSmear]),
        .mystery: GenreStyle(genre: .mystery,
            treatments: [classicSerif, condensedImpact, typewriter, wideSans],
            moods: [p("1B2A4A", "34495E", "F2A541", "F3E9D2"), p("2E1C12", "4A2C17", "D4A017", "F4F1E8"), p("13404A", "0B4F55", "FFB38A", "F2ECDF")],
            archetypes: [.framedWindow, .fullBleedTop, .doubleExposure, .cinematic, .splitBand, .ghostSubject, .duotonePoster, .arch],
            effects: ["look.navy-amber.vignette", "tone.dusty-film.3", "look.petrol-cream.matte", "grade.slate-amber.2", "duo.prussian.bone.1", "tone.moonlight.2"],
            fills: [.smoke, .grain, .marble, .halftone]),
        .horror: GenreStyle(genre: .horror,
            treatments: [horrorDisplay, condensedImpact, fantasyCaps, typewriter],
            moods: [p("0A0A0A", "4A0E17", "9E1B32", "E8E6E1"), p("111214", "1E3D2F", "8BC34A", "F7F4EE"), p("0B0C10", "2B2D31", "D7263D", "EDE6D6")],
            archetypes: [.behindSubject, .doubleExposure, .ghostSubject, .duotonePoster, .cinematic, .fullBleedBottom, .medallion],
            effects: ["duo.oxblood.bone.2", "tone.noir.4", "look.crimson-cream.grain", "tone.gloom.3", "look.ink-rose.vignette", "print.dot-screen.2.mono"],
            fills: [.smoke, .grain, .watercolor, .marble]),
        .romance: GenreStyle(genre: .romance,
            treatments: [script, didoneItalic, didone, fatface, bigCaslon],
            moods: [p("F4C2C2", "F28AB2", "9E1B32", "F7F4EE"), p("3B1F3A", "D81E5B", "FFB38A", "F4F1E8"), p("F3E9D2", "FBB474", "B87333", "4A1942")],
            archetypes: [.fullBleedTop, .blendedPair, .arch, .medallion, .minimal, .splitBand, .framedWindow, .behindSubject],
            effects: ["look.plum-peach.bloom", "tone.dream.2", "look.crimson-rose.glow", "grade.violet-rose.1", "leak.peach.tr", "look.umber-cream.matte"],
            fills: [.meshBlend, .watercolor, .bokeh, .radial]),
        .fantasy: GenreStyle(genre: .fantasy,
            treatments: [fantasyCaps, optimaEpic, medieval, didone, classicSerif],
            moods: [p("0B1D3A", "23308C", "D4A017", "F3E9D2"), p("1E3D2F", "0B4A33", "F2A541", "EDE6D6"), p("3A1F6B", "8E44AD", "F4C430", "F4F1E8")],
            archetypes: [.medallion, .arch, .blendedPair, .fullBleedTop, .behindSubject, .ghostSubject, .framedWindow, .goldenGrid],
            effects: ["look.indigo-amber.bloom", "leak.gold.top", "look.forest-cream.glow", "grade.violet-amber.2", "tone.dream.3", "atmo.amber.haze"],
            fills: [.starfield, .smoke, .sunburst, .marble, .bokeh]),
        .scienceFiction: GenreStyle(genre: .scienceFiction,
            treatments: [tech, wideSans, futuraBold, thinSans, dinStack],
            moods: [p("0B0C10", "0B6E8A", "48CAE4", "F7F4EE"), p("111214", "3A1F6B", "FF2E88", "D6EAF8"), p("0B1D3A", "1B998B", "F2E863", "F4F1E8")],
            archetypes: [.cinematic, .behindSubject, .ghostSubject, .goldenGrid, .duotonePoster, .medallion, .typographic],
            effects: ["look.cyan-amber.cinematic", "grade.teal-peach.3", "look.violet-rose.bloom", "tone.chrome.3", "leak.electric-blue.br", "paint.neon-edges.1"],
            fills: [.starfield, .halftone, .stripes, .bokeh, .smoke]),
        .literary: GenreStyle(genre: .literary,
            treatments: [bigCaslon, thinSans, gill, didoneItalic, classicSerif],
            moods: [p("F2ECDF", "B23A2E", "1B2A4A", "D8C3A5"), p("E8E6E1", "34495E", "C8553D", "111214"), p("1E3D2F", "A3B18A", "F2ECDF", "D4A017")],
            archetypes: [.minimal, .doubleExposure, .framedWindow, .arch, .goldenGrid, .typographic, .splitBand, .medallion],
            effects: ["tone.matte.2", "look.slate-cream.matte", "duo.navy-ink.bone.0", "tone.faded-print.2", "paint.watercolor.1", "look.olive-cream.grain"],
            fills: [.bauhaus, .goldenBlocks, .grain, .watercolor, .paintSmear]),
        .historical: GenreStyle(genre: .historical,
            treatments: [classicSerif, didone, fantasyCaps, deco, bigCaslon],
            moods: [p("2E1C12", "6B4A1C", "D4A017", "F3E9D2"), p("4A0E17", "7A2E12", "F2A541", "F4F1E8"), p("1B2A4A", "34495E", "D8C3A5", "F2ECDF")],
            archetypes: [.framedWindow, .arch, .blendedPair, .fullBleedTop, .splitBand, .medallion, .ghostSubject],
            effects: ["tone.sepia.2", "look.umber-amber.matte", "tone.dusty-film.2", "grade.rust-cream.2", "duo.espresso.bone.1", "paint.oil-paint.1"],
            fills: [.marble, .grain, .watercolor, .sunburst]),
        .youngAdult: GenreStyle(genre: .youngAdult,
            treatments: [futuraBold, marker, condensedImpact, gill, slab],
            moods: [p("2D7DD2", "F28C28", "F7F4EE", "111214"), p("D81E5B", "F4C430", "7FD8BE", "1B2A4A"), p("8E44AD", "48CAE4", "F2E863", "111214")],
            archetypes: [.behindSubject, .typographic, .duotonePoster, .splitBand, .goldenGrid, .medallion, .diagonal],
            effects: ["look.violet-peach.bloom", "tone.vibrant.3", "duo.ultramarine.complement.2", "leak.hot-pink.tl", "tone.punch.2", "paint.pop-poster.1"],
            fills: [.paintSmear, .meshBlend, .halftone, .stripes, .bauhaus]),
        .cozy: GenreStyle(genre: .cozy,
            treatments: [marker, script, fatface, bigCaslon, slab],
            moods: [p("F3E9D2", "C8553D", "1E4D2B", "FBB474"), p("D6EAF8", "2B59C3", "F28AB2", "F7F4EE"), p("A3B18A", "F2ECDF", "B23A2E", "4A2C17")],
            archetypes: [.arch, .medallion, .minimal, .framedWindow, .splitBand, .typographic],
            effects: ["tone.warm.2", "look.forest-peach.glow", "tone.instant.2", "grade.rust-cream.1", "paint.watercolor.0", "leak.apricot.tl"],
            fills: [.watercolor, .sunburst, .meshBlend, .stripes, .radial]),
        .nonfiction: GenreStyle(genre: .nonfiction,
            treatments: [gill, futuraBold, thinSans, dinStack, condensedImpact],
            moods: [p("F7F4EE", "111214", "E4572E"), p("111214", "F2A541", "F7F4EE"), p("1B3B8A", "F7F4EE", "F2E863")],
            archetypes: [.typographic, .goldenGrid, .minimal, .splitBand, .framedWindow],
            effects: ["tone.high-contrast.2", "duo.cobalt.bone.1", "tone.mono.3", "print.dot-screen.1.color", "tone.clarity.2"],
            fills: [.solid, .goldenBlocks, .bauhaus, .halftone, .linear]),
        .memoir: GenreStyle(genre: .memoir,
            treatments: [thinSans, bigCaslon, didoneItalic, gill],
            moods: [p("F2ECDF", "4A2C17", "C8553D"), p("E8E6E1", "1B2A4A", "F2A541"), p("1E3D2F", "F3E9D2", "D4A017")],
            archetypes: [.minimal, .doubleExposure, .fullBleedBottom, .framedWindow, .arch, .splitBand, .behindSubject],
            effects: ["tone.instant.3", "tone.faded-print.3", "look.umber-cream.grain", "tone.mono.2", "duo.sepia-brown.bone.0", "look.slate-peach.matte"],
            fills: [.grain, .watercolor, .linear, .paintSmear])
    ]
}
