// Horn recipes. Section recipes write one lead line and voice the other horns
// underneath it; solo recipes improvise. Every note gets a breath shape:
// dynamics curve, delayed vibrato, scoops, falls, slurs and tongued attacks.

import { BAR, BEAT, S16 } from './types';
import type { Chord, Note, Part, PhraseUse, StyleId } from './types';
import { PB, chordAt, isPhraseEnd, nextChange, segments, steps } from './perf';
import type { GenCtx } from './perf';
import { clamp, mod12, nearestPitch, roleInterval, scalePcsFor, scaleStep } from './theory';
import { colorIntervals } from './voicing';
import { cellFamily, guideLine, riffLine, soloLine } from './lines';
import type { LineNote } from './lines';
import type { PatternDef, SectionPlayer } from './patterns';
import { bankLine } from './phrasebank';
import type { LineRole } from './phrasebank';

type HornId = SectionPlayer['inst'];

export const HORN_RANGE: Record<HornId, { lo: number; hi: number; cLo: number; cHi: number; lead: number }> = {
  trumpet: { lo: 55, hi: 84, cLo: 58, cHi: 79, lead: 72 },
  alto: { lo: 49, hi: 80, cLo: 53, cHi: 76, lead: 67 },
  tenor: { lo: 44, hi: 75, cLo: 46, cHi: 70, lead: 62 },
  trombone: { lo: 40, hi: 72, cLo: 43, cHi: 67, lead: 58 },
  bari: { lo: 36, hi: 65, cLo: 37, cHi: 60, lead: 50 },
  flute: { lo: 60, hi: 96, cLo: 62, cHi: 91, lead: 79 },
};
const ORDER: HornId[] = ['flute', 'trumpet', 'alto', 'tenor', 'trombone', 'bari'];
/** which octave each horn takes when the section plays one line together */
const OCT: Record<HornId, number> = { flute: 12, trumpet: 0, alto: 0, tenor: -12, trombone: -12, bari: -24 };
/** an instrument's range, moved by its type (flugelhorn sits lower, lead trumpet higher) */
export function rangeOf(inst: HornId, shift = 0) {
  const r = HORN_RANGE[inst] ?? HORN_RANGE.tenor;
  return { lo: r.lo + shift, hi: r.hi + shift, cLo: r.cLo + shift, cHi: r.cHi + shift, lead: r.lead + shift };
}

type Shape = 'natural' | 'swell' | 'fp' | 'hairpin' | 'dim';
interface HornEv {
  t: number;
  d: number;
  p: number;
  kind: 'stab' | 'long' | 'line';
  acc?: boolean;
  start?: boolean;
  end?: boolean;
  fall?: boolean;
  shape?: Shape;
}

interface RenderOpts {
  /** lead players get full vibrato and ornaments; inner voices stay plainer */
  lead: boolean;
  /** section parts play tighter and with less individual ornament */
  section: boolean;
  /** notes at or below this pitch are in the instrument's breathy low register */
  low: number;
}

function fit(p: number, inst: HornId, comfy = true, shift = 0): number {
  const r = rangeOf(inst, shift);
  const lo = comfy ? r.cLo : r.lo;
  const hi = comfy ? r.cHi : r.hi;
  while (p > hi) p -= 12;
  while (p < lo) p += 12;
  return p;
}

