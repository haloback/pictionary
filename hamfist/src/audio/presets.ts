// Built-in instrument presets. All are synthesised with Tone.js
// (https://github.com/Tonejs/Tone.js) so the app works offline with no
// sample downloads. Each preset also names the General MIDI program that is
// sent on MIDI out and written to exported files.

export type Env = [attack: number, decay: number, sustain: number, release: number];

export interface FilterEnv {
  base: number;
  oct: number;
  env: Env;
  q?: number;
}

export interface Preset {
  id: string;
  name: string;
  cat: string;
  gm: number;
  voice: "synth" | "fm" | "mono";
  osc?: Record<string, unknown>;
  env: Env;
  /** fm only */
  harm?: number;
  index?: number;
  modEnv?: Env;
  /** mono only */
  filt?: FilterEnv;
  /** dB trim */
  gain?: number;
  /** static low-pass in Hz */
  lp?: number;
  chorus?: boolean;
  vibrato?: number;
  tremolo?: number;
  drive?: number;
  rev?: number;
  dly?: number;
}

const P = (id: string, name: string, cat: string, gm: number, p: Omit<Preset, "id" | "name" | "cat" | "gm">): Preset => ({ id, name, cat, gm, ...p });
const partials = (...p: number[]) => ({ type: "custom", partials: p });
const fat = (type: string, count: number, spread: number) => ({ type: `fat${type}`, count, spread });

