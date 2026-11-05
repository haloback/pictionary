import Foundation
import NaturalLanguage

/// Reads the mood of a book from its title, subtitle, tagline and blurb using the NaturalLanguage
/// framework plus a hand-written lexicon, and turns that into palette and genre suggestions.
enum BriefMood {
    struct Mood {
        /// −1 (grim) ... 1 (joyful). 0 when the text gives nothing away.
        var sentiment: Double
        /// Mood tags from `vocabulary`, strongest first, at most 5.
        var tags: [String]
        /// Nouns and adjectives from the text, lowercased and deduplicated, at most 12.
        var keywords: [String]
    }

    /// Every tag `analyze` can produce.
    static let vocabulary: [String] = ["dark", "tense", "romantic", "cozy", "cosmic", "epic", "cold", "warm", "eerie",
                                       "historical", "quiet", "bold", "bright", "playful", "elegant", "gritty", "dreamy"]

    // MARK: Lexicon

    /// Word → mood tags. Words are lowercased; plurals and common inflections are listed explicitly.
    static let lexicon: [String: [String]] = {
        var l: [String: [String]] = [:]
        func add(_ words: [String], _ tags: [String]) {
            for w in words { l[w, default: []].append(contentsOf: tags) }
        }
        add(["blood", "bloody", "knife", "knives", "murder", "murderer", "dead", "death", "kill", "killer", "corpse", "grave",
             "poison", "gun", "bullet", "debt", "debts", "revenge", "vengeance", "betrayal", "crime", "shadow", "shadows"],
            ["dark", "tense"])
        add(["secret", "secrets", "lie", "lies", "liar", "hunt", "hunted", "hunter", "chase", "escape", "trap", "trapped",
             "missing", "vanished", "stranger", "witness", "conspiracy", "silence", "silent", "deadline", "run", "fear"],
            ["tense"])
        add(["love", "lover", "lovers", "kiss", "kisses", "heart", "hearts", "wedding", "bride", "groom", "passion", "desire",
             "romance", "romantic", "sweetheart", "darling", "crush", "forever", "vow", "vows", "honeymoon", "affair"],
            ["romantic"])
        add(["garden", "gardens", "tea", "teacup", "village", "cottage", "bakery", "bake", "baking", "cake", "cakes", "pie",
             "knitting", "quilt", "bookshop", "bookstore", "cat", "cats", "dog", "puppy", "kitten", "hearth", "fireplace",
             "cocoa", "trouble", "vicar", "parish", "lane", "inn", "cafe", "seaside"],
            ["cozy"])
        add(["star", "stars", "orbit", "ship", "starship", "galaxy", "galaxies", "planet", "planets", "moon", "moons", "space",
             "void", "nebula", "rocket", "cosmos", "cosmic", "alien", "aliens", "android", "robot", "robots", "colony", "signal"],
            ["cosmic"])
        add(["king", "kings", "queen", "queens", "sword", "swords", "dragon", "dragons", "throne", "crown", "kingdom", "realm",
             "prophecy", "quest", "legend", "wizard", "sorcerer", "witch", "blade", "knight", "knights", "empire", "warrior"],
            ["epic"])
        add(["snow", "winter", "ice", "frost", "frozen", "glacier", "blizzard", "arctic", "north", "tundra", "cold", "chill"],
            ["cold"])
        add(["summer", "sun", "sunshine", "beach", "beaches", "heat", "desert", "golden", "honey", "harvest", "orchard", "warm",
             "sunset", "sunrise", "island", "tropical", "fire", "ember", "embers"],
            ["warm"])
        add(["ghost", "ghosts", "haunt", "haunted", "haunting", "night", "midnight", "whisper", "whispers", "graveyard",
             "spirit", "spirits", "curse", "cursed", "demon", "nightmare", "hollow", "fog", "mist", "crypt", "bone", "bones"],
            ["eerie"])
        add(["war", "wars", "empire", "letter", "letters", "regiment", "duke", "duchess", "earl", "countess", "lord", "lady",
             "manor", "estate", "century", "revolution", "colonial", "victorian", "regency", "dynasty", "abbey", "cathedral"],
            ["historical"])
        add(["quiet", "small", "still", "stillness", "hush", "slow", "soft", "gentle", "ordinary", "plain", "lake", "meadow",
             "evening", "memory", "memories", "pause", "afternoon"],
            ["quiet"])
        add(["money", "power", "win", "winner", "winning", "success", "rich", "billion", "million", "boss", "empire", "deal",
             "hustle", "rules", "secrets", "strategy", "leader", "growth", "fast", "big"],
            ["bold"])
        add(["joy", "happy", "happiness", "laugh", "laughter", "light", "bright", "morning", "hope", "hopeful", "smile",
             "spring", "bloom", "rainbow", "delight"],
            ["bright"])
        add(["fun", "silly", "giggle", "party", "circus", "game", "games", "prank", "mischief", "wacky", "goofy", "candy",
             "balloon", "pirate", "pirates", "monster", "monsters", "unicorn"],
            ["playful"])
        add(["elegant", "elegance", "grace", "graceful", "silk", "velvet", "pearl", "pearls", "ballroom", "champagne",
             "opera", "salon", "couture", "ivory", "marble"],
            ["elegant"])
        add(["street", "streets", "city", "concrete", "alley", "gang", "cop", "cops", "detective", "gritty", "grit", "rust",
             "smoke", "whiskey", "noir", "dirt", "dust", "prison", "docks"],
            ["gritty"])
        add(["dream", "dreams", "dreaming", "dreamer", "cloud", "clouds", "wonder", "wander", "wandering", "drift", "fairy",
             "fairies", "moonlight", "lullaby", "wish", "wishes", "sleep", "sky", "feather"],
            ["dreamy"])
        return l
    }()

