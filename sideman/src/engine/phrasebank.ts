// The phrase bank. A phrase is a rhythm cell combined with a shape: a melodic
// contour for lines, a note-function scheme for bass, a touch for comping.
// A few hundred curated and derived rhythms times a few dozen shapes gives
// many thousands of distinct phrases, all of which re-fit themselves to the
// chords. A band plan decides who speaks in each bar so the phrases chosen
// for different players answer and reinforce each other.

import { BAR, BEAT, S16 } from './types';
import type { Chord, PhraseUse, StyleId } from './types';
import { chordAt, nextChange, steps } from './perf';
import type { BandPlan, GenCtx, Slot } from './perf';
import { clamp, mod12, nearestPitch, pentFor, roleInterval, scalePcsFor, scaleStep } from './theory';
import { colorIntervals } from './voicing';
import { RNG } from './rng';
import type { LineNote } from './lines';

export type RFam = 'funk' | 'eight' | 'swing' | 'slow' | 'latin';
export function rfamOf(style: StyleId): RFam {
  if (style === 'funk' || style === 'afrobeat' || style === 'neosoul') return 'funk';
  if (style === 'jazz' || style === 'blues') return 'swing';
  if (style === 'ballad') return 'slow';
  if (style === 'bossa') return 'latin';
  return 'eight';
}
const FAM_NAME: Record<RFam, string> = { funk: 'Sixteenth', eight: 'Eighth', swing: 'Swing', slow: 'Slow', latin: 'Clave' };

// x attack, X accented attack, - hold, . rest
const BASE: Record<RFam, string[]> = {
  funk: [
    'x.xx|.x..|x.x-|....',
    '..x.|xx.x|--..|....',
    'x..x|..x.|X--.|....',
    '....|x.xx|.x.X|--..',
    'xx.x|..x.|..X-|--..',
    '..xx|.x.x|..X-|....',
    'x.x.|.xx.|x..X|-...',
    '....|..x.|xx.x|X-..',
    'X...|..x.|.X..|....',
    '..X.|....|x.X.|....',
    'X..X|..X.|....|....',
    '.X.x|....|..X.|....',
    'x.xx|x.x.|.x.x|X---',
    'X--x|.x.x|..x.|x.X-',
    '.x.x|.x.x|X--.|..x.',
    'x..x|.xx.|.x.x|..X-',
  ],
  eight: [
    'x-x-|x---|..x-|x---',
    '..x-|x-x-|X---|--..',
    'x---|x-x-|x-..|....',
    '....|x-x-|x-x-|X---',
    'x-x-|x-x-|X---|....',
    'x---|--x-|x---|--..',
    '..x-|x---|--x-|x-..',
    'x-..|x-x-|--x-|X---',
    'X...|....|..X.|....',
    '....|X...|....|X.x.',
    '..X.|..X.|....|....',
    'X...|..x.|X...|....',
    'x-x-|..x-|x-x-|..X-',
    'X---|..x-|x-x-|x---',
    '..x-|..x-|x-x-|X---',
    'x---|x---|x-x-|x-x-',
  ],
  swing: [
    'x-x-|x-x-|x-x-|x---',
    '..x-|x-x-|x-..|x-x-',
    'x---|..x-|x-x-|X---',
    '....|x-x-|x-x-|x-x-',
    'x-x-|x---|....|..x-',
    'x-x-|x-x-|x-x-|x-x-',
    '..x-|x-x-|X---|....',
    'x---|x-x-|..x-|x-x-',
    'X...|....|..x.|....',
    '....|..X.|....|..X.',
    '..X.|....|....|X...',
    'X...|..X.|....|....',
    '..x-|x-..|x-x-|X---',
    'x-..|..x-|x-x-|x-..',
    'X---|--x-|x-x-|X---',
    '..x-|x-x-|..x-|x-x-',
  ],
  slow: [
    'x---|----|x---|x---',
    'x---|--x-|x---|----',
    '....|x---|x---|--x-',
    'x---|----|----|x-x-',
    '..x-|x---|----|x---',
    'x---|x---|x---|----',
    'X---|----|----|----',
    'x---|----|x---|----',
    '....|....|x---|x---',
    'x---|----|--x-|x---',
    'x-x-|x---|----|----',
    '....|x---|----|x---',
    'x---|----|x-x-|x---',
    '..x-|----|x---|----',
    'x---|x-x-|----|x---',
    'x-x-|----|x---|--x-',
    '....|x---|x-x-|x---',
    'x---|----|--x-|----',
  ],
  latin: [
    'x--x|--x-|..x-|x---',
    'x-.x|-.x-|x-.x|-.x-',
    '..x-|x-.x|-.x-|x---',
    'X--x|--X-|....|....',
    '....|x-x-|.x-x|-.X-',
    'x-x-|.x-x|-.x-|x-..',
    '..x-|..x-|x--x|--X-',
    'x--x|--x-|x-x-|X---',
    'X..X|..X.|....|....',
    '....|X...|X...|....',
    '..X.|..X.|..X.|....',
    'X...|..X.|....|X...',
    'x-x-|x--x|--x-|x-..',
    '.x-x|-.x-|x-x-|X---',
  ],
};

