import Foundation

// MARK: - The Signature design language
//
// A signature design is a hand-composed cover: every element has a precise box (normalized, top-left
// origin, on a 1:1.6 cover), a role in the palette, and a binding to the book (title, author...).
// Designs are art-directed like a top cover designer's work: one idea, two or three colors,
// type as image, bold crops, real negative space. `SignatureLibrary.build` turns one into layers.

/// Palette roles. Designs refer to roles, so every palette variant stays coherent.
struct SigPalette: Hashable {
    let name: String
    let bg: RGBA
    let ink: RGBA
    let accent: RGBA
    let muted: RGBA
    let paper: RGBA

    init(_ name: String, bg: String, ink: String, accent: String, muted: String, paper: String) {
        self.name = name
        self.bg = RGBA(hex: bg)
        self.ink = RGBA(hex: ink)
        self.accent = RGBA(hex: accent)
        self.muted = RGBA(hex: muted)
        self.paper = RGBA(hex: paper)
    }

    var colors: [RGBA] { [bg, ink, accent, muted, paper] }
}

indirect enum SigColor: Hashable {
    case bg, ink, accent, muted, paper
    case hex(String)
    /// A role at reduced opacity.
    case alpha(SigColor, Double)

    func resolve(_ p: SigPalette) -> RGBA {
        switch self {
        case .bg: return p.bg
        case .ink: return p.ink
        case .accent: return p.accent
        case .muted: return p.muted
        case .paper: return p.paper
        case .hex(let h): return RGBA(hex: h)
        case .alpha(let c, let a): return c.resolve(p).withAlpha(a)
        }
    }
}

/// What a text element says.
enum SigText: Hashable {
    case title, author, subtitle, tagline, series
    /// Fixed words set by the design ("A NOVEL", "BOOK ONE").
    case label(String)
    /// The book's subtitle if it has one, otherwise these words.
    case subtitleOr(String)
    /// The book's series if it has one, otherwise these words.
    case seriesOr(String)
}

/// How the title is broken into lines.
enum SigBreak: Hashable {
    case asTyped
    /// One word per line, the way big stacked titles are set.
    case stacked
    /// Balanced across this many lines.
    case lines(Int)
    case oneLine
}

/// Type settings for a text element.
struct SigType: Hashable {
    /// Candidate fonts (PostScript names), first available wins. Bundled fonts are always available.
    var fonts: [String]
    var color: SigColor = .ink
    var letterCase: LetterCase = .upper
    var tracking: Double = 0
    var lineHeight: Double = 1.0
    var align: TextAlign = .center
    var breaks: SigBreak = .asTyped
    /// Degrees; -90 runs the line up the cover.
    var rotation: Double = 0
    /// A title style from the style library (gold foil, emboss...), applied on top.
    var styleID: String?
    var flourish: TextFlourish = .none
    var flourishColor: SigColor?
    var gradientTo: SigColor?
    var shadow = false
    var opacity: Double = 1

    init(_ fonts: [String], color: SigColor = .ink, letterCase: LetterCase = .upper, tracking: Double = 0, lineHeight: Double = 1.0,
         align: TextAlign = .center, breaks: SigBreak = .asTyped, rotation: Double = 0, styleID: String? = nil,
         flourish: TextFlourish = .none, flourishColor: SigColor? = nil, gradientTo: SigColor? = nil, shadow: Bool = false, opacity: Double = 1) {
        self.fonts = fonts; self.color = color; self.letterCase = letterCase; self.tracking = tracking; self.lineHeight = lineHeight
        self.align = align; self.breaks = breaks; self.rotation = rotation; self.styleID = styleID; self.flourish = flourish
        self.flourishColor = flourishColor; self.gradientTo = gradientTo; self.shadow = shadow; self.opacity = opacity
    }
}

/// Photo treatments.
enum SigLook: Hashable {
    case natural
    case mono
    /// Hard black and white.
    case stark
    case sepia
    /// Shadows in the first color, highlights in the second.
    case duotone(SigColor, SigColor)
    /// Black and white washed with one color.
    case tint(SigColor)
    case faded
}

/// Grounds and blocks of color.
enum SigFill: Hashable {
    case solid(SigColor)
    /// Angle in degrees, 90 runs top to bottom.
    case linear(SigColor, SigColor, Double)
    case radial(SigColor, SigColor)
    /// A `MaterialLibrary` id, printed in the palette when its colorway is "palette".
    case material(String)
    /// Simulated watercolor with these paints on paper.
    case watercolor([SigColor])
    case grain(SigColor)
}

