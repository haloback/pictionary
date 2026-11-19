// Bass recipes. Step templates describe rhythm and note function; the realiser
// resolves them against the harmony, forces roots on chord changes, adds
// approach notes, anticipations, dead notes, slides and hammer-ons.

import { BAR, BEAT, S16 } from './types';
import type { Art, Chord, Part, StyleId } from './types';
import { PB, chordAt, isPhraseEnd, nextChange, segments, stepWeight, steps } from './perf';
import type { GenCtx } from './perf';
import { chordPcs, clamp, mod12, nearestPitch, pitchAtOrAbove, roleInterval, scalePcsFor, scaleStep } from './theory';
import type { PatternDef } from './patterns';
import type { RNG } from './rng';

const LO = 28; // E1
const HI = 55; // G3

interface BassDef {
  bars: string[];
  fills?: string[];
  /** note length as a fraction of the written length */
  gate: number;
  /** ms behind (+) or ahead (-) of the beat */
  lay?: number;
  vel?: number;
  /** multiplier for slide probability */
  slide?: number;
  /** add dead notes in the gaps */
  ghosts?: boolean;
  slap?: boolean;
  /** sit a fourth higher (melodic styles) */
  high?: boolean;
}

/*
  Template tokens (16 per bar, "|" is cosmetic):
    R root   r soft root   8 octave   5 fifth   3 third   6 sixth   7 seventh
    c any chord tone   s scale step   a approach note into the next root
    n next chord's root (pickup)   x dead note   - hold   . rest
*/

