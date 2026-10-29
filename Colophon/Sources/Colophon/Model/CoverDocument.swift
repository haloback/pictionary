import CoreGraphics
import Foundation

enum Genre: String, Codable, CaseIterable, Identifiable {
    case thriller, mystery, horror, romance, fantasy, scienceFiction, literary, historical, youngAdult, cozy, nonfiction, memoir

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thriller: return "Thriller"
        case .mystery: return "Mystery & Crime"
        case .horror: return "Horror"
        case .romance: return "Romance"
        case .fantasy: return "Fantasy"
        case .scienceFiction: return "Science Fiction"
        case .literary: return "Literary Fiction"
        case .historical: return "Historical"
        case .youngAdult: return "Young Adult"
        case .cozy: return "Cozy & Women's Fiction"
        case .nonfiction: return "Nonfiction"
        case .memoir: return "Memoir"
        }
    }
}

struct BookInfo: Codable, Hashable {
    var title: String = ""
    var subtitle: String = ""
    var author: String = ""
    var series: String = ""
    var tagline: String = ""
    var genre: Genre = .literary
}

struct CanvasSpec: Codable, Hashable {
    var width: Int = 1600
    var height: Int = 2560

    /// height / width. Kindle's ideal is 1.6.
    var aspect: Double { Double(height) / Double(max(1, width)) }
    var size: CGSize { CGSize(width: width, height: height) }
}

enum BlendMode: String, Codable, CaseIterable, Identifiable {
    case normal, multiply, screen, overlay, softLight, hardLight, colorDodge, colorBurn
    case darken, lighten, difference, exclusion, hue, saturation, color, luminosity

    var id: String { rawValue }

    var cg: CGBlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .softLight: return .softLight
        case .hardLight: return .hardLight
        case .colorDodge: return .colorDodge
        case .colorBurn: return .colorBurn
        case .darken: return .darken
        case .lighten: return .lighten
        case .difference: return .difference
        case .exclusion: return .exclusion
        case .hue: return .hue
        case .saturation: return .saturation
        case .color: return .color
        case .luminosity: return .luminosity
        }
    }

    var label: String {
        switch self {
        case .softLight: return "Soft Light"
        case .hardLight: return "Hard Light"
        case .colorDodge: return "Color Dodge"
        case .colorBurn: return "Color Burn"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}

enum FadeEdge: String, Codable, CaseIterable, Identifiable {
    case none, top, bottom, left, right, topAndBottom, vignette
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .top: return "Fade Top"
        case .bottom: return "Fade Bottom"
        case .left: return "Fade Left"
        case .right: return "Fade Right"
        case .topAndBottom: return "Fade Top & Bottom"
        case .vignette: return "Soft Oval"
        }
    }
}

struct ShadowStyle: Codable, Hashable {
    var color = RGBA(0, 0, 0, 0.55)
    /// Blur radius as a fraction of canvas height.
    var radius: Double = 0.012
    var dx: Double = 0
    var dy: Double = 0.004
}

enum Cutout: String, Codable, CaseIterable, Identifiable {
    case none, subject, background
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Whole Image"
        case .subject: return "Subject Only"
        case .background: return "Background Only"
        }
    }
}

enum ShapeKind: String, Codable, CaseIterable, Identifiable {
    case rectangle, roundedRect, ellipse, arch, diamond, triangle, hexagon, rule, frame, diagonalBand, ring, chevron
    var id: String { rawValue }
    var label: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .roundedRect: return "Rounded Rectangle"
        case .ellipse: return "Circle / Oval"
        case .arch: return "Arch"
        case .diamond: return "Diamond"
        case .triangle: return "Triangle"
        case .hexagon: return "Hexagon"
        case .rule: return "Rule"
        case .frame: return "Frame"
        case .diagonalBand: return "Diagonal Band"
        case .ring: return "Ring"
        case .chevron: return "Chevron"
        }
    }
    var symbol: String {
        switch self {
        case .rectangle: return "rectangle"
        case .roundedRect: return "rectangle.roundedtop"
        case .ellipse: return "circle"
        case .arch: return "door.left.hand.closed"
        case .diamond: return "diamond"
        case .triangle: return "triangle"
        case .hexagon: return "hexagon"
        case .rule: return "minus"
        case .frame: return "square.dashed"
        case .diagonalBand: return "line.diagonal"
        case .ring: return "circle.circle"
        case .chevron: return "chevron.down"
        }
    }
    /// Shapes that make sense as a window to cut an image into.
    static let clipShapes: [ShapeKind] = [.rectangle, .roundedRect, .ellipse, .arch, .diamond, .hexagon, .triangle]
}

