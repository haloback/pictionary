import Foundation

/// OpenAI CLIP's byte-level BPE tokenizer: a port of `clip/simple_tokenizer.py`
/// (bytes-to-unicode mapping, whitespace cleaning, lowercasing, the word regex, per-token BPE
/// with the "</w>" end-of-word convention, merge ranks from merges.txt, ids from vocab.json).
struct ClipTokenizer {
    /// Thread-safe memo of token -> BPE pieces, mirroring the Python `cache` dict.
    private final class PieceCache {
        private let lock = NSLock()
        private var store: [String: [String]] = [:]

        subscript(key: String) -> [String]? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return store[key]
            }
            set {
                lock.lock()
                store[key] = newValue
                lock.unlock()
            }
        }
    }

    static let startOfText = "<|startoftext|>"
    static let endOfText = "<|endoftext|>"

    let vocab: [String: Int]
    /// Merge pair ("a b") -> rank; lower merges first.
    let ranks: [String: Int]
    let bosID: Int32
    let eosID: Int32

    private let cache = PieceCache()

    /// Byte -> printable unicode scalar, exactly as `bytes_to_unicode()`.
    static let byteEncoder: [String] = {
        var bs: [Int] = []
        bs += Array(33...126)   // "!"..."~"
        bs += Array(161...172)  // "¡"..."¬"
        bs += Array(174...255)  // "®"..."ÿ"
        var cs: [Int] = bs
        var n: Int = 0
        for b in 0..<256 where !bs.contains(b) {
            bs.append(b)
            cs.append(256 + n)
            n += 1
        }
        var table: [String] = Array(repeating: "", count: 256)
        for (b, c) in zip(bs, cs) {
            if let scalar = Unicode.Scalar(c) { table[b] = String(Character(scalar)) }
        }
        return table
    }()

    /// Bytes-to-unicode as a dictionary (256 entries, a bijection).
    static func bytesToUnicode() -> [UInt8: String] {
        var out: [UInt8: String] = [:]
        for b in 0..<256 { out[UInt8(b)] = byteEncoder[b] }
        return out
    }

    /// The word-splitting pattern, case-insensitive (ICU `\p{L}` / `\p{N}` classes).
    static let pattern: NSRegularExpression = {
        let source: String = "<\\|startoftext\\|>|<\\|endoftext\\|>|'s|'t|'re|'ve|'m|'ll|'d|[\\p{L}]+|[\\p{N}]|[^\\s\\p{L}\\p{N}]+"
        // The pattern is a constant; a failure here is a programming error.
        return try! NSRegularExpression(pattern: source, options: [.caseInsensitive])
    }()

    // MARK: Init

    /// `merges` are lines of merges.txt, in file order; a leading "#version" header and blank lines are ignored.
    init(vocab: [String: Int], merges: [String]) {
        self.vocab = vocab
        var ranks: [String: Int] = [:]
        ranks.reserveCapacity(merges.count)
        var rank: Int = 0
        for line in merges {
            let trimmed: String = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts: [Substring] = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let key: String = String(parts[0]) + " " + String(parts[1])
            if ranks[key] == nil {
                ranks[key] = rank
                rank += 1
            }
        }
        self.ranks = ranks
        bosID = Int32(vocab[ClipTokenizer.startOfText] ?? 49406)
        eosID = Int32(vocab[ClipTokenizer.endOfText] ?? 49407)
        cache[ClipTokenizer.startOfText] = [ClipTokenizer.startOfText]
        cache[ClipTokenizer.endOfText] = [ClipTokenizer.endOfText]
    }

    /// Loads `vocab.json` and `merges.txt` from a directory.
    init(directory: URL) throws {
        let vocabURL: URL = directory.appendingPathComponent("vocab.json")
        let mergesURL: URL = directory.appendingPathComponent("merges.txt")
        let vocabData: Data = try Data(contentsOf: vocabURL)
        let json: Any = try JSONSerialization.jsonObject(with: vocabData, options: [])
        guard let raw = json as? [String: Any] else {
            throw TasteEngineError.badFile("vocab.json")
        }
        var vocab: [String: Int] = [:]
        vocab.reserveCapacity(raw.count)
        for (k, v) in raw {
            if let n = v as? NSNumber { vocab[k] = n.intValue } else if let i = v as? Int { vocab[k] = i }
        }
        guard !vocab.isEmpty else { throw TasteEngineError.badFile("vocab.json") }
        let mergesText: String = try String(contentsOf: mergesURL, encoding: .utf8)
        let lines: [String] = mergesText.components(separatedBy: "\n")
        self.init(vocab: vocab, merges: lines)
    }

    // MARK: Cleaning and splitting

    /// Collapses whitespace runs to one space, trims, lowercases (`whitespace_clean(basic_clean(text)).lower()`).
    static func clean(_ text: String) -> String {
        var out: String = ""
        out.reserveCapacity(text.count)
        var pendingSpace: Bool = false
        for ch in text {
            if ch.isWhitespace || ch.isNewline {
                pendingSpace = true
            } else {
                if pendingSpace && !out.isEmpty { out.append(" ") }
                pendingSpace = false
                out.append(ch)
            }
        }
        return out.lowercased()
    }

    /// The regex pieces of a cleaned text.
    static func split(_ cleaned: String) -> [String] {
        let ns: NSString = cleaned as NSString
        let whole: NSRange = NSRange(location: 0, length: ns.length)
        var out: [String] = []
        for m in pattern.matches(in: cleaned, options: [], range: whole) {
            out.append(ns.substring(with: m.range))
        }
        return out
    }

    /// Cleans and splits text into the pieces BPE runs on (before byte encoding).
    func pieces(_ text: String) -> [String] {
        ClipTokenizer.split(ClipTokenizer.clean(text))
    }

    /// Maps a piece's UTF-8 bytes through the byte encoder (one symbol per byte).
    static func byteEncode(_ piece: String) -> [String] {
        var out: [String] = []
        out.reserveCapacity(piece.utf8.count)
        for b in piece.utf8 { out.append(byteEncoder[Int(b)]) }
        return out
    }

    // MARK: BPE

    private static func pairs(of word: [String]) -> Set<String> {
        var out: Set<String> = []
        if word.count < 2 { return out }
        for i in 0..<(word.count - 1) { out.insert(word[i] + " " + word[i + 1]) }
        return out
    }

    /// Runs BPE on one byte-encoded token (symbols from `byteEncode`); the last symbol gets "</w>".
    func bpe(_ symbols: [String]) -> [String] {
        guard !symbols.isEmpty else { return [] }
        let key: String = symbols.joined()
        if let hit = cache[key] { return hit }
        var word: [String] = symbols
        word[word.count - 1] = word[word.count - 1] + "</w>"
        var pairs: Set<String> = ClipTokenizer.pairs(of: word)
        if pairs.isEmpty {
            cache[key] = word
            return word
        }
        while true {
            // Lowest-ranked pair present in the word.
            var best: String? = nil
            var bestRank: Int = Int.max
            for p in pairs {
                if let r = ranks[p], r < bestRank {
                    bestRank = r
                    best = p
                }
            }
            guard let bigram = best else { break }
            let halves: [Substring] = bigram.split(separator: " ", omittingEmptySubsequences: false)
            let first: String = String(halves[0])
            let second: String = String(halves[1])
            var merged: [String] = []
            merged.reserveCapacity(word.count)
            var i: Int = 0
            while i < word.count {
                // Find the next `first` at or after i.
                var j: Int = i
                while j < word.count && word[j] != first { j += 1 }
                if j == word.count {
                    merged.append(contentsOf: word[i...])
                    break
                }
                if j > i { merged.append(contentsOf: word[i..<j]) }
                i = j
                if i < word.count - 1 && word[i + 1] == second {
                    merged.append(first + second)
                    i += 2
                } else {
                    merged.append(word[i])
                    i += 1
                }
            }
            word = merged
            if word.count == 1 { break }
            pairs = ClipTokenizer.pairs(of: word)
        }
        cache[key] = word
        return word
    }

    /// BPE on a plain-text piece (convenience: byte-encodes, then merges).
    func bpe(word: String) -> [String] {
        if word == ClipTokenizer.startOfText || word == ClipTokenizer.endOfText { return [word] }
        return bpe(ClipTokenizer.byteEncode(word))
    }

    /// The BPE strings for a text, in order (what `self.bpe(token).split(' ')` yields in Python).
    func tokens(_ text: String) -> [String] {
        var out: [String] = []
        for piece in pieces(text) { out.append(contentsOf: bpe(word: piece)) }
        return out
    }

    /// Raw vocabulary ids for a text, without BOS/EOS or padding. Unknown pieces are skipped.
    func ids(_ text: String) -> [Int] {
        var out: [Int] = []
        for t in tokens(text) {
            if let id = vocab[t] { out.append(id) }
        }
        return out
    }

    /// `<|startoftext|>` + ids + `<|endoftext|>`, truncated to `length` (EOS kept last) and padded with 0 (mask 0).
    func encode(_ text: String, length: Int = 77) -> (ids: [Int32], mask: [Int32]) {
        let n: Int = max(2, length)
        var body: [Int32] = ids(text).map { Int32($0) }
        if body.count > n - 2 { body = Array(body.prefix(n - 2)) }
        var ids: [Int32] = [bosID]
        ids.append(contentsOf: body)
        ids.append(eosID)
        var mask: [Int32] = Array(repeating: 1, count: ids.count)
        while ids.count < n {
            ids.append(0)
            mask.append(0)
        }
        return (ids, mask)
    }
}
