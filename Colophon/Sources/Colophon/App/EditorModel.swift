import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var colophonProject: UTType { UTType(filenameExtension: "colophon", conformingTo: .json) ?? .json }
}

struct Variation: Identifiable {
    let id = UUID()
    var document: CoverDocument
    var thumbnail: CGImage?
    var favorite = false
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case layer = "Layer", effects = "Effects", color = "Color", ideas = "Ideas", check = "Check", book = "Book"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .layer: return "slider.horizontal.3"
        case .effects: return "wand.and.stars"
        case .color: return "paintpalette"
        case .ideas: return "lightbulb"
        case .check: return "checkmark.seal"
        case .book: return "book.closed"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

struct CompareRef: Identifiable {
    let id = UUID()
    var name: String
    var image: CGImage
}

enum CanvasTool: String {
    case select, erase, restore, paint, smudge, blend, lift
    /// Paint over something in a photo to have it filled in from the surroundings.
    case remove

    var paintTool: PaintTool? {
        switch self {
        case .paint: return .paint
        case .smudge: return .smudge
        case .blend: return .blend
        case .lift: return .lift
        default: return nil
        }
    }
}

enum LayerAlign {
    case left, centerX, right, top, middle, bottom
}

enum GuideStyle: String, CaseIterable, Identifiable {
    case golden = "Golden Section", thirds = "Rule of Thirds", spiral = "Golden Spiral", safe = "Safe Area Only"
    var id: String { rawValue }
}

@MainActor
@Observable
final class EditorModel {
    enum Screen { case start, variations, editor }

    var screen: Screen = .start
    var document = CoverDocument()
    var selection: UUID?
    var fileURL: URL?
    var isDirty = false

    var preview: CGImage?
    var revision = 0
    var showGuides = true
    var guideStyle: GuideStyle = .golden
    var showInspector = true
    var inspectorTab: InspectorTab = .layer
    var showExport = false
    var showThumbnailPreview = true
    var activeSnapLines: (x: [Double], y: [Double]) = ([], [])

    var variations: [Variation] = []
    var isGenerating = false
    var variationCount = 24

    var targetStoreID = "kdp"
    var preflight: [PreflightIssue] = []
    var suggestions: [Suggestion] = []
    /// The art director's score for the cover as it stands.
    var critique: CriticReport?
    /// What the local taste model (CLIP) makes of the cover, when it's installed.
    var taste: TasteReport?
    /// Where readers look first, drawn over the canvas when `showAttention` is on.
    var showAttention = false
    var attentionMap: CGImage?
    var insightBackground: CGImage?
    var isAnalyzing = false

    var effectBase: CGImage?
    var effectBaseVersion = 0
    var toast: String?

    var showFavoritesOnly = false
    var showPaperback = false
    var tool: CanvasTool = .select
    /// Brush diameter as a fraction of the cover's width.
    var brushSize: Double = 0.05
    /// Strokes painted with the Remove tool (image space of `removalLayerID`), not yet applied.
    var removalStrokes: [MaskStroke] = []
    var removalLayerID: UUID?
    /// True while an object removal is being computed.
    var isRemoving = false
    var isRemix = false

    var showCompare = false
    var showShortcuts = false
    var compareRefs: [CompareRef] = []
    var recentFiles: [URL] = (UserDefaults.standard.stringArray(forKey: "recentFiles") ?? []).compactMap { URL(string: $0) }
    var appearance: AppAppearance = AppAppearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .system

    func setAppearance(_ a: AppAppearance) {
        appearance = a
        UserDefaults.standard.set(a.rawValue, forKey: "appearance")
        NSApp.appearance = a.nsAppearance
    }
    /// A recovered cover from a session that ended without saving.
    var recoveryAvailable = FileManager.default.fileExists(atPath: EditorModel.recoveryURL.path)
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?
    var showSeries = false
    var showMaterialBackground = false
    var paintColor = RGBA(hex: "2A3B9E")
    var randomLocks: Set<RandomAspect> = []
    var randomCreativity = 0.35
    var showSaveTemplate = false
    @ObservationIgnored var recentRecipes: [Int] = []
    var paintStrength = 0.7
    var paintWetness = 0.4
    var showDecor: DecorLibrary.Kind?
    var showIllustrations = false
    var showTemplates = false
    var showFonts = false
    var copiedTextStyle: TextContent?
    /// Snapshots of everything tried this session, for the Versions strip.
    let versions = VersionHistory()
    var showVersions = true
    @ObservationIgnored private var lastSnapshotTime = Date.distantPast
    /// Ordinary edits are snapshotted at most this often.
    static let editSnapshotInterval: TimeInterval = 25

    @ObservationIgnored private var undoStack: [CoverDocument] = []
    @ObservationIgnored private var redoStack: [CoverDocument] = []
    @ObservationIgnored private var lastUndoKey: String?
    @ObservationIgnored private var lastUndoTime = Date.distantPast
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private var insightTask: Task<Void, Never>?
    @ObservationIgnored private var effectBaseTask: Task<Void, Never>?
    @ObservationIgnored var previewHeight: CGFloat = 1280

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var selectedLayer: Layer? { document.layer(selection) }
    var targetStore: StoreSpec { StoreSpec.spec(targetStoreID) }

    // MARK: Mutation & undo