struct ImageContent: Codable, Hashable {
    var assetID: UUID
    var cutout: Cutout = .none
    /// 1 = aspect-fill the frame. Larger values crop in.
    var zoom: Double = 1
    /// Which part of the image stays visible when cropped (0...1).
    var focusX: Double = 0.5
    var focusY: Double = 0.5
    var flipped: Bool = false
    /// Brush touch-ups to the cutout (or plain erasing when the whole image shows).
    var maskEdits: [MaskStroke] = []

    init(assetID: UUID) {
        self.assetID = assetID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        assetID = try c.decode(UUID.self, forKey: .assetID)
        cutout = try c.decodeIfPresent(Cutout.self, forKey: .cutout) ?? .none
        zoom = try c.decodeIfPresent(Double.self, forKey: .zoom) ?? 1
        focusX = try c.decodeIfPresent(Double.self, forKey: .focusX) ?? 0.5
        focusY = try c.decodeIfPresent(Double.self, forKey: .focusY) ?? 0.5
        flipped = try c.decodeIfPresent(Bool.self, forKey: .flipped) ?? false
        maskEdits = try c.decodeIfPresent([MaskStroke].self, forKey: .maskEdits) ?? []
    }
}

struct NPoint: Codable, Hashable {
    var x: Double
    var y: Double
}

/// One brush stroke in image space (0...1, top-left origin).
struct MaskStroke: Codable, Hashable {
    /// true restores pixels, false erases them.
    var restore: Bool
    /// Brush radius as a fraction of the image's shorter side.
    var radius: Double
    var points: [NPoint]
}

enum PaperType: String, Codable, CaseIterable, Identifiable {
    case white, cream, color
    var id: String { rawValue }
    var label: String {
        switch self {
        case .white: return "White paper"
        case .cream: return "Cream paper"
        case .color: return "Premium color"
        }
    }
    /// Inches of spine per page (KDP's published per-page thickness).
    var inchesPerPage: Double {
        switch self {
        case .white: return 0.002252
        case .cream: return 0.0025
        case .color: return 0.002347
        }
    }
}

/// Settings for the printed paperback wraparound.
struct PrintSettings: Codable, Hashable {
    var trimWidth: Double = 6
    var trimHeight: Double = 9
    var pageCount: Int = 300
    var paper: PaperType = .cream
    var blurb: String = ""
    var quote: String = ""
    var keepBarcodeArea: Bool = true

    static let bleed = 0.125
    static let dpi = 300.0

    var spineWidth: Double { Double(pageCount) * paper.inchesPerPage }
    /// KDP allows spine text from 80 pages; thinner spines can't hold it reliably.
    var spineHasText: Bool { pageCount >= 80 }
    var fullWidth: Double { 2 * trimWidth + spineWidth + 2 * PrintSettings.bleed }
    var fullHeight: Double { trimHeight + 2 * PrintSettings.bleed }

    static let trims: [(String, Double, Double)] = [
        ("5 x 8 in", 5, 8), ("5.25 x 8 in", 5.25, 8), ("5.5 x 8.5 in", 5.5, 8.5),
        ("6 x 9 in", 6, 9), ("7 x 10 in", 7, 10), ("8.5 x 11 in", 8.5, 11)
    ]
}

enum FillStyle: String, Codable, CaseIterable, Identifiable {
    case solid, linear, radial, meshBlend, paintSmear, watercolor, smoke, marble, grain
    case sunburst, stripes, bokeh, starfield, bauhaus, goldenBlocks, halftone, scrim

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solid: return "Solid"
        case .linear: return "Linear Blend"
        case .radial: return "Radial Glow"
        case .meshBlend: return "Mesh Blend"
        case .paintSmear: return "Paint Smear"
        case .watercolor: return "Watercolor"
        case .smoke: return "Smoke"
        case .marble: return "Marble"
        case .grain: return "Grained Color"
        case .sunburst: return "Sunburst"
        case .stripes: return "Stripes"
        case .bokeh: return "Bokeh"
        case .starfield: return "Starfield"
        case .bauhaus: return "Bauhaus Shapes"
        case .goldenBlocks: return "Golden Blocks"
        case .halftone: return "Halftone"
        case .scrim: return "Legibility Scrim"
        }
    }
}

