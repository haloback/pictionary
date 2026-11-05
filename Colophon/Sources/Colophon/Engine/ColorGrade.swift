import CoreGraphics
import Foundation

/// Nudges a photo toward the cover's palette with a color-blend fill clipped to it.
enum Harmonizer {
    /// Hue distance on the wheel, 0...180.
    static func hueDistance(_ a: RGBA, _ b: RGBA) -> Double {
        var d = abs(a.hsl.h - b.hsl.h).truncatingRemainder(dividingBy: 360)
        if d > 180 { d = 360 - d }
        return d
    }

    /// A solid fill in `.color` blend, clipped to the photo, that pulls its hues toward the palette.
    /// `mean` is the photo's average color (from `ImageInsight.meanColor`); the palette color nearest
    /// to it in hue wins, so the shift reads as a grade rather than a tint. Without it, the dominant color is used.
    static func layer(for photo: Layer, palette: PaletteRoles, strength: Double, mean: RGBA? = nil) -> Layer {
        var ink = palette.dominant
        if let mean, mean.chroma > 0.02 {
            let candidates = [palette.dominant, palette.accent]
            ink = candidates.min { hueDistance($0, mean) < hueDistance($1, mean) } ?? palette.dominant
        }
        // A fully desaturated ink would drain the photo; keep some color in it.
        let h = ink.hsl
        ink = RGBA(h: h.h, s: max(0.3, h.s), l: h.l.clamped(0.3, 0.7))
        var l = Layer.fill(.solid, colors: [ink], frame: photo.frame)
        l.name = "Harmony"
        l.blend = .color
        l.opacity = (0.18 + 0.35 * strength.clamped01).clamped01
        l.clipToBelow = true
        return l
    }
}

/// An art-directed set of adjustments that reads as one film stock or grade.
struct ColorGradePreset: Identifiable {
    let id: String
    let name: String
    let genres: [Genre]
    let adjust: Adjustments
}

/// Named grades a cover can wear, built from `Adjustments` so they stay editable afterwards.
enum ColorGrade {
    static let all: [ColorGradePreset] = build()

    static func preset(_ id: String) -> ColorGradePreset? { all.first { $0.id == id } }

    /// Grades tagged with the genre first, then the rest, so every genre has the whole shelf.
    static func suggested(for genre: Genre) -> [ColorGradePreset] {
        let tagged = all.filter { $0.genres.contains(genre) }
        let rest = all.filter { !$0.genres.contains(genre) }
        return tagged + rest
    }

    private static func make(_ name: String, _ genres: [Genre], _ tune: (inout Adjustments) -> Void) -> ColorGradePreset {
        var a = Adjustments()
        tune(&a)
        return ColorGradePreset(id: "grade." + EffectLibrary.slug(name), name: name, genres: genres, adjust: a)
    }

