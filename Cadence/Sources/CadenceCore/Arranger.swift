import Foundation

/// Turns a session into notes, one bar at a time. Every bar is generated from a
/// seed of (track, bar, variation), so it is stable while you play and changes
/// only when you regenerate. Song sections change the chords and energy; a
/// `BandResponse` lets the band react to how you're playing.
public struct Arranger: Sendable {
    public let session: Session
    public let style: Style
    /// Voicings per chord slot, keyed by progression + voicing style + range.
    private let voicings: [String: [[Int]]]

    public init(session: Session) {
        self.session = session
        self.style = session.style
        var progressions: [String: Progression] = ["main": session.progression]
        for (k, p) in session.sectionProgressions { progressions[k] = p }
        var v: [String: [[Int]]] = [:]
        for (pk, prog) in progressions {
            let chords = prog.slots.map(\.chord)
            for track in session.tracks {
                guard let part = track.part else { continue }
                let (vs, range) = Arranger.voicingSetup(part: part, instrument: track.profile)
                let k = Arranger.voicingKey(pk, vs, range)
                if v[k] == nil { v[k] = VoicingEngine.voiceLoop(chords, style: vs, range: range) }
            }
        }
        voicings = v
    }

    public var beatsPerBar: Double { Double(style.beatsPerBar) }

    static func voicingKey(_ prog: String, _ v: VoicingStyle, _ r: ClosedRange<Int>) -> String {
        "\(prog)|\(v.rawValue)-\(r.lowerBound)-\(r.upperBound)"
    }

    static func voicingSetup(part: PartSpec, instrument: InstrumentProfile) -> (VoicingStyle, ClosedRange<Int>) {
        let vs = part.voicing ?? instrument.liveVoicing
        var range: ClosedRange<Int>
        switch vs {
        case .triad: range = 55...79
        case .close: range = 53...79
        case .drop2: range = 48...79
        case .rootless: range = 50...77
        case .shell: range = 41...67
        case .quartal: range = 50...81
        case .spread: range = 38...84
        case .guitar: range = 40...76
        }
        if case .line = part.kind { range = 48...84 }
        let lo = max(range.lowerBound, instrument.range.lowerBound)
        let hi = min(range.upperBound, instrument.range.upperBound)
        return (vs, lo...max(hi, lo + 12))
    }

    /// Everything a bar needs to know about where it is in the song.
    struct BarContext {
        let bar: Int
        /// Output position of the bar (song beats).
        let barStart: Double
        /// Position of the bar inside its progression's own timeline.
        let chordStart: Double
        let harmony: BarHarmony
        let density: Double
        var prog: Progression { harmony.progression }

        /// Song beat → beat inside the progression.
        func local(_ t: Double) -> Double { chordStart + (t - barStart) }
    }

    func voicing(for track: Track, progressionKey: String, slot: Int) -> [Int] {
        guard let part = track.part else { return [] }
        let (vs, range) = Arranger.voicingSetup(part: part, instrument: track.profile)
        let list = voicings[Arranger.voicingKey(progressionKey, vs, range)] ?? []
        guard !list.isEmpty else { return [] }
        return list[slot % list.count]
    }

    // MARK: Rendering

    /// All audible notes of every track in the bar range, with track ids.
    public func render(bars: Range<Int>) -> [(Track, [NoteEvent])] {
        session.tracks.filter { session.isAudible($0) }.map { t in
            (t, bars.flatMap { render(track: t, bar: $0) })
        }
    }