struct FillContent: Codable, Hashable {
    var style: FillStyle
    var colors: [RGBA]
    /// Direction in degrees. 90 points down (darker at the bottom for scrims).
    var angle: Double = 90
    var seed: Int = 7
    /// Style-specific amount: smear length, stripe width, scrim strength...
    var intensity: Double = 0.5
}

struct ShapeContent: Codable, Hashable {
    var kind: ShapeKind
    var fill: RGBA?
    var stroke: RGBA?
    /// Stroke width as a fraction of canvas width.
    var strokeWidth: Double = 0.004
    /// Corner radius as a fraction of the shorter side.
    var cornerRadius: Double = 0.08
}

enum TextRole: String, Codable, CaseIterable, Identifiable {
    case title, subtitle, author, series, tagline, custom
    var id: String { rawValue }
    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    /// Contrast a role needs: titles are large type (3:1), small lines need 4.5:1.
    var minimumContrast: Double {
        switch self {
        case .title: return 3.0
        default: return 4.5
        }
    }
}

enum TextAlign: String, Codable, CaseIterable, Identifiable {
    case left, center, right
    var id: String { rawValue }
}

enum LetterCase: String, Codable, CaseIterable, Identifiable {
    case asTyped, upper, lower, title
    var id: String { rawValue }
    var label: String {
        switch self {
        case .asTyped: return "As Typed"
        case .upper: return "UPPERCASE"
        case .lower: return "lowercase"
        case .title: return "Title Case"
        }
    }
}

struct TextContent: Codable, Hashable {
    var text: String
    var role: TextRole = .custom
    var fontName: String = "Didot"
    /// Used when autoFit is off: font size as a fraction of canvas height.
    var fontSize: Double = 0.05
    /// Scale the type to fill its frame exactly.
    var autoFit: Bool = true
    /// Letter spacing in ems.
    var tracking: Double = 0
    /// Baseline-to-baseline distance in ems.
    var lineHeight: Double = 1.04
    var alignment: TextAlign = .center
    var letterCase: LetterCase = .asTyped
    var color: RGBA = .nearWhite
    var gradientTo: RGBA?
    var strokeColor: RGBA?
    /// Stroke width as a fraction of the font size.
    var strokeWidth: Double = 0.025
    var glowColor: RGBA?
    /// Glow radius as a fraction of the font size.
    var glowRadius: Double = 0.25
    /// Re-draws the photo's subject over the text so the type sits behind it.
    var behindSubject: Bool = false
    /// A genre finish: metal foils, distressed print, neon...
    var texture: TextTexture = .none
    /// Bends each line along an arc. Positive arches up, negative sags down; 1 is a half circle.
    var arc: Double = 0
}

extension TextContent {
    // Declared in an extension so the memberwise initializer stays available.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(text: try c.decode(String.self, forKey: .text))
        role = try c.decodeIfPresent(TextRole.self, forKey: .role) ?? .custom
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName) ?? "Didot"
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 0.05
        autoFit = try c.decodeIfPresent(Bool.self, forKey: .autoFit) ?? true
        tracking = try c.decodeIfPresent(Double.self, forKey: .tracking) ?? 0
        lineHeight = try c.decodeIfPresent(Double.self, forKey: .lineHeight) ?? 1.04
        alignment = try c.decodeIfPresent(TextAlign.self, forKey: .alignment) ?? .center
        letterCase = try c.decodeIfPresent(LetterCase.self, forKey: .letterCase) ?? .asTyped
        color = try c.decodeIfPresent(RGBA.self, forKey: .color) ?? .nearWhite
        gradientTo = try c.decodeIfPresent(RGBA.self, forKey: .gradientTo)
        strokeColor = try c.decodeIfPresent(RGBA.self, forKey: .strokeColor)
        strokeWidth = try c.decodeIfPresent(Double.self, forKey: .strokeWidth) ?? 0.025
        glowColor = try c.decodeIfPresent(RGBA.self, forKey: .glowColor)
        glowRadius = try c.decodeIfPresent(Double.self, forKey: .glowRadius) ?? 0.25
        behindSubject = try c.decodeIfPresent(Bool.self, forKey: .behindSubject) ?? false
        texture = try c.decodeIfPresent(TextTexture.self, forKey: .texture) ?? .none
        arc = try c.decodeIfPresent(Double.self, forKey: .arc) ?? 0
    }
}