export const PRESETS: Preset[] = [
  // Keys
  P("grand", "Grand Piano", "Keys", 0, { voice: "mono", osc: partials(1, 0.62, 0.36, 0.26, 0.14, 0.1, 0.06, 0.04), env: [0.003, 2.2, 0, 0.5], filt: { base: 320, oct: 4.6, env: [0.002, 1.0, 0.12, 0.5] }, rev: 0.22 }),
  P("bright", "Bright Piano", "Keys", 1, { voice: "mono", osc: partials(1, 0.8, 0.55, 0.42, 0.3, 0.22, 0.15, 0.1, 0.07), env: [0.002, 1.6, 0, 0.35], filt: { base: 600, oct: 4.8, env: [0.001, 0.7, 0.15, 0.4] }, rev: 0.15 }),
  P("epiano", "Electric Piano", "Keys", 4, { voice: "fm", harm: 1, index: 2.4, env: [0.004, 1.8, 0.12, 0.6], modEnv: [0.002, 0.5, 0.08, 0.4], tremolo: 0.25, chorus: true, rev: 0.2 }),
  P("wurli", "Reed Piano", "Keys", 5, { voice: "fm", harm: 2, index: 1.8, env: [0.003, 1.1, 0.1, 0.3], modEnv: [0.002, 0.3, 0.2, 0.3], drive: 0.12, tremolo: 0.35, rev: 0.15 }),
  P("harpsi", "Harpsichord", "Keys", 6, { voice: "mono", osc: { type: "pulse", width: 0.82 }, env: [0.001, 1.0, 0, 0.12], filt: { base: 1800, oct: 2.5, env: [0.001, 0.5, 0.2, 0.2] }, gain: -5, rev: 0.25 }),
  P("clav", "Clavinet", "Keys", 7, { voice: "mono", osc: { type: "pulse", width: 0.7 }, env: [0.001, 0.4, 0, 0.07], filt: { base: 500, oct: 3.6, env: [0.001, 0.16, 0.1, 0.1], q: 3 }, gain: -3, rev: 0.08 }),
  P("celesta", "Celesta", "Keys", 8, { voice: "fm", harm: 4, index: 1.2, env: [0.001, 1.1, 0, 0.9], modEnv: [0.001, 0.25, 0, 0.3], rev: 0.35 }),
  P("musicbox", "Music Box", "Keys", 10, { voice: "fm", harm: 7, index: 0.9, env: [0.001, 1.5, 0, 1.3], modEnv: [0.001, 0.2, 0, 0.2], gain: -2, rev: 0.4 }),
  // Mallets
  P("vibes", "Vibraphone", "Mallets", 11, { voice: "fm", harm: 4, index: 0.6, env: [0.002, 2.4, 0, 1.6], modEnv: [0.001, 0.4, 0, 0.4], tremolo: 0.45, rev: 0.35 }),
  P("marimba", "Marimba", "Mallets", 12, { voice: "fm", harm: 4, index: 1.6, env: [0.001, 0.5, 0, 0.3], modEnv: [0.001, 0.07, 0, 0.1], rev: 0.2 }),
  P("kalimba", "Kalimba", "Mallets", 108, { voice: "fm", harm: 8, index: 2, env: [0.001, 0.7, 0, 0.45], modEnv: [0.001, 0.05, 0, 0.1], rev: 0.3, dly: 0.12 }),
  P("steeldrum", "Steel Pan", "Mallets", 114, { voice: "fm", harm: 2.01, index: 3.2, env: [0.002, 0.9, 0.04, 0.5], modEnv: [0.001, 0.3, 0.1, 0.3], rev: 0.25 }),
  P("bell", "Bell", "Mallets", 14, { voice: "fm", harm: 3.5, index: 5, env: [0.001, 2.6, 0, 2.2], modEnv: [0.001, 1.2, 0.1, 1], gain: -6, rev: 0.45 }),
  // Organs and reeds
  P("organ", "Drawbar Organ", "Organ", 16, { voice: "synth", osc: partials(1, 0.9, 0.5, 0.55, 0, 0.25, 0, 0.3), env: [0.008, 0.05, 1, 0.06], chorus: true, gain: -6, rev: 0.18 }),
  P("rockorgan", "Rock Organ", "Organ", 18, { voice: "synth", osc: partials(1, 1, 0.8, 0.6, 0.3, 0.4, 0.1, 0.4, 0.2), env: [0.006, 0.05, 1, 0.07], chorus: true, drive: 0.25, gain: -9, rev: 0.15 }),
  P("church", "Pipe Organ", "Organ", 19, { voice: "synth", osc: partials(1, 0.7, 0.5, 0.42, 0.3, 0.25, 0.2, 0.16, 0.1), env: [0.07, 0.1, 1, 0.55], gain: -8, rev: 0.6 }),
  P("accordion", "Accordion", "Organ", 21, { voice: "mono", osc: fat("square", 2, 14), env: [0.04, 0.1, 0.9, 0.12], filt: { base: 900, oct: 1.6, env: [0.05, 0.2, 0.8, 0.2] }, gain: -8, rev: 0.15 }),
  P("harmonica", "Harmonica", "Organ", 22, { voice: "mono", osc: { type: "pulse", width: 0.62 }, env: [0.03, 0.1, 0.85, 0.1], filt: { base: 1100, oct: 1.4, env: [0.04, 0.2, 0.7, 0.2], q: 2 }, vibrato: 0.12, gain: -9, rev: 0.2 }),
  // Guitars and plucked strings
  P("nylon", "Nylon Guitar", "Guitar", 24, { voice: "mono", osc: partials(1, 0.5, 0.32, 0.16, 0.09, 0.05), env: [0.002, 1.2, 0, 0.3], filt: { base: 420, oct: 3.2, env: [0.001, 0.4, 0.1, 0.3] }, rev: 0.2 }),
  P("steel", "Steel Guitar", "Guitar", 25, { voice: "mono", osc: { type: "sawtooth" }, env: [0.002, 1.5, 0, 0.4], filt: { base: 700, oct: 3.8, env: [0.001, 0.6, 0.1, 0.4] }, gain: -5, rev: 0.2 }),
  P("jazzgtr", "Jazz Guitar", "Guitar", 26, { voice: "mono", osc: partials(1, 0.6, 0.25, 0.1, 0.05), env: [0.003, 1.1, 0, 0.25], filt: { base: 320, oct: 2.2, env: [0.001, 0.3, 0.2, 0.3] }, rev: 0.18 }),
  P("clean", "Clean Electric", "Guitar", 27, { voice: "mono", osc: { type: "sawtooth" }, env: [0.002, 1.6, 0.05, 0.35], filt: { base: 900, oct: 3, env: [0.001, 0.5, 0.15, 0.4] }, chorus: true, gain: -6, rev: 0.25, dly: 0.08 }),
  P("muted", "Muted Guitar", "Guitar", 28, { voice: "mono", osc: { type: "sawtooth" }, env: [0.001, 0.15, 0, 0.06], filt: { base: 320, oct: 3, env: [0.001, 0.08, 0, 0.08] }, gain: -3, rev: 0.1 }),
  P("overdrive", "Overdriven Guitar", "Guitar", 29, { voice: "mono", osc: { type: "sawtooth" }, env: [0.004, 0.4, 0.6, 0.2], filt: { base: 700, oct: 2.4, env: [0.003, 0.4, 0.5, 0.3] }, drive: 0.4, lp: 3800, gain: -12, rev: 0.2 }),
  P("dist", "Distortion Guitar", "Guitar", 30, { voice: "mono", osc: fat("sawtooth", 2, 10), env: [0.004, 0.3, 0.8, 0.18], filt: { base: 600, oct: 2.6, env: [0.003, 0.4, 0.6, 0.3] }, drive: 0.8, lp: 3200, gain: -16, rev: 0.15 }),
  P("banjo", "Banjo", "Guitar", 105, { voice: "mono", osc: { type: "pulse", width: 0.88 }, env: [0.001, 0.5, 0, 0.14], filt: { base: 1500, oct: 2.4, env: [0.001, 0.2, 0.1, 0.2] }, gain: -6, rev: 0.12 }),
  P("harp", "Harp", "Guitar", 46, { voice: "mono", osc: partials(1, 0.4, 0.2, 0.1, 0.04), env: [0.002, 2.0, 0, 1.1], filt: { base: 500, oct: 3, env: [0.001, 0.6, 0.1, 0.6] }, rev: 0.4 }),
  P("pizz", "Pizzicato", "Strings", 45, { voice: "mono", osc: { type: "sawtooth" }, env: [0.002, 0.28, 0, 0.16], filt: { base: 500, oct: 2.2, env: [0.001, 0.12, 0, 0.12] }, gain: -3, rev: 0.3 }),
  // World
  P("sitar", "Sitar", "World", 104, { voice: "fm", harm: 1.005, index: 9, env: [0.002, 2.0, 0, 0.5], modEnv: [0.001, 1.3, 0.1, 0.5], gain: -7, rev: 0.3 }),
  P("koto", "Koto", "World", 107, { voice: "mono", osc: { type: "pulse", width: 0.8 }, env: [0.001, 1.1, 0, 0.4], filt: { base: 700, oct: 3.4, env: [0.001, 0.25, 0.05, 0.3] }, gain: -5, rev: 0.35 }),
  P("shamisen", "Shamisen", "World", 106, { voice: "mono", osc: { type: "pulse", width: 0.92 }, env: [0.001, 0.5, 0, 0.2], filt: { base: 900, oct: 3, env: [0.001, 0.12, 0.05, 0.2], q: 2 }, gain: -6, rev: 0.2 }),
  P("oud", "Oud", "World", 24, { voice: "mono", osc: partials(1, 0.7, 0.45, 0.2, 0.15, 0.06), env: [0.002, 0.9, 0, 0.25], filt: { base: 380, oct: 3, env: [0.001, 0.3, 0.1, 0.3] }, rev: 0.25 }),
  P("panflute", "Pan Flute", "World", 75, { voice: "synth", osc: partials(1, 0.12, 0.3, 0.04), env: [0.05, 0.15, 0.8, 0.22], vibrato: 0.08, rev: 0.4 }),
  P("shaku", "Shakuhachi", "World", 77, { voice: "synth", osc: partials(1, 0.45, 0.1, 0.15), env: [0.1, 0.2, 0.8, 0.3], vibrato: 0.2, rev: 0.45 }),
  P("bagpipe", "Bagpipe", "World", 109, { voice: "mono", osc: fat("sawtooth", 2, 6), env: [0.05, 0.1, 1, 0.1], filt: { base: 1400, oct: 1, env: [0.05, 0.1, 1, 0.1], q: 3 }, gain: -12, rev: 0.25 }),
  // Bass
  P("upright", "Upright Bass", "Bass", 32, { voice: "mono", osc: partials(1, 0.5, 0.25, 0.12), env: [0.01, 0.8, 0.12, 0.2], filt: { base: 160, oct: 2.6, env: [0.004, 0.3, 0.2, 0.3] }, gain: 2, rev: 0.08 }),
  P("finger", "Finger Bass", "Bass", 33, { voice: "mono", osc: partials(1, 0.7, 0.4, 0.3, 0.15), env: [0.004, 0.9, 0.3, 0.12], filt: { base: 200, oct: 2.6, env: [0.002, 0.25, 0.3, 0.2] }, gain: 1, rev: 0.04 }),
  P("pick", "Picked Bass", "Bass", 34, { voice: "mono", osc: { type: "sawtooth" }, env: [0.002, 0.8, 0.25, 0.1], filt: { base: 300, oct: 3.4, env: [0.001, 0.2, 0.25, 0.2] }, gain: -3, rev: 0.04 }),
  P("slap", "Slap Bass", "Bass", 36, { voice: "mono", osc: { type: "sawtooth" }, env: [0.001, 0.4, 0.1, 0.08], filt: { base: 250, oct: 5, env: [0.001, 0.12, 0.1, 0.1], q: 3 }, gain: -3, rev: 0.05 }),
  P("fretless", "Fretless Bass", "Bass", 35, { voice: "mono", osc: partials(1, 0.6, 0.3, 0.1), env: [0.03, 0.6, 0.6, 0.2], filt: { base: 250, oct: 2, env: [0.03, 0.3, 0.5, 0.3] }, gain: 1, chorus: true, rev: 0.1 }),
  P("synthbass", "Synth Bass", "Bass", 38, { voice: "mono", osc: { type: "sawtooth" }, env: [0.003, 0.3, 0.5, 0.1], filt: { base: 120, oct: 4, env: [0.002, 0.2, 0.3, 0.15], q: 2 }, gain: -2 }),
  P("sub", "Sub Bass", "Bass", 39, { voice: "synth", osc: partials(1, 0.18, 0.05), env: [0.006, 0.4, 0.85, 0.25], gain: 3 }),
  P("reese", "Reese Bass", "Bass", 39, { voice: "mono", osc: fat("sawtooth", 3, 30), env: [0.01, 0.2, 1, 0.15], filt: { base: 160, oct: 2.5, env: [0.01, 0.4, 0.5, 0.3], q: 1.5 }, gain: -6 }),
  P("acid", "Acid Line", "Bass", 38, { voice: "mono", osc: { type: "sawtooth" }, env: [0.002, 0.2, 0.4, 0.08], filt: { base: 180, oct: 4.6, env: [0.002, 0.15, 0.1, 0.1], q: 9 }, gain: -8, dly: 0.15 }),
  P("log", "Log Drum Bass", "Bass", 117, { voice: "fm", harm: 0.5, index: 5, env: [0.001, 0.6, 0, 0.2], modEnv: [0.001, 0.09, 0, 0.1], gain: 2 }),
  // Strings, brass, winds, voices
  P("violin", "Violin", "Strings", 40, { voice: "mono", osc: { type: "sawtooth" }, env: [0.07, 0.2, 0.85, 0.2], filt: { base: 900, oct: 2, env: [0.08, 0.3, 0.7, 0.3] }, vibrato: 0.12, gain: -9, rev: 0.35 }),
  P("fiddle", "Fiddle", "Strings", 110, { voice: "mono", osc: { type: "sawtooth" }, env: [0.03, 0.15, 0.85, 0.12], filt: { base: 1200, oct: 2, env: [0.03, 0.2, 0.7, 0.2] }, vibrato: 0.08, gain: -10, rev: 0.25 }),
  P("strings", "String Section", "Strings", 48, { voice: "synth", osc: fat("sawtooth", 3, 18), env: [0.12, 0.3, 0.9, 0.5], lp: 2600, gain: -12, rev: 0.4 }),
  P("slowstr", "Slow Strings", "Strings", 49, { voice: "synth", osc: fat("sawtooth", 3, 22), env: [0.6, 0.4, 0.9, 1.4], lp: 2000, gain: -12, rev: 0.5 }),
  P("choir", "Choir", "Strings", 52, { voice: "synth", osc: { type: "fatcustom", partials: [1, 0.3, 0.5, 0.1, 0.2, 0.05], count: 3, spread: 20 }, env: [0.25, 0.3, 0.9, 0.9], chorus: true, lp: 2400, gain: -8, rev: 0.55 }),
  P("trumpet", "Trumpet", "Brass", 56, { voice: "mono", osc: { type: "sawtooth" }, env: [0.03, 0.15, 0.75, 0.1], filt: { base: 500, oct: 3, env: [0.04, 0.25, 0.6, 0.2] }, vibrato: 0.05, gain: -8, rev: 0.25 }),
  P("brass", "Brass Section", "Brass", 61, { voice: "mono", osc: fat("sawtooth", 3, 10), env: [0.04, 0.2, 0.8, 0.15], filt: { base: 450, oct: 3, env: [0.05, 0.3, 0.6, 0.2] }, gain: -12, rev: 0.25 }),
  P("sax", "Saxophone", "Brass", 65, { voice: "mono", osc: { type: "pulse", width: 0.66 }, env: [0.035, 0.15, 0.8, 0.12], filt: { base: 600, oct: 2.2, env: [0.04, 0.3, 0.6, 0.2], q: 2 }, vibrato: 0.1, gain: -8, rev: 0.25 }),
  P("flute", "Flute", "Brass", 73, { voice: "synth", osc: partials(1, 0.25, 0.1, 0.03), env: [0.06, 0.1, 0.9, 0.15], vibrato: 0.1, rev: 0.35 }),
  // Synths
  P("square", "Square Lead", "Synth", 80, { voice: "mono", osc: { type: "square" }, env: [0.004, 0.1, 0.7, 0.1], filt: { base: 2000, oct: 2, env: [0.004, 0.2, 0.6, 0.2] }, gain: -12, rev: 0.15, dly: 0.12 }),
  P("saw", "Saw Lead", "Synth", 81, { voice: "mono", osc: { type: "sawtooth" }, env: [0.005, 0.15, 0.7, 0.15], filt: { base: 1200, oct: 2.5, env: [0.005, 0.3, 0.5, 0.2], q: 1.5 }, gain: -11, rev: 0.2, dly: 0.15 }),
  P("supersaw", "Supersaw", "Synth", 81, { voice: "synth", osc: fat("sawtooth", 5, 32), env: [0.01, 0.2, 0.8, 0.3], lp: 6000, gain: -14, rev: 0.3, dly: 0.12 }),
  P("pluck", "Synth Pluck", "Synth", 84, { voice: "mono", osc: { type: "sawtooth" }, env: [0.001, 0.32, 0, 0.2], filt: { base: 300, oct: 4.6, env: [0.001, 0.18, 0, 0.2], q: 2 }, gain: -4, rev: 0.25, dly: 0.2 }),
  P("pad", "Warm Pad", "Synth", 89, { voice: "synth", osc: fat("sawtooth", 3, 22), env: [0.5, 0.5, 0.85, 1.4], lp: 1400, chorus: true, gain: -11, rev: 0.45 }),
  P("glass", "Glass Pad", "Synth", 88, { voice: "fm", harm: 2, index: 1.5, env: [0.3, 0.6, 0.7, 1.6], modEnv: [0.4, 0.5, 0.4, 1], chorus: true, gain: -5, rev: 0.55, dly: 0.15 }),
  P("polysynth", "Poly Synth", "Synth", 90, { voice: "mono", osc: fat("sawtooth", 2, 14), env: [0.012, 0.3, 0.6, 0.35], filt: { base: 700, oct: 3, env: [0.01, 0.35, 0.3, 0.3] }, gain: -11, rev: 0.25 }),
  P("synthbrass", "Synth Brass", "Synth", 62, { voice: "mono", osc: fat("sawtooth", 3, 14), env: [0.02, 0.2, 0.8, 0.2], filt: { base: 500, oct: 3.2, env: [0.05, 0.25, 0.5, 0.2] }, gain: -12, rev: 0.2 }),
  P("chip", "Chip Pulse", "Synth", 80, { voice: "synth", osc: { type: "pulse", width: 0.5 }, env: [0.001, 0.05, 0.9, 0.03], gain: -14 }),
];