function realise(ctx: GenCtx, def: BassDef, barTpl: (bar: number, rng: RNG) => string): Part {
  const b = new PB(ctx);
  const rng = ctx.rng.fork('bass');
  const cx = ctx.params.complexity;
  const ex = ctx.params.expression;
  const total = ctx.bars * 16;
  const tok: string[] = [];
  for (let bar = 0; bar < ctx.bars; bar++) tok.push(...steps(barTpl(bar, rng.fork('tpl' + bar))));

  // harmony changes: force a root, or treat a late attack held over the change as an anticipation
  const antic = new Set<number>();
  for (const sp of ctx.spans) {
    if (!sp.change || sp.t === 0) continue;
    const c = Math.round(sp.t / S16);
    if (c >= total) continue;
    const here = tok[c];
    if (here === 'R' || here === 'r') continue;
    let a = -1;
    if (here === '-') {
      if (tok[c - 1] !== '-' && tok[c - 1] !== '.' && tok[c - 1] !== 'x') a = c - 1;
      else if (tok[c - 1] === '-' && c >= 2 && tok[c - 2] !== '-' && tok[c - 2] !== '.' && tok[c - 2] !== 'x') a = c - 2;
    }
    if (a >= 0) {
      antic.add(a);
      tok[a] = 'R';
    } else tok[c] = 'R';
  }
  // dead notes in the gaps for busier takes
  if (def.ghosts) {
    for (let i = 1; i < total - 1; i++) {
      if (tok[i] === '.' && tok[i + 1] !== '.' && tok[i + 1] !== '-' && tok[i + 1] !== 'x' && rng.chance(cx * 0.3)) tok[i] = 'x';
    }
  }

  const base = (def.high ? 33 : LO) + clamp(ctx.params.octave, -1, 1) * 12;
  const rootOf = (ch: Chord, near: number): number => {
    let p = pitchAtOrAbove(ch.bass, base);
    if (p + 12 <= base + 15 && Math.abs(p + 12 - near) < Math.abs(p - near)) p += 12;
    return p;
  };
  const toneAbove = (ch: Chord, root: number, iv: number): number => {
    let p = pitchAtOrAbove(mod12(ch.root + iv), root + 1);
    if (p > HI + clamp(ctx.params.octave, 0, 1) * 12) p -= 12;
    return p;
  };

  let prev = base + 6;
  let prevRoot = base + 6;
  for (let i = 0; i < total; i++) {
    const tk = tok[i];
    if (tk === '-' || tk === '.') continue;
    const t = i * S16;
    const sp = antic.has(i) ? nextChange(ctx, t).span : chordAt(ctx, t);
    const ch = sp.chord;
    if (ch.nc) continue;
    let holds = 0;
    while (i + 1 + holds < total && tok[i + 1 + holds] === '-') holds++;
    const len = (1 + holds) * S16;
    const w = stepWeight(i);
    const root = rootOf(ch, prevRoot);
    let p = root;
    let art: Art | undefined;
    let v = [82, 87, 95, 103][w] + (def.vel ?? 0);
    let gate = holds >= 3 ? Math.max(def.gate, 0.92) : def.gate;

    switch (tk) {
      case 'R':
        if (def.slap) art = 'slap';
        break;
      case 'r':
        v -= 14;
        break;
      case '8':
        p = root + 12;
        v += 4;
        if (def.slap) {
          art = 'pop';
          gate = Math.min(gate, 0.5);
        }
        break;
      case '5':
        p = toneAbove(ch, root, roleInterval(ch, '5'));
        if (root >= base + 7 && rng.chance(0.45)) p -= 12;
        break;
      case '3':
        p = toneAbove(ch, root, roleInterval(ch, '3'));
        break;
      case '6':
        p = toneAbove(ch, root, roleInterval(ch, '6'));
        break;
      case '7':
        p = toneAbove(ch, root, roleInterval(ch, '7'));
        if (p - root > 9 && root - 2 >= LO && rng.chance(0.5)) p -= 12;
        break;
      case 'c': {
        const cands = chordPcs(ch)
          .slice(0, 4)
          .map((pc) => nearestPitch(pc, prev, LO, HI))
          .filter((q) => q !== prev);
        p = cands.length ? rng.pick(cands) : root;
        break;
      }
      case 's': {
        const target = rootOf(nextChange(ctx, t).span.chord, root);
        p = scaleStep(prev, scalePcsFor(ch, ctx.key), target >= prev ? 1 : -1);
        p = clamp(p, LO, HI);
        v -= 4;
        break;
      }
      case 'n':
      case 'a': {
        // find the chord sounding at the next root attack
        let j = i + 1;
        while (j < total && (tok[j] === '-' || tok[j] === '.' || tok[j] === 'x')) j++;
        const tt = Math.min(j * S16, ctx.len);
        const target = tt >= ctx.len ? ctx.spans[0].chord : antic.has(j) ? nextChange(ctx, tt).span.chord : chordAt(ctx, tt).chord;
        const tp = rootOf(target, root);
        if (tk === 'n') {
          p = tp;
        } else {
          const pcs = scalePcsFor(target, ctx.key);
          const opts = [tp - 1, tp + 1, scaleStep(tp, pcs, -1), scaleStep(tp, pcs, 1), tp - 5, tp + 7];
          const wts = [35, 18, 18, 10, 14, 5].map((wt, k) => (opts[k] < LO || opts[k] > HI || opts[k] === prev ? 0 : wt));
          p = rng.weighted(opts, wts);
        }
        v -= 5;
        break;
      }
      case 'x':
        b.note(t, b.ms(45), clamp(prev, LO, HI), rng.range(34, 50), { art: 'ghost', abs: true, off: b.ms(def.lay ?? 3) + b.jit(4) });
        continue;
    }
    if (tk === 'R' || tk === 'r') prevRoot = root;
    p = clamp(p, LO - 5, HI + 12);
    const off = b.ms(def.lay ?? 3) + b.jit(5);
    const startAbs = b.w(t) + off;

    // slide up into important roots
    if ((tk === 'R' || tk === 'n') && w >= 2 && (sp.change || antic.has(i)) && rng.chance(ex * 0.2 * (def.slide ?? 1))) {
      art = art ?? 'slide';
      const sl = b.ms(rng.range(55, 95));
      b.bendRampAbs(startAbs - 2, startAbs + sl, -2, 0, 0.7);
      b.bendAbs(startAbs + sl + 4, 0);
    } else if (w >= 1 && tk !== 'r' && rng.chance(ex * cx * 0.16) && p - 2 >= LO) {
      // hammer-on from the scale tone below
      const g = scaleStep(p, scalePcsFor(ch, ctx.key), -1);
      b.note(t, b.ms(48), g, v - 14, { abs: true, off: off - b.ms(38) });
      art = art ?? 'legato';
    }
    b.note(t, len * gate, p, v, { art, off });
    // a touch of vibrato on long held notes
    if (len >= BEAT * 3 && rng.chance(ex * 0.45)) {
      const endAbs = b.w(t + len * gate) + off;
      b.cAbs('vib', startAbs + (endAbs - startAbs) * 0.45, 0);
      b.rampAbs('vib', startAbs + (endAbs - startAbs) * 0.5, endAbs - 20, 0, 0.3 + ex * 0.25, 1, 60);
      b.cAbs('vib', endAbs, 0);
    }
    prev = p;
  }
  return b.part();
}

