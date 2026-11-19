// MIDI output: maps the abstract performance (dynamics, vibrato, bends,
// articulations) onto real controllers through a per-track profile, and
// reads/writes Standard MIDI Files.

import { ALL_ARTS, PPQ } from './types';
import type { Art, Part } from './types';
import { clamp } from './theory';

export type VibTarget = 'cc' | 'bend' | 'aftertouch' | 'off';
export type ProfileId = 'gm' | 'mod' | 'breath' | 'anysynth' | 'keyswitch' | 'notes' | 'custom';

export interface MidiProfile {
  preset: ProfileId;
  /** 1..16 */
  channel: number;
  program: number;
  sendProgram: boolean;
  /** controllers that receive the dynamics curve (e.g. 11, 1, 2, 7) */
  dynCC: number[];
  vibTarget: VibTarget;
  vibCC: number;
  /** vibrato depth in semitones when rendered as pitch bend */
  vibDepth: number;
  sendBends: boolean;
  bendRange: number;
  /** send RPN 0 so the synth's bend range matches */
  sendBendRange: boolean;
  pedal: boolean;
  keyswitch: boolean;
  ksMap: Partial<Record<Art, number>>;
  velMin: number;
  velMax: number;
}

export const DEFAULT_KS: Record<Art, number> = {
  sustain: 24,
  staccato: 26,
  marcato: 28,
  legato: 29,
  mute: 31,
  ghost: 33,
  slide: 35,
  fall: 36,
  slap: 38,
  pop: 40,
  doit: 41,
  shake: 43,
  gliss: 45,
  growl: 47,
  subtone: 48,
  bend: 50,
};

export interface ProfilePreset {
  id: ProfileId;
  name: string;
  desc: string;
  patch: Partial<MidiProfile>;
}

export const PROFILE_PRESETS: ProfilePreset[] = [
  {
    id: 'gm',
    name: 'General MIDI',
    desc: 'Expression on CC11, vibrato on the mod wheel (CC1), program change and bend range sent. Works with any GM synth or multi-timbral module.',
    patch: { dynCC: [11], vibTarget: 'cc', vibCC: 1, sendBends: true, bendRange: 2, sendBendRange: true, sendProgram: true, pedal: true, keyswitch: false },
  },
  {
    id: 'mod',
    name: 'Sample library',
    desc: 'Dynamics on the mod wheel (CC1) and expression (CC11) together, vibrato on CC21. The usual layout for orchestral and horn libraries.',
    patch: { dynCC: [1, 11], vibTarget: 'cc', vibCC: 21, sendBends: true, bendRange: 2, sendBendRange: false, sendProgram: false, pedal: true, keyswitch: false },
  },
  {
    id: 'breath',
    name: 'Breath controlled',
    desc: 'Dynamics on breath (CC2) and expression (CC11), vibrato depth on CC1. For physically modelled winds and wind-controller patches.',
    patch: { dynCC: [2, 11], vibTarget: 'cc', vibCC: 1, sendBends: true, bendRange: 2, sendBendRange: false, sendProgram: false, pedal: true, keyswitch: false },
  },
  {
    id: 'anysynth',
    name: 'Any synth',
    desc: 'Dynamics on volume (CC7) and vibrato drawn into the pitch bend itself, so even a synth with no mod routing plays the full performance.',
    patch: { dynCC: [7], vibTarget: 'bend', vibCC: 1, vibDepth: 0.22, sendBends: true, bendRange: 2, sendBendRange: true, sendProgram: false, pedal: true, keyswitch: false },
  },
  {
    id: 'keyswitch',
    name: 'Keyswitch library',
    desc: 'Like Sample library, plus a keyswitch note before each change of articulation. Edit the note map to match your instrument.',
    patch: { dynCC: [1, 11], vibTarget: 'cc', vibCC: 21, sendBends: true, bendRange: 2, sendBendRange: false, sendProgram: false, pedal: true, keyswitch: true },
  },
  {
    id: 'notes',
    name: 'Notes only',
    desc: 'Just notes with humanised timing and velocity. No controllers or bends, for shaping by hand.',
    patch: { dynCC: [], vibTarget: 'off', sendBends: false, sendBendRange: false, sendProgram: false, pedal: false, keyswitch: false },
  },
];

