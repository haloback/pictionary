import AppKit
import CoreGraphics
import CoreText
import Foundation

/// What a decor layer stores (Codable, Hashable — it goes into the document).
struct DecorContent: Codable, Hashable {
    var itemID: String
    var color: RGBA
    /// Secondary color: inner line, badge text, ribbon text. nil = derived from `color` (or knocked out for solid badges).
    var color2: RGBA? = nil
    /// Badges and banners only; nil = the item's default text.
    var text: String? = nil
}

/// Thousands of procedural cover ornaments, drawn with Core Graphics at any size: borders, corner flourishes,
/// dividers, badges/seals and ribbons/banners. Nothing here is an image asset; every item is a recipe
/// (`DD.Spec`) that renders crisp, antialiased paths at the requested pixel size.
final class DecorLibrary {
    static let shared = DecorLibrary()

    enum Kind: String, CaseIterable {
        case border, corners, divider, badge, banner

        /// Plural label for chips and menus.
        var label: String {
            switch self {
            case .border: return "Borders"
            case .corners: return "Corners"
            case .divider: return "Dividers"
            case .badge: return "Badges"
            case .banner: return "Banners"
            }
        }
    }

    enum ColorRole { case light, dark, accent, gold }

    struct Item: Identifiable, Hashable {
        let id: String
        let name: String
        let kind: Kind
        let category: String
        let tags: [String]
        /// Where it goes on a 2:3 or 1:1.6 cover when inserted (borders: .full).
        let defaultFrame: NRect
        let defaultText: String?
        let colorRole: ColorRole
        let secondRole: ColorRole?

        static func == (a: Item, b: Item) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    /// The fixed metallic used by "Gold" items.
    static let goldColor = RGBA(hex: "E7C877")

    /// Default texts for badges and banners. No award or bestseller claims.
    static let defaultTexts: [String] = [
        "A NOVEL", "BOOK ONE", "BOOK TWO", "BOOK THREE", "BOOK FOUR", "BOOK FIVE", "BOOK SIX",
        "PART ONE", "NEW", "FIRST EDITION", "SPECIAL EDITION", "COLLECTOR'S EDITION",
        "A MEMOIR", "SHORT STORIES", "POEMS"
    ]

    let items: [Item]
    let categories: [String]
    private let index: [String: Item]
    private let specs: [String: DD.Spec]
    private let haystacks: [String]

    func item(_ id: String) -> Item? { index[id] }

    /// Words are AND-matched over name, category and tags.
    func search(_ query: String, kind: Kind?) -> [Item] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        var out: [Item] = []
        for i in 0..<items.count {
            let it = items[i]
            if let kind, it.kind != kind { continue }
            if words.isEmpty {
                out.append(it)
                continue
            }
            let hay = haystacks[i]
            var ok = true
            for w in words where !hay.contains(w) {
                ok = false
                break
            }
            if ok { out.append(it) }
        }
        return out
    }

    /// Colors for a new layer from the cover palette (gold = a fixed metallic).
    func colors(for item: Item, palette: PaletteRoles) -> (RGBA, RGBA?) {
        let a = DecorLibrary.resolve(item.colorRole, palette)
        var b: RGBA? = nil
        if let r = item.secondRole { b = DecorLibrary.resolve(r, palette) }
        return (a, b)
    }

    private static func resolve(_ role: ColorRole, _ p: PaletteRoles) -> RGBA {
        switch role {
        case .light: return p.light
        case .dark: return p.dark
        case .accent: return p.accent
        case .gold: return goldColor
        }
    }

    /// Transparent raster of the decor at `size` pixels. `canvasHeight` is the full cover height in pixels, so
    /// line weights scale with the cover, not with the layer box.
    func render(_ c: DecorContent, size: CGSize, canvasHeight: CGFloat) -> CGImage? {
        guard let spec = specs[c.itemID], let it = index[c.itemID] else { return nil }
        let w = min(12000, max(1, Int(size.width.rounded())))
        let h = min(12000, max(1, Int(size.height.rounded())))
        guard let ctx = Gfx.context(w, h) else { return nil }
        let W = CGFloat(w)
        let Hh = CGFloat(h)
        // Work in a top-left origin space.
        ctx.translateBy(x: 0, y: Hh)
        ctx.scaleBy(x: 1, y: -1)
        ctx.setShouldAntialias(true)
        ctx.setAllowsAntialiasing(true)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        let H: CGFloat = canvasHeight > 1 ? canvasHeight : Hh
        let bounds = CGRect(x: 0, y: 0, width: W, height: Hh)
        let c1 = c.color
        let c2 = c.color2
        let text = c.text ?? it.defaultText ?? ""
        let seed = DD.stableSeed(c.itemID)
        switch spec {
        case let .border(fam, style, weight, inset):
            DD.drawBorder(ctx, fam, style, bounds: bounds, H: H, weight: weight.borderFrac, inset: inset.borderFrac,
                          c1: c1, c2: c2 ?? c1)
        case let .cornerBorder(fam, weight, inset):
            DD.drawCornerBorder(ctx, fam, bounds: bounds, H: H, weight: weight.borderFrac, inset: inset.borderFrac,
                                c1: c1, c2: c2 ?? c1, seed: seed)
        case let .corners(orn, osz, inset, weight):
            DD.drawCorners(ctx, orn, bounds: bounds, H: H, unitFrac: osz.frac, inset: inset.cornerFrac,
                           weight: weight.cornerFrac, c1: c1, c2: c2 ?? c1)
        case let .divider(line, motif, cap):
            DD.drawDivider(ctx, line, motif, cap, W: W, Hh: Hh, H: H, c1: c1, c2: c2 ?? c1)
        case let .badge(shape, ring, solid):
            DD.drawBadge(ctx, shape, ring, solid, W: W, Hh: Hh, text: text, c1: c1, c2: c2)
        case let .banner(style, end, solid):
            DD.drawBanner(ctx, style, end, solid, W: W, Hh: Hh, text: text, c1: c1, c2: c2)
        }
        return ctx.makeImage()
    }

    /// Convenience for thumbnails: renders the item with sample colors from the palette, over a
    /// contrasting ground (a 2:3 page for borders and corners, the whole tile for the rest).
    func thumbnail(_ id: String, size: CGSize, palette: PaletteRoles) -> CGImage? {
        guard let it = index[id] else { return nil }
        let cols = colors(for: it, palette: palette)
        var content = DecorContent(itemID: id, color: cols.0)
        content.color2 = cols.1
        let w = max(8, Int(size.width.rounded()))
        let h = max(8, Int(size.height.rounded()))
        guard let ctx = Gfx.context(w, h) else { return nil }
        let W = CGFloat(w)
        let Hh = CGFloat(h)
        let ground: RGBA = cols.0.luminance > 0.3 ? palette.dark : palette.light
        switch it.kind {
        case .border, .corners:
            let ph = Hh * 0.94
            let pw = ph * 2 / 3
            let page = CGRect(x: (W - pw) / 2, y: (Hh - ph) / 2, width: pw, height: ph)
            ctx.setFillColor(ground.cgColor)
            ctx.fill(page)
            if let img = render(content, size: page.size, canvasHeight: ph) { ctx.draw(img, in: page) }
        default:
            ctx.setFillColor(ground.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: W, height: Hh))
            let f = it.defaultFrame
            let aspect = CGFloat((f.w * 2) / max(0.001, f.h * 3))
            var bw: CGFloat = W * 0.88
            var bh: CGFloat = bw / aspect
            if bh > Hh * 0.8 {
                bh = Hh * 0.8
                bw = bh * aspect
            }
            let box = CGRect(x: (W - bw) / 2, y: (Hh - bh) / 2, width: bw, height: bh)
            let canvasH: CGFloat = bw / CGFloat(max(0.01, f.w)) * 1.5
            if let img = render(content, size: box.size, canvasHeight: canvasH) { ctx.draw(img, in: box) }
        }
        return ctx.makeImage()
    }

    // MARK: Building

    private init() {
        var b = DecorBuilder()
        b.buildBorders()
        b.buildCorners()
        b.buildDividers()
        b.buildBadges()
        b.buildBanners()
        items = b.items
        specs = b.specs
        haystacks = b.hay
        var cats: [String] = []
        for it in b.items where !cats.contains(it.category) { cats.append(it.category) }
        categories = cats
        var idx: [String: Item] = [:]
        for it in b.items { idx[it.id] = it }
        index = idx
    }
}

// MARK: - Catalog

fileprivate struct DecorBuilder {
    var items: [DecorLibrary.Item] = []
    var specs: [String: DD.Spec] = [:]
    var hay: [String] = []

    mutating func add(_ id: String, _ name: String, _ kind: DecorLibrary.Kind, _ category: String, _ tags: [String],
                      _ frame: NRect, _ text: String?, _ role: DecorLibrary.ColorRole, _ second: DecorLibrary.ColorRole?,
                      _ spec: DD.Spec) {
        let item = DecorLibrary.Item(id: id, name: name, kind: kind, category: category, tags: tags, defaultFrame: frame,
                                     defaultText: text, colorRole: role, secondRole: second)
        items.append(item)
        specs[id] = spec
        let h = name + " " + category + " " + tags.joined(separator: " ")
        hay.append(h.lowercased())
    }

    static func slug(_ s: String) -> String {
        var out = ""
        for ch in s.lowercased() {
            if ch == " " { out.append("-") } else if ch.isLetter || ch.isNumber { out.append(ch) }
        }
        return out
    }

    static func title(_ s: String) -> String {
        let words = s.lowercased().split(separator: " ")
        var parts: [String] = []
        for w in words {
            let str = String(w)
            parts.append(str.prefix(1).uppercased() + String(str.dropFirst()))
        }
        return parts.joined(separator: " ")
    }

    mutating func buildBorders() {
        for fam in DD.LineFamily.allCases {
            for cs in DD.CornerStyle.allCases {
                for w in DD.Weight.allCases {
                    for ins in DD.InsetLevel.allCases {
                        for tone in DD.Tone.allCases {
                            let id = "border.\(fam.rawValue).\(cs.rawValue).\(w.rawValue).\(ins.rawValue).\(tone.rawValue)"
                            let name = "\(fam.label), \(cs.label), \(w.label), \(ins.label), \(tone.label)"
                            var tags: [String] = fam.tags
                            tags.append(contentsOf: ["border", "frame", cs.rawValue, cs.label.lowercased(), w.rawValue,
                                                     w.alias, ins.rawValue, tone.rawValue])
                            add(id, name, .border, fam.category, tags, .full, nil, tone.role, nil,
                                .border(fam, cs, w, ins))
                        }
                    }
                }
            }
        }
        for fam in DD.CornerFamily.allCases {
            for w in DD.Weight.allCases {
                for ins in DD.InsetLevel.allCases {
                    for tone in DD.Tone.allCases {
                        let id = "border.\(fam.rawValue).\(w.rawValue).\(ins.rawValue).\(tone.rawValue)"
                        let name = "\(fam.label), \(w.label), \(ins.label), \(tone.label)"
                        var tags: [String] = fam.tags
                        tags.append(contentsOf: ["border", "frame", w.rawValue, w.alias, ins.rawValue, tone.rawValue])
                        add(id, name, .border, fam.category, tags, .full, nil, tone.role, nil,
                            .cornerBorder(fam, w, ins))
                    }
                }
            }
        }
    }

    mutating func buildCorners() {
        let weights: [DD.Weight] = [.regular, .heavy]
        let insets: [DD.InsetLevel] = [.edge, .inset]
        for orn in DD.CornerOrn.allCases {
            for size in DD.OrnSize.allCases {
                for ins in insets {
                    for w in weights {
                        for tone in DD.Tone.allCases {
                            let id = "corners.\(orn.rawValue).\(size.rawValue).\(ins.rawValue).\(w.rawValue).\(tone.rawValue)"
                            let name = "\(orn.label) Corners, \(size.label), \(ins.label), \(w.label), \(tone.label)"
                            var tags: [String] = orn.tags
                            tags.append(contentsOf: ["corner", "corners", "ornament", size.rawValue, ins.rawValue,
                                                     w.rawValue, w.alias, tone.rawValue])
                            add(id, name, .corners, "Corner Ornaments", tags, .full, nil, tone.role, nil,
                                .corners(orn, size, ins, w))
                        }
                    }
                }
            }
        }
    }

    mutating func buildDividers() {
        let frame = NRect(0.25, 0.62, 0.5, 0.04)
        for line in DD.DivLine.allCases {
            for motif in DD.DivMotif.allCases {
                for cap in DD.DivCap.allCases {
                    for tone in DD.Tone.allCases {
                        let id = "divider.\(line.rawValue).\(motif.rawValue).\(cap.rawValue).\(tone.rawValue)"
                        let name = "\(line.label) Divider, \(motif.label), \(cap.label), \(tone.label)"
                        var tags: [String] = ["divider", "rule", "separator", "line", line.rawValue, motif.rawValue,
                                              cap.rawValue, tone.rawValue]
                        tags.append(contentsOf: motif.tags)
                        add(id, name, .divider, "Dividers", tags, frame, nil, tone.role, nil,
                            .divider(line, motif, cap))
                    }
                }
            }
        }
    }

    mutating func buildBadges() {
        let frame = NRect(0.68, 0.06, 0.24, 0.15)
        for shape in DD.BadgeShape.allCases {
            for ring in DD.BadgeRing.allCases {
                for solid in [true, false] {
                    for text in DecorLibrary.defaultTexts {
                        let fill = solid ? "solid" : "outline"
                        let id = "badge.\(shape.rawValue).\(ring.rawValue).\(fill).\(DecorBuilder.slug(text))"
                        let name = "\(shape.label), \(ring.label), \(solid ? "Solid" : "Outline"), \(DecorBuilder.title(text))"
                        var tags: [String] = ["badge", "seal", "sticker", "stamp", shape.rawValue, ring.rawValue, fill]
                        tags.append(contentsOf: shape.tags)
                        tags.append(text.lowercased())
                        let role: DecorLibrary.ColorRole = solid ? .accent : .gold
                        let second: DecorLibrary.ColorRole? = solid ? .light : nil
                        add(id, name, .badge, "Badges & Seals", tags, frame, text, role, second,
                            .badge(shape, ring, solid))
                    }
                }
            }
        }
    }

    mutating func buildBanners() {
        let frame = NRect(0.15, 0.7, 0.7, 0.07)
        for style in DD.BannerStyle.allCases {
            for end in DD.BannerEnd.allCases {
                for solid in [true, false] {
                    for text in DecorLibrary.defaultTexts {
                        let fill = solid ? "solid" : "outline"
                        let id = "banner.\(style.rawValue).\(end.rawValue).\(fill).\(DecorBuilder.slug(text))"
                        let name = "\(style.label), \(end.label), \(solid ? "Solid" : "Outline"), \(DecorBuilder.title(text))"
                        var tags: [String] = ["banner", "ribbon", "label", style.rawValue, end.rawValue, fill]
                        tags.append(contentsOf: style.tags)
                        tags.append(text.lowercased())
                        let role: DecorLibrary.ColorRole = solid ? .accent : .light
                        let second: DecorLibrary.ColorRole? = solid ? .light : nil
                        add(id, name, .banner, "Ribbons & Banners", tags, frame, text, role, second,
                            .banner(style, end, solid))
                    }
                }
            }
        }
    }
}

// MARK: - Drawing