/** Turn abstract horn events into notes, dynamics, vibrato and bends for one player. */
function renderHorn(b: PB, evs: HornEv[], o: RenderOpts): void {
  const ctx = b.ctx;
  const rng = ctx.rng.fork('horn-perf');
  const ex = ctx.params.expression;
  const cx = ctx.params.complexity;
  const tr = ctx.traits;
  const dynScale = 0.55 + ctx.params.dynamics * 0.5;
  const jazzy = ctx.style === 'jazz' || ctx.style === 'blues' || ctx.style === 'funk' || ctx.style === 'soul' || ctx.style === 'neosoul';
  const bias = b.ms(rng.range(-4, 5));
  const sorted = evs.slice().sort((a, c) => a.t - c.t);
  let prevEndAbs = -1e9;
  let prevPitch = -1;
  let prevSlurred = false;
  const D = (v: number) => clamp(v * dynScale, 0.05, 1);
  const solo = o.lead ? 1 : 0.35;

  sorted.forEach((e, i) => {
    const next = sorted[i + 1];
    const off = bias + b.jit(o.section ? 3 : 5);
    const startAbs = b.w(e.t) + off;
    const gapNext = next ? next.t - (e.t + e.d) : 9999;
    const pitchLift = clamp((e.p - 60) / 60, -0.1, 0.15);
    const isShort = e.kind === 'stab' || (e.d <= S16 * 2 && gapNext >= S16);
    const isLong = e.d >= BEAT && e.kind !== 'stab';
    // the instrument type decides how readily it falls off a note
    const fall = (!!e.fall && rng.chance(Math.min(1, tr.fall))) || (!e.fall && !!e.end && !!e.acc && !isShort && e.d >= S16 * 3 && gapNext >= BEAT && rng.chance(Math.max(0, tr.fall - 1) * 0.3));
    let vel: number;
    let dur: number;
    let art: Note['art'];

    if (isShort) {
      dur = e.kind === 'stab' && e.d > S16 * 2 ? e.d * 0.7 : Math.min(e.d, S16 * 2) * (e.acc ? 0.62 : 0.5);
      vel = e.acc ? 110 : 94;
      art = e.acc ? 'marcato' : 'staccato';
      b.cAbs('dyn', startAbs - 4, D((e.acc ? 0.92 : 0.76) + pitchLift));
      prevSlurred = false;
    } else {
      // slur into the next note when they connect and move by a small interval
      const connects = gapNext < 20 && next && next.kind === 'line';
      const slurNext = !!connects && Math.abs(next!.p - e.p) <= 4 && rng.chance(o.section ? 0.35 : 0.6);
      dur = isLong ? e.d * (gapNext < 20 ? 0.97 : 0.93) : slurNext ? e.d + 14 : e.d * 0.86;
      vel = (e.acc ? 104 : 88) - (prevSlurred ? 12 : 0);
      if (prevSlurred) art = 'legato';
      else if (e.acc && !isLong) art = 'marcato';
      prevSlurred = slurNext;
    }
    if (fall) art = 'fall';
    const endAbs = startAbs + (b.w(e.t + dur) - b.w(e.t));
    const durAbs = endAbs - startAbs;

    // grace note from below (solo players, tongued notes on the beat)
    if (!o.section && !isShort && art !== 'legato' && Math.round(e.t / S16) % 4 === 0 && rng.chance(ex * cx * 0.14 * tr.grace) && startAbs - prevEndAbs > b.ms(60)) {
      const g = scaleStep(e.p, scalePcsFor(chordAt(ctx, e.t).chord, ctx.key), -1);
      b.note(e.t, b.ms(46), g, vel - 14, { abs: true, off: off - b.ms(36), raw: false });
      art = 'legato';
    }
    const nn = b.note(e.t, dur, e.p, vel, { art, off });

    const free = startAbs - prevEndAbs > b.ms(25);
    let bent = false;
    if (tr.gliss > 0 && !isShort && prevPitch >= 0 && startAbs - prevEndAbs < b.ms(130) && prevPitch !== e.p && Math.abs(prevPitch - e.p) <= 5 && rng.chance(Math.min(1, ex * 0.4 * tr.gliss))) {
      // slide from the previous note (trombone, plunger)
      const gl = Math.min(b.ms(rng.range(60, 120)), durAbs * 0.5);
      b.bendRampAbs(startAbs - 2, startAbs + gl, clamp(prevPitch - e.p, -2, 2), 0, 0.8);
      b.bendAbs(startAbs + gl + 3, 0);
      if (!fall) nn.art = 'gliss';
      bent = true;
    } else if (free && !isShort && (e.start || e.acc || isLong) && rng.chance(Math.min(1, ex * (jazzy ? 0.3 : 0.14) * solo * tr.scoop))) {
      // scoop into the note; some types make it a slow, deliberate bend
      const slow = tr.bend > 0 && rng.chance(Math.min(0.8, 0.3 * tr.bend));
      const depth = slow ? rng.range(1, 2) : rng.range(0.5, 1.1);
      const sl = Math.min(b.ms(slow ? rng.range(130, 210) : rng.range(55, 105)), durAbs * 0.5);
      b.bendRampAbs(startAbs - 3, startAbs + sl, -depth, 0, 0.6);
      b.bendAbs(startAbs + sl + 3, 0);
      if (slow && !nn.art) nn.art = 'bend';
      bent = true;
    }

    // a shake: a lip trill through the back of a long, loud note
    const shake = isLong && !fall && tr.shake > 0 && durAbs > b.ms(380) && (e.acc || e.shape === 'fp' || (!!e.end && tr.shake > 1)) && rng.chance(Math.min(1, ex * 0.4 * tr.shake * solo));
    // a doit: rip upward off the end
    const doit = !fall && !shake && !isShort && tr.doit > 0 && !!e.end && gapNext >= BEAT / 2 && rng.chance(Math.min(1, ex * 0.22 * tr.doit * solo));

    if (!isShort) {
      const shape: Shape = e.shape ?? 'natural';
      const peak = D((e.acc ? 0.9 : 0.74) + pitchLift);
      if (!isLong) {
        b.cAbs('dyn', startAbs - 3, peak);
      } else if (shape === 'swell') {
        b.rampAbs('dyn', startAbs - 3, endAbs - 10, D(0.32), D(0.84 + pitchLift), 1.5);
      } else if (shape === 'fp') {
        b.cAbs('dyn', startAbs - 3, D(0.96));
        b.rampAbs('dyn', startAbs + b.ms(60), startAbs + b.ms(170), D(0.96), D(0.34), 0.7);
        b.rampAbs('dyn', startAbs + b.ms(180), endAbs - 6, D(0.34), D(1), 1.8);
      } else if (shape === 'hairpin') {
        const mid = startAbs + durAbs * 0.55;
        b.rampAbs('dyn', startAbs - 3, mid, D(0.42), D(0.86 + pitchLift), 1.2);
        b.rampAbs('dyn', mid + 20, endAbs - 6, D(0.86 + pitchLift), D(0.4), 1.1);
      } else if (shape === 'dim') {
        b.rampAbs('dyn', startAbs - 3, endAbs - 6, peak, D(0.3), 1.2);
      } else {
        // natural: tongued attack, settle, then lean one way or the other
        b.cAbs('dyn', startAbs - 3, peak);
        const settle = startAbs + Math.min(b.ms(140), durAbs * 0.3);
        b.rampAbs('dyn', startAbs + b.ms(30), settle, peak, peak * 0.84, 1);
        const lean = e.end ? 0.78 : rng.chance(0.5) ? 1.08 : 0.9;
        b.rampAbs('dyn', settle + 20, endAbs - 6, peak * 0.84, clamp(peak * 0.84 * lean, 0.05, 1), 1.2, 50);
      }
      // vibrato arrives late on held notes
      const vibDepth = (o.lead ? 0.35 + ex * 0.5 : ex * 0.25) * (ctx.style === 'ballad' || ctx.style === 'bossa' ? 1.15 : 1) * tr.vib;
      if (isLong && !shake && vibDepth > 0.08 && durAbs > b.ms(380) && !fall && rng.chance(o.lead ? 0.9 : 0.5)) {
        const vs = startAbs + Math.max(durAbs * 0.38, b.ms(220));
        if (vs < endAbs - b.ms(80)) {
          b.cAbs('vib', startAbs, 0);
          b.rampAbs('vib', vs, vs + (endAbs - vs) * 0.6, 0, clamp(vibDepth, 0, 1), 1.3, 40);
          b.cAbs('vib', endAbs + 2, 0);
        }
      }
    }

    if (shake) {
      const ss = startAbs + durAbs * 0.4;
      const step = b.ms(62);
      let up = false;
      for (let t = ss; t < endAbs - step; t += step) {
        up = !up;
        b.bendAbs(t, up ? 1.7 : 0);
      }
      b.bendAbs(endAbs + 4, 0);
      nn.art = 'shake';
    } else if (doit) {
      const dl = Math.min(b.ms(rng.range(120, 180)), durAbs * 0.45);
      b.bendRampAbs(endAbs - dl, endAbs, 0, 2, 1.4);
      b.rampAbs('dyn', endAbs - dl, endAbs, D(0.9), D(0.3), 1.6, 20);
      b.bendAbs(endAbs + 14, 0);
      nn.art = 'doit';
    } else if (fall) {
      // fall-off: pitch and air drop away together
      const fl = Math.min(b.ms(rng.range(140, 230)), durAbs * 0.55);
      const fs = endAbs - fl;
      b.bendRampAbs(fs, endAbs, 0, -2, 1.5);
      b.rampAbs('dyn', fs, endAbs, D(0.85), D(0.15), 1.2, 20);
      b.bendAbs(endAbs + 14, 0);
    }
    // tone colours that are a matter of the player's reed and air
    if ((!nn.art || nn.art === 'marcato') && !bent && tr.growl > 0 && !!e.acc && rng.chance(Math.min(1, 0.4 * tr.growl * (0.4 + ex)))) {
      nn.art = 'growl';
      nn.v = clamp(nn.v + 5, 1, 127);
    } else if (!nn.art && tr.subtone > 0 && vel < 96 && e.p <= o.low + Math.max(0, tr.subtone - 1) * 6 && rng.chance(Math.min(1, 0.45 * tr.subtone))) {
      nn.art = 'subtone';
      nn.v = clamp(nn.v - 9, 1, 127);
    }
    prevEndAbs = endAbs;
    prevPitch = e.p;
  });
}