export type RKind = 'full' | 'back' | 'front' | 'shift' | 'thin' | 'push';
export interface Rhythm {
  id: string;
  name: string;
  fam: RFam;
  kind: RKind;
  /** 16 step characters */
  s: string;
  /** attack steps */
  at: number[];
  n: number;
}

const isAtk = (c: string) => c === 'x' || c === 'X';
function tidy(a: string[]): string {
  // a hold with no note before it is just silence
  let sounding = false;
  return a
    .map((c) => {
      if (isAtk(c)) sounding = true;
      else if (c === '.') sounding = false;
      else if (c === '-' && !sounding) return '.';
      return c;
    })
    .join('');
}
function derive(base: string): { s: string; kind: RKind }[] {
  const st = steps(base);
  const out: { s: string; kind: RKind }[] = [{ s: tidy(st), kind: 'full' }];
  const atk = st.map((c, i) => (isAtk(c) ? i : -1)).filter((i) => i >= 0);
  // answer / pickup: only the back half
  const back = st.map((c, i) => (i < 8 ? '.' : c));
  if (back.filter(isAtk).length >= 2) out.push({ s: tidy(back), kind: 'back' });
  // tag: the front half, landing on a long last note
  const fr = st.map((c, i) => (i < 8 ? c : '.'));
  const lastF = fr.map((c, i) => (isAtk(c) ? i : -1)).filter((i) => i >= 0);
  if (lastF.length >= 2) {
    const l = lastF[lastF.length - 1];
    fr[l] = 'X';
    for (let i = l + 1; i < 12; i++) fr[i] = '-';
    out.push({ s: tidy(fr), kind: 'front' });
  }
  // the same figure started an eighth later
  const sh = ['.', '.', ...st.slice(0, 14)];
  if (sh.filter(isAtk).length >= 2) out.push({ s: tidy(sh), kind: 'shift' });
  // thinned: weak sixteenths dropped
  if (atk.length > 3) {
    const th = st.slice();
    let drop = false;
    for (let i = 0; i < 16; i++) {
      if (isAtk(th[i])) {
        drop = i % 2 === 1 || (i % 4 === 2 && atk.length > 5 && th[i] !== 'X');
        if (drop) th[i] = '.';
      } else if (th[i] === '-' && drop) th[i] = '.';
      else if (th[i] === '.') drop = false;
    }
    if (th.filter(isAtk).length >= 2) out.push({ s: tidy(th), kind: 'thin' });
  }
  // pushed: the last on-beat note arrives an eighth early and is held over
  const l = atk[atk.length - 1];
  if (l >= 4 && l % 4 === 0 && !isAtk(st[l - 1]) && !isAtk(st[l - 2])) {
    const pu = st.slice();
    pu[l - 2] = 'X';
    pu[l - 1] = '-';
    pu[l] = '-';
    out.push({ s: tidy(pu), kind: 'push' });
  }
  return out;
}

