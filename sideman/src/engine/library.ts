// The part library: every recipe the randomiser can draw from, plus the
// genre, instrument and instrument-type definitions.

import { NEUTRAL_TRAITS } from './types';
import type { Art, Family, InstId, StyleId, Traits } from './types';
import type { PatternDef } from './patterns';
import { fitsStyle } from './patterns';
import { DRUM_PATTERNS, PERC_PATTERNS } from './drums';
import { LIVE_DRUM_PATTERNS } from './livedrums';
import { BASS_PATTERNS } from './bass';
import { GUITAR_PATTERNS } from './guitar';
import { KEYS_PATTERNS } from './keys';
import { HORN_PATTERNS } from './horns';

/** A genre the band can play. Each belongs to a feel family that decides which recipes suit it. */
export interface StyleDef {
  id: string;
  name: string;
  group: string;
  family: StyleId;
  tempo: number;
  /** 0 straight .. 1 full triplet */
  swing: number;
  grid: 8 | 16;
  desc: string;
  /** recorded-drummer styles that suit it, best first */
  drums: string[];
  /** recipes this genre is known for (favoured by the randomiser) */
  prefer?: string[];
}

export const STYLES: StyleDef[] = [
  { id: 'funk', name: 'Funk', group: 'Funk and soul', family: 'funk', tempo: 102, swing: 0.1, grid: 16, drums: ['funk'], desc: 'Tight sixteenths, syncopation, stabs' },
  { id: 'disco', name: 'Disco', group: 'Funk and soul', family: 'funk', tempo: 118, swing: 0, grid: 16, drums: ['dance', 'funk'], prefer: ['d.disco', 'b.octaves', 'g.funk16', 'hs.stabs', 'k.soul'], desc: 'Four on the floor, octave bass, chicken-scratch guitar' },
  { id: 'soul', name: 'Soul / R&B', group: 'Funk and soul', family: 'soul', tempo: 104, swing: 0, grid: 16, drums: ['soul'], desc: 'Backbeat, melodic bass, horn punches' },
  { id: 'motown', name: 'Motown', group: 'Funk and soul', family: 'soul', tempo: 114, swing: 0, grid: 16, drums: ['soul', 'pop'], prefer: ['d.motown', 'b.soul', 'g.chops', 'p.tamb', 'hs.swell', 'k.pop8'], desc: 'Snare on every beat, busy bass, tambourine' },
  { id: 'gospel', name: 'Gospel', group: 'Funk and soul', family: 'soul', tempo: 96, swing: 0.2, grid: 16, drums: ['gospel', 'soul'], prefer: ['k.soul', 'k.organpad', 'b.soul', 'hs.swell'], desc: 'Organ, pushed chords, big dynamics' },
  { id: 'neosoul', name: 'Neo-soul', group: 'Funk and soul', family: 'neosoul', tempo: 84, swing: 0.4, grid: 16, drums: ['hiphop', 'soul'], desc: 'Behind the beat, lush harmony' },
  { id: 'hiphop', name: 'Hip-hop / Boom bap', group: 'Funk and soul', family: 'neosoul', tempo: 90, swing: 0.3, grid: 16, drums: ['hiphop'], prefer: ['d.laidback', 'b.neosoul', 'k.pad', 'k.neosoul', 'hs.answers'], desc: 'Head-nod drums, sparse bass, sampled-sounding stabs' },
  { id: 'neworleans', name: 'New Orleans second line', group: 'Funk and soul', family: 'funk', tempo: 100, swing: 0.35, grid: 16, drums: ['neworleans'], prefer: ['hs.riff', 'hs.answers', 'hs.bank', 'b.boogie', 'k.boogie'], desc: 'Street-beat snare, riffing horns' },
  { id: 'fusion', name: 'Jazz-funk / Fusion', group: 'Funk and soul', family: 'funk', tempo: 112, swing: 0.05, grid: 16, drums: ['funk', 'jazz'], prefer: ['k.neosoul', 'k.clav', 'b.funk16', 'h.banklead', 'hs.soli', 'g.muteline'], desc: 'Funk grooves under jazz harmony and solos' },
  { id: 'dance', name: 'Dance / House', group: 'Funk and soul', family: 'funk', tempo: 124, swing: 0, grid: 16, drums: ['dance'], prefer: ['d.disco', 'b.octaves', 'k.soul', 'k.pad', 'p.shaker'], desc: 'Steady kick, off-beat hats, piano stabs' },

  { id: 'pop', name: 'Pop', group: 'Pop and rock', family: 'pop', tempo: 116, swing: 0, grid: 16, drums: ['pop', 'rock'], desc: 'Straight eighths, clear and supportive' },
  { id: 'rock', name: 'Rock', group: 'Pop and rock', family: 'rock', tempo: 126, swing: 0, grid: 16, drums: ['rock'], desc: 'Driving eighths, power chords' },
  { id: 'punk', name: 'Punk', group: 'Pop and rock', family: 'rock', tempo: 172, swing: 0, grid: 16, drums: ['punk', 'rock'], prefer: ['g.pm8', 'g.power', 'b.pump8', 'd.drive'], desc: 'Fast, loud, down-strokes' },
  { id: 'country', name: 'Country', group: 'Pop and rock', family: 'pop', tempo: 108, swing: 0.15, grid: 8, drums: ['country', 'pop'], prefer: ['g.boomchick', 'g.travis', 'b.rootfive', 'k.pop8', 'p.tamb'], desc: 'Two-beat bass, boom-chick guitar' },
  { id: 'folk', name: 'Folk / Singer-songwriter', group: 'Pop and rock', family: 'pop', tempo: 96, swing: 0, grid: 16, drums: ['pop', 'country'], prefer: ['g.strum8', 'g.travis', 'g.arp', 'b.rootfive', 'b.ballad', 'k.pad', 'p.shaker'], desc: 'Acoustic strumming and picking, light touch' },
  { id: 'ballad', name: 'Ballad', group: 'Pop and rock', family: 'ballad', tempo: 68, swing: 0, grid: 16, drums: ['pop', 'soul', 'rock'], desc: 'Slow, sustained, spacious' },
  { id: 'slowjam', name: 'Slow jam', group: 'Pop and rock', family: 'ballad', tempo: 64, swing: 0.25, grid: 16, drums: ['soul', 'hiphop'], prefer: ['k.neosoul', 'b.neosoul', 'g.ballad', 'hs.pads', 'h.long'], desc: 'Slow R&B with a lazy sixteenth lilt' },

  { id: 'jazz', name: 'Jazz swing', group: 'Jazz and blues', family: 'jazz', tempo: 144, swing: 0.62, grid: 8, drums: ['jazz'], desc: 'Ride cymbal, walking bass, comping' },
  { id: 'bebop', name: 'Bebop', group: 'Jazz and blues', family: 'jazz', tempo: 208, swing: 0.5, grid: 8, drums: ['jazz'], prefer: ['b.walk', 'k.jazzcomp', 'h.lead', 'h.banklead', 'g.charleston', 'd.swing'], desc: 'Fast walking four with long eighth-note lines' },
  { id: 'jazzballad', name: 'Jazz ballad', group: 'Jazz and blues', family: 'jazz', tempo: 66, swing: 0.5, grid: 8, drums: ['jazz'], prefer: ['b.twofeel', 'k.neosoul', 'g.ballad', 'hs.guide', 'h.long', 'd.ballad'], desc: 'Two-feel bass, soft comping, long tones' },
  { id: 'blues', name: 'Blues shuffle', group: 'Jazz and blues', family: 'blues', tempo: 108, swing: 0.85, grid: 8, drums: ['blues', 'jazz'], desc: 'Triplet shuffle, boogie lines' },

  { id: 'bossa', name: 'Bossa nova', group: 'Latin and Caribbean', family: 'bossa', tempo: 132, swing: 0, grid: 16, drums: ['latin'], desc: 'Clave, root-fifth bass, soft comping' },
  { id: 'latinjazz', name: 'Latin jazz', group: 'Latin and Caribbean', family: 'bossa', tempo: 152, swing: 0, grid: 16, drums: ['latin', 'afrocuban'], prefer: ['k.montuno', 'p.latin', 'b.bossa', 'hs.riffharm', 'h.banklead'], desc: 'Montuno piano, congas, harmonised horns' },
  { id: 'salsa', name: 'Salsa / Son', group: 'Latin and Caribbean', family: 'bossa', tempo: 176, swing: 0, grid: 16, drums: ['afrocuban', 'latin'], prefer: ['b.tumbao', 'k.montuno', 'p.clave', 'p.conga', 'p.latin', 'hs.stabs', 'hs.hits'], desc: 'Anticipated tumbao bass, clave, brass hits' },
  { id: 'reggae', name: 'Reggae', group: 'Latin and Caribbean', family: 'reggae', tempo: 76, swing: 0.3, grid: 16, drums: ['reggae'], desc: 'One drop, skank, heavy bass' },
  { id: 'ska', name: 'Ska', group: 'Latin and Caribbean', family: 'reggae', tempo: 150, swing: 0, grid: 16, drums: ['reggae', 'punk'], prefer: ['g.skank', 'k.skank', 'hs.offbeats', 'hs.riff', 'd.steppers', 'b.afrobeat'], desc: 'Up-tempo off-beats and horn lines' },

  { id: 'afrobeat', name: 'Afrobeat', group: 'African', family: 'afrobeat', tempo: 112, swing: 0.08, grid: 16, drums: ['afrobeat'], desc: 'Interlocking guitars, horn riffs' },
  { id: 'highlife', name: 'Highlife', group: 'African', family: 'afrobeat', tempo: 126, swing: 0.05, grid: 16, drums: ['highlife', 'afrobeat'], prefer: ['g.highlife', 'hs.riffharm', 'hs.bankharm', 'b.afrobeat', 'p.afrobell', 'p.shaker'], desc: 'Bright picked guitars and sweet horn harmonies' },
];
export const styleDef = (id: string): StyleDef => STYLES.find((s) => s.id === id) ?? STYLES[0];
export const familyOf = (id: string): StyleId => styleDef(id).family;

