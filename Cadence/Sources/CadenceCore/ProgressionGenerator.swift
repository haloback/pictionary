import Foundation

public enum ProgressionGenerator {
    /// Writes a four-chord loop that suits the style, in the given key.
    public static func generate(style: Style, key: Key, seed: Int) -> Progression {
        var rng = SeededRandom(seed, stableHash(style.id), key.tonic, stableHash(key.scale.rawValue))
        let templates = style.harmony.templates
        let template = templates[rng.weightedIndex(templates.indices.map { $0 == 0 ? 2.0 : 1.0 })]
        let wantsSevenths = style.harmony.colorLevel >= 1
        var chords: [Chord] = template.map { key.diatonicChord(degree: $0, seventh: wantsSevenths) }

        if style.harmony.allDominant {
            chords = chords.map { Chord(root: $0.root, quality: .dominant7) }
        }
        chords = chords.map { $0.colored(level: style.harmony.colorLevel, rng: &rng) }

        // A secondary dominant leading into the next chord now and then.
        if style.harmony.colorLevel >= 2, chords.count == 4, !style.harmony.allDominant,
           chords[2].root != chords[3].root, rng.chance(0.2) {
            chords[2] = Chord(root: chords[3].root + 7, quality: style.harmony.colorLevel >= 3 ? .dominant13 : .dominant7)
        }

        // Folk/pop styles occasionally borrow a sus chord for motion.
        if style.harmony.colorLevel == 0, rng.chance(0.25), let idx = chords.indices.last,
           !chords[idx].quality.isMinor {
            chords[idx] = Chord(root: chords[idx].root, quality: .sus4)
        }

        let beatsEach = style.harmony.beatsPerChord ?? Double(style.beatsPerBar)
        return Progression(chords: chords, beatsEach: beatsEach)
    }

    /// A key that suits the style: its preferred scale on a friendly tonic.
    public static func suggestedKey(for style: Style, seed: Int) -> Key {
        var rng = SeededRandom(seed, stableHash(style.id))
        let friendly: [Int]
        switch style.family {
        case "Rock", "Folk & Country", "Blues": friendly = [7, 2, 9, 4, 0]           // guitar keys
        case "Jazz", "Gospel", "Soul & R&B": friendly = [5, 10, 3, 8, 1, 0]        // flat keys
        default: friendly = [0, 2, 5, 7, 9, 10, 3]
        }
        return Key(tonic: rng.pick(friendly), scale: style.scale)
    }
}
