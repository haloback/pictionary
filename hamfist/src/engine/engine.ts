// Performance engine: a lookahead sequencer that keeps a genre-shaped band
// running underneath whatever the player is hammering out.
//
// Everything is expressed as note events pushed to a Sink, so the same
// stream drives the built-in synths, MIDI out, the recorder and the visuals.
import type { Genre } from "./genres";
import { BASS, COMP, DRUMS, DRUM_RANK, METERS, type DrumVoice, type Meter } from "./patterns";
import { mulberry32, nearestAllowed, snap } from "./smash";
import { buildPool, chordFromToken, mod12, nearestWithPc, scaleIntervals, voiceChord, type Chord, type Pool } from "./theory";
import { LEAD_ID, type EngineView, type LayerConfig, type Sink } from "./types";

const LOOKAHEAD = 0.12;
const LEAD_LO = 36;
const LEAD_HI = 98;
const SILENT = 0.04;

export interface LeadConfig {
  octave: number;
}

export interface EngineOptions {
  /** 0-1: how hard note starts are pulled onto the grid. */
  tighten: number;
  /** Stop the band after a few bars of silence. */
  autoStop: boolean;
}

interface HeldNote {
  raw: number;
  pitch: number;
  on: number;
  vel: number;
  /** Harmony notes this key spawned, per layer id. */
  harm: Map<string, number[]>;
  released: boolean;
}

interface EchoEvent {
  time: number;
  pitch: number;
  vel: number;
  dur: number;
  layer: string;
}

interface LayerState {
  voicing?: number[];
  arpIdx: number;
  droneUntil: number;
  counterPitch: number;
  counterBusyUntil: number;
}

export class Engine {
  private sinks: Sink[];
  private genre!: Genre;
  private meter: Meter = METERS["4/4"];
  private keyRoot = 0;
  private bpm = 110;
  private scale: number[] = [];
  private progIndex = 0;
  private chords: Chord[] = [];
  private pools: Pool[] = [];
  private layers: LayerConfig[] = [];
  private layerState = new Map<string, LayerState>();
  private lead: LeadConfig = { octave: 0 };
  private opts: EngineOptions = { tighten: 0.6, autoStop: true };

  private playing = false;
  private t0 = 0;
  private nextStep = 0;
  private energy = 0;
  private lastTick = 0;
  private lastInput = 0;
  private recentOns: number[] = [];
  private held = new Map<string, HeldNote>();
  private sustain = false;
  private echoes: EchoEvent[] = [];
  private lastLeadPitch = 64;
  private leadDir = 0;
  private rng = mulberry32(7);

  constructor(sinks: Sink[], genre: Genre) {
    this.sinks = sinks;
    this.setGenre(genre, 0);
  }

  // ---------------------------------------------------------------- config

  setGenre(genre: Genre, now: number, keepTempo = false) {
    this.genre = genre;
    this.meter = METERS[genre.meter] ?? METERS["4/4"];
    this.scale = scaleIntervals(genre.scale);
    if (!keepTempo) this.bpm = genre.bpm;
    this.progIndex = 0;
    this.rebuildHarmony();
    this.layerState.clear();
    this.echoes = [];
    if (this.playing) {
      // Restart the bar so the new groove lands on a downbeat.
      this.t0 = now + 0.03;
      this.nextStep = 0;
    }
  }

  setKey(root: number) {
    this.keyRoot = mod12(root);
    this.rebuildHarmony();
  }

  setProgression(index: number) {
    this.progIndex = ((index % this.genre.progs.length) + this.genre.progs.length) % this.genre.progs.length;
    this.rebuildHarmony();
  }

  setTempo(bpm: number, now: number) {
    const next = Math.min(260, Math.max(40, bpm));
    if (this.playing) {
      const pos = (now - this.t0) / this.stepDur();
      this.bpm = next;
      this.t0 = now - pos * this.stepDur();
    } else {
      this.bpm = next;
    }
  }