const index = new Map(PRESETS.map((p) => [p.id, p]));

export function getPreset(id: string): Preset {
  return index.get(id) ?? PRESETS[0];
}

export const PRESET_CATS: string[] = [...new Set(PRESETS.map((p) => p.cat))];

export interface KitDef {
  id: string;
  name: string;
  kick: { freq: number; decay: number; drop: number; oct: number };
  snare: { decay: number; tone: number; gain: number };
  hat: number;
  lp: number;
  gain: number;
  latin?: boolean;
}

export const KITS: KitDef[] = [
  { id: "acoustic", name: "Studio Kit", kick: { freq: 52, decay: 0.32, drop: 0.03, oct: 5 }, snare: { decay: 0.2, tone: 190, gain: 0 }, hat: 0.045, lp: 16000, gain: 0 },
  { id: "brush", name: "Brush Kit", kick: { freq: 58, decay: 0.24, drop: 0.02, oct: 3 }, snare: { decay: 0.26, tone: 210, gain: -8 }, hat: 0.06, lp: 9000, gain: -4 },
  { id: "rock", name: "Rock Kit", kick: { freq: 48, decay: 0.4, drop: 0.035, oct: 6 }, snare: { decay: 0.28, tone: 170, gain: 2 }, hat: 0.05, lp: 16000, gain: 1 },
  { id: "808", name: "808", kick: { freq: 44, decay: 0.9, drop: 0.06, oct: 4 }, snare: { decay: 0.16, tone: 230, gain: -2 }, hat: 0.03, lp: 16000, gain: 0 },
  { id: "909", name: "909", kick: { freq: 50, decay: 0.38, drop: 0.045, oct: 7 }, snare: { decay: 0.2, tone: 200, gain: 0 }, hat: 0.035, lp: 16000, gain: 0 },
  { id: "lofi", name: "Dusty Kit", kick: { freq: 54, decay: 0.3, drop: 0.04, oct: 4 }, snare: { decay: 0.17, tone: 180, gain: -3 }, hat: 0.04, lp: 5200, gain: -1 },
  { id: "latin", name: "Percussion", kick: { freq: 60, decay: 0.26, drop: 0.02, oct: 3 }, snare: { decay: 0.14, tone: 260, gain: -4 }, hat: 0.04, lp: 14000, gain: 0, latin: true },
];

export function getKit(id: string): KitDef {
  return KITS.find((k) => k.id === id) ?? KITS[0];
}
