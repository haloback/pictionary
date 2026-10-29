import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Ebook storefront cover targets. Values follow each store's published guidance at the
/// time of writing; stores do revise them, so the notes say "recommended".
struct StoreSpec: Identifiable, Hashable {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let minWidth: Int
    let minHeight: Int
    let note: String

    var aspect: Double { Double(height) / Double(width) }

    static let all: [StoreSpec] = [
        StoreSpec(id: "kdp", name: "Amazon Kindle", width: 1600, height: 2560, minWidth: 625, minHeight: 1000,
                  note: "Recommended 1600 x 2560 (1:1.6). JPEG or TIFF, RGB, under 50 MB."),
        StoreSpec(id: "gplay", name: "Google Play Books", width: 1800, height: 2700, minWidth: 640, minHeight: 960,
                  note: "2:3 portrait. JPEG or PNG; larger images look better on tablets."),
        StoreSpec(id: "apple", name: "Apple Books", width: 1600, height: 2400, minWidth: 1400, minHeight: 2100,
                  note: "At least 1400 px wide, 2:3 recommended. JPEG or PNG, RGB."),
        StoreSpec(id: "kobo", name: "Kobo Writing Life", width: 1600, height: 2400, minWidth: 1000, minHeight: 1500,
                  note: "Recommended 1600 x 2400. JPEG or PNG."),
        StoreSpec(id: "bn", name: "Barnes & Noble Press", width: 1600, height: 2400, minWidth: 1400, minHeight: 1400,
                  note: "Recommended 1600 x 2400, short side at least 1400 px."),
        StoreSpec(id: "d2d", name: "Draft2Digital", width: 1600, height: 2400, minWidth: 1400, minHeight: 2100,
                  note: "Recommended 1600 x 2400. JPEG."),
        StoreSpec(id: "ingram", name: "IngramSpark (ebook)", width: 1600, height: 2560, minWidth: 1400, minHeight: 2240,
                  note: "Recommended 1600 x 2560. JPEG, RGB.")
    ]

    static func spec(_ id: String) -> StoreSpec { all.first { $0.id == id } ?? all[0] }
}

enum Severity: Int, Comparable {
    case pass, info, warning, fail
    static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
}

enum FixAction {
    case improveContrast(UUID)
    case addScrim(UUID)
    case moveIntoSafeArea(UUID)
    case enlarge(UUID)
    case addBorder
    case resizeCanvas(StoreSpec)

    var label: String {
        switch self {
        case .improveContrast: return "Fix Color"
        case .addScrim: return "Add Scrim"
        case .moveIntoSafeArea: return "Move Inside"
        case .enlarge: return "Enlarge"
        case .addBorder: return "Add Border"
        case .resizeCanvas: return "Match Size"
        }
    }
}

struct PreflightIssue: Identifiable {
    let id = UUID()
    let severity: Severity
    let title: String
    let detail: String
    var fix: FixAction?
}

enum Preflight {
    static let safeMargin = 0.04

    static func run(_ doc: CoverDocument, spec: StoreSpec, background: CGImage?, full: CGImage?) -> [PreflightIssue] {
        var out: [PreflightIssue] = []
        let c = doc.canvas

        // Size and shape
        if abs(c.aspect - spec.aspect) > 0.01 {
            out.append(PreflightIssue(severity: .warning, title: "Proportions differ from \(spec.name)",
                                      detail: "Your canvas is \(c.width) x \(c.height); \(spec.name) recommends \(spec.width) x \(spec.height). Export re-flows the layout, so check it, or switch the canvas.",
                                      fix: .resizeCanvas(spec)))
        } else {
            out.append(PreflightIssue(severity: .pass, title: "Proportions match \(spec.name)", detail: spec.note))
        }
        out.append(PreflightIssue(severity: .pass, title: "Export resolution \(spec.width) x \(spec.height)",
                                  detail: "Above the \(spec.minWidth) x \(spec.minHeight) minimum. Exports are sRGB, high-quality JPEG or PNG."))

        // Required content
        let title = doc.textLayer(role: .title)
        if title == nil || title?.textContent?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            out.append(PreflightIssue(severity: .fail, title: "No title on the cover",
                                      detail: "Stores expect the cover to show the book's title, matching your metadata."))
        }
        if doc.textLayer(role: .author) == nil {
            out.append(PreflightIssue(severity: .warning, title: "No author name",
                                      detail: "Readers look for the author's name; stores compare it with your metadata."))
        }