  setLayers(layers: LayerConfig[], now: number) {
    const alive = new Set(layers.filter((l) => !l.mute).map((l) => l.id));
    for (const h of this.held.values()) {
      for (const [id, notes] of h.harm) {
        if (!alive.has(id)) {
          for (const p of notes) this.off(id, p, now);
          h.harm.delete(id);
        }
      }
    }
    this.echoes = this.echoes.filter((e) => alive.has(e.layer));
    this.layers = layers;
  }

  setLead(lead: LeadConfig) {
    this.lead = lead;
  }

  setOptions(o: Partial<EngineOptions>) {
    this.opts = { ...this.opts, ...o };
  }

  private rebuildHarmony() {
    const tokens = this.genre.progs[this.progIndex].split(" ");
    this.chords = tokens.map((t) => chordFromToken(t, this.keyRoot));
    this.pools = this.chords.map((c) => buildPool(this.keyRoot, this.scale, c));
  }

  // ------------------------------------------------------------- transport

  private stepDur() {
    return (60 / this.bpm) * this.meter.stepBeats;
  }

  private stepTime(n: number) {
    const sd = this.stepDur();
    const swung = this.meter.stepBeats === 0.25 && n % 2 === 1 ? this.genre.swing * sd : 0;
    return this.t0 + n * sd + swung;
  }

  private chordSpan() {
    return this.meter.steps * this.genre.hr;
  }

  private chordIndexAt(step: number) {
    return Math.floor(Math.max(0, step) / this.chordSpan()) % this.chords.length;
  }

  start(now: number) {
    if (this.playing) return;
    this.playing = true;
    this.t0 = now;
    this.nextStep = 0;
    this.layerState.clear();
    this.lastInput = now;
    this.rng = mulberry32(7);
  }

  stop() {
    this.playing = false;
    this.echoes = [];
    this.held.clear();
    this.sustain = false;
    this.energy = 0;
    for (const s of this.sinks) s.panic();
  }

  isPlaying() {
    return this.playing;
  }

  /** Call every 20-30 ms. */
  tick(now: number) {
    const dt = this.lastTick ? Math.min(0.5, now - this.lastTick) : 0;
    this.lastTick = now;
    this.energy *= Math.exp(-dt / 2.4);
    if (this.held.size > 0) {
      this.energy = Math.max(this.energy, 0.28);
      this.lastInput = now;
    }

    if (!this.playing) return;

    if (this.opts.autoStop) {
      const idleBars = (now - this.lastInput) / (this.stepDur() * this.meter.steps);
      if (idleBars > 4) {
        this.playing = false;
        this.echoes = [];
        return;
      }
    }

    while (this.stepTime(this.nextStep) < now + LOOKAHEAD) {
      this.scheduleStep(this.nextStep);
      this.nextStep++;
    }

    if (this.echoes.length) {
      const due = this.echoes.filter((e) => e.time < now + LOOKAHEAD);
      if (due.length) {
        this.echoes = this.echoes.filter((e) => e.time >= now + LOOKAHEAD);
        for (const e of due) {
          const step = Math.round((e.time - this.t0) / this.stepDur());
          const pool = this.pools[this.chordIndexAt(step)];
          const p = nearestAllowed(e.pitch, pool, []);
          this.note(e.layer, p, e.vel, Math.max(now, e.time), e.dur);
        }
      }
    }
  }

  getView(now: number): EngineView {
    const pos = this.playing ? Math.max(0, Math.floor((now - this.t0) / this.stepDur())) : 0;
    return {
      playing: this.playing,
      bar: Math.floor(pos / this.meter.steps),
      step: pos % this.meter.steps,
      steps: this.meter.steps,
      pulse: this.meter.pulse,
      chordIndex: this.chordIndexAt(pos),
      chords: this.chords.map((c) => c.symbol),
      energy: this.energy,
      held: this.held.size,
    };
  }

  /** Bar grid for visualisers: time of bar zero and bar length in seconds. */
  getGrid() {
    return { playing: this.playing, t0: this.t0, bar: this.stepDur() * this.meter.steps, span: this.genre.hr };
  }