enum TextTexture: String, Codable, CaseIterable, Identifiable {
    case none, gold, silver, roseGold, copper, neon, distressed, wornPrint, chalk

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Flat Color"
        case .gold: return "Gold Foil"
        case .silver: return "Silver Foil"
        case .roseGold: return "Rose Gold"
        case .copper: return "Copper"
        case .neon: return "Neon"
        case .distressed: return "Distressed"
        case .wornPrint: return "Worn Print"
        case .chalk: return "Chalk"
        }
    }

    /// The genres each finish is at home in, for suggestions.
    static func suggested(for g: Genre) -> TextTexture {
        switch g {
        case .thriller, .horror, .mystery: return .distressed
        case .fantasy, .historical: return .gold
        case .scienceFiction: return .neon
        case .romance, .cozy: return .roseGold
        case .youngAdult: return .neon
        case .literary, .memoir: return .wornPrint
        case .nonfiction: return .silver
        }
    }

    /// Metal ramps, top to bottom, with a bright band just above the middle.
    var metalStops: [RGBA]? {
        switch self {
        case .gold: return ["7A5A16", "C99A3B", "FFF1C1", "B8862B", "E7C877", "6E4F12"].map { RGBA(hex: $0) }
        case .silver: return ["5E6369", "B9BEC4", "FAFBFC", "8D9399", "D7DBDF", "4E5358"].map { RGBA(hex: $0) }
        case .roseGold: return ["8A4B45", "D99A8F", "FFE3DC", "B8706A", "F0C0B5", "7A3F3A"].map { RGBA(hex: $0) }
        case .copper: return ["5C2E14", "B8693A", "FFD2AE", "9A4F24", "D99060", "4A230E"].map { RGBA(hex: $0) }
        default: return nil
        }
    }
}

enum LayerContent: Codable, Hashable {
    case image(ImageContent)
    case fill(FillContent)
    case shape(ShapeContent)
    case text(TextContent)
}

struct EffectInstance: Codable, Hashable, Identifiable {
    var id = UUID()
    var presetID: String
    var amount: Double = 1
}

/// Photo-style corrections. Each runs from -1 to 1; 0 leaves the layer untouched.
struct Adjustments: Codable, Hashable {
    var exposure: Double = 0
    var contrast: Double = 0
    var saturation: Double = 0
    var warmth: Double = 0
    var sharpness: Double = 0
    var blur: Double = 0

    var isIdentity: Bool { self == Adjustments() }
}

struct Layer: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var content: LayerContent
    var frame: NRect = .full
    var rotation: Double = 0
    var opacity: Double = 1
    var blend: BlendMode = .normal
    var isVisible: Bool = true
    var isLocked: Bool = false
    /// Cut the layer into a shape: arch windows, circular medallions, diamonds...
    var clipShape: ShapeKind?
    var fade: FadeEdge = .none
    var fadeAmount: Double = 0.35
    var shadow: ShadowStyle?
    var effects: [EffectInstance] = []
    var adjust = Adjustments()

    init(id: UUID = UUID(), name: String, content: LayerContent, frame: NRect = .full) {
        self.id = id
        self.name = name
        self.content = content
        self.frame = frame
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Layer"
        content = try c.decode(LayerContent.self, forKey: .content)
        frame = try c.decodeIfPresent(NRect.self, forKey: .frame) ?? .full
        rotation = try c.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        blend = try c.decodeIfPresent(BlendMode.self, forKey: .blend) ?? .normal
        isVisible = try c.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        clipShape = try c.decodeIfPresent(ShapeKind.self, forKey: .clipShape)
        fade = try c.decodeIfPresent(FadeEdge.self, forKey: .fade) ?? .none
        fadeAmount = try c.decodeIfPresent(Double.self, forKey: .fadeAmount) ?? 0.35
        shadow = try c.decodeIfPresent(ShadowStyle.self, forKey: .shadow)
        effects = try c.decodeIfPresent([EffectInstance].self, forKey: .effects) ?? []
        adjust = try c.decodeIfPresent(Adjustments.self, forKey: .adjust) ?? Adjustments()
    }

    var textContent: TextContent? {
        get { if case .text(let t) = content { return t }; return nil }
        set { if let n = newValue { content = .text(n) } }
    }

    var imageContent: ImageContent? {
        get { if case .image(let i) = content { return i }; return nil }
        set { if let n = newValue { content = .image(n) } }
    }

    var fillContent: FillContent? {
        get { if case .fill(let f) = content { return f }; return nil }
        set { if let n = newValue { content = .fill(n) } }
    }

    var shapeContent: ShapeContent? {
        get { if case .shape(let s) = content { return s }; return nil }
        set { if let n = newValue { content = .shape(n) } }
    }

    var kindSymbol: String {
        switch content {
        case .image(let i): return i.cutout == .subject ? "person.crop.rectangle" : "photo"
        case .fill: return "paintbrush.pointed"
        case .shape(let s): return s.kind.symbol
        case .text: return "textformat"
        }
    }

    var kindLabel: String {
        switch content {
        case .image: return "Image"
        case .fill(let f): return f.style.label
        case .shape(let s): return s.kind.label
        case .text(let t): return t.role.label
        }
    }

    static func text(_ text: String, role: TextRole, frame: NRect, font: String, color: RGBA) -> Layer {
        Layer(name: role.label, content: .text(TextContent(text: text, role: role, fontName: font, color: color)), frame: frame)
    }

    static func image(_ id: UUID, frame: NRect = .full, name: String = "Photo") -> Layer {
        Layer(name: name, content: .image(ImageContent(assetID: id)), frame: frame)
    }

    static func fill(_ style: FillStyle, colors: [RGBA], frame: NRect = .full, angle: Double = 90, seed: Int = 7, intensity: Double = 0.5) -> Layer {
        Layer(name: style.label, content: .fill(FillContent(style: style, colors: colors, angle: angle, seed: seed, intensity: intensity)), frame: frame)
    }

    static func shape(_ kind: ShapeKind, fill: RGBA?, stroke: RGBA? = nil, strokeWidth: Double = 0.004, frame: NRect) -> Layer {
        Layer(name: kind.label, content: .shape(ShapeContent(kind: kind, fill: fill, stroke: stroke, strokeWidth: strokeWidth)), frame: frame)
    }
}

