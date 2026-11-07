import CoreGraphics
import Foundation

/// Pushes a cover toward a target design score the way a patient art director would: repair first,
/// then try a handful of small edits (a bigger or smaller title, the title moved to the quiet part of
/// the photo, another palette, a film grade, a tracked-out author line, a shadow on or off), keep the
/// one that scores best, and stop when nothing helps any more. Seeded, so the same cover improves the same way.
enum AutoImprover {
    struct Outcome {
        var document: CoverDocument
        var report: CriticReport
        /// The review of the cover as it came in.
        var start: CriticReport
        /// How many accepted steps it took.
        var steps: Int
    }

    /// The minimum gain that counts as an improvement.
    static let minimumGain = 1.0

    static func improve(_ doc: CoverDocument, target: Double = 90, maxSteps: Int = 12,
                        progress: ((Int, Double) -> Void)? = nil) -> (CoverDocument, CriticReport) {
        let o = run(doc, target: target, maxSteps: maxSteps, progress: progress)
        return (o.document, o.report)
    }

    static func run(_ doc: CoverDocument, target: Double = 90, maxSteps: Int = 12, seed: Int = 7,
                    progress: ((Int, Double) -> Void)? = nil) -> Outcome {
        let start = Critic.review(doc)
        guard start.score < target else { return Outcome(document: doc, report: start, start: start, steps: 0) }
        var rng = SeededRNG(seed: seed)
        var best = doc
        var bestReport = start

        // The critic's own repair comes first; it only stays if it helped.
        var repaired = doc
        let rr = Critic.repair(&repaired)
        if rr.score > bestReport.score { best = repaired; bestReport = rr }

        var steps = 0
        while bestReport.score < target && steps < max(0, maxSteps) {
            let pool = candidates(for: best, report: bestReport, rng: &rng)
            var winner: (CoverDocument, CriticReport)?
            for var c in pool {
                let r = Critic.repair(&c, geometry: false)
                if winner == nil || r.score > winner!.1.score { winner = (c, r) }
            }
            guard let w = winner, w.1.score >= bestReport.score + minimumGain else { break }
            best = w.0
            bestReport = w.1
            steps += 1
            progress?(steps, bestReport.score)
        }
        return Outcome(document: best, report: bestReport, start: start, steps: steps)
    }

    // MARK: Candidates

    /// Edits worth trying on this cover, chosen by what the critic complained about; always a few general ones.
    static func candidates(for doc: CoverDocument, report: CriticReport, rng: inout SeededRNG) -> [CoverDocument] {
        var out: [CoverDocument] = []
        let kinds = Set(report.issues.map(\.kind))
        let titleID = doc.textLayer(role: .title)?.id
        let titleIssues = report.issues.filter { $0.layerID != nil && $0.layerID == titleID }
        let titleKinds = Set(titleIssues.map(\.kind))
        let hasPhoto = firstPhoto(doc) != nil
        let legibilityTrouble = kinds.contains(.legibility) || kinds.contains(.busyGround)

        // (a) Title size.
        if titleKinds.contains(.prominence) || titleIssues.isEmpty {
            if let c = scaledTitle(doc, factor: 1.15) { out.append(c) }
            if titleKinds.contains(.prominence), let c = scaledTitle(doc, factor: 1.4) { out.append(c) }
        }
        if titleKinds.contains(.margin) || titleKinds.contains(.collision) || titleKinds.contains(.face) || titleKinds.contains(.legibility) {
            if let c = scaledTitle(doc, factor: 0.87) { out.append(c) }
        }
        // (b) Title in the quietest band of the photo.
        if hasPhoto && (legibilityTrouble || titleKinds.contains(.face) || titleKinds.contains(.photoText) || titleKinds.contains(.attention)) {
            if let c = titleInQuietBand(doc) { out.append(c) }
        }
        // (c) Palette swaps.
        if legibilityTrouble || kinds.contains(.thumbnail) {
            for p in alternativePalettes(doc, rng: &rng) { out.append(recolored(doc, palette: p)) }
        }
        // (d) A film grade on the photo.
        if hasPhoto && (legibilityTrouble || kinds.contains(.photo)) {
            for g in ColorGrade.suggested(for: doc.book.genre).prefix(2) {
                if let c = graded(doc, grade: g) { out.append(c) }
            }
        }
        // (e) Author in tracked capitals.
        if let c = trackedAuthor(doc) { out.append(c) }
        // (f) The title shadow on or off.
        if let c = toggledTitleShadow(doc) { out.append(c) }

        // Nothing targeted (or an issue the edits above don't address): try the whole set once.
        if out.isEmpty {
            if let c = scaledTitle(doc, factor: 1.15) { out.append(c) }
            if let c = scaledTitle(doc, factor: 0.87) { out.append(c) }
            if hasPhoto, let c = titleInQuietBand(doc) { out.append(c) }
            for p in alternativePalettes(doc, rng: &rng) { out.append(recolored(doc, palette: p)) }
            if hasPhoto { for g in ColorGrade.suggested(for: doc.book.genre).prefix(2) { if let c = graded(doc, grade: g) { out.append(c) } } }
        }
        return out
    }

