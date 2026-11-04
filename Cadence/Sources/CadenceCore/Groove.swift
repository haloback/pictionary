import Foundation

/// A feel learned from real playing: how early or late each 16th of the bar
/// lands, and how hard. Applied on top of a style's own pattern.
public struct GrooveTemplate: Hashable, Codable, Sendable {
    public var name: String
    public var stepsPerBeat: Int
    /// Offset in beats for each step of the bar (positive = late).
    public var timing: [Double]
    /// Velocity multiplier for each step of the bar.
    public var velocity: [Double]
    /// 0 = ignore, 1 = full groove.
    public var amount: Double = 1

    /// Learns a groove from notes (positions in beats). Needs a couple of bars of playing.
    public static func learn(from notes: [NoteEvent], beatsPerBar: Int, name: String, stepsPerBeat: Int = 4) -> GrooveTemplate? {
        guard notes.count >= 8 else { return nil }
        let steps = beatsPerBar * stepsPerBeat
        let stepLen = 1.0 / Double(stepsPerBeat)
        var offsetSum = [Double](repeating: 0, count: steps)
        var velSum = [Double](repeating: 0, count: steps)
        var count = [Int](repeating: 0, count: steps)
        for n in notes {
            let pos = n.start.truncatingRemainder(dividingBy: Double(beatsPerBar))
            let stepF = (pos / stepLen).rounded()
            let step = Int(stepF) % steps
            let offset = pos - stepF * stepLen
            guard abs(offset) <= stepLen * 0.5 else { continue }
            offsetSum[step] += offset
            velSum[step] += Double(n.velocity)
            count[step] += 1
        }
        let filled = count.filter { $0 > 0 }.count
        guard filled >= 3 else { return nil }
        let mean = velSum.reduce(0, +) / Double(count.reduce(0, +))
        var timing = [Double](repeating: 0, count: steps)
        var velocity = [Double](repeating: 1, count: steps)
        for s in 0..<steps where count[s] > 0 {
            timing[s] = min(max(offsetSum[s] / Double(count[s]), -0.12), 0.12)
            velocity[s] = min(max(velSum[s] / Double(count[s]) / mean, 0.6), 1.4)
        }
        // Steps nobody played borrow from steps in the same spot of other beats.
        for s in 0..<steps where count[s] == 0 {
            let peers = stride(from: s % stepsPerBeat, to: steps, by: stepsPerBeat).filter { count[$0] > 0 }
            if !peers.isEmpty {
                timing[s] = peers.map { timing[$0] }.reduce(0, +) / Double(peers.count)
                velocity[s] = peers.map { velocity[$0] }.reduce(0, +) / Double(peers.count)
            }
        }
        return GrooveTemplate(name: name, stepsPerBeat: stepsPerBeat, timing: timing, velocity: velocity)
    }

    /// The step a position belongs to, if it sits on the grid.
    func step(atPos pos: Double) -> Int? {
        let stepLen = 1.0 / Double(stepsPerBeat)
        let f = pos / stepLen
        guard abs(f - f.rounded()) < 0.08 else { return nil }
        let s = Int(f.rounded())
        return timing.indices.contains(s) ? s : nil
    }

    public func offset(atPos pos: Double) -> Double {
        guard let s = step(atPos: pos) else { return 0 }
        return timing[s] * amount
    }

    public func velocityScale(atPos pos: Double) -> Double {
        guard let s = step(atPos: pos) else { return 1 }
        return 1 + (velocity[s] - 1) * amount
    }
}

/// How the band should respond to what you're playing right now.
public struct BandResponse: Hashable, Sendable {
    /// Multiplies the band's velocities (you play louder, they play louder).
    public var loudness: Double = 1
    /// Multiplies the band's density (you play busy, they give you space).
    public var busyness: Double = 1
    /// You just stopped: answer with a fill.
    public var fill = false
    /// You're digging in: lift the band (crash, fuller parts).
    public var lift = false

    public init(loudness: Double = 1, busyness: Double = 1, fill: Bool = false, lift: Bool = false) {
        self.loudness = loudness
        self.busyness = busyness
        self.fill = fill
        self.lift = lift
    }

    public static let neutral = BandResponse()
}

/// Watches your playing and turns it into a `BandResponse`.
public struct ResponseTracker: Sendable {
    private var hits: [(t: Double, v: Int)] = []
    private var lastNote = -1000.0
    private var lastFill = -1000.0
    private var smoothedLoudness = 1.0

    public init() {}

    public mutating func noteOn(velocity: Int, at t: Double) {
        hits.append((t, velocity))
        hits.removeAll { t - $0.t > 6 }
        lastNote = t
    }