    func mutate(undoKey: String? = nil, _ change: (inout CoverDocument) -> Void) {
        let now = Date()
        if undoKey == nil || undoKey != lastUndoKey || now.timeIntervalSince(lastUndoTime) > 1.2 {
            undoStack.append(document)
            if undoStack.count > 200 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
        lastUndoKey = undoKey
        lastUndoTime = now
        change(&document)
        documentChanged()
        if now.timeIntervalSince(lastSnapshotTime) > EditorModel.editSnapshotInterval { snapshot(reason: "Edit") }
    }

    // MARK: Versions

    /// Records the cover as it stands in the Versions strip (skipped when the design hasn't changed).
    func snapshot(reason: String) {
        if versions.add(document, reason: reason, score: critique?.score) { lastSnapshotTime = Date() }
    }

    /// Brings a version back as the current cover (undoable).
    func restoreVersion(_ id: UUID) {
        guard let v = versions.version(id) else { return }
        let keepSelection = selection
        lastSnapshotTime = Date()
        mutate { d in d = v.document }
        selection = keepSelection.flatMap { id in document.layer(id) != nil ? id : nil }
        for f in v.document.fonts.values { FontCatalog.register(f) }
        toast = "Restored \(v.reason)"
    }

    /// Puts a version beside the current cover in the Compare sheet.
    func compareVersion(_ id: UUID) {
        guard let v = versions.version(id), let img = v.thumbnail else { return }
        compareRefs.removeAll { $0.name == "Version: \(v.reason)" }
        compareRefs.append(CompareRef(name: "Version: \(v.reason)", image: img))
        showCompare = true
    }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(document)
        document = prev
        lastUndoKey = nil
        if let s = selection, document.layer(s) == nil { selection = nil }
        documentChanged()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(document)
        document = next
        lastUndoKey = nil
        documentChanged()
    }

    private func documentChanged() {
        revision += 1
        isDirty = true
        scheduleRender()
        scheduleInsights()
    }

    func layerBinding(_ id: UUID) -> Binding<Layer> {
        Binding(
            get: { self.document.layer(id) ?? Layer(name: "", content: .shape(ShapeContent(kind: .rectangle))) },
            set: { new in
                self.mutate(undoKey: "layer-\(id)") { d in
                    if let i = d.index(of: id) { d.layers[i] = new }
                }
            })
    }

    var bookBinding: Binding<BookInfo> {
        Binding(get: { self.document.book }, set: { new in self.updateBook(new) })
    }

    /// Keeps text layers in sync with the brief.
    func updateBook(_ b: BookInfo) {
        let old = document.book
        mutate(undoKey: "book") { d in BookSync.apply(b, old: old, to: &d) }
    }

    // MARK: Back cover blurb

    var isDraftingBlurb = false

    /// Drafts back-cover copy from the synopsis (on device) and writes it into `book.blurb`.
    func draftBlurb(tone: BlurbWriter.Tone) {
        guard !isDraftingBlurb else { return }
        let book = document.book
        guard BlurbWriter.wordCount(book.synopsis) >= 30 else {
            toast = "Write a synopsis of at least 30 words first"
            return
        }
        isDraftingBlurb = true
        Task { @MainActor in
            let text = await BlurbWriter.draft(book: book, synopsis: book.synopsis, tone: tone)
            var updated = document.book
            updated.blurb = text
            updateBook(updated)
            isDraftingBlurb = false
            toast = BlurbWriter.usesOnDeviceModel ? "Blurb drafted with the on-device model" : "Blurb drafted from your synopsis"
        }
    }

    // MARK: Rendering

    func scheduleRender() {
        renderTask?.cancel()
        let doc = document
        let h = previewHeight
        let size = CGSize(width: (h / CGFloat(doc.canvas.aspect)).rounded(), height: h)
        renderTask = Task.detached(priority: .userInitiated) { [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000)
            if Task.isCancelled { return }
            let img = CoverRenderer.shared.render(doc, size: size, quality: .preview)
            if Task.isCancelled { return }
            await self?.setPreview(img)
        }
    }

    private func setPreview(_ img: CGImage?) { preview = img }

    func scheduleInsights() {
        insightTask?.cancel()
        guard screen == .editor else { return }
        let doc = document
        let spec = targetStore
        let wantHeat = showAttention
        insightTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            if Task.isCancelled { return }
            let bg = Polisher.backgroundSample(doc)
            let full = CoverRenderer.shared.render(doc, size: CGSize(width: 200, height: (200 * doc.canvas.aspect).rounded()), quality: .preview)
            let issues = Preflight.run(doc, spec: spec, background: bg, full: full)
            let ideas = SuggestionEngine.suggestions(for: doc, background: bg)
            let verdict = Critic.review(doc, background: bg)
            let flavor = TasteEngine.shared.isReady ? TasteEngine.shared.taste(of: doc) : nil
            let heat: CGImage? = wantHeat ? Critic.renderedForAttention(doc).flatMap { VisionServices.attention(for: $0)?.heat } : nil
            if Task.isCancelled { return }
            await self?.setInsights(issues, ideas, bg, verdict, flavor, heat)
        }
    }

    private func setInsights(_ issues: [PreflightIssue], _ ideas: [Suggestion], _ bg: CGImage?, _ verdict: CriticReport, _ flavor: TasteReport?, _ heat: CGImage?) {
        preflight = issues
        suggestions = ideas
        insightBackground = bg
        critique = verdict
        taste = flavor
        attentionMap = heat
    }

    /// Downloads the taste model (about 280 MB, once) and re-reads the cover with it.
    func installTaste() {
        Task { @MainActor in
            do {
                try await TasteEngine.shared.install()
                toast = "Taste model ready"
                scheduleInsights()
            } catch {
                toast = "Taste model: \(error.localizedDescription)"
            }
        }
    }

    /// The mood the brief gives off, for palette and genre hints in the Book panel.
    var briefMood: BriefMood.Mood {
        BriefMood.analyze(title: document.book.title, subtitle: document.book.subtitle, tagline: document.book.tagline)
    }

    func applyPalette(_ colors: [RGBA], name: String) {
        mutate { d in d.palette = colors }
        toast = "Palette: \(name)"
    }

    func refreshEffectBase() {
        effectBaseTask?.cancel()
        let doc = document
        let target = effectTarget
        effectBaseTask = Task.detached(priority: .utility) { [weak self] in
            let size = CGSize(width: 150, height: (150 * doc.canvas.aspect).rounded())
            var img: CGImage?
            if let t = target, var l = doc.layer(t) {
                l.effects = []
                l.frame = .full
                l.clipShape = nil
                l.fade = .none
                img = CoverRenderer.shared.rasterize(l, doc: doc, canvas: size, quality: .preview)?.image
            }
            if img == nil { img = CoverRenderer.shared.render(doc, size: size) }
            await self?.setEffectBase(img)
        }
    }

