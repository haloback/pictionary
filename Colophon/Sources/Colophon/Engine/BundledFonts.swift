import AppKit
import CoreText

/// Display faces bundled with Colophon (SIL Open Font License or Apache 2.0; licenses in Fonts/licenses).
enum BundledFonts {
    static let entries: [FontCatalog.Entry] = [
        FontCatalog.Entry(id: "Cinzel-Regular", label: "Cinzel Regular", mood: .fantasy),
        FontCatalog.Entry(id: "Cinzel-Bold", label: "Cinzel Bold", mood: .fantasy),
        FontCatalog.Entry(id: "CinzelDecorative-Bold", label: "Cinzel Decorative Bold", mood: .fantasy),
        FontCatalog.Entry(id: "CinzelDecorative-Black", label: "Cinzel Decorative Black", mood: .fantasy),
        FontCatalog.Entry(id: "UncialAntiqua-Regular", label: "Uncial Antiqua", mood: .fantasy),
        FontCatalog.Entry(id: "MedievalSharp", label: "MedievalSharp", mood: .fantasy),
        FontCatalog.Entry(id: "PirataOne-Regular", label: "Pirata One", mood: .fantasy),
        FontCatalog.Entry(id: "UnifrakturMaguntia", label: "UnifrakturMaguntia", mood: .fantasy),
        FontCatalog.Entry(id: "IM_FELL_English_SC", label: "IM FELL English SC", mood: .fantasy),
        FontCatalog.Entry(id: "MarcellusSC-Regular", label: "Marcellus SC", mood: .fantasy),
        FontCatalog.Entry(id: "PlayfairDisplay-BoldItalic", label: "Playfair Display Bold Italic", mood: .didone),
        FontCatalog.Entry(id: "PlayfairDisplay-Bold", label: "Playfair Display Bold", mood: .didone),
        FontCatalog.Entry(id: "PlayfairDisplay-Black", label: "Playfair Display Black", mood: .didone),
        FontCatalog.Entry(id: "BodoniModa-Bold", label: "Bodoni Moda Bold", mood: .didone),
        FontCatalog.Entry(id: "BodoniModa-Black", label: "Bodoni Moda Black", mood: .didone),
        FontCatalog.Entry(id: "AbrilFatface-Regular", label: "Abril Fatface", mood: .didone),
        FontCatalog.Entry(id: "DMSerifDisplay-Italic", label: "DM Serif Display Italic", mood: .didone),
        FontCatalog.Entry(id: "DMSerifDisplay-Regular", label: "DM Serif Display Regular", mood: .didone),
        FontCatalog.Entry(id: "YesevaOne-Regular", label: "Yeseva One Regular", mood: .didone),
        FontCatalog.Entry(id: "RozhaOne-Regular", label: "Rozha One Regular", mood: .didone),
        FontCatalog.Entry(id: "Prata-Regular", label: "Prata Regular", mood: .didone),
        FontCatalog.Entry(id: "LibreCaslonDisplay-Regular", label: "Libre Caslon Display Regular", mood: .didone),
        FontCatalog.Entry(id: "CormorantGaramond-MediumItalic", label: "Cormorant Garamond Medium Italic", mood: .didone),
        FontCatalog.Entry(id: "CormorantGaramond-SemiBold", label: "Cormorant Garamond SemiBold", mood: .didone),
        FontCatalog.Entry(id: "CormorantGaramond-Bold", label: "Cormorant Garamond Bold", mood: .didone),
        FontCatalog.Entry(id: "Fraunces-Black", label: "Fraunces Black", mood: .didone),
        FontCatalog.Entry(id: "BebasNeue-Regular", label: "Bebas Neue Regular", mood: .condensed),
        FontCatalog.Entry(id: "Anton-Regular", label: "Anton Regular", mood: .condensed),
        FontCatalog.Entry(id: "LeagueGothic-Regular", label: "League Gothic Regular", mood: .condensed),
        FontCatalog.Entry(id: "Oswald-Bold", label: "Oswald Bold", mood: .condensed),
        FontCatalog.Entry(id: "BigShouldersDisplay-Black", label: "Big Shoulders Display Black", mood: .condensed),
        FontCatalog.Entry(id: "SixCaps", label: "Six Caps", mood: .condensed),
        FontCatalog.Entry(id: "Antonio-Bold", label: "Antonio Bold", mood: .condensed),
        FontCatalog.Entry(id: "Teko-SemiBold", label: "Teko SemiBold", mood: .condensed),
        FontCatalog.Entry(id: "ArchivoBlack-Regular", label: "Archivo Black Regular", mood: .condensed),
        FontCatalog.Entry(id: "Montserrat-Black", label: "Montserrat Black", mood: .sans),
        FontCatalog.Entry(id: "JosefinSans-Light", label: "Josefin Sans Light", mood: .sans),
        FontCatalog.Entry(id: "JosefinSans-Bold", label: "Josefin Sans Bold", mood: .sans),
        FontCatalog.Entry(id: "Syne-ExtraBold", label: "Syne ExtraBold", mood: .sans),
        FontCatalog.Entry(id: "Unbounded-ExtraBold", label: "Unbounded ExtraBold", mood: .sans),
        FontCatalog.Entry(id: "PoiretOne-Regular", label: "Poiret One", mood: .deco),
        FontCatalog.Entry(id: "Limelight-Regular", label: "Limelight Regular", mood: .deco),
        FontCatalog.Entry(id: "Monoton-Regular", label: "Monoton", mood: .deco),
        FontCatalog.Entry(id: "Bungee-Regular", label: "Bungee Regular", mood: .deco),
        FontCatalog.Entry(id: "BungeeShade-Regular", label: "Bungee Shade Regular", mood: .deco),
        FontCatalog.Entry(id: "BungeeInline-Regular", label: "Bungee Inline Regular", mood: .deco),
        FontCatalog.Entry(id: "Righteous-Regular", label: "Righteous", mood: .deco),
        FontCatalog.Entry(id: "Rye-Regular", label: "Rye Regular", mood: .deco),
        FontCatalog.Entry(id: "Orbitron-Black", label: "Orbitron Black", mood: .scifi),
        FontCatalog.Entry(id: "Audiowide-Regular", label: "Audiowide Regular", mood: .scifi),
        FontCatalog.Entry(id: "Michroma-Regular", label: "Michroma Regular", mood: .scifi),
        FontCatalog.Entry(id: "Syncopate-Bold", label: "Syncopate Bold", mood: .scifi),
        FontCatalog.Entry(id: "Exo2-ExtraBold", label: "Exo 2 ExtraBold", mood: .scifi),
        FontCatalog.Entry(id: "Creepster-Regular", label: "Creepster", mood: .horror),
        FontCatalog.Entry(id: "Nosifer-Regular", label: "Nosifer", mood: .horror),
        FontCatalog.Entry(id: "Butcherman-Regular", label: "Butcherman Regular", mood: .horror),
        FontCatalog.Entry(id: "MetalMania-Regular", label: "Metal Mania", mood: .horror),
        FontCatalog.Entry(id: "SpecialElite-Regular", label: "Special Elite Regular", mood: .horror),
        FontCatalog.Entry(id: "GreatVibes-Regular", label: "Great Vibes Regular", mood: .script),
        FontCatalog.Entry(id: "PinyonScript-Regular", label: "Pinyon Script Regular", mood: .script),
        FontCatalog.Entry(id: "Parisienne-Regular", label: "Parisienne", mood: .script),
        FontCatalog.Entry(id: "AlexBrush-Regular", label: "Alex Brush Regular", mood: .script),
        FontCatalog.Entry(id: "Sacramento-Regular", label: "Sacramento", mood: .script),
        FontCatalog.Entry(id: "Allura-Regular", label: "Allura Regular", mood: .script),
        FontCatalog.Entry(id: "MrsSaintDelafield-Regular", label: "Mrs Saint Delafield", mood: .script),
        FontCatalog.Entry(id: "PermanentMarker-Regular", label: "Permanent Marker Regular", mood: .brush),
        FontCatalog.Entry(id: "RockSalt-Regular", label: "Rock Salt Regular", mood: .brush),
        FontCatalog.Entry(id: "CaveatBrush-Regular", label: "Caveat Brush", mood: .brush),
        FontCatalog.Entry(id: "KaushanScript-Regular", label: "Kaushan Script", mood: .brush),
    ]

    /// Registers the bundled faces once, from the app's Resources or, during development, the package folder.
    static let registered: Bool = {
        for url in fontFiles() {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    private static func fontFiles() -> [URL] {
        var dirs: [URL] = []
        if let r = Bundle.main.resourceURL { dirs.append(r.appendingPathComponent("Fonts")) }
        // Sources/Colophon/Engine/BundledFonts.swift -> package root -> Fonts
        let source = URL(fileURLWithPath: #filePath)
        dirs.append(source.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fonts"))
        for dir in dirs {
            guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            let fonts = items.filter { ["ttf", "otf"].contains($0.pathExtension.lowercased()) }
            if !fonts.isEmpty { return fonts }
        }
        return []
    }
}
