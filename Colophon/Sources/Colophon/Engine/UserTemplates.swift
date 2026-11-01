import CoreGraphics
import Foundation
import ImageIO
import Observation

/// A cover design the author saved to reuse on other books.
struct UserTemplate: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var created = Date()
    var genre: Genre
    var includesPictures: Bool
    /// The saved cover. Without pictures, its assets are stripped and photos come from the book it's applied to.
    var document: CoverDocument

    static func == (a: UserTemplate, b: UserTemplate) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

/// Saved templates, one JSON file (plus a thumbnail) each in Application Support/Colophon/Templates.
@Observable final class UserTemplateStore {
    static let shared = UserTemplateStore()

    private(set) var templates: [UserTemplate] = []
    let directory: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Colophon/Templates", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        templates = files.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(UserTemplate.self, from: Data(contentsOf: $0)) }
            .sorted { $0.created > $1.created }
    }

    private func file(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString + ".json") }
    private func thumbFile(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString + ".png") }

    @discardableResult
    func save(_ doc: CoverDocument, name: String, includePictures: Bool) throws -> UserTemplate {
        var d = doc
        d.templateID = nil
        if !includePictures {
            d.assets = [:]
            d.assetOrder = []
        }
        let t = UserTemplate(name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "My Template" : name,
                             genre: doc.book.genre, includesPictures: includePictures, document: d)
        let data = try JSONEncoder().encode(t)
        try data.write(to: file(t.id), options: .atomic)
        // Thumbnail from the full cover as it looks now.
        let h: CGFloat = 480
        if let img = CoverRenderer.shared.render(doc, size: CGSize(width: (h / CGFloat(doc.canvas.aspect)).rounded(), height: h), quality: .preview) {
            _ = Exporter.write(img, to: thumbFile(t.id), format: .png, quality: 1)
        }
        templates.insert(t, at: 0)
        return t
    }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: file(id))
        try? FileManager.default.removeItem(at: thumbFile(id))
        templates.removeAll { $0.id == id }
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = templates.firstIndex(where: { $0.id == id }) else { return }
        templates[i].name = name
        if let data = try? JSONEncoder().encode(templates[i]) { try? data.write(to: file(id), options: .atomic) }
    }

    func thumbnail(_ id: UUID) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(thumbFile(id) as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    /// The saved design on another book: its title, names and lines replace the template's,
    /// and its photos fill the template's picture frames (unless the template brought its own).
    static func apply(_ t: UserTemplate, to base: CoverDocument) -> CoverDocument {
        var d = t.document
        let templateBook = d.book
        BookSync.apply(base.book, old: templateBook, to: &d)
        d.book = base.book
        d.canvas = base.canvas
        for (k, v) in base.fonts where d.fonts[k] == nil { d.fonts[k] = v }
        if !t.includesPictures {
            d.assets = base.assets
            d.assetOrder = base.assetOrder
            let photos = base.assetOrder.filter { base.assets[$0.uuidString] != nil }
            var n = 0
            var kept: [Layer] = []
            for var l in d.layers {
                if var ic = l.imageContent {
                    if photos.isEmpty {
                        // No photo on this book: paint the frame instead.
                        let pal = PaletteRoles(d.palette)
                        var art = Layer.fill(.material, colors: [pal.dark, pal.accent, pal.light], frame: l.frame, seed: 7 + n)
                        art.fillContent?.materialID = "mat.watercolor.palette.b"
                        art.name = "Artwork"
                        kept.append(art)
                    } else {
                        ic.assetID = photos[n % photos.count]
                        l.imageContent = ic
                        kept.append(l)
                    }
                    n += 1
                } else {
                    // Masks that pointed at a template photo now point at the matching new one.
                    kept.append(l)
                }
            }
            d.layers = kept
        } else {
            for (k, v) in base.assets where d.assets[k] == nil { d.assets[k] = v }
        }
        d.recipe = t.document.recipe
        return d
    }
}