    public func render(track: Track, bar: Int, response: BandResponse = .neutral) -> [NoteEvent] {
        let songBars = session.songBars
        guard bar >= track.startBar, bar < track.endBar(songBars: songBars) else { return [] }
        if track.isRecorded { return renderTake(track, bar: bar) }
        guard let part = track.part else { return [] }
        var rng = SeededRandom(stableHash(track.id.uuidString), bar, session.variationSeed)
        let harmony = session.harmony(atBar: bar)
        // Quiet sections thin the band out; full ones fill it in.
        let energy = 0.45 + 0.75 * harmony.intensity
        let density = min(max(part.density * energy * response.busyness, 0.08), 1)
        let ctx = BarContext(bar: bar, barStart: Double(bar) * beatsPerBar, chordStart: Double(harmony.localBar) * beatsPerBar,
                             harmony: harmony, density: density)
        let beats = beatsPerBar
        let vary = { (p: Pattern, rng: inout SeededRandom) in
            GrooveVariation.vary(p, kind: part.kind, barInPhrase: harmony.localBar % 4, beats: beats, rng: &rng)
        }
        var events: [NoteEvent] = []
        switch part.kind {
        case .drums(let groove):
            events = renderDrums(groove, ctx: ctx, response: response, rng: &rng)
        case .comp(let comp):
            events = renderComp(vary(comp.pattern(beats: beats), &rng), track: track, ctx: ctx, rng: &rng)
        case .bass(let bass):
            events = renderBass(vary(bass.pattern(beats: beats), &rng), track: track, ctx: ctx, rng: &rng)
        case .line(let line):
            events = renderLine(line, track: track, part: part, ctx: ctx, rng: &rng)
        }
        let velocityScale = (0.78 + 0.3 * harmony.intensity) * response.loudness
        return Humanizer(feel: style.feel, tempo: session.tempo, amount: track.humanize, beatsPerBar: beatsPerBar,
                         stepsPerBeat: style.stepsPerBeat, groove: session.groove, velocityScale: velocityScale)
            .apply(events, bar: harmony.localBar, instrument: track.profile, rng: &rng)
            .map { var e = $0; e.start += ctx.barStart - Double(harmony.localBar) * beatsPerBar; return e }
    }

    func keep(_ hit: Hit, density: Double, rng: inout SeededRandom) -> Bool {
        if hit.pos == 0 { return true }
        if hit.ghost { return rng.chance(density * 0.9) }
        return rng.chance(0.55 + density * 0.6)
    }

    func renderTake(_ track: Track, bar: Int) -> [NoteEvent] {
        let loopBeats = Double(max(track.takeBars, 1)) * beatsPerBar
        let offset = Double(bar - track.startBar) * beatsPerBar
        let loopPos = offset.truncatingRemainder(dividingBy: loopBeats)
        let barStart = Double(bar) * beatsPerBar
        return track.take.compactMap { e in
            let start = Quantizer.pull(e.start, grid: track.quantizeGrid, amount: track.quantize)
            guard start >= loopPos - 1e-6, start < loopPos + beatsPerBar - 1e-6 else { return nil }
            var n = e
            n.start = barStart + (start - loopPos)
            return n
        }
    }

    // Drum events are built in "local" bar time (bar = harmony.localBar) and
    // shifted to song time by `render`.
    func renderDrums(_ groove: DrumGroove, ctx: BarContext, response: BandResponse, rng: inout SeededRandom) -> [NoteEvent] {
        let h = ctx.harmony
        let localStart = ctx.chordStart
        let phraseEnd = (h.localBar + 1) % 4 == 0
        var pattern = GrooveVariation.vary(groove.pattern(beats: beatsPerBar), kind: .drums(groove), barInPhrase: h.localBar % 4,
                                           beats: beatsPerBar, rng: &rng)
        let energetic: Set<DrumGroove> = [.pop, .rock, .fourOnFloor, .disco, .gospel, .funk, .motown, .dnb, .cinematic, .march,
                                          .country, .reggaeton, .trap, .afrobeats, .amapiano, .halfTime, .boomBap]
        if h.isSectionEnd && h.nextIntensity > h.intensity + 0.2 && energetic.contains(groove) {
            pattern = GrooveVariation.buildUp(beats: beatsPerBar)
        } else if h.isSectionEnd || response.fill || (phraseEnd && ctx.density > 0.35 && rng.chance(0.75)) {
            pattern = groove.fill(beats: beatsPerBar)
        }
        var out: [NoteEvent] = []
        for hit in pattern.hits where keep(hit, density: ctx.density, rng: &rng) {
            guard case .drum(let d) = hit.target else { continue }
            out.append(NoteEvent(pitch: d.rawValue, velocity: Int(hit.vel * 127), start: localStart + hit.pos, duration: 0.12))
        }
        let sectionHit = h.isSectionStart && h.intensity >= 0.55
        let phraseHit = h.sectionIndex == nil && h.localBar % 8 == 0 && ctx.density > 0.5
        if energetic.contains(groove) && (sectionHit || phraseHit || (response.lift && h.localBar % 4 == 0)) {
            out.append(NoteEvent(pitch: Drum.crash.rawValue, velocity: 100, start: localStart, duration: 0.5))
        }
        return out
    }

    /// The chord slot a hit should play. Off-beat hits just before a chord
    /// change anticipate the next chord, the way players push changes.
    func chordSlot(_ prog: Progression, at beat: Double, len: Double) -> Int {
        let idx = prog.slotIndex(atBeat: beat)
        let end = prog.slotEnd(atBeat: beat)
        let frac = beat - beat.rounded(.down)
        if frac > 0.01, end - beat <= 0.5 + 1e-9, beat + len > end + 1e-9 {
            return (idx + 1) % max(prog.slots.count, 1)
        }
        return idx
    }

