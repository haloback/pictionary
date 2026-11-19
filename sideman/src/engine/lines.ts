// Melodic line generators shared by horns and guitar: improvised solo phrases,
// repeating riffs that adapt to each chord, and slow guide-tone lines.

import { BAR, BEAT, S16 } from './types';
import type { Chord, StyleId } from './types';
import { chordAt, isPhraseEnd, nextChange, steps } from './perf';
import type { GenCtx } from './perf';
import { clamp, keyScalePcs, mod12, nearestPitch, pentFor, pitchAtOrBelow, roleInterval, scalePcsFor, scaleStep } from './theory';
import type { RNG } from './rng';

export interface LineNote {
  t: number;
  d: number;
  p: number;
  acc?: boolean;
  /** first / last note of a phrase (breath before / after) */
  start?: boolean;
  end?: boolean;
}

type CellFamily = 'funk' | 'eight' | 'swing' | 'slow';

// x attack, X accented attack, - hold, . rest
const CELLS: Record<CellFamily, string[]> = {
  funk: [
    'x.xx|.x..|x.x-|....',
    '..x.|xx.x|--..|....',
    'x..x|..x.|X--.|....',
    '....|x.xx|.x.X|--..',
    'xx.x|..x.|..X-|--..',
    '..xx|.x.x|..X-|....',
    'x.x.|.xx.|x..X|-...',
    '....|..x.|xx.x|X-..',
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
  ],
  slow: ['x---|----|x---|x---', 'x---|--x-|x---|----', '....|x---|x---|--x-', 'x---|----|----|x-x-', '..x-|x---|----|x---', 'x---|x---|x---|----'],
};
const CADENCE: Record<CellFamily, string[]> = {
  funk: ['x.xx|.X--|----|....', '..x.|X---|--..|....', 'x..x|X---|----|....'],
  eight: ['x-x-|X---|----|....', 'x---|----|--..|....', '..x-|X---|----|--..'],
  swing: ['x-x-|X---|----|....', '..x-|x-X-|----|....', 'x---|----|--..|....'],
  slow: ['x---|----|----|....', 'x---|x---|----|--..'],
};

export function cellFamily(style: StyleId): CellFamily {
  if (style === 'funk' || style === 'afrobeat' || style === 'neosoul') return 'funk';
  if (style === 'jazz' || style === 'blues') return 'swing';
  if (style === 'ballad') return 'slow';
  return 'eight';
}

interface Attack {
  t: number;
  d: number;
  acc: boolean;
}
function attacks(cell: string, t0: number, ctx?: GenCtx): Attack[] {
  const st = steps(cell);
  const out: Attack[] = [];
  for (let i = 0; i < 16; i++) {
    if (st[i] !== 'x' && st[i] !== 'X') continue;
    let n = 1;
    while (i + n < 16 && st[i + n] === '-') n++;
    out.push({ t: t0 + i * S16, d: n * S16, acc: st[i] === 'X' });
  }
  // stay silent through "N.C." bars
  if (ctx) return out.filter((a) => !chordAt(ctx, a.t).chord.nc && !harmonyFor(ctx, a.t, a.d).nc);
  return out;
}

/** The chord a note should be heard against (late notes held over a change anticipate it). */
function harmonyFor(ctx: GenCtx, t: number, d: number): Chord {
  const nc = nextChange(ctx, t);
  if (nc.t - t <= BEAT / 2 && t + d > nc.t + 60 && nc.t < ctx.len) return nc.span.chord;
  return chordAt(ctx, t).chord;
}

export interface SoloOpts {
  lo: number;
  hi: number;
  center: number;
  /** use the key's blues scale for passing notes */
  blues?: boolean;
  family?: CellFamily;
  /** probability of leaving a bar empty */
  space?: number;
  /** only play in the second half of each phrase (answering) */
  answer?: boolean;
  /** only play short fills at the end of every other bar */
  fills?: boolean;
}

