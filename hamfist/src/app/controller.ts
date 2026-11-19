// Wires the engine to the outside world: keys, MIDI, sound, capture, state.
import * as Tone from "tone";
import { Engine } from "../engine/engine";
import { getGenre } from "../engine/genres";
import { keyForCode } from "../engine/keymap";
import { writeMidi, type TakeTrack } from "../engine/smf";
import { pitchName } from "../engine/theory";
import { LEAD_ID } from "../engine/types";
import { Midi } from "../audio/midi";
import { getPreset } from "../audio/presets";
import { ToneSink } from "../audio/toneSink";
import { Capture } from "./capture";
import { ROLE_INFO, resolveInstrument, useApp, type AppState } from "./store";

const clock = () => performance.now() / 1000;

export const capture = new Capture();
export const sound = new ToneSink();
export const midi = new Midi();
export const engine = new Engine([sound, midi, capture], getGenre(useApp.getState().genreId));

type KeyListener = (code: string, down: boolean, note: string) => void;
const keyListeners = new Set<KeyListener>();
export const onKey = (fn: KeyListener) => {
  keyListeners.add(fn);
  return () => void keyListeners.delete(fn);
};

function sync(s: AppState, prev?: AppState) {
  const now = clock();
  const g = getGenre(s.genreId);
  if (!prev || s.genreId !== prev.genreId) {
    engine.setGenre(g, now, true);
    engine.setKey(s.keyRoot);
  }
  if (!prev || s.keyRoot !== prev.keyRoot) engine.setKey(s.keyRoot);
  if (!prev || s.bpm !== prev.bpm) {
    engine.setTempo(s.bpm, now);
    sound.setTempo(s.bpm);
  }
  if (!prev || s.progIndex !== prev.progIndex || s.genreId !== prev.genreId) engine.setProgression(s.progIndex);
  engine.setOptions({ tighten: s.tighten, autoStop: s.autoStop });
  engine.setLead({ octave: s.lead.octave });
  engine.setLayers(s.layers, now);

  // Instruments for every voice, in both the synth and on MIDI out.
  const leadInst = resolveInstrument("lead", s.lead.instrument, g);
  sound.configure(LEAD_ID, `i:${leadInst}`, s.lead.volume);
  midi.configure(LEAD_ID, s.lead.channel, getPreset(leadInst).gm);
  const alive = new Set([LEAD_ID]);
  for (const l of s.layers) {
    alive.add(l.id);
    const inst = resolveInstrument(l.role, l.instrument, g);
    if (l.role === "drums") {
      sound.configure(l.id, `k:${inst}`, l.volume);
      midi.configure(l.id, 10, 0);
    } else {
      sound.configure(l.id, `i:${inst}`, l.volume);
      midi.configure(l.id, l.channel, getPreset(inst).gm);
    }
  }
  for (const id of sound.layers()) {
    if (!alive.has(id)) {
      sound.remove(id);
      midi.remove(id);
    }
  }
  if (!prev || s.midiOut !== prev.midiOut) midi.setOutput(s.midiOut);
}

async function wake() {
  if (sound.ready) return;
  try {
    await sound.init();
    useApp.getState().set({ audioReady: true });
  } catch {
    useApp.getState().set({ toast: "Audio could not start. Check your output device." });
  }
}

function typing(target: EventTarget | null) {
  const el = target as HTMLElement | null;
  if (!el) return false;
  if (el.tagName === "INPUT") return (el as HTMLInputElement).type !== "range";
  return el.tagName === "TEXTAREA" || el.tagName === "SELECT" || el.isContentEditable;
}

export function stopAll() {
  engine.stop();
  keyListeners.forEach((fn) => {
    for (const code of downCodes) fn(code, false, "");
  });
  downCodes.clear();
}

const downCodes = new Set<string>();

export function pressKey(code: string, raw: number) {
  void wake();
  if (downCodes.has(code)) return;
  downCodes.add(code);
  const pitch = engine.inputOn(code, raw, null, clock());
  keyListeners.forEach((fn) => fn(code, true, pitchName(pitch)));
}

