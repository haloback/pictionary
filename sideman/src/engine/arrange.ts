// Project model, arrangement generation and the smart randomiser.

import { BAR, DEFAULT_PARAMS } from './types';
import type { ChordSpan, InstId, Key, Part, StyleId, TrackParams } from './types';
import { RNG, hashStr, newSeed } from './rng';
import { expandChart, parseChart } from './chart';
import { detectKey } from './theory';
import { finalize } from './perf';
import type { Feel, GenCtx, Groove } from './perf';
import { grooveFor } from './drums';
import { isSectionPattern } from './horns';
import { getPattern, instDef, patternsFor, patternsForStyle, styleDef } from './library';
import type { PatternDef, SectionPlayer } from './patterns';
import { makeProfile, renderEvents, writeSMF } from './midi';
import type { MidiProfile, SmfTrack } from './midi';

export interface Track {
  id: string;
  inst: InstId;
  variant: string;
  patternId: string;
  seed: number;
  locked: boolean;
  mute: boolean;
  solo: boolean;
  /** preview volume 0..1 */
  gain: number;
  params: TrackParams;
  midi: MidiProfile;
}

export interface Project {
  name: string;
  chart: string;
  repeats: number;
  tempo: number;
  style: StyleId;
  /** null = use the style's swing */
  swing: number | null;
  key: Key | null;
  energy: number;
  /** shared seed for the horn section so the horns breathe together */
  sectionSeed: number;
  tracks: Track[];
}

export interface Arrangement {
  parts: Record<string, Part>;
  spans: ChordSpan[];
  key: Key;
  bars: number;
  len: number;
  errors: string[];
}

let idCounter = 0;
const uid = () => `t${Date.now().toString(36)}${(idCounter++).toString(36)}`;

function freeChannel(tracks: Track[], preferred: number): number {
  const used = new Set(tracks.map((t) => t.midi.channel));
  if (preferred === 10 || !used.has(preferred)) return preferred;
  for (let c = 1; c <= 16; c++) if (c !== 10 && !used.has(c)) return c;
  return preferred;
}

export function makeTrack(inst: InstId, style: StyleId, existing: Track[], rng: RNG = new RNG(newSeed())): Track {
  const def = instDef(inst);
  const pat = rng.pick(patternsForStyle(inst, style));
  const variant = pat.variant && def.variants.some((v) => v.id === pat.variant) ? pat.variant : def.variants[0].id;
  const program = def.variants.find((v) => v.id === variant)!.program;
  return {
    id: uid(),
    inst,
    variant,
    patternId: pat.id,
    seed: rng.int(1, 0x7fffffff),
    locked: false,
    mute: false,
    solo: false,
    gain: 0.8,
    params: { ...DEFAULT_PARAMS },
    midi: makeProfile(freeChannel(existing, def.channel), program),
  };
}

export function defaultProject(): Project {
  const rng = new RNG(20240607);
  const p: Project = {
    name: 'Untitled session',
    chart: 'Dm9 | G13 | Cmaj9 | A7#9',
    repeats: 2,
    tempo: 92,
    style: 'soul',
    swing: null,
    key: null,
    energy: 0.6,
    sectionSeed: 7411,
    tracks: [],
  };
  for (const inst of ['drums', 'bass', 'guitar', 'keys', 'trumpet', 'alto', 'tenor', 'trombone'] as InstId[]) {
    p.tracks.push(makeTrack(inst, p.style, p.tracks, rng.fork(inst)));
  }
  return smartRandomize(p, 99173);
}

export function feelOf(p: Project): Feel {
  const s = styleDef(p.style);
  return { swing: p.swing ?? s.swing, grid: s.grid };
}