export function makeProfile(channel: number, program: number, preset: ProfileId = 'gm'): MidiProfile {
  const base: MidiProfile = {
    preset,
    channel,
    program,
    sendProgram: true,
    dynCC: [11],
    vibTarget: 'cc',
    vibCC: 1,
    vibDepth: 0.22,
    sendBends: true,
    bendRange: 2,
    sendBendRange: true,
    pedal: true,
    keyswitch: false,
    ksMap: { ...DEFAULT_KS },
    velMin: 1,
    velMax: 127,
  };
  return applyPreset(base, preset);
}
export function applyPreset(p: MidiProfile, preset: ProfileId): MidiProfile {
  const def = PROFILE_PRESETS.find((x) => x.id === preset);
  return def ? { ...p, ...def.patch, preset } : { ...p, preset };
}

export interface MidiEv {
  t: number;
  /** raw channel message bytes */
  b: number[];
  /** sort priority within a tick (lower first) */
  o: number;
}

const VIB_HZ = 5.6;

/** Render one part to channel messages according to its profile. */
export function renderEvents(part: Part, prof: MidiProfile, tempo: number): MidiEv[] {
  const ch = clamp(prof.channel - 1, 0, 15);
  const ev: MidiEv[] = [];
  const cc = (t: number, num: number, val: number, o = 2) => ev.push({ t, b: [0xb0 | ch, num, clamp(Math.round(val), 0, 127)], o });

  if (prof.sendProgram) ev.push({ t: 0, b: [0xc0 | ch, clamp(prof.program, 0, 127)], o: 0 });
  if (prof.sendBends && prof.sendBendRange) {
    cc(0, 101, 0, 0);
    cc(0, 100, 0, 0);
    cc(0, 6, prof.bendRange, 0);
    cc(0, 38, 0, 0);
    cc(0, 101, 127, 0);
    cc(0, 100, 127, 0);
  }

  // ---- notes (+ keyswitches)
  const vel = (v: number) => clamp(Math.round(prof.velMin + (v / 127) * (prof.velMax - prof.velMin)), 1, 127);
  let lastKs = -1;
  for (const n of part.notes) {
    if (prof.keyswitch) {
      const art: Art = n.art ?? 'sustain';
      const ks = prof.ksMap[art] ?? prof.ksMap.sustain;
      if (ks != null && ks !== lastKs) {
        const kt = Math.max(0, n.t - 10);
        ev.push({ t: kt, b: [0x90 | ch, ks, 100], o: 1 });
        ev.push({ t: Math.max(kt + 1, n.t + 4), b: [0x80 | ch, ks, 0], o: 5 });
        lastKs = ks;
      }
    }
    ev.push({ t: n.t, b: [0x90 | ch, n.p, vel(n.v)], o: 4 });
    ev.push({ t: n.t + n.d, b: [0x80 | ch, n.p, 0], o: 3 });
  }

  // ---- controllers
  const last = new Map<string, number>();
  const push = (key: string, t: number, fn: () => void, val: number) => {
    if (last.get(key) === val) return;
    last.set(key, val);
    fn();
  };
  const vibPoints: { t: number; v: number }[] = [];
  for (const c of part.ctrl) {
    if (c.k === 'dyn') {
      // keep a floor so a quiet passage never mutes the instrument outright
      const val = Math.round(18 + c.v * 109);
      for (const num of prof.dynCC) push('cc' + num, c.t, () => cc(c.t, num, val), val);
    } else if (c.k === 'ped') {
      if (prof.pedal) {
        const val = c.v >= 0.5 ? 127 : 0;
        push('cc64', c.t, () => cc(c.t, 64, val, c.v >= 0.5 ? 6 : 2), val);
      }
    } else if (c.k === 'vib') {
      if (prof.vibTarget === 'cc') {
        const val = Math.round(c.v * 127);
        push('cc' + prof.vibCC, c.t, () => cc(c.t, prof.vibCC, val), val);
      } else if (prof.vibTarget === 'aftertouch') {
        const val = Math.round(c.v * 127);
        push('at', c.t, () => ev.push({ t: c.t, b: [0xd0 | ch, val], o: 2 }), val);
      } else if (prof.vibTarget === 'bend') vibPoints.push({ t: c.t, v: c.v });
    }
  }

  // ---- pitch bend (with vibrato folded in when requested)
  if (prof.sendBends) {
    const pts = part.bends.slice();
    const baseAt = (t: number): number => {
      let v = 0;
      for (const p of pts) {
        if (p.t <= t) v = p.s;
        else break;
      }
      return v;
    };
    const out: { t: number; s: number }[] = pts.map((p) => ({ t: p.t, s: p.s }));
    if (vibPoints.length) {
      const tickSec = 60 / (tempo * PPQ);
      const step = 10;
      for (let i = 0; i < vibPoints.length - 1; i++) {
        const a = vibPoints[i];
        const z = vibPoints[i + 1];
        if (a.v <= 0 && z.v <= 0) continue;
        for (let t = a.t; t < z.t; t += step) {
          const depth = a.v + ((z.v - a.v) * (t - a.t)) / Math.max(1, z.t - a.t);
          const lfo = Math.sin(2 * Math.PI * VIB_HZ * t * tickSec);
          out.push({ t, s: baseAt(t) + lfo * depth * prof.vibDepth });
        }
        if (z.v <= 0) out.push({ t: z.t, s: baseAt(z.t) });
      }
      out.sort((x, y) => x.t - y.t);
    }
    let lastBend = 8192;
    for (const p of out) {
      const val = clamp(Math.round(8192 + clamp(p.s / prof.bendRange, -1, 1) * 8191), 0, 16383);
      if (val === lastBend) continue;
      lastBend = val;
      ev.push({ t: p.t, b: [0xe0 | ch, val & 0x7f, (val >> 7) & 0x7f], o: 2 });
    }
  }

  ev.sort((a, c) => a.t - c.t || a.o - c.o);
  return ev;
}

