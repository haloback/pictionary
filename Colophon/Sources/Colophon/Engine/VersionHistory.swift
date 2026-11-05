import CoreGraphics
import Foundation
import Observation

/// Everything the author has tried this session: a snapshot after each randomize, template, repair or polish,
/// plus a coalesced one for ordinary edits, so the design they liked three randomizes ago is a click away.
@MainActor
@Observable
final class VersionHistory {
    struct Version: Identifiable {
        let id: UUID
        let date: Date
        /// "Randomize", "Template: X", "Repair", "Polish", "Edit", "Opened", "Started".
        let reason: String
        let document: CoverDocument
        var thumbnail: CGImage?
        /// The critic's score when the snapshot was taken, if it had one.
        let score: Double?
    }

    static let capacity = 60
    static let thumbnailHeight: CGFloat = 160

    private(set) var versions: [Version] = []
    private(set) var pinned: Set<UUID> = []

    nonisolated init() {}

    var last: Version? { versions.last }
    var count: Int { versions.count }

    func version(_ id: UUID) -> Version? { versions.first { $0.id == id } }
    func isPinned(_ id: UUID) -> Bool { pinned.contains(id) }

    /// Adds a snapshot unless the design hasn't changed since the last one. Returns whether a version was added.
    /// An explicit reason arriving right after a coalesced "Edit" of the same design relabels that entry instead,
    /// so a randomize that also tripped the edit timer shows up once, as "Randomize".
    @discardableResult
    func add(_ doc: CoverDocument, reason: String, score: Double?) -> Bool {
        if let last = versions.last, VersionHistory.sameDesign(last.document, doc) {
            if last.reason == "Edit", reason != "Edit", Date().timeIntervalSince(last.date) < 2 {
                let i = versions.count - 1
                versions[i] = Version(id: last.id, date: last.date, reason: reason, document: last.document,
                                      thumbnail: last.thumbnail, score: score ?? last.score)
            }
            return false
        }
        let v = Version(id: UUID(), date: Date(), reason: reason, document: doc, thumbnail: nil, score: score)
        versions.append(v)
        trim()
        renderThumbnail(for: v.id, doc: doc)
        return true
    }

    func pin(_ id: UUID) {
        guard versions.contains(where: { $0.id == id }) else { return }
        pinned.insert(id)
    }

    func unpin(_ id: UUID) { pinned.remove(id) }

    func togglePin(_ id: UUID) {
        if pinned.contains(id) { unpin(id) } else { pin(id) }
    }

    func remove(_ id: UUID) {
        versions.removeAll { $0.id == id }
        pinned.remove(id)
    }

    func clear() {
        versions = []
        pinned = []
    }

    /// Drops the oldest unpinned versions once the list is over capacity. Pinned versions are never dropped.
    private func trim() {
        var over = versions.count - VersionHistory.capacity
        guard over > 0 else { return }
        var kept: [Version] = []
        kept.reserveCapacity(versions.count)
        for v in versions {
            if over > 0, !pinned.contains(v.id) {
                over -= 1
                continue
            }
            kept.append(v)
        }
        versions = kept
    }

    private func renderThumbnail(for id: UUID, doc: CoverDocument) {
        let h = VersionHistory.thumbnailHeight
        let size = CGSize(width: (h / CGFloat(doc.canvas.aspect)).rounded(), height: h)
        Task.detached(priority: .utility) { [weak self] in
            let img = CoverRenderer.shared.render(doc, size: size, quality: .preview)
            await self?.setThumbnail(id, img)
        }
    }

    private func setThumbnail(_ id: UUID, _ img: CGImage?) {
        if let i = versions.firstIndex(where: { $0.id == id }) { versions[i].thumbnail = img }
    }

    /// Whether two documents are the same design. Compares everything the author can change on the
    /// cover; picture and font bytes are compared by key only, since they're immutable once imported.
    nonisolated static func sameDesign(_ a: CoverDocument, _ b: CoverDocument) -> Bool {
        if a.layers.count != b.layers.count { return false }
        if a.background != b.background || a.palette != b.palette { return false }
        if a.canvas != b.canvas || a.book != b.book { return false }
        if a.archetypeName != b.archetypeName || a.templateID != b.templateID { return false }
        if a.assetOrder != b.assetOrder || Set(a.fonts.keys) != Set(b.fonts.keys) { return false }
        if a.paperback != b.paperback || a.recipe != b.recipe { return false }
        // Same design, whatever the layer ids: a rebuilt document is still the same picture.
        let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        func stripped(_ layers: [Layer]) -> [Layer] { layers.map { var l = $0; l.id = zero; return l } }
        return stripped(a.layers) == stripped(b.layers)
    }
}
