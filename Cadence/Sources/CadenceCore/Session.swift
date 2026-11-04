import Foundation

public struct NoteEvent: Hashable, Codable, Sendable {
    public var pitch: Int
    public var velocity: Int
    /// Beats from the start of the song (or of the take, inside a recorded track).
    public var start: Double
    public var duration: Double

    public init(pitch: Int, velocity: Int, start: Double, duration: Double) {
        self.pitch = pitch
        self.velocity = velocity
        self.start = start
        self.duration = duration
    }

    public var end: Double { start + duration }
}

public enum SnapStrength: String, CaseIterable, Codable, Sendable {
    /// Every note lands on a chord tone.
    case strict
    /// Notes land in the scale; strong beats and mashed chords land on chord tones.
    case guided
    /// No correction.
    case free

    public var displayName: String { rawValue.capitalized }
    public var explanation: String {
        switch self {
        case .strict: return "Every note lands on a tone of the current chord."
        case .guided: return "Notes stay in the scale; mashed chords and strong beats land on chord tones."
        case .free: return "No correction. You're on your own."
        }
    }
}

public enum TrackSource: Hashable, Codable, Sendable {
    /// A band member the engine plays.
    case generated(PartSpec)
    /// Something you recorded.
    case recorded
}

public struct Track: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var source: TrackSource
    public var instrument: InstrumentID
    public var muted: Bool = false
    public var solo: Bool = false
    public var volume: Double
    public var startBar: Int = 0
    /// nil = runs as long as the song.
    public var lengthBars: Int?
    /// Recorded notes, beats relative to the take's start.
    public var take: [NoteEvent] = []
    /// A recorded take loops every `takeBars` bars when its region is extended.
    public var takeBars: Int = 0
    /// 0 = robotic, 1 = style default, 2 = very loose.
    public var humanize: Double = 1
    public var colorIndex: Int
    /// Recorded takes keep exactly what you played; this pulls them toward
    /// the grid on playback (0 = as played, 1 = fully on the grid).
    public var quantize: Double = 0
    /// Grid steps per beat for `quantize`: 2 = 8ths, 3 = triplets, 4 = 16ths.
    public var quantizeGrid: Int = 4

    public init(id: UUID = UUID(), name: String, source: TrackSource, instrument: InstrumentID, volume: Double, colorIndex: Int) {
        self.id = id
        self.name = name
        self.source = source
        self.instrument = instrument
        self.volume = volume
        self.colorIndex = colorIndex
    }

    public var part: PartSpec? {
        if case .generated(let p) = source { return p }
        return nil
    }

    public var isRecorded: Bool { if case .recorded = source { return true } else { return false } }

    public var roleName: String { part?.kind.roleName ?? "Your take" }

    public var profile: InstrumentProfile { InstrumentProfile.of(instrument) }

    public func endBar(songBars: Int) -> Int { startBar + (lengthBars ?? max(songBars - startBar, 1)) }
}

public struct Session: Codable, Hashable, Sendable {
    public var styleID: String
    public var key: Key
    public var progression: Progression
    public var tempo: Double
    public var autoTempo: Bool = true
    public var snap: SnapStrength = .guided
    public var keyMap: KeyMap = .anyKey
    /// What your hands sound like.
    public var liveInstrument: InstrumentID
    public var tracks: [Track]
    /// Bumping this re-rolls the band's variations.
    public var variationSeed: Int = 1
    /// Minimum song length in bars, set by recording or dragging.
    public var minimumBars: Int = 4
    /// Name of the progression's source ("Generated", or the imported file).
    public var progressionSource: String = "Generated"
    /// Verse/chorus/… in order. Empty = loop the main progression.
    public var sections: [SongSection] = []
    /// Chords for sections that have their own (keyed by `SongSection.chordsKey`).
    public var sectionProgressions: [String: Progression] = [:]
    /// The band reacts to how loud and how busy you play.
    public var bandFollowsMe: Bool = true
    /// Bars of click before recording starts from a stop.
    public var countInBars: Int = 1
    /// Metronome while playing.
    public var clickEnabled: Bool = false
    /// How tightly new takes are pulled to the grid.
    public var takeQuantize: Double = 0.3
    public var quantizeGrid: Int = 4
    /// A feel learned from MIDI you dropped in, or from one of your takes.
    public var groove: GrooveTemplate?

