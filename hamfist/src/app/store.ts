import { create } from "zustand";
import { persist } from "zustand/middleware";
import { getGenre, type Genre } from "../engine/genres";
import type { LayerConfig, Role } from "../engine/types";
import type { PortInfo } from "../audio/midi";

/** "auto" means: whatever the current genre uses for this role. */
export const AUTO = "auto";

export interface LeadState {
  instrument: string;
  volume: number;
  octave: number;
  channel: number;
}

export interface AppState {
  genreId: string;
  keyRoot: number;
  bpm: number;
  tempoLocked: boolean;
  progIndex: number;
  tighten: number;
  autoStop: boolean;
  lead: LeadState;
  layers: LayerConfig[];
  midiOut: string;
  // session only
  audioReady: boolean;
  midiIns: PortInfo[];
  midiOuts: PortInfo[];
  midiError: string | null;
  toast: string | null;

  setGenre(id: string): void;
  setKey(root: number): void;
  setBpm(bpm: number): void;
  setTempoLocked(v: boolean): void;
  setProg(i: number): void;
  setTighten(v: number): void;
  setAutoStop(v: boolean): void;
  setLead(p: Partial<LeadState>): void;
  addLayer(role: Role): void;
  updateLayer(id: string, p: Partial<LayerConfig>): void;
  removeLayer(id: string): void;
  setMidiOut(id: string): void;
  set(p: Partial<AppState>): void;
}

export const ROLE_INFO: Record<Role, { name: string; blurb: string; follow: number; density: number }> = {
  drums: { name: "Drums", blurb: "The genre's groove, building as you play harder", follow: 0.6, density: 0.65 },
  bass: { name: "Bass", blurb: "Walks the chord roots in the genre's bass style", follow: 0.5, density: 0.7 },
  chords: { name: "Chords", blurb: "Comps the progression with smooth voice leading", follow: 0.6, density: 0.5 },
  arp: { name: "Arpeggio", blurb: "Runs up and down the current chord", follow: 0.7, density: 0.5 },
  harmony: { name: "Harmony", blurb: "Shadows every note you play in thirds and sixths", follow: 1, density: 0.4 },
  echo: { name: "Echo", blurb: "Repeats your phrases, re-pitched to the next chord", follow: 1, density: 0.4 },
  drone: { name: "Drone", blurb: "Holds the root and fifth under everything", follow: 0.4, density: 0.4 },
  counter: { name: "Counter-melody", blurb: "Answers you in the gaps between phrases", follow: 0.8, density: 0.5 },
};

export const ROLES = Object.keys(ROLE_INFO) as Role[];

export function resolveInstrument(role: Role | "lead", instrument: string, g: Genre): string {
  if (instrument !== AUTO) return instrument;
  switch (role) {
    case "lead":
      return g.lead;
    case "drums":
      return g.kit;
    case "bass":
      return g.bassI;
    case "chords":
      return g.chords;
    case "arp":
    case "echo":
      return g.arpI;
    case "harmony":
      return g.lead;
    case "counter":
      return g.arpI === g.lead ? g.chords : g.arpI;
    case "drone":
      return g.pad;
  }
}

let uid = 0;
const newId = (role: Role) => `${role}-${Date.now().toString(36)}-${uid++}`;

function nextChannel(layers: LayerConfig[], role: Role): number {
  if (role === "drums") return 10;
  const used = new Set(layers.map((l) => l.channel));
  for (let ch = 2; ch <= 16; ch++) if (ch !== 10 && !used.has(ch)) return ch;
  return 16;
}

function makeLayer(role: Role, layers: LayerConfig[]): LayerConfig {
  const info = ROLE_INFO[role];
  return {
    id: newId(role),
    role,
    instrument: AUTO,
    volume: role === "drums" ? 0.72 : role === "bass" ? 0.78 : 0.62,
    follow: info.follow,
    density: info.density,
    octave: role === "harmony" || role === "echo" ? 0 : 0,
    mute: false,
    solo: false,
    channel: nextChannel(layers, role),
  };
}

const starter = (): LayerConfig[] => {
  const out: LayerConfig[] = [];
  for (const r of ["drums", "bass", "chords"] as Role[]) out.push(makeLayer(r, out));
  return out;
};

export const useApp = create<AppState>()(
  persist(
    (set, get) => ({
      genreId: "lo-fi-hip-hop",
      keyRoot: 0,
      bpm: getGenre("lo-fi-hip-hop").bpm,
      tempoLocked: false,
      progIndex: 0,
      tighten: 0.6,
      autoStop: true,
      lead: { instrument: AUTO, volume: 0.8, octave: 0, channel: 1 },
      layers: starter(),
      midiOut: "",
      audioReady: false,
      midiIns: [],
      midiOuts: [],
      midiError: null,
      toast: null,

      setGenre: (id) => {
        const g = getGenre(id);
        set({ genreId: g.id, progIndex: 0, ...(get().tempoLocked ? {} : { bpm: g.bpm }) });
      },
      setKey: (root) => set({ keyRoot: ((root % 12) + 12) % 12 }),
      setBpm: (bpm) => set({ bpm: Math.round(Math.min(240, Math.max(40, bpm))) }),
      setTempoLocked: (v) => set({ tempoLocked: v }),
      setProg: (i) => set({ progIndex: i }),
      setTighten: (v) => set({ tighten: v }),
      setAutoStop: (v) => set({ autoStop: v }),
      setLead: (p) => set({ lead: { ...get().lead, ...p } }),
      addLayer: (role) => set({ layers: [...get().layers, makeLayer(role, get().layers)] }),
      updateLayer: (id, p) => set({ layers: get().layers.map((l) => (l.id === id ? { ...l, ...p } : l)) }),
      removeLayer: (id) => set({ layers: get().layers.filter((l) => l.id !== id) }),
      setMidiOut: (id) => set({ midiOut: id }),
      set: (p) => set(p),
    }),
    {
      name: "hamfist-v1",
      partialize: (s) => ({
        genreId: s.genreId,
        keyRoot: s.keyRoot,
        bpm: s.bpm,
        tempoLocked: s.tempoLocked,
        tighten: s.tighten,
        autoStop: s.autoStop,
        lead: s.lead,
        layers: s.layers,
      }),
    },
  ),
);
