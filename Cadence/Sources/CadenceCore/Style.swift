import Foundation

public enum PartKind: Hashable, Codable, Sendable {
    case comp(CompStyle)
    case bass(BassStyle)
    case drums(DrumGroove)
    case line(LineStyle)

    public var roleName: String {
        switch self {
        case .comp: return "Chords"
        case .bass: return "Bass"
        case .drums: return "Drums"
        case .line(let l): return l == .pad || l == .drone ? "Pad" : "Melody"
        }
    }
}

public struct PartSpec: Hashable, Codable, Sendable {
    public var kind: PartKind
    public var instrument: InstrumentID
    public var voicing: VoicingStyle?
    /// 0...1. Low density drops ghost notes and some hits.
    public var density: Double
    public var volume: Double

    public init(_ kind: PartKind, _ instrument: InstrumentID, voicing: VoicingStyle? = nil, density: Double = 0.75, volume: Double? = nil) {
        self.kind = kind
        self.instrument = instrument
        self.voicing = voicing
        self.density = density
        switch kind {
        case .drums: self.volume = volume ?? 0.8
        case .bass: self.volume = volume ?? 0.85
        case .comp: self.volume = volume ?? 0.75
        case .line(let l): self.volume = volume ?? (l == .pad || l == .drone ? 0.5 : 0.65)
        }
    }
}

/// The human part: where notes land relative to the grid, and how hard.
public struct Feel: Hashable, Codable, Sendable {
    /// 0 = straight, 1 = full triplet swing.
    public var swing: Double
    /// Beat fraction that swings: 0.5 swings 8ths, 0.25 swings 16ths.
    public var swingUnit: Double
    /// Random timing spread (standard deviation), milliseconds.
    public var jitterMs: Double
    /// Whole band sits this far behind the beat, milliseconds.
    public var behindMs: Double
    /// Random velocity spread, 0...1.
    public var velocityVariance: Double
    /// Overall loudness, 0...1.
    public var dynamics: Double

    public static let straight = Feel(swing: 0, swingUnit: 0.5, jitterMs: 6, behindMs: 0, velocityVariance: 0.08, dynamics: 0.75)
    public static let tight = Feel(swing: 0, swingUnit: 0.25, jitterMs: 2.5, behindMs: 0, velocityVariance: 0.05, dynamics: 0.8)
    public static let pocket = Feel(swing: 0.45, swingUnit: 0.25, jitterMs: 9, behindMs: 16, velocityVariance: 0.13, dynamics: 0.7)
    public static let swing8 = Feel(swing: 0.62, swingUnit: 0.5, jitterMs: 9, behindMs: 6, velocityVariance: 0.12, dynamics: 0.7)
    public static let shuffle = Feel(swing: 1.0, swingUnit: 0.5, jitterMs: 8, behindMs: 4, velocityVariance: 0.1, dynamics: 0.75)
    public static let laidBack = Feel(swing: 0.25, swingUnit: 0.25, jitterMs: 10, behindMs: 12, velocityVariance: 0.12, dynamics: 0.68)
    public static let lilt = Feel(swing: 0.18, swingUnit: 0.25, jitterMs: 7, behindMs: 4, velocityVariance: 0.1, dynamics: 0.72)
    public static let rubato = Feel(swing: 0, swingUnit: 0.5, jitterMs: 16, behindMs: 0, velocityVariance: 0.15, dynamics: 0.62)
}

public struct HarmonyProfile: Hashable, Codable, Sendable {
    /// Four-chord shapes as scale degrees (0 = tonic).
    public var templates: [[Int]]
    /// 0 triads, 1 sevenths, 2 ninths, 3 rich extensions and alterations.
    public var colorLevel: Int
    /// Turn every chord into a dominant 7th (blues).
    public var allDominant: Bool = false
    public var beatsPerChord: Double? = nil
}

enum Harmony {
    static let pop = [[0, 4, 5, 3], [5, 3, 0, 4], [0, 5, 3, 4], [0, 3, 5, 4], [3, 0, 4, 5]]
    static let rock = [[0, 6, 3, 0], [0, 3, 4, 3], [0, 4, 3, 3], [5, 3, 0, 4]]
    static let jazz = [[1, 4, 0, 0], [0, 5, 1, 4], [2, 5, 1, 4], [1, 4, 0, 5]]
    static let soul = [[0, 3, 0, 3], [0, 3, 6, 4], [0, 2, 3, 6], [0, 6, 3, 4]]
    static let neoSoul = [[3, 2, 1, 0], [1, 4, 0, 5], [0, 3, 2, 5], [3, 4, 2, 5]]
    static let gospel = [[3, 4, 2, 5], [0, 3, 0, 4], [3, 2, 1, 4], [5, 1, 4, 0]]
    static let minorPop = [[0, 5, 2, 6], [0, 6, 5, 6], [0, 3, 5, 4], [5, 2, 6, 0]]
    static let cinematic = [[0, 5, 2, 6], [0, 5, 3, 0], [0, 3, 5, 4], [5, 3, 0, 4]]
    static let classical = [[0, 3, 4, 0], [0, 1, 4, 0], [0, 5, 3, 4], [0, 4, 5, 2]]
    static let blues = [[0, 3, 0, 4], [0, 0, 3, 4], [0, 3, 4, 3]]
    static let latin = [[0, 4, 4, 0], [1, 4, 0, 0], [0, 3, 4, 3]]
    static let afro = [[0, 3, 5, 4], [1, 4, 0, 3], [0, 4, 5, 3], [3, 4, 0, 0]]
    static let ambient = [[0, 3, 0, 3], [0, 5, 3, 0], [0, 4, 5, 3], [3, 0, 3, 0]]
    static let country = [[0, 3, 0, 4], [0, 4, 5, 3], [0, 0, 3, 4]]
    static let reggae = [[0, 3, 0, 3], [0, 4, 3, 4], [0, 5, 3, 4], [1, 0, 1, 0]]
    static let lofi = [[1, 4, 0, 5], [3, 2, 1, 0], [3, 4, 2, 5], [0, 5, 1, 4]]
    static let bossa = [[0, 1, 4, 0], [1, 4, 0, 0], [0, 5, 1, 4]]
    static let funk = [[0, 3, 0, 3], [0, 0, 3, 3], [0, 6, 0, 3]]
    static let modal = [[0, 0, 6, 6], [0, 3, 0, 3], [0, 1, 0, 1]]
}

