// Recorded drummer: real grooves and fills from the Groove MIDI Dataset
// (CC BY 4.0), chosen to suit the tempo, swing and busyness asked for, then
// re-fitted to the project's feel. Timing and velocity are as the drummers
// played them.

import bank from './data/groove.json';
import { BAR, S16 } from './types';
import type { Part } from './types';
import { PB, isPhraseEnd, makeUnwarp, makeWarp } from './perf';
import type { Feel, GenCtx, Groove } from './perf';
import { clamp } from './theory';
import type { PatternDef } from './patterns';
import type { StyleId } from './types';

interface Hit {
  /** ticks from the bar line (can be slightly negative) */
  p: number;
  /** General MIDI drum note */
  v: number;
  vel: number;
}
interface Rec {
  s: string;
  b: number;
  d: number;
  f?: number;
  n: number;
  w8?: number;
  w16?: number;
  h: string;
  bars?: Hit[][];
}
const DATA = bank as unknown as { source: string; voices: number[]; early: number; grooves: Rec[]; fills: Rec[] };
export const GROOVE_SOURCE = DATA.source;
export const GROOVE_COUNTS = { grooveBars: DATA.grooves.length * 4, fills: DATA.fills.length };

function decode(r: Rec): Hit[][] {
  if (r.bars) return r.bars;
  const bin = typeof atob === 'function' ? atob(r.h) : Buffer.from(r.h, 'base64').toString('binary');
  const out: Hit[][] = [];
  let i = 0;
  while (i < bin.length) {
    const n = bin.charCodeAt(i++);
    const hits: Hit[] = [];
    for (let k = 0; k < n; k++) {
      const b0 = bin.charCodeAt(i++);
      const b1 = bin.charCodeAt(i++);
      const b2 = bin.charCodeAt(i++);
      hits.push({ p: ((b0 << 3) | (b1 >> 5)) - DATA.early, v: DATA.voices[(b1 >> 1) & 15], vel: ((b1 & 1) << 6) | (b2 >> 2) });
    }
    out.push(hits);
  }
  r.bars = out;
  return out;
}

const SWUNG = new Set(['jazz', 'blues']);
/** The feel a recording was played with, as far as the hats and ride reveal it. */
function feelOf(r: Rec, grid: 8 | 16): Feel {
  const w = grid === 8 ? r.w8 : r.w16;
  if (w == null || w < 0) return { swing: grid === 8 && SWUNG.has(r.s) ? 0.55 : 0, grid };
  return { swing: w / 100, grid };
}

function liveDrums(ctx: GenCtx, tag: string): { part: Part; groove: Groove } {
  const b = new PB(ctx);
  const rng = ctx.rng.fork('live');
  const cx = ctx.params.complexity;
  const groove: Groove = { kicks: [], snares: [] };
  let pool = DATA.grooves.filter((g) => g.s === tag);
  if (!pool.length) pool = DATA.grooves;
  const dens = pool.map((g) => g.n).sort((x, y) => x - y);
  const pct = (n: number) => dens.findIndex((d) => d >= n) / Math.max(1, dens.length - 1);
  const target = ctx.feel.swing;
  const weigh = (g: Rec) => {
    const tempo = Math.exp(-Math.abs(Math.log2(g.b / ctx.tempo)) * 3);
    const sw = Math.exp(-Math.abs(feelOf(g, ctx.feel.grid).swing - target) * 4);
    const busy = Math.exp(-Math.abs(pct(g.n) - (0.15 + cx * 0.7)) * 2.2);
    return tempo * sw * busy + 1e-6;
  };
  // deal from the best-fitting third so a take is both suitable and varied
  const ranked = pool.map((g) => ({ g, w: weigh(g) })).sort((x, y) => y.w - x.w);
  const short = ranked.slice(0, Math.max(4, Math.ceil(ranked.length / 3)));
  const a = rng.weighted(
    short.map((x) => x.g),
    short.map((x) => x.w),
  );
  // a second chunk of the same performance for the back half of each eight bars
  const siblings = pool.filter((g) => g.f === a.f && g !== a);
  const second = siblings.length ? rng.pick(siblings) : a;

  let fills = DATA.fills.filter((f) => f.s === tag);
  if (fills.length < 6) fills = DATA.fills.filter((f) => f.s === tag || Math.abs(Math.log2(f.b / a.b)) < 0.25);
  const sameDrummer = fills.filter((f) => f.d === a.d);
  if (sameDrummer.length >= 6) fills = sameDrummer;

  const hum = clamp(ctx.params.humanize * 2, 0, 1);
  const velScale = (0.6 + 0.55 * ctx.params.dynamics) * (0.92 + 0.14 * ctx.energy);
  const projWarp = makeWarp(ctx.feel);

  const emit = (rec: Rec, hits: Hit[], bar: number, from = -9999, to = 9999) => {
    const own = feelOf(rec, ctx.feel.grid);
    const un = makeUnwarp(own);
    const rewarp = Math.abs(own.swing - ctx.feel.swing) > 0.08;
    for (const h of hits) {
      if (h.p < from || h.p >= to) continue;
      const straight = un(h.p);
      const q = Math.round(straight / S16) * S16;
      // humanize below half pulls the hit towards the grid; at half and above it is as played
      const pos = q + (straight - q) * hum;
      const t = bar * BAR + (rewarp || hum < 1 ? projWarp(pos) : h.p);
      if (t < -40 || t >= ctx.len) continue;
      b.notes.push({ t: Math.round(t), d: 60, p: h.v, v: clamp(Math.round(h.vel * velScale), 1, 127) });
      const gridT = bar * BAR + clamp(q, 0, BAR - S16);
      if (h.v === 36 && h.vel > 40 && !groove.kicks.includes(gridT)) groove.kicks.push(gridT);
      if (h.v === 38 && h.vel > 75 && !groove.snares.includes(gridT)) groove.snares.push(gridT);
    }
  };

  let crashNext = ctx.bars >= 4;
  for (let bar = 0; bar < ctx.bars; bar++) {
    const rec = Math.floor(bar / 4) % 2 === 1 ? second : a;
    const bars = decode(rec);
    const hits = bars[bar % 4] ?? bars[0];
    const r = rng.fork('bar' + bar);
    const big = (bar + 1) % (ctx.phrase * 2) === 0 || bar === ctx.bars - 1;
    const wantFill = isPhraseEnd(ctx, bar) && ctx.bars > 1 && fills.length > 0 && r.chance(0.35 + cx * 0.35 + ctx.energy * 0.15 + (big ? 0.2 : 0));
    const startsWithCrash = hits.some((h) => (h.v === 49 || h.v === 57) && h.p < 100);
    if (crashNext && !startsWithCrash) {
      b.notes.push({ t: bar * BAR, d: 60, p: 49, v: clamp(Math.round(104 * velScale), 1, 127) });
      if (!hits.some((h) => h.v === 36 && h.p < 100)) b.notes.push({ t: bar * BAR, d: 60, p: 36, v: clamp(Math.round(102 * velScale), 1, 127) });
    }
    crashNext = false;
    if (wantFill) {
      const fr = r.weighted(
        fills,
        fills.map((f) => Math.exp(-Math.abs(Math.log2(f.b / ctx.tempo)) * 2.5) * Math.exp(-Math.abs(f.n / 24 - (0.3 + cx * 0.5 + (big ? 0.2 : 0))) * 1.5)),
      );
      const fh = decode(fr)[0];
      // the groove carries on until the fill's first stroke
      const first = Math.max(0, Math.min(...fh.filter((h) => h.v !== 42 && h.v !== 44 && h.v !== 51).map((h) => h.p), BAR));
      const cut = Math.min(first, BAR / 2 + (big ? 0 : BAR / 4)) - 30;
      emit(rec, hits, bar, -9999, cut);
      emit(fr, fh, bar, cut);
      crashNext = bar + 1 < ctx.bars;
    } else emit(rec, hits, bar);
  }
  groove.kicks.sort((x, y) => x - y);
  return { part: b.part(), groove };
}

