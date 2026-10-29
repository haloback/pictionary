import Foundation

/// What a single hit in a pattern plays. Pitches are resolved later against
/// whatever chord is sounding at that moment.
public enum HitTarget: Hashable, Codable, Sendable {
    case chord            // the whole voicing
    case upper            // voicing minus its lowest note
    case low              // lowest note of the voicing
    case arp(Int)         // n-th note of the voicing (0-based, wraps up an octave)
    case root, fifth, octave, third, approach, walk
    case drum(Drum)
}

public struct Hit: Hashable, Codable, Sendable {
    /// Position in beats from the start of the bar.
    public var pos: Double
    public var len: Double
    /// 0...1
    public var vel: Double
    public var target: HitTarget
    /// Ghost notes are the first to go when density is turned down.
    public var ghost: Bool
}

public struct Pattern: Sendable {
    public var hits: [Hit]
}

/// Parses one-bar step grids. Characters:
/// `X` accent, `x` normal, `o` soft, `g` ghost, `-` hold previous, `.` rest,
/// digits are arpeggio steps (1-based), and in bass lines `R`/`r` root,
/// `F` fifth, `O` octave, `T` third, `A` approach note, `W` walking note.
enum Grid {
    static func parse(_ grid: String, beats: Double, target: HitTarget?) -> [Hit] {
        let chars = Array(grid.replacingOccurrences(of: " ", with: ""))
        guard !chars.isEmpty else { return [] }
        let step = beats / Double(chars.count)
        var hits: [Hit] = []
        for (i, c) in chars.enumerated() {
            if c == "-" {
                if !hits.isEmpty { hits[hits.count - 1].len += step }
                continue
            }
            if c == "." { continue }
            var vel = 0.78
            var ghost = false
            var t = target ?? .chord
            switch c {
            case "X": vel = 1.0
            case "x": vel = 0.78
            case "o": vel = 0.58
            case "g": vel = 0.34; ghost = true
            case "R": t = .root; vel = 0.92
            case "r": t = .root; vel = 0.45; ghost = true
            case "F": t = .fifth; vel = 0.76
            case "O": t = .octave; vel = 0.74
            case "T": t = .third; vel = 0.72
            case "A": t = .approach; vel = 0.7
            case "W": t = .walk; vel = 0.82
            default:
                if let d = c.wholeNumberValue, d > 0 {
                    t = .arp(d - 1)
                    vel = 0.72
                } else {
                    continue
                }
            }
            hits.append(Hit(pos: Double(i) * step, len: step, vel: vel, target: t, ghost: ghost))
        }
        return hits
    }

    static func lines(_ lines: [(HitTarget?, String)], beats: Double) -> Pattern {
        Pattern(hits: lines.flatMap { parse($0.1, beats: beats, target: $0.0) }.sorted { $0.pos < $1.pos })
    }
}

public enum DrumGroove: String, CaseIterable, Codable, Sendable {
    case none, pop, rock, fourOnFloor, disco, halfTime, boomBap, trap, lofi, jazzSwing, brushes
    case bossa, samba, oneDrop, afrobeats, amapiano, highlife, gospel, funk, motown, neoSoul
    case dnb, reggaeton, salsa, country, cinematic, ambientPulse, march, shuffle, sixEight, waltz

