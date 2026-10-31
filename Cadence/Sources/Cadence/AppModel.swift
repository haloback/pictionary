import AppKit
import CadenceCore
import Foundation
import Observation
import UniformTypeIdentifiers

enum AppMode: String, CaseIterable, Identifiable {
    case stage = "Stage", studio = "Studio"
    var id: String { rawValue }
}

@MainActor
@Observable
final class AppModel {
    private(set) var session: Session
    var mode: AppMode = .stage
    var showStyleBrowser = false
    var showChordEditor = false
    var selectedTrackID: UUID?
    var isPlaying = false
    var isRecording = false
    var takeCount = 0
    var recentHits: [SnapHit] = []
    var correctedCount = 0
    var heldInputs: Set<Int> = []
    var soundingOutputs: Set<Int> = []
    var midiSources: [String] = []
    var message: String?
    var computerOctave = 4
    /// Note previews per track for the Studio lanes, rebuilt when the session changes.
    private(set) var previews: [UUID: [NoteEvent]] = [:]

    let audio = AudioEngine()
    let conductor: Conductor
    private let midi = MIDIInput()
    @ObservationIgnored private var saveWork: DispatchWorkItem?

    init() {
        let initial = AppModel.loadSaved() ?? Session(style: StyleLibrary.defaultStyle)
        session = initial
        conductor = Conductor(audio: audio, session: initial)
        selectedTrackID = initial.tracks.first?.id
        wire()
        rebuildPreviews()
        midi.start()
    }

    private func wire() {
        conductor.onHit = { [weak self] hit in
            guard let self else { return }
            self.recentHits.append(hit)
            if self.recentHits.count > 24 { self.recentHits.removeFirst(self.recentHits.count - 24) }
            if hit.corrected { self.correctedCount += 1 }
            self.heldInputs.insert(hit.input)
            self.soundingOutputs.formUnion(hit.outputs)
        }
        conductor.onRelease = { [weak self] input, released in
            guard let self else { return }
            self.heldInputs.remove(input)
            self.soundingOutputs.subtract(released)
            if self.heldInputs.isEmpty { self.soundingOutputs = [] }
        }
        conductor.onTempoDetected = { [weak self] bpm in
            self?.session.tempo = bpm
        }
        conductor.onTransportChanged = { [weak self] playing in
            self?.isPlaying = playing
            if !playing { self?.isRecording = false }
        }
        let conductor = self.conductor
        midi.onEvent = { @Sendable event in
            switch event {
            case .noteOn(let n, let v): conductor.liveNoteOn(n, velocity: v)
            case .noteOff(let n): conductor.liveNoteOff(n)
            case .sustain(let down): conductor.sustain(down)
            }
        }
        midi.onSourcesChanged = { [weak self] names in
            self?.midiSources = names
        }
    }

    // MARK: Session changes

    var style: Style { session.style }

    func mutate(_ change: (inout Session) -> Void) {
        change(&session)
        conductor.update(session: session)
        rebuildPreviews()
        scheduleSave()
    }

    private func rebuildPreviews() {
        let arranger = Arranger(session: session)
        let bars = session.songBars
        var p: [UUID: [NoteEvent]] = [:]
        for t in session.tracks {
            p[t.id] = (0..<bars).flatMap { arranger.render(track: t, bar: $0) }
        }
        previews = p
    }

    func select(style: Style, keepProgression: Bool = false) {
        mutate { $0.apply(style: style, keepProgression: keepProgression) }
        selectedTrackID = session.tracks.first?.id
        correctedCount = 0
    }

    func regenerateProgression() { mutate { $0.regenerateProgression() } }

    func varyBand() { mutate { $0.variationSeed &+= 7 } }

    func setKey(tonic: Int? = nil, scale: ScaleType? = nil) {
        let k = Key(tonic: tonic ?? session.key.tonic, scale: scale ?? session.key.scale)
        mutate { $0.setKey(k) }
    }

    func setTempo(_ bpm: Double) { mutate { $0.tempo = min(max(bpm.rounded(), 40), 300) } }
    func setAutoTempo(_ on: Bool) { mutate { $0.autoTempo = on } }
    func setSnap(_ s: SnapStrength) { mutate { $0.snap = s } }
    func setKeyMap(_ m: KeyMap) { mutate { $0.keyMap = m } }

    var keyMapper: KeyMapper {
        KeyMapper(key: session.key, progressionChords: session.progression.slots.map(\.chord), colorLevel: style.harmony.colorLevel)
    }

    func apply(named: NamedProgression) {
        mutate { $0.apply(named: named) }
        message = "\(named.name): \(session.progression.slots.map { chordName($0.chord) }.joined(separator: " – "))"
    }

    func reharmonizations(for index: Int) -> [Reharmonizer.Suggestion] {
        let slots = session.progression.slots
        guard let slot = slots[safe: index] else { return [] }
        return Reharmonizer.suggestions(for: slot.chord, next: slots[safe: (index + 1) % slots.count]?.chord, key: session.key)
    }

