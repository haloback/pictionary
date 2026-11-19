import { describe, expect, it } from "vitest";
import { Engine } from "../src/engine/engine";
import { FAMILIES, GENRES, GROUPS, getGenre } from "../src/engine/genres";
import { BASS, COMP, DRUMS, METERS } from "../src/engine/patterns";
import { buildPool, chordFromToken, mod12, parseToken, scaleExists, scaleIntervals } from "../src/engine/theory";
import { KEYS } from "../src/engine/keymap";
import { writeMidi } from "../src/engine/smf";
import { LEAD_ID, type LayerConfig, type Sink } from "../src/engine/types";
import { mulberry32 } from "../src/engine/smash";
import { KITS, PRESETS } from "../src/audio/presets";

interface Ev { kind: "on" | "off" | "drum"; layer: string; pitch: number; vel: number; time: number }

function recorder() {
  const events: Ev[] = [];
  const sink: Sink = {
    noteOn: (layer, pitch, vel, time) => events.push({ kind: "on", layer, pitch, vel, time }),
    noteOff: (layer, pitch, time) => events.push({ kind: "off", layer, pitch, vel: 0, time }),
    drum: (layer, _v, vel, time) => events.push({ kind: "drum", layer, pitch: 0, vel, time }),
    panic: () => {},
  };
  return { events, sink };
}

const layer = (role: LayerConfig["role"], o: Partial<LayerConfig> = {}): LayerConfig => ({
  id: role, role, instrument: "grand", volume: 0.8, follow: 0, density: 0.7, octave: 0, mute: false, solo: false, channel: 2, ...o,
});

const ALL: LayerConfig[] = ["drums", "bass", "chords", "arp", "harmony", "echo", "drone", "counter"].map((r) => layer(r as LayerConfig["role"]));

describe("genre database", () => {
  it("has several hundred uniquely named genres", () => {
    expect(GENRES.length).toBeGreaterThan(400);
    expect(new Set(GENRES.map((g) => g.id)).size).toBe(GENRES.length);
    expect(GROUPS.length).toBeGreaterThan(15);
  });

  it("every genre and family resolves to valid musical data", () => {
    const presetIds = new Set(PRESETS.map((p) => p.id));
    const kitIds = new Set(KITS.map((k) => k.id));
    for (const g of [...GENRES, ...FAMILIES.map((f) => ({ ...f, name: f.id }))]) {
      const where = `genre "${g.name}"`;
      const meter = METERS[g.meter];
      expect(meter, `${where} meter ${g.meter}`).toBeTruthy();
      expect(scaleExists(g.scale), `${where} scale ${g.scale}`).toBe(true);
      expect(g.progs.length, where).toBeGreaterThan(0);
      for (const prog of g.progs) for (const tok of prog.split(" ")) expect(parseToken(tok), `${where} chord ${tok}`).toBeTruthy();
      expect(DRUMS[g.drums], `${where} drums ${g.drums}`).toBeTruthy();
      expect(BASS[g.bass], `${where} bass ${g.bass}`).toBeDefined();
      expect(COMP[g.comp], `${where} comp ${g.comp}`).toBeDefined();
      for (const [k, p] of Object.entries(DRUMS[g.drums])) expect(p!.length % meter.steps, `${where} drum ${g.drums}.${k} vs ${g.meter}`).toBe(0);
      if (BASS[g.bass]) expect(BASS[g.bass].length % meter.steps, `${where} bass ${g.bass} vs ${g.meter}`).toBe(0);
      if (COMP[g.comp]) expect(COMP[g.comp].length % meter.steps, `${where} comp ${g.comp} vs ${g.meter}`).toBe(0);
      for (const inst of [g.lead, g.chords, g.bassI, g.pad, g.arpI]) expect(presetIds.has(inst), `${where} instrument ${inst}`).toBe(true);
      expect(kitIds.has(g.kit), `${where} kit ${g.kit}`).toBe(true);
      expect(g.bpm).toBeGreaterThanOrEqual(40);
      expect(g.bpm).toBeLessThanOrEqual(240);
    }
  });
});

/** Mash random keys for `seconds` and return everything the engine emitted. */
function mash(genreId: string, seconds: number, seed: number, layers = ALL, key = 0) {
  const { events, sink } = recorder();
  const g = getGenre(genreId);
  const eng = new Engine([sink], g);
  eng.setKey(key);
  eng.setLayers(layers, 0);
  const rnd = mulberry32(seed);
  const down = new Set<string>();
  let peak = 0;
  for (let now = 0; now < seconds; now += 0.02) {
    if (rnd() < 0.3) {
      // fistful: 1-5 neighbouring keys at once
      const start = Math.floor(rnd() * (KEYS.length - 6));
      const n = 1 + Math.floor(rnd() * 5);
      for (let i = 0; i < n; i++) {
        const k = KEYS[start + i];
        if (!down.has(k.code)) { down.add(k.code); eng.inputOn(k.code, k.raw, null, now); }
      }
    }
    for (const code of [...down]) if (rnd() < 0.12) { down.delete(code); eng.inputOff(code, now); }
    peak = Math.max(peak, down.size);
    eng.tick(now);
  }
  for (const code of down) eng.inputOff(code, seconds);
  return { events, g, peak };
}

function allowedAt(g: ReturnType<typeof getGenre>, key: number) {
  // union of every pitch class any chord of the first progression permits
  const scale = scaleIntervals(g.scale);
  const sets = g.progs[0].split(" ").map((t) => buildPool(key, scale, chordFromToken(t, key)));
  return (pc: number) => sets.some((p) => p.weight[pc] >= 0);
}

