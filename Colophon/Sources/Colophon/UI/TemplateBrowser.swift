import AppKit
import SwiftUI

/// Renders template previews with the author's own book details, off the main thread.
final class TemplateThumbs {
    static let shared = TemplateThumbs()
    private let cache = NSCache<NSString, CGImage>()
    private let queue = DispatchQueue(label: "colophon.template-thumbs", qos: .userInitiated, attributes: .concurrent)
    private let gate = DispatchSemaphore(value: 4)

    init() { cache.countLimit = 600 }

    static func signature(_ d: CoverDocument) -> String {
        "\(d.book.title)|\(d.book.subtitle)|\(d.book.author)|\(d.book.tagline)|\(d.book.series)|\(d.assetOrder.count)|\(d.canvas.width)x\(d.canvas.height)"
    }

    func cached(_ id: String, signature: String) -> CGImage? { cache.object(forKey: (id + "|" + signature) as NSString) }

    func thumb(_ t: CoverTemplate, base: CoverDocument, signature: String) async -> CGImage? {
        let key = (t.id + "|" + signature) as NSString
        if let hit = cache.object(forKey: key) { return hit }
        return await withCheckedContinuation { cont in
            queue.async {
                self.gate.wait()
                defer { self.gate.signal() }
                let doc = TemplateLibrary.shared.apply(t, to: base)
                let h: CGFloat = 300
                let size = CGSize(width: (h / CGFloat(doc.canvas.aspect)).rounded(), height: h)
                let img = CoverRenderer.shared.render(doc, size: size, quality: .preview)
                if let img { self.cache.setObject(img, forKey: key) }
                cont.resume(returning: img)
            }
        }
    }
}