function lineToEvs(line: LineNote[], fallProb: number, rng: { chance: (p: number) => boolean }): HornEv[] {
  return line.map((n, i) => {
    const next = line[i + 1];
    const gap = next ? next.t - (n.t + n.d) : 9999;
    const kind: HornEv['kind'] = n.d >= BEAT ? 'long' : 'line';
    const fall = !!n.end && n.d >= S16 * 3 && n.d <= BEAT * 2 && gap >= BEAT && rng.chance(fallProb);
    return { t: n.t, d: n.d, p: n.p, kind, acc: n.acc, start: n.start, end: n.end, fall };
  });
}

// ------------------------------------------------------------------ voicing

/** Pitches for `n` horns, lead first, voiced downward in close position. */
function voiceBelow(lead: number, ch: Chord, ctx: GenCtx, n: number, mode: 'close' | 'drop2' | 'spread'): number[] {
  const out = [lead];
  if (n <= 1) return out;
  const set = colorIntervals(ch, ctx.key, 1).map((i) => mod12(ch.root + i));
  const leadIn = set.includes(mod12(lead));
  if (!leadIn) {
    // passing tone: parallel diatonic thirds under the lead
    const pcs = scalePcsFor(ch, ctx.key);
    for (let k = 1; k < n; k++) out.push(scaleStep(lead, pcs, -2 * k));
  } else {
    let p = lead;
    for (let k = 1; k < n; k++) {
      let q = p - 1;
      while (!set.includes(mod12(q)) || (k === 1 && lead - q < 2) || mod12(q) === mod12(lead)) {
        q--;
        if (p - q > 12) break;
      }
      if (mod12(q) === mod12(lead)) q = lead - 12;
      out.push(q);
      p = q;
      if (set.length <= 3 && k === set.length - 1 && k + 1 < n) {
        out.push(lead - 12);
        p = lead - 12;
        k++;
      }
    }
  }
  if ((mode === 'drop2' || mode === 'spread') && out.length >= 3) {
    out[1] -= 12;
    out.sort((a, b) => b - a);
  }
  if (mode === 'spread' && out.length >= 4) {
    out[out.length - 1] = nearestPitch(ch.bass, out[out.length - 1] - 5, 36, 60);
  }
  return out.slice(0, n);
}

