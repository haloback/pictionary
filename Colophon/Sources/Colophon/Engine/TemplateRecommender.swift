import Foundation

/// Ranks templates for one particular book: each candidate is built around the author's title, names and
/// photo, judged by the critic, and the strongest come first. Signature designs for the genre are always
/// in the running, plus a spread of generated layouts.
enum TemplateRecommender {
    struct Pick: Identifiable {
        let template: CoverTemplate
        let score: Double
        var id: String { template.id }
    }

    /// Candidates worth judging for this book: cheap to list, so the expensive judging stays bounded.
    static func candidates(for base: CoverDocument, limit: Int = 48) -> [CoverTemplate] {
        let lib = TemplateLibrary.shared
        let genre = base.book.genre
        let hasPhoto = !base.assetOrder.filter { base.assets[$0.uuidString] != nil }.isEmpty
        var out: [CoverTemplate] = []
        // Every Signature design for the genre, in its hero palette.
        for t in lib.templates where t.isSignature && t.genre == genre && t.signaturePalette == 0 { out.append(t) }
        // A spread of generated layouts: every archetype once, rotating through the variations by book title.
        let seed = TemplateLibrary.seed(base.book.title + base.book.author)
        let generated = lib.templates.filter { !$0.isSignature && $0.genre == genre && (hasPhoto || !$0.needsPhoto) }
        var byArchetype: [Archetype: [CoverTemplate]] = [:]
        for t in generated { byArchetype[t.archetype, default: []].append(t) }
        for (k, arch) in Archetype.allCases.enumerated() {
            guard let pool = byArchetype[arch], !pool.isEmpty else { continue }
            out.append(pool[(seed + k * 7) % pool.count])
        }
        return Array(out.prefix(limit))
    }

    /// The candidates built and judged for this book, best first. Slow (one render per candidate): call off the main thread.
    static func rank(for base: CoverDocument, candidates: [CoverTemplate]? = nil, keep: Int = 12) -> [Pick] {
        let list = candidates ?? self.candidates(for: base)
        var picks: [Pick] = []
        for t in list {
            let doc = TemplateLibrary.shared.apply(t, to: base)
            let r = Critic.review(doc)
            // Signature designs carry art direction the critic can't measure; a small bonus keeps them competitive.
            picks.append(Pick(template: t, score: r.score + (t.isSignature ? 4 : 0)))
        }
        picks.sort { $0.score > $1.score }
        return Array(picks.prefix(keep))
    }
}