/** Improvised melodic phrases: motif, repeat, contrast, cadence, breath. */
export function soloLine(ctx: GenCtx, o: SoloOpts): LineNote[] {
  const rng = ctx.rng.fork('solo');
  const fam = o.family ?? cellFamily(ctx.style);
  const cx = ctx.params.complexity;
  const out: LineNote[] = [];
  let cur = o.center + rng.int(-3, 3);
  const space = o.space ?? 0.12;
  const bluesPcs = (() => {
    const tonic = ctx.key.tonic;
    return [0, 3, 5, 6, 7, 10].map((i) => mod12(tonic + i));
  })();

  for (let ph = 0; ph * ctx.phrase < ctx.bars; ph++) {
    const prng = rng.fork('ph' + ph);
    const a = prng.pick(CELLS[fam]);
    const bCell = prng.pick(CELLS[fam].filter((c) => c !== a));
    const form = prng.pick(['aaba', 'abab', 'aabc', 'abac']);
    let dir = ph % 2 === 0 ? 1 : -1;
    // each new phrase starts back towards the middle of the instrument
    cur = Math.round(cur * 0.45 + o.center * 0.55);
    let phraseNotes: Attack[] = [];
    const flush = () => {
      if (!phraseNotes.length) return;
      assign(phraseNotes);
      phraseNotes = [];
    };

    const assign = (atk: Attack[]) => {
      // pass 1: strong notes land on chord tones
      const pitch: (number | null)[] = atk.map(() => null);
      const strong = atk.map((n, i) => {
        const step = Math.round(n.t / S16) % 16;
        const next = atk[i + 1];
        return n.d >= BEAT || step % 8 === 0 || n.acc || !next || next.t - (n.t + n.d) >= S16 * 2 || i === 0;
      });
      let c = cur;
      atk.forEach((n, i) => {
        if (!strong[i]) return;
        const ch = harmonyFor(ctx, n.t, n.d);
        if (ch.nc) return;
        const last = i === atk.length - 1;
        const roles: [number, number][] = [
          [roleInterval(ch, '3'), 3],
          [roleInterval(ch, '5'), last ? 2.5 : 2],
          [roleInterval(ch, '7'), ch.seventh == null && !ch.sixth ? 0.5 : last ? 1.2 : 3],
          [0, last ? 2.6 : 1.4],
          [roleInterval(ch, '9'), cx > 0.35 && !last ? 1.8 : 0.2],
        ];
        const want = c + dir * (n.d >= BEAT ? 3 : 2);
        const cands: number[] = [];
        const wts: number[] = [];
        for (const [iv, wt] of roles) {
          const p = nearestPitch(mod12(ch.root + iv), want, o.lo, o.hi);
          if (cands.includes(p)) continue;
          cands.push(p);
          wts.push((wt / (1 + Math.abs(p - want) / 3)) * (p === c ? 0.35 : 1));
        }
        const p = prng.weighted(cands, wts);
        pitch[i] = p;
        c = p;
        if (c > o.hi - 4) dir = -1;
        if (c < o.lo + 4) dir = 1;
        if (prng.chance(0.18)) dir = -dir;
      });
      // pass 2: weak notes run stepwise into the next strong note
      for (let i = 0; i < atk.length; i++) {
        if (pitch[i] != null) continue;
        let j = i;
        while (j < atk.length && pitch[j] == null) j++;
        const before = i > 0 ? pitch[i - 1]! : cur;
        const target = j < atk.length ? pitch[j]! : before;
        const m = j - i;
        const side = before < target ? -1 : before > target ? 1 : prng.chance(0.5) ? 1 : -1;
        for (let k = 0; k < m; k++) {
          const n = atk[i + k];
          const ch = harmonyFor(ctx, n.t, n.d);
          const pcs = o.blues ? bluesPcs : scalePcsFor(ch, ctx.key);
          const stepsAway = m - k;
          let p: number;
          if (before === target && m >= 2 && k === m - 2) p = scaleStep(target, pcs, -side);
          else if (stepsAway === 1 && prng.chance(0.22) && !o.blues && fam !== 'slow') p = target + side; // chromatic approach
          else p = scaleStep(target, pcs, side * Math.min(stepsAway, 3));
          pitch[i + k] = clamp(p, o.lo, o.hi);
        }
        i = j - 1;
      }
      atk.forEach((n, i) => {
        if (pitch[i] == null) return;
        out.push({ t: n.t, d: n.d, p: pitch[i]!, acc: n.acc, start: i === 0, end: i === atk.length - 1 });
      });
      cur = c;
    };

    for (let k = 0; k < ctx.phrase; k++) {
      const bar = ph * ctx.phrase + k;
      if (bar >= ctx.bars) break;
      const t0 = bar * BAR;
      const last = isPhraseEnd(ctx, bar);
      if (o.answer && k < Math.floor(ctx.phrase / 2)) continue;
      if (o.fills) {
        // two-beat pickups at the end of every other bar
        if (k % 2 === 0) continue;
        const cell = prng.fork('f' + k).pick(CELLS[fam]);
        const atk = attacks(cell, t0, ctx)
          .filter((n) => n.t - t0 >= BEAT * 2)
          .map((n) => ({ ...n, d: Math.min(n.d, t0 + BAR - n.t) }));
        if (atk.length) {
          phraseNotes = atk;
          flush();
        }
        continue;
      }
      if (!last && k > 0 && prng.chance(space * (1.4 - cx))) {
        flush();
        continue;
      }
      const letter = form[k % 4];
      let cell = last ? prng.pick(CADENCE[fam]) : letter === 'a' ? a : letter === 'b' ? bCell : prng.pick(CELLS[fam]);
      // busier takes fill a rest, sparser takes thin the cell
      let atk = attacks(cell, t0, ctx);
      if (cx < 0.3 && atk.length > 3) atk = atk.filter((_, i) => i % 3 !== 1);
      // a breath separates phrases: bars with a long gap end the current phrase
      const prev = phraseNotes[phraseNotes.length - 1];
      if (prev && atk.length && atk[0].t - (prev.t + prev.d) >= BEAT) flush();
      phraseNotes.push(...atk);
      if (last) flush();
    }
    flush();
  }
  return out.sort((x, y) => x.t - y.t);
}

