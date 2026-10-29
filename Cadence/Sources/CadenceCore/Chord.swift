import Foundation

public enum ChordQuality: String, CaseIterable, Codable, Sendable {
    case major, minor, diminished, augmented, sus2, sus4, power
    case major6, minor6, add9, minorAdd9
    case dominant7, major7, minor7, halfDiminished7, diminished7, minorMajor7, dominant7sus4
    case dominant9, major9, minor9, dominant11, minor11, dominant13, major13, minor13
    case major7sharp11, dominant7flat9, dominant7sharp9, dominant7flat13

    /// Intervals from the root, extensions above the octave.
    public var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .diminished: return [0, 3, 6]
        case .augmented: return [0, 4, 8]
        case .sus2: return [0, 2, 7]
        case .sus4: return [0, 5, 7]
        case .power: return [0, 7]
        case .major6: return [0, 4, 7, 9]
        case .minor6: return [0, 3, 7, 9]
        case .add9: return [0, 4, 7, 14]
        case .minorAdd9: return [0, 3, 7, 14]
        case .dominant7: return [0, 4, 7, 10]
        case .major7: return [0, 4, 7, 11]
        case .minor7: return [0, 3, 7, 10]
        case .halfDiminished7: return [0, 3, 6, 10]
        case .diminished7: return [0, 3, 6, 9]
        case .minorMajor7: return [0, 3, 7, 11]
        case .dominant7sus4: return [0, 5, 7, 10]
        case .dominant9: return [0, 4, 7, 10, 14]
        case .major9: return [0, 4, 7, 11, 14]
        case .minor9: return [0, 3, 7, 10, 14]
        case .dominant11: return [0, 7, 10, 14, 17]
        case .minor11: return [0, 3, 7, 10, 14, 17]
        case .dominant13: return [0, 4, 7, 10, 14, 21]
        case .major13: return [0, 4, 7, 11, 14, 21]
        case .minor13: return [0, 3, 7, 10, 14, 21]
        case .major7sharp11: return [0, 4, 7, 11, 18]
        case .dominant7flat9: return [0, 4, 7, 10, 13]
        case .dominant7sharp9: return [0, 4, 7, 10, 15]
        case .dominant7flat13: return [0, 4, 7, 10, 20]
        }
    }

    public var suffix: String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .diminished: return "°"
        case .augmented: return "+"
        case .sus2: return "sus2"
        case .sus4: return "sus4"
        case .power: return "5"
        case .major6: return "6"
        case .minor6: return "m6"
        case .add9: return "add9"
        case .minorAdd9: return "m(add9)"
        case .dominant7: return "7"
        case .major7: return "maj7"
        case .minor7: return "m7"
        case .halfDiminished7: return "m7♭5"
        case .diminished7: return "°7"
        case .minorMajor7: return "m(maj7)"
        case .dominant7sus4: return "7sus4"
        case .dominant9: return "9"
        case .major9: return "maj9"
        case .minor9: return "m9"
        case .dominant11: return "11"
        case .minor11: return "m11"
        case .dominant13: return "13"
        case .major13: return "maj13"
        case .minor13: return "m13"
        case .major7sharp11: return "maj7♯11"
        case .dominant7flat9: return "7♭9"
        case .dominant7sharp9: return "7♯9"
        case .dominant7flat13: return "7♭13"
        }
    }

    public var isMinor: Bool {
        switch self {
        case .minor, .minor6, .minorAdd9, .minor7, .minorMajor7, .minor9, .minor11, .minor13,
             .halfDiminished7, .diminished, .diminished7:
            return true
        default:
            return false
        }
    }

    public var isDominant: Bool {
        switch self {
        case .dominant7, .dominant9, .dominant11, .dominant13, .dominant7sus4,
             .dominant7flat9, .dominant7sharp9, .dominant7flat13:
            return true
        default:
            return false
        }
    }

    /// Basic triad family, used when matching a played/imported chord.
    public var triadFamily: ChordQuality {
        switch self {
        case .major, .major6, .add9, .major7, .major9, .major13, .major7sharp11,
             .dominant7, .dominant9, .dominant13, .dominant7flat9, .dominant7sharp9, .dominant7flat13:
            return .major
        case .minor, .minor6, .minorAdd9, .minor7, .minorMajor7, .minor9, .minor11, .minor13:
            return .minor
        case .diminished, .halfDiminished7, .diminished7: return .diminished
        case .sus4, .dominant7sus4, .dominant11: return .sus4
        default: return self
        }
    }

    /// Text aliases accepted when typing or importing chord symbols, longest first.
    static let aliases: [(String, ChordQuality)] = {
        var list: [(String, ChordQuality)] = [
            ("maj7#11", .major7sharp11), ("maj7♯11", .major7sharp11), ("Δ7#11", .major7sharp11),
            ("m(maj7)", .minorMajor7), ("mMaj7", .minorMajor7), ("mmaj7", .minorMajor7), ("m(add9)", .minorAdd9), ("madd9", .minorAdd9),
            ("7sus4", .dominant7sus4), ("7sus", .dominant7sus4),
            ("m7b5", .halfDiminished7), ("m7♭5", .halfDiminished7), ("ø7", .halfDiminished7), ("ø", .halfDiminished7),
            ("maj13", .major13), ("maj9", .major9), ("maj7", .major7), ("Maj7", .major7), ("M7", .major7), ("Δ7", .major7), ("Δ", .major7),
            ("min13", .minor13), ("min11", .minor11), ("min9", .minor9), ("min7", .minor7), ("min6", .minor6),
            ("m13", .minor13), ("m11", .minor11), ("m9", .minor9), ("m7", .minor7), ("m6", .minor6), ("-7", .minor7),
            ("dim7", .diminished7), ("°7", .diminished7), ("o7", .diminished7), ("dim", .diminished), ("°", .diminished),
            ("7b13", .dominant7flat13), ("7♭13", .dominant7flat13), ("7b9", .dominant7flat9), ("7♭9", .dominant7flat9),
            ("7#9", .dominant7sharp9), ("7♯9", .dominant7sharp9),
            ("add9", .add9), ("add2", .add9), ("sus2", .sus2), ("sus4", .sus4), ("sus", .sus4),
            ("aug", .augmented), ("+", .augmented),
            ("13", .dominant13), ("11", .dominant11), ("9", .dominant9), ("7", .dominant7), ("6", .major6), ("5", .power),
            ("min", .minor), ("m", .minor), ("-", .minor), ("maj", .major), ("M", .major),
        ]
        list.sort { $0.0.count > $1.0.count }
        return list
    }()
}

