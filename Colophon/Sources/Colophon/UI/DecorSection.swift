import SwiftUI

/// Inspector for a border, corner set, divider, badge or banner layer.
struct DecorSection: View {
    @Environment(EditorModel.self) private var model
    @Binding var layer: Layer
    @State private var browsing = false

    private var x: Binding<DecorContent> {
        Binding(get: { layer.decorContent ?? DecorContent(itemID: "", color: .nearWhite) }, set: { layer.decorContent = $0 })
    }

    var body: some View {
        let item = DecorLibrary.shared.item(x.wrappedValue.itemID)
        PanelSection(item.map { $0.kind.rawValue.capitalized } ?? "Decor") {
            FieldRow("Design") {
                Button { browsing = true } label: {
                    Text(item?.name ?? "Choose…").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            RGBAPicker(label: "Color", color: x.color)
            Toggle("Second color", isOn: Binding(get: { x.wrappedValue.color2 != nil }, set: { on in
                x.wrappedValue.color2 = on ? PaletteRoles(model.document.palette).accent : nil
            })).controlSize(.small)
            if let c2 = x.wrappedValue.color2 {
                RGBAPicker(label: "Second", color: Binding(get: { c2 }, set: { x.wrappedValue.color2 = $0 }))
            }
            if let item, item.defaultText != nil {
                FieldRow("Text") {
                    TextField(item.defaultText ?? "", text: Binding(get: { x.wrappedValue.text ?? item.defaultText ?? "" },
                                                                   set: { x.wrappedValue.text = $0 }))
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack {
                Button("Fit to Cover") { layer.frame = .full }.disabled(item?.kind != .border && item?.kind != .corners)
                Button("Use Cover Colors") {
                    if let item {
                        let (a, b) = DecorLibrary.shared.colors(for: item, palette: PaletteRoles(model.document.palette))
                        x.wrappedValue.color = a
                        x.wrappedValue.color2 = b
                    }
                }
            }
            .controlSize(.small)
        }
        .sheet(isPresented: $browsing) {
            DecorBrowserSheet(kind: item?.kind, palette: model.document.palette) { id in
                x.wrappedValue.itemID = id
                if let picked = DecorLibrary.shared.item(id) { layer.name = picked.name }
            }
        }
    }
}