function fromBars(def: BassDef): (ctx: GenCtx) => Part {
  return (ctx) =>
    realise(ctx, def, (bar, rng) => {
      if (def.fills && isPhraseEnd(ctx, bar) && rng.chance(0.55 + ctx.params.complexity * 0.4)) return rng.pick(def.fills);
      // mostly cycle through the written bars, sometimes swap one for variety
      if (def.bars.length > 1 && rng.chance(ctx.params.complexity * 0.25)) return rng.pick(def.bars);
      return def.bars[bar % def.bars.length];
    });
}

/** Bass line built from the actual kick drum pattern. */
function kickLock(ctx: GenCtx): Part {
  const def: BassDef = { bars: [], gate: 0.72, lay: 4, ghosts: true, slide: 1.2 };
  const kicks = new Set(ctx.groove.kicks.map((t) => Math.round(t / S16)));
  return realise(ctx, def, (bar, rng) => {
    const out: string[] = new Array(16).fill('.');
    const cx = ctx.params.complexity;
    let lastAttack = -9;
    for (let i = 0; i < 16; i++) {
      const g = bar * 16 + i;
      const isKick = kicks.has(g) || (kicks.size === 0 && i % 8 === 0);
      if (i === 0) out[i] = 'R';
      else if (isKick) out[i] = rng.weighted(['R', '8', '5', '7', 'c'], [48, 14 + cx * 14, 14, 10 + cx * 10, cx * 14]);
      else if (lastAttack >= 0 && i - lastAttack <= (i % 4 === 0 ? 3 : 2)) {
        out[i] = '-';
        continue;
      } else continue;
      lastAttack = i;
    }
    // lead into the next bar
    if (out[14] === '.' && out[15] === '.' && rng.chance(0.45 + cx * 0.35)) {
      out[14] = 'a';
      out[15] = '-';
    } else if (out[15] === '.' && rng.chance(0.25 + cx * 0.3)) out[15] = 'a';
    if (isPhraseEnd(ctx, bar) && rng.chance(0.4 + cx * 0.4)) {
      out[12] = '7';
      out[13] = rng.chance(0.5) ? 'x' : '-';
      out[14] = 's';
      out[15] = 'a';
    }
    return out.join('');
  });
}