/** Top-line note for stabs and pads: a colour tone close to where the lead already is. */
function topNote(ch: Chord, ctx: GenCtx, prev: number, center: number, rng: GenCtx['rng'], move = 0.3): number {
  const roles: [number, number][] = [
    [roleInterval(ch, '3'), 2.4],
    [roleInterval(ch, '5'), 2],
    [roleInterval(ch, '7'), ch.seventh != null || ch.sixth ? 2.2 : 0.25],
    [roleInterval(ch, '9'), ch.seventh != null ? 2 : 0.6],
    [0, 1.6],
  ];
  const cands: number[] = [];
  const wts: number[] = [];
  for (const [iv, wt] of roles) {
    const p = nearestPitch(mod12(ch.root + iv), prev, center - 6, center + 7);
    if (cands.includes(p)) continue;
    cands.push(p);
    const dist = Math.abs(p - prev);
    wts.push(wt / (1 + dist * (1 - move) * 1.2) / (1 + Math.abs(p - center) * 0.08));
  }
  return rng.weighted(cands, wts);
}

function sortPlayers(players: SectionPlayer[]): SectionPlayer[] {
  return players.slice().sort((a, b) => ORDER.indexOf(a.inst) - ORDER.indexOf(b.inst));
}

type SectionWriter = (ctx: GenCtx, lead: HornId, leadShift: number) => { evs: HornEv[]; mode: 'close' | 'drop2' | 'spread' | 'octaves'; uses?: PhraseUse[] };

/** Build a section recipe from a lead-line writer. */
function section(writer: SectionWriter) {
  return (ctx: GenCtx, players: SectionPlayer[]): Part[] => {
    const order = sortPlayers(players);
    if (!order.length) return [];
    const leadInst = order[0].inst;
    const { evs, mode, uses } = writer(ctx, leadInst, order[0].ctx.shift);
    const parts = new Map<SectionPlayer, Part>();
    order.forEach((pl, idx) => {
      const b = new PB(pl.ctx);
      const oct = pl.ctx.params.octave * 12;
      const sh = pl.ctx.shift;
      const mine: HornEv[] = evs.map((e) => {
        const ch = harmony(ctx, e.t, e.d);
        let p: number;
        if (mode === 'octaves') p = fit(e.p + OCT[pl.inst] - OCT[leadInst], pl.inst, true, sh);
        else {
          const v = voiceBelow(e.p, ch, ctx, order.length, mode);
          p = fit(v[Math.min(idx, v.length - 1)], pl.inst, false, sh);
        }
        return { ...e, p: p + oct };
      });
      renderHorn(b, mine, { lead: idx === 0, section: true, low: rangeOf(pl.inst, sh).cLo + 9 + oct });
      const part = b.part();
      if (uses) part.phrases = uses;
      parts.set(pl, part);
    });
    return players.map((pl) => parts.get(pl)!);
  };
}

function harmony(ctx: GenCtx, t: number, d: number): Chord {
  const nc = nextChange(ctx, t);
  if (nc.t - t <= BEAT / 2 && nc.t < ctx.len && t + d > nc.t - 30) {
    // a late hit with nothing after it before the change belongs to the next chord
    return nc.span.chord;
  }
  return chordAt(ctx, t).chord;
}

// ------------------------------------------------------------------ section writers

const STAB_CELLS = {
  funk: ['S...|..s.|.S..|....', '..S.|....|s.S.|....', 'S..S|..S.|....|....', '....|..S.|....|s.S.', '.S.s|....|..S.|....', 'S...|....|...S|.s..', '....|S..s|..S.|....'],
  eight: ['S...|....|..S.|....', '....|S...|....|S.s.', '..S.|..S.|....|....', 'S...|..s.|S...|....', '....|....|S.s.|S...', 'S...|....|....|..S.'],
  swing: ['S...|....|..s.|....', '....|..S.|....|..S.', '..S.|....|....|S...', 'S...|..S.|....|....', '....|S...|..s.|....', '..s.|..S.|....|....'],
  slow: ['S...|....|....|....', '....|....|S...|....', 'S...|....|..s.|....'],
};
const STAB_ENDS = {
  funk: ['S...|..s.|L---|....', '..S.|S..s|..L-|--..', 'S..S|..L-|--..|....'],
  eight: ['S...|..s.|L---|--..', '..S.|S...|L---|....', 'S...|....|L---|--..'],
  swing: ['S...|..s.|..L-|--..', '..S.|....|L---|--..', 'S...|..S.|..L-|....'],
  slow: ['S...|....|L---|----'],
};

