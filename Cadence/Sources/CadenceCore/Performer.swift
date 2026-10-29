import Foundation

/// One note the live player should start or stop.
public struct LiveOutput: Hashable, Sendable {
    public var pitch: Int
    /// 0 means note-off.
    public var velocity: Int
    /// Seconds to wait before sending (used for strums and legato hand-offs).
    public var delay: Double
    /// The key that was actually pressed.
    public var input: Int

    public var isOn: Bool { velocity > 0 }
}

/// Interprets what you play so it always sounds right: wrong notes slide into
/// the scale, mashed clusters become chords, and the chosen instrument's
/// technique (strum, legato, monophonic) is applied.
///
/// Not thread-safe; the caller serializes access.
public final class Performer {
    public var key: Key
    public var snap: SnapStrength
    public var instrument: InstrumentProfile
    /// Notes pressed within this many seconds of each other count as one mash.
    public var mashWindow: Double = 0.04

    private var owners: [Int: [Int]] = [:]       // pressed key -> sounding pitches
    private var refCount: [Int: Int] = [:]       // sounding pitch -> owners
    private var groupStart: Double = -10
    private var groupInputs: [Int] = []
    private var groupStrummed = false
    private var monoNote: Int?
    private var lastInput: Int?

    public init(key: Key, snap: SnapStrength, instrument: InstrumentProfile) {
        self.key = key
        self.snap = snap
        self.instrument = instrument
    }

    public var soundingPitches: [Int] { refCount.filter { $0.value > 0 }.map(\.key).sorted() }

    /// Snaps a single pitch. `inMash` and `strongBeat` pull it to a chord tone.
    public func snapPitch(_ input: Int, chord: Chord, inMash: Bool, strongBeat: Bool) -> Int {
        let direction = (lastInput.map { input >= $0 } ?? true) ? 1 : -1
        switch snap {
        case .free:
            return input
        case .strict:
            return nearest(to: input, in: chord.pitchClasses, direction: direction)
        case .guided:
            let scaleNote = key.nearestScaleNote(to: input, direction: direction)
            if inMash || strongBeat {
                let chordNote = nearest(to: input, in: chord.pitchClasses, direction: direction)
                if abs(chordNote - input) <= 2 { return chordNote }
            }
            return scaleNote
        }
    }

    func nearest(to pitch: Int, in pcs: Set<Int>, direction: Int) -> Int {
        if pcs.contains(mod12(pitch)) { return pitch }
        for d in 1...6 {
            let a = direction >= 0 ? pitch + d : pitch - d
            let b = direction >= 0 ? pitch - d : pitch + d
            if pcs.contains(mod12(a)) { return a }
            if pcs.contains(mod12(b)) { return b }
        }
        return pitch
    }

    private func clampToRange(_ p: Int) -> Int {
        var n = p
        while n < instrument.range.lowerBound { n += 12 }
        while n > instrument.range.upperBound { n -= 12 }
        return n
    }

    private func shapeVelocity(_ v: Int) -> Int {
        let scaled = Double(v) * instrument.velocityScale
        return Int(min(max(scaled, 6), Double(instrument.velocityCeiling)))
    }

    private func start(_ pitch: Int, velocity: Int, input: Int, delay: Double = 0, into out: inout [LiveOutput]) {
        owners[input, default: []].append(pitch)
        let count = refCount[pitch, default: 0]
        refCount[pitch] = count + 1
        if count == 0 {
            out.append(LiveOutput(pitch: pitch, velocity: velocity, delay: delay, input: input))
        }
    }

    private func release(_ pitch: Int, input: Int, delay: Double = 0, into out: inout [LiveOutput]) {
        guard let count = refCount[pitch], count > 0 else { return }
        if count == 1 {
            refCount[pitch] = nil
            out.append(LiveOutput(pitch: pitch, velocity: 0, delay: delay, input: input))
        } else {
            refCount[pitch] = count - 1
        }
    }

    /// - Parameters:
    ///   - time: seconds, any monotonic clock.
    ///   - beatPhase: position within the current beat, 0..<1.
    ///   - chord: the chord sounding now.
    public func noteOn(_ input: Int, velocity: Int, time: Double, beatPhase: Double, chord: Chord) -> [LiveOutput] {
        var out: [LiveOutput] = []
        if time - groupStart > mashWindow {
            groupStart = time
            groupInputs = []
            groupStrummed = false
        }
        groupInputs.append(input)
        let inMash = groupInputs.count > 1
        let strongBeat = beatPhase < 0.12 || beatPhase > 0.93
        let vel = shapeVelocity(velocity)
        defer { lastInput = input }

        // Guitar and harp: once a mash has 3+ keys, strum a real chord shape.
        if instrument.articulation == .strum, groupInputs.count >= 3, !groupStrummed, snap != .free {
            groupStrummed = true
            let center = groupInputs.reduce(0, +) / groupInputs.count
            let lo = max(instrument.range.lowerBound, center - 14)
            let range = lo...min(instrument.range.upperBound, lo + 30)
            let shape = VoicingEngine.voice(chord, style: instrument.liveVoicing, range: range, previous: soundingPitches.isEmpty ? nil : soundingPitches)
            let spread = instrument.strumMs / 1000
            for (i, p) in shape.prefix(instrument.maxVoices).enumerated() where refCount[p, default: 0] == 0 {
                start(p, velocity: Int(Double(vel) * (1 - Double(i) * 0.03)), input: input, delay: Double(i) * spread, into: &out)
            }
            return out
        }
        if groupStrummed { return out }

        let pitch = clampToRange(snapPitch(input, chord: chord, inMash: inMash, strongBeat: strongBeat))

        if instrument.monophonic {
            if inMash, let current = monoNote, pitch <= current { return out }   // keep the top voice of a mash
            if let current = monoNote, current != pitch {
                // Legato: the new note starts before the old one lets go.
                for (k, v) in owners where v.contains(current) {
                    owners[k] = v.filter { $0 != current }
                    release(current, input: k, delay: instrument.articulation == .legato ? 0.03 : 0, into: &out)
                }
            }
            monoNote = pitch
            start(pitch, velocity: vel, input: input, into: &out)
            return out
        }

        if soundingPitches.count >= instrument.maxVoices, refCount[pitch, default: 0] == 0 { return out }
        start(pitch, velocity: vel, input: input, into: &out)
        return out
    }

