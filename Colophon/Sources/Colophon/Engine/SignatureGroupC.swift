import Foundation

// MARK: - Signature group C: romance, cozy, young adult

extension SignatureLibrary {
    static var groupC: [SignatureDesign] {
        var out: [SignatureDesign] = []
        var e: [SigElement] = []

        // MARK: Romance

        // 1. Blade & Ring (romantasy): a ring pierced by a slender blade, built from three shapes.
        e = []
        e.append(.fill(.material("mat.smoke.palette.f"), .full))
        e.append(.shape(.ellipse, NRect(0.2, 0.14, 0.6, 0.375), .accent, stroke: 0.004, rotation: 0))
        e.append(.shape(.diamond, NRect(0.465, 0.07, 0.07, 0.52), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.39, 0.175, 0.22, 0.007), .accent, stroke: 0, rotation: 0))
        e.append(.text(.seriesOr("BOOK ONE"), NRect(0.2, 0.62, 0.6, 0.02), SigType(["Montserrat-Black"], color: .accent, tracking: 0.4)))
        e.append(.text(.title, NRect(0.07, 0.655, 0.86, 0.19), SigType(["Cinzel-Bold"], color: .ink, tracking: 0.04, lineHeight: 0.95, breaks: .lines(2), gradientTo: .accent)))
        e.append(.text(.author, NRect(0.15, 0.9, 0.7, 0.03), SigType(["Cinzel-Regular"], color: .ink, tracking: 0.2)))
        out.append(SignatureDesign(id: "romance-blade-and-ring", name: "Blade & Ring", genre: .romance,
                                   idea: "A slender blade pierces a thin gold ring: love and violence in one romantasy emblem, floating in smoke.",
                                   tags: ["graphic", "dark", "romantasy", "elegant", "epic", "minimal"], elements: e,
                                   palettes: [SigPalette("Obsidian & Gilt", bg: "0E0B12", ink: "F3E6C8", accent: "C9A24B", muted: "4A3F55", paper: "F7EFDC"),
                                              SigPalette("Wine & Brass", bg: "2A0A12", ink: "F4E4CF", accent: "D4A055", muted: "6B2A36", paper: "FAF0E2"),
                                              SigPalette("Midnight & Frost", bg: "0A1424", ink: "E8F0F7", accent: "9FC3E0", muted: "2E4562", paper: "F2F6FA")],
                                   sample: SigSample(title: "A Crown of Quiet Knives", author: "Seraphine Vale", series: "The Thornbound Court")))

        // 2. Ember Arch (romantasy): a duotone portrait seen through a tall cathedral arch, doubled by a fine gold line.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0.14, 0.07, 0.72, 0.56), clip: .arch, look: .duotone(.bg, .accent), focusY: 0.3, zoom: 1.1, index: 0, fallback: .material("mat.nebula.palette.b")))
        e.append(.shape(.arch, NRect(0.12, 0.055, 0.76, 0.585), .accent, stroke: 0.003, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.67, 0.86, 0.16), SigType(["CinzelDecorative-Bold"], color: .ink, tracking: 0.02, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.shape(.diamond, NRect(0.485, 0.845, 0.03, 0.019), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.15, 0.88, 0.7, 0.035), SigType(["CormorantGaramond-SemiBold"], color: .ink, tracking: 0.25)))
        out.append(SignatureDesign(id: "romance-ember-arch", name: "Ember Arch", genre: .romance,
                                   idea: "A duotone portrait glows through a tall arch window, its edge echoed by a hairline of gold, like a fae court's doorway.",
                                   tags: ["photo", "dark", "romantasy", "elegant", "atmospheric", "romantic"], elements: e,
                                   palettes: [SigPalette("Ember & Ash", bg: "160C0A", ink: "F6E3C6", accent: "E0663A", muted: "5A2A1E", paper: "FBEFDD"),
                                              SigPalette("Fae Teal", bg: "07191A", ink: "E6F2EA", accent: "4FC1A6", muted: "1F4A47", paper: "F1F7F2"),
                                              SigPalette("Rose Night", bg: "1A0E1C", ink: "F5E1E8", accent: "D9809B", muted: "4C2A47", paper: "FAEFF2")],
                                   sample: SigSample(title: "Court of Embers", author: "Lyra Ashdown", photo: "portrait")))

