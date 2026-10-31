import Foundation

/// Suggests chords that could replace (or lead into) a chord, with the reason
/// a musician would give for each.
public enum Reharmonizer {
    public enum Kind: String, Sendable, CaseIterable {
        case color = "Add color"
        case substitute = "Same function"
        case borrowed = "Borrowed"
        case leading = "Lead into the next chord"
    }

    public struct Suggestion: Hashable, Sendable {
        public var chord: Chord
        public var kind: Kind
        public var reason: String
    }

    /// Modes to borrow from, with how to describe them.
    static let parallelModes: [(ScaleType, String)] = [
        (.naturalMinor, "minor"), (.major, "major"), (.dorian, "Dorian"),
        (.mixolydian, "Mixolydian"), (.lydian, "Lydian"), (.phrygian, "Phrygian"), (.harmonicMinor, "harmonic minor"),
    ]

    public static func suggestions(for chord: Chord, next: Chord?, key: Key) -> [Suggestion] {
        var out: [Suggestion] = []
        let name = { (c: Chord) in c.symbol(in: key) }

        // Color: richer versions of the same chord.
        let colors: [ChordQuality]
        switch chord.quality.triadFamily {
        case .major where chord.quality.isDominant:
            colors = [.dominant9, .dominant13, .dominant7sus4, .dominant7sharp9, .dominant7flat9, .dominant7flat13]
        case .major: colors = [.major7, .major9, .major6, .add9, .major7sharp11, .sus2]
        case .minor: colors = [.minor7, .minor9, .minor11, .minor6, .minorAdd9]
        case .diminished: colors = [.halfDiminished7, .diminished7]
        default: colors = [.dominant7sus4, .sus2, .major]
        }
        for q in colors where q != chord.quality {
            out.append(Suggestion(chord: Chord(root: chord.root, quality: q, bass: chord.bass), kind: .color,
                                  reason: "\(q.suffix.isEmpty ? "plain" : q.suffix) color on the same root"))
        }

        // Same function: diatonic chords that share at least two notes.
        let diatonic = (0..<7).map { key.diatonicChord(degree: $0, seventh: chord.coreIntervals.count >= 4) }
        for c in diatonic where c.root != chord.root {
            let shared = c.pitchClasses.intersection(chord.pitchClasses).count
            if shared >= 2 {
                out.append(Suggestion(chord: c, kind: .substitute,
                                      reason: "\(c.roman(in: key)) shares \(shared) notes with \(name(chord))"))
            }
        }
        // Inversions over a different bass keep the harmony but move the bass line.
        if let third = chord.third {
            out.append(Suggestion(chord: Chord(root: chord.root, quality: chord.quality, bass: third), kind: .substitute,
                                  reason: "first inversion: smoother bass line"))
        }

        // Borrowed from parallel modes: same root position in the scale, different mode.
        if let degree = key.degree(of: chord.root) {
            for (mode, label) in parallelModes where mode != key.scale.harmonicParent {
                let borrowed = Key(tonic: key.tonic, scale: mode).diatonicChord(degree: degree, seventh: chord.coreIntervals.count >= 4)
                guard borrowed.pitchClasses != chord.pitchClasses, !out.contains(where: { $0.chord == borrowed }) else { continue }
                out.append(Suggestion(chord: borrowed, kind: .borrowed,
                                      reason: "\(borrowed.roman(in: key)) from \(NoteName.name(key.tonic, flats: key.prefersFlats)) \(label)"))
            }
        }

        // Tritone substitution of a dominant.
        if chord.quality.isDominant {
            let sub = Chord(root: chord.root + 6, quality: .dominant7)
            out.append(Suggestion(chord: sub, kind: .substitute, reason: "tritone sub: same 3rd and 7th, chromatic bass"))
        }

        if let next {
            let target = next.root
            out.append(Suggestion(chord: Chord(root: target + 7, quality: .dominant7), kind: .leading,
                                  reason: "V7 of \(name(next)): pulls hard into it"))
            out.append(Suggestion(chord: Chord(root: target + 1, quality: .dominant7), kind: .leading,
                                  reason: "♭II7 of \(name(next)): slides down a half step"))
            out.append(Suggestion(chord: Chord(root: target - 1, quality: .diminished7), kind: .leading,
                                  reason: "passing diminished: climbs a half step into \(name(next))"))
            out.append(Suggestion(chord: Chord(root: target + 7, quality: .dominant7sus4), kind: .leading,
                                  reason: "sus dominant of \(name(next)): gospel-style lift"))
        }

        var seen = Set<Chord>([chord])
        return out.filter { seen.insert($0.chord).inserted }
    }
}