        // Legibility of every line of type
        let canvasSize = c.size
        for l in doc.layers where l.isVisible {
            guard let t = l.textContent else { continue }
            let label = t.role == .custom ? "\"\(t.text.prefix(18))\"" : t.role.label
            if let bg = background {
                let s = PixelSampler.stats(bg, region: l.frame)
                let ratio = t.color.contrast(with: s.mean)
                let need = t.role.minimumContrast
                let lifted = l.shadow != nil || t.glowColor != nil || t.strokeColor != nil
                if ratio < 2 && !lifted {
                    out.append(PreflightIssue(severity: .fail, title: "\(label) is hard to read",
                                              detail: String(format: "Contrast %.1f:1 against what's behind it. Aim for %.1f:1.", ratio, need), fix: .improveContrast(l.id)))
                } else if ratio < need && !lifted {
                    out.append(PreflightIssue(severity: .warning, title: "\(label) contrast is low",
                                              detail: String(format: "%.1f:1; %.1f:1 reads clearly at thumbnail size.", ratio, need), fix: .improveContrast(l.id)))
                } else {
                    out.append(PreflightIssue(severity: .pass, title: "\(label) is legible", detail: String(format: "Contrast %.1f:1%@.", ratio, lifted ? " plus shadow or outline" : "")))
                }
                if s.busyness > 0.2 && !lifted {
                    out.append(PreflightIssue(severity: .warning, title: "Busy image behind \(label)",
                                              detail: "Detail behind type fights with it. A scrim or shadow fixes it.", fix: .addScrim(l.id)))
                }
            }

            let f = l.frame
            if f.x < safeMargin || f.maxX > 1 - safeMargin || f.y < safeMargin * 0.6 || f.maxY > 1 - safeMargin * 0.6 {
                out.append(PreflightIssue(severity: .warning, title: "\(label) is close to the edge",
                                          detail: "Store pages crop and round corners. Keep type 4% inside the trim.", fix: .moveIntoSafeArea(l.id)))
            }

            // Thumbnail test: how tall is the type when the cover is 160 px tall in search results?
            let box = f.pixels(in: canvasSize).size
            let size = TextRenderer.resolvedSize(t, box: box, canvasHeight: canvasSize.height)
            let capAtThumb = size * 0.7 * 160 / canvasSize.height
            if t.role == .title {
                if capAtThumb < 7 {
                    out.append(PreflightIssue(severity: .warning, title: "Title is small in search results",
                                              detail: String(format: "About %.0f px tall on a 160 px thumbnail. 8 px or more reads at a glance.", capAtThumb), fix: .enlarge(l.id)))
                } else {
                    out.append(PreflightIssue(severity: .pass, title: "Title reads at thumbnail size", detail: String(format: "About %.0f px tall on a 160 px thumbnail.", capAtThumb)))
                }
            } else if t.role == .author && capAtThumb < 3 {
                out.append(PreflightIssue(severity: .info, title: "Author name vanishes in thumbnails",
                                          detail: "Fine for debut authors; established names usually go bigger.", fix: .enlarge(l.id)))
            }
        }

        // Typeface discipline
        let families = Set(doc.layers.compactMap { $0.textContent.map { FontCatalog.family($0.fontName) } })
        if families.count > 3 {
            out.append(PreflightIssue(severity: .warning, title: "\(families.count) typefaces in use",
                                      detail: "Professional covers rarely use more than two. Try matching the subtitle to the author line."))
        }

        // Pale covers vanish on white store pages.
        if let img = full {
            let edges = [NRect(0, 0, 1, 0.02), NRect(0, 0.98, 1, 0.02), NRect(0, 0, 0.02, 1), NRect(0.98, 0, 0.02, 1)]
            let lum = edges.map { PixelSampler.stats(img, region: $0).mean.luminance }.reduce(0, +) / 4
            let hasBorder = doc.layers.contains { $0.shapeContent?.kind == .frame && $0.frame.x <= 0.001 }
            if lum > 0.85 && !hasBorder {
                out.append(PreflightIssue(severity: .warning, title: "Light edges blend into white store pages",
                                          detail: "Amazon suggests a thin medium-gray border on very light covers.", fix: .addBorder))
            }
        }

