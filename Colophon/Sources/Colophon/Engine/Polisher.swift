import CoreGraphics
import Foundation

/// The safety net that keeps every cover legible: it looks at what is actually behind each
/// line of type and fixes color, adds shadows or inserts a scrim.
enum Polisher {
    static func backgroundSample(_ doc: CoverDocument) -> CGImage? {
        let textIDs = Set(doc.layers.filter { $0.textContent != nil }.map(\.id))
        let h: CGFloat = 320
        return CoverRenderer.shared.render(doc, size: CGSize(width: (h / CGFloat(doc.canvas.aspect)).rounded(), height: h),
                                           quality: .preview, excluding: textIDs)
    }

    static func polish(_ doc: inout CoverDocument, palette: PaletteRoles? = nil) {
        guard let bg = backgroundSample(doc) else { return }
        let p = palette ?? PaletteRoles(doc.palette)
        var insertions: [(Int, Layer)] = []

        for (i, layer) in doc.layers.enumerated() {
            guard var t = layer.textContent else { continue }
            let stats = PixelSampler.stats(bg, region: layer.frame)
            let need = t.role.minimumContrast
            let onDark = stats.mean.luminance < 0.36

            if t.color.contrast(with: stats.mean) < need {
                t.color = ColorAdvisor.bestText(on: stats.mean, candidates: ColorAdvisor.textCandidates(p, onDark: onDark), minimum: need)
            }
            let achieved = t.color.contrast(with: stats.mean)
            var l = layer
            // Busy photo or marginal contrast: lift the type off the image.
            if (stats.busyness > 0.16 || achieved < need + 1) && l.shadow == nil && t.glowColor == nil {
                let shadowColor = t.color.isDark ? RGBA(1, 1, 1, 0.35) : RGBA(0, 0, 0, 0.6)
                l.shadow = ShadowStyle(color: shadowColor, radius: t.role == .title ? 0.012 : 0.006, dx: 0, dy: t.role == .title ? 0.003 : 0.0015)
            }
            if achieved < need {
                let scrimColor = t.color.isDark ? p.light : p.dark
                var s = Layer.fill(.scrim, colors: [scrimColor], frame: l.frame.insetBy(dx: -0.08, dy: -0.06 * l.frame.h - 0.02), angle: 90, intensity: 0.9)
                s.fillContent?.style = .solid
                s.fillContent?.colors = [scrimColor.withAlpha(0.55)]
                s.fade = .vignette
                s.fadeAmount = 0.9
                s.name = "Auto Scrim"
                insertions.append((i, s))
            }
            l.textContent = t
            doc.layers[i] = l
        }
        for (i, s) in insertions.reversed() { doc.layers.insert(s, at: i) }
    }
}

/// One-click design ideas that respond to the current cover.
struct Suggestion: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
    let apply: (inout CoverDocument) -> Void
}

