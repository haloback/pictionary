import AppKit
import SwiftUI

/// Renders illustration thumbnails off the main thread (the library caches them).
final class IllustrationThumbs {
    static let shared = IllustrationThumbs()
    private let queue = DispatchQueue(label: "colophon.illustration-thumbs", qos: .userInitiated, attributes: .concurrent)

    func thumb(_ item: IllustrationLibrary.Item, color: RGBA) async -> CGImage? {
        await withCheckedContinuation { cont in
            queue.async {
                let img = IllustrationLibrary.shared.thumbnail(item, size: CGSize(width: 160, height: 160), color: color)
                cont.resume(returning: img)
            }
        }
    }
}

/// One browser for every downloadable icon pack: search, install packs, pick outline or filled, click to add.
struct IllustrationBrowserSheet: View {
    /// The color the cover's type reads in; thumbnails are tinted with it.
    let ink: RGBA
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var pack: String?
    @State private var style: IllustrationLibrary.Style?
    @State private var limit = 300
    @State private var installError: String?

    init(ink: RGBA, onPick: @escaping (String) -> Void) {
        self.ink = ink
        self.onPick = onPick
    }

    private var lib: IllustrationLibrary { .shared }

    private var results: [IllustrationLibrary.Item] {
        lib.search(query, pack: pack, style: style, limit: limit + 1)
    }

    private var installedCount: Int { lib.packs.filter(\.isInstalled).count }

    var body: some View {
        let found = results
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Illustrations").font(.headline)
                    Text(installedCount == 0
                         ? "Install a pack below: thousands of silhouettes and line icons, recolored to your cover."
                         : "\(lib.items.count.formatted()) silhouettes and line icons, recolored to your cover.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                TextField("Search sword, raven, teacup, rocket, key…", text: $query)
                    .textFieldStyle(.roundedBorder).frame(width: 260)
                Picker("", selection: $style) {
                    Text("Any").tag(IllustrationLibrary.Style?.none)
                    ForEach(IllustrationLibrary.Style.allCases) { s in Text(s.label).tag(IllustrationLibrary.Style?.some(s)) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 190)
                Button("Surprise Me") {
                    if let it = found.randomElement() { onPick(it.id); dismiss() }
                }
                .disabled(found.isEmpty)
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All packs", selected: pack == nil) { pack = nil }
                    ForEach(lib.packs) { p in packChip(p) }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 10)
            if let installError {
                Text(installError).font(.system(size: 11)).foregroundStyle(.red).padding(.horizontal, 14).padding(.bottom, 8)
            }
            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84, maximum: 104), spacing: 10)], spacing: 12) {
                    ForEach(found.prefix(limit)) { it in
                        IllustrationTile(item: it, ink: ink) {
                            onPick(it.id)
                            dismiss()
                        }
                    }
                }
                .padding(14)
                if found.count > limit {
                    Button("Show more") { limit += 300 }.padding(.bottom, 16)
                }
                if found.isEmpty {
                    if installedCount == 0 {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle").font(.system(size: 28, weight: .light)).foregroundStyle(.tertiary)
                            Text("No packs installed yet").font(.system(size: 13, weight: .medium))
                            Text("Press Install on a pack above. Each downloads once and stays on this Mac.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        .padding(40)
                    } else {
                        Text("Nothing matches “\(query)”.").foregroundStyle(.secondary).padding(40)
                    }
                }
            }
        }
        .frame(width: 860, height: 640)
        .onChange(of: query) { limit = 300 }
        .onChange(of: pack) { limit = 300 }
        .onChange(of: style) { limit = 300 }
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

    @ViewBuilder
    private func packChip(_ p: IllustrationLibrary.Pack) -> some View {
        let state = lib.state(of: p)
        HStack(spacing: 6) {
            chip(p.name, selected: pack == p.id) { pack = p.id }
            switch state {
            case .ready:
                Text(p.license).font(.system(size: 10)).foregroundStyle(.secondary)
            case .downloading(let what):
                ProgressView().controlSize(.mini)
                Text(what).font(.system(size: 10)).foregroundStyle(.secondary)
            case .notInstalled, .failed:
                Button("Install (\(p.approximateSize), \(p.license))") { install(p) }
                    .controlSize(.small)
                    .help(p.attribution.isEmpty ? "No attribution required." : "Requires a credit line: \(p.attribution). Colophon writes Credits.txt on export.")
            }
        }
        .padding(.trailing, 6)
    }

    private func install(_ p: IllustrationLibrary.Pack) {
        installError = nil
        Task { @MainActor in
            do {
                try await IllustrationLibrary.shared.install(p)
                pack = p.id
            } catch {
                installError = "\(p.name): \(error.localizedDescription)"
            }
        }
    }
}

private struct IllustrationTile: View {
    let item: IllustrationLibrary.Item
    let ink: RGBA
    let action: () -> Void
    @State private var image: CGImage?

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1))
                    if let image {
                        Image(decorative: image, scale: 2).resizable().aspectRatio(contentMode: .fit).padding(10)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
                Text(item.name).font(.system(size: 10)).lineLimit(1).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .help(item.artist.map { "\(item.name) by \($0) (\(item.pack))" } ?? "\(item.name) (\(item.pack))")
        .task(id: item.id + ink.hex) {
            image = await IllustrationThumbs.shared.thumb(item, color: ink)
        }
    }
}
