// The translator: takes whatever key was hit and decides which note it
// should have been.
import type { Pool } from "./theory";
import { mod12 } from "./theory";

export interface SnapContext {
  pool: Pool;
  /** Pitches already sounding (or pending) in the same voice group. */
  sounding: number[];
  /** Raw and resolved pitch of every key currently held, to keep hand shape. */
  held: { raw: number; pitch: number }[];
  /** On a strong pulse, or in the middle of a fistful: lean on chord tones. */
  strong: boolean;
  smash: boolean;
  lo: number;
  hi: number;
}

/**
 * Pick the pitch nearest to `raw` that fits the harmony and does not collide
 * with what is already sounding. Costs are in semitones-ish units.
 */
export function snap(raw: number, ctx: SnapContext): number {
  const { pool, sounding, held, strong, smash, lo, hi } = ctx;
  let r = raw;
  while (r < lo) r += 12;
  while (r > hi) r -= 12;

  let best = -1;
  let bestCost = Infinity;
  for (let span = 7; span <= 19 && best < 0; span += 6) {
    for (let c = Math.max(lo, r - span); c <= Math.min(hi, r + span); c++) {
      const w = pool.weight[mod12(c)];
      if (w < 0) continue;
      let cost = Math.abs(c - r);
      if (w === 1) cost += strong || smash ? 2.2 : 0.7;
      else if (w === 2) cost += strong || smash ? 6 : 3;
      let blocked = false;
      for (const s of sounding) {
        const d = Math.abs(c - s);
        if (d === 0) {
          blocked = true;
          break;
        }
        if (d === 1) cost += 14;
        else if (d === 2) cost += smash ? 2.6 : 1;
        else if (d === 6) cost += 0.8;
      }
      if (blocked) continue;
      // A higher key should stay above a lower key.
      for (const h of held) {
        if (h.raw < raw && h.pitch >= c) cost += 4;
        else if (h.raw > raw && h.pitch <= c) cost += 4;
      }
      // Tiny downward bias keeps ties deterministic.
      if (c > r) cost += 0.01;
      if (cost < bestCost) {
        bestCost = cost;
        best = c;
      }
    }
  }
  if (best < 0) {
    // Everything nearby is taken: fall back to any free allowed pitch.
    for (let c = lo; c <= hi; c++) {
      if (pool.weight[mod12(c)] >= 0 && !sounding.includes(c)) {
        const cost = Math.abs(c - r);
        if (cost < bestCost) {
          bestCost = cost;
          best = c;
        }
      }
    }
  }
  return best < 0 ? r : best;
}

/** Nearest allowed pitch to `target` that is not an avoid note and not already used. */
export function nearestAllowed(rawTarget: number, pool: Pool, taken: number[], chordOnly = false): number {
  const target = Math.round(rawTarget);
  let best = -1;
  let bestCost = Infinity;
  for (let c = target - 6; c <= target + 6; c++) {
    const w = pool.weight[mod12(c)];
    if (w < 0 || w === 2 || (chordOnly && w !== 0)) continue;
    let cost = Math.abs(c - target) + w * 0.6;
    for (const t of taken) {
      const d = Math.abs(c - t);
      if (d === 0) cost += 50;
      else if (d === 1) cost += 6;
    }
    if (cost < bestCost) {
      bestCost = cost;
      best = c;
    }
  }
  if (best < 0) return chordOnly ? nearestAllowed(target, pool, taken, false) : target;
  return best;
}

/** Small deterministic PRNG so generated parts are reproducible in tests. */
export function mulberry32(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