    static func firstPhoto(_ doc: CoverDocument) -> (index: Int, assetID: UUID)? {
        for (i, l) in doc.layers.enumerated() where l.isVisible {
            if let ic = l.imageContent, ic.cutout == Cutout.none { return (i, ic.assetID) }
        }
        return nil
    }

    /// The title's frame scaled about its center and kept inside the text margins.
    static func scaledTitle(_ doc: CoverDocument, factor: Double) -> CoverDocument? {
        guard let title = doc.textLayer(role: .title), let i = doc.index(of: title.id) else { return nil }
        let m = Critic.textMargin
        let f = title.frame
        var w = min(f.w * factor, 1 - 2 * m)
        var h = min(f.h * factor, 1 - 2 * m)
        w = max(0.05, w)
        h = max(0.02, h)
        var x = f.midX - w / 2, y = f.midY - h / 2
        x = min(max(m, x), 1 - m - w)
        y = min(max(m, y), 1 - m - h)
        let nf = NRect(x, y, w, h)
        guard nf != f else { return nil }
        var d = doc
        d.layers[i].frame = nf
        return d
    }

    /// The title moved to the quietest two-row band of the first photo.
    static func titleInQuietBand(_ doc: CoverDocument) -> CoverDocument? {
        guard let title = doc.textLayer(role: .title), let i = doc.index(of: title.id), let photo = firstPhoto(doc) else { return nil }
        let ins = AssetStore.shared.insight(photo.assetID, data: doc.assetData(photo.assetID))
        let band = ImageInsight.bandRect(start: ins.quietestBand(rows: 2), rows: 2)
        // The band is in photo space; the photo's frame maps it onto the cover.
        let pf = doc.layers[photo.index].frame
        let bandY = pf.y + band.y * pf.h, bandH = band.h * pf.h
        let m = Critic.textMargin
        var f = title.frame
        var y = bandY + (bandH - f.h) / 2
        y = min(max(m, y), 1 - m - f.h)
        guard abs(y - f.y) > 0.01 else { return nil }
        f.y = y
        var d = doc
        d.layers[i].frame = f
        return d
    }