public struct Style: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var family: String
    public var baseName: String
    public var variation: String
    public var ensemble: String
    public var summary: String
    public var tempoRange: ClosedRange<Double>
    public var defaultTempo: Double
    public var beatsPerBar: Int
    /// 4 for 16th-note grids, 3 for triplet (12/8) grids.
    public var stepsPerBeat: Int
    public var feel: Feel
    public var harmony: HarmonyProfile
    public var scale: ScaleType
    public var parts: [PartSpec]
    /// Your hands are this instrument by default.
    public var liveInstrument: InstrumentID
    public var liveVoicing: VoicingStyle
    /// Style-map coordinates, 0...1.
    public var energy: Double
    public var acousticness: Double

    public var meterLabel: String {
        if stepsPerBeat == 3 { return "12/8" }
        return "\(beatsPerBar)/4"
    }
}

/// Builds the style catalogue: hand-tuned base genres, each re-imagined in
/// several moods and band sizes.
public enum StyleLibrary {
    public static let all: [Style] = build()
    public static let byID: [String: Style] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    public static var families: [String] { var seen: [String] = []; for s in all where !seen.contains(s.family) { seen.append(s.family) }; return seen }
    public static var defaultStyle: Style { byID["neo-soul"] ?? all[0] }

    public static func style(id: String) -> Style { byID[id] ?? defaultStyle }