const KIND_NAME: Record<RKind, string> = { full: '', back: ' pickup', front: ' tag', shift: ' late', thin: ' sparse', push: ' pushed' };
const RHYTHMS: Record<RFam, Rhythm[]> = { funk: [], eight: [], swing: [], slow: [], latin: [] };
for (const fam of Object.keys(BASE) as RFam[]) {
  const seen = new Set<string>();
  BASE[fam].forEach((base, bi) => {
    for (const d of derive(base)) {
      if (seen.has(d.s)) continue;
      seen.add(d.s);
      const at = d.s.split('').map((c, i) => (isAtk(c) ? i : -1)).filter((i) => i >= 0);
      const num = String(bi + 1).padStart(2, '0');
      RHYTHMS[fam].push({ id: `${fam.slice(0, 2)}${num}${d.kind === 'full' ? '' : d.kind[0]}`, name: `${FAM_NAME[fam]} ${num}${KIND_NAME[d.kind]}`, fam, kind: d.kind, s: d.s, at, n: at.length });
    }
  });
}
export const rhythmsOf = (fam: RFam): Rhythm[] => RHYTHMS[fam];

// ------------------------------------------------------------------ line shapes

type Contour = 'rise' | 'fall' | 'arch' | 'dip' | 'flat' | 'zig' | 'sigh';
type Weak = 'step' | 'chord' | 'pent' | 'blues' | 'neighbor' | 'enclose' | 'repeat' | 'chrom' | 'octave';
export interface Shape {
  id: string;
  name: string;
  contour: Contour;
  weak: Weak;
  /** styles this shape is at home in (weight boost) */
  home: StyleId[];
}
const S = (id: string, name: string, contour: Contour, weak: Weak, home: StyleId[] = []): Shape => ({ id, name, contour, weak, home });
export const LINE_SHAPES: Shape[] = [
  S('climb', 'Climb', 'rise', 'step'),
  S('descent', 'Descent', 'fall', 'step'),
  S('arch', 'Arch', 'arch', 'step'),
  S('valley', 'Valley', 'dip', 'step'),
  S('arpup', 'Arpeggio up', 'rise', 'chord', ['jazz', 'bossa', 'ballad', 'pop']),
  S('arpdown', 'Arpeggio down', 'fall', 'chord', ['jazz', 'bossa', 'ballad', 'pop']),
  S('arparch', 'Arpeggio arch', 'arch', 'chord', ['jazz', 'bossa', 'soul']),
  S('turn', 'Turn', 'flat', 'neighbor', ['soul', 'ballad', 'bossa', 'jazz']),
  S('repeat', 'Repeated note', 'flat', 'repeat', ['funk', 'afrobeat', 'reggae', 'rock']),
  S('enclose', 'Enclosure', 'flat', 'enclose', ['jazz', 'bossa', 'blues']),
  S('pentup', 'Pentatonic climb', 'rise', 'pent', ['funk', 'rock', 'afrobeat', 'pop', 'reggae', 'soul']),
  S('pentdown', 'Pentatonic fall', 'fall', 'pent', ['funk', 'rock', 'afrobeat', 'pop', 'reggae', 'soul']),
  S('pentarch', 'Pentatonic arch', 'arch', 'pent', ['funk', 'rock', 'afrobeat', 'pop', 'neosoul']),
  S('pentzig', 'Pentatonic zigzag', 'zig', 'pent', ['funk', 'afrobeat', 'rock']),
  S('bluesfall', 'Blues fall', 'fall', 'blues', ['blues', 'funk', 'soul', 'rock', 'neosoul']),
  S('bluescry', 'Blues cry', 'arch', 'blues', ['blues', 'funk', 'soul', 'rock']),
  S('bluesclimb', 'Blues climb', 'rise', 'blues', ['blues', 'funk', 'soul', 'rock']),
  S('chromup', 'Chromatic run up', 'rise', 'chrom', ['jazz', 'blues', 'bossa']),
  S('chromdown', 'Chromatic run down', 'fall', 'chrom', ['jazz', 'blues', 'bossa']),
  S('zigzag', 'Zigzag', 'zig', 'step'),
  S('thirds', 'Broken thirds', 'zig', 'chord', ['jazz', 'bossa', 'pop', 'ballad']),
  S('octaves', 'Octave leaps', 'flat', 'octave', ['funk', 'afrobeat', 'rock', 'reggae']),
  S('sigh', 'Leap and settle', 'sigh', 'step', ['soul', 'ballad', 'neosoul', 'pop']),
  S('sighpent', 'Cry and fall', 'sigh', 'pent', ['soul', 'blues', 'rock', 'neosoul', 'reggae']),
];
function contourAt(c: Contour, x: number, i: number): number {
  switch (c) {
    case 'rise':
      return x;
    case 'fall':
      return -x;
    case 'arch':
      return Math.sin(Math.PI * x);
    case 'dip':
      return -Math.sin(Math.PI * x);
    case 'flat':
      return 0;
    case 'zig':
      return x * 0.6 + (i % 2 ? 0.35 : 0);
    case 'sigh':
      return i === 0 ? 0 : 1 - x * 0.9;
  }
}