    /// Three palettes to try: the photo's own first, then the genre's moods and named palettes for the genre.
    static func alternativePalettes(_ doc: CoverDocument, rng: inout SeededRNG) -> [[RGBA]] {
        var pool: [[RGBA]] = []
        if let first = doc.assetOrder.first(where: { doc.assets[$0.uuidString] != nil }) {
            let p = AssetStore.shared.palette(first, data: doc.assetData(first))
            if !p.isEmpty { pool.append(p) }
        }
        var rest: [[RGBA]] = []
        for mood in GenreStyle.of(doc.book.genre).moods { rest.append(mood) }
        for p in TemplateLibrary.palettes where p.moods.contains(doc.book.genre) { rest.append(p.colors) }
        // Seeded order, so two runs try the same palettes.
        var ordered: [[RGBA]] = []
        while !rest.isEmpty { ordered.append(rest.remove(at: rng.int(rest.count))) }
        pool += ordered
        var out: [[RGBA]] = []
        for p in pool where p != doc.palette && !out.contains(p) && PaletteRoles(p).light.contrast(with: PaletteRoles(p).dark) >= 7 {
            out.append(p)
            if out.count == 3 { break }
        }
        return out
    }

    /// The cover in another palette: large plain grounds take the palette's colors, every line of type turns
    /// light or dark by the ground under it, and the polisher settles the rest.
    static func recolored(_ doc: CoverDocument, palette: [RGBA]) -> CoverDocument {
        var d = doc
        d.palette = palette
        let roles = PaletteRoles(palette)
        let groundDark = roles.dominant.luminance < 0.36
        for i in d.layers.indices {
            guard var f = d.layers[i].fillContent, d.layers[i].frame.area > 0.5, !d.layers[i].clipToBelow,
                  d.layers[i].blend == .normal, f.style != .scrim, f.style != .material else { continue }
            let shade = roles.dominant.withLightness((roles.dominant.hsl.l + (groundDark ? -0.06 : 0.06)).clamped(0, 1))
            switch f.colors.count {
            case 0, 1: f.colors = [roles.dominant]
            case 2: f.colors = [roles.dominant, shade]
            default: f.colors = [roles.dominant, roles.accent, shade]
            }
            d.layers[i].fillContent = f
        }
        if d.layers.contains(where: { $0.fillContent != nil && $0.frame.area > 0.5 }) == false {
            d.background = roles.dominant
        }
        let bg = Polisher.backgroundSample(d)
        for i in d.layers.indices {
            guard var t = d.layers[i].textContent else { continue }
            let onDark: Bool
            if let bg { onDark = PixelSampler.stats(bg, region: d.layers[i].frame).mean.luminance < 0.36 } else { onDark = groundDark }
            t.color = onDark ? roles.light : roles.dark
            if t.gradientTo != nil { t.gradientTo = onDark ? roles.accent.withLightness(0.75) : roles.accent.withLightness(0.3) }
            d.layers[i].textContent = t
        }
        Polisher.polish(&d, palette: roles, background: bg)
        return d
    }

    /// The first photo wearing a color grade.
    static func graded(_ doc: CoverDocument, grade: ColorGradePreset) -> CoverDocument? {
        guard let photo = firstPhoto(doc) else { return nil }
        guard doc.layers[photo.index].adjust != grade.adjust else { return nil }
        var d = doc
        d.layers[photo.index].adjust = grade.adjust
        return d
    }

    /// The author's name in tracked capitals.
    static func trackedAuthor(_ doc: CoverDocument) -> CoverDocument? {
        guard let author = doc.textLayer(role: .author), let i = doc.index(of: author.id), var t = author.textContent else { return nil }
        guard t.letterCase != .upper || abs(t.tracking - 0.25) > 0.01 else { return nil }
        t.letterCase = .upper
        t.tracking = 0.25
        var d = doc
        d.layers[i].textContent = t
        return d
    }

    /// The title's shadow added or removed.
    static func toggledTitleShadow(_ doc: CoverDocument) -> CoverDocument? {
        guard let title = doc.textLayer(role: .title), let i = doc.index(of: title.id) else { return nil }
        var d = doc
        if title.shadow == nil {
            let dark = title.textContent?.color.isDark ?? false
            d.layers[i].shadow = ShadowStyle(color: dark ? RGBA(1, 1, 1, 0.35) : RGBA(0, 0, 0, 0.55), radius: 0.012, dx: 0, dy: 0.004)
        } else {
            d.layers[i].shadow = nil
        }
        return d
    }
}
