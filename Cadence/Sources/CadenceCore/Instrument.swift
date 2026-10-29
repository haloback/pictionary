import Foundation

/// How an instrument turns notes into a performance.
public enum Articulation: String, Codable, Sendable {
    /// Notes ring for their written length (piano, keys).
    case normal
    /// Notes overlap slightly into the next one (strings, voice, winds).
    case legato
    /// Short and punchy (horns stabs, pizzicato, plucks).
    case staccato
    /// Chords roll low-to-high or high-to-low like a pick across strings.
    case strum
    /// Long and soft, held through the chord (pads, choir).
    case sustain
}

public enum InstrumentID: String, CaseIterable, Codable, Sendable, Identifiable {
    case grandPiano, feltPiano, rhodes, wurlitzer, organ, clavinet
    case nylonGuitar, steelGuitar, cleanGuitar, mutedGuitar, overdriveGuitar
    case violin, viola, cello, strings, pizzicato, harp
    case flute, clarinet, saxophone, trumpet, horns, brass
    case choir, pad, warmPad, synthLead, synthPluck
    case acousticBass, fingerBass, slapBass, synthBass, bass808
    case marimba, vibraphone, kalimba, steelDrums
    case drumKit, brushKit, jazzKit, electronicKit, kit808, percussion

    public var id: String { rawValue }
}

public struct InstrumentProfile: Hashable, Sendable {
    public let id: InstrumentID
    public let name: String
    /// General MIDI program (0-based). Used for export and for the built-in sound bank.
    public let program: Int
    public let isDrums: Bool
    public let range: ClosedRange<Int>
    public let articulation: Articulation
    /// One voice at a time (a violin plays the top note of what you mash).
    public let monophonic: Bool
    /// Most notes it will sound at once.
    public let maxVoices: Int
    /// Scales velocity: a violin is gentler than a piano.
    public let velocityScale: Double
    /// Upper bound on any single velocity.
    public let velocityCeiling: Int
    /// Strum spread between strings, in milliseconds.
    public let strumMs: Double
    /// Note length multiplier applied on top of the pattern.
    public let lengthScale: Double
    /// The voicing this instrument plays when you mash a chord.
    public let liveVoicing: VoicingStyle
    public let character: String
    public let family: Family

    public enum Family: String, Sendable, CaseIterable {
        case keys = "Keys", guitar = "Guitar", strings = "Strings", winds = "Winds & Brass"
        case voices = "Voices & Synths", bass = "Bass", mallets = "Mallets", drums = "Drums"
    }

    public static func of(_ id: InstrumentID) -> InstrumentProfile { table[id]! }

    public static var all: [InstrumentProfile] { InstrumentID.allCases.map { of($0) } }

