import AppKit
import SwiftUI

/// Renders style previews: the layer's own words, styled, over the part of the cover behind them.
enum StyleTiles {
    private static let cache = NSCache<NSString, CGImage>()

    static func render(_ preset: TextStylePreset?, text: TextContent, palette: PaletteRoles, background: CGImage?,
                       region: NRect, useFont: Bool, key: String) -> CGImage? {
        let cacheKey = "\(preset?.id ?? "none")|\(key)" as NSString
        if let c = cache.object(forKey: cacheKey) { return c }
        let W = 300, H = 170
        guard let ctx = Gfx.context(W, H) else { return nil }
        let tileRect = CGRect(x: 0, y: 0, width: W, height: H)

        // Ground: the real cover under this text, aspect-filled into the tile.
        if let bg = background {
            let r = CGRect(x: region.x * Double(bg.width), y: region.y * Double(bg.height),
                           width: max(1, region.w * Double(bg.width)), height: max(1, region.h * Double(bg.height))).integral
            if let crop = bg.cropping(to: r.intersection(CGRect(x: 0, y: 0, width: bg.width, height: bg.height))) {
                let s = max(CGFloat(W) / CGFloat(crop.width), CGFloat(H) / CGFloat(crop.height))
                let dw = CGFloat(crop.width) * s, dh = CGFloat(crop.height) * s
                ctx.draw(crop, in: CGRect(x: (CGFloat(W) - dw) / 2, y: (CGFloat(H) - dh) / 2, width: dw, height: dh))
            }
        } else {
            ctx.setFillColor(palette.dark.cgColor)
            ctx.fill(tileRect)
        }
        guard let ground = ctx.makeImage() else { return nil }

        var t = text
        t.text = String(text.text.components(separatedBy: "\n").first?.prefix(14) ?? "Title")
        if t.text.trimmingCharacters(in: .whitespaces).isEmpty { t.text = "Title" }
        t.autoFit = true
        t.arc = 0
        if let preset {
            preset.apply(to: &t, palette: palette)
            if useFont, let f = preset.fonts.first(where: FontCatalog.isAvailable) { t.fontName = f }
        } else {
            t.style = TextStyle()
        }
        let box = CGSize(width: CGFloat(W) * 0.84, height: CGFloat(H) * 0.56)
        guard case let (img, pad)? = TextRenderer.render(t, box: box, canvasHeight: CGFloat(H) * 4) else { return ground }
        var raster = img
        let origin = CGPoint(x: (CGFloat(W) - box.width) / 2 - pad, y: (CGFloat(H) - box.height) / 2 - pad)
        if t.style.needsScene, let pctx = Gfx.context(img.width, img.height) {
            pctx.draw(ground, in: CGRect(x: -origin.x, y: -origin.y, width: CGFloat(W), height: CGFloat(H)))
            if let patch = pctx.makeImage(),
               let blended = TextStyler.blendIntoScene(img, background: patch, style: t.style, fontSize: box.height * 0.8) {
                raster = blended
            }
        }
        ctx.draw(raster, in: CGRect(x: origin.x, y: origin.y, width: CGFloat(img.width), height: CGFloat(img.height)))
        guard let out = ctx.makeImage() else { return nil }
        cache.setObject(out, forKey: cacheKey)
        return out
    }
}

struct StyleGallery: View {
    @Environment(EditorModel.self) private var model
    @Binding var layer: Layer
    @State private var query = ""
    @State private var family: String?
    @State private var genre: Genre?
    @State private var similarTo: String?
    @State private var shown = 40
    @State private var useFont = true

    private var library: StyleLibrary { StyleLibrary.shared }

    private var results: [TextStylePreset] {
        if let id = similarTo { return library.similar(to: id) }
        return library.search(query, family: family, genre: genre)
    }

