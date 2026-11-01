import SwiftUI

/// Floating bar over the canvas while painting: tool, paint color, real pigments, size, strength, wetness.
struct PaintToolbar: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Picker("", selection: $model.tool) {
                    ForEach(PaintTool.allCases) { t in
                        Label(t.label, systemImage: t.symbol).tag(CanvasTool(rawValue: t.rawValue) ?? .paint)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 300)
                if model.tool == .paint {
                    ColorPicker("", selection: Binding(get: { model.paintColor.color }, set: { model.paintColor = RGBA(color: $0) }), supportsOpacity: false)
                        .labelsHidden()
                }
                slider("Size", $model.brushSize, 0.005...0.25)
                slider(model.tool == .smudge ? "Drag" : model.tool == .lift ? "Lift" : "Strength", $model.paintStrength, 0.05...1)
                if model.tool == .paint { slider("Wet", $model.paintWetness, 0...1) }
                Button("Done") { model.tool = .select }.controlSize(.small)
            }
            if model.tool == .paint {
                HStack(spacing: 4) {
                    ForEach(Pigments.watercolor, id: \.name) { p in
                        Button { model.paintColor = p.color } label: {
                            Circle().fill(p.color.color)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().strokeBorder(model.paintColor == p.color ? Color.white : Color.black.opacity(0.25),
                                                               lineWidth: model.paintColor == p.color ? 2 : 0.5))
                        }
                        .buttonStyle(.plain)
                        .help(p.name + " (" + p.index + ")")
                    }
                }
            }
            Text(hint).font(.system(size: 10.5)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline))
    }

    private var hint: String {
        switch model.tool {
        case .paint: return "Colors mix like real paint: blue over yellow makes green. A wetter brush picks up and blends what it passes over."
        case .smudge: return "Drag colors into each other. On a cover without paint, you smudge a copy of the artwork itself."
        case .blend: return "A wet brush: neighboring colors melt together."
        case .lift: return "Blot paint back off, like a tissue on wet watercolor."
        default: return ""
        }
    }

    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Slider(value: value, in: range).frame(width: 80).controlSize(.small)
        }
    }
}

/// Inspector for a paint layer.
struct PaintSection: View {
    @Environment(EditorModel.self) private var model
    @Binding var layer: Layer

    var body: some View {
        let strokes = layer.paintContent?.strokes ?? []
        PanelSection("Paint") {
            HStack(spacing: 6) {
                ForEach(PaintTool.allCases) { t in
                    Button { model.selection = layer.id; model.tool = CanvasTool(rawValue: t.rawValue) ?? .paint } label: {
                        Label(t.label, systemImage: t.symbol)
                    }
                }
            }
            .controlSize(.small)
            Text("\(strokes.count) strokes\(layer.paintContent?.baseAssetID != nil ? " over a copy of the artwork" : "").")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button("Undo Last Stroke") {
                    if !strokes.isEmpty { layer.paintContent?.strokes.removeLast() }
                }
                .disabled(strokes.isEmpty)
                Button("Clear") { layer.paintContent?.strokes = [] }.disabled(strokes.isEmpty)
            }
            .controlSize(.small)
            Text("Paint mixes like real pigment. Use Blending above to glaze it over the art (Multiply or Linear Burn).")
                .font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
