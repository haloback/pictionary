import AppKit
import SwiftUI

/// Renders material thumbnails off the main thread and keeps them around.
final class MaterialThumbs {
    static let shared = MaterialThumbs()
    private let cache = NSCache<NSString, CGImage>()
    private let queue = DispatchQueue(label: "colophon.material-thumbs", qos: .userInitiated, attributes: .concurrent)

    init() { cache.countLimit = 900 }

    private func key(_ id: String, _ palette: [RGBA]) -> NSString {
        (id + "|" + palette.map { String(format: "%.2f,%.2f,%.2f", $0.r, $0.g, $0.b) }.joined(separator: ";")) as NSString
    }

    func cached(_ id: String, palette: [RGBA]) -> CGImage? { cache.object(forKey: key(id, palette)) }

    func thumb(_ id: String, palette: [RGBA]) async -> CGImage? {
        let k = key(id, palette)
        if let hit = cache.object(forKey: k) { return hit }
        return await withCheckedContinuation { cont in
            queue.async {
                let img = MaterialLibrary.shared.renderImage(id, size: CGSize(width: 220, height: 220), palette: palette, seed: 1)
                if let img { self.cache.setObject(img, forKey: k) }
                cont.resume(returning: img)
            }
        }
    }
}

/// One browser for every material: backgrounds, title faces and texture masks.
struct MaterialPickerSheet: View {
    enum Purpose { case background, titleFace, mask }

    let purpose: Purpose
    let palette: [RGBA]
    var current: String?
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category: String?
    @State private var masks = false
    @State private var limit = 240

    private var lib: MaterialLibrary { .shared }

    private var results: [MaterialLibrary.Material] {
        lib.search(query, category: masks ? nil : category, masksOnly: masks)
    }

    private var title: String {
        switch purpose {
        case .background: return "Material Background"
        case .titleFace: return "Title Material"
        case .mask: return "Texture Mask"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text("\(lib.materials.count.formatted()) materials. Cover Palette ones print in your cover's colors.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                TextField("Search marble, linen, rust, gold, ocean…", text: $query)
                    .textFieldStyle(.roundedBorder).frame(width: 260)
                Button("Surprise Me") {
                    if let m = results.randomElement() { onPick(m.id); dismiss() }
                }
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip("All", selected: !masks && category == nil) { masks = false; category = nil }
                    ForEach(lib.categories.filter { $0 != "Masks" }, id: \.self) { c in
                        chip(c, selected: !masks && category == c) { masks = false; category = c }
                    }
                    Divider().frame(height: 16)
                    chip("Masks (gray)", selected: masks) { masks = true }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 10)
            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 130), spacing: 10)], spacing: 12) {
                    ForEach(results.prefix(limit)) { m in
                        MaterialTile(material: m, palette: palette, selected: m.id == current) {
                            onPick(m.id)
                            dismiss()
                        }
                    }
                }
                .padding(14)
                if results.count > limit {
                    Button("Show more (\((results.count - limit).formatted()) left)") { limit += 240 }
                        .padding(.bottom, 16)
                }
                if results.isEmpty {
                    Text("No materials match “\(query)”.").foregroundStyle(.secondary).padding(40)
                }
            }
        }
        .frame(width: 860, height: 640)
        .onAppear { masks = purpose == .mask }
        .onChange(of: query) { limit = 240 }
        .onChange(of: category) { limit = 240 }
        .onChange(of: masks) { limit = 240 }
    }

    private func chip(_ label: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(selected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08)))
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct MaterialTile: View {
    let material: MaterialLibrary.Material
    let palette: [RGBA]
    let selected: Bool
    let action: () -> Void
    @State private var image: CGImage?

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1))
                    if let image {
                        Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected ? Color.accentColor : Color.black.opacity(0.08), lineWidth: selected ? 2 : 0.5))
                Text(material.name).font(.system(size: 10.5)).lineLimit(2).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .help(material.name)
        .task(id: material.id) {
            image = MaterialThumbs.shared.cached(material.id, palette: palette)
            if image == nil { image = await MaterialThumbs.shared.thumb(material.id, palette: palette) }
        }
    }
}

/// A compact row that shows the chosen material and opens the browser.
struct MaterialRow: View {
    let label: String
    let purpose: MaterialPickerSheet.Purpose
    let palette: [RGBA]
    @Binding var materialID: String?
    var allowsNone = true
    @State private var picking = false

    var body: some View {
        FieldRow(label) {
            HStack(spacing: 6) {
                Button {
                    picking = true
                } label: {
                    Text(materialID.flatMap { MaterialLibrary.shared.material($0)?.name } ?? "Choose…")
                        .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
                if allowsNone, materialID != nil {
                    Button { materialID = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $picking) {
            MaterialPickerSheet(purpose: purpose, palette: palette, current: materialID) { materialID = $0 }
        }
    }
}