    var body: some View {
        let found = results
        PanelSection("Style", trailing: AnyView(
            Toggle("Use style's font", isOn: $useFont).toggleStyle(.checkbox).controlSize(.small)
                .help("Also switch to a typeface designed for the style"))) {
            HStack(spacing: 6) {
                TextField("Search \(library.all.count.formatted()) styles: gold, drips, neon pink…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: query) { _, _ in similarTo = nil; shown = 40 }
                Menu {
                    Button("Any genre") { genre = nil; shown = 40 }
                    Divider()
                    ForEach(Genre.allCases) { g in Button(g.label) { genre = g; similarTo = nil; shown = 40 } }
                } label: {
                    Image(systemName: genre == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(genre.map { "Showing styles for \($0.label)" } ?? "Filter by genre")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    chip("All", selected: family == nil && similarTo == nil) { family = nil; similarTo = nil; shown = 40 }
                    ForEach(library.families, id: \.id) { f in
                        chip(f.name, selected: family == f.id && similarTo == nil) { family = f.id; similarTo = nil; shown = 40 }
                    }
                }
            }
            HStack(spacing: 8) {
                Button { surprise(from: found) } label: { Label("Surprise Me", systemImage: "dice") }
                    .help("Apply a random style from the current results")
                Button {
                    similarTo = layer.textContent?.style.presetName.isEmpty == false ? currentPresetID : nil
                    shown = 40
                } label: { Label("More Like This", systemImage: "square.stack.3d.down.right") }
                    .disabled(currentPresetID == nil)
                    .help("Styles close to the one on this layer")
                Spacer()
                Text(similarTo != nil ? "Similar styles" : "\(found.count.formatted()) styles")
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            .controlSize(.small)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                if similarTo == nil && query.isEmpty && family == nil && genre == nil {
                    StyleTile(preset: nil, layer: layer, useFont: false)
                }
                ForEach(found.prefix(shown)) { p in
                    StyleTile(preset: p, layer: layer, useFont: useFont)
                }
            }
            if found.count > shown {
                Button("Show \(min(40, found.count - shown)) more") { shown += 40 }
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var currentPresetID: String? {
        guard let name = layer.textContent?.style.presetName, !name.isEmpty else { return nil }
        return library.all.first { $0.name == name }?.id
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 10.5, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(selected ? Theme.accent.opacity(0.18) : Color.primary.opacity(0.05), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func surprise(from list: [TextStylePreset]) {
        guard let p = list.randomElement() else { return }
        let id = layer.id
        let palette = PaletteRoles(model.document.palette)
        let f = useFont
        model.mutate { d in
            guard let i = d.index(of: id), var t = d.layers[i].textContent else { return }
            p.apply(to: &t, palette: palette)
            if f, let font = p.fonts.first(where: FontCatalog.isAvailable) { t.fontName = font }
            d.layers[i].textContent = t
        }
        model.toast = "Applied \(p.name)"
    }
}

private struct StyleTile: View {
    @Environment(EditorModel.self) private var model
    let preset: TextStylePreset?
    let layer: Layer
    let useFont: Bool
    @State private var image: CGImage?
    @State private var hover = false

    private var selected: Bool {
        let name = layer.textContent?.style.presetName ?? ""
        return preset.map { $0.name == name } ?? (layer.textContent?.style.isActive == false)
    }

    var body: some View {
        Button { apply() } label: {
            VStack(spacing: 3) {
                ZStack {
                    if let image {
                        Image(decorative: image, scale: 2).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color.primary.opacity(0.06))
                    }
                }
                .frame(height: 70)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(selected ? Theme.accent : (hover ? Color.primary.opacity(0.4) : Theme.hairline), lineWidth: selected ? 2 : 1))
                Text(preset?.name ?? "No Style").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(preset.map { "\($0.name) (\($0.category))" } ?? "Plain type")
        .task(id: renderKey) {
            guard let t = layer.textContent else { return }
            let palette = PaletteRoles(model.document.palette)
            let bg = model.insightBackground
            let region = layer.frame
            let p = preset, f = useFont, key = renderKey
            image = await Task.detached(priority: .utility) {
                StyleTiles.render(p, text: t, palette: palette, background: bg, region: region, useFont: f, key: key)
            }.value
        }
    }

    private var renderKey: String {
        let t = layer.textContent
        return "\(t?.text.hashValue ?? 0)-\(t?.fontName ?? "")-\(t?.color.hex ?? "")-\(useFont)-\(model.document.palette.map(\.hex).joined())-\(layer.frame.x)-\(layer.frame.y)-\(model.insightBackground.map { "\($0.width)x\($0.height)" } ?? "none")-\(model.revision / 25)"
    }

    private func apply() {
        let id = layer.id
        let palette = PaletteRoles(model.document.palette)
        let p = preset, f = useFont
        model.mutate { d in
            guard let i = d.index(of: id), var t = d.layers[i].textContent else { return }
            if let p {
                p.apply(to: &t, palette: palette)
                if f, let font = p.fonts.first(where: FontCatalog.isAvailable) { t.fontName = font }
            } else {
                t.style = TextStyle()
            }
            d.layers[i].textContent = t
        }
        model.toast = preset.map { "Applied \($0.name)" } ?? "Style removed"
    }
}

/// Every pass of the style engine, for fine-tuning a preset or building one from scratch.
struct StyleControls: View {
    @Binding var t: TextContent
    @State private var open = false

    private var s: Binding<TextStyle> { $t.style }

    var body: some View {
        PanelSection("Fine-Tune Style", trailing: AnyView(
            Button(open ? "Hide" : "Show") { withAnimation { open.toggle() } }.buttonStyle(.link).font(.system(size: 11)))) {
            if open {
                group("Material") {
                    FieldRow("Surface") {
                        Picker("", selection: s.surface) { ForEach(SurfaceTexture.allCases) { Text($0.label).tag($0) } }.labelsHidden()
                    }
                    if s.wrappedValue.surface != .none {
                        ValueSlider(label: "Scale", value: s.surfaceScale, range: 0.4...3) { String(format: "%.1fx", $0) }
                        ValueSlider(label: "Tint", value: s.surfaceTint, range: 0...1)
                    }
                }
                group("Relief") {
                    ValueSlider(label: "Bevel", value: s.bevel, range: 0...1)
                    if s.wrappedValue.bevel > 0 {
                        FieldRow("Edge") {
                            Picker("", selection: s.bevelStyle) { ForEach(BevelStyle.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented).labelsHidden()
                        }
                        ValueSlider(label: "Light", value: s.lightAngle, range: 0...360) { String(format: "%.0f°", $0) }
                        ValueSlider(label: "Gloss", value: s.gloss, range: 0...1)
                    }
                    ValueSlider(label: "Inner Shadow", value: s.innerShadow, range: 0...1)
                    ValueSlider(label: "Inner Glow", value: s.innerGlow, range: 0...1)
                    if s.wrappedValue.innerGlow > 0 { optionalColor("Glow Color", s.innerGlowColor, fallback: .white) }
                }
                group("Outside the Letters") {
                    ValueSlider(label: "Outline", value: s.outline, range: 0...0.1) { String(format: "%.0f", $0 * 1000) }
                    if s.wrappedValue.outline > 0 { optionalColor("Outline Color", s.outlineColor, fallback: .nearBlack) }
                    ValueSlider(label: "2nd Outline", value: s.outline2, range: 0...0.1) { String(format: "%.0f", $0 * 1000) }
                    if s.wrappedValue.outline2 > 0 { optionalColor("2nd Color", s.outline2Color, fallback: .nearWhite) }
                    ValueSlider(label: "Outer Glow", value: s.outerGlow, range: 0...1)
                    if s.wrappedValue.outerGlow > 0 { optionalColor("Glow Color", s.outerGlowColor, fallback: t.color) }
                    ValueSlider(label: "3D Depth", value: s.extrude, range: 0...0.5)
                    ValueSlider(label: "Long Shadow", value: s.longShadow, range: 0...1)
                    if s.wrappedValue.extrude > 0 || s.wrappedValue.longShadow > 0 {
                        ValueSlider(label: "Direction", value: s.extrudeAngle, range: 0...360) { String(format: "%.0f°", $0) }
                        if s.wrappedValue.extrude > 0 { optionalColor("Depth Color", s.extrudeColor, fallback: t.color.withLightness(0.2)) }
                        if s.wrappedValue.longShadow > 0 { optionalColor("Shadow Color", s.longShadowColor, fallback: RGBA(0, 0, 0, 0.45)) }
                    }
                }
                if [.stripes, .polkaDots, .checker, .plaid, .thread, .glitter, .gradient].contains(s.wrappedValue.surface) {
                    group("Pattern Colors") {
                        optionalColor("Color 1", s.patternColor, fallback: t.color)
                        optionalColor("Color 2", s.patternColor2, fallback: ColorAdvisor.opposite(t.color))
                    }
                }
                group("Shape") {
                    ValueSlider(label: "Roundness", value: s.roundness, range: 0...1)
                    ValueSlider(label: "Drips", value: s.drips, range: 0...1)
                    ValueSlider(label: "Stitching", value: s.stitch, range: 0...1)
                    if s.wrappedValue.stitch > 0 { optionalColor("Thread", s.stitchColor, fallback: t.color.withLightness(0.92)) }
                }
                group("Shadows & Stacks") {
                    ValueSlider(label: "Drop Shadow", value: s.dropShadow, range: 0...1)
                    ValueSlider(label: "Stacked", value: s.echo, range: 0...1)
                    if s.wrappedValue.echo > 0 {
                        optionalColor("Stack 1", s.echoColor, fallback: ColorAdvisor.opposite(t.color))
                        optionalColor("Stack 2", s.echoColor2, fallback: t.color.withLightness(0.25))
                    }
                    ValueSlider(label: "Smoke", value: s.smokeTrail, range: 0...1)
                    if s.wrappedValue.smokeTrail > 0 { optionalColor("Smoke Color", s.smokeColor, fallback: t.color.withLightness(0.85)) }
                }
                group("Age & Print") {
                    FieldRow("Wear") {
                        Picker("", selection: s.wear) { ForEach(WearKind.allCases) { Text($0.label).tag($0) } }.labelsHidden()
                    }
                    if s.wrappedValue.wear != .none { ValueSlider(label: "Amount", value: s.wearAmount, range: 0...1) }
                    ValueSlider(label: "Halftone", value: s.halftone, range: 0...1)
                    ValueSlider(label: "Color Split", value: s.glitch, range: 0...1)
                }
                group("Into the Photo") {
                    ValueSlider(label: "Photo Grain", value: s.photoTexture, range: 0...1)
                    ValueSlider(label: "Wrap", value: s.photoDisplace, range: 0...1)
                    ValueSlider(label: "Light Wrap", value: s.lightWrap, range: 0...1)
                    ValueSlider(label: "Match Color", value: s.colorMatch, range: 0...1)
                    ValueSlider(label: "In Shadows", value: s.photoErode, range: 0...1)
                    ValueSlider(label: "Photo Fill", value: s.photoFill, range: 0...1)
                    Text("These read the picture behind the type, so the words take on its grain, light and color.")
                        .font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Button("Reset Style") { t.style = TextStyle() }.controlSize(.small)
            } else {
                Text(t.style.isActive ? "\(t.style.presetName.isEmpty ? "Custom style" : t.style.presetName). Show to adjust each pass." : "Pick a style above, or show the controls to build your own.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.tertiary).padding(.top, 4)
            content()
        }
    }

    private func optionalColor(_ label: String, _ b: Binding<RGBA?>, fallback: RGBA) -> some View {
        RGBAPicker(label: label, color: Binding(get: { b.wrappedValue ?? fallback }, set: { b.wrappedValue = $0 }))
    }
}
