import Foundation
import CadenceCore

/// What a key press turned into, for the snap display.
struct SnapHit: Identifiable, Hashable {
    let id = UUID()
    let input: Int
    let outputs: [Int]
    var corrected: Bool { outputs.count != 1 || outputs.first != input }
}

/// Runs the band in real time on its own thread, and handles live playing with
/// as little latency as possible. All state is guarded by `lock`; callbacks are
/// delivered on the main queue.
final class Conductor: @unchecked Sendable {
    static let liveTrackID = UUID(uuidString: "00000000-0000-0000-0000-00000000CAFE")!

    private struct Scheduled {
        var beat: Double          // absolute beat
        var track: UUID
        var pitch: Int
        var velocity: Int         // 0 = off
    }

    private let audio: AudioEngine
    private let lock = NSLock()

    private var session: Session
    private var arranger: Arranger
    private var tempo: Double

    // Transport. Absolute beats count up forever; song beats wrap when looping.
    private var playing = false
    private var anchorTime = 0.0
    private var anchorBeat = 0.0
    private var offsetBeats = 0.0
    private var looping = true
    private var nextBar = 0
    private var queue: [Scheduled] = []
    private var generation = 0

    // Live playing.
    private let performer: Performer
    private var recorder: TakeRecorder?
    private var tempoDetector = TempoDetector()
    private var lastTempoUpdate = 0.0
    private var sustainDown = false
    private var sustained: Set<Int> = []
    var startOnFirstNote = true

    // Delivered on the main thread.
    var onHit: (@MainActor (SnapHit) -> Void)?
    var onRelease: (@MainActor (Int, [Int]) -> Void)?
    var onTempoDetected: (@MainActor (Double) -> Void)?
    var onTransportChanged: (@MainActor (Bool) -> Void)?