  getTempo() {
    return this.bpm;
  }

  // ----------------------------------------------------------------- input

  /**
   * A key went down. `raw` is the pitch the key nominally stands for;
   * `vel` is 0-1, or null when the device has no velocity.
   */
  inputOn(id: string, raw: number, vel: number | null, now: number) {
    if (this.held.has(id)) this.release(id, now, true);
    if (!this.playing) this.start(now);
    this.lastInput = now;

    const sd = this.stepDur();
    let t = now;
    const pos = (now - this.t0) / sd;
    if (this.opts.tighten > 0 && pos > 0.05) {
      const next = Math.ceil(pos);
      const tPrev = this.stepTime(next - 1);
      const tNext = this.stepTime(next);
      const frac = (now - tPrev) / Math.max(1e-4, tNext - tPrev);
      // Just behind the grid reads as "late but on it"; anything else is
      // nudged forward onto the next subdivision.
      if (frac > 0.3 && tNext > now) t = now + Math.min(0.12, tNext - now) * this.opts.tighten;
    }
    const step = Math.max(0, Math.round((t - this.t0) / sd));
    const pool = this.pools[this.chordIndexAt(step)];

    this.recentOns = this.recentOns.filter((x) => now - x < 0.07);
    this.recentOns.push(now);
    const smash = this.recentOns.length + this.held.size >= 3;
    const strong = step % this.meter.pulse === 0;

    let v = vel;
    if (v === null) {
      v = 0.58 + this.energy * 0.24 + (strong ? 0.07 : 0) + (this.rng() - 0.5) * 0.1;
      if (smash) v -= 0.06;
    }
    v = Math.min(1, Math.max(0.08, v));

    const heldList = [...this.held.values()];
    const pitch = snap(raw + this.lead.octave * 12, {
      pool,
      sounding: heldList.map((h) => h.pitch),
      held: heldList.map((h) => ({ raw: h.raw + this.lead.octave * 12, pitch: h.pitch })),
      strong,
      smash,
      lo: LEAD_LO,
      hi: LEAD_HI,
    });

    const note: HeldNote = { raw, pitch, on: t, vel: v, harm: new Map(), released: false };
    this.held.set(id, note);
    for (const s of this.sinks) s.raw?.(raw, now);
    this.on(LEAD_ID, pitch, v, t);
    this.spawnFollowers(note, pool, t);

    this.energy = Math.min(1, this.energy + 0.13 * (0.5 + v * 0.5));
    this.leadDir = Math.sign(pitch - this.lastLeadPitch);
    this.lastLeadPitch = pitch;
    return pitch;
  }

  inputOff(id: string, now: number) {
    const h = this.held.get(id);
    if (!h) return;
    if (this.sustain) {
      h.released = true;
      return;
    }
    this.release(id, now, false);
  }

  setSustain(on: boolean, now: number) {
    this.sustain = on;
    if (!on) {
      for (const [id, h] of [...this.held]) if (h.released) this.release(id, now, false);
    }
  }

  private release(id: string, now: number, immediate: boolean) {
    const h = this.held.get(id);
    if (!h) return;
    const t = immediate ? Math.max(now, h.on) : Math.max(now, h.on + 0.09);
    this.off(LEAD_ID, h.pitch, t);
    for (const [layer, notes] of h.harm) for (const p of notes) this.off(layer, p, t);
    this.held.delete(id);
  }