/** One way of building or playing an instrument, with its own sound and habits. */
export interface VariantDef {
  id: string;
  name: string;
  /** General MIDI program number (0-based) */
  program: number;
  /** articulations this type can play (others fall back to a plain note) */
  arts: Art[];
  /** how much it leans on each expressive device */
  traits?: Partial<Traits>;
  /** semitones to shift the playing range */
  shift?: number;
  note?: string;
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

const BRASS: Art[] = ['sustain', 'staccato', 'marcato', 'legato', 'fall', 'doit', 'shake', 'bend'];
const REED: Art[] = ['sustain', 'staccato', 'marcato', 'legato', 'fall', 'bend', 'growl', 'subtone'];
const FRET: Art[] = ['sustain', 'staccato', 'legato', 'mute', 'ghost', 'slide', 'bend'];
const KEYB: Art[] = ['sustain', 'staccato', 'ghost'];
const KIT: Art[] = ['sustain'];

export const INSTRUMENTS: InstDef[] = [
  {
    id: 'drums',
    name: 'Drums',
    short: 'DR',
    family: 'drums',
    channel: 10,
    variants: [
      { id: 'kit', name: 'Studio kit', program: 0, arts: KIT },
      { id: 'room', name: 'Room kit', program: 8, arts: KIT },
      { id: 'power', name: 'Power kit', program: 16, arts: KIT },
      { id: 'jazzkit', name: 'Jazz kit', program: 32, arts: KIT },
      { id: 'brush', name: 'Brush kit', program: 40, arts: KIT },
      { id: 'electro', name: 'Drum machine', program: 25, arts: KIT },
    ],
  },
  { id: 'perc', name: 'Percussion', short: 'PC', family: 'perc', channel: 10, variants: [{ id: 'perc', name: 'Hand percussion', program: 0, arts: KIT }] },
  {
    id: 'bass',
    name: 'Bass',
    short: 'BS',
    family: 'bass',
    channel: 2,
    variants: [
      { id: 'finger', name: 'Electric, fingered', program: 33, arts: ['sustain', 'staccato', 'legato', 'ghost', 'slide'], note: 'Round and even; slides into roots, hammer-ons, dead notes.' },
      { id: 'pick', name: 'Electric, picked', program: 34, arts: ['sustain', 'staccato', 'mute', 'ghost', 'slide'], traits: { ghost: 0.6, grace: 0.5 }, note: 'Harder attack, fewer ornaments, palm-muted drive.' },
      { id: 'fretless', name: 'Fretless', program: 35, arts: ['sustain', 'legato', 'slide', 'gliss', 'ghost'], traits: { gliss: 1.6, slide: 1.8, vib: 2 }, note: 'Glides between notes and sings with vibrato on held tones.' },
      { id: 'slap', name: 'Slap', program: 36, arts: ['sustain', 'staccato', 'slap', 'pop', 'ghost', 'legato'], traits: { ghost: 1.6, slide: 0.5 }, note: 'Thumbed lows, popped highs, plenty of dead notes.' },
      { id: 'upright', name: 'Upright', program: 32, arts: ['sustain', 'legato', 'ghost', 'slide', 'gliss'], traits: { gliss: 0.8, slide: 1.3, vib: 0.6, ghost: 1.2 }, note: 'Woody and percussive; slides and the odd glissando.' },
      { id: 'synth', name: 'Synth bass', program: 38, arts: ['sustain', 'staccato', 'legato', 'gliss'], traits: { ghost: 0, slide: 0, grace: 0, gliss: 1.2, vib: 0 }, note: 'Machine-tight with portamento between legato notes.' },
      { id: 'fivestring', name: 'Five-string', program: 33, arts: ['sustain', 'staccato', 'legato', 'ghost', 'slide'], shift: -5, note: 'Reaches down to low B for deeper roots.' },
    ],
  },
  {
    id: 'guitar',
    name: 'Guitar',
    short: 'GT',
    family: 'guitar',
    channel: 3,
    variants: [
      { id: 'clean', name: 'Electric, clean', program: 27, arts: FRET, note: 'Chops, scratches and stabs that slide in.' },
      { id: 'jazz', name: 'Electric, hollow-body', program: 26, arts: ['sustain', 'staccato', 'legato', 'slide'], traits: { bend: 0, slide: 0.7 }, note: 'Warm and plain: no bends, soft attack.' },
      { id: 'muted', name: 'Electric, muted', program: 28, arts: ['sustain', 'staccato', 'mute', 'ghost', 'legato'], traits: { bend: 0.3 }, note: 'Palm on the bridge throughout.' },
      { id: 'overdrive', name: 'Overdriven', program: 29, arts: FRET, traits: { bend: 1.6, vib: 1.4, slide: 1.2 }, note: 'Bends up into notes, wide vibrato, palm mutes.' },
      { id: 'lead', name: 'Distorted lead', program: 30, arts: FRET, traits: { bend: 2.2, vib: 1.8, slide: 1.4 }, note: 'Singing bends and heavy vibrato on every long note.' },
      { id: 'slideguitar', name: 'Slide guitar', program: 27, arts: ['sustain', 'legato', 'gliss', 'slide'], traits: { gliss: 2.4, vib: 1.8, bend: 0 }, note: 'Glides from note to note with a bottleneck shimmer.' },
      { id: 'steel', name: 'Acoustic, steel', program: 25, arts: ['sustain', 'staccato', 'legato', 'mute', 'ghost', 'slide'], traits: { bend: 0.3 }, note: 'Full strums, ringing strings.' },
      { id: 'twelve', name: 'Acoustic, twelve-string', program: 25, arts: ['sustain', 'staccato', 'mute', 'ghost'], traits: { bend: 0 }, note: 'The lower courses are doubled an octave up.' },
      { id: 'nylon', name: 'Acoustic, nylon', program: 24, arts: ['sustain', 'staccato', 'legato', 'slide'], traits: { bend: 0, slide: 0.6 }, note: 'Fingerstyle, soft rolled chords.' },
    ],
  },
  {
    id: 'keys',
    name: 'Keys',
    short: 'KY',
    family: 'keys',
    channel: 4,
    variants: [
      { id: 'grand', name: 'Grand piano', program: 0, arts: KEYB },
      { id: 'upright', name: 'Upright piano', program: 1, arts: KEYB },
      { id: 'rhodes', name: 'Electric piano (tine)', program: 4, arts: KEYB },
      { id: 'wurli', name: 'Electric piano (reed)', program: 5, arts: KEYB },
      { id: 'clav', name: 'Clavinet', program: 7, arts: ['sustain', 'staccato', 'ghost', 'mute'] },
      { id: 'organ', name: 'Drawbar organ', program: 16, arts: ['sustain', 'staccato'] },
      { id: 'rockorgan', name: 'Rock organ', program: 18, arts: ['sustain', 'staccato'] },
      { id: 'vibes', name: 'Vibraphone', program: 11, arts: ['sustain', 'staccato'] },
      { id: 'strings', name: 'String ensemble', program: 48, arts: ['sustain', 'staccato', 'legato'] },
      { id: 'pad', name: 'Warm synth pad', program: 89, arts: ['sustain'] },
    ],
  },
  {
    id: 'trumpet',
    name: 'Trumpet',
    short: 'TP',
    family: 'horn',
    channel: 5,
    variants: [
      { id: 'open', name: 'Open', program: 56, arts: BRASS, traits: { doit: 0.6, shake: 0.6, bend: 1 }, note: 'Bright and direct: falls, doits and the odd shake.' },
      { id: 'leadtp', name: 'Lead (high and hot)', program: 56, arts: BRASS, traits: { doit: 1.6, shake: 1.8, fall: 1.4, vib: 1.2 }, shift: 4, note: 'Sits a third higher and shakes its long notes.' },
      { id: 'muted', name: 'Harmon mute', program: 59, arts: ['sustain', 'staccato', 'legato', 'bend'], traits: { fall: 0.3, vib: 0.5, scoop: 1.3 }, note: 'Thin and intimate; scoops but no shakes or falls.' },
      { id: 'cup', name: 'Cup mute', program: 59, arts: ['sustain', 'staccato', 'marcato', 'legato', 'fall'], traits: { fall: 0.7, vib: 0.8 }, note: 'Softened section sound.' },
      { id: 'flugel', name: 'Flugelhorn', program: 56, arts: ['sustain', 'legato', 'staccato', 'bend'], traits: { fall: 0.2, vib: 1.5, scoop: 0.8 }, shift: -3, note: 'Dark and round, long legato lines, deep vibrato.' },
    ],
  },
  {
    id: 'alto',
    name: 'Alto Sax',
    short: 'AS',
    family: 'horn',
    channel: 6,
    variants: [
      { id: 'alto', name: 'Alto', program: 65, arts: REED, traits: { bend: 1, growl: 0.5, subtone: 0.4 }, note: 'Singing and agile: scoops, bends and falls.' },
      { id: 'altogrowl', name: 'Alto, R&B growl', program: 65, arts: REED, traits: { growl: 2, fall: 1.4, scoop: 1.5, bend: 1.5 }, note: 'Growls on the loud notes and bends hard.' },
      { id: 'soprano', name: 'Soprano', program: 64, arts: ['sustain', 'staccato', 'legato', 'bend', 'fall'], traits: { vib: 1.3, growl: 0, subtone: 0 }, shift: 7, note: 'A fifth higher, pure with fast vibrato.' },
    ],
  },
  {
    id: 'tenor',
    name: 'Tenor Sax',
    short: 'TS',
    family: 'horn',
    channel: 7,
    variants: [
      { id: 'tenor', name: 'Tenor', program: 66, arts: REED, traits: { bend: 1, growl: 0.5, subtone: 0.8 }, note: 'Full-voiced with breathy low notes.' },
      { id: 'tenorbreathy', name: 'Tenor, breathy ballad', program: 66, arts: ['sustain', 'legato', 'subtone', 'bend', 'staccato', 'fall'], traits: { subtone: 2.4, vib: 1.6, fall: 0.3, growl: 0, bend: 0.8 }, note: 'Subtone throughout the low register, slow wide vibrato.' },
      { id: 'tenorhonk', name: 'Tenor, rock and roll', program: 66, arts: REED, traits: { growl: 2.4, fall: 1.6, scoop: 1.6, subtone: 0 }, note: 'Honks, growls and falls off every phrase.' },
    ],
  },
  {
    id: 'trombone',
    name: 'Trombone',
    short: 'TB',
    family: 'horn',
    channel: 8,
    variants: [
      { id: 'trombone', name: 'Tenor trombone', program: 57, arts: ['sustain', 'staccato', 'marcato', 'legato', 'fall', 'gliss', 'doit'], traits: { gliss: 1, doit: 0.4 }, note: 'Slides between close notes; falls on phrase ends.' },
      { id: 'basstrombone', name: 'Bass trombone', program: 57, arts: ['sustain', 'staccato', 'marcato', 'legato', 'fall', 'gliss'], traits: { gliss: 0.6, vib: 0.5 }, shift: -7, note: 'A fifth lower, anchoring the section.' },
      { id: 'plunger', name: 'Trombone, plunger', program: 57, arts: ['sustain', 'staccato', 'legato', 'gliss', 'growl', 'bend', 'fall'], traits: { gliss: 1.8, growl: 1.5, scoop: 1.8, fall: 0.6, bend: 1 }, note: 'Talking glissandi and growls.' },
    ],
  },
  { id: 'bari', name: 'Bari Sax', short: 'BX', family: 'horn', channel: 9, variants: [{ id: 'bari', name: 'Baritone', program: 67, arts: REED, traits: { growl: 1, subtone: 0.6, bend: 0.7 }, note: 'Gruff low reed; honks on the accents.' }] },
  {
    id: 'flute',
    name: 'Flute',
    short: 'FL',
    family: 'horn',
    channel: 11,
    variants: [
      { id: 'flute', name: 'Concert flute', program: 73, arts: ['sustain', 'staccato', 'legato', 'bend', 'fall'], traits: { fall: 0.4, vib: 1.5, scoop: 0.5 }, note: 'Light and quick with a shimmer on held notes.' },
      { id: 'piccolo', name: 'Piccolo', program: 72, arts: ['sustain', 'staccato', 'legato'], traits: { fall: 0.2, vib: 1 }, shift: 12, note: 'An octave higher.' },
    ],
  },
];
export const instDef = (id: InstId): InstDef => INSTRUMENTS.find((i) => i.id === id)!;
export function variantDef(inst: InstId, variant: string): VariantDef {
  const d = instDef(inst);
  return d.variants.find((v) => v.id === variant) ?? d.variants[0];
}
const TRAIT_ART: Partial<Record<keyof Traits, Art>> = { fall: 'fall', doit: 'doit', shake: 'shake', gliss: 'gliss', growl: 'growl', subtone: 'subtone', bend: 'bend', slide: 'slide', ghost: 'ghost' };
/** A type's expressive leanings; a device it has no articulation for is never used. */
export function traitsOf(inst: InstId, variant: string): Traits {
  const v = variantDef(inst, variant);
  const t: Traits = { ...NEUTRAL_TRAITS, ...(v.traits ?? {}) };
  if (instDef(inst).family === 'horn' || instDef(inst).family === 'bass' || instDef(inst).family === 'guitar') {
    for (const k of Object.keys(TRAIT_ART) as (keyof Traits)[]) if (!v.arts.includes(TRAIT_ART[k]!)) t[k] = 0;
  }
  return t;
}

export const PATTERNS: PatternDef[] = [...LIVE_DRUM_PATTERNS, ...DRUM_PATTERNS, ...PERC_PATTERNS, ...BASS_PATTERNS, ...GUITAR_PATTERNS, ...KEYS_PATTERNS, ...HORN_PATTERNS];
const byId = new Map(PATTERNS.map((p) => [p.id, p]));
export const getPattern = (id: string): PatternDef | undefined => byId.get(id);

export function patternsFor(inst: InstId): PatternDef[] {
  const fam = instDef(inst).family;
  return PATTERNS.filter((p) => p.family === fam);
}
/** Does this recipe suit the genre: by feel family, or because the genre names it. */
export function fitsGenre(p: PatternDef, genre: string): boolean {
  const g = styleDef(genre);
  return fitsStyle(p, g.family) || !!g.prefer?.includes(p.id);
}
/** Recipes for an instrument that suit a genre (falls back to everything if none do). */
export function patternsForStyle(inst: InstId, genre: string): PatternDef[] {
  const all = patternsFor(inst);
  const fit = all.filter((p) => fitsGenre(p, genre));
  return fit.length ? fit : all;
}