    /// Splits a chord's time in half and puts a chord that leads into the next one in the second half.
    func insertLeadIn(at index: Int, chord: Chord) {
        mutate { s in
            guard s.progression.slots.indices.contains(index) else { return }
            let half = s.progression.slots[index].beats / 2
            guard half >= 1 else { s.progression.slots[index].chord = chord; return }
            s.progression.slots[index].beats = half
            s.progression.slots.insert(ChordSlot(chord: chord, beats: half), at: index + 1)
            s.progressionSource = "Edited"
        }
    }
    func setLiveInstrument(_ id: InstrumentID) { mutate { $0.liveInstrument = id } }

    func updateTrack(_ id: UUID, _ change: (inout Track) -> Void) {
        mutate { s in
            if let i = s.tracks.firstIndex(where: { $0.id == id }) { change(&s.tracks[i]) }
        }
    }

    func toggleMute(_ id: UUID) { updateTrack(id) { $0.muted.toggle() } }
    func toggleSolo(_ id: UUID) { updateTrack(id) { $0.solo.toggle() } }

    func deleteTrack(_ id: UUID) {
        mutate { $0.tracks.removeAll { $0.id == id } }
        if selectedTrackID == id { selectedTrackID = session.tracks.first?.id }
    }

    func setTrackLength(_ id: UUID, bars: Int?) {
        updateTrack(id) { t in t.lengthBars = bars.map { max(1, $0) } }
    }

    func addLayer(_ kind: PartKind, instrument: InstrumentID) {
        mutate { $0.addTrack(part: PartSpec(kind, instrument)) }
        selectedTrackID = session.tracks.last?.id
    }

    func setPart(_ id: UUID, _ change: (inout PartSpec) -> Void) {
        updateTrack(id) { t in
            guard case .generated(var p) = t.source else { return }
            change(&p)
            t.source = .generated(p)
            t.instrument = p.instrument
        }
    }

    // MARK: Chords

    func replaceChord(at index: Int, with chord: Chord) {
        mutate { s in
            guard s.progression.slots.indices.contains(index) else { return }
            s.progression.slots[index].chord = chord
            s.progressionSource = "Edited"
        }
    }

    func deleteChord(at index: Int) {
        mutate { s in
            guard s.progression.slots.count > 1, s.progression.slots.indices.contains(index) else { return }
            s.progression.slots.remove(at: index)
            s.progressionSource = "Edited"
        }
    }

    func insertChord(after index: Int) {
        mutate { s in
            let src = s.progression.slots[min(index, s.progression.slots.count - 1)]
            s.progression.slots.insert(ChordSlot(chord: src.chord, beats: Double(s.beatsPerBar)), at: index + 1)
            s.progressionSource = "Edited"
        }
    }

    func setChordLength(at index: Int, beats: Double) {
        mutate { s in
            guard s.progression.slots.indices.contains(index) else { return }
            s.progression.slots[index].beats = max(1, beats)
        }
    }

    /// Chords that make sense to swap in at a slot: diatonic chords plus colors of the current one.
    func chordSuggestions(for index: Int) -> [Chord] {
        let key = session.key
        var list: [Chord] = (0..<7).map { key.diatonicChord(degree: $0, seventh: style.harmony.colorLevel >= 1) }
        if let current = session.progression.slots[safe: index]?.chord {
            for q in [ChordQuality.major7, .minor7, .dominant7, .major9, .minor9, .dominant13, .sus4, .add9, .minor11] {
                list.append(Chord(root: current.root, quality: q))
            }
        }
        var seen = Set<Chord>()
        return list.filter { seen.insert($0).inserted }
    }

    func importText(_ text: String) -> Bool {
        guard let prog = ChordDetector.progression(fromText: text, beatsPerBar: session.beatsPerBar) else {
            message = "Couldn't read those chords. Try something like “Dm9 G13 Cmaj9 A7”."
            return false
        }
        let key = ChordDetector.key(for: prog)
        mutate { s in
            s.progression = prog
            s.key = key
            s.progressionSource = "Typed"
        }
        return true
    }

    // MARK: Transport

    func togglePlay() {
        if isPlaying {
            if isRecording { finishTake() }
            conductor.stop()
        } else {
            conductor.play()
        }
    }

    func toggleRecord() {
        if isRecording { finishTake() } else {
            conductor.startRecording()
            isRecording = true
            isPlaying = true
            correctedCount = 0
        }
    }

    private func finishTake() {
        isRecording = false
        guard let take = conductor.stopRecording() else {
            message = "Nothing was played, so no take was kept."
            return
        }
        takeCount += 1
        let inst = InstrumentProfile.of(session.liveInstrument)
        var track = Track(name: "Take \(takeCount) · \(inst.name)", source: .recorded, instrument: inst.id, volume: 0.9,
                          colorIndex: 0)
        track.take = take.notes
        track.takeBars = take.bars
        track.startBar = take.startBar
        track.humanize = 0
        mutate { s in
            s.tracks.insert(track, at: 0)
            s.minimumBars = max(s.minimumBars, take.startBar + take.bars)
        }
        selectedTrackID = track.id
    }

    // MARK: Live input from the UI