    func pattern(beats: Double) -> Pattern {
        let k: HitTarget = .drum(.kick), s: HitTarget = .drum(.snare), h: HitTarget = .drum(.closedHat)
        let oh: HitTarget = .drum(.openHat), cl: HitTarget = .drum(.clap), sh: HitTarget = .drum(.shaker)
        let ss: HitTarget = .drum(.sideStick), ride: HitTarget = .drum(.ride), ph: HitTarget = .drum(.pedalHat)
        let tam: HitTarget = .drum(.tambourine)
        let l: [(HitTarget?, String)]
        switch self {
        case .none: l = []
        case .pop: l = [(k, "X.....x.X......."), (s, "....X.......X..."), (h, "x.o.x.o.x.o.x.o.")]
        case .rock: l = [(k, "X.......X.X....."), (s, "....X.......X..."), (h, "x.x.x.x.x.x.x.x.")]
        case .fourOnFloor: l = [(k, "X...X...X...X..."), (cl, "....X.......X..."), (oh, "..o...o...o...o."), (sh, "gggggggggggggggg")]
        case .disco: l = [(k, "X...X...X...X..."), (s, "....X.......X..."), (oh, "..o...o...o...o."), (h, "x.g.x.g.x.g.x.g.")]
        case .halfTime: l = [(k, "X......x..X....."), (s, "........X......."), (h, "x.x.x.x.x.x.x.x.")]
        case .boomBap: l = [(k, "X......x.xX....."), (s, "....X.......X..g"), (h, "x.x.x.x.x.x.x.x.")]
        case .trap: l = [(k, "X......x...x...."), (s, "........X......."), (h, "xgxgxgxgxgxgxxxx")]
        case .lofi: l = [(k, "X......x..X....."), (s, "....o.......o..."), (h, "o.g.o.g.o.g.o.g.")]
        case .jazzSwing: l = [(ride, "X...x.o.X...x.o."), (ph, "....x.......x..."), (k, "g...g...g...g..."), (s, "......g.......g.")]
        case .brushes: l = [(s, "o.g.o.g.o.g.o.g."), (ph, "....x.......x..."), (k, "g.......g.......")]
        case .bossa: l = [(ss, "x..x..x...x..x.."), (k, "o..go..go..go..g"), (h, "g.g.g.g.g.g.g.g.")]
        case .samba: l = [(k, "o..xo..xo..xo..x"), (sh, "xgxgxgxgxgxgxgxg"), (ss, "x.x..x.x.x..x.x.")]
        case .oneDrop: l = [(k, "........X......."), (ss, "........X......."), (h, "x.x.x.x.x.x.x.x.")]
        case .afrobeats: l = [(k, "X.....x.X.....x."), (ss, "...x..x....x..x."), (sh, "xgxgxgxgxgxgxgxg"), (.drum(.highConga), "..o...o...o.o..o")]
        case .amapiano: l = [(k, "X...X...X...X..."), (cl, "....x.......x..."), (sh, "xgxgxgxgxgxgxgxg"), (ss, "..x..x....x..x..")]
        case .highlife: l = [(.drum(.cowbell), "x.x.xx.x.x.xx.x."), (k, "X.......X......."), (s, "....o.......o..."), (sh, "xgxgxgxgxgxgxgxg")]
        case .gospel: l = [(k, "X.....x.X.....x."), (s, "....X.......X..."), (h, "x.x.x.x.x.x.x.x."), (tam, "....x.......x...")]
        case .funk: l = [(k, "X..x..x...X..x.."), (s, "....X..g.g..X..g"), (h, "xgxgxgxgxgxgxgxg")]
        case .motown: l = [(k, "X...X...X...X..."), (s, "....X.......X..."), (tam, "....X.......X..."), (h, "x.x.x.x.x.x.x.x.")]
        case .neoSoul: l = [(k, "X......xx.X....."), (s, "....X.......X..."), (h, "x.gx.gx.x.gx.gx.")]
        case .dnb: l = [(k, "X.........X....."), (s, "....X.......X..."), (h, "x.x.x.x.x.x.x.x.")]
        case .reggaeton: l = [(k, "X...X...X...X..."), (s, "...x..x....x..x."), (h, "x.x.x.x.x.x.x.x.")]
        case .salsa: l = [(.drum(.clave), "x..x...x..x.x..."), (.drum(.lowConga), "......x.......x."), (.drum(.highConga), "..g...g...g...g."), (.drum(.cowbell), "x...x...x...x...")]
        case .country: l = [(k, "X.......X......."), (s, "gxgxXxgxgxgxXxgx"), (h, "x.x.x.x.x.x.x.x.")]
        case .cinematic: l = [(.drum(.lowTom), "X.......o...o.o."), (k, "X.......X......."), (.drum(.midTom), "............g.g.")]
        case .ambientPulse: l = [(k, "o.......o......."), (sh, "g.g.g.g.g.g.g.g.")]
        case .march: l = [(s, "X.xxX.x.X.xxX.x."), (k, "X...X...X...X...")]
        case .shuffle: l = [(h, "X.xX.xX.xX.x"), (k, "X.....X....."), (s, "...X.....X..")]
        case .sixEight: l = [(h, "xggxggxggxgg"), (k, "X.....o....."), (s, "......X.....")]
        case .waltz: l = [(k, "X..........."), (h, "....x...x..."), (s, "....g...g...")]
        }
        return Grid.lines(l, beats: beats)
    }

    /// One-bar fill played at the end of a phrase.
    func fill(beats: Double) -> Pattern {
        switch self {
        case .none, .ambientPulse: return Pattern(hits: [])
        case .jazzSwing, .brushes:
            return Grid.lines([(.drum(.snare), "........g.o.x.o."), (.drum(.ride), "X...x.o.X......."), (.drum(.kick), "............o...")], beats: beats)
        case .fourOnFloor, .disco, .amapiano:
            return Grid.lines([(.drum(.kick), "X...X...X...X..."), (.drum(.clap), "....X.......xxxx"), (.drum(.openHat), "..o...o...o.....")], beats: beats)
        case .trap:
            return Grid.lines([(.drum(.kick), "X......x...x...."), (.drum(.snare), "........X...gxgx"), (.drum(.closedHat), "xxxxxxxxxxxxxxxx")], beats: beats)
        default:
            if beats < 4 { return pattern(beats: beats) }
            return Grid.lines([(.drum(.kick), "X.......X......."), (.drum(.snare), "....X...o.ox.xox"), (.drum(.highTom), "........x......."), (.drum(.midTom), "..........x....."), (.drum(.lowTom), "............x.x.")], beats: beats)
        }
    }
}

