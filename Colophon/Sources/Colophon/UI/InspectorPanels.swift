import AppKit
import CoreImage
import SwiftUI

// MARK: - Effects

struct EffectsInspector: View {
    @Environment(EditorModel.self) private var model
    @State private var query = ""
    @State private var family: EffectFamily? = .looks

    var body: some View {
        let results = EffectLibrary.shared.search(query, family: family)
        VStack(spacing: 0) {
            applied
            VStack(spacing: 8) {
                TextField("Search \(EffectLibrary.shared.presets.count.formatted()) effects: noir, teal, grain…", text: $query)
                    .textFieldStyle(.roundedBorder)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chip(nil, "All")
                        ForEach(EffectFamily.allCases) { f in chip(f, f.rawValue) }
                    }
                }
            }
            .padding(12)
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 10) {
                    ForEach(results.prefix(600)) { p in
                        EffectTile(preset: p)
                    }
                }
                .padding(12)
                if results.count > 600 {
                    Text("Showing 600 of \(results.count.formatted()). Search or pick a family to narrow it down.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 12)
                }
            }
        }
    }

    private func chip(_ f: EffectFamily?, _ label: String) -> some View {
        let on = family == f
        return Button { family = f } label: {
            HStack(spacing: 4) {
                if let f { Image(systemName: f.symbol).font(.system(size: 10)) }
                Text(label).font(.system(size: 11, weight: on ? .semibold : .regular))
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(on ? Theme.accent.opacity(0.18) : Color.primary.opacity(0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(on ? Theme.accent : Color.clear))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var applied: some View {
        if let id = model.effectTarget, let layer = model.document.layer(id) {
            PanelSection("On \(layer.name)") {
                if layer.effects.isEmpty {
                    Text("Click any effect below to apply it. Stack as many as you like; each has its own strength.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(layer.effects) { e in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(EffectLibrary.shared.preset(e.presetID)?.name ?? e.presetID).font(.system(size: 11)).lineLimit(1)
                                Slider(value: amountBinding(id, e.id), in: 0...1).controlSize(.mini)
                            }
                            Button { remove(id, e.id) } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.borderless).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func amountBinding(_ layerID: UUID, _ effectID: UUID) -> Binding<Double> {
        Binding(
            get: { model.document.layer(layerID)?.effects.first { $0.id == effectID }?.amount ?? 1 },
            set: { v in
                model.mutate(undoKey: "fx-\(effectID)") { d in
                    if let i = d.index(of: layerID), let j = d.layers[i].effects.firstIndex(where: { $0.id == effectID }) { d.layers[i].effects[j].amount = v }
                }
            })
    }

    private func remove(_ layerID: UUID, _ effectID: UUID) {
        model.mutate { d in if let i = d.index(of: layerID) { d.layers[i].effects.removeAll { $0.id == effectID } } }
    }
}

/// Thumbnail rendering for effect tiles, cached per base image version.
final class EffectThumbCache {
    static let shared = EffectThumbCache()
    private let cache = NSCache<NSString, CGImage>()

    func image(_ preset: EffectPreset, base: CGImage, version: Int) -> CGImage? {
        let key = "\(preset.id)#\(version)" as NSString
        if let c = cache.object(forKey: key) { return c }
        let ci = CIImage(cgImage: base)
        let out = preset.apply(ci, EffectContext(scale: CGFloat(base.height) / 1000, seed: 3)).cropped(to: ci.extent)
        guard let img = Gfx.render(out, extent: ci.extent) else { return nil }
        cache.setObject(img, forKey: key)
        return img
    }
}

private struct EffectTile: View {
    @Environment(EditorModel.self) private var model
    let preset: EffectPreset
    @State private var thumb: CGImage?
    @State private var hover = false

    var body: some View {
        Button { model.applyEffect(preset.id) } label: {
            VStack(spacing: 4) {
                ZStack {
                    if let thumb {
                        Image(decorative: thumb, scale: 1).resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color.primary.opacity(0.06))
                    }
                }
                .frame(width: 88, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(hover ? Theme.accent : Theme.hairline, lineWidth: hover ? 2 : 1))
                Text(preset.name)
                    .font(.system(size: 9.5))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 88, height: 26, alignment: .top)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(preset.name)
        .task(id: "\(preset.id)-\(model.effectBaseVersion)") {
            guard let base = model.effectBase else { return }
            let version = model.effectBaseVersion
            let p = preset
            thumb = await Task.detached(priority: .utility) { EffectThumbCache.shared.image(p, base: base, version: version) }.value
        }
    }
}

// MARK: - Color

struct ColorInspector: View {
    @Environment(EditorModel.self) private var model
    @State private var base = RGBA(hex: "E4572E")
    @State private var harmony: Harmony = .complementary
    @State private var blendA = RGBA(hex: "1B2A4A")
    @State private var blendB = RGBA(hex: "F2A541")

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PanelSection("Cover Palette", trailing: AnyView(
                    Button("From Photo") { model.reextractPalette() }.buttonStyle(.link).font(.system(size: 11))
                        .disabled(model.document.assetOrder.isEmpty))) {
                    swatchRow(model.document.palette)
                    Text(model.selection == nil ? "Select a layer, then click a swatch to color it." : "Click a swatch to apply it to the selected layer.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    if let tl = model.document.textLayer(role: .title), let bg = model.insightBackground, let t = tl.textContent {
                        let s = PixelSampler.stats(bg, region: tl.frame)
                        let ratio = t.color.contrast(with: s.mean)
                        HStack(spacing: 8) {
                            Image(systemName: ratio >= 4.5 ? "checkmark.circle.fill" : (ratio >= 3 ? "exclamationmark.circle.fill" : "xmark.octagon.fill"))
                                .foregroundStyle(ratio >= 4.5 ? Color.green : (ratio >= 3 ? Color.orange : Color.red))
                            Text(String(format: "Title contrast %.1f:1", ratio)).font(.system(size: 12, weight: .medium))
                            Spacer()
                            Swatch(color: t.color, size: 16)
                            Text("on").font(.system(size: 10)).foregroundStyle(.secondary)
                            Swatch(color: s.mean, size: 16)
                        }
                    }
                }

                PanelSection("Harmony") {
                    HStack {
                        RGBAPicker(label: "Base", color: $base, supportsOpacity: false)
                        Button { model.pickColorFromScreen() } label: { Label("Pick", systemImage: "eyedropper") }
                            .controlSize(.small)
                            .help("Pick any color on screen. It's applied to the selected layer, or added to the palette.")
                    }
                    HStack(spacing: 6) {
                        ForEach(model.document.palette.prefix(6).indices, id: \.self) { i in
                            Button { base = model.document.palette[i] } label: { Swatch(color: model.document.palette[i], size: 16) }.buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    FieldRow("Scheme") {
                        Picker("", selection: $harmony) { ForEach(Harmony.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden()
                    }
                    Text(harmony.explanation).font(.system(size: 11)).foregroundStyle(.secondary)
                    swatchRow(harmony.colors(from: base), size: 34)
                    HStack {
                        Button("Use as Palette") { model.mutate { d in d.palette = harmony.colors(from: base) } }
                        Button("Opposite of Base") { base = ColorAdvisor.opposite(base) }
                    }
                    .controlSize(.small)
                }

                PanelSection("Shades & Tints") {
                    swatchRow(base.shades(9), size: 24)
                    swatchRow((0..<9).map { base.withSaturation(Double($0) / 8) }, size: 24)
                }

                PanelSection("Blend Two Colors") {
                    HStack {
                        ColorPicker("", selection: Binding(get: { blendA.color }, set: { blendA = RGBA(color: $0) })).labelsHidden()
                        Image(systemName: "arrow.left.and.right").foregroundStyle(.secondary)
                        ColorPicker("", selection: Binding(get: { blendB.color }, set: { blendB = RGBA(color: $0) })).labelsHidden()
                        Spacer()
                        Button("Opposites") { blendB = ColorAdvisor.opposite(blendA) }.controlSize(.small)
                        Button("From Palette") {
                            let p = PaletteRoles(model.document.palette)
                            blendA = p.dark
                            blendB = p.accent
                        }
                        .controlSize(.small)
                    }
                    LinearGradient(colors: [blendA.color, blendB.color], startPoint: .leading, endPoint: .trailing)
                        .frame(height: 18).clipShape(RoundedRectangle(cornerRadius: 4))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        blendButton("Gradient Wash", "square.lefthalf.filled", .linear, .softLight, 0.75)
                        blendButton("Mesh Blend", "circle.hexagongrid", .meshBlend, .color, 0.5)
                        blendButton("Paint Smear", "scribble.variable", .paintSmear, .overlay, 0.7)
                        blendButton("Watercolor", "drop", .watercolor, .multiply, 0.8)
                        blendButton("Smoke", "smoke", .smoke, .screen, 0.7)
                        blendButton("Light Glow", "sun.max", .radial, .screen, 0.6)
                    }
                    .controlSize(.small)
                    Text("Each adds a new layer above your artwork and below the type, with a blend mode chosen to mix rather than cover.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            if let first = model.document.palette.first(where: { $0.hsl.s > 0.25 }) ?? model.document.palette.first { base = first }
            let p = PaletteRoles(model.document.palette)
            blendA = p.dark
            blendB = p.accent
        }
    }

    private func swatchRow(_ colors: [RGBA], size: CGFloat = 26) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                Button { model.applyColor(c) } label: { Swatch(color: c, size: size) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Copy \(c.hex)") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(c.hex, forType: .string)
                        }
                        Button("Add to Palette") { model.mutate { d in d.palette.append(c) } }
                    }
            }
            Spacer(minLength: 0)
        }
    }

    private func blendButton(_ title: String, _ symbol: String, _ style: FillStyle, _ mode: BlendMode, _ opacity: Double) -> some View {
        Button {
            let colors = style == .radial ? [blendB.withAlpha(0.9), blendA.withAlpha(0)] : [blendA, blendB, blendA.mixed(with: blendB, 0.5)]
            var l = Layer.fill(style, colors: colors, angle: 90, seed: Int.random(in: 1...99_999), intensity: 0.6)
            l.blend = mode
            l.opacity = opacity
            l.name = title
            model.mutate { d in
                let i = d.layers.firstIndex { $0.textContent != nil } ?? d.layers.count
                d.layers.insert(l, at: i)
            }
            model.selection = l.id
        } label: {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Ideas

struct IdeasInspector: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Button { model.autoPolish() } label: {
                    HStack {
                        Image(systemName: "wand.and.rays")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Polish").font(.system(size: 13, weight: .semibold))
                            Text("Checks every line of type against what's behind it and fixes color, shadow and scrims.")
                                .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.accent.opacity(0.5)))
                }
                .buttonStyle(.plain)

                if model.suggestions.isEmpty {
                    ProgressView().padding(30)
                }
                ForEach(model.suggestions) { s in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: s.symbol)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.title).font(.system(size: 12, weight: .semibold))
                            Text(s.detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Button("Try") { model.apply(s) }.controlSize(.small)
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: Theme.radius))
                }
                Text("Every idea is one undo away (Command-Z).")
                    .font(.system(size: 11)).foregroundStyle(.tertiary).padding(.top, 4)
            }
            .padding(12)
        }
    }
}