    static let table: [InstrumentID: InstrumentProfile] = {
        var t: [InstrumentID: InstrumentProfile] = [:]
        func add(_ id: InstrumentID, _ name: String, _ program: Int, _ family: Family, range: ClosedRange<Int>,
                 _ art: Articulation, mono: Bool = false, voices: Int = 10, vel: Double = 1, ceiling: Int = 127,
                 strum: Double = 0, length: Double = 1, voicing: VoicingStyle = .close, drums: Bool = false,
                 _ character: String) {
            t[id] = InstrumentProfile(id: id, name: name, program: program, isDrums: drums, range: range,
                                      articulation: art, monophonic: mono, maxVoices: voices, velocityScale: vel,
                                      velocityCeiling: ceiling, strumMs: strum, lengthScale: length,
                                      liveVoicing: voicing, character: character, family: family)
        }
        add(.grandPiano, "Grand Piano", 0, .keys, range: 21...108, .normal, voicing: .spread,
            "Full concert grand. Both hands, sustain pedal, chords spread across two octaves.")
        add(.feltPiano, "Felt Piano", 0, .keys, range: 36...96, .sustain, vel: 0.7, ceiling: 92, length: 1.2, voicing: .spread,
            "Soft hammers and long sustain. Everything is gentle and close.")
        add(.rhodes, "Rhodes", 4, .keys, range: 36...91, .normal, vel: 0.85, voicing: .rootless,
            "Bell-like electric piano. Mashed chords turn into rootless 9th and 11th voicings.")
        add(.wurlitzer, "Wurlitzer", 4, .keys, range: 36...91, .normal, vel: 0.9, voicing: .close,
            "Reedy electric piano with a bit of bark when you dig in.")
        add(.organ, "Organ", 16, .keys, range: 36...96, .sustain, vel: 0.9, length: 1.05, voicing: .close,
            "Drawbar organ. Notes hold full and swell with the band.")
        add(.clavinet, "Clavinet", 7, .keys, range: 36...91, .staccato, length: 0.5, voicing: .close,
            "Funky, percussive keys. Short, choppy and on the groove.")
        add(.nylonGuitar, "Nylon Guitar", 24, .guitar, range: 40...84, .strum, voices: 6, vel: 0.85, strum: 14, voicing: .guitar,
            "Warm classical guitar. Chords are finger-rolled, single notes are plucked.")
        add(.steelGuitar, "Acoustic Guitar", 25, .guitar, range: 40...84, .strum, voices: 6, vel: 0.9, strum: 11, voicing: .guitar,
            "Steel-string strums that alternate down and up with the groove.")
        add(.cleanGuitar, "Clean Electric", 27, .guitar, range: 40...86, .strum, voices: 6, vel: 0.85, strum: 9, voicing: .guitar,
            "Bright, clean electric. Picked patterns interlock with the rhythm section.")
        add(.mutedGuitar, "Muted Guitar", 28, .guitar, range: 40...76, .staccato, voices: 6, vel: 0.85, strum: 6, length: 0.35, voicing: .guitar,
            "Palm-muted chucks and skanks.")
        add(.overdriveGuitar, "Overdrive Guitar", 29, .guitar, range: 40...84, .strum, voices: 3, vel: 0.95, strum: 7, voicing: .triad,
            "Crunchy power chords and riffs.")
        add(.violin, "Violin", 40, .strings, range: 55...100, .legato, mono: true, voices: 1, vel: 0.72, ceiling: 100, length: 1.1, voicing: .close,
            "Soft and connected. Held notes swell with a slow bow, fast notes turn light and bouncy. Plays the top note of whatever you mash.")
        add(.viola, "Viola", 41, .strings, range: 48...88, .legato, mono: true, voices: 1, vel: 0.72, ceiling: 100, length: 1.1,
            "Darker than a violin. A singing inner line.")
        add(.cello, "Cello", 42, .strings, range: 36...76, .legato, mono: true, voices: 1, vel: 0.78, ceiling: 105, length: 1.1,
            "Deep, warm and vocal. Follows the bass line with slides.")
        add(.strings, "String Section", 48, .strings, range: 36...96, .sustain, voices: 6, vel: 0.7, ceiling: 100, length: 1.05, voicing: .spread,
            "Lush ensemble. Chords bloom slowly and hold.")
        add(.pizzicato, "Pizzicato Strings", 45, .strings, range: 36...96, .staccato, voices: 4, vel: 0.85, length: 0.4, voicing: .triad,
            "Plucked strings, light and playful.")
        add(.harp, "Harp", 46, .strings, range: 24...103, .strum, voices: 8, vel: 0.8, strum: 40, voicing: .spread,
            "Every chord becomes a glistening rolled arpeggio.")
        add(.flute, "Flute", 73, .winds, range: 60...96, .legato, mono: true, voices: 1, vel: 0.75, ceiling: 105,
            "Airy and light. Plays the top voice.")
        add(.clarinet, "Clarinet", 71, .winds, range: 50...91, .legato, mono: true, voices: 1, vel: 0.78,
            "Woody and smooth.")
        add(.saxophone, "Tenor Sax", 66, .winds, range: 44...80, .legato, mono: true, voices: 1, vel: 0.85,
            "Breathy and soulful.")
        add(.trumpet, "Trumpet", 56, .winds, range: 54...86, .legato, mono: true, voices: 1, vel: 0.85,
            "Bright and singing.")
        add(.horns, "Horn Section", 61, .winds, range: 48...84, .staccato, voices: 3, length: 0.55, voicing: .close,
            "Short, punchy stabs in three-part harmony.")
        add(.brass, "Brass Ensemble", 61, .winds, range: 40...84, .sustain, voices: 5, vel: 0.85, voicing: .spread,
            "Big, warm brass swells.")
        add(.choir, "Choir", 52, .voices, range: 48...84, .sustain, voices: 4, vel: 0.7, ceiling: 100, length: 1.1, voicing: .close,
            "Sustained 'ooh' in close harmony that follows each chord.")
        add(.pad, "Synth Pad", 89, .voices, range: 36...91, .sustain, voices: 6, vel: 0.7, length: 1.1, voicing: .spread,
            "Slow-blooming pad that fills out the room.")
        add(.warmPad, "Warm Pad", 89, .voices, range: 36...91, .sustain, voices: 6, vel: 0.65, length: 1.1, voicing: .quartal,
            "Soft analog pad voiced in open fourths.")
        add(.synthLead, "Synth Lead", 81, .voices, range: 48...96, .legato, mono: true, voices: 1, vel: 0.9,
            "Gliding mono lead.")
        add(.synthPluck, "Synth Pluck", 84, .voices, range: 48...96, .staccato, voices: 4, length: 0.4, voicing: .triad,
            "Bright, short plucks for house and pop.")
        add(.acousticBass, "Upright Bass", 32, .bass, range: 28...55, .normal, mono: true, voices: 1, vel: 0.9,
            "Woody upright. Walks, slides and leaves space.")
        add(.fingerBass, "Electric Bass", 33, .bass, range: 28...55, .normal, mono: true, voices: 1, vel: 0.9,
            "Fingered electric bass, round and steady.")
        add(.slapBass, "Slap Bass", 36, .bass, range: 28...60, .staccato, mono: true, voices: 1, length: 0.6,
            "Popping funk bass.")
        add(.synthBass, "Synth Bass", 38, .bass, range: 24...55, .normal, mono: true, voices: 1,
            "Fat analog bass.")
        add(.bass808, "808 Bass", 38, .bass, range: 24...50, .legato, mono: true, voices: 1, length: 1.2,
            "Long, booming 808 with glides.")
        add(.marimba, "Marimba", 12, .mallets, range: 45...96, .staccato, voices: 4, length: 0.5, voicing: .triad,
            "Warm wooden mallets.")
        add(.vibraphone, "Vibraphone", 11, .mallets, range: 53...89, .normal, voices: 4, vel: 0.8, voicing: .rootless,
            "Shimmering vibes for jazz and lounge.")
        add(.kalimba, "Kalimba", 108, .mallets, range: 55...91, .staccato, voices: 3, vel: 0.8, length: 0.6, voicing: .triad,
            "Thumb piano, delicate and bright.")
        add(.steelDrums, "Steel Drums", 114, .mallets, range: 55...88, .staccato, voices: 3, length: 0.6, voicing: .triad,
            "Caribbean steel pan.")
        add(.drumKit, "Drum Kit", 0, .drums, range: 27...87, .normal, drums: true, "Standard acoustic kit.")
        add(.brushKit, "Brush Kit", 40, .drums, range: 27...87, .normal, vel: 0.8, drums: true, "Brushes on snare, soft and swishy.")
        add(.jazzKit, "Jazz Kit", 32, .drums, range: 27...87, .normal, vel: 0.85, drums: true, "Tuned-up jazz kit with ride cymbal.")
        add(.electronicKit, "Electronic Kit", 24, .drums, range: 27...87, .normal, drums: true, "Punchy electronic drums.")
        add(.kit808, "808 Kit", 25, .drums, range: 27...87, .normal, drums: true, "Classic drum-machine kit.")
        add(.percussion, "Percussion", 0, .drums, range: 27...87, .normal, vel: 0.85, drums: true, "Shakers, congas, tambourine and clave.")
        return t
    }()
}

/// General MIDI drum notes.
public enum Drum: Int, Codable, Sendable {
    case kick = 36, sideStick = 37, snare = 38, clap = 39, lowTom = 45, midTom = 47, highTom = 50
    case closedHat = 42, pedalHat = 44, openHat = 46, crash = 49, ride = 51, rideBell = 53
    case tambourine = 54, cowbell = 56, highConga = 62, lowConga = 64, cabasa = 69, shaker = 70
    case clave = 75, woodBlock = 76, highBongo = 60, lowBongo = 61, timbale = 65
}
