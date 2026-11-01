import AppKit
import SwiftUI

/// Browses the Google Fonts catalog, downloads families on demand and picks a style.
struct FontBrowserSheet: View {
    let sample: String
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var category: FontLibrary.Category? = nil
    @State private var limit: Int = 200
    @State private var expanded: String? = nil

    private static let pageSize: Int = 200

    init(sample: String, onPick: @escaping (String) -> Void) {
        self.sample = sample
        self.onPick = onPick
    }

    private var lib: FontLibrary { FontLibrary.shared }

    private var previewText: String {
        let t: String = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "The Quick Brown Fox" : t.replacingOccurrences(of: "\n", with: " ")
    }

    var body: some View {
        let results: [FontLibrary.Family] = lib.search(query, category: category)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Fonts").font(.headline)
                    Text("\(lib.families.count.formatted()) font families from Google Fonts, free for commercial use")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                TextField("Search names, designers, styles…", text: $query)
                    .textFieldStyle(.roundedBorder).frame(width: 240)
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip("All", selected: category == nil) { category = nil }
                    ForEach(FontLibrary.Category.allCases) { c in
                        chip(c.label, selected: category == c) { category = c }
                    }
                    Spacer(minLength: 0)
                    Text("\(results.count.formatted()) shown")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 10)
            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(results.prefix(limit)) { family in
                        FontFamilyRow(family: family,
                                      sample: previewText,
                                      expanded: expanded == family.id,
                                      onToggle: { toggle(family) },
                                      onPick: { name in
                                          onPick(name)
                                          dismiss()
                                      })
                        Divider().padding(.leading, 14)
                    }
                }
                if results.count > limit {
                    Button("Show more (\((results.count - limit).formatted()) left)") { limit += FontBrowserSheet.pageSize }
                        .padding(.vertical, 16)
                }
                if results.isEmpty {
                    Text(lib.families.isEmpty ? "The Google Fonts catalog couldn't be loaded." : "No font families match “\(query)”.")
                        .foregroundStyle(.secondary).padding(40)
                }
            }
        }
        .frame(width: 760, height: 640)
        .onAppear { lib.registerCached() }
        .onChange(of: query) { limit = FontBrowserSheet.pageSize }
        .onChange(of: category) { limit = FontBrowserSheet.pageSize }
    }

    private func toggle(_ family: FontLibrary.Family) {
        if expanded == family.id {
            expanded = nil
            return
        }
        expanded = family.id
        if lib.state(of: family) != .ready {
            Task { @MainActor in
                _ = try? await FontLibrary.shared.install(family)
            }
        }
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

/// One family: details, a live preview once downloaded, and its styles when expanded.
private struct FontFamilyRow: View {
    let family: FontLibrary.Family
    let sample: String
    let expanded: Bool
    let onToggle: () -> Void
    let onPick: (String) -> Void

    private var lib: FontLibrary { FontLibrary.shared }

    var body: some View {
        let state: FontLibrary.State = lib.state(of: family)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(family.name).font(.system(size: 13, weight: .semibold))
                    Text(details).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                trailing(state)
            }
            if state == .ready {
                preview(lib.resolvedName(lib.defaultStyle(family), in: family), size: 28)
                if expanded { styleButtons }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(expanded ? Color.accentColor.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }

    private var details: String {
        let count: Int = family.styles.count
        let styles: String = count == 1 ? "1 style" : "\(count) styles"
        let designer: String = family.designer.isEmpty ? "Unknown designer" : family.designer
        return "\(designer) · \(family.category.label) · \(styles) · \(licenseLabel)"
    }

    private var licenseLabel: String {
        switch family.license {
        case "APACHE2": return "Apache 2.0"
        case "UFL": return "Ubuntu Font License"
        default: return "SIL OFL"
        }
    }

    @ViewBuilder
    private func trailing(_ state: FontLibrary.State) -> some View {
        switch state {
        case .ready:
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        case .downloading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Downloading…").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .notDownloaded:
            Button("Download") { download() }.controlSize(.small)
        case .failed(let message):
            HStack(spacing: 6) {
                Text(message).font(.system(size: 11)).foregroundStyle(.red).lineLimit(2)
                    .frame(maxWidth: 260, alignment: .trailing)
                Button("Retry") { download() }.controlSize(.small)
            }
        }
    }

    private func download() {
        let f: FontLibrary.Family = family
        Task { @MainActor in
            _ = try? await FontLibrary.shared.install(f)
        }
    }

    @ViewBuilder
    private func preview(_ postScriptName: String, size: CGFloat) -> some View {
        if let font = NSFont(name: postScriptName, size: size) {
            Text(sample)
                .font(Font(font as CTFont))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(sample).font(.system(size: size)).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private var styleButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(family.styles, id: \.self) { style in
                    let name: String = lib.resolvedName(style, in: family)
                    Button {
                        onPick(name)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            styleSample(name)
                            Text(FontFamilyRow.styleLabel(style))
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(NSFont(name: name, size: 12) == nil)
                    .help(name)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func styleSample(_ postScriptName: String) -> some View {
        if let font = NSFont(name: postScriptName, size: 16) {
            Text("Aa").font(Font(font as CTFont)).foregroundStyle(.primary)
        } else {
            Text("Aa").font(.system(size: 16)).foregroundStyle(.secondary)
        }
    }

    static func styleLabel(_ style: FontLibrary.Style) -> String {
        let weight: String
        switch style.weight {
        case ..<150: weight = "Thin"
        case 150..<250: weight = "ExtraLight"
        case 250..<350: weight = "Light"
        case 350..<450: weight = "Regular"
        case 450..<550: weight = "Medium"
        case 550..<650: weight = "SemiBold"
        case 650..<750: weight = "Bold"
        case 750..<850: weight = "ExtraBold"
        default: weight = "Black"
        }
        if style.italic {
            return weight == "Regular" ? "Italic \(style.weight)" : "\(weight) Italic \(style.weight)"
        }
        return "\(weight) \(style.weight)"
    }
}
