import CoreGraphics
import Foundation

/// What the critic found wrong (or right) with one part of a cover.
struct CriticIssue: Identifiable {
    enum Kind: String {
        case legibility, busyGround, collision, margin, prominence, thumbnail, face, hierarchy, photoText, photo, attention
    }
    let id = UUID()
    let kind: Kind
    let severity: Severity
    let layerID: UUID?
    let message: String
    /// Points taken off the score.
    let penalty: Double
}

/// The art director's verdict on a cover: a score out of 100 and what to fix.
struct CriticReport {
    var score: Double
    var issues: [CriticIssue]

    var grade: String {
        switch score {
        case 92...: return "A"
        case 84..<92: return "A−"
        case 76..<84: return "B+"
        case 68..<76: return "B"
        case 58..<68: return "C"
        default: return "D"
        }
    }
    var worst: Severity { issues.map(\.severity).max() ?? .pass }
    static let perfect = CriticReport(score: 100, issues: [])
}

/// Looks at a cover the way an art director does, measuring instead of guessing: real contrast under
/// every line of type, type that collides or crowds the trim, titles too small to read as a thumbnail,
/// text across a face. Scores it, and repairs what it can.
enum Critic {
    static let safeInset = 0.03
    static let textMargin = 0.045

    // MARK: Review

    /// The cover without any type, at the size the ink measurement uses.
    static func inkBase(_ doc: CoverDocument) -> CGImage? {
        let textIDs = Set(doc.layers.filter { $0.textContent != nil }.map(\.id))
        let h: CGFloat = 512
        return CoverRenderer.shared.render(doc, size: CGSize(width: (h / CGFloat(doc.canvas.aspect)).rounded(), height: h), quality: .preview, excluding: textIDs)
    }

    /// Ink against ground as actually rendered: the layer is drawn alone over the cover without type, and the
    /// glyph cores (the pixels it changes most) are compared with what was under them. Styles, plates,
    /// shadows and glows all count, because they are all in the picture.
    static func renderedContrast(_ doc: CoverDocument, layer: Layer, base: CGImage) -> Double? {
        let others = Set(doc.layers.filter { $0.textContent != nil && $0.id != layer.id }.map(\.id))
        guard let withInk = CoverRenderer.shared.render(doc, size: CGSize(width: CGFloat(base.width), height: CGFloat(base.height)), quality: .preview, excluding: others) else { return nil }
        let a = PixelSampler.pixels(base, maxSide: 512), b = PixelSampler.pixels(withInk, maxSide: 512)
        guard a.w == b.w, a.h == b.h else { return nil }
        let f = layer.frame
        let x0 = max(0, Int(f.x * Double(a.w))), x1 = min(a.w, Int(f.maxX * Double(a.w)) + 1)
        let y0 = max(0, Int(f.y * Double(a.h))), y1 = min(a.h, Int(f.maxY * Double(a.h)) + 1)
        guard x1 > x0, y1 > y0 else { return nil }
        var deltas: [(Double, Double, Double)] = []
        var maxDelta = 0.0
        for y in y0..<y1 {
            for x in x0..<x1 {
                let i = (y * a.w + x) * 4
                let la = RGBA(Double(a.data[i]) / 255, Double(a.data[i + 1]) / 255, Double(a.data[i + 2]) / 255).luminance
                let lb = RGBA(Double(b.data[i]) / 255, Double(b.data[i + 1]) / 255, Double(b.data[i + 2]) / 255).luminance
                let d = abs(la - lb)
                if d > 0.01 { deltas.append((d, la, lb)); maxDelta = max(maxDelta, d) }
            }
        }
        let total = Double((x1 - x0) * (y1 - y0))
        // The glyphs cover a few percent of their box at least; less than that and the type has vanished.
        guard total > 0, Double(deltas.count) / total >= 0.01, maxDelta > 0.02 else { return 1 }
        // Anti-aliased edges blend ink and ground; the cores are the pixels changed most.
        let cut = maxDelta * 0.55
        var inkSum = 0.0, groundSum = 0.0, n = 0.0
        for (d, la, lb) in deltas where d >= cut { inkSum += lb; groundSum += la; n += 1 }
        guard n > 0 else { return 1 }
        let ink = inkSum / n, ground = groundSum / n
        return (max(ink, ground) + 0.05) / (min(ink, ground) + 0.05)
    }

