// Small deterministic random generator so every take can be recalled from its seed.

export function hashStr(s: string): number {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export class RNG {
  private s: number;
  readonly seed: number;
  constructor(seed: number) {
    this.seed = seed >>> 0 || 0x9e3779b9;
    this.s = this.seed;
  }
  /** float in [0,1) */
  f(): number {
    let t = (this.s += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  /** integer in [lo, hi] inclusive */
  int(lo: number, hi: number): number {
    return lo + Math.floor(this.f() * (hi - lo + 1));
  }
  range(lo: number, hi: number): number {
    return lo + this.f() * (hi - lo);
  }
  chance(p: number): boolean {
    return this.f() < p;
  }
  pick<T>(arr: readonly T[]): T {
    return arr[Math.floor(this.f() * arr.length)];
  }
  weighted<T>(items: readonly T[], weights: readonly number[]): T {
    let total = 0;
    for (const w of weights) total += Math.max(0, w);
    if (total <= 0) return items[0];
    let r = this.f() * total;
    for (let i = 0; i < items.length; i++) {
      r -= Math.max(0, weights[i]);
      if (r <= 0) return items[i];
    }
    return items[items.length - 1];
  }
  /** approx. gaussian, mean 0, sd 1 */
  gauss(): number {
    return (this.f() + this.f() + this.f() + this.f() - 2) * 1.732;
  }
  shuffle<T>(arr: readonly T[]): T[] {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(this.f() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }
  /** independent child stream */
  fork(label: string | number): RNG {
    return new RNG((Math.imul(this.seed, 2654435761) ^ hashStr(String(label))) >>> 0);
  }
}

export function newSeed(): number {
  return (Math.floor(Math.random() * 0xffffffff) >>> 0) || 1;
}
