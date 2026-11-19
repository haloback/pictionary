// Project model, arrangement generation, the smart randomiser and band presets.

import { BAR, DEFAULT_PARAMS } from './types';
import type { ChordSpan, InstId, Key, Part, TrackParams } from './types';
import { RNG, hashStr, newSeed } from './rng';
import { expandChart, parseChart } from './chart';
import { detectKey } from './theory';
import { finalize } from './perf';
import type { BandPlan, Feel, GenCtx, Groove } from './perf';
import { grooveFor } from './drums';
import { liveGrooveFor } from './livedrums';
import { isSectionPattern } from './horns';
import { makePlan } from './phrasebank';
import { familyOf, getPattern, instDef, patternsFor, patternsForStyle, styleDef, traitsOf, variantDef } from './library';
import type { PatternDef, SectionPlayer } from './patterns';
import { makeProfile, renderEvents, writeSMF } from './midi';
import type { MidiProfile, SmfTrack } from './midi';

export interface Track {
  id: string;
  inst: InstId;
  variant: string;
  patternId: string;
  seed: number;
  /** seed of the band plan this player follows (shared by players dealt together) */
  plan: number;
  /** per-bar "different phrase here" counters for phrase-bank parts */
  swaps?: Record<number, number>;
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
  /** genre id (see STYLES) */
  style: string;
  /** null = use the genre's swing */
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

export function makeTrack(inst: InstId, genre: string, existing: Track[], rng: RNG = new RNG(newSeed()), plan = 1): Track {
  const def = instDef(inst);
  const pat = rng.pick(patternsForStyle(inst, genre));
  const variant = pat.variant && def.variants.some((v) => v.id === pat.variant) ? pat.variant : def.variants[0].id;
  const program = def.variants.find((v) => v.id === variant)!.program;
  return {
    id: uid(),
    inst,
    variant,
    patternId: pat.id,
    seed: rng.int(1, 0x7fffffff),
    plan,
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
  const family = familyOf(project.style);

  const plans = new Map<number, BandPlan>();
  const planFor = (seed: number): BandPlan => {
    let p = plans.get(seed);
    if (!p) {
      p = makePlan(seed, bars, family);
      plans.set(seed, p);
    }
    return p;
  };

  const baseCtx = (track: Track, seed: number): GenCtx => ({
    spans,
    bars,
    len,
    key,
    style: family,
    feel,
    tempo: project.tempo,
    energy: project.energy,
    params: track.params,
    rng: new RNG(seed),
    groove: { kicks: [], snares: [] },
    inst: track.inst,
    variant: track.variant,
    phrase: 4,
    traits: traitsOf(track.inst, track.variant),
    shift: variantDef(track.inst, track.variant).shift ?? 0,
    plan: planFor(track.plan ?? project.sectionSeed),
    swaps: track.swaps ?? {},
  });
  /** An instrument type only plays the articulations it has. */
  const done = (track: Track, part: Part): Part => {
    const arts = new Set(variantDef(track.inst, track.variant).arts);
    const out = finalize(part, len);
    for (const n of out.notes) if (n.art && !arts.has(n.art)) delete n.art;
    return out;
  };

  // the drummer sets the groove the bass locks to
  const drummer = project.tracks.find((t) => t.inst === 'drums');
  let groove: Groove = { kicks: [], snares: [] };
  if (drummer && getPattern(drummer.patternId)) {
    const c = baseCtx(drummer, drummer.seed);
    groove = liveGrooveFor(drummer.patternId, c) ?? grooveFor(drummer.patternId, baseCtx(drummer, drummer.seed));
  } else {
    const fallback = patternsForStyle('drums', project.style).find((p) => !p.tag) ?? patternsFor('drums').find((p) => !p.tag)!;
    const ghost: Track = { ...(project.tracks[0] ?? makeTrack('drums', project.style, [])), inst: 'drums', variant: 'kit', params: { ...DEFAULT_PARAMS } };
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
      parts[t.id] = done(t, pat.gen!(ctx));
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
    const players: SectionPlayer[] = tracks.map((t, i) => {
      const c = baseCtx(t, (secSeed ^ hashStr(t.inst + i)) >>> 0);
      c.groove = groove;
      return { inst: t.inst as SectionPlayer['inst'], ctx: c };
    });
    const out = pat.section!(secCtx, players);
    tracks.forEach((t, i) => (parts[t.id] = done(t, out[i])));
  }
  return { parts, spans, key, bars, len, errors };
}

// ------------------------------------------------------------------ smart randomise

/**
 * How much the randomiser wants a recipe: recipes list their home family
 * first, genres name the recipes they are known for, recorded drummers are
 * matched to the genre, and busier recipes come forward as energy rises.
 */
function weightFor(p: PatternDef, energy: number, genre?: string): number {
  let w = Math.max(0.25, 1 + (p.density - 2) * (energy - 0.5) * 1.6);
  if (!genre) return w;
  const g = styleDef(genre);
  if (p.styles !== '*' && p.styles[0] === g.family) w *= 2.6;
  if (g.prefer?.includes(p.id)) w *= 3.2;
  if (p.tag) {
    const rank = g.drums.indexOf(p.tag);
    w *= rank === 0 ? 5 : rank > 0 ? 2.2 : 0.25;
  }
  return w;
}

const HORNS: InstId[] = ['flute', 'trumpet', 'alto', 'tenor', 'trombone', 'bari'];
const isHorn = (i: InstId) => HORNS.includes(i);

function applyPattern(t: Track, pat: PatternDef, rng: RNG, plan?: number): Track {
  const def = instDef(t.inst);
  let variant = t.variant;
  let midi = t.midi;
  if (pat.variant && def.variants.some((v) => v.id === pat.variant)) {
    variant = pat.variant;
    midi = { ...midi, program: def.variants.find((v) => v.id === variant)!.program };
  }
  const next: Track = { ...t, patternId: pat.id, seed: rng.int(1, 0x7fffffff), variant, midi, plan: plan ?? t.plan };
  delete next.swaps;
  return next;
}

/**
 * Re-deal the band. Unlocked tracks get a new recipe and a new take, chosen so
 * the parts complement each other: one busy comping instrument at a time, horns
 * that leave room for a soloist, a shared band plan so phrase-bank players
 * trade bars instead of talking over each other, density that follows energy.
 */
export function smartRandomize(project: Project, seed: number = newSeed()): Project {
  const rng = new RNG(seed);
  const genre = project.style;
  const en = project.energy;
  const plan = rng.int(1, 0x7fffffff);
  const tracks = project.tracks.map((t) => ({ ...t }));
  const out: Track[] = tracks.slice();
  const setTrack = (t: Track) => {
    out[out.findIndex((x) => x.id === t.id)] = t;
  };
  const pick = (inst: InstId, mod: (p: PatternDef) => number, filter?: (p: PatternDef) => boolean): PatternDef => {
    let pool = patternsForStyle(inst, genre);
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
      pool.map((p) => weightFor(p, en, genre) * mod(p)),
    );
  };

  // rhythm section
  for (const t of tracks) {
    if (t.locked) continue;
    if (t.inst === 'drums' || t.inst === 'perc' || t.inst === 'bass') setTrack(applyPattern(t, pick(t.inst, () => 1), rng.fork(t.id), plan));
  }

  // comping instruments share the space
  const comps = rng.shuffle(tracks.filter((t) => t.inst === 'guitar' || t.inst === 'keys'));
  let budget = 0;
  let padTaken = false;
  let busyTaken = false;
  let lineTaken = false;
  for (const t of comps) {
    if (t.locked) {
      const p = getPattern(t.patternId);
      if (p) {
        budget += p.density;
        padTaken = padTaken || p.role === 'pad';
        busyTaken = busyTaken || p.density === 3;
        lineTaken = lineTaken || p.role === 'line';
      }
    }
  }
  for (const t of comps) {
    if (t.locked) continue;
    const pat = pick(t.inst, (p) => {
      let w = 1;
      if (busyTaken && p.density === 3) w *= 0.08;
      if (padTaken && p.role === 'pad') w *= 0.15;
      if (lineTaken && p.role === 'line') w *= 0.1;
      // someone has to hold the harmony before a guitar goes off playing lines
      if (p.role === 'line' && budget === 0 && comps.length < 2) w *= 0.3;
      if (budget >= 3 && p.density >= 2) w *= 0.4;
      if (budget >= 2 && p.density === 1) w *= 1.8;
      return w;
    });
    budget += pat.density;
    padTaken = padTaken || pat.role === 'pad';
    busyTaken = busyTaken || pat.density === 3;
    lineTaken = lineTaken || pat.role === 'line';
    setTrack(applyPattern(t, pat, rng.fork(t.id), plan));
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
    } else if (freeHorns.length >= 3 && rng.chance(0.35)) {
      const cands = freeHorns.filter((t) => t.inst === 'tenor' || t.inst === 'alto' || t.inst === 'trumpet' || t.inst === 'flute');
      if (cands.length) soloist = rng.pick(cands);
    }
    let soloPat: PatternDef | null = null;
    if (soloist) {
      soloPat = pick(
        soloist.inst,
        (p) => (p.id === 'h.fills' || p.id === 'h.answer' || p.id === 'h.banklead' ? 1.6 : 1) * (lineTaken && p.density === 3 ? 0.3 : 1),
        (p) => !p.section,
      );
    }
    const hasSolo = !!soloist || lineTaken || horns.some((t) => t.locked && !isSectionPattern(t.patternId));
    const first = freeHorns.find((t) => t !== soloist) ?? freeHorns[0];
    const sectionPat = lockedSection
      ? getPattern(lockedSection.patternId)!
      : pick(
          first.inst,
          (p) => {
            let w = hasSolo ? (p.role === 'line' && p.id !== 'hs.bankanswer' ? 0.15 : 1.4) : 1;
            // a bank lead wants a bank answer behind it
            if (soloPat?.id === 'h.banklead' && p.id === 'hs.bankanswer') w *= 5;
            if (!hasSolo && p.id === 'hs.bankanswer') w *= 0.2;
            if (budget >= 5 && p.density === 3) w *= 0.4;
            return w;
          },
          (p) => !!p.section,
        );
    if (!lockedSection) sectionSeed = rng.int(1, 0x7fffffff);
    for (const t of freeHorns) {
      if (t === soloist && soloPat) setTrack(applyPattern(t, soloPat, rng.fork(t.id), plan));
      else setTrack(applyPattern(t, sectionPat, rng.fork(t.id), lockedSection ? lockedSection.plan : plan));
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
  const mates = inSection ? project.tracks.filter((x) => isHorn(x.inst) && x.patternId === t.patternId && (!x.locked || x.id === trackId)).map((x) => x.id) : [trackId];
  const clear = (x: Track): Track => {
    const y = { ...x };
    delete y.swaps;
    return y;
  };
  if (mode === 'take') {
    if (inSection) return { ...project, sectionSeed: rng.int(1, 0x7fffffff), tracks: project.tracks.map((x) => (mates.includes(x.id) ? clear(x) : x)) };
    return { ...project, tracks: project.tracks.map((x) => (x.id === trackId ? { ...clear(x), seed: rng.int(1, 0x7fffffff) } : x)) };
  }
  const pool = patternsForStyle(t.inst, project.style).filter((p) => p.id !== t.patternId && (!inSection || !!p.section));
  const all = pool.length ? pool : patternsFor(t.inst).filter((p) => p.id !== t.patternId);
  if (!all.length) return rerollTrack(project, trackId, 'take', seed);
  const pat = rng.weighted(
    all,
    all.map((p) => weightFor(p, project.energy, project.style)),
  );
  if (inSection) {
    return {
      ...project,
      sectionSeed: rng.int(1, 0x7fffffff),
      tracks: project.tracks.map((x) => (mates.includes(x.id) ? applyPattern(x, pat, rng.fork(x.id)) : x)),
    };
  }
  return { ...project, tracks: project.tracks.map((x) => (x.id === trackId ? applyPattern(x, pat, rng) : x)) };
}

/** Ask for a different phrase in one bar of a phrase-bank part (the whole section moves together). */
export function swapPhrase(project: Project, trackId: string, bar: number): Project {
  const t = project.tracks.find((x) => x.id === trackId);
  if (!t) return project;
  const inSection = isHorn(t.inst) && isSectionPattern(t.patternId);
  const mates = inSection ? project.tracks.filter((x) => isHorn(x.inst) && x.patternId === t.patternId).map((x) => x.id) : [trackId];
  const n = (t.swaps?.[bar] ?? 0) + 1;
  return { ...project, tracks: project.tracks.map((x) => (mates.includes(x.id) ? { ...x, swaps: { ...(x.swaps ?? {}), [bar]: n } } : x)) };
}

// ------------------------------------------------------------------ band presets

export interface PresetPlayer {
  inst: InstId;
  variant?: string;
  /** recipe id; left out, the randomiser chooses one that fits */
  recipe?: string;
  params?: Partial<TrackParams>;
  midi?: MidiProfile;
  gain?: number;
}
export interface BandPreset {
  id: string;
  name: string;
  /** genre id, or null to keep the current genre */
  genre: string | null;
  desc: string;
  tempo?: number;
  swing?: number | null;
  energy?: number;
  players: PresetPlayer[];
  user?: boolean;
}

const P = (inst: InstId, variant?: string, recipe?: string, params?: Partial<TrackParams>): PresetPlayer => ({ inst, variant, recipe, params });

export const BAND_PRESETS: BandPreset[] = [
  {
    id: 'funk-band',
    name: 'Tight funk band',
    genre: 'funk',
    desc: 'Recorded funk drummer, sixteenth bass, scratch guitar, clav and a four-horn section on stabs.',
    players: [P('drums', 'kit', 'dl.funk'), P('bass', 'finger', 'b.funk16'), P('guitar', 'clean', 'g.funk16'), P('keys', 'clav', 'k.clav'), P('trumpet', 'open', 'hs.stabs'), P('alto', 'alto', 'hs.stabs'), P('tenor', 'tenor', 'hs.stabs'), P('trombone', 'trombone', 'hs.stabs')],
  },
  {
    id: 'disco-floor',
    name: 'Disco floor',
    genre: 'disco',
    desc: 'Four on the floor, octave bass, strings and swelling brass.',
    players: [P('drums', 'kit', 'd.disco'), P('perc', 'perc', 'p.tamb16'), P('bass', 'finger', 'b.octaves'), P('guitar', 'clean', 'g.funk16'), P('keys', 'strings', 'k.pad'), P('keys', 'rhodes', 'k.soul'), P('trumpet', 'open', 'hs.swell'), P('alto', 'alto', 'hs.swell'), P('trombone', 'trombone', 'hs.swell')],
  },
  {
    id: 'soul-revue',
    name: 'Soul revue',
    genre: 'soul',
    desc: 'Backbeat chops, organ and a punchy three-horn line with a growling tenor.',
    players: [P('drums', 'kit', 'dl.soul'), P('bass', 'finger', 'b.soul'), P('guitar', 'clean', 'g.chops'), P('keys', 'organ', 'k.organpad'), P('trumpet', 'open', 'hs.stabs'), P('tenor', 'tenorhonk', 'hs.stabs'), P('bari', 'bari', 'hs.stabs')],
  },
  {
    id: 'motown-revue',
    name: 'Motown house band',
    genre: 'motown',
    desc: 'Snare on every beat, tambourine, a busy bass and horns that swell into the changes.',
    players: [P('drums', 'kit', 'd.motown'), P('perc', 'perc', 'p.tamb'), P('bass', 'finger', 'b.soul', { complexity: 0.7 }), P('guitar', 'clean', 'g.chops'), P('keys', 'grand', 'k.pop8'), P('trumpet', 'open', 'hs.swell'), P('tenor', 'tenor', 'hs.swell'), P('bari', 'bari', 'hs.swell')],
  },
  {
    id: 'gospel-band',
    name: 'Sunday gospel band',
    genre: 'gospel',
    desc: 'Organ swells under pushed piano chords, with a melodic bass.',
    players: [P('drums', 'kit', 'dl.gospel'), P('bass', 'fivestring', 'b.soul'), P('keys', 'organ', 'k.organpad'), P('keys', 'grand', 'k.soul'), P('guitar', 'clean', 'g.chops'), P('perc', 'perc', 'p.tamb')],
  },
  {
    id: 'neosoul-quartet',
    name: 'Neo-soul quartet',
    genre: 'neosoul',
    desc: 'Lazy pocket, lush Rhodes, answering guitar and a flugelhorn on long tones.',
    players: [P('drums', 'kit', 'dl.hiphop'), P('bass', 'fivestring', 'b.neosoul'), P('keys', 'rhodes', 'k.neosoul'), P('guitar', 'clean', 'g.answers'), P('trumpet', 'flugel', 'h.long')],
  },
  {
    id: 'boom-bap',
    name: 'Boom-bap trio',
    genre: 'hiphop',
    desc: 'Head-nod drums, synth bass, Rhodes pads and a muted trumpet in the gaps.',
    players: [P('drums', 'electro', 'dl.hiphop'), P('bass', 'synth', 'b.neosoul'), P('keys', 'rhodes', 'k.pad'), P('trumpet', 'muted', 'h.bankfills')],
  },
  {
    id: 'second-line',
    name: 'Second line brass band',
    genre: 'neworleans',
    desc: 'Street-beat snare and a horn line riffing from the phrase bank.',
    players: [P('drums', 'kit', 'dl.neworleans'), P('bass', 'upright', 'b.boogie'), P('trumpet', 'open', 'hs.bank'), P('alto', 'alto', 'hs.bank'), P('tenor', 'tenorhonk', 'hs.bank'), P('trombone', 'plunger', 'hs.bank'), P('bari', 'bari', 'hs.bank')],
  },
  {
    id: 'fusion-group',
    name: 'Fusion group',
    genre: 'fusion',
    desc: 'Fretless bass, Rhodes, a muted guitar riff and a tenor lead answered by the band.',
    players: [P('drums', 'kit', 'dl.funk'), P('bass', 'fretless', 'b.funk16'), P('keys', 'rhodes', 'k.neosoul'), P('guitar', 'muted', 'g.muteline'), P('tenor', 'tenor', 'h.banklead')],
  },
  {
    id: 'pop-four',
    name: 'Pop four-piece',
    genre: 'pop',
    desc: 'Strummed acoustic, piano eighths and a bass locked to the kick.',
    players: [P('drums', 'kit', 'dl.pop'), P('bass', 'pick', 'b.kicklock'), P('guitar', 'steel', 'g.strum8'), P('keys', 'grand', 'k.pop8')],
  },
  {
    id: 'rock-band',
    name: 'Rock band',
    genre: 'rock',
    desc: 'Palm-muted rhythm guitar, a lead guitar that bends, rock organ and a driving bass.',
    players: [P('drums', 'power', 'dl.rock'), P('bass', 'pick', 'b.pump8'), P('guitar', 'overdrive', 'g.pm8'), P('guitar', 'lead', 'g.banklead'), P('keys', 'rockorgan', 'k.organpad')],
  },
  {
    id: 'punk-trio',
    name: 'Punk trio',
    genre: 'punk',
    desc: 'Fast down-strokes, picked bass, no frills.',
    energy: 0.9,
    players: [P('drums', 'power', 'dl.punk'), P('bass', 'pick', 'b.pump8'), P('guitar', 'overdrive', 'g.power')],
  },
  {
    id: 'country-band',
    name: 'Country band',
    genre: 'country',
    desc: 'Boom-chick acoustic, two-beat bass, upright piano and a slide guitar answering.',
    players: [P('drums', 'kit', 'dl.country'), P('bass', 'finger', 'b.rootfive'), P('guitar', 'steel', 'g.boomchick'), P('guitar', 'slideguitar', 'g.bankanswer'), P('keys', 'upright', 'k.pop8')],
  },
  {
    id: 'coffee-house',
    name: 'Coffee-house set',
    genre: 'folk',
    desc: 'Travis-picked guitar, upright bass, shaker and a flute counter-line.',
    energy: 0.4,
    players: [P('guitar', 'steel', 'g.travis'), P('bass', 'upright', 'b.ballad'), P('perc', 'perc', 'p.shaker'), P('flute', 'flute', 'h.long')],
  },
  {
    id: 'ballad-ensemble',
    name: 'Ballad ensemble',
    genre: 'ballad',
    desc: 'Piano arpeggios, strings, arpeggiated guitar and a breathy tenor.',
    energy: 0.4,
    players: [P('drums', 'kit', 'd.ballad'), P('bass', 'finger', 'b.ballad'), P('keys', 'grand', 'k.ballad'), P('keys', 'strings', 'k.pad'), P('guitar', 'clean', 'g.arp'), P('tenor', 'tenorbreathy', 'h.long')],
  },
  {
    id: 'jazz-quintet',
    name: 'Jazz quintet',
    genre: 'jazz',
    desc: 'Walking upright, rootless comping, trumpet lead answered by tenor.',
    players: [P('drums', 'jazzkit', 'dl.jazz'), P('bass', 'upright', 'b.walk'), P('keys', 'grand', 'k.jazzcomp'), P('trumpet', 'open', 'h.banklead'), P('tenor', 'tenor', 'h.bankanswer')],
  },
  {
    id: 'bebop-quartet',
    name: 'Bebop quartet',
    genre: 'bebop',
    desc: 'Up-tempo walking four with an alto running the changes.',
    players: [P('drums', 'jazzkit', 'd.swing'), P('bass', 'upright', 'b.walk'), P('keys', 'grand', 'k.jazzcomp'), P('alto', 'alto', 'h.lead', { complexity: 0.8 })],
  },
  {
    id: 'late-night',
    name: 'Late-night trio and tenor',
    genre: 'jazzballad',
    desc: 'Brushes, two-feel bass, soft piano and a subtone tenor.',
    energy: 0.35,
    players: [P('drums', 'brush', 'd.ballad'), P('bass', 'upright', 'b.twofeel'), P('keys', 'grand', 'k.neosoul'), P('tenor', 'tenorbreathy', 'h.long')],
  },
  {
    id: 'big-band',
    name: 'Big band',
    genre: 'jazz',
    desc: 'Four-to-the-bar guitar and eight horns from lead trumpet down to bass trombone.',
    energy: 0.75,
    players: [
      P('drums', 'jazzkit', 'dl.jazz'),
      P('bass', 'upright', 'b.walk'),
      P('guitar', 'jazz', 'g.four'),
      P('keys', 'grand', 'k.jazzcomp'),
      P('trumpet', 'leadtp', 'hs.stabs'),
      P('trumpet', 'open', 'hs.stabs'),
      P('alto', 'alto', 'hs.stabs'),
      P('alto', 'alto', 'hs.stabs'),
      P('tenor', 'tenor', 'hs.stabs'),
      P('trombone', 'trombone', 'hs.stabs'),
      P('trombone', 'basstrombone', 'hs.stabs'),
      P('bari', 'bari', 'hs.stabs'),
    ],
  },
  {
    id: 'blues-bar',
    name: 'Blues bar band',
    genre: 'blues',
    desc: 'Shuffle, boogie bass and piano, an overdriven guitar answering a honking tenor.',
    players: [P('drums', 'kit', 'd.shuffle'), P('bass', 'finger', 'b.boogie'), P('keys', 'upright', 'k.boogie'), P('guitar', 'overdrive', 'g.answers'), P('tenor', 'tenorhonk', 'h.blues')],
  },
  {
    id: 'bossa-quartet',
    name: 'Bossa quartet',
    genre: 'bossa',
    desc: 'Nylon-string fingerstyle, soft Rhodes and a flute over the top.',
    energy: 0.45,
    players: [P('drums', 'brush', 'd.bossa'), P('bass', 'upright', 'b.bossa'), P('guitar', 'nylon', 'g.bossa'), P('keys', 'rhodes', 'k.bossa'), P('flute', 'flute', 'h.long')],
  },
  {
    id: 'salsa-orchestra',
    name: 'Salsa orchestra',
    genre: 'salsa',
    desc: 'Tumbao bass, montuno piano, full percussion and two trumpets with two trombones on the hits.',
    energy: 0.75,
    players: [P('drums', 'kit', 'dl.afrocuban'), P('perc', 'perc', 'p.latin'), P('bass', 'finger', 'b.tumbao'), P('keys', 'grand', 'k.montuno'), P('trumpet', 'leadtp', 'hs.hits'), P('trumpet', 'open', 'hs.hits'), P('trombone', 'trombone', 'hs.hits'), P('trombone', 'trombone', 'hs.hits')],
  },
  {
    id: 'roots-reggae',
    name: 'Roots reggae band',
    genre: 'reggae',
    desc: 'One drop, dub bass, skank guitar, organ bubble and horns that answer.',
    players: [P('drums', 'kit', 'd.onedrop'), P('perc', 'perc', 'p.bongos'), P('bass', 'finger', 'b.reggae'), P('guitar', 'clean', 'g.skank'), P('keys', 'organ', 'k.bubble'), P('trumpet', 'open', 'hs.answers'), P('tenor', 'tenor', 'hs.answers'), P('trombone', 'trombone', 'hs.answers')],
  },
  {
    id: 'ska-band',
    name: 'Ska band',
    genre: 'ska',
    desc: 'Off-beat guitar and piano with a horn line in octaves.',
    energy: 0.75,
    players: [P('drums', 'kit', 'd.steppers'), P('bass', 'finger', 'b.rootfive'), P('guitar', 'clean', 'g.skank'), P('keys', 'grand', 'k.skank'), P('trumpet', 'open', 'hs.riff'), P('tenor', 'tenor', 'hs.riff'), P('trombone', 'trombone', 'hs.riff')],
  },
  {
    id: 'afrobeat-orchestra',
    name: 'Afrobeat orchestra',
    genre: 'afrobeat',
    desc: 'Two interlocking guitars, bass ostinato, bell and shaker, and a baritone-anchored horn riff.',
    players: [P('drums', 'kit', 'dl.afrobeat'), P('perc', 'perc', 'p.afrobell'), P('bass', 'finger', 'b.afrobeat'), P('guitar', 'clean', 'g.highlife'), P('guitar', 'muted', 'g.muteline'), P('keys', 'organ', 'k.soul'), P('trumpet', 'open', 'hs.riff'), P('alto', 'alto', 'hs.riff'), P('tenor', 'tenor', 'hs.riff'), P('bari', 'bari', 'hs.riff')],
  },
  {
    id: 'highlife-band',
    name: 'Highlife band',
    genre: 'highlife',
    desc: 'Bright picked guitars with sweetly harmonised horns.',
    players: [P('drums', 'kit', 'dl.highlife'), P('perc', 'perc', 'p.shaker'), P('bass', 'finger', 'b.afrobeat'), P('guitar', 'clean', 'g.highlife'), P('guitar', 'clean', 'g.bank'), P('trumpet', 'open', 'hs.riffharm'), P('alto', 'alto', 'hs.riffharm'), P('tenor', 'tenor', 'hs.riffharm')],
  },
  {
    id: 'horns-only',
    name: 'Horn section only',
    genre: null,
    desc: 'Five horns and nothing else, for adding a section to a track you already have. Keeps the current genre.',
    players: [P('trumpet', 'open'), P('alto', 'alto'), P('tenor', 'tenor'), P('trombone', 'trombone'), P('bari', 'bari')],
  },
  {
    id: 'rhythm-only',
    name: 'Rhythm section only',
    genre: null,
    desc: 'Drums, bass, guitar and keys in the current genre.',
    players: [P('drums'), P('bass'), P('guitar'), P('keys')],
  },
];

/** Replace the band with a preset's players. The chart is kept. */
export function applyBandPreset(project: Project, preset: BandPreset, seed: number = newSeed()): Project {
  const rng = new RNG(seed);
  const genre = preset.genre && styleDef(preset.genre).id === preset.genre ? preset.genre : project.style;
  const g = styleDef(genre);
  const plan = rng.int(1, 0x7fffffff);
  const tracks: Track[] = [];
  const auto = new Set<string>();
  preset.players.forEach((pl, i) => {
    if (!instDef(pl.inst)) return;
    const t = makeTrack(pl.inst, genre, tracks, rng.fork('p' + i), plan);
    const def = instDef(pl.inst);
    const pat = pl.recipe ? getPattern(pl.recipe) : undefined;
    if (pat && pat.family === def.family) t.patternId = pat.id;
    else auto.add(t.id);
    const variant = pl.variant && def.variants.some((v) => v.id === pl.variant) ? pl.variant : t.variant;
    t.variant = variant;
    t.midi = pl.midi ? { ...pl.midi } : { ...t.midi, program: def.variants.find((v) => v.id === variant)!.program };
    if (pl.midi) t.midi.channel = def.family === 'drums' || def.family === 'perc' ? 10 : freeChannel(tracks, pl.midi.channel);
    if (pl.params) t.params = { ...t.params, ...pl.params };
    if (pl.gain != null) t.gain = pl.gain;
    tracks.push(t);
  });
  let next: Project = {
    ...project,
    style: genre,
    tempo: preset.tempo ?? (preset.genre ? g.tempo : project.tempo),
    swing: preset.swing !== undefined ? preset.swing : preset.genre ? null : project.swing,
    energy: preset.energy ?? project.energy,
    sectionSeed: rng.int(1, 0x7fffffff),
    tracks,
  };
  if (auto.size) {
    // let the randomiser fill the open chairs around the fixed ones
    const dealt = smartRandomize({ ...next, tracks: tracks.map((t) => ({ ...t, locked: !auto.has(t.id) })) }, rng.int(1, 0x7fffffff));
    next = { ...dealt, tracks: dealt.tracks.map((t) => ({ ...t, locked: false, plan })) };
  }
  return next;
}

/** Capture the current band as a reusable preset. */
export function presetFromProject(project: Project, name: string): BandPreset {
  return {
    id: 'u' + newSeed().toString(36),
    name,
    genre: project.style,
    desc: project.tracks.map((t) => instDef(t.inst).name).join(', '),
    tempo: project.tempo,
    swing: project.swing,
    energy: project.energy,
    user: true,
    players: project.tracks.map((t) => ({ inst: t.inst, variant: t.variant, recipe: t.patternId, params: { ...t.params }, midi: { ...t.midi }, gain: t.gain })),
  };
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