struct CoverDocument: Codable {
    var version: Int = 1
    var book = BookInfo()
    var canvas = CanvasSpec()
    var background = RGBA.ink
    /// Bottom to top.
    var layers: [Layer] = []
    /// Encoded images keyed by UUID string. Imports are downsampled to 4000px.
    var assets: [String: Data] = [:]
    /// Order of imported images, so "the first photo" is stable.
    var assetOrder: [UUID] = []
    /// The colors this design is built from.
    var palette: [RGBA] = []
    var archetypeName: String = ""
    /// Font files the user imported, keyed by PostScript name, so the project opens anywhere.
    var fonts: [String: Data] = [:]
    var paperback = PrintSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        book = try c.decodeIfPresent(BookInfo.self, forKey: .book) ?? BookInfo()
        canvas = try c.decodeIfPresent(CanvasSpec.self, forKey: .canvas) ?? CanvasSpec()
        background = try c.decodeIfPresent(RGBA.self, forKey: .background) ?? .ink
        layers = try c.decodeIfPresent([Layer].self, forKey: .layers) ?? []
        assets = try c.decodeIfPresent([String: Data].self, forKey: .assets) ?? [:]
        assetOrder = try c.decodeIfPresent([UUID].self, forKey: .assetOrder) ?? []
        palette = try c.decodeIfPresent([RGBA].self, forKey: .palette) ?? []
        archetypeName = try c.decodeIfPresent(String.self, forKey: .archetypeName) ?? ""
        fonts = try c.decodeIfPresent([String: Data].self, forKey: .fonts) ?? [:]
        paperback = try c.decodeIfPresent(PrintSettings.self, forKey: .paperback) ?? PrintSettings()
    }

    func assetData(_ id: UUID) -> Data? { assets[id.uuidString] }

    mutating func addAsset(_ data: Data) -> UUID {
        let id = UUID()
        assets[id.uuidString] = data
        assetOrder.append(id)
        return id
    }

    func index(of id: UUID) -> Int? { layers.firstIndex { $0.id == id } }

    func layer(_ id: UUID?) -> Layer? {
        guard let id else { return nil }
        return layers.first { $0.id == id }
    }

    func textLayer(role: TextRole) -> Layer? {
        layers.last { $0.textContent?.role == role }
    }

    /// Image layers that are the "main photo" (not cutouts), bottom first.
    var photoLayers: [Layer] {
        layers.filter { $0.imageContent != nil && $0.imageContent?.cutout == Cutout.none }
    }
}
