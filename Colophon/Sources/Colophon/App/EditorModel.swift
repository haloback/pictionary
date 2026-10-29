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
    var insightBackground: CGImage?
    var isAnalyzing = false

    var effectBase: CGImage?
    var effectBaseVersion = 0
    var toast: String?

    var showFavoritesOnly = false
    var showSeries = false
    var copiedTextStyle: TextContent?

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
        insightTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            if Task.isCancelled { return }
            let bg = Polisher.backgroundSample(doc)
            let full = CoverRenderer.shared.render(doc, size: CGSize(width: 200, height: (200 * doc.canvas.aspect).rounded()), quality: .preview)
            let issues = Preflight.run(doc, spec: spec, background: bg, full: full)
            let ideas = SuggestionEngine.suggestions(for: doc, background: bg)
            if Task.isCancelled { return }
            await self?.setInsights(issues, ideas, bg)
        }
    }

    private func setInsights(_ issues: [PreflightIssue], _ ideas: [Suggestion], _ bg: CGImage?) {
        preflight = issues
        suggestions = ideas
        insightBackground = bg
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

    func adopt(_ v: Variation) {
        if screen == .editor || !document.layers.isEmpty { undoStack.append(document) }
        document = v.document
        selection = document.textLayer(role: .title)?.id
        screen = .editor
        documentChanged()
        refreshEffectBase()
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
        toast = "Polished type color, shadows and scrims"
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
            case .image:
                d.layers[i].effects.append(EffectInstance(presetID: "wash.\(EffectLibrary.slug(ColorBook.vivid.min { $0.color.distance(to: c) < $1.color.distance(to: c) }!.name)).color", amount: 0.6))
            }
        }
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
            toast = "Saved \(url.lastPathComponent)"
        } catch {
            toast = "Couldn't save: \(error.localizedDescription)"
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
