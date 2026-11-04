import Foundation

/// A part of the song (verse, chorus…) with its own length, energy and,
/// optionally, its own chords.
public struct SongSection: Identifiable, Hashable, Codable, Sendable {
    public var id = UUID()
    public var name: String
    public var kind: SectionKind
    public var bars: Int
    /// 0 = whisper, 1 = full band.
    public var intensity: Double
    /// Key into `Session.sectionProgressions`; nil plays the main progression.
    /// Sections that share a key (every chorus) share their chords.
    public var chordsKey: String?

    public init(name: String, kind: SectionKind, bars: Int, intensity: Double, chordsKey: String?) {
        self.name = name
        self.kind = kind
        self.bars = bars
        self.intensity = intensity
        self.chordsKey = chordsKey
    }
}

public enum SectionKind: String, CaseIterable, Codable, Sendable {
    case intro, verse, preChorus, chorus, bridge, breakdown, outro

    public var displayName: String {
        switch self {
        case .intro: return "Intro"
        case .verse: return "Verse"
        case .preChorus: return "Pre-Chorus"
        case .chorus: return "Chorus"
        case .bridge: return "Bridge"
        case .breakdown: return "Breakdown"
        case .outro: return "Outro"
        }
    }

    public var defaultBars: Int {
        switch self {
        case .intro, .preChorus, .breakdown, .outro: return 4
        case .verse, .chorus, .bridge: return 8
        }
    }

    public var defaultIntensity: Double {
        switch self {
        case .intro: return 0.35
        case .verse: return 0.6
        case .preChorus: return 0.75
        case .chorus: return 1.0
        case .bridge: return 0.7
        case .breakdown: return 0.25
        case .outro: return 0.4
        }
    }

    /// Choruses, pre-choruses and bridges get chords of their own.
    var ownChords: Bool { self == .chorus || self == .preChorus || self == .bridge }
}

/// Where a bar sits in the song.
public struct BarHarmony: Sendable {
    public let progression: Progression
    /// Identifies the progression for voicing caches ("main" or a section key).
    public let progressionKey: String
    /// Bar index counted from the start of its section (or the song).
    public let localBar: Int
    public let sectionIndex: Int?
    public let intensity: Double
    public let isSectionStart: Bool
    public let isSectionEnd: Bool
    /// Intensity of what comes next, for build-ups.
    public let nextIntensity: Double
}

extension Session {
    public var sectionBars: Int { sections.reduce(0) { $0 + $1.bars } }

    public func progression(forKey key: String?) -> Progression {
        guard let key, let p = sectionProgressions[key] else { return progression }
        return p
    }

    public func harmony(atBar bar: Int) -> BarHarmony {
        var b = bar
        for (i, s) in sections.enumerated() {
            if b < s.bars {
                let next = sections[safe: i + 1]
                return BarHarmony(progression: progression(forKey: s.chordsKey), progressionKey: s.chordsKey ?? "main",
                               localBar: b, sectionIndex: i, intensity: s.intensity,
                               isSectionStart: b == 0, isSectionEnd: b == s.bars - 1,
                               nextIntensity: next?.intensity ?? (i == sections.count - 1 ? sections[0].intensity : s.intensity))
            }
            b -= s.bars
        }
        // No sections (or past them): the main progression loops from the song start.
        return BarHarmony(progression: progression, progressionKey: "main", localBar: bar, sectionIndex: nil,
                       intensity: 1, isSectionStart: bar == 0, isSectionEnd: false, nextIntensity: 1)
    }

    /// The chord sounding at a song position.
    public func chord(atSongBeat beat: Double) -> Chord {
        let bpb = Double(beatsPerBar)
        let bar = Int((max(beat, 0) / bpb).rounded(.down))
        let h = harmony(atBar: bar)
        return h.progression.chord(atBeat: Double(h.localBar) * bpb + (max(beat, 0) - Double(bar) * bpb))
    }

    /// The progression playing at a song position, and the position inside it.
    public func progressionPosition(atSongBeat beat: Double) -> (progression: Progression, beat: Double, section: Int?) {
        let bpb = Double(beatsPerBar)
        let bar = Int((max(beat, 0) / bpb).rounded(.down))
        let h = harmony(atBar: bar)
        return (h.progression, Double(h.localBar) * bpb + (max(beat, 0) - Double(bar) * bpb), h.sectionIndex)
    }

    /// The bar a section starts on.
    public func startBar(ofSection index: Int) -> Int {
        sections.prefix(index).reduce(0) { $0 + $1.bars }
    }

    public mutating func addSection(_ kind: SectionKind, at index: Int? = nil) {
        var key: String?
        if kind.ownChords {
            key = kind.displayName
            if sectionProgressions[key!] == nil {
                sectionProgressions[key!] = Session.contrastingProgression(for: kind, style: style, key: self.key,
                                                                          seed: variationSeed, avoiding: progression)
            }
        }
        let count = sections.filter { $0.kind == kind }.count
        let name = count == 0 ? kind.displayName : "\(kind.displayName) \(count + 1)"
        let section = SongSection(name: name, kind: kind, bars: kind.defaultBars, intensity: kind.defaultIntensity, chordsKey: key)
        if let index, index <= sections.count { sections.insert(section, at: index) } else { sections.append(section) }
    }

    /// A classic song form, built from the current chords.
    public mutating func buildSong() {
        sections = []
        sectionProgressions = [:]
        for k: SectionKind in [.intro, .verse, .preChorus, .chorus, .verse, .preChorus, .chorus, .bridge, .chorus, .outro] {
            addSection(k)
        }
    }

    public mutating func removeSection(id: UUID) {
        sections.removeAll { $0.id == id }
        let used = Set(sections.compactMap(\.chordsKey))
        sectionProgressions = sectionProgressions.filter { used.contains($0.key) }
    }

    /// Gives a section its own copy of the chords so editing them doesn't touch other sections.
    public mutating func giveOwnChords(sectionID: UUID) {
        guard let i = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        let current = progression(forKey: sections[i].chordsKey)
        var key = sections[i].name
        while sectionProgressions[key] != nil && sections.contains(where: { $0.chordsKey == key && $0.id != sectionID }) { key += "'" }
        sectionProgressions[key] = current
        sections[i].chordsKey = key
    }

    /// Chorus/bridge chords that differ from the verse: a different template,
    /// or the verse's chords started from another point.
    public static func contrastingProgression(for kind: SectionKind, style: Style, key: Key, seed: Int, avoiding main: Progression) -> Progression {
        let offset = kind == .chorus ? 101 : (kind == .bridge ? 202 : 303)
        for attempt in 0..<6 {
            let p = ProgressionGenerator.generate(style: style, key: key, seed: seed &+ offset &+ attempt * 17)
            if p.slots.map(\.chord) != main.slots.map(\.chord) {
                if kind == .preChorus {
                    // Pre-choruses lean toward the dominant to set up the chorus.
                    var slots = p.slots
                    if let last = slots.indices.last {
                        slots[last].chord = Chord(root: key.tonic + 7, quality: style.harmony.colorLevel >= 2 ? .dominant7sus4 : .dominant7)
                    }
                    return Progression(slots: slots)
                }
                return p
            }
        }
        var slots = main.slots
        slots.append(slots.removeFirst())
        return Progression(slots: slots)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
