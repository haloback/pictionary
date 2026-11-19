// Harmony primitives. Scale and chord dictionaries come from tonal
// (https://github.com/tonaljs/tonal); everything here is the glue that turns
// them into pitch-class sets the performance engine can snap notes onto.
import { ChordType, Interval, ScaleType } from "tonal";

export const NOTE_NAMES = ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"] as const;

export interface Chord {
  /** Root pitch class, 0-11. */
  root: number;
  /** Semitone offsets from the root, ascending, may exceed 12 for extensions. */
  intervals: number[];
  /** Pitch classes contained in the chord. */
  pcs: number[];
  /** Display symbol, e.g. "Dm9". */
  symbol: string;
  /** tonal chord type alias, e.g. "m9". */
  type: string;
}

const mod12 = (n: number) => ((n % 12) + 12) % 12;

const scaleCache = new Map<string, number[]>();

/** Semitone offsets of a named scale (tonal scale name). Falls back to major. */
export function scaleIntervals(name: string): number[] {
  const hit = scaleCache.get(name);
  if (hit) return hit;
  const st = ScaleType.get(name);
  const out = st.empty ? [0, 2, 4, 5, 7, 9, 11] : st.intervals.map((i) => mod12(Interval.semitones(i) ?? 0));
  scaleCache.set(name, out);
  return out;
}

export function scaleExists(name: string): boolean {
  return !ScaleType.get(name).empty;
}

const DEGREE_SEMIS = [0, 2, 4, 5, 7, 9, 11];
const chordCache = new Map<string, { offset: number; intervals: number[]; type: string } | null>();

/**
 * Parse a progression token. Format: [b|#]<degree 1-7><chord type>.
 * The degree is measured against the major scale of the key, so "b7" is the
 * flat seventh and "6m7" is the relative minor seventh. Chord type is any
 * tonal alias: "", m, 7, maj7, m9, sus4, 5, m7b5, 13 ...
 */
export function parseToken(token: string) {
  if (chordCache.has(token)) return chordCache.get(token)!;
  const m = /^([b#]?)([1-7])(.*)$/.exec(token);
  let res: { offset: number; intervals: number[]; type: string } | null = null;
  if (m) {
    const acc = m[1] === "b" ? -1 : m[1] === "#" ? 1 : 0;
    const type = m[3];
    const ct = ChordType.get(type === "" ? "M" : type);
    if (!ct.empty) {
      res = {
        offset: mod12(DEGREE_SEMIS[Number(m[2]) - 1] + acc),
        intervals: ct.intervals.map((i) => Interval.semitones(i) ?? 0),
        type,
      };
    }
  }
  chordCache.set(token, res);
  return res;
}

export function chordFromToken(token: string, keyRoot: number): Chord {
  const p = parseToken(token) ?? { offset: 0, intervals: [0, 4, 7], type: "" };
  const root = mod12(keyRoot + p.offset);
  return {
    root,
    intervals: p.intervals,
    pcs: [...new Set(p.intervals.map((i) => mod12(root + i)))],
    symbol: NOTE_NAMES[root] + p.type,
    type: p.type,
  };
}

export interface Pool {
  /** weight per pitch class: 0 = chord tone, 1 = scale tone, 2 = avoid note, -1 = not allowed */
  weight: Int8Array;
}

/**
 * Build the set of pitch classes a player may land on right now.
 * Chord tones are always in. Scale tones are in unless they sit a semitone
 * away from a chord tone that is foreign to the scale (a borrowed chord).
 * Scale tones a semitone above a chord tone are kept but flagged as avoid
 * notes, so they only appear as short passing tones.
 */
export function buildPool(keyRoot: number, scale: number[], chord: Chord): Pool {
  const weight = new Int8Array(12).fill(-1);
  const scalePcs = new Set(scale.map((s) => mod12(keyRoot + s)));
  const chordPcs = new Set(chord.pcs);
  for (const pc of scalePcs) weight[pc] = 1;
  for (const pc of chordPcs) {
    if (!scalePcs.has(pc)) {
      for (const d of [-1, 1]) {
        const n = mod12(pc + d);
        if (!chordPcs.has(n)) weight[n] = -1;
      }
    }
  }
  for (const pc of scalePcs) {
    if (weight[pc] === 1 && chordPcs.has(mod12(pc - 1)) && !chordPcs.has(pc)) weight[pc] = 2;
  }
  for (const pc of chordPcs) weight[pc] = 0;
  return { weight };
}

/** Nearest pitch to `target` whose pitch class is in `pcs`. Ties resolve downward. */
export function nearestWithPc(target: number, pcs: number[]): number {
  let best = target;
  let bestD = 99;
  for (const pc of pcs) {
    const base = target - mod12(target - pc);
    for (const cand of [base, base + 12]) {
      const d = Math.abs(cand - target);
      if (d < bestD) {
        bestD = d;
        best = cand;
      }
    }
  }
  return best;
}

/**
 * Voice a chord close to `center`, moving as little as possible from the
 * previous voicing so pads and stabs glide between chords instead of jumping.
 */
export function voiceChord(chord: Chord, center: number, voices: number, prev?: number[]): number[] {
  const ivs = chord.intervals.slice();
  // Drop the fifth first when there are more colours than voices.
  while (ivs.length > voices && ivs.length > 2) {
    const fifth = ivs.findIndex((i) => i % 12 === 7);
    if (fifth > 0 && ivs.length > 3) ivs.splice(fifth, 1);
    else ivs.splice(ivs.length > 3 ? 0 : ivs.length - 1, 1);
  }
  const pcs = [...new Set(ivs.map((i) => mod12(chord.root + i)))];
  let out: number[];
  if (prev && prev.length) {
    const used = new Set<number>();
    out = pcs.map((pc) => {
      let best = 0;
      let bestD = 99;
      for (const p of prev) {
        const cand = nearestWithPc(p, [pc]);
        const d = Math.abs(cand - p) + (used.has(cand) ? 20 : 0) + Math.abs(cand - center) * 0.08;
        if (d < bestD) {
          bestD = d;
          best = cand;
        }
      }
      used.add(best);
      return best;
    });
  } else {
    out = pcs.map((pc) => nearestWithPc(center, [pc]));
  }
  out = [...new Set(out)].sort((a, b) => a - b);
  // Pad out to the requested voice count by doubling at the octave.
  let i = 0;
  while (out.length < voices && i < 8) {
    const cand = out[i % out.length] + 12;
    if (!out.includes(cand)) out.push(cand);
    i++;
  }
  // Keep the voicing inside a sane window around the centre.
  out = out.map((n) => {
    while (n > center + 14) n -= 12;
    while (n < center - 14) n += 12;
    return n;
  });
  return [...new Set(out)].sort((a, b) => a - b);
}

export function pitchName(midi: number): string {
  return NOTE_NAMES[mod12(midi)] + (Math.floor(midi / 12) - 1);
}

export { mod12 };