export const BASS_SHAPES = ['Roots', 'Root and fifth', 'Octaves', 'Chord tones', 'Walk-up', 'Pedal', 'Approach', 'Top-down'] as const;
export const COMP_SHAPES = ['Stabs', 'Rings', 'Scratch', 'Mixed'] as const;

/** How many distinct phrases the bank can deal for a style, per kind of player. */
export function bankSize(style: StyleId): { rhythms: number; lines: number; bass: number; comp: number; total: number } {
  const r = rhythmsOf(rfamOf(style)).length;
  const lines = r * LINE_SHAPES.length;
  const bass = r * BASS_SHAPES.length;
  const comp = r * COMP_SHAPES.length;
  return { rhythms: r, lines, bass, comp, total: lines + bass + comp * 2 };
}
export function bankTotal(): number {
  let n = 0;
  for (const fam of Object.keys(RHYTHMS) as RFam[]) n += RHYTHMS[fam].length * (LINE_SHAPES.length + BASS_SHAPES.length + COMP_SHAPES.length * 2);
  return n;
}

// ------------------------------------------------------------------ band plan

const FORMS = ['LALA', 'LLAT', 'LALT', 'L-AT', 'LLLA', 'LAL-', 'LLAA', 'LATL'];
/** Decide, bar by bar, who speaks: lead, answer, everyone together, or nobody. */
export function makePlan(seed: number, bars: number, style: StyleId): BandPlan {
  const rng = new RNG(seed).fork('plan');
  const first = rng.pick(FORMS);
  const second = rng.chance(0.5) ? first.slice(0, 3) + 'T' : rng.pick(FORMS);
  const cycle = (first + second).split('') as Slot[];
  const slots: Slot[] = [];
  for (let i = 0; i < bars; i++) slots.push(cycle[i % 8]);
  const sparse = rhythmsOf(rfamOf(style)).filter((r) => r.n >= 2 && r.n <= 4 && (r.kind === 'full' || r.kind === 'push'));
  const pool = sparse.length >= 2 ? sparse : rhythmsOf(rfamOf(style));
  const a = rng.pick(pool);
  const b = rng.pick(pool.filter((r) => r !== a).length ? pool.filter((r) => r !== a) : pool);
  return { seed, slots, accents: [a.s, b.s] };
}

// ------------------------------------------------------------------ dealing

function pickRhythm(ctx: GenCtx, rng: RNG, kinds: RKind[], avoid?: Rhythm): Rhythm {
  const all = rhythmsOf(rfamOf(ctx.style));
  let pool = all.filter((r) => kinds.includes(r.kind) && r !== avoid);
  if (!pool.length) pool = all;
  // complexity leans towards busier figures
  const want = 2 + ctx.params.complexity * 6 + ctx.energy * 1.5;
  return rng.weighted(
    pool,
    pool.map((r) => Math.exp(-Math.abs(r.n - want) * 0.35)),
  );
}
function pickShape(ctx: GenCtx, rng: RNG): Shape {
  return rng.weighted(
    LINE_SHAPES,
    LINE_SHAPES.map((s) => (s.home.includes(ctx.style) ? 3 : s.home.length ? 0.5 : 1.2)),
  );
}