    static func review(_ doc: CoverDocument, background: CGImage? = nil) -> CriticReport {
        let bg = background ?? Polisher.backgroundSample(doc)
        let base = inkBase(doc)
        var issues: [CriticIssue] = []
        let canvasH = Double(doc.canvas.height)
        let texts = doc.layers.filter { $0.textContent != nil && $0.isVisible && $0.opacity >= 0.5 }
        let faces = faceRects(doc)
        let words = photoTextRects(doc)
        // The photo itself: a screenshot, a weak picture, words in it.
        for l in doc.layers where l.isVisible {
            guard let ic = l.imageContent, l.frame.area > 0.2 else { continue }
            let ins = AssetStore.shared.insight(ic.assetID, data: doc.assetData(ic.assetID))
            if ins.isUtility {
                issues.append(CriticIssue(kind: .photo, severity: .warning, layerID: l.id, message: ins.photoNote ?? "The picture looks like a document.", penalty: 10))
            } else if let a = ins.aesthetic, a < -0.35 {
                issues.append(CriticIssue(kind: .photo, severity: .info, layerID: l.id, message: ins.photoNote ?? "The photo is weak on its own.", penalty: 4))
            }
        }

        for l in texts {
            guard let t = l.textContent else { continue }
            let role = t.role
            let box = l.frame.pixels(in: CGSize(width: Double(doc.canvas.width), height: canvasH))
            let size = Double(TextRenderer.resolvedSize(t, box: box.size, canvasHeight: CGFloat(canvasH)))
            let capFraction = size * 0.7 / canvasH
            let lifted = l.shadow != nil || t.glowColor != nil || t.strokeColor != nil || t.style.isActive

            if let bg {
                let stats = PixelSampler.stats(bg, region: l.frame)
                let need = role.minimumContrast
                let nominal = faceColor(t).contrast(with: stats.mean) + (lifted ? 1.5 : 0)
                let achieved = base.flatMap { renderedContrast(doc, layer: l, base: $0) } ?? nominal
                if achieved < need {
                    let short = (need - achieved) / need
                    let weight = role == .title ? 32.0 : 16.0
                    issues.append(CriticIssue(kind: .legibility, severity: short > 0.4 ? .fail : .warning, layerID: l.id,
                                              message: "\(role.label) reads at \(String(format: "%.1f", achieved)):1 against what's behind it; it needs \(String(format: "%.1f", need)):1.",
                                              penalty: min(weight, weight * (0.35 + short))))
                }
                if stats.busyness > 0.2 && !lifted && !hasBacking(doc, under: l) {
                    issues.append(CriticIssue(kind: .busyGround, severity: .warning, layerID: l.id,
                                              message: "The \(role.label.lowercased()) sits on a busy area with nothing lifting it off.",
                                              penalty: role == .title ? 7 : 3))
                }
            }
            if role == .title && capFraction < 0.045 {
                issues.append(CriticIssue(kind: .prominence, severity: capFraction < 0.03 ? .fail : .warning, layerID: l.id,
                                          message: "The title's capitals stand only \(Int(capFraction * 100))% of the cover height; bestsellers run 6–20%.",
                                          penalty: min(22, (0.045 - capFraction) / 0.045 * 30)))
            }
            if role != .title && role != .author && capFraction < 0.011 {
                issues.append(CriticIssue(kind: .thumbnail, severity: .info, layerID: l.id,
                                          message: "The \(role.label.lowercased()) will vanish at thumbnail size.", penalty: 2))
            }
            if l.rotation == 0 && (l.frame.x < -0.001 || l.frame.maxX > 1.001 || l.frame.y < -0.001 || l.frame.maxY > 1.001) {
                // Deliberate bleeds exist, so this stays a note.
                issues.append(CriticIssue(kind: .margin, severity: .info, layerID: l.id,
                                          message: "The \(role.label.lowercased()) runs off the cover.", penalty: 3))
            } else if l.rotation == 0 && role != .title && (l.frame.x < safeInset - 0.001 || l.frame.maxX > 1 - safeInset + 0.001
                                                          || l.frame.y < safeInset - 0.001 || l.frame.maxY > 1 - safeInset + 0.001) {
                issues.append(CriticIssue(kind: .margin, severity: .warning, layerID: l.id,
                                          message: "The \(role.label.lowercased()) crowds the trim edge.", penalty: 5))
            }
            for f in faces where !t.behindSubject {
                let cover = l.frame.intersectionArea(f) / max(1e-6, f.w * f.h)
                if cover > 0.3 {
                    issues.append(CriticIssue(kind: .face, severity: .warning, layerID: l.id,
                                              message: "The \(role.label.lowercased()) covers a face.", penalty: 14))
                    break
                }
            }
            for w in words {
                if l.frame.intersectionArea(w) / max(1e-6, w.w * w.h) > 0.4 {
                    issues.append(CriticIssue(kind: .photoText, severity: .warning, layerID: l.id,
                                              message: "The \(role.label.lowercased()) sits on words that are in the photo.", penalty: 8))
                    break
                }
            }
        }

        // Collisions between lines of type.
        for i in texts.indices {
            for j in (i + 1)..<texts.count where texts[i].rotation == 0 && texts[j].rotation == 0 {
                let a = texts[i].frame, b = texts[j].frame
                let inter = a.intersectionArea(b)
                let smaller = max(1e-6, min(a.w * a.h, b.w * b.h))
                if inter / smaller > 0.06 {
                    issues.append(CriticIssue(kind: .collision, severity: .fail, layerID: texts[j].id,
                                              message: "\(texts[i].name) and \(texts[j].name) overlap.", penalty: 12))
                }
            }
        }

        // Where readers look first: the title should own a fair share of the attention, or at least the peak.
        if let title = doc.textLayer(role: .title), title.isVisible, let full = renderedForAttention(doc),
           let att = VisionServices.attention(for: full) {
            var inside: Float = 0, total: Float = 0
            var peakV: Float = -1, peakX = 0, peakY = 0
            for y in 0..<att.height {
                for x in 0..<att.width {
                    let v = att.map[y * att.width + x]
                    total += v
                    let nx = (Double(x) + 0.5) / Double(att.width), ny = (Double(y) + 0.5) / Double(att.height)
                    if title.frame.insetBy(dx: -0.04, dy: -0.04).contains(nx, ny) { inside += v }
                    if v > peakV { peakV = v; peakX = x; peakY = y }
                }
            }
            let share = total > 0 ? Double(inside / total) : 1
            let px = (Double(peakX) + 0.5) / Double(att.width), py = (Double(peakY) + 0.5) / Double(att.height)
            let peakOnTitle = title.frame.insetBy(dx: -0.04, dy: -0.04).contains(px, py)
            if !peakOnTitle && share < 0.3 {
                let row = py < 0.33 ? "top" : py < 0.66 ? "middle" : "bottom"
                let col = px < 0.33 ? "left" : px < 0.66 ? "center" : "right"
                issues.append(CriticIssue(kind: .attention, severity: .info, layerID: title.id,
                                          message: "Readers' eyes land \(row) \(col), not on the title (it draws \(Int(share * 100))% of the attention).",
                                          penalty: 4))
            }
        }

        // Hierarchy: the author outranking the title is a deliberate brand-name move, otherwise a flaw.
        if let title = doc.textLayer(role: .title), let author = doc.textLayer(role: .author),
           let tt = title.textContent, let at = author.textContent {
            let cw = CGSize(width: Double(doc.canvas.width), height: canvasH)
            let ts = TextRenderer.resolvedSize(tt, box: title.frame.pixels(in: cw).size, canvasHeight: CGFloat(canvasH))
            let aus = TextRenderer.resolvedSize(at, box: author.frame.pixels(in: cw).size, canvasHeight: CGFloat(canvasH))
            if aus > ts * 1.15 && !(doc.archetypeName.lowercased().contains("brand")) {
                issues.append(CriticIssue(kind: .hierarchy, severity: .info, layerID: author.id,
                                          message: "The author's name is set larger than the title.", penalty: 4))
            }
        }

        let score = max(0, min(100, 100 - issues.reduce(0) { $0 + $1.penalty }))
        return CriticReport(score: score, issues: issues.sorted { $0.penalty > $1.penalty })
    }