describe("smash translation", () => {
  it("only ever emits notes that belong to the harmony, in every genre", () => {
    for (let i = 0; i < GENRES.length; i += 1) {
      const id = GENRES[i].id;
      const key = i % 12;
      const { events, g } = mash(id, 6, i + 1, ALL, key);
      const ok = allowedAt(g, key);
      const ons = events.filter((e) => e.kind === "on");
      expect(ons.length, id).toBeGreaterThan(10);
      for (const e of ons) expect(ok(mod12(e.pitch)), `${id}: ${e.layer} played pc ${mod12(e.pitch)}`).toBe(true);
    }
  });

  it("is polyphonic: simultaneous keys become distinct simultaneous notes", () => {
    const { events, sink } = recorder();
    const eng = new Engine([sink], getGenre("pop"));
    eng.setLayers([], 0);
    const fist = KEYS.slice(12, 20);
    fist.forEach((k) => eng.inputOn(k.code, k.raw, null, 0));
    const lead = events.filter((e) => e.kind === "on" && e.layer === LEAD_ID).map((e) => e.pitch);
    expect(lead.length).toBe(8);
    expect(new Set(lead).size).toBe(8);
    // no semitone clusters in the resulting voicing
    const sorted = [...lead].sort((a, b) => a - b);
    for (let i = 1; i < sorted.length; i++) expect(sorted[i] - sorted[i - 1]).toBeGreaterThan(1);
    fist.forEach((k) => eng.inputOff(k.code, 1));
    expect(events.filter((e) => e.kind === "off" && e.layer === LEAD_ID).length).toBe(8);
  });

  it("every note on is matched by a later note off (no stuck notes)", () => {
    for (const id of ["pop", "swing", "trap", "salsa", "flamenco", "progressive-rock"]) {
      const { events } = mash(id, 10, 42);
      const open = new Map<string, number>();
      for (const e of [...events].sort((a, b) => a.time - b.time || (a.kind === "off" ? -1 : 1))) {
        if (e.kind === "drum") continue;
        const k = `${e.layer}:${e.pitch}`;
        open.set(k, (open.get(k) ?? 0) + (e.kind === "on" ? 1 : -1));
      }
      const stuck = [...open].filter(([, v]) => v > 0);
      expect(stuck, id).toEqual([]);
    }
  });

  it("every layer role produces sound, and layers are polyphonic", () => {
    const { events } = mash("house", 16, 3);
    for (const l of ALL) {
      const n = events.filter((e) => e.layer === l.id && e.kind !== "off").length;
      expect(n, l.role).toBeGreaterThan(l.role === "drone" ? 1 : 5);
    }
    // chords layer: several notes share one start time
    const chordOns = events.filter((e) => e.layer === "chords" && e.kind === "on");
    const first = chordOns[0].time;
    expect(chordOns.filter((e) => Math.abs(e.time - first) < 0.05).length).toBeGreaterThanOrEqual(3);
  });

  it("follow makes a layer fall silent when the player stops", () => {
    const { events, sink } = recorder();
    const eng = new Engine([sink], getGenre("funk"));
    eng.setOptions({ autoStop: false });
    eng.setLayers([layer("drums", { follow: 1 }), layer("bass", { follow: 0 })], 0);
    for (let now = 0; now < 30; now += 0.02) {
      if (now < 6 && Math.round(now * 50) % 10 === 0) { eng.inputOn("a", 60, 0.9, now); eng.inputOff("a", now + 0.01); }
      eng.tick(now);
    }
    const drumsEarly = events.filter((e) => e.layer === "drums" && e.time < 6).length;
    const drumsLate = events.filter((e) => e.layer === "drums" && e.time > 22).length;
    const bassLate = events.filter((e) => e.layer === "bass" && e.kind === "on" && e.time > 22).length;
    expect(drumsEarly).toBeGreaterThan(20);
    expect(drumsLate).toBe(0);
    expect(bassLate).toBeGreaterThan(5);
  });

  it("the band stops by itself after a few silent bars", () => {
    const { sink } = recorder();
    const eng = new Engine([sink], getGenre("pop"));
    eng.setLayers(ALL, 0);
    eng.inputOn("a", 60, 0.8, 0);
    eng.inputOff("a", 0.2);
    for (let now = 0; now < 30; now += 0.02) eng.tick(now);
    expect(eng.isPlaying()).toBe(false);
  });
});

describe("midi export", () => {
  it("writes a well formed multi-track file", () => {
    const bytes = writeMidi({
      bpm: 120,
      tracks: [
        { name: "You", channel: 0, program: 0, events: [{ kind: "on", time: 1, pitch: 60, vel: 0.8 }, { kind: "off", time: 1.5, pitch: 60 }] },
        { name: "Drums", channel: 9, program: 0, events: [{ kind: "drum", time: 1, voice: "k", vel: 1 }] },
      ],
    });
    const head = String.fromCharCode(...bytes.slice(0, 4));
    expect(head).toBe("MThd");
    expect(bytes[9]).toBe(1); // format 1
    expect(bytes[11]).toBe(3); // tempo track + 2
    let tracks = 0;
    for (let i = 14; i < bytes.length; ) {
      expect(String.fromCharCode(...bytes.slice(i, i + 4))).toBe("MTrk");
      const len = (bytes[i + 4] << 24) | (bytes[i + 5] << 16) | (bytes[i + 6] << 8) | bytes[i + 7];
      i += 8 + len;
      tracks++;
      if (i === bytes.length) break;
    }
    expect(tracks).toBe(3);
  });
});