    private func setEffectBase(_ img: CGImage?) {
        effectBase = img
        effectBaseVersion += 1
    }

    /// Where a clicked effect goes: the selection, else the main photo, else the bottom layer.
    var effectTarget: UUID? {
        if let s = selection, document.layer(s) != nil { return s }
        return document.photoLayers.first?.id ?? document.layers.first?.id
    }

    // MARK: Start & variations

    func importImages(_ urls: [URL]) {
        let imageURLs = urls.filter { url in
            guard let t = UTType(filenameExtension: url.pathExtension) else { return false }
            return t.conforms(to: .image)
        }
        guard !imageURLs.isEmpty else { return }
        Task.detached(priority: .userInitiated) { [weak self] in
            for url in imageURLs {
                guard let data = AssetStore.importData(from: url) else { continue }
                await self?.addAsset(data)
            }
        }
    }

    private func addAsset(_ data: Data) {
        let id = document.addAsset(data)
        revision += 1
        let d = data
        Task.detached(priority: .utility) { AssetStore.shared.warm(id, data: d) }
        if screen == .editor {
            mutate { doc in
                var l = Layer.image(id)
                l.name = "Photo"
                let insertAt = doc.layers.firstIndex { $0.textContent != nil } ?? doc.layers.count
                doc.layers.insert(l, at: insertAt)
            }
            selection = document.layers.first { $0.imageContent?.assetID == id }?.id
        }
    }

    func removeAsset(_ id: UUID) {
        document.assets[id.uuidString] = nil
        document.assetOrder.removeAll { $0 == id }
        revision += 1
    }

    func generateVariations(only archetype: Archetype? = nil) {
        isGenerating = true
        isRemix = false
        screen = .variations
        variations = []
        var base = document
        base.layers = []
        let count = archetype == nil ? variationCount : 8
        let seed = Int.random(in: 1...999_999)
        Task.detached(priority: .userInitiated) { [weak self, base] in
            let docs = CoverComposer.variations(base: base, count: count, seed: seed, only: archetype)
            let items = docs.map { Variation(document: $0, thumbnail: nil) }
            await self?.setVariations(items)
            for item in items {
                let doc = item.document
                let img = CoverRenderer.shared.render(doc, size: CGSize(width: 360, height: (360 * doc.canvas.aspect).rounded()), quality: .preview)
                await self?.setThumbnail(item.id, img)
            }
            await self?.finishGenerating()
        }
    }

    private func setVariations(_ v: [Variation]) { variations = v }
    private func finishGenerating() { isGenerating = false }
    private func setThumbnail(_ id: UUID, _ img: CGImage?) {
        if let i = variations.firstIndex(where: { $0.id == id }) { variations[i].thumbnail = img }
    }

    /// Variations of the cover being edited: same layout and edits, new decisions.
    func remixCurrent() {
        guard !document.layers.isEmpty else { return }
        isGenerating = true
        isRemix = true
        screen = .variations
        let base = document
        let seed = Int.random(in: 1...999_999)
        variations = [Variation(document: { var d = base; d.archetypeName = "Your current cover"; return d }(), thumbnail: preview)]
        Task.detached(priority: .userInitiated) { [weak self] in
            let docs = Remixer.remix(base, count: 11, seed: seed)
            let items = docs.map { Variation(document: $0, thumbnail: nil) }
            await self?.appendVariations(items)
            for item in items {
                let doc = item.document
                let img = CoverRenderer.shared.render(doc, size: CGSize(width: 360, height: (360 * doc.canvas.aspect).rounded()), quality: .preview)
                await self?.setThumbnail(item.id, img)
            }
            await self?.finishGenerating()
        }
    }

    private func appendVariations(_ v: [Variation]) { variations.append(contentsOf: v) }

    func adopt(_ v: Variation) {
        if screen == .editor || !document.layers.isEmpty { undoStack.append(document) }
        document = v.document
        selection = document.textLayer(role: .title)?.id
        screen = .editor
        documentChanged()
        refreshEffectBase()
        snapshot(reason: "Started")
    }

    func startBlank() {
        mutate { d in
            let p = PaletteRoles(d.palette.isEmpty ? GenreStyle.of(d.book.genre).moods[0] : d.palette)
            d.palette = p.colors
            var bg = Layer.fill(.meshBlend, colors: [p.dark, p.accent.withLightness(0.3), p.dominant.withLightness(0.25)], seed: 11, intensity: 0.6)
            bg.name = "Background"
            d.layers = [bg]
            for id in d.assetOrder { d.layers.append(.image(id)) }
            let t = GenreStyle.of(d.book.genre).treatments[0]
            var title = Layer.text(TitleBreaker.auto(d.book.title.isEmpty ? "Untitled" : d.book.title, stacked: t.stacked), role: .title, frame: NRect(0.075, 0.08, 0.85, 0.3), font: t.titleFont, color: p.light)
            title.textContent?.letterCase = t.titleCase
            title.textContent?.tracking = t.titleTracking
            title.name = "Title"
            d.layers.append(title)
            var author = Layer.text(d.book.author.isEmpty ? "Author Name" : d.book.author, role: .author, frame: NRect(0.1, 0.885, 0.8, 0.05), font: t.authorFont, color: p.light)
            author.textContent?.letterCase = .upper
            author.textContent?.tracking = 0.25
            author.name = "Author"
            d.layers.append(author)
            d.background = p.dark
        }
        screen = .editor
        selection = document.textLayer(role: .title)?.id
        snapshot(reason: "Started")
    }

    func newProject() {
        guard confirmDiscard() else { return }
        document = CoverDocument()
        fileURL = nil
        selection = nil
        variations = []
        undoStack = []
        redoStack = []
        isDirty = false
        preview = nil
        versions.clear()
        screen = .start
    }