    /// The color the type actually shows: a styled face (stone, bronze, wood) is dark whatever the nominal color.
    static func faceColor(_ t: TextContent) -> RGBA {
        if t.style.isActive && TemplateLibrary.darkFaces.contains(t.style.surface) { return RGBA(0.24, 0.21, 0.18) }
        if t.texture.metalStops != nil || (t.style.isActive && t.style.surface != .none) { return t.color.mixed(with: RGBA(0.5, 0.5, 0.5), 0.3) }
        return t.color
    }

    /// The whole cover, small, for the attention model.
    static func renderedForAttention(_ doc: CoverDocument) -> CGImage? {
        let h: CGFloat = 384
        return CoverRenderer.shared.render(doc, size: CGSize(width: (h / CGFloat(doc.canvas.aspect)).rounded(), height: h), quality: .preview)
    }

    private static func hasBacking(_ doc: CoverDocument, under text: Layer) -> Bool {
        guard let ti = doc.index(of: text.id) else { return false }
        for l in doc.layers[..<ti].reversed() {
            guard let f = l.fillContent else { continue }
            if (f.style == .scrim || f.style == .solid) && l.frame.intersectionArea(text.frame) > text.frame.w * text.frame.h * 0.8 { return true }
        }
        return false
    }

    /// Faces in the cover's photos, in cover coordinates.
    static func faceRects(_ doc: CoverDocument) -> [NRect] {
        photoRects(doc) { id, data in AssetStore.shared.faces(id, data: data) }
    }

