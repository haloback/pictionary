// Built-in preview instruments (Web Audio). These are sketches for auditioning
// a take, not the final sound: they respond to velocity, the dynamics curve,
// vibrato and pitch bend so you can hear the performance data working.

import type { Art, InstId } from '../engine/types';

type Kind = 'drums' | 'pluck' | 'bass' | 'piano' | 'ep' | 'organ' | 'clav' | 'horn';

interface Chan {
  kind: Kind;
  inst: InstId;
  variant: string;
  input: GainNode;
  filter: BiquadFilterNode | null;
  dyn: GainNode;
  vol: GainNode;
  detune: ConstantSourceNode;
  vibGain: GainNode;
  openHat: GainNode | null;
}

const mtof = (m: number) => 440 * Math.pow(2, (m - 69) / 12);

const FORMANTS: Record<string, { f: number[]; odd: number; tilt: number; noise: number; cutoff: number }> = {
  trumpet: { f: [1200, 2500], odd: 1, tilt: 0.95, noise: 0, cutoff: 6500 },
  alto: { f: [950, 2100], odd: 0.7, tilt: 1.15, noise: 0.05, cutoff: 5200 },
  tenor: { f: [650, 1750], odd: 0.7, tilt: 1.15, noise: 0.06, cutoff: 4300 },
  trombone: { f: [520, 1500], odd: 1, tilt: 1.05, noise: 0, cutoff: 4000 },
  bari: { f: [380, 1150], odd: 0.65, tilt: 1.1, noise: 0.06, cutoff: 3200 },
  flute: { f: [900, 1800], odd: 1, tilt: 2.1, noise: 0.09, cutoff: 5200 },
};

export class Synth {
  ctx!: AudioContext;
  private master!: GainNode;
  private rev!: ConvolverNode;
  private revIn!: GainNode;
  private chans = new Map<string, Chan>();
  private noise!: AudioBuffer;
  private ksCache = new Map<string, { buf: AudioBuffer; n: number }>();
  private waveCache = new Map<string, PeriodicWave>();
  private lfo!: OscillatorNode;
  ready = false;

  init(): void {
    if (this.ready) return;
    const Ctx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    this.ctx = new Ctx({ latencyHint: 'interactive' });
    const c = this.ctx;
    this.master = c.createGain();
    this.master.gain.value = 0.7;
    const comp = c.createDynamicsCompressor();
    comp.threshold.value = -14;
    comp.ratio.value = 3;
    comp.attack.value = 0.008;
    comp.release.value = 0.18;
    this.master.connect(comp).connect(c.destination);

    // noise for drums and breath
    this.noise = c.createBuffer(1, c.sampleRate * 2, c.sampleRate);
    const nd = this.noise.getChannelData(0);
    for (let i = 0; i < nd.length; i++) nd[i] = Math.random() * 2 - 1;

    // a small room
    const len = Math.floor(c.sampleRate * 1.3);
    const ir = c.createBuffer(2, len, c.sampleRate);
    for (let ch = 0; ch < 2; ch++) {
      const d = ir.getChannelData(ch);
      let lp = 0;
      for (let i = 0; i < len; i++) {
        const x = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2.6);
        lp += 0.35 * (x - lp);
        d[i] = lp;
      }
    }
    this.rev = c.createConvolver();
    this.rev.buffer = ir;
    this.revIn = c.createGain();
    this.revIn.gain.value = 1;
    const revOut = c.createGain();
    revOut.gain.value = 0.5;
    this.revIn.connect(this.rev).connect(revOut).connect(this.master);

