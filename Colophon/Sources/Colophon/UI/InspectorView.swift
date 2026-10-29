import SwiftUI

struct InspectorView: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            Picker("", selection: $model.inspectorTab) {
                ForEach(InspectorTab.allCases) { t in
                    Image(systemName: t.symbol).help(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, 10)
            HStack {
                Text(model.inspectorTab.rawValue).font(.system(size: 13, weight: .semibold))
                Spacer()
                tabAccessory
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider()
            Group {
                switch model.inspectorTab {
                case .layer: LayerInspector()
                case .effects: EffectsInspector()
                case .color: ColorInspector()
                case .ideas: IdeasInspector()
                case .check: CheckInspector()
                case .book: BookInspector()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var tabAccessory: some View {
        switch model.inspectorTab {
        case .effects:
            Text("\(EffectLibrary.shared.presets.count.formatted()) presets").font(.system(size: 11)).foregroundStyle(.secondary)
        case .check:
            let fails = model.preflight.filter { $0.severity >= .warning }.count
            Text(fails == 0 ? "Ready to publish" : "\(fails) to review")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(fails == 0 ? Color.green : Color.orange)
        case .layer:
            if let l = model.selectedLayer { Text(l.kindLabel).font(.system(size: 11)).foregroundStyle(.secondary) }
        default:
            EmptyView()
        }
    }
}

// MARK: - Layer

struct LayerInspector: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        if let id = model.selection, model.document.layer(id) != nil {
            let b = model.layerBinding(id)
            ScrollView {
                VStack(spacing: 0) {
                    switch b.wrappedValue.content {
                    case .text: TextSection(layer: b)
                    case .image: ImageSection(layer: b)
                    case .fill: FillSection(layer: b)
                    case .shape: ShapeSection(layer: b)
                    }
                    if b.wrappedValue.textContent == nil {
                        AdjustSection(layer: b)
                    }
                    AppearanceSection(layer: b)
                    GeometrySection(layer: b)
                }
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "cursorarrow.click.2").font(.system(size: 30, weight: .light)).foregroundStyle(.tertiary)
                Text("Select a layer").font(.system(size: 13, weight: .medium))
                Text("Click anything on the cover, or pick it from the layer list.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(30)
            .frame(maxHeight: .infinity)
        }
    }
}

private struct TextSection: View {
    @Environment(EditorModel.self) private var model
    @Binding var layer: Layer
    @State private var showFonts = false

    private var t: Binding<TextContent> {
        Binding(get: { layer.textContent ?? TextContent(text: "") }, set: { layer.textContent = $0 })
    }

    var body: some View {
        PanelSection("Text") {
            TextEditor(text: t.text)
                .font(.system(size: 13))
                .frame(minHeight: 56, maxHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            if t.wrappedValue.role == .title {
                HStack(spacing: 6) {
                    Text("Line breaks").font(.system(size: 11)).foregroundStyle(.secondary)
                    ForEach(1...4, id: \.self) { n in
                        Button("\(n)") { t.wrappedValue.text = TitleBreaker.balanced(t.wrappedValue.text.replacingOccurrences(of: "\n", with: " "), lines: n) }
                    }
                    Button("Stack") { t.wrappedValue.text = TitleBreaker.auto(t.wrappedValue.text.replacingOccurrences(of: "\n", with: " "), stacked: true) }
                }
                .controlSize(.small)
            }
            FieldRow("Role") {
                Picker("", selection: t.role) { ForEach(TextRole.allCases) { Text($0.label).tag($0) } }.labelsHidden()
            }
        }
        PanelSection("Typeface") {
            Button { showFonts = true } label: {
                HStack {
                    Text(FontCatalog.displayName(t.wrappedValue.fontName))
                        .font(.custom(t.wrappedValue.fontName, size: 15))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFonts, arrowEdge: .leading) {
                FontPicker(selection: t.fontName, sample: t.wrappedValue.text).environment(model)
            }
            FieldRow("Case") {
                Picker("", selection: t.letterCase) { ForEach(LetterCase.allCases) { Text($0.label).tag($0) } }.labelsHidden()
            }
            FieldRow("Align") {
                Picker("", selection: t.alignment) {
                    Image(systemName: "text.alignleft").tag(TextAlign.left)
                    Image(systemName: "text.aligncenter").tag(TextAlign.center)
                    Image(systemName: "text.alignright").tag(TextAlign.right)
                }
                .pickerStyle(.segmented).labelsHidden()
            }
            Toggle("Fit text to its box", isOn: t.autoFit).controlSize(.small)
            if !t.wrappedValue.autoFit {
                ValueSlider(label: "Size", value: t.fontSize, range: 0.01...0.25) { String(format: "%.1f%%", $0 * 100) }
            }
            ValueSlider(label: "Tracking", value: t.tracking, range: -0.05...0.6) { String(format: "%.2f", $0) }
            ValueSlider(label: "Leading", value: t.lineHeight, range: 0.75...1.6) { String(format: "%.2f", $0) }
        }
        PanelSection("Color & Finish") {
            RGBAPicker(label: "Fill", color: t.color)
            colorSuggestions
            Toggle("Gradient", isOn: Binding(get: { t.wrappedValue.gradientTo != nil }, set: { on in
                t.wrappedValue.gradientTo = on ? PaletteRoles(model.document.palette).accent.withLightness(0.7) : nil
            })).controlSize(.small)
            if let g = t.wrappedValue.gradientTo {
                RGBAPicker(label: "Fades to", color: Binding(get: { g }, set: { t.wrappedValue.gradientTo = $0 }))
            }
            Toggle("Outline", isOn: Binding(get: { t.wrappedValue.strokeColor != nil }, set: { on in
                t.wrappedValue.strokeColor = on ? (t.wrappedValue.color.isDark ? RGBA.nearWhite : RGBA.nearBlack) : nil
            })).controlSize(.small)
            if let s = t.wrappedValue.strokeColor {
                RGBAPicker(label: "Outline", color: Binding(get: { s }, set: { t.wrappedValue.strokeColor = $0 }))
                ValueSlider(label: "Weight", value: t.strokeWidth, range: 0.005...0.08) { String(format: "%.0f", $0 * 1000) }
            }
            Toggle("Glow", isOn: Binding(get: { t.wrappedValue.glowColor != nil }, set: { on in
                t.wrappedValue.glowColor = on ? PaletteRoles(model.document.palette).accent.withAlpha(0.9) : nil
            })).controlSize(.small)
            if let g = t.wrappedValue.glowColor {
                RGBAPicker(label: "Glow", color: Binding(get: { g }, set: { t.wrappedValue.glowColor = $0 }))
                ValueSlider(label: "Radius", value: t.glowRadius, range: 0.05...0.8)
            }
        }
        PanelSection("Depth") {
            Toggle(isOn: t.behindSubject) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Behind subject")
                    Text("The photo's subject overlaps the type.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .disabled(model.document.photoLayers.isEmpty)
        }
    }

    /// Palette colors plus the best-contrast and opposite options, one click each.
    private var colorSuggestions: some View {
        let p = PaletteRoles(model.document.palette)
        var picks: [(String, RGBA)] = [("Light", p.light), ("Dark", p.dark), ("Accent", p.accent), ("Opposite", ColorAdvisor.opposite(p.dominant))]
        if let bg = model.insightBackground {
            let s = PixelSampler.stats(bg, region: layer.frame)
            let best = ColorAdvisor.bestText(on: s.mean, candidates: ColorAdvisor.textCandidates(p, onDark: s.mean.luminance < 0.36), minimum: 4.5)
            picks.insert(("Best contrast", best), at: 0)
        }
        return HStack(spacing: 6) {
            ForEach(Array(picks.enumerated()), id: \.offset) { _, pick in
                Button { t.wrappedValue.color = pick.1 } label: {
                    Swatch(color: pick.1, size: 24, selected: t.wrappedValue.color == pick.1)
                }
                .buttonStyle(.plain)
                .help(pick.0 + " " + pick.1.hex)
            }
            Spacer()
        }
    }
}

private struct FontPicker: View {
    @Environment(EditorModel.self) private var model
    @Binding var selection: String
    let sample: String
    @State private var query = ""
    @State private var showAll = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search fonts", text: $query).textFieldStyle(.roundedBorder)
                Toggle("All installed", isOn: $showAll).toggleStyle(.switch).controlSize(.mini)
            }
            .padding(10)
            HStack {
                Button { model.importFont() } label: { Label("Import Font…", systemImage: "plus") }
                    .help("Add a .ttf or .otf file. It is saved inside the project.")
                Spacer()
                Text("Embedded in the project").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .controlSize(.small)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            Divider()
            List {
                if showAll {
                    ForEach(FontCatalog.installed.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { name in
                        row(name, label: FontCatalog.displayName(name))
                    }
                } else {
                    if !model.document.fonts.isEmpty {
                        Section("Your Fonts") {
                            ForEach(model.document.fonts.keys.sorted(), id: \.self) { name in row(name, label: FontCatalog.displayName(name)) }
                        }
                    }
                    ForEach(FontCatalog.Mood.allCases) { mood in
                        let items = FontCatalog.curated.filter { $0.mood == mood && FontCatalog.isAvailable($0.id) && (query.isEmpty || $0.label.localizedCaseInsensitiveContains(query)) }
                        if !items.isEmpty {
                            Section(mood.rawValue) {
                                ForEach(items) { e in row(e.id, label: e.label) }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 340, height: 460)
    }

    private func row(_ name: String, label: String) -> some View {
        Button { selection = name } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sampleText).font(.custom(name, size: 20)).lineLimit(1)
                    Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                if selection == name { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sampleText: String {
        let s = sample.replacingOccurrences(of: "\n", with: " ")
        return s.isEmpty ? "The Quiet Hours" : String(s.prefix(22))
    }
}

private struct ImageSection: View {
    @Environment(EditorModel.self) private var model
    @Binding var layer: Layer

    private var ic: Binding<ImageContent> {
        Binding(get: { layer.imageContent ?? ImageContent(assetID: UUID()) }, set: { layer.imageContent = $0 })
    }

    var body: some View {
        PanelSection("Picture") {
            FieldRow("Show") {
                Picker("", selection: ic.cutout) { ForEach(Cutout.allCases) { Text($0.label).tag($0) } }.labelsHidden()
            }
            ValueSlider(label: "Zoom", value: ic.zoom, range: 1...4) { String(format: "%.1fx", $0) }
            ValueSlider(label: "Focus X", value: ic.focusX, range: 0...1)
            ValueSlider(label: "Focus Y", value: ic.focusY, range: 0...1)
            Toggle("Flip horizontally", isOn: ic.flipped).controlSize(.small)
            HStack {
                Button { model.liftSubject(layer.id) } label: { Label("Lift Subject", systemImage: "person.crop.rectangle.stack") }
                    .help("Copy just the subject onto its own layer, ready to overlap type or shapes")
                Menu("Cut Into") {
                    Button("No Shape") { layer.clipShape = nil }
                    ForEach(ShapeKind.clipShapes) { k in
                        Button { layer.clipShape = k } label: { Label(k.label, systemImage: k.symbol) }
                    }
                }
                .fixedSize()
            }
            .controlSize(.small)
            Button { focusOnSubject() } label: { Label("Center on Subject", systemImage: "viewfinder") }
                .controlSize(.small)
        }
        PanelSection("Refine Cutout") {
            Text(ic.wrappedValue.cutout == .none
                 ? "Paint on the cover to erase parts of this picture, or restore them."
                 : "Fix the automatic cutout edge: erase what shouldn't be there, restore what was missed.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                brushButton(.erase, "Erase", "eraser")
                brushButton(.restore, "Restore", "paintbrush.pointed")
                Spacer()
                if !ic.wrappedValue.maskEdits.isEmpty {
                    Button("Clear \(ic.wrappedValue.maskEdits.count)") { model.clearMaskEdits(layer.id) }
                        .help("Remove all brush edits on this picture")
                }
            }
            .controlSize(.small)
            ValueSlider(label: "Brush", value: Binding(get: { model.brushSize }, set: { model.brushSize = $0 }), range: 0.01...0.2)
        }
    }

    private func brushButton(_ tool: CanvasTool, _ title: String, _ symbol: String) -> some View {
        let on = model.tool == tool
        return Button {
            model.selection = layer.id
            model.tool = on ? .select : tool
        } label: {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(.bordered)
        .tint(on ? Theme.accent : nil)
        .help(on ? "Stop painting (Esc)" : "Paint on the cover to \(title.lowercased())")
    }

    private func focusOnSubject() {
        let id = ic.wrappedValue.assetID
        let f = AssetStore.shared.focus(id, data: model.document.assetData(id))
        ic.wrappedValue.focusX = f.midX
        ic.wrappedValue.focusY = f.midY
    }
}

private struct FillSection: View {
    @Binding var layer: Layer

    private var f: Binding<FillContent> {
        Binding(get: { layer.fillContent ?? FillContent(style: .solid, colors: []) }, set: { layer.fillContent = $0 })
    }

    var body: some View {
        PanelSection("Painted Ground") {
            FieldRow("Style") {
                Picker("", selection: f.style) { ForEach(FillStyle.allCases) { Text($0.label).tag($0) } }.labelsHidden()
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(f.wrappedValue.colors.enumerated()), id: \.offset) { i, _ in
                    HStack {
                        RGBAPicker(label: i == 0 ? "Colors" : "", color: Binding(get: { f.wrappedValue.colors[safe: i] ?? .black }, set: { if i < f.wrappedValue.colors.count { f.wrappedValue.colors[i] = $0 } }))
                        if f.wrappedValue.colors.count > 1 {
                            Button { f.wrappedValue.colors.remove(at: i) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                        }
                    }
                }
                HStack {
                    Button { f.wrappedValue.colors.append(ColorAdvisor.opposite(f.wrappedValue.colors.last ?? .ink)) } label: { Label("Add Opposite", systemImage: "plus") }
                    Button { f.wrappedValue.colors.append((f.wrappedValue.colors.last ?? .ink).adjusting(hue: 30)) } label: { Label("Add Neighbor", systemImage: "plus") }
                }
                .controlSize(.small)
            }
            ValueSlider(label: "Angle", value: f.angle, range: 0...360) { String(format: "%.0f°", $0) }
            ValueSlider(label: "Amount", value: f.intensity, range: 0...1)
            HStack {
                Text("Variation \(f.wrappedValue.seed)").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button { f.wrappedValue.seed = Int.random(in: 1...99_999) } label: { Label("Shuffle", systemImage: "dice") }.controlSize(.small)
            }
        }
    }
}

private struct ShapeSection: View {
    @Binding var layer: Layer

    private var s: Binding<ShapeContent> {
        Binding(get: { layer.shapeContent ?? ShapeContent(kind: .rectangle) }, set: { layer.shapeContent = $0 })
    }

    var body: some View {
        PanelSection("Shape") {
            FieldRow("Kind") {
                Picker("", selection: s.kind) { ForEach(ShapeKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) } }.labelsHidden()
            }
            Toggle("Fill", isOn: Binding(get: { s.wrappedValue.fill != nil }, set: { s.wrappedValue.fill = $0 ? (s.wrappedValue.stroke ?? .nearWhite) : nil })).controlSize(.small)
            if let fill = s.wrappedValue.fill {
                RGBAPicker(label: "Fill", color: Binding(get: { fill }, set: { s.wrappedValue.fill = $0 }))
            }
            Toggle("Stroke", isOn: Binding(get: { s.wrappedValue.stroke != nil }, set: { s.wrappedValue.stroke = $0 ? (s.wrappedValue.fill ?? .nearWhite) : nil })).controlSize(.small)
            if let stroke = s.wrappedValue.stroke {
                RGBAPicker(label: "Stroke", color: Binding(get: { stroke }, set: { s.wrappedValue.stroke = $0 }))
                ValueSlider(label: "Weight", value: s.strokeWidth, range: 0.001...0.03) { String(format: "%.1f", $0 * 1000) }
            }
            if s.wrappedValue.kind == .roundedRect {
                ValueSlider(label: "Corners", value: s.cornerRadius, range: 0...0.5)
            }
        }
    }
}

private struct AppearanceSection: View {
    @Binding var layer: Layer

    var body: some View {
        PanelSection("Blending") {
            ValueSlider(label: "Opacity", value: $layer.opacity, range: 0...1)
            FieldRow("Mode") {
                Picker("", selection: $layer.blend) { ForEach(BlendMode.allCases) { Text($0.label).tag($0) } }.labelsHidden()
            }
            FieldRow("Edges") {
                Picker("", selection: $layer.fade) { ForEach(FadeEdge.allCases) { Text($0.label).tag($0) } }.labelsHidden()
            }
            if layer.fade != .none {
                ValueSlider(label: "Softness", value: $layer.fadeAmount, range: 0.05...1)
            }
            FieldRow("Cut into") {
                Picker("", selection: $layer.clipShape) {
                    Text("None").tag(ShapeKind?.none)
                    ForEach(ShapeKind.clipShapes) { Text($0.label).tag(ShapeKind?.some($0)) }
                }
                .labelsHidden()
            }
            Toggle("Shadow", isOn: Binding(get: { layer.shadow != nil }, set: { layer.shadow = $0 ? ShadowStyle() : nil })).controlSize(.small)
            if let sh = layer.shadow {
                let sb = Binding(get: { sh }, set: { layer.shadow = $0 })
                RGBAPicker(label: "Color", color: sb.color)
                ValueSlider(label: "Blur", value: sb.radius, range: 0...0.06) { String(format: "%.1f", $0 * 1000) }
                ValueSlider(label: "Drop", value: sb.dy, range: -0.03...0.03) { String(format: "%.1f", $0 * 1000) }
            }
        }
    }
}

private struct GeometrySection: View {
    @Environment(EditorModel.self) private var model
    @Binding var layer: Layer

    var body: some View {
        PanelSection("Position") {
            HStack(spacing: 8) {
                num("X", $layer.frame.x)
                num("Y", $layer.frame.y)
            }
            HStack(spacing: 8) {
                num("W", $layer.frame.w)
                num("H", $layer.frame.h)
            }
            HStack(spacing: 2) {
                alignButton(.left, "align.horizontal.left", "Align to left margin")
                alignButton(.centerX, "align.horizontal.center", "Center horizontally")
                alignButton(.right, "align.horizontal.right", "Align to right margin")
                Divider().frame(height: 16).padding(.horizontal, 4)
                alignButton(.top, "align.vertical.top", "Align to top margin")
                alignButton(.middle, "align.vertical.center", "Center vertically")
                alignButton(.bottom, "align.vertical.bottom", "Align to bottom margin")
            }
            ValueSlider(label: "Rotation", value: $layer.rotation, range: -180...180) { String(format: "%.0f°", $0) }
            HStack {
                Button("Fill Cover") { layer.frame = .full }
                Button("Center") { layer.frame.x = (1 - layer.frame.w) / 2 }
                Button("Golden ↑") { layer.frame.y = Golden.minor - layer.frame.h / 2 }
                Button("Golden ↓") { layer.frame.y = Golden.major - layer.frame.h / 2 }
            }
            .controlSize(.small)
            Toggle("Lock position", isOn: $layer.isLocked).controlSize(.small)
        }
    }

    private func alignButton(_ a: LayerAlign, _ symbol: String, _ help: String) -> some View {
        Button { model.align(a) } label: { Image(systemName: symbol).frame(width: 26, height: 20) }
            .buttonStyle(.borderless)
            .help(help)
            .accessibilityLabel(help)
    }

    private func num(_ label: String, _ v: Binding<Double>) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 14)
            TextField("", value: Binding(get: { (v.wrappedValue * 100 * 10).rounded() / 10 }, set: { v.wrappedValue = $0 / 100 }), format: .number)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11).monospacedDigit())
            Text("%").font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
}

private struct AdjustSection: View {
    @Binding var layer: Layer

    var body: some View {
        PanelSection("Adjust", trailing: layer.adjust.isIdentity ? nil : AnyView(
            Button("Reset") { layer.adjust = Adjustments() }.buttonStyle(.link).font(.system(size: 11)))) {
            ValueSlider(label: "Exposure", value: $layer.adjust.exposure, range: -1...1, format: signed)
            ValueSlider(label: "Contrast", value: $layer.adjust.contrast, range: -1...1, format: signed)
            ValueSlider(label: "Saturation", value: $layer.adjust.saturation, range: -1...1, format: signed)
            ValueSlider(label: "Warmth", value: $layer.adjust.warmth, range: -1...1, format: signed)
            ValueSlider(label: "Sharpness", value: $layer.adjust.sharpness, range: -1...1, format: signed)
            ValueSlider(label: "Blur", value: $layer.adjust.blur, range: 0...1)
        }
    }

    private func signed(_ v: Double) -> String { String(format: "%+.0f", v * 100) }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
