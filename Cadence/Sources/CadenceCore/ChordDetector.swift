import Foundation

/// Reads a chord progression out of an imported MIDI file or typed text.
public enum ChordDetector {
    static let candidates: [ChordQuality] = [.major, .minor, .dominant7, .major7, .minor7, .halfDiminished7,
                                              .diminished, .sus4, .sus2, .major9, .minor9, .dominant9, .major6, .minor6]

    /// Best chord for a pitch-class weight profile (12 values).
    public static func detectChord(weights: [Double], bass: Int?) -> Chord? {
        let total = weights.reduce(0, +)
        guard total > 0.0001 else { return nil }
        var best: Chord?
        var bestScore = -Double.infinity
        for root in 0..<12 {
            for q in candidates {
                let pcs = Set(q.intervals.map { mod12(root + $0) })
                var inside = 0.0, outside = 0.0
                for pc in 0..<12 {
                    if pcs.contains(pc) { inside += weights[pc] } else { outside += weights[pc] }
                }
                // Unplayed chord tones count against a candidate; root and 3rd matter most.
                var missing = 0.0
                for (n, iv) in q.intervals.enumerated() where weights[mod12(root + iv)] < total * 0.02 {
                    missing += n < 2 ? 0.35 : 0.15
                }
                var score = inside / total - 0.9 * outside / total - missing - Double(q.intervals.count) * 0.012
                if bass == root { score += 0.12 }
                if score > bestScore {
                    bestScore = score
                    best = Chord(root: root, quality: q)
                }
            }
        }
        if var b = best, let bass, bass != b.root, b.pitchClasses.contains(bass) {
            b.bass = bass
            best = b
        }
        return best
    }

    static let majorProfile = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    static let minorProfile = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    /// Krumhansl–Schmuckler key finding.
    public static func detectKey(weights: [Double]) -> Key {
        func corr(_ a: [Double], _ b: [Double]) -> Double {
            let ma = a.reduce(0, +) / 12, mb = b.reduce(0, +) / 12
            var num = 0.0, da = 0.0, db = 0.0
            for i in 0..<12 {
                num += (a[i] - ma) * (b[i] - mb)
                da += (a[i] - ma) * (a[i] - ma)
                db += (b[i] - mb) * (b[i] - mb)
            }
            return da * db > 0 ? num / sqrt(da * db) : 0
        }
        var best = Key(tonic: 0, scale: .major)
        var bestScore = -2.0
        for tonic in 0..<12 {
            let rotated = (0..<12).map { weights[mod12($0 + tonic)] }
            let maj = corr(rotated, majorProfile), min = corr(rotated, minorProfile)
            if maj > bestScore { bestScore = maj; best = Key(tonic: tonic, scale: .major) }
            if min > bestScore { bestScore = min; best = Key(tonic: tonic, scale: .naturalMinor) }
        }
        return best
    }

    /// Detects chord changes every half bar and merges repeats.
    public static func progression(from notes: [MIDIFile.Note], beatsPerBar: Int, maxBars: Int = 16) -> (Progression, Key)? {
        let pitched = notes.filter { $0.channel != 9 }
        guard !pitched.isEmpty else { return nil }
        let first = (pitched.map(\.start).min() ?? 0)
        let origin = (first / Double(beatsPerBar)).rounded(.down) * Double(beatsPerBar)
        let lastEnd = pitched.map { $0.start + $0.duration }.max() ?? 0
        let windowBeats = beatsPerBar % 2 == 0 ? Double(beatsPerBar) / 2 : Double(beatsPerBar)
        let totalBeats = min(lastEnd - origin, Double(maxBars * beatsPerBar))
        let windowCount = max(1, Int((totalBeats / windowBeats).rounded(.up)))

        var global = [Double](repeating: 0, count: 12)
        var chords: [Chord?] = []
        for w in 0..<windowCount {
            let ws = origin + Double(w) * windowBeats, we = ws + windowBeats
            var weights = [Double](repeating: 0, count: 12)
            var lowest: (Int, Double)?
            for n in pitched {
                let overlap = min(n.start + n.duration, we) - max(n.start, ws)
                guard overlap > 0.01 else { continue }
                let weight = overlap * (Double(n.velocity) / 127 + 0.3)
                weights[mod12(n.pitch)] += weight
                if overlap > windowBeats * 0.25, lowest == nil || n.pitch < lowest!.0 { lowest = (n.pitch, overlap) }
            }
            for i in 0..<12 { global[i] += weights[i] }
            chords.append(detectChord(weights: weights, bass: lowest.map { mod12($0.0) }))
        }
        // Fill rests with the previous chord, then merge repeats.
        var filled: [Chord] = []
        for c in chords {
            if let c { filled.append(c) } else if let last = filled.last { filled.append(last) }
        }
        guard !filled.isEmpty else { return nil }
        var slots: [ChordSlot] = []
        for c in filled {
            if let last = slots.last, last.chord == c {
                slots[slots.count - 1].beats += windowBeats
            } else {
                slots.append(ChordSlot(chord: c, beats: windowBeats))
            }
        }
        // Round the loop up to whole bars.
        let total = slots.reduce(0) { $0 + $1.beats }
        let remainder = total.truncatingRemainder(dividingBy: Double(beatsPerBar))
        if remainder > 0.01 { slots[slots.count - 1].beats += Double(beatsPerBar) - remainder }
        let key = detectKey(weights: global)
        return (Progression(slots: slots), key)
    }

    /// Parses text like "Dm9 G13 | Cmaj9 | A7b13". Bars are separated by `|`;
    /// without bars, each chord gets one bar.
    public static func progression(fromText text: String, beatsPerBar: Int) -> Progression? {
        let cleaned = text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: ",", with: " ")
        let hasBars = cleaned.contains("|")
        let bars = hasBars ? cleaned.split(separator: "|").map(String.init) : cleaned.split(separator: " ").map(String.init)
        var slots: [ChordSlot] = []
        for bar in bars {
            let tokens = bar.split(separator: " ").map(String.init).filter { !$0.isEmpty }
            let chords = tokens.compactMap { Chord.parse($0) }
            guard !chords.isEmpty else { continue }
            let each = Double(beatsPerBar) / Double(chords.count)
            slots += chords.map { ChordSlot(chord: $0, beats: each) }
        }
        return slots.isEmpty ? nil : Progression(slots: slots)
    }

    /// Key that best fits a progression's chords.
    public static func key(for progression: Progression) -> Key {
        var w = [Double](repeating: 0, count: 12)
        for s in progression.slots {
            for pc in s.chord.pitchClasses { w[pc] += s.beats }
            w[s.chord.root] += s.beats * 0.8
        }
        if let first = progression.slots.first { w[first.chord.root] += 2 }
        return detectKey(weights: w)
    }
}