public struct Chord: Hashable, Codable, Sendable {
    public var root: Int
    public var quality: ChordQuality
    public var bass: Int?

    public init(root: Int, quality: ChordQuality, bass: Int? = nil) {
        self.root = mod12(root)
        self.quality = quality
        self.bass = bass.map(mod12)
    }

    public var pitchClasses: Set<Int> { Set(quality.intervals.map { mod12(root + $0) }) }

    /// Root, 3rd (or sus tone), 5th, 7th: the tones that define the chord.
    public var coreIntervals: [Int] { quality.intervals.filter { $0 < 12 } }
    public var extensionIntervals: [Int] { quality.intervals.filter { $0 >= 12 } }

    public var third: Int? { coreIntervals.first { [2, 3, 4, 5].contains($0) }.map { mod12(root + $0) } }
    public var seventh: Int? {
        if quality == .diminished7 { return mod12(root + 9) }
        return coreIntervals.first { $0 == 10 || $0 == 11 }.map { mod12(root + $0) }
    }
    public var fifth: Int? { coreIntervals.first { [6, 7, 8].contains($0) }.map { mod12(root + $0) } }
    public var bassNote: Int { bass ?? root }

    public func symbol(flats: Bool) -> String {
        var s = NoteName.name(root, flats: flats) + quality.suffix
        if let b = bass, b != root { s += "/" + NoteName.name(b, flats: flats) }
        return s
    }

    public func symbol(in key: Key) -> String { symbol(flats: key.prefersFlats) }

    /// Roman numeral relative to the key, e.g. "ii9", "♭VImaj7".
    public func roman(in key: Key) -> String {
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII"]
        let majorSteps = [0, 2, 4, 5, 7, 9, 11]
        let interval = mod12(root - key.tonic)
        var numeral: String
        if let i = majorSteps.firstIndex(of: interval) {
            numeral = numerals[i]
        } else if let i = majorSteps.firstIndex(of: interval + 1) {
            numeral = "♭" + numerals[i]
        } else {
            numeral = "♯" + numerals[majorSteps.firstIndex(of: interval - 1) ?? 0]
        }
        // In minor-family keys, the flat degrees are diatonic; name them plainly.
        if key.scale.isMinorish, numeral.hasPrefix("♭"), key.contains(root) {
            numeral = String(numeral.dropFirst())
        }
        var suffix = quality.suffix
        if quality.isMinor {
            numeral = numeral.lowercased()
            if suffix.hasPrefix("m") && !suffix.hasPrefix("maj") { suffix = String(suffix.dropFirst()) }
        }
        if quality == .halfDiminished7 { suffix = "ø7" }
        return numeral + suffix
    }