    /// Words printed inside the cover's photos (signs, pages, labels), in cover coordinates.
    static func photoTextRects(_ doc: CoverDocument) -> [NRect] {
        photoRects(doc) { id, data in AssetStore.shared.textRegions(id, data: data) }
    }

    private static func photoRects(_ doc: CoverDocument, _ pick: (UUID, Data?) -> [NRect]) -> [NRect] {
        var out: [NRect] = []
        let canvas = CGSize(width: Double(doc.canvas.width), height: Double(doc.canvas.height))
        for l in doc.layers {
            guard l.isVisible, let ic = l.imageContent, ic.cutout != .background else { continue }
            let data = doc.assetData(ic.assetID)
            let faces = pick(ic.assetID, data)
            guard !faces.isEmpty, let img = AssetStore.shared.image(ic.assetID, data: data, resolution: .thumbnail) else { continue }
            let frame = l.frame.pixels(in: canvas)
            let iw = Double(img.width), ih = Double(img.height)
            let s = max(frame.width / iw, frame.height / ih) * max(1, ic.zoom)
            let dw = iw * s, dh = ih * s
            let ox = -(dw - frame.width) * ic.focusX.clamped01
            let oy = -(dh - frame.height) * ic.focusY.clamped01
            for f in faces {
                let fx = ic.flipped ? (1 - f.maxX) : f.x
                let x = frame.minX + ox + fx * dw, y = frame.minY + oy + f.y * dh
                let r = NRect(x / canvas.width, y / canvas.height, f.w * dw / canvas.width, f.h * dh / canvas.height)
                if r.maxX > 0 && r.x < 1 && r.maxY > 0 && r.y < 1 { out.append(r) }
            }
        }
        return out
    }

    // MARK: Repair

