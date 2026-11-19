// Keyboard / ensemble voicing helpers with voice leading.

import type { Chord, Key } from './types';
import { mod12, roleInterval, scaleFor } from './theory';

/**
 * Which intervals to play for a chord.
 *   rich 0: plain chord tones (pop)
 *   rich 1: third, fifth, seventh plus a ninth where it fits (soul, funk)
 *   rich 2: rootless jazz voicing (3, 5/13, 7, 9)
 */
export function colorIntervals(ch: Chord, key: Key, rich: 0 | 1 | 2): number[] {
  if (ch.nc) return [];
  const scale = scaleFor(ch, key);
  const third = ch.third ?? ch.sus ?? 7;
  const fifth = ch.fifth ?? (ch.tensions.includes(8) ? 8 : 6);
  const has7 = ch.seventh != null || ch.sixth;
  const seventh = ch.seventh ?? 9;
  const explicit9 = ch.tensions.find((t) => t === 1 || t === 2 || t === 3);
  const nine = explicit9 ?? (scale.includes(2) ? 2 : null);
  const thirteen = ch.tensions.includes(9) ? 9 : ch.tensions.includes(8) ? 8 : null;
  const extra = ch.tensions.filter((t) => t === 5 || t === 6);

  if (ch.quality === 'power') return [0, 7];
  if (rich === 0) {
    const out = [0, third];
    if (ch.fifth != null) out.push(ch.fifth);
    if (has7) out.push(seventh);
    for (const t of ch.tensions) if (!out.includes(t)) out.push(t);
    // five or more notes: drop the root, then the fifth
    if (out.length > 4) out.splice(0, 1);
    if (out.length > 4 && ch.fifth != null) out.splice(out.indexOf(ch.fifth), 1);
    return out;
  }
  if (!has7) {
    // triads: keep them honest, add a ninth for colour on the richer settings
    const out = [0, third, fifth];
    for (const t of ch.tensions) if (!out.includes(t)) out.push(t);
    if (rich === 2 && nine != null && ch.third != null && !out.includes(nine)) out.push(nine);
    return out;
  }
  if (ch.quality === 'dim') return [0, 3, 6, 9];
  if (ch.quality === 'hdim') return [3, 6, 10, rich === 2 && scale.includes(5) ? 5 : 0];
  const out: number[] = [third];
  if (ch.quality === 'dom' || (ch.quality === 'sus' && ch.seventh === 10)) {
    if (thirteen != null) out.push(thirteen);
    else if (rich === 2 && ch.fifth === 7 && scale.includes(9)) out.push(9);
    else out.push(fifth);
  } else out.push(fifth);
  out.push(seventh);
  if (nine != null) out.push(nine);
  else out.push(0);
  for (const t of extra) if (!out.includes(t) && out.length < 5) out.push(t);
  return out;
}

/**
 * Place pitch classes in close position, choosing the inversion and octave that
 * moves least from the previous voicing (or sits nearest `center` when there is none).
 */
export function voiceLead(pcs: number[], prev: number[] | null, center: number, lo: number, hi: number): number[] {
  const set = [...new Set(pcs.map(mod12))];
  if (!set.length) return [];
  let best: number[] = [];
  let bestScore = Infinity;
  for (const bottomPc of set) {
    for (let oct = 2; oct <= 6; oct++) {
      const bottom = oct * 12 + bottomPc;
      if (bottom < lo) continue;
      const v = [bottom];
      const rest = set.filter((p) => p !== bottomPc).map((p) => bottom + mod12(p - bottomPc));
      rest.sort((a, b) => a - b);
      v.push(...rest);
      const top = v[v.length - 1];
      if (top > hi) continue;
      const mean = v.reduce((a, b) => a + b, 0) / v.length;
      let score = Math.abs(mean - center) * 0.6;
      if (prev && prev.length) {
        const ptop = prev[prev.length - 1];
        score += Math.abs(top - ptop) * 1.6;
        for (const n of v) score += Math.min(...prev.map((p) => Math.abs(p - n))) * 0.5;
      }
      // avoid muddy seconds at the bottom and a semitone rub under the top voice
      if (v.length > 1 && v[1] - v[0] <= 2 && v[0] < 58) score += 3;
      if (v.length > 2 && top - v[v.length - 2] === 1) score += 7;
      if (score < bestScore) {
        bestScore = score;
        best = v;
      }
    }
  }
  if (!best.length) {
    // range too tight: fall back to stacking from lo
    const b0 = lo + mod12(set[0] - lo);
    best = [b0, ...set.slice(1).map((p) => b0 + mod12(p - set[0]))].sort((a, b) => a - b);
  }
  return best;
}

export function chordVoicing(ch: Chord, key: Key, rich: 0 | 1 | 2, prev: number[] | null, center: number, lo = 50, hi = 81): number[] {
  const ivs = colorIntervals(ch, key, rich);
  return voiceLead(
    ivs.map((i) => ch.root + i),
    prev,
    center,
    lo,
    hi,
  );
}

export { roleInterval };