/// Recipes and Core Graphics drawing for every decor item. All drawing happens in a top-left origin space.
fileprivate enum DD {
    // MARK: Recipe vocabulary

    enum Spec {
        case border(LineFamily, CornerStyle, Weight, InsetLevel)
        case cornerBorder(CornerFamily, Weight, InsetLevel)
        case corners(CornerOrn, OrnSize, InsetLevel, Weight)
        case divider(DivLine, DivMotif, DivCap)
        case badge(BadgeShape, BadgeRing, Bool)
        case banner(BannerStyle, BannerEnd, Bool)
    }

    enum LineFamily: String, CaseIterable {
        case single, double, triple
        case thickThin = "thick-thin"
        case thinThickThin = "thin-thick-thin"
        case dashed, dotted
        case dashDot = "dash-dot"
        case bead
        case diamondChain = "diamond-chain"
        case squareChain = "square-chain"
        case stitched
        case doubleDots = "double-dots"
        case rope, zigzag, wave, scallop, meander, chevron, checker
        case filmStrip = "film-strip"
        case perforation
        case goldFrame = "gilded"

        var label: String {
            switch self {
            case .single: return "Single Line"
            case .double: return "Double Line"
            case .triple: return "Triple Line"
            case .thickThin: return "Thick & Thin"
            case .thinThickThin: return "Thin-Thick-Thin"
            case .dashed: return "Dashed"
            case .dotted: return "Dotted"
            case .dashDot: return "Dash-Dot"
            case .bead: return "Bead Chain"
            case .diamondChain: return "Diamond Chain"
            case .squareChain: return "Square Chain"
            case .stitched: return "Stitched"
            case .doubleDots: return "Double Line with Dots"
            case .rope: return "Rope Twist"
            case .zigzag: return "Zigzag"
            case .wave: return "Wave"
            case .scallop: return "Scallop"
            case .meander: return "Greek Key"
            case .chevron: return "Chevron Band"
            case .checker: return "Checker Band"
            case .filmStrip: return "Film Strip"
            case .perforation: return "Postage Perforation"
            case .goldFrame: return "Gilded Frame"
            }
        }

        var category: String {
            switch self {
            case .single, .double, .triple, .thickThin, .thinThickThin: return "Classic Lines"
            case .dashed, .dotted, .dashDot, .stitched: return "Dashes & Dots"
            case .bead, .diamondChain, .squareChain, .doubleDots, .rope: return "Chains & Cords"
            case .zigzag, .wave, .scallop: return "Waves & Scallops"
            case .meander, .chevron, .checker: return "Patterned Bands"
            case .filmStrip, .perforation: return "Film & Stamp"
            case .goldFrame: return "Gilded"
            }
        }

        var tags: [String] {
            switch self {
            case .single: return ["single", "thin", "line", "rule", "minimal", "classic"]
            case .double: return ["double", "line", "classic", "elegant"]
            case .triple: return ["triple", "line", "classic", "formal"]
            case .thickThin: return ["thick", "thin", "double", "line", "classic"]
            case .thinThickThin: return ["thick", "thin", "triple", "line", "formal"]
            case .dashed: return ["dashed", "dashes", "line", "playful"]
            case .dotted: return ["dotted", "dots", "line", "playful"]
            case .dashDot: return ["dash", "dot", "dotted", "dashed", "line"]
            case .bead: return ["bead", "beads", "pearls", "chain", "dots"]
            case .diamondChain: return ["diamond", "chain", "jewel"]
            case .squareChain: return ["square", "chain", "links", "geometric"]
            case .stitched: return ["stitched", "stitch", "sewing", "craft", "cozy"]
            case .doubleDots: return ["double", "dots", "dotted", "line"]
            case .rope: return ["rope", "twist", "cord", "nautical"]
            case .zigzag: return ["zigzag", "zig", "playful", "geometric"]
            case .wave: return ["wave", "wavy", "ocean", "water"]
            case .scallop: return ["scallop", "scalloped", "lace", "cute"]
            case .meander: return ["greek", "key", "meander", "classical", "antique"]
            case .chevron: return ["chevron", "arrows", "geometric"]
            case .checker: return ["checker", "checkered", "check", "geometric"]
            case .filmStrip: return ["film", "strip", "cinema", "movie", "sprocket", "photo"]
            case .perforation: return ["stamp", "postage", "perforated", "perforation", "mail"]
            case .goldFrame: return ["gold", "gilded", "gilt", "frame", "bevel", "luxury", "ornate"]
            }
        }
    }

    enum CornerFamily: String, CaseIterable {
        case decoSteps = "deco-steps"
        case decoFan = "deco-fan"
        case nouveau = "nouveau-curl"
        case filigree
        case victorian = "victorian-bracket"
        case viewfinder
        case cornerDots = "corner-dots"
        case torn = "torn-paper"
        case brush = "rough-brush"
        case grunge

        var label: String {
            switch self {
            case .decoSteps: return "Art Deco Steps"
            case .decoFan: return "Art Deco Fans"
            case .nouveau: return "Art Nouveau Curls"
            case .filigree: return "Filigree Spirals"
            case .victorian: return "Victorian Brackets"
            case .viewfinder: return "Viewfinder Brackets"
            case .cornerDots: return "Corner Dots"
            case .torn: return "Torn Paper Edge"
            case .brush: return "Rough Brush Edge"
            case .grunge: return "Grunge Edge"
            }
        }

        var category: String {
            switch self {
            case .decoSteps, .decoFan: return "Art Deco"
            case .nouveau, .filigree: return "Art Nouveau & Filigree"
            case .victorian: return "Victorian"
            case .viewfinder, .cornerDots: return "Modern"
            case .torn, .brush, .grunge: return "Rough Edges"
            }
        }

        var tags: [String] {
            switch self {
            case .decoSteps: return ["deco", "art deco", "steps", "stepped", "gatsby", "1920s", "geometric"]
            case .decoFan: return ["deco", "art deco", "fan", "sunburst", "gatsby", "1920s"]
            case .nouveau: return ["nouveau", "curl", "curls", "flourish", "organic", "whiplash", "romantic"]
            case .filigree: return ["filigree", "spiral", "curl", "ornate", "lace", "fantasy"]
            case .victorian: return ["victorian", "bracket", "brackets", "ornate", "antique", "ticket"]
            case .viewfinder: return ["viewfinder", "camera", "brackets", "bracket", "crop", "tech", "modern"]
            case .cornerDots: return ["dots", "corner", "minimal", "modern"]
            case .torn: return ["torn", "paper", "ripped", "rough", "edge", "collage"]
            case .brush: return ["brush", "paint", "rough", "hand", "drawn", "edge", "ink"]
            case .grunge: return ["grunge", "distressed", "rough", "dirty", "edge", "horror", "punk"]
            }
        }
    }

    enum CornerStyle: String, CaseIterable {
        case square, rounded, chamfered, notched, ticket

        var label: String {
            switch self {
            case .square: return "Square"
            case .rounded: return "Rounded"
            case .chamfered: return "Chamfered"
            case .notched: return "Notched"
            case .ticket: return "Ticket"
            }
        }
    }

    enum Weight: String, CaseIterable {
        case fine, regular, heavy

        var label: String {
            switch self {
            case .fine: return "Fine"
            case .regular: return "Regular"
            case .heavy: return "Heavy"
            }
        }

        var alias: String {
            switch self {
            case .fine: return "hairline"
            case .regular: return "medium"
            case .heavy: return "bold"
            }
        }

        /// Line weight as a fraction of the cover height.
        var borderFrac: CGFloat {
            switch self {
            case .fine: return 0.0022
            case .regular: return 0.0040
            case .heavy: return 0.0068
            }
        }

        var cornerFrac: CGFloat {
            switch self {
            case .fine: return 0.0018
            case .regular: return 0.0028
            case .heavy: return 0.0050
            }
        }
    }

    enum InsetLevel: String, CaseIterable {
        case edge, inset, deep

        var label: String {
            switch self {
            case .edge: return "Edge"
            case .inset: return "Inset"
            case .deep: return "Deep"
            }
        }

        /// Distance from the raster edge as a fraction of the cover height.
        var borderFrac: CGFloat {
            switch self {
            case .edge: return 0.016
            case .inset: return 0.034
            case .deep: return 0.060
            }
        }

        var cornerFrac: CGFloat {
            switch self {
            case .edge: return 0.022
            case .inset: return 0.045
            case .deep: return 0.070
            }
        }
    }

    enum Tone: String, CaseIterable {
        case light, accent, gold

        var label: String {
            switch self {
            case .light: return "Light"
            case .accent: return "Accent"
            case .gold: return "Gold"
            }
        }

        var role: DecorLibrary.ColorRole {
            switch self {
            case .light: return .light
            case .accent: return .accent
            case .gold: return .gold
            }
        }
    }

    enum CornerOrn: String, CaseIterable {
        case flourish, fan, steps, spiral, viewfinder, victorian, dots, sprig, photo
        case doubleL = "double-l"
        case star, scroll

        var label: String {
            switch self {
            case .flourish: return "Nouveau Flourish"
            case .fan: return "Deco Fan"
            case .steps: return "Deco Steps"
            case .spiral: return "Filigree Spiral"
            case .viewfinder: return "Viewfinder"
            case .victorian: return "Victorian Bracket"
            case .dots: return "Dot Cluster"
            case .sprig: return "Leaf Sprig"
            case .photo: return "Photo Mount"
            case .doubleL: return "Double Bracket"
            case .star: return "Star"
            case .scroll: return "Baroque Scroll"
            }
        }

        var tags: [String] {
            switch self {
            case .flourish: return ["nouveau", "flourish", "curl", "organic", "romantic"]
            case .fan: return ["deco", "art deco", "fan", "sunburst", "gatsby"]
            case .steps: return ["deco", "art deco", "steps", "geometric"]
            case .spiral: return ["filigree", "spiral", "curl", "ornate", "fantasy"]
            case .viewfinder: return ["viewfinder", "camera", "brackets", "crop", "modern", "tech"]
            case .victorian: return ["victorian", "bracket", "brackets", "ornate", "antique"]
            case .dots: return ["dots", "minimal", "modern"]
            case .sprig: return ["leaf", "leaves", "botanical", "floral", "nature", "sprig"]
            case .photo: return ["photo", "mount", "scrapbook", "triangle", "vintage"]
            case .doubleL: return ["bracket", "brackets", "double", "lines", "minimal"]
            case .star: return ["star", "celestial", "sparkle"]
            case .scroll: return ["baroque", "scroll", "ornate", "flourish", "classical"]
            }
        }
    }

    enum OrnSize: String, CaseIterable {
        case small, medium, large

        var label: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            }
        }

        /// Ornament unit as a fraction of the cover height.
        var frac: CGFloat {
            switch self {
            case .small: return 0.0085
            case .medium: return 0.0125
            case .large: return 0.018
            }
        }
    }

    enum DivLine: String, CaseIterable {
        case single, double, dotted, fading, tapered

        var label: String {
            switch self {
            case .single: return "Single"
            case .double: return "Double"
            case .dotted: return "Dotted"
            case .fading: return "Fading"
            case .tapered: return "Tapered"
            }
        }
    }

    enum DivMotif: String, CaseIterable {
        case none, diamond, dot
        case threeDots = "three-dots"
        case star, asterism, fleuron, circle, leaf, chevron

        var label: String {
            switch self {
            case .none: return "Plain"
            case .diamond: return "Diamond"
            case .dot: return "Dot"
            case .threeDots: return "Three Dots"
            case .star: return "Star"
            case .asterism: return "Asterism"
            case .fleuron: return "Fleuron Scroll"
            case .circle: return "Circle"
            case .leaf: return "Leaves"
            case .chevron: return "Chevrons"
            }
        }

        var tags: [String] {
            switch self {
            case .none: return ["plain", "simple", "minimal"]
            case .diamond: return ["diamond", "jewel"]
            case .dot: return ["dot", "point"]
            case .threeDots: return ["dots", "ellipsis"]
            case .star: return ["star", "celestial"]
            case .asterism: return ["asterism", "asterisk", "stars", "section", "break"]
            case .fleuron: return ["fleuron", "scroll", "flourish", "ornate", "curl"]
            case .circle: return ["circle", "ring"]
            case .leaf: return ["leaf", "leaves", "botanical", "floral"]
            case .chevron: return ["chevron", "arrows"]
            }
        }
    }

    enum DivCap: String, CaseIterable {
        case none, dots, diamonds, curls

        var label: String {
            switch self {
            case .none: return "Plain Ends"
            case .dots: return "Dot Ends"
            case .diamonds: return "Diamond Ends"
            case .curls: return "Curled Ends"
            }
        }
    }

    enum BadgeShape: String, CaseIterable {
        case circle
        case star12 = "starburst-12"
        case star16 = "starburst-16"
        case star24 = "starburst-24"
        case scalloped, shield, hexagon, rosette

        var label: String {
            switch self {
            case .circle: return "Circle Seal"
            case .star12: return "Starburst 12"
            case .star16: return "Starburst 16"
            case .star24: return "Starburst 24"
            case .scalloped: return "Scalloped Seal"
            case .shield: return "Shield"
            case .hexagon: return "Hexagon"
            case .rosette: return "Rosette"
            }
        }

        var tags: [String] {
            switch self {
            case .circle: return ["circle", "round", "medallion"]
            case .star12, .star16, .star24: return ["starburst", "burst", "star", "sticker"]
            case .scalloped: return ["scalloped", "scallop", "wavy", "rosette"]
            case .shield: return ["shield", "crest", "heraldic"]
            case .hexagon: return ["hexagon", "hex", "geometric"]
            case .rosette: return ["rosette", "ribbon", "medal"]
            }
        }
    }

    enum BadgeRing: String, CaseIterable {
        case single, double, dotted, beaded

        var label: String {
            switch self {
            case .single: return "Single Ring"
            case .double: return "Double Ring"
            case .dotted: return "Dotted Ring"
            case .beaded: return "Beaded Ring"
            }
        }
    }

    enum BannerStyle: String, CaseIterable {
        case forked = "forked-ribbon"
        case straight = "band"
        case curved = "curved-ribbon"
        case tab = "tab-label"
        case bracket = "bracket-label"

        var label: String {
            switch self {
            case .forked: return "Forked Ribbon"
            case .straight: return "Straight Band"
            case .curved: return "Curved Ribbon"
            case .tab: return "Tab Label"
            case .bracket: return "Bracket Label"
            }
        }

        var tags: [String] {
            switch self {
            case .forked: return ["forked", "ribbon", "tails", "classic"]
            case .straight: return ["straight", "band", "strip", "bar"]
            case .curved: return ["curved", "arched", "arc", "ribbon"]
            case .tab: return ["tab", "label", "tag", "pill"]
            case .bracket: return ["bracket", "brackets", "label", "ornate"]
            }
        }
    }

    enum BannerEnd: String, CaseIterable {
        case flat, point, notch, round, concave

        var label: String {
            switch self {
            case .flat: return "Flat Ends"
            case .point: return "Pointed Ends"
            case .notch: return "Notched Ends"
            case .round: return "Rounded Ends"
            case .concave: return "Concave Ends"
            }
        }
    }

    // MARK: Fonts

    static let serifFont: String = FontCatalog.resolve(["Cinzel-Bold", "PlayfairDisplay-Bold", "Times-Bold"])
    static let condensedFont: String = FontCatalog.resolve(["Oswald-Bold", "BebasNeue-Regular", "Montserrat-Black"])
    static let displayFont: String = FontCatalog.resolve(["PlayfairDisplay-Bold", "Cinzel-Bold", "Times-Bold"])

    static func stableSeed(_ s: String) -> Int {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 {
            h ^= UInt64(b)
            h = h &* 1099511628211
        }
        return Int(truncatingIfNeeded: h & 0x7FFF_FFFF)
    }

    // MARK: Vector helpers

    static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
    static func add(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func sub(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func mul(_ a: CGPoint, _ s: CGFloat) -> CGPoint { CGPoint(x: a.x * s, y: a.y * s) }
    static func len(_ a: CGPoint) -> CGFloat { (a.x * a.x + a.y * a.y).squareRoot() }

    static func unit(_ a: CGPoint) -> CGPoint {
        let l = len(a)
        if l < 1e-9 { return CGPoint(x: 1, y: 0) }
        return CGPoint(x: a.x / l, y: a.y / l)
    }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    /// Inward normal for clockwise travel in a top-left space.
    static func perp(_ t: CGPoint) -> CGPoint { CGPoint(x: -t.y, y: t.x) }

    /// o + u * a + v * b
    static func at(_ o: CGPoint, _ u: CGPoint, _ a: CGFloat, _ v: CGPoint, _ b: CGFloat) -> CGPoint {
        let x: CGFloat = o.x + u.x * a + v.x * b
        let y: CGFloat = o.y + u.y * a + v.y * b
        return CGPoint(x: x, y: y)
    }

    static func rotate(_ v: CGPoint, _ a: CGFloat) -> CGPoint {
        let c = cos(a)
        let s = sin(a)
        let x: CGFloat = v.x * c - v.y * s
        let y: CGFloat = v.x * s + v.y * c
        return CGPoint(x: x, y: y)
    }

    static func quadPt(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let u: CGFloat = 1 - t
        let w0: CGFloat = u * u
        let w1: CGFloat = 2 * u * t
        let w2: CGFloat = t * t
        let x: CGFloat = a.x * w0 + c.x * w1 + b.x * w2
        let y: CGFloat = a.y * w0 + c.y * w1 + b.y * w2
        return CGPoint(x: x, y: y)
    }

    static func circleRect(_ c: CGPoint, _ r: CGFloat) -> CGRect {
        CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
    }

    // MARK: Point lists

    static func arcPts(_ c: CGPoint, _ r: CGFloat, _ a0: CGFloat, _ a1: CGFloat, _ steps: Int) -> [CGPoint] {
        var out: [CGPoint] = []
        let n = max(2, steps)
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let a: CGFloat = a0 + (a1 - a0) * t
            out.append(CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
        }
        return out
    }

    static func circlePts(_ c: CGPoint, _ r: CGFloat, _ n: Int) -> [CGPoint] {
        var out: [CGPoint] = []
        for i in 0..<n {
            let a: CGFloat = 2 * CGFloat.pi * CGFloat(i) / CGFloat(n)
            out.append(CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
        }
        return out
    }

    static func starPts(_ c: CGPoint, _ r1: CGFloat, _ r2: CGFloat, _ n: Int, _ rot: CGFloat) -> [CGPoint] {
        var out: [CGPoint] = []
        for i in 0..<(2 * n) {
            let a: CGFloat = rot + CGFloat.pi * CGFloat(i) / CGFloat(n)
            let r: CGFloat = i % 2 == 0 ? r1 : r2
            out.append(CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
        }
        return out
    }

    /// r(θ) = base + amp * |sin(lobes θ / 2)|: a ring of `lobes` outward bumps.
    static func lobed(_ c: CGPoint, _ base: CGFloat, _ amp: CGFloat, _ lobes: Int, _ samples: Int) -> [CGPoint] {
        var out: [CGPoint] = []
        let half: CGFloat = CGFloat(lobes) / 2
        for i in 0..<samples {
            let a: CGFloat = 2 * CGFloat.pi * CGFloat(i) / CGFloat(samples)
            let r: CGFloat = base + amp * abs(sin(half * a))
            out.append(CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
        }
        return out
    }

    /// Archimedean spiral. `increasing` turns clockwise on screen (top-left space).
    static func spiralPts(_ c: CGPoint, _ r0: CGFloat, _ r1: CGFloat, _ a0: CGFloat, _ turns: CGFloat, _ increasing: Bool) -> [CGPoint] {
        var out: [CGPoint] = []
        let steps = max(16, Int(turns * 56))
        let dir: CGFloat = increasing ? 1 : -1
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let a: CGFloat = a0 + dir * t * turns * 2 * CGFloat.pi
            let r: CGFloat = r0 + (r1 - r0) * t
            out.append(CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
        }
        return out
    }

    static func scaled(_ pts: [CGPoint], _ c: CGPoint, _ s: CGFloat) -> [CGPoint] {
        var out: [CGPoint] = []
        out.reserveCapacity(pts.count)
        for q in pts { out.append(CGPoint(x: c.x + (q.x - c.x) * s, y: c.y + (q.y - c.y) * s)) }
        return out
    }

    /// Evenly spaced points around a closed polyline, the count fitted to `spacing`.
    static func evenly(_ pts: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard let first = pts.first else { return [] }
        var closed = pts
        closed.append(first)
        let sm = Sampler(closed)
        guard sm.total > 0, spacing > 0 else { return [] }
        let n = max(3, Int((sm.total / spacing).rounded()))
        var out: [CGPoint] = []
        for i in 0..<n {
            let s: CGFloat = sm.total * CGFloat(i) / CGFloat(n)
            out.append(sm.at(s).0)
        }
        return out
    }

    // MARK: Paths and paint

    static func polyPath(_ pts: [CGPoint], closed: Bool) -> CGMutablePath {
        let path = CGMutablePath()
        guard let first = pts.first else { return path }
        path.move(to: first)
        if pts.count > 1 {
            for i in 1..<pts.count { path.addLine(to: pts[i]) }
        }
        if closed { path.closeSubpath() }
        return path
    }

    static func fill(_ ctx: CGContext, _ path: CGPath, _ c: RGBA, evenOdd: Bool = false) {
        ctx.setFillColor(c.cgColor)
        ctx.addPath(path)
        if evenOdd { ctx.fillPath(using: .evenOdd) } else { ctx.fillPath() }
    }

    static func stroke(_ ctx: CGContext, _ path: CGPath, _ c: RGBA, _ w: CGFloat) {
        ctx.setStrokeColor(c.cgColor)
        ctx.setLineWidth(max(0.5, w))
        ctx.addPath(path)
        ctx.strokePath()
    }

    static func erase(_ ctx: CGContext, _ path: CGPath, evenOdd: Bool = false) {
        ctx.saveGState()
        ctx.setBlendMode(.destinationOut)
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.addPath(path)
        if evenOdd { ctx.fillPath(using: .evenOdd) } else { ctx.fillPath() }
        ctx.restoreGState()
    }

    static func eraseStroke(_ ctx: CGContext, _ path: CGPath, _ w: CGFloat) {
        ctx.saveGState()
        ctx.setBlendMode(.destinationOut)
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setLineWidth(max(0.5, w))
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// Fills in `c`, or knocks the shape out of what is already drawn when `c` is nil.
    static func paintFill(_ ctx: CGContext, _ path: CGPath, _ c: RGBA?, evenOdd: Bool = false) {
        if let c { fill(ctx, path, c, evenOdd: evenOdd) } else { erase(ctx, path, evenOdd: evenOdd) }
    }

    static func paintStroke(_ ctx: CGContext, _ path: CGPath, _ c: RGBA?, _ w: CGFloat) {
        if let c { stroke(ctx, path, c, w) } else { eraseStroke(ctx, path, w) }
    }

    // MARK: Arc-length sampling

    struct Sampler {
        let pts: [CGPoint]
        let cum: [CGFloat]
        let total: CGFloat

        init(_ p: [CGPoint]) {
            pts = p
            var c: [CGFloat] = [0]
            var acc: CGFloat = 0
            if p.count > 1 {
                for i in 1..<p.count {
                    acc += DD.len(DD.sub(p[i], p[i - 1]))
                    c.append(acc)
                }
            }
            cum = c
            total = acc
        }

        /// Position and unit tangent at arc length `s`.
        func at(_ s: CGFloat) -> (CGPoint, CGPoint) {
            guard pts.count > 1 else { return (pts.first ?? .zero, CGPoint(x: 1, y: 0)) }
            let target = min(max(s, 0), total)
            var lo = 0
            var hi = pts.count - 1
            while hi - lo > 1 {
                let mid = (lo + hi) / 2
                if cum[mid] <= target { lo = mid } else { hi = mid }
            }
            let seg = lo
            var j = seg
            while j < pts.count - 2 && cum[j + 1] - cum[j] < 1e-6 { j += 1 }
            if cum[j + 1] - cum[j] < 1e-6 {
                j = seg
                while j > 0 && cum[j + 1] - cum[j] < 1e-6 { j -= 1 }
            }
            let segLen = cum[seg + 1] - cum[seg]
            let t: CGFloat = segLen > 1e-6 ? (target - cum[seg]) / segLen : 0
            let pos = DD.lerp(pts[seg], pts[seg + 1], t)
            let tan = DD.unit(DD.sub(pts[j + 1], pts[j]))
            return (pos, tan)
        }
    }

    struct Mark {
        let pos: CGPoint
        let tan: CGPoint
        var nrm: CGPoint { DD.perp(tan) }
    }

    // MARK: Frame loops

    /// A closed outline around a frame, clockwise from the top-left corner. Each corner contributes a run
    /// of points (`firsts`...`lasts`) whose middle (`mids`) is where corner motifs are anchored.
    struct Loop {
        var pts: [CGPoint] = []
        var mids: [Int] = []
        var firsts: [Int] = []
        var lasts: [Int] = []
        var tangents: [CGPoint] = []
    }

    static func cornerFrame(_ R: CGRect, _ k: Int) -> (c: CGPoint, inD: CGPoint, outD: CGPoint) {
        switch k {
        case 0: return (p(R.minX, R.minY), p(0, 1), p(1, 0))
        case 1: return (p(R.maxX, R.minY), p(-1, 0), p(0, 1))
        case 2: return (p(R.maxX, R.maxY), p(0, -1), p(-1, 0))
        default: return (p(R.minX, R.maxY), p(1, 0), p(0, -1))
        }
    }

    static func arcSteps(_ r: CGFloat, _ span: CGFloat) -> Int {
        var n = Int((r * span / 2.0).rounded(.up))
        n = min(240, max(8, n))
        if n % 2 == 1 { n += 1 }
        return n
    }

    /// The outline of `R` with corner treatment `style` (size `r` at offset 0), offset inward by `d`.
    /// Offsets are exact: rounded corners shrink about the same centre, ticket corners grow about the
    /// frame corner, chamfers stay parallel.
    static func loop(_ R: CGRect, _ style: CornerStyle, _ r: CGFloat, _ d: CGFloat) -> Loop {
        var out = Loop()
        for k in 0..<4 {
            let f = cornerFrame(R, k)
            var local: [CGPoint] = []
            var mid = 0
            switch style {
            case .square:
                local.append(p(d, d))
            case .rounded:
                let rr: CGFloat = r - d
                if rr < 0.5 {
                    local.append(p(d, d))
                } else {
                    let n = arcSteps(rr, CGFloat.pi / 2)
                    for i in 0...n {
                        let th: CGFloat = CGFloat(i) / CGFloat(n) * (CGFloat.pi / 2)
                        local.append(p(r - rr * sin(th), r - rr * cos(th)))
                    }
                    mid = n / 2
                }
            case .chamfered:
                let cc: CGFloat = r - 0.5858 * d
                if cc < 0.5 {
                    local.append(p(d, d))
                } else {
                    local.append(p(d + cc, d))
                    local.append(p(d + cc / 2, d + cc / 2))
                    local.append(p(d, d + cc))
                    mid = 1
                }
            case .notched:
                local.append(p(d + r, d))
                local.append(p(d + r, d + r))
                local.append(p(d, d + r))
                mid = 1
            case .ticket:
                let r2: CGFloat = r + d
                let th0: CGFloat = asin(min(0.95, d / max(r2, 0.001)))
                let span: CGFloat = CGFloat.pi / 2 - 2 * th0
                let n = arcSteps(r2, span)
                for i in 0...n {
                    let th: CGFloat = th0 + span * CGFloat(i) / CGFloat(n)
                    local.append(p(r2 * cos(th), r2 * sin(th)))
                }
                mid = n / 2
            }
            out.firsts.append(out.pts.count)
            out.mids.append(out.pts.count + mid)
            for q in local { out.pts.append(at(f.c, f.inD, q.x, f.outD, q.y)) }
            out.lasts.append(out.pts.count - 1)
            out.tangents.append(unit(sub(f.outD, f.inD)))
        }
        return out
    }

    /// A solid band between inward offsets `a` and `b`, with exact corners.
    static func ring(_ ctx: CGContext, _ R: CGRect, _ style: CornerStyle, _ r: CGFloat, _ a: CGFloat, _ b: CGFloat, _ col: RGBA?) {
        let path = CGMutablePath()
        path.addPath(polyPath(loop(R, style, r, a).pts, closed: true))
        path.addPath(polyPath(loop(R, style, r, b).pts, closed: true))
        paintFill(ctx, path, col, evenOdd: true)
    }

    /// The loop split into four runs, each from one corner's midpoint to the next.
    static func quarters(_ L: Loop) -> [[CGPoint]] {
        var res: [[CGPoint]] = []
        let n = L.pts.count
        guard n > 0, L.mids.count == 4 else { return res }
        for k in 0..<4 {
            let s = L.mids[k]
            var e = L.mids[(k + 1) % 4]
            if e <= s { e += n }
            var q: [CGPoint] = []
            var i = s
            while i <= e {
                q.append(L.pts[i % n])
                i += 1
            }
            res.append(q)
        }
        return res
    }

    /// Motif anchors: per quarter a whole number of equal steps, so a motif sits on every corner.
    static func motifs(_ L: Loop, _ spacing: CGFloat) -> [Mark] {
        var res: [Mark] = []
        let qs = quarters(L)
        for k in 0..<qs.count {
            let q = qs[k]
            let sm = Sampler(q)
            let n = max(1, Int((sm.total / max(spacing, 0.5)).rounded()))
            for i in 0..<n {
                if i == 0 {
                    res.append(Mark(pos: q[0], tan: L.tangents[k]))
                } else {
                    let s: CGFloat = sm.total * CGFloat(i) / CGFloat(n)
                    let v = sm.at(s)
                    res.append(Mark(pos: v.0, tan: v.1))
                }
            }
        }
        return res
    }

    /// Strokes each quarter with a dash pattern stretched to a whole number of repeats, so dashes meet
    /// symmetrically in every corner.
    static func dashQuarters(_ ctx: CGContext, _ L: Loop, _ pattern: [CGFloat], phase: CGFloat, width: CGFloat, color: RGBA) {
        var period: CGFloat = 0
        for v in pattern { period += v }
        guard period > 0 else { return }
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(max(0.5, width))
        ctx.setLineCap(.round)
        for q in quarters(L) {
            let sm = Sampler(q)
            guard sm.total > 0 else { continue }
            let n = max(1, Int((sm.total / period).rounded()))
            let scale: CGFloat = sm.total / (CGFloat(n) * period)
            var pat: [CGFloat] = []
            for v in pattern { pat.append(v * scale) }
            ctx.setLineDash(phase: phase * scale, lengths: pat)
            ctx.addPath(polyPath(q, closed: false))
            ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: [])
    }

    /// A periodic curve riding on the loop. `f(u)` (u in periods) returns the inward offset.
    static func offsetCurve(_ L: Loop, period: CGFloat, spp: Int, halfInteger: Bool, cornerScale: CGFloat,
                            _ f: (CGFloat) -> CGFloat) -> CGMutablePath {
        let path = CGMutablePath()
        let qs = quarters(L)
        var started = false
        for k in 0..<qs.count {
            let sm = Sampler(qs[k])
            let total = sm.total
            guard total > 0 else { continue }
            let cycles: CGFloat
            if halfInteger {
                let n = max(0, Int((total / period - 0.5).rounded()))
                cycles = CGFloat(n) + 0.5
            } else {
                cycles = CGFloat(max(1, Int((total / period).rounded())))
            }
            let m = max(2, Int((cycles * CGFloat(spp)).rounded()))
            for j in 0...m {
                if started && j == 0 { continue }
                let s: CGFloat = total * CGFloat(j) / CGFloat(m)
                let v = sm.at(s)
                var tan = v.1
                var scale: CGFloat = 1
                if j == 0 {
                    tan = L.tangents[k]
                    scale = cornerScale
                } else if j == m {
                    tan = L.tangents[(k + 1) % 4]
                    scale = cornerScale
                }
                let u: CGFloat = cycles * CGFloat(j) / CGFloat(m)
                let off: CGFloat = f(u) * scale
                let pt = add(v.0, mul(perp(tan), off))
                if !started {
                    path.move(to: pt)
                    started = true
                } else {
                    path.addLine(to: pt)
                }
            }
        }
        if started { path.closeSubpath() }
        return path
    }

    /// The straight run of each side between corners.
    static func edges(_ L: Loop) -> [(CGPoint, CGPoint)] {
        var out: [(CGPoint, CGPoint)] = []
        guard L.lasts.count == 4, L.firsts.count == 4 else { return out }
        for k in 0..<4 {
            out.append((L.pts[L.lasts[k]], L.pts[L.firsts[(k + 1) % 4]]))
        }
        return out
    }

    // MARK: Borders

    static func drawBorder(_ ctx: CGContext, _ fam: LineFamily, _ style: CornerStyle, bounds: CGRect, H: CGFloat,
                           weight: CGFloat, inset: CGFloat, c1: RGBA, c2: RGBA) {
        let lw: CGFloat = max(0.75, weight * H)
        let ins: CGFloat = inset * H
        let R = bounds.insetBy(dx: ins, dy: ins)
        guard R.width > lw * 24, R.height > lw * 24 else { return }
        let r: CGFloat = max(0.028 * H, lw * 10)
        let cs: CGFloat = (style == .square || style == .notched) ? 1.4142 : 1
        let thin: CGFloat = max(0.6, lw * 0.32)
        let gap: CGFloat = max(lw * 2.2, 1.5)

        func band(_ a: CGFloat, _ b: CGFloat, _ col: RGBA) { ring(ctx, R, style, r, a, b, col) }
        func lp(_ d: CGFloat) -> Loop { loop(R, style, r, d) }

        switch fam {
        case .single:
            band(0, lw, c1)
        case .double:
            band(0, lw, c1)
            band(lw + gap, lw * 2 + gap, c2)
        case .triple:
            let g: CGFloat = max(lw * 1.6, 1.5)
            band(0, lw, c1)
            band(lw + g, lw * 2 + g, c2)
            band(lw * 2 + g * 2, lw * 3 + g * 2, c1)
        case .thickThin:
            let thick: CGFloat = lw * 2.6
            let t2: CGFloat = max(lw * 0.5, 0.75)
            let g: CGFloat = max(lw * 1.4, 1.5)
            band(0, thick, c1)
            band(thick + g, thick + g + t2, c2)
        case .thinThickThin:
            let t1: CGFloat = max(lw * 0.5, 0.75)
            let thick: CGFloat = lw * 2.4
            let g: CGFloat = max(lw * 1.3, 1.5)
            band(0, t1, c2)
            band(t1 + g, t1 + g + thick, c1)
            band(t1 + g * 2 + thick, t1 * 2 + g * 2 + thick, c2)
        case .dashed:
            dashQuarters(ctx, lp(lw * 0.5), [lw * 2.4, lw * 2.6], phase: lw * 1.2, width: lw, color: c1)
        case .dotted:
            let dia: CGFloat = lw * 1.3
            dashQuarters(ctx, lp(dia * 0.5), [0, lw * 2.6], phase: 0, width: dia, color: c1)
        case .dashDot:
            dashQuarters(ctx, lp(lw * 0.5), [lw * 2.6, lw * 1.9, 0, lw * 1.9], phase: lw * 1.3, width: lw, color: c1)
        case .stitched:
            band(0, thin, c2)
            dashQuarters(ctx, lp(lw * 2.0), [lw * 1.8, lw * 1.7], phase: lw * 0.9, width: lw * 0.8, color: c1)
        case .bead:
            let rb: CGFloat = lw * 1.1
            let l = lp(rb)
            stroke(ctx, polyPath(l.pts, closed: true), c2, max(0.6, lw * 0.3))
            let path = CGMutablePath()
            for m in motifs(l, lw * 3.4) { path.addEllipse(in: circleRect(m.pos, rb)) }
            fill(ctx, path, c1)
        case .diamondChain:
            let l = lp(lw * 1.35)
            stroke(ctx, polyPath(l.pts, closed: true), c2, max(0.6, lw * 0.3))
            let path = CGMutablePath()
            let hl: CGFloat = lw * 1.55
            let hw: CGFloat = lw * 1.25
            for m in motifs(l, lw * 3.7) {
                let n = m.nrm
                var q: [CGPoint] = []
                q.append(at(m.pos, m.tan, hl, n, 0))
                q.append(at(m.pos, m.tan, 0, n, hw))
                q.append(at(m.pos, m.tan, -hl, n, 0))
                q.append(at(m.pos, m.tan, 0, n, -hw))
                path.addPath(polyPath(q, closed: true))
            }
            fill(ctx, path, c1)
        case .squareChain:
            let h: CGFloat = lw * 1.1
            let l = lp(h + lw * 0.3)
            let path = CGMutablePath()
            for m in motifs(l, lw * 3.1) {
                let n = m.nrm
                var q: [CGPoint] = []
                q.append(at(m.pos, m.tan, -h, n, -h))
                q.append(at(m.pos, m.tan, h, n, -h))
                q.append(at(m.pos, m.tan, h, n, h))
                q.append(at(m.pos, m.tan, -h, n, h))
                path.addPath(polyPath(q, closed: true))
            }
            stroke(ctx, path, c1, lw * 0.55)
        case .doubleDots:
            let g: CGFloat = lw * 3.2
            band(0, lw, c1)
            band(lw + g, lw * 2 + g, c1)
            let l = lp(lw + g / 2)
            let rd: CGFloat = lw * 0.65
            let path = CGMutablePath()
            for m in motifs(l, lw * 2.8) { path.addEllipse(in: circleRect(m.pos, rd)) }
            fill(ctx, path, c2)
        case .rope:
            let B: CGFloat = lw * 3.5
            band(0, thin, c2)
            band(B - thin, B, c2)
            let l = lp(B / 2)
            let half: CGFloat = B / 2 - thin - lw * 0.55
            let path = CGMutablePath()
            for m in motifs(l, lw * 1.5) {
                let n = m.nrm
                path.move(to: at(m.pos, m.tan, -lw * 0.8, n, -half))
                path.addLine(to: at(m.pos, m.tan, lw * 0.8, n, half))
            }
            ctx.setLineCap(.round)
            stroke(ctx, path, c1, lw * 0.95)
        case .zigzag:
            let A: CGFloat = lw * 2.2
            let l = lp(A / 2 + lw / 2)
            let path = offsetCurve(l, period: lw * 2.8, spp: 2, halfInteger: false, cornerScale: cs) { u in
                let fr: CGFloat = u - floor(u + 0.0001)
                let tri: CGFloat = 1 - abs(2 * fr - 1)
                return A * (0.5 - tri)
            }
            stroke(ctx, path, c1, lw)
        case .wave:
            let A: CGFloat = lw * 1.5
            let l = lp(A + lw / 2)
            let path = offsetCurve(l, period: lw * 5, spp: 24, halfInteger: true, cornerScale: 1) { u in
                A * sin(2 * CGFloat.pi * u)
            }
            stroke(ctx, path, c1, lw)
        case .scallop:
            let A: CGFloat = lw * 1.7
            let l = lp(A + lw / 2)
            let path = offsetCurve(l, period: lw * 4.4, spp: 24, halfInteger: false, cornerScale: 1) { u in
                let fr: CGFloat = u - floor(u + 0.0001)
                let x: CGFloat = 2 * fr - 1
                return -A * max(0, 1 - x * x).squareRoot()
            }
            stroke(ctx, path, c1, lw)
            let inner: CGFloat = A + lw / 2 + lw * 1.5
            band(inner, inner + thin, c2)
        case .meander, .chevron:
            let B: CGFloat = lw * 7
            let lr: CGFloat = max(0.75, B * 0.075)
            band(0, lr, c1)
            band(B - lr, B, c1)
            let l = lp(B / 2)
            let uv: CGFloat = (B - lr) / 6
            let path = CGMutablePath()
            for e in edges(l) {
                let a = e.0
                let t = unit(sub(e.1, a))
                let n = perp(t)
                let elen = len(sub(e.1, a))
                let margin: CGFloat = (style == .square ? B / 2 : 0) + uv * 1.4
                let avail: CGFloat = elen - 2 * margin
                if fam == .meander {
                    let tile: CGFloat = uv * 5
                    if avail < tile { continue }
                    let nt = max(1, Int((avail / tile).rounded()))
                    let su: CGFloat = avail / (CGFloat(nt) * 5)
                    let hook: [CGPoint] = [p(0, 6), p(0, 1), p(4, 1), p(4, 5), p(2, 5), p(2, 3)]
                    for i in 0..<nt {
                        let base: CGFloat = margin + (CGFloat(i) * 5 + 0.5) * su
                        var q: [CGPoint] = []
                        for g in hook { q.append(at(a, t, base + g.x * su, n, (g.y - 3) * uv)) }
                        path.addPath(polyPath(q, closed: false))
                    }
                } else {
                    let tile: CGFloat = B * 0.7
                    if avail < tile { continue }
                    let nt = max(1, Int((avail / tile).rounded()))
                    let tl: CGFloat = avail / CGFloat(nt)
                    let h: CGFloat = (B - lr) / 2 - lr * 1.8
                    for i in 0..<nt {
                        let s0: CGFloat = margin + CGFloat(i) * tl
                        var q: [CGPoint] = []
                        q.append(at(a, t, s0 + tl * 0.22, n, -h))
                        q.append(at(a, t, s0 + tl * 0.72, n, 0))
                        q.append(at(a, t, s0 + tl * 0.22, n, h))
                        path.addPath(polyPath(q, closed: false))
                    }
                }
            }
            stroke(ctx, path, c1, fam == .meander ? lr : lr * 1.3)
            bandCorners(ctx, l, style, B, lr, c2)
        case .checker:
            let B: CGFloat = lw * 4
            band(0, thin, c1)
            band(B - thin, B, c1)
            let l = lp(B / 2)
            let cell: CGFloat = B / 2
            let path = CGMutablePath()
            for e in edges(l) {
                let a = e.0
                let t = unit(sub(e.1, a))
                let n = perp(t)
                let elen = len(sub(e.1, a))
                let margin: CGFloat = style == .square ? B / 2 : 0
                let avail: CGFloat = elen - 2 * margin
                if avail < cell { continue }
                var nc = max(1, Int((avail / cell).rounded()))
                if nc % 2 == 0 { nc += 1 }
                let cl: CGFloat = avail / CGFloat(nc)
                for i in 0..<nc {
                    let s0: CGFloat = margin + CGFloat(i) * cl
                    let o0: CGFloat = i % 2 == 0 ? -B / 2 : 0
                    var q: [CGPoint] = []
                    q.append(at(a, t, s0, n, o0))
                    q.append(at(a, t, s0 + cl, n, o0))
                    q.append(at(a, t, s0 + cl, n, o0 + cell))
                    q.append(at(a, t, s0, n, o0 + cell))
                    path.addPath(polyPath(q, closed: true))
                }
            }
            if style == .square {
                for k in 0..<4 {
                    let c = l.pts[l.mids[k]]
                    path.addRect(CGRect(x: c.x - B / 2, y: c.y - B / 2, width: B, height: B))
                }
            }
            fill(ctx, path, c1)
        case .filmStrip:
            let B: CGFloat = lw * 7
            let u: CGFloat = B / 7
            let path = CGMutablePath()
            path.addPath(polyPath(lp(0).pts, closed: true))
            path.addPath(polyPath(lp(B).pts, closed: true))
            let l = lp(B / 2)
            let hw: CGFloat = u * 1.5
            let hh: CGFloat = u * 1.25
            let pitch: CGFloat = u * 2.8
            let rowOff: CGFloat = B / 2 - u * 1.55
            for e in edges(l) {
                let a = e.0
                let t = unit(sub(e.1, a))
                let n = perp(t)
                let elen = len(sub(e.1, a))
                let margin: CGFloat = (style == .square ? B / 2 : 0) + u * 0.8
                let avail: CGFloat = elen - 2 * margin
                if avail < pitch { continue }
                let nh = max(1, Int((avail / pitch).rounded()))
                let p2: CGFloat = avail / CGFloat(nh)
                for i in 0..<nh {
                    let s: CGFloat = margin + (CGFloat(i) + 0.5) * p2
                    for side in [CGFloat(-1), CGFloat(1)] {
                        let c = at(a, t, s, n, side * rowOff)
                        let tr = CGAffineTransform(a: t.x, b: t.y, c: n.x, d: n.y, tx: c.x, ty: c.y)
                        let rect = CGRect(x: -hw / 2, y: -hh / 2, width: hw, height: hh)
                        path.addRoundedRect(in: rect, cornerWidth: u * 0.3, cornerHeight: u * 0.3, transform: tr)
                    }
                }
            }
            fill(ctx, path, c1, evenOdd: true)
        case .perforation:
            let B: CGFloat = lw * 5
            band(0, B, c1)
            let rr: CGFloat = lw * 0.9
            let holes = CGMutablePath()
            for m in motifs(lp(0), lw * 2.6) { holes.addEllipse(in: circleRect(m.pos, rr)) }
            erase(ctx, holes)
            let inner: CGFloat = B + lw * 1.4
            band(inner, inner + max(0.6, lw * 0.5), c2)
        case .goldFrame:
            drawGilded(ctx, R, style, r, bounds: bounds, B: lw * 6, lw: lw, c1: c1)
        }
    }

    /// A bevelled metallic band: stepped light/dark profile plus a diagonal sheen.
    static func drawGilded(_ ctx: CGContext, _ R: CGRect, _ style: CornerStyle, _ r: CGFloat, bounds: CGRect, B: CGFloat,
                           lw: CGFloat, c1: RGBA) {
        let dk = c1.mixed(with: .black, 0.55)
        let lt = c1.mixed(with: .white, 0.55)
        ring(ctx, R, style, r, 0, B, c1)
        let prof: [Double] = [0.2, 0.62, 0.95, 0.78, 0.5, 0.3, 0.42, 0.7, 0.88, 0.4]
        let n = prof.count
        for i in 0..<n {
            let t = prof[i]
            let col: RGBA = t < 0.5 ? dk.mixed(with: c1, t * 2) : c1.mixed(with: lt, (t - 0.5) * 2)
            let a: CGFloat = B * CGFloat(i) / CGFloat(n)
            let b: CGFloat = B * CGFloat(i + 1) / CGFloat(n)
            ring(ctx, R, style, r, a, b, col)
        }
        ctx.saveGState()
        let clip = CGMutablePath()
        clip.addPath(polyPath(loop(R, style, r, 0).pts, closed: true))
        clip.addPath(polyPath(loop(R, style, r, B).pts, closed: true))
        ctx.addPath(clip)
        ctx.clip(using: .evenOdd)
        var cols: [CGColor] = []
        cols.append(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0))
        cols.append(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.32))
        cols.append(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0))
        cols.append(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.2))
        cols.append(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0))
        cols.append(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.24))
        cols.append(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0))
        let locs: [CGFloat] = [0, 0.18, 0.34, 0.5, 0.66, 0.82, 1]
        if let g = CGGradient(colorsSpace: Gfx.sRGB, colors: cols as CFArray, locations: locs) {
            ctx.drawLinearGradient(g, start: CGPoint(x: bounds.minX, y: bounds.minY),
                                   end: CGPoint(x: bounds.maxX, y: bounds.maxY), options: [])
        }
        ctx.restoreGState()
        let edge: CGFloat = max(0.6, lw * 0.25)
        ring(ctx, R, style, r, 0, edge, dk)
        ring(ctx, R, style, r, B - edge, B, dk)
    }

    /// Small ornaments where a patterned band turns a corner.
    static func bandCorners(_ ctx: CGContext, _ l: Loop, _ style: CornerStyle, _ B: CGFloat, _ lr: CGFloat, _ col: RGBA) {
        let strokes = CGMutablePath()
        let fills = CGMutablePath()
        for k in 0..<min(4, l.mids.count) {
            let c = l.pts[l.mids[k]]
            switch style {
            case .square:
                let s: CGFloat = B * 0.23
                strokes.addRect(CGRect(x: c.x - s, y: c.y - s, width: s * 2, height: s * 2))
                let s2: CGFloat = B * 0.08
                fills.addRect(CGRect(x: c.x - s2, y: c.y - s2, width: s2 * 2, height: s2 * 2))
            case .chamfered:
                let s: CGFloat = B * 0.3
                strokes.addPath(polyPath([p(c.x, c.y - s), p(c.x + s, c.y), p(c.x, c.y + s), p(c.x - s, c.y)], closed: true))
                fills.addEllipse(in: circleRect(c, B * 0.08))
            case .notched:
                fills.addEllipse(in: circleRect(c, B * 0.12))
            case .rounded, .ticket:
                strokes.addEllipse(in: circleRect(c, B * 0.22))
                fills.addEllipse(in: circleRect(c, B * 0.08))
            }
        }
        if !strokes.isEmpty { stroke(ctx, strokes, col, lr) }
        if !fills.isEmpty { fill(ctx, fills, col) }
    }

    // MARK: Corner-led borders

    static func cornerMap(_ R: CGRect, _ k: Int, _ q: CGPoint) -> CGPoint {
        switch k {
        case 0: return p(R.minX + q.x, R.minY + q.y)
        case 1: return p(R.maxX - q.x, R.minY + q.y)
        case 2: return p(R.maxX - q.x, R.maxY - q.y)
        default: return p(R.minX + q.x, R.maxY - q.y)
        }
    }

    /// A closed outline whose four corners are the mirrored `local` polyline (from the left-edge side
    /// to the top-edge side, as seen in the top-left corner).
    static func cornerPolygon(_ R: CGRect, _ local: [CGPoint]) -> [CGPoint] {
        var out: [CGPoint] = []
        for k in 0..<4 {
            let seq: [CGPoint] = (k == 1 || k == 3) ? Array(local.reversed()) : local
            for q in seq { out.append(cornerMap(R, k, q)) }
        }
        return out
    }

    /// Runs `body` once per corner with the CTM moved to that corner and mirrored so +x and +y point inward.
    static func eachCorner(_ ctx: CGContext, _ R: CGRect, _ body: (Int) -> Void) {
        for k in 0..<4 {
            ctx.saveGState()
            let c = cornerMap(R, k, .zero)
            ctx.translateBy(x: c.x, y: c.y)
            let sx: CGFloat = (k == 1 || k == 2) ? -1 : 1
            let sy: CGFloat = k >= 2 ? -1 : 1
            ctx.scaleBy(x: sx, y: sy)
            body(k)
            ctx.restoreGState()
        }
    }

    static func diamondPath(_ c: CGPoint, _ hw: CGFloat, _ hh: CGFloat) -> CGMutablePath {
        polyPath([p(c.x, c.y - hh), p(c.x + hw, c.y), p(c.x, c.y + hh), p(c.x - hw, c.y)], closed: true)
    }

    struct WalkPt {
        let pos: CGPoint
        let nrm: CGPoint
        let s: CGFloat
    }

    /// Points around a rectangle every ~`step`, with inward normals (diagonal at corners).
    static func walk(_ R: CGRect, step: CGFloat) -> [WalkPt] {
        let corners: [CGPoint] = [p(R.minX, R.minY), p(R.maxX, R.minY), p(R.maxX, R.maxY), p(R.minX, R.maxY)]
        let normals: [CGPoint] = [p(0, 1), p(-1, 0), p(0, -1), p(1, 0)]
        var out: [WalkPt] = []
        var s: CGFloat = 0
        for k in 0..<4 {
            let a = corners[k]
            let b = corners[(k + 1) % 4]
            let elen = len(sub(b, a))
            let n = max(1, Int((elen / max(step, 0.5)).rounded()))
            let prevN = normals[(k + 3) % 4]
            for i in 0..<n {
                let t = CGFloat(i) / CGFloat(n)
                let nrm: CGPoint = i == 0 ? add(normals[k], prevN) : normals[k]
                out.append(WalkPt(pos: lerp(a, b, t), nrm: nrm, s: s + elen * t))
            }
            s += elen
        }
        return out
    }

    /// Smooth, seamless (whole cycles around the perimeter) noise in -1...1.
    struct Wobble {
        var freq: [CGFloat] = []
        var phase: [CGFloat] = []
        var amp: [CGFloat] = []

        init(total: CGFloat, H: CGFloat, rng: inout SeededRNG, wavelengths: [CGFloat]) {
            var sum: CGFloat = 0
            for i in 0..<wavelengths.count {
                let cycles: CGFloat = max(1, (total / max(1, wavelengths[i] * H)).rounded())
                freq.append(2 * CGFloat.pi * cycles / max(total, 1))
                phase.append(CGFloat(rng.unit()) * 2 * CGFloat.pi)
                let a: CGFloat = 1 / CGFloat(i + 1)
                amp.append(a)
                sum += a
            }
            if sum > 0 {
                for i in 0..<amp.count { amp[i] /= sum }
            }
        }

        func at(_ s: CGFloat) -> CGFloat {
            var v: CGFloat = 0
            for i in 0..<freq.count { v += amp[i] * sin(s * freq[i] + phase[i]) }
            return v
        }
    }

    static func drawCornerBorder(_ ctx: CGContext, _ fam: CornerFamily, bounds: CGRect, H: CGFloat, weight: CGFloat,
                                 inset: CGFloat, c1: RGBA, c2: RGBA, seed: Int) {
        let lw: CGFloat = max(0.75, weight * H)
        let ins: CGFloat = inset * H
        let R = bounds.insetBy(dx: ins, dy: ins)
        guard R.width > lw * 24, R.height > lw * 24 else { return }
        let k: CGFloat = max(0.012 * H, lw * 3)
        let total: CGFloat = 2 * (R.width + R.height)

        func sq(_ a: CGFloat, _ b: CGFloat, _ col: RGBA) { ring(ctx, R, .square, 0, a, b, col) }

        switch fam {
        case .decoSteps:
            sq(0, lw, c1)
            let g: CGFloat = k * 0.9
            let s: CGFloat = k * 0.9
            var local: [CGPoint] = []
            local.append(p(g, g + 3 * s))
            local.append(p(g + s, g + 3 * s))
            local.append(p(g + s, g + 2 * s))
            local.append(p(g + 2 * s, g + 2 * s))
            local.append(p(g + 2 * s, g + s))
            local.append(p(g + 3 * s, g + s))
            local.append(p(g + 3 * s, g))
            stroke(ctx, polyPath(cornerPolygon(R, local), closed: true), c2, max(0.75, lw * 0.75))
            eachCorner(ctx, R) { _ in
                fill(ctx, diamondPath(p(g + s * 1.05, g + s * 1.05), s * 0.55, s * 0.55), c1)
            }
        case .decoFan:
            sq(0, lw, c1)
            eachCorner(ctx, R) { _ in drawOrn(ctx, .fan, k: k, lw: lw * 0.85, c1: c1, c2: c2) }
        case .nouveau:
            sq(0, max(0.75, lw * 0.6), c1)
            eachCorner(ctx, R) { _ in
                ctx.translateBy(x: k * 0.5, y: k * 0.5)
                drawOrn(ctx, .flourish, k: k, lw: lw, c1: c1, c2: c2)
            }
        case .filigree:
            sq(0, max(0.75, lw * 0.6), c1)
            eachCorner(ctx, R) { _ in
                ctx.translateBy(x: k * 0.45, y: k * 0.45)
                drawOrn(ctx, .spiral, k: k, lw: lw, c1: c1, c2: c2)
            }
        case .victorian:
            sq(0, lw, c1)
            ring(ctx, R, .ticket, k * 3.0, k * 1.1, k * 1.1 + max(0.75, lw * 0.7), c2)
            eachCorner(ctx, R) { _ in
                let path = diamondPath(p(k * 1.6, k * 1.6), k * 0.7, k * 0.7)
                path.addEllipse(in: circleRect(p(k * 2.9, k * 0.85), k * 0.28))
                path.addEllipse(in: circleRect(p(k * 0.85, k * 2.9), k * 0.28))
                fill(ctx, path, c1)
            }
        case .viewfinder:
            eachCorner(ctx, R) { _ in drawOrn(ctx, .viewfinder, k: k, lw: lw, c1: c1, c2: c2) }
        case .cornerDots:
            sq(0, max(0.75, lw * 0.6), c1)
            eachCorner(ctx, R) { _ in
                ctx.translateBy(x: k * 0.3, y: k * 0.3)
                drawOrn(ctx, .dots, k: k, lw: lw, c1: c1, c2: c2)
            }
        case .torn:
            var rng = SeededRNG(seed: seed)
            let wp = walk(R, step: max(2, 0.0042 * H))
            let wob = Wobble(total: total, H: H, rng: &rng, wavelengths: [0.31, 0.11, 0.047])
            let amp: CGFloat = lw * 1.8
            var poly: [CGPoint] = []
            for w in wp {
                let smooth: CGFloat = amp * (0.55 + 0.45 * wob.at(w.s))
                let jag: CGFloat = amp * 0.75 * CGFloat(rng.unit())
                poly.append(add(w.pos, mul(w.nrm, smooth + jag)))
            }
            let path = CGMutablePath()
            path.addRect(bounds)
            path.addPath(polyPath(poly, closed: true))
            fill(ctx, path, c1, evenOdd: true)
            stroke(ctx, polyPath(poly, closed: true), c1.mixed(with: .white, 0.45).withAlpha(0.6), max(0.6, lw * 0.35))
        case .brush:
            var rng = SeededRNG(seed: seed)
            let wp = walk(R, step: max(2, 0.004 * H))
            let w1 = Wobble(total: total, H: H, rng: &rng, wavelengths: [0.4, 0.13, 0.05])
            let w2 = Wobble(total: total, H: H, rng: &rng, wavelengths: [0.23, 0.07, 0.03])
            var outer: [CGPoint] = []
            var inner: [CGPoint] = []
            var streaks: [[CGPoint]] = [[], [], []]
            for w in wp {
                let o: CGFloat = lw * 0.45 * (1 + w1.at(w.s)) + lw * 0.1
                let width: CGFloat = lw * 2.4 * (0.62 + 0.38 * w2.at(w.s)) + lw * 0.25 * CGFloat(rng.unit())
                outer.append(add(w.pos, mul(w.nrm, o)))
                inner.append(add(w.pos, mul(w.nrm, o + width)))
                for j in 0..<3 {
                    let f: CGFloat = 0.25 + 0.25 * CGFloat(j)
                    streaks[j].append(add(w.pos, mul(w.nrm, o + width * f)))
                }
            }
            let path = CGMutablePath()
            path.addPath(polyPath(outer, closed: true))
            path.addPath(polyPath(inner, closed: true))
            fill(ctx, path, c1, evenOdd: true)
            ctx.saveGState()
            ctx.setBlendMode(.destinationOut)
            ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.85))
            ctx.setLineCap(.round)
            for j in 0..<3 {
                var pat: [CGFloat] = []
                for _ in 0..<6 {
                    pat.append(lw * CGFloat(rng.range(5, 28)))
                    pat.append(lw * CGFloat(rng.range(2, 12)))
                }
                ctx.setLineDash(phase: lw * CGFloat(rng.range(0, 20)), lengths: pat)
                ctx.setLineWidth(max(0.5, lw * CGFloat(rng.range(0.1, 0.22))))
                ctx.addPath(polyPath(streaks[j], closed: true))
                ctx.strokePath()
            }
            ctx.restoreGState()
        case .grunge:
            var rng = SeededRNG(seed: seed)
            let wp = walk(R, step: max(2, 0.003 * H))
            let wob = Wobble(total: total, H: H, rng: &rng, wavelengths: [0.27, 0.09, 0.035])
            var poly: [CGPoint] = []
            for w in wp {
                let off: CGFloat = lw * 1.4 * (0.5 + 0.5 * wob.at(w.s)) + lw * 0.45 * CGFloat(rng.unit())
                poly.append(add(w.pos, mul(w.nrm, off)))
            }
            guard let first = poly.first else { return }
            let band = CGMutablePath()
            band.addRect(bounds)
            band.addPath(polyPath(poly, closed: true))
            fill(ctx, band, c1, evenOdd: true)
            var closed = poly
            closed.append(first)
            let sm = Sampler(closed)
            let count = min(1600, max(60, Int(sm.total / (lw * 1.4))))
            let specks = CGMutablePath()
            for _ in 0..<count {
                let v = sm.at(CGFloat(rng.unit()) * sm.total)
                let u = CGFloat(rng.unit())
                let d: CGFloat = lw * (0.3 + 3.2 * u * u)
                let rad: CGFloat = lw * (0.08 + 0.42 * CGFloat(rng.unit()) * CGFloat(rng.unit()))
                specks.addEllipse(in: circleRect(add(v.0, mul(perp(v.1), d)), rad))
            }
            fill(ctx, specks, c1)
            let holes = CGMutablePath()
            for _ in 0..<(count / 2) {
                let v = sm.at(CGFloat(rng.unit()) * sm.total)
                let u = CGFloat(rng.unit())
                let d: CGFloat = -lw * (0.2 + 3.0 * u * u)
                let rad: CGFloat = lw * (0.1 + 0.35 * CGFloat(rng.unit()) * CGFloat(rng.unit()))
                holes.addEllipse(in: circleRect(add(v.0, mul(perp(v.1), d)), rad))
            }
            erase(ctx, holes)
        }
    }

    // MARK: Corner ornaments

    static func drawCorners(_ ctx: CGContext, _ orn: CornerOrn, bounds: CGRect, H: CGFloat, unitFrac: CGFloat, inset: CGFloat,
                            weight: CGFloat, c1: RGBA, c2: RGBA) {
        let ins: CGFloat = inset * H
        let R = bounds.insetBy(dx: ins, dy: ins)
        guard R.width > 4, R.height > 4 else { return }
        let k: CGFloat = max(1, unitFrac * H)
        let lw: CGFloat = max(0.75, weight * H)
        eachCorner(ctx, R) { _ in drawOrn(ctx, orn, k: k, lw: lw, c1: c1, c2: c2) }
    }

    /// Runs `body` as-is and mirrored across the corner diagonal.
    static func bothHalves(_ ctx: CGContext, _ body: () -> Void) {
        body()
        ctx.saveGState()
        ctx.concatenate(CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0))
        body()
        ctx.restoreGState()
    }

    static func leafPath(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat) -> CGMutablePath {
        let mid = lerp(a, b, 0.5)
        let n = perp(unit(sub(b, a)))
        let path = CGMutablePath()
        path.move(to: a)
        path.addQuadCurve(to: b, control: add(mid, mul(n, w)))
        path.addQuadCurve(to: a, control: add(mid, mul(n, -w)))
        path.closeSubpath()
        return path
    }

    /// One corner ornament in local space: origin at the frame corner, +x along the top edge, +y down the side.
    static func drawOrn(_ ctx: CGContext, _ o: CornerOrn, k: CGFloat, lw: CGFloat, c1: RGBA, c2: RGBA) {
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        switch o {
        case .viewfinder:
            let path = polyPath([p(0, 6 * k), p(0, 0), p(6 * k, 0)], closed: false)
            stroke(ctx, path, c1, lw * 1.5)
        case .doubleL:
            let path = polyPath([p(0, 6.5 * k), p(0, 0), p(6.5 * k, 0)], closed: false)
            path.addPath(polyPath([p(1.2 * k, 4.6 * k), p(1.2 * k, 1.2 * k), p(4.6 * k, 1.2 * k)], closed: false))
            stroke(ctx, path, c1, lw)
            fill(ctx, CGPath(ellipseIn: circleRect(p(2.3 * k, 2.3 * k), k * 0.35), transform: nil), c2)
        case .steps:
            let path = CGMutablePath()
            for j in 0..<3 {
                let off: CGFloat = CGFloat(j) * 1.2 * k
                let arm: CGFloat = 7 * k - CGFloat(j) * 1.8 * k
                path.addPath(polyPath([p(off, arm), p(off, off), p(arm, off)], closed: false))
            }
            stroke(ctx, path, c1, lw)
            let s: CGFloat = 0.35 * k
            fill(ctx, CGPath(rect: CGRect(x: 3.3 * k - s, y: 3.3 * k - s, width: s * 2, height: s * 2), transform: nil), c2)
        case .fan:
            let disc = CGMutablePath()
            disc.move(to: .zero)
            for q in arcPts(.zero, 1.6 * k, 0, CGFloat.pi / 2, 24) { disc.addLine(to: q) }
            disc.closeSubpath()
            fill(ctx, disc, c2)
            let lines = CGMutablePath()
            lines.addPath(polyPath(arcPts(.zero, 2.4 * k, 0, CGFloat.pi / 2, 36), closed: false))
            lines.addPath(polyPath(arcPts(.zero, 5.4 * k, 0, CGFloat.pi / 2, 64), closed: false))
            for i in 1...5 {
                let a: CGFloat = CGFloat(i) * CGFloat.pi / 12
                lines.move(to: p(2.9 * k * cos(a), 2.9 * k * sin(a)))
                lines.addLine(to: p(5.4 * k * cos(a), 5.4 * k * sin(a)))
            }
            stroke(ctx, lines, c1, lw)
            let dots = CGMutablePath()
            for i in 0...6 {
                let a: CGFloat = CGFloat(i) * CGFloat.pi / 12
                dots.addEllipse(in: circleRect(p(6.1 * k * cos(a), 6.1 * k * sin(a)), k * 0.22))
            }
            fill(ctx, dots, c1)
        case .flourish:
            bothHalves(ctx) {
                let path = CGMutablePath()
                path.move(to: p(1.0 * k, 1.0 * k))
                path.addCurve(to: p(8.5 * k, 0.9 * k), control1: p(2.5 * k, 0.25 * k), control2: p(5.5 * k, 0.35 * k))
                path.addCurve(to: p(10.4 * k, 2.9 * k), control1: p(10.2 * k, 1.2 * k), control2: p(11.0 * k, 2.2 * k))
                path.addCurve(to: p(8.9 * k, 2.9 * k), control1: p(10.0 * k, 3.7 * k), control2: p(9.0 * k, 3.6 * k))
                path.addCurve(to: p(9.6 * k, 2.2 * k), control1: p(8.8 * k, 2.4 * k), control2: p(9.2 * k, 2.1 * k))
                stroke(ctx, path, c1, lw * 1.1)
                let tendril = CGMutablePath()
                tendril.move(to: p(5.0 * k, 0.5 * k))
                tendril.addCurve(to: p(6.2 * k, 2.4 * k), control1: p(5.6 * k, 1.2 * k), control2: p(6.6 * k, 1.6 * k))
                tendril.addCurve(to: p(5.4 * k, 2.2 * k), control1: p(5.9 * k, 3.0 * k), control2: p(5.2 * k, 2.7 * k))
                stroke(ctx, tendril, c1, lw * 0.8)
                fill(ctx, CGPath(ellipseIn: circleRect(p(12.0 * k, 1.2 * k), k * 0.32), transform: nil), c2)
            }
            fill(ctx, leafPath(p(1.3 * k, 1.3 * k), p(4.4 * k, 4.4 * k), 1.2 * k), c2)
            fill(ctx, CGPath(ellipseIn: circleRect(p(0.45 * k, 0.45 * k), k * 0.3), transform: nil), c1)
        case .spiral:
            bothHalves(ctx) {
                let path = CGMutablePath()
                path.move(to: p(0.9 * k, 0.9 * k))
                path.addQuadCurve(to: p(6.2 * k, 0.8 * k), control: p(3.0 * k, 0.45 * k))
                path.addPath(polyPath(spiralPts(p(6.2 * k, 2.0 * k), 1.2 * k, 0.25 * k, -CGFloat.pi / 2, 1.5, true), closed: false))
                path.addPath(polyPath(spiralPts(p(3.4 * k, 1.65 * k), 1.0 * k, 0.2 * k, -CGFloat.pi / 2, 1.2, false), closed: false))
                stroke(ctx, path, c1, lw * 0.9)
                let dots = CGMutablePath()
                dots.addEllipse(in: circleRect(p(8.3 * k, 0.9 * k), k * 0.3))
                dots.addEllipse(in: circleRect(p(9.3 * k, 0.9 * k), k * 0.2))
                fill(ctx, dots, c2)
            }
            fill(ctx, diamondPath(p(1.9 * k, 1.9 * k), k * 0.5, k * 0.5), c2)
        case .scroll:
            bothHalves(ctx) {
                let path = CGMutablePath()
                path.move(to: p(1.2 * k, 1.2 * k))
                path.addCurve(to: p(4.8 * k, 0.9 * k), control1: p(2.2 * k, 0.4 * k), control2: p(3.6 * k, 0.3 * k))
                path.addPath(polyPath(spiralPts(p(4.8 * k, 2.1 * k), 1.2 * k, 0.35 * k, -CGFloat.pi / 2, 1.25, true), closed: false))
                path.move(to: p(5.6 * k, 0.95 * k))
                path.addCurve(to: p(9.2 * k, 1.6 * k), control1: p(7.0 * k, 1.0 * k), control2: p(8.2 * k, 0.9 * k))
                path.addPath(polyPath(spiralPts(p(9.2 * k, 2.4 * k), 0.8 * k, 0.25 * k, -CGFloat.pi / 2, 1.1, true), closed: false))
                stroke(ctx, path, c1, lw * 1.05)
            }
            fill(ctx, leafPath(p(1.4 * k, 1.4 * k), p(3.2 * k, 3.2 * k), 1.0 * k), c2)
        case .victorian:
            let r1: CGFloat = 3.2 * k
            var outer: [CGPoint] = [p(0, 8 * k)]
            outer.append(contentsOf: arcPts(.zero, r1, CGFloat.pi / 2, 0, 40))
            outer.append(p(8 * k, 0))
            let r2: CGFloat = 4.1 * k
            let off: CGFloat = 0.9 * k
            let v1: CGFloat = (r2 * r2 - off * off).squareRoot()
            let aStart: CGFloat = atan2(v1, off)
            let aEnd: CGFloat = atan2(off, v1)
            var inner: [CGPoint] = [p(off, 7.2 * k)]
            inner.append(contentsOf: arcPts(.zero, r2, aStart, aEnd, 40))
            inner.append(p(7.2 * k, off))
            stroke(ctx, polyPath(outer, closed: false), c1, lw)
            stroke(ctx, polyPath(inner, closed: false), c1, lw * 0.7)
            let dots = diamondPath(p(1.25 * k, 1.25 * k), 0.75 * k, 0.75 * k)
            dots.addEllipse(in: circleRect(p(2.55 * k, 0.6 * k), 0.3 * k))
            dots.addEllipse(in: circleRect(p(0.6 * k, 2.55 * k), 0.3 * k))
            dots.addEllipse(in: circleRect(p(0, 8.6 * k), 0.42 * k))
            dots.addEllipse(in: circleRect(p(8.6 * k, 0), 0.42 * k))
            fill(ctx, dots, c2)
        case .dots:
            let path = CGMutablePath()
            path.addEllipse(in: circleRect(p(1.0 * k, 1.0 * k), 0.6 * k))
            let steps: [(CGFloat, CGFloat)] = [(2.6, 0.45), (4.0, 0.32), (5.2, 0.22)]
            for st in steps {
                path.addEllipse(in: circleRect(p(st.0 * k, 1.0 * k), st.1 * k))
                path.addEllipse(in: circleRect(p(1.0 * k, st.0 * k), st.1 * k))
            }
            path.addEllipse(in: circleRect(p(2.3 * k, 2.3 * k), 0.3 * k))
            fill(ctx, path, c1)
        case .sprig:
            bothHalves(ctx) {
                let a = p(0.8 * k, 0.8 * k)
                let c = p(4.2 * k, 0.3 * k)
                let b = p(9.0 * k, 1.8 * k)
                var stem: [CGPoint] = []
                for i in 0...32 { stem.append(quadPt(a, c, b, CGFloat(i) / 32)) }
                stroke(ctx, polyPath(stem, closed: false), c1, lw * 0.9)
                let leaves = CGMutablePath()
                let ts: [CGFloat] = [0.3, 0.5, 0.7, 0.88]
                for i in 0..<ts.count {
                    let t = ts[i]
                    let pt = quadPt(a, c, b, t)
                    let tan = unit(sub(quadPt(a, c, b, t + 0.01), pt))
                    let side: CGFloat = i % 2 == 0 ? 1 : -1
                    let dir = rotate(tan, side * 0.7)
                    leaves.addPath(leafPath(pt, add(pt, mul(dir, 1.9 * k)), 0.45 * k))
                }
                let tipTan = unit(sub(b, quadPt(a, c, b, 0.97)))
                leaves.addPath(leafPath(b, add(b, mul(tipTan, 1.6 * k)), 0.4 * k))
                fill(ctx, leaves, c1)
            }
            fill(ctx, CGPath(ellipseIn: circleRect(p(0.8 * k, 0.8 * k), 0.45 * k), transform: nil), c2)
        case .photo:
            let tri = polyPath([p(0, 0), p(5.5 * k, 0), p(0, 5.5 * k)], closed: true)
            fill(ctx, tri, c1)
            eraseStroke(ctx, polyPath([p(0.35 * k, 4.2 * k), p(4.2 * k, 0.35 * k)], closed: false), max(0.75, lw * 0.6))
        case .star:
            stroke(ctx, polyPath([p(0, 7 * k), p(0, 0), p(7 * k, 0)], closed: false), c1, lw)
            fill(ctx, polyPath(starPts(p(2.3 * k, 2.3 * k), 1.5 * k, 0.55 * k, 8, -CGFloat.pi / 2), closed: true), c2)
            let dots = CGMutablePath()
            dots.addEllipse(in: circleRect(p(5.4 * k, 1.1 * k), 0.3 * k))
            dots.addEllipse(in: circleRect(p(1.1 * k, 5.4 * k), 0.3 * k))
            fill(ctx, dots, c1)
        }
    }

    // MARK: Dividers

    static func drawDivider(_ ctx: CGContext, _ style: DivLine, _ motif: DivMotif, _ cap: DivCap, W: CGFloat, Hh: CGFloat,
                            H: CGFloat, c1: RGBA, c2: RGBA) {
        let cy: CGFloat = Hh / 2
        let cx: CGFloat = W / 2
        let lw: CGFloat = min(max(0.0024 * H, 0.8), Hh * 0.1)
        let m: CGFloat = min(Hh * 0.86, max(lw * 8, 0.028 * H))
        let pad: CGFloat = lw * 1.5 + 1
        var capW: CGFloat = 0
        switch cap {
        case .none: capW = 0
        case .dots: capW = lw * 3.2 + lw * 1.4
        case .diamonds: capW = lw * 4.8 + lw * 1.4
        case .curls: capW = lw * 2.4 + lw * 0.5
        }
        let x0: CGFloat = pad + capW
        let x1: CGFloat = W - pad - capW
        guard x1 - x0 > lw * 4 else { return }
        let hw: CGFloat = motifHalfWidth(motif, m)
        let g: CGFloat = motif == .none ? 0 : m * 0.22 + lw
        let xa: CGFloat = cx - hw - g
        let xb: CGFloat = cx + hw + g
        // Halves as (outer end, inner end).
        var halves: [(CGFloat, CGFloat)] = []
        if motif == .none {
            halves = [(x0, cx), (x1, cx)]
        } else {
            if xa - x0 > lw { halves.append((x0, xa)) }
            if x1 - xb > lw { halves.append((x1, xb)) }
        }

        switch style {
        case .single, .double:
            let path = CGMutablePath()
            for hv in halves {
                let lo = min(hv.0, hv.1)
                let hi = max(hv.0, hv.1)
                if style == .single {
                    path.addRect(CGRect(x: lo, y: cy - lw / 2, width: hi - lo, height: lw))
                } else {
                    let t: CGFloat = max(0.8, lw * 0.75)
                    path.addRect(CGRect(x: lo, y: cy - lw * 1.3 - t / 2, width: hi - lo, height: t))
                    path.addRect(CGRect(x: lo, y: cy + lw * 1.3 - t / 2, width: hi - lo, height: t))
                }
            }
            fill(ctx, path, c1)
        case .dotted:
            let path = CGMutablePath()
            let rd: CGFloat = lw * 0.8
            let spacing: CGFloat = lw * 3.2
            for hv in halves {
                let length: CGFloat = abs(hv.1 - hv.0)
                let n = max(1, Int((length / spacing).rounded()))
                let dir: CGFloat = hv.1 > hv.0 ? 1 : -1
                for i in 0...n {
                    let x: CGFloat = hv.0 + dir * length * CGFloat(i) / CGFloat(n)
                    path.addEllipse(in: circleRect(p(x, cy), rd))
                }
            }
            fill(ctx, path, c1)
        case .fading:
            let th: CGFloat = lw * 1.1
            if motif == .none {
                fadeRect(ctx, CGRect(x: x0, y: cy - th / 2, width: x1 - x0, height: th), c1, both: true, fromLeft: true)
            } else {
                for hv in halves {
                    let lo = min(hv.0, hv.1)
                    let hi = max(hv.0, hv.1)
                    fadeRect(ctx, CGRect(x: lo, y: cy - th / 2, width: hi - lo, height: th), c1, both: false, fromLeft: hv.0 < hv.1)
                }
            }
        case .tapered:
            let hh: CGFloat = lw * 1.3
            let path = CGMutablePath()
            for hv in halves {
                let outer = hv.0
                let inner = hv.1
                let midX: CGFloat = (outer + inner) / 2
                path.move(to: p(outer, cy))
                path.addQuadCurve(to: p(inner, cy - hh), control: p(midX, cy - hh))
                path.addLine(to: p(inner, cy + hh))
                path.addQuadCurve(to: p(outer, cy), control: p(midX, cy + hh))
                path.closeSubpath()
            }
            fill(ctx, path, c1)
        }

        // End caps, drawn on the left and mirrored to the right.
        if cap != .none {
            for side in 0..<2 {
                ctx.saveGState()
                if side == 1 {
                    ctx.translateBy(x: W, y: 0)
                    ctx.scaleBy(x: -1, y: 1)
                }
                switch cap {
                case .none:
                    break
                case .dots:
                    fill(ctx, CGPath(ellipseIn: circleRect(p(pad + lw * 1.6, cy), lw * 1.6), transform: nil), c1)
                case .diamonds:
                    fill(ctx, diamondPath(p(pad + lw * 2.4, cy), lw * 2.4, lw * 1.9), c1)
                case .curls:
                    let rc: CGFloat = lw * 2.4
                    let center = p(x0, cy - rc)
                    let pts = spiralPts(center, rc, rc * 0.3, CGFloat.pi / 2, 0.85, true)
                    ctx.setLineCap(.round)
                    stroke(ctx, polyPath(pts, closed: false), c1, lw)
                }
                ctx.restoreGState()
            }
        }

        drawMotif(ctx, motif, p(cx, cy), m, lw, c2)
    }

    static func fadeRect(_ ctx: CGContext, _ rect: CGRect, _ c: RGBA, both: Bool, fromLeft: Bool) {
        guard rect.width > 0 else { return }
        ctx.saveGState()
        ctx.clip(to: rect)
        var cols: [CGColor] = []
        var locs: [CGFloat] = []
        if both {
            cols = [c.withAlpha(0).cgColor, c.cgColor, c.cgColor, c.withAlpha(0).cgColor]
            locs = [0, 0.42, 0.58, 1]
        } else if fromLeft {
            cols = [c.withAlpha(0).cgColor, c.cgColor]
            locs = [0, 1]
        } else {
            cols = [c.cgColor, c.withAlpha(0).cgColor]
            locs = [0, 1]
        }
        if let g = CGGradient(colorsSpace: Gfx.sRGB, colors: cols as CFArray, locations: locs) {
            ctx.drawLinearGradient(g, start: p(rect.minX, rect.midY), end: p(rect.maxX, rect.midY), options: [])
        }
        ctx.restoreGState()
    }

    static func motifHalfWidth(_ m: DivMotif, _ s: CGFloat) -> CGFloat {
        switch m {
        case .none: return 0
        case .diamond: return s * 0.34
        case .dot: return s * 0.13
        case .threeDots: return s * 0.4
        case .star: return s * 0.34
        case .asterism: return s * 0.38
        case .fleuron: return s * 1.1
        case .circle: return s * 0.26
        case .leaf: return s * 0.8
        case .chevron: return s * 0.5
        }
    }

    static func drawMotif(_ ctx: CGContext, _ motif: DivMotif, _ c: CGPoint, _ m: CGFloat, _ lw: CGFloat, _ col: RGBA) {
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        switch motif {
        case .none:
            break
        case .diamond:
            fill(ctx, diamondPath(c, m * 0.34, m * 0.22), col)
        case .dot:
            fill(ctx, CGPath(ellipseIn: circleRect(c, m * 0.13), transform: nil), col)
        case .threeDots:
            let path = CGMutablePath()
            path.addEllipse(in: circleRect(p(c.x - m * 0.3, c.y), m * 0.085))
            path.addEllipse(in: circleRect(c, m * 0.1))
            path.addEllipse(in: circleRect(p(c.x + m * 0.3, c.y), m * 0.085))
            fill(ctx, path, col)
        case .star:
            fill(ctx, polyPath(starPts(c, m * 0.34, m * 0.14, 5, -CGFloat.pi / 2), closed: true), col)
        case .asterism:
            let centers: [CGPoint] = [p(c.x - m * 0.22, c.y + m * 0.13), p(c.x + m * 0.22, c.y + m * 0.13), p(c.x, c.y - m * 0.17)]
            let path = CGMutablePath()
            let ar: CGFloat = m * 0.12
            for q in centers {
                for i in 0..<3 {
                    let a: CGFloat = CGFloat.pi / 2 + CGFloat(i) * CGFloat.pi / 3
                    path.move(to: p(q.x - ar * cos(a), q.y - ar * sin(a)))
                    path.addLine(to: p(q.x + ar * cos(a), q.y + ar * sin(a)))
                }
            }
            stroke(ctx, path, col, max(0.8, lw * 0.9))
        case .fleuron:
            fill(ctx, diamondPath(c, m * 0.12, m * 0.18), col)
            for side in 0..<2 {
                ctx.saveGState()
                if side == 1 {
                    ctx.translateBy(x: c.x * 2, y: 0)
                    ctx.scaleBy(x: -1, y: 1)
                }
                let path = CGMutablePath()
                path.move(to: p(c.x + m * 0.16, c.y))
                path.addCurve(to: p(c.x + m * 0.85, c.y), control1: p(c.x + m * 0.36, c.y - m * 0.42),
                              control2: p(c.x + m * 0.62, c.y + m * 0.38))
                path.addPath(polyPath(spiralPts(p(c.x + m * 0.85, c.y - m * 0.16), m * 0.16, m * 0.05, CGFloat.pi / 2, 0.9, false),
                                      closed: false))
                stroke(ctx, path, col, max(0.8, lw * 1.1))
                fill(ctx, CGPath(ellipseIn: circleRect(p(c.x + m * 1.04, c.y + m * 0.02), m * 0.045), transform: nil), col)
                ctx.restoreGState()
            }
        case .circle:
            stroke(ctx, CGPath(ellipseIn: circleRect(c, m * 0.22), transform: nil), col, max(0.8, lw * 1.2))
            fill(ctx, CGPath(ellipseIn: circleRect(c, m * 0.07), transform: nil), col)
        case .leaf:
            let path = leafPath(p(c.x - m * 0.1, c.y), p(c.x - m * 0.8, c.y), m * 0.24)
            path.addPath(leafPath(p(c.x + m * 0.1, c.y), p(c.x + m * 0.8, c.y), m * 0.24))
            path.addEllipse(in: circleRect(c, m * 0.06))
            fill(ctx, path, col)
        case .chevron:
            let path = CGMutablePath()
            path.addPath(polyPath([p(c.x - m * 0.46, c.y - m * 0.22), p(c.x - m * 0.2, c.y), p(c.x - m * 0.46, c.y + m * 0.22)], closed: false))
            path.addPath(polyPath([p(c.x + m * 0.46, c.y - m * 0.22), p(c.x + m * 0.2, c.y), p(c.x + m * 0.46, c.y + m * 0.22)], closed: false))
            stroke(ctx, path, col, max(0.8, lw * 1.4))
            fill(ctx, diamondPath(c, m * 0.07, m * 0.07), col)
        }
    }

    // MARK: Text

    static func makeLine(_ s: String, _ font: CTFont, kern: CGFloat) -> CTLine {
        var attrs: [NSAttributedString.Key: Any] = [:]
        attrs[NSAttributedString.Key(kCTFontAttributeName as String)] = font
        attrs[NSAttributedString.Key(kCTKernAttributeName as String)] = NSNumber(value: Double(kern))
        attrs[NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String)] = NSNumber(value: true)
        let str = NSAttributedString(string: s, attributes: attrs)
        return CTLineCreateWithAttributedString(str as CFAttributedString)
    }

    static func lineWidth(_ line: CTLine) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    static func drawCTLine(_ ctx: CGContext, _ line: CTLine, x: CGFloat, baseline: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: x, y: baseline)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textMatrix = .identity
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    static func setTextPaint(_ ctx: CGContext, _ color: RGBA?) {
        if let color {
            ctx.setFillColor(color.cgColor)
        } else {
            ctx.setBlendMode(.destinationOut)
            ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        }
    }

    /// Centered lines auto-fitted into `box`. Each line has a relative scale. nil color knocks the text out.
    static func drawTextBlock(_ ctx: CGContext, _ lines: [(String, CGFloat)], font name: String, center: CGPoint, box: CGSize,
                              color: RGBA?, tracking: CGFloat) {
        guard !lines.isEmpty, box.width > 2, box.height > 2 else { return }
        let ref: CGFloat = 100
        let refFont = FontCatalog.ctFont(name, size: ref)
        let capR: CGFloat = max(CTFontGetCapHeight(refFont), ref * 0.5) / ref
        var limit: CGFloat = box.height / capR
        var hUnits: CGFloat = 0
        for i in 0..<lines.count {
            let sc = lines[i].1
            let ln = makeLine(lines[i].0, refFont, kern: tracking * ref)
            let w: CGFloat = (lineWidth(ln) - tracking * ref) / ref
            if w > 0 { limit = min(limit, box.width / (w * sc)) }
            hUnits += sc * capR
            if i > 0 { hUnits += capR * 0.55 * min(sc, lines[i - 1].1) }
        }
        limit = min(limit, box.height / max(hUnits, 0.01))
        let size: CGFloat = max(2, limit)
        ctx.saveGState()
        setTextPaint(ctx, color)
        var y: CGFloat = center.y - size * hUnits / 2
        for i in 0..<lines.count {
            let sc = lines[i].1
            if i > 0 { y += size * capR * 0.55 * min(sc, lines[i - 1].1) }
            let f = FontCatalog.ctFont(name, size: size * sc)
            let kern: CGFloat = tracking * size * sc
            let ln = makeLine(lines[i].0, f, kern: kern)
            let w: CGFloat = lineWidth(ln) - kern
            y += size * sc * capR
            drawCTLine(ctx, ln, x: center.x - w / 2, baseline: y)
        }
        ctx.restoreGState()
    }

    /// One line of text set along an arc centered on `o`, caps centered on `radius`, reading left to right over the top.
    static func drawArcText(_ ctx: CGContext, _ text: String, font name: String, center o: CGPoint, radius: CGFloat,
                            maxArc: CGFloat, maxH: CGFloat, color: RGBA?, tracking: CGFloat) {
        guard !text.isEmpty, radius > 1, maxArc > 2, maxH > 1 else { return }
        let ref: CGFloat = 100
        let refFont = FontCatalog.ctFont(name, size: ref)
        let capR: CGFloat = max(CTFontGetCapHeight(refFont), ref * 0.5) / ref
        let refLine = makeLine(text, refFont, kern: tracking * ref)
        let wU: CGFloat = (lineWidth(refLine) - tracking * ref) / ref
        var size: CGFloat = maxH / capR
        if wU > 0 { size = min(size, maxArc / wU) }
        size = max(2, size)
        let font = FontCatalog.ctFont(name, size: size)
        let kern: CGFloat = tracking * size
        let line = makeLine(text, font, kern: kern)
        let total: CGFloat = lineWidth(line) - kern
        let rb: CGFloat = radius - size * capR / 2
        guard rb > 1 else { return }
        ctx.saveGState()
        setTextPaint(ctx, color)
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            if count == 0 { continue }
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            var advances = [CGSize](repeating: .zero, count: count)
            let all = CFRange(location: 0, length: 0)
            CTRunGetGlyphs(run, all, &glyphs)
            CTRunGetPositions(run, all, &positions)
            CTRunGetAdvances(run, all, &advances)
            for i in 0..<count {
                let mid: CGFloat = positions[i].x + advances[i].width / 2 - total / 2
                let phi: CGFloat = mid / rb
                let gx: CGFloat = o.x + rb * sin(phi)
                let gy: CGFloat = o.y - rb * cos(phi)
                ctx.saveGState()
                ctx.translateBy(x: gx, y: gy)
                ctx.rotate(by: phi)
                ctx.scaleBy(x: 1, y: -1)
                let g: [CGGlyph] = [glyphs[i]]
                let gpos: [CGPoint] = [CGPoint(x: -advances[i].width / 2, y: 0)]
                CTFontDrawGlyphs(font, g, gpos, 1, ctx)
                ctx.restoreGState()
            }
        }
        ctx.restoreGState()
    }

    /// Splits badge text into one or two lines with relative sizes ("BOOK" small over "ONE" large).
    static func badgeLines(_ text: String) -> [(String, CGFloat)] {
        let words = text.split(separator: " ").map(String.init)
        if words.count <= 1 { return [(text, 1)] }
        let small: Set<String> = ["A", "AN", "THE", "BOOK", "PART", "VOLUME", "VOL.", "NO.", "ISSUE"]
        if words.count == 2 {
            if small.contains(words[0].uppercased()) { return [(words[0], 0.5), (words[1], 1)] }
            return [(words[0], 1), (words[1], 1)]
        }
        // Balance longer text over two lines.
        var best = 1
        var bestDiff = Int.max
        for i in 1..<words.count {
            let a = words[0..<i].joined(separator: " ").count
            let b = words[i...].joined(separator: " ").count
            let d = abs(a - b)
            if d < bestDiff {
                bestDiff = d
                best = i
            }
        }
        return [(words[0..<best].joined(separator: " "), 1), (words[best...].joined(separator: " "), 1)]
    }

    // MARK: Badges

    static func shieldPts(_ cx: CGFloat, _ y0: CGFloat, _ sw: CGFloat, _ sh: CGFloat) -> [CGPoint] {
        let xl: CGFloat = cx - sw / 2
        let xr: CGFloat = cx + sw / 2
        let ys: CGFloat = y0 + sh * 0.42
        let yc: CGFloat = y0 + sh * 0.8
        let bottom = p(cx, y0 + sh)
        var pts: [CGPoint] = [p(xl, y0), p(xr, y0), p(xr, ys)]
        let n = 40
        for i in 1...n { pts.append(quadPt(p(xr, ys), p(xr, yc), bottom, CGFloat(i) / CGFloat(n))) }
        for i in 1...n { pts.append(quadPt(bottom, p(xl, yc), p(xl, ys), CGFloat(i) / CGFloat(n))) }
        return pts
    }

    static func drawBadge(_ ctx: CGContext, _ shape: BadgeShape, _ ringKind: BadgeRing, _ solid: Bool, W: CGFloat, Hh: CGFloat,
                          text: String, c1: RGBA, c2: RGBA?) {
        let side: CGFloat = min(W, Hh)
        guard side > 4 else { return }
        let cx: CGFloat = W / 2
        let cy: CGFloat = Hh / 2
        let top: CGFloat = cy - side / 2
        let R: CGFloat = side * 0.47
        let lwr: CGFloat = max(0.75, side * 0.013)
        let olw: CGFloat = max(0.75, side * 0.02)
        var mc = p(cx, cy)
        var body: [CGPoint] = []
        var ringPts: [CGPoint] = []
        var circular = true
        var ringR: CGFloat = R * 0.86
        var textCenter = mc
        var textBox = CGSize(width: R, height: R * 0.6)
        var tails: [[CGPoint]] = []
        var fontName: String = serifFont

        switch shape {
        case .circle:
            body = circlePts(mc, R, 360)
            ringR = R * 0.86
        case .star12, .star16, .star24:
            let n: Int = shape == .star12 ? 12 : (shape == .star16 ? 16 : 24)
            let ri: CGFloat = shape == .star12 ? 0.8 : (shape == .star16 ? 0.85 : 0.89)
            body = starPts(mc, R, R * ri, n, -CGFloat.pi / 2)
            ringR = R * ri * 0.9
            fontName = condensedFont
        case .scalloped:
            let a: CGFloat = R * 0.06
            body = lobed(mc, R - a, a, 24, 720)
            ringR = (R - a) * 0.88
        case .rosette:
            let Rm: CGFloat = side * 0.31
            mc = p(cx, top + side * 0.05 + Rm)
            let a: CGFloat = Rm * 0.07
            body = lobed(mc, Rm - a, a, 32, 720)
            ringR = (Rm - a) * 0.86
            for sgnIndex in 0..<2 {
                let sgn: CGFloat = sgnIndex == 0 ? -1 : 1
                let A = p(cx + sgn * side * 0.06, mc.y + Rm * 0.5)
                let B = p(cx + sgn * side * 0.22, top + side * 0.95)
                let dir = unit(sub(B, A))
                let n = perp(dir)
                let w: CGFloat = side * 0.15
                var tail: [CGPoint] = []
                tail.append(add(A, mul(n, w / 2)))
                tail.append(add(B, mul(n, w / 2)))
                tail.append(add(B, mul(dir, -w * 0.35)))
                tail.append(add(B, mul(n, -w / 2)))
                tail.append(add(A, mul(n, -w / 2)))
                tails.append(tail)
            }
        case .shield:
            circular = false
            let sw: CGFloat = side * 0.8
            let sh: CGFloat = side * 0.92
            let y0: CGFloat = cy - sh / 2
            body = shieldPts(cx, y0, sw, sh)
            mc = p(cx, y0 + sh * 0.44)
            ringPts = scaled(body, mc, 0.86)
            textCenter = p(cx, y0 + sh * 0.40)
            textBox = CGSize(width: sw * 0.62, height: sh * 0.34)
        case .hexagon:
            circular = false
            var hex: [CGPoint] = []
            for i in 0..<6 {
                let a: CGFloat = -CGFloat.pi / 2 + CGFloat(i) * CGFloat.pi / 3
                hex.append(p(cx + R * cos(a), cy + R * sin(a)))
            }
            body = hex
            ringPts = scaled(body, mc, 0.85)
            textBox = CGSize(width: R * 0.866 * 2 * 0.66, height: R * 0.62)
            fontName = condensedFont
        }
        let innerScale: CGFloat = ringKind == .double ? 0.9 : 1
        if circular {
            ringPts = circlePts(mc, ringR, 360)
            textCenter = mc
            let rt: CGFloat = ringR * innerScale - lwr * 2
            textBox = CGSize(width: rt * 1.62, height: rt * 1.08)
        } else if innerScale < 1 {
            textBox = CGSize(width: textBox.width * 0.92, height: textBox.height * 0.92)
        }

        let ringCol: RGBA? = solid ? c2 : c1
        let textCol: RGBA? = solid ? c2 : (c2 ?? c1)

        for t in tails {
            let path = polyPath(t, closed: true)
            if solid {
                fill(ctx, path, c1.mixed(with: .black, 0.22))
            } else {
                erase(ctx, path)
                stroke(ctx, path, c1, olw * 0.8)
            }
        }
        let bodyPath = polyPath(body, closed: true)
        if solid {
            fill(ctx, bodyPath, c1)
        } else {
            erase(ctx, bodyPath)
            stroke(ctx, bodyPath, c1, olw)
        }

        switch ringKind {
        case .single:
            paintStroke(ctx, polyPath(ringPts, closed: true), ringCol, lwr)
        case .double:
            paintStroke(ctx, polyPath(ringPts, closed: true), ringCol, lwr * 0.6)
            paintStroke(ctx, polyPath(scaled(ringPts, mc, 0.92), closed: true), ringCol, lwr * 0.6)
        case .dotted:
            let path = CGMutablePath()
            for q in evenly(ringPts, spacing: lwr * 2.9) { path.addEllipse(in: circleRect(q, lwr * 0.62)) }
            paintFill(ctx, path, ringCol)
        case .beaded:
            let path = CGMutablePath()
            for q in evenly(ringPts, spacing: lwr * 2.75) { path.addEllipse(in: circleRect(q, lwr * 1.05)) }
            paintFill(ctx, path, ringCol)
        }

        if !text.isEmpty {
            drawTextBlock(ctx, badgeLines(text.uppercased()), font: fontName, center: textCenter, box: textBox,
                          color: textCol, tracking: 0.06)
        }
    }

    // MARK: Banners

    static func extentOut(_ e: BannerEnd, _ hh: CGFloat) -> CGFloat {
        switch e {
        case .flat: return 0
        case .point: return hh * 0.85
        case .notch: return hh * 0.9
        case .round: return hh
        case .concave: return hh * 0.6
        }
    }

    /// The outline of a band end, from the top corner (E - n·hh) to the bottom corner (E + n·hh).
    static func endShape(_ E: CGPoint, out: CGPoint, n: CGPoint, hh: CGFloat, _ e: BannerEnd) -> [CGPoint] {
        let topC = add(E, mul(n, -hh))
        let botC = add(E, mul(n, hh))
        switch e {
        case .flat:
            return [topC, botC]
        case .point:
            return [topC, add(E, mul(out, hh * 0.85)), botC]
        case .notch:
            let k: CGFloat = hh * 0.9
            return [topC, add(topC, mul(out, k)), E, add(botC, mul(out, k)), botC]
        case .round:
            var pts: [CGPoint] = []
            for j in 0...20 {
                let th: CGFloat = -CGFloat.pi / 2 + CGFloat.pi * CGFloat(j) / 20
                pts.append(at(E, n, hh * sin(th), out, hh * cos(th)))
            }
            return pts
        case .concave:
            let k: CGFloat = hh * 0.6
            var pts: [CGPoint] = [topC]
            for j in 0...20 {
                let t = CGFloat(j) / 20
                pts.append(at(E, n, hh * (2 * t - 1), out, k * (1 - sin(CGFloat.pi * t))))
            }
            pts.append(botC)
            return pts
        }
    }

    /// A band of half-height `hh` along a centerline, with the given end shapes.
    static func bandPoly(_ cl: [CGPoint], _ tans: [CGPoint], hh: CGFloat, left: BannerEnd, right: BannerEnd) -> [CGPoint] {
        var pts: [CGPoint] = []
        let m = cl.count
        guard m >= 2, tans.count == m else { return pts }
        for i in 0..<m { pts.append(add(cl[i], mul(perp(tans[i]), -hh))) }
        let tr = tans[m - 1]
        pts.append(contentsOf: endShape(cl[m - 1], out: tr, n: perp(tr), hh: hh, right))
        var i = m - 1
        while i >= 0 {
            pts.append(add(cl[i], mul(perp(tans[i]), hh)))
            i -= 1
        }
        let tl = tans[0]
        pts.append(contentsOf: endShape(cl[0], out: mul(tl, -1), n: mul(perp(tl), -1), hh: hh, left))
        return pts
    }

    static func straightBand(_ x0: CGFloat, _ x1: CGFloat, _ cy: CGFloat, _ hh: CGFloat, _ left: BannerEnd, _ right: BannerEnd) -> [CGPoint] {
        bandPoly([p(x0, cy), p(x1, cy)], [p(1, 0), p(1, 0)], hh: hh, left: left, right: right)
    }

    static func drawBanner(_ ctx: CGContext, _ style: BannerStyle, _ end: BannerEnd, _ solid: Bool, W: CGFloat, Hh: CGFloat,
                           text: String, c1: RGBA, c2: RGBA?) {
        guard W > 8, Hh > 4 else { return }
        let margin: CGFloat = Hh * 0.05
        let lwo: CGFloat = max(1, Hh * 0.035)
        let shade = c1.mixed(with: .black, 0.32)
        let tailCol = c1.mixed(with: .black, 0.14)
        let textCol: RGBA? = solid ? c2 : (c2 ?? c1)
        let cy: CGFloat = Hh / 2
        let txt = text.uppercased()

        func shape(_ pts: [CGPoint], _ col: RGBA) {
            let path = polyPath(pts, closed: true)
            if solid {
                fill(ctx, path, col)
            } else {
                erase(ctx, path)
                stroke(ctx, path, c1, lwo)
            }
        }

        switch style {
        case .forked:
            let hh: CGFloat = Hh * 0.3
            let drop: CGFloat = Hh * 0.3
            let mainCY: CGFloat = margin + hh + lwo * 0.5
            let tailCY: CGFloat = mainCY + drop
            let ext: CGFloat = extentOut(end, hh)
            let tailOuter: CGFloat = margin + lwo + ext
            let tl: CGFloat = min(Hh * 1.4, W * 0.22)
            let foldW: CGFloat = drop * 0.85
            let tailInner: CGFloat = tailOuter + tl
            let mainL: CGFloat = tailInner - foldW
            let mainR: CGFloat = W - mainL
            guard mainR - mainL > hh else { return }
            shape(straightBand(tailOuter, tailInner, tailCY, hh, end, .flat), tailCol)
            shape(straightBand(W - tailInner, W - tailOuter, tailCY, hh, .flat, end), tailCol)
            let mb: CGFloat = mainCY + hh
            shape([p(mainL, mb), p(mainL + foldW, mb), p(mainL + foldW, mb + drop)], shade)
            shape([p(mainR, mb), p(mainR - foldW, mb + drop), p(mainR - foldW, mb)], shade)
            shape(straightBand(mainL, mainR, mainCY, hh, .flat, .flat), c1)
            if !txt.isEmpty {
                drawTextBlock(ctx, [(txt, 1)], font: serifFont, center: p(W / 2, mainCY),
                              box: CGSize(width: mainR - mainL - hh * 0.8, height: hh * 2 * 0.6), color: textCol, tracking: 0.1)
            }
        case .straight:
            let hh: CGFloat = Hh * 0.38
            let xL: CGFloat = margin + lwo + extentOut(end, hh)
            shape(straightBand(xL, W - xL, cy, hh, end, end), c1)
            if !txt.isEmpty {
                drawTextBlock(ctx, [(txt, 1)], font: condensedFont, center: p(W / 2, cy),
                              box: CGSize(width: W - 2 * xL - hh * 0.6, height: hh * 1.25), color: textCol, tracking: 0.12)
            }
        case .curved:
            let hh: CGFloat = Hh * 0.25
            let sg: CGFloat = Hh * 0.28
            let apexY: CGFloat = margin + lwo + hh
            let hc: CGFloat = W / 2 - (margin + lwo + extentOut(end, hh) + hh * 0.3)
            guard hc > hh else { return }
            let Rc: CGFloat = (hc * hc + sg * sg) / (2 * sg)
            let O = p(W / 2, apexY + Rc)
            let phiM: CGFloat = min(1.2, asin(min(1, hc / Rc)))
            var cl: [CGPoint] = []
            var tans: [CGPoint] = []
            let steps = 72
            for i in 0...steps {
                let phi: CGFloat = -phiM + 2 * phiM * CGFloat(i) / CGFloat(steps)
                cl.append(p(O.x + Rc * sin(phi), O.y - Rc * cos(phi)))
                tans.append(p(cos(phi), sin(phi)))
            }
            shape(bandPoly(cl, tans, hh: hh, left: end, right: end), c1)
            if !txt.isEmpty {
                let arc: CGFloat = 2 * phiM * Rc - hh * 1.2
                drawArcText(ctx, txt, font: serifFont, center: O, radius: Rc, maxArc: arc, maxH: hh * 1.2,
                            color: textCol, tracking: 0.1)
            }
        case .tab:
            let hh: CGFloat = Hh * 0.4
            let xL: CGFloat = margin + lwo + extentOut(end, hh)
            shape(straightBand(xL, W - xL, cy, hh, end, end), c1)
            let hh2: CGFloat = hh * 0.76
            let d: CGFloat = hh - hh2
            let lineCol: RGBA? = solid ? c2 : c1
            paintStroke(ctx, polyPath(straightBand(xL + d, W - xL - d, cy, hh2, end, end), closed: true), lineCol,
                        max(1, Hh * 0.022))
            if !txt.isEmpty {
                drawTextBlock(ctx, [(txt, 1)], font: condensedFont, center: p(W / 2, cy),
                              box: CGSize(width: W - 2 * (xL + d) - hh2 * 0.8, height: hh2 * 1.2), color: textCol, tracking: 0.12)
            }
        case .bracket:
            let hh: CGFloat = Hh * 0.3
            let hb: CGFloat = hh * 1.35
            let g: CGFloat = Hh * 0.1
            let arm: CGFloat = Hh * 0.12
            let dotR: CGFloat = Hh * 0.06
            let gapDot: CGFloat = Hh * 0.06
            let xE: CGFloat = margin + lwo + dotR * 2 + gapDot + extentOut(end, hb) + g
            guard W - 2 * xE > hh * 2 else { return }
            shape(straightBand(xE, W - xE, cy, hh, end, end), c1)
            let brackets = CGMutablePath()
            let dots = CGMutablePath()
            for sideIndex in 0..<2 {
                let right = sideIndex == 1
                let out = right ? p(1, 0) : p(-1, 0)
                let n = right ? p(0, 1) : p(0, -1)
                let E = p(right ? W - xE : xE, cy)
                let Eb = add(E, mul(out, g))
                var poly: [CGPoint] = [at(Eb, n, -hb, out, -arm)]
                poly.append(contentsOf: endShape(Eb, out: out, n: n, hh: hb, end))
                poly.append(at(Eb, n, hb, out, -arm))
                brackets.addPath(polyPath(poly, closed: false))
                let dc = add(Eb, mul(out, extentOut(end, hb) + gapDot + dotR))
                dots.addEllipse(in: circleRect(dc, dotR))
            }
            stroke(ctx, brackets, c1, lwo * 1.1)
            fill(ctx, dots, c1)
            if !txt.isEmpty {
                drawTextBlock(ctx, [(txt, 1)], font: displayFont, center: p(W / 2, cy),
                              box: CGSize(width: W - 2 * xE - hh * 0.5, height: hh * 1.2), color: textCol, tracking: 0.1)
            }
        }
    }
}