const stabs: SectionWriter = (ctx, lead, ls) => {
  const rng = ctx.rng.fork('stabs');
  const fam = cellFamily(ctx.style);
  const cx = ctx.params.complexity;
  const center = rangeOf(lead, ls).lead + 2;
  const a = rng.pick(STAB_CELLS[fam]);
  const c2 = rng.pick(STAB_CELLS[fam].filter((c) => c !== a));
  const evs: HornEv[] = [];
  let prev = center;
  for (let bar = 0; bar < ctx.bars; bar++) {
    const r = rng.fork('b' + bar);
    let cell = bar % 2 === 0 ? a : c2;
    if (isPhraseEnd(ctx, bar)) cell = r.pick(STAB_ENDS[fam]);
    else if (r.chance(0.15 + (1 - cx) * 0.2) && bar % 2 === 1) continue; // leave a bar of space
    const st = steps(cell);
    for (let i = 0; i < 16; i++) {
      const tk = st[i];
      if (tk !== 'S' && tk !== 's' && tk !== 'L') continue;
      if (tk === 's' && r.chance((1 - cx) * 0.4)) continue;
      let n = 1;
      while (i + n < 16 && st[i + n] === '-') n++;
      const t = bar * BAR + i * S16;
      const d = tk === 'L' ? n * S16 : S16 * 2;
      const ch = harmony(ctx, t, d);
      if (ch.nc) continue;
      prev = topNote(ch, ctx, prev, center, r, 0.35);
      evs.push({
        t,
        d,
        p: prev,
        kind: tk === 'L' ? 'long' : 'stab',
        acc: tk !== 's',
        shape: tk === 'L' ? 'fp' : undefined,
        fall: tk === 'L' && r.chance(0.35 + ctx.params.expression * 0.4),
        end: tk === 'L',
      });
    }
  }
  return { evs, mode: 'close' };
};

const offbeats: SectionWriter = (ctx, lead, ls) => {
  const rng = ctx.rng.fork('off');
  const center = rangeOf(lead, ls).lead;
  const evs: HornEv[] = [];
  let prev = center;
  const cells = ['..s.|..s.|..s.|..s.', '..s.|..s.|..s.|..S.', '..s.|..S.|..s.|..s.'];
  for (let bar = 0; bar < ctx.bars; bar++) {
    const r = rng.fork('b' + bar);
    const st = steps(r.pick(cells));
    for (let i = 0; i < 16; i++) {
      if (st[i] === '.') continue;
      const t = bar * BAR + i * S16;
      const ch = chordAt(ctx, t).chord;
      if (ch.nc) continue;
      if (i === 2 || r.chance(0.2)) prev = topNote(ch, ctx, prev, center, r, 0.1);
      else prev = nearestPitch(mod12(prev), prev, center - 7, center + 7);
      // keep the top voice a chord tone
      const set = colorIntervals(ch, ctx.key, 1).map((x) => mod12(ch.root + x));
      if (!set.includes(mod12(prev))) prev = topNote(ch, ctx, prev, center, r, 0.1);
      evs.push({ t, d: S16 * 2, p: prev, kind: 'stab', acc: st[i] === 'S' });
    }
  }
  return { evs, mode: 'close' };
};

const pads: SectionWriter = (ctx, lead, ls) => {
  const rng = ctx.rng.fork('pads');
  const center = rangeOf(lead, ls).lead - 2;
  const evs: HornEv[] = [];
  let prev = center;
  let k = 0;
  for (const seg of segments(ctx)) {
    if (seg.chord.nc) continue;
    // re-attack at least every two bars so players can breathe
    for (let t = seg.t; t < seg.t + seg.d; t += BAR * 2) {
      const d = Math.min(BAR * 2, seg.t + seg.d - t);
      prev = topNote(seg.chord, ctx, prev, center, rng, 0.12);
      const breath = k % 2 === 1 || d >= BAR * 2;
      evs.push({
        t,
        d: breath ? Math.max(BEAT, d - BEAT / 2) : d,
        p: prev,
        kind: 'long',
        shape: rng.weighted(['swell', 'hairpin', 'natural'] as Shape[], [3, 2, 1.5]),
        start: true,
        end: breath,
      });
      k++;
    }
  }
  return { evs, mode: rng.chance(0.5) ? 'drop2' : 'spread' };
};

