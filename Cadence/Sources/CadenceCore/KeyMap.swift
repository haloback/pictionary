import Foundation

/// How the physical keys you press map to what's played.
public enum KeyMap: String, CaseIterable, Codable, Sendable {
    /// Play anything; notes are snapped into the key.
    case anyKey
    /// White keys walk the current scale (C = tonic, D = 2nd, …) in any key or
    /// mode; black keys play the tones of the chord that's sounding.
    case whiteKeysScale
    /// One key, one chord. White keys C–B are the key's chords I–vii; black
    /// keys are the chords of the progression, in order.
    case chordKeys

    public var displayName: String {
        switch self {
        case .anyKey: return "Any key"
        case .whiteKeysScale: return "White = scale"
        case .chordKeys: return "One-key chords"
        }
    }

    public var explanation: String {
        switch self {
        case .anyKey: return "Play anywhere. Wrong notes slide into the key."
        case .whiteKeysScale: return "White keys play the scale from the tonic up, whatever the key. Black keys play the current chord's tones."
        case .chordKeys: return "Each white key plays a full chord in the key (C = I, D = ii, …). Black keys play the progression's chords. Low keys add the bass."
        }
    }
}

/// Pure key-mapping logic, shared by the live performer and the on-screen keyboard.
public struct KeyMapper: Sendable {
    public var key: Key
    public var progressionChords: [Chord]
    /// The style's harmonic richness (0 triads … 3 extended chords).
    public var colorLevel: Int

    static let whitePCs = [0, 2, 4, 5, 7, 9, 11]
    static let blackPCs = [1, 3, 6, 8, 10]

    public init(key: Key, progressionChords: [Chord], colorLevel: Int) {
        self.key = key
        self.progressionChords = progressionChords
        self.colorLevel = colorLevel
    }

    public static func isWhite(_ pitch: Int) -> Bool { whitePCs.contains(mod12(pitch)) }

    /// Number of white keys from MIDI 0 up to (not including) `pitch`'s octave position.
    static func whiteIndex(_ pitch: Int) -> Int {
        let octave = Int((Double(pitch) / 12).rounded(.down))
        let within = whitePCs.firstIndex(of: mod12(pitch)) ?? whitePCs.filter { $0 < mod12(pitch) }.count
        return octave * 7 + within
    }

    /// White key -> scale note. Middle C is the tonic near middle C, and every
    /// step up the white keys is one step up the scale.
    public func scalePitch(forKey pitch: Int) -> Int {
        let steps = Self.whiteIndex(pitch) - Self.whiteIndex(60)
        let intervals = key.scale.intervals
        let n = intervals.count
        let octave = Int((Double(steps) / Double(n)).rounded(.down))
        let degree = steps - octave * n
        let tonicBase = 60 + (key.tonic <= 6 ? key.tonic : key.tonic - 12)
        return tonicBase + 12 * octave + intervals[degree]
    }

    /// Black key -> a tone of `chord` in that key's octave: C♯ root, D♯ 3rd,
    /// F♯ 5th, G♯ 7th (or octave), A♯ the color tone.
    public func chordTone(forKey pitch: Int, chord: Chord) -> Int {
        let index = Self.blackPCs.firstIndex(of: mod12(pitch)) ?? 0
        let intervals = chord.quality.intervals.sorted()
        let interval = index < intervals.count ? intervals[index] : intervals[index % intervals.count] + 12
        let octaveC = pitch - mod12(pitch)
        return octaveC + mod12(chord.root) + interval
    }

    /// The chord a key plays in `.chordKeys` mode.
    public func chord(forKey pitch: Int) -> Chord? {
        let pc = mod12(pitch)
        if let degree = Self.whitePCs.firstIndex(of: pc) {
            var rng = SeededRandom(degree, colorLevel, key.tonic)
            return key.diatonicChord(degree: degree, seventh: colorLevel >= 1).colored(level: colorLevel, rng: &rng)
        }
        guard !progressionChords.isEmpty, let i = Self.blackPCs.firstIndex(of: pc) else { return nil }
        return progressionChords[i % progressionChords.count]
    }
}