    public static func search(_ query: String, family: String? = nil) -> [Style] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        return all.filter { s in
            if let f = family, s.family != f { return false }
            guard !words.isEmpty else { return true }
            let hay = "\(s.name) \(s.family) \(s.summary) \(s.variation) \(s.ensemble)".lowercased()
            return words.allSatisfy { hay.contains($0) || synonyms[$0]?.contains(where: hay.contains) == true }
        }
    }

    static let synonyms: [String: [String]] = [
        "rainy": ["late night", "lo-fi", "ballad", "bossa"], "chill": ["lo-fi", "late night", "ambient", "lounge"],
        "happy": ["pop", "uptempo", "highlife", "motown", "calypso"], "sad": ["ballad", "minor", "slow"],
        "church": ["gospel", "hymn", "worship"], "movie": ["cinematic", "film"], "dance": ["house", "disco", "amapiano", "afrobeats"],
        "90s": ["r&b", "boom bap", "quiet storm"], "70s": ["soft rock", "disco", "funk", "soul"],
    ]

    struct Base {
        let id: String, name: String, family: String, tempo: ClosedRange<Double>, bpm: Double
        let beats: Int, steps: Int, feel: Feel, harmony: HarmonyProfile, scale: ScaleType
        let parts: [PartSpec], energy: Double, acoustic: Double, live: InstrumentID, liveVoicing: VoicingStyle
        let summary: String
    }

    static func b(_ id: String, _ name: String, _ family: String, _ tempo: ClosedRange<Double>, _ bpm: Double,
                  feel: Feel, harmony: [[Int]], color: Int, scale: ScaleType = .major, meter: (Int, Int) = (4, 4),
                  dominant: Bool = false, energy: Double, acoustic: Double, live: InstrumentID = .grandPiano,
                  voicing: VoicingStyle = .close, _ parts: [PartSpec], _ summary: String) -> Base {
        Base(id: id, name: name, family: family, tempo: tempo, bpm: bpm, beats: meter.0, steps: meter.1, feel: feel,
             harmony: HarmonyProfile(templates: harmony, colorLevel: color, allDominant: dominant), scale: scale,
             parts: parts, energy: energy, acoustic: acoustic, live: live, liveVoicing: voicing, summary: summary)
    }

    static func p(_ k: PartKind, _ i: InstrumentID, _ v: VoicingStyle? = nil, d: Double = 0.75, vol: Double? = nil) -> PartSpec {
        PartSpec(k, i, voicing: v, density: d, volume: vol)
    }

    static let bases: [Base] = [
        // Pop & Rock
        b("modern-pop", "Modern Pop", "Pop", 96...124, 110, feel: .straight, harmony: Harmony.pop, color: 1, energy: 0.65, acoustic: 0.35, voicing: .triad,
          [p(.comp(.pushedEighths), .grandPiano, .triad), p(.bass(.pop), .synthBass), p(.drums(.pop), .electronicKit), p(.line(.pad), .pad)],
          "Punchy piano pushes, tight drums and a warm synth bed."),
        b("piano-ballad", "Piano Ballad", "Pop", 60...78, 68, feel: .laidBack, harmony: Harmony.pop, color: 1, energy: 0.25, acoustic: 0.8, voicing: .spread,
          [p(.comp(.balladArp), .grandPiano, .spread), p(.bass(.wholeRoot), .fingerBass), p(.drums(.pop), .drumKit, d: 0.35), p(.line(.pad), .strings)],
          "Flowing arpeggios, soft kit and strings that swell into the chorus."),
        b("synth-pop", "Synth Pop", "Pop", 108...128, 118, feel: .tight, harmony: Harmony.minorPop, color: 1, scale: .naturalMinor, energy: 0.75, acoustic: 0.1, live: .synthPluck, voicing: .triad,
          [p(.comp(.eighthPulse), .synthPluck, .triad), p(.bass(.octaves), .synthBass), p(.drums(.disco), .electronicKit), p(.line(.pad), .pad)],
          "Driving 8th-note synths, octave bass and gated drums."),
        b("k-pop", "K-Pop Bright", "Pop", 110...130, 122, feel: .tight, harmony: Harmony.pop, color: 2, energy: 0.85, acoustic: 0.1, live: .synthPluck,
          [p(.comp(.houseStabs), .synthPluck, .close), p(.bass(.octaves), .synthBass), p(.drums(.fourOnFloor), .electronicKit), p(.line(.counterMelody), .synthLead, d: 0.5)],
          "Glossy stabs over four-on-the-floor, with a bright synth hook."),
        b("indie-folk", "Indie Folk", "Folk & Country", 84...110, 96, feel: .straight, harmony: Harmony.pop, color: 1, energy: 0.45, acoustic: 0.9, live: .steelGuitar, voicing: .guitar,
          [p(.comp(.strum8), .steelGuitar, .guitar), p(.bass(.rootFifth), .acousticBass), p(.drums(.pop), .drumKit, d: 0.4), p(.line(.counterMelody), .violin, d: 0.5)],
          "Strummed acoustic, upright bass, light kit and a fiddle answering you."),
        b("singer-songwriter", "Singer-Songwriter", "Folk & Country", 76...100, 88, feel: .laidBack, harmony: Harmony.pop, color: 1, energy: 0.3, acoustic: 0.95, live: .nylonGuitar, voicing: .guitar,
          [p(.comp(.travisPick), .nylonGuitar, .guitar), p(.bass(.wholeRoot), .acousticBass, d: 0.5)],
          "Fingerpicked guitar with a gentle bass. Just you and a stool."),
        b("pop-punk", "Pop Punk", "Rock", 150...180, 165, feel: .tight, harmony: Harmony.rock, color: 0, scale: .mixolydian, energy: 0.95, acoustic: 0.3, live: .overdriveGuitar, voicing: .triad,
          [p(.comp(.eighthPulse), .overdriveGuitar, .triad), p(.bass(.rockEighths), .fingerBass), p(.drums(.rock), .drumKit)],
          "Fast power chords, driving 8th bass and a loud kit."),
        b("arena-rock", "Arena Rock", "Rock", 100...130, 116, feel: .straight, harmony: Harmony.rock, color: 0, scale: .mixolydian, energy: 0.85, acoustic: 0.4, live: .overdriveGuitar, voicing: .triad,
          [p(.comp(.strum8), .overdriveGuitar, .triad), p(.bass(.rockEighths), .fingerBass), p(.drums(.rock), .drumKit), p(.line(.pad), .organ)],
          "Big guitars, steady bass and an organ underneath."),
        b("classic-rock", "Classic Rock", "Rock", 110...140, 124, feel: .straight, harmony: Harmony.rock, color: 0, scale: .mixolydian, energy: 0.8, acoustic: 0.45, voicing: .triad,
          [p(.comp(.quarterPulse), .grandPiano, .triad), p(.bass(.rockEighths), .fingerBass), p(.drums(.rock), .drumKit), p(.comp(.strum8), .cleanGuitar, .guitar, d: 0.6)],
          "Barrelhouse piano and guitar over a straight-ahead rock beat."),
        b("soft-rock", "Soft Rock 70s", "Rock", 80...104, 92, feel: .laidBack, harmony: Harmony.pop, color: 2, energy: 0.45, acoustic: 0.55, live: .wurlitzer,
          [p(.comp(.quarterPulse), .wurlitzer, .close), p(.bass(.pop), .fingerBass), p(.drums(.pop), .drumKit, d: 0.6), p(.line(.pad), .strings)],
          "Wurlitzer, round bass and a relaxed kit, with strings."),
        // Soul & R&B
        b("motown", "Motown", "Soul & R&B", 112...132, 122, feel: .straight, harmony: Harmony.pop, color: 1, energy: 0.75, acoustic: 0.6,
          [p(.comp(.quarterPulse), .grandPiano, .close), p(.bass(.motown), .fingerBass), p(.drums(.motown), .drumKit), p(.comp(.hornStabs), .horns, .close)],
          "Four-on-the-floor piano, busy bass, tambourine and horn hits."),
        b("classic-soul", "Classic Soul", "Soul & R&B", 70...96, 84, feel: .laidBack, harmony: Harmony.gospel, color: 1, energy: 0.5, acoustic: 0.6, live: .organ,
          [p(.comp(.halfNotes), .organ, .close), p(.bass(.pop), .fingerBass), p(.drums(.gospel), .drumKit), p(.comp(.hornStabs), .horns, .close, d: 0.5)],
          "Warm organ, a deep pocket and horns on the turnaround."),
        b("neo-soul", "Neo-Soul", "Soul & R&B", 68...92, 80, feel: .pocket, harmony: Harmony.neoSoul, color: 3, energy: 0.4, acoustic: 0.45, live: .rhodes, voicing: .rootless,
          [p(.comp(.neoSoulComp), .rhodes, .rootless), p(.bass(.pop), .fingerBass), p(.drums(.neoSoul), .drumKit), p(.line(.pad), .strings, d: 0.4)],
          "Rhodes with 9ths and 11ths, ghosted comping and a drummer behind the beat."),
        b("modern-rnb", "Modern R&B", "Soul & R&B", 64...90, 76, feel: .pocket, harmony: Harmony.neoSoul, color: 2, energy: 0.45, acoustic: 0.15, live: .rhodes, voicing: .rootless,
          [p(.comp(.lofiLazy), .rhodes, .rootless), p(.bass(.slide808), .bass808), p(.drums(.trap), .kit808), p(.line(.pad), .warmPad)],
          "Lush keys, sliding 808 and skittering hats."),
        b("quiet-storm", "Quiet Storm", "Soul & R&B", 60...76, 68, feel: .laidBack, harmony: Harmony.neoSoul, color: 3, energy: 0.2, acoustic: 0.5, live: .rhodes, voicing: .rootless,
          [p(.comp(.sustained), .rhodes, .rootless), p(.bass(.wholeRoot), .fingerBass), p(.drums(.brushes), .brushKit), p(.line(.pad), .strings)],
          "Late-night Rhodes, brushes and a velvet string bed."),
        b("funk", "Funk", "Soul & R&B", 96...116, 106, feel: .pocket, harmony: Harmony.funk, color: 2, scale: .dorian, energy: 0.85, acoustic: 0.45, live: .clavinet,
          [p(.comp(.funkChops), .clavinet, .close), p(.bass(.funk), .slapBass), p(.drums(.funk), .drumKit), p(.comp(.hornStabs), .horns, .close)],
          "Choppy clav, slap bass, 16th hats and horn punches."),
        b("disco", "Disco", "Soul & R&B", 116...128, 120, feel: .straight, harmony: Harmony.minorPop, color: 2, scale: .naturalMinor, energy: 0.85, acoustic: 0.35,
          [p(.comp(.eighthPulse), .grandPiano, .close), p(.bass(.octaves), .fingerBass), p(.drums(.disco), .drumKit), p(.line(.pad), .strings)],
          "Octave bass, open hats on the off-beat and soaring strings."),
        // Gospel
        b("sunday-gospel", "Sunday Gospel", "Gospel", 68...100, 84, feel: .laidBack, harmony: Harmony.gospel, color: 3, energy: 0.6, acoustic: 0.65,
          [p(.comp(.gospelStabs), .grandPiano, .close), p(.line(.pad), .organ), p(.bass(.gospel), .fingerBass), p(.drums(.gospel), .drumKit)],
          "Church piano with walk-ups, Hammond swells and a deep pocket."),
        b("gospel-shout", "Gospel Shout", "Gospel", 120...150, 136, feel: .shuffle, harmony: Harmony.gospel, color: 2, energy: 0.95, acoustic: 0.6, live: .organ,
          [p(.comp(.eighthPulse), .organ, .close), p(.bass(.gospel), .fingerBass), p(.drums(.gospel), .drumKit), p(.comp(.gospelStabs), .grandPiano, .close)],
          "Shuffling praise break: organ, piano and a drummer who won't stop."),
        b("worship", "Worship Ballad", "Gospel", 64...80, 72, feel: .laidBack, harmony: Harmony.pop, color: 1, energy: 0.35, acoustic: 0.6, voicing: .spread,
          [p(.comp(.balladArp), .grandPiano, .spread), p(.line(.pad), .warmPad), p(.bass(.wholeRoot), .fingerBass), p(.drums(.pop), .drumKit, d: 0.35)],
          "Spacious piano, ambient pad and a slow-building kit."),
        b("hymn", "Spiritual Hymn", "Gospel", 60...80, 70, feel: .rubato, harmony: Harmony.classical, color: 0, energy: 0.2, acoustic: 0.85, live: .organ,
          [p(.comp(.halfNotes), .organ, .close), p(.line(.pad), .choir)],
          "Four-part organ hymn with a choir."),
        // Jazz
        b("swing-trio", "Swing Trio", "Jazz", 120...200, 150, feel: .swing8, harmony: Harmony.jazz, color: 2, energy: 0.6, acoustic: 0.9, voicing: .rootless,
          [p(.comp(.charleston), .grandPiano, .rootless), p(.bass(.walking), .acousticBass), p(.drums(.jazzSwing), .jazzKit)],
          "Charleston comping, walking upright and a ride cymbal that swings."),
        b("jazz-ballad", "Jazz Ballad", "Jazz", 56...76, 64, feel: .swing8, harmony: Harmony.jazz, color: 3, energy: 0.2, acoustic: 0.95, voicing: .rootless,
          [p(.comp(.sustained), .grandPiano, .rootless), p(.bass(.rootFifth), .acousticBass), p(.drums(.brushes), .brushKit)],
          "Lush rootless voicings, brushes and a patient bass."),
        b("bebop", "Bebop", "Jazz", 200...280, 220, feel: .swing8, harmony: Harmony.jazz, color: 3, energy: 0.9, acoustic: 0.9, voicing: .shell,
          [p(.comp(.charleston), .grandPiano, .shell), p(.bass(.walking), .acousticBass), p(.drums(.jazzSwing), .jazzKit)],
          "Burning tempo, shell voicings and a walking bass that never sits still."),
        b("modal-jazz", "Modal Jazz", "Jazz", 120...160, 136, feel: .swing8, harmony: Harmony.modal, color: 2, scale: .dorian, energy: 0.6, acoustic: 0.9, voicing: .quartal,
          [p(.comp(.charleston), .grandPiano, .quartal), p(.bass(.walking), .acousticBass), p(.drums(.jazzSwing), .jazzKit)],
          "Stacked fourths over a Dorian vamp."),
        b("cool-jazz", "Cool Jazz", "Jazz", 100...140, 120, feel: .swing8, harmony: Harmony.jazz, color: 2, energy: 0.45, acoustic: 0.85, live: .vibraphone, voicing: .rootless,
          [p(.comp(.charleston), .vibraphone, .rootless), p(.bass(.walking), .acousticBass), p(.drums(.brushes), .brushKit)],
          "Vibes, brushes and walking bass. Relaxed and airy."),
        b("jazz-waltz", "Jazz Waltz", "Jazz", 120...170, 144, feel: .swing8, harmony: Harmony.jazz, color: 2, meter: (3, 4), energy: 0.5, acoustic: 0.9, voicing: .rootless,
          [p(.comp(.waltzComp), .grandPiano, .rootless), p(.bass(.waltz), .acousticBass), p(.drums(.waltz), .jazzKit)],
          "A lilting three: bass on one, piano on two and three."),
        b("lounge", "Lounge", "Jazz", 90...112, 100, feel: .lilt, harmony: Harmony.bossa, color: 2, energy: 0.35, acoustic: 0.7, live: .vibraphone, voicing: .rootless,
          [p(.comp(.bossaComp), .vibraphone, .rootless), p(.bass(.bossa), .acousticBass), p(.drums(.bossa), .brushKit)],
          "Cocktail-hour vibes over a soft bossa groove."),
        b("smooth-jazz", "Smooth Jazz", "Jazz", 84...104, 94, feel: .pocket, harmony: Harmony.neoSoul, color: 3, energy: 0.45, acoustic: 0.4, live: .rhodes, voicing: .rootless,
          [p(.comp(.neoSoulComp), .rhodes, .rootless), p(.bass(.pop), .fingerBass), p(.drums(.neoSoul), .drumKit), p(.line(.counterMelody), .saxophone, d: 0.5)],
          "Silky Rhodes, fretless-style bass and a sax answering your phrases."),
        b("fusion", "Jazz Fusion", "Jazz", 100...130, 116, feel: .pocket, harmony: Harmony.funk, color: 3, scale: .dorian, energy: 0.8, acoustic: 0.3, live: .rhodes, voicing: .quartal,
          [p(.comp(.funkChops), .rhodes, .quartal), p(.bass(.funk), .slapBass), p(.drums(.funk), .drumKit), p(.line(.counterMelody), .synthLead, d: 0.5)],
          "Quartal Rhodes chops, slap bass and a gliding lead."),
        // Blues & Country
        b("chicago-blues", "Chicago Blues", "Blues", 70...100, 84, feel: .shuffle, harmony: Harmony.blues, color: 1, scale: .blues, meter: (4, 3), dominant: true, energy: 0.6, acoustic: 0.6, voicing: .shell,
          [p(.comp(.twelveEightArp), .grandPiano, .shell), p(.bass(.twelveEight), .fingerBass), p(.drums(.shuffle), .drumKit), p(.line(.pad), .organ, d: 0.5)],
          "12/8 shuffle, triplet piano and an organ hum."),
        b("slow-blues", "Slow Blues", "Blues", 54...70, 60, feel: .shuffle, harmony: Harmony.blues, color: 2, scale: .blues, meter: (4, 3), dominant: true, energy: 0.35, acoustic: 0.6, live: .cleanGuitar, voicing: .shell,
          [p(.comp(.twelveEightArp), .grandPiano, .shell), p(.bass(.twelveEight), .fingerBass), p(.drums(.sixEight), .drumKit), p(.line(.pad), .organ)],
          "Slow and heavy 12/8. Let every note cry."),
        b("boogie-woogie", "Boogie Woogie", "Blues", 140...180, 160, feel: .shuffle, harmony: Harmony.blues, color: 1, scale: .blues, dominant: true, energy: 0.85, acoustic: 0.85, voicing: .shell,
          [p(.comp(.stride), .grandPiano, .shell), p(.bass(.rockEighths), .acousticBass), p(.drums(.rock), .drumKit, d: 0.6)],
          "Rolling left hand, stride chords and a shuffled backbeat."),
        b("country", "Country", "Folk & Country", 96...130, 112, feel: .straight, harmony: Harmony.country, color: 0, energy: 0.6, acoustic: 0.8, live: .steelGuitar, voicing: .guitar,
          [p(.comp(.strum8), .steelGuitar, .guitar), p(.bass(.rootFifth), .fingerBass), p(.drums(.country), .drumKit), p(.line(.counterMelody), .violin, d: 0.5)],
          "Boom-chick bass, train-beat snare and a fiddle."),
        b("bluegrass", "Bluegrass", "Folk & Country", 110...160, 130, feel: .straight, harmony: Harmony.country, color: 0, energy: 0.75, acoustic: 1, live: .steelGuitar, voicing: .guitar,
          [p(.comp(.strum16), .steelGuitar, .guitar), p(.bass(.rootFifth), .acousticBass), p(.line(.counterMelody), .violin, d: 0.7)],
          "Fast flatpicked guitar, upright bass and fiddle runs. No drums."),
        b("americana", "Americana", "Folk & Country", 80...100, 90, feel: .laidBack, harmony: Harmony.country, color: 1, energy: 0.45, acoustic: 0.8, live: .steelGuitar, voicing: .guitar,
          [p(.comp(.strum8), .steelGuitar, .guitar), p(.line(.pad), .organ, d: 0.5), p(.bass(.rootFifth), .fingerBass), p(.drums(.brushes), .brushKit)],
          "Dusty acoustic, organ and brushes."),
        // Latin
        b("bossa-nova", "Bossa Nova", "Latin", 120...144, 130, feel: .lilt, harmony: Harmony.bossa, color: 2, energy: 0.4, acoustic: 0.9, live: .nylonGuitar, voicing: .guitar,
          [p(.comp(.bossaComp), .nylonGuitar, .guitar), p(.bass(.bossa), .acousticBass), p(.drums(.bossa), .brushKit)],
          "Nylon guitar comping, cross-stick clave and a gentle bass."),
        b("samba", "Samba", "Latin", 96...112, 102, feel: .lilt, harmony: Harmony.bossa, color: 2, energy: 0.8, acoustic: 0.85, live: .nylonGuitar, voicing: .guitar,
          [p(.comp(.eighthPulse), .nylonGuitar, .guitar), p(.bass(.bossa), .acousticBass), p(.drums(.samba), .percussion)],
          "Busy surdo, shakers and nylon strums."),
        b("salsa", "Salsa", "Latin", 88...104, 96, feel: .straight, harmony: Harmony.latin, color: 1, energy: 0.85, acoustic: 0.75,
          [p(.comp(.montuno), .grandPiano, .close), p(.bass(.tumbao), .acousticBass), p(.drums(.salsa), .percussion), p(.comp(.hornStabs), .horns, .close)],
          "Piano montuno, anticipated tumbao bass, clave and horns."),
        b("latin-pop", "Latin Pop", "Latin", 92...106, 98, feel: .tight, harmony: Harmony.minorPop, color: 1, scale: .naturalMinor, energy: 0.8, acoustic: 0.3, live: .nylonGuitar, voicing: .guitar,
          [p(.comp(.strum16), .nylonGuitar, .guitar), p(.bass(.reggaeton), .synthBass), p(.drums(.reggaeton), .electronicKit), p(.line(.pad), .pad)],
          "Nylon guitar over a dembow beat."),
        b("reggaeton", "Reggaeton", "Latin", 88...100, 94, feel: .tight, harmony: Harmony.minorPop, color: 1, scale: .naturalMinor, energy: 0.85, acoustic: 0.1, live: .synthPluck,
          [p(.comp(.reggaetonStabs), .synthPluck, .triad), p(.bass(.reggaeton), .bass808), p(.drums(.reggaeton), .electronicKit), p(.line(.pad), .pad)],
          "The dembow: kick on every beat, snare dancing around it."),
        b("tango", "Tango", "Latin", 112...128, 120, feel: .rubato, harmony: Harmony.classical, color: 1, scale: .harmonicMinor, energy: 0.6, acoustic: 0.9,
          [p(.comp(.quarterPulse), .grandPiano, .close), p(.bass(.rootFifth), .acousticBass), p(.line(.topVoice), .violin)],
          "Marcato piano, dramatic violin and harmonic minor tension."),
        // Caribbean & African
        b("roots-reggae", "Roots Reggae", "Caribbean", 66...80, 74, feel: .pocket, harmony: Harmony.reggae, color: 0, energy: 0.45, acoustic: 0.5, live: .organ,
          [p(.comp(.offbeatSkank), .mutedGuitar, .guitar), p(.bass(.oneDrop), .fingerBass), p(.drums(.oneDrop), .drumKit), p(.comp(.offbeatSkank), .organ, .close, d: 0.6)],
          "One-drop drums, skanking guitar and organ bubble, deep bass."),
        b("dancehall", "Dancehall", "Caribbean", 90...104, 98, feel: .tight, harmony: Harmony.minorPop, color: 1, scale: .naturalMinor, energy: 0.8, acoustic: 0.1, live: .synthPluck,
          [p(.comp(.offbeatSkank), .synthPluck, .triad), p(.bass(.reggaeton), .synthBass), p(.drums(.reggaeton), .electronicKit)],
          "Digital riddim, off-beat synth stabs."),
        b("calypso", "Steel Drum Calypso", "Caribbean", 100...120, 110, feel: .lilt, harmony: Harmony.reggae, color: 0, energy: 0.7, acoustic: 0.6, live: .steelDrums, voicing: .triad,
          [p(.comp(.offbeatSkank), .steelDrums, .triad), p(.bass(.afro), .fingerBass), p(.drums(.samba), .percussion)],
          "Sunny steel pans, bouncing bass and hand percussion."),
        b("afrobeats", "Afrobeats", "African", 98...112, 104, feel: .lilt, harmony: Harmony.afro, color: 1, energy: 0.7, acoustic: 0.4, live: .cleanGuitar,
          [p(.comp(.highlifePick), .cleanGuitar, .guitar), p(.bass(.afro), .fingerBass), p(.drums(.afrobeats), .electronicKit), p(.line(.pad), .warmPad)],
          "Rolling percussion, plucked guitar and a bouncing bass."),
        b("amapiano", "Amapiano", "African", 108...116, 112, feel: .lilt, harmony: Harmony.afro, color: 2, scale: .dorian, energy: 0.65, acoustic: 0.25, live: .rhodes, voicing: .rootless,
          [p(.comp(.amapianoChords), .rhodes, .rootless), p(.bass(.logDrum), .bass808), p(.drums(.amapiano), .electronicKit), p(.line(.pad), .warmPad)],
          "Jazzy keys, shakers and the signature log-drum bass."),
        b("highlife", "Highlife Guitar Band", "African", 104...124, 112, feel: .lilt, harmony: Harmony.afro, color: 0, energy: 0.75, acoustic: 0.6, live: .cleanGuitar, voicing: .guitar,
          [p(.comp(.highlifePick), .cleanGuitar, .guitar), p(.bass(.afro), .fingerBass), p(.drums(.highlife), .percussion), p(.comp(.hornStabs), .horns, .close, d: 0.5)],
          "Bright interlocking guitars, bell pattern and horns."),
        b("afro-cuban-68", "Afro-Cuban 6/8", "African", 100...120, 108, feel: .straight, harmony: Harmony.minorPop, color: 1, scale: .naturalMinor, meter: (4, 3), energy: 0.6, acoustic: 0.8, live: .marimba, voicing: .triad,
          [p(.comp(.twelveEightArp), .marimba, .triad), p(.bass(.twelveEight), .acousticBass), p(.drums(.sixEight), .percussion)],
          "Marimba triplets over a 6/8 bell and conga groove."),
        // Electronic & Hip-Hop
        b("deep-house", "Deep House", "Electronic", 118...126, 122, feel: .tight, harmony: Harmony.minorPop, color: 2, scale: .dorian, energy: 0.75, acoustic: 0.1, live: .rhodes, voicing: .rootless,
          [p(.comp(.houseStabs), .rhodes, .rootless), p(.bass(.octaves), .synthBass), p(.drums(.fourOnFloor), .electronicKit), p(.line(.pad), .pad)],
          "Four-on-the-floor, off-beat Rhodes stabs and a deep bass."),
        b("lofi", "Lo-fi Hip-Hop", "Hip-Hop", 70...90, 80, feel: .pocket, harmony: Harmony.lofi, color: 3, energy: 0.3, acoustic: 0.35, live: .rhodes, voicing: .rootless,
          [p(.comp(.lofiLazy), .rhodes, .rootless), p(.bass(.pop), .fingerBass, d: 0.5), p(.drums(.lofi), .drumKit), p(.line(.pad), .warmPad, d: 0.4)],
          "Dusty Rhodes 9ths, lazy drums and a soft bass. Study mode."),
        b("boom-bap", "Boom Bap", "Hip-Hop", 84...96, 90, feel: .pocket, harmony: Harmony.soul, color: 2, scale: .dorian, energy: 0.55, acoustic: 0.3,
          [p(.comp(.lofiLazy), .grandPiano, .close), p(.bass(.afro), .fingerBass), p(.drums(.boomBap), .drumKit)],
          "Hard kick and snare, sampled-sounding piano and a fat bass."),
        b("trap-soul", "Trap Soul", "Hip-Hop", 130...150, 140, feel: .tight, harmony: Harmony.minorPop, color: 2, scale: .naturalMinor, energy: 0.7, acoustic: 0.05, live: .rhodes, voicing: .rootless,
          [p(.comp(.sustained), .rhodes, .rootless), p(.bass(.slide808), .bass808), p(.drums(.trap), .kit808), p(.line(.pad), .pad)],
          "Half-time trap drums, sliding 808 and moody keys."),
        b("dnb", "Drum & Bass", "Electronic", 168...176, 172, feel: .tight, harmony: Harmony.minorPop, color: 2, scale: .naturalMinor, energy: 0.95, acoustic: 0.05, live: .pad, voicing: .spread,
          [p(.comp(.sustained), .pad, .spread), p(.bass(.dnbSub), .synthBass), p(.drums(.dnb), .electronicKit)],
          "Rolling breaks at 172 with sub bass and wide pads."),
        b("synthwave", "Synthwave", "Electronic", 84...110, 100, feel: .tight, harmony: Harmony.minorPop, color: 1, scale: .naturalMinor, energy: 0.65, acoustic: 0.05, live: .synthPluck, voicing: .triad,
          [p(.comp(.eighthPulse), .synthPluck, .triad), p(.bass(.octaves), .synthBass), p(.drums(.pop), .electronicKit), p(.line(.pad), .pad)],
          "Retro arps, octave bass and gated snare."),
        b("ambient", "Ambient", "Ambient & Cinematic", 60...80, 70, feel: .rubato, harmony: Harmony.ambient, color: 2, scale: .lydian, energy: 0.1, acoustic: 0.3, live: .feltPiano, voicing: .quartal,
          [p(.comp(.sustained), .warmPad, .quartal), p(.line(.drone), .pad)],
          "Slow-blooming pads and drones. Every note you play hangs in the air."),
        // Cinematic & Classical
        b("cinematic-epic", "Cinematic Epic", "Ambient & Cinematic", 80...110, 96, feel: .straight, harmony: Harmony.cinematic, color: 1, scale: .naturalMinor, energy: 0.9, acoustic: 0.7, live: .strings, voicing: .spread,
          [p(.comp(.arpRolling), .strings, .close), p(.bass(.rootFifth), .cello), p(.drums(.cinematic), .percussion), p(.line(.pad), .brass)],
          "String ostinato, taiko-style toms and big brass."),
        b("film-tender", "Tender Film Score", "Ambient & Cinematic", 60...80, 70, feel: .rubato, harmony: Harmony.classical, color: 1, energy: 0.2, acoustic: 0.85, live: .feltPiano, voicing: .spread,
          [p(.comp(.balladArp), .feltPiano, .spread), p(.line(.pad), .strings), p(.line(.topVoice), .cello, d: 0.5)],
          "Felt piano, a cello line and strings that breathe with you."),
        b("classical-piano", "Classical Piano", "Classical", 66...100, 84, feel: .rubato, harmony: Harmony.classical, color: 0, energy: 0.35, acoustic: 1,
          [p(.comp(.alberti), .grandPiano, .close)],
          "Alberti bass under your right hand. Mozart-style."),
        b("baroque", "Baroque Strings", "Classical", 90...120, 104, feel: .straight, harmony: Harmony.classical, color: 0, energy: 0.55, acoustic: 1, live: .violin,
          [p(.comp(.eighthPulse), .strings, .close), p(.bass(.rockEighths), .cello), p(.comp(.arpUp), .harp, .spread, d: 0.5)],
          "Driving continuo strings and harp."),
        b("romantic-waltz", "Romantic Waltz", "Classical", 132...168, 150, feel: .rubato, harmony: Harmony.classical, color: 1, meter: (3, 4), energy: 0.45, acoustic: 1,
          [p(.comp(.waltzComp), .grandPiano, .close), p(.line(.pad), .strings)],
          "Oom-pah-pah in three with sweeping strings."),
        b("lullaby", "Music Box Lullaby", "Classical", 60...76, 68, feel: .rubato, harmony: Harmony.classical, color: 0, energy: 0.1, acoustic: 0.7, live: .kalimba, voicing: .triad,
          [p(.comp(.arpUp), .kalimba, .triad), p(.line(.pad), .strings, d: 0.4)],
          "Twinkling music box arpeggios."),
        b("orchestral-march", "Orchestral March", "Classical", 108...124, 116, feel: .straight, harmony: Harmony.classical, color: 0, energy: 0.8, acoustic: 0.85, live: .brass,
          [p(.comp(.quarterPulse), .strings, .close), p(.comp(.hornStabs), .brass, .close), p(.bass(.rootFifth), .cello), p(.drums(.march), .percussion)],
          "Snare rolls, brass fanfares and marching strings."),
        b("celtic", "Celtic Jig", "Folk & Country", 100...120, 110, feel: .straight, harmony: Harmony.country, color: 0, scale: .mixolydian, meter: (4, 3), energy: 0.65, acoustic: 1, live: .flute,
          [p(.comp(.twelveEightArp), .harp, .triad), p(.bass(.twelveEight), .acousticBass), p(.drums(.sixEight), .percussion), p(.line(.counterMelody), .flute, d: 0.6)],
          "Harp, bodhrán-style drum and a tin-whistle line in 6/8."),
    ]

    struct Variation {
        let name: String, tempo: Double, energy: Double, density: Double, feelBoost: Double, color: Int
        let acousticSwap: Bool, addsPad: Bool, lofi: Bool, summary: String
    }

    static let variations: [Variation] = [
        Variation(name: "Classic", tempo: 1, energy: 0, density: 0, feelBoost: 1, color: 0, acousticSwap: false, addsPad: false, lofi: false, summary: ""),
        Variation(name: "Late Night", tempo: 0.88, energy: -0.2, density: -0.2, feelBoost: 1.2, color: 1, acousticSwap: false, addsPad: false, lofi: false, summary: "Slower, darker, richer chords."),
        Variation(name: "Uptempo", tempo: 1.15, energy: 0.2, density: 0.1, feelBoost: 0.9, color: 0, acousticSwap: false, addsPad: false, lofi: false, summary: "Faster and brighter."),
        Variation(name: "Sparse", tempo: 0.95, energy: -0.25, density: -0.35, feelBoost: 1, color: 0, acousticSwap: false, addsPad: false, lofi: false, summary: "Lots of space. The band plays less so you can play more."),
        Variation(name: "Live Band", tempo: 1, energy: 0.05, density: 0.05, feelBoost: 1.5, color: 0, acousticSwap: false, addsPad: false, lofi: false, summary: "Looser timing and dynamics, like a band in a room."),
        Variation(name: "Lo-fi Tape", tempo: 0.92, energy: -0.15, density: -0.1, feelBoost: 1.8, color: 1, acousticSwap: false, addsPad: false, lofi: true, summary: "Wobbly, dusty and relaxed."),
        Variation(name: "Cinematic", tempo: 0.94, energy: -0.05, density: -0.1, feelBoost: 1.1, color: 1, acousticSwap: false, addsPad: true, lofi: false, summary: "Adds strings and space for a film-score feel."),
        Variation(name: "Unplugged", tempo: 0.96, energy: -0.1, density: -0.05, feelBoost: 1.2, color: 0, acousticSwap: true, addsPad: false, lofi: false, summary: "Acoustic instruments only."),
    ]

    static let acousticMap: [InstrumentID: InstrumentID] = [
        .rhodes: .grandPiano, .wurlitzer: .grandPiano, .clavinet: .grandPiano, .synthPluck: .marimba, .synthLead: .flute,
        .cleanGuitar: .steelGuitar, .overdriveGuitar: .steelGuitar, .mutedGuitar: .nylonGuitar,
        .synthBass: .acousticBass, .bass808: .acousticBass, .fingerBass: .acousticBass, .slapBass: .acousticBass,
        .electronicKit: .brushKit, .kit808: .percussion, .drumKit: .brushKit, .pad: .strings, .warmPad: .strings, .organ: .strings,
    ]

    static func build() -> [Style] {
        var out: [Style] = []
        for base in bases {
            for v in variations {
                var parts = base.parts.map { part -> PartSpec in
                    var p = part
                    p.density = min(1, max(0.15, p.density + v.density))
                    if v.acousticSwap, let swap = acousticMap[p.instrument] { p.instrument = swap }
                    return p
                }
                if v.addsPad, !parts.contains(where: { if case .line = $0.kind { return true } else { return false } }) {
                    parts.append(PartSpec(.line(.pad), .strings))
                }
                var feel = base.feel
                feel.jitterMs *= v.feelBoost
                feel.velocityVariance = min(0.3, feel.velocityVariance * v.feelBoost)
                if v.lofi { feel.behindMs += 10; feel.swing = max(feel.swing, 0.3) }
                if v.name == "Live Band" { feel.behindMs += 4 }
                var harmony = base.harmony
                harmony.colorLevel = min(3, harmony.colorLevel + v.color)
                let tempo = (base.bpm * v.tempo).rounded()
                let range = min(base.tempo.lowerBound, tempo)...max(base.tempo.upperBound, tempo)

                // Band sizes. Skip a size when it would be identical to a bigger one.
                var ensembles: [(String, [PartSpec])] = [("Band", parts)]
                let core = Array(parts.prefix(3))
                if core.count < parts.count { ensembles.append(("Trio", core)) }
                let duo = Array(parts.prefix(2))
                if duo.count < core.count { ensembles.append(("Duo", duo)) }

                for (ens, ensParts) in ensembles {
                    let id = [base.id, v.name == "Classic" ? nil : v.name.lowercased().replacingOccurrences(of: " ", with: "-"),
                              ens == "Band" ? nil : ens.lowercased()].compactMap { $0 }.joined(separator: "-")
                    var name = v.name == "Classic" ? base.name : "\(v.name) \(base.name)"
                    if ens != "Band" { name += " · \(ens)" }
                    let energy = min(1, max(0, base.energy + v.energy - (ens == "Duo" ? 0.1 : 0)))
                    var acoustic = base.acoustic + (v.acousticSwap ? 0.35 : 0) - (v.lofi ? 0.1 : 0)
                    acoustic = min(1, max(0, acoustic))
                    let live = v.acousticSwap ? (acousticMap[base.live] ?? base.live) : base.live
                    out.append(Style(id: id, name: name, family: base.family, baseName: base.name, variation: v.name, ensemble: ens,
                                     summary: v.summary.isEmpty ? base.summary : "\(base.summary) \(v.summary)",
                                     tempoRange: range, defaultTempo: tempo, beatsPerBar: base.beats, stepsPerBeat: base.steps,
                                     feel: feel, harmony: harmony, scale: base.scale, parts: ensParts, liveInstrument: live,
                                     liveVoicing: base.liveVoicing, energy: energy, acousticness: acoustic))
                }
            }
        }
        return out
    }
}