/// Famous chord progressions, written relative to the tonic so they work in any key.
public struct NamedProgression: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let mood: String
    public let minor: Bool
    /// (semitones above the tonic, quality, beats)
    public let chords: [Step]

    public struct Step: Hashable, Sendable {
        public let offset: Int
        public let quality: ChordQuality
        public let beats: Double?
        public let bass: Int?
    }

    public var romanSummary: String {
        let key = Key(tonic: 0, scale: minor ? .naturalMinor : .major)
        return chords.map { Chord(root: $0.offset, quality: $0.quality).roman(in: key) }.joined(separator: " – ")
    }

    /// Builds the progression in a key. Chords without a length take one bar.
    public func progression(tonic: Int, beatsPerBar: Int) -> Progression {
        Progression(slots: chords.map {
            ChordSlot(chord: Chord(root: tonic + $0.offset, quality: $0.quality, bass: $0.bass.map { tonic + $0 }),
                      beats: $0.beats ?? Double(beatsPerBar))
        })
    }

    static func p(_ name: String, _ mood: String, minor: Bool = false, _ steps: [(Int, ChordQuality)], beats: [Double]? = nil) -> NamedProgression {
        NamedProgression(name: name, mood: mood, minor: minor, chords: steps.enumerated().map { i, s in
            Step(offset: s.0, quality: s.1, beats: beats?[i], bass: nil)
        })
    }

    public static let library: [NamedProgression] = [
        p("Axis", "Pop", [(0, .major), (7, .major), (9, .minor), (5, .major)]),
        p("Sad Pop", "Pop", [(9, .minor), (5, .major), (0, .major), (7, .major)]),
        p("Doo-Wop", "Pop", [(0, .major), (9, .minor), (5, .major), (7, .major)]),
        p("Pachelbel", "Pop", [(0, .major), (7, .major), (9, .minor), (4, .minor), (5, .major), (0, .major), (5, .major), (7, .major)],
          beats: [2, 2, 2, 2, 2, 2, 2, 2]),
        p("Royal Road", "Pop", [(5, .major7), (7, .dominant7), (4, .minor7), (9, .minor)]),
        p("Mixolydian Rock", "Rock", [(0, .major), (10, .major), (5, .major), (0, .major)]),
        p("Epic Minor", "Cinematic", minor: true, [(0, .minor), (8, .major), (3, .major), (10, .major)]),
        p("Andalusian Cadence", "Cinematic", minor: true, [(0, .minor), (10, .major), (8, .major), (7, .dominant7)]),
        p("Minor Plagal Lift", "Cinematic", minor: true, [(0, .minor), (5, .minor), (10, .major), (3, .major)]),
        p("Lydian Float", "Cinematic", [(0, .major7), (2, .major), (0, .major7), (2, .major)]),
        p("ii–V–I", "Jazz", [(2, .minor7), (7, .dominant7), (0, .major7), (0, .major7)]),
        p("Rhythm Changes A", "Jazz", [(0, .major7), (9, .minor7), (2, .minor7), (7, .dominant7)], beats: [2, 2, 2, 2]),
        p("Minor ii–V–i", "Jazz", minor: true, [(2, .halfDiminished7), (7, .dominant7flat9), (0, .minor9), (0, .minor9)]),
        p("Backdoor", "Jazz", [(5, .minor7), (10, .dominant7), (0, .major7), (0, .major7)]),
        p("Neo-Soul Descent", "Soul", [(5, .major9), (4, .minor7), (2, .minor9), (0, .major9)]),
        p("Two-of-Us Turn", "Soul", [(5, .major7), (4, .dominant7sharp9), (9, .minor7), (7, .minor7), (0, .dominant9)],
          beats: [4, 4, 4, 2, 2]),
        p("Dorian Vamp", "Soul", minor: true, [(0, .minor9), (5, .dominant9), (0, .minor9), (5, .dominant9)]),
        p("Gospel 1–4", "Gospel", [(0, .major9), (5, .dominant9), (0, .major9), (7, .dominant7sus4)]),
        p("Gospel Walk-up", "Gospel", [(5, .major7), (6, .diminished7), (7, .dominant13), (9, .minor9)], beats: [2, 2, 2, 2]),
        p("Twelve-Bar Blues", "Blues", [(0, .dominant7), (0, .dominant7), (0, .dominant7), (0, .dominant7), (5, .dominant7), (5, .dominant7),
                                        (0, .dominant7), (0, .dominant7), (7, .dominant7), (5, .dominant7), (0, .dominant7), (7, .dominant7)]),
        p("Bossa Turnaround", "Latin", [(0, .major7), (2, .minor7), (7, .dominant9), (0, .major7)]),
        p("Afro Bounce", "African", [(0, .major), (5, .major), (9, .minor), (7, .major)]),
        p("Reggae One-Four", "Caribbean", [(0, .major), (5, .major), (0, .major), (5, .major)]),
        p("Classical Cadence", "Classical", [(0, .major), (5, .major), (7, .dominant7), (0, .major)]),
        p("Minor Lament", "Classical", minor: true, [(0, .minor), (7, .major), (5, .minor), (7, .dominant7)]),
    ]
}