/// One element of a design, back to front.
enum SigElement: Hashable {
    case fill(SigFill, NRect)
    /// The book's photo (index into its photos). Without photos, `fallback` fills the same shape.
    case photo(NRect, clip: ShapeKind?, look: SigLook, focusY: Double, zoom: Double, index: Int, fallback: SigFill)
    case shape(ShapeKind, NRect, SigColor, stroke: Double, rotation: Double)
    case text(SigText, NRect, SigType)
    /// A border, corner set, divider, badge or banner found by keywords in the decor library.
    case decor(String, DecorLibrary.Kind, NRect, SigColor)
    /// A soft gradient for legibility over a photo; angle 90 darkens toward the bottom.
    case scrim(NRect, SigColor, angle: Double, strength: Double)
}

/// What a design needs for its demo render.
struct SigSample: Hashable {
    var title: String
    var subtitle: String = ""
    var author: String
    var tagline: String = ""
    var series: String = ""
    /// "portrait", "landscape" or "space": which public-domain test photo suits it.
    var photo: String = ""
}

struct SignatureDesign {
    let id: String
    let name: String
    let genre: Genre
    /// One sentence on the idea, shown in the browser.
    let idea: String
    let tags: [String]
    let elements: [SigElement]
    /// Two to four designer-picked palettes; the first is the hero.
    let palettes: [SigPalette]
    let sample: SigSample

    var usesPhoto: Bool {
        elements.contains { if case .photo = $0 { return true }; return false }
    }
}

// MARK: - Building

enum SignatureLibrary {
    /// All designs from every genre group.
    static let all: [SignatureDesign] = {
        var d: [SignatureDesign] = []
        d += examples
        d += groupA
        d += groupB
        d += groupC
        d += groupD
        var seen = Set<String>()
        return d.filter { seen.insert($0.id).inserted }
    }()

    static func design(_ id: String) -> SignatureDesign? { all.first { $0.id == id } }

    /// The design with one of its palettes, built around `base`'s book, photos, fonts and canvas.
    static func build(_ design: SignatureDesign, palette pi: Int, base: CoverDocument) -> CoverDocument {
        let p = design.palettes[min(max(0, pi), design.palettes.count - 1)]
        var doc = base
        doc.layers = []
        doc.palette = p.colors
        doc.background = p.bg
        doc.archetypeName = "Signature: " + design.name
        doc.recipe = nil
        doc.templateID = "sig.\(design.id).\(pi)"
        let photos = base.assetOrder.filter { base.assets[$0.uuidString] != nil }
        var n = 0
        for e in design.elements {
            n += 1
            switch e {
            case .fill(let f, let r):
                doc.layers.append(fillLayer(f, r, p, seed: n * 37 + 11))
            case .photo(let r, let clip, let look, let focusY, let zoom, let index, let fallback):
                if photos.isEmpty {
                    var l = fillLayer(fallback, r, p, seed: n * 53 + 5)
                    l.clipShape = clip
                    l.name = "Artwork"
                    doc.layers.append(l)
                } else {
                    var l = Layer.image(photos[index % photos.count], frame: r)
                    l.clipShape = clip
                    l.imageContent?.focusY = focusY
                    l.imageContent?.zoom = max(1, zoom)
                    doc.layers.append(contentsOf: treated(l, look, p))
                }
            case .shape(let kind, let r, let c, let stroke, let rot):
                let color = c.resolve(p)
                var l = Layer.shape(kind, fill: stroke > 0 ? nil : color, stroke: stroke > 0 ? color : nil, strokeWidth: max(0.001, stroke), frame: r)
                l.rotation = rot
                doc.layers.append(l)
            case .text(let what, let r, let t):
                guard let text = words(what, doc.book, breaks: t.breaks) else { continue }
                var l = Layer.text(text, role: role(what), frame: r, font: FontCatalog.resolve(t.fonts + ["Helvetica-Bold"]), color: t.color.resolve(p))
                l.rotation = t.rotation
                l.opacity = t.opacity
                if var tc = l.textContent {
                    tc.letterCase = t.letterCase
                    tc.tracking = t.tracking
                    tc.lineHeight = t.lineHeight
                    tc.alignment = t.align
                    tc.autoFit = true
                    tc.flourish = t.flourish
                    tc.flourishColor = t.flourishColor?.resolve(p)
                    tc.gradientTo = t.gradientTo?.resolve(p)
                    if let sid = t.styleID, let preset = TextStylePreset.preset(sid) {
                        let keep = tc.color
                        preset.apply(to: &tc, palette: PaletteRoles(p.colors))
                        tc.color = keep
                        tc.fontName = FontCatalog.resolve(t.fonts + ["Helvetica-Bold"])
                    }
                    l.textContent = tc
                }
                if t.shadow { l.shadow = ShadowStyle(color: RGBA(0, 0, 0, 0.5), radius: 0.01, dx: 0, dy: 0.003) }
                l.name = roleName(what)
                doc.layers.append(l)
            case .decor(let query, let kind, let r, let c):
                if let item = DecorLibrary.shared.search(query, kind: kind).first {
                    let color = c.resolve(p)
                    var l = Layer.decor(item.id, color: color, color2: nil, frame: r)
                    l.name = item.name
                    doc.layers.append(l)
                }
            case .scrim(let r, let c, let angle, let strength):
                var l = Layer.fill(.scrim, colors: [c.resolve(p)], frame: r, angle: angle, intensity: strength)
                l.name = "Scrim"
                doc.layers.append(l)
            }
        }
        return doc
    }

