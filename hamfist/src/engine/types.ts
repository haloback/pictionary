import type { DrumVoice } from "./patterns";

export type Role = "bass" | "chords" | "arp" | "drums" | "harmony" | "echo" | "drone" | "counter";

export interface LayerConfig {
  id: string;
  role: Role;
  /** Instrument preset id, or drum kit id for the drums role. */
  instrument: string;
  volume: number;
  /** 0 = plays regardless of you, 1 = only breathes when you play. */
  follow: number;
  /** Role specific richness: voices, pattern complexity, repeats. */
  density: number;
  octave: number;
  mute: boolean;
  solo: boolean;
  /** MIDI channel 1-16. */
  channel: number;
}

export const LEAD_ID = "lead";

export interface Sink {
  /** `time` is in seconds on the engine clock. Velocity is 0-1. */
  noteOn(layer: string, pitch: number, vel: number, time: number): void;
  noteOff(layer: string, pitch: number, time: number): void;
  drum(layer: string, voice: DrumVoice, vel: number, time: number): void;
  /** Raw, untranslated input. Only visualisers care. */
  raw?(pitch: number, time: number): void;
  panic(): void;
}

export interface EngineView {
  playing: boolean;
  bar: number;
  step: number;
  steps: number;
  pulse: number;
  chordIndex: number;
  chords: string[];
  energy: number;
  held: number;
}
