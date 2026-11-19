// Core data model for the Sideman engine.
// Everything is expressed in ticks (PPQ = 480) on a 4/4 grid.

export const PPQ = 480;
export const BEAT = PPQ;
export const BAR = PPQ * 4;
export const S16 = PPQ / 4; // one sixteenth-note step

/** Articulation tags. The MIDI renderer can map these to keyswitches. */
export type Art =
  | 'sustain'
  | 'staccato'
  | 'marcato'
  | 'legato'
  | 'mute' // palm mute / muted
  | 'ghost' // dead note / scratch
  | 'slide'
  | 'fall'
  | 'slap'
  | 'pop';

export const ALL_ARTS: Art[] = ['sustain', 'staccato', 'marcato', 'legato', 'mute', 'ghost', 'slide', 'fall', 'slap', 'pop'];

export interface Note {
  t: number; // start tick
  d: number; // duration ticks
  p: number; // MIDI pitch
  v: number; // velocity 1..127
  art?: Art;
}

/** Abstract continuous controllers, 0..1. Mapped to real CCs by a MIDI profile. */
export type CtrlKind = 'dyn' | 'vib' | 'ped';
export interface Ctrl {
  t: number;
  k: CtrlKind;
  v: number;
}

/** Pitch bend in semitones (can be fractional). */
export interface Bend {
  t: number;
  s: number;
}

export interface Part {
  notes: Note[];
  ctrl: Ctrl[];
  bends: Bend[];
}

export type InstId =
  | 'drums'
  | 'perc'
  | 'bass'
  | 'guitar'
  | 'keys'
  | 'trumpet'
  | 'alto'
  | 'tenor'
  | 'trombone'
  | 'bari';

export type Family = 'drums' | 'bass' | 'guitar' | 'keys' | 'horn';

export type StyleId =
  | 'funk'
  | 'soul'
  | 'pop'
  | 'rock'
  | 'jazz'
  | 'bossa'
  | 'reggae'
  | 'ballad'
  | 'neosoul'
  | 'afrobeat'
  | 'blues';

export interface Chord {
  sym: string;
  root: number; // pitch class 0..11
  bass: number; // pitch class of the bass note (slash chords)
  third: 3 | 4 | null;
  fifth: 6 | 7 | 8 | null;
  seventh: 9 | 10 | 11 | null;
  sixth: boolean;
  sus: 2 | 5 | null;
  tensions: number[]; // semitone intervals above root, mod 12 (1,2,3,5,6,8,9)
  quality: 'maj' | 'min' | 'dom' | 'dim' | 'hdim' | 'aug' | 'sus' | 'power';
  nc?: boolean; // "N.C." – no chord
}

export interface Key {
  tonic: number;
  minor: boolean;
}

export interface ChordSpan {
  t: number;
  d: number;
  chord: Chord;
  bar: number;
  /** true when this span starts a different chord than the previous span */
  change: boolean;
}

export interface TrackParams {
  /** 0..1 – how busy / ornamented the part is */
  complexity: number;
  /** 0..1 – overall loudness (velocity + dynamics) */
  dynamics: number;
  /** 0..1 – timing and velocity looseness */
  humanize: number;
  /** 0..1 – how many slides, falls, scoops, ghost notes, vibrato */
  expression: number;
  /** octave shift, -2..2 */
  octave: number;
}

export const DEFAULT_PARAMS: TrackParams = {
  complexity: 0.5,
  dynamics: 0.7,
  humanize: 0.5,
  expression: 0.6,
  octave: 0,
};
