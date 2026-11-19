// Shared performance helpers: generation context, swing warp, humanised part builder.

import { BAR, PPQ } from './types';
import type { Art, Bend, ChordSpan, Ctrl, CtrlKind, InstId, Key, Note, Part, StyleId, TrackParams } from './types';
import { RNG } from './rng';
import { clamp } from './theory';

export interface Groove {
  /** grid ticks of kick drum hits */
  kicks: number[];
  /** grid ticks of backbeat snare hits */
  snares: number[];
}

export interface Feel {
  /** 0 = straight, 1 = full triplet swing */
  swing: number;
  /** which subdivision swings */
  grid: 8 | 16;
}

export interface GenCtx {
  spans: ChordSpan[];
  bars: number;
  len: number;
  key: Key;
  style: StyleId;
  feel: Feel;
  tempo: number;
  /** 0..1 global intensity */
  energy: number;
  params: TrackParams;
  rng: RNG;
  groove: Groove;
  inst: InstId;
  variant: string;
  /** bars per phrase (fills, breaths and crashes follow this) */
  phrase: number;
}

export function chordAt(ctx: { spans: ChordSpan[] }, t: number): ChordSpan {
  const sp = ctx.spans;
  let lo = 0;
  let hi = sp.length - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (sp[mid].t <= t) lo = mid;
    else hi = mid - 1;
  }
  return sp[lo];
}
/** The next span (strictly after t) where the harmony actually changes. Wraps to the top for loops. */
export function nextChange(ctx: { spans: ChordSpan[]; len: number }, t: number): { span: ChordSpan; t: number } {
  for (const s of ctx.spans) if (s.t > t && s.change) return { span: s, t: s.t };
  return { span: ctx.spans[0], t: ctx.len };
}
/** Contiguous segments of unchanged harmony. */
export function segments(ctx: { spans: ChordSpan[]; len: number }): ChordSpan[] {
  const out: ChordSpan[] = [];
  for (const s of ctx.spans) {
    const last = out[out.length - 1];
    if (last && !s.change) last.d += s.d;
    else out.push({ ...s });
  }
  return out;
}

export function makeWarp(feel: Feel): (t: number) => number {
  if (feel.swing <= 0.001) return (t) => t;
  const unit = feel.grid === 8 ? PPQ : PPQ / 2;
  const half = unit / 2;
  const shift = (feel.swing * unit) / 6;
  return (t: number) => {
    const base = Math.floor(t / unit) * unit;
    const x = t - base;
    return base + (x < half ? (x * (half + shift)) / half : half + shift + ((x - half) * (half - shift)) / half);
  };
}

export interface NoteOpts {
  art?: Art;
  /** extra offset in ticks, applied after swing */
  off?: number;
  /** treat `d` as absolute ticks instead of grid length */
  abs?: boolean;
  /** skip velocity humanising */
  raw?: boolean;
}

export class PB {
  notes: Note[] = [];
  ctrl: Ctrl[] = [];
  bends: Bend[] = [];
  readonly w: (t: number) => number;
  /** ticks per millisecond */
  readonly tpm: number;
  private readonly hum: number;
  private readonly velScale: number;
  readonly rng: RNG;

  constructor(readonly ctx: GenCtx) {
    this.w = makeWarp(ctx.feel);
    this.tpm = (ctx.tempo * PPQ) / 60000;
    this.hum = ctx.params.humanize * 2;
    this.velScale = (0.6 + 0.55 * ctx.params.dynamics) * (0.92 + 0.14 * ctx.energy);
    this.rng = ctx.rng.fork('perf');
  }

  ms(ms: number): number {
    return ms * this.tpm;
  }
  /** random timing offset in ticks with the given standard deviation in ms */
  jit(ms: number): number {
    return this.rng.gauss() * ms * this.tpm * this.hum;
  }
  /** humanised, dynamics-scaled velocity */
  vel(v: number, spread = 5): number {
    return clamp(Math.round(v * this.velScale + this.rng.gauss() * spread * this.hum), 1, 127);
  }