  /** Harmony and echo layers react to each lead note directly. */
  private spawnFollowers(note: HeldNote, pool: Pool, t: number) {
    const anySolo = this.layers.some((l) => l.solo);
    for (const l of this.layers) {
      if (l.mute || (anySolo && !l.solo)) continue;
      if (l.role === "harmony") {
        const p = note.pitch;
        const taken = [...this.held.values()].map((h) => h.pitch);
        const targets = [p + 4];
        if (l.density > 0.34) targets.push(p - 8);
        if (l.density > 0.67) targets.push(p + 9);
        const out: number[] = [];
        for (const target of targets) {
          const n = nearestAllowed(target, pool, [...taken, ...out]) + l.octave * 12;
          if (n !== p && n >= 0 && n <= 127 && !out.includes(n)) out.push(n);
        }
        note.harm.set(l.id, out);
        out.forEach((n, i) => this.on(l.id, n, note.vel * 0.72, t + 0.004 * (i + 1)));
      } else if (l.role === "echo") {
        const sd = this.stepDur();
        const delay = sd * (this.meter.stepBeats === 0.25 ? 3 : 2);
        const repeats = 1 + Math.round(l.density * 3);
        for (let k = 1; k <= repeats; k++) {
          this.echoes.push({
            time: t + k * delay,
            pitch: note.pitch + l.octave * 12,
            vel: note.vel * Math.pow(0.62, k),
            dur: delay * 0.7,
            layer: l.id,
          });
        }
      }
    }
  }

  // ------------------------------------------------------------ generation

  private intensity(l: LayerConfig) {
    const e = Math.min(1, this.energy * 1.3);
    return 1 - l.follow + l.follow * e;
  }

  private state(id: string): LayerState {
    let s = this.layerState.get(id);
    if (!s) {
      s = { arpIdx: 0, droneUntil: 0, counterPitch: 72, counterBusyUntil: 0 };
      this.layerState.set(id, s);
    }
    return s;
  }