    /// Parses chord symbols like "Fm9", "B♭13", "C/E", "Ebmaj7#11".
    public static func parse(_ text: String) -> Chord? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard let (root, len) = NoteName.parse(Substring(t)) else { return nil }
        var rest = String(t.dropFirst(len))
        var bass: Int?
        if let slash = rest.lastIndex(of: "/") {
            let bassText = rest[rest.index(after: slash)...]
            if let (b, bl) = NoteName.parse(bassText), bl == bassText.count {
                bass = b
                rest = String(rest[..<slash])
            }
        }
        if rest.isEmpty { return Chord(root: root, quality: .major, bass: bass) }
        if rest == "m" || rest == "min" || rest == "-" { return Chord(root: root, quality: .minor, bass: bass) }
        for (alias, q) in ChordQuality.aliases where rest == alias {
            return Chord(root: root, quality: q, bass: bass)
        }
        // Unknown extensions: keep the longest known prefix so imports degrade gracefully.
        for (alias, q) in ChordQuality.aliases where rest.hasPrefix(alias) {
            return Chord(root: root, quality: q, bass: bass)
        }
        return nil
    }

    /// Richer version of this chord for genres that like color tones.
    public func colored(level: Int, rng: inout SeededRandom) -> Chord {
        guard level > 0 else {
            var c = self
            c.quality = quality.triadFamily == .sus4 ? .sus4 : (quality.triadFamily == .diminished ? .diminished : quality.triadFamily)
            return c
        }
        var c = self
        switch quality {
        case .major:
            c.quality = level >= 2 ? (rng.chance(0.5) ? .major9 : .add9) : (rng.chance(0.6) ? .major7 : .add9)
        case .minor:
            c.quality = level >= 3 ? .minor11 : (level >= 2 ? .minor9 : .minor7)
        case .major7:
            c.quality = level >= 3 ? (rng.chance(0.35) ? .major7sharp11 : .major9) : (level >= 2 ? .major9 : .major7)
        case .minor7:
            c.quality = level >= 3 ? (rng.chance(0.5) ? .minor11 : .minor9) : (level >= 2 ? .minor9 : .minor7)
        case .dominant7:
            if level >= 3 { c.quality = rng.pick([.dominant13, .dominant9, .dominant7sharp9, .dominant7flat13]) }
            else if level >= 2 { c.quality = rng.chance(0.5) ? .dominant13 : .dominant9 }
        case .diminished:
            c.quality = level >= 1 ? .halfDiminished7 : .diminished
        default:
            break
        }
        return c
    }
}

/// A chord held for a number of beats. A progression loops.
public struct ChordSlot: Hashable, Codable, Sendable, Identifiable {
    public var id = UUID()
    public var chord: Chord
    public var beats: Double

    public init(chord: Chord, beats: Double) {
        self.chord = chord
        self.beats = beats
    }
}

public struct Progression: Hashable, Codable, Sendable {
    public var slots: [ChordSlot]

    public init(slots: [ChordSlot]) { self.slots = slots }

    public init(chords: [Chord], beatsEach: Double) {
        slots = chords.map { ChordSlot(chord: $0, beats: beatsEach) }
    }

    public var totalBeats: Double { max(slots.reduce(0) { $0 + $1.beats }, 1) }

    /// Index of the slot sounding at an absolute beat (the progression loops).
    public func slotIndex(atBeat beat: Double) -> Int {
        guard !slots.isEmpty else { return 0 }
        var b = beat.truncatingRemainder(dividingBy: totalBeats)
        if b < 0 { b += totalBeats }
        var acc = 0.0
        for (i, s) in slots.enumerated() {
            acc += s.beats
            if b < acc - 1e-9 { return i }
        }
        return slots.count - 1
    }

    public func chord(atBeat beat: Double) -> Chord {
        guard !slots.isEmpty else { return Chord(root: 0, quality: .major) }
        return slots[slotIndex(atBeat: beat)].chord
    }

    /// Absolute beat where the chord sounding at `beat` ends.
    public func slotEnd(atBeat beat: Double) -> Double {
        let loopStart = (beat / totalBeats).rounded(.down) * totalBeats
        let idx = slotIndex(atBeat: beat)
        let end = slots[0...idx].reduce(0) { $0 + $1.beats }
        return loopStart + end
    }

    public func nextChord(afterBeat beat: Double) -> Chord {
        guard !slots.isEmpty else { return Chord(root: 0, quality: .major) }
        return slots[(slotIndex(atBeat: beat) + 1) % slots.count].chord
    }
}