    private func onMain(_ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated { work() } }
    }

    init(audio: AudioEngine, session: Session) {
        self.audio = audio
        self.session = session
        self.arranger = Arranger(session: session)
        self.tempo = session.tempo
        self.performer = Performer(key: session.key, snap: session.snap, instrument: .of(session.liveInstrument))
        performer.keyMap = session.keyMap
        performer.mapper = KeyMapper(key: session.key, progressionChords: session.progression.slots.map(\.chord),
                                     colorLevel: session.style.harmony.colorLevel)
        configureAudio(for: session)
    }

    static func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000 }

    // MARK: Clock (call with lock held)

    private var beatsPerBar: Double { Double(session.beatsPerBar) }
    private var songLengthBeats: Double { Double(session.songBars) * beatsPerBar }

    private func absBeat(at t: Double) -> Double { anchorBeat + (t - anchorTime) * tempo / 60 }
    private func time(ofAbsBeat b: Double) -> Double { anchorTime + (b - anchorBeat) * 60 / tempo }

    private func songBeat(fromAbs b: Double) -> Double {
        let s = b - offsetBeats
        guard looping else { return s }
        let length = songLengthBeats
        var r = s.truncatingRemainder(dividingBy: length)
        if r < 0 { r += length }
        return r
    }

    // MARK: Public state

    var isPlaying: Bool { lock.lock(); defer { lock.unlock() }; return playing }
    var isRecording: Bool { lock.lock(); defer { lock.unlock() }; return recorder != nil }

    /// Current position in the song, in beats.
    func currentSongBeat() -> Double {
        lock.lock(); defer { lock.unlock() }
        guard playing else { return 0 }
        return max(songBeat(fromAbs: absBeat(at: Self.now())), 0)
    }

    // MARK: Session updates

    func update(session newSession: Session) {
        lock.lock()
        let old = session
        session = newSession
        arranger = Arranger(session: recorder == nil ? newSession : openEnded(newSession))
        performer.key = newSession.key
        performer.snap = newSession.snap
        performer.keyMap = newSession.keyMap
        performer.mapper = KeyMapper(key: newSession.key, progressionChords: newSession.progression.slots.map(\.chord),
                                     colorLevel: newSession.style.harmony.colorLevel)
        if performer.instrument.id != newSession.liveInstrument {
            performer.instrument = .of(newSession.liveInstrument)
        }
        if newSession.tempo != tempo {
            if playing {
                let t = Self.now()
                anchorBeat = absBeat(at: t)
                anchorTime = t
            }
            tempo = newSession.tempo
        }
        let wasAudible = Set(old.tracks.filter { old.isAudible($0) }.map(\.id))
        let nowAudible = Set(newSession.tracks.filter { newSession.isAudible($0) }.map(\.id))
        if playing { requeueFromNow() }
        lock.unlock()

        configureAudio(for: newSession)
        for id in wasAudible.subtracting(nowAudible) { audio.allNotesOff(id) }
    }

    private func openEnded(_ s: Session) -> Session {
        var copy = s
        copy.minimumBars = max(s.minimumBars, 100_000)
        return copy
    }

    private func configureAudio(for session: Session) {
        let wanted = Set(session.tracks.map(\.id) + [Self.liveTrackID])
        for id in audio.configuredIDs.subtracting(wanted) { audio.remove(id: id) }
        for t in session.tracks { audio.configure(id: t.id, instrument: t.profile, volume: t.volume) }
        audio.configure(id: Self.liveTrackID, instrument: .of(session.liveInstrument), volume: 0.95)
    }

    // MARK: Transport

    func play() {
        lock.lock()
        startLocked(at: Self.now() + 0.03)
        lock.unlock()
    }

    private func startLocked(at t: Double) {
        guard !playing else { return }
        playing = true
        anchorTime = t
        anchorBeat = 0
        offsetBeats = 0
        looping = true
        nextBar = 0
        queue = []
        generation += 1
        let gen = generation
        let thread = Thread { [weak self] in self?.run(generation: gen) }
        thread.qualityOfService = .userInteractive
        thread.name = "Cadence Conductor"
        thread.start()
        onMain { self.onTransportChanged?(true) }
    }

    func stop() {
        lock.lock()
        playing = false
        generation += 1
        queue = []
        recorder = nil
        looping = true
        arranger = Arranger(session: session)
        lock.unlock()
        audio.allNotesOff(except: Self.liveTrackID)
        onMain { self.onTransportChanged?(false) }
    }

    private func run(generation gen: Int) {
        while true {
            lock.lock()
            guard playing, generation == gen else { lock.unlock(); return }
            let t = Self.now()
            let beat = absBeat(at: t)
            while Double(nextBar) * beatsPerBar <= beat + 1.0 {
                scheduleBar(nextBar, after: -Double.infinity)
                nextBar += 1
            }
            var due: [Scheduled] = []
            var i = 0
            while i < queue.count, queue[i].beat <= beat { i += 1 }
            if i > 0 {
                due = Array(queue[0..<i])
                queue.removeFirst(i)
            }
            var wait = 0.002
            if let next = queue.first { wait = min(wait, max(time(ofAbsBeat: next.beat) - t, 0)) }
            lock.unlock()

            for e in due {
                if e.velocity > 0 { audio.noteOn(e.track, pitch: e.pitch, velocity: e.velocity) } else { audio.noteOff(e.track, pitch: e.pitch) }
            }
            if wait > 0.0003 { Thread.sleep(forTimeInterval: wait) }
        }
    }

    /// Queues one bar. Only notes starting after `after` (absolute beat) are added.
    private func scheduleBar(_ bar: Int, after: Double) {
        let barStart = Double(bar) * beatsPerBar
        let songStart = songBeat(fromAbs: barStart)
        let songBar = Int((songStart / beatsPerBar).rounded(.down))
        let shift = barStart - Double(songBar) * beatsPerBar
        var added: [Scheduled] = []
        let s = arranger.session
        for track in s.tracks where s.isAudible(track) {
            for e in arranger.render(track: track, bar: songBar) {
                let on = e.start + shift
                guard on > after else { continue }
                added.append(Scheduled(beat: on, track: track.id, pitch: e.pitch, velocity: e.velocity))
                added.append(Scheduled(beat: on + e.duration, track: track.id, pitch: e.pitch, velocity: 0))
            }
        }
        queue.append(contentsOf: added)
        queue.sort { $0.beat != $1.beat ? $0.beat < $1.beat : $0.velocity < $1.velocity }
    }

    /// After a change, drop queued notes that haven't started and re-render
    /// from the current position. Pending note-offs stay so nothing hangs.
    private func requeueFromNow() {
        let beat = absBeat(at: Self.now())
        queue.removeAll { $0.velocity > 0 && $0.beat > beat }
        let currentBar = Int((beat / beatsPerBar).rounded(.down))
        nextBar = max(currentBar, 0)
        scheduleBar(nextBar, after: beat)
        nextBar += 1
    }

    // MARK: Recording

    func startRecording() {
        lock.lock()
        if !playing { startLocked(at: Self.now() + 0.03) }
        let t = Self.now()
        let abs = absBeat(at: t)
        let song = max(songBeat(fromAbs: abs), 0)
        offsetBeats = abs - song
        looping = false
        let startBar = (song / beatsPerBar).rounded(.down)
        recorder = TakeRecorder(startBeat: startBar * beatsPerBar)
        arranger = Arranger(session: openEnded(session))
        requeueFromNow()
        lock.unlock()
    }

    /// Ends the take. Returns the notes, its first bar and its length in bars.
    func stopRecording() -> (notes: [NoteEvent], startBar: Int, bars: Int)? {
        lock.lock()
        defer { lock.unlock() }
        guard var rec = recorder else { return nil }
        recorder = nil
        let song = songBeat(fromAbs: absBeat(at: Self.now()))
        let take = rec.finish(atBeat: song, beatsPerBar: session.beatsPerBar)
        looping = true
        arranger = Arranger(session: session)
        if playing { requeueFromNow() }
        guard !take.notes.isEmpty else { return nil }
        return (take.notes, Int(rec.startBeat / beatsPerBar), take.bars)
    }

    // MARK: Live input (called from the MIDI thread or the main thread)

    func liveNoteOn(_ input: Int, velocity: Int) {
        lock.lock()
        let t = Self.now()
        if !playing && startOnFirstNote { startLocked(at: t) }
        let abs = playing ? absBeat(at: t) : 0
        let song = max(songBeat(fromAbs: abs), 0)
        let chord = session.progression.chord(atBeat: song)
        let outs = performer.noteOn(input, velocity: velocity, time: t, beatPhase: song - song.rounded(.down), chord: chord)
        sustained.remove(input)
        let beatsPerSecond = tempo / 60
        if recorder != nil {
            for o in outs {
                let b = song + o.delay * beatsPerSecond
                if o.isOn { recorder?.noteOn(o.pitch, velocity: o.velocity, beat: b) } else { recorder?.noteOff(o.pitch, beat: b) }
            }
        }
        let detected = detectTempo(at: t)
        lock.unlock()

        send(outs)
        let hit = SnapHit(input: input, outputs: outs.filter(\.isOn).map(\.pitch))
        onMain {
            self.onHit?(hit)
            if let detected { self.onTempoDetected?(detected) }
        }
    }

    func liveNoteOff(_ input: Int) {
        lock.lock()
        if sustainDown {
            sustained.insert(input)
            lock.unlock()
            return
        }
        let outs = releaseLocked(input)
        lock.unlock()
        send(outs)
        let released = outs.map(\.pitch)
        onMain { self.onRelease?(input, released) }
    }

    func sustain(_ down: Bool) {
        lock.lock()
        sustainDown = down
        var outs: [LiveOutput] = []
        var released: [Int] = []
        if !down {
            for input in sustained {
                outs += releaseLocked(input)
                released.append(input)
            }
            sustained = []
        }
        lock.unlock()
        send(outs)
        onMain { for i in released { self.onRelease?(i, []) } }
    }

    private func releaseLocked(_ input: Int) -> [LiveOutput] {
        let outs = performer.noteOff(input)
        if recorder != nil {
            let song = max(songBeat(fromAbs: absBeat(at: Self.now())), 0)
            for o in outs { recorder?.noteOff(o.pitch, beat: song) }
        }
        return outs
    }

    func allLiveOff() {
        lock.lock()
        let outs = performer.allOff()
        sustained = []
        lock.unlock()
        send(outs)
    }

    private func send(_ outs: [LiveOutput]) {
        for o in outs {
            let fire = { [audio] in
                if o.isOn { audio.noteOn(Self.liveTrackID, pitch: o.pitch, velocity: o.velocity) } else { audio.noteOff(Self.liveTrackID, pitch: o.pitch) }
            }
            if o.delay <= 0.0005 { fire() } else { DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + o.delay, execute: fire) }
        }
    }

    /// Follows your tempo while you play (not while recording, so takes stay on the grid).
    private func detectTempo(at t: Double) -> Double? {
        tempoDetector.add(onset: t)
        guard session.autoTempo, recorder == nil, t - lastTempoUpdate > 1.5 else { return nil }
        let style = session.style
        guard let est = tempoDetector.estimate(range: style.tempoRange, prior: session.tempo) else { return nil }
        guard abs(est - tempo) >= 1.5 else { return nil }
        lastTempoUpdate = t
        let smoothed = (tempo + (est - tempo) * 0.5).rounded()
        if playing {
            anchorBeat = absBeat(at: t)
            anchorTime = t
        }
        tempo = smoothed
        session.tempo = smoothed
        arranger = Arranger(session: session)
        return smoothed
    }
}