    public func noteOff(_ input: Int) -> [LiveOutput] {
        var out: [LiveOutput] = []
        for p in owners[input] ?? [] {
            release(p, input: input, into: &out)
            if p == monoNote, refCount[p] == nil { monoNote = nil }
        }
        owners[input] = nil
        return out
    }

    public func allOff() -> [LiveOutput] {
        let out = refCount.keys.map { LiveOutput(pitch: $0, velocity: 0, delay: 0, input: $0) }
        owners = [:]
        refCount = [:]
        monoNote = nil
        return out
    }
}

/// Listens to when you play and estimates the tempo you're feeling.
public struct TempoDetector: Sendable {
    public private(set) var onsets: [Double] = []
    public var window: Double = 8

    public init() {}

    public mutating func add(onset t: Double) {
        if let last = onsets.last, t - last < 0.06 { return }      // chord, not a new onset
        onsets.append(t)
        onsets.removeAll { t - $0 > window }
    }

    public mutating func reset() { onsets = [] }

    /// Best tempo in `range`, gently biased toward `prior`. nil until there is
    /// enough playing to judge.
    public func estimate(range: ClosedRange<Double>, prior: Double) -> Double? {
        guard onsets.count >= 6 else { return nil }
        var pairs: [Double] = []
        for i in 0..<onsets.count {
            for j in (i + 1)..<onsets.count {
                let d = onsets[j] - onsets[i]
                if d > 4 { break }
                if d > 0.08 { pairs.append(d) }
            }
        }
        guard pairs.count >= 5 else { return nil }
        var best = prior
        var bestScore = -Double.infinity
        var bpm = range.lowerBound
        while bpm <= range.upperBound {
            let beat = 60 / bpm
            var score = 0.0
            for d in pairs {
                var s = 0.0
                for (k, w) in [(1.0, 1.0), (0.5, 0.55), (2.0, 0.7)] {
                    let x = d / (beat * k)
                    let off = abs(x - x.rounded())
                    s = max(s, w * exp(-(off * off) / (2 * 0.06 * 0.06)))
                }
                score += s
            }
            let z = (bpm - prior) / 12
            score *= 1 + 0.2 * exp(-z * z / 2)
            if score > bestScore {
                bestScore = score
                best = bpm
            }
            bpm += 0.5
        }
        return bestScore / Double(pairs.count) > 0.35 ? best : nil
    }
}

/// Collects what you play while recording into a loopable take.
public struct TakeRecorder: Sendable {
    public let startBeat: Double
    public private(set) var notes: [NoteEvent] = []
    private var open: [Int: (Double, Int)] = [:]

    public init(startBeat: Double) { self.startBeat = startBeat }

    public var isEmpty: Bool { notes.isEmpty && open.isEmpty }

    public mutating func noteOn(_ pitch: Int, velocity: Int, beat: Double) {
        if open[pitch] != nil { noteOff(pitch, beat: beat) }
        open[pitch] = (beat, velocity)
    }

    public mutating func noteOff(_ pitch: Int, beat: Double) {
        guard let (start, vel) = open.removeValue(forKey: pitch) else { return }
        notes.append(NoteEvent(pitch: pitch, velocity: vel, start: start - startBeat, duration: max(beat - start, 0.05)))
    }

    /// Finishes the take. `timingCorrection` pulls notes toward the 16th grid
    /// (0 = as played, 1 = fully quantized).
    public mutating func finish(atBeat beat: Double, beatsPerBar: Int, timingCorrection: Double = 0.3) -> (notes: [NoteEvent], bars: Int) {
        for p in Array(open.keys) { noteOff(p, beat: beat) }
        let length = max(beat - startBeat, 0.1)
        let bars = max(1, Int((length / Double(beatsPerBar) - 0.1).rounded(.up)))
        let corrected = notes.map { n -> NoteEvent in
            var c = n
            let grid = (n.start * 4).rounded() / 4
            c.start = max(0, n.start + (grid - n.start) * timingCorrection)
            return c
        }.sorted { $0.start < $1.start }
        return (corrected, bars)
    }
}