    public var style: Style { StyleLibrary.style(id: styleID) }

    public init(style: Style, seed: Int = 1) {
        styleID = style.id
        key = ProgressionGenerator.suggestedKey(for: style, seed: seed)
        progression = ProgressionGenerator.generate(style: style, key: key, seed: seed)
        tempo = style.defaultTempo
        liveInstrument = style.liveInstrument
        tracks = []
        variationSeed = seed
        tracks = Session.bandTracks(for: style)
    }

    public static func bandTracks(for style: Style) -> [Track] {
        style.parts.enumerated().map { i, part in
            let inst = InstrumentProfile.of(part.instrument)
            return Track(name: inst.name, source: .generated(part), instrument: part.instrument, volume: part.volume, colorIndex: i + 1)
        }
    }

    public var beatsPerBar: Int { style.beatsPerBar }

    public var progressionBars: Int {
        Int((progression.totalBeats / Double(beatsPerBar)).rounded(.up))
    }

    /// Song length: long enough for the progression, every take and every dragged region.
    public var songBars: Int {
        var bars = sections.isEmpty ? max(progressionBars, minimumBars) : max(sectionBars, minimumBars)
        for t in tracks {
            if let len = t.lengthBars { bars = max(bars, t.startBar + len) }
            if t.isRecorded { bars = max(bars, t.startBar + max(t.takeBars, 1)) }
        }
        return bars
    }

    public var hasSolo: Bool { tracks.contains { $0.solo } }

    public func isAudible(_ track: Track) -> Bool {
        if track.muted { return false }
        if hasSolo { return track.solo }
        return true
    }

    /// Switch genre. Keeps your recorded takes, rebuilds the band, and writes a
    /// new progression unless you imported one.
    public mutating func apply(style: Style, keepProgression: Bool) {
        styleID = style.id
        if !keepProgression {
            key = Key(tonic: key.tonic, scale: style.scale)
            progression = ProgressionGenerator.generate(style: style, key: key, seed: variationSeed)
            progressionSource = "Generated"
            tempo = style.defaultTempo
        } else {
            tempo = min(max(tempo, style.tempoRange.lowerBound), style.tempoRange.upperBound)
        }
        liveInstrument = style.liveInstrument
        let recorded = tracks.filter { $0.isRecorded }
        tracks = Session.bandTracks(for: style) + recorded
    }

    /// Uses a famous progression in the current key (switching to minor if it's a minor one).
    public mutating func apply(named: NamedProgression) {
        if named.minor != key.scale.isMinorish {
            key = Key(tonic: key.tonic, scale: named.minor ? .naturalMinor : .major)
        }
        progression = named.progression(tonic: key.tonic, beatsPerBar: beatsPerBar)
        progressionSource = named.name
    }

    public mutating func regenerateProgression() {
        variationSeed &+= 1
        progression = ProgressionGenerator.generate(style: style, key: key, seed: variationSeed)
        progressionSource = "Generated"
    }

    public mutating func setKey(_ newKey: Key) {
        let shift = mod12(newKey.tonic - key.tonic)
        progression.slots = progression.slots.map { slot in
            var s = slot
            s.chord = Chord(root: slot.chord.root + shift, quality: slot.chord.quality, bass: slot.chord.bass.map { $0 + shift })
            return s
        }
        if newKey.scale != key.scale && progressionSource == "Generated" {
            key = newKey
            progression = ProgressionGenerator.generate(style: style, key: key, seed: variationSeed)
        } else {
            key = newKey
        }
    }