export interface RiffOpts {
  center: number;
  lo: number;
  hi: number;
  family?: CellFamily;
  /** bars in the riff before it repeats */
  bars?: 1 | 2;
  /** only play in answering bars */
  answer?: boolean;
}

/** A short pentatonic riff that repeats and re-fits itself to every chord. */
export function riffLine(ctx: GenCtx, o: RiffOpts): LineNote[] {
  const rng = ctx.rng.fork('riff');
  const fam = o.family ?? cellFamily(ctx.style);
  const nBars = o.bars ?? (rng.chance(0.5) ? 2 : 1);
  const cells = [rng.pick(CELLS[fam]), rng.pick(CELLS[fam])];
  // degree walk on a pentatonic ladder (index 0 = root)
  const motif = cells.map((cell, ci) => {
    const atk = attacks(cell, 0);
    let idx = rng.pick([0, 2, 3, 4]);
    return atk.map((n, i) => {
      const lastNote = i === atk.length - 1;
      if (i > 0) idx += rng.weighted([-2, -1, 0, 1, 2], [1, 3, 1.2, 3, 1]);
      if (lastNote) idx = rng.pick(ci === nBars - 1 ? [0, 0, 5, 3] : [2, 3, 4, 1]);
      idx = clamp(idx, -2, 7);
      return { ...n, idx };
    });
  });
  const out: LineNote[] = [];
  for (let bar = 0; bar < ctx.bars; bar++) {
    if (o.answer && bar % 2 === 0) continue;
    const m = motif[bar % nBars];
    const t0 = bar * BAR;
    const vary = isPhraseEnd(ctx, bar) ? rng.fork('v' + bar) : null;
    m.forEach((n, i) => {
      const ch = harmonyFor(ctx, t0 + n.t, n.d);
      if (ch.nc) return;
      const pent = pentFor(ch);
      let idx = n.idx;
      if (vary && i >= m.length - 2) idx += vary.pick([-1, 1, 2, 0]);
      const base = pitchAtOrBelow(ch.root, o.center);
      const oct = Math.floor(idx / 5);
      let p = base + pent[((idx % 5) + 5) % 5] + oct * 12;
      while (p > o.hi) p -= 12;
      while (p < o.lo) p += 12;
      out.push({ t: t0 + n.t, d: n.d, p, acc: n.acc || i === m.length - 1, start: i === 0, end: i === m.length - 1 });
    });
  }
  return out;
}

/** Slow counter-line moving by step between guide tones (3rds and 7ths). */
export function guideLine(ctx: GenCtx, center: number, lo: number, hi: number, startRole: '3' | '7' = '3'): LineNote[] {
  const out: LineNote[] = [];
  let cur = center;
  let first = true;
  const segs: { t: number; d: number; chord: Chord }[] = [];
  for (const s of ctx.spans) {
    const last = segs[segs.length - 1];
    if (last && !s.change && last.t + last.d === s.t && Math.floor(last.t / BAR) === Math.floor(s.t / BAR)) last.d += s.d;
    else segs.push({ t: s.t, d: s.d, chord: s.chord });
  }
  for (const s of segs) {
    if (s.chord.nc) continue;
    const g1 = mod12(s.chord.root + roleInterval(s.chord, '3'));
    // plain triads have no seventh: the second line takes the fifth instead of inventing one
    const g2 = mod12(s.chord.root + roleInterval(s.chord, s.chord.seventh != null || s.chord.sixth ? '7' : '5'));
    let p: number;
    if (first) {
      p = nearestPitch(startRole === '3' ? g1 : g2, center, lo, hi);
      first = false;
    } else {
      const a = nearestPitch(g1, cur, lo, hi);
      const c = nearestPitch(g2, cur, lo, hi);
      p = Math.abs(a - cur) <= Math.abs(c - cur) ? a : c;
      // guide tones resolve downwards; jump back up before the line sinks out of its register
      if (center - p > 6 && p + 12 <= hi) p += 12;
    }
    out.push({ t: s.t, d: s.d, p, start: true, end: true });
    cur = p;
  }
  return out;
}

export function keyBluesPcs(ctx: GenCtx): number[] {
  const k = ctx.key;
  const minorTonic = k.minor ? k.tonic : mod12(k.tonic + 9);
  void keyScalePcs;
  return [0, 3, 5, 6, 7, 10].map((i) => mod12((k.minor ? minorTonic : k.tonic) + i));
}

export type { RNG };