const swellHit: SectionWriter = (ctx, lead, ls) => {
  const rng = ctx.rng.fork('swell');
  const cx = ctx.params.complexity;
  const center = rangeOf(lead, ls).lead + 1;
  const evs: HornEv[] = [];
  let prev = center;
  const every = cx > 0.6 ? 1 : 2;
  for (let bar = 0; bar < ctx.bars; bar++) {
    const r = rng.fork('b' + bar);
    const t0 = bar * BAR;
    if (bar % every === every - 1) {
      // crescendo through the back half of the bar ...
      const len = r.chance(0.5) ? BEAT * 2 : BEAT * 3;
      const ts = t0 + BAR - len;
      const ch = chordAt(ctx, ts).chord;
      if (!ch.nc) {
        prev = topNote(ch, ctx, prev, center, r, 0.3);
        evs.push({ t: ts, d: len - S16, p: prev, kind: 'long', shape: 'fp', start: true });
      }
      // ... into a hit on the next downbeat
      const th = t0 + BAR;
      if (th < ctx.len) {
        const ch2 = chordAt(ctx, th).chord;
        if (!ch2.nc) {
          prev = topNote(ch2, ctx, prev, center, r, 0.2);
          evs.push({ t: th, d: S16 * 2, p: prev, kind: 'stab', acc: true });
        }
      }
    } else if (r.chance(0.3 + cx * 0.4)) {
      const i = r.pick([6, 10, 14]);
      const t = t0 + i * S16;
      const ch = harmony(ctx, t, S16 * 2);
      if (!ch.nc) {
        prev = topNote(ch, ctx, prev, center, r, 0.3);
        evs.push({ t, d: S16 * 2, p: prev, kind: 'stab', acc: false });
      }
    }
  }
  if (ctx.bars >= 2) {
    const ch = ctx.spans[0].chord;
    if (!ch.nc && !evs.some((e) => e.t === 0)) evs.push({ t: 0, d: S16 * 2, p: topNote(ch, ctx, center, center, rng, 0.2), kind: 'stab', acc: true });
  }
  return { evs, mode: 'close' };
};

const riff =
  (opts: { answer?: boolean; harm?: boolean }): SectionWriter =>
  (ctx, lead, ls) => {
    const rng = ctx.rng.fork('riffsec');
    const r = rangeOf(lead, ls);
    const line = riffLine(ctx, { center: r.lead, lo: r.cLo + 4, hi: r.cHi, answer: opts.answer });
    return { evs: lineToEvs(line, 0.3 + ctx.params.expression * 0.4, rng), mode: opts.harm ? 'close' : 'octaves' };
  };

const soli: SectionWriter = (ctx, lead, ls) => {
  const rng = ctx.rng.fork('soli');
  const r = rangeOf(lead, ls);
  const line = soloLine(ctx, { lo: r.cLo + 5, hi: r.cHi, center: r.lead + 2, space: 0.2 });
  return { evs: lineToEvs(line, 0.2 + ctx.params.expression * 0.3, rng), mode: 'close' };
};

/** A section line dealt from the phrase bank, in octaves or harmonised. */
const bankSection =
  (role: LineRole, harm: boolean): SectionWriter =>
  (ctx, lead, ls) => {
    const rng = ctx.rng.fork('banksec');
    const r = rangeOf(lead, ls);
    const got = bankLine(ctx, role, { lo: r.cLo + 4, hi: r.cHi, center: r.lead });
    return { evs: lineToEvs(got.notes, 0.3 + ctx.params.expression * 0.4, rng), mode: harm ? 'close' : 'octaves', uses: got.uses };
  };

/** The whole section on the band's shared accent figure, with the comping players. */
const bandHits: SectionWriter = (ctx, lead, ls) => {
  const rng = ctx.rng.fork('hits');
  const center = rangeOf(lead, ls).lead + 2;
  const evs: HornEv[] = [];
  let prev = center;
  for (let bar = 0; bar < ctx.bars; bar++) {
    const r = rng.fork('b' + bar);
    const st = steps(ctx.plan.accents[bar % 2]);
    const last = st.map((c, i) => (c === 'x' || c === 'X' ? i : -1)).filter((i) => i >= 0).pop();
    for (let i = 0; i < 16; i++) {
      if (st[i] !== 'x' && st[i] !== 'X') continue;
      let n = 1;
      while (i + n < 16 && st[i + n] === '-') n++;
      const t = bar * BAR + i * S16;
      const long = n >= 3;
      const d = long ? n * S16 : S16 * 2;
      const ch = harmony(ctx, t, d);
      if (ch.nc) continue;
      prev = topNote(ch, ctx, prev, center, r, 0.3);
      const closing = isPhraseEnd(ctx, bar) && i === last;
      evs.push({ t, d, p: prev, kind: long ? 'long' : 'stab', acc: st[i] === 'X' || closing, shape: long ? 'fp' : undefined, end: closing, fall: closing && long && r.chance(0.5) });
    }
  }
  return { evs, mode: 'close' };
};

/** Two interleaved guide-tone lines shared out among the players. */
function guideSection(ctx: GenCtx, players: SectionPlayer[]): Part[] {
  const order = sortPlayers(players);
  const parts = new Map<SectionPlayer, Part>();
  order.forEach((pl, idx) => {
    const r = rangeOf(pl.inst, pl.ctx.shift);
    const b = new PB(pl.ctx);
    const rng = pl.ctx.rng.fork('guide');
    const oct = pl.ctx.params.octave * 12;
    const line = guideLine(ctx, r.lead - 3 + oct, r.cLo + oct, r.cHi + oct, idx % 2 === 0 ? '3' : '7');
    const evs: HornEv[] = line.map((n, i) => ({
      t: n.t,
      d: i % 2 === 1 || n.d >= BAR * 2 ? Math.max(BEAT, n.d - BEAT / 2) : n.d,
      p: n.p,
      kind: 'long',
      shape: rng.weighted(['natural', 'hairpin', 'swell'] as Shape[], [3, 2, 1.5]),
      start: true,
      end: i % 2 === 1,
    }));
    renderHorn(b, evs, { lead: idx === 0, section: true, low: r.cLo + 9 + oct });
    parts.set(pl, b.part());
  });
  return players.map((pl) => parts.get(pl)!);
}

