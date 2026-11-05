import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Drafts back-cover copy from the author's synopsis. On macOS 26 with Apple Intelligence it asks the
/// on-device language model; everywhere else (and whenever the model fails) it builds an extractive
/// draft from the synopsis with NaturalLanguage: the strongest sentences, in order, plus a stakes line.
/// Nothing leaves the Mac either way.
enum BlurbWriter {
    enum Tone: String, CaseIterable, Identifiable {
        case gripping, warm, literary, witty, epic

        var id: String { rawValue }

        var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

        /// How the tone is described to the model.
        var instruction: String {
            switch self {
            case .gripping: return "urgent and tense, short punchy sentences, present tense"
            case .warm: return "warm, inviting and emotionally generous, with gentle humour allowed"
            case .literary: return "measured, elegant and evocative, with restraint rather than hype"
            case .witty: return "light, dry and playful, with one well-placed joke at most"
            case .epic: return "grand and sweeping, with a sense of scale, fate and consequence"
            }
        }
    }

    // MARK: On-device model

    /// True only when the FoundationModels framework is linked and the system model is ready to use.
    static var usesOnDeviceModel: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    static func draft(book: BookInfo, synopsis: String, tone: Tone) async -> String {
        let synopsis = synopsis.trimmingCharacters(in: .whitespacesAndNewlines)
        #if canImport(FoundationModels)
        if #available(macOS 26, *), usesOnDeviceModel {
            if let text = await modelDraft(book: book, synopsis: synopsis, tone: tone) {
                return text
            }
        }
        #endif
        return extractiveDraft(book: book, synopsis: synopsis, tone: tone)
    }

    /// The prompt sent to the on-device model. Exposed so the wording can be tested without the model.
    static func prompt(book: BookInfo, synopsis: String, tone: Tone) -> String {
        var lines: [String] = []
        lines.append("Write the back-cover blurb for a \(book.genre.label.lowercased()) novel.")
        if !book.title.isEmpty { lines.append("Title: \(book.title)") }
        if !book.subtitle.isEmpty { lines.append("Subtitle: \(book.subtitle)") }
        if !book.author.isEmpty { lines.append("Author: \(book.author)") }
        if !book.series.isEmpty { lines.append("Series: \(book.series)") }
        lines.append("Tone: \(tone.instruction).")
        lines.append("")
        lines.append("Rules:")
        lines.append("- Exactly three short paragraphs separated by blank lines, 120 to 180 words in total.")
        lines.append("- The first line is a hook: one striking sentence that makes a browser keep reading.")
        lines.append("- Use only facts from the synopsis below. Do not invent names, places or events.")
        lines.append("- Reveal nothing that happens after the midpoint of the synopsis; no spoilers, no ending.")
        lines.append("- End on a question or a line about what is at stake.")
        lines.append("- No quotation marks, no review quotes, no headings, no bullet points, no title repeated.")
        lines.append("- Plain prose only; return just the blurb text.")
        lines.append("")
        lines.append("Synopsis:")
        lines.append(synopsis)
        return lines.joined(separator: "\n")
    }

    #if canImport(FoundationModels)
    @available(macOS 26, *)
    private static func modelDraft(book: BookInfo, synopsis: String, tone: Tone) async -> String? {
        do {
            let session = LanguageModelSession(instructions: "You are a seasoned publishing copywriter who writes back-cover blurbs for novels. You never spoil endings and you never invent plot details.")
            let response = try await session.respond(to: prompt(book: book, synopsis: synopsis, tone: tone))
            let text = clean(response.content)
            let words = wordCount(text)
            guard words >= 60, words <= 260 else { return nil }
            return text
        } catch {
            return nil
        }
    }
    #endif

    /// Strips quotes and stray markup the model might add, and normalizes paragraph breaks.
    static func clean(_ raw: String) -> String {
        var paragraphs: [String] = []
        for block in raw.components(separatedBy: "\n") {
            var line = block.trimmingCharacters(in: .whitespaces)
            while line.hasPrefix("#") || line.hasPrefix("-") || line.hasPrefix("*") { line.removeFirst(); line = line.trimmingCharacters(in: .whitespaces) }
            line = line.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "“", with: "").replacingOccurrences(of: "”", with: "")
            if line.isEmpty { continue }
            paragraphs.append(line)
        }
        return paragraphs.joined(separator: "\n\n")
    }

    // MARK: Extractive draft

    /// A sentence of the synopsis with everything the scorer looked at.
    struct Candidate {
        var index: Int
        var text: String
        var words: Int
        var hook: Double
        var named: Bool
        var score: Double
    }

    static func extractiveDraft(book: BookInfo, synopsis: String, tone: Tone) -> String {
        let sentences = self.sentences(synopsis)
        guard !sentences.isEmpty else { return stakesLine(genre: book.genre, tone: tone, seed: book.title.utf8.count) }
        let candidates = scored(sentences, genre: book.genre, tone: tone)
        let chosen = choose(candidates)
        guard let hook = chosen.max(by: { ($0.hook, -$0.index) < ($1.hook, -$1.index) }) else {
            return stakesLine(genre: book.genre, tone: tone, seed: synopsis.utf8.count)
        }

        var first = hook.text
        if hook.words > 20 { first = fragment(hook.text) }

        var rest = chosen.filter { $0.index != hook.index }
        var middle: [String] = []
        while middle.count < 3, !rest.isEmpty { middle.append(rest.removeFirst().text) }
        // Pad a thin draft with what's left, so the blurb has some body.
        var body = wordCount(first) + middle.reduce(0) { $0 + wordCount($1) }
        while body < 60, !rest.isEmpty {
            let s = rest.removeFirst()
            middle.append(s.text)
            body += s.words
        }

        let stakes = stakesLine(genre: book.genre, tone: tone, seed: synopsis.utf8.count)
        var paragraphs = [first]
        if !middle.isEmpty { paragraphs.append(middle.joined(separator: " ")) }
        paragraphs.append(stakes)
        return paragraphs.joined(separator: "\n\n")
    }

    /// Sentences of the text, trimmed, via NLTokenizer.
    static func sentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var out: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { out.append(s) }
            return true
        }
        return out
    }

    static func scored(_ sentences: [String], genre: Genre, tone: Tone) -> [Candidate] {
        let n = sentences.count
        let midpoint = n / 2
        let wanted: Set<String> = [genre.rawValue, tone.rawValue]
        var out: [Candidate] = []
        for (i, s) in sentences.enumerated() {
            // Anything after the midpoint that reads like a resolution is a spoiler: drop it.
            if i >= midpoint, looksLikeResolution(s) { continue }
            let words = wordCount(s)
            let tokens = BriefMood.tokens(s)
            var hook = 0.0
            for t in tokens {
                guard let tags = lexicon[t] else { continue }
                // Any hook word counts a little; one that fits the genre or tone counts more.
                hook += 0.4
                if !wanted.isDisjoint(with: tags) { hook += 1.0 }
            }
            let named = hasNamedEntity(s)
            var score = hook
            if named { score += 1.0 }
            let third = Double(i) / Double(max(1, n))
            if third < 1.0 / 3.0 { score += 1.5 } else if third < 2.0 / 3.0 { score += 0.5 }
            if words >= 8, words <= 28 {
                score += 0.8
            } else if words < 8 {
                score -= 0.6
            } else {
                score -= 0.1 * Double(words - 28)
            }
            out.append(Candidate(index: i, text: s, words: words, hook: hook, named: named, score: score))
        }
        return out
    }

    /// 4–6 of the best candidates, in original order, with at least one from the first third.
    static func choose(_ candidates: [Candidate]) -> [Candidate] {
        guard !candidates.isEmpty else { return [] }
        let count = min(candidates.count, candidates.count >= 9 ? 6 : max(4, min(candidates.count, 5)))
        let ranked = candidates.sorted { ($0.score, -$0.index) > ($1.score, -$1.index) }
        var picked = Array(ranked.prefix(count))
        let total = (candidates.last?.index ?? 0) + 1
        let firstThird = { (c: Candidate) in Double(c.index) / Double(max(1, total)) < 1.0 / 3.0 }
        if !picked.contains(where: firstThird), let early = ranked.first(where: firstThird), let last = picked.indices.last {
            picked[last] = early
        }
        return picked.sorted { $0.index < $1.index }
    }

    /// Trims a long sentence to the clauses before its later commas, keeping at most ~20 words.
    static func fragment(_ sentence: String) -> String {
        let pieces = sentence.components(separatedBy: ",")
        guard pieces.count > 1 else { return sentence }
        var kept: [String] = []
        var words = 0
        for p in pieces {
            let w = wordCount(p)
            if !kept.isEmpty, words + w > 20 { break }
            kept.append(p)
            words += w
        }
        var out = kept.joined(separator: ",").trimmingCharacters(in: .whitespaces)
        while let last = out.last, ",;:".contains(last) { out.removeLast() }
        if let last = out.last, !".!?…".contains(last) { out += "." }
        return out
    }

    static func hasNamedEntity(_ sentence: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = sentence
        var found = false
        let kinds: Set<NLTag> = [.personalName, .placeName, .organizationName]
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, _ in
            if let tag, kinds.contains(tag) { found = true; return false }
            return true
        }
        return found
    }

    static func looksLikeResolution(_ sentence: String) -> Bool {
        let lower = sentence.lowercased()
        for phrase in resolutionPhrases where lower.contains(phrase) { return true }
        return false
    }

    /// Phrases that signal the story's resolution. Matched as substrings of the lowercased sentence.
    static let resolutionPhrases: [String] = [
        "in the end", "finally", "at last", "realizes", "realises", "realized", "realised", "turns out", "turned out",
        "is revealed", "was revealed", "reveals that", "revealed that", "confesses", "confessed", "the truth is",
        "ultimately", "in the final", "the killer is", "the killer was", "was behind it", "is behind it", "they marry",
        "happily ever after", "defeats", "defeated", "destroys", "destroyed", "dies", "died", "is dead", "survives",
        "survived", "escapes", "escaped", "epilogue", "years later", "saves the", "saved the", "wins", "won the",
        "reunited", "reunite", "forgives", "forgave", "the ending", "ends with", "comes home", "came home"
    ]

    // MARK: Lexicon

    /// Hook word → genre and tone tags (raw values of `Genre` and `Tone`). Lowercased; inflections listed.
    static let lexicon: [String: [String]] = {
        var l: [String: [String]] = [:]
        func add(_ words: [String], _ tags: [String]) {
            for w in words { l[w, default: []].append(contentsOf: tags) }
        }
        add(["secret", "secrets", "dead", "death", "missing", "hunt", "hunted", "hunter", "killer", "murder", "murdered",
             "body", "bodies", "lie", "lies", "conspiracy", "witness", "trap", "trapped", "chase", "escape", "run",
             "deadline", "danger", "dangerous", "threat", "target", "assassin", "spy", "agent", "hostage", "ransom",
             "vanished", "disappeared", "stalker", "bomb", "countdown", "betrayal", "betrayed", "cover-up"],
            ["thriller", "gripping"])
        add(["detective", "inspector", "clue", "clues", "suspect", "suspects", "alibi", "case", "crime", "evidence",
             "investigation", "investigate", "poison", "corpse", "confession", "motive", "victim", "unsolved", "cold"],
            ["mystery", "gripping"])
        add(["haunted", "haunting", "ghost", "ghosts", "nightmare", "scream", "screams", "darkness", "shadow", "shadows",
             "blood", "bone", "bones", "curse", "cursed", "demon", "possessed", "whisper", "whispers", "basement", "attic",
             "cellar", "grave", "graveyard", "creature", "something", "nobody", "alone"],
            ["horror", "gripping"])
        add(["heart", "hearts", "kiss", "kissed", "past", "second chance", "love", "loved", "lover", "wedding", "bride",
             "fake", "pretend", "enemies", "rival", "rivals", "spark", "sparks", "chemistry", "romance", "date", "dating",
             "ex", "crush", "passion", "desire", "forever", "promise", "promised", "wedding", "widow", "widower"],
            ["romance", "warm"])
        add(["magic", "magical", "sword", "swords", "dragon", "dragons", "kingdom", "throne", "crown", "prophecy", "queen",
             "king", "realm", "quest", "witch", "wizard", "sorcerer", "sorceress", "empire", "war", "blade", "oath",
             "legend", "chosen", "ancient", "gods", "goddess", "spell", "spells", "fae", "mage", "heir"],
            ["fantasy", "epic"])
        add(["ship", "starship", "colony", "planet", "planets", "orbit", "galaxy", "android", "ai", "signal", "alien",
             "aliens", "station", "mission", "launch", "crew", "machine", "machines", "future", "virus", "experiment",
             "clone", "clones", "mars", "earth", "void", "simulation", "upload"],
            ["scienceFiction", "epic"])
        add(["mother", "father", "daughter", "son", "family", "families", "grief", "memory", "memories", "silence",
             "home", "house", "inheritance", "marriage", "childhood", "sister", "brother", "loss", "lost", "letters",
             "years", "decades", "generations", "belong", "belonging", "becoming", "leaving", "return", "returns"],
            ["literary", "warm"])
        add(["war", "wartime", "regiment", "soldier", "soldiers", "letter", "letters", "duke", "duchess", "countess",
             "lord", "lady", "manor", "estate", "court", "revolution", "plague", "siege", "century", "empire", "exile",
             "colony", "abbey", "cathedral", "crusade", "dynasty", "fleet", "harbor", "harbour"],
            ["historical", "epic"])
        add(["school", "senior", "prom", "crush", "parents", "summer", "best friend", "friends", "secret", "first",
             "seventeen", "sixteen", "scholarship", "graduation", "band", "team", "dare", "truth", "rumor", "rumors"],
            ["youngAdult", "warm"])
        add(["bakery", "bookshop", "cafe", "village", "cottage", "garden", "tea", "cat", "dog", "recipe", "inn",
             "festival", "neighbor", "neighbors", "neighbour", "neighbours", "knitting", "quilt", "wedding", "pie",
             "lighthouse", "harbor", "seaside", "sisters", "cousin", "aunt", "grandmother", "grandfather"],
            ["cozy", "warm"])
        add(["history", "science", "evidence", "research", "discover", "discovery", "journey", "guide", "method", "lessons",
             "true", "untold", "inside", "revealed", "story", "stories", "how", "why", "rise", "fall", "decline"],
            ["nonfiction", "literary"])
        add(["i", "me", "my", "mother", "father", "childhood", "grew", "survived", "survival", "recovery", "faith",
             "addiction", "escape", "refugee", "immigrant", "hometown", "diagnosis", "grief", "healing", "told"],
            ["memoir", "warm"])
        add(["unfortunately", "disaster", "accidentally", "somehow", "terrible", "ridiculous", "perfectly", "absolutely",
             "mishap", "chaos", "awkward", "allegedly", "definitely", "technically", "plan", "plans", "scheme", "schemes",
             "hilarious", "worst", "wrong", "mistake", "mistakes", "fiasco", "oops"],
            ["witty"])
        add(["everything", "nothing", "never", "always", "only", "last", "first", "one", "must", "before", "until",
             "unless", "because", "now", "tonight", "when", "once", "whoever", "whatever", "cost", "price", "stakes",
             "choice", "choose", "survive", "fight", "truth", "lies", "question", "answer", "answers", "find", "found"],
            ["gripping", "epic", "literary"])
        add(["sweeping", "destiny", "fate", "legacy", "empire", "crown", "battle", "battles", "army", "armies", "ages",
             "centuries", "world", "worlds", "continent", "sea", "seas", "mountain", "mountains", "storm", "storms"],
            ["epic"])
        return l
    }()

    // MARK: Stakes templates

    struct StakesTemplate {
        /// Nil means any genre.
        var genres: Set<Genre>?
        /// Nil means any tone.
        var tones: Set<Tone>?
        var text: String
    }

    /// Generic closing lines: they name no character, place or event, so they can never contradict the plot.
    static let templates: [StakesTemplate] = {
        var t: [StakesTemplate] = []
        func add(_ genres: [Genre]?, _ tones: [Tone]?, _ text: String) {
            t.append(StakesTemplate(genres: genres.map { Set($0) }, tones: tones.map { Set($0) }, text: text))
        }
        add([.thriller], [.gripping], "Some doors, once opened, never close.")
        add([.thriller], [.gripping], "The clock is running. The truth is not on her side.")
        add([.thriller], [.epic], "Trust no one. Not even the people who sent you.")
        add([.thriller, .mystery], [.witty], "Everybody has a secret. Only one of them is worth killing for.")
        add([.mystery], [.gripping], "Every answer raises a darker question.")
        add([.mystery], [.literary], "Some truths are buried for a reason. Some people dig anyway.")
        add([.mystery, .cozy], [.warm], "In a town this small, nobody's business stays their own for long.")
        add([.mystery, .cozy], [.witty], "Solving a murder was never on the to-do list.")
        add([.horror], [.gripping], "Something is waiting. It has been waiting a long time.")
        add([.horror], [.literary], "The house remembers everything. Soon, so will you.")
        add([.horror], [.epic], "Some things should stay buried. This one didn't.")
        add([.romance], [.warm], "Sometimes the hardest thing to fight for is a second chance.")
        add([.romance], [.witty], "Falling in love was not part of the plan. Then again, neither was the plan.")
        add([.romance], [.gripping], "What if the one thing she never wanted is the only thing she can't walk away from?")
        add([.romance], [.literary], "A story about the distance between what we say and what we mean.")
        add([.fantasy], [.epic], "A crown is only as safe as the hands that hold it.")
        add([.fantasy], [.gripping], "Power always has a price. Someone has to pay it.")
        add([.fantasy], [.warm], "Magic is easy. Belonging is the hard part.")
        add([.fantasy, .scienceFiction], [.witty], "Saving the world would be easier if anyone had read the manual.")
        add([.scienceFiction], [.epic], "Out here, the stars don't care who you were.")
        add([.scienceFiction], [.gripping], "The signal is real. What answers it may not be.")
        add([.scienceFiction], [.literary], "What makes us human may be the first thing we lose.")
        add([.literary], [.warm], "A story about what we owe the people who made us.")
        add([.literary], [.literary], "What we inherit is never only what we were given.")
        add([.literary], [.gripping], "Some families keep secrets. Some secrets keep families.")
        add([.literary, .memoir], [.witty], "Growing up is easy. Growing out of it is another matter.")
        add([.historical], [.epic], "History remembers the victors. This is the story of everyone else.")
        add([.historical], [.literary], "In an age that demanded silence, she chose to be heard.")
        add([.historical], [.warm], "Across years and oceans, some promises hold.")
        add([.youngAdult], [.warm], "Growing up means finding out who you are when nobody is watching.")
        add([.youngAdult], [.gripping], "Senior year was supposed to be the easy part.")
        add([.youngAdult], [.witty], "Surviving high school is hard enough without a secret like this one.")
        add([.cozy], [.warm], "Sometimes the life you need is the one you least expected.")
        add([.cozy], [.witty], "New beginnings, old grudges and far too much cake.")
        add([.nonfiction], [.literary], "A clear-eyed account of how we got here and where we go next.")
        add([.nonfiction], [.gripping], "The real story is stranger, and more urgent, than anything you've heard.")
        add([.nonfiction], [.epic], "A sweeping account that changes how we see the world we thought we knew.")
        add([.memoir], [.warm], "A memoir about leaving, returning and finding out what home means.")
        add([.memoir], [.literary], "An unflinching account of a life pieced back together, one truth at a time.")
        add([.memoir], [.gripping], "The hardest story to tell is the one you lived.")
        add(nil, [.gripping], "How far would you go to protect the truth?")
        add(nil, [.warm], "A story about the people who stay, and the ones who find their way back.")
        add(nil, [.literary], "A novel about what we carry, and what we finally set down.")
        add(nil, [.witty], "It was never going to be simple. It was never going to be dull, either.")
        add(nil, [.epic], "Everything that came before was only the beginning.")
        add(nil, nil, "What happens next will change everything.")
        return t
    }()

    /// A closing line that fits the genre and tone; deterministic for a given seed.
    static func stakesLine(genre: Genre, tone: Tone, seed: Int) -> String {
        let exact = templates.filter { ($0.genres?.contains(genre) ?? false) && ($0.tones?.contains(tone) ?? false) }
        let genreOnly = templates.filter { ($0.genres?.contains(genre) ?? false) && $0.tones == nil }
        let toneOnly = templates.filter { $0.genres == nil && ($0.tones?.contains(tone) ?? false) }
        let generic = templates.filter { $0.genres == nil && $0.tones == nil }
        let pool = !exact.isEmpty ? exact : (!genreOnly.isEmpty ? genreOnly : (!toneOnly.isEmpty ? toneOnly : generic))
        guard !pool.isEmpty else { return "What happens next will change everything." }
        return pool[abs(seed) % pool.count].text
    }

    // MARK: Utilities

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Cuts the blurb down to at most `words`, dropping whole sentences from the end and keeping
    /// paragraph breaks. If even the first sentence is too long it is cut mid-sentence with an ellipsis.
    static func shorten(_ blurb: String, to words: Int) -> String {
        guard words > 0 else { return "" }
        guard wordCount(blurb) > words else { return blurb }
        var budget = words
        var paragraphs: [String] = []
        for block in blurb.components(separatedBy: "\n\n") {
            if budget <= 0 { break }
            var kept: [String] = []
            for s in sentences(block) {
                let w = wordCount(s)
                if w > budget { break }
                kept.append(s)
                budget -= w
            }
            if !kept.isEmpty { paragraphs.append(kept.joined(separator: " ")) }
            if budget <= 0 { break }
        }
        if paragraphs.isEmpty {
            let first = sentences(blurb).first ?? blurb
            let cut = first.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).prefix(words).joined(separator: " ")
            return cut + "…"
        }
        return paragraphs.joined(separator: "\n\n")
    }
}