  private scheduleStep(n: number) {
    const t = this.stepTime(n);
    const sd = this.stepDur();
    const { steps, pulse } = this.meter;
    const s = n % steps;
    const bar = Math.floor(n / steps);
    const span = this.chordSpan();
    const ci = this.chordIndexAt(n);
    const chord = this.chords[ci];
    const pool = this.pools[ci];
    const next = this.chords[(ci + 1) % this.chords.length];
    const chordStart = n % span === 0;
    const toChange = span - (n % span);

    if (chordStart && n > 0) this.retuneHeld(pool, t);

    const anySolo = this.layers.some((l) => l.solo);
    for (const l of this.layers) {
      const st = this.state(l.id);
      if (chordStart) st.arpIdx = 0;
      if (l.mute || (anySolo && !l.solo)) continue;
      const I = this.intensity(l);
      if (I < SILENT) continue;
      const gain = 0.55 + 0.45 * I;

      switch (l.role) {
        case "drums": {
          const pat = DRUMS[this.genre.drums] ?? {};
          let any = false;
          for (const key in pat) {
            const voice = key as DrumVoice;
            const p = pat[voice]!;
            any = true;
            const ch = p[n % p.length];
            if (ch === "." || ch === undefined) continue;
            const rank = DRUM_RANK[voice];
            if (rank > l.density * 1.1 + 0.1 || rank > I * 1.6 + 0.05) continue;
            const base = ch === "X" ? 1 : ch === "o" ? 0.34 : 0.8;
            this.drum(l.id, voice, base * gain + (this.rng() - 0.5) * 0.08, t);
          }
          // A short fill into every fourth bar when things are busy.
          if (any && l.density > 0.5 && I > 0.55 && bar % 4 === 3 && s >= steps - pulse && s % 1 === 0) {
            const k = s - (steps - pulse);
            this.drum(l.id, k < pulse / 2 ? "s" : "t", 0.45 + (k / pulse) * 0.4, t);
          }
          break;
        }
        case "bass": {
          const p = BASS[this.genre.bass] ?? "";
          const rootPitch = 28 + mod12(chord.root - 4) + l.octave * 12;
          if (l.density < 0.3 || !p) {
            if (s === 0 || (s === Math.floor(steps / 2) && l.density >= 0.15)) {
              this.note(l.id, rootPitch, 0.78 * gain, t, Math.min(toChange, steps / 2) * sd * 0.92);
            }
            break;
          }
          const ch = p[n % p.length];
          if (ch === "." || ch === "-" || ch === undefined) break;
          let holds = 0;
          while (holds + 1 < toChange && p[(n + holds + 1) % p.length] === "-") holds++;
          let pitch = rootPitch;
          if (ch === "n") pitch = 28 + mod12(next.root - 4) + l.octave * 12;
          else if (ch === "a") {
            // Step into the next root from the nearest harmony note below it.
            const target = 28 + mod12(next.root - 4) + l.octave * 12;
            pitch = target - 1;
            while (pitch > target - 5 && pool.weight[mod12(pitch)] < 0) pitch--;
            if (pool.weight[mod12(pitch)] < 0) pitch = rootPitch;
          } else if (ch !== "1" && ch !== "8") pitch = nearestAllowed(rootPitch + this.bassInterval(ch, chord), pool, []);
          else pitch = rootPitch + this.bassInterval(ch, chord);
          const accent = s % pulse === 0 ? 0.82 : 0.68;
          this.note(l.id, pitch, accent * gain, t, (1 + holds) * sd * 0.92);
          break;
        }
        case "chords": {
          const p = COMP[this.genre.comp] ?? "";
          if (!p) break;
          const ch = p[n % p.length];
          if (ch === "." || ch === "-" || ch === undefined) break;
          if (I < 0.3 && s !== 0) break;
          let holds = 0;
          while (holds + 1 < toChange && p[(n + holds + 1) % p.length] === "-") holds++;
          let dur: number;
          if (holds > 0) dur = (1 + holds) * sd * 0.97;
          else {
            let gap = 1;
            while (gap < 4 && gap < toChange && p[(n + gap) % p.length] === ".") gap++;
            dur = Math.min(gap, 2) * sd * 0.82;
          }
          const voices = 3 + Math.round(l.density * 2);
          st.voicing = voiceChord(chord, 59 + l.octave * 12, voices, st.voicing);
          const base = ch === "X" ? 0.82 : ch === "o" ? 0.4 : 0.66;
          st.voicing.forEach((pitch, i) => this.note(l.id, pitch, base * gain, t + i * 0.005, dur));
          break;
        }
        case "arp": {
          let rate = this.genre.arp[1];
          if (l.density > 0.7 && rate > 1) rate = Math.max(1, rate / 2);
          if (n % rate !== 0) break;
          const notes = this.arpNotes(chord, 55 + l.octave * 12, l.density < 0.35 ? 1 : 2);
          const idx = this.arpIndex(this.genre.arp[0], st.arpIdx++, notes.length);
          const accent = s % pulse === 0 ? 0.7 : 0.56;
          this.note(l.id, notes[idx], accent * gain, t, Math.min(rate * sd * 0.9, 0.6));
          break;
        }
        case "drone": {
          if (n < st.droneUntil) break;
          const root = nearestWithPc(48 + l.octave * 12, [chord.root]);
          const fifth = chord.intervals.find((i) => i % 12 === 7 || i % 12 === 6 || i % 12 === 8) ?? 7;
          const notes = [root, root + (fifth % 12)];
          if (l.density > 0.5) notes.push(root + 12);
          if (l.density > 0.8) notes.push(root + 12 + (chord.intervals[1] % 12));
          const dur = toChange * sd * 0.985;
          for (const pitch of notes) this.note(l.id, pitch, 0.55 * gain, t, dur);
          st.droneUntil = n + toChange;
          break;
        }
        case "counter": {
          if (t < st.counterBusyUntil) break;
          const unit = this.meter.stepBeats === 0.25 ? 2 : 1;
          if (n % unit !== 0) break;
          let prob = (0.2 + 0.55 * l.density) * (0.4 + 0.6 * I);
          // Answer the player rather than talk over them.
          if (this.held.size > 0) prob *= 0.45;
          if (s % pulse === 0) prob *= 1.4;
          if (this.rng() > prob) break;
          const center = 67 + l.octave * 12 - this.leadDir * 3;
          const pullDown = st.counterPitch > center + 7 ? -2 : st.counterPitch < center - 7 ? 2 : 0;
          const move = [-3, -2, -1, 1, 2, 3][Math.floor(this.rng() * 6)] + pullDown - this.leadDir;
          const taken = [...this.held.values()].map((h) => h.pitch);
          const pitch = nearestAllowed(st.counterPitch + move * 1.7, pool, taken, s % pulse === 0);
          st.counterPitch = pitch;
          const len = (1 + Math.floor(this.rng() * 3)) * unit;
          const dur = Math.min(len, toChange) * sd;
          st.counterBusyUntil = t + dur * 0.95;
          this.note(l.id, pitch, (0.5 + this.rng() * 0.15) * gain, t, dur * 0.9);
          break;
        }
        default:
          break;
      }
    }
  }

