import AppKit
import SwiftUI

/// Renders decor thumbnails off the main thread and keeps them around.
final class DecorThumbs {
    static let shared = DecorThumbs()
    private let cache = NSCache<NSString, CGImage>()
    private let queue = DispatchQueue(label: "colophon.decor-thumbs", qos: .userInitiated, attributes: .concurrent)

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
                let roles = PaletteRoles(palette)
                let img = DecorLibrary.shared.thumbnail(id, size: CGSize(width: 220, height: 220), palette: roles)
                if let img { self.cache.setObject(img, forKey: k) }
                cont.resume(returning: img)
            }
        }
    }
}

/// One browser for every ornament: borders, corner sets, dividers, badges and banners.
struct DecorBrowserSheet: View {
    let palette: [RGBA]
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var kind: DecorLibrary.Kind?
    @State private var limit = 240

    init(kind: DecorLibrary.Kind?, palette: [RGBA], onPick: @escaping (String) -> Void) {
        self.palette = palette
        self.onPick = onPick
        _kind = State(initialValue: kind)
    }

    private var lib: DecorLibrary { .shared }

    private var results: [DecorLibrary.Item] {
        lib.search(query, kind: kind)
    }

    private var title: String {
        switch kind {
        case .border: return "Borders"
        case .corners: return "Corner Ornaments"
        case .divider: return "Dividers"
        case .badge: return "Badges & Seals"
        case .banner: return "Ribbons & Banners"
        case nil: return "Ornaments"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text("\(lib.items.count.formatted()) ornaments, drawn crisp at any size in your cover's colors.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                TextField("Search gold, deco, scallop, ribbon, seal…", text: $query)
                    .textFieldStyle(.roundedBorder).frame(width: 260)
                Button("Surprise Me") {
                    if let it = results.randomElement() { onPick(it.id); dismiss() }
                }
                .disabled(results.isEmpty)
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip("All", selected: kind == nil) { kind = nil }
                    ForEach(DecorLibrary.Kind.allCases, id: \.self) { k in
                        chip(k.label, selected: kind == k) { kind = k }
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 10)
            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 130), spacing: 10)], spacing: 12) {
                    ForEach(results.prefix(limit)) { it in
                        DecorTile(item: it, palette: palette) {
                            onPick(it.id)
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
                    Text("No ornaments match “\(query)”.").foregroundStyle(.secondary).padding(40)
                }
            }
        }
        .frame(width: 860, height: 640)
        .onChange(of: query) { limit = 240 }
        .onChange(of: kind) { limit = 240 }
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

private struct DecorTile: View {
    let item: DecorLibrary.Item
    let palette: [RGBA]
    let action: () -> Void
    @State private var image: CGImage?

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1))
                    if let image {
                        Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
                Text(item.name).font(.system(size: 10.5)).lineLimit(2).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .help(item.name)
        .task(id: item.id) {
            image = DecorThumbs.shared.cached(item.id, palette: palette)
            if image == nil { image = await DecorThumbs.shared.thumb(item.id, palette: palette) }
        }
    }
}