enum SuggestionEngine {
    static func suggestions(for doc: CoverDocument, background: CGImage?) -> [Suggestion] {
        var out: [Suggestion] = []
        let p = PaletteRoles(doc.palette)
        let titleLayer = doc.textLayer(role: .title)
        let photo = doc.photoLayers.first
        let topTextIndex = doc.layers.firstIndex { $0.textContent != nil } ?? doc.layers.count

        if let tl = titleLayer, let bg = background {
            let stats = PixelSampler.stats(bg, region: tl.frame)
            let t = tl.textContent!
            if t.color.contrast(with: stats.mean) < 4.5 {
                let better = ColorAdvisor.bestText(on: stats.mean, candidates: ColorAdvisor.textCandidates(p, onDark: stats.mean.luminance < 0.36), minimum: 4.5)
                out.append(Suggestion(symbol: "circle.lefthalf.filled", title: "Make the title pop",
                                      detail: "Contrast is \(String(format: "%.1f", t.color.contrast(with: stats.mean))):1. Switch to \(better.hex) for \(String(format: "%.1f", better.contrast(with: stats.mean))):1.") { d in
                    if let i = d.index(of: tl.id) { d.layers[i].textContent?.color = better }
                })
            }
            if stats.busyness > 0.14 {
                out.append(Suggestion(symbol: "rectangle.bottomthird.inset.filled", title: "Calm the area behind the title",
                                      detail: "The image is busy there. A soft scrim fades it toward your darkest color.") { d in
                    guard let i = d.index(of: tl.id) else { return }
                    let up = tl.frame.midY < 0.5
                    var s = Layer.fill(.scrim, colors: [p.dark], frame: up ? NRect(0, 0, 1, min(1, tl.frame.maxY + 0.12)) : NRect(0, max(0, tl.frame.y - 0.12), 1, 1 - max(0, tl.frame.y - 0.12)), angle: up ? 270 : 90, intensity: 0.85)
                    s.name = "Legibility Scrim"
                    d.layers.insert(s, at: i)
                })
            }
        }

        if let tl = titleLayer, let ph = photo, tl.textContent?.behindSubject == false {
            out.append(Suggestion(symbol: "person.and.background.dotted", title: "Tuck the title behind the subject",
                                  detail: "Lifts the subject from the photo and slides the type behind it, magazine style.") { d in
                guard let i = d.index(of: tl.id) else { return }
                d.layers[i].textContent?.behindSubject = true
                d.layers[i].textContent?.autoFit = true
                if d.layers[i].frame.h < 0.22 { d.layers[i].frame = NRect(0.04, 0.05, 0.92, 0.3) }
                _ = ph
            })
        }

        if let tl = titleLayer {
            let opposite = ColorAdvisor.opposite(p.dominant)
            out.append(Suggestion(symbol: "arrow.left.arrow.right.circle", title: "Use the opposite color for the title",
                                  detail: "\(opposite.hex) sits across the wheel from the cover's main color \(p.dominant.hex).") { d in
                if let i = d.index(of: tl.id) { d.layers[i].textContent?.color = opposite }
            })
            let centerY = tl.frame.midY
            let nearest = [Golden.minor, Golden.major].min { abs($0 - centerY) < abs($1 - centerY) }!
            if abs(nearest - centerY) > 0.03 {
                out.append(Suggestion(symbol: "rectangle.split.3x3", title: "Snap the title to the golden line",
                                      detail: "Moves the title so it centers on the \(nearest < 0.5 ? "upper" : "lower") golden section (\(Int(nearest * 100))%).") { d in
                    if let i = d.index(of: tl.id) { d.layers[i].frame.y = (nearest - tl.frame.h / 2).clamped(0.02, 0.98 - tl.frame.h) }
                })
            }
            if let t = tl.textContent, t.gradientTo == nil {
                out.append(Suggestion(symbol: "paintbrush.pointed", title: "Blend the title into the accent",
                                      detail: "A vertical gradient from \(t.color.hex) into \(p.accent.withLightness(0.7).hex).") { d in
                    if let i = d.index(of: tl.id) { d.layers[i].textContent?.gradientTo = p.accent.withLightness(0.7) }
                })
            }
        }

        if let tl = titleLayer, tl.textContent?.texture == TextTexture.none {
            let finish = TextTexture.suggested(for: doc.book.genre)
            out.append(Suggestion(symbol: "textformat.alt", title: "Give the title a \(finish.label.lowercased()) finish",
                                  detail: "A finish readers associate with \(doc.book.genre.label.lowercased()) covers.") { d in
                if let i = d.index(of: tl.id) { d.layers[i].textContent?.texture = finish }
            })
        }
        if let tl = titleLayer, tl.textContent?.arc == 0, (tl.textContent?.text.split(separator: "\n").count ?? 2) == 1 {
            out.append(Suggestion(symbol: "arrow.up.and.down.text.horizontal", title: "Arch the title",
                                  detail: "A gentle curve suits medallion, arch and badge-style covers.") { d in
                if let i = d.index(of: tl.id) { d.layers[i].textContent?.arc = 0.35 }
            })
        }
        out.append(Suggestion(symbol: "scribble.variable", title: "Smear paint across the artwork",
                              detail: "Streaks of your palette, overlaid softly so the photo shows through.") { d in
            var l = Layer.fill(.paintSmear, colors: [p.dark, p.accent, p.dominant, p.light], seed: Int.random(in: 1...99999), intensity: 0.6)
            l.blend = .softLight
            l.opacity = 0.7
            d.layers.insert(l, at: min(topTextIndex, d.layers.count))
        })
        out.append(Suggestion(symbol: "circle.hexagongrid", title: "Mesh-blend two palette colors",
                              detail: "A soft blend of \(p.accent.hex) and \(p.dark.hex) washed over the image in Color mode.") { d in
            var l = Layer.fill(.meshBlend, colors: [p.dark, p.accent, p.dominant], seed: Int.random(in: 1...99999), intensity: 0.7)
            l.blend = .color
            l.opacity = 0.45
            d.layers.insert(l, at: min(topTextIndex, d.layers.count))
        })
        out.append(Suggestion(symbol: "sun.haze", title: "Add a light leak in the accent",
                              detail: "A warm glow from the corner opposite the title.") { d in
            var l = Layer.fill(.radial, colors: [p.accent.withAlpha(0.85), p.accent.withAlpha(0)], intensity: 0.4)
            l.blend = .screen
            l.frame = NRect(0.3, 0.3, 0.9, 0.9)
            d.layers.insert(l, at: min(topTextIndex, d.layers.count))
        })

        if let ph = photo {
            let hasGrain = ph.effects.contains { $0.presetID.contains("grain") }
            if !hasGrain {
                out.append(Suggestion(symbol: "circle.dotted", title: "Unify everything with film grain",
                                      detail: "Fine grain glues photo, color and type into one printed-looking surface.") { d in
                    if let i = d.index(of: ph.id) { d.layers[i].effects.append(EffectInstance(presetID: "tone.fine-grain.3", amount: 1)) }
                })
            }
            if let duo = EffectLibrary.shared.closestDuotone(to: p.dark) {
                out.append(Suggestion(symbol: "circle.lefthalf.filled.righthalf.striped.horizontal", title: "Duotone the photo in your palette",
                                      detail: "\(duo.name). Makes mismatched photos feel art-directed.") { d in
                    if let i = d.index(of: ph.id) { d.layers[i].effects.append(EffectInstance(presetID: duo.id, amount: 0.9)) }
                })
            }
            if !doc.layers.contains(where: { $0.imageContent?.cutout == .subject }) {
                out.append(Suggestion(symbol: "person.crop.rectangle.stack", title: "Lift the subject for depth",
                                      detail: "Blurs the background and sets a sharp cutout of the subject on top.") { d in
                    guard let i = d.index(of: ph.id) else { return }
                    d.layers[i].effects.append(EffectInstance(presetID: "tone.background-blur.3", amount: 1))
                    var s = ph
                    s.id = UUID()
                    s.name = "Subject (lifted)"
                    s.imageContent?.cutout = .subject
                    s.effects = []
                    s.shadow = ShadowStyle(color: RGBA(0, 0, 0, 0.55), radius: 0.018, dx: 0, dy: 0.006)
                    d.layers.insert(s, at: i + 1)
                })
            }
            if ph.fade == .none && ph.frame.h < 0.95 {
                out.append(Suggestion(symbol: "square.bottomhalf.filled", title: "Fade the photo into the color",
                                      detail: "Dissolves the photo's edge into the ground so there is no hard seam.") { d in
                    if let i = d.index(of: ph.id) { d.layers[i].fade = .bottom; d.layers[i].fadeAmount = 0.3 }
                })
            }
            out.append(Suggestion(symbol: "camera.aperture", title: "Add a vignette",
                                  detail: "Darkens the corners to pull the eye toward the center.") { d in
                if let i = d.index(of: ph.id) { d.layers[i].effects.append(EffectInstance(presetID: "tone.vignette.3", amount: 1)) }
            })
        }

        if let au = doc.textLayer(role: .author), let t = au.textContent, t.tracking < 0.15 {
            out.append(Suggestion(symbol: "textformat.size", title: "Track out the author name",
                                  detail: "Wide letter-spacing on small caps is the classic professional touch.") { d in
                if let i = d.index(of: au.id) { d.layers[i].textContent?.tracking = 0.3; d.layers[i].textContent?.letterCase = .upper }
            })
        }
        if let tl = titleLayer, let au = doc.textLayer(role: .author), !doc.layers.contains(where: { $0.shapeContent?.kind == .rule }) {
            out.append(Suggestion(symbol: "minus", title: "Add a hairline rule",
                                  detail: "A short rule between title and author adds structure and rhythm.") { d in
                let y = (tl.frame.maxY + au.frame.y) / 2
                guard y > 0.05, y < 0.95 else { return }
                var r = Layer.shape(.rule, fill: p.accent, frame: NRect(0.44, y, 0.12, 0.0025))
                r.name = "Rule"
                d.layers.append(r)
            })
        }
        return out
    }
}