  private bassInterval(ch: string, chord: Chord): number {
    const find = (targets: number[], fallback: number) => {
      const hit = chord.intervals.find((i) => targets.includes(i % 12));
      return hit !== undefined ? hit % 12 : fallback;
    };
    switch (ch) {
      case "3":
        return find([3, 4], chord.intervals.includes(5) ? 5 : 4);
      case "5":
        return find([7, 6, 8], 7);
      case "6":
        return find([9], chord.intervals.some((i) => i % 12 === 3) ? 8 : 9);
      case "7":
        return find([10, 11], 10);
      case "8":
        return 12;
      default:
        return 0;
    }
  }

  private arpNotes(chord: Chord, center: number, octaves: number): number[] {
    const root = nearestWithPc(center - 5, [chord.root]);
    const ivs = [...new Set(chord.intervals.map((i) => i % 12))].sort((a, b) => a - b);
    const out: number[] = [];
    for (let o = 0; o < octaves; o++) for (const i of ivs) out.push(root + i + 12 * o);
    out.push(root + 12 * octaves);
    return out;
  }

  private arpIndex(shape: string, i: number, len: number): number {
    switch (shape) {
      case "down":
        return len - 1 - (i % len);
      case "updown": {
        const period = Math.max(1, len * 2 - 2);
        const k = i % period;
        return k < len ? k : period - k;
      }
      case "converge": {
        const k = i % len;
        return k % 2 === 0 ? k / 2 : len - 1 - (k - 1) / 2;
      }
      case "random":
        return Math.floor(this.rng() * len);
      case "broken":
        return (Math.floor(i / 2) + (i % 2 ? 2 : 0)) % len;
      case "alberti":
        return [0, 2, 1, 2][i % 4] % len;
      default:
        return i % len;
    }
  }

  /** When the chord changes under a held note that no longer fits, slide it. */
  private retuneHeld(pool: Pool, t: number) {
    for (const h of this.held.values()) {
      const w = pool.weight[mod12(h.pitch)];
      if (w === 0 || w === 1) continue;
      const taken = [...this.held.values()].filter((o) => o !== h).map((o) => o.pitch);
      const np = nearestAllowed(h.pitch, pool, taken);
      if (np === h.pitch) continue;
      this.off(LEAD_ID, h.pitch, t);
      this.on(LEAD_ID, np, h.vel * 0.85, t);
      h.pitch = np;
    }
  }

  // ------------------------------------------------------------------ emit

  private on(layer: string, pitch: number, vel: number, time: number) {
    if (pitch < 0 || pitch > 127) return;
    for (const s of this.sinks) s.noteOn(layer, pitch, Math.min(1, Math.max(0.02, vel)), time);
  }

  private off(layer: string, pitch: number, time: number) {
    if (pitch < 0 || pitch > 127) return;
    for (const s of this.sinks) s.noteOff(layer, pitch, time);
  }

  private note(layer: string, pitch: number, vel: number, time: number, dur: number) {
    this.on(layer, pitch, vel, time);
    this.off(layer, pitch, time + Math.max(0.03, dur));
  }

  private drum(layer: string, voice: DrumVoice, vel: number, time: number) {
    for (const s of this.sinks) s.drum(layer, voice, Math.min(1, Math.max(0.05, vel)), time);
  }
}