        // 3. Venn (contemporary rom-com): two overlapping circles, two people; the overlap is the story.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.author, NRect(0.1, 0.06, 0.8, 0.035), SigType(["Montserrat-Black"], color: .ink, tracking: 0.25)))
        e.append(.shape(.ellipse, NRect(0.1, 0.17, 0.52, 0.325), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.38, 0.3, 0.52, 0.325), .alpha(.muted, 0.85), stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.65, 0.86, 0.19), SigType(["DMSerifDisplay-Italic"], color: .ink, letterCase: .asTyped, lineHeight: 0.9, breaks: .lines(2))))
        e.append(.text(.tagline, NRect(0.1, 0.885, 0.8, 0.022), SigType(["JosefinSans-Bold"], color: .ink, tracking: 0.2)))
        out.append(SignatureDesign(id: "romance-venn", name: "Venn", genre: .romance,
                                   idea: "Two flat circles drift into each other; where they overlap a third color appears, which is the whole rom-com in one diagram.",
                                   tags: ["graphic", "light", "rom-com", "playful", "modern", "romantic"], elements: e,
                                   palettes: [SigPalette("Bubblegum & Tomato", bg: "FCE9E2", ink: "1F1A3A", accent: "F0533F", muted: "F28AB0", paper: "FFF8F4"),
                                              SigPalette("Mint & Coral", bg: "E4F3EC", ink: "13322C", accent: "FF7A59", muted: "5FC4A6", paper: "F8FFFB"),
                                              SigPalette("Butter & Cobalt", bg: "FBF1C9", ink: "172554", accent: "2F5BEA", muted: "F7B538", paper: "FFFBEA")],
                                   sample: SigSample(title: "Accidentally Yours, Probably", author: "Jules Marchetti", tagline: "Two plus-ones. One wedding. Zero chill.")))

        // 4. Postcard (contemporary rom-com): a sunlit view framed like a holiday postcard, a postmark ring stamped on its corner.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.title, NRect(0.07, 0.06, 0.86, 0.24), SigType(["Fraunces-Black"], color: .ink, letterCase: .title, tracking: -0.01, lineHeight: 0.88, breaks: .lines(2))))
        e.append(.photo(NRect(0.08, 0.34, 0.84, 0.42), clip: .roundedRect, look: .natural, focusY: 0.5, zoom: 1, index: 0, fallback: .watercolor([.accent, .muted])))
        e.append(.shape(.ellipse, NRect(0.68, 0.3, 0.22, 0.1375), .accent, stroke: 0.004, rotation: -12))
        e.append(.text(.author, NRect(0.08, 0.81, 0.84, 0.045), SigType(["Montserrat-Black"], color: .ink, tracking: 0.12)))
        e.append(.text(.tagline, NRect(0.08, 0.88, 0.84, 0.022), SigType(["JosefinSans-Bold"], color: .muted, tracking: 0.2)))
        out.append(SignatureDesign(id: "romance-postcard", name: "Postcard", genre: .romance,
                                   idea: "The photo is a holiday postcard with rounded corners and a stamped postmark ring; a chunky soft serif title sits above like handwriting on the back.",
                                   tags: ["photo", "light", "rom-com", "summer", "playful", "bold type"], elements: e,
                                   palettes: [SigPalette("Riviera", bg: "F6EFE3", ink: "0F2E4C", accent: "E14B3B", muted: "56677A", paper: "FFFFFF"),
                                              SigPalette("Lemon Grove", bg: "FFF3C4", ink: "1E3A2B", accent: "D9881A", muted: "55633F", paper: "FFFDF3"),
                                              SigPalette("Coral Night", bg: "102A43", ink: "FFF1E6", accent: "FF7F66", muted: "A9B8C6", paper: "FFFFFF")],
                                   sample: SigSample(title: "The Summer I Said Yes", author: "Daisy Okafor", tagline: "Out of office. Into trouble.", photo: "landscape")))

        // 5. Cameo (Regency): an oval portrait cameo in a hairline gold ring, inside a fine double border on linen.
        e = []
        e.append(.fill(.material("mat.linen.palette.f"), .full))
        e.append(.decor("double square fine inset", .border, .full, .accent))
        e.append(.shape(.ellipse, NRect(0.2, 0.09, 0.6, 0.47), .accent, stroke: 0.003, rotation: 0))
        e.append(.photo(NRect(0.23, 0.11, 0.54, 0.43), clip: .ellipse, look: .natural, focusY: 0.25, zoom: 1.15, index: 0, fallback: .watercolor([.muted, .accent])))
        e.append(.text(.seriesOr("A REGENCY ROMANCE"), NRect(0.15, 0.6, 0.7, 0.02), SigType(["Cinzel-Regular"], color: .accent, tracking: 0.3)))
        e.append(.text(.title, NRect(0.08, 0.63, 0.84, 0.2), SigType(["CormorantGaramond-MediumItalic"], color: .ink, letterCase: .title, lineHeight: 0.9, breaks: .lines(2))))
        e.append(.shape(.rule, NRect(0.42, 0.85, 0.16, 0.002), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.15, 0.87, 0.7, 0.035), SigType(["Cinzel-Regular"], color: .ink, tracking: 0.2)))
        out.append(SignatureDesign(id: "romance-cameo", name: "Cameo", genre: .romance,
                                   idea: "A portrait set like a Regency cameo: an oval crop in a hairline gold ring, with a swooning italic title beneath.",
                                   tags: ["photo", "light", "regency", "historical", "elegant", "vintage", "romantic"], elements: e,
                                   palettes: [SigPalette("Duck Egg & Gilt", bg: "DCE6E4", ink: "1E2B3A", accent: "8F6A2E", muted: "8BA3A3", paper: "F4F1EA"),
                                              SigPalette("Blush & Claret", bg: "F2E1DC", ink: "3A1420", accent: "8E2F45", muted: "C99A9E", paper: "FBF5F2"),
                                              SigPalette("Ivory & Ink", bg: "EFE7D6", ink: "191919", accent: "7A5C2E", muted: "9C9078", paper: "FAF6EC")],
                                   sample: SigSample(title: "The Duke Who Wrote Back", author: "Henrietta Lisle", series: "The Ashcombe Letters", photo: "portrait")))

        // 6. Silk Hem (historical romance): a full portrait above, a solid band of silk color below, trimmed in gold.
        e = []
        e.append(.photo(NRect(0, 0, 1, 0.7), clip: nil, look: .natural, focusY: 0.2, zoom: 1, index: 0, fallback: .watercolor([.accent, .muted, .bg])))
        e.append(.fill(.solid(.bg), NRect(0, 0.66, 1, 0.34)))
        e.append(.shape(.rectangle, NRect(0, 0.66, 1, 0.006), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.69, 0.86, 0.16), SigType(["BodoniModa-Bold"], color: .ink, letterCase: .title, lineHeight: 0.92, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.07, 0.875, 0.86, 0.03), SigType(["JosefinSans-Bold"], color: .accent, tracking: 0.3)))
        e.append(.text(.tagline, NRect(0.07, 0.92, 0.86, 0.024), SigType(["CormorantGaramond-MediumItalic"], color: .muted, letterCase: .asTyped)))
        out.append(SignatureDesign(id: "romance-silk-hem", name: "Silk Hem", genre: .romance,
                                   idea: "A painted portrait fills the top two-thirds; a solid band of jewel-toned silk, edged with a gold trim line, carries the type like a gown's hem.",
                                   tags: ["photo", "dark", "historical", "elegant", "romantic", "classic"], elements: e,
                                   palettes: [SigPalette("Sapphire Silk", bg: "14234A", ink: "F6EEDC", accent: "D8B26E", muted: "9DA9C6", paper: "FBF6EA"),
                                              SigPalette("Emerald", bg: "0F3B2E", ink: "F3EBD7", accent: "CFAE6A", muted: "8FB3A2", paper: "FAF5E8"),
                                              SigPalette("Claret", bg: "4A0F1E", ink: "F8EADB", accent: "E0B07A", muted: "C9979E", paper: "FCF3EA")],
                                   sample: SigSample(title: "A Season of Scandal", author: "Clementine Harrow", tagline: "She was never meant to be seen.", photo: "portrait")))

        // 7. Slash (dark romance): one blood-red line cuts diagonally through a hushed, stacked title.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.seriesOr("A DARK ROMANCE"), NRect(0.2, 0.08, 0.6, 0.02), SigType(["Montserrat-Black"], color: .muted, tracking: 0.45)))
        e.append(.text(.title, NRect(0.08, 0.28, 0.84, 0.33), SigType(["BodoniModa-Black"], color: .ink, tracking: 0.02, lineHeight: 0.86, breaks: .stacked)))
        e.append(.shape(.rule, NRect(-0.1, 0.44, 1.2, 0.007), .accent, stroke: 0, rotation: -32))
        e.append(.text(.tagline, NRect(0.1, 0.82, 0.8, 0.024), SigType(["CormorantGaramond-MediumItalic"], color: .muted, letterCase: .asTyped)))
        e.append(.text(.author, NRect(0.1, 0.88, 0.8, 0.035), SigType(["Montserrat-Black"], color: .ink, tracking: 0.35)))
        out.append(SignatureDesign(id: "romance-slash", name: "Slash", genre: .romance,
                                   idea: "A single blood-red hairline slices diagonally across a stacked high-contrast serif title on near-black; nothing else.",
                                   tags: ["typographic", "dark", "dark romance", "minimal", "moody", "bold type"], elements: e,
                                   palettes: [SigPalette("Black & Blood", bg: "0A0A0B", ink: "EDE6DA", accent: "B3121E", muted: "8C8780", paper: "F4EFE6"),
                                              SigPalette("Black & Absinthe", bg: "090B09", ink: "E8EEDF", accent: "9BC53D", muted: "7E8676", paper: "F2F5EC"),
                                              SigPalette("Bone & Black", bg: "E9E3D8", ink: "0D0D0D", accent: "8A0E18", muted: "5E5850", paper: "F6F2EA")],
                                   sample: SigSample(title: "Vow of Ruin", author: "Raven Castell", tagline: "He swore to destroy me. Then he swore to keep me.")))

        // 8. Slit (dark romance): the photo is glimpsed only through a narrow vertical slit in black.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0.36, 0, 0.28, 0.8), clip: nil, look: .stark, focusY: 0.35, zoom: 1.2, index: 0, fallback: .material("mat.smoke.charcoal.b")))
        e.append(.text(.title, NRect(0.04, 0.41, 0.92, 0.17), SigType(["PlayfairDisplay-Black"], color: .paper, tracking: 0.08, breaks: .oneLine, shadow: true)))
        e.append(.shape(.rectangle, NRect(0.45, 0.845, 0.1, 0.004), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.15, 0.88, 0.7, 0.035), SigType(["Montserrat-Black"], color: .paper, tracking: 0.4)))
        e.append(.text(.tagline, NRect(0.1, 0.93, 0.8, 0.02), SigType(["Montserrat-Black"], color: .muted, tracking: 0.25)))
        out.append(SignatureDesign(id: "romance-slit", name: "Slit", genre: .romance,
                                   idea: "The photo is only glimpsed through a narrow vertical slit in black, like a door left ajar; the title is laid across it in white.",
                                   tags: ["photo", "dark", "dark romance", "minimal", "moody", "cinematic"], elements: e,
                                   palettes: [SigPalette("Noir & Crimson", bg: "000000", ink: "F2EEE8", accent: "C2141F", muted: "8A8A8A", paper: "F2EEE8"),
                                              SigPalette("Noir & Violet", bg: "07060A", ink: "EFEAF5", accent: "8A4FFF", muted: "85808F", paper: "EFEAF5"),
                                              SigPalette("Smoke & Gold", bg: "121212", ink: "F1E9D8", accent: "C9A24B", muted: "8C877D", paper: "F1E9D8")],
                                   sample: SigSample(title: "Hush", author: "Delphine Marsh", tagline: "Don't make a sound", photo: "portrait")))

        // 9. Wildflower Wash (sweet romance): a soft watercolor wash blooms over the top; a gentle serif title below.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.fill(.watercolor([.accent, .muted]), NRect(0, 0, 1, 0.58)))
        e.append(.text(.title, NRect(0.08, 0.61, 0.84, 0.19), SigType(["DMSerifDisplay-Regular"], color: .ink, letterCase: .title, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.decor("leaf", .divider, NRect(0.3, 0.815, 0.4, 0.03), .accent))
        e.append(.text(.author, NRect(0.15, 0.86, 0.7, 0.035), SigType(["JosefinSans-Bold"], color: .ink, tracking: 0.25)))
        e.append(.text(.tagline, NRect(0.1, 0.915, 0.8, 0.022), SigType(["CormorantGaramond-MediumItalic"], color: .ink, letterCase: .asTyped, opacity: 0.75)))
        out.append(SignatureDesign(id: "romance-wildflower-wash", name: "Wildflower Wash", genre: .romance,
                                   idea: "A loose wet-in-wet wash of field colors blooms over the top half and fades into cream paper, where a soft serif title waits.",
                                   tags: ["painted", "light", "sweet", "soft", "romantic", "gentle"], elements: e,
                                   palettes: [SigPalette("Lavender Field", bg: "F7F3EC", ink: "2F2A45", accent: "A78BCB", muted: "8FA889", paper: "FFFDF8"),
                                              SigPalette("Peach Orchard", bg: "FBF3EA", ink: "3D2A22", accent: "F2A07B", muted: "A7C4A0", paper: "FFFCF7"),
                                              SigPalette("Seaglass", bg: "F2F5F2", ink: "1E3A40", accent: "7FB7BE", muted: "E5B8A0", paper: "FFFFFF")],
                                   sample: SigSample(title: "Home by Lavender Lane", author: "Molly Ashby", tagline: "Some roads always lead you back.")))

        // MARK: Cozy

        // 10. Awning (cozy mystery): a striped shop awning with a scalloped edge crowns the cover.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.fill(.material("mat.stripes.palette.b"), NRect(0, 0, 1, 0.14)))
        e.append(.shape(.ellipse, NRect(0, 0.11, 0.167, 0.06), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.167, 0.11, 0.167, 0.06), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.333, 0.11, 0.167, 0.06), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.5, 0.11, 0.167, 0.06), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.667, 0.11, 0.167, 0.06), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.833, 0.11, 0.167, 0.06), .accent, stroke: 0, rotation: 0))
        e.append(.text(.seriesOr("A TEA SHOP MYSTERY"), NRect(0.12, 0.25, 0.76, 0.022), SigType(["Montserrat-Black"], color: .accent, tracking: 0.3, flourish: .rules)))
        e.append(.text(.title, NRect(0.08, 0.3, 0.84, 0.38), SigType(["Fraunces-Black"], color: .ink, letterCase: .title, lineHeight: 0.9, breaks: .stacked)))
        e.append(.decor("fleuron", .divider, NRect(0.3, 0.71, 0.4, 0.035), .accent))
        e.append(.text(.author, NRect(0.1, 0.86, 0.8, 0.04), SigType(["JosefinSans-Bold"], color: .ink, tracking: 0.2)))
        out.append(SignatureDesign(id: "cozy-awning", name: "Awning", genre: .cozy,
                                   idea: "A striped shop awning with a scalloped edge crowns the cover, so the whole book becomes the shopfront; a warm soft serif title stacks below.",
                                   tags: ["graphic", "light", "cozy mystery", "charming", "playful", "vintage"], elements: e,
                                   palettes: [SigPalette("Mint Parlour", bg: "F3EEE1", ink: "23324A", accent: "3F8A77", muted: "B9D6C9", paper: "FFFDF6"),
                                              SigPalette("Raspberry", bg: "FBF0EA", ink: "3B1F2B", accent: "C8435A", muted: "F2C4C9", paper: "FFFFFF"),
                                              SigPalette("Butterscotch", bg: "F6EEDB", ink: "2E2A24", accent: "C27A1E", muted: "EAD3A8", paper: "FFFDF5")],
                                   sample: SigSample(title: "Death by Darjeeling", author: "Penelope Finch", series: "A Tea Shop Mystery")))

        // 11. Magnifier (cozy mystery): the photo is seen through a magnifying glass built from a ring and a handle.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.title, NRect(0.08, 0.05, 0.84, 0.2), SigType(["PlayfairDisplay-Bold"], color: .ink, letterCase: .title, lineHeight: 0.92, breaks: .lines(2))))
        e.append(.shape(.roundedRect, NRect(0.739, 0.584, 0.08, 0.167), .ink, stroke: 0, rotation: -45))
        e.append(.photo(NRect(0.16, 0.28, 0.6, 0.375), clip: .ellipse, look: .natural, focusY: 0.5, zoom: 1.3, index: 0, fallback: .watercolor([.accent, .muted])))
        e.append(.shape(.ellipse, NRect(0.15, 0.274, 0.62, 0.3875), .ink, stroke: 0.012, rotation: 0))
        e.append(.text(.author, NRect(0.1, 0.82, 0.8, 0.04), SigType(["JosefinSans-Bold"], color: .ink, tracking: 0.25)))
        e.append(.text(.seriesOr("A VILLAGE MYSTERY"), NRect(0.15, 0.885, 0.7, 0.02), SigType(["Montserrat-Black"], color: .accent, tracking: 0.3)))
        out.append(SignatureDesign(id: "cozy-magnifier", name: "Magnifier", genre: .cozy,
                                   idea: "A round lens and a stout handle turn the photo into a view through a detective's magnifying glass, set on a quiet flat ground.",
                                   tags: ["photo", "light", "cozy mystery", "charming", "classic", "playful"], elements: e,
                                   palettes: [SigPalette("Hedgerow", bg: "EDE6D3", ink: "2A3B2E", accent: "A34A28", muted: "8A9A7B", paper: "FAF7EE"),
                                              SigPalette("Duck Blue", bg: "DDE7EA", ink: "15303D", accent: "A8601F", muted: "7E9AA3", paper: "F6FAFB"),
                                              SigPalette("Plum Jam", bg: "F1E6E6", ink: "3A1E33", accent: "2F7A6B", muted: "B49AA8", paper: "FCF8F8")],
                                   sample: SigSample(title: "The Body in the Bluebells", author: "Harriet Pell", series: "A Little Wickham Mystery", photo: "landscape")))

        // 12. Jam Label (cozy mystery): an oval preserves label on gingham; the title is lettered inside it.
        e = []
        e.append(.fill(.material("mat.checker.palette.f"), .full))
        e.append(.shape(.ellipse, NRect(0.09, 0.25, 0.82, 0.5), .paper, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.115, 0.265, 0.77, 0.47), .accent, stroke: 0.004, rotation: 0))
        e.append(.text(.seriesOr("A PANTRY MYSTERY"), NRect(0.25, 0.34, 0.5, 0.02), SigType(["Montserrat-Black"], color: .accent, tracking: 0.3)))
        e.append(.text(.title, NRect(0.17, 0.38, 0.66, 0.24), SigType(["Fraunces-Black"], color: .ink, letterCase: .title, lineHeight: 0.9, breaks: .lines(3))))
        e.append(.text(.author, NRect(0.25, 0.64, 0.5, 0.03), SigType(["JosefinSans-Bold"], color: .ink, tracking: 0.2)))
        out.append(SignatureDesign(id: "cozy-jam-label", name: "Jam Label", genre: .cozy,
                                   idea: "The cover is a jar of preserves: a cream oval label with a fine inner line sits on gingham, and the title is lettered on it like a homemade label.",
                                   tags: ["graphic", "light", "cozy mystery", "charming", "vintage", "playful"], elements: e,
                                   palettes: [SigPalette("Strawberry Gingham", bg: "F4D9D6", ink: "4A1621", accent: "B8323E", muted: "E8AFAF", paper: "FFFBF5"),
                                              SigPalette("Blueberry", bg: "D6DFEE", ink: "1C2747", accent: "3F5BA9", muted: "A9B9D9", paper: "FFFDF8"),
                                              SigPalette("Greengage", bg: "DCE6CC", ink: "26361E", accent: "557A2A", muted: "B8C99B", paper: "FFFDF4")],
                                   sample: SigSample(title: "Murder at the Marmalade Fair", author: "Rosie Quill", series: "A Pantry Mystery")))

        // 13. Garden Panel (cozy mystery): a tall garden painting panel at right, the title stacked in a cream left column.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0.5, 0.05, 0.44, 0.9), clip: .roundedRect, look: .natural, focusY: 0.5, zoom: 1.2, index: 0, fallback: .watercolor([.accent, .muted])))
        e.append(.text(.seriesOr("A GARDEN MYSTERY"), NRect(0.07, 0.07, 0.38, 0.018), SigType(["Montserrat-Black"], color: .accent, tracking: 0.25, align: .left)))
        e.append(.text(.title, NRect(0.065, 0.11, 0.4, 0.34), SigType(["DMSerifDisplay-Regular"], color: .ink, letterCase: .title, lineHeight: 0.9, align: .left, breaks: .stacked)))
        e.append(.shape(.rectangle, NRect(0.07, 0.48, 0.12, 0.003), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.07, 0.885, 0.38, 0.028), SigType(["JosefinSans-Bold"], color: .ink, tracking: 0.12, align: .left)))
        out.append(SignatureDesign(id: "cozy-garden-panel", name: "Garden Panel", genre: .cozy,
                                   idea: "Split like a seed packet: a tall rounded panel of garden painting on the right, the title stacked down a quiet cream column on the left.",
                                   tags: ["photo", "light", "cozy mystery", "botanical", "elegant", "asymmetric"], elements: e,
                                   palettes: [SigPalette("Potting Shed", bg: "EFE8DA", ink: "233127", accent: "A0412D", muted: "7D8C6E", paper: "FBF8F1"),
                                              SigPalette("Foxglove", bg: "F3E9EE", ink: "34203A", accent: "8E3B76", muted: "A890A6", paper: "FDF9FB"),
                                              SigPalette("Night Garden", bg: "1B2620", ink: "EFE8DA", accent: "D9A441", muted: "6E8172", paper: "F5F1E6")],
                                   sample: SigSample(title: "Poison & Petals", author: "Lavinia Brooke", series: "A Garden Club Mystery", photo: "landscape")))

        // 14. Hearth (cozy fantasy): a glowing hearth arch with a little flame, sparks drifting up toward the title.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.fill(.radial(.alpha(.accent, 0.55), .bg), NRect(0.05, 0.32, 0.9, 0.56)))
        e.append(.shape(.arch, NRect(0.22, 0.4, 0.56, 0.44), .accent, stroke: 0.004, rotation: 0))
        e.append(.shape(.diamond, NRect(0.44, 0.64, 0.12, 0.17), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.diamond, NRect(0.475, 0.7, 0.05, 0.1), .paper, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.14, 0.838, 0.72, 0.004), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.diamond, NRect(0.3, 0.46, 0.018, 0.018), .paper, stroke: 0, rotation: 0))
        e.append(.shape(.diamond, NRect(0.66, 0.42, 0.022, 0.022), .paper, stroke: 0, rotation: 0))
        e.append(.shape(.diamond, NRect(0.56, 0.36, 0.014, 0.014), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.07, 0.86, 0.21), SigType(["Fraunces-Black"], color: .ink, letterCase: .title, lineHeight: 0.9, breaks: .lines(2))))
        e.append(.text(.seriesOr("A COZY FANTASY"), NRect(0.15, 0.3, 0.7, 0.02), SigType(["JosefinSans-Bold"], color: .accent, tracking: 0.3)))
        e.append(.text(.author, NRect(0.1, 0.89, 0.8, 0.035), SigType(["JosefinSans-Bold"], color: .ink, tracking: 0.25)))
        out.append(SignatureDesign(id: "cozy-hearth", name: "Hearth", genre: .cozy,
                                   idea: "A hearth arch drawn in one warm line holds a tiny two-tone flame, its glow and a few drifting sparks the only light on a dark ground.",
                                   tags: ["graphic", "dark", "cozy fantasy", "warm", "charming", "minimal"], elements: e,
                                   palettes: [SigPalette("Hearthlight", bg: "2A1A14", ink: "F7E7CC", accent: "F2A03D", muted: "6B3E2A", paper: "FFF4DE"),
                                              SigPalette("Mossy Den", bg: "1E2A20", ink: "F1ECD6", accent: "E7B65C", muted: "4C5E43", paper: "FFF8E6"),
                                              SigPalette("Dusk Plum", bg: "2B1A2E", ink: "F6E6DA", accent: "F08A5D", muted: "5E3A5C", paper: "FFF1E8")],
                                   sample: SigSample(title: "The Dragon Who Baked Bread", author: "Wren Hollowell", series: "Tales of the Copper Kettle")))

        // 15. Framed Print (cozy fantasy): a duotone landscape matted like a framed print, title lettered on the mat.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.title, NRect(0.08, 0.06, 0.84, 0.17), SigType(["Prata-Regular"], color: .ink, letterCase: .title, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.shape(.rectangle, NRect(0.085, 0.26, 0.83, 0.57), .accent, stroke: 0.003, rotation: 0))
        e.append(.photo(NRect(0.1, 0.27, 0.8, 0.55), clip: nil, look: .duotone(.ink, .paper), focusY: 0.5, zoom: 1, index: 0, fallback: .watercolor([.muted, .accent])))
        e.append(.text(.author, NRect(0.1, 0.865, 0.8, 0.032), SigType(["Cinzel-Regular"], color: .ink, tracking: 0.25)))
        e.append(.text(.series, NRect(0.2, 0.92, 0.6, 0.018), SigType(["JosefinSans-Bold"], color: .accent, tracking: 0.3)))
        out.append(SignatureDesign(id: "cozy-framed-print", name: "Framed Print", genre: .cozy,
                                   idea: "A landscape in a soft two-color duotone is matted and hairline-framed like a print hung in a cottage, the title lettered on the mat above.",
                                   tags: ["photo", "light", "cozy fantasy", "gentle", "elegant", "vintage"], elements: e,
                                   palettes: [SigPalette("Moss & Cream", bg: "EFEADB", ink: "24382B", accent: "8A5A2B", muted: "8FA383", paper: "FBF8EF"),
                                              SigPalette("Fog & Heather", bg: "E7E5EC", ink: "2E2840", accent: "7A5A8E", muted: "9E98B3", paper: "F9F8FB"),
                                              SigPalette("Honey & Pine", bg: "F3E8CF", ink: "1F3326", accent: "A8741F", muted: "A9B38F", paper: "FFFAEC")],
                                   sample: SigSample(title: "The Moss Witch of Hollow Fen", author: "Briony Tamsin", series: "The Hollow Fen Tales", photo: "landscape")))

        // 16. Crescent (cozy fantasy): a crescent moon cut from two circles over a charming lowercase title.
        e = []
        e.append(.fill(.material("mat.stars.palette.f"), .full))
        e.append(.shape(.ellipse, NRect(0.3, 0.1, 0.4, 0.25), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.38, 0.075, 0.4, 0.25), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.diamond, NRect(0.2, 0.3, 0.024, 0.015), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.diamond, NRect(0.78, 0.33, 0.018, 0.011), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.08, 0.42, 0.84, 0.3), SigType(["Fraunces-Black"], color: .ink, letterCase: .lower, lineHeight: 0.92, breaks: .lines(3))))
        e.append(.decor("star", .divider, NRect(0.3, 0.75, 0.4, 0.03), .accent))
        e.append(.text(.author, NRect(0.1, 0.88, 0.8, 0.035), SigType(["JosefinSans-Bold"], color: .ink, tracking: 0.3)))
        out.append(SignatureDesign(id: "cozy-crescent", name: "Crescent", genre: .cozy,
                                   idea: "A crescent moon is cut from two overlapping circles above a soft, lowercase title, like a witch's shop sign at dusk.",
                                   tags: ["graphic", "dark", "cozy fantasy", "whimsical", "charming", "celestial"], elements: e,
                                   palettes: [SigPalette("Plum Night", bg: "241A3A", ink: "F5EBDD", accent: "F2C36B", muted: "4C3D6B", paper: "FFF6E6"),
                                              SigPalette("Teal Night", bg: "0F2A2E", ink: "EFF2E6", accent: "F0B35A", muted: "2E5357", paper: "FAFBF3"),
                                              SigPalette("Rose Dusk", bg: "F3DDD6", ink: "2E1C33", accent: "B5476A", muted: "D8B2AE", paper: "FFF7F3")],
                                   sample: SigSample(title: "Tea & Trouble at Thistledown", author: "Mabel Featherstone")))

        // 17. Hanging Sign (cozy mystery): the title on a painted sign hanging from chains, the author on a smaller sign beneath.
        e = []
        e.append(.fill(.material("mat.woodgrain.palette.f"), .full))
        e.append(.shape(.rectangle, NRect(0.247, 0, 0.006, 0.125), .muted, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.747, 0, 0.006, 0.125), .muted, stroke: 0, rotation: 0))
        e.append(.shape(.roundedRect, NRect(0.1, 0.12, 0.8, 0.44), .paper, stroke: 0, rotation: 0))
        e.append(.shape(.roundedRect, NRect(0.125, 0.135, 0.75, 0.41), .accent, stroke: 0.004, rotation: 0))
        e.append(.text(.seriesOr("A CAFE MYSTERY"), NRect(0.2, 0.17, 0.6, 0.02), SigType(["Montserrat-Black"], color: .accent, tracking: 0.3)))
        e.append(.text(.title, NRect(0.15, 0.205, 0.7, 0.28), SigType(["PlayfairDisplay-Black"], color: .ink, letterCase: .title, lineHeight: 0.9, breaks: .lines(3))))
        e.append(.shape(.rectangle, NRect(0.42, 0.5, 0.16, 0.003), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.297, 0.56, 0.006, 0.1), .muted, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.697, 0.56, 0.006, 0.1), .muted, stroke: 0, rotation: 0))
        e.append(.shape(.roundedRect, NRect(0.22, 0.66, 0.56, 0.1), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.26, 0.692, 0.48, 0.036), SigType(["JosefinSans-Bold"], color: .paper, tracking: 0.15)))
        e.append(.text(.tagline, NRect(0.1, 0.86, 0.8, 0.026), SigType(["CormorantGaramond-MediumItalic"], color: .paper, letterCase: .asTyped, shadow: true)))
        out.append(SignatureDesign(id: "cozy-hanging-sign", name: "Hanging Sign", genre: .cozy,
                                   idea: "The title is painted on a cream shop sign hung by two chains against dark wood, with the author on a smaller sign swinging beneath it.",
                                   tags: ["graphic", "dark", "cozy mystery", "charming", "vintage", "warm"], elements: e,
                                   palettes: [SigPalette("Walnut & Ivory", bg: "4A3222", ink: "2B1D14", accent: "8C2F25", muted: "C9B59A", paper: "F6EEDC"),
                                              SigPalette("Painted Teal", bg: "2F4E4C", ink: "1D2B2A", accent: "A34A27", muted: "CFC6AE", paper: "F4EFE1"),
                                              SigPalette("Blackboard", bg: "26292B", ink: "1E1F20", accent: "2E6E5A", muted: "B8B2A4", paper: "F2EEE3")],
                                   sample: SigSample(title: "Closing Time at the Crooked Spoon", author: "Dorothy Mayhew", tagline: "The specials board just got a lot darker.")))

        // MARK: Young adult

        // 18. Bleed (YA): a neon duotone photo; the one-word title is so big it runs off both edges.
        e = []
        e.append(.photo(.full, clip: nil, look: .duotone(.bg, .accent), focusY: 0.35, zoom: 1, index: 0, fallback: .material("mat.halftone.palette.b")))
        e.append(.scrim(NRect(0, 0.45, 1, 0.55), .bg, angle: 90, strength: 0.9))
        e.append(.text(.author, NRect(0.08, 0.06, 0.84, 0.035), SigType(["Montserrat-Black"], color: .paper, tracking: 0.35, shadow: true)))
        e.append(.text(.title, NRect(-0.04, 0.6, 1.08, 0.26), SigType(["Anton-Regular"], color: .paper, tracking: -0.01, breaks: .oneLine)))
        e.append(.text(.tagline, NRect(0.1, 0.9, 0.8, 0.022), SigType(["Montserrat-Black"], color: .accent, tracking: 0.2)))
        out.append(SignatureDesign(id: "youngadult-bleed", name: "Bleed", genre: .youngAdult,
                                   idea: "A photo flooded with one neon duotone; the title is set so large it bleeds off both edges of the cover.",
                                   tags: ["photo", "dark", "bold type", "neon", "modern", "condensed"], elements: e,
                                   palettes: [SigPalette("Ultraviolet", bg: "1B0B3A", ink: "1B0B3A", accent: "FF3D9A", muted: "7A5CC2", paper: "FFFFFF"),
                                              SigPalette("Acid", bg: "0B1F1A", ink: "0B1F1A", accent: "C6FF3D", muted: "2F7A5C", paper: "FFFFFF"),
                                              SigPalette("Arcade Blue", bg: "0A1340", ink: "0A1340", accent: "33D6FF", muted: "4058C8", paper: "FFFFFF")],
                                   sample: SigSample(title: "Static", author: "Kai Moreno", tagline: "Tune in. You can't get out.", photo: "portrait")))

        // 19. Orbit (YA): a planet-sized circle of space cut from a loud flat color, ringed by one orbit line.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0.1, 0.1, 0.8, 0.5), clip: .ellipse, look: .natural, focusY: 0.5, zoom: 1.2, index: 0, fallback: .material("mat.nebula.palette.b")))
        e.append(.shape(.ellipse, NRect(0.02, 0.28, 0.96, 0.15), .accent, stroke: 0.004, rotation: -12))
        e.append(.text(.title, NRect(0.07, 0.65, 0.86, 0.2), SigType(["Syne-ExtraBold"], color: .ink, letterCase: .lower, lineHeight: 0.88, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.07, 0.89, 0.86, 0.035), SigType(["Montserrat-Black"], color: .ink, tracking: 0.3)))
        out.append(SignatureDesign(id: "youngadult-orbit", name: "Orbit", genre: .youngAdult,
                                   idea: "A huge circle of deep space is punched out of a loud flat color and circled by a single tilted orbit line; lowercase title below.",
                                   tags: ["photo", "light", "bold type", "modern", "cosmic", "graphic"], elements: e,
                                   palettes: [SigPalette("Tangerine", bg: "FF6B2C", ink: "0B0612", accent: "FFF2D6", muted: "7A2A10", paper: "FFF8EC"),
                                              SigPalette("Lilac", bg: "C9B8FF", ink: "120C2E", accent: "FFE14D", muted: "5B4BA8", paper: "FFFFFF"),
                                              SigPalette("Lime", bg: "D8FF5C", ink: "0E1A12", accent: "2B3BFF", muted: "5D7A1F", paper: "FFFFFF")],
                                   sample: SigSample(title: "We Were Made of Stars", author: "Tobi Achebe", photo: "space")))

        // 20. Echo (YA): the title repeats three times, growing from a whisper to full volume.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.title, NRect(0.06, 0.06, 0.88, 0.22), SigType(["Unbounded-ExtraBold"], color: .ink, lineHeight: 0.9, align: .left, breaks: .lines(2), opacity: 0.18)))
        e.append(.text(.title, NRect(0.06, 0.3, 0.88, 0.22), SigType(["Unbounded-ExtraBold"], color: .ink, lineHeight: 0.9, align: .left, breaks: .lines(2), opacity: 0.45)))
        e.append(.text(.title, NRect(0.06, 0.54, 0.88, 0.22), SigType(["Unbounded-ExtraBold"], color: .ink, lineHeight: 0.9, align: .left, breaks: .lines(2))))
        e.append(.shape(.rectangle, NRect(0.06, 0.81, 0.2, 0.012), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.06, 0.86, 0.88, 0.04), SigType(["Montserrat-Black"], color: .ink, tracking: 0.3, align: .left)))
        out.append(SignatureDesign(id: "youngadult-echo", name: "Echo", genre: .youngAdult,
                                   idea: "The title is set three times down the cover, fading up from a whisper to full volume, a typographic crescendo.",
                                   tags: ["typographic", "light", "bold type", "modern", "loud", "pattern"], elements: e,
                                   palettes: [SigPalette("Hot Pink", bg: "FF6FB5", ink: "14051F", accent: "FFE600", muted: "B0306E", paper: "FFFFFF"),
                                              SigPalette("Electric", bg: "1638FF", ink: "FFFFFF", accent: "FF5BC8", muted: "0A1F99", paper: "FFFFFF"),
                                              SigPalette("Mono Lime", bg: "111111", ink: "E6FF4F", accent: "FF4D2E", muted: "3A3A3A", paper: "FFFFFF")],
                                   sample: SigSample(title: "Say It Louder", author: "Priya Lennox")))

        // 21. Tilt (YA): a tilted slab of color cuts across a duotone photo, the title riding its angle.
        e = []
        e.append(.photo(.full, clip: nil, look: .duotone(.muted, .paper), focusY: 0.3, zoom: 1, index: 0, fallback: .material("mat.concrete.palette.b")))
        e.append(.scrim(NRect(0, 0, 1, 0.2), .muted, angle: 270, strength: 0.6))
        e.append(.text(.tagline, NRect(0.08, 0.05, 0.84, 0.022), SigType(["Montserrat-Black"], color: .paper, tracking: 0.25)))
        e.append(.shape(.rectangle, NRect(-0.2, 0.6, 1.4, 0.6), .accent, stroke: 0, rotation: -8))
        e.append(.text(.title, NRect(0.07, 0.665, 0.86, 0.19), SigType(["BigShouldersDisplay-Black"], color: .ink, lineHeight: 0.86, breaks: .lines(2), rotation: -8)))
        e.append(.text(.author, NRect(0.1, 0.875, 0.8, 0.035), SigType(["Montserrat-Black"], color: .ink, tracking: 0.3, rotation: -8)))
        out.append(SignatureDesign(id: "youngadult-tilt", name: "Tilt", genre: .youngAdult,
                                   idea: "A tilted slab of flat color slices across a duotone photo, and the title rides its eight-degree angle, off balance and urgent.",
                                   tags: ["photo", "dark", "bold type", "modern", "dynamic", "condensed"], elements: e,
                                   palettes: [SigPalette("Signal Yellow", bg: "111111", ink: "111111", accent: "FFD60A", muted: "1B1B2F", paper: "F4F1EA"),
                                              SigPalette("Ink Blue", bg: "0B1240", ink: "FFFFFF", accent: "0B2DFF", muted: "0B1240", paper: "E9ECFF"),
                                              SigPalette("Mint", bg: "06231A", ink: "06231A", accent: "7CF5C8", muted: "06231A", paper: "F0FFF8")],
                                   sample: SigSample(title: "Nobody Saw Us Fall", author: "Jordan Okoye", tagline: "Everyone has a version", photo: "portrait")))

        // 22. Polaroid (YA contemporary): a taped instant photo, the title scrawled in marker across its edge.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.shape(.rectangle, NRect(0.16, 0.13, 0.68, 0.52), .paper, stroke: 0, rotation: 0))
        e.append(.photo(NRect(0.2, 0.155, 0.6, 0.39), clip: nil, look: .faded, focusY: 0.3, zoom: 1.1, index: 0, fallback: .watercolor([.muted, .accent])))
        e.append(.shape(.rectangle, NRect(0.38, 0.11, 0.24, 0.045), .alpha(.accent, 0.85), stroke: 0, rotation: -6))
        e.append(.text(.title, NRect(0.06, 0.59, 0.88, 0.2), SigType(["PermanentMarker-Regular"], color: .ink, letterCase: .asTyped, lineHeight: 0.95, breaks: .lines(2), rotation: -4)))
        e.append(.text(.author, NRect(0.08, 0.87, 0.84, 0.035), SigType(["Montserrat-Black"], color: .ink, tracking: 0.3)))
        out.append(SignatureDesign(id: "youngadult-polaroid", name: "Polaroid", genre: .youngAdult,
                                   idea: "One instant photo taped to a flat color wall, with the title scrawled in marker across its bottom edge as if someone wrote on it.",
                                   tags: ["photo", "light", "contemporary", "handwritten", "playful", "nostalgic"], elements: e,
                                   palettes: [SigPalette("Bubblegum", bg: "FFC6D9", ink: "1A1033", accent: "7DE2D1", muted: "F28AB0", paper: "FFFFFF"),
                                              SigPalette("Sky", bg: "BFE3FF", ink: "0D1B3E", accent: "FFD84D", muted: "6FA8DC", paper: "FFFFFF"),
                                              SigPalette("Tangerine", bg: "FFB27A", ink: "1F0E05", accent: "3F6BFF", muted: "E36F2C", paper: "FFFFFF")],
                                   sample: SigSample(title: "Everything We Didn't Post", author: "Maya Castellanos", photo: "portrait")))

        // 23. Blood Moon (YA fantasy): a red moon rising behind a single sharp peak; the title stands on the dark ground below.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.fill(.radial(.alpha(.accent, 0.3), .bg), NRect(0, 0, 1, 0.62)))
        e.append(.shape(.ellipse, NRect(0.25, 0.1, 0.5, 0.3125), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.08, 0.3, 0.84, 0.31), .muted, stroke: 0, rotation: 0))
        e.append(.fill(.solid(.muted), NRect(0, 0.6, 1, 0.4)))
        e.append(.text(.seriesOr("BOOK ONE"), NRect(0.2, 0.05, 0.6, 0.02), SigType(["Montserrat-Black"], color: .ink, tracking: 0.4, opacity: 0.8)))
        e.append(.text(.title, NRect(0.06, 0.64, 0.88, 0.2), SigType(["Cinzel-Bold"], color: .ink, tracking: 0.06, lineHeight: 0.92, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.1, 0.885, 0.8, 0.035), SigType(["Montserrat-Black"], color: .ink, tracking: 0.35)))
        out.append(SignatureDesign(id: "youngadult-blood-moon", name: "Blood Moon", genre: .youngAdult,
                                   idea: "A flat red moon rises behind one razor-sharp mountain silhouette; vast dark space, and a carved title on the ground below.",
                                   tags: ["graphic", "dark", "ya fantasy", "epic", "minimal", "bold type"], elements: e,
                                   palettes: [SigPalette("Blood Moon", bg: "0B0B10", ink: "F2ECE4", accent: "C8202F", muted: "17161F", paper: "F2ECE4"),
                                              SigPalette("Ice Moon", bg: "08121E", ink: "EAF4FF", accent: "9ED8FF", muted: "0F1E2E", paper: "EAF4FF"),
                                              SigPalette("Gold Eclipse", bg: "0F0C08", ink: "F6EBD3", accent: "E2A93B", muted: "1C1711", paper: "F6EBD3")],
                                   sample: SigSample(title: "A Throne of Teeth", author: "Sable Rios", series: "The Ashen Crown")))

        // 24. Sliver (YA thriller): the photo is cropped to a thin eye-line band across black, a tall condensed title below.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.author, NRect(0.06, 0.06, 0.88, 0.04), SigType(["Oswald-Bold"], color: .ink, tracking: 0.3)))
        e.append(.text(.tagline, NRect(0.06, 0.32, 0.88, 0.022), SigType(["Montserrat-Black"], color: .accent, tracking: 0.2)))
        e.append(.photo(NRect(0, 0.36, 1, 0.13), clip: nil, look: .tint(.accent), focusY: 0.3, zoom: 1, index: 0, fallback: .material("mat.scratches.palette.b")))
        e.append(.text(.title, NRect(0.06, 0.55, 0.88, 0.32), SigType(["LeagueGothic-Regular"], color: .ink, lineHeight: 0.88, breaks: .lines(2))))
        out.append(SignatureDesign(id: "youngadult-sliver", name: "Sliver", genre: .youngAdult,
                                   idea: "The photo is cut down to a thin eye-line band across black, like a redacted file, with a towering condensed title below.",
                                   tags: ["photo", "dark", "ya thriller", "bold type", "minimal", "condensed"], elements: e,
                                   palettes: [SigPalette("Red Alert", bg: "0A0A0A", ink: "F4F4F4", accent: "FF2E2E", muted: "6E6E6E", paper: "FFFFFF"),
                                              SigPalette("Toxic", bg: "0A0D0A", ink: "EFFFE8", accent: "7CFF4F", muted: "5A6B55", paper: "FFFFFF"),
                                              SigPalette("Cold Case", bg: "0C1220", ink: "E8F0FF", accent: "5CA8FF", muted: "5C6880", paper: "FFFFFF")],
                                   sample: SigSample(title: "The Last One Awake", author: "Riley Navarro", tagline: "Six friends went to the lake. Five came back.", photo: "portrait")))

        // 25. Horizon (YA contemporary): a sunset gradient and a half-sunk sun; an airy lowercase title in the sky.
        e = []
        e.append(.fill(.linear(.accent, .bg, 90), .full))
        e.append(.shape(.ellipse, NRect(0.25, 0.42, 0.5, 0.3125), .paper, stroke: 0, rotation: 0))
        e.append(.fill(.solid(.muted), NRect(0, 0.58, 1, 0.42)))
        e.append(.shape(.rectangle, NRect(0.3, 0.62, 0.4, 0.004), .alpha(.paper, 0.7), stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.36, 0.66, 0.28, 0.004), .alpha(.paper, 0.5), stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.42, 0.7, 0.16, 0.004), .alpha(.paper, 0.3), stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.07, 0.07, 0.86, 0.27), SigType(["Montserrat-Black"], color: .ink, letterCase: .lower, tracking: -0.02, lineHeight: 0.9, breaks: .lines(3))))
        e.append(.text(.author, NRect(0.07, 0.88, 0.86, 0.035), SigType(["JosefinSans-Bold"], color: .paper, tracking: 0.35)))
        out.append(SignatureDesign(id: "youngadult-horizon", name: "Horizon", genre: .youngAdult,
                                   idea: "A sunset gradient, a flat sun half-sunk below a hard horizon line, and three fading reflections on the water; the title hangs in the sky.",
                                   tags: ["graphic", "light", "contemporary", "summer", "romantic", "modern"], elements: e,
                                   palettes: [SigPalette("Golden Hour", bg: "FF5E7E", ink: "1E0F2E", accent: "FFB25B", muted: "2B1E4F", paper: "FFF4E0"),
                                              SigPalette("Blue Hour", bg: "C58BE8", ink: "0E1230", accent: "9EC9FF", muted: "13183A", paper: "FFF6EC"),
                                              SigPalette("Citrus", bg: "FF8A3D", ink: "1A1205", accent: "FFE76A", muted: "0F3D3A", paper: "FFFBEA")],
                                   sample: SigSample(title: "the summer we stopped counting", author: "Ellie Park")))

        return out
    }
}