        // Composition
        if let tl = title {
            let onGolden = [Golden.minor, Golden.major, 1.0 / 3.0, 2.0 / 3.0].contains { abs($0 - tl.frame.midY) < 0.06 }
                || abs(tl.frame.y - 0.06) < 0.05 || tl.frame.h > 0.25
            out.append(PreflightIssue(severity: onGolden ? .pass : .info,
                                      title: onGolden ? "Title sits on a strong line" : "Title floats between guides",
                                      detail: onGolden ? "Aligned to a golden-section, thirds or top band." : "Try snapping it to a golden line (View > Guides)."))
            if let ph = doc.photoLayers.first, tl.textContent?.behindSubject == false {
                let focus = AssetStore.shared.focus(ph.imageContent!.assetID, data: doc.assetData(ph.imageContent!.assetID))
                let mapped = NRect(ph.frame.x + focus.x * ph.frame.w, ph.frame.y + focus.y * ph.frame.h, focus.w * ph.frame.w, focus.h * ph.frame.h)
                if mapped.area > 0, tl.frame.intersectionArea(mapped) / mapped.area > 0.35 {
                    out.append(PreflightIssue(severity: .info, title: "Title covers the photo's focal point",
                                              detail: "Move it, or turn on \"Behind subject\" so the subject overlaps the type."))
                }
            }
        }
        return out.sorted { $0.severity > $1.severity }
    }

    static func apply(_ fix: FixAction, to doc: inout CoverDocument, background: CGImage?) {
        let p = PaletteRoles(doc.palette)
        switch fix {
        case .improveContrast(let id):
            guard let i = doc.index(of: id), var t = doc.layers[i].textContent else { return }
            if let bg = background {
                let s = PixelSampler.stats(bg, region: doc.layers[i].frame)
                t.color = ColorAdvisor.bestText(on: s.mean, candidates: ColorAdvisor.textCandidates(p, onDark: s.mean.luminance < 0.36), minimum: t.role.minimumContrast)
            }
            doc.layers[i].textContent = t
            if doc.layers[i].shadow == nil {
                doc.layers[i].shadow = ShadowStyle(color: t.color.isDark ? RGBA(1, 1, 1, 0.4) : RGBA(0, 0, 0, 0.6), radius: 0.008, dx: 0, dy: 0.002)
            }
        case .addScrim(let id):
            guard let i = doc.index(of: id) else { return }
            let f = doc.layers[i].frame
            let dark = !(doc.layers[i].textContent?.color.isDark ?? false)
            var s = Layer.fill(.solid, colors: [(dark ? p.dark : p.light).withAlpha(0.6)], frame: f.insetBy(dx: -0.1, dy: -0.04))
            s.fade = .vignette
            s.fadeAmount = 0.9
            s.name = "Legibility Scrim"
            doc.layers.insert(s, at: i)
        case .moveIntoSafeArea(let id):
            guard let i = doc.index(of: id) else { return }
            var f = doc.layers[i].frame
            let m = safeMargin + 0.01
            f.w = min(f.w, 1 - 2 * m)
            f.h = min(f.h, 1 - 2 * m)
            f.x = f.x.clamped(m, 1 - m - f.w)
            f.y = f.y.clamped(m * 0.8, 1 - m * 0.8 - f.h)
            doc.layers[i].frame = f
        case .enlarge(let id):
            guard let i = doc.index(of: id) else { return }
            var f = doc.layers[i].frame
            let cy = f.midY
            f.h = min(0.4, f.h * 1.35)
            f.x = max(0.05, f.x - 0.03)
            f.w = min(0.9, f.w + 0.06)
            f.y = (cy - f.h / 2).clamped(0.03, 0.97 - f.h)
            doc.layers[i].frame = f
            doc.layers[i].textContent?.autoFit = true
        case .addBorder:
            var b = Layer.shape(.frame, fill: nil, stroke: RGBA(0.55, 0.55, 0.57), strokeWidth: 0.0025, frame: .full)
            b.name = "Store Border"
            doc.layers.append(b)
        case .resizeCanvas(let spec):
            doc.canvas = CanvasSpec(width: spec.width, height: spec.height)
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG", png = "PNG", tiff = "TIFF"
    var id: String { rawValue }
    var ext: String { self == .jpeg ? "jpg" : rawValue.lowercased() }
    var type: UTType { self == .jpeg ? .jpeg : (self == .png ? .png : .tiff) }
}

enum Exporter {
    static func write(_ img: CGImage, to url: URL, format: ExportFormat, quality: Double) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, format.type.identifier as CFString, 1, nil) else { return false }
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyDPIWidth: 300,
            kCGImagePropertyDPIHeight: 300
        ]
        CGImageDestinationAddImage(dest, img, props as CFDictionary)
        return CGImageDestinationFinalize(dest)
    }

    static func safeFileName(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = s.components(separatedBy: bad).joined(separator: "-").trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Cover" : cleaned
    }

    /// Renders and writes one file per store. Returns written URLs.
    static func export(_ doc: CoverDocument, specs: [StoreSpec], format: ExportFormat, quality: Double, folder: URL,
                       progress: (Int) -> Void) -> [URL] {
        var urls: [URL] = []
        let base = safeFileName(doc.book.title.isEmpty ? "Cover" : doc.book.title)
        for (n, spec) in specs.enumerated() {
            var d = doc
            d.canvas = CanvasSpec(width: spec.width, height: spec.height)
            guard let img = CoverRenderer.shared.render(d, size: CGSize(width: spec.width, height: spec.height), quality: .full) else { continue }
            let url = folder.appendingPathComponent("\(base) - \(spec.name).\(format.ext)")
            if write(img, to: url, format: format, quality: quality) { urls.append(url) }
            progress(n + 1)
        }
        return urls
    }
}
