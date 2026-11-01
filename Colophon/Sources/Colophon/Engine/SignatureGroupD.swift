import Foundation

// MARK: - Group D: fantasy, science fiction, historical

extension SignatureLibrary {
    static var groupD: [SignatureDesign] {
        var out: [SignatureDesign] = []
        var e: [SigElement] = []

        // MARK: Fantasy

        // F1 Sword in the Ring: one gold emblem on a dark glow, a monumental inscribed title.
        e = []
        e.append(.fill(.radial(.muted, .bg), .full))
        e.append(.text(.series, NRect(0.1, 0.045, 0.8, 0.02), SigType(["Cinzel-Regular"], color: .accent, tracking: 0.4)))
        e.append(.shape(.ring, NRect(0.21, 0.16, 0.58, 0.3625), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.493, 0.1, 0.014, 0.52), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.39, 0.215, 0.22, 0.009), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.diamond, NRect(0.479, 0.083, 0.042, 0.026), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.493, 0.62, 0.014, 0.035), .accent, stroke: 0, rotation: 180))
        e.append(.text(.title, NRect(0.07, 0.7, 0.86, 0.15), SigType(["Cinzel-Bold"], tracking: 0.06, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.2, 0.9, 0.6, 0.03), SigType(["Cinzel-Regular"], color: .accent, tracking: 0.3)))
        out.append(SignatureDesign(id: "fantasy-sword-in-the-ring", name: "Sword in the Ring", genre: .fantasy,
                                   idea: "A single gold emblem, a blade driven through a ring, glows in the dark like a sigil stamped on a war banner.",
                                   tags: ["graphic", "dark", "epic", "emblem", "serif", "minimal"], elements: e,
                                   palettes: [SigPalette("Midnight & Gilt", bg: "0B1426", ink: "F3E9D2", accent: "D4AF5A", muted: "26385E", paper: "F3E9D2"),
                                              SigPalette("Oxblood & Brass", bg: "22080B", ink: "F1E4CC", accent: "C99A4B", muted: "5A1C22", paper: "F1E4CC"),
                                              SigPalette("Forest & Silver", bg: "0C1A15", ink: "EEF0EC", accent: "C3CCCA", muted: "24453B", paper: "EEF0EC")],
                                   sample: SigSample(title: "The Iron Covenant", author: "Corin Vael", series: "THE ASHEN THRONE · BOOK ONE")))

        // F2 Atlas Plate: a vellum title band over the painted land, like a plate in an old atlas.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.photo(NRect(0, 0.42, 1, 0.58), clip: nil, look: .natural, focusY: 0.5, zoom: 1, index: 0, fallback: .watercolor([.accent, .muted, .ink])))
        e.append(.shape(.rule, NRect(0, 0.418, 1, 0.004), .ink, stroke: 0, rotation: 0))
        e.append(.text(.seriesOr("BOOK ONE"), NRect(0.08, 0.05, 0.84, 0.018), SigType(["Montserrat-Black"], color: .accent, tracking: 0.4)))
        e.append(.text(.title, NRect(0.07, 0.09, 0.86, 0.2), SigType(["CormorantGaramond-Bold"], tracking: 0.06, lineHeight: 0.88, breaks: .lines(2))))
        e.append(.decor("tapered diamond", .divider, NRect(0.3, 0.305, 0.4, 0.03), .accent))
        e.append(.text(.author, NRect(0.15, 0.352, 0.7, 0.03), SigType(["CormorantGaramond-SemiBold"], tracking: 0.25)))
        out.append(SignatureDesign(id: "fantasy-atlas-plate", name: "Atlas Plate", genre: .fantasy,
                                   idea: "A vellum band sits over the painted land like the title plate of an old atlas, split from the world by one hard line.",
                                   tags: ["photo", "light", "epic", "serif", "classic", "elegant"], elements: e,
                                   palettes: [SigPalette("Vellum & Lapis", bg: "EFE6D2", ink: "1C2340", accent: "9A3B22", muted: "7B7563", paper: "F8F2E4"),
                                              SigPalette("Slate & Ember", bg: "1B1E24", ink: "EDE3CF", accent: "D9822B", muted: "6B6E73", paper: "EDE3CF"),
                                              SigPalette("Bone & Moss", bg: "E6E2D3", ink: "1F2E22", accent: "7A5A1E", muted: "7F8670", paper: "F3F0E6")],
                                   sample: SigSample(title: "Kingdom of Low Tides", author: "Aurelie Strand", series: "THE TIDEBORN · BOOK ONE", photo: "landscape")))

        // F3 The Gate: the painting seen through a stone arch, outlined in gold.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.series, NRect(0.1, 0.045, 0.8, 0.02), SigType(["Cinzel-Regular"], color: .accent, tracking: 0.35)))
        e.append(.photo(NRect(0.16, 0.12, 0.68, 0.5), clip: .arch, look: .natural, focusY: 0.45, zoom: 1.1, index: 0, fallback: .watercolor([.accent, .muted, .bg])))
        e.append(.shape(.arch, NRect(0.14, 0.107, 0.72, 0.526), .accent, stroke: 0.004, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.665, 0.86, 0.16), SigType(["CinzelDecorative-Bold"], tracking: 0.03, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.decor("tapered star", .divider, NRect(0.35, 0.835, 0.3, 0.025), .accent))
        e.append(.text(.author, NRect(0.15, 0.88, 0.7, 0.035), SigType(["Cinzel-Bold"], color: .accent, tracking: 0.3)))
        out.append(SignatureDesign(id: "fantasy-the-gate", name: "The Gate", genre: .fantasy,
                                   idea: "The world is glimpsed through a single gold-lined arch, a doorway the reader is invited to step through.",
                                   tags: ["photo", "dark", "epic", "serif", "arch", "atmospheric"], elements: e,
                                   palettes: [SigPalette("Basalt & Gold", bg: "17191C", ink: "EFE6D3", accent: "C9A24D", muted: "3A3D42", paper: "EFE6D3"),
                                              SigPalette("Lapis Night", bg: "0F1A33", ink: "F0E8D6", accent: "D7B567", muted: "2C3B5E", paper: "F0E8D6"),
                                              SigPalette("Ivory & Oxide", bg: "EEE6D6", ink: "1C1A17", accent: "8C3A1E", muted: "A39A88", paper: "F7F2E8")],
                                   sample: SigSample(title: "The Last Lantern of Ostmere", author: "Bram Halloway", series: "THE LANTERN CYCLE · I", photo: "landscape")))

        // F4 Hand Mirror: a fairytale portrait inside an oval glass with a slim handle.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.title, NRect(0.08, 0.05, 0.84, 0.17), SigType(["DMSerifDisplay-Italic"], letterCase: .title, lineHeight: 0.9, breaks: .lines(2))))
        e.append(.shape(.ellipse, NRect(0.2, 0.257, 0.6, 0.416), .accent, stroke: 0.006, rotation: 0))
        e.append(.photo(NRect(0.225, 0.274, 0.55, 0.382), clip: .ellipse, look: .faded, focusY: 0.3, zoom: 1.15, index: 0, fallback: .watercolor([.accent, .muted])))
        e.append(.shape(.diamond, NRect(0.47, 0.672, 0.06, 0.03), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.roundedRect, NRect(0.484, 0.7, 0.032, 0.15), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.15, 0.895, 0.7, 0.03), SigType(["JosefinSans-Bold"], tracking: 0.3)))
        out.append(SignatureDesign(id: "fantasy-hand-mirror", name: "Hand Mirror", genre: .fantasy,
                                   idea: "The heroine looks out of an enchanted hand mirror, the whole cover drawn as a single object on a pale ground.",
                                   tags: ["photo", "light", "fairytale", "romantic", "elegant", "italic"], elements: e,
                                   palettes: [SigPalette("Cream & Garnet", bg: "F3ECDF", ink: "2A1A1F", accent: "8E2F3A", muted: "C9A9A4", paper: "FBF7F0"),
                                              SigPalette("Frost & Silver", bg: "E6EBEE", ink: "1C2633", accent: "6F7F92", muted: "B7C3CE", paper: "F5F8FA"),
                                              SigPalette("Night Glass", bg: "171420", ink: "EFE6DA", accent: "C7A15A", muted: "4A3F5C", paper: "EFE6DA")],
                                   sample: SigSample(title: "The Salt Bride", author: "Wren Achterberg", photo: "portrait")))

        // F5 Cut-Paper Wood: a fairytale forest of paper triangles under a red moon.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.subtitleOr("A FAIRY TALE"), NRect(0.25, 0.07, 0.5, 0.018), SigType(["JosefinSans-Bold"], color: .accent, tracking: 0.4)))
        e.append(.text(.title, NRect(0.07, 0.11, 0.86, 0.13), SigType(["Fraunces-Black"], letterCase: .title, tracking: -0.02, breaks: .oneLine)))
        e.append(.shape(.ellipse, NRect(0.58, 0.31, 0.26, 0.1625), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.0, 0.56, 0.22, 0.3), .muted, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.3, 0.49, 0.24, 0.37), .muted, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.62, 0.58, 0.2, 0.28), .muted, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.8, 0.52, 0.2, 0.34), .muted, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.0, 0.64, 0.18, 0.22), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.14, 0.58, 0.22, 0.28), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.42, 0.61, 0.2, 0.25), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.58, 0.54, 0.26, 0.32), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.84, 0.65, 0.16, 0.21), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0, 0.855, 1, 0.145), .ink, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.15, 0.905, 0.7, 0.03), SigType(["JosefinSans-Bold"], color: .paper, tracking: 0.3)))
        out.append(SignatureDesign(id: "fantasy-cut-paper-wood", name: "Cut-Paper Wood", genre: .fantasy,
                                   idea: "A fairytale forest cut from two layers of paper triangles, with one red moon caught in the branches.",
                                   tags: ["graphic", "light", "fairytale", "playful", "folk", "modern"], elements: e,
                                   palettes: [SigPalette("Cream & Pine", bg: "F2E8D8", ink: "1E3A2F", accent: "C8462F", muted: "7E9A83", paper: "F2E8D8"),
                                              SigPalette("Snow & Ink", bg: "EDEFF2", ink: "1B1F2A", accent: "B3242F", muted: "939CAE", paper: "EDEFF2"),
                                              SigPalette("Dusk Rose", bg: "F3DDD3", ink: "3A1E2C", accent: "D9862F", muted: "A8708A", paper: "F7E9E2")],
                                   sample: SigSample(title: "Thornwood", author: "Ottilie Marsh")))

        // F6 Library Binding: a cloth case, a small gilt key, title stamped in gold.
        e = []
        e.append(.fill(.material("mat.linen.palette.b"), .full))
        e.append(.decor("thin-thick-thin fine", .border, .full, .accent))
        e.append(.text(.title, NRect(0.13, 0.15, 0.74, 0.2), SigType(["MarcellusSC-Regular"], tracking: 0.08, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.3, 0.38, 0.4, 0.018), SigType(["MarcellusSC-Regular"], color: .accent, tracking: 0.4)))
        e.append(.shape(.ellipse, NRect(0.44, 0.47, 0.12, 0.075), .accent, stroke: 0.006, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.494, 0.543, 0.012, 0.16), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.506, 0.66, 0.04, 0.012), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.506, 0.684, 0.028, 0.012), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.15, 0.83, 0.7, 0.032), SigType(["MarcellusSC-Regular"], color: .accent, tracking: 0.25)))
        out.append(SignatureDesign(id: "fantasy-library-binding", name: "Library Binding", genre: .fantasy,
                                   idea: "A cloth-bound book with a tiny gilt key at its center: the smallest object promising the largest secret.",
                                   tags: ["graphic", "dark", "literary", "elegant", "vintage", "minimal"], elements: e,
                                   palettes: [SigPalette("Bottle Green & Gilt", bg: "1D3B2F", ink: "E2C27A", accent: "D8B76A", muted: "12261E", paper: "EFE3C4"),
                                              SigPalette("Oxblood Cloth", bg: "561A1F", ink: "EBCF8E", accent: "E1C27A", muted: "34100F", paper: "F1E4C8"),
                                              SigPalette("Navy Buckram", bg: "18243D", ink: "E6CF96", accent: "D9C08A", muted: "0E1626", paper: "EEE4CC")],
                                   sample: SigSample(title: "The Archive of Unwritten Doors", author: "Leopold Fenn")))

        // F7 The Slit: the portrait cropped to a narrow band across the eyes.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.tagline, NRect(0.1, 0.06, 0.8, 0.02), SigType(["Montserrat-Black"], color: .accent, tracking: 0.35)))
        e.append(.shape(.rule, NRect(0, 0.155, 1, 0.005), .accent, stroke: 0, rotation: 0))
        e.append(.photo(NRect(0, 0.16, 1, 0.15), clip: nil, look: .duotone(.bg, .accent), focusY: 0.3, zoom: 1.6, index: 0, fallback: .material("mat.smoke.palette.b")))
        e.append(.shape(.rule, NRect(0, 0.31, 1, 0.005), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.4, 0.86, 0.3), SigType(["BodoniModa-Black"], lineHeight: 0.88, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.12, 0.87, 0.76, 0.04), SigType(["BodoniModa-Bold"], tracking: 0.2)))
        out.append(SignatureDesign(id: "fantasy-the-slit", name: "The Slit", genre: .fantasy,
                                   idea: "Only the eyes survive: the portrait is cut to a blood-washed slit across a black cover.",
                                   tags: ["photo", "dark", "grimdark", "moody", "serif", "bold type"], elements: e,
                                   palettes: [SigPalette("Bone & Blood", bg: "0A0A0A", ink: "EDE6DA", accent: "B3121B", muted: "6E6A64", paper: "EDE6DA"),
                                              SigPalette("Ash & Violet", bg: "121016", ink: "E8E2EE", accent: "7A3FC2", muted: "5E5868", paper: "E8E2EE"),
                                              SigPalette("Soot & Gold", bg: "0D0C0A", ink: "F0E6D0", accent: "C9A13F", muted: "6A6250", paper: "F0E6D0")],
                                   sample: SigSample(title: "Crown of Teeth", author: "Silas Morrow", tagline: "Every queen is fed", photo: "portrait")))

        // F8 Blood Diamond: a blackletter title knocked into a red lozenge on a charred ground.
        e = []
        e.append(.fill(.material("mat.grunge.palette.b"), .full))
        e.append(.text(.seriesOr("BOOK ONE"), NRect(0.2, 0.06, 0.6, 0.02), SigType(["Cinzel-Bold"], tracking: 0.4)))
        e.append(.shape(.diamond, NRect(0.06, 0.17, 0.88, 0.56), .accent, stroke: 0.003, rotation: 0))
        e.append(.shape(.diamond, NRect(0.1, 0.195, 0.8, 0.51), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.19, 0.385, 0.62, 0.13), SigType(["PirataOne-Regular"], color: .paper, letterCase: .title, breaks: .oneLine)))
        e.append(.text(.author, NRect(0.15, 0.85, 0.7, 0.04), SigType(["Cinzel-Bold"], tracking: 0.2)))
        out.append(SignatureDesign(id: "fantasy-blood-diamond", name: "Blood Diamond", genre: .fantasy,
                                   idea: "A blackletter title sealed inside a red lozenge, like a warning painted on a plague door.",
                                   tags: ["graphic", "dark", "grimdark", "blackletter", "bold type", "gothic"], elements: e,
                                   palettes: [SigPalette("Char & Crimson", bg: "140F0F", ink: "E9DFD0", accent: "8E1420", muted: "3A2A28", paper: "F1E8DA"),
                                              SigPalette("Moss & Bone", bg: "0F1410", ink: "E6DCC4", accent: "2F4A2C", muted: "28302A", paper: "EDE4CE"),
                                              SigPalette("Midnight Ink", bg: "0E1116", ink: "E3E6EA", accent: "1E3B5C", muted: "262C35", paper: "EEF0F2")],
                                   sample: SigSample(title: "Wormwood", author: "Isolde Graff", series: "THE HEXEN ROAD · BOOK ONE")))

        // F9 Eclipse: a black sun with a thin corona over a tinted landscape.
        e = []
        e.append(.photo(.full, clip: nil, look: .duotone(.bg, .muted), focusY: 0.6, zoom: 1, index: 0, fallback: .material("mat.clouds.palette.b")))
        e.append(.scrim(NRect(0, 0.5, 1, 0.5), .bg, angle: 90, strength: 0.9))
        e.append(.shape(.ellipse, NRect(0.235, 0.13, 0.53, 0.33125), .accent, stroke: 0.004, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.25, 0.14, 0.5, 0.3125), .bg, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.6, 0.86, 0.2), SigType(["CormorantGaramond-Bold"], tracking: 0.12, lineHeight: 0.9, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.15, 0.89, 0.7, 0.028), SigType(["Montserrat-Black"], color: .accent, tracking: 0.35)))
        out.append(SignatureDesign(id: "fantasy-eclipse", name: "Eclipse", genre: .fantasy,
                                   idea: "A black sun ringed by a hairline corona hangs over a darkened land; nothing else is needed.",
                                   tags: ["photo", "dark", "moody", "atmospheric", "serif", "minimal"], elements: e,
                                   palettes: [SigPalette("Eclipse Gold", bg: "07080C", ink: "F1EADB", accent: "E8C26A", muted: "4A5870", paper: "F1EADB"),
                                              SigPalette("Blood Moon", bg: "0C0506", ink: "F2E4DC", accent: "E2553A", muted: "6E3030", paper: "F2E4DC"),
                                              SigPalette("Cold Corona", bg: "050A10", ink: "EAF4F7", accent: "BFE7F0", muted: "3A6070", paper: "EAF4F7")],
                                   sample: SigSample(title: "The Ninth Dark", author: "Ansel Rook", photo: "landscape")))

        // MARK: Science fiction

        // S1 Orbital Diagram: a Swiss-style figure of concentric orbits, one red planet.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.label("FIG. 1"), NRect(0.08, 0.05, 0.2, 0.016), SigType(["Montserrat-Black"], tracking: 0.2, align: .left)))
        e.append(.shape(.ellipse, NRect(0.15, 0.00875, 0.9, 0.5625), .ink, stroke: 0.002, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.3, 0.1025, 0.6, 0.375), .ink, stroke: 0.002, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.45, 0.19625, 0.3, 0.1875), .ink, stroke: 0.002, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.56, 0.265, 0.08, 0.05), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.363, 0.407, 0.05, 0.03125), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.65, 0.86, 0.13), SigType(["Montserrat-Black"], tracking: -0.02, align: .left, breaks: .oneLine)))
        e.append(.shape(.rule, NRect(0.08, 0.8, 0.84, 0.003), .ink, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.08, 0.82, 0.55, 0.035), SigType(["Montserrat-Black"], letterCase: .title, align: .left)))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.62, 0.827, 0.3, 0.016), SigType(["Montserrat-Black"], color: .muted, tracking: 0.3, align: .right)))
        out.append(SignatureDesign(id: "scienceFiction-orbital-diagram", name: "Orbital Diagram", genre: .scienceFiction,
                                   idea: "The cover is a scientific figure: hairline orbits around a star, and one red world the story happens on.",
                                   tags: ["graphic", "light", "hard sf", "swiss", "minimal", "modern"], elements: e,
                                   palettes: [SigPalette("Lab White & Signal", bg: "F2F0EB", ink: "111111", accent: "FF4F1F", muted: "6E6E6A", paper: "F2F0EB"),
                                              SigPalette("Blueprint", bg: "13305C", ink: "EAF0F7", accent: "F2C230", muted: "9FB2CF", paper: "EAF0F7"),
                                              SigPalette("Graphite & Cyan", bg: "1A1C1F", ink: "E9ECEF", accent: "37D2E6", muted: "8A9097", paper: "E9ECEF")],
                                   sample: SigSample(title: "Perihelion", author: "Tomas Ekwueme")))

        // S2 Planet Limb: black sky above, the world's edge below; wide type floats in vacuum.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0, 0.5, 1, 0.5), clip: nil, look: .natural, focusY: 0.4, zoom: 1, index: 0, fallback: .material("mat.nebula.palette.b")))
        e.append(.scrim(NRect(0, 0.5, 1, 0.16), .bg, angle: 270, strength: 0.9))
        e.append(.text(.author, NRect(0.08, 0.06, 0.84, 0.024), SigType(["JosefinSans-Bold"], tracking: 0.5)))
        e.append(.text(.title, NRect(0.08, 0.16, 0.84, 0.18), SigType(["Syncopate-Bold"], tracking: 0.08, lineHeight: 1.05, breaks: .lines(2))))
        e.append(.text(.tagline, NRect(0.08, 0.37, 0.84, 0.02), SigType(["JosefinSans-Bold"], color: .muted, tracking: 0.3)))
        out.append(SignatureDesign(id: "scienceFiction-planet-limb", name: "Planet Limb", genre: .scienceFiction,
                                   idea: "Half the cover is pure vacuum; the other half is the curve of a world, with wide type floating in the silence between.",
                                   tags: ["photo", "dark", "hard sf", "minimal", "wide type", "atmospheric"], elements: e,
                                   palettes: [SigPalette("Vacuum", bg: "000000", ink: "F4F4F4", accent: "9FC6FF", muted: "9A9A9A", paper: "F4F4F4"),
                                              SigPalette("Mars Dawn", bg: "120806", ink: "F6E8DC", accent: "E8743A", muted: "B08C78", paper: "F6E8DC"),
                                              SigPalette("Ice Moon", bg: "050B12", ink: "EAF6FA", accent: "8FE3F0", muted: "8CA3B2", paper: "EAF6FA")],
                                   sample: SigSample(title: "The Quiet Orbit", author: "Nadia Okonjo", tagline: "Nobody answers at this distance", photo: "space")))

        // S3 Carrier Wave: rings ripple up from one point at the bottom edge, under a giant condensed title.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.shape(.ellipse, NRect(-0.5, 0.375, 2.0, 1.25), .alpha(.accent, 0.35), stroke: 0.003, rotation: 0))
        e.append(.shape(.ellipse, NRect(-0.25, 0.53125, 1.5, 0.9375), .alpha(.accent, 0.55), stroke: 0.003, rotation: 0))
        e.append(.shape(.ellipse, NRect(0, 0.6875, 1, 0.625), .alpha(.accent, 0.8), stroke: 0.003, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.25, 0.84375, 0.5, 0.3125), .accent, stroke: 0.003, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.47, 0.98, 0.06, 0.0375), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.06, 0.86, 0.36), SigType(["LeagueGothic-Regular"], lineHeight: 0.86, align: .left, breaks: .stacked)))
        e.append(.text(.author, NRect(0.07, 0.445, 0.6, 0.03), SigType(["Oswald-Bold"], tracking: 0.25, align: .left)))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.07, 0.485, 0.5, 0.017), SigType(["Oswald-Bold"], color: .muted, tracking: 0.35, align: .left)))
        out.append(SignatureDesign(id: "scienceFiction-carrier-wave", name: "Carrier Wave", genre: .scienceFiction,
                                   idea: "A single signal pulses up from the bottom edge in fading rings toward a giant condensed title.",
                                   tags: ["graphic", "dark", "hard sf", "condensed", "bold type", "modern"], elements: e,
                                   palettes: [SigPalette("Deep Field & Phosphor", bg: "0A0D10", ink: "EDEFEA", accent: "9CF06A", muted: "8A968E", paper: "EDEFEA"),
                                              SigPalette("Ink & Radar Orange", bg: "101010", ink: "F2EFEA", accent: "FF6A1A", muted: "8E8A84", paper: "F2EFEA"),
                                              SigPalette("Paper & Cobalt", bg: "EEECE6", ink: "141414", accent: "2546D8", muted: "6A6862", paper: "EEECE6")],
                                   sample: SigSample(title: "Carrier Wave", author: "Ilse Brandvold")))

        // S4 Rank Insignia: three gold chevrons over a nebula, like fleet rank stripes.
        e = []
        e.append(.photo(.full, clip: nil, look: .natural, focusY: 0.4, zoom: 1.1, index: 0, fallback: .material("mat.nebula.palette.b")))
        e.append(.scrim(NRect(0, 0.42, 1, 0.58), .bg, angle: 90, strength: 0.95))
        e.append(.shape(.chevron, NRect(0.37, 0.15, 0.26, 0.07), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.chevron, NRect(0.37, 0.235, 0.26, 0.07), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.chevron, NRect(0.37, 0.32, 0.26, 0.07), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.52, 0.86, 0.2), SigType(["Unbounded-ExtraBold"], tracking: 0.02, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.text(.series, NRect(0.1, 0.755, 0.8, 0.02), SigType(["Montserrat-Black"], color: .accent, tracking: 0.35)))
        e.append(.text(.author, NRect(0.12, 0.89, 0.76, 0.034), SigType(["Montserrat-Black"], tracking: 0.3)))
        out.append(SignatureDesign(id: "scienceFiction-rank-insignia", name: "Rank Insignia", genre: .scienceFiction,
                                   idea: "Three gold chevrons, the rank stripes of a fleet, stand alone against the galaxy like a uniform patch.",
                                   tags: ["photo", "dark", "space opera", "epic", "bold type", "military"], elements: e,
                                   palettes: [SigPalette("Admiralty", bg: "0B1030", ink: "F3F0E8", accent: "E5B94E", muted: "3B2A6B", paper: "F3F0E8"),
                                              SigPalette("Red Giant", bg: "1A0608", ink: "F6ECE4", accent: "F08A3C", muted: "6B1E2A", paper: "F6ECE4"),
                                              SigPalette("Teal Nebula", bg: "041A1E", ink: "EAF7F4", accent: "7FF0D8", muted: "1E4F5A", paper: "EAF7F4")],
                                   sample: SigSample(title: "Admiral of Nothing", author: "Rhys Calloway", series: "THE MERIDIAN WAR · ONE", photo: "space")))

        // S5 Signal Block: a duotone heroine, cut across by a solid block of hot color that carries the title.
        e = []
        e.append(.photo(.full, clip: nil, look: .duotone(.bg, .paper), focusY: 0.3, zoom: 1.05, index: 0, fallback: .material("mat.smoke.palette.b")))
        e.append(.scrim(NRect(0, 0, 1, 0.16), .bg, angle: 270, strength: 0.7))
        e.append(.text(.seriesOr("BOOK ONE"), NRect(0.07, 0.045, 0.86, 0.02), SigType(["Oswald-Bold"], color: .paper, tracking: 0.4, align: .left)))
        e.append(.shape(.rectangle, NRect(0, 0.64, 1, 0.36), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.67, 0.86, 0.18), SigType(["Anton-Regular"], color: .bg, lineHeight: 0.92, align: .left, breaks: .lines(2))))
        e.append(.shape(.rule, NRect(0.07, 0.87, 0.2, 0.004), .bg, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.07, 0.89, 0.86, 0.035), SigType(["Oswald-Bold"], color: .bg, tracking: 0.3, align: .left)))
        out.append(SignatureDesign(id: "scienceFiction-signal-block", name: "Signal Block", genre: .scienceFiction,
                                   idea: "A hard duotone portrait is cut off at the chest by a slab of signal color, and the title is printed straight onto the slab.",
                                   tags: ["photo", "dark", "space opera", "bold type", "condensed", "modern"], elements: e,
                                   palettes: [SigPalette("Navy & Amber", bg: "0E1A33", ink: "0E1A33", accent: "F5A623", muted: "5E6B85", paper: "F3EEE4"),
                                              SigPalette("Oxide & Mint", bg: "2A0F12", ink: "2A0F12", accent: "9FE8C8", muted: "7A5054", paper: "F4EDE6"),
                                              SigPalette("Ink & Signal Yellow", bg: "111111", ink: "111111", accent: "F2E14C", muted: "6E6E6E", paper: "F2F2F2")],
                                   sample: SigSample(title: "The Mercenary Saint", author: "Kaia Varga", series: "THE DRIFT WARS · BOOK ONE", photo: "portrait")))

        // S6 Ringed Crescent: a vast ringed planet rising, lit only on one edge.
        e = []
        e.append(.fill(.material("mat.stars.palette.f"), .full))
        e.append(.text(.series, NRect(0.08, 0.06, 0.84, 0.02), SigType(["Michroma-Regular"], color: .accent, tracking: 0.35)))
        e.append(.text(.title, NRect(0.08, 0.11, 0.84, 0.16), SigType(["Michroma-Regular"], tracking: 0.1, lineHeight: 1.1, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.15, 0.3, 0.7, 0.024), SigType(["JosefinSans-Bold"], color: .muted, tracking: 0.45)))
        e.append(.shape(.ellipse, NRect(0.04, 0.47, 1.1, 0.6875), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.1, 0.5, 1.1, 0.6875), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(-0.18, 0.69, 1.36, 0.12), .alpha(.paper, 0.85), stroke: 0.003, rotation: -12))
        out.append(SignatureDesign(id: "scienceFiction-ringed-crescent", name: "Ringed Crescent", genre: .scienceFiction,
                                   idea: "A planet too big for the cover rises in the dark, lit on one thin edge and crossed by the hairline of its ring.",
                                   tags: ["graphic", "dark", "space opera", "epic", "wide type", "minimal"], elements: e,
                                   palettes: [SigPalette("Void & Solar", bg: "05070D", ink: "EEF1F6", accent: "F0A04B", muted: "9AA6BA", paper: "EEF1F6"),
                                              SigPalette("Violet Dusk", bg: "0D0618", ink: "F1EAF8", accent: "C77DFF", muted: "A495B8", paper: "F1EAF8"),
                                              SigPalette("Ice Giant", bg: "020A12", ink: "EAF5FB", accent: "7FD3FF", muted: "8FA6B6", paper: "EAF5FB")],
                                   sample: SigSample(title: "The Halo Sovereign", author: "Esme Taranis", series: "THE SILVERED EMPIRE · I")))

        // S7 Misregistered: the title printed twice, slightly out of register, like a feed that won't hold still.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.shape(.rule, NRect(0.07, 0.05, 0.86, 0.0025), .ink, stroke: 0, rotation: 0))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.07, 0.065, 0.5, 0.018), SigType(["JosefinSans-Bold"], tracking: 0.35, align: .left)))
        e.append(.text(.title, NRect(0.082, 0.208, 0.86, 0.5), SigType(["DMSerifDisplay-Regular"], color: .accent, letterCase: .title, lineHeight: 0.9, align: .left, breaks: .stacked, opacity: 0.9)))
        e.append(.text(.title, NRect(0.07, 0.2, 0.86, 0.5), SigType(["DMSerifDisplay-Regular"], letterCase: .title, lineHeight: 0.9, align: .left, breaks: .stacked)))
        e.append(.shape(.rule, NRect(0.07, 0.86, 0.86, 0.0025), .ink, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.07, 0.875, 0.6, 0.032), SigType(["JosefinSans-Bold"], letterCase: .title, tracking: 0.05, align: .left)))
        out.append(SignatureDesign(id: "scienceFiction-misregistered", name: "Misregistered", genre: .scienceFiction,
                                   idea: "The title is printed twice, a hair out of register, so the near future feels like a signal that won't quite hold still.",
                                   tags: ["typographic", "light", "near future", "literary", "serif", "modern"], elements: e,
                                   palettes: [SigPalette("Newsprint & Cyan", bg: "EDEAE2", ink: "1A1A1A", accent: "1FB5C9", muted: "8B877D", paper: "EDEAE2"),
                                              SigPalette("Riso Pink", bg: "F4EFE6", ink: "23305E", accent: "FF5C8A", muted: "8E8A9A", paper: "F4EFE6"),
                                              SigPalette("Night Mode", bg: "16181D", ink: "EDE9E1", accent: "FF6B3D", muted: "6F737C", paper: "EDE9E1")],
                                   sample: SigSample(title: "Everything Is Weather Now", author: "Priya Castellane")))

        // S8 Lit Screen: a lone glowing phone in an empty field; the face lives inside it.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.author, NRect(0.1, 0.06, 0.8, 0.026), SigType(["Montserrat-Black"], tracking: 0.3)))
        e.append(.shape(.roundedRect, NRect(0.352, 0.2, 0.296, 0.37), .ink, stroke: 0.003, rotation: 0))
        e.append(.photo(NRect(0.365, 0.208, 0.27, 0.354), clip: .roundedRect, look: .tint(.accent), focusY: 0.3, zoom: 1.2, index: 0, fallback: .linear(.accent, .muted, 90)))
        e.append(.text(.title, NRect(0.08, 0.66, 0.84, 0.17), SigType(["LibreCaslonDisplay-Regular"], letterCase: .title, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.3, 0.87, 0.4, 0.018), SigType(["Montserrat-Black"], color: .muted, tracking: 0.4)))
        out.append(SignatureDesign(id: "scienceFiction-lit-screen", name: "Lit Screen", genre: .scienceFiction,
                                   idea: "One small glowing screen in a vast quiet field: the only face left is the one inside the device.",
                                   tags: ["photo", "light", "near future", "literary", "minimal", "serif"], elements: e,
                                   palettes: [SigPalette("Concrete & Glow", bg: "DCD9D2", ink: "1E1F22", accent: "4B7BFF", muted: "6E6C66", paper: "F2F0EB"),
                                              SigPalette("Midnight Scroll", bg: "0F1115", ink: "EDEBE6", accent: "9B7BFF", muted: "8A8E97", paper: "EDEBE6"),
                                              SigPalette("Peach & Teal", bg: "F1D9C6", ink: "2A2522", accent: "1F8A8A", muted: "7A6558", paper: "FAEFE6")],
                                   sample: SigSample(title: "The Last Good Year", author: "Jonah Ferreira-Lind", photo: "portrait")))

        // MARK: Historical

        // H1 Censored Print: a sepia photograph mounted on crumpled paper, stamped by the censor.
        e = []
        e.append(.fill(.material("mat.crumpled.palette.f"), .full))
        e.append(.shape(.rectangle, NRect(0.1, 0.07, 0.8, 0.53), .paper, stroke: 0, rotation: 0))
        e.append(.photo(NRect(0.13, 0.09, 0.74, 0.47), clip: nil, look: .sepia, focusY: 0.5, zoom: 1, index: 0, fallback: .material("mat.dust.palette.b")))
        e.append(.shape(.rectangle, NRect(0.56, 0.52, 0.34, 0.055), .accent, stroke: 0.004, rotation: -8))
        e.append(.text(.label("PASSED BY CENSOR"), NRect(0.58, 0.535, 0.3, 0.025), SigType(["SpecialElite-Regular"], color: .accent, tracking: 0.08, rotation: -8)))
        e.append(.text(.title, NRect(0.08, 0.65, 0.84, 0.18), SigType(["Oswald-Bold"], tracking: 0.02, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.08, 0.87, 0.84, 0.032), SigType(["SpecialElite-Regular"], letterCase: .title, tracking: 0.1)))
        out.append(SignatureDesign(id: "historical-censored-print", name: "Censored Print", genre: .historical,
                                   idea: "A sepia photograph mounted on worn paper, cleared for release by a crooked red censor's stamp.",
                                   tags: ["photo", "light", "wartime", "vintage", "condensed", "documentary"], elements: e,
                                   palettes: [SigPalette("Kraft & Stamp Red", bg: "CDB48C", ink: "2A2118", accent: "A8261E", muted: "7A6448", paper: "F3EBDD"),
                                              SigPalette("Field Grey", bg: "B4B3A7", ink: "1F211C", accent: "7A1E1A", muted: "6E6F66", paper: "EEECE4"),
                                              SigPalette("Navy Ledger", bg: "1F2A3A", ink: "EDE6D6", accent: "D0A84E", muted: "6A7584", paper: "EDE6D6")],
                                   sample: SigSample(title: "The Lantern Bridge", author: "Margit Havelka", photo: "landscape")))

        // H2 Searchlights: two pale beams cross the night over a blacked-out skyline.
        e = []
        e.append(.fill(.linear(.muted, .bg, 90), .full))
        e.append(.shape(.triangle, NRect(0.08, 0.05, 0.26, 0.95), .alpha(.paper, 0.14), stroke: 0, rotation: 200))
        e.append(.shape(.triangle, NRect(0.6, 0.05, 0.26, 0.95), .alpha(.paper, 0.1), stroke: 0, rotation: 155))
        e.append(.text(.title, NRect(0.07, 0.07, 0.86, 0.33), SigType(["BebasNeue-Regular"], tracking: 0.02, lineHeight: 0.88, breaks: .stacked)))
        e.append(.text(.tagline, NRect(0.07, 0.42, 0.86, 0.02), SigType(["Oswald-Bold"], color: .accent, tracking: 0.3)))
        e.append(.shape(.rectangle, NRect(0.05, 0.8, 0.1, 0.07), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.18, 0.76, 0.07, 0.11), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.3, 0.79, 0.12, 0.08), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.32, 0.755, 0.08, 0.05), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.48, 0.72, 0.05, 0.15), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.56, 0.78, 0.14, 0.09), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.75, 0.75, 0.08, 0.12), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.86, 0.8, 0.1, 0.07), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0, 0.86, 1, 0.14), .bg, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.15, 0.905, 0.7, 0.032), SigType(["Oswald-Bold"], color: .accent, tracking: 0.35)))
        out.append(SignatureDesign(id: "historical-searchlights", name: "Searchlights", genre: .historical,
                                   idea: "Two pale searchlight beams cross over a blacked-out city, sweeping straight through a towering title.",
                                   tags: ["graphic", "dark", "wartime", "condensed", "bold type", "atmospheric"], elements: e,
                                   palettes: [SigPalette("Blitz Night", bg: "0C0F14", ink: "F1E9D8", accent: "E8A33C", muted: "2A3550", paper: "F1E9D8"),
                                              SigPalette("Ember Raid", bg: "120A08", ink: "F4E6D8", accent: "F06A2A", muted: "4A2218", paper: "F4E6D8"),
                                              SigPalette("Moonlit Steel", bg: "0A1018", ink: "EEF2F6", accent: "C9D6E2", muted: "33475E", paper: "EEF2F6")],
                                   sample: SigSample(title: "Blackout Summer", author: "Edith Rowan", tagline: "London, 1940. The lights went out. They did not.")))

        // H3 Ribbon: a medal ribbon divides a stacked title column from a black-and-white face.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.photo(NRect(0.5, 0, 0.5, 1), clip: nil, look: .mono, focusY: 0.3, zoom: 1.1, index: 0, fallback: .watercolor([.muted, .ink])))
        e.append(.shape(.rectangle, NRect(0.455, 0, 0.045, 1), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.4715, 0, 0.012, 1), .paper, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.06, 0.07, 0.36, 0.48), SigType(["Antonio-Bold"], lineHeight: 0.9, align: .left, breaks: .stacked)))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.06, 0.84, 0.36, 0.018), SigType(["Oswald-Bold"], color: .accent, tracking: 0.35, align: .left)))
        e.append(.text(.author, NRect(0.06, 0.87, 0.36, 0.06), SigType(["Oswald-Bold"], tracking: 0.08, lineHeight: 1.0, align: .left, breaks: .stacked)))
        out.append(SignatureDesign(id: "historical-ribbon", name: "Ribbon", genre: .historical,
                                   idea: "A striped medal ribbon runs the full height, dividing a stacked title column from a soldier's quiet face.",
                                   tags: ["photo", "light", "wartime", "asymmetric", "condensed", "moody"], elements: e,
                                   palettes: [SigPalette("Linen & Ribbon Red", bg: "ECE5D8", ink: "1C1B19", accent: "B0261E", muted: "8D8577", paper: "ECE5D8"),
                                              SigPalette("Olive Drab", bg: "D8D3BF", ink: "25281E", accent: "4B5A2A", muted: "8A876F", paper: "EEEAD9"),
                                              SigPalette("Night Ledger", bg: "15171A", ink: "ECE5D8", accent: "C79A3A", muted: "6C6A66", paper: "ECE5D8")],
                                   sample: SigSample(title: "Snow on the Rails", author: "Halina Brzeska", photo: "portrait")))

        // H4 Deco Window: a stepped black arch over a gold sunburst, the title set inside like a theatre marquee.
        e = []
        e.append(.fill(.material("mat.sunburst.palette.b"), .full))
        e.append(.shape(.arch, NRect(0.14, 0.1, 0.72, 0.7), .accent, stroke: 0.004, rotation: 0))
        e.append(.shape(.arch, NRect(0.16, 0.12, 0.68, 0.66), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.arch, NRect(0.185, 0.145, 0.63, 0.61), .accent, stroke: 0.002, rotation: 0))
        e.append(.text(.label("A NOVEL"), NRect(0.3, 0.29, 0.4, 0.018), SigType(["JosefinSans-Bold"], color: .accent, tracking: 0.45)))
        e.append(.text(.title, NRect(0.22, 0.33, 0.56, 0.27), SigType(["Limelight-Regular"], lineHeight: 1.0, breaks: .stacked)))
        e.append(.decor("fading diamond", .divider, NRect(0.3, 0.625, 0.4, 0.02), .accent))
        e.append(.text(.author, NRect(0.24, 0.67, 0.52, 0.026), SigType(["JosefinSans-Bold"], tracking: 0.35)))
        out.append(SignatureDesign(id: "historical-deco-window", name: "Deco Window", genre: .historical,
                                   idea: "A black arched window set into a gilded sunburst, the title glowing inside it like a ballroom marquee.",
                                   tags: ["graphic", "dark", "gilded age", "art deco", "elegant", "glamorous"], elements: e,
                                   palettes: [SigPalette("Jet & Gilt", bg: "0D0D0F", ink: "EAD7A4", accent: "C9A24D", muted: "2A2A2E", paper: "EAD7A4"),
                                              SigPalette("Emerald Salon", bg: "0C2A22", ink: "EBD9AC", accent: "D2B05C", muted: "1D4036", paper: "EBD9AC"),
                                              SigPalette("Champagne", bg: "F1E7D2", ink: "1E1A14", accent: "A88536", muted: "D8C9A6", paper: "F8F2E4")],
                                   sample: SigSample(title: "The Diamond Hour", author: "Celeste Whitlock")))

        // H5 Sealing Wax: a cream letter, an italic title, and one red wax seal.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.shape(.rectangle, NRect(0.05, 0.032, 0.9, 0.936), .muted, stroke: 0.0025, rotation: 0))
        e.append(.text(.title, NRect(0.1, 0.1, 0.8, 0.36), SigType(["PlayfairDisplay-BoldItalic"], letterCase: .title, lineHeight: 0.95, breaks: .lines(3))))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.2, 0.49, 0.6, 0.02), SigType(["CormorantGaramond-SemiBold"], color: .muted, tracking: 0.35)))
        e.append(.shape(.ellipse, NRect(0.39, 0.57, 0.22, 0.1375), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.415, 0.5856, 0.17, 0.10625), .alpha(.hex("000000"), 0.28), stroke: 0.003, rotation: 0))
        e.append(.shape(.diamond, NRect(0.475, 0.62, 0.05, 0.0375), .alpha(.paper, 0.4), stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.15, 0.85, 0.7, 0.035), SigType(["CormorantGaramond-SemiBold"], tracking: 0.25)))
        out.append(SignatureDesign(id: "historical-sealing-wax", name: "Sealing Wax", genre: .historical,
                                   idea: "The cover is a private letter: an italic title written on cream paper, closed with one red wax seal.",
                                   tags: ["typographic", "light", "period", "regency", "elegant", "romantic"], elements: e,
                                   palettes: [SigPalette("Laid Paper & Sealing Wax", bg: "F1EADB", ink: "2A1E1A", accent: "9E1B22", muted: "6E604E", paper: "FBF7EF"),
                                              SigPalette("Dove & Ink Blue", bg: "E4E2DC", ink: "1B2440", accent: "23407A", muted: "5F6372", paper: "F6F5F1"),
                                              SigPalette("Tea & Black Wax", bg: "E6D5B8", ink: "2B2016", accent: "1A1614", muted: "6B5A44", paper: "F5ECDC")],
                                   sample: SigSample(title: "A Season of Small Deceits", author: "Harriet Lisle")))

        // H6 Gallery Plaque: the portrait hung as a museum painting, named on a gilt-edged plaque.
        e = []
        e.append(.photo(.full, clip: nil, look: .natural, focusY: 0.28, zoom: 1, index: 0, fallback: .material("mat.canvas.palette.b")))
        e.append(.decor("gilded frame regular", .border, .full, .accent))
        e.append(.shape(.rectangle, NRect(0.12, 0.69, 0.76, 0.22), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.135, 0.699, 0.73, 0.202), .accent, stroke: 0.002, rotation: 0))
        e.append(.text(.title, NRect(0.17, 0.72, 0.66, 0.12), SigType(["PlayfairDisplay-Bold"], letterCase: .title, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.2, 0.855, 0.6, 0.024), SigType(["Montserrat-Black"], color: .accent, tracking: 0.35)))
        out.append(SignatureDesign(id: "historical-gallery-plaque", name: "Gallery Plaque", genre: .historical,
                                   idea: "The heroine hangs in a gilt frame like a museum portrait, named on a small engraved plaque.",
                                   tags: ["photo", "dark", "gilded age", "period", "elegant", "serif"], elements: e,
                                   palettes: [SigPalette("Walnut & Gilt", bg: "1E140E", ink: "F2E6CC", accent: "C9A24D", muted: "5A4632", paper: "F2E6CC"),
                                              SigPalette("Black Lacquer", bg: "0B0B0B", ink: "F0EADF", accent: "D8C17E", muted: "4A4640", paper: "F0EADF"),
                                              SigPalette("Ivory Plaque", bg: "EDE4D0", ink: "241B12", accent: "A8812F", muted: "8C7A5E", paper: "F8F2E4")],
                                   sample: SigSample(title: "The Calder Heiress", author: "Philippa Ashcombe", photo: "portrait")))

        // H7 Saga Lintel: one enormous word spans the sky over a wide land; an oxblood band carries the name.
        e = []
        e.append(.photo(.full, clip: nil, look: .natural, focusY: 0.6, zoom: 1, index: 0, fallback: .watercolor([.accent, .muted, .ink])))
        e.append(.scrim(NRect(0, 0, 1, 0.45), .hex("000000"), angle: 270, strength: 0.75))
        e.append(.text(.title, NRect(0.05, 0.08, 0.9, 0.13), SigType(["PlayfairDisplay-Black"], color: .paper, tracking: 0.04, breaks: .oneLine, shadow: true)))
        e.append(.shape(.rule, NRect(0.4, 0.23, 0.2, 0.003), .paper, stroke: 0, rotation: 0))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.1, 0.25, 0.8, 0.022), SigType(["Montserrat-Black"], color: .paper, tracking: 0.4)))
        e.append(.shape(.rectangle, NRect(0, 0.86, 1, 0.14), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.08, 0.89, 0.84, 0.05), SigType(["PlayfairDisplay-Bold"], color: .paper, tracking: 0.2)))
        out.append(SignatureDesign(id: "historical-saga-lintel", name: "Saga Lintel", genre: .historical,
                                   idea: "One enormous word spans the sky like a carved lintel over generations of land; a deep band below carries the family name.",
                                   tags: ["photo", "dark", "saga", "epic", "serif", "bold type"], elements: e,
                                   palettes: [SigPalette("Oxblood & Ivory", bg: "1A1210", ink: "F3EBDD", accent: "5C1A14", muted: "9B8A76", paper: "F3EBDD"),
                                              SigPalette("Prussian", bg: "0E1622", ink: "EEF0F2", accent: "1C2E4A", muted: "7B8A9E", paper: "EEF0F2"),
                                              SigPalette("Moss Saga", bg: "141A12", ink: "F1EEDF", accent: "2E3B26", muted: "8A9277", paper: "F1EEDF")],
                                   sample: SigSample(title: "Harrowgate", subtitle: "A Family Saga", author: "Eleanor Penrose-Vane", photo: "landscape")))

        // H8 The Crossing: a pale sky, a deep sea, one tiny ship on the horizon.
        e = []
        e.append(.fill(.linear(.paper, .muted, 90), NRect(0, 0, 1, 0.62)))
        e.append(.text(.title, NRect(0.07, 0.07, 0.86, 0.36), SigType(["Fraunces-Black"], letterCase: .title, tracking: -0.02, lineHeight: 0.88, align: .left, breaks: .stacked)))
        e.append(.fill(.solid(.ink), NRect(0, 0.62, 1, 0.38)))
        e.append(.shape(.triangle, NRect(0.64, 0.548, 0.028, 0.06), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.668, 0.535, 0.034, 0.073), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.625, 0.608, 0.09, 0.012), .ink, stroke: 0, rotation: 0))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.07, 0.84, 0.86, 0.02), SigType(["JosefinSans-Bold"], color: .alpha(.paper, 0.75), tracking: 0.35, align: .left)))
        e.append(.text(.author, NRect(0.07, 0.875, 0.86, 0.04), SigType(["JosefinSans-Bold"], color: .paper, tracking: 0.25, align: .left)))
        out.append(SignatureDesign(id: "historical-the-crossing", name: "The Crossing", genre: .historical,
                                   idea: "A pale sky over a deep sea with one tiny ship on the horizon: a generation's voyage reduced to a single line.",
                                   tags: ["graphic", "light", "saga", "minimal", "serif", "atmospheric"], elements: e,
                                   palettes: [SigPalette("Linen Sky & Atlantic", bg: "152238", ink: "152238", accent: "C2452D", muted: "D9CDB8", paper: "F1EBDF"),
                                              SigPalette("Dusk Harbour", bg: "2B1F33", ink: "2B1F33", accent: "8C2F2A", muted: "E8B79C", paper: "F6E2CF"),
                                              SigPalette("Green Water", bg: "1D3A34", ink: "1D3A34", accent: "B8862E", muted: "C9D3C4", paper: "EEF1EA")],
                                   sample: SigSample(title: "The Crossing Years", author: "Margarethe Lindqvist")))

        return out
    }
}
