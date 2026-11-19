// Playable guitar voicings found by searching the fretboard, so strummed parts
// use the shapes (and string order) a real player would.

import type { Chord } from './types';
import { chordIntervals, mod12 } from './theory';
import type { RNG } from './rng';

export const TUNING = [40, 45, 50, 55, 59, 64];
export type VoicingKind = 'full' | 'top4' | 'triad' | 'shell' | 'power';

export interface Voicing {
  /** fret per string, low E first; -1 = not played */
  frets: number[];
  /** indices of played strings, low to high */
  strings: number[];
  /** sounding pitch per played string, same order as `strings` */
  pitches: number[];
  /** average fretted position */
  pos: number;
  score: number;
}

function fingers(frets: number[]): number {
  const fretted = frets.map((f, s) => ({ f, s })).filter((x) => x.f > 0);
  if (!fretted.length) return 0;
  const hasOpen = frets.some((f) => f === 0);
  const minF = Math.min(...fretted.map((x) => x.f));
  let count = 0;
  let barre = false;
  let prev: { f: number; s: number } | null = null;
  for (const x of fretted) {
    if (x.f === minF && !hasOpen) {
      if (!barre) count++;
      barre = true;
      prev = null;
      continue;
    }
    if (prev && prev.f === x.f && x.s === prev.s + 1) {
      prev = x;
      continue;
    }
    count++;
    prev = x;
  }
  return count;
}

function make(frets: number[]): Voicing {
  const strings: number[] = [];
  const pitches: number[] = [];
  let sum = 0;
  let n = 0;
  frets.forEach((f, s) => {
    if (f < 0) return;
    strings.push(s);
    pitches.push(TUNING[s] + f);
    if (f > 0) {
      sum += f;
      n++;
    }
  });
  return { frets: frets.slice(), strings, pitches, pos: n ? sum / n : 0, score: 0 };
}

const cache = new Map<string, Voicing[]>();