    // MARK: Layers

    func addText(role: TextRole = .custom) {
        let p = PaletteRoles(document.palette)
        var l = Layer.text(role == .custom ? "Your words" : role.label, role: role, frame: NRect(0.15, 0.45, 0.7, 0.08),
                           font: GenreStyle.of(document.book.genre).treatments[0].authorFont, color: p.light)
        l.textContent?.tracking = 0.1
        insertAboveSelection(l)
    }

    func addShape(_ kind: ShapeKind) {
        let p = PaletteRoles(document.palette)
        let isOutline = kind == .frame || kind == .ring
        let frame: NRect = kind == .rule ? NRect(0.4, 0.5, 0.2, 0.003) : (kind == .frame ? NRect(0.05, 0.05 / document.canvas.aspect * 1.0, 0.9, 1 - 0.1 / document.canvas.aspect) : NRect(0.3, 0.4, 0.4, 0.4 / document.canvas.aspect))
        insertAboveSelection(.shape(kind, fill: isOutline ? nil : p.accent, stroke: isOutline ? p.accent : nil, strokeWidth: 0.004, frame: frame))
    }

    func addFill(_ style: FillStyle) {
        let p = PaletteRoles(document.palette)
        var l = Layer.fill(style, colors: style == .scrim ? [p.dark] : [p.dark, p.accent, p.dominant, p.light], seed: Int.random(in: 1...99_999))
        if style == .scrim { l.frame = NRect(0, 0.5, 1, 0.5) }
        // Grounds go to the bottom, scrims under the type, overlays above the photo.
        mutate { d in
            switch style {
            case .scrim:
                let i = d.layers.firstIndex { $0.textContent != nil } ?? d.layers.count
                d.layers.insert(l, at: i)
            default:
                d.layers.insert(l, at: 0)
            }
        }
        selection = l.id
    }

    // MARK: Painting

    @ObservationIgnored private var paintKey = ""
    @ObservationIgnored private var paintLayerID: UUID?

    /// The paint layer strokes go to: the selected one, or a new one. Smudge, blend and lift on a cover without
    /// paint start from a copy of the artwork, so they move the photo's own colors.
    private func paintTarget(for tool: PaintTool) -> UUID? {
        if let l = selectedLayer, l.paintContent != nil { return l.id }
        if tool == .paint, let top = document.layers.last(where: { $0.paintContent != nil }) { return top.id }
        var content = PaintContent()
        if tool != .paint {
            var art = document
            art.layers.removeAll { $0.textContent != nil || $0.decorContent != nil }
            let h: CGFloat = 1400
            if let img = CoverRenderer.shared.render(art, size: CGSize(width: (h / CGFloat(document.canvas.aspect)).rounded(), height: h), quality: .full),
               let data = AssetStore.encode(img) {
                var id = UUID()
                mutate { d in id = d.addAsset(data) }
                content.baseAssetID = id
            }
        }
        var l = Layer(name: tool == .paint ? "Paint" : "Smudged Artwork", content: .paint(content), frame: .full)
        l.name = tool == .paint ? "Paint" : "Smudged Artwork"
        mutate { d in
            let i = d.layers.firstIndex { $0.textContent != nil || $0.decorContent != nil } ?? d.layers.count
            d.layers.insert(l, at: i)
        }
        selection = l.id
        return l.id
    }

    func beginPaintStroke(_ tool: PaintTool, canvasX: Double, canvasY: Double) {
        guard let id = paintTarget(for: tool) else { return }
        paintLayerID = id
        paintKey = "paint-\(UUID().uuidString)"
        let stroke = PaintStroke(tool: tool, color: paintColor, size: brushSize, strength: paintStrength, wetness: paintWetness,
                                 points: [NPoint(x: canvasX, y: canvasY)])
        mutate(undoKey: paintKey) { d in
            if let i = d.index(of: id) { d.layers[i].paintContent?.strokes.append(stroke) }
        }
    }

    func extendPaintStroke(canvasX: Double, canvasY: Double) {
        guard let id = paintLayerID, let l = document.layer(id), let last = l.paintContent?.strokes.last?.points.last else { return }
        guard hypot(canvasX - last.x, canvasY - last.y) > brushSize * 0.08 else { return }
        mutate(undoKey: paintKey) { d in
            guard let i = d.index(of: id), let n = d.layers[i].paintContent?.strokes.count, n > 0 else { return }
            d.layers[i].paintContent?.strokes[n - 1].points.append(NPoint(x: canvasX, y: canvasY))
        }
    }

    // MARK: Smart randomize and saved templates

    /// Re-rolls the unlocked parts of the cover (undoable). Locked layers and locked aspects stay.
    func smartRandomize() {
        var opts = SmartRandomizer.Options()
        opts.locks = randomLocks
        opts.creativity = randomCreativity
        let fresh = SmartRandomizer.randomize(document, options: opts, recent: recentRecipes, seed: Int.random(in: 1...999_999))
        if let sig = fresh.recipe?.signature {
            recentRecipes.append(sig)
        } else if let cur = SmartRandomizer.signatureOf(fresh) {
            recentRecipes.append(TemplateLibrary.seed("sig." + cur.0.id))
        }
        if recentRecipes.count > 40 { recentRecipes.removeFirst() }
        let keepSelection = selection
        mutate { d in d = fresh }
        selection = keepSelection.flatMap { id in document.layer(id) != nil ? id : nil }
        snapshot(reason: "Randomize")
    }

    func lockTextLayers(_ locked: Bool) {
        mutate { d in for i in d.layers.indices where d.layers[i].textContent != nil { d.layers[i].isLocked = locked } }
    }

    func unlockAllLayers() {
        mutate { d in for i in d.layers.indices { d.layers[i].isLocked = false } }
    }

    func saveAsTemplate(name: String, includePictures: Bool) {
        do {
            let t = try UserTemplateStore.shared.save(document, name: name, includePictures: includePictures)
            toast = "Saved template \(t.name)"
        } catch {
            toast = "Couldn't save the template: \(error.localizedDescription)"
        }
    }