public enum CompStyle: String, CaseIterable, Codable, Sendable {
    case sustained, halfNotes, quarterPulse, eighthPulse, pushedEighths, offbeatSkank
    case neoSoulComp, gospelStabs, charleston, bossaComp, montuno
    case arpUp, arpRolling, alberti, balladArp, strum8, strum16, travisPick, highlifePick
    case houseStabs, lofiLazy, funkChops, stride, reggaetonStabs, amapianoChords, hornStabs
    case waltzComp, twelveEightArp

    func pattern(beats: Double) -> Pattern {
        let l: [(HitTarget?, String)]
        switch self {
        case .sustained: l = [(.chord, "X---------------")]
        case .halfNotes: l = [(.chord, "X-------x-------")]
        case .quarterPulse: l = [(.chord, "X--.x--.x--.x--.")]
        case .eighthPulse: l = [(.chord, "X-o-x-o-x-o-x-o-")]
        case .pushedEighths: l = [(.chord, "X-----x---x---x-")]
        case .offbeatSkank: l = [(.upper, "..x...x...x...x.")]
        case .neoSoulComp: l = [(.chord, "X-----g..x--..g."), (.low, "..........o.....")]
        case .gospelStabs: l = [(.chord, "X-----.xX-.x..x-")]
        case .charleston: l = [(.chord, "X--..x--........")]
        case .bossaComp: l = [(.upper, "x-.x-.x-..x-.x-."), (.low, "X.......X.......")]
        case .montuno: l = [(nil, "1.3.24.3.1.3.24.")]
        case .arpUp: l = [(nil, "1-2-3-4-5-4-3-2-")]
        case .arpRolling: l = [(nil, "1234543212345432")]
        case .alberti: l = [(nil, "1-3-2-3-1-3-2-3-")]
        case .balladArp: l = [(.low, "X-------x-------"), (nil, "..3-4-5-..3-4-5-")]
        case .strum8: l = [(.chord, "X---x-o---o-x-o-")]
        case .strum16: l = [(.chord, "X-oxx-oxX-oxx-ox")]
        case .travisPick: l = [(nil, "1-4-2-5-1-4-2-5-")]
        case .highlifePick: l = [(nil, "4.5.3.4.5.4.3.5.")]
        case .houseStabs: l = [(.upper, "..X...x...x..x.x")]
        case .lofiLazy: l = [(.chord, "X-------.x------")]
        case .funkChops: l = [(.upper, "..x.x..gx.x..x.g")]
        case .stride: l = [(.low, "X-------X-------"), (.upper, "....x-------x---")]
        case .reggaetonStabs: l = [(.upper, "X..x..x.X..x..x.")]
        case .amapianoChords: l = [(.chord, "X-----x-..x---x-")]
        case .hornStabs: l = [(.upper, "....X.......x.x.")]
        case .waltzComp: l = [(.low, "X-----------"), (.upper, "....x-..x-..")]
        case .twelveEightArp: l = [(nil, "123432123432")]
        }
        return Grid.lines(l, beats: beats)
    }
}

public enum BassStyle: String, CaseIterable, Codable, Sendable {
    case none, wholeRoot, rootFifth, rockEighths, pop, walking, bossa, octaves, oneDrop, afro
    case slide808, tumbao, funk, motown, dnbSub, reggaeton, gospel, logDrum, waltz, twelveEight

    func pattern(beats: Double) -> Pattern {
        let g: String
        switch self {
        case .none: g = ""
        case .wholeRoot: g = "R---------------"
        case .rootFifth: g = "R-------F-------"
        case .rockEighths: g = "R-R-R-R-R-R-R-R-"
        case .pop: g = "R-----R-R-----A-"
        case .walking: g = "W---W---W---W---"
        case .bossa: g = "R-----F-R-----F-"
        case .octaves: g = "R-O-R-O-R-O-R-O-"
        case .oneDrop: g = "R-----..R-F-..A-"
        case .afro: g = "R-----R---F---r-"
        case .slide808: g = "R---------R-----"
        case .tumbao: g = "......R-....F---"
        case .funk: g = "R.rR..R.R.rF.R.O"
        case .motown: g = "R-.RF-.RR-.RO-.A"
        case .dnbSub: g = "R---------R-----"
        case .reggaeton: g = "R--R..R.R--R..R."
        case .gospel: g = "R---.RF-R---TFA-"
        case .logDrum: g = "..R...R-..R.R..."
        case .waltz: g = "R-------F---"
        case .twelveEight: g = "R-----F-----"
        }
        return Pattern(hits: Grid.parse(g, beats: beats, target: nil))
    }
}

/// Melodic parts (violin, flute, sax…) and pads.
public enum LineStyle: String, CaseIterable, Codable, Sendable {
    /// Sings the top voice of each chord, legato, with passing tones.
    case topVoice
    /// Answers between chord changes with short scale runs.
    case counterMelody
    /// Holds the chord, swelling in.
    case pad
    /// Long root-and-fifth drones (ambient, cinematic).
    case drone
}