// ------------------------------------------------------------------ SMF writer

function vlq(n: number): number[] {
  n = Math.max(0, Math.round(n));
  const out = [n & 0x7f];
  n >>= 7;
  while (n > 0) {
    out.unshift((n & 0x7f) | 0x80);
    n >>= 7;
  }
  return out;
}
function meta(type: number, data: number[]): number[] {
  return [0xff, type, ...vlq(data.length), ...data];
}
function text(type: number, s: string): number[] {
  const bytes = Array.from(new TextEncoder().encode(s));
  return meta(type, bytes);
}
function chunk(id: string, data: number[]): number[] {
  const len = data.length;
  return [...id.split('').map((c) => c.charCodeAt(0)), (len >>> 24) & 0xff, (len >>> 16) & 0xff, (len >>> 8) & 0xff, len & 0xff, ...data];
}

export interface SmfTrack {
  name: string;
  events: MidiEv[];
}
export interface SmfInput {
  title: string;
  tempo: number;
  /** total length in ticks: every track ends exactly here so clips loop cleanly */
  len: number;
  markers?: { t: number; text: string }[];
  tracks: SmfTrack[];
}

interface RawEv {
  t: number;
  o: number;
  data: number[];
}
function trackChunk(evs: RawEv[], len: number): number[] {
  evs.sort((a, b) => a.t - b.t || a.o - b.o);
  const data: number[] = [];
  let prev = 0;
  for (const e of evs) {
    const t = clamp(Math.round(e.t), 0, len);
    data.push(...vlq(t - prev), ...e.data);
    prev = t;
  }
  data.push(...vlq(Math.max(0, len - prev)), 0xff, 0x2f, 0x00);
  return chunk('MTrk', data);
}

/** Write a Standard MIDI File. One track -> format 0, several -> format 1 with a tempo track. */
export function writeSMF(input: SmfInput): Uint8Array {
  const mpq = Math.round(60000000 / input.tempo);
  const conductor: RawEv[] = [
    { t: 0, o: -3, data: text(0x03, input.title) },
    { t: 0, o: -2, data: meta(0x51, [(mpq >> 16) & 0xff, (mpq >> 8) & 0xff, mpq & 0xff]) },
    { t: 0, o: -2, data: meta(0x58, [4, 2, 24, 8]) },
    ...(input.markers ?? []).map((m) => ({ t: m.t, o: -1, data: text(0x06, m.text) })),
  ];
  const single = input.tracks.length === 1;
  const chunks: number[] = [];
  if (single) {
    const tr = input.tracks[0];
    const evs: RawEv[] = [...conductor.slice(1), { t: 0, o: -3, data: text(0x03, tr.name) }, ...tr.events.map((e) => ({ t: e.t, o: e.o, data: e.b }))];
    chunks.push(...trackChunk(evs, input.len));
  } else {
    chunks.push(...trackChunk(conductor, input.len));
    for (const tr of input.tracks) {
      const evs: RawEv[] = [{ t: 0, o: -3, data: text(0x03, tr.name) }, ...tr.events.map((e) => ({ t: e.t, o: e.o, data: e.b }))];
      chunks.push(...trackChunk(evs, input.len));
    }
  }
  const nTracks = single ? 1 : input.tracks.length + 1;
  const header = chunk('MThd', [0, single ? 0 : 1, (nTracks >> 8) & 0xff, nTracks & 0xff, (PPQ >> 8) & 0xff, PPQ & 0xff]);
  return new Uint8Array([...header, ...chunks]);
}