    public mutating func reset() {
        hits = []
        lastNote = -1000
        lastFill = -1000
        smoothedLoudness = 1
    }

    /// Call once per bar, just before the band plays it.
    public mutating func response(at t: Double, beatSeconds: Double) -> BandResponse {
        var r = BandResponse()
        let recent = hits.filter { t - $0.t <= 3 }
        let target = recent.isEmpty ? 1.0 : min(max(Double(recent.map(\.v).reduce(0, +)) / Double(recent.count) / 85, 0.72), 1.25)
        smoothedLoudness = smoothedLoudness * 0.55 + target * 0.45
        r.loudness = smoothedLoudness
        r.lift = smoothedLoudness > 1.12

        let rate = Double(hits.filter { t - $0.t <= 2 }.count) / 2
        if rate > 6 { r.busyness = 0.65 } else if rate > 3.5 { r.busyness = 0.85 }

        // A pause after you've been playing: the band answers.
        let silence = t - lastNote
        if lastNote > -1000, silence >= beatSeconds * 2, silence < 8, lastFill < lastNote {
            r.fill = true
            r.busyness = max(r.busyness, 1.05)
            lastFill = t
        }
        return r
    }
}

/// Makes repeating one-bar patterns breathe over a 4-bar phrase: bar 2 is a
/// light variation, bar 4 a turnaround that leads into the next phrase.
enum GrooveVariation {
    static func vary(_ pattern: Pattern, kind: PartKind, barInPhrase: Int, beats: Double, rng: inout SeededRandom) -> Pattern {
        guard barInPhrase == 1 || barInPhrase == 3 else { return pattern }
        let turnaround = barInPhrase == 3
        var hits = pattern.hits
        switch kind {
        case .drums:
            // Ghost snare pickups and an open hat into the next bar.
            let offbeats = stride(from: 0.25, to: beats, by: 0.5).filter { p in !hits.contains { abs($0.pos - p) < 0.01 } }
            for p in offbeats.shuffled(using: &rng).prefix(turnaround ? 2 : 1) {
                hits.append(Hit(pos: p, len: 0.25, vel: 0.3, target: .drum(.snare), ghost: true))
            }
            if turnaround {
                if let i = hits.lastIndex(where: { $0.target == .drum(.closedHat) }) { hits[i].target = .drum(.openHat) }
                if rng.chance(0.6) { hits.append(Hit(pos: beats - 0.25, len: 0.25, vel: 0.6, target: .drum(.kick), ghost: false)) }
            }
        case .comp:
            if turnaround {
                // Leave a gap, then push into the next bar.
                if hits.count > 2, rng.chance(0.5) { hits.removeLast() }
                if !hits.contains(where: { abs($0.pos - (beats - 0.5)) < 0.01 }) {
                    let target = hits.first?.target ?? .chord
                    hits.append(Hit(pos: beats - 0.5, len: 0.5, vel: 0.8, target: target, ghost: false))
                }
            } else if rng.chance(0.5), let i = hits.indices.last(where: { hits[$0].pos >= 1 }) {
                // Anticipate one hit by an 8th.
                hits[i].pos = max(0.5, hits[i].pos - 0.5)
            }
        case .bass:
            if turnaround {
                hits.removeAll { $0.pos >= beats - 1 + 0.01 }
                hits.append(Hit(pos: beats - 1, len: 0.5, vel: 0.75, target: .fifth, ghost: false))
                hits.append(Hit(pos: beats - 0.5, len: 0.5, vel: 0.72, target: .approach, ghost: false))
            } else if rng.chance(0.4) {
                hits.append(Hit(pos: beats - 0.5, len: 0.25, vel: 0.6, target: .octave, ghost: true))
            }
        case .line:
            break
        }
        hits.sort { $0.pos < $1.pos }
        return Pattern(hits: hits)
    }

    /// A snare build into a bigger section: 8ths, then 16ths, getting louder.
    static func buildUp(beats: Double) -> Pattern {
        var hits: [Hit] = []
        var p = 0.0
        while p < beats - 0.01 {
            let progress = p / beats
            hits.append(Hit(pos: p, len: 0.25, vel: 0.45 + progress * 0.55, target: .drum(.snare), ghost: false))
            p += progress < 0.5 ? 0.5 : 0.25
        }
        hits.append(Hit(pos: 0, len: 0.25, vel: 0.9, target: .drum(.kick), ghost: false))
        hits.append(Hit(pos: beats / 2, len: 0.25, vel: 0.85, target: .drum(.kick), ghost: false))
        return Pattern(hits: hits.sorted { $0.pos < $1.pos })
    }
}