/** Generate every part of the arrangement. Deterministic for a given project. */
export function generate(project: Project): Arrangement {
  const chart = parseChart(project.chart);
  const errors = chart.errors.slice();
  const parts: Record<string, Part> = {};
  if (!chart.bars.length) {
    for (const t of project.tracks) parts[t.id] = { notes: [], ctrl: [], bends: [] };
    return { parts, spans: [], key: project.key ?? { tonic: 0, minor: false }, bars: 0, len: 0, errors: errors.length ? errors : ['Type a chord progression to begin'] };
  }
  const spans = expandChart(chart, Math.max(1, project.repeats));
  const bars = chart.bars.length * Math.max(1, project.repeats);
  const len = bars * BAR;
  const key = project.key ?? detectKey(spans);
  const feel = feelOf(project);

  const baseCtx = (track: Track, seed: number): GenCtx => ({
    spans,
    bars,
    len,
    key,
    style: project.style,
    feel,
    tempo: project.tempo,
    energy: project.energy,
    params: track.params,
    rng: new RNG(seed),
    groove: { kicks: [], snares: [] },
    inst: track.inst,
    variant: track.variant,
    phrase: 4,
  });

  // the drummer sets the groove the bass locks to
  const drummer = project.tracks.find((t) => t.inst === 'drums');
  let groove: Groove = { kicks: [], snares: [] };
  if (drummer && getPattern(drummer.patternId)) groove = grooveFor(drummer.patternId, baseCtx(drummer, drummer.seed));
  else {
    const fallback = patternsForStyle('drums', project.style)[0];
    const ghost: Track = { ...(project.tracks[0] ?? makeTrack('drums', project.style, [])), inst: 'drums', params: { ...DEFAULT_PARAMS } };
    groove = grooveFor(fallback.id, baseCtx(ghost, 1234));
  }

  // horn sections: every horn on the same section recipe is voiced together
  const sections = new Map<string, Track[]>();
  for (const t of project.tracks) {
    const pat = getPattern(t.patternId) ?? patternsFor(t.inst)[0];
    if (pat.section && isSectionPattern(pat.id)) {
      if (!sections.has(pat.id)) sections.set(pat.id, []);
      sections.get(pat.id)!.push(t);
    } else {
      const ctx = baseCtx(t, t.seed);
      ctx.groove = groove;
      parts[t.id] = finalize(pat.gen!(ctx), len);
    }
  }
  for (const [pid, tracks] of sections) {
    const pat = getPattern(pid)!;
    const secSeed = (project.sectionSeed ^ hashStr(pid)) >>> 0;
    const lead = tracks[0];
    // section-level settings follow the average of its players
    const avg = (f: (p: TrackParams) => number) => tracks.reduce((a, t) => a + f(t.params), 0) / tracks.length;
    const secCtx = baseCtx(lead, secSeed);
    secCtx.params = { ...lead.params, complexity: avg((p) => p.complexity), expression: avg((p) => p.expression), octave: 0 };
    secCtx.groove = groove;
    const players: SectionPlayer[] = tracks.map((t) => {
      const c = baseCtx(t, (secSeed ^ hashStr(t.inst + t.id.length)) >>> 0);
      c.groove = groove;
      return { inst: t.inst as SectionPlayer['inst'], ctx: c };
    });
    const out = pat.section!(secCtx, players);
    tracks.forEach((t, i) => (parts[t.id] = finalize(out[i], len)));
  }
  return { parts, spans, key, bars, len, errors };
}

// ------------------------------------------------------------------ smart randomise

/** Recipes list their home style first; the randomiser leans towards those. */
function weightFor(p: PatternDef, energy: number, style?: StyleId): number {
  const home = style && p.styles !== '*' && p.styles[0] === style ? 2.6 : 1;
  return Math.max(0.25, 1 + (p.density - 2) * (energy - 0.5) * 1.6) * home;
}

const HORNS: InstId[] = ['trumpet', 'alto', 'tenor', 'trombone', 'bari'];
const isHorn = (i: InstId) => HORNS.includes(i);

function applyPattern(t: Track, pat: PatternDef, rng: RNG): Track {
  const def = instDef(t.inst);
  let variant = t.variant;
  let midi = t.midi;
  if (pat.variant && def.variants.some((v) => v.id === pat.variant)) {
    variant = pat.variant;
    midi = { ...midi, program: def.variants.find((v) => v.id === variant)!.program };
  }
  return { ...t, patternId: pat.id, seed: rng.int(1, 0x7fffffff), variant, midi };
}

/**
 * Re-deal the band. Unlocked tracks get a new recipe and a new take, chosen so
 * the parts complement each other: one busy comping instrument at a time, horns
 * that leave room for a soloist, density that follows the energy setting.
 */
