import { create } from 'zustand';
import { defaultProject, exportMidi, fileSafe, generate, makeTrack, rerollTrack, smartRandomize, trackLabel } from '../engine/arrange';
import type { Arrangement, Project, Track } from '../engine/arrange';
import type { InstId, StyleId, TrackParams } from '../engine/types';
import { getPattern, instDef, patternsFor, styleDef } from '../engine/library';
import { applyPreset } from '../engine/midi';
import type { MidiProfile, ProfileId } from '../engine/midi';
import { chordsFromMidi } from '../engine/detect';
import { parseChart } from '../engine/chart';
import { isSectionPattern } from '../engine/horns';
import { newSeed } from '../engine/rng';
import { player } from '../audio/player';
import { openFile, saveMany, saveMidi, saveProject } from '../platform';

export interface SavedTake {
  id: string;
  name: string;
  inst: InstId;
  patternId: string;
  seed: number;
  sectionSeed: number;
  variant: string;
  params: TrackParams;
  style: StyleId;
}

export type Theme = 'auto' | 'light' | 'dark';
export type Tab = 'part' | 'feel' | 'midi';

interface State {
  project: Project;
  arr: Arrangement;
  past: Project[];
  future: Project[];
  selected: string | null;
  tab: Tab;
  playing: boolean;
  loop: boolean;
  takes: SavedTake[];
  useTakes: boolean;
  midiOutId: string | null;
  midiOutputs: { id: string; name: string }[];
  midiError: string | null;
  previewMuted: boolean;
  theme: Theme;
  toast: { msg: string; id: number } | null;

  update: (fn: (p: Project) => Project, coalesce?: string) => void;
  undo: () => void;
  redo: () => void;
  select: (id: string | null, tab?: Tab) => void;
  setTab: (t: Tab) => void;
  setChart: (text: string) => void;
  setStyle: (s: StyleId) => void;
  loadPreset: (pr: { text: string; style?: string; tempo?: number }) => void;
  randomizeAll: () => void;
  reroll: (id: string, mode: 'recipe' | 'take') => void;
  setTrack: (id: string, patch: Partial<Track>, coalesce?: string) => void;
  setParams: (id: string, patch: Partial<TrackParams>, coalesce?: string) => void;
  setMidi: (id: string, patch: Partial<MidiProfile>) => void;
  setPreset: (id: string, preset: ProfileId) => void;
  setPattern: (id: string, patternId: string) => void;
  setVariant: (id: string, variant: string) => void;
  addTrack: (inst: InstId) => void;
  removeTrack: (id: string) => void;
  togglePlay: (fromTick?: number) => void;
  stop: () => void;
  setLoop: (v: boolean) => void;
  saveTake: (id: string) => void;
  applyTake: (take: SavedTake, trackId: string) => void;
  deleteTake: (id: string) => void;
  setUseTakes: (v: boolean) => void;
  notify: (msg: string) => void;
  newSession: () => void;
  importFile: (name: string, data: Uint8Array) => void;
  openDialog: () => Promise<void>;
  saveSession: () => Promise<void>;
  exportAll: () => Promise<void>;
  exportStems: () => Promise<void>;
  exportTrack: (id: string) => Promise<void>;
  midiBytes: (ids?: string[]) => Uint8Array;
  midiName: (id?: string) => string;
  stemFiles: () => { name: string; data: Uint8Array }[];
  initMidi: () => Promise<void>;
  setMidiOut: (id: string | null) => void;
  setPreviewMuted: (v: boolean) => void;
  setTheme: (t: Theme) => void;
}

const LS = { project: 'sideman.project.v1', takes: 'sideman.takes.v1', settings: 'sideman.settings.v1' };
function load<T>(key: string): T | null {
  try {
    const s = localStorage.getItem(key);
    return s ? (JSON.parse(s) as T) : null;
  } catch {
    return null;
  }
}
function store(key: string, v: unknown): void {
  try {
    localStorage.setItem(key, JSON.stringify(v));
  } catch {
    /* storage unavailable */
  }
}

/** Accept a saved project only if it has the shape we expect. */
function validProject(p: unknown): p is Project {
  const q = p as Project;
  return !!q && typeof q.chart === 'string' && Array.isArray(q.tracks) && q.tracks.every((t) => !!t && typeof t.id === 'string' && !!instDef(t.inst) && !!t.midi && !!t.params);
}
function repair(p: Project): Project {
  return {
    ...p,
    tracks: p.tracks.map((t) => {
      const pats = patternsFor(t.inst);
      const def = instDef(t.inst);
      return {
        ...t,
        patternId: pats.some((x) => x.id === t.patternId) ? t.patternId : pats[0].id,
        variant: def.variants.some((v) => v.id === t.variant) ? t.variant : def.variants[0].id,
      };
    }),
  };
}

