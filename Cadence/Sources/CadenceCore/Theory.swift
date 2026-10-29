import Foundation

@inline(__always) public func mod12(_ v: Int) -> Int { ((v % 12) + 12) % 12 }

public enum ScaleType: String, CaseIterable, Codable, Sendable, Identifiable {
    case major, naturalMinor, dorian, phrygian, lydian, mixolydian, locrian
    case harmonicMinor, melodicMinor
    case majorPentatonic, minorPentatonic, blues

    public var id: String { rawValue }

    public var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor: return [0, 2, 3, 5, 7, 8, 10]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        case .majorPentatonic: return [0, 2, 4, 7, 9]
        case .minorPentatonic: return [0, 3, 5, 7, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        }
    }

    public var displayName: String {
        switch self {
        case .major: return "Major"
        case .naturalMinor: return "Minor"
        case .dorian: return "Dorian"
        case .phrygian: return "Phrygian"
        case .lydian: return "Lydian"
        case .mixolydian: return "Mixolydian"
        case .locrian: return "Locrian"
        case .harmonicMinor: return "Harmonic Minor"
        case .melodicMinor: return "Melodic Minor"
        case .majorPentatonic: return "Major Pentatonic"
        case .minorPentatonic: return "Minor Pentatonic"
        case .blues: return "Blues"
        }
    }

    /// Seven-note scale used to build chords. Pentatonic and blues keys borrow
    /// the harmony of their parent mode.
    public var harmonicParent: ScaleType {
        switch self {
        case .majorPentatonic: return .major
        case .minorPentatonic: return .naturalMinor
        case .blues: return .mixolydian
        default: return self
        }
    }

    /// Semitones from this mode's tonic down to its relative major tonic.
    var offsetFromRelativeMajor: Int {
        switch self.harmonicParent {
        case .major: return 0
        case .dorian: return 2
        case .phrygian: return 4
        case .lydian: return 5
        case .mixolydian: return 7
        case .naturalMinor, .harmonicMinor, .melodicMinor: return 9
        case .locrian: return 11
        default: return 0
        }
    }

    public var isMinorish: Bool {
        intervals.contains(3) && !intervals.contains(4)
    }
}

public struct Key: Hashable, Codable, Sendable {
    public var tonic: Int
    public var scale: ScaleType

    public init(tonic: Int, scale: ScaleType) {
        self.tonic = mod12(tonic)
        self.scale = scale
    }

    public var pitchClasses: [Int] { scale.intervals.map { mod12(tonic + $0) } }
    public var harmonyPitchClasses: [Int] { scale.harmonicParent.intervals.map { mod12(tonic + $0) } }

    public func contains(_ pitch: Int) -> Bool { pitchClasses.contains(mod12(pitch)) }

    /// Spell with flats when the key signature has flats.
    public var prefersFlats: Bool {
        let relMajor = mod12(tonic - scale.offsetFromRelativeMajor)
        return [5, 10, 3, 8, 1, 6].contains(relMajor)
    }

    public func name(of pitch: Int) -> String {
        NoteName.name(pitch, flats: prefersFlats)
    }

    public var displayName: String { "\(name(of: tonic)) \(scale.displayName)" }

    /// Nearest in-scale MIDI note. Ties resolve upward on the way up the
    /// keyboard and downward on the way down (`direction`).
    public func nearestScaleNote(to pitch: Int, direction: Int = 1) -> Int {
        if contains(pitch) { return pitch }
        for d in 1...6 {
            let first = direction >= 0 ? pitch + d : pitch - d
            let second = direction >= 0 ? pitch - d : pitch + d
            if contains(first) { return first }
            if contains(second) { return second }
        }
        return pitch
    }

    /// Diatonic chord built by stacking thirds on a scale degree (0-based).
    public func diatonicChord(degree: Int, seventh: Bool) -> Chord {
        let pcs = harmonyPitchClasses
        let n = pcs.count
        let d = ((degree % n) + n) % n
        let root = pcs[d]
        func interval(_ step: Int) -> Int { mod12(pcs[(d + step) % n] - root) }
        let third = interval(2), fifth = interval(4), sev = interval(6)
        let quality: ChordQuality
        switch (third, fifth, seventh ? sev : -1) {
        case (4, 7, 11): quality = .major7
        case (4, 7, 10): quality = .dominant7
        case (3, 7, 10): quality = .minor7
        case (3, 7, 11): quality = .minorMajor7
        case (3, 6, 10): quality = .halfDiminished7
        case (3, 6, 9): quality = .diminished7
        case (4, 8, _): quality = .augmented
        case (4, 7, _): quality = .major
        case (3, 7, _): quality = .minor
        case (3, 6, _): quality = .diminished
        default: quality = .major
        }
        return Chord(root: root, quality: quality)
    }

    /// The scale degree of `pitch`, or nil when it is outside the scale.
    public func degree(of pitch: Int) -> Int? {
        harmonyPitchClasses.firstIndex(of: mod12(pitch))
    }

    public static let allTonics = Array(0..<12)
}

public enum NoteName {
    static let sharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    static let flats = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]

    public static func name(_ pitch: Int, flats useFlats: Bool) -> String {
        (useFlats ? flats : sharps)[mod12(pitch)]
    }

    public static func nameWithOctave(_ pitch: Int, flats: Bool) -> String {
        "\(name(pitch, flats: flats))\(pitch / 12 - 1)"
    }

    /// Parses "C", "F#", "Bb", "E♭" into a pitch class.
    public static func parse(_ s: Substring) -> (pc: Int, length: Int)? {
        guard let first = s.first else { return nil }
        let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let base = letters[Character(first.uppercased())] else { return nil }
        var pc = base
        var len = 1
        var rest = s.dropFirst()
        while let c = rest.first {
            if c == "#" || c == "♯" { pc += 1 } else if c == "b" || c == "♭" { pc -= 1 } else { break }
            len += 1
            rest = rest.dropFirst()
        }
        return (mod12(pc), len)
    }
}