function harmonyFor(ctx: GenCtx, t: number, d: number): Chord {
  const nc = nextChange(ctx, t);
  if (nc.t - t <= BEAT / 2 && t + d > nc.t + 60 && nc.t < ctx.len) return nc.span.chord;
  return chordAt(ctx, t).chord;
}

interface LineState {
  cur: number;
  lo: number;
  hi: number;
  center: number;
}

/** Realise one phrase (rhythm + shape) against the harmony from bar start t0. */
function playLine(ctx: GenCtx, r: Rhythm, sh: Shape, t0: number, st: LineState, rng: RNG): LineNote[] {
  const chars = r.s.split('');
  const atk: { t: number; d: number; acc: boolean; step: number }[] = [];
  for (const i of r.at) {
    let n = 1;
    while (i + n < 16 && chars[i + n] === '-') n++;
    const t = t0 + i * S16;
    if (chordAt(ctx, t).chord.nc || harmonyFor(ctx, t, n * S16).nc) continue;
    atk.push({ t, d: n * S16, acc: chars[i] === 'X', step: i });
  }
  const n = atk.length;
  if (!n) return [];
  const base = Math.round(st.cur * 0.55 + st.center * 0.45);
  const span = 6 + ctx.params.complexity * 6;
  const bluesPcs = [0, 3, 5, 6, 7, 10].map((i) => mod12(ctx.key.tonic + i));
  const want = atk.map((_, i) => base + contourAt(sh.contour, n > 1 ? i / (n - 1) : 0, i) * span);
  const anchor = atk.map((a, i) => i === 0 || i === n - 1 || a.acc || a.d >= BEAT || a.step % 8 === 0);
  const pitch: number[] = new Array(n).fill(0);
  const toneNear = (pcs: number[], target: number, not?: number): number => {
    let best = target;
    let bd = 99;
    for (const pc of pcs) {
      const p = nearestPitch(pc, target, st.lo, st.hi);
      const d = Math.abs(p - target) + (p === not ? 2.5 : 0) + rng.f() * 0.4;
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    return best;
  };
  // anchors sit on chord tones
  let prev = -1;
  atk.forEach((a, i) => {
    if (!anchor[i]) return;
    const ch = harmonyFor(ctx, a.t, a.d);
    const pcs = [...colorIntervals(ch, ctx.key, 1), 0].map((iv) => mod12(ch.root + iv));
    // the last note of a phrase prefers a stable tone
    const stable = i === n - 1 ? [0, roleInterval(ch, '3'), roleInterval(ch, '5')].map((iv) => mod12(ch.root + iv)) : pcs;
    pitch[i] = toneNear(stable, want[i], sh.weak === 'repeat' ? undefined : prev);
    prev = pitch[i];
  });
  // the notes between take their character from the shape
  for (let i = 0; i < n; i++) {
    if (anchor[i]) continue;
    let j = i;
    while (j < n && !anchor[j]) j++;
    const before = pitch[i - 1];
    const target = j < n ? pitch[j] : before;
    const k = j - i; // notes until the next anchor
    const a = atk[i];
    const ch = harmonyFor(ctx, a.t, a.d);
    const scale = scalePcsFor(ch, ctx.key);
    const side = before < target ? -1 : before > target ? 1 : i % 2 ? 1 : -1;
    let p: number;
    switch (sh.weak) {
      case 'chord':
        p = toneNear(
          colorIntervals(ch, ctx.key, 1).map((iv) => mod12(ch.root + iv)),
          want[i],
          before,
        );
        break;
      case 'pent':
        p = toneNear(
          pentFor(ch).map((iv) => mod12(ch.root + iv)),
          want[i],
          before,
        );
        break;
      case 'blues':
        p = toneNear(bluesPcs, want[i], before);
        break;
      case 'neighbor':
        p = scaleStep(before, scale, i % 2 ? 1 : -1);
        break;
      case 'enclose':
        p = k === 1 ? target - 1 : k === 2 ? scaleStep(target, scale, 1) : scaleStep(target, scale, side * Math.min(k, 3));
        break;
      case 'repeat':
        p = before;
        break;
      case 'chrom':
        p = target + side * Math.min(k, 4);
        break;
      case 'octave':
        p = before + 12 <= st.hi ? before + 12 : before - 12;
        break;
      default:
        p = scaleStep(target, scale, side * Math.min(k, 3));
    }
    pitch[i] = clamp(p, st.lo, st.hi);
  }
  st.cur = pitch[n - 1];
  return atk.map((a, i) => ({ t: a.t, d: a.d, p: pitch[i], acc: a.acc, start: i === 0, end: i === n - 1 }));
}

export type LineRole = 'lead' | 'answer' | 'riff' | 'fills';
export interface BankLine {
  notes: LineNote[];
  uses: PhraseUse[];
}

/**
 * Deal a line from the phrase bank. The band plan says which bars this role
 * speaks in, so a lead and an answer chosen from the bank never talk over
 * each other, and in "together" bars every player gets the same phrase.
 */
export function bankLine(ctx: GenCtx, role: LineRole, range: { lo: number; hi: number; center: number }): BankLine {
  const rng = ctx.rng.fork('bank-' + role);
  const st: LineState = { cur: range.center, lo: range.lo, hi: range.hi, center: range.center };
  const notes: LineNote[] = [];
  const uses: PhraseUse[] = [];
  const play = (bar: number, r: Rhythm, sh: Shape, state: LineState, seedRng: RNG) => {
    const got = playLine(ctx, r, sh, bar * BAR, state, seedRng);
    if (!got.length) return;
    notes.push(...got);
    uses.push({ bar, id: `${r.id}.${sh.id}`, name: `${r.name} · ${sh.name}` });
  };
  for (let ph = 0; ph * ctx.phrase < ctx.bars; ph++) {
    const prng = rng.fork('ph' + ph);
    const shA = pickShape(ctx, prng);
    const shB = pickShape(ctx, prng);
    const A = pickRhythm(ctx, prng, ['full', 'shift', 'thin']);
    const B = pickRhythm(ctx, prng, ['full', 'push', 'thin'], A);
    const tag = pickRhythm(ctx, prng, ['front', 'push']);
    const pick = pickRhythm(ctx, prng, ['back']);
    for (let k = 0; k < ctx.phrase; k++) {
      const bar = ph * ctx.phrase + k;
      if (bar >= ctx.bars) break;
      const slot = ctx.plan.slots[bar] ?? 'L';
      const salt = ctx.swaps[bar] ?? 0;
      if (slot === 'T' && role !== 'fills' && !salt) {
        // everyone plays the plan's phrase, each in their own register
        const trng = new RNG(ctx.plan.seed).fork('together' + bar);
        const tr = pickRhythm(ctx, trng, ['full', 'push']);
        const tsh = pickShape(ctx, trng);
        play(bar, tr, tsh, { ...st, cur: st.center }, new RNG(ctx.plan.seed).fork('tp' + bar));
        continue;
      }
      let r: Rhythm | null = null;
      let sh = shA;
      const lastBar = k === ctx.phrase - 1 || bar === ctx.bars - 1;
      if (role === 'lead') {
        // statement, statement or contrast, contrast, tag
        if (slot === 'L') r = lastBar ? tag : k === 0 ? A : k === 1 ? (prng.fork('v' + k).chance(0.5) ? A : B) : B;
        if (r === B) sh = shB;
      } else if (role === 'answer') {
        if (slot === 'A') {
          // answer a call with a pickup into the next bar, or a full reply if the lead is resting
          const prevSlot = ctx.plan.slots[bar - 1];
          r = prevSlot === 'L' ? (lastBar ? tag : A) : pick;
          sh = shB;
        }
      } else if (role === 'riff') {
        r = lastBar && ctx.phrase > 2 ? tag : k % 2 === 0 ? A : B;
        if (r === B) sh = shA;
      } else if (role === 'fills') {
        if (slot !== 'L' || k % 2 === 1) r = pick;
        sh = shB;
      }
      if (!r) continue;
      let srng = prng.fork('bar' + k);
      if (salt) {
        // the player asked for something else in this bar
        srng = prng.fork(`swap${bar}:${salt}`);
        r = pickRhythm(ctx, srng, role === 'fills' ? ['back'] : ['full', 'shift', 'thin', 'push', 'front'], r);
        sh = pickShape(ctx, srng);
      }
      play(bar, r, sh, st, srng);
    }
  }
  return { notes: notes.sort((a, b) => a.t - b.t), uses };
}

// ------------------------------------------------------------------ bass and comping from the same rhythms

const BASS_GATE: Record<RFam, number> = { funk: 0.6, eight: 0.82, swing: 0.86, slow: 0.95, latin: 0.86 };
export const bassGate = (style: StyleId) => BASS_GATE[rfamOf(style)];

/** Turn a rhythm into a bass template (see bass.ts for the token language). */
function bassTokens(r: Rhythm, shape: number, rng: RNG): string {
  const out: string[] = r.s.split('').map((c) => (c === '-' ? '-' : '.'));
  const m = r.at.length;
  r.at.forEach((i, j) => {
    const onBeat = i % 4 === 0;
    let tk: string;
    if (j === 0) tk = 'R';
    else if (j === m - 1 && i >= 10 && m > 2 && shape !== 5) tk = rng.chance(0.75) ? 'a' : 'n';
    else {
      switch (shape) {
        case 0:
          tk = onBeat ? 'R' : 'r';
          break;
        case 1:
          tk = j % 2 ? '5' : 'R';
          break;
        case 2:
          tk = j % 2 ? '8' : 'R';
          break;
        case 3:
          tk = ['3', '5', '7', '5'][(j - 1) % 4];
          break;
        case 4:
          tk = 's';
          break;
        case 5:
          tk = onBeat ? 'R' : 'r';
          break;
        case 6:
          tk = onBeat ? 'R' : 'c';
          break;
        default:
          tk = ['8', '7', '5', '3'][(j - 1) % 4];
      }
    }
    out[i] = tk;
  });
  return out.join('');
}

export interface BankBars {
  bars: string[];
  uses: PhraseUse[];
}

export function bankBass(ctx: GenCtx): BankBars {
  const rng = ctx.rng.fork('bank-bass');
  const bars: string[] = [];
  const uses: PhraseUse[] = [];
  for (let ph = 0; ph * ctx.phrase < ctx.bars; ph++) {
    const prng = rng.fork('ph' + ph);
    const A = pickRhythm(ctx, prng, ['full', 'thin', 'push']);
    const B = pickRhythm(ctx, prng, ['full', 'thin', 'shift'], A);
    const shape = prng.int(0, BASS_SHAPES.length - 1);
    for (let k = 0; k < ctx.phrase; k++) {
      const bar = ph * ctx.phrase + k;
      if (bar >= ctx.bars) break;
      const salt = ctx.swaps[bar] ?? 0;
      let r = k % 2 === 0 ? A : B;
      let sp = k === ctx.phrase - 1 ? 4 : shape; // walk up out of the phrase
      const srng = prng.fork(salt ? `swap${bar}:${salt}` : 'bar' + k);
      if (salt) {
        r = pickRhythm(ctx, srng, ['full', 'thin', 'push', 'shift'], r);
        sp = srng.int(0, BASS_SHAPES.length - 1);
      }
      bars.push(bassTokens(r, sp, srng));
      uses.push({ bar, id: `${r.id}.b${sp}`, name: `${r.name} · ${BASS_SHAPES[sp]}` });
    }
  }
  return { bars, uses };
}

function overlap(a: string, b: string): number {
  let n = 0;
  for (let i = 0; i < 16; i++) if (isAtk(a[i]) && isAtk(b[i])) n++;
  return n;
}

/**
 * Comping rhythms for guitar or keys. On alternate bars the player joins the
 * band's shared accent figure; in between it picks a figure that stays out of
 * the accents' way, so two comping players interlock rather than collide.
 */
export function bankComp(ctx: GenCtx, who: 'guitar' | 'keys'): { rhythms: Rhythm[]; shapes: number[]; uses: PhraseUse[] } {
  const rng = ctx.rng.fork('bank-comp');
  const fam = rfamOf(ctx.style);
  const all = rhythmsOf(fam);
  const rhythms: Rhythm[] = [];
  const shapes: number[] = [];
  const uses: PhraseUse[] = [];
  const shape = rng.int(0, COMP_SHAPES.length - 1);
  for (let bar = 0; bar < ctx.bars; bar++) {
    const salt = ctx.swaps[bar] ?? 0;
    const acc = ctx.plan.accents[bar % 2];
    const together = (bar % 2 === 0) === (who === 'guitar');
    const deal = (dr: RNG, avoid?: Rhythm): Rhythm => {
      // deal a few and keep the one that collides least with the shared accents
      const cands = [0, 1, 2, 3, 4].map(() => pickRhythm(ctx, dr, ['full', 'thin', 'push', 'shift'], avoid));
      return cands.sort((x, y) => overlap(x.s, acc) - overlap(y.s, acc))[0];
    };
    const plain = rng.fork('bar' + (bar % (ctx.phrase * 2)));
    let r: Rhythm = together ? (all.find((x) => x.s === acc) ?? pickRhythm(ctx, plain, ['full'])) : deal(plain);
    let sp = shape;
    if (salt) {
      // the player asked for something else here: never deal the same figure back
      const srng = rng.fork(`swap${bar}:${salt}`);
      r = deal(srng, r);
      sp = (shape + 1 + srng.int(0, COMP_SHAPES.length - 2)) % COMP_SHAPES.length;
    }
    rhythms.push(r);
    shapes.push(sp);
    uses.push({ bar, id: `${r.id}.c${sp}`, name: `${r.name} · ${COMP_SHAPES[sp]}${together && !salt ? ' (band accents)' : ''}` });
  }
  return { rhythms, shapes, uses };
}

/** Guitar strum tokens for a comping rhythm (see guitar.ts). */
export function guitarTokens(r: Rhythm, shape: number, sixteenths: boolean): string {
  const ch = r.s.split('');
  const out = ch.map(() => '.');
  for (const i of r.at) {
    let h = 0;
    while (i + 1 + h < 16 && ch[i + 1 + h] === '-') h++;
    const acc = ch[i] === 'X';
    const ring = shape === 1 || (shape === 3 && h >= 2) || h >= 4;
    out[i] = ring ? (acc ? 'F' : 'f') : acc ? 'S' : 's';
    if (ring) for (let k = 1; k <= h; k++) out[i + k] = '-';
  }
  if (shape === 2 && sixteenths) for (let i = 0; i < 16; i++) if (out[i] === '.') out[i] = 'm';
  return out.join('');
}

/** Right- and left-hand tokens for a comping rhythm (see keys.ts). */
export function keysTokens(r: Rhythm, shape: number): { rh: string; lh: string } {
  const ch = r.s.split('');
  const rh = ch.map(() => '.');
  const lh = ch.map(() => '.');
  r.at.forEach((i, j) => {
    let h = 0;
    while (i + 1 + h < 16 && ch[i + 1 + h] === '-') h++;
    const acc = ch[i] === 'X';
    const ring = shape === 1 || (shape === 3 && h >= 2) || h >= 3;
    rh[i] = ring ? (acc ? 'C' : 'c') : acc ? 'S' : 's';
    if (ring) for (let k = 1; k <= h; k++) rh[i + k] = '-';
    if (j === 0) {
      lh[i] = 'R';
      for (let k = 1; k <= Math.max(h, 1) && i + k < 16; k++) lh[i + k] = '-';
    }
  });
  return { rh: rh.join(''), lh: lh.join('') };
}
