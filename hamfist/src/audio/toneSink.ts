// Built-in sound engine. Turns engine events into audio through Tone.js.
import * as Tone from "tone";
import type { DrumVoice } from "../engine/patterns";
import type { Sink } from "../engine/types";
import { getKit, getPreset, type Env, type KitDef, type Preset } from "./presets";

const env = (e: Env) => ({ attack: e[0], decay: e[1], sustain: e[2], release: e[3] });

interface Voice {
  key: string;
  gain: Tone.Gain;
  dispose(): void;
  on?(pitch: number, vel: number, time: number): void;
  off?(pitch: number, time: number): void;
  drum?(voice: DrumVoice, vel: number, time: number): void;
  releaseAll(): void;
}

class Buses {
  master: Tone.Gain;
  reverb: Tone.Gain;
  delay: Tone.Gain;
  private fx: Tone.FeedbackDelay;

  constructor() {
    const limiter = new Tone.Limiter(-1).toDestination();
    const comp = new Tone.Compressor({ threshold: -18, ratio: 3.5, attack: 0.01, release: 0.2 }).connect(limiter);
    this.master = new Tone.Gain(0.62).connect(comp);
    const rev = new Tone.Reverb({ decay: 2.8, preDelay: 0.012, wet: 1 }).connect(this.master);
    this.reverb = new Tone.Gain(1).connect(rev);
    this.fx = new Tone.FeedbackDelay({ delayTime: 0.3, feedback: 0.32, wet: 1 }).connect(this.master);
    this.delay = new Tone.Gain(1).connect(this.fx);
  }

  setTempo(bpm: number) {
    this.fx.delayTime.rampTo((60 / bpm) * 0.75, 0.1);
  }
}

function buildInstrument(p: Preset, buses: Buses): Voice {
  let synth: Tone.PolySynth<any>;
  if (p.voice === "mono") {
    const f = p.filt ?? { base: 2000, oct: 2, env: p.env };
    synth = new Tone.PolySynth(Tone.MonoSynth, {
      oscillator: p.osc ?? { type: "sawtooth" },
      envelope: env(p.env),
      filter: { type: "lowpass", rolloff: -24, Q: f.q ?? 1 },
      filterEnvelope: { ...env(f.env), baseFrequency: f.base, octaves: f.oct },
    } as any);
  } else if (p.voice === "fm") {
    synth = new Tone.PolySynth(Tone.FMSynth, {
      harmonicity: p.harm ?? 1,
      modulationIndex: p.index ?? 2,
      oscillator: { type: "sine" },
      modulation: { type: "sine" },
      envelope: env(p.env),
      modulationEnvelope: env(p.modEnv ?? p.env),
    } as any);
  } else {
    synth = new Tone.PolySynth(Tone.Synth, { oscillator: p.osc ?? { type: "triangle" }, envelope: env(p.env) } as any);
  }
  synth.maxPolyphony = 36;
  synth.volume.value = (p.gain ?? 0) - 9;

  const nodes: Tone.ToneAudioNode[] = [];
  if (p.drive) nodes.push(new Tone.Distortion({ distortion: p.drive, oversample: "2x" }));
  if (p.lp) nodes.push(new Tone.Filter(p.lp, "lowpass"));
  if (p.vibrato) nodes.push(new Tone.Vibrato(5.2, p.vibrato));
  if (p.tremolo) nodes.push(new Tone.Tremolo(4.6, p.tremolo).start());
  if (p.chorus) nodes.push(new Tone.Chorus({ frequency: 0.9, delayTime: 3.5, depth: 0.5, wet: 0.45 }).start());

  const gain = new Tone.Gain(0.8).connect(buses.master);
  const revSend = new Tone.Gain(p.rev ?? 0.12).connect(buses.reverb);
  const dlySend = new Tone.Gain(p.dly ?? 0).connect(buses.delay);
  gain.connect(revSend);
  gain.connect(dlySend);
  synth.chain(...nodes, gain);

  return {
    key: `i:${p.id}`,
    gain,
    on: (pitch, vel, time) => synth.triggerAttack(Tone.mtof(pitch as Tone.Unit.MidiNote), time, vel),
    off: (pitch, time) => synth.triggerRelease(Tone.mtof(pitch as Tone.Unit.MidiNote), time),
    releaseAll: () => synth.releaseAll(),
    dispose: () => {
      synth.releaseAll();
      // Let tails ring out before tearing the graph down.
      setTimeout(() => [synth, ...nodes, gain, revSend, dlySend].forEach((n) => n.dispose()), 2500);
    },
  };
}