    /// Words that are never interesting keywords.
    static let stopWords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "of", "in", "on", "at", "to", "for", "with", "by", "from", "as", "is", "are", "was",
        "were", "be", "been", "it", "its", "this", "that", "these", "those", "he", "she", "they", "we", "you", "i", "his", "her",
        "their", "our", "your", "my", "me", "him", "them", "us", "who", "what", "when", "where", "why", "how", "some", "any",
        "all", "no", "not", "one", "two", "novel", "book", "story", "tale", "author", "new", "other", "same", "such", "than",
        "then", "there", "here", "into", "over", "under", "about", "after", "before", "more", "most", "very", "just", "only",
        "own", "s", "t", "will", "can", "may", "has", "have", "had", "do", "does", "did", "so", "if", "out", "up", "down"
    ]

    // MARK: Analysis

    static func analyze(title: String, subtitle: String, tagline: String, blurb: String = "") -> Mood {
        let text = [title, subtitle, tagline, blurb].filter { !$0.isEmpty }.joined(separator: ". ")
        guard !text.isEmpty else { return Mood(sentiment: 0, tags: [], keywords: []) }

        let sentiment = sentimentScore(text)
        let words = tokens(text)
        let keywords = extractKeywords(text, tokens: words)

        // Count lexicon hits over every word (verbs like "haunt" matter too), plus sentiment nudges.
        var hits: [String: Int] = [:]
        var order: [String] = []
        func bump(_ tag: String, _ n: Int = 1) {
            if hits[tag] == nil { order.append(tag) }
            hits[tag, default: 0] += n
        }
        for w in words {
            if let tags = lexicon[w] {
                for t in tags { bump(t) }
            } else if let stem = stemmed(w), let tags = lexicon[stem] {
                for t in tags { bump(t) }
            }
        }
        if sentiment <= -0.3 { bump("dark") }
        if sentiment >= 0.4 { bump("bright") }

        let ranked = order.sorted { a, b in
            let ha = hits[a] ?? 0, hb = hits[b] ?? 0
            if ha != hb { return ha > hb }
            return (order.firstIndex(of: a) ?? 0) < (order.firstIndex(of: b) ?? 0)
        }
        let tags = Array(ranked.filter { vocabulary.contains($0) }.prefix(5))
        return Mood(sentiment: sentiment, tags: tags, keywords: keywords)
    }

    /// NLTagger sentiment of the whole text, −1...1 (0 when the tagger has no opinion).
    static func sentimentScore(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        var total = 0.0, n = 0.0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore, options: []) { tag, _ in
            if let raw = tag?.rawValue, let v = Double(raw), v.isFinite {
                total += v
                n += 1
            }
            return true
        }
        guard n > 0 else { return 0 }
        return (total / n).clamped(-1, 1)
    }

    /// Lowercased alphabetic words in order.
    static func tokens(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var out: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let w = text[range].lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            if !w.isEmpty, w.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) { out.append(w) }
            return true
        }
        return out
    }

    /// Nouns and adjectives via NLTagger, lowercased and deduplicated, minus stop words, max 12.
    static func extractKeywords(_ text: String, tokens words: [String]) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var out: [String] = []
        var seen = Set<String>()
        func take(_ w: String) {
            guard w.count > 1, !stopWords.contains(w), !seen.contains(w) else { return }
            seen.insert(w)
            out.append(w)
        }
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitPunctuation, .omitWhitespace, .omitOther]) { tag, range in
            if tag == .noun || tag == .adjective {
                take(text[range].lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
            }
            return true
        }
        // Titles are often all proper nouns or ambiguous; make sure lexicon words are kept as keywords too.
        if out.count < 3 {
            for w in words where lexicon[w] != nil { take(w) }
        }
        return Array(out.prefix(12))
    }

    /// A crude singular/stem so "orchards", "haunting" and "kissed" still hit the lexicon.
    static func stemmed(_ w: String) -> String? {
        let suffixes = ["ies", "ing", "ed", "es", "s"]
        for s in suffixes where w.hasSuffix(s) && w.count > s.count + 2 {
            var base = String(w.dropLast(s.count))
            if s == "ies" { base += "y" }
            return base
        }
        return nil
    }

    // MARK: Suggestions

    /// Tag → words that, in a palette's name, mean it fits.
    static let paletteNameHints: [String: [String]] = [
        "dark": ["noir", "midnight", "blood", "storm", "smoke", "charcoal", "ink", "night", "deep", "wine"],
        "tense": ["noir", "blood", "storm", "electric", "crimson", "red"],
        "romantic": ["rose", "blush", "cherry", "blossom", "wine", "plum", "smoke rose", "sunset", "lavender"],
        "cozy": ["forest", "harvest", "sage", "honey", "mint", "terracotta", "linen", "moss", "lantern"],
        "cosmic": ["midnight", "nebula", "violet", "electric", "neon", "glacier", "ocean", "arctic"],
        "epic": ["royal", "gold", "bronze", "ember", "plum", "emerald", "midnight"],
        "cold": ["arctic", "glacier", "storm", "slate", "ocean", "ice"],
        "warm": ["ember", "honey", "desert", "sunset", "terracotta", "copper", "amber", "harvest"],
        "eerie": ["blood", "noir", "moss", "storm", "smoke", "wine"],
        "historical": ["sepia", "bronze", "archive", "royal", "desert", "copper", "ink and paper"],
        "quiet": ["sage", "linen", "mint", "ink and paper", "smoke rose", "slate", "glacier"],
        "bold": ["citrus", "electric", "neon", "mustard", "noir", "coral"],
        "bright": ["citrus", "coral", "mint", "honey", "sunset", "cherry"],
        "playful": ["citrus", "coral", "neon", "cherry", "mint"],
        "elegant": ["ink and paper", "royal", "midnight gold", "plum", "sage", "smoke rose"],
        "gritty": ["copper smoke", "charcoal", "storm", "noir", "ink"],
        "dreamy": ["lavender", "violet", "glacier", "cherry blossom", "mint", "rose"]
    ]

    /// `TemplateLibrary.palettes` ranked for the mood, best first. Always the whole list (≥ 3).
    static func palettes(for mood: Mood) -> [TemplateLibrary.NamedPalette] {
        let all = TemplateLibrary.palettes
        let genre = genreHint(for: mood)
        var scored: [(Int, Double)] = []
        for (i, p) in all.enumerated() {
            scored.append((i, score(p, mood: mood, genre: genre)))
        }
        scored.sort { a, b in
            if a.1 != b.1 { return a.1 > b.1 }
            return a.0 < b.0
        }
        return scored.map { all[$0.0] }
    }

    static func score(_ p: TemplateLibrary.NamedPalette, mood: Mood, genre: Genre?) -> Double {
        let name = p.name.lowercased()
        let dark = p.colors.first ?? .ink
        let accent = p.colors.count > 2 ? p.colors[2] : (p.colors.last ?? .ink)
        let hue = accent.hsl.h
        var s = 0.0
        for (rank, tag) in mood.tags.enumerated() {
            // Earlier tags are stronger.
            let weight = 1.0 / Double(rank + 1)
            if let hints = paletteNameHints[tag], hints.contains(where: { name.contains($0) }) { s += 2 * weight }
            switch tag {
            case "dark", "eerie", "tense":
                if dark.luminance < 0.08 { s += 1 * weight }
            case "warm":
                if hueIn(hue, 0, 60) { s += 1.5 * weight }
            case "cold":
                if hueIn(hue, 180, 260) { s += 1.5 * weight }
            case "romantic":
                if hueIn(hue, 300, 360) { s += 1.5 * weight }
            case "cosmic":
                if hueIn(hue, 160, 300) { s += 0.5 * weight }
            case "bright", "playful":
                if accent.hsl.s > 0.7 { s += 0.5 * weight }
            case "quiet", "elegant":
                if accent.hsl.s < 0.45 { s += 0.5 * weight }
            default:
                break
            }
        }
        if let g = genre, p.moods.contains(g) { s += 1 }
        return s
    }

    private static func hueIn(_ h: Double, _ lo: Double, _ hi: Double) -> Bool {
        let x = ((h.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        return x >= lo && x <= hi
    }

    /// The genre the strongest tag points to, or nil when the text gave no tags.
    static func genreHint(for mood: Mood) -> Genre? {
        guard let strongest = mood.tags.first else { return nil }
        switch strongest {
        case "dark", "tense", "gritty": return .thriller
        case "eerie": return .horror
        case "romantic": return .romance
        case "cozy", "warm", "playful": return .cozy
        case "cosmic": return .scienceFiction
        case "epic", "dreamy": return .fantasy
        case "historical": return .historical
        case "quiet", "elegant", "cold": return .literary
        case "bold", "bright": return .nonfiction
        default: return nil
        }
    }
}