    func applyUserTemplate(_ t: UserTemplate) {
        let rebuilt = UserTemplateStore.apply(t, to: document)
        mutate { d in d = rebuilt }
        selection = nil
        snapshot(reason: "Template: \(t.name)")
        toast = "Applied \(t.name)"
    }

    /// Rebuilds the cover from a template around this book's title, names and photos (undoable).
    func applyTemplate(_ t: CoverTemplate) {
        let rebuilt = TemplateLibrary.shared.apply(t, to: document)
        mutate { d in d = rebuilt }
        selection = nil
        snapshot(reason: "Template: \(t.name)")
        toast = "Applied \(t.name)"
    }

    /// A border, corner set, divider, badge or banner, colored from the cover palette.
    func addDecor(_ itemID: String) {
        guard let item = DecorLibrary.shared.item(itemID) else { return }
        let (a, b) = DecorLibrary.shared.colors(for: item, palette: PaletteRoles(document.palette))
        var l = Layer.decor(itemID, color: a, color2: b, frame: item.defaultFrame)
        l.name = item.name
        // Borders sit above the art and below the type; ornaments go on top.
        mutate { d in
            if item.kind == .border || item.kind == .corners {
                let i = d.layers.firstIndex { $0.textContent != nil } ?? d.layers.count
                d.layers.insert(l, at: i)
            } else {
                d.layers.append(l)
            }
        }
        selection = l.id
    }

    /// A silhouette or line icon from the illustration library, in the cover's ink color, above the art and below the type.
    func addIllustration(_ itemID: String) {
        guard let item = IllustrationLibrary.shared.item(itemID) else { return }
        let color = inkColor
        let w = 0.3
        let h = w * Double(document.canvas.width) / Double(max(1, document.canvas.height))
        let frame = NRect((1 - w) / 2, (1 - h) / 2, w, h)
        var l = Layer.illustration(itemID, color: color, frame: frame)
        l.name = item.name
        mutate { d in
            let i = d.layers.firstIndex { $0.textContent != nil } ?? d.layers.count
            d.layers.insert(l, at: max(min(1, d.layers.count), i))
        }
        selection = l.id
    }

    /// The color type and ornaments read in against this cover's ground.
    var inkColor: RGBA {
        let p = PaletteRoles(document.palette)
        let ground = document.layers.first?.fillContent?.colors.first ?? document.background
        return ground.isDark ? p.light : p.dark
    }

    /// A full-cover ground printed from the material library.
    func addMaterialFill(_ materialID: String) {
        let p = PaletteRoles(document.palette)
        var l = Layer.fill(.material, colors: [p.dark, p.accent, p.dominant, p.light], seed: Int.random(in: 1...99_999))
        l.fillContent?.materialID = materialID
        if let m = MaterialLibrary.shared.material(materialID) { l.name = m.name }
        mutate { d in d.layers.insert(l, at: 0) }
        selection = l.id
    }

