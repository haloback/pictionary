import type { Family, Part, StyleId } from './types';
import type { GenCtx } from './perf';

export type PatternRole = 'groove' | 'pad' | 'rhythm' | 'line';

export interface SectionPlayer {
  inst: 'trumpet' | 'alto' | 'tenor' | 'trombone' | 'bari' | 'flute';
  /** per-player context (own rng, params) */
  ctx: GenCtx;
}

export interface PatternDef {
  id: string;
  name: string;
  /** which instrument family this recipe belongs to ('perc' is its own lane) */
  family: Family | 'perc';
  styles: StyleId[] | '*';
  /** 1 sparse .. 3 busy */
  density: 1 | 2 | 3;
  role: PatternRole;
  desc: string;
  /** suggested instrument variant when this recipe is picked by the randomiser */
  variant?: string;
  /** recorded-drummer recipes: the dataset style they draw from */
  tag?: string;
  /** built from the phrase bank (supports per-bar swapping) */
  bank?: boolean;
  gen?: (ctx: GenCtx) => Part;
  /** horn section recipes voice all players at once */
  section?: (ctx: GenCtx, players: SectionPlayer[]) => Part[];
}

export function fitsStyle(p: PatternDef, style: StyleId): boolean {
  return p.styles === '*' || p.styles.includes(style);
}