// ------------------------------------------------------------------ solo recipes

function solo(kind: 'lead' | 'fills' | 'answer' | 'blues' | 'long' | 'bank', role: LineRole = 'lead') {
  return (ctx: GenCtx): Part => {
    const inst = ctx.inst as HornId;
    const r = rangeOf(inst, ctx.shift);
    const oct = ctx.params.octave * 12;
    const b = new PB(ctx);
    const rng = ctx.rng.fork('solo-ev');
    let evs: HornEv[];
    let uses: PhraseUse[] | undefined;
    if (kind === 'bank') {
      const got = bankLine(ctx, role, { lo: r.cLo + 2 + oct, hi: r.cHi + 3 + oct, center: r.lead + oct });
      evs = lineToEvs(got.notes, 0.25 + ctx.params.expression * 0.35, rng);
      uses = got.uses;
    } else if (kind === 'long') {
      const line = guideLine(ctx, r.lead + oct, r.cLo + oct, r.cHi + oct, rng.chance(0.5) ? '3' : '7');
      evs = line.map((n, i) => ({
        t: n.t,
        d: Math.max(BEAT, n.d - (i % 2 === 1 ? BEAT / 2 : 30)),
        p: n.p,
        kind: 'long' as const,
        shape: rng.weighted(['natural', 'hairpin', 'swell', 'dim'] as Shape[], [3, 2, 2, 1]),
        start: true,
        end: i % 2 === 1,
      }));
    } else {
      const line = soloLine(ctx, {
        lo: r.cLo + 2 + oct,
        hi: r.cHi + 3 + oct,
        center: r.lead + oct,
        blues: kind === 'blues',
        fills: kind === 'fills',
        answer: kind === 'answer',
        space: kind === 'lead' ? 0.14 : 0.05,
      });
      evs = lineToEvs(line, 0.25 + ctx.params.expression * 0.35, rng);
    }
    renderHorn(b, evs, { lead: true, section: false, low: r.cLo + 9 + oct });
    const part = b.part();
    if (uses) part.phrases = uses;
    return part;
  };
}

// ------------------------------------------------------------------ library

const ALL: StyleId[] = ['funk', 'soul', 'pop', 'rock', 'jazz', 'bossa', 'reggae', 'ballad', 'neosoul', 'afrobeat', 'blues'];