  note(t: number, d: number, p: number, v: number, o: NoteOpts = {}): Note {
    const off = o.off ?? 0;
    const start = this.w(t) + off;
    const end = o.abs ? start + d : this.w(t + d) + off;
    const n: Note = {
      t: Math.round(start),
      d: Math.max(8, Math.round(end - start)),
      p: clamp(Math.round(p), 0, 127),
      v: o.raw ? clamp(Math.round(v), 1, 127) : this.vel(v),
    };
    if (o.art && o.art !== 'sustain') n.art = o.art;
    this.notes.push(n);
    return n;
  }
  c(k: CtrlKind, t: number, v: number, off = 0): void {
    this.ctrl.push({ t: Math.round(this.w(t) + off), k, v: clamp(v, 0, 1) });
  }
  /** same as c() but the time is already final (post-swing) */
  cAbs(k: CtrlKind, t: number, v: number): void {
    this.ctrl.push({ t: Math.round(t), k, v: clamp(v, 0, 1) });
  }
  bendAbs(t: number, s: number): void {
    this.bends.push({ t: Math.round(t), s });
  }
  /** ramp a controller between two absolute times; shape > 1 eases in, < 1 eases out */
  rampAbs(k: CtrlKind, t0: number, t1: number, v0: number, v1: number, shape = 1, step = 30): void {
    const n = Math.max(1, Math.round((t1 - t0) / step));
    for (let i = 0; i <= n; i++) {
      const x = i / n;
      this.cAbs(k, t0 + (t1 - t0) * x, v0 + (v1 - v0) * Math.pow(x, shape));
    }
  }
  bendRampAbs(t0: number, t1: number, s0: number, s1: number, shape = 1, step = 12): void {
    const n = Math.max(1, Math.round((t1 - t0) / step));
    for (let i = 0; i <= n; i++) {
      const x = i / n;
      this.bendAbs(t0 + (t1 - t0) * x, s0 + (s1 - s0) * Math.pow(x, shape));
    }
  }
  part(): Part {
    return { notes: this.notes, ctrl: this.ctrl, bends: this.bends };
  }
}

/** Sort, clamp to the song length and remove same-pitch overlaps so any synth plays it cleanly. */
export function finalize(part: Part, len: number): Part {
  let notes = part.notes
    .filter((n) => n.t < len - 4 && n.t + n.d > 0)
    .map((n) => {
      const t = Math.max(0, n.t);
      const end = Math.min(len, n.t + n.d);
      return { ...n, t, d: Math.max(6, end - t), v: clamp(Math.round(n.v), 1, 127) };
    })
    .sort((a, b) => a.t - b.t || a.p - b.p);

  // same pitch must not overlap itself
  const lastByPitch = new Map<number, Note>();
  const drop = new Set<Note>();
  for (const n of notes) {
    const prev = lastByPitch.get(n.p);
    if (prev) {
      if (prev.t === n.t) {
        // identical onset: keep the louder / longer one
        if (n.v > prev.v) prev.v = n.v;
        if (n.d > prev.d) prev.d = n.d;
        drop.add(n);
        continue;
      }
      if (n.t - prev.t < 12) {
        // a re-strike this close is the same hit: keep one
        if (n.v > prev.v) prev.v = n.v;
        prev.d = Math.max(prev.d, n.t + n.d - prev.t);
        drop.add(n);
        continue;
      }
      if (prev.t + prev.d > n.t - 2) prev.d = n.t - prev.t - 2;
    }
    lastByPitch.set(n.p, n);
  }
  notes = notes.filter((n) => !drop.has(n));

  const clampT = (t: number) => clamp(t, 0, len - 1);
  const ctrl = part.ctrl
    .map((c) => ({ ...c, t: clampT(c.t) }))
    .sort((a, b) => a.t - b.t);
  const bends = part.bends
    .map((b) => ({ ...b, t: clampT(b.t) }))
    .sort((a, b) => a.t - b.t);
  return { notes, ctrl, bends };
}

/** Parse a 16-step pattern string; "|" and spaces are cosmetic. */
export function steps(s: string): string[] {
  const out = s.replace(/[|\s]/g, '').split('');
  while (out.length < 16) out.push('.');
  return out.slice(0, 16);
}

/** Metric weight of a sixteenth step: 3 = downbeat, 2 = beat, 1 = eighth, 0 = sixteenth. */
export function stepWeight(i: number): number {
  if (i % 16 === 0) return 3;
  if (i % 4 === 0) return 2;
  if (i % 2 === 0) return 1;
  return 0;
}

export function barOf(t: number): number {
  return Math.floor(t / BAR);
}

/** Is `bar` the last bar of a phrase? */
export function isPhraseEnd(ctx: GenCtx, bar: number): boolean {
  return (bar + 1) % ctx.phrase === 0 || bar === ctx.bars - 1;
}
