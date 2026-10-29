import Foundation

/// "More like this": variations of the cover being edited that keep its layout and
/// the user's edits, and explore one or two design decisions at a time.
enum Remixer {
    enum Move: CaseIterable {
        case type, palette, opposite, effect, crop, mirror
    }

    static func remix(_ doc: CoverDocument, count: Int, seed: Int) -> [CoverDocument] {
        var rng = SeededRNG(seed: seed)
        let style = GenreStyle.of(doc.book.genre)
        let hasPhoto = !doc.photoLayers.isEmpty
        let moves: [Move] = Move.allCases.filter { hasPhoto || ($0 != .effect && $0 != .crop) }
        var out: [CoverDocument] = []
        for i in 0..<count {
            var d = doc
            var names: [String] = []
            // Every remix makes one primary move; half of them add a second.
            var picks = [moves[i % moves.count]]
            if rng.unit() < 0.5 {
                let extra = rng.pick(moves)
                if extra != picks[0] { picks.append(extra) }
            }
            for m in picks {
                switch m {
                case .type:
                    let t = style.treatments[(i + rng.int(style.treatments.count)) % style.treatments.count]
                    retype(&d, t)
                    names.append(t.name)
                case .palette:
                    let mood = style.moods[rng.int(style.moods.count)]
                    recolor(&d, to: PaletteRoles(mood))
                    names.append("Genre colors")
                case .opposite:
                    recolor(&d, to: PaletteRoles(d.palette).complementary)
                    names.append("Opposite accent")
                case .effect:
                    let e = style.effects[rng.int(style.effects.count)]
                    for j in d.layers.indices where d.layers[j].imageContent?.cutout == Cutout.none {
                        d.layers[j].effects = [EffectInstance(presetID: e, amount: 0.85)]
                    }
                    names.append(EffectLibrary.shared.preset(e)?.name.components(separatedBy: ",").first ?? "New look")
                case .crop:
                    for j in d.layers.indices where d.layers[j].imageContent != nil {
                        d.layers[j].imageContent?.zoom = rng.range(1.15, 1.7)
                        d.layers[j].imageContent?.focusX = rng.range(0.3, 0.7)
                        d.layers[j].imageContent?.focusY = rng.range(0.25, 0.6)
                    }
                    names.append("Tighter crop")
                case .mirror:
                    mirror(&d)
                    names.append("Flipped layout")
                }
            }
            d.archetypeName = names.joined(separator: " + ")
            Polisher.polish(&d)
            out.append(d)
        }
        return out
    }

    static func retype(_ d: inout CoverDocument, _ t: TypeTreatment) {
        for j in d.layers.indices {
            guard var c = d.layers[j].textContent else { continue }
            switch c.role {
            case .title:
                c.fontName = t.titleFont
                c.letterCase = t.titleCase
                c.tracking = t.titleTracking
                c.lineHeight = t.titleLineHeight
                c.text = TitleBreaker.auto(c.text.replacingOccurrences(of: "\n", with: " "), stacked: t.stacked)
            case .author, .series:
                c.fontName = t.authorFont
                c.letterCase = t.authorCase
                c.tracking = t.authorTracking
            default:
                c.fontName = t.authorFont
            }
            d.layers[j].textContent = c
        }
    }

    /// Maps every color to the new palette by its rank in lightness, so darks stay dark
    /// and lights stay light.
    static func recolor(_ d: inout CoverDocument, to p: PaletteRoles) {
        let old = (d.palette.isEmpty ? [RGBA.ink, RGBA.paper] : d.palette).sorted { $0.luminance < $1.luminance }
        let new = [p.dark, p.dominant, p.accent, p.light].sorted { $0.luminance < $1.luminance }
        func map(_ c: RGBA) -> RGBA {
            guard let idx = old.indices.min(by: { old[$0].distance(to: c) < old[$1].distance(to: c) }) else { return c }
            let pos = old.count > 1 ? Double(idx) / Double(old.count - 1) : 0
            return new[Int((pos * Double(new.count - 1)).rounded())].withAlpha(c.a)
        }
        for j in d.layers.indices {
            switch d.layers[j].content {
            case .text(var t):
                t.color = map(t.color)
                t.gradientTo = t.gradientTo.map(map)
                t.glowColor = t.glowColor.map(map)
                d.layers[j].content = .text(t)
            case .fill(var f):
                f.colors = f.colors.map(map)
                d.layers[j].content = .fill(f)
            case .shape(var s):
                s.fill = s.fill.map(map)
                s.stroke = s.stroke.map(map)
                d.layers[j].content = .shape(s)
            case .image:
                break
            }
        }
        d.palette = p.colors
        d.background = p.dark
    }

    /// Flips the composition top to bottom: the title moves to the other golden band.
    static func mirror(_ d: inout CoverDocument) {
        for j in d.layers.indices {
            var f = d.layers[j].frame
            guard f.h < 0.98 else { continue }
            f.y = 1 - f.maxY
            d.layers[j].frame = f
            if var fill = d.layers[j].fillContent, fill.style == .scrim {
                fill.angle = fill.angle == 90 ? 270 : (fill.angle == 270 ? 90 : fill.angle)
                d.layers[j].fillContent = fill
            }
            if d.layers[j].fade == .bottom { d.layers[j].fade = .top } else if d.layers[j].fade == .top { d.layers[j].fade = .bottom }
        }
        // A title that was behind the subject can't stay there once it moves.
        for j in d.layers.indices where d.layers[j].textContent?.behindSubject == true {
            d.layers[j].textContent?.behindSubject = false
        }
    }
}