    private static func fillLayer(_ f: SigFill, _ r: NRect, _ p: SigPalette, seed: Int) -> Layer {
        var l: Layer
        switch f {
        case .solid(let c):
            l = Layer.fill(.solid, colors: [c.resolve(p)], frame: r)
        case .linear(let a, let b, let angle):
            l = Layer.fill(.linear, colors: [a.resolve(p), b.resolve(p)], frame: r, angle: angle)
            l.fillContent?.paintMix = true
        case .radial(let a, let b):
            l = Layer.fill(.radial, colors: [a.resolve(p), b.resolve(p)], frame: r, intensity: 0.55)
        case .material(let id):
            l = Layer.fill(.material, colors: [p.bg, p.accent, p.paper], frame: r, seed: seed)
            l.fillContent?.materialID = id
        case .watercolor(let paints):
            l = Layer.fill(.wetInWet, colors: paints.map { $0.resolve(p) } + [p.paper], frame: r, seed: seed, intensity: 0.55)
        case .grain(let c):
            l = Layer.fill(.grain, colors: [c.resolve(p), c.resolve(p).withLightness(max(0, c.resolve(p).hsl.l - 0.04))], frame: r, seed: seed, intensity: 0.3)
        }
        l.name = "Ground"
        return l
    }

    /// The photo layer plus any tint layers its look needs (clipped to the photo).
    private static func treated(_ photo: Layer, _ look: SigLook, _ p: SigPalette) -> [Layer] {
        var l = photo
        var extra: [Layer] = []
        func tint(_ c: RGBA, _ mode: BlendMode) {
            var t = Layer.fill(.solid, colors: [c], frame: photo.frame)
            t.blend = mode
            t.clipToBelow = true
            t.name = "Photo Tint"
            extra.append(t)
        }
        switch look {
        case .natural:
            break
        case .mono:
            l.adjust.saturation = -1
            l.adjust.contrast = 0.15
        case .stark:
            l.adjust.saturation = -1
            l.adjust.contrast = 0.6
            l.adjust.exposure = -0.1
        case .sepia:
            l.adjust.saturation = -0.85
            l.adjust.warmth = 0.7
            l.adjust.contrast = 0.1
        case .duotone(let dark, let light):
            l.adjust.saturation = -1
            l.adjust.contrast = 0.25
            tint(light.resolve(p), .multiply)
            tint(dark.resolve(p), .lighten)
        case .tint(let c):
            l.adjust.saturation = -1
            l.adjust.contrast = 0.2
            tint(c.resolve(p), .color)
        case .faded:
            l.adjust.saturation = -0.45
            l.adjust.contrast = -0.2
            l.adjust.exposure = 0.12
        }
        return [l] + extra
    }

    private static func role(_ t: SigText) -> TextRole {
        switch t {
        case .title: return .title
        case .author: return .author
        case .subtitle, .subtitleOr: return .subtitle
        case .tagline: return .tagline
        case .series, .seriesOr: return .series
        case .label: return .custom
        }
    }

    private static func roleName(_ t: SigText) -> String {
        if case .label(let s) = t { return s.capitalized }
        return role(t).label
    }

    private static func words(_ t: SigText, _ b: BookInfo, breaks: SigBreak) -> String? {
        func nonEmpty(_ s: String) -> String? {
            let v = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }
        switch t {
        case .title:
            let title = nonEmpty(b.title) ?? "Untitled"
            switch breaks {
            case .asTyped: return title
            case .oneLine: return title.replacingOccurrences(of: "\n", with: " ")
            case .stacked: return title.split(separator: " ").joined(separator: "\n")
            case .lines(let k): return TitleBreaker.balanced(title, lines: max(1, k))
            }
        case .author: return nonEmpty(b.author) ?? "Author Name"
        case .subtitle: return nonEmpty(b.subtitle)
        case .tagline: return nonEmpty(b.tagline)
        case .series: return nonEmpty(b.series)
        case .label(let s): return s
        case .subtitleOr(let s): return nonEmpty(b.subtitle) ?? s
        case .seriesOr(let s): return nonEmpty(b.series) ?? s
        }
    }