    public mutating func addTrack(part: PartSpec) {
        let inst = InstrumentProfile.of(part.instrument)
        tracks.append(Track(name: inst.name, source: .generated(part), instrument: part.instrument, volume: part.volume,
                            colorIndex: (tracks.map(\.colorIndex).max() ?? 0) + 1))
    }
}

// Sessions saved by older versions lack the newer fields; fill in defaults.
extension Track {
    enum CodingKeys: String, CodingKey {
        case id, name, source, instrument, muted, solo, volume, startBar, lengthBars, take, takeBars, humanize, colorIndex, quantize, quantizeGrid
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        source = try c.decode(TrackSource.self, forKey: .source)
        instrument = try c.decode(InstrumentID.self, forKey: .instrument)
        muted = try c.decodeIfPresent(Bool.self, forKey: .muted) ?? false
        solo = try c.decodeIfPresent(Bool.self, forKey: .solo) ?? false
        volume = try c.decode(Double.self, forKey: .volume)
        startBar = try c.decodeIfPresent(Int.self, forKey: .startBar) ?? 0
        lengthBars = try c.decodeIfPresent(Int.self, forKey: .lengthBars)
        take = try c.decodeIfPresent([NoteEvent].self, forKey: .take) ?? []
        takeBars = try c.decodeIfPresent(Int.self, forKey: .takeBars) ?? 0
        humanize = try c.decodeIfPresent(Double.self, forKey: .humanize) ?? 1
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        quantize = try c.decodeIfPresent(Double.self, forKey: .quantize) ?? 0
        quantizeGrid = try c.decodeIfPresent(Int.self, forKey: .quantizeGrid) ?? 4
    }
}

extension Session {
    enum CodingKeys: String, CodingKey {
        case styleID, key, progression, tempo, autoTempo, snap, keyMap, liveInstrument, tracks, variationSeed, minimumBars
        case progressionSource, sections, sectionProgressions, bandFollowsMe, countInBars, clickEnabled, takeQuantize, quantizeGrid, groove
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        styleID = try c.decode(String.self, forKey: .styleID)
        key = try c.decode(Key.self, forKey: .key)
        progression = try c.decode(Progression.self, forKey: .progression)
        tempo = try c.decode(Double.self, forKey: .tempo)
        autoTempo = try c.decodeIfPresent(Bool.self, forKey: .autoTempo) ?? true
        snap = try c.decodeIfPresent(SnapStrength.self, forKey: .snap) ?? .guided
        keyMap = try c.decodeIfPresent(KeyMap.self, forKey: .keyMap) ?? .anyKey
        liveInstrument = try c.decode(InstrumentID.self, forKey: .liveInstrument)
        tracks = try c.decode([Track].self, forKey: .tracks)
        variationSeed = try c.decodeIfPresent(Int.self, forKey: .variationSeed) ?? 1
        minimumBars = try c.decodeIfPresent(Int.self, forKey: .minimumBars) ?? 4
        progressionSource = try c.decodeIfPresent(String.self, forKey: .progressionSource) ?? "Generated"
        sections = try c.decodeIfPresent([SongSection].self, forKey: .sections) ?? []
        sectionProgressions = try c.decodeIfPresent([String: Progression].self, forKey: .sectionProgressions) ?? [:]
        bandFollowsMe = try c.decodeIfPresent(Bool.self, forKey: .bandFollowsMe) ?? true
        countInBars = try c.decodeIfPresent(Int.self, forKey: .countInBars) ?? 1
        clickEnabled = try c.decodeIfPresent(Bool.self, forKey: .clickEnabled) ?? false
        takeQuantize = try c.decodeIfPresent(Double.self, forKey: .takeQuantize) ?? 0.3
        quantizeGrid = try c.decodeIfPresent(Int.self, forKey: .quantizeGrid) ?? 4
        groove = try c.decodeIfPresent(GrooveTemplate.self, forKey: .groove)
    }
}