    this.lfo = c.createOscillator();
    this.lfo.frequency.value = 5.6;
    this.lfo.start();
    this.ready = true;
  }

  /** the mix bus (before the output compressor); other engines can join it */
  get bus(): AudioNode {
    return this.master;
  }

  setMaster(v: number): void {
    if (this.ready) this.master.gain.setTargetAtTime(v, this.ctx.currentTime, 0.02);
  }

  private kindOf(inst: InstId, variant: string): Kind {
    if (inst === 'drums' || inst === 'perc') return 'drums';
    if (inst === 'bass') return 'bass';
    if (inst === 'guitar') return 'pluck';
    if (inst === 'keys') {
      if (['organ', 'rockorgan', 'strings', 'pad'].includes(variant)) return 'organ';
      if (variant === 'clav') return 'clav';
      return variant === 'grand' || variant === 'upright' ? 'piano' : 'ep';
    }
    return 'horn';
  }

  /** Create or update the mixer strip for a track. */
  channel(id: string, inst: InstId, variant: string, gain: number, pan = 0): Chan {
    const c = this.ctx;
    let ch = this.chans.get(id);
    const kind = this.kindOf(inst, variant);
    if (ch && (ch.kind !== kind || ch.inst !== inst || ch.variant !== variant)) {
      ch.vol.disconnect();
      this.chans.delete(id);
      ch = undefined;
    }
    if (!ch) {
      const input = c.createGain();
      const dyn = c.createGain();
      const vol = c.createGain();
      const panner = c.createStereoPanner();
      panner.pan.value = pan;
      let filter: BiquadFilterNode | null = null;
      if (kind === 'horn') {
        filter = c.createBiquadFilter();
        filter.type = 'lowpass';
        filter.frequency.value = 2400;
        filter.Q.value = 0.6;
        input.connect(filter).connect(dyn);
      } else input.connect(dyn);
      dyn.connect(vol).connect(panner).connect(this.master);
      const send = c.createGain();
      send.gain.value = kind === 'horn' ? 0.22 : kind === 'bass' ? 0.02 : kind === 'drums' ? 0.08 : 0.14;
      panner.connect(send).connect(this.revIn);
      const detune = c.createConstantSource();
      detune.offset.value = 0;
      detune.start();
      const vibGain = c.createGain();
      vibGain.gain.value = 0;
      this.lfo.connect(vibGain);
      ch = { kind, inst, variant, input, filter, dyn, vol, detune, vibGain, openHat: null };
      this.chans.set(id, ch);
    }
    ch.vol.gain.setTargetAtTime(gain, c.currentTime, 0.02);
    return ch;
  }
  removeMissing(ids: Set<string>): void {
    for (const [id, ch] of this.chans) {
      if (!ids.has(id)) {
        ch.vol.disconnect();
        this.chans.delete(id);
      }
    }
  }
  setGain(id: string, gain: number): void {
    const ch = this.chans.get(id);
    if (ch) ch.vol.gain.setTargetAtTime(gain, this.ctx.currentTime, 0.02);
  }

  // ---- continuous control
  dyn(id: string, when: number, v: number): void {
    const ch = this.chans.get(id);
    if (!ch) return;
    ch.dyn.gain.setTargetAtTime(0.18 + 0.82 * Math.pow(v, 1.6), when, 0.012);
    if (ch.filter) {
      const f = FORMANTS[ch.inst] ?? FORMANTS.tenor;
      ch.filter.frequency.setTargetAtTime(500 + Math.pow(v, 1.6) * f.cutoff, when, 0.015);
    }
  }
  vib(id: string, when: number, v: number): void {
    const ch = this.chans.get(id);
    if (ch) ch.vibGain.gain.setTargetAtTime(v * 28, when, 0.02);
  }
  bend(id: string, when: number, semis: number): void {
    const ch = this.chans.get(id);
    if (ch) ch.detune.offset.setTargetAtTime(semis * 100, when, 0.004);
  }
  resetControls(): void {
    if (!this.ready) return;
    const t = this.ctx.currentTime;
    for (const ch of this.chans.values()) {
      ch.dyn.gain.cancelScheduledValues(t);
      ch.dyn.gain.setTargetAtTime(ch.kind === 'horn' || ch.kind === 'organ' ? 0.6 : 1, t, 0.02);
      ch.vibGain.gain.cancelScheduledValues(t);
      ch.vibGain.gain.setTargetAtTime(0, t, 0.02);
      ch.detune.offset.cancelScheduledValues(t);
      ch.detune.offset.setTargetAtTime(0, t, 0.01);
      if (ch.filter) ch.filter.frequency.cancelScheduledValues(t);
    }
  }
  /** Fade everything that is sounding (used on stop). */
  panic(): void {
    if (!this.ready) return;
    const t = this.ctx.currentTime;
    for (const ch of this.chans.values()) {
      const g = ch.input.gain;
      g.cancelScheduledValues(t);
      g.setTargetAtTime(0, t, 0.015);
      g.setTargetAtTime(1, t + 0.12, 0.01);
    }
    this.resetControls();
  }

  // ---- notes
  note(id: string, when: number, pitch: number, vel: number, dur: number, art?: Art): void {
    const ch = this.chans.get(id);
    if (!ch) return;
    const v = vel / 127;
    switch (ch.kind) {
      case 'drums':
        return this.drum(ch, when, pitch, v);
      case 'pluck':
        return this.pluck(ch, when, pitch, v, dur, art, ch.variant === 'nylon' ? 0.3 : ch.variant === 'jazz' ? 0.28 : ch.variant === 'steel' ? 0.75 : 0.55, 0.5);
      case 'bass':
        return this.pluck(ch, when, pitch, v, dur, art, ch.variant === 'slap' || ch.variant === 'pick' ? 0.5 : ch.variant === 'upright' ? 0.2 : 0.3, 0.9);
      case 'piano':
        return this.pluck(ch, when, pitch, v, dur, art, 0.35, 0.55, true);
      case 'clav':
        return this.pluck(ch, when, pitch, v, Math.min(dur, 0.5), art, 0.95, 0.5);
      case 'ep':
        return this.ep(ch, when, pitch, v, dur);
      case 'organ':
        return this.organ(ch, when, pitch, v, dur);
      case 'horn':
        return this.horn(ch, when, pitch, v, dur, art);
    }
  }

  private wire(ch: Chan, p: AudioParam): void {
    ch.detune.connect(p);
    ch.vibGain.connect(p);
  }

  /** Karplus-Strong string, rendered once per pitch and cached. */
  private string(pitch: number, bright: number, muted: boolean, soft: boolean): { buf: AudioBuffer; n: number } {
    const b = Math.round(bright * 5);
    const key = `${pitch}:${b}:${muted ? 1 : 0}:${soft ? 1 : 0}`;
    const hit = this.ksCache.get(key);
    if (hit) return hit;
    const sr = this.ctx.sampleRate;
    const f = mtof(pitch);
    const n = Math.max(2, Math.round(sr / f));
    const secs = muted ? 0.35 : pitch < 48 ? 4 : 3;
    const len = Math.floor(sr * secs);
    const buf = this.ctx.createBuffer(1, len, sr);
    const d = buf.getChannelData(0);
    let lp = 0;
    const k = 0.08 + (b / 5) * 0.85;
    let mean = 0;
    for (let i = 0; i < n; i++) {
      const x = Math.random() * 2 - 1;
      lp += k * (x - lp);
      d[i] = lp;
      mean += lp;
    }
    mean /= n;
    for (let i = 0; i < n; i++) d[i] -= mean;
    if (soft) for (let i = 0; i < n; i++) d[i] *= Math.sin((Math.PI * i) / n);
    const decay = muted ? 0.93 : Math.min(0.9996, 0.9905 + (pitch - 28) * 0.00016);
    for (let i = n; i < len; i++) d[i] = decay * 0.5 * (d[i - n] + d[i - n + 1]);
    let peak = 0;
    for (let i = 0; i < Math.min(len, n * 8); i++) peak = Math.max(peak, Math.abs(d[i]));
    const g = peak > 0 ? 0.9 / peak : 1;
    for (let i = 0; i < len; i++) d[i] *= g;
    const out = { buf, n };
    this.ksCache.set(key, out);
    return out;
  }

  private pluck(ch: Chan, when: number, pitch: number, v: number, dur: number, art: Art | undefined, bright: number, level: number, piano = false): void {
    const c = this.ctx;
    const muted = art === 'ghost' || art === 'mute';
    const s = this.string(pitch, Math.min(1, bright * (0.55 + v * 0.6)), muted, piano);
    const src = c.createBufferSource();
    src.buffer = s.buf;
    src.playbackRate.value = (mtof(pitch) * s.n) / c.sampleRate;
    this.wire(ch, src.detune);
    const g = c.createGain();
    const amp = level * (0.25 + v * v * 0.9) * (art === 'ghost' ? 0.6 : 1);
    g.gain.setValueAtTime(0, when);
    g.gain.linearRampToValueAtTime(amp, when + 0.002);
    const end = when + Math.max(0.03, dur);
    g.gain.setTargetAtTime(0, end, piano ? 0.07 : 0.035);
    src.connect(g).connect(ch.input);
    if (ch.kind === 'bass') {
      // weight: a sine at the fundamental
      const o = c.createOscillator();
      o.frequency.value = mtof(pitch);
      this.wire(ch, o.detune);
      const og = c.createGain();
      og.gain.setValueAtTime(0, when);
      og.gain.linearRampToValueAtTime(muted ? amp * 0.3 : amp * 0.55, when + 0.006);
      og.gain.setTargetAtTime(0, when + 0.02, muted ? 0.05 : 0.7);
      og.gain.setTargetAtTime(0, end, 0.03);
      o.connect(og).connect(ch.input);
      o.start(when);
      o.stop(end + 0.4);
    }
    src.start(when);
    src.stop(end + 0.6);
  }

  private ep(ch: Chan, when: number, pitch: number, v: number, dur: number): void {
    const c = this.ctx;
    const f = mtof(pitch);
    const car = c.createOscillator();
    const mod = c.createOscillator();
    const mg = c.createGain();
    car.frequency.value = f;
    mod.frequency.value = f * (ch.variant === 'wurli' ? 2 : 1);
    this.wire(ch, car.detune);
    this.wire(ch, mod.detune);
    const idx = f * (0.3 + v * v * (ch.variant === 'wurli' ? 2.6 : 1.9));
    mg.gain.setValueAtTime(idx, when);
    mg.gain.setTargetAtTime(idx * 0.12, when + 0.005, 0.22);
    mod.connect(mg).connect(car.frequency);
    // bell-like tine partial
    const tine = c.createOscillator();
    tine.frequency.value = f * 4.01;
    this.wire(ch, tine.detune);
    const tg = c.createGain();
    tg.gain.setValueAtTime(0.08 * v, when);
    tg.gain.setTargetAtTime(0, when, 0.09);
    const g = c.createGain();
    const amp = 0.2 * (0.25 + v * 0.9);
    g.gain.setValueAtTime(0, when);
    g.gain.linearRampToValueAtTime(amp, when + 0.003);
    g.gain.setTargetAtTime(amp * 0.25, when + 0.01, 1.1);
    const end = when + Math.max(0.04, dur);
    g.gain.setTargetAtTime(0, end, 0.06);
    car.connect(g);
    tine.connect(tg).connect(g);
    g.connect(ch.input);
    for (const o of [car, mod, tine]) {
      o.start(when);
      o.stop(end + 0.5);
    }
  }

  private wave(key: string, build: () => Float32Array): PeriodicWave {
    let w = this.waveCache.get(key);
    if (!w) {
      const imag = build();
      w = this.ctx.createPeriodicWave(new Float32Array(imag.length), imag);
      this.waveCache.set(key, w);
    }
    return w;
  }

  private organ(ch: Chan, when: number, pitch: number, v: number, dur: number): void {
    const c = this.ctx;
    const o = c.createOscillator();
    o.setPeriodicWave(
      this.wave('organ', () => {
        const a = new Float32Array(17);
        const bars: [number, number][] = [[1, 1], [2, 0.8], [3, 0.7], [4, 0.45], [6, 0.3], [8, 0.3], [16, 0.12]];
        for (const [h, amp] of bars) a[h] = amp;
        return a;
      }),
    );
    o.frequency.value = mtof(pitch);
    this.wire(ch, o.detune);
    const g = c.createGain();
    const amp = 0.11 + v * 0.03;
    g.gain.setValueAtTime(0, when);
    g.gain.linearRampToValueAtTime(amp * 1.3, when + 0.004);
    g.gain.setTargetAtTime(amp, when + 0.01, 0.02);
    const end = when + Math.max(0.04, dur);
    g.gain.setTargetAtTime(0, end, 0.02);
    o.connect(g).connect(ch.input);
    o.start(when);
    o.stop(end + 0.2);
  }

  private horn(ch: Chan, when: number, pitch: number, v: number, dur: number, art?: Art): void {
    const c = this.ctx;
    const fm = FORMANTS[ch.inst] ?? FORMANTS.tenor;
    const f = mtof(pitch);
    const o = c.createOscillator();
    o.setPeriodicWave(
      this.wave(`${ch.inst}:${ch.variant}:${pitch}`, () => {
        const n = Math.min(40, Math.floor(9000 / f));
        const a = new Float32Array(n + 1);
        for (let h = 1; h <= n; h++) {
          const hz = h * f;
          let bump = 0.25;
          for (const ff of fm.f) bump += Math.exp(-Math.pow((hz - ff) / (ff * 0.55), 2));
          const muted = ch.variant === 'muted' ? Math.exp(-Math.pow((hz - 2200) / 900, 2)) * 2 + 0.1 : 1;
          a[h] = (bump * muted * (h % 2 === 0 ? fm.odd : 1)) / Math.pow(h, fm.tilt);
        }
        return a;
      }),
    );
    o.frequency.value = f;
    this.wire(ch, o.detune);
    const g = c.createGain();
    const legato = art === 'legato';
    const hard = art === 'marcato' || art === 'staccato';
    const amp = 0.4 * (0.35 + v * 0.75);
    const atk = legato ? 0.012 : hard ? 0.016 : 0.03;
    g.gain.setValueAtTime(0, when);
    g.gain.linearRampToValueAtTime(amp * (hard ? 1.25 : 1), when + atk);
    g.gain.setTargetAtTime(amp, when + atk, 0.05);
    const end = when + Math.max(0.05, dur);
    g.gain.setTargetAtTime(0, end, 0.028);
    o.connect(g);
    if (fm.noise > 0) {
      const ns = c.createBufferSource();
      ns.buffer = this.noise;
      ns.loop = true;
      const bp = c.createBiquadFilter();
      bp.type = 'bandpass';
      bp.frequency.value = Math.min(6000, f * 5);
      bp.Q.value = 0.8;
      const ng = c.createGain();
      ng.gain.value = fm.noise * 6;
      ns.connect(bp).connect(ng).connect(g);
      ns.start(when, Math.random());
      ns.stop(end + 0.2);
    }
    g.connect(ch.input);
    o.start(when);
    o.stop(end + 0.25);
  }

  // ---- drums
  private burst(ch: Chan, when: number, type: BiquadFilterType, freq: number, q: number, amp: number, decay: number, dest?: AudioNode): GainNode {
    const c = this.ctx;
    const ns = c.createBufferSource();
    ns.buffer = this.noise;
    const fl = c.createBiquadFilter();
    fl.type = type;
    fl.frequency.value = freq;
    fl.Q.value = q;
    const g = c.createGain();
    g.gain.setValueAtTime(amp, when);
    g.gain.setTargetAtTime(0, when + 0.001, decay);
    ns.connect(fl).connect(g).connect(dest ?? ch.input);
    ns.start(when, Math.random());
    ns.stop(when + decay * 8 + 0.05);
    return g;
  }
  private tone(ch: Chan, when: number, f0: number, f1: number, sweep: number, amp: number, decay: number, type: OscillatorType = 'sine'): void {
    const c = this.ctx;
    const o = c.createOscillator();
    o.type = type;
    o.frequency.setValueAtTime(f0, when);
    o.frequency.exponentialRampToValueAtTime(Math.max(20, f1), when + sweep);
    const g = c.createGain();
    g.gain.setValueAtTime(amp, when);
    g.gain.setTargetAtTime(0, when + 0.002, decay);
    o.connect(g).connect(ch.input);
    o.start(when);
    o.stop(when + decay * 8 + 0.05);
  }
  private drum(ch: Chan, when: number, pitch: number, v: number): void {
    const a = v * v;
    const choke = () => {
      if (ch.openHat) {
        ch.openHat.gain.cancelScheduledValues(when);
        ch.openHat.gain.setTargetAtTime(0, when, 0.008);
        ch.openHat = null;
      }
    };
    switch (pitch) {
      case 36:
        this.tone(ch, when, 150, 46, 0.09, 1.0 * a + 0.15, 0.09);
        this.burst(ch, when, 'lowpass', 2500, 0.5, 0.25 * a, 0.006);
        break;
      case 38:
        this.tone(ch, when, 240, 170, 0.04, 0.4 * a + 0.03, 0.05, 'triangle');
        this.burst(ch, when, 'bandpass', 3200, 0.5, 0.7 * a + 0.03, 0.065 + v * 0.03);
        break;
      case 37:
        this.tone(ch, when, 1700, 1650, 0.01, 0.3 * a + 0.05, 0.012, 'triangle');
        this.burst(ch, when, 'bandpass', 900, 3, 0.5 * a, 0.012);
        break;
      case 39:
        for (let i = 0; i < 3; i++) this.burst(ch, when + i * 0.011, 'bandpass', 1300, 1.2, 0.5 * a, i === 2 ? 0.07 : 0.01);
        break;
      case 42:
        choke();
        this.burst(ch, when, 'highpass', 7500, 0.8, 0.32 * a + 0.02, 0.018 + v * 0.012);
        break;
      case 44:
        choke();
        this.burst(ch, when, 'highpass', 6500, 0.8, 0.2 * a + 0.02, 0.014);
        break;
      case 46:
        choke();
        ch.openHat = this.burst(ch, when, 'highpass', 6800, 0.8, 0.3 * a + 0.03, 0.16);
        break;
      case 51:
        this.burst(ch, when, 'bandpass', 5200, 1.6, 0.22 * a + 0.03, 0.22);
        this.tone(ch, when, 3400, 3400, 0.01, 0.03 * a, 0.12, 'square');
        break;
      case 53:
        this.tone(ch, when, 2900, 2900, 0.01, 0.07 * a, 0.2, 'square');
        this.burst(ch, when, 'bandpass', 5200, 2, 0.12 * a, 0.2);
        break;
      case 49:
      case 57:
        this.burst(ch, when, 'highpass', 4200, 0.4, 0.45 * a + 0.05, 0.5);
        break;
      case 50:
        this.tone(ch, when, 260, 190, 0.1, 0.7 * a, 0.11);
        break;
      case 47:
        this.tone(ch, when, 200, 140, 0.1, 0.75 * a, 0.13);
        break;
      case 43:
      case 45:
        this.tone(ch, when, 140, 95, 0.12, 0.8 * a, 0.16);
        break;
      case 54:
        this.burst(ch, when, 'highpass', 8200, 1.2, 0.26 * a + 0.02, 0.05);
        break;
      case 56:
        this.tone(ch, when, 800, 800, 0.01, 0.16 * a, 0.045, 'square');
        this.tone(ch, when, 540, 540, 0.01, 0.16 * a, 0.045, 'square');
        break;
      case 69:
      case 70:
        this.burst(ch, when, 'highpass', 6000, 0.7, 0.2 * a + 0.015, 0.022);
        break;
      case 62:
        this.tone(ch, when, 360, 330, 0.02, 0.5 * a + 0.02, v > 0.6 ? 0.035 : 0.02);
        this.burst(ch, when, 'bandpass', 2500, 1, 0.2 * a, 0.01);
        break;
      case 63:
        this.tone(ch, when, 300, 270, 0.03, 0.6 * a, 0.11);
        break;
      case 64:
        this.tone(ch, when, 200, 180, 0.03, 0.65 * a, 0.14);
        break;
      case 60:
        this.tone(ch, when, 520, 480, 0.02, 0.45 * a + 0.02, 0.05);
        break;
      case 61:
        this.tone(ch, when, 380, 350, 0.02, 0.5 * a, 0.08);
        break;
      case 75:
        this.tone(ch, when, 2400, 2400, 0.01, 0.4 * a, 0.016, 'triangle');
        break;
      case 67:
        this.tone(ch, when, 1150, 1150, 0.01, 0.2 * a, 0.07, 'square');
        break;
      case 68:
        this.tone(ch, when, 780, 780, 0.01, 0.2 * a, 0.08, 'square');
        break;
      default:
        this.burst(ch, when, 'bandpass', 3000, 1, 0.3 * a, 0.04);
    }
  }
}