// MARK: - Check

struct CheckInspector: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PanelSection("Store") {
                    Picker("", selection: $model.targetStoreID) {
                        ForEach(StoreSpec.all) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    Text(model.targetStore.note).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if let p = model.preview {
                    PanelSection("Thumbnail Test", trailing: AnyView(
                        Button("Compare…") { model.showCompare = true }.buttonStyle(.link).font(.system(size: 11)))) {
                        HStack(alignment: .bottom, spacing: 14) {
                            ForEach([48.0, 80.0, 120.0], id: \.self) { w in
                                VStack(spacing: 4) {
                                    Image(decorative: p, scale: 1).resizable().interpolation(.medium)
                                        .frame(width: w, height: w * model.document.canvas.aspect)
                                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                                    Text("\(Int(w))pt").font(.system(size: 9)).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                PanelSection("Design Score", trailing: model.critique == nil ? nil : AnyView(
                    Menu("Fix") {
                        Button("Fix colors, lifts and backings") { model.autoRepair(moveType: false) }
                        Button("Fix everything, including moving type") { model.autoRepair(moveType: true) }
                    }.controlSize(.small).fixedSize())) {
                    if let c = model.critique {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(Int(c.score))").font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(c.score >= 84 ? Color.green : c.score >= 68 ? Color.orange : Color.red)
                            Text(c.grade).font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
                            Spacer()
                            Text(c.issues.isEmpty ? "Nothing to fix" : "\(c.issues.count) note\(c.issues.count == 1 ? "" : "s")")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Text("Measured like an art director would: contrast under every line, collisions, trim, faces, thumbnail size.")
                            .font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Toggle("Show where readers look first", isOn: Binding(get: { model.showAttention }, set: { on in model.showAttention = on; model.scheduleInsights() }))
                            .controlSize(.small).font(.system(size: 11))
                        ForEach(c.issues) { issue in
                            HStack(alignment: .top, spacing: 9) {
                                icon(issue.severity)
                                Text(issue.message).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 4)
                                if let id = issue.layerID, model.document.layer(id) != nil {
                                    Button("Select") { model.selection = id }.buttonStyle(.link).font(.system(size: 11))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                PanelSection("Taste", trailing: TasteEngine.shared.isReady ? nil : AnyView(
                    Button("Install") { model.installTaste() }.controlSize(.small))) {
                    tasteBody
                }
                PanelSection("Checks") {
                    if model.preflight.isEmpty { ProgressView().frame(maxWidth: .infinity) }
                    ForEach(model.preflight) { issue in
                        HStack(alignment: .top, spacing: 9) {
                            icon(issue.severity)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.title).font(.system(size: 12, weight: .medium))
                                Text(issue.detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 4)
                            if let fix = issue.fix {
                                Button(fix.label) { model.apply(fix) }.controlSize(.small)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }

    @ViewBuilder private var tasteBody: some View {
        let engine = TasteEngine.shared
        switch engine.status {
        case .notInstalled:
            Text("A local CLIP model (OpenAI, open source, about 280 MB, downloaded once) reads the cover the way a browsing reader would: which genre it looks like, its mood, and whether it reads as professionally designed. Nothing leaves your Mac.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        case .downloading(let p):
            ProgressView(value: p) { Text("Downloading the taste model… \(Int(p * 100))%").font(.system(size: 11)) }
        case .installing:
            ProgressView { Text("Compiling the model for this Mac…").font(.system(size: 11)) }
        case .failed(let why):
            Text("Couldn't install: \(why)").font(.system(size: 11)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            Button("Try again") { model.installTaste() }.controlSize(.small)
        case .ready:
            if let t = model.taste {
                HStack(spacing: 14) {
                    tasteStat("Reads as pro", t.professionalism)
                    if let a = t.aesthetic { tasteStat("Aesthetic", a) }
                    tasteStat("Fits \(model.document.book.genre.label)", t.fitForBook)
                }
                if (t.genreFit.first?.score ?? 0) < 0.2 {
                    Text("No strong genre signal: the cover could sit on several shelves.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(t.genreFit.prefix(4).enumerated()), id: \.offset) { _, g in
                        HStack(spacing: 8) {
                            Text(g.genre.label).font(.system(size: 11)).frame(width: 110, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.primary.opacity(0.08))
                                    Capsule().fill(g.genre == model.document.book.genre ? Color.accentColor : Color.secondary.opacity(0.6))
                                        .frame(width: max(2, geo.size.width * g.score))
                                }
                            }
                            .frame(height: 6)
                            Text("\(Int(g.score * 100))%").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).frame(width: 34, alignment: .trailing)
                        }
                    }
                }
                if !t.moodTags.isEmpty {
                    Text("Reads as: " + t.moodTags.joined(separator: ", ")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    private func tasteStat(_ label: String, _ value: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value * 100))").font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(value >= 0.6 ? Color.green : value >= 0.4 ? Color.orange : Color.red)
            Text(label).font(.system(size: 9.5)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func icon(_ s: Severity) -> some View {
        let (name, color): (String, Color) = {
            switch s {
            case .pass: return ("checkmark.circle.fill", .green)
            case .info: return ("info.circle.fill", .blue)
            case .warning: return ("exclamationmark.triangle.fill", .orange)
            case .fail: return ("xmark.octagon.fill", .red)
            }
        }()
        return Image(systemName: name).foregroundStyle(color).font(.system(size: 13))
    }
}

// MARK: - Book

struct BookInspector: View {
    @Environment(EditorModel.self) private var model
    @State private var blurbTone: BlurbWriter.Tone = .gripping

    /// What the title and lines give off, and the palettes and genre that suit it.
    @ViewBuilder private var moodSection: some View {
        let mood = model.briefMood
        if !mood.tags.isEmpty {
            PanelSection("Mood of the Brief") {
                Text("Reads as " + mood.tags.joined(separator: ", ") + ".").font(.system(size: 12))
                if let g = BriefMood.genreHint(for: mood), g != model.document.book.genre {
                    HStack(spacing: 6) {
                        Text("Sounds like \(g.label).").font(.system(size: 11)).foregroundStyle(.secondary)
                        Button("Set genre") { var b = model.document.book; b.genre = g; model.updateBook(b) }.buttonStyle(.link).font(.system(size: 11))
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(BriefMood.palettes(for: mood).prefix(6).enumerated()), id: \.offset) { _, p in
                            Button { model.applyPalette(p.colors, name: p.name) } label: {
                                VStack(spacing: 3) {
                                    HStack(spacing: 0) {
                                        ForEach(Array(p.colors.enumerated()), id: \.offset) { _, c in Rectangle().fill(c.color) }
                                    }
                                    .frame(width: 64, height: 18).clipShape(RoundedRectangle(cornerRadius: 3))
                                    Text(p.name).font(.system(size: 9)).lineLimit(1).frame(width: 64)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Text("Palettes that suit the mood; click one to use it.").font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        let book = model.bookBinding
        ScrollView {
            VStack(spacing: 0) {
                PanelSection("Brief") {
                    field("Title", book.title)
                    field("Subtitle", book.subtitle)
                    field("Author", book.author)
                    field("Series", book.series)
                    field("Tagline", book.tagline)
                    FieldRow("Genre") {
                        Picker("", selection: book.genre) { ForEach(Genre.allCases) { Text($0.label).tag($0) } }.labelsHidden()
                    }
                    Text("Edits flow straight into the matching text on the cover.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                backCoverSection(book)
                moodSection
                PanelSection("Canvas") {
                    Text("\(model.document.canvas.width) x \(model.document.canvas.height) px").font(.system(size: 12, design: .monospaced))
                    HStack {
                        Button("1:1.6 Kindle") { model.mutate { d in d.canvas = CanvasSpec(width: 1600, height: 2560) } }
                        Button("2:3 Most Stores") { model.mutate { d in d.canvas = CanvasSpec(width: 1600, height: 2400) } }
                    }
                    .controlSize(.small)
                    FieldRow("Backdrop") {
                        ColorPicker("", selection: Binding(get: { model.document.background.color }, set: { c in model.mutate(undoKey: "bg") { d in d.background = RGBA(color: c) } }), supportsOpacity: false)
                            .labelsHidden()
                    }
                }
                PanelSection("Pictures") {
                    Text("\(model.document.assetOrder.count) imported").font(.system(size: 12))
                    Button { model.chooseImages() } label: { Label("Add Photo or Artwork…", systemImage: "photo.badge.plus") }
                        .controlSize(.small)
                }
                PanelSection("Series") {
                    Text("Give every book in a series the same design. Type the titles and Colophon exports matching covers plus a lineup image.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button { model.showSeries = true } label: { Label("Make Series Covers…", systemImage: "books.vertical") }
                        .controlSize(.small)
                }
                PanelSection("Start Over") {
                    Button { model.generateVariations() } label: { Label("Design New Covers from This Brief", systemImage: "sparkles") }
                    Text("Your current design stays one undo away after you pick a new one.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func field(_ label: String, _ b: Binding<String>) -> some View {
        FieldRow(label) { TextField(label, text: b).textFieldStyle(.roundedBorder) }
    }

    /// Synopsis in, blurb out: drafted on device, then edited by hand.
    private func backCoverSection(_ book: Binding<BookInfo>) -> some View {
        let synopsisWords = BlurbWriter.wordCount(book.wrappedValue.synopsis)
        let blurbWords = BlurbWriter.wordCount(book.wrappedValue.blurb)
        return PanelSection("Back Cover") {
            Text("Synopsis").font(.system(size: 11)).foregroundStyle(.secondary)
            TextEditor(text: book.synopsis)
                .font(.system(size: 12))
                .frame(minHeight: 90)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            Picker("", selection: $blurbTone) {
                ForEach(BlurbWriter.Tone.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            HStack(spacing: 8) {
                Button { model.draftBlurb(tone: blurbTone) } label: { Label("Draft Blurb", systemImage: "text.quote") }
                    .controlSize(.small)
                    .disabled(synopsisWords < 30 || model.isDraftingBlurb)
                if model.isDraftingBlurb {
                    ProgressView().controlSize(.small)
                } else if synopsisWords < 30 {
                    Text("\(synopsisWords)/30 words").font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
            Text("Uses Apple's on-device model on macOS 26; otherwise drafts from your synopsis. Nothing leaves your Mac.")
                .font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Blurb").font(.system(size: 11)).foregroundStyle(.secondary)
            TextEditor(text: book.blurb)
                .font(.system(size: 12))
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            HStack {
                Text("\(blurbWords) words").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Button("Shorten to 150 words") {
                    var b = book.wrappedValue
                    b.blurb = BlurbWriter.shorten(b.blurb, to: 150)
                    model.updateBook(b)
                }
                .controlSize(.small)
                .disabled(blurbWords <= 150)
            }
        }
    }
}

// MARK: - Export

struct ExportSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = ["kdp", "gplay", "apple"]
    @State private var format: ExportFormat = .jpeg
    @State private var quality = 0.92
    @State private var progress = 0
    @State private var running = false
    @State private var written: [URL] = []
    @State private var mockups: Set<MockupKind> = [.book3D, .social]
    @State private var ads: Set<AdKind> = []
    @State private var headline = ""
    @State private var cta = "Available now"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export for Stores").font(.system(size: 18, weight: .semibold))
                Text("One file per store at its recommended size. The layout re-flows to each shape, so check the Check tab for any store you pick.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(StoreSpec.all) { s in
                    Toggle(isOn: Binding(get: { selected.contains(s.id) }, set: { on in if on { selected.insert(s.id) } else { selected.remove(s.id) } })) {
                        HStack {
                            Text(s.name).font(.system(size: 13))
                            Spacer()
                            Text("\(s.width) x \(s.height)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.radius))
            VStack(alignment: .leading, spacing: 6) {
                Text("Marketing Images").font(.system(size: 12, weight: .semibold))
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                    ForEach(MockupKind.allCases) { k in
                        Toggle(k.label, isOn: Binding(get: { mockups.contains(k) }, set: { on in if on { mockups.insert(k) } else { mockups.remove(k) } }))
                    }
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.radius))
            VStack(alignment: .leading, spacing: 6) {
                Text("Ads & Promo").font(.system(size: 12, weight: .semibold))
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                    ForEach(AdKind.allCases) { k in
                        Toggle(k.label, isOn: Binding(get: { ads.contains(k) }, set: { on in if on { ads.insert(k) } else { ads.remove(k) } }))
                    }
                }
                if !ads.isEmpty {
                    HStack {
                        TextField("Headline", text: $headline).textFieldStyle(.roundedBorder)
                        TextField("Button", text: $cta).textFieldStyle(.roundedBorder).frame(width: 140)
                    }
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.radius))
            HStack {
                Picker("Format", selection: $format) { ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                if format == .jpeg {
                    Slider(value: $quality, in: 0.7...1) { Text("Quality") }
                    Text("\(Int(quality * 100))").font(.system(size: 11).monospacedDigit()).frame(width: 26)
                }
            }
            if running {
                ProgressView(value: Double(progress), total: Double(max(1, selected.count + mockups.count + ads.count)))
            }
            if !written.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("\(written.count) files exported").font(.system(size: 12))
                    Spacer()
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(written) }
                }
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Export…") { export() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled((selected.isEmpty && mockups.isEmpty && ads.isEmpty) || running)
            }
        }
        .padding(22)
        .frame(width: 640)
        .onAppear { if headline.isEmpty { headline = AdRenderer.defaultHeadline(model.document) } }
    }

    private func export() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let specs = StoreSpec.all.filter { selected.contains($0.id) }
        let doc = model.document
        let fmt = format, q = quality
        let kinds = MockupKind.allCases.filter { mockups.contains($0) }
        let adKinds = AdKind.allCases.filter { ads.contains($0) }
        let head = headline.isEmpty ? AdRenderer.defaultHeadline(doc) : headline
        let button = cta.isEmpty ? "Available now" : cta
        running = true
        progress = 0
        written = []
        Task.detached(priority: .userInitiated) {
            let access = folder.startAccessingSecurityScopedResource()
            var urls = Exporter.export(doc, specs: specs, format: fmt, quality: q, folder: folder) { n in
                Task { @MainActor in progress = n }
            }
            let base = Exporter.safeFileName(doc.book.title.isEmpty ? "Cover" : doc.book.title)
            for (n, kind) in kinds.enumerated() {
                guard let img = MockupRenderer.render(kind, doc: doc) else { continue }
                let f: ExportFormat = kind.needsAlpha ? .png : fmt
                let url = folder.appendingPathComponent("\(base) - \(kind.fileSuffix).\(f.ext)")
                if Exporter.write(img, to: url, format: f, quality: q) { urls.append(url) }
                let done = specs.count + n + 1
                Task { @MainActor in progress = done }
            }
            for (n, kind) in adKinds.enumerated() {
                guard let img = AdRenderer.render(kind, doc: doc, headline: head, cta: button) else { continue }
                let url = folder.appendingPathComponent("\(base) - \(kind.fileSuffix).\(fmt == .png ? "png" : "jpg")")
                if Exporter.write(img, to: url, format: fmt == .png ? .png : .jpeg, quality: q) { urls.append(url) }
                let done = specs.count + kinds.count + n + 1
                Task { @MainActor in progress = done }
            }
            let finished = urls
            if access { folder.stopAccessingSecurityScopedResource() }
            await MainActor.run {
                written = finished
                running = false
            }
        }
    }
}


// MARK: - Series

struct SeriesSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var titles = ""
    @State private var running = false
    @State private var progress = 0
    @State private var written: [URL] = []
    @State private var preview: CGImage?

    private var titleList: [String] {
        titles.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Series Covers").font(.system(size: 18, weight: .semibold))
                Text("One title per line, in reading order. Each cover keeps this design: same layout, type, colors and effects. Only the title and the book number change.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            TextEditor(text: $titles)
                .font(.system(size: 13))
                .frame(height: 130)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            if let preview {
                Image(decorative: preview, scale: 1).resizable().aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
                    .frame(maxWidth: .infinity)
            }
            if running {
                ProgressView(value: Double(progress), total: Double(max(1, titleList.count + 1)))
            }
            if !written.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("\(written.count) files exported").font(.system(size: 12))
                    Spacer()
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(written) }
                }
            }
            HStack {
                Button("Preview Lineup") { makePreview() }.disabled(titleList.isEmpty || running)
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Export…") { export() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(titleList.isEmpty || running)
            }
        }
        .padding(22)
        .frame(width: 560)
        .onAppear {
            if titles.isEmpty { titles = model.document.book.title }
        }
    }

    private func docs() -> [CoverDocument] {
        let base = model.document
        return titleList.enumerated().map { i, t in SeriesKit.retitle(base, title: t, number: i + 1) }
    }

    private func makePreview() {
        let list = docs()
        Task.detached(priority: .userInitiated) {
            let img = SeriesKit.lineup(list, coverHeight: 320)
            await MainActor.run { preview = img }
        }
    }

    private func export() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let list = docs()
        let spec = model.targetStore
        running = true
        progress = 0
        written = []
        Task.detached(priority: .userInitiated) {
            var urls: [URL] = []
            for (i, d) in list.enumerated() {
                let name = Exporter.safeFileName("\(i + 1) - \(d.book.title)")
                var sized = d
                sized.canvas = CanvasSpec(width: spec.width, height: spec.height)
                if let img = CoverRenderer.shared.render(sized, size: CGSize(width: spec.width, height: spec.height), quality: .full) {
                    let url = folder.appendingPathComponent("\(name).jpg")
                    if Exporter.write(img, to: url, format: .jpeg, quality: 0.92) { urls.append(url) }
                }
                let done = i + 1
                await MainActor.run { progress = done }
            }
            if let lineup = SeriesKit.lineup(list) {
                let url = folder.appendingPathComponent("Series Lineup.png")
                if Exporter.write(lineup, to: url, format: .png, quality: 1) { urls.append(url) }
            }
            let finished = urls
            await MainActor.run {
                written = finished
                running = false
                progress = list.count + 1
            }
        }
    }
}
