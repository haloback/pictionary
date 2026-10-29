import Foundation

/// How chord tones are stacked on the keyboard. Genres pick a style; the engine
/// then voice-leads from chord to chord so the hands barely move.
public enum VoicingStyle: String, CaseIterable, Codable, Sendable {
    /// Plain triads in any inversion (pop, folk, rock).
    case triad
    /// Four notes within an octave (gospel, soul, pop ballads).
    case close
    /// Close voicing with the second voice from the top dropped an octave.
    case drop2
    /// Jazz piano "A/B" voicings: no root, 3rd and 7th with 9th/13th.
    case rootless
    /// Root, 3rd and 7th only (big band, bebop, blues).
    case shell
    /// Stacked fourths (modal jazz, neo-soul, cinematic).
    case quartal
    /// Wide, open spacing with the root in the bass (ballads, cinematic).
    case spread
    /// Six-string barre/open shapes (guitar parts).
    case guitar

    public var displayName: String {
        switch self {
        case .triad: return "Triad"
        case .close: return "Close"
        case .drop2: return "Drop-2"
        case .rootless: return "Rootless"
        case .shell: return "Shell"
        case .quartal: return "Quartal"
        case .spread: return "Spread"
        case .guitar: return "Guitar shape"
        }
    }
}

public enum VoicingEngine {
    /// Voices every chord of a loop, voice-leading around the loop twice so the
    /// last chord leads smoothly back into the first.
    public static func voiceLoop(_ chords: [Chord], style: VoicingStyle, range: ClosedRange<Int>) -> [[Int]] {
        guard !chords.isEmpty else { return [] }
        var result = [[Int]](repeating: [], count: chords.count)
        var previous: [Int]?
        for pass in 0..<2 {
            for (i, chord) in chords.enumerated() {
                let v = voice(chord, style: style, range: range, previous: previous)
                if pass == 1 || result[i].isEmpty { result[i] = v }
                previous = v
            }
        }
        return result
    }

    public static func voice(_ chord: Chord, style: VoicingStyle, range: ClosedRange<Int>, previous: [Int]?) -> [Int] {
        let cands = candidates(for: chord, style: style, range: range)
        guard !cands.isEmpty else {
            // Fallback: a close triad near the middle of the range.
            let mid = (range.lowerBound + range.upperBound) / 2
            let root = mid - mod12(mid - chord.root)
            return [root, root + (chord.quality.isMinor ? 3 : 4), root + 7]
        }
        let center = Double(range.lowerBound + range.upperBound) / 2
        var best = cands[0]
        var bestCost = Double.infinity
        for c in cands {
            let cost = Self.cost(c, previous: previous, center: center)
            if cost < bestCost {
                bestCost = cost
                best = c
            }
        }
        return best
    }

    static func cost(_ v: [Int], previous: [Int]?, center: Double) -> Double {
        let centroid = Double(v.reduce(0, +)) / Double(v.count)
        var cost = abs(centroid - center) * (previous == nil ? 0.6 : 0.25)
        // Low, tight intervals sound muddy.
        for i in 1..<max(v.count, 1) where i < v.count {
            let interval = v[i] - v[i - 1]
            if v[i - 1] < 52 && interval <= 3 { cost += 6 }
            if v[i - 1] < 45 && interval < 7 { cost += 6 }
        }
        if let p = previous, !p.isEmpty {
            for n in v { cost += Double(p.map { abs($0 - n) }.min() ?? 0) }
            for n in p { cost += Double(v.map { abs($0 - n) }.min() ?? 0) * 0.5 }
            // Keep the top voice singing smoothly.
            cost += Double(abs((v.last ?? 0) - (p.last ?? 0))) * 0.6
        }
        return cost
    }