// ------------------------------------------------------------------ SMF reader

export interface ParsedNote {
  t: number;
  d: number;
  p: number;
  v: number;
  ch: number;
  track: number;
}
export interface ParsedSmf {
  format: number;
  ppq: number;
  tempo: number;
  nTracks: number;
  trackNames: string[];
  notes: ParsedNote[];
  cc: { t: number; ch: number; num: number; val: number; track: number }[];
  bends: { t: number; ch: number; val: number; track: number }[];
  markers: { t: number; text: string }[];
  /** end-of-track tick per track */
  ends: number[];
}

export function parseSMF(bytes: Uint8Array): ParsedSmf {
  let pos = 0;
  const u8 = () => bytes[pos++];
  const u16 = () => (u8() << 8) | u8();
  const u32 = () => ((u8() << 24) | (u8() << 16) | (u8() << 8) | u8()) >>> 0;
  const str = (n: number) => {
    const s = new TextDecoder().decode(bytes.subarray(pos, pos + n));
    pos += n;
    return s;
  };
  const readVlq = () => {
    let v = 0;
    for (let i = 0; i < 4; i++) {
      const b = u8();
      v = (v << 7) | (b & 0x7f);
      if (!(b & 0x80)) break;
    }
    return v;
  };
  if (str(4) !== 'MThd') throw new Error('Not a MIDI file');
  const hlen = u32();
  const format = u16();
  const nTracks = u16();
  const division = u16();
  pos += hlen - 6;
  if (division & 0x8000) throw new Error('SMPTE time division is not supported');
  const out: ParsedSmf = { format, ppq: division, tempo: 120, nTracks, trackNames: [], notes: [], cc: [], bends: [], markers: [], ends: [] };
  let gotTempo = false;
  for (let tr = 0; tr < nTracks && pos < bytes.length; tr++) {
    if (str(4) !== 'MTrk') throw new Error('Bad track chunk');
    const len = u32();
    const end = pos + len;
    let t = 0;
    let status = 0;
    const open = new Map<number, { t: number; v: number }[]>();
    out.trackNames[tr] = '';
    while (pos < end) {
      t += readVlq();
      let b = u8();
      if (b < 0x80) {
        pos--;
        b = status;
      } else if (b < 0xf0) status = b;
      if (b === 0xff) {
        const type = u8();
        const l = readVlq();
        if (type === 0x51 && !gotTempo) {
          out.tempo = 60000000 / ((bytes[pos] << 16) | (bytes[pos + 1] << 8) | bytes[pos + 2]);
          gotTempo = true;
        } else if (type === 0x03) out.trackNames[tr] = new TextDecoder().decode(bytes.subarray(pos, pos + l));
        else if (type === 0x06) out.markers.push({ t, text: new TextDecoder().decode(bytes.subarray(pos, pos + l)) });
        else if (type === 0x2f) out.ends[tr] = t;
        pos += l;
      } else if (b === 0xf0 || b === 0xf7) {
        pos += readVlq();
      } else {
        const type = b & 0xf0;
        const ch = b & 0x0f;
        const d1 = u8();
        const d2 = type === 0xc0 || type === 0xd0 ? 0 : u8();
        const key = (ch << 8) | d1;
        if (type === 0x90 && d2 > 0) {
          if (!open.has(key)) open.set(key, []);
          open.get(key)!.push({ t, v: d2 });
        } else if (type === 0x80 || (type === 0x90 && d2 === 0)) {
          const o = open.get(key)?.shift();
          if (o) out.notes.push({ t: o.t, d: t - o.t, p: d1, v: o.v, ch, track: tr });
        } else if (type === 0xb0) out.cc.push({ t, ch, num: d1, val: d2, track: tr });
        else if (type === 0xe0) out.bends.push({ t, ch, val: (d2 << 7) | d1, track: tr });
      }
    }
    pos = end;
  }
  out.notes.sort((a, b) => a.t - b.t);
  return out;
}

export const ART_LABEL: Record<Art, string> = {
  sustain: 'Sustain',
  staccato: 'Staccato',
  marcato: 'Marcato',
  legato: 'Legato',
  mute: 'Muted',
  ghost: 'Dead note',
  slide: 'Slide',
  fall: 'Fall',
  slap: 'Slap',
  pop: 'Pop',
  doit: 'Doit',
  shake: 'Shake',
  gliss: 'Glissando',
  growl: 'Growl',
  subtone: 'Subtone',
  bend: 'Bend up',
};
export { ALL_ARTS };