    func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.message = "Choose photos, paintings, sketches or diagrams"
        if panel.runModal() == .OK { importImages(panel.urls) }
    }

    private func insertAboveSelection(_ l: Layer) {
        mutate { d in
            if let s = selection, let i = d.index(of: s) { d.layers.insert(l, at: i + 1) } else { d.layers.append(l) }
        }
        selection = l.id
    }

    func duplicateSelected() {
        guard let s = selectedLayer else { return }
        var copy = s
        copy.id = UUID()
        copy.name = s.name + " Copy"
        copy.frame.x = min(1 - copy.frame.w, copy.frame.x + 0.02)
        copy.frame.y = min(1 - copy.frame.h, copy.frame.y + 0.02)
        insertAboveSelection(copy)
    }

    func deleteSelected() {
        guard let s = selection else { return }
        mutate { d in d.layers.removeAll { $0.id == s } }
        selection = nil
    }

    func moveSelected(by delta: Int) {
        guard let s = selection, let i = document.index(of: s) else { return }
        let j = (i + delta).clamped(0, document.layers.count - 1)
        guard j != i else { return }
        mutate { d in d.layers.swapAt(i, j) }
    }

    func liftSubject(_ id: UUID) {
        guard let l = document.layer(id), l.imageContent != nil else { return }
        var s = l
        s.id = UUID()
        s.name = "Subject (lifted)"
        s.imageContent?.cutout = .subject
        s.shadow = ShadowStyle(color: RGBA(0, 0, 0, 0.55), radius: 0.018, dx: 0, dy: 0.006)
        mutate { d in
            if let i = d.index(of: id) { d.layers.insert(s, at: i + 1) }
        }
        selection = s.id
        toast = "Subject lifted onto its own layer"
    }

    /// Sets the picture's focus so the largest face (or the salient region) sits on the rule of thirds.
    func smartCrop(_ id: UUID) {
        guard let l = document.layer(id), let ic = l.imageContent else { return }
        let data = document.assetData(ic.assetID)
        let insight = AssetStore.shared.insight(ic.assetID, data: data)
        guard let size = AssetStore.shared.imageSize(ic.assetID, data: data) else { return }
        let canvas = CGSize(width: document.canvas.width, height: document.canvas.height)
        let f = insight.smartFocus(frame: l.frame, canvas: canvas, imageSize: size, zoom: ic.zoom)
        mutate { d in
            if let i = d.index(of: id) {
                d.layers[i].imageContent?.focusX = f.focusX
                d.layers[i].imageContent?.focusY = f.focusY
            }
        }
        toast = insight.faces.isEmpty ? "Framed on the subject" : "Framed to keep the face in view"
    }

    /// Inserts a palette-colored harmony layer directly above the photo (once).
    func harmonizePhoto(_ id: UUID) {
        guard let l = document.layer(id), let ic = l.imageContent, let i = document.index(of: id) else { return }
        if let above = document.layers[safe: i + 1], above.name == "Harmony" {
            toast = "This picture is already harmonized"
            return
        }
        let insight = AssetStore.shared.insight(ic.assetID, data: document.assetData(ic.assetID))
        let harmony = Harmonizer.layer(for: l, palette: PaletteRoles(document.palette), strength: 0.6, mean: insight.meanColor)
        mutate { d in
            if let j = d.index(of: id) { d.layers.insert(harmony, at: j + 1) }
        }
        toast = "Harmonized the picture to the cover palette"
    }

    func cutInto(_ shape: ShapeKind?, layer id: UUID) {
        mutate { d in if let i = d.index(of: id) { d.layers[i].clipShape = shape } }
    }

    func nudge(dx: Double, dy: Double) {
        guard let s = selection, let l = document.layer(s), !l.isLocked else { return }
        mutate(undoKey: "nudge-\(s)") { d in
            if let i = d.index(of: s) {
                d.layers[i].frame.x += dx
                d.layers[i].frame.y += dy
            }
        }
    }

    func applyEffect(_ presetID: String) {
        guard let t = effectTarget else { return }
        mutate { d in
            if let i = d.index(of: t) { d.layers[i].effects.append(EffectInstance(presetID: presetID, amount: 1)) }
        }
        if selection == nil { selection = t }
    }

    func apply(_ s: Suggestion) {
        mutate { d in s.apply(&d) }
        toast = s.title
    }

    func apply(_ fix: FixAction) {
        let bg = insightBackground
        mutate { d in Preflight.apply(fix, to: &d, background: bg) }
    }

    func autoPolish() {
        let p = PaletteRoles(document.palette)
        mutate { d in Polisher.polish(&d, palette: p) }
        snapshot(reason: "Polish")
        toast = "Polished type color, shadows and scrims"
    }

    /// Lets the critic fix everything it measured: colors, lifts, backings, and type moved off faces, collisions and the trim.
    func autoRepair(moveType: Bool = true) {
        let p = PaletteRoles(document.palette)
        var report = CriticReport.perfect
        mutate { d in report = Critic.repair(&d, geometry: moveType, palette: p) }
        critique = report
        snapshot(reason: "Repair")
        toast = "Design score \(Int(report.score)) (\(report.grade))"
    }

    func reextractPalette() {
        guard let id = document.assetOrder.first else { return }
        let cols = AssetStore.shared.palette(id, data: document.assetData(id))
        guard !cols.isEmpty else { return }
        mutate { d in d.palette = cols }
    }

    /// Applies a color to whatever the selected layer's main color is.
    func applyColor(_ c: RGBA) {
        guard let s = selection else { return }
        mutate(undoKey: "color-\(s)") { d in
            guard let i = d.index(of: s) else { return }
            switch d.layers[i].content {
            case .text(var t): t.color = c; d.layers[i].content = .text(t)
            case .shape(var sh):
                if sh.fill != nil { sh.fill = c } else { sh.stroke = c }
                d.layers[i].content = .shape(sh)
            case .fill(var f):
                if f.colors.isEmpty { f.colors = [c] } else { f.colors[0] = c }
                d.layers[i].content = .fill(f)
            case .decor(var x):
                x.color = c
                d.layers[i].content = .decor(x)
            case .illustration(var x):
                x.color = c
                d.layers[i].content = .illustration(x)
            case .paint:
                break
            case .image:
                d.layers[i].effects.append(EffectInstance(presetID: "wash.\(EffectLibrary.slug(ColorBook.vivid.min { $0.color.distance(to: c) < $1.color.distance(to: c) }!.name)).color", amount: 0.6))
            }
        }
    }

    // MARK: Cutout brush

    /// Converts a point on the cover (0...1) into the image's own space for a layer,
    /// with the brush radius in that space.
    func imagePoint(_ l: Layer, canvasX: Double, canvasY: Double) -> (NPoint, Double)? {
        guard let ic = l.imageContent,
              let img = AssetStore.shared.image(ic.assetID, data: document.assetData(ic.assetID), resolution: .thumbnail) else { return nil }
        let cw = Double(document.canvas.width), ch = Double(document.canvas.height)
        let W = l.frame.w * cw, H = l.frame.h * ch
        var px = (canvasX - l.frame.x) * cw
        let py = (canvasY - l.frame.y) * ch
        let iw = Double(img.width), ih = Double(img.height)
        let s = max(W / iw, H / ih) * max(1, ic.zoom)
        let dw = iw * s, dh = ih * s
        let ox = -(dw - W) * ic.focusX.clamped01, oy = -(dh - H) * ic.focusY.clamped01
        if ic.flipped { px = W - px }
        let radius = (brushSize * cw / 2) / s / min(iw, ih)
        return (NPoint(x: (px - ox) / dw, y: (py - oy) / dh), radius)
    }

    /// The inverse of `imagePoint`: a stroke in a layer's image space back on the cover (0...1),
    /// with its brush diameter as a fraction of the cover's width. For drawing pending strokes.
    func canvasStroke(_ l: Layer, _ s: MaskStroke) -> (points: [(x: Double, y: Double)], diameter: Double)? {
        guard let ic = l.imageContent,
              let img = AssetStore.shared.image(ic.assetID, data: document.assetData(ic.assetID), resolution: .thumbnail) else { return nil }
        let cw = Double(document.canvas.width), ch = Double(document.canvas.height)
        let W = l.frame.w * cw, H = l.frame.h * ch
        let iw = Double(img.width), ih = Double(img.height)
        let sc = max(W / iw, H / ih) * max(1, ic.zoom)
        let dw = iw * sc, dh = ih * sc
        let ox = -(dw - W) * ic.focusX.clamped01, oy = -(dh - H) * ic.focusY.clamped01
        let pts = s.points.map { p -> (x: Double, y: Double) in
            var px = p.x * dw + ox
            if ic.flipped { px = W - px }
            return (l.frame.x + px / cw, l.frame.y + (p.y * dh + oy) / ch)
        }
        return (pts, 2 * s.radius * min(iw, ih) * sc / cw)
    }

    @ObservationIgnored private var strokeKey = ""

    func beginStroke(layer id: UUID, canvasX: Double, canvasY: Double) {
        guard let l = document.layer(id), case let (p, r)? = imagePoint(l, canvasX: canvasX, canvasY: canvasY) else { return }
        if tool == .remove {
            beginRemovalStroke(layer: id, point: p, radius: r)
            return
        }
        strokeKey = "brush-\(UUID().uuidString)"
        let stroke = MaskStroke(restore: tool == .restore, radius: r, points: [p])
        mutate(undoKey: strokeKey) { d in
            if let i = d.index(of: id) { d.layers[i].imageContent?.maskEdits.append(stroke) }
        }
    }

    func extendStroke(layer id: UUID, canvasX: Double, canvasY: Double) {
        guard let l = document.layer(id), case let (p, r)? = imagePoint(l, canvasX: canvasX, canvasY: canvasY) else { return }
        if tool == .remove {
            extendRemovalStroke(layer: id, point: p, radius: r)
            return
        }
        guard let last = l.imageContent?.maskEdits.last?.points.last else { return }
        guard hypot(p.x - last.x, p.y - last.y) > r * 0.25 else { return }
        mutate(undoKey: strokeKey) { d in
            guard let i = d.index(of: id), let n = d.layers[i].imageContent?.maskEdits.count, n > 0 else { return }
            d.layers[i].imageContent?.maskEdits[n - 1].points.append(p)
        }
    }

    func clearMaskEdits(_ id: UUID) {
        mutate { d in if let i = d.index(of: id) { d.layers[i].imageContent?.maskEdits = [] } }
    }

    // MARK: Object removal

    private func beginRemovalStroke(layer id: UUID, point p: NPoint, radius r: Double) {
        if removalLayerID != id { removalStrokes = [] }
        removalLayerID = id
        removalStrokes.append(MaskStroke(restore: false, radius: r, points: [p]))
    }

    private func extendRemovalStroke(layer id: UUID, point p: NPoint, radius r: Double) {
        guard removalLayerID == id, let last = removalStrokes.last?.points.last else { return }
        guard hypot(p.x - last.x, p.y - last.y) > r * 0.25 else { return }
        removalStrokes[removalStrokes.count - 1].points.append(p)
    }

    func cancelRemoval() {
        removalStrokes = []
        removalLayerID = nil
        if tool == .remove { tool = .select }
    }

    /// Fills in whatever the Remove strokes cover and swaps the layer's picture for the result
    /// (a new asset, so undo brings the original back).
    func applyRemoval(_ id: UUID) {
        guard !isRemoving, removalLayerID == id, !removalStrokes.isEmpty,
              let ic = document.layer(id)?.imageContent else { return }
        let strokes = removalStrokes
        let assetID = ic.assetID
        let data = document.assetData(assetID)
        isRemoving = true
        Task.detached(priority: .userInitiated) { [weak self] in
            var encoded: Data?
            if let full = AssetStore.shared.image(assetID, data: data, resolution: .full),
               let mask = Inpainter.strokeMask(strokes, width: full.width, height: full.height),
               let out = Inpainter.remove(from: full, mask: mask) {
                encoded = AssetStore.encode(out)
            }
            await self?.finishRemoval(id, data: encoded, what: "Removed from the photo")
        }
    }

    /// Removes a detected subject (an index from `AssetStore.subjects`) from the layer's photo.
    func removeSubject(_ id: UUID, instance: Int) {
        guard !isRemoving, let ic = document.layer(id)?.imageContent else { return }
        let assetID = ic.assetID
        let data = document.assetData(assetID)
        isRemoving = true
        Task.detached(priority: .userInitiated) { [weak self] in
            var encoded: Data?
            if let mask = AssetStore.shared.instanceMask(assetID, data: data, instances: IndexSet(integer: instance)),
               let full = AssetStore.shared.image(assetID, data: data, resolution: .full),
               let out = Inpainter.remove(from: full, mask: mask) {
                encoded = AssetStore.encode(out)
            }
            await self?.finishRemoval(id, data: encoded, what: "Subject removed from the photo")
        }
    }

    private func finishRemoval(_ id: UUID, data: Data?, what: String) {
        isRemoving = false
        guard let data else {
            toast = "Couldn't fill that in"
            return
        }
        var newID: UUID?
        mutate { d in
            let nid = d.addAsset(data)
            if let i = d.index(of: id) {
                d.layers[i].imageContent?.assetID = nid
                // Instance indices belong to the old picture.
                d.layers[i].imageContent?.keptSubjects = nil
            }
            newID = nid
        }
        if let newID {
            Task.detached(priority: .utility) { AssetStore.shared.warm(newID, data: data) }
        }
        removalStrokes = []
        removalLayerID = nil
        if tool == .remove { tool = .select }
        toast = what
    }

    // MARK: Workflow tools

    func toggleFavorite(_ id: UUID) {
        if let i = variations.firstIndex(where: { $0.id == id }) { variations[i].favorite.toggle() }
    }

    func copyTextStyle() {
        guard let t = selectedLayer?.textContent else { return }
        copiedTextStyle = t
        toast = "Copied the style of \"\(t.text.replacingOccurrences(of: "\n", with: " ").prefix(24))\""
    }

    func pasteTextStyle() {
        guard let s = selection, let style = copiedTextStyle, selectedLayer?.textContent != nil else { return }
        mutate { d in
            guard let i = d.index(of: s), let current = d.layers[i].textContent else { return }
            var t = style
            t.text = current.text
            t.role = current.role
            d.layers[i].textContent = t
        }
    }

    /// Lines a layer up with the safe margins or the center.
    func align(_ edge: LayerAlign) {
        guard let s = selection else { return }
        let m = Preflight.safeMargin + 0.02
        mutate { d in
            guard let i = d.index(of: s) else { return }
            var f = d.layers[i].frame
            switch edge {
            case .left: f.x = m
            case .centerX: f.x = (1 - f.w) / 2
            case .right: f.x = 1 - m - f.w
            case .top: f.y = m
            case .middle: f.y = (1 - f.h) / 2
            case .bottom: f.y = 1 - m - f.h
            }
            d.layers[i].frame = f
        }
    }

    func pickColorFromScreen() {
        NSColorSampler().show { [weak self] color in
            guard let color else { return }
            let c = RGBA(nsColor: color)
            Task { @MainActor in
                guard let self else { return }
                if self.selection != nil {
                    self.applyColor(c)
                } else {
                    self.mutate { d in d.palette.append(c) }
                }
                self.toast = "Picked \(c.hex)"
            }
        }
    }

    func importFont() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.font]
        panel.allowsMultipleSelection = true
        panel.message = "Choose .ttf or .otf font files to use on this cover"
        guard panel.runModal() == .OK else { return }
        var names: [String] = []
        var added: [String: Data] = [:]
        for url in panel.urls {
            guard let data = try? Data(contentsOf: url), let name = FontCatalog.register(data) else { continue }
            added[name] = data
            names.append(name)
        }
        guard !names.isEmpty else {
            toast = "Couldn't read that font file"
            return
        }
        mutate { d in
            for (k, v) in added { d.fonts[k] = v }
            if let s = selection, let i = d.index(of: s), d.layers[i].textContent != nil {
                d.layers[i].textContent?.fontName = names[0]
            }
        }
        toast = names.count == 1 ? "Added \(FontCatalog.displayName(names[0]))" : "Added \(names.count) fonts"
    }

    // MARK: Files

    func save() {
        if let url = fileURL { write(to: url) } else { saveAs() }
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.colophonProject]
        panel.nameFieldStringValue = Exporter.safeFileName(document.book.title.isEmpty ? "Untitled Cover" : document.book.title) + ".colophon"
        if panel.runModal() == .OK, let url = panel.url {
            write(to: url)
            fileURL = url
        }
    }

    private func write(to url: URL) {
        do {
            let data = try JSONEncoder().encode(document)
            try data.write(to: url, options: .atomic)
            isDirty = false
            noteRecent(url)
            discardRecovery()
            toast = "Saved \(url.lastPathComponent)"
        } catch {
            toast = "Couldn't save: \(error.localizedDescription)"
        }
    }

    // MARK: Recent files, autosave and recovery

    static var recoveryURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Colophon", isDirectory: true)
        return dir.appendingPathComponent("Recovered Cover.colophon")
    }

    func noteRecent(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        recentFiles = Array(recentFiles.prefix(10))
        UserDefaults.standard.set(recentFiles.map(\.absoluteString), forKey: "recentFiles")
    }

    func clearRecent() {
        recentFiles = []
        UserDefaults.standard.removeObject(forKey: "recentFiles")
    }

    func openRecent(_ url: URL) {
        guard confirmDiscard() else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            recentFiles.removeAll { $0 == url }
            toast = "That file has moved or been deleted"
            return
        }
        load(url)
    }

    /// Saves unsaved work every 45 seconds: in place when the project has a file,
    /// otherwise to a recovery file offered on the next launch.
    func startAutosave() {
        autosaveTask?.cancel()
        NSApp.appearance = appearance.nsAppearance
        autosaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 45_000_000_000)
                self?.autosaveNow()
            }
        }
    }

    func autosaveNow() {
        guard isDirty, !document.layers.isEmpty else { return }
        if let url = fileURL {
            if let data = try? JSONEncoder().encode(document), (try? data.write(to: url, options: .atomic)) != nil {
                isDirty = false
            }
        } else {
            let url = EditorModel.recoveryURL
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(document) { try? data.write(to: url, options: .atomic) }
        }
    }

    func restoreRecovery() {
        let url = EditorModel.recoveryURL
        guard let data = try? Data(contentsOf: url), let doc = try? JSONDecoder().decode(CoverDocument.self, from: data) else {
            discardRecovery()
            return
        }
        document = doc
        fileURL = nil
        for f in doc.fonts.values { FontCatalog.register(f) }
        screen = doc.layers.isEmpty ? .start : .editor
        isDirty = true
        recoveryAvailable = false
        documentChanged()
        versions.clear()
        snapshot(reason: "Opened")
        toast = "Recovered your unsaved cover. Save it to keep it."
    }

    func discardRecovery() {
        try? FileManager.default.removeItem(at: EditorModel.recoveryURL)
        recoveryAvailable = false
    }

    // MARK: Compare

    func addCompareReferences() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.message = "Choose covers to compare against, such as bestsellers in your genre"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let data = try? Data(contentsOf: url), let img = AssetStore.decode(data, maxPixel: 1200) else { continue }
            compareRefs.append(CompareRef(name: url.deletingPathExtension().lastPathComponent, image: img))
        }
    }

    func open() {
        guard confirmDiscard() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.colophonProject, .json]
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }

    func load(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let doc = try JSONDecoder().decode(CoverDocument.self, from: data)
            document = doc
            fileURL = url
            noteRecent(url)
            undoStack = []
            redoStack = []
            selection = nil
            screen = doc.layers.isEmpty ? .start : .editor
            isDirty = false
            for data in doc.fonts.values { FontCatalog.register(data) }
            for id in doc.assetOrder {
                let d = doc.assetData(id)
                Task.detached(priority: .utility) { AssetStore.shared.warm(id, data: d) }
            }
            documentChanged()
            isDirty = false
            versions.clear()
            snapshot(reason: "Opened")
        } catch {
            toast = "Couldn't open that file: \(error.localizedDescription)"
        }
    }

    private func confirmDiscard() -> Bool {
        guard isDirty, !document.layers.isEmpty else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard unsaved changes?"
        alert.informativeText = "Your current cover has changes that haven't been saved."
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

extension Int {
    func clamped(_ lo: Int, _ hi: Int) -> Int { Swift.min(hi, Swift.max(lo, self)) }
}
