import Foundation

/// Deterministic, seedable RNG (SplitMix64). Every generated part is seeded from
/// stable inputs (track, bar, style) so the band plays the same thing each time a
/// bar comes around, until you ask it to vary.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public init(_ parts: Int...) {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for p in parts {
            h ^= UInt64(bitPattern: Int64(p))
            h = h &* 0x0000_0100_0000_01B3
        }
        self.init(seed: h)
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    public mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    public mutating func chance(_ p: Double) -> Bool {
        unit() < p
    }

    /// Standard normal sample (Box–Muller).
    public mutating func gaussian() -> Double {
        let u1 = max(unit(), 1e-12)
        let u2 = unit()
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }

    public mutating func pick<T>(_ items: [T]) -> T {
        items[Int(next() % UInt64(items.count))]
    }

    /// Picks an index with probability proportional to `weights`.
    public mutating func weightedIndex(_ weights: [Double]) -> Int {
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        var r = unit() * total
        for (i, w) in weights.enumerated() {
            r -= w
            if r < 0 { return i }
        }
        return weights.count - 1
    }
}

/// Stable string hash (Swift's `hashValue` is randomized per process).
public func stableHash(_ s: String) -> Int {
    var h: UInt64 = 0xCBF2_9CE4_8422_2325
    for b in s.utf8 {
        h ^= UInt64(b)
        h = h &* 0x0000_0100_0000_01B3
    }
    return Int(truncatingIfNeeded: h)
}