/** Walking quarter notes (or a half-note two-feel) for swing. */
function walking(ctx: GenCtx, twoFeel: boolean): Part {
  const b = new PB(ctx);
  const rng = ctx.rng.fork('walk');
  const cx = ctx.params.complexity;
  const ex = ctx.params.expression;
  const segs = segments(ctx);
  const lo = 28 + clamp(ctx.params.octave, -1, 1) * 12;
  const hi = lo + 22;
  let cur = lo + 9;
  const emit = (beat: number, lenBeats: number, p: number, accent: boolean) => {
    const off = b.ms(-3) + b.jit(5);
    const t = beat * BEAT;
    const v = (accent ? 98 : 88) + (beat % 4 === 0 ? 4 : 0);
    if (rng.chance(ex * 0.08)) {
      const s = b.w(t) + off;
      b.bendRampAbs(s - 2, s + b.ms(50), -1, 0, 0.7);
      b.bendAbs(s + b.ms(55), 0);
    }
    b.note(t, lenBeats * BEAT * 0.9, p, v, { off });
  };

  segs.forEach((seg, si) => {
    if (seg.chord.nc) return;
    const sb = Math.round(seg.t / BEAT);
    const n = Math.max(1, Math.round(seg.d / BEAT));
    const next = segs[(si + 1) % segs.length].chord;
    const pcs = scalePcsFor(seg.chord, ctx.key);
    const tones = chordPcs(seg.chord).slice(0, 4);
    const root = nearestPitch(seg.chord.bass, cur, lo, hi - 4);
    const nextRoot = nearestPitch(next.nc ? seg.chord.bass : next.bass, root, lo, hi - 4);
    const line: number[] = [root];
    cur = root;
    let dir = nextRoot === cur ? (cur < lo + 10 ? 1 : -1) : Math.sign(nextRoot - cur);
    // if the target is very close, walk away first and come back
    if (Math.abs(nextRoot - cur) <= 2 && n >= 3) dir = cur < lo + 10 ? 1 : -1;
    for (let k = 1; k < n; k++) {
      let p: number;
      if (k === n - 1) {
        const npcs = scalePcsFor(next.nc ? seg.chord : next, ctx.key);
        const opts = [nextRoot - 1, nextRoot + 1, scaleStep(nextRoot, npcs, -1), scaleStep(nextRoot, npcs, 1), nextRoot - 5, nextRoot + 7];
        const wts = [30, 22, 20, 14, 10, 6].map((wt, j) => {
          const o = opts[j];
          if (o < lo || o > hi || o === cur) return 0;
          return wt / (1 + Math.abs(o - cur) * 0.35);
        });
        p = rng.weighted(opts, wts);
      } else {
        if (cur >= hi - 3) dir = -1;
        if (cur <= lo + 2) dir = 1;
        if (n >= 4 && k === Math.floor(n / 2) && Math.abs(nextRoot - cur) <= 2) dir = -dir || 1;
        const strong = (sb + k) % 2 === 0;
        if (strong || rng.chance(0.3)) {
          const cands = tones.map((pc) => (dir > 0 ? pitchAtOrAbove(pc, cur + 1) : cur - 1 - mod12(cur - 1 - pc))).filter((q) => q >= lo && q <= hi && Math.abs(q - cur) <= 7);
          p = cands.length ? cands.sort((x, y) => Math.abs(x - cur) - Math.abs(y - cur))[rng.chance(0.75) ? 0 : cands.length - 1] : scaleStep(cur, pcs, dir);
        } else p = scaleStep(cur, pcs, dir);
        p = clamp(p, lo, hi);
      }
      line.push(p);
      cur = p;
    }
    if (twoFeel) {
      for (let k = 0; k < n; k += 2) {
        const span = Math.min(2, n - k);
        let p = k === 0 ? line[0] : nearestPitch(mod12(seg.chord.root + roleInterval(seg.chord, '5')), line[0], lo, hi);
        if (k > 0 && rng.chance(0.25)) p = line[0];
        emit(sb + k, span, p, k === 0);
        // pickup into the next chord
        if (k + span >= n && rng.chance(0.3 + cx * 0.4)) b.note((sb + n) * BEAT - BEAT / 2, BEAT * 0.4, line[n - 1] ?? p, 78, { off: b.jit(5) });
      }
    } else {
      line.forEach((p, k) => {
        emit(sb + k, 1, p, (sb + k) % 2 === 1);
        // skip note: a swung dead/low note between beats
        if (k < n - 1 && rng.chance(cx * 0.16)) {
          b.note((sb + k) * BEAT + BEAT / 2, b.ms(50), p, rng.range(38, 55), { art: 'ghost', abs: true, off: b.jit(5) });
        }
      });
    }
  });
  return b.part();
}

interface BassRecipe {
  id: string;
  name: string;
  styles: StyleId[] | '*';
  density: 1 | 2 | 3;
  desc: string;
  variant?: string;
  def?: BassDef;
  gen?: (ctx: GenCtx) => Part;
}