export function smartRandomize(project: Project, seed: number = newSeed()): Project {
  const rng = new RNG(seed);
  const style = project.style;
  const en = project.energy;
  const tracks = project.tracks.map((t) => ({ ...t }));
  const out: Track[] = tracks.slice();
  const setTrack = (t: Track) => {
    out[out.findIndex((x) => x.id === t.id)] = t;
  };
  const pick = (inst: InstId, mod: (p: PatternDef) => number, filter?: (p: PatternDef) => boolean): PatternDef => {
    let pool = patternsForStyle(inst, style);
    if (filter) {
      const f = pool.filter(filter);
      if (f.length) pool = f;
      else {
        const g = patternsFor(inst).filter(filter);
        if (g.length) pool = g;
      }
    }
    return rng.weighted(
      pool,
      pool.map((p) => weightFor(p, en, style) * mod(p)),
    );
  };

  // rhythm section
  for (const t of tracks) {
    if (t.locked) continue;
    if (t.inst === 'drums' || t.inst === 'perc' || t.inst === 'bass') setTrack(applyPattern(t, pick(t.inst, () => 1), rng.fork(t.id)));
  }

  // comping instruments share the space
  const comps = rng.shuffle(tracks.filter((t) => t.inst === 'guitar' || t.inst === 'keys'));
  let budget = 0;
  let padTaken = false;
  let busyTaken = false;
  for (const t of comps) {
    if (t.locked) {
      const p = getPattern(t.patternId);
      if (p) {
        budget += p.density;
        padTaken = padTaken || p.role === 'pad';
        busyTaken = busyTaken || p.density === 3;
      }
    }
  }
  for (const t of comps) {
    if (t.locked) continue;
    const pat = pick(t.inst, (p) => {
      let w = 1;
      if (busyTaken && p.density === 3) w *= 0.08;
      if (padTaken && p.role === 'pad') w *= 0.15;
      if (budget >= 3 && p.density >= 2) w *= 0.4;
      if (budget >= 2 && p.density === 1) w *= 1.8;
      return w;
    });
    budget += pat.density;
    padTaken = padTaken || pat.role === 'pad';
    busyTaken = busyTaken || pat.density === 3;
    setTrack(applyPattern(t, pat, rng.fork(t.id)));
  }

  // horns
  const horns = tracks.filter((t) => isHorn(t.inst));
  const freeHorns = horns.filter((t) => !t.locked);
  const lockedSection = horns.find((t) => t.locked && isSectionPattern(t.patternId));
  let sectionSeed = project.sectionSeed;
  if (freeHorns.length) {
    let soloist: Track | null = null;
    if (horns.length === 1) {
      if (rng.chance(0.6)) soloist = freeHorns[0];
    } else if (freeHorns.length >= 3 && rng.chance(0.3)) {
      const cands = freeHorns.filter((t) => t.inst === 'tenor' || t.inst === 'alto' || t.inst === 'trumpet');
      if (cands.length) soloist = rng.pick(cands);
    }
    const hasSolo = !!soloist || horns.some((t) => t.locked && !isSectionPattern(t.patternId));
    const first = freeHorns.find((t) => t !== soloist) ?? freeHorns[0];
    const sectionPat = lockedSection
      ? getPattern(lockedSection.patternId)!
      : pick(
          first.inst,
          (p) => (hasSolo ? (p.role === 'line' ? 0.15 : 1.4) : 1) * (budget >= 5 && p.density === 3 ? 0.4 : 1),
          (p) => !!p.section,
        );
    if (!lockedSection) sectionSeed = rng.int(1, 0x7fffffff);
    for (const t of freeHorns) {
      if (t === soloist) {
        const sp = pick(
          t.inst,
          (p) => (p.id === 'h.fills' || p.id === 'h.answer' ? 1.6 : 1),
          (p) => !p.section,
        );
        setTrack(applyPattern(t, sp, rng.fork(t.id)));
      } else setTrack(applyPattern(t, sectionPat, rng.fork(t.id)));
    }
  }
  return { ...project, tracks: out, sectionSeed };
}

/**
 * Re-roll one track. 'recipe' draws a different recipe from the library,
 * 'take' keeps the recipe and deals a fresh performance of it.
 * Horns on a section recipe move together.
 */
export function rerollTrack(project: Project, trackId: string, mode: 'recipe' | 'take', seed: number = newSeed()): Project {
  const rng = new RNG(seed);
  const t = project.tracks.find((x) => x.id === trackId);
  if (!t) return project;
  const inSection = isHorn(t.inst) && isSectionPattern(t.patternId);
  if (mode === 'take') {
    if (inSection) return { ...project, sectionSeed: rng.int(1, 0x7fffffff) };
    return { ...project, tracks: project.tracks.map((x) => (x.id === trackId ? { ...x, seed: rng.int(1, 0x7fffffff) } : x)) };
  }
  const pool = patternsForStyle(t.inst, project.style).filter((p) => p.id !== t.patternId && (!inSection || !!p.section));
  const all = pool.length ? pool : patternsFor(t.inst).filter((p) => p.id !== t.patternId);
  if (!all.length) return rerollTrack(project, trackId, 'take', seed);
  const pat = rng.weighted(
    all,
    all.map((p) => weightFor(p, project.energy, project.style)),
  );
  if (inSection) {
    const mates = project.tracks.filter((x) => isHorn(x.inst) && x.patternId === t.patternId && !x.locked).map((x) => x.id);
    return {
      ...project,
      sectionSeed: rng.int(1, 0x7fffffff),
      tracks: project.tracks.map((x) => (mates.includes(x.id) || x.id === trackId ? applyPattern(x, pat, rng.fork(x.id)) : x)),
    };
  }
  return { ...project, tracks: project.tracks.map((x) => (x.id === trackId ? applyPattern(x, pat, rng) : x)) };
}

// ------------------------------------------------------------------ export

export function trackLabel(t: Track): string {
  return instDef(t.inst).name;
}

/** Build a MIDI file from the arrangement. Pass track ids to export a subset (one id -> a single-track clip). */
export function exportMidi(project: Project, arr: Arrangement, trackIds?: string[]): Uint8Array {
  const chosen = project.tracks.filter((t) => (trackIds ? trackIds.includes(t.id) : !t.mute));
  const tracks: SmfTrack[] = chosen.map((t) => ({
    name: trackLabel(t),
    events: renderEvents(arr.parts[t.id] ?? { notes: [], ctrl: [], bends: [] }, t.midi, project.tempo),
  }));
  const markers = arr.spans.filter((s) => s.change || s.t === 0).map((s) => ({ t: s.t, text: s.chord.sym }));
  return writeSMF({ title: project.name, tempo: project.tempo, len: arr.len, markers, tracks });
}

export function fileSafe(s: string): string {
  return s.replace(/[^\w\- ]+/g, '').trim().replace(/\s+/g, '-') || 'sideman';
}