    /// The sample book for a design's demo render.
    static func sampleDocument(_ d: SignatureDesign) -> CoverDocument {
        var doc = CoverDocument()
        doc.book = BookInfo(title: d.sample.title, subtitle: d.sample.subtitle, author: d.sample.author,
                            series: d.sample.series, tagline: d.sample.tagline, genre: d.genre)
        return doc
    }
}

// MARK: - Two worked examples (the house standard for every design)

extension SignatureLibrary {
    static var examples: [SignatureDesign] {
        var out: [SignatureDesign] = []

        // The Grid: a massive, tightly leaded serif title carries the cover; one sun is the only image.
        var e: [SigElement] = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.shape(.rule, NRect(0.08, 0.05, 0.84, 0.0025), .ink, stroke: 0, rotation: 0))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.08, 0.065, 0.4, 0.022), SigType(["Montserrat-Black"], tracking: 0.3, align: .left)))
        e.append(.text(.title, NRect(0.065, 0.11, 0.86, 0.56), SigType(["PlayfairDisplay-Black"], letterCase: .title, tracking: -0.03, lineHeight: 0.84, align: .left, breaks: .stacked)))
        e.append(.shape(.ellipse, NRect(0.6, 0.66, 0.26, 0.2), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.rule, NRect(0.08, 0.945, 0.84, 0.0025), .ink, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.08, 0.905, 0.6, 0.03), SigType(["Montserrat-Black"], letterCase: .title, tracking: 0.04, align: .left)))
        out.append(SignatureDesign(id: "literary-the-grid", name: "The Grid", genre: .literary,
                                   idea: "A massive, tightly stacked serif carries the cover; one orange sun is the only image.",
                                   tags: ["typographic", "minimal", "light", "modern"], elements: e,
                                   palettes: [SigPalette("Paper & Vermilion", bg: "F1EBDD", ink: "121212", accent: "E8562A", muted: "8A8478", paper: "FBF7EE"),
                                              SigPalette("Night & Gold", bg: "14171C", ink: "F1EBDD", accent: "E7B547", muted: "6B6E73", paper: "F1EBDD"),
                                              SigPalette("Sage & Plum", bg: "D9DFCF", ink: "2B2233", accent: "7A3E65", muted: "7D8F7A", paper: "F4F1E8")],
                                   sample: SigSample(title: "The Salt Orchard", author: "Ines Valcourt")))

        // Brand Name: the author is the biggest thing on the cover; hard black-and-white photo; one red word.
        e = []
        e.append(.photo(.full, clip: nil, look: .stark, focusY: 0.3, zoom: 1, index: 0, fallback: .material("mat.smoke.charcoal.b")))
        e.append(.scrim(NRect(0, 0, 1, 0.32), .hex("000000"), angle: 270, strength: 0.75))
        e.append(.scrim(NRect(0, 0.45, 1, 0.55), .hex("000000"), angle: 90, strength: 0.95))
        e.append(.text(.author, NRect(0.06, 0.035, 0.88, 0.1), SigType(["BebasNeue-Regular"], color: .paper, tracking: 0.06)))
        e.append(.text(.label("THE NEW NOVEL"), NRect(0.25, 0.14, 0.5, 0.018), SigType(["Montserrat-Black"], color: .paper, tracking: 0.4)))
        e.append(.text(.title, NRect(0.08, 0.6, 0.84, 0.27), SigType(["Anton-Regular"], color: .paper, lineHeight: 0.92, breaks: .lines(2))))
        e.append(.text(.tagline, NRect(0.1, 0.9, 0.8, 0.022), SigType(["Montserrat-Black"], color: .muted, tracking: 0.3)))
        out.append(SignatureDesign(id: "thriller-brand-name", name: "Brand Name", genre: .thriller,
                                   idea: "The author's name is the biggest thing on the cover, like an established bestseller; hard black-and-white photo.",
                                   tags: ["photo", "dark", "condensed", "bold type"], elements: e,
                                   palettes: [SigPalette("Black & Signal Red", bg: "000000", ink: "000000", accent: "E2231A", muted: "CFCFCF", paper: "F2F2F2"),
                                              SigPalette("Black & Acid", bg: "000000", ink: "000000", accent: "D4FF3A", muted: "BDBDBD", paper: "F2F2F2")],
                                   sample: SigSample(title: "No One Leaves", author: "Mara Kellen", tagline: "Some doors only open one way", photo: "landscape")))
        return out
    }
}
