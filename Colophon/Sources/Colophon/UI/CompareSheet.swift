import SwiftUI

/// Your cover beside favorites and real bestsellers, at the sizes shoppers actually see.
struct CompareSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 160
    @State private var grayscale = false
    @State private var squint = false
    @State private var darkPage = false

    private struct Item: Identifiable {
        let id: String
        let name: String
        let image: CGImage
        let isYours: Bool
        var refID: UUID?
    }

    private var items: [Item] {
        var out: [Item] = []
        if let p = model.preview { out.append(Item(id: "yours", name: "Your cover", image: p, isYours: true)) }
        for v in model.variations where v.favorite {
            if let t = v.thumbnail { out.append(Item(id: v.id.uuidString, name: v.document.archetypeName, image: t, isYours: false)) }
        }
        for r in model.compareRefs {
            out.append(Item(id: r.id.uuidString, name: r.name, image: r.image, isYours: false, refID: r.id))
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text("Compare").font(.system(size: 16, weight: .semibold))
                Picker("", selection: $height) {
                    Text("Search results").tag(CGFloat(160))
                    Text("Also bought").tag(CGFloat(240))
                    Text("Product page").tag(CGFloat(400))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 330)
                Toggle("Grayscale", isOn: $grayscale)
                    .help("Checks that the cover reads on value alone, the way it will on e-ink Kindles")
                Toggle("Squint", isOn: $squint)
                    .help("Blurs everything: the strongest shapes and the title should still stand out")
                Toggle("Dark page", isOn: $darkPage)
                    .help("Stores show covers on white and on dark mode pages")
                Spacer()
                Button { model.addCompareReferences() } label: { Label("Add Bestsellers…", systemImage: "plus") }
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(14)
            Divider()
            ScrollView {
                if items.count <= 1 {
                    VStack(spacing: 6) {
                        Text("Add a few covers from your genre's bestseller list to see how yours holds up beside them.")
                        Text("Covers you heart in Cover Ideas show up here too.").foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12))
                    .padding(.top, 20)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: height / 1.6 + 16), spacing: 18, alignment: .top)], alignment: .leading, spacing: 22) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Image(decorative: item.image, scale: 1)
                                .resizable()
                                .interpolation(.medium)
                                .aspectRatio(contentMode: .fit)
                                .frame(height: height)
                                .grayscale(grayscale ? 1 : 0)
                                .blur(radius: squint ? max(2, height / 40) : 0)
                                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                                .overlay(alignment: .topTrailing) {
                                    if let id = item.refID {
                                        Button { model.compareRefs.removeAll { $0.id == id } } label: {
                                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.white, Color.black.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                        .padding(4)
                                        .accessibilityLabel("Remove \(item.name)")
                                    }
                                }
                            Text(item.name)
                                .font(.system(size: 11, weight: item.isYours ? .semibold : .regular))
                                .foregroundStyle(item.isYours ? Theme.accent : (darkPage ? Color.white.opacity(0.75) : Color.black.opacity(0.65)))
                                .lineLimit(1)
                                .frame(width: height / 1.6 + 10, alignment: .leading)
                        }
                    }
                }
                .padding(24)
            }
            .background(darkPage ? Color(white: 0.11) : Color.white)
        }
        .frame(width: 1100, height: 700)
    }
}

struct ShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let groups: [(String, [(String, String)])] = [
        ("Design", [("Generate cover ideas", "Shift Cmd G"), ("More like this cover", "Shift Cmd M"), ("Auto-polish legibility", "Shift Cmd P"),
                    ("Paperback wraparound", "Shift Cmd B"), ("Compare at store size", "Shift Cmd Y"), ("Pick color from screen", "Shift Cmd K")]),
        ("Layers", [("Add text", "Shift Cmd T"), ("Add photo", "Shift Cmd I"), ("Lift subject", "Shift Cmd L"), ("Duplicate", "Cmd D"),
                    ("Delete", "Cmd Delete"), ("Bring forward / back", "Cmd ] / Cmd ["), ("Copy / paste text style", "Opt Cmd C / Opt Cmd V")]),
        ("Canvas", [("Nudge", "Arrow keys"), ("Nudge further", "Shift Arrow"), ("Deselect or stop brushing", "Esc"),
                    ("Edit text", "Double-click"), ("Show / hide guides", "Cmd ;")]),
        ("File", [("New cover", "Cmd N"), ("Open", "Cmd O"), ("Save", "Cmd S"), ("Export for stores", "Cmd E"), ("Undo / redo", "Cmd Z / Shift Cmd Z")])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts").font(.system(size: 18, weight: .semibold))
            Grid(alignment: .topLeading, horizontalSpacing: 36, verticalSpacing: 18) {
                GridRow {
                    group(groups[0])
                    group(groups[1])
                }
                GridRow {
                    group(groups[2])
                    group(groups[3])
                }
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 680)
    }

    private func group(_ g: (String, [(String, String)])) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(g.0).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(g.1.indices, id: \.self) { i in
                let row = g.1[i]
                HStack {
                    Text(row.0).font(.system(size: 12))
                    Spacer(minLength: 16)
                    Text(row.1).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 290)
    }
}