export const HORN_PATTERNS: PatternDef[] = [
  {
    id: 'hs.stabs',
    name: 'Section: Punch Stabs',
    family: 'horn',
    styles: ['funk', 'soul', 'pop', 'rock', 'jazz', 'afrobeat', 'blues', 'neosoul', 'bossa'],
    density: 2,
    role: 'rhythm',
    desc: 'Tight voiced hits on a syncopated figure, with a long fall-off note to close each phrase.',
    section: section(stabs),
  },
  {
    id: 'hs.pads',
    name: 'Section: Warm Pads',
    family: 'horn',
    styles: ALL,
    density: 1,
    role: 'pad',
    desc: 'Sustained open voicings that swell and fade, re-breathing every two bars.',
    section: section(pads),
  },
  {
    id: 'hs.swell',
    name: 'Section: Swell and Hit',
    family: 'horn',
    styles: ['funk', 'soul', 'pop', 'rock', 'afrobeat', 'neosoul', 'blues', 'jazz'],
    density: 1,
    role: 'rhythm',
    desc: 'A forte-piano crescendo through the bar that lands as a hit on the next downbeat.',
    section: section(swellHit),
  },
  {
    id: 'hs.riff',
    name: 'Section: Unison Riff',
    family: 'horn',
    styles: ['funk', 'afrobeat', 'soul', 'blues', 'rock', 'reggae', 'neosoul', 'pop'],
    density: 3,
    role: 'line',
    desc: 'Everyone on one pentatonic riff in octaves, re-fitted to each chord.',
    section: section(riff({})),
  },
  {
    id: 'hs.riffharm',
    name: 'Section: Harmonised Riff',
    family: 'horn',
    styles: ['funk', 'afrobeat', 'soul', 'blues', 'jazz', 'pop', 'bossa'],
    density: 3,
    role: 'line',
    desc: 'The riff voiced in close harmony under the lead.',
    section: section(riff({ harm: true })),
  },
  {
    id: 'hs.answers',
    name: 'Section: Call and Answer',
    family: 'horn',
    styles: ['funk', 'soul', 'blues', 'afrobeat', 'reggae', 'rock', 'pop', 'neosoul', 'jazz'],
    density: 1,
    role: 'line',
    desc: 'The section stays out for a bar, then answers in the next.',
    section: section(riff({ answer: true })),
  },
  {
    id: 'hs.offbeats',
    name: 'Section: Off-beat Pulses',
    family: 'horn',
    styles: ['reggae', 'afrobeat', 'pop'],
    density: 2,
    role: 'rhythm',
    desc: 'Short voiced notes on every off-beat.',
    section: section(offbeats),
  },
  {
    id: 'hs.guide',
    name: 'Section: Guide-tone Lines',
    family: 'horn',
    styles: ['jazz', 'bossa', 'ballad', 'neosoul', 'soul', 'pop'],
    density: 1,
    role: 'pad',
    desc: 'Slow lines trading thirds and sevenths, moving by step through the changes.',
    section: guideSection,
  },
  {
    id: 'hs.soli',
    name: 'Section: Soli',
    family: 'horn',
    styles: ['jazz', 'funk', 'soul', 'blues', 'bossa', 'afrobeat'],
    density: 3,
    role: 'line',
    desc: 'An improvised line with the whole section harmonised underneath.',
    section: section(soli),
  },
  {
    id: 'hs.hits',
    name: 'Section: Band Hits',
    family: 'horn',
    styles: ['funk', 'soul', 'pop', 'rock', 'jazz', 'bossa', 'afrobeat', 'blues', 'neosoul', 'reggae'],
    density: 2,
    role: 'rhythm',
    desc: 'The section lands on the accent figure the whole band shares, so horns, guitar and keys punch together.',
    section: section(bandHits),
  },
  {
    id: 'hs.bank',
    name: 'Section: Phrase bank riffs',
    family: 'horn',
    styles: ALL,
    density: 3,
    role: 'line',
    bank: true,
    desc: 'A riff built from bank phrases, played by the whole section in octaves. Swap any bar.',
    section: section(bankSection('riff', false)),
  },
  {
    id: 'hs.bankharm',
    name: 'Section: Phrase bank, harmonised',
    family: 'horn',
    styles: ALL,
    density: 3,
    role: 'line',
    bank: true,
    desc: 'Bank phrases voiced in close harmony under the lead horn.',
    section: section(bankSection('riff', true)),
  },
  {
    id: 'hs.bankanswer',
    name: 'Section: Phrase bank answers',
    family: 'horn',
    styles: ALL,
    density: 1,
    role: 'line',
    bank: true,
    desc: 'The section replies in the bars the band plan leaves for answers, and joins the tutti bars.',
    section: section(bankSection('answer', true)),
  },
  {
    id: 'h.banklead',
    name: 'Solo: Phrase bank lead',
    family: 'horn',
    styles: ALL,
    density: 3,
    role: 'line',
    bank: true,
    desc: 'Lead phrases dealt from the bank: statement, variation, contrast, tag. Speaks in the lead bars of the band plan.',
    gen: solo('bank', 'lead'),
  },
  {
    id: 'h.bankanswer',
    name: 'Solo: Phrase bank answers',
    family: 'horn',
    styles: ALL,
    density: 1,
    role: 'line',
    bank: true,
    desc: 'Replies from the bank in the bars a lead player leaves open.',
    gen: solo('bank', 'answer'),
  },
  {
    id: 'h.bankfills',
    name: 'Solo: Phrase bank fills',
    family: 'horn',
    styles: ALL,
    density: 1,
    role: 'line',
    bank: true,
    desc: 'Pickup phrases from the bank in the gaps.',
    gen: solo('bank', 'fills'),
  },
  {
    id: 'h.lead',
    name: 'Solo: Lead Line',
    family: 'horn',
    styles: ALL,
    density: 3,
    role: 'line',
    desc: 'Improvised phrases built from a motif: statement, repeat, contrast, cadence.',
    gen: solo('lead'),
  },
  {
    id: 'h.blues',
    name: 'Solo: Blues Licks',
    family: 'horn',
    styles: ['blues', 'funk', 'soul', 'rock', 'jazz', 'neosoul', 'reggae'],
    density: 3,
    role: 'line',
    desc: 'Blues-scale phrases that lean on blue notes and land on chord tones.',
    gen: solo('blues'),
  },
  {
    id: 'h.fills',
    name: 'Solo: Fills',
    family: 'horn',
    styles: ALL,
    density: 1,
    role: 'line',
    desc: 'Short pickups in the gaps at the end of every other bar.',
    gen: solo('fills'),
  },
  {
    id: 'h.answer',
    name: 'Solo: Answer Phrases',
    family: 'horn',
    styles: ALL,
    density: 2,
    role: 'line',
    desc: 'Rests for the first half of each phrase, then replies.',
    gen: solo('answer'),
  },
  {
    id: 'h.long',
    name: 'Solo: Long Tones',
    family: 'horn',
    styles: ['ballad', 'bossa', 'jazz', 'neosoul', 'soul', 'pop', 'reggae'],
    density: 1,
    role: 'pad',
    desc: 'A slow counter-melody with late vibrato and shaped dynamics.',
    gen: solo('long'),
  },
];

export function isSectionPattern(id: string): boolean {
  return id.startsWith('hs.');
}