function search(chord: Chord, kind: VoicingKind): Voicing[] {
  const key = chord.sym + '|' + kind;
  const hit = cache.get(key);
  if (hit) return hit;
  const out: Voicing[] = [];
  const ivs = chordIntervals(chord);
  const allowed = new Set(ivs.map((i) => mod12(chord.root + i)));
  allowed.add(chord.bass);
  const rootPc = chord.root;
  const thirdPc = chord.third != null ? mod12(rootPc + chord.third) : chord.sus != null ? mod12(rootPc + chord.sus) : null;
  const seventhPc = chord.seventh != null ? mod12(rootPc + chord.seventh) : chord.sixth ? mod12(rootPc + 9) : null;
  const fifthPc = chord.fifth != null ? mod12(rootPc + chord.fifth) : null;
  const tensionPcs = chord.tensions.map((t) => mod12(rootPc + t));

  if (kind === 'power' || chord.nc) {
    let s = 0;
    let f = mod12(chord.bass - TUNING[0]);
    if (f > 8) {
      s = 1;
      f = mod12(chord.bass - TUNING[1]);
    }
    const frets = [-1, -1, -1, -1, -1, -1];
    frets[s] = f;
    frets[s + 1] = f + 2;
    frets[s + 2] = f + 2;
    const v = make(frets);
    cache.set(key, [v]);
    return [v];
  }

  const essential: number[] = [];
  if (thirdPc != null) essential.push(thirdPc);
  if (seventhPc != null) essential.push(seventhPc);
  if (kind === 'full') {
    essential.push(chord.bass);
    if (seventhPc == null && fifthPc != null) essential.push(fifthPc);
  }
  if ((kind === 'top4' || kind === 'triad') && seventhPc == null) essential.push(rootPc);

  const frets = [-1, -1, -1, -1, -1, -1];
  const firstString = kind === 'top4' ? 2 : kind === 'triad' ? 3 : 0;
  const lastString = kind === 'shell' ? 4 : 5;

  const evaluate = (base: number) => {
    const v = make(frets);
    const n = v.strings.length;
    if (n < 3) return;
    const pcs = v.pitches.map(mod12);
    for (const e of essential) if (!pcs.includes(e)) return;
    if (fingers(frets) > 4) return;
    const lo = v.strings[0];
    const hi = v.strings[n - 1];
    const contiguous = hi - lo + 1 === n;
    let score = 0;
    if (kind === 'full') {
      if (!contiguous || n < 4 || hi < 4) return;
      if (pcs[0] !== chord.bass) return;
      score += (n - 4) * 3 + (hi === 5 ? 2 : 0);
      if (v.pos <= 3) score += 4;
      if (frets.some((f) => f === 0) && v.pos <= 3) score += 1.5;
      score -= v.pos * 0.35;
    } else if (kind === 'top4') {
      if (!contiguous || n < 3 || hi < 4) return;
      score += (n === 4 ? 2 : 0) - Math.abs(v.pos - 7) * 0.5;
      if (frets.some((f) => f === 0)) score -= 3;
    } else if (kind === 'triad') {
      if (n !== 3) return;
      score -= Math.abs(v.pos - 8) * 0.45;
      if (frets.some((f) => f === 0)) score -= 3;
    } else if (kind === 'shell') {
      if (lo > 1 || n > 4) return;
      if (pcs[0] !== chord.bass) return;
      // root on 6: skip the A string; root on 5: next strings adjacent
      const rest = v.strings.slice(1);
      if (lo === 0 && rest[0] !== 2) return;
      if (lo === 1 && rest[0] !== 2) return;
      for (let i = 1; i < rest.length; i++) if (rest[i] !== rest[i - 1] + 1) return;
      score += (n === 4 ? 1 : 0) - Math.abs(frets[lo] - 5) * 0.3;
      if (frets.some((f) => f === 0)) score -= 2;
    }
    const thirds = thirdPc != null ? pcs.filter((p) => p === thirdPc).length : 0;
    if (thirds > 1) score -= (thirds - 1) * 1.2;
    score += tensionPcs.filter((p) => pcs.includes(p)).length * 1.8;
    if (fifthPc != null && pcs.includes(fifthPc)) score += 0.5;
    score += new Set(pcs).size * 0.6;
    void base;
    v.score = score;
    out.push(v);
  };

  const dfs = (s: number, base: number) => {
    if (s > lastString) {
      evaluate(base);
      return;
    }
    if (s < firstString) {
      frets[s] = -1;
      dfs(s + 1, base);
      return;
    }
    frets[s] = -1;
    dfs(s + 1, base);
    if (base <= 2 && allowed.has(mod12(TUNING[s]))) {
      frets[s] = 0;
      dfs(s + 1, base);
    }
    for (let f = Math.max(1, base); f <= base + 3; f++) {
      if (!allowed.has(mod12(TUNING[s] + f))) continue;
      frets[s] = f;
      dfs(s + 1, base);
    }
    frets[s] = -1;
  };
  for (let base = 0; base <= 12; base++) dfs(0, base);

  // de-duplicate (same shape reached from several windows)
  const seen = new Set<string>();
  const uniq = out.filter((v) => {
    const k = v.frets.join(',');
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
  uniq.sort((a, b) => b.score - a.score);
  const res = uniq.slice(0, 40);
  cache.set(key, res);
  return res;
}

/** Best voicing for a chord, staying close to the previous hand position. */
export function pickVoicing(chord: Chord, kind: VoicingKind, prev: Voicing | null, rng: RNG): Voicing {
  let list = search(chord, kind);
  if (!list.length && kind === 'full') list = search(chord, 'shell');
  if (!list.length) list = search(chord, 'top4');
  if (!list.length) list = search(chord, 'triad');
  if (!list.length) list = search(chord, 'power');
  const scored = list.map((v) => {
    let s = v.score;
    if (prev) {
      s -= Math.abs(v.pos - prev.pos) * (kind === 'full' ? 0.5 : 0.8);
      const top = v.pitches[v.pitches.length - 1];
      const ptop = prev.pitches[prev.pitches.length - 1];
      if (kind !== 'full') s -= Math.abs(top - ptop) * 0.35;
    }
    return { v, s };
  });
  scored.sort((a, b) => b.s - a.s);
  if (scored.length > 1 && scored[0].s - scored[1].s < 1.2 && rng.chance(0.3)) return scored[1].v;
  return scored[0].v;
}

export function fretString(v: Voicing): string {
  return v.frets.map((f) => (f < 0 ? 'x' : String(f))).join(v.frets.some((f) => f > 9) ? '-' : '');
}
