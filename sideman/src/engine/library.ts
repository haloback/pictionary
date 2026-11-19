// The part library: every recipe the randomiser can draw from, plus the
// instrument and style definitions.

import type { Family, InstId, StyleId } from './types';
import type { PatternDef } from './patterns';
import { fitsStyle } from './patterns';
import { DRUM_PATTERNS, PERC_PATTERNS } from './drums';
import { BASS_PATTERNS } from './bass';
import { GUITAR_PATTERNS } from './guitar';
import { KEYS_PATTERNS } from './keys';
import { HORN_PATTERNS } from './horns';

export interface StyleDef {
  id: StyleId;
  name: string;
  tempo: number;
  /** 0 straight .. 1 full triplet */
  swing: number;
  grid: 8 | 16;
  desc: string;
}

export const STYLES: StyleDef[] = [
  { id: 'funk', name: 'Funk', tempo: 102, swing: 0.1, grid: 16, desc: 'Tight sixteenths, syncopation, stabs' },
  { id: 'soul', name: 'Soul / R&B', tempo: 104, swing: 0, grid: 16, desc: 'Backbeat, melodic bass, horn punches' },
  { id: 'neosoul', name: 'Neo-soul', tempo: 84, swing: 0.4, grid: 16, desc: 'Behind the beat, lush harmony' },
  { id: 'pop', name: 'Pop', tempo: 116, swing: 0, grid: 16, desc: 'Straight eighths, clear and supportive' },
  { id: 'rock', name: 'Rock', tempo: 126, swing: 0, grid: 16, desc: 'Driving eighths, power chords' },
  { id: 'jazz', name: 'Jazz swing', tempo: 144, swing: 0.62, grid: 8, desc: 'Ride cymbal, walking bass, comping' },
  { id: 'blues', name: 'Blues shuffle', tempo: 108, swing: 0.85, grid: 8, desc: 'Triplet shuffle, boogie lines' },
  { id: 'bossa', name: 'Bossa / Latin', tempo: 132, swing: 0, grid: 16, desc: 'Clave, root-fifth bass, soft comping' },
  { id: 'reggae', name: 'Reggae', tempo: 76, swing: 0.3, grid: 16, desc: 'One drop, skank, heavy bass' },
  { id: 'afrobeat', name: 'Afrobeat / Highlife', tempo: 112, swing: 0.08, grid: 16, desc: 'Interlocking guitars, horn riffs' },
  { id: 'ballad', name: 'Ballad', tempo: 68, swing: 0, grid: 16, desc: 'Slow, sustained, spacious' },
];
export const styleDef = (id: StyleId): StyleDef => STYLES.find((s) => s.id === id) ?? STYLES[0];

export interface VariantDef {
  id: string;
  name: string;
  /** General MIDI program number (0-based) */
  program: number;
}
export interface InstDef {
  id: InstId;
  name: string;
  short: string;
  family: Family | 'perc';
  variants: VariantDef[];
  /** preferred MIDI channel (1..16) */
  channel: number;
}

export const INSTRUMENTS: InstDef[] = [
  { id: 'drums', name: 'Drums', short: 'DR', family: 'drums', channel: 10, variants: [{ id: 'kit', name: 'Drum kit', program: 0 }] },
  { id: 'perc', name: 'Percussion', short: 'PC', family: 'perc', channel: 10, variants: [{ id: 'perc', name: 'Hand percussion', program: 0 }] },
  {
    id: 'bass',
    name: 'Bass',
    short: 'BS',
    family: 'bass',
    channel: 2,
    variants: [
      { id: 'finger', name: 'Electric, fingered', program: 33 },
      { id: 'pick', name: 'Electric, picked', program: 34 },
      { id: 'fretless', name: 'Fretless', program: 35 },
      { id: 'slap', name: 'Slap', program: 36 },
      { id: 'upright', name: 'Upright', program: 32 },
    ],
  },
  {
    id: 'guitar',
    name: 'Guitar',
    short: 'GT',
    family: 'guitar',
    channel: 3,
    variants: [
      { id: 'clean', name: 'Electric, clean', program: 27 },
      { id: 'jazz', name: 'Electric, jazz', program: 26 },
      { id: 'muted', name: 'Electric, muted', program: 28 },
      { id: 'overdrive', name: 'Overdriven', program: 29 },
      { id: 'steel', name: 'Acoustic, steel', program: 25 },
      { id: 'nylon', name: 'Acoustic, nylon', program: 24 },
    ],
  },
  {
    id: 'keys',
    name: 'Keys',
    short: 'KY',
    family: 'keys',
    channel: 4,
    variants: [
      { id: 'grand', name: 'Grand piano', program: 0 },
      { id: 'rhodes', name: 'Electric piano (tine)', program: 4 },
      { id: 'wurli', name: 'Electric piano (reed)', program: 5 },
      { id: 'clav', name: 'Clavinet', program: 7 },
      { id: 'organ', name: 'Drawbar organ', program: 16 },
    ],
  },
  {
    id: 'trumpet',
    name: 'Trumpet',
    short: 'TP',
    family: 'horn',
    channel: 5,
    variants: [
      { id: 'open', name: 'Open', program: 56 },
      { id: 'muted', name: 'Harmon mute', program: 59 },
    ],
  },
  {
    id: 'alto',
    name: 'Alto Sax',
    short: 'AS',
    family: 'horn',
    channel: 6,
    variants: [
      { id: 'alto', name: 'Alto', program: 65 },
      { id: 'soprano', name: 'Soprano', program: 64 },
    ],
  },
  { id: 'tenor', name: 'Tenor Sax', short: 'TS', family: 'horn', channel: 7, variants: [{ id: 'tenor', name: 'Tenor', program: 66 }] },
  { id: 'trombone', name: 'Trombone', short: 'TB', family: 'horn', channel: 8, variants: [{ id: 'trombone', name: 'Tenor trombone', program: 57 }] },
  { id: 'bari', name: 'Bari Sax', short: 'BX', family: 'horn', channel: 9, variants: [{ id: 'bari', name: 'Baritone', program: 67 }] },
];
export const instDef = (id: InstId): InstDef => INSTRUMENTS.find((i) => i.id === id)!;

export const PATTERNS: PatternDef[] = [...DRUM_PATTERNS, ...PERC_PATTERNS, ...BASS_PATTERNS, ...GUITAR_PATTERNS, ...KEYS_PATTERNS, ...HORN_PATTERNS];
const byId = new Map(PATTERNS.map((p) => [p.id, p]));
export const getPattern = (id: string): PatternDef | undefined => byId.get(id);

export function patternsFor(inst: InstId): PatternDef[] {
  const fam = instDef(inst).family;
  return PATTERNS.filter((p) => p.family === fam);
}
/** Recipes for an instrument that suit a style (falls back to everything if none do). */
export function patternsForStyle(inst: InstId, style: StyleId): PatternDef[] {
  const all = patternsFor(inst);
  const fit = all.filter((p) => fitsStyle(p, style));
  return fit.length ? fit : all;
}