function buildKit(kit: KitDef, buses: Buses): Voice {
  const gain = new Tone.Gain(0.8).connect(buses.master);
  const revSend = new Tone.Gain(0.07).connect(buses.reverb);
  gain.connect(revSend);
  const tone = new Tone.Filter(kit.lp, "lowpass").connect(gain);
  const trim = new Tone.Volume(kit.gain - 4).connect(tone);

  const kick = new Tone.MembraneSynth({
    pitchDecay: kit.kick.drop,
    octaves: kit.kick.oct,
    oscillator: { type: "sine" },
    envelope: { attack: 0.001, decay: kit.kick.decay, sustain: 0, release: 0.05 },
  }).connect(trim);
  kick.volume.value = 2;

  const snareBody = new Tone.MembraneSynth({ pitchDecay: 0.012, octaves: 2, envelope: { attack: 0.001, decay: 0.11, sustain: 0, release: 0.03 } }).connect(trim);
  snareBody.volume.value = -8 + kit.snare.gain;
  const snareBand = new Tone.Filter(1800, "highpass").connect(trim);
  const snareNoise = new Tone.NoiseSynth({ noise: { type: "white" }, envelope: { attack: 0.001, decay: kit.snare.decay, sustain: 0, release: 0.03 } }).connect(snareBand);
  snareNoise.volume.value = -9 + kit.snare.gain;

  const hatHp = new Tone.Filter(8000, "highpass").connect(trim);
  const hat = new Tone.NoiseSynth({ noise: { type: "white" }, envelope: { attack: 0.001, decay: kit.hat, sustain: 0, release: 0.01 } }).connect(hatHp);
  hat.volume.value = -16;
  const openHat = new Tone.NoiseSynth({ noise: { type: "white" }, envelope: { attack: 0.001, decay: 0.26, sustain: 0, release: 0.05 } }).connect(hatHp);
  openHat.volume.value = -18;

  const clapBp = new Tone.Filter({ frequency: 1300, type: "bandpass", Q: 1.4 }).connect(trim);
  const clap = new Tone.NoiseSynth({ noise: { type: "pink" }, envelope: { attack: 0.004, decay: 0.16, sustain: 0, release: 0.04 } }).connect(clapBp);
  clap.volume.value = -3;

  const rim = new Tone.MembraneSynth({ pitchDecay: 0.004, octaves: 1.2, envelope: { attack: 0.001, decay: 0.045, sustain: 0, release: 0.01 } }).connect(trim);
  rim.volume.value = -10;

  const tom = new Tone.MembraneSynth({ pitchDecay: 0.05, octaves: 2.5, envelope: { attack: 0.001, decay: 0.28, sustain: 0, release: 0.05 } }).connect(trim);
  tom.volume.value = -5;

  // Shaker in most kits, a conga-like hand drum in the percussion kit.
  const shakerHp = new Tone.Filter(5200, "highpass").connect(trim);
  const shaker = new Tone.NoiseSynth({ noise: { type: "white" }, envelope: { attack: 0.006, decay: 0.05, sustain: 0, release: 0.01 } }).connect(shakerHp);
  shaker.volume.value = -19;
  const conga = new Tone.MembraneSynth({ pitchDecay: 0.01, octaves: 1.4, envelope: { attack: 0.001, decay: 0.16, sustain: 0, release: 0.03 } }).connect(trim);
  conga.volume.value = -7;

  const bell = new Tone.PolySynth(Tone.Synth, { oscillator: { type: "square" }, envelope: { attack: 0.001, decay: kit.latin ? 0.05 : 0.14, sustain: 0, release: 0.02 } } as any).connect(trim);
  bell.volume.value = kit.latin ? -14 : -20;

  const cymHp = new Tone.Filter(6000, "highpass").connect(trim);
  const ride = new Tone.MetalSynth({ harmonicity: 5.1, modulationIndex: 20, resonance: 5000, octaves: 1, envelope: { attack: 0.001, decay: 0.5, release: 0.1 } } as any).connect(cymHp);
  ride.volume.value = -27;
  const crash = new Tone.NoiseSynth({ noise: { type: "white" }, envelope: { attack: 0.002, decay: 1.1, sustain: 0, release: 0.2 } }).connect(cymHp);
  crash.volume.value = -17;

  // Tone refuses to start a monophonic source twice at the same instant.
  const last: Partial<Record<DrumVoice, number>> = {};
  const all = [kick, snareBody, snareNoise, snareBand, hat, openHat, hatHp, clap, clapBp, rim, tom, shaker, shakerHp, conga, bell, ride, crash, cymHp, trim, tone, gain, revSend];

  return {
    key: `k:${kit.id}`,
    gain,
    drum: (voice, vel, time) => {
      const prev = last[voice] ?? 0;
      const t = time <= prev ? prev + 0.002 : time;
      last[voice] = t;
      switch (voice) {
        case "k":
          kick.triggerAttackRelease(kit.kick.freq, 0.2, t, vel);
          break;
        case "s":
          snareBody.triggerAttackRelease(kit.snare.tone, 0.1, t, vel);
          snareNoise.triggerAttackRelease(0.1, t, vel);
          break;
        case "h":
          hat.triggerAttackRelease(0.03, t, vel);
          break;
        case "oh":
          openHat.triggerAttackRelease(0.2, t, vel);
          break;
        case "c":
          clap.triggerAttackRelease(0.1, t, vel);
          break;
        case "r":
          rim.triggerAttackRelease(kit.latin ? 1900 : 520, 0.03, t, vel);
          break;
        case "t":
          tom.triggerAttackRelease(kit.latin ? 150 : 105, 0.2, t, vel);
          break;
        case "p":
          if (kit.latin) conga.triggerAttackRelease(vel > 0.6 ? 250 : 330, 0.1, t, vel);
          else shaker.triggerAttackRelease(0.04, t, vel);
          break;
        case "cb":
          if (kit.latin) bell.triggerAttackRelease([2450], 0.03, t, vel);
          else bell.triggerAttackRelease([545, 815], 0.08, t, vel);
          break;
        case "rd":
          ride.triggerAttackRelease(320, 0.3, t, vel);
          break;
        case "cr":
          crash.triggerAttackRelease(0.8, t, vel * 0.8);
          break;
      }
    },
    releaseAll: () => {},
    dispose: () => setTimeout(() => all.forEach((n) => n.dispose()), 1500),
  };
}

