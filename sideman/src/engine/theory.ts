import type { Chord, ChordSpan, Key } from './types';

const LETTER_PC: Record<string, number> = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
const SHARP_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const FLAT_NAMES = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

export const mod12 = (n: number) => ((n % 12) + 12) % 12;
export const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));
export const lerp = (a: number, b: number, x: number) => a + (b - a) * x;

export function pcName(pc: number, flats = true): string {
  return (flats ? FLAT_NAMES : SHARP_NAMES)[mod12(pc)];
}
export function noteName(midi: number, flats = true): string {
  return pcName(midi, flats) + (Math.floor(midi / 12) - 1);
}
export function keyName(k: Key): string {
  const flats = keyPrefersFlats(k);
  return pcName(k.tonic, flats) + (k.minor ? ' minor' : ' major');
}
export function keyPrefersFlats(k: Key): boolean {
  const majorTonic = k.minor ? mod12(k.tonic + 3) : k.tonic;
  return [0, 5, 10, 3, 8, 1, 6].includes(majorTonic);
}

function parseNote(s: string): number | null {
  const m = /^([A-Ga-g])([#b]?)$/.exec(s);
  if (!m) return null;
  let pc = LETTER_PC[m[1].toUpperCase()];
  if (m[2] === '#') pc += 1;
  if (m[2] === 'b') pc -= 1;
  return mod12(pc);
}

export const NO_CHORD: Chord = {
  sym: 'N.C.',
  root: 0,
  bass: 0,
  third: null,
  fifth: null,
  seventh: null,
  sixth: false,
  sus: null,
  tensions: [],
  quality: 'power',
  nc: true,
};

/** Parse a chord symbol such as "Bbmaj9", "F#m7b5", "G13", "C/E", "D7#9", "Asus4". */
export function parseChord(input: string): Chord | null {
  let sym = input.trim().replace(/♯/g, '#').replace(/♭/g, 'b').replace(/Δ/g, 'maj7').replace(/°/g, 'dim').replace(/ø/g, 'm7b5').replace('6/9', '69');
  if (!sym) return null;
  if (/^(n\.?c\.?|nc)$/i.test(sym)) return { ...NO_CHORD };
  const m = /^([A-G][#b]?)([^/]*)(?:\/([A-G][#b]?))?$/.exec(sym);
  if (!m) return null;
  const root = parseNote(m[1])!;
  const bass = m[3] ? parseNote(m[3])! : root;
  let s = m[2];

  let third: 3 | 4 | null = 4;
  let fifth: 6 | 7 | 8 | null = 7;
  let seventh: 9 | 10 | 11 | null = null;
  let sixth = false;
  let sus: 2 | 5 | null = null;
  const tens = new Set<number>();
  let majFlag = false;
  let dim = false;
  let power = false;

  const eat = (re: RegExp): string | null => {
    const mm = re.exec(s);
    if (!mm) return null;
    s = s.slice(mm[0].length);
    return mm[0];
  };

  if (eat(/^(maj|Maj|MAJ|ma(?!j)|M(?!i))/)) majFlag = true;
  else if (eat(/^(min|mi(?!n)|m|-)/)) {
    third = 3;
    if (eat(/^(maj|Maj|M)/)) majFlag = true;
  } else if (eat(/^(dim|o)/)) {
    third = 3;
    fifth = 6;
    dim = true;
  } else if (eat(/^(aug|\+)/)) fifth = 8;

  const num = eat(/^(69|6\/9|13|11|9|7|6|5|2|4)/);
  const sev = (): 9 | 10 | 11 => (dim ? 9 : majFlag ? 11 : 10);
  switch (num) {
    case '7':
      seventh = sev();
      break;
    case '9':
      seventh = sev();
      tens.add(2);
      break;
    case '11':
      seventh = sev();
      tens.add(2);
      if (third === 4) {
        third = null;
        sus = 5;
      } else tens.add(5);
      break;
    case '13':
      seventh = sev();
      tens.add(2);
      tens.add(9);
      break;
    case '6':
      sixth = true;
      break;
    case '69':
    case '6/9':
      sixth = true;
      tens.add(2);
      break;
    case '5':
      third = null;
      power = true;
      break;
    case '2':
      tens.add(2);
      break;
    case '4':
      third = null;
      sus = 5;
      break;
  }

  let guard = 0;
  while (s.length && guard++ < 12) {
    if (eat(/^[(),\s]/)) continue;
    if (eat(/^sus2/)) {
      third = null;
      sus = 2;
    } else if (eat(/^sus4?/)) {
      third = null;
      sus = 5;
    } else if (eat(/^add(9|2)/)) tens.add(2);
    else if (eat(/^add(11|4)/)) tens.add(5);
    else if (eat(/^add(13|6)/)) tens.add(9);
    else if (eat(/^(b5|-5)/)) fifth = 6;
    else if (eat(/^(#5|\+5|\+)/)) fifth = 8;
    else if (eat(/^b9/)) tens.add(1);
    else if (eat(/^#9/)) tens.add(3);
    else if (eat(/^#11/)) tens.add(6);
    else if (eat(/^b13/)) tens.add(8);
    else if (eat(/^alt/)) {
      if (seventh == null) seventh = 10;
      tens.add(1);
      tens.add(3);
      tens.add(8);
      fifth = null;
    } else if (eat(/^(maj7|M7)/)) seventh = 11;
    else if (eat(/^13/)) tens.add(9);
    else if (eat(/^11/)) tens.add(5);
    else if (eat(/^9/)) tens.add(2);
    else if (eat(/^7/)) seventh = 10;
    else return null;
  }
  if (s.length) return null;

  let quality: Chord['quality'];
  if (power) quality = 'power';
  else if (sus) quality = 'sus';
  else if (third === 3 && fifth === 6 && seventh === 10) quality = 'hdim';
  else if (third === 3 && fifth === 6) quality = 'dim';
  else if (third === 3) quality = 'min';
  else if (seventh === 10) quality = 'dom';
  else if (fifth === 8 && seventh == null) quality = 'aug';
  else quality = 'maj';

  return { sym, root, bass, third, fifth, seventh, sixth, sus, tensions: [...tens].sort((a, b) => a - b), quality };
}

/** Intervals above the root, ascending, in "function order". */
export function chordIntervals(c: Chord): number[] {
  if (c.nc) return [];
  const out: number[] = [0];
  if (c.third != null) out.push(c.third);
  if (c.sus != null) out.push(c.sus);
  if (c.fifth != null) out.push(c.fifth);
  if (c.sixth) out.push(9);
  if (c.seventh != null) out.push(c.seventh);
  for (const t of c.tensions) if (!out.includes(t)) out.push(t);
  return out;
}
export function chordPcs(c: Chord): number[] {
  return chordIntervals(c).map((i) => mod12(c.root + i));
}

export type Role = 'R' | '3' | '5' | '6' | '7' | '9';
/** Interval above the root for a functional role, with sensible fallbacks. */
export function roleInterval(c: Chord, role: Role): number {
  switch (role) {
    case 'R':
      return 0;
    case '3':
      return c.third ?? c.sus ?? 7;
    case '5':
      return c.fifth ?? 6;
    case '6':
      return c.fifth === 6 ? 8 : 9;
    case '7':
      if (c.seventh != null) return c.seventh;
      if (c.sixth) return 9;
      return c.third === 3 ? 10 : c.quality === 'power' || c.quality === 'sus' ? 10 : 9;
    case '9':
      if (c.tensions.includes(1)) return 1;
      if (c.tensions.includes(3) && !c.tensions.includes(2)) return 3;
      return 2;
  }
}

const SCALES: Record<string, number[]> = {
  ionian: [0, 2, 4, 5, 7, 9, 11],
  lydian: [0, 2, 4, 6, 7, 9, 11],
  mixo: [0, 2, 4, 5, 7, 9, 10],
  lydDom: [0, 2, 4, 6, 7, 9, 10],
  mixoB13: [0, 2, 4, 5, 7, 8, 10],
  phrygDom: [0, 1, 4, 5, 7, 8, 10],
  altered: [0, 1, 3, 4, 6, 8, 10],
  hwDim: [0, 1, 3, 4, 6, 7, 9, 10],
  dorian: [0, 2, 3, 5, 7, 9, 10],
  aeolian: [0, 2, 3, 5, 7, 8, 10],
  phrygian: [0, 1, 3, 5, 7, 8, 10],
  melMin: [0, 2, 3, 5, 7, 9, 11],
  harmMin: [0, 2, 3, 5, 7, 8, 11],
  locrian: [0, 1, 3, 5, 6, 8, 10],
  locrian2: [0, 2, 3, 5, 6, 8, 10],
  whDim: [0, 2, 3, 5, 6, 8, 9, 11],
  whole: [0, 2, 4, 6, 8, 10],
  lydAug: [0, 2, 4, 6, 8, 9, 11],
};
const CANDIDATES: Record<Chord['quality'], string[]> = {
  maj: ['ionian', 'lydian', 'mixo'],
  dom: ['mixo', 'lydDom', 'mixoB13', 'phrygDom', 'altered', 'hwDim'],
  min: ['dorian', 'aeolian', 'phrygian', 'melMin', 'harmMin'],
  hdim: ['locrian', 'locrian2'],
  dim: ['whDim'],
  aug: ['lydAug', 'whole'],
  sus: ['mixo', 'ionian', 'dorian'],
  power: ['mixo', 'dorian', 'aeolian', 'ionian'],
};

export function keyScalePcs(k: Key): number[] {
  const iv = k.minor ? [0, 2, 3, 5, 7, 8, 10] : [0, 2, 4, 5, 7, 9, 11];
  return iv.map((i) => mod12(k.tonic + i));
}

const scaleCache = new Map<string, number[]>();
/** Chord scale as intervals above the chord root, chosen to fit both chord and key. */
export function scaleFor(c: Chord, k: Key): number[] {
  if (c.nc) return SCALES.ionian;
  const ck = `${c.sym}|${k.tonic}|${k.minor}`;
  const hit = scaleCache.get(ck);
  if (hit) return hit;
  const need = chordIntervals(c).map(mod12);
  const keyPcs = new Set(keyScalePcs(k));
  let best = SCALES[CANDIDATES[c.quality][0]];
  let bestScore = -1;
  for (const name of CANDIDATES[c.quality]) {
    const sc = SCALES[name];
    const fits = need.filter((n) => sc.includes(n)).length;
    const overlap = sc.filter((i) => keyPcs.has(mod12(c.root + i))).length / sc.length;
    const score = fits * 10 + overlap * 7;
    if (score > bestScore + 1e-9) {
      bestScore = score;
      best = sc;
    }
  }
  scaleCache.set(ck, best);
  return best;
}
export function scalePcsFor(c: Chord, k: Key): number[] {
  return scaleFor(c, k).map((i) => mod12(c.root + i));
}

/** Pentatonic flavour for riffs: major pent on major/dominant chords, minor pent otherwise. */
export function pentFor(c: Chord): number[] {
  if (c.third === 4 || (c.third == null && c.seventh !== 10 && c.quality !== 'power')) return [0, 2, 4, 7, 9];
  return [0, 3, 5, 7, 10];
}

/** Guess the key from a list of chord spans. */
export function detectKey(spans: ChordSpan[]): Key {
  const real = spans.filter((s) => !s.chord.nc);
  if (!real.length) return { tonic: 0, minor: false };
  let best: Key = { tonic: 0, minor: false };
  let bestScore = -Infinity;
  const total = real.reduce((a, s) => a + s.d, 0);
  for (let tonic = 0; tonic < 12; tonic++) {
    for (const minor of [false, true]) {
      const scale = new Set(keyScalePcs({ tonic, minor }));
      const leading = mod12(tonic + 11);
      let score = 0;
      real.forEach((s, i) => {
        const pcs = chordPcs(s.chord);
        // a minor key borrows its leading note only on the dominant chord
        const isV = mod12(s.chord.root - 7) === tonic;
        const inScale = pcs.filter((p) => scale.has(p) || (minor && isV && p === leading)).length / pcs.length;
        score += (s.d / total) * inScale;
        const isTonic = s.chord.root === tonic && (minor ? s.chord.third === 3 : s.chord.third === 4 && s.chord.seventh !== 10);
        if (isTonic) score += (s.d / total) * 0.35;
        // a dominant that actually resolves to the tonic chord is strong evidence
        const next = real[(i + 1) % real.length].chord;
        if (s.chord.quality === 'dom' && isV && next.root === tonic && (next.third === 3) === minor) score += (s.d / total) * 0.5;
      });
      const first = real[0].chord;
      if (first.root === tonic && (first.third === 3) === minor) score += 0.03;
      if (score > bestScore + 1e-9) {
        bestScore = score;
        best = { tonic, minor };
      }
    }
  }
  return best;
}

/** The pitch with pitch class `pc` closest to `target`, kept inside [lo, hi]. */
export function nearestPitch(pc: number, target: number, lo = 0, hi = 127): number {
  pc = mod12(pc);
  let p = target - mod12(target - pc);
  if (target - p > 6) p += 12;
  while (p < lo) p += 12;
  while (p > hi) p -= 12;
  if (p < lo) p += 12;
  return p;
}
/** Lowest pitch with pitch class `pc` at or above `floor`. */
export function pitchAtOrAbove(pc: number, floor: number): number {
  return floor + mod12(pc - floor);
}
export function pitchAtOrBelow(pc: number, ceil: number): number {
  return ceil - mod12(ceil - pc);
}

/** Move `steps` scale degrees from `pitch` (snapping to the scale first). */
export function scaleStep(pitch: number, pcs: number[], steps: number): number {
  const set = new Set(pcs.map(mod12));
  let p = pitch;
  const dir = steps >= 0 ? 1 : -1;
  let n = Math.abs(steps);
  let guard = 0;
  while (n > 0 && guard++ < 64) {
    p += dir;
    if (set.has(mod12(p))) n--;
  }
  return p;
}
export function snapToSet(pitch: number, pcs: number[], preferDir = 0): number {
  const set = new Set(pcs.map(mod12));
  if (set.has(mod12(pitch))) return pitch;
  for (let d = 1; d < 7; d++) {
    const a = pitch + (preferDir >= 0 ? d : -d);
    const b = pitch - (preferDir >= 0 ? d : -d);
    if (set.has(mod12(a))) return a;
    if (set.has(mod12(b))) return b;
  }
  return pitch;
}