    /// Ordered pitch classes (bottom to top) for styles that may be inverted.
    static func rotatableTones(_ chord: Chord, style: VoicingStyle) -> [[Int]] {
        let r = chord.root
        let third = chord.third ?? mod12(r + 4)
        let fifth = chord.fifth ?? mod12(r + 7)
        let seventh = chord.seventh
        let exts = chord.extensionIntervals.map { mod12(r + $0) }
        let ninth = chord.extensionIntervals.first { $0 == 13 || $0 == 14 || $0 == 15 }.map { mod12(r + $0) }
        let upper = chord.extensionIntervals.first { $0 == 17 || $0 == 18 || $0 == 20 || $0 == 21 }.map { mod12(r + $0) }

        switch style {
        case .triad:
            if chord.quality == .power { return [[r, fifth]] }
            return [[r, third, fifth]]
        case .close, .drop2:
            var tones: [Int]
            if let s = seventh {
                tones = [r, third, fifth, s]
                if let n = ninth { tones[0] = n }          // 9th replaces the root
                if let u = upper { tones[2] = u }          // 11th/13th replaces the 5th
            } else if chord.quality == .major6 || chord.quality == .minor6 {
                tones = [r, third, fifth, mod12(r + 9)]
            } else if let n = exts.first {
                tones = [r, third, fifth, n]
            } else {
                tones = [r, third, fifth, r]
            }
            return [tones]
        case .rootless:
            let s = seventh ?? mod12(r + (chord.quality.isMinor ? 10 : 11))
            let color = ninth ?? mod12(r + 2)
            let fiveOr13 = upper ?? fifth
            return [[third, fiveOr13, s, color], [s, color, third, fiveOr13]]
        case .quartal:
            // Stack fourths from the 3rd (or root), bending each to the nearest
            // chord tone or 9th so it still spells the chord.
            let allowed = Set(chord.pitchClasses).union([mod12(r + 2)])
            var out: [[Int]] = []
            for start in [third, seventh ?? fifth] {
                var stack = [start]
                var cur = start
                for _ in 0..<3 {
                    cur = mod12(cur + 5)
                    let snapped = [0, 1, -1, 2, -2].map { mod12(cur + $0) }.first { allowed.contains($0) } ?? cur
                    stack.append(snapped)
                    cur = snapped
                }
                out.append(stack)
            }
            return out
        default:
            return []
        }
    }

    /// Absolute interval templates (root at the bottom, not inverted).
    static func fixedTemplates(_ chord: Chord, style: VoicingStyle) -> [[Int]] {
        let r = chord.root
        let thirdI = chord.third.map { mod12($0 - r) } ?? 4
        let fifthI = chord.fifth.map { mod12($0 - r) } ?? 7
        let sevI = chord.seventh.map { mod12($0 - r) }
        let ext = chord.extensionIntervals.first
        switch style {
        case .shell:
            if let s = sevI { return [[0, s, thirdI + 12], [0, thirdI, s]] }
            return [[0, fifthI, thirdI + 12]]
        case .spread:
            var t = [0, fifthI, thirdI + 12]
            if let s = sevI { t.append(s + 12) } else { t.append(fifthI + 12) }
            if let e = ext { t.append(e + 12 > t.last! ? e + 12 : e + 24) }
            return [t]
        case .guitar:
            if chord.quality == .power { return [[0, 7, 12], [0, 7, 12, 19]] }
            // E-shape (root on low E) and A-shape (root on A) barre chords.
            var eShape = [0, fifthI, 12, thirdI + 12, fifthI + 12, 24]
            var aShape = [0, fifthI, 12, thirdI + 12, fifthI + 12]
            if let s = sevI {
                eShape[2] = s
                aShape[2] = s
            }
            if let e = ext, e == 14 { aShape[4] = 14 }
            return [eShape, aShape]
        default:
            return []
        }
    }

    public static func candidates(for chord: Chord, style: VoicingStyle, range: ClosedRange<Int>) -> [[Int]] {
        var out: [[Int]] = []
        let fixed = fixedTemplates(chord, style: style)
        if !fixed.isEmpty {
            for t in fixed {
                var root = range.lowerBound + mod12(chord.root - range.lowerBound)
                while root + (t.last ?? 0) <= range.upperBound {
                    out.append(t.map { root + $0 })
                    root += 12
                }
            }
            if style == .guitar {
                // Guitar shapes: the root must sit on the low strings.
                out = out.filter { $0[0] <= 57 }
            }
            return out
        }
        for tones in rotatableTones(chord, style: style) {
            for rot in 0..<tones.count {
                let ordered = Array(tones[rot...] + tones[..<rot])
                for start in range.lowerBound...(range.lowerBound + 11) {
                    guard mod12(start) == ordered[0] else { continue }
                    var notes = [start]
                    for pc in ordered.dropFirst() {
                        var n = notes.last! + 1
                        while mod12(n) != pc { n += 1 }
                        notes.append(n)
                    }
                    if style == .drop2, notes.count >= 4 {
                        let dropped = notes.remove(at: notes.count - 2) - 12
                        notes.insert(dropped, at: 0)
                    }
                    // Try this shape in every octave that fits.
                    var shift = 0
                    while notes.last! + shift <= range.upperBound {
                        if notes.first! + shift >= range.lowerBound {
                            out.append(notes.map { $0 + shift })
                        }
                        shift += 12
                    }
                }
            }
        }
        return out
    }
}