export function releaseKey(code: string) {
  if (!downCodes.delete(code)) return;
  engine.inputOff(code, clock());
  keyListeners.forEach((fn) => fn(code, false, ""));
}

let started = false;

// Handles for poking at the running app from the dev console and from tests.
if (import.meta.env.DEV) (window as unknown as Record<string, unknown>).__hamfist = { engine, sound, capture, midi, Tone };

export function boot() {
  if (started) return;
  started = true;
  sync(useApp.getState());
  useApp.subscribe((s, prev) => sync(s, prev));

  window.addEventListener("keydown", (e) => {
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (e.code === "Escape") {
      if (typing(e.target)) (e.target as HTMLElement).blur();
      else stopAll();
      return;
    }
    if (typing(e.target)) return;
    const key = keyForCode(e.code);
    if (!key) return;
    e.preventDefault();
    if (e.repeat) return;
    (document.activeElement as HTMLElement | null)?.blur?.();
    pressKey(key.code, key.raw);
  });
  // Give the keys back to the instrument as soon as a control has been used.
  document.addEventListener("change", (e) => {
    const el = e.target as HTMLElement;
    if (el.tagName === "SELECT") el.blur();
  });
  document.addEventListener("keydown", (e) => {
    if (e.code === "Enter" && typing(e.target)) (e.target as HTMLElement).blur();
  });
  window.addEventListener("keyup", (e) => {
    const key = keyForCode(e.code);
    if (key) releaseKey(key.code);
  });
  window.addEventListener("blur", () => {
    for (const code of [...downCodes]) releaseKey(code);
  });
  window.addEventListener("pointerdown", () => void wake(), { once: true });

  midi.onPorts = (ins, outs) => {
    const st = useApp.getState();
    st.set({ midiIns: ins, midiOuts: outs, midiError: midi.error });
    if (st.midiOut && !outs.some((o) => o.id === st.midiOut)) st.setMidiOut("");
  };
  void midi.init({
    noteOn: (id, pitch, vel) => {
      void wake();
      engine.inputOn(id, pitch, vel, clock());
    },
    noteOff: (id) => engine.inputOff(id, clock()),
    sustain: (on) => engine.setSustain(on, clock()),
  });

  setInterval(() => {
    const now = clock();
    engine.tick(now);
    capture.trim(now);
  }, 20);
}

/** Save everything captured so far as a multi-track MIDI file. */
export async function saveTake(): Promise<void> {
  const s = useApp.getState();
  const g = getGenre(s.genreId);
  const tracks: TakeTrack[] = [];
  const leadInst = getPreset(resolveInstrument("lead", s.lead.instrument, g));
  tracks.push({ name: `You (${leadInst.name})`, channel: s.lead.channel - 1, program: leadInst.gm, events: capture.events.get(LEAD_ID) ?? [] });
  for (const l of s.layers) {
    const events = capture.events.get(l.id) ?? [];
    if (l.role === "drums") tracks.push({ name: "Drums", channel: 9, program: 0, events });
    else {
      const p = getPreset(resolveInstrument(l.role, l.instrument, g));
      tracks.push({ name: `${ROLE_INFO[l.role].name} (${p.name})`, channel: l.channel - 1, program: p.gm, events });
    }
  }
  if (!tracks.some((t) => t.events.length)) {
    s.set({ toast: "Nothing to save yet. Play something first." });
    return;
  }
  const bytes = writeMidi({ bpm: s.bpm, tracks });
  const stamp = new Date().toISOString().slice(0, 16).replace(/[:T]/g, "-");
  const name = `Hamfist ${g.name} ${stamp}.mid`;
  if (window.hamfist) {
    const path = await window.hamfist.saveMidi(name, bytes);
    if (path) s.set({ toast: `Saved ${path.split("/").pop()}` });
  } else {
    const url = URL.createObjectURL(new Blob([bytes as BlobPart], { type: "audio/midi" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = name;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 2000);
    s.set({ toast: `Saved ${name}` });
  }
}