    func renderComp(_ pattern: Pattern, track: Track, ctx: BarContext, rng: inout SeededRandom) -> [NoteEvent] {
        let inst = track.profile
        let prog = ctx.prog
        var out: [NoteEvent] = []
        let beatSec = 60.0 / session.tempo
        for hit in pattern.hits where keep(hit, density: ctx.density, rng: &rng) {
            let t = ctx.chordStart + hit.pos
            let slot = chordSlot(prog, at: t, len: hit.len)
            let voicing = voicing(for: track, progressionKey: ctx.harmony.progressionKey, slot: slot)
            guard !voicing.isEmpty else { continue }
            var notes: [Int]
            switch hit.target {
            case .chord: notes = voicing
            case .upper: notes = voicing.count > 2 ? Array(voicing.dropFirst()) : voicing
            case .low: notes = [voicing[0]]
            case .arp(let i):
                var n = voicing[i % voicing.count] + 12 * (i / voicing.count)
                while n > inst.range.upperBound { n -= 12 }
                notes = [n]
            default: notes = voicing
            }
            if notes.count > inst.maxVoices { notes = Array(notes.suffix(inst.maxVoices)) }
            // Don't hold past the chord change.
            let anticipated = slot != prog.slotIndex(atBeat: t)
            let len = anticipated ? hit.len : min(hit.len, max(prog.slotEnd(atBeat: t) - t, 0.1))
            let vel = Int(hit.vel * 127)
            if inst.articulation == .strum && notes.count > 2 {
                let down = (hit.pos * 2).truncatingRemainder(dividingBy: 2) < 0.5
                let ordered = down ? notes : notes.reversed()
                let spread = inst.strumMs / 1000 / beatSec
                for (i, n) in ordered.enumerated() {
                    let accent = down ? 1.0 - Double(i) * 0.03 : 0.8 - Double(i) * 0.04
                    out.append(NoteEvent(pitch: n, velocity: Int(Double(vel) * accent), start: t + Double(i) * spread, duration: len - Double(i) * spread))
                }
            } else {
                for n in notes {
                    // Top note sings a touch louder than the inner voices.
                    let v = n == notes.last ? vel : Int(Double(vel) * 0.88)
                    out.append(NoteEvent(pitch: n, velocity: v, start: t, duration: len))
                }
            }
        }
        return out
    }

    func bassPitch(_ pc: Int, near: Int, range: ClosedRange<Int>) -> Int {
        var n = near - 6 + mod12(pc - (near - 6))
        while n < range.lowerBound { n += 12 }
        while n > range.upperBound { n -= 12 }
        return n
    }

    func renderBass(_ pattern: Pattern, track: Track, ctx: BarContext, rng: inout SeededRandom) -> [NoteEvent] {
        let inst = track.profile
        let prog = ctx.prog
        let range = max(inst.range.lowerBound, 28)...min(inst.range.upperBound, 55)
        let home = 38
        var out: [NoteEvent] = []
        var last = home
        let key = session.key
        for hit in pattern.hits where keep(hit, density: ctx.density, rng: &rng) {
            let t = ctx.chordStart + hit.pos
            let slot = chordSlot(prog, at: t, len: hit.len)
            let chord = prog.slots[slot].chord
            let next = prog.slots[(slot + 1) % prog.slots.count].chord
            let root = bassPitch(chord.bassNote, near: home, range: range)
            var pitch: Int
            switch hit.target {
            case .root: pitch = root
            case .fifth: pitch = root + 7 <= range.upperBound ? root + 7 : root - 5
            case .octave: pitch = root + 12 <= range.upperBound ? root + 12 : root
            case .third: pitch = root + mod12((chord.third ?? chord.root + 4) - chord.root)
            case .approach:
                let target = bassPitch(next.bassNote, near: last, range: range)
                pitch = rng.chance(0.5) ? target - 1 : target + (rng.chance(0.5) ? 1 : -2)
            case .walk:
                let slotEnd = prog.slotEnd(atBeat: t)
                let slotStart = slotEnd - prog.slots[slot].beats
                if abs(t - slotStart) < 0.01 {
                    pitch = root
                } else if slotEnd - t <= 1.01 {
                    let target = bassPitch(next.bassNote, near: last, range: range)
                    pitch = rng.chance(0.6) ? target + (last < target ? -1 : 1) : target + 7 - (target + 7 > range.upperBound ? 12 : 0)
                } else {
                    let tones = chord.pitchClasses.map { bassPitch($0, near: last, range: range) } +
                        [key.nearestScaleNote(to: last + 2), key.nearestScaleNote(to: last - 2, direction: -1)]
                    let choices = tones.filter { $0 != last }
                    pitch = rng.pick(choices.isEmpty ? [root] : choices)
                }
            default: pitch = root
            }
            pitch = min(max(pitch, range.lowerBound), range.upperBound)
            last = pitch
            out.append(NoteEvent(pitch: pitch, velocity: Int(hit.vel * 127), start: t, duration: hit.len * 0.95))
        }
        return out
    }

