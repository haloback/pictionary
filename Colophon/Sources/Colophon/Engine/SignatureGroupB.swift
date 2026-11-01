import Foundation

// MARK: - Signature group B: thriller, mystery, horror

extension SignatureLibrary {
    static var groupB: [SignatureDesign] {
        var out: [SignatureDesign] = []
        var e: [SigElement] = []

        // MARK: Thriller

        // Redacted: a classified page where every line is blacked out except the title; a red stamp lands on top.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.seriesOr("FILE 07 / EYES ONLY"), NRect(0.08, 0.05, 0.6, 0.018), SigType(["Montserrat-Black"], color: .muted, tracking: 0.3, align: .left)))
        e.append(.shape(.rule, NRect(0.08, 0.08, 0.84, 0.002), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.08, 0.12, 0.84, 0.034), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.08, 0.175, 0.62, 0.034), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.08, 0.23, 0.78, 0.034), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.08, 0.285, 0.44, 0.034), .ink, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.08, 0.35, 0.84, 0.2), SigType(["Montserrat-Black"], tracking: -0.01, lineHeight: 0.92, align: .left, breaks: .lines(2))))
        e.append(.shape(.rectangle, NRect(0.08, 0.59, 0.84, 0.034), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.08, 0.645, 0.7, 0.034), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.08, 0.7, 0.52, 0.034), .ink, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.08, 0.755, 0.8, 0.034), .ink, stroke: 0, rotation: 0))
        e.append(.text(.label("DECLASSIFIED"), NRect(0.54, 0.665, 0.36, 0.045), SigType(["Montserrat-Black"], color: .accent, tracking: 0.25, rotation: -8, flourish: .box, flourishColor: .accent, opacity: 0.92)))
        e.append(.shape(.rule, NRect(0.08, 0.86, 0.84, 0.002), .ink, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.08, 0.88, 0.7, 0.045), SigType(["Montserrat-Black"], tracking: 0.12, align: .left)))
        out.append(SignatureDesign(id: "thriller-redacted", name: "Redacted", genre: .thriller,
                                   idea: "A classified page where every line is blacked out except the title, with a red stamp struck across the bars.",
                                   tags: ["typographic", "light", "minimal", "modern", "bold type", "graphic"], elements: e,
                                   palettes: [SigPalette("Dossier & Stamp Red", bg: "F1EEE6", ink: "111111", accent: "C8102E", muted: "7C7A73", paper: "FAF8F2"),
                                              SigPalette("Manila Folder", bg: "E6D3A6", ink: "1A1712", accent: "9E1B1B", muted: "6E5F43", paper: "F3E7C9"),
                                              SigPalette("Carbon & White-Out", bg: "15171A", ink: "EDEAE2", accent: "FF3B1F", muted: "7A7D83", paper: "EDEAE2")],
                                   sample: SigSample(title: "The Quiet Protocol", author: "Daniel Asher Reyes")))

        // Window Grid: the city seen through the mullions of an office tower; the title sits on the solid sill below.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0, 0, 1, 0.66), clip: nil, look: .duotone(.hex("0A0A0A"), .accent), focusY: 0.45, zoom: 1.1, index: 0, fallback: .material("mat.bokeh.palette.b")))
        e.append(.shape(.rectangle, NRect(0.328, 0, 0.012, 0.66), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.66, 0, 0.012, 0.66), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0, 0.216, 1, 0.008), .bg, stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0, 0.436, 1, 0.008), .bg, stroke: 0, rotation: 0))
        e.append(.fill(.solid(.bg), NRect(0, 0.66, 1, 0.34)))
        e.append(.text(.title, NRect(0.07, 0.695, 0.86, 0.14), SigType(["Montserrat-Black"], tracking: -0.01, lineHeight: 0.95, align: .left, breaks: .lines(2))))
        e.append(.shape(.rule, NRect(0.07, 0.86, 0.12, 0.004), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.07, 0.878, 0.6, 0.032), SigType(["JosefinSans-Bold"], tracking: 0.2, align: .left)))
        e.append(.text(.subtitleOr("A THRILLER"), NRect(0.07, 0.928, 0.4, 0.016), SigType(["Montserrat-Black"], color: .muted, tracking: 0.3, align: .left)))
        out.append(SignatureDesign(id: "thriller-window-grid", name: "Window Grid", genre: .thriller,
                                   idea: "The city glows through the mullions of a high-rise window; the title sits on the dark sill beneath.",
                                   tags: ["photo", "dark", "modern", "urban", "bold type", "atmospheric"], elements: e,
                                   palettes: [SigPalette("Amber City", bg: "0E0F12", ink: "F4F1EA", accent: "F2A33A", muted: "8D8F94", paper: "F4F1EA"),
                                              SigPalette("Blue Hour", bg: "0B1220", ink: "EEF2F8", accent: "4FA3FF", muted: "7E8BA3", paper: "EEF2F8"),
                                              SigPalette("Daylight Cobalt", bg: "ECEBE7", ink: "121316", accent: "2E6BFF", muted: "6E6F73", paper: "F7F6F2")],
                                   sample: SigSample(title: "The Fortieth Floor", author: "Nathan Okafor", photo: "landscape")))

        // The Slit: the photo survives only as a thin horizontal band across a dark field, like a view through a letterbox.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.title, NRect(0.07, 0.07, 0.86, 0.32), SigType(["LeagueGothic-Regular"], tracking: 0.02, lineHeight: 0.86, breaks: .stacked)))
        e.append(.photo(NRect(0, 0.43, 1, 0.13), clip: nil, look: .duotone(.hex("050607"), .accent), focusY: 0.5, zoom: 1, index: 0, fallback: .material("mat.ripples.palette.b")))
        e.append(.text(.tagline, NRect(0.12, 0.6, 0.76, 0.022), SigType(["Montserrat-Black"], color: .muted, tracking: 0.28)))
        e.append(.text(.author, NRect(0.07, 0.83, 0.86, 0.065), SigType(["Oswald-Bold"], tracking: 0.25)))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.3, 0.915, 0.4, 0.018), SigType(["Montserrat-Black"], color: .muted, tracking: 0.4)))
        out.append(SignatureDesign(id: "thriller-the-slit", name: "The Slit", genre: .thriller,
                                   idea: "The photo is cut down to a single letterbox band across a dark field, like a view through a mail slot.",
                                   tags: ["photo", "dark", "minimal", "condensed", "atmospheric", "moody"], elements: e,
                                   palettes: [SigPalette("Ink & Cold Steel", bg: "0E1418", ink: "EEF1F2", accent: "8FC1D4", muted: "7D8A92", paper: "EEF1F2"),
                                              SigPalette("Black & Sodium", bg: "0A0A0A", ink: "F3EFE6", accent: "F2A51A", muted: "8A857C", paper: "F3EFE6"),
                                              SigPalette("Bone & Black", bg: "EDE9E1", ink: "101010", accent: "C9C2B5", muted: "6B665E", paper: "FAF8F4")],
                                   sample: SigSample(title: "Dead Water", author: "Signe Halvorsen", tagline: "The tide gives back what it takes", photo: "landscape")))

        // Spine Line: the title runs vertically up the left edge like a spine; the photo fills the rest behind a hard accent cut.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0.34, 0, 0.66, 1), clip: nil, look: .duotone(.hex("0B0B0B"), .paper), focusY: 0.35, zoom: 1, index: 0, fallback: .material("mat.concrete.palette.b")))
        e.append(.scrim(NRect(0.34, 0.7, 0.66, 0.3), .hex("000000"), angle: 90, strength: 0.85))
        e.append(.scrim(NRect(0.34, 0, 0.66, 0.2), .hex("000000"), angle: 270, strength: 0.6))
        e.append(.shape(.rectangle, NRect(0.334, 0, 0.008, 1), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(-0.556, 0.4125, 1.472, 0.175), SigType(["Anton-Regular"], tracking: 0.02, breaks: .oneLine, rotation: -90)))
        e.append(.text(.tagline, NRect(0.4, 0.05, 0.54, 0.02), SigType(["Montserrat-Black"], color: .paper, tracking: 0.2, align: .right)))
        e.append(.text(.author, NRect(0.4, 0.895, 0.54, 0.035), SigType(["Montserrat-Black"], color: .paper, tracking: 0.2, align: .right)))
        out.append(SignatureDesign(id: "thriller-spine-line", name: "Spine Line", genre: .thriller,
                                   idea: "The title is set vertically up the left edge like a spine; the photo fills the rest behind one hard accent cut.",
                                   tags: ["photo", "dark", "vertical", "condensed", "bold type", "modern"], elements: e,
                                   palettes: [SigPalette("Gunmetal & Blaze", bg: "1B1F23", ink: "F1F1EE", accent: "FF5A1F", muted: "5A6168", paper: "F1F1EE"),
                                              SigPalette("Navy & Signal Yellow", bg: "0F1A2B", ink: "F3F0E6", accent: "FFC21A", muted: "4F607A", paper: "F3F0E6"),
                                              SigPalette("Bone & Black", bg: "E9E6DF", ink: "0F0F0F", accent: "D7261E", muted: "8C877E", paper: "F5F3EE")],
                                   sample: SigSample(title: "Overwatch", author: "Cole Brandt", tagline: "They see everything. Except him.", photo: "portrait")))

        // Echo: the title repeats down the cover, fading in and out; only one line burns in full color.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.title, NRect(0.06, 0.05, 0.88, 0.1), SigType(["BebasNeue-Regular"], tracking: 0.02, breaks: .oneLine, opacity: 0.07)))
        e.append(.text(.title, NRect(0.06, 0.155, 0.88, 0.1), SigType(["BebasNeue-Regular"], tracking: 0.02, breaks: .oneLine, opacity: 0.14)))
        e.append(.text(.title, NRect(0.06, 0.26, 0.88, 0.1), SigType(["BebasNeue-Regular"], tracking: 0.02, breaks: .oneLine, opacity: 0.3)))
        e.append(.text(.title, NRect(0.06, 0.365, 0.88, 0.1), SigType(["BebasNeue-Regular"], color: .accent, tracking: 0.02, breaks: .oneLine)))
        e.append(.text(.title, NRect(0.06, 0.47, 0.88, 0.1), SigType(["BebasNeue-Regular"], tracking: 0.02, breaks: .oneLine, opacity: 0.3)))
        e.append(.text(.title, NRect(0.06, 0.575, 0.88, 0.1), SigType(["BebasNeue-Regular"], tracking: 0.02, breaks: .oneLine, opacity: 0.14)))
        e.append(.text(.title, NRect(0.06, 0.68, 0.88, 0.1), SigType(["BebasNeue-Regular"], tracking: 0.02, breaks: .oneLine, opacity: 0.07)))
        e.append(.text(.author, NRect(0.06, 0.83, 0.88, 0.055), SigType(["Montserrat-Black"], tracking: 0.2)))
        e.append(.text(.tagline, NRect(0.1, 0.91, 0.8, 0.02), SigType(["Montserrat-Black"], color: .muted, tracking: 0.28)))
        out.append(SignatureDesign(id: "thriller-echo", name: "Echo", genre: .thriller,
                                   idea: "The title repeats down the cover like an echo, fading in and out; only the middle line burns in full color.",
                                   tags: ["typographic", "dark", "pattern", "condensed", "bold type", "modern"], elements: e,
                                   palettes: [SigPalette("Black & Alarm Red", bg: "0C0C0C", ink: "EDEDED", accent: "FF2A2A", muted: "8A8A8A", paper: "F5F5F5"),
                                              SigPalette("Midnight & Cyan", bg: "0D1030", ink: "E8EAF6", accent: "3DF5FF", muted: "7C80A6", paper: "E8EAF6"),
                                              SigPalette("Paper & Cobalt", bg: "F2F0EA", ink: "141414", accent: "1F3BFF", muted: "6F6D68", paper: "FFFFFF")],
                                   sample: SigSample(title: "Never Twice", author: "Rhea Calloway", tagline: "The second time, she'll be ready.")))

        // The Cut: a slab of hazard color slices across a black-and-white photo; the title rides the cut.
        e = []
        e.append(.photo(.full, clip: nil, look: .mono, focusY: 0.4, zoom: 1, index: 0, fallback: .material("mat.concrete.charcoal.b")))
        e.append(.scrim(NRect(0, 0, 1, 0.25), .hex("000000"), angle: 270, strength: 0.7))
        e.append(.scrim(NRect(0, 0.78, 1, 0.22), .hex("000000"), angle: 90, strength: 0.75))
        e.append(.shape(.rectangle, NRect(-0.3, 0.53, 1.6, 0.18), .accent, stroke: 0, rotation: -12))
        e.append(.text(.title, NRect(0.05, 0.56, 0.9, 0.12), SigType(["Anton-Regular"], color: .bg, tracking: 0.01, breaks: .oneLine, rotation: -12)))
        e.append(.text(.author, NRect(0.08, 0.06, 0.84, 0.05), SigType(["Oswald-Bold"], color: .paper, tracking: 0.3)))
        e.append(.text(.tagline, NRect(0.1, 0.92, 0.8, 0.02), SigType(["Montserrat-Black"], color: .paper, tracking: 0.25)))
        out.append(SignatureDesign(id: "thriller-the-cut", name: "The Cut", genre: .thriller,
                                   idea: "A slab of hazard color slices diagonally across a black-and-white photo; the title rides the cut.",
                                   tags: ["photo", "dark", "bold type", "condensed", "energetic", "modern"], elements: e,
                                   palettes: [SigPalette("Hazard Yellow", bg: "111111", ink: "F5F5F5", accent: "FFD400", muted: "9A9A9A", paper: "F5F5F5"),
                                              SigPalette("Signal Orange", bg: "0E0E0E", ink: "F5F5F5", accent: "FF5B1F", muted: "9A9A9A", paper: "F5F5F5"),
                                              SigPalette("Ice Blue", bg: "0A1622", ink: "F1F6FA", accent: "9BE7FF", muted: "8FA2B2", paper: "F1F6FA")],
                                   sample: SigSample(title: "Running Red", author: "Theo March", tagline: "Twelve hours. Four cities. One way out.", photo: "landscape")))

        // Hard Border: the stacked title is so big it runs off the right edge; a single accent bar holds the line.
        e = []
        e.append(.fill(.material("mat.concrete.palette.f"), .full))
        e.append(.text(.title, NRect(0.06, 0.07, 1.06, 0.5), SigType(["Anton-Regular"], tracking: -0.01, lineHeight: 0.86, align: .left, breaks: .stacked)))
        e.append(.shape(.rectangle, NRect(0.06, 0.62, 0.2, 0.012), .accent, stroke: 0, rotation: 0))
        e.append(.text(.tagline, NRect(0.06, 0.65, 0.6, 0.05), SigType(["JosefinSans-Bold"], tracking: 0.1, lineHeight: 1.1, align: .left, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.06, 0.87, 0.88, 0.07), SigType(["Montserrat-Black"], tracking: 0.05, align: .left)))
        out.append(SignatureDesign(id: "thriller-hard-border", name: "Hard Border", genre: .thriller,
                                   idea: "The stacked title is set so big it bleeds off the right edge of the cover; one accent bar is the only other mark.",
                                   tags: ["typographic", "light", "bold type", "condensed", "minimal", "modern"], elements: e,
                                   palettes: [SigPalette("Concrete & Red", bg: "D8D6D1", ink: "121212", accent: "E0261B", muted: "6F6D69", paper: "F2F1EE"),
                                              SigPalette("Black & Bone", bg: "121212", ink: "ECE8DF", accent: "E0261B", muted: "8A8780", paper: "ECE8DF"),
                                              SigPalette("Olive Drab & Brass", bg: "2E3328", ink: "EDEBE3", accent: "F2B33D", muted: "8A8F7E", paper: "EDEBE3")],
                                   sample: SigSample(title: "Hard Border", author: "Viktor Sandell", tagline: "No papers. No witnesses. No way back.")))

        // Surveillance: the photo framed as a CCTV feed, viewfinder brackets and a red recording dot.
        e = []
        e.append(.photo(.full, clip: nil, look: .mono, focusY: 0.35, zoom: 1.05, index: 0, fallback: .material("mat.smoke.palette.b")))
        e.append(.scrim(NRect(0, 0, 1, 0.18), .hex("000000"), angle: 270, strength: 0.6))
        e.append(.scrim(NRect(0, 0.58, 1, 0.42), .hex("000000"), angle: 90, strength: 0.92))
        e.append(.decor("corners viewfinder", .corners, NRect(0.06, 0.05, 0.88, 0.58), .paper))
        e.append(.shape(.ellipse, NRect(0.11, 0.087, 0.03, 0.01875), .accent, stroke: 0, rotation: 0))
        e.append(.text(.label("REC"), NRect(0.155, 0.086, 0.1, 0.021), SigType(["Montserrat-Black"], color: .paper, tracking: 0.2, align: .left)))
        e.append(.text(.label("CAM 04"), NRect(0.7, 0.086, 0.19, 0.021), SigType(["Montserrat-Black"], color: .paper, tracking: 0.2, align: .right)))
        e.append(.text(.title, NRect(0.07, 0.67, 0.86, 0.18), SigType(["BebasNeue-Regular"], color: .paper, tracking: 0.03, lineHeight: 0.9, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.1, 0.885, 0.8, 0.035), SigType(["Montserrat-Black"], color: .muted, tracking: 0.3)))
        out.append(SignatureDesign(id: "thriller-surveillance", name: "Surveillance", genre: .thriller,
                                   idea: "The photo is framed as a CCTV feed: viewfinder brackets, a red recording dot, and the title as the evidence beneath.",
                                   tags: ["photo", "dark", "modern", "tech", "bold type", "moody"], elements: e,
                                   palettes: [SigPalette("CCTV Red", bg: "000000", ink: "F2F2F2", accent: "FF2B2B", muted: "B5B5B5", paper: "F2F2F2"),
                                              SigPalette("Night Vision", bg: "000000", ink: "EAF7EE", accent: "39FF88", muted: "9CC9A9", paper: "EAF7EE"),
                                              SigPalette("Infrared Amber", bg: "000000", ink: "F7EFE4", accent: "FF9F1C", muted: "C2B6A6", paper: "F7EFE4")],
                                   sample: SigSample(title: "The Watched", author: "Priya Daswani", photo: "portrait")))

        // MARK: Mystery

        // Keyhole: a golden-age detective cover; light pours through a keyhole in a dark lacquered door.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.decor("border double fine inset", .border, .full, .accent))
        e.append(.text(.seriesOr("A DETECTIVE NOVEL"), NRect(0.2, 0.08, 0.6, 0.02), SigType(["Cinzel-Regular"], color: .accent, tracking: 0.3)))
        e.append(.text(.title, NRect(0.1, 0.115, 0.8, 0.2), SigType(["LibreCaslonDisplay-Regular"], tracking: 0.04, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.fill(.radial(.alpha(.paper, 0.22), .alpha(.bg, 0)), NRect(0.15, 0.33, 0.7, 0.48)))
        e.append(.shape(.ellipse, NRect(0.4, 0.42, 0.2, 0.125), .paper, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.385, 0.49, 0.23, 0.24), .paper, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.15, 0.82, 0.7, 0.045), SigType(["Cinzel-Regular"], tracking: 0.15)))
        out.append(SignatureDesign(id: "mystery-keyhole", name: "Keyhole", genre: .mystery,
                                   idea: "A golden-age detective cover: warm light pours through a single keyhole in a dark lacquered door.",
                                   tags: ["graphic", "dark", "classic", "vintage", "elegant", "minimal"], elements: e,
                                   palettes: [SigPalette("Crime Club Green", bg: "1E3A2F", ink: "F1E7CF", accent: "C9A24A", muted: "7E8C76", paper: "F6EBCB"),
                                              SigPalette("Oxblood Lacquer", bg: "4A1418", ink: "F3E6CF", accent: "D4A853", muted: "8E6A5E", paper: "FFF1D6"),
                                              SigPalette("Midnight Study", bg: "15203A", ink: "EEE6D3", accent: "D9B45A", muted: "6F7A92", paper: "FFF4D6")],
                                   sample: SigSample(title: "Death at Wexley Hall", author: "Margaret Ashby-Cole")))

        // Deco Arch: a 1930s travel-poster arch frames a sepia photo; fan corners and a crisp Cinzel title.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.decor("corners fan", .corners, .full, .accent))
        e.append(.photo(NRect(0.18, 0.1, 0.64, 0.5), clip: .arch, look: .sepia, focusY: 0.35, zoom: 1, index: 0, fallback: .watercolor([.accent, .muted])))
        e.append(.shape(.arch, NRect(0.16, 0.088, 0.68, 0.5245), .ink, stroke: 0.004, rotation: 0))
        e.append(.text(.title, NRect(0.1, 0.65, 0.8, 0.13), SigType(["Cinzel-Bold"], tracking: 0.06, lineHeight: 0.98, breaks: .lines(2))))
        e.append(.decor("divider single diamond", .divider, NRect(0.3, 0.79, 0.4, 0.02), .accent))
        e.append(.text(.author, NRect(0.15, 0.825, 0.7, 0.04), SigType(["CormorantGaramond-SemiBold"], tracking: 0.2)))
        e.append(.text(.subtitleOr("A MYSTERY"), NRect(0.25, 0.885, 0.5, 0.018), SigType(["JosefinSans-Bold"], color: .muted, tracking: 0.4)))
        out.append(SignatureDesign(id: "mystery-deco-arch", name: "Deco Arch", genre: .mystery,
                                   idea: "A 1930s travel-poster arch frames a sepia photograph, as if the murder happened on holiday.",
                                   tags: ["photo", "light", "vintage", "art deco", "elegant", "classic"], elements: e,
                                   palettes: [SigPalette("Riviera Cream", bg: "F1E6CF", ink: "1F2A33", accent: "B8862B", muted: "7C6E57", paper: "FBF5E8"),
                                              SigPalette("Seafoam & Rust", bg: "D7E6DE", ink: "1C2B2A", accent: "B5562E", muted: "62736C", paper: "F2F7F3"),
                                              SigPalette("Deco Night", bg: "141A22", ink: "EFE3C8", accent: "CFA54C", muted: "8A8F99", paper: "EFE3C8")],
                                   sample: SigSample(title: "The Lido Murders", author: "Felicity Ashdown-Grey", photo: "portrait")))

        // One Lit Window: domestic suspense; a black house at dusk, and only one window is awake.
        e = []
        e.append(.fill(.linear(.muted, .bg, 90), .full))
        e.append(.text(.title, NRect(0.08, 0.07, 0.84, 0.24), SigType(["DMSerifDisplay-Regular"], letterCase: .title, lineHeight: 0.92, breaks: .lines(2))))
        e.append(.text(.tagline, NRect(0.12, 0.335, 0.76, 0.022), SigType(["CormorantGaramond-MediumItalic"], color: .alpha(.ink, 0.75), letterCase: .asTyped)))
        e.append(.shape(.triangle, NRect(0.24, 0.47, 0.52, 0.135), .hex("06070A"), stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.28, 0.6, 0.44, 0.31), .hex("06070A"), stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0, 0.9, 1, 0.1), .hex("06070A"), stroke: 0, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.55, 0.66, 0.07, 0.065), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.1, 0.925, 0.8, 0.035), SigType(["Montserrat-Black"], tracking: 0.25)))
        out.append(SignatureDesign(id: "mystery-one-lit-window", name: "One Lit Window", genre: .mystery,
                                   idea: "Domestic suspense: a black house against a dusk sky, and only one window is awake.",
                                   tags: ["graphic", "dark", "domestic", "suspense", "moody", "atmospheric", "minimal"], elements: e,
                                   palettes: [SigPalette("Dusk", bg: "141A26", ink: "F3EEE4", accent: "F5C451", muted: "3B4A66", paper: "F3EEE4"),
                                              SigPalette("Ember Night", bg: "140D0C", ink: "F6EDE3", accent: "FF8A3D", muted: "4A2E2A", paper: "F6EDE3"),
                                              SigPalette("Winter Pine", bg: "0C1418", ink: "EEF3F2", accent: "F2E6B8", muted: "2F4550", paper: "EEF3F2")],
                                   sample: SigSample(title: "Someone Is Awake", author: "Claire Whitlow", tagline: "At 3 a.m. the house next door turns on a light.")))

        // Pale Portrait: a washed-out portrait, a calm serif title, and one red underline as the only disquieting note.
        e = []
        e.append(.photo(.full, clip: nil, look: .faded, focusY: 0.3, zoom: 1, index: 0, fallback: .watercolor([.muted, .paper])))
        e.append(.fill(.solid(.alpha(.paper, 0.35)), .full))
        e.append(.fill(.solid(.alpha(.paper, 0.6)), NRect(0, 0.35, 1, 0.31)))
        e.append(.scrim(NRect(0, 0, 1, 0.2), .paper, angle: 270, strength: 0.8))
        e.append(.scrim(NRect(0, 0.82, 1, 0.18), .paper, angle: 90, strength: 0.8))
        e.append(.text(.author, NRect(0.1, 0.06, 0.8, 0.04), SigType(["JosefinSans-Bold"], tracking: 0.3)))
        e.append(.text(.title, NRect(0.08, 0.38, 0.84, 0.2), SigType(["PlayfairDisplay-Bold"], letterCase: .title, lineHeight: 0.95, breaks: .lines(2), flourish: .underline, flourishColor: .accent)))
        e.append(.text(.tagline, NRect(0.12, 0.61, 0.76, 0.024), SigType(["CormorantGaramond-MediumItalic"], letterCase: .asTyped)))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.3, 0.92, 0.4, 0.018), SigType(["Montserrat-Black"], tracking: 0.4)))
        out.append(SignatureDesign(id: "mystery-pale-portrait", name: "Pale Portrait", genre: .mystery,
                                   idea: "Domestic suspense: a washed-out portrait and a calm serif title, with one red underline as the only wrong note.",
                                   tags: ["photo", "light", "domestic", "suspense", "elegant", "modern"], elements: e,
                                   palettes: [SigPalette("Linen & Red", bg: "EEE9E1", ink: "1A1A1A", accent: "C1272D", muted: "A39E96", paper: "F7F4EE"),
                                              SigPalette("Sage & Garnet", bg: "E4EAE2", ink: "1E2622", accent: "B23A48", muted: "93A096", paper: "EEF2EC"),
                                              SigPalette("Powder & Vermilion", bg: "E3EAF0", ink: "18202A", accent: "D2462E", muted: "8E9AA6", paper: "EEF2F6")],
                                   sample: SigSample(title: "What She Buried", author: "Laura Penhallow", tagline: "Every marriage has its secrets. Theirs has a body.", photo: "portrait")))

        // Venetian Blinds: noir light falls through blinds across a hard black-and-white photo.
        e = []
        e.append(.photo(.full, clip: nil, look: .stark, focusY: 0.35, zoom: 1.05, index: 0, fallback: .material("mat.smoke.charcoal.b")))
        e.append(.shape(.rectangle, NRect(-0.2, 0.0, 1.4, 0.045), .alpha(.hex("000000"), 0.72), stroke: 0, rotation: -14))
        e.append(.shape(.rectangle, NRect(-0.2, 0.09, 1.4, 0.045), .alpha(.hex("000000"), 0.72), stroke: 0, rotation: -14))
        e.append(.shape(.rectangle, NRect(-0.2, 0.18, 1.4, 0.045), .alpha(.hex("000000"), 0.72), stroke: 0, rotation: -14))
        e.append(.shape(.rectangle, NRect(-0.2, 0.27, 1.4, 0.045), .alpha(.hex("000000"), 0.72), stroke: 0, rotation: -14))
        e.append(.shape(.rectangle, NRect(-0.2, 0.36, 1.4, 0.045), .alpha(.hex("000000"), 0.72), stroke: 0, rotation: -14))
        e.append(.shape(.rectangle, NRect(-0.2, 0.45, 1.4, 0.045), .alpha(.hex("000000"), 0.72), stroke: 0, rotation: -14))
        e.append(.shape(.rectangle, NRect(-0.2, 0.54, 1.4, 0.045), .alpha(.hex("000000"), 0.72), stroke: 0, rotation: -14))
        e.append(.scrim(NRect(0, 0.55, 1, 0.45), .hex("000000"), angle: 90, strength: 0.95))
        e.append(.text(.series, NRect(0.07, 0.05, 0.6, 0.02), SigType(["Montserrat-Black"], color: .paper, tracking: 0.3, align: .left)))
        e.append(.text(.title, NRect(0.07, 0.66, 0.86, 0.18), SigType(["PlayfairDisplay-Black"], color: .paper, tracking: -0.01, lineHeight: 0.88, align: .left, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.07, 0.88, 0.7, 0.035), SigType(["Montserrat-Black"], color: .accent, tracking: 0.25, align: .left)))
        out.append(SignatureDesign(id: "mystery-venetian-blinds", name: "Venetian Blinds", genre: .mystery,
                                   idea: "Noir: hard light falls through venetian blinds across a black-and-white photo; one lipstick-red name.",
                                   tags: ["photo", "dark", "noir", "vintage", "moody", "atmospheric"], elements: e,
                                   palettes: [SigPalette("Black & Lipstick", bg: "000000", ink: "F2EEE6", accent: "D7263D", muted: "9A9A9A", paper: "F2EEE6"),
                                              SigPalette("Brass Bar", bg: "000000", ink: "F2EEE6", accent: "D9A441", muted: "9A9A9A", paper: "F2EEE6"),
                                              SigPalette("Absinthe", bg: "000000", ink: "EEF2E6", accent: "9FD356", muted: "9AA090", paper: "EEF2E6")],
                                   sample: SigSample(title: "The Long Rain Down", author: "Vic Moreno", series: "A Sam Doyle Case", photo: "portrait")))

        // Under the Lamp: noir; a single streetlamp throws a cone of light, and the title stands in it.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.shape(.rectangle, NRect(0.495, 0, 0.01, 0.11), .muted, stroke: 0, rotation: 0))
        e.append(.shape(.triangle, NRect(0.12, 0.12, 0.76, 0.7), .alpha(.accent, 0.92), stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.08, 0.79, 0.84, 0.06), .alpha(.accent, 0.92), stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.465, 0.1, 0.07, 0.04), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.28, 0.56, 0.44, 0.2), SigType(["Anton-Regular"], color: .bg, tracking: 0.02, lineHeight: 0.92, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.1, 0.89, 0.8, 0.035), SigType(["Montserrat-Black"], tracking: 0.3)))
        out.append(SignatureDesign(id: "mystery-under-the-lamp", name: "Under the Lamp", genre: .mystery,
                                   idea: "Noir: a single streetlamp throws a cone of light into the dark, and the title stands inside it.",
                                   tags: ["graphic", "dark", "noir", "minimal", "moody", "bold type"], elements: e,
                                   palettes: [SigPalette("Sodium Night", bg: "0E1117", ink: "EDE6D6", accent: "F2C14E", muted: "3A3F4A", paper: "EDE6D6"),
                                              SigPalette("Cold Moon", bg: "0B1016", ink: "E4ECF0", accent: "D9E3EA", muted: "34404C", paper: "E4ECF0"),
                                              SigPalette("Neon Red", bg: "120A0E", ink: "F3E6E8", accent: "FF5A5F", muted: "3E2A30", paper: "F3E6E8")],
                                   sample: SigSample(title: "Nobody Walks Home", author: "Frank Delacroix")))

        // Floor Plan: golden-age country-house mystery; a fine-line plan of the rooms, a red X where the body lies.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.title, NRect(0.1, 0.075, 0.8, 0.2), SigType(["LibreCaslonDisplay-Regular"], tracking: 0.03, lineHeight: 0.95, breaks: .lines(2))))
        e.append(.text(.subtitleOr("A MYSTERY"), NRect(0.2, 0.29, 0.6, 0.018), SigType(["JosefinSans-Bold"], color: .accent, tracking: 0.35)))
        e.append(.shape(.rectangle, NRect(0.12, 0.36, 0.76, 0.42), .ink, stroke: 0.004, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.12, 0.36, 0.3, 0.2), .ink, stroke: 0.0025, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.42, 0.36, 0.46, 0.14), .ink, stroke: 0.0025, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.12, 0.56, 0.22, 0.22), .ink, stroke: 0.0025, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.62, 0.5, 0.26, 0.28), .ink, stroke: 0.0025, rotation: 0))
        e.append(.shape(.rectangle, NRect(0.47, 0.645, 0.08, 0.006), .accent, stroke: 0, rotation: 45))
        e.append(.shape(.rectangle, NRect(0.47, 0.645, 0.08, 0.006), .accent, stroke: 0, rotation: -45))
        e.append(.text(.author, NRect(0.1, 0.84, 0.8, 0.05), SigType(["Prata-Regular"], tracking: 0.12)))
        out.append(SignatureDesign(id: "mystery-floor-plan", name: "Floor Plan", genre: .mystery,
                                   idea: "A golden-age country-house mystery: a fine-line floor plan of the rooms, and a red X where the body lies.",
                                   tags: ["graphic", "light", "classic", "vintage", "minimal", "puzzle"], elements: e,
                                   palettes: [SigPalette("Foolscap", bg: "EFE8D6", ink: "1C1C1C", accent: "B3261E", muted: "8A806C", paper: "FBF7EC"),
                                              SigPalette("Blueprint", bg: "1F3F6B", ink: "EEF2F6", accent: "FF6A5E", muted: "8FA7C4", paper: "EEF2F6"),
                                              SigPalette("Racing Green", bg: "1F3529", ink: "F0E8D2", accent: "E2B04A", muted: "7F8F7E", paper: "F0E8D2")],
                                   sample: SigSample(title: "Nine Rooms at Ashcombe", author: "Margery Thistlewood")))

        // White Horizon: Nordic mystery; a cold photo above, its highlights melting into a snow-white field below.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0, 0, 1, 0.5), clip: nil, look: .duotone(.hex("12161A"), .bg), focusY: 0.55, zoom: 1, index: 0, fallback: .material("mat.clouds.palette.f")))
        e.append(.shape(.rectangle, NRect(0.66, 0.474, 0.012, 0.026), .accent, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.08, 0.56, 0.84, 0.19), SigType(["Montserrat-Black"], tracking: 0.03, lineHeight: 0.95, align: .left, breaks: .lines(2))))
        e.append(.shape(.rule, NRect(0.08, 0.775, 0.08, 0.005), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.08, 0.8, 0.6, 0.035), SigType(["JosefinSans-Bold"], tracking: 0.2, align: .left)))
        e.append(.text(.subtitleOr("A MYSTERY"), NRect(0.08, 0.92, 0.5, 0.018), SigType(["Montserrat-Black"], color: .muted, tracking: 0.35, align: .left)))
        out.append(SignatureDesign(id: "mystery-white-horizon", name: "White Horizon", genre: .mystery,
                                   idea: "Nordic mystery: a cold photo whose highlights melt into a snow-white field, with one tiny red figure on the horizon.",
                                   tags: ["photo", "light", "nordic", "minimal", "modern", "atmospheric"], elements: e,
                                   palettes: [SigPalette("Snowfield", bg: "F2F3F1", ink: "14181C", accent: "C8262C", muted: "7F878D", paper: "F2F3F1"),
                                              SigPalette("Peat & Moss", bg: "E7E0D2", ink: "1D1A16", accent: "2F5D50", muted: "857C6C", paper: "F3EEE4"),
                                              SigPalette("Ash & Cobalt", bg: "DADBD6", ink: "141414", accent: "1E4FA0", muted: "6E706B", paper: "EDEDEA")],
                                   sample: SigSample(title: "The Frozen Shore", author: "Astrid Nyqvist", photo: "landscape")))

        // MARK: Horror

        // Ajar: a door stands open a crack in total darkness; the photo is visible only through that sliver of light.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.tagline, NRect(0.15, 0.06, 0.7, 0.022), SigType(["CormorantGaramond-MediumItalic"], color: .muted, letterCase: .asTyped)))
        e.append(.shape(.rectangle, NRect(0.32, 0.14, 0.35, 0.5), .alpha(.muted, 0.45), stroke: 0.002, rotation: 0))
        e.append(.photo(NRect(0.62, 0.14, 0.05, 0.5), clip: nil, look: .faded, focusY: 0.4, zoom: 1, index: 0, fallback: .material("mat.lightleak.palette.f")))
        e.append(.shape(.triangle, NRect(0.565, 0.64, 0.16, 0.1), .alpha(.paper, 0.14), stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.1, 0.78, 0.8, 0.07), SigType(["CormorantGaramond-SemiBold"], tracking: 0.2, breaks: .oneLine)))
        e.append(.text(.author, NRect(0.2, 0.89, 0.6, 0.028), SigType(["Montserrat-Black"], color: .muted, tracking: 0.3)))
        out.append(SignatureDesign(id: "horror-ajar", name: "Ajar", genre: .horror,
                                   idea: "A door stands open a crack in total darkness; the photo shows only through that sliver of light.",
                                   tags: ["photo", "dark", "literary", "minimal", "atmospheric", "quiet"], elements: e,
                                   palettes: [SigPalette("Lamp Black", bg: "0B0A09", ink: "E8E2D6", accent: "F3E6C4", muted: "6A645A", paper: "F3E6C4"),
                                              SigPalette("Cold Hall", bg: "080B0E", ink: "E3ECF0", accent: "DCEBF2", muted: "56636B", paper: "DCEBF2"),
                                              SigPalette("The Red Room", bg: "0A0505", ink: "E9DCD6", accent: "E2412F", muted: "6E4A45", paper: "E2412F")],
                                   sample: SigSample(title: "The Unlit House", author: "Imogen Thorne", tagline: "Don't go in. Don't look in. Don't let it out.", photo: "portrait")))

        // Unblinking: two small eyes open in a vast, empty black; nothing else.
        e = []
        e.append(.fill(.radial(.muted, .bg), .full))
        e.append(.text(.title, NRect(0.08, 0.08, 0.84, 0.09), SigType(["CormorantGaramond-Bold"], tracking: 0.18, breaks: .oneLine)))
        e.append(.text(.tagline, NRect(0.15, 0.19, 0.7, 0.02), SigType(["CormorantGaramond-MediumItalic"], color: .alpha(.ink, 0.55), letterCase: .asTyped)))
        e.append(.shape(.ellipse, NRect(0.44, 0.47, 0.035, 0.012), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.525, 0.47, 0.035, 0.012), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.1, 0.88, 0.8, 0.035), SigType(["JosefinSans-Bold"], tracking: 0.3)))
        out.append(SignatureDesign(id: "horror-unblinking", name: "Unblinking", genre: .horror,
                                   idea: "Two small eyes open in a vast, empty black; the restraint is the scare.",
                                   tags: ["graphic", "dark", "minimal", "literary", "quiet", "moody"], elements: e,
                                   palettes: [SigPalette("Pitch & Sulphur", bg: "050505", ink: "E6E1D8", accent: "F0D35A", muted: "1E1E1E", paper: "E6E1D8"),
                                              SigPalette("Wolf Light", bg: "05080A", ink: "E2EAEC", accent: "BFE3E8", muted: "18222A", paper: "E2EAEC"),
                                              SigPalette("Ember", bg: "070303", ink: "EDE0DC", accent: "E8402A", muted: "2A1110", paper: "EDE0DC")],
                                   sample: SigSample(title: "Unblinking", author: "Silas Merrow", tagline: "It has been watching since before you were born.")))

        // Black Sun: folk horror; a midsummer eclipse, a black disc ringed in red on a bone-pale ground.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.shape(.ellipse, NRect(0.17, 0.165, 0.66, 0.4125), .accent, stroke: 0.003, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.2, 0.184, 0.6, 0.375), .ink, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.08, 0.65, 0.84, 0.14), SigType(["CormorantGaramond-Bold"], tracking: 0.1, lineHeight: 1.0, breaks: .lines(2))))
        e.append(.shape(.rule, NRect(0.45, 0.815, 0.1, 0.003), .accent, stroke: 0, rotation: 0))
        e.append(.text(.author, NRect(0.15, 0.84, 0.7, 0.035), SigType(["JosefinSans-Bold"], tracking: 0.3)))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.3, 0.92, 0.4, 0.018), SigType(["JosefinSans-Bold"], color: .muted, tracking: 0.4)))
        out.append(SignatureDesign(id: "horror-black-sun", name: "Black Sun", genre: .horror,
                                   idea: "Folk horror: a midsummer eclipse, one black disc ringed in red on a bone-pale ground.",
                                   tags: ["graphic", "light", "folk", "literary", "minimal", "elegant"], elements: e,
                                   palettes: [SigPalette("Bone & Black", bg: "EFE9DA", ink: "141210", accent: "B8322A", muted: "8B8577", paper: "F8F4EA"),
                                              SigPalette("Hayfield", bg: "E9D9A6", ink: "1D1A12", accent: "5B6B2E", muted: "8A7C52", paper: "F5ECCF"),
                                              SigPalette("Ash Rose", bg: "E8D8D2", ink: "1E1416", accent: "7A1F2B", muted: "8E7A76", paper: "F5ECE8")],
                                   sample: SigSample(title: "The Longest Day of the Year", author: "Agnes Vell")))

        // Her Likeness: a haunted portrait drowned in one color; the title is a small italic whisper.
        e = []
        e.append(.photo(.full, clip: nil, look: .duotone(.bg, .accent), focusY: 0.3, zoom: 1.05, index: 0, fallback: .material("mat.smoke.palette.b")))
        e.append(.scrim(NRect(0, 0, 1, 0.3), .bg, angle: 270, strength: 0.8))
        e.append(.scrim(NRect(0, 0.6, 1, 0.4), .bg, angle: 90, strength: 0.95))
        e.append(.text(.tagline, NRect(0.12, 0.05, 0.76, 0.022), SigType(["CormorantGaramond-MediumItalic"], color: .paper, letterCase: .asTyped, opacity: 0.8)))
        e.append(.text(.title, NRect(0.08, 0.72, 0.84, 0.11), SigType(["DMSerifDisplay-Italic"], color: .paper, letterCase: .title, breaks: .oneLine)))
        e.append(.text(.author, NRect(0.1, 0.875, 0.8, 0.032), SigType(["JosefinSans-Bold"], color: .paper, tracking: 0.3)))
        out.append(SignatureDesign(id: "horror-her-likeness", name: "Her Likeness", genre: .horror,
                                   idea: "A haunted portrait drowned in a single color; the title is a small italic whisper beneath it.",
                                   tags: ["photo", "dark", "literary", "gothic", "elegant", "moody"], elements: e,
                                   palettes: [SigPalette("Oxblood", bg: "120607", ink: "F2E7DF", accent: "B3262B", muted: "6A3A38", paper: "F2E7DF"),
                                              SigPalette("Bruise", bg: "0E0A16", ink: "ECE6F2", accent: "6E4CA8", muted: "4A3D5E", paper: "ECE6F2"),
                                              SigPalette("Verdigris", bg: "07110F", ink: "E3EFEA", accent: "3F8C7A", muted: "2E4A43", paper: "E3EFEA")],
                                   sample: SigSample(title: "Her Likeness", author: "Odile Marchetti", tagline: "She has been watching from the wall for two hundred years.", photo: "portrait")))

        // Mercy: visceral with restraint; a single red drip runs from a black title down a clean white cover.
        e = []
        e.append(.fill(.grain(.bg), .full))
        e.append(.text(.title, NRect(0.07, 0.07, 0.86, 0.19), SigType(["PlayfairDisplay-Black"], tracking: -0.01, breaks: .oneLine)))
        e.append(.shape(.rectangle, NRect(0.617, 0.245, 0.008, 0.485), .accent, stroke: 0, rotation: 0))
        e.append(.shape(.ellipse, NRect(0.61, 0.722, 0.022, 0.018), .accent, stroke: 0, rotation: 0))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.3, 0.835, 0.4, 0.018), SigType(["Montserrat-Black"], color: .muted, tracking: 0.4)))
        e.append(.text(.author, NRect(0.07, 0.875, 0.86, 0.045), SigType(["Montserrat-Black"], tracking: 0.3)))
        out.append(SignatureDesign(id: "horror-the-drip", name: "The Drip", genre: .horror,
                                   idea: "Visceral with restraint: one thin red drip runs from the black title down an otherwise clean white cover.",
                                   tags: ["typographic", "light", "minimal", "visceral", "bold type", "modern"], elements: e,
                                   palettes: [SigPalette("Clinic White", bg: "F4F2EE", ink: "0F0F0F", accent: "B0141B", muted: "8F8A84", paper: "FFFFFF"),
                                              SigPalette("Black Gloss", bg: "0D0D0D", ink: "F1EEE8", accent: "C3161E", muted: "807B75", paper: "F1EEE8"),
                                              SigPalette("Old Bone", bg: "E8E1D3", ink: "1A1714", accent: "5A0F12", muted: "857C6E", paper: "F4EFE5")],
                                   sample: SigSample(title: "Mercy", author: "Hollis Crane")))

        // The Still Lake: the title hangs upside down in black water beneath it, a reflection that should not be there.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.photo(NRect(0, 0, 1, 0.52), clip: nil, look: .mono, focusY: 0.6, zoom: 1, index: 0, fallback: .material("mat.clouds.palette.f")))
        e.append(.scrim(NRect(0, 0.28, 1, 0.24), .bg, angle: 90, strength: 1.0))
        e.append(.shape(.rule, NRect(0.08, 0.5185, 0.84, 0.0015), .muted, stroke: 0, rotation: 0))
        e.append(.text(.title, NRect(0.08, 0.425, 0.84, 0.09), SigType(["CormorantGaramond-Bold"], tracking: 0.12, breaks: .oneLine)))
        e.append(.text(.title, NRect(0.08, 0.522, 0.84, 0.09), SigType(["CormorantGaramond-Bold"], tracking: 0.12, breaks: .oneLine, rotation: 180, opacity: 0.25)))
        e.append(.text(.author, NRect(0.1, 0.88, 0.8, 0.035), SigType(["JosefinSans-Bold"], color: .muted, tracking: 0.3)))
        out.append(SignatureDesign(id: "horror-still-lake", name: "The Still Lake", genre: .horror,
                                   idea: "The title sits on a black waterline, and its reflection hangs upside down beneath it, wrong in a way you notice slowly.",
                                   tags: ["photo", "dark", "literary", "atmospheric", "minimal", "quiet"], elements: e,
                                   palettes: [SigPalette("Black Water", bg: "060708", ink: "E9ECEC", accent: "9FB7BF", muted: "8A9196", paper: "E9ECEC"),
                                              SigPalette("Peat Bog", bg: "0B0905", ink: "EDE3CC", accent: "B59A5A", muted: "978C73", paper: "EDE3CC"),
                                              SigPalette("Blood Moon", bg: "0A0404", ink: "F0E1DC", accent: "C0392B", muted: "9C7A74", paper: "F0E1DC")],
                                   sample: SigSample(title: "The Still Lake", author: "Ewan Galbraith", photo: "landscape")))

        // Feral: three clean cuts tear through a huge title, like claw marks; no blood needed.
        e = []
        e.append(.fill(.solid(.bg), .full))
        e.append(.text(.author, NRect(0.06, 0.07, 0.88, 0.045), SigType(["Montserrat-Black"], color: .accent, tracking: 0.3)))
        e.append(.text(.title, NRect(0.06, 0.32, 0.88, 0.28), SigType(["Anton-Regular"], tracking: 0.01, lineHeight: 0.88, breaks: .stacked)))
        e.append(.shape(.rectangle, NRect(0.18, 0.454, 0.44, 0.012), .bg, stroke: 0, rotation: -62))
        e.append(.shape(.rectangle, NRect(0.27, 0.464, 0.44, 0.012), .bg, stroke: 0, rotation: -62))
        e.append(.shape(.rectangle, NRect(0.36, 0.474, 0.44, 0.012), .bg, stroke: 0, rotation: -62))
        e.append(.text(.subtitleOr("A NOVEL"), NRect(0.3, 0.65, 0.4, 0.018), SigType(["Montserrat-Black"], color: .muted, tracking: 0.4)))
        e.append(.text(.tagline, NRect(0.12, 0.88, 0.76, 0.022), SigType(["JosefinSans-Bold"], color: .muted, tracking: 0.2)))
        out.append(SignatureDesign(id: "horror-claw-marks", name: "Claw Marks", genre: .horror,
                                   idea: "Three clean cuts tear diagonally through a huge title like claw marks; violence implied, never shown.",
                                   tags: ["typographic", "dark", "visceral", "bold type", "condensed", "minimal"], elements: e,
                                   palettes: [SigPalette("Black & Bone", bg: "0C0B0A", ink: "EDE6D8", accent: "C1121F", muted: "7D766C", paper: "EDE6D8"),
                                              SigPalette("Night Forest", bg: "0E1611", ink: "E7EADF", accent: "D9A21B", muted: "727A6C", paper: "E7EADF"),
                                              SigPalette("Bone Ground", bg: "EAE3D3", ink: "141210", accent: "8E1B1B", muted: "6E665A", paper: "F5F0E6")],
                                   sample: SigSample(title: "Feral", author: "Dana Wolcott", tagline: "Something in the woods remembers the town.")))

        // Found Photograph: one old snapshot, a little too small, alone on a stained wall; a handwritten caption.
        e = []
        e.append(.fill(.material("mat.dust.palette.f"), .full))
        e.append(.shape(.rectangle, NRect(0.22, 0.16, 0.56, 0.42), .paper, stroke: 0, rotation: 0))
        e.append(.photo(NRect(0.25, 0.18, 0.5, 0.33), clip: nil, look: .sepia, focusY: 0.3, zoom: 1.1, index: 0, fallback: .material("mat.smoke.parchment.b")))
        e.append(.text(.tagline, NRect(0.26, 0.522, 0.48, 0.04), SigType(["CaveatBrush-Regular"], color: .bg, letterCase: .asTyped, breaks: .lines(2))))
        e.append(.text(.title, NRect(0.08, 0.66, 0.84, 0.13), SigType(["SpecialElite-Regular"], tracking: 0.04, lineHeight: 1.0, breaks: .lines(2))))
        e.append(.text(.author, NRect(0.1, 0.86, 0.8, 0.035), SigType(["JosefinSans-Bold"], color: .muted, tracking: 0.3)))
        out.append(SignatureDesign(id: "horror-found-photograph", name: "Found Photograph", genre: .horror,
                                   idea: "One old snapshot hangs alone on a stained wall, with a handwritten caption no one should have written.",
                                   tags: ["photo", "dark", "vintage", "found", "atmospheric", "moody"], elements: e,
                                   palettes: [SigPalette("Basement", bg: "1A1714", ink: "EAE2D2", accent: "4A2A1F", muted: "9A9182", paper: "F2EBDD"),
                                              SigPalette("Darkroom", bg: "0B0B0B", ink: "ECECEC", accent: "3A1414", muted: "8E8E8E", paper: "F4F2EC"),
                                              SigPalette("Mildew", bg: "23271F", ink: "E6E8DC", accent: "4A5A3E", muted: "8F9682", paper: "EEEEE2")],
                                   sample: SigSample(title: "The Last Photograph of Ada Price", author: "Wren Halloway", tagline: "she wasn't alone in the room", photo: "portrait")))

        return out
    }
}