export class ToneSink implements Sink {
  private buses: Buses | null = null;
  private voices = new Map<string, Voice>();
  private wanted = new Map<string, { key: string; volume: number }>();
  private offset = -Infinity;
  ready = false;

  /** Must be called from a user gesture. */
  async init() {
    if (this.ready) return;
    await Tone.start();
    Tone.getContext().lookAhead = 0.2;
    this.buses = new Buses();
    this.ready = true;
    for (const [id, w] of this.wanted) this.apply(id, w.key, w.volume);
  }

  setTempo(bpm: number) {
    this.buses?.setTempo(bpm);
  }

  /** `key` is "i:<presetId>" or "k:<kitId>". */
  configure(layer: string, key: string, volume: number) {
    this.wanted.set(layer, { key, volume });
    if (this.ready) this.apply(layer, key, volume);
  }

  remove(layer: string) {
    this.wanted.delete(layer);
    this.voices.get(layer)?.dispose();
    this.voices.delete(layer);
  }

  layers() {
    return [...this.wanted.keys()];
  }

  private apply(layer: string, key: string, volume: number) {
    let v = this.voices.get(layer);
    if (!v || v.key !== key) {
      v?.dispose();
      v = key.startsWith("k:") ? buildKit(getKit(key.slice(2)), this.buses!) : buildInstrument(getPreset(key.slice(2)), this.buses!);
      this.voices.set(layer, v);
    }
    v.gain.gain.rampTo(volume * volume * 1.2, 0.05);
  }

  /** Engine clock (performance.now seconds) to audio context time. */
  private at(time: number): number {
    const ctx = Tone.getContext();
    const now = ctx.currentTime;
    const measured = now - performance.now() / 1000;
    // currentTime advances in blocks; the running max is the true offset.
    this.offset = Math.max(this.offset - 0.00002, measured);
    return Math.max(now, time + this.offset);
  }

  noteOn(layer: string, pitch: number, vel: number, time: number) {
    if (!this.ready) return;
    try {
      this.voices.get(layer)?.on?.(pitch, vel, this.at(time));
    } catch {
      /* a dropped note is better than a dead transport */
    }
  }

  noteOff(layer: string, pitch: number, time: number) {
    if (!this.ready) return;
    try {
      this.voices.get(layer)?.off?.(pitch, this.at(time) + 0.001);
    } catch {
      /* ignore */
    }
  }

  drum(layer: string, voice: DrumVoice, vel: number, time: number) {
    if (!this.ready) return;
    try {
      this.voices.get(layer)?.drum?.(voice, vel, this.at(time));
    } catch {
      /* ignore */
    }
  }

  panic() {
    for (const v of this.voices.values()) v.releaseAll();
  }
}
