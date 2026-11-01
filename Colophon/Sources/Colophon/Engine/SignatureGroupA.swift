import Foundation

// MARK: - Signature group A: literary, memoir, nonfiction

extension SignatureLibrary {
    static var groupA: [SignatureDesign] {
        var out: [SignatureDesign] = []
        var e: [SigElement] = []

        // MARK: Literary

        // Horizon Band: the photo is cropped to a thin horizon strip; everything else is quiet paper.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.25, 0.1, 0.5, 0.018), SigType(["Montserrat-Black"], color: .muted, tracking: 0.4)))
        e.append(.text(.title, NRect(0.08, 0.14, 0.84, 0.24), SigType(["CormorantGaramond-SemiBold"], letterCase: .asTyped, tracking: -0.01, lineHeight: 0.9, breaks: .lines(2))))
        e.append(.photo(NRect(0, 0.45, 1, 0.15), clip: nil, look: .faded, focusY: 0.55, zoom: 1.4, index: 0, fallback: .watercolor([.accent, .muted])))
        e.append(.shape(.rule, NRect(0.47, 0.83, 0.06, 0.0025), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.2, 0.86, 0.6, 0.03), SigType(["Montserrat-Black"], tracking: 0.3)))
        out.append(SignatureDesign(id: "literary-horizon-band", name: "Horizon Band", genre: .literary,
                                   idea: "The photo is cropped to a thin horizon strip across the middle; the rest is quiet paper and a calm serif.",
                                   tags: ["photo", "light", "minimal", "elegant", "atmospheric"], elements: e,
                                   palettes: [SigPalette("Fog & Slate", bg: "E9E6DF", ink: "1E2328", accent: "5C7A8A", muted: "8C8C86", paper: "F6F4EF"),
                                              SigPalette("Dusk", bg: "2A2733", ink: "F2E9DD", accent: "D98C5F", muted: "8A8296", paper: "F2E9DD"),
                                              SigPalette("Sea Glass", bg: "D7E2DC", ink: "17302B", accent: "3E7D6E", muted: "6F8A82", paper: "EFF4F0")],
                                   sample: SigSample(title: "Where the Water Turns", author: "Tobias Wren", photo: "landscape")))