    func renderLine(_ line: LineStyle, track: Track, part: PartSpec, ctx: BarContext, rng: inout SeededRandom) -> [NoteEvent] {
        let inst = track.profile
        let prog = ctx.prog
        let pk = ctx.harmony.progressionKey
        let barEnd = ctx.chordStart + beatsPerBar
        var out: [NoteEvent] = []
        // Chord slots that begin inside this bar (plus the one already sounding
        // when a section starts mid-chord).
        var t = ctx.chordStart
        var starts: [(Double, Int)] = []
        while t < barEnd - 1e-6 {
            let idx = prog.slotIndex(atBeat: t)
            let end = prog.slotEnd(atBeat: t)
            let slotStart = end - prog.slots[idx].beats
            if abs(slotStart - t) < 1e-6 || (t == ctx.chordStart && ctx.harmony.isSectionStart) { starts.append((t, idx)) }
            t = end
        }
        for (start, idx) in starts {
            let slot = prog.slots[idx]
            let voicing = voicing(for: track, progressionKey: pk, slot: idx)
            guard !voicing.isEmpty else { continue }
            let len = min(slot.beats, prog.slotEnd(atBeat: start) - start)
            switch line {
            case .pad:
                let notes = inst.monophonic ? [voicing.last!] : Array(voicing.suffix(inst.maxVoices))
                for n in notes {
                    out.append(NoteEvent(pitch: n, velocity: Int(70 + rng.unit() * 12), start: start, duration: len))
                }
            case .drone:
                let root = 36 + mod12(slot.chord.root - 36)
                out.append(NoteEvent(pitch: root, velocity: 64, start: start, duration: len))
                out.append(NoteEvent(pitch: root + 7, velocity: 56, start: start, duration: len))
            case .topVoice:
                var top = voicing.last!
                while top < inst.range.lowerBound + 7 { top += 12 }
                while top > inst.range.upperBound - 3 { top -= 12 }
                if ctx.density > 0.5 && len >= 2 && rng.chance(0.6) {
                    out.append(NoteEvent(pitch: top, velocity: 84, start: start, duration: len - 1))
                    let nextTop = self.voicing(for: track, progressionKey: pk, slot: (idx + 1) % prog.slots.count).last ?? top
                    let passing = session.key.nearestScaleNote(to: top + (nextTop > top ? 2 : -2), direction: nextTop > top ? 1 : -1)
                    out.append(NoteEvent(pitch: passing, velocity: 72, start: start + len - 1, duration: 1))
                } else {
                    out.append(NoteEvent(pitch: top, velocity: 84, start: start, duration: len))
                }
            case .counterMelody:
                guard rng.chance(0.35 + ctx.density * 0.5) else { continue }
                let nextVoicing = self.voicing(for: track, progressionKey: pk, slot: (idx + 1) % prog.slots.count)
                var target = nextVoicing.last ?? voicing.last!
                while target < inst.range.lowerBound + 9 { target += 12 }
                while target > inst.range.upperBound - 4 { target -= 12 }
                let steps = rng.pick([3, 4, 4, 5])
                let up = rng.chance(0.5)
                var notes: [Int] = []
                var n = target
                for _ in 0..<steps {
                    notes.insert(n, at: 0)
                    n = session.key.nearestScaleNote(to: n + (up ? -2 : 2), direction: up ? -1 : 1)
                }
                let stepLen = 0.5
                let begin = start + len - stepLen * Double(steps)
                for (i, p) in notes.enumerated() {
                    let last = i == notes.count - 1
                    out.append(NoteEvent(pitch: p, velocity: Int(66 + Double(i) * 5), start: begin + Double(i) * stepLen,
                                         duration: last ? stepLen * 1.5 : stepLen))
                }
            }
        }
        return out
    }
}
