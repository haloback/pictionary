import SwiftUI

struct EditorView: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            LayersSidebar()
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
        } detail: {
            CanvasArea()
        }
        .inspector(isPresented: $model.showInspector) {
            InspectorView()
                .inspectorColumnWidth(min: 300, ideal: 336, max: 440)
        }
        .toolbar { toolbar }
        .onAppear {
            model.scheduleRender()
            model.scheduleInsights()
            model.refreshEffectBase()
        }
        .onChange(of: model.selection) { _, _ in model.refreshEffectBase() }
        .onChange(of: model.targetStoreID) { _, _ in model.scheduleInsights() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { model.screen = model.variations.isEmpty ? .start : .variations } label: {
                Label("Ideas", systemImage: "square.grid.2x2")
            }
            .help(model.variations.isEmpty ? "Back to the brief" : "Back to the cover ideas")
        }
        ToolbarItemGroup(placement: .principal) {
            Menu {
                Button { model.chooseImages() } label: { Label("Photo or Artwork…", systemImage: "photo") }
                Divider()
                Button { model.addText(role: .custom) } label: { Label("Text", systemImage: "textformat") }
                Menu("Book Text") {
                    ForEach([TextRole.title, .subtitle, .author, .series, .tagline], id: \.self) { r in
                        Button(r.label) { model.addText(role: r) }
                    }
                }
                Divider()
                Menu("Shape") {
                    ForEach(ShapeKind.allCases) { k in
                        Button { model.addShape(k) } label: { Label(k.label, systemImage: k.symbol) }
                    }
                }
                Menu("Color & Texture") {
                    ForEach(FillStyle.allCases) { s in
                        Button(s.label) { model.addFill(s) }
                    }
                }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .help("Add a photo, text, shape or painted texture")

            Button { model.generateVariations() } label: { Label("New Ideas", systemImage: "sparkles") }
                .help("Design a new batch of covers from this brief")
            Button { model.remixCurrent() } label: { Label("More Like This", systemImage: "square.stack.3d.down.right") }
                .help("Variations of this cover: same layout and edits, new type, color, look or crop")
            Button { model.autoPolish() } label: { Label("Polish", systemImage: "wand.and.rays") }
                .help("Fix type color, shadows and scrims so everything is legible")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Toggle(isOn: Binding(get: { model.showGuides }, set: { model.showGuides = $0 })) {
                Label("Guides", systemImage: "squareshape.split.3x3")
            }
            .help("Golden-section guides and safe area")
            Button { model.showPaperback = true } label: { Label("Paperback", systemImage: "book") }
                .help("Print wraparound: back, spine and front as a print-ready PDF")
            Button { model.showExport = true } label: { Label("Export", systemImage: "square.and.arrow.up") }
                .help("Export store-ready files for Kindle, Google Play, Apple Books and more")
            Button { model.showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.right") }
        }
    }
}

struct LayersSidebar: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selection) {
            Section {
                ForEach(model.document.layers.reversed()) { layer in
                    LayerRow(layer: layer)
                        .tag(layer.id)
                        .contextMenu { contextMenu(layer) }
                }
                .onMove { from, to in
                    model.mutate { d in
                        var rev = Array(d.layers.reversed())
                        rev.move(fromOffsets: from, toOffset: to)
                        d.layers = rev.reversed()
                    }
                }
            } header: {
                Text("Layers")
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 14) {
                Button { model.addText() } label: { Image(systemName: "textformat") }.help("Add text")
                Button { model.chooseImages() } label: { Image(systemName: "photo") }.help("Add a photo")
                Button { model.addShape(.rectangle) } label: { Image(systemName: "square.on.circle") }.help("Add a shape")
                Spacer()
                Button { model.duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }.help("Duplicate").disabled(model.selection == nil)
                Button { model.deleteSelected() } label: { Image(systemName: "trash") }.help("Delete").disabled(model.selection == nil)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func contextMenu(_ layer: Layer) -> some View {
        Button("Duplicate") { model.selection = layer.id; model.duplicateSelected() }
        Button("Delete", role: .destructive) { model.selection = layer.id; model.deleteSelected() }
        Divider()
        Button("Bring Forward") { model.selection = layer.id; model.moveSelected(by: 1) }
        Button("Send Backward") { model.selection = layer.id; model.moveSelected(by: -1) }
        if layer.textContent != nil {
            Divider()
            Button("Copy Style") { model.selection = layer.id; model.copyTextStyle() }
            Button("Paste Style") { model.selection = layer.id; model.pasteTextStyle() }
                .disabled(model.copiedTextStyle == nil)
        }
        if layer.imageContent != nil {
            Divider()
            Button("Lift Subject to New Layer") { model.liftSubject(layer.id) }
            Menu("Cut Into Shape") {
                Button("No Shape") { model.cutInto(nil, layer: layer.id) }
                ForEach(ShapeKind.clipShapes) { k in Button(k.label) { model.cutInto(k, layer: layer.id) } }
            }
        }
    }
}

private struct LayerRow: View {
    @Environment(EditorModel.self) private var model
    let layer: Layer

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: layer.kindSymbol)
                .font(.system(size: 12))
                .frame(width: 18)
                .foregroundStyle(layer.textContent != nil ? Theme.accent : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(layer.textContent.map { $0.text.replacingOccurrences(of: "\n", with: " ") }.map { String($0.prefix(28)) } ?? layer.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button { toggle(\.isLocked) } label: {
                Image(systemName: layer.isLocked ? "lock.fill" : "lock.open").font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .opacity(layer.isLocked ? 1 : 0.35)
            .help(layer.isLocked ? "Unlock" : "Lock position")
            Button { toggle(\.isVisible) } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash").font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .opacity(layer.isVisible ? 0.6 : 1)
        }
        .opacity(layer.isVisible ? 1 : 0.5)
    }

    private var subtitle: String {
        var parts = [layer.kindLabel]
        if layer.blend != .normal { parts.append(layer.blend.label) }
        if !layer.effects.isEmpty { parts.append("\(layer.effects.count) fx") }
        if layer.textContent?.behindSubject == true { parts.append("behind subject") }
        return parts.joined(separator: ", ")
    }

    private func toggle(_ kp: WritableKeyPath<Layer, Bool>) {
        let id = layer.id
        model.mutate { d in if let i = d.index(of: id) { d.layers[i][keyPath: kp].toggle() } }
    }
}