const saved = load<Project>(LS.project);
const initial = validProject(saved) ? repair(saved) : defaultProject();
const settings = load<{ theme: Theme; loop: boolean; useTakes: boolean; previewMuted: boolean }>(LS.settings);
let lastCoalesce = '';
let lastCoalesceAt = 0;
let toastId = 0;
let midiAccess: MIDIAccess | null = null;

export const useApp = create<State>((set, get) => {
  const commit = (project: Project, pushHistory: boolean) => {
    const arr = generate(project);
    const s = get();
    set({
      project,
      arr,
      past: pushHistory ? [...s.past.slice(-60), s.project] : s.past,
      future: pushHistory ? [] : s.future,
    });
    store(LS.project, project);
    if (player.playing) player.load(project, arr);
  };
  const saveSettings = () => {
    const s = get();
    store(LS.settings, { theme: s.theme, loop: s.loop, useTakes: s.useTakes, previewMuted: s.previewMuted });
  };

  return {
    project: initial,
    arr: generate(initial),
    past: [],
    future: [],
    selected: initial.tracks[0]?.id ?? null,
    tab: 'part',
    playing: false,
    loop: settings?.loop ?? true,
    takes: load<SavedTake[]>(LS.takes) ?? [],
    useTakes: settings?.useTakes ?? false,
    midiOutId: null,
    midiOutputs: [],
    midiError: null,
    previewMuted: settings?.previewMuted ?? false,
    theme: settings?.theme ?? 'auto',
    toast: null,

    update: (fn, coalesce) => {
      const now = Date.now();
      const merge = !!coalesce && coalesce === lastCoalesce && now - lastCoalesceAt < 900;
      lastCoalesce = coalesce ?? '';
      lastCoalesceAt = now;
      commit(fn(get().project), !merge);
    },
    undo: () => {
      const s = get();
      const prev = s.past[s.past.length - 1];
      if (!prev) return;
      set({ past: s.past.slice(0, -1), future: [s.project, ...s.future] });
      lastCoalesce = '';
      commit(prev, false);
      if (!prev.tracks.some((t) => t.id === get().selected)) set({ selected: prev.tracks[0]?.id ?? null });
    },
    redo: () => {
      const s = get();
      const next = s.future[0];
      if (!next) return;
      set({ past: [...s.past, s.project], future: s.future.slice(1) });
      lastCoalesce = '';
      commit(next, false);
    },
    select: (id, tab) => set(tab ? { selected: id, tab } : { selected: id }),
    setTab: (tab) => set({ tab }),
    setChart: (text) => get().update((p) => ({ ...p, chart: text }), 'chart'),
    setStyle: (style) =>
      get().update((p) => {
        // moving to a new style re-deals the unlocked players so the band fits it
        const next = { ...p, style, tempo: styleDef(style).tempo, swing: null };
        return smartRandomize(next);
      }),
    loadPreset: (pr) =>
      get().update((p) => {
        let next: Project = { ...p, chart: pr.text };
        if (pr.style && pr.style !== p.style) next = smartRandomize({ ...next, style: pr.style as StyleId, swing: null });
        if (pr.tempo) next = { ...next, tempo: pr.tempo };
        return next;
      }),
    randomizeAll: () => {
      const { takes, useTakes } = get();
      get().update((p) => {
        let q = smartRandomize(p);
        if (useTakes && takes.length) {
          // deal some of the user's saved takes back into the band
          q = {
            ...q,
            tracks: q.tracks.map((t) => {
              if (t.locked || isSectionPattern(t.patternId)) return t;
              const mine = takes.filter((k) => k.inst === t.inst && getPattern(k.patternId));
              if (!mine.length || Math.random() > 0.45) return t;
              const k = mine[Math.floor(Math.random() * mine.length)];
              return { ...t, patternId: k.patternId, seed: k.seed, variant: k.variant, params: { ...k.params } };
            }),
          };
        }
        return q;
      });
    },
    reroll: (id, mode) => get().update((p) => rerollTrack(p, id, mode)),
    setTrack: (id, patch, coalesce) =>
      get().update((p) => ({ ...p, tracks: p.tracks.map((t) => (t.id === id ? { ...t, ...patch } : t)) }), coalesce),
    setParams: (id, patch, coalesce) =>
      get().update((p) => ({ ...p, tracks: p.tracks.map((t) => (t.id === id ? { ...t, params: { ...t.params, ...patch } } : t)) }), coalesce),
    setMidi: (id, patch) =>
      get().update(
        (p) => ({ ...p, tracks: p.tracks.map((t) => (t.id === id ? { ...t, midi: { ...t.midi, ...patch, preset: 'preset' in patch ? patch.preset! : 'custom' } } : t)) }),
        'midi' + id + Object.keys(patch).join(),
      ),
    setPreset: (id, preset) => get().update((p) => ({ ...p, tracks: p.tracks.map((t) => (t.id === id ? { ...t, midi: applyPreset(t.midi, preset) } : t)) })),
    setPattern: (id, patternId) => {
      const pat = getPattern(patternId);
      if (!pat) return;
      get().update((p) => ({
        ...p,
        tracks: p.tracks.map((t) => {
          if (t.id !== id) return t;
          const def = instDef(t.inst);
          const variant = pat.variant && def.variants.some((v) => v.id === pat.variant) ? pat.variant : t.variant;
          return { ...t, patternId, variant, midi: { ...t.midi, program: def.variants.find((v) => v.id === variant)!.program } };
        }),
      }));
    },
    setVariant: (id, variant) =>
      get().update((p) => ({
        ...p,
        tracks: p.tracks.map((t) => {
          if (t.id !== id) return t;
          const v = instDef(t.inst).variants.find((x) => x.id === variant);
          return v ? { ...t, variant, midi: { ...t.midi, program: v.program } } : t;
        }),
      })),
    addTrack: (inst) => {
      let id = '';
      get().update((p) => {
        const t = makeTrack(inst, p.style, p.tracks);
        // a new horn joins the section that is already playing
        const mate = p.tracks.find((x) => instDef(x.inst).family === 'horn' && isSectionPattern(x.patternId));
        if (mate && instDef(inst).family === 'horn') t.patternId = mate.patternId;
        id = t.id;
        return { ...p, tracks: [...p.tracks, t] };
      });
      set({ selected: id });
    },
    removeTrack: (id) => {
      get().update((p) => ({ ...p, tracks: p.tracks.filter((t) => t.id !== id) }));
      if (get().selected === id) set({ selected: get().project.tracks[0]?.id ?? null });
    },

    togglePlay: (fromTick) => {
      const s = get();
      if (s.playing && fromTick == null) return s.stop();
      player.loop = s.loop;
      player.previewMuted = s.previewMuted;
      player.onEnd = () => set({ playing: false });
      void player.play(s.project, s.arr, fromTick ?? 0).then(() => set({ playing: player.playing }));
    },
    stop: () => {
      player.stop();
      set({ playing: false });
    },
    setLoop: (v) => {
      player.loop = v;
      set({ loop: v });
      saveSettings();
    },

    saveTake: (id) => {
      const s = get();
      const t = s.project.tracks.find((x) => x.id === id);
      if (!t) return;
      const pat = getPattern(t.patternId);
      const n = s.takes.filter((k) => k.inst === t.inst && k.patternId === t.patternId).length + 1;
      const take: SavedTake = {
        id: 'k' + newSeed().toString(36),
        name: `${pat?.name.replace(/^(Section|Solo): /, '') ?? 'Take'} ${n}`,
        inst: t.inst,
        patternId: t.patternId,
        seed: t.seed,
        sectionSeed: s.project.sectionSeed,
        variant: t.variant,
        params: { ...t.params },
        style: s.project.style,
      };
      const takes = [take, ...s.takes];
      set({ takes });
      store(LS.takes, takes);
      s.notify(`Saved "${take.name}" to your takes`);
    },
    applyTake: (take, trackId) =>
      get().update((p) => ({
        ...p,
        sectionSeed: isSectionPattern(take.patternId) ? take.sectionSeed : p.sectionSeed,
        tracks: p.tracks.map((t) => {
          if (t.id !== trackId || !getPattern(take.patternId)) return t;
          const def = instDef(t.inst);
          const variant = def.variants.some((v) => v.id === take.variant) ? take.variant : t.variant;
          return { ...t, patternId: take.patternId, seed: take.seed, variant, params: { ...take.params }, midi: { ...t.midi, program: def.variants.find((v) => v.id === variant)!.program } };
        }),
      })),
    deleteTake: (id) => {
      const takes = get().takes.filter((k) => k.id !== id);
      set({ takes });
      store(LS.takes, takes);
    },
    setUseTakes: (v) => {
      set({ useTakes: v });
      saveSettings();
    },

    notify: (msg) => {
      const id = ++toastId;
      set({ toast: { msg, id } });
      setTimeout(() => {
        if (get().toast?.id === id) set({ toast: null });
      }, 3200);
    },
    newSession: () => {
      get().stop();
      const p = defaultProject();
      get().update(() => smartRandomize(p));
      set({ selected: get().project.tracks[0]?.id ?? null });
    },

    importFile: (name, data) => {
      const s = get();
      const lower = name.toLowerCase();
      try {
        if (lower.endsWith('.mid') || lower.endsWith('.midi')) {
          const res = chordsFromMidi(data);
          s.update((p) => ({ ...p, chart: res.chart, tempo: Math.min(240, Math.max(40, res.tempo)), repeats: 1 }));
          s.notify(`Read ${res.bars} bars of chords from ${name}`);
          return;
        }
        const text = new TextDecoder().decode(data);
        if (lower.endsWith('.sideman') || lower.endsWith('.json')) {
          const obj = JSON.parse(text) as { project?: unknown; takes?: SavedTake[] };
          const proj = obj.project ?? obj;
          if (!validProject(proj)) throw new Error('That file is not a Sideman session');
          s.stop();
          s.update(() => repair(proj));
          set({ selected: get().project.tracks[0]?.id ?? null });
          s.notify(`Opened ${name}`);
          return;
        }
        const chart = parseChart(text);
        if (!chart.bars.length) throw new Error('No chords found in that file');
        s.update((p) => ({ ...p, chart: text.trim().replace(/\n+/g, ' | ') }));
        s.notify(`Loaded ${chart.bars.length} bars from ${name}`);
      } catch (e) {
        s.notify(e instanceof Error ? e.message : 'Could not read that file');
      }
    },
    openDialog: async () => {
      const f = await openFile();
      if (f) get().importFile(f.name, f.data);
    },
    saveSession: async () => {
      const s = get();
      const where = await saveProject(fileSafe(s.project.name) + '.sideman', JSON.stringify({ app: 'sideman', version: 1, project: s.project }, null, 2));
      if (where) s.notify('Session saved');
    },

    midiBytes: (ids) => {
      const s = get();
      return exportMidi(s.project, s.arr, ids);
    },
    midiName: (id) => {
      const s = get();
      const base = fileSafe(s.project.name);
      if (!id) return `${base}.mid`;
      const t = s.project.tracks.find((x) => x.id === id);
      const same = s.project.tracks.filter((x) => t && x.inst === t.inst);
      const suffix = t && same.length > 1 ? `-${same.indexOf(t) + 1}` : '';
      return `${base}-${t ? fileSafe(trackLabel(t)) : 'part'}${suffix}.mid`;
    },
    stemFiles: () => {
      const s = get();
      const anySolo = s.project.tracks.some((t) => t.solo);
      return s.project.tracks.filter((t) => !t.mute && (!anySolo || t.solo)).map((t) => ({ name: s.midiName(t.id), data: s.midiBytes([t.id]) }));
    },
    exportAll: async () => {
      const s = get();
      if (!s.arr.len) return s.notify('Nothing to export yet');
      const where = await saveMidi(s.midiName(), s.midiBytes());
      if (where) s.notify('MIDI file saved');
    },
    exportStems: async () => {
      const s = get();
      if (!s.arr.len) return s.notify('Nothing to export yet');
      const files = s.stemFiles();
      const where = await saveMany(files);
      if (where) s.notify(`${files.length} part files saved`);
    },
    exportTrack: async (id) => {
      const s = get();
      const where = await saveMidi(s.midiName(id), s.midiBytes([id]));
      if (where) s.notify('Part saved');
    },

    initMidi: async () => {
      if (midiAccess || !navigator.requestMIDIAccess) {
        if (!navigator.requestMIDIAccess) set({ midiError: 'Live MIDI output is not available here' });
        return;
      }
      try {
        midiAccess = await navigator.requestMIDIAccess({ sysex: false });
        const refresh = () => {
          const outs = [...midiAccess!.outputs.values()].map((o) => ({ id: o.id, name: o.name ?? 'MIDI output' }));
          set({ midiOutputs: outs, midiError: null });
          const cur = get().midiOutId;
          if (cur && !outs.some((o) => o.id === cur)) get().setMidiOut(null);
        };
        midiAccess.onstatechange = refresh;
        refresh();
      } catch {
        set({ midiError: 'MIDI access was refused' });
      }
    },
    setMidiOut: (id) => {
      const out = id && midiAccess ? midiAccess.outputs.get(id) ?? null : null;
      player.setMidiOut(out);
      set({ midiOutId: out ? id : null });
    },
    setPreviewMuted: (v) => {
      player.previewMuted = v;
      player.applyMix(get().project);
      set({ previewMuted: v });
      saveSettings();
    },
    setTheme: (theme) => {
      set({ theme });
      saveSettings();
    },
  };
});

// keep the live mix in step with mute/solo/volume changes
useApp.subscribe((s, prev) => {
  if (s.project !== prev.project) player.applyMix(s.project);
});