        // Up the Spine: the title runs vertically up the left edge; a narrow column holds everything else.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.title, NRect(-0.47, 0.381, 1.44, 0.2375), SigType(["Anton-Regular"], tracking: 0.02, breaks: .oneLine, rotation: -90)))
        e.append(.shape(.rectangle, NRect(0.52, 0.06, 0.002, 0.88), .muted, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.58, 0.06, 0.06, 0.0375), .accent, stroke: 0, rotation: 0))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.58, 0.115, 0.34, 0.018), SigType(["Montserrat-Black"], color: .muted, tracking: 0.35, align: .left)))
        e.append(.text(.author, NRect(0.58, 0.895, 0.34, 0.04), SigType(["PlayfairDisplay-Bold"], letterCase: .title, align: .left)))
        out.append(SignatureDesign(id: "literary-up-the-spine", name: "Up the Spine", genre: .literary,
                                   idea: "The title runs vertically up the left edge in towering condensed caps; a narrow right column holds a red square and the author.",
                                   tags: ["typographic", "dark", "bold type", "modern", "minimal"], elements: e,
                                   palettes: [SigPalette("Ink & Ember", bg: "141414", ink: "F3EEE4", accent: "E2552B", muted: "7A756C", paper: "F3EEE4"),
                                              SigPalette("Cobalt & Saffron", bg: "1B2A6B", ink: "F4F1EA", accent: "F2C14E", muted: "8C95BF", paper: "F4F1EA"),
                                              SigPalette("Bone & Black", bg: "EEE9DF", ink: "151515", accent: "B5281C", muted: "8E877B", paper: "FAF7F0")],
                                   sample: SigSample(title: "Ash Year", author: "Oren Halvorsen")))

        // Arch Window: a portrait seen through a chapel-window arch, framed by a hairline.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0.2, 0.08, 0.6, 0.5), clip: .arch, look: .duotone(.ink, .paper), focusY: 0.3, zoom: 1.1, index: 0, fallback: .watercolor([.accent, .muted])))
        e.append(.shape(.arch, NRect(0.18, 0.068, 0.64, 0.524), .ink, stroke: 0.003, rotation: 0))
        e.append(.text(.title, NRect(0.08, 0.63, 0.84, 0.18), SigType(["DMSerifDisplay-Italic"], letterCase: .asTyped, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.shape(.rule, NRect(0.46, 0.835, 0.08, 0.0025), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.2, 0.86, 0.6, 0.03), SigType(["Montserrat-Black"], tracking: 0.3)))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.3, 0.915, 0.4, 0.016), SigType(["Montserrat-Black"], color: .muted, tracking: 0.4)))
        out.append(SignatureDesign(id: "literary-arch-window", name: "Arch Window", genre: .literary,
                                   idea: "A duotone portrait seen through a chapel-window arch with a hairline frame; an italic serif title sits below like a caption.",
                                   tags: ["photo", "light", "elegant", "classic", "romantic"], elements: e,
                                   palettes: [SigPalette("Plaster", bg: "EDE4D3", ink: "2A1D17", accent: "B4532A", muted: "8D7B6A", paper: "F7F1E6"),
                                              SigPalette("Oxblood", bg: "3B1418", ink: "F1E6D6", accent: "D9A35B", muted: "9C7A70", paper: "F1E6D6"),
                                              SigPalette("Chapel Blue", bg: "D8DEE3", ink: "1C2733", accent: "9A3B2E", muted: "6E7C88", paper: "F2F4F5")],
                                   sample: SigSample(title: "The Lesser Saints", author: "Clara Benedetti", photo: "portrait")))

        // Color Field: two soft-edged painted fields stacked like a gallery canvas; the title waits below.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.fill(.watercolor([.accent]), NRect(0.07, 0.05, 0.86, 0.4)))
        e.append(.fill(.watercolor([.muted]), NRect(0.07, 0.47, 0.86, 0.23)))
        e.append(.text(.title, NRect(0.07, 0.74, 0.86, 0.12), SigType(["Prata-Regular"], tracking: 0.1, breaks: .oneLine)))
        e.append(.text(.author, NRect(0.2, 0.895, 0.6, 0.025), SigType(["JosefinSans-Bold"], tracking: 0.35)))
        out.append(SignatureDesign(id: "literary-color-field", name: "Color Field", genre: .literary,
                                   idea: "Two soft-edged painted fields stack like an abstract canvas; the title is set small and wide on the bare margin below.",
                                   tags: ["painted", "light", "minimal", "artful", "modern"], elements: e,
                                   palettes: [SigPalette("Rust & Plum", bg: "EFE8DA", ink: "1F1A1C", accent: "C2502E", muted: "4A2A45", paper: "F7F2E8"),
                                              SigPalette("Ochre & Teal", bg: "ECE6D6", ink: "14201F", accent: "D49A2A", muted: "1F4D4A", paper: "F6F1E4"),
                                              SigPalette("Rose & Slate", bg: "F1EAE6", ink: "221E20", accent: "D98A8A", muted: "5B5F66", paper: "F8F4F1")],
                                   sample: SigSample(title: "Late Light", author: "Agnes Morrow")))

        // The Band: a solid band of color cuts across a toned landscape and carries the title.
        e = []
        e.append(.photo(.full, clip: nil, look: .duotone(.ink, .muted), focusY: 0.45, zoom: 1, index: 0, fallback: .material("mat.clouds.palette.f")))
        e.append(.scrim(NRect(0, 0, 1, 0.2), .hex("000000"), angle: 270, strength: 0.5))
        e.append(.scrim(NRect(0, 0.78, 1, 0.22), .hex("000000"), angle: 90, strength: 0.6))
        e.append(.text(.author, NRect(0.07, 0.05, 0.6, 0.03), SigType(["Montserrat-Black"], color: .paper, tracking: 0.3, align: .left)))
        e.append(.fill(.solid(.accent), NRect(0, 0.6, 1, 0.22)))
        e.append(.text(.title, NRect(0.07, 0.625, 0.86, 0.17), SigType(["BodoniModa-Bold"], color: .paper, tracking: 0.02, lineHeight: 0.9, align: .left, breaks: .lines(2))))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.07, 0.85, 0.5, 0.018), SigType(["Montserrat-Black"], color: .paper, tracking: 0.4, align: .left)))
        out.append(SignatureDesign(id: "literary-the-band", name: "The Band", genre: .literary,
                                   idea: "A solid band of deep color slices across a toned landscape and carries the title in reversed Bodoni.",
                                   tags: ["photo", "dark", "bold type", "modern", "moody"], elements: e,
                                   palettes: [SigPalette("Prussian", bg: "0F1E2E", ink: "0E1620", accent: "1E3A5F", muted: "9AB0C4", paper: "F4EFE6"),
                                              SigPalette("Oxide", bg: "2A0F0A", ink: "1A0B07", accent: "8E2B1A", muted: "D9B8A0", paper: "F6EDE3"),
                                              SigPalette("Moss", bg: "1A2419", ink: "121A12", accent: "2F4A2C", muted: "B9C4A6", paper: "F2F0E6")],
                                   sample: SigSample(title: "A Field in Winter", author: "Henrik Aaland", photo: "landscape")))

        // The Thread: one red line drops from the top edge and the title hangs from it.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.shape(.rectangle, NRect(0.4985, 0, 0.003, 0.39), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.diamond, NRect(0.485, 0.385, 0.03, 0.019), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.08, 0.44, 0.84, 0.3), SigType(["CormorantGaramond-Bold"], letterCase: .asTyped, tracking: -0.01, lineHeight: 0.88, breaks: .stacked)))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.3, 0.775, 0.4, 0.018), SigType(["Montserrat-Black"], color: .muted, tracking: 0.4)))
        e.append(.text(.author, NRect(0.15, 0.885, 0.7, 0.04), SigType(["CormorantGaramond-MediumItalic"], letterCase: .asTyped)))
        out.append(SignatureDesign(id: "literary-the-thread", name: "The Thread", genre: .literary,
                                   idea: "A single red thread drops from the top edge to a tiny knot, and the title hangs from it in open space.",
                                   tags: ["graphic", "light", "minimal", "elegant", "quiet"], elements: e,
                                   palettes: [SigPalette("Linen & Red Thread", bg: "F3EFE7", ink: "1A1A1A", accent: "C1272D", muted: "8A857C", paper: "FBF9F4"),
                                              SigPalette("Midnight & Gold", bg: "101826", ink: "EFE7D6", accent: "D4A84B", muted: "6E7891", paper: "EFE7D6"),
                                              SigPalette("Celadon", bg: "DCE5DC", ink: "1D2B24", accent: "B0413E", muted: "74867B", paper: "F2F5F1")],
                                   sample: SigSample(title: "Small Mercies", author: "Delphine Osei")))

        // Echo: the title is struck once in full ink, then repeats down the cover, fading like a sound.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.title, NRect(0.07, 0.07, 0.86, 0.1), SigType(["BodoniModa-Black"], tracking: -0.01, breaks: .oneLine)))
        e.append(.text(.title, NRect(0.07, 0.18, 0.86, 0.1), SigType(["BodoniModa-Black"], color: .muted, tracking: -0.01, breaks: .oneLine, opacity: 0.55)))
        e.append(.text(.title, NRect(0.07, 0.29, 0.86, 0.1), SigType(["BodoniModa-Black"], color: .muted, tracking: -0.01, breaks: .oneLine, opacity: 0.32)))
        e.append(.text(.title, NRect(0.07, 0.4, 0.86, 0.1), SigType(["BodoniModa-Black"], color: .muted, tracking: -0.01, breaks: .oneLine, opacity: 0.17)))
        e.append(.text(.title, NRect(0.07, 0.51, 0.86, 0.1), SigType(["BodoniModa-Black"], color: .muted, tracking: -0.01, breaks: .oneLine, opacity: 0.08)))
        e.append(.shape(.rule, NRect(0.07, 0.83, 0.1, 0.004), .accent, stroke: 0, rotation: 0))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.07, 0.85, 0.5, 0.018), SigType(["Montserrat-Black"], color: .accent, tracking: 0.35, align: .left)))
        e.append(.text(.author, NRect(0.07, 0.89, 0.7, 0.04), SigType(["Montserrat-Black"], letterCase: .title, tracking: 0.02, align: .left)))
        out.append(SignatureDesign(id: "literary-echo", name: "Echo", genre: .literary,
                                   idea: "The title is struck once in full ink, then repeats down the cover in ever fainter impressions, like a sound dying away.",
                                   tags: ["typographic", "light", "modern", "bold type", "pattern"], elements: e,
                                   palettes: [SigPalette("Chalk & Blue", bg: "F2F0EB", ink: "111111", accent: "2E5BFF", muted: "111111", paper: "FAFAF7"),
                                              SigPalette("Deep Water", bg: "0D2230", ink: "EAF2F2", accent: "5FD0C4", muted: "EAF2F2", paper: "EAF2F2"),
                                              SigPalette("Blush & Wine", bg: "F3DCD4", ink: "3A1020", accent: "C2402B", muted: "3A1020", paper: "FAF0EC")],
                                   sample: SigSample(title: "Undertow", author: "Maren Solberg")))

        // Sliver: the portrait survives only as a narrow vertical slice; the title holds the left.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0.64, 0, 0.16, 1), clip: nil, look: .natural, focusY: 0.4, zoom: 1, index: 0, fallback: .material("mat.inkwash.palette.b")))
        e.append(.text(.title, NRect(0.07, 0.07, 0.52, 0.4), SigType(["LibreCaslonDisplay-Regular"], letterCase: .asTyped, tracking: -0.01, lineHeight: 0.92, align: .left, breaks: .stacked)))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.07, 0.5, 0.4, 0.018), SigType(["Montserrat-Black"], color: .accent, tracking: 0.35, align: .left)))
        e.append(.text(.author, NRect(0.07, 0.9, 0.52, 0.03), SigType(["JosefinSans-Bold"], tracking: 0.2, align: .left)))
        out.append(SignatureDesign(id: "literary-sliver", name: "Sliver", genre: .literary,
                                   idea: "The portrait survives only as a narrow vertical slice; a tall stacked Caslon title holds the open left side.",
                                   tags: ["photo", "light", "minimal", "elegant", "modern"], elements: e,
                                   palettes: [SigPalette("Gallery White", bg: "F4F2EE", ink: "141414", accent: "A6402B", muted: "7C7770", paper: "FFFFFF"),
                                              SigPalette("Graphite", bg: "1E1F21", ink: "EDEBE6", accent: "D9A441", muted: "77777A", paper: "EDEBE6"),
                                              SigPalette("Pale Ochre", bg: "EADFC6", ink: "22190F", accent: "6E2E1F", muted: "8F826A", paper: "F6F0E2")],
                                   sample: SigSample(title: "Grace Under Glass", author: "Julien Achterberg", photo: "portrait")))

        // MARK: Memoir

        // Snapshot: a small bordered print laid on linen, like a photo found in a drawer.
        e = []
        e.append(.fill(.material("mat.linen.palette.f"), .full))
        e.append(.shape(.rectangle, NRect(0.207, 0.106, 0.6, 0.45), .alpha(.ink, 0.14), stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.2, 0.1, 0.6, 0.45), .paper, stroke: 0, rotation: 0))
        e.append(.photo(NRect(0.235, 0.122, 0.53, 0.36), clip: nil, look: .faded, focusY: 0.35, zoom: 1.1, index: 0, fallback: .watercolor([.accent, .muted])))
        e.append(.text(.title, NRect(0.08, 0.61, 0.84, 0.17), SigType(["CormorantGaramond-MediumItalic"], letterCase: .asTyped, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.text(.subtitleOr("A MEMOIR"), NRect(0.2, 0.8, 0.6, 0.02), SigType(["JosefinSans-Bold"], color: .muted, tracking: 0.35)))
        e.append(.text(.author, NRect(0.2, 0.885, 0.6, 0.03), SigType(["JosefinSans-Bold"], tracking: 0.25)))
        out.append(SignatureDesign(id: "memoir-snapshot", name: "Snapshot", genre: .memoir,
                                   idea: "A small bordered family print lies on linen like a photo found in a drawer; a long italic title reads as its caption.",
                                   tags: ["photo", "light", "intimate", "nostalgic", "elegant"], elements: e,
                                   palettes: [SigPalette("Kitchen Table", bg: "E8E0D0", ink: "2B211B", accent: "B9714A", muted: "857767", paper: "FBF8F2"),
                                              SigPalette("Blue Hour", bg: "26303D", ink: "F2EDE3", accent: "C9A27A", muted: "8E98A6", paper: "F7F3EA"),
                                              SigPalette("Mint Linen", bg: "DCE6DE", ink: "1F2A26", accent: "A0524A", muted: "6D7F76", paper: "FAFBF8")],
                                   sample: SigSample(title: "The Year My Mother Learned to Swim", author: "Nora Kessling", photo: "portrait")))

        // Close: a full-bleed black-and-white face; the title is one quiet word at the foot.
        e = []
        e.append(.photo(.full, clip: nil, look: .mono, focusY: 0.3, zoom: 1.15, index: 0, fallback: .material("mat.smoke.palette.f")))
        e.append(.scrim(NRect(0, 0.52, 1, 0.48), .hex("000000"), angle: 90, strength: 0.9))
        e.append(.text(.subtitleOr("A MEMOIR"), NRect(0.08, 0.715, 0.5, 0.018), SigType(["JosefinSans-Bold"], color: .accent, tracking: 0.4, align: .left)))
        e.append(.text(.title, NRect(0.075, 0.74, 0.85, 0.13), SigType(["PlayfairDisplay-Bold"], color: .paper, letterCase: .asTyped, align: .left, breaks: .oneLine)))
        e.append(.text(.author, NRect(0.08, 0.9, 0.6, 0.028), SigType(["JosefinSans-Bold"], color: .paper, tracking: 0.25, align: .left)))
        out.append(SignatureDesign(id: "memoir-close", name: "Close", genre: .memoir,
                                   idea: "A full-bleed black-and-white face fills the cover; the title is one quiet serif line at its foot, with a single spot of color above it.",
                                   tags: ["photo", "dark", "intimate", "elegant", "moody"], elements: e,
                                   palettes: [SigPalette("Silver Print", bg: "0E0E0E", ink: "0E0E0E", accent: "D8B26E", muted: "A9A9A9", paper: "F5F2EC"),
                                              SigPalette("Rose Print", bg: "120E0F", ink: "120E0F", accent: "E8A3A0", muted: "B3A9AA", paper: "F7F0EE"),
                                              SigPalette("Cold Blue", bg: "0B0F14", ink: "0B0F14", accent: "9CC3E0", muted: "A3ABB3", paper: "F1F4F6")],
                                   sample: SigSample(title: "Daughter", author: "Ruth Adeyemi", photo: "portrait")))

        // Top Half: a sepia photograph above, a clean page below, divided by one line of color.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0, 0, 1, 0.56), clip: nil, look: .sepia, focusY: 0.45, zoom: 1, index: 0, fallback: .material("mat.watercolor.palette.f")))
        e.append(.fill(.solid(.accent), NRect(0, 0.56, 1, 0.008)))
        e.append(.text(.title, NRect(0.07, 0.61, 0.86, 0.19), SigType(["PlayfairDisplay-Bold"], letterCase: .asTyped, tracking: -0.01, lineHeight: 0.92, align: .left, breaks: .lines(2))))
        e.append(.text(.subtitle, NRect(0.07, 0.815, 0.86, 0.026), SigType(["CormorantGaramond-MediumItalic"], color: .muted, letterCase: .asTyped, align: .left)))
        e.append(.text(.author, NRect(0.07, 0.9, 0.6, 0.028), SigType(["Montserrat-Black"], tracking: 0.25, align: .left)))
        out.append(SignatureDesign(id: "memoir-top-half", name: "Top Half", genre: .memoir,
                                   idea: "A sepia photograph fills the top half and a clean page the bottom, split by a single line of color, like an album leaf.",
                                   tags: ["photo", "light", "nostalgic", "classic", "warm"], elements: e,
                                   palettes: [SigPalette("Cream & Rust", bg: "F3EDE1", ink: "231A14", accent: "A4452A", muted: "6E6154", paper: "F9F5EC"),
                                              SigPalette("Graphite", bg: "1D1C1A", ink: "F1EADC", accent: "C99A4B", muted: "A49D90", paper: "F1EADC"),
                                              SigPalette("Seafoam", bg: "E3ECE8", ink: "15302C", accent: "C25B3A", muted: "4F6A64", paper: "F3F7F5")],
                                   sample: SigSample(title: "All the Houses We Left", subtitle: "A Memoir of Moving On", author: "Samuel Okafor", photo: "landscape")))

        // Eyes: the portrait is cropped to a letterbox of the eyes, held between title and author.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.title, NRect(0.08, 0.08, 0.84, 0.28), SigType(["DMSerifDisplay-Regular"], letterCase: .asTyped, tracking: -0.01, lineHeight: 0.9, breaks: .lines(2))))
        e.append(.photo(NRect(0, 0.42, 1, 0.13), clip: nil, look: .mono, focusY: 0.42, zoom: 1.7, index: 0, fallback: .material("mat.inkwash.palette.f")))
        e.append(.text(.subtitleOr("A MEMOIR"), NRect(0.2, 0.6, 0.6, 0.02), SigType(["JosefinSans-Bold"], color: .accent, tracking: 0.4)))
        e.append(.text(.author, NRect(0.15, 0.875, 0.7, 0.04), SigType(["DMSerifDisplay-Italic"], letterCase: .asTyped)))
        out.append(SignatureDesign(id: "memoir-eyes", name: "Eyes", genre: .memoir,
                                   idea: "The portrait is cropped to a letterbox of the eyes alone, a gaze held between title and author.",
                                   tags: ["photo", "light", "intimate", "modern", "striking"], elements: e,
                                   palettes: [SigPalette("Cream & Black", bg: "EFE9DE", ink: "141210", accent: "B23A2C", muted: "8B847A", paper: "F8F5EF"),
                                              SigPalette("Indigo", bg: "1C2140", ink: "F0ECE2", accent: "E3B04B", muted: "7F86A8", paper: "F0ECE2"),
                                              SigPalette("Blush", bg: "F2DED6", ink: "2B1418", accent: "8E2D3B", muted: "9C7C78", paper: "FAF1EE")],
                                   sample: SigSample(title: "Look at Me", author: "Ilse Brandt", photo: "portrait")))

        // Quiet: a lowercase italic title at the optical center of warm paper, and almost nothing else.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.title, NRect(0.1, 0.33, 0.8, 0.21), SigType(["CormorantGaramond-MediumItalic"], letterCase: .lower, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.shape(.rule, NRect(0.45, 0.575, 0.1, 0.002), .accent, stroke: 0, rotation: 0))
        e.append(.text(.subtitleOr("a memoir"), NRect(0.3, 0.595, 0.4, 0.024), SigType(["CormorantGaramond-MediumItalic"], color: .muted, letterCase: .lower)))
        e.append(.text(.author, NRect(0.2, 0.9, 0.6, 0.022), SigType(["JosefinSans-Bold"], tracking: 0.4)))
        out.append(SignatureDesign(id: "memoir-quiet", name: "Quiet", genre: .memoir,
                                   idea: "A lowercase italic title rests at the optical center of warm paper, with one short hairline and nothing else: a whisper of a cover.",
                                   tags: ["typographic", "light", "minimal", "quiet", "elegant"], elements: e,
                                   palettes: [SigPalette("Warm Paper", bg: "F2ECE1", ink: "2A2420", accent: "A5664A", muted: "857B70", paper: "FAF6EF"),
                                              SigPalette("Night Garden", bg: "1F2A24", ink: "EDE6D6", accent: "C7A86B", muted: "8C9A8E", paper: "EDE6D6"),
                                              SigPalette("Dove", bg: "E6E4E1", ink: "232326", accent: "6E5A8A", muted: "7E7D80", paper: "F5F4F2")],
                                   sample: SigSample(title: "The Weight of Small Things", author: "Agathe Lund")))

        // Typewritten: a manuscript page with a red margin line, the title typed in place.
        e = []
        e.append(.fill(.material("mat.fibers.palette.f"), .full))
        e.append(.shape(.rectangle, NRect(0.14, 0, 0.003, 1), .alpha(.accent, 0.75), stroke: 0, rotation: 0))
        e.append(.text(.subtitleOr("A MEMOIR"), NRect(0.19, 0.08, 0.5, 0.022), SigType(["SpecialElite-Regular"], color: .muted, tracking: 0.2, align: .left)))
        e.append(.text(.title, NRect(0.19, 0.12, 0.74, 0.3), SigType(["SpecialElite-Regular"], letterCase: .asTyped, lineHeight: 1.05, align: .left, breaks: .lines(3))))
        e.append(.text(.author, NRect(0.19, 0.89, 0.6, 0.032), SigType(["SpecialElite-Regular"], letterCase: .asTyped, align: .left)))
        out.append(SignatureDesign(id: "memoir-typewritten", name: "Typewritten", genre: .memoir,
                                   idea: "The cover is a typed manuscript page with a red margin line; the title sits where the first lines would be.",
                                   tags: ["typographic", "light", "quiet", "vintage", "intimate"], elements: e,
                                   palettes: [SigPalette("Legal Pad", bg: "F2E7B8", ink: "1E1C17", accent: "C23B2E", muted: "6F6650", paper: "FBF6DE"),
                                              SigPalette("Carbon Copy", bg: "E9EBEE", ink: "1B2440", accent: "C0392B", muted: "6A7186", paper: "F7F8FA"),
                                              SigPalette("Night Shift", bg: "15171C", ink: "E8E3D6", accent: "E0553D", muted: "7C7F86", paper: "E8E3D6")],
                                   sample: SigSample(title: "Notes from the Night Shift", author: "Dana Whitcombe")))

        // Locket: a small oval portrait ringed in gold on a deep ground, set like a keepsake.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.shape(.ellipse, NRect(0.3, 0.1, 0.4, 0.34), .accent, stroke: 0.003, rotation: 0))
        e.append(.photo(NRect(0.32, 0.1125, 0.36, 0.315), clip: .ellipse, look: .sepia, focusY: 0.3, zoom: 1.3, index: 0, fallback: .watercolor([.accent, .muted])))
        e.append(.text(.title, NRect(0.08, 0.51, 0.84, 0.2), SigType(["Cinzel-Regular"], tracking: 0.06, breaks: .lines(2))))
        e.append(.shape(.rule, NRect(0.42, 0.745, 0.16, 0.002), .accent, stroke: 0, rotation: 0))
        e.append(.text(.subtitleOr("A MEMOIR"), NRect(0.25, 0.77, 0.5, 0.026), SigType(["CormorantGaramond-MediumItalic"], color: .muted, letterCase: .title)))
        e.append(.text(.author, NRect(0.15, 0.885, 0.7, 0.028), SigType(["Cinzel-Bold"], tracking: 0.2)))
        out.append(SignatureDesign(id: "memoir-locket", name: "Locket", genre: .memoir,
                                   idea: "A small oval portrait ringed in a gold hairline sits high on a deep ground, kept like a locket; classical capitals below.",
                                   tags: ["photo", "dark", "elegant", "intimate", "vintage"], elements: e,
                                   palettes: [SigPalette("Velvet Green", bg: "14261F", ink: "EFE6D2", accent: "C9A45C", muted: "9AA79C", paper: "EFE6D2"),
                                              SigPalette("Mourning Black", bg: "121112", ink: "EDE7DB", accent: "B8B8B8", muted: "8A8580", paper: "EDE7DB"),
                                              SigPalette("Oxblood", bg: "3A1218", ink: "F3E7D7", accent: "D8B06A", muted: "B59A90", paper: "F3E7D7")],
                                   sample: SigSample(title: "The Keeper of Letters", author: "Margarethe Vos", photo: "portrait")))

        // Say It Loud: a voice-driven memoir; the title shouts in heavy serif and fills a saturated ground.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.title, NRect(0.06, 0.06, 0.88, 0.66), SigType(["Fraunces-Black"], letterCase: .asTyped, tracking: -0.02, lineHeight: 0.82, align: .left, breaks: .stacked)))
        e.append(.text(.subtitleOr("A MEMOIR"), NRect(0.06, 0.75, 0.6, 0.022), SigType(["Montserrat-Black"], tracking: 0.3, align: .left)))
        e.append(.fill(.solid(.ink), NRect(0, 0.84, 1, 0.16)))
        e.append(.text(.author, NRect(0.06, 0.88, 0.88, 0.08), SigType(["Montserrat-Black"], color: .bg, tracking: 0.04, align: .left)))
        out.append(SignatureDesign(id: "memoir-say-it-loud", name: "Say It Loud", genre: .memoir,
                                   idea: "A voice-driven memoir: the heavy serif title shouts across a saturated ground, and the author's name is stamped in a black band.",
                                   tags: ["typographic", "bold type", "playful", "modern", "light"], elements: e,
                                   palettes: [SigPalette("Marigold", bg: "F2C230", ink: "1A1414", accent: "D6402B", muted: "1A1414", paper: "FFF8E6"),
                                              SigPalette("Hot Pink", bg: "FF6FA8", ink: "1A0E14", accent: "1A0E14", muted: "1A0E14", paper: "FFF0F6"),
                                              SigPalette("Cobalt", bg: "2340D8", ink: "F7F3E8", accent: "FFD23F", muted: "F7F3E8", paper: "F7F3E8")],
                                   sample: SigSample(title: "Say It Louder", author: "Bex Calloway")))

        // MARK: Nonfiction

        // One Word: a big-idea business book; one word, as wide as the cover, on safety yellow.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.title, NRect(0.06, 0.28, 0.88, 0.22), SigType(["Anton-Regular"], tracking: -0.01, breaks: .oneLine)))
        e.append(.shape(.rectangle, NRect(0.07, 0.53, 0.12, 0.008), .accent, stroke: 0, rotation: 0))
        e.append(.text(.subtitle, NRect(0.07, 0.56, 0.86, 0.03), SigType(["Montserrat-Black"], color: .muted, letterCase: .asTyped, tracking: 0.01, align: .left)))
        e.append(.text(.author, NRect(0.07, 0.885, 0.86, 0.045), SigType(["Montserrat-Black"], tracking: 0.1, align: .left)))
        out.append(SignatureDesign(id: "nonfiction-one-word", name: "One Word", genre: .nonfiction,
                                   idea: "A big-idea book sold on one word: the title runs edge to edge in condensed black caps on a loud, flat ground.",
                                   tags: ["typographic", "light", "bold type", "modern", "business"], elements: e,
                                   palettes: [SigPalette("Safety Yellow", bg: "FFD400", ink: "111111", accent: "E8382E", muted: "2E2E2E", paper: "FFFFFF"),
                                              SigPalette("Black & Signal", bg: "101010", ink: "F5F5F0", accent: "FF5A1F", muted: "B5B5B0", paper: "F5F5F0"),
                                              SigPalette("Ice & Blue", bg: "E4EEF2", ink: "0E1A24", accent: "1F6FEB", muted: "3E4F5C", paper: "FFFFFF")],
                                   sample: SigSample(title: "Leverage", subtitle: "How Small Forces Move Big Worlds", author: "Dr. Priya Raman")))

        // Rising Line: one bold band climbs across the cover like a growth chart.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.shape(.diagonalBand, NRect(-0.05, 0.42, 1.1, 0.48), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.07, 0.86, 0.28), SigType(["Montserrat-Black"], tracking: -0.01, lineHeight: 0.9, align: .left, breaks: .stacked)))
        e.append(.text(.subtitle, NRect(0.07, 0.375, 0.86, 0.024), SigType(["Montserrat-Black"], color: .muted, letterCase: .asTyped, align: .left)))
        e.append(.text(.author, NRect(0.35, 0.9, 0.58, 0.032), SigType(["Montserrat-Black"], tracking: 0.12, align: .right)))
        out.append(SignatureDesign(id: "nonfiction-rising-line", name: "Rising Line", genre: .nonfiction,
                                   idea: "One bold band of color climbs across the cover like a growth chart; heavy sans title stacked hard to the top left.",
                                   tags: ["graphic", "light", "bold type", "modern", "business"], elements: e,
                                   palettes: [SigPalette("White & Orange", bg: "FFFFFF", ink: "101418", accent: "FF5B14", muted: "4E5763", paper: "FFFFFF"),
                                              SigPalette("Navy & Lime", bg: "0F1B33", ink: "F5F7FA", accent: "C6F432", muted: "A3AFC4", paper: "F5F7FA"),
                                              SigPalette("Cream & Green", bg: "F5F1E6", ink: "102A1E", accent: "1E9E5A", muted: "4D5B50", paper: "FFFFFF")],
                                   sample: SigSample(title: "Small Bets Win", subtitle: "The Quiet Math of Lasting Success", author: "Marcus Ellery")))

        // Divided Mind: a stark portrait, cut by a solid column that holds the title (psychology).
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0, 0, 0.56, 1), clip: nil, look: .stark, focusY: 0.35, zoom: 1.2, index: 0, fallback: .material("mat.halftone.palette.b")))
        e.append(.fill(.solid(.accent), NRect(0.556, 0, 0.008, 1)))
        e.append(.text(.title, NRect(0.61, 0.07, 0.33, 0.32), SigType(["Oswald-Bold"], lineHeight: 0.95, align: .left, breaks: .stacked)))
        e.append(.text(.subtitle, NRect(0.61, 0.41, 0.33, 0.02), SigType(["JosefinSans-Bold"], color: .muted, tracking: 0.05, align: .left)))
        e.append(.text(.author, NRect(0.61, 0.9, 0.33, 0.03), SigType(["Oswald-Bold"], tracking: 0.1, align: .left)))
        out.append(SignatureDesign(id: "nonfiction-divided-mind", name: "Divided Mind", genre: .nonfiction,
                                   idea: "A hard black-and-white face is split down the middle by a solid column of color that carries the title: two selves, one cover.",
                                   tags: ["photo", "dark", "bold type", "modern", "psychology"], elements: e,
                                   palettes: [SigPalette("Red Room", bg: "9E0F24", ink: "FFFFFF", accent: "F2C14E", muted: "F2C7CC", paper: "FFFFFF"),
                                              SigPalette("Black Lab", bg: "111111", ink: "F2F2F2", accent: "00B3A4", muted: "A8A8A8", paper: "F2F2F2"),
                                              SigPalette("Cobalt", bg: "1A33B8", ink: "FFFFFF", accent: "FFD23F", muted: "C3CBF2", paper: "FFFFFF")],
                                   sample: SigSample(title: "The Divided Mind", subtitle: "On Doubt and Decision", author: "Leah Moradi", photo: "portrait")))

        // Deep Field: the universe full bleed, a wide display title floating in its dark sky (science).
        e = []
        e.append(.fill(.solid(.hex("000000")), .full))
        e.append(.photo(NRect(0, 0.36, 1, 0.64), clip: nil, look: .natural, focusY: 0.5, zoom: 1, index: 0, fallback: .material("mat.nebula.palette.b")))
        e.append(.scrim(NRect(0, 0.36, 1, 0.12), .hex("000000"), angle: 270, strength: 0.9))
        e.append(.scrim(NRect(0, 0.78, 1, 0.22), .hex("000000"), angle: 90, strength: 0.6))
        e.append(.text(.title, NRect(0.07, 0.08, 0.86, 0.22), SigType(["Syne-ExtraBold"], color: .paper, tracking: 0.02, lineHeight: 0.92, breaks: .lines(2))))
        e.append(.text(.subtitle, NRect(0.1, 0.32, 0.8, 0.022), SigType(["JosefinSans-Bold"], color: .accent, tracking: 0.2)))
        e.append(.text(.author, NRect(0.15, 0.9, 0.7, 0.032), SigType(["JosefinSans-Bold"], color: .paper, tracking: 0.35)))
        out.append(SignatureDesign(id: "nonfiction-deep-field", name: "Deep Field", genre: .nonfiction,
                                   idea: "The universe runs full bleed and a wide display title floats in its darkest sky, like a narrative science bestseller.",
                                   tags: ["photo", "dark", "epic", "modern", "science"], elements: e,
                                   palettes: [SigPalette("Deep Field", bg: "05070D", ink: "05070D", accent: "F2B84B", muted: "8A93A8", paper: "F4F2EC"),
                                              SigPalette("Ice Blue", bg: "050A12", ink: "050A12", accent: "8FD3FF", muted: "8796A8", paper: "F2F6FA"),
                                              SigPalette("Signal Red", bg: "0A0606", ink: "0A0606", accent: "FF6A5C", muted: "A08E8C", paper: "F6F1EE")],
                                   sample: SigSample(title: "The Edge of Everything", subtitle: "How We Learned the Shape of Time", author: "Ana Lindqvist", photo: "space")))

        // Museum Plate: the image hangs in a hairline frame like an archive print; capitals above, caption below (history).
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.title, NRect(0.07, 0.06, 0.86, 0.17), SigType(["Cinzel-Bold"], tracking: 0.04, breaks: .lines(2))))
        e.append(.shape(.frame, NRect(0.1, 0.26, 0.8, 0.5), .ink, stroke: 0.003, rotation: 0))
        e.append(.photo(NRect(0.125, 0.276, 0.75, 0.468), clip: nil, look: .sepia, focusY: 0.5, zoom: 1, index: 0, fallback: .material("mat.topo.palette.f")))
        e.append(.text(.subtitle, NRect(0.08, 0.785, 0.84, 0.03), SigType(["CormorantGaramond-MediumItalic"], letterCase: .asTyped)))
        e.append(.shape(.rule, NRect(0.45, 0.84, 0.1, 0.002), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.2, 0.87, 0.6, 0.032), SigType(["Cinzel-Regular"], tracking: 0.2)))
        out.append(SignatureDesign(id: "nonfiction-museum-plate", name: "Museum Plate", genre: .nonfiction,
                                   idea: "The image hangs in a hairline frame like an archive print, with engraved capitals above and an italic caption below.",
                                   tags: ["photo", "light", "classic", "vintage", "history"], elements: e,
                                   palettes: [SigPalette("Parchment", bg: "EDE3CC", ink: "2A1E12", accent: "8C2F1C", muted: "6B5A43", paper: "F7F0DF"),
                                              SigPalette("Archive Green", bg: "1E2B24", ink: "EDE3CC", accent: "C29B57", muted: "8A9A8C", paper: "EDE3CC"),
                                              SigPalette("Admiralty", bg: "1B2235", ink: "EEE6D3", accent: "B8893F", muted: "7D8499", paper: "EEE6D3")],
                                   sample: SigSample(title: "The Last Map of Empire", subtitle: "Cartographers, Spies, and the Race for a Continent", author: "Edmund Hale", photo: "landscape")))

        // Contour: a survey map ground, a summit marker, and the title in a solid block (exploration).
        e = []
        e.append(.fill(.material("mat.topo.palette.f"), .full))
        e.append(.shape(.triangle, NRect(0.47, 0.24, 0.06, 0.03), .accent, stroke: 0, rotation: 0))
        e.append(.fill(.solid(.ink), NRect(0.07, 0.29, 0.86, 0.36)))
        e.append(.text(.title, NRect(0.12, 0.33, 0.76, 0.28), SigType(["Oswald-Bold"], color: .paper, tracking: 0.02, lineHeight: 0.95, breaks: .stacked)))
        e.append(.text(.subtitle, NRect(0.07, 0.68, 0.86, 0.024), SigType(["Montserrat-Black"], tracking: 0.12)))
        e.append(.text(.author, NRect(0.15, 0.89, 0.7, 0.034), SigType(["Oswald-Bold"], tracking: 0.25)))
        out.append(SignatureDesign(id: "nonfiction-contour", name: "Contour", genre: .nonfiction,
                                   idea: "A field of survey contour lines with one small summit marker; the title is cut into a solid block like an expedition stamp.",
                                   tags: ["graphic", "light", "bold type", "adventure", "science"], elements: e,
                                   palettes: [SigPalette("Glacier", bg: "E6ECEF", ink: "0F2433", accent: "D9442B", muted: "8FA3B0", paper: "F7FAFB"),
                                              SigPalette("Desert Survey", bg: "E9DCC3", ink: "2B1D12", accent: "1F6F78", muted: "A68F6E", paper: "F7F0E2"),
                                              SigPalette("Moss", bg: "DDE3D3", ink: "1C2B1E", accent: "C8862A", muted: "8E9C86", paper: "F5F7F0")],
                                   sample: SigSample(title: "Into the White", subtitle: "A Winter on the Antarctic Ice", author: "Rowan Achebe")))

        // The Card: a self-help title set huge on a white card, laid on a cheerful ground.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.author, NRect(0.08, 0.05, 0.84, 0.032), SigType(["Montserrat-Black"], tracking: 0.2)))
        e.append(.shape(.roundedRect, NRect(0.08, 0.12, 0.84, 0.58), .paper, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.13, 0.16, 0.74, 0.5), SigType(["Montserrat-Black"], tracking: -0.02, lineHeight: 0.88, breaks: .stacked)))
        e.append(.text(.subtitle, NRect(0.08, 0.75, 0.84, 0.03), SigType(["JosefinSans-Bold"], tracking: 0.08)))
        out.append(SignatureDesign(id: "nonfiction-the-card", name: "The Card", genre: .nonfiction,
                                   idea: "A self-help promise set huge and stacked on a white card, laid on a cheerful flat ground like a note to yourself.",
                                   tags: ["typographic", "light", "bold type", "playful", "self-help"], elements: e,
                                   palettes: [SigPalette("Coral", bg: "FF7A59", ink: "141414", accent: "FFFFFF", muted: "5C2A1E", paper: "FFF6EE"),
                                              SigPalette("Sky", bg: "7CC6F5", ink: "0E1B2C", accent: "FFFFFF", muted: "234060", paper: "FFFFFF"),
                                              SigPalette("Lilac", bg: "C9B6F2", ink: "1E1430", accent: "FFFFFF", muted: "4A3A70", paper: "FFFFFF")],
                                   sample: SigSample(title: "You Are Not Behind", subtitle: "A Field Guide to Your Own Pace", author: "Jess Moreau")))

        // Dawn: a half sun rises from the bottom edge beneath a calm lowercase title (self-help).
        e = []
        e.append(.fill(.linear(.paper, .bg, 90), .full))
        e.append(.text(.title, NRect(0.1, 0.15, 0.8, 0.3), SigType(["DMSerifDisplay-Regular"], letterCase: .lower, tracking: -0.01, lineHeight: 0.88, breaks: .stacked)))
        e.append(.text(.subtitle, NRect(0.12, 0.49, 0.76, 0.028), SigType(["CormorantGaramond-MediumItalic"], letterCase: .asTyped)))
        e.append(.shape(.ellipse, NRect(0.2, 0.7, 0.6, 0.375), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.28, 0.86, 0.44, 0.026), SigType(["JosefinSans-Bold"], color: .paper, tracking: 0.3)))
        out.append(SignatureDesign(id: "nonfiction-dawn", name: "Dawn", genre: .nonfiction,
                                   idea: "A half sun rises from the bottom edge into a soft morning gradient, beneath a calm lowercase serif title.",
                                   tags: ["graphic", "light", "calm", "minimal", "self-help"], elements: e,
                                   palettes: [SigPalette("Peach Dawn", bg: "F6D9C4", ink: "2E1A14", accent: "A83E22", muted: "8A6A5C", paper: "FFF5EC"),
                                              SigPalette("Sage Morning", bg: "D8E3D3", ink: "1C2A20", accent: "2F5A3E", muted: "6F8273", paper: "F5F8F2"),
                                              SigPalette("Lavender Dusk", bg: "E2DAEC", ink: "2A2140", accent: "4B3A7A", muted: "7E7494", paper: "F7F4FB")],
                                   sample: SigSample(title: "Begin Again", subtitle: "Gentle Practices for a Fresh Start", author: "Hana Oduya")))

        // Field Note: a calm landscape full bleed, the title on a paper card pinned to its lower left (self-help).
        e = []
        e.append(.photo(.full, clip: nil, look: .natural, focusY: 0.5, zoom: 1.1, index: 0, fallback: .watercolor([.accent, .muted, .bg])))
        e.append(.fill(.solid(.paper), NRect(0.07, 0.52, 0.66, 0.41)))
        e.append(.text(.title, NRect(0.11, 0.56, 0.58, 0.22), SigType(["PlayfairDisplay-Bold"], letterCase: .asTyped, tracking: -0.01, lineHeight: 0.95, align: .left, breaks: .stacked)))
        e.append(.shape(.rule, NRect(0.11, 0.8, 0.08, 0.003), .accent, stroke: 0, rotation: 0))
        e.append(.text(.subtitle, NRect(0.11, 0.82, 0.58, 0.022), SigType(["CormorantGaramond-MediumItalic"], color: .muted, letterCase: .asTyped, align: .left)))
        e.append(.text(.author, NRect(0.11, 0.87, 0.58, 0.028), SigType(["JosefinSans-Bold"], tracking: 0.25, align: .left)))
        out.append(SignatureDesign(id: "nonfiction-field-note", name: "Field Note", genre: .nonfiction,
                                   idea: "A calm landscape runs full bleed and the title sits on a plain paper card pinned to its lower left, like a note left on the view.",
                                   tags: ["photo", "light", "calm", "elegant", "self-help"], elements: e,
                                   palettes: [SigPalette("Oat", bg: "D9CDB6", ink: "1F2421", accent: "B5643C", muted: "6F6A60", paper: "FAF6EE"),
                                              SigPalette("Fog", bg: "C7CFD4", ink: "18222B", accent: "5E8C7B", muted: "66717A", paper: "F5F7F8"),
                                              SigPalette("Clay", bg: "D7B9A6", ink: "2B1B16", accent: "8A3D2A", muted: "7A5E52", paper: "FBF4EE")],
                                   sample: SigSample(title: "The Quiet Hours", subtitle: "Rituals for a Slower, Kinder Life", author: "Elise Marchetti", photo: "landscape")))

        return out
    }
}
