import Foundation

/// Makes grid-perfect notes sound played: swing, sitting behind the beat,
/// timing drift, accents, phrase-level dynamics and articulation.
public struct Humanizer: Sendable {
    public var feel: Feel
    public var tempo: Double
    /// Multiplies the timing and velocity randomness (0 = robotic).
    public var amount: Double
    public var beatsPerBar: Double
    public var stepsPerBeat: Int

    public init(feel: Feel, tempo: Double, amount: Double, beatsPerBar: Double, stepsPerBeat: Int) {
        self.feel = feel
        self.tempo = tempo
        self.amount = amount
        self.beatsPerBar = beatsPerBar
        self.stepsPerBeat = stepsPerBeat
    }

    func msToBeats(_ ms: Double) -> Double { ms / 1000 * tempo / 60 }

    /// Moves off-beat 8ths (or 16ths) later toward a triplet feel.
    public func swung(_ beat: Double) -> Double {
        guard feel.swing > 0, stepsPerBeat == 4 else { return beat }
        let whole = beat.rounded(.down)
        let frac = beat - whole
        if feel.swingUnit >= 0.5 {
            if abs(frac - 0.5) < 0.01 { return whole + 0.5 + feel.swing / 6 }
            if abs(frac - 0.75) < 0.01 { return whole + 0.75 + feel.swing / 12 }   // 16ths inside a swung 8th
        } else {
            if abs(frac - 0.25) < 0.01 { return whole + 0.25 + feel.swing / 12 }
            if abs(frac - 0.75) < 0.01 { return whole + 0.75 + feel.swing / 12 }
        }
        return beat
    }

    func accent(_ posInBar: Double) -> Double {
        let frac = posInBar - posInBar.rounded(.down)
        if posInBar < 0.01 { return 1.08 }
        if frac < 0.01 {
            // Backbeat or beat 3 slightly stronger than weak beats.
            let beat = Int(posInBar.rounded())
            return beatsPerBar == 4 && beat == 2 ? 1.03 : 1.0
        }
        return abs(frac - 0.5) < 0.01 ? 0.95 : 0.9
    }

    public func apply(_ events: [NoteEvent], bar: Int, instrument: InstrumentProfile, rng: inout SeededRandom) -> [NoteEvent] {
        let barStart = Double(bar) * beatsPerBar
        return events.map { e in
            var n = e
            let pos = e.start - barStart
            // A slow swell that peaks in the middle of each 4-bar phrase.
            let phrase = (Double(bar % 4) + pos / beatsPerBar) / 4
            let phraseCurve = 1 + 0.07 * sin(.pi * phrase)

            // Timing.
            let onBeat = abs(pos - pos.rounded()) < 0.01
            let jitter = rng.gaussian() * feel.jitterMs * amount * (onBeat ? 0.6 : 1)
            let behind = feel.behindMs * min(amount, 1.5) * (instrument.isDrums && pos < 0.01 ? 0.5 : 1)
            n.start = barStart + swung(pos) + msToBeats(behind + jitter)
            n.start = max(n.start, barStart - msToBeats(15))

            // Velocity.
            var v = Double(e.velocity) / 127
            v *= accent(pos) * phraseCurve * (0.55 + feel.dynamics * 0.6) * instrument.velocityScale
            v += rng.gaussian() * feel.velocityVariance * amount * 0.5
            n.velocity = Int(min(max(v * 127, 8), Double(instrument.velocityCeiling)))

            // Length / articulation.
            if instrument.isDrums {
                n.duration = 0.12
            } else {
                var len = e.duration * instrument.lengthScale
                switch instrument.articulation {
                case .staccato: len = min(len, 0.45 * max(e.duration, 0.25) + 0.05)
                case .legato: len += msToBeats(40)
                case .sustain: len = max(len, e.duration)
                case .normal, .strum: len *= 0.94
                }
                len *= 1 + rng.gaussian() * 0.04 * amount
                n.duration = max(len, 0.06)
            }
            return n
        }
    }
}
