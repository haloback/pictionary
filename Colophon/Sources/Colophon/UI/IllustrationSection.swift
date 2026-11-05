import SwiftUI

/// Inspector for a silhouette or line-icon layer from `IllustrationLibrary`.
struct IllustrationSection: View {
    @Environment(EditorModel.self) private var model
    @Binding var layer: Layer
    @State private var browsing = false

    private var x: Binding<IllustrationContent> {
        Binding(get: { layer.illustrationContent ?? IllustrationContent(itemID: "", color: .nearWhite) },
                set: { layer.illustrationContent = $0 })
    }

    var body: some View {
        let lib = IllustrationLibrary.shared
        let item = lib.item(x.wrappedValue.itemID)
        PanelSection("Illustration") {
            FieldRow("Design") {
                Button { browsing = true } label: {
                    Text(item?.name ?? "Replace…").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let item {
                Text("\(lib.pack(item.pack)?.name ?? item.pack), \(item.style.label.lowercased())")
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            RGBAPicker(label: "Color", color: x.color)
            Toggle("Gradient to a second color", isOn: Binding(get: { x.wrappedValue.color2 != nil }, set: { on in
                x.wrappedValue.color2 = on ? PaletteRoles(model.document.palette).accent : nil
            })).controlSize(.small)
            if let c2 = x.wrappedValue.color2 {
                RGBAPicker(label: "Second", color: Binding(get: { c2 }, set: { x.wrappedValue.color2 = $0 }))
            }
            Toggle("Flip horizontally", isOn: x.flipped).controlSize(.small)
            HStack {
                Button("Replace…") { browsing = true }
                Button("Use Cover Ink") { x.wrappedValue.color = model.inkColor }
            }
            .controlSize(.small)
            if let item, let credit = lib.credit(for: item) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Credit required").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary)
                    Text(credit).font(.system(size: 10.5)).foregroundStyle(.secondary).textSelection(.enabled)
                    Text("Colophon writes a Credits.txt beside your exported covers.")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }
        .sheet(isPresented: $browsing) {
            IllustrationBrowserSheet(ink: model.inkColor) { id in
                x.wrappedValue.itemID = id
                if let picked = IllustrationLibrary.shared.item(id) { layer.name = picked.name }
            }
        }
    }
}