const LIVE: { tag: string; name: string; styles: StyleId[]; density: 1 | 2 | 3 }[] = [
  { tag: 'funk', name: 'Funk', styles: ['funk', 'neosoul', 'afrobeat', 'soul'], density: 3 },
  { tag: 'soul', name: 'Soul', styles: ['soul', 'neosoul', 'pop', 'ballad', 'funk'], density: 2 },
  { tag: 'rock', name: 'Rock', styles: ['rock', 'pop', 'blues', 'ballad'], density: 2 },
  { tag: 'pop', name: 'Pop', styles: ['pop', 'ballad', 'soul', 'rock'], density: 2 },
  { tag: 'jazz', name: 'Jazz', styles: ['jazz', 'blues'], density: 2 },
  { tag: 'hiphop', name: 'Hip-hop', styles: ['neosoul', 'funk', 'soul'], density: 2 },
  { tag: 'latin', name: 'Latin', styles: ['bossa'], density: 2 },
  { tag: 'afrocuban', name: 'Afro-Cuban', styles: ['bossa', 'afrobeat'], density: 3 },
  { tag: 'afrobeat', name: 'Afrobeat', styles: ['afrobeat', 'funk'], density: 3 },
  { tag: 'highlife', name: 'Highlife', styles: ['afrobeat'], density: 2 },
  { tag: 'neworleans', name: 'New Orleans', styles: ['funk', 'blues', 'jazz', 'soul'], density: 3 },
  { tag: 'reggae', name: 'Reggae', styles: ['reggae'], density: 2 },
  { tag: 'blues', name: 'Blues', styles: ['blues'], density: 2 },
  { tag: 'gospel', name: 'Gospel', styles: ['soul'], density: 2 },
  { tag: 'country', name: 'Country', styles: ['pop', 'rock'], density: 2 },
  { tag: 'punk', name: 'Punk', styles: ['rock'], density: 3 },
  { tag: 'dance', name: 'Dance', styles: ['funk', 'pop'], density: 2 },
];

export const LIVE_DRUM_PATTERNS: PatternDef[] = LIVE.map((l) => {
  const n = DATA.grooves.filter((g) => g.s === l.tag).length * 4;
  const f = DATA.fills.filter((x) => x.s === l.tag).length;
  return {
    id: 'dl.' + l.tag,
    name: `Recorded: ${l.name}`,
    family: 'drums',
    styles: l.styles,
    density: l.density,
    role: 'groove',
    tag: l.tag,
    desc: `A real drummer's ${l.name.toLowerCase()} playing: ${n} recorded bars${f ? ` and ${f} fills` : ''} to draw from, with their own timing and touch.`,
    gen: (ctx) => liveDrums(ctx, l.tag).part,
  };
});

export function liveGrooveFor(patternId: string, ctx: GenCtx): Groove | null {
  const l = LIVE.find((x) => 'dl.' + x.tag === patternId);
  return l ? liveDrums(ctx, l.tag).groove : null;
}