    /// Fixes legibility (colors, lifts, backings) and, when `geometry` is allowed, moves type off collisions,
    /// faces and the trim. Returns the review of the repaired cover.
    @discardableResult
    static func repair(_ doc: inout CoverDocument, geometry: Bool = true, palette: PaletteRoles? = nil) -> CriticReport {
        guard let bg = Polisher.backgroundSample(doc) else { return review(doc) }
        let p = palette ?? PaletteRoles(doc.palette)
        if geometry {
            fixGeometry(&doc, faces: faceRects(doc) + photoTextRects(doc))
        }
        Polisher.polish(&doc, palette: p, background: bg)
        // A second look: anything still failing gets a soft backing behind the words.
        var report = review(doc, background: bg)
        var insertions: [(Int, Layer)] = []
        for issue in report.issues where issue.kind == .legibility && issue.severity == .fail {
            guard let id = issue.layerID, let i = doc.index(of: id), let t = doc.layers[i].textContent else { continue }
            if hasBacking(doc, under: doc.layers[i]) { continue }
            insertions.append((i, backing(for: doc.layers[i], color: t.color.isDark ? p.light : p.dark)))
        }
        if !insertions.isEmpty {
            for (i, s) in insertions.reversed() { doc.layers.insert(s, at: i) }
            report = review(doc)
        }
        return report
    }

    /// A soft block of the opposite tone behind one line of type.
    static func backing(for text: Layer, color: RGBA) -> Layer {
        let f = text.frame
        var s = Layer.fill(.solid, colors: [color.withAlpha(0.62)], frame: f.insetBy(dx: -0.06, dy: -max(0.02, f.h * 0.35)))
        s.fade = .vignette
        s.fadeAmount = 0.9
        s.name = "Backing"
        return s
    }

    private static func fixGeometry(_ doc: inout CoverDocument, faces: [NRect]) {
        let ids = doc.layers.filter { $0.textContent != nil && $0.rotation == 0 }.map(\.id)
        // Keep every line inside the safe area.
        for id in ids {
            guard let i = doc.index(of: id) else { continue }
            var f = doc.layers[i].frame
            let isTitle = doc.layers[i].textContent?.role == .title
            let inset = isTitle ? 0.0 : safeInset
            if f.w > 1 - 2 * inset { f.w = 1 - 2 * inset }
            if f.h > 1 - 2 * inset { f.h = 1 - 2 * inset }
            f.x = min(max(inset, f.x), 1 - inset - f.w)
            f.y = min(max(inset, f.y), 1 - inset - f.h)
            doc.layers[i].frame = f
        }
        // Move supporting lines away from faces and from each other; the title stays where the design put it.
        let priority: [TextRole] = [.title, .author, .subtitle, .tagline, .series, .custom]
        let ordered = ids.sorted { a, b in
            let ra = priority.firstIndex(of: doc.layers[doc.index(of: a)!].textContent!.role) ?? 9
            let rb = priority.firstIndex(of: doc.layers[doc.index(of: b)!].textContent!.role) ?? 9
            return ra < rb
        }
        var placed: [NRect] = []
        for id in ordered {
            guard let i = doc.index(of: id) else { continue }
            let role = doc.layers[i].textContent?.role ?? .custom
            var f = doc.layers[i].frame
            let behind = doc.layers[i].textContent?.behindSubject ?? false
            func clear(_ r: NRect) -> Bool {
                for o in placed where o.intersectionArea(r) / max(1e-6, min(o.w * o.h, r.w * r.h)) > 0.06 { return false }
                if !behind { for face in faces where r.intersectionArea(face) / max(1e-6, face.w * face.h) > 0.3 { return false } }
                return true
            }
            // The title moves only to get off a face; everything else also clears the other lines.
            let coversFace = !behind && faces.contains { f.intersectionArea($0) / max(1e-6, $0.w * $0.h) > 0.3 }
            if (role != .title && !clear(f)) || (role == .title && coversFace) {
                // Try nudging down, then up, in small steps.
                var found = false
                for step in 1...30 {
                    let d = Double(step) * 0.02
                    for dir in [1.0, -1.0] {
                        var c = f
                        c.y = f.y + dir * d
                        if c.y < safeInset || c.maxY > 1 - safeInset { continue }
                        if clear(c) { f = c; found = true; break }
                    }
                    if found { break }
                }
                doc.layers[i].frame = f
            }
            placed.append(f)
        }
    }

    // MARK: Choosing

    /// The best of several candidates by score; ties go to the earlier one.
    static func best(_ candidates: [CoverDocument]) -> (CoverDocument, CriticReport)? {
        var winner: (CoverDocument, CriticReport)?
        for c in candidates {
            let r = review(c)
            if winner == nil || r.score > winner!.1.score { winner = (c, r) }
        }
        return winner
    }
}