    private static func build() -> [ColorGradePreset] {
        var list: [ColorGradePreset] = []

        list.append(make("Teal & Orange Cinematic", [.thriller, .scienceFiction, .mystery]) { a in
            a.contrast = 0.25; a.saturation = 0.1; a.vibrance = 0.2
            a.shadowTint = RGBA(hex: "0E5E6F"); a.highlightTint = RGBA(hex: "F2A541"); a.tintAmount = 0.55
            a.vignette = 0.25
        })
        list.append(make("Bleach Bypass", [.thriller, .mystery, .horror]) { a in
            a.contrast = 0.55; a.saturation = -0.55; a.gain = 0.15; a.lift = -0.1
            a.grain = 0.3; a.vignette = 0.2
        })
        list.append(make("Kodachrome", [.historical, .memoir, .literary]) { a in
            a.contrast = 0.3; a.saturation = 0.2; a.warmth = 0.25; a.vibrance = 0.15
            a.shadowTint = RGBA(hex: "1B2A4A"); a.highlightTint = RGBA(hex: "F3E9D2"); a.tintAmount = 0.35
            a.grain = 0.15
        })
        list.append(make("Faded Matte", [.literary, .memoir, .romance, .youngAdult]) { a in
            a.fade = 0.6; a.contrast = -0.15; a.saturation = -0.2; a.warmth = 0.1
            a.highlightTint = RGBA(hex: "F3E9D2"); a.tintAmount = 0.3; a.grain = 0.2
        })
        list.append(make("Noir Silver", [.mystery, .thriller, .literary]) { a in
            a.saturation = -1; a.contrast = 0.45; a.lift = -0.15; a.gain = 0.1
            a.grain = 0.35; a.vignette = 0.45
        })
        list.append(make("Golden Hour", [.romance, .cozy, .memoir, .youngAdult]) { a in
            a.warmth = 0.5; a.exposure = 0.1; a.gamma = 0.1; a.vibrance = 0.2
            a.shadowTint = RGBA(hex: "7A2E12"); a.highlightTint = RGBA(hex: "F2A541"); a.tintAmount = 0.45
            a.fade = 0.15
        })
        list.append(make("Nordic Cold", [.mystery, .thriller, .literary, .scienceFiction]) { a in
            a.warmth = -0.45; a.saturation = -0.3; a.contrast = 0.15; a.gamma = 0.05
            a.shadowTint = RGBA(hex: "1B2A4A"); a.highlightTint = RGBA(hex: "D6EAF8"); a.tintAmount = 0.4
        })
        list.append(make("Cross-Process", [.youngAdult, .scienceFiction, .fantasy]) { a in
            a.contrast = 0.4; a.saturation = 0.35; a.vibrance = 0.3
            a.shadowTint = RGBA(hex: "1E4D2B"); a.highlightTint = RGBA(hex: "F2E863"); a.tintAmount = 0.6
            a.lift = 0.1
        })
        list.append(make("Sepia Archive", [.historical, .memoir, .nonfiction]) { a in
            a.saturation = -0.85; a.warmth = 0.45; a.contrast = 0.1; a.fade = 0.3
            a.shadowTint = RGBA(hex: "4A2C17"); a.highlightTint = RGBA(hex: "F3E9D2"); a.tintAmount = 0.6
            a.grain = 0.3; a.vignette = 0.35
        })
        list.append(make("Velvet Night", [.romance, .fantasy, .horror]) { a in
            a.exposure = -0.25; a.contrast = 0.3; a.saturation = 0.1; a.lift = -0.1
            a.shadowTint = RGBA(hex: "3A1F6B"); a.highlightTint = RGBA(hex: "F4C2C2"); a.tintAmount = 0.5
            a.vignette = 0.5
        })
        list.append(make("Pastel Dream", [.romance, .cozy, .youngAdult]) { a in
            a.exposure = 0.2; a.contrast = -0.3; a.saturation = -0.15; a.fade = 0.5; a.gamma = 0.15
            a.shadowTint = RGBA(hex: "B39DDB"); a.highlightTint = RGBA(hex: "FFB38A"); a.tintAmount = 0.35
        })
        list.append(make("Moody Forest", [.fantasy, .mystery, .literary, .horror]) { a in
            a.exposure = -0.15; a.contrast = 0.25; a.saturation = -0.2; a.warmth = -0.1
            a.shadowTint = RGBA(hex: "1E3D2F"); a.highlightTint = RGBA(hex: "A3B18A"); a.tintAmount = 0.5
            a.vignette = 0.4; a.fade = 0.1
        })
        list.append(make("Desert Dust", [.historical, .literary, .thriller]) { a in
            a.warmth = 0.35; a.saturation = -0.25; a.contrast = 0.1; a.gain = 0.1; a.fade = 0.2
            a.shadowTint = RGBA(hex: "6B4A1C"); a.highlightTint = RGBA(hex: "D8C3A5"); a.tintAmount = 0.45
            a.grain = 0.25
        })
        list.append(make("Neon Night", [.scienceFiction, .thriller, .youngAdult]) { a in
            a.contrast = 0.45; a.saturation = 0.4; a.vibrance = 0.4; a.lift = -0.15
            a.shadowTint = RGBA(hex: "2A2F6B"); a.highlightTint = RGBA(hex: "FF2E88"); a.tintAmount = 0.55
            a.vignette = 0.35
        })
        list.append(make("Ivory Fade", [.literary, .nonfiction, .memoir, .cozy]) { a in
            a.exposure = 0.15; a.contrast = -0.1; a.saturation = -0.35; a.fade = 0.45; a.warmth = 0.15
            a.highlightTint = RGBA(hex: "F4F1E8"); a.tintAmount = 0.4
        })
        list.append(make("Technicolor", [.fantasy, .youngAdult, .cozy, .historical]) { a in
            a.contrast = 0.35; a.saturation = 0.5; a.vibrance = 0.3; a.gain = 0.05
            a.shadowTint = RGBA(hex: "0F2E4C"); a.highlightTint = RGBA(hex: "F4C430"); a.tintAmount = 0.3
        })
        list.append(make("Gothic Crimson", [.horror, .fantasy, .romance]) { a in
            a.exposure = -0.2; a.contrast = 0.4; a.saturation = -0.1; a.lift = -0.15
            a.shadowTint = RGBA(hex: "4A0E17"); a.highlightTint = RGBA(hex: "D7263D"); a.tintAmount = 0.55
            a.vignette = 0.6; a.grain = 0.2
        })
        list.append(make("Icy Blue", [.scienceFiction, .thriller, .mystery, .fantasy]) { a in
            a.warmth = -0.55; a.contrast = 0.2; a.saturation = -0.15; a.gain = 0.1
            a.shadowTint = RGBA(hex: "0B6E8A"); a.highlightTint = RGBA(hex: "D6EAF8"); a.tintAmount = 0.5
        })
        list.append(make("Rose Film", [.romance, .cozy, .youngAdult, .memoir]) { a in
            a.warmth = 0.2; a.contrast = -0.05; a.saturation = -0.1; a.fade = 0.3; a.gamma = 0.08
            a.shadowTint = RGBA(hex: "5B1A2E"); a.highlightTint = RGBA(hex: "F28AB2"); a.tintAmount = 0.45
            a.grain = 0.15
        })
        list.append(make("Smoke & Ash", [.thriller, .horror, .mystery, .literary]) { a in
            a.saturation = -0.7; a.contrast = 0.2; a.fade = 0.35; a.warmth = -0.1
            a.shadowTint = RGBA(hex: "2F3E4E"); a.highlightTint = RGBA(hex: "BFC5CC"); a.tintAmount = 0.5
            a.grain = 0.4; a.vignette = 0.3
        })
        list.append(make("Paper Print", [.nonfiction, .literary, .historical]) { a in
            a.saturation = -0.4; a.contrast = 0.3; a.exposure = 0.1; a.fade = 0.25; a.warmth = 0.1
            a.highlightTint = RGBA(hex: "EDE6D6"); a.tintAmount = 0.5; a.grain = 0.45
        })
        list.append(make("Hard Mono", [.nonfiction, .thriller, .literary, .memoir]) { a in
            a.saturation = -1; a.contrast = 0.7; a.lift = -0.25; a.gain = 0.15; a.sharpness = 0.3
        })
        list.append(make("Summer Haze", [.romance, .cozy, .youngAdult]) { a in
            a.exposure = 0.2; a.contrast = -0.25; a.warmth = 0.3; a.fade = 0.4; a.vibrance = 0.15
            a.highlightTint = RGBA(hex: "FFB38A"); a.tintAmount = 0.4; a.sharpness = -0.1
        })
        list.append(make("Deep Space", [.scienceFiction, .fantasy, .thriller]) { a in
            a.exposure = -0.3; a.contrast = 0.5; a.saturation = 0.15; a.lift = -0.2; a.warmth = -0.2
            a.shadowTint = RGBA(hex: "0B1D3A"); a.highlightTint = RGBA(hex: "7B83EB"); a.tintAmount = 0.5
            a.vignette = 0.55
        })
        list.append(make("Emerald Ink", [.fantasy, .mystery, .literary]) { a in
            a.contrast = 0.3; a.saturation = -0.2; a.lift = -0.05
            a.shadowTint = RGBA(hex: "0B4A33"); a.highlightTint = RGBA(hex: "7FD8BE"); a.tintAmount = 0.5
            a.vignette = 0.3
        })
        list.append(make("Amber Lamp", [.cozy, .historical, .romance, .memoir]) { a in
            a.exposure = -0.1; a.warmth = 0.4; a.contrast = 0.2; a.gamma = -0.05
            a.shadowTint = RGBA(hex: "2E1C12"); a.highlightTint = RGBA(hex: "F2A541"); a.tintAmount = 0.55
            a.vignette = 0.5; a.grain = 0.15
        })
        list.append(make("Cobalt Dusk", [.scienceFiction, .mystery, .youngAdult]) { a in
            a.contrast = 0.25; a.saturation = 0.05; a.warmth = -0.15
            a.shadowTint = RGBA(hex: "1B3B8A"); a.highlightTint = RGBA(hex: "FF6F59"); a.tintAmount = 0.5
            a.fade = 0.1
        })
        list.append(make("Bone White", [.horror, .literary, .nonfiction]) { a in
            a.exposure = 0.25; a.contrast = 0.35; a.saturation = -0.6; a.gain = 0.1; a.fade = 0.15
            a.highlightTint = RGBA(hex: "EDE6D6"); a.tintAmount = 0.4; a.grain = 0.3; a.vignette = 0.2
        })

        return list
    }
}