const RECIPES: BassRecipe[] = [
  {
    id: 'b.kicklock',
    name: 'Kick Lock',
    styles: ['funk', 'soul', 'pop', 'rock', 'neosoul', 'afrobeat', 'ballad'],
    density: 2,
    desc: 'Follows the kick drum hit for hit, with approach notes into each change.',
    gen: kickLock,
  },
  {
    id: 'b.pump8',
    name: 'Pumping Eighths',
    styles: ['rock', 'pop'],
    density: 2,
    variant: 'pick',
    desc: 'Driving root eighths with fifths and run-ups at phrase ends.',
    def: {
      gate: 0.82,
      lay: 0,
      bars: ['R-R-|R-R-|R-R-|R-R-', 'R-R-|R-R-|R-R-|R-a-', 'R-R-|R-R-|R-R-|5-R-'],
      fills: ['R-R-|R-R-|R-5-|8-a-', 'R-R-|R-R-|3-s-|5-a-', 'R-R-|R-8-|7-5-|3-a-'],
    },
  },
  {
    id: 'b.rootfive',
    name: 'Root and Fifth',
    styles: ['pop', 'ballad', 'reggae', 'soul', 'blues'],
    density: 1,
    desc: 'Two-beat root and fifth with a pickup now and then.',
    def: {
      gate: 0.86,
      bars: ['R---|--..|5---|--..', 'R---|--..|5---|--n-', 'R---|--R-|5---|--..'],
      fills: ['R---|--..|5-3-|s-a-', 'R---|--..|8-7-|5-a-'],
    },
  },
  {
    id: 'b.soul',
    name: 'Syncopated Soul',
    styles: ['soul', 'pop', 'funk', 'neosoul'],
    density: 2,
    desc: 'Dotted figures that push across the bar line, chord tones and chromatic approaches.',
    def: {
      gate: 0.84,
      lay: 5,
      ghosts: true,
      bars: ['R---|--R-|..R-|5-a-', 'R--R|-.5.|R-.3|5-a-', 'R---|--R-|.5R-|3-5-', 'R-.R|-.R-|5-6-|5-a-'],
      fills: ['R---|--R-|3-s-|5-a-', 'R-.R|-.8-|7-5-|3sa-', 'R---|..8-|7-6-|5-a-'],
    },
  },
  {
    id: 'b.funk16',
    name: 'Sixteenth Funk',
    styles: ['funk', 'afrobeat', 'neosoul'],
    density: 3,
    desc: 'Short stabbing roots, octave jumps and dead notes on the sixteenth grid.',
    def: {
      gate: 0.6,
      lay: 2,
      ghosts: true,
      slide: 1.4,
      bars: ['R..x|R.x8|..xR|.x7a', 'R..R|.x8.|x.R.|x7.a', 'R.Rx|..8.|.xR.|7.a.', 'R..x|.R.8|x.7.|R.xa'],
      fills: ['R..x|R.x8|.87.|5s.a', 'R.R.|x.8.|7x5x|3.sa'],
    },
  },
  {
    id: 'b.slap',
    name: 'Slap and Pop',
    styles: ['funk'],
    density: 3,
    variant: 'slap',
    desc: 'Thumbed roots answered by popped octaves.',
    def: {
      gate: 0.5,
      slap: true,
      ghosts: true,
      vel: 6,
      bars: ['R..8|.xR.|x.8x|R.7a', 'R.x8|..Rx|.8.R|x.8.', 'R..R|x8..|R.x8|.R.a'],
      fills: ['R..8|.xR.|8.7.|5.8a'],
    },
  },
  {
    id: 'b.octaves',
    name: 'Octave Bounce',
    styles: ['funk', 'pop', 'soul', 'afrobeat'],
    density: 2,
    desc: 'Root and octave eighths, the disco engine.',
    def: {
      gate: 0.62,
      bars: ['R-8-|R-8-|R-8-|R-8-', 'R-8-|R-8-|R-8-|5-a-', 'R-8-|R-8-|7-8-|R-8-'],
      fills: ['R-8-|R-8-|7-5-|3-a-'],
    },
  },
  {
    id: 'b.walk',
    name: 'Walking Four',
    styles: ['jazz', 'blues'],
    density: 2,
    variant: 'upright',
    desc: 'Quarter-note walking line: roots on the changes, chord and scale tones between, chromatic approaches.',
    gen: (ctx) => walking(ctx, false),
  },
  {
    id: 'b.twofeel',
    name: 'Two-feel',
    styles: ['jazz', 'bossa', 'ballad'],
    density: 1,
    variant: 'upright',
    desc: 'Half notes on root and fifth with the occasional pickup.',
    gen: (ctx) => walking(ctx, true),
  },
  {
    id: 'b.bossa',
    name: 'Bossa Root-Fifth',
    styles: ['bossa'],
    density: 2,
    variant: 'upright',
    desc: 'Dotted quarter and eighth, the surdo pattern on root and fifth.',
    def: {
      gate: 0.9,
      bars: ['R---|--5-|5---|--n-', 'R---|--5-|5---|--n-', 'R---|--R-|5---|--n-'],
      fills: ['R---|--5-|8---|5-a-'],
    },
  },
  {
    id: 'b.reggae',
    name: 'Dub Line',
    styles: ['reggae'],
    density: 2,
    desc: 'Heavy, round and melodic, leaving the downbeat open as often as not.',
    def: {
      gate: 0.9,
      lay: 8,
      vel: 4,
      slide: 0.6,
      bars: ['R---|..R-|3-5-|....', '..R-|R-.5|--3-|R-..', 'R-R-|..5-|3---|R-..', 'R---|..R-|5-3-|R-..'],
      fills: ['R---|..R-|3-5-|6-5-'],
    },
  },
  {
    id: 'b.ballad',
    name: 'Long Tones',
    styles: ['ballad', 'neosoul', 'soul', 'pop', 'bossa'],
    density: 1,
    desc: 'Whole and half notes with gentle lead-ins.',
    def: {
      gate: 0.96,
      lay: 6,
      bars: ['R---|----|----|--..', 'R---|----|----|--a-', 'R---|----|5---|--n-', 'R---|----|--R-|3-5-'],
      fills: ['R---|----|5---|8-a-', 'R---|----|3---|5-a-'],
    },
  },
  {
    id: 'b.neosoul',
    name: 'Behind the Beat',
    styles: ['neosoul', 'soul', 'funk'],
    density: 2,
    desc: 'Lazy placement, slides into roots and space between phrases.',
    def: {
      gate: 0.88,
      lay: 16,
      slide: 2.2,
      ghosts: true,
      bars: ['R---|---x|R-..|..a-', 'R---|--.R|-..5|-.a.', 'R--.|..R-|--7-|..n-', 'R---|-..R|-.3-|5.a-'],
      fills: ['R---|--.8|-.7-|5sa-'],
    },
  },
  {
    id: 'b.afrobeat',
    name: 'Ostinato',
    styles: ['afrobeat', 'funk', 'reggae'],
    density: 2,
    desc: 'A short interlocking figure repeated with hypnotic consistency.',
    def: {
      gate: 0.58,
      lay: 0,
      bars: ['R.R.|.R.5|..R.|7.R.', 'R.R.|.R.5|..R.|7.8.'],
      fills: ['R.R.|.R.5|..7.|5.a.'],
    },
  },
  {
    id: 'b.boogie',
    name: 'Boogie Line',
    styles: ['blues', 'rock', 'jazz'],
    density: 2,
    desc: 'Root, third, fifth, sixth and back: the shuffle walk-up.',
    def: {
      gate: 0.8,
      bars: ['R-R-|3-3-|5-5-|6-5-', 'R-R-|3-3-|5-5-|6-7-', 'R---|3---|5---|6---', '8-8-|7-7-|6-6-|5-5-'],
      fills: ['R-R-|3-3-|5-5-|6-a-'],
    },
  },
  {
    id: 'b.rocksync',
    name: 'Push and Drive',
    styles: ['rock', 'pop', 'blues'],
    density: 2,
    variant: 'pick',
    desc: 'Eighths with pushed anticipations into the changes.',
    def: {
      gate: 0.8,
      bars: ['R-R-|R-RR|-.R-|R-n-', 'R-R-|R-R-|R-R-|R.n-', 'R-.R|-.R-|R-R-|5-n-'],
      fills: ['R-R-|R-RR|-.8-|7-a-'],
    },
  },
];

export const BASS_PATTERNS: PatternDef[] = RECIPES.map((r) => ({
  id: r.id,
  name: r.name,
  family: 'bass',
  styles: r.styles,
  density: r.density,
  role: 'groove',
  desc: r.desc,
  variant: r.variant,
  gen: r.gen ?? fromBars(r.def!),
}));