struct TemplateBrowserSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var genre: Genre?
    @State private var showPhotoLayouts = true
    @State private var limit = 120
    @State private var tags: Set<String> = []
    @State private var mine = false
    @State private var pendingDelete: UserTemplate?
    @State private var recommended: [TemplateRecommender.Pick] = []
    @State private var recommendedFor = ""
    @State private var described: [CoverTemplate] = []
    @State private var describedFor = ""
    private var store: UserTemplateStore { .shared }

    private var hasPhoto: Bool { !model.document.photoLayers.isEmpty || !model.document.assetOrder.isEmpty }

    private var results: [CoverTemplate] {
        let all = TemplateLibrary.shared.search(query, genre: genre, tags: tags)
        let base = (hasPhoto || showPhotoLayouts) ? all : all.filter { !$0.needsPhoto }
        // With the taste model, a description ("foggy, quiet, literary") also finds designs that look like it.
        if !described.isEmpty && describedFor == query {
            var merged = described
            for t in base where !described.contains(where: { $0.id == t.id }) { merged.append(t) }
            return merged
        }
        return base
    }

    /// Asks the taste model which Signature designs look like the typed description.
    private func describeSearch(_ q: String) async {
        let words = q.trimmingCharacters(in: .whitespaces)
        guard TasteEngine.shared.isReady, words.split(separator: " ").count >= 2 else { described = []; describedFor = ""; return }
        let hits = await Task.detached(priority: .userInitiated) { TasteEngine.shared.search(words, in: SignatureLibrary.all, limit: 12) }.value
        let lib = TemplateLibrary.shared
        described = hits.compactMap { lib.template("sig.\($0.design.id).0") }
        describedFor = q
    }

    var body: some View {
        let base = model.document
        let sig = TemplateThumbs.signature(base)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Templates").font(.headline)
                    Text("\(TemplateLibrary.shared.templates.count.formatted()) designs, shown with your title, names and photos.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if !hasPhoto {
                    Toggle("Photo layouts", isOn: $showPhotoLayouts).controlSize(.small)
                        .help("Layouts built around a photo. Without one, they use a painted ground instead.")
                }
                TextField(TasteEngine.shared.isReady ? "Search, or describe the cover you want…" : "Search palette, layout, font…", text: $query)
                    .textFieldStyle(.roundedBorder).frame(width: 240)
                    .task(id: query) {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if Task.isCancelled { return }
                        await describeSearch(query)
                    }
                Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.showSaveTemplate = true } } label: {
                    Label("Save Current Cover…", systemImage: "square.and.arrow.down")
                }
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(14)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip("My Templates (\(store.templates.count))", selected: mine) { mine = true }
                    Divider().frame(height: 16)
                    chip("Signature", selected: !mine && tags.contains("signature")) {
                        mine = false
                        if tags.contains("signature") { tags.remove("signature") } else { tags.insert("signature") }
                    }
                    chip("All", selected: !mine && genre == nil) { mine = false; genre = nil }
                    ForEach(Genre.allCases) { g in chip(g.label, selected: !mine && genre == g) { mine = false; genre = g } }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 6)
            if !mine {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("Look").font(.system(size: 11)).foregroundStyle(.secondary)
                        ForEach(TemplateLibrary.tagChips, id: \.self) { tag in
                            let key = tag.lowercased()
                            chip(tag, selected: tags.contains(key)) {
                                if tags.contains(key) { tags.remove(key) } else { tags.insert(key) }
                            }
                        }
                        if !tags.isEmpty { Button("Clear") { tags = [] }.buttonStyle(.link).font(.system(size: 11)) }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 10)
            }
            Divider()
            if mine {
                myTemplates
            } else {
            ScrollView {
                if query.isEmpty && tags.isEmpty && (genre == nil || genre == base.book.genre) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles").foregroundStyle(Color.accentColor)
                            Text("Recommended for “\(base.book.title.isEmpty ? "your book" : base.book.title)”").font(.system(size: 12, weight: .semibold))
                            Text(recommended.isEmpty ? "judging designs with your title and photo…" : "the designs that score highest with your words and pictures")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 14) {
                                if recommended.isEmpty { ProgressView().controlSize(.small).padding(.vertical, 40) }
                                ForEach(recommended) { pick in
                                    TemplateTile(template: pick.template, base: base, signature: sig, current: base.templateID == pick.template.id) {
                                        model.applyTemplate(pick.template)
                                        dismiss()
                                    }
                                    .frame(width: 128)
                                    .overlay(alignment: .topTrailing) {
                                        Text("\(Int(pick.score))").font(.system(size: 9.5, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 5).padding(.vertical, 2)
                                            .background(Color.black.opacity(0.6), in: Capsule()).foregroundStyle(.white).padding(5)
                                    }
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                        }
                        Divider().padding(.horizontal, 14)
                    }
                    .padding(.top, 10)
                    .task(id: sig + "|" + base.book.genre.rawValue) {
                        let key = sig + "|" + base.book.genre.rawValue
                        if recommendedFor == key { return }
                        let snapshot = base
                        let picks = await Task.detached(priority: .userInitiated) { TemplateRecommender.rank(for: snapshot) }.value
                        recommended = picks
                        recommendedFor = key
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 14)], spacing: 16) {
                    ForEach(results.prefix(limit)) { t in
                        TemplateTile(template: t, base: base, signature: sig, current: base.templateID == t.id) {
                            model.applyTemplate(t)
                            dismiss()
                        }
                    }
                }
                .padding(14)
                if results.count > limit {
                    Button("Show more (\((results.count - limit).formatted()) left)") { limit += 120 }.padding(.bottom, 16)
                }
                if results.isEmpty {
                    Text("No templates match “\(query)”.").foregroundStyle(.secondary).padding(40)
                }
            }
            }
        }
        .confirmationDialog("Delete “\(pendingDelete?.name ?? "")”?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete Template", role: .destructive) {
                if let t = pendingDelete { store.delete(t.id) }
                pendingDelete = nil
            }
        } message: {
            Text("This removes the saved template. Covers already made with it are not affected.")
        }
        .frame(width: 960, height: 700)
        .onAppear { genre = model.document.book.genre }
        .onChange(of: query) { limit = 120 }
        .onChange(of: genre) { limit = 120 }
    }

    @ViewBuilder
    private var myTemplates: some View {
        if store.templates.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down.on.square").font(.system(size: 30)).foregroundStyle(.secondary)
                Text("No saved templates yet").font(.headline)
                Text("Design a cover you like, then use Save Current Cover to reuse it on other books.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 14)], spacing: 16) {
                    ForEach(store.templates) { t in
                        VStack(alignment: .leading, spacing: 5) {
                            Button {
                                model.applyUserTemplate(t)
                                dismiss()
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.1))
                                    if let img = store.thumbnail(t.id) {
                                        Image(decorative: img, scale: 1).resizable().aspectRatio(contentMode: .fit)
                                    } else {
                                        Image(systemName: "photo").foregroundStyle(.secondary)
                                    }
                                }
                                .aspectRatio(1 / 1.6, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                            HStack(spacing: 4) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(t.name).font(.system(size: 10.5)).lineLimit(1)
                                    Text(t.genre.label + (t.includesPictures ? ", with pictures" : "")).font(.system(size: 9.5)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Button { pendingDelete = t } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless).help("Delete this template")
                            }
                        }
                        .contextMenu {
                            Button("Use on This Cover") { model.applyUserTemplate(t); dismiss() }
                            Button("Delete…", role: .destructive) { pendingDelete = t }
                        }
                    }
                }
                .padding(14)
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

private struct TemplateTile: View {
    let template: CoverTemplate
    let base: CoverDocument
    let signature: String
    let current: Bool
    let action: () -> Void
    @State private var image: CGImage?

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.1))
                    if let image {
                        Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .aspectRatio(1 / 1.6, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(current ? Color.accentColor : Color.black.opacity(0.1), lineWidth: current ? 2 : 0.5))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                Text(template.name).font(.system(size: 10.5)).lineLimit(2).foregroundStyle(.primary)
                HStack(spacing: 4) {
                    if template.isSignature {
                        Image(systemName: "seal.fill").font(.system(size: 8.5)).foregroundStyle(Color.accentColor)
                    }
                    Text(template.genre.label + (template.isSignature ? ", Signature" : template.needsPhoto ? ", photo" : ""))
                        .font(.system(size: 9.5)).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .help(template.signatureID.flatMap { SignatureLibrary.design($0)?.idea }.map { template.name + "\n" + $0 } ?? template.name)
        .task(id: template.id + signature) {
            image = TemplateThumbs.shared.cached(template.id, signature: signature)
            if image == nil { image = await TemplateThumbs.shared.thumb(template, base: base, signature: signature) }
        }
    }
}