    static let computerKeys: [Character: Int] = [
        "a": 0, "w": 1, "s": 2, "e": 3, "d": 4, "f": 5, "t": 6, "g": 7, "y": 8, "h": 9, "u": 10, "j": 11,
        "k": 12, "o": 13, "l": 14, "p": 15, ";": 16, "'": 17,
    ]

    /// Typing on the Mac keyboard plays too: the home row is a piano.
    func computerKey(_ characters: String, down: Bool) -> Bool {
        guard let c = characters.lowercased().first else { return false }
        if down && c == "z" { computerOctave = max(1, computerOctave - 1); return true }
        if down && c == "x" { computerOctave = min(7, computerOctave + 1); return true }
        if down && c == " " { togglePlay(); return true }
        if down && c == "r" { toggleRecord(); return true }
        guard let offset = Self.computerKeys[c] else { return false }
        let note = (computerOctave + 1) * 12 + offset
        if down { conductor.liveNoteOn(note, velocity: Int.random(in: 84...104)) } else { conductor.liveNoteOff(note) }
        return true
    }

    func pianoKey(_ note: Int, down: Bool) {
        if down { conductor.liveNoteOn(note, velocity: 96) } else { conductor.liveNoteOff(note) }
    }

    // MARK: Import / export

    func importFiles(_ urls: [URL]) -> Bool {
        guard let url = urls.first(where: { ["mid", "midi", "smf"].contains($0.pathExtension.lowercased()) }) else {
            if let url = urls.first, let text = try? String(contentsOf: url, encoding: .utf8) { return importText(text) }
            message = "Drop a .mid file to import its chords."
            return false
        }
        do {
            let data = try Data(contentsOf: url)
            let contents = try MIDIFile.read(data)
            let bpb = contents.beatsPerBar ?? session.beatsPerBar
            guard let (prog, key) = ChordDetector.progression(from: contents.notes, beatsPerBar: bpb) else {
                message = "No chords found in \(url.lastPathComponent)."
                return false
            }
            mutate { s in
                s.progression = prog
                s.key = key
                if let bpm = contents.tempo, s.style.tempoRange.contains(bpm) { s.tempo = bpm.rounded() }
                s.progressionSource = url.deletingPathExtension().lastPathComponent
            }
            message = "Imported \(prog.slots.count) chords from \(url.lastPathComponent) in \(key.displayName)."
            return true
        } catch {
            message = "Couldn't read \(url.lastPathComponent)."
            return false
        }
    }

    func openImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.midi, .plainText]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { _ = importFiles([url]) }
    }

    var exportName: String { "\(style.name.replacingOccurrences(of: "/", with: "-")) \(Int(session.tempo)) BPM" }

    func writeExport(track: Track? = nil) -> URL? {
        let data = track.map { Exporter.midi(track: $0, session: session) } ?? Exporter.midi(session: session, title: exportName)
        let name = (track?.name ?? exportName).replacingOccurrences(of: "/", with: "-")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Cadence Export", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(name).mid")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            message = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// For dragging the multi-track MIDI onto Finder, Logic, GarageBand…
    func dragProvider(track: Track? = nil) -> NSItemProvider {
        guard let url = writeExport(track: track), let provider = NSItemProvider(contentsOf: url) else { return NSItemProvider() }
        provider.suggestedName = url.deletingPathExtension().lastPathComponent
        return provider
    }

    func exportWithPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.midi]
        panel.nameFieldStringValue = "\(exportName).mid"
        if panel.runModal() == .OK, let dest = panel.url, let src = writeExport() {
            try? FileManager.default.removeItem(at: dest)
            do { try FileManager.default.copyItem(at: src, to: dest) } catch { message = "Export failed: \(error.localizedDescription)" }
        }
    }

    // MARK: Persistence

    nonisolated private static var saveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cadence", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.json")
    }

    nonisolated private static func loadSaved() -> Session? {
        guard let data = try? Data(contentsOf: saveURL),
              let s = try? JSONDecoder().decode(Session.self, from: data),
              StyleLibrary.byID[s.styleID] != nil else { return nil }
        return s
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let snapshot = session
        let work = DispatchWorkItem {
            if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: AppModel.saveURL, options: .atomic) }
        }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1, execute: work)
    }

    func newSession() {
        conductor.stop()
        takeCount = 0
        mutate { $0 = Session(style: $0.style, seed: Int.random(in: 1...10_000)) }
        selectedTrackID = session.tracks.first?.id
    }

    // MARK: Display helpers

    func chordName(_ chord: Chord) -> String { chord.symbol(in: session.key) }
    func noteName(_ pitch: Int) -> String { session.key.name(of: pitch) }

    /// How your hands would voice a chord right now, for display.
    func voicingText(_ chord: Chord) -> String {
        let inst = InstrumentProfile.of(session.liveInstrument)
        let v = VoicingEngine.voice(chord, style: inst.liveVoicing, range: 48...79, previous: nil)
        return v.map { noteName($0) }.joined(separator: " · ") + "   " + inst.liveVoicing.displayName.lowercased()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
