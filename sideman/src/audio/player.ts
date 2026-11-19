// Transport: schedules the arrangement into the preview synth and, when a port
// is chosen, out to any hardware or software synth over Web MIDI.

import { PPQ } from '../engine/types';
import type { Arrangement, Project } from '../engine/arrange';
import { applyPreset, renderEvents } from '../engine/midi';
import { Synth } from './synth';
import { SfSynth } from './sfsynth';

interface Ev {
  /** seconds from the top of the loop */
  time: number;
  fire: (when: number, perfNow: number) => void;
}

const LOOKAHEAD = 0.16;
const TICK_MS = 25;

const PAN: Record<string, number> = { drums: 0, perc: 0.3, bass: 0, guitar: -0.35, keys: 0.3, trumpet: 0.2, alto: -0.15, tenor: 0.12, trombone: -0.25, bari: 0.05, flute: -0.1 };

export class Player {
  synth = new Synth();
  /** sampled General MIDI instruments; used instead of the sketch synth when loaded */
  sf = new SfSynth();
  /** which preview engine the user wants */
  engine: 'sampled' | 'sketch' = 'sampled';
  private evs: Ev[] = [];
  private idx = 0;
  private loopN = 0;
  private startTime = 0;
  private loopDur = 0;
  private timer: number | null = null;
  private tempo = 120;
  private lenTicks = 0;
  private midiOut: MIDIOutput | null = null;
  private channels = new Set<number>();
  playing = false;
  loop = true;
  previewMuted = false;
  onEnd: (() => void) | null = null;

  setMidiOut(out: MIDIOutput | null): void {
    this.silenceMidi();
    this.midiOut = out;
  }

  private gains(project: Project): Map<string, number> {
    const anySolo = project.tracks.some((t) => t.solo);
    const m = new Map<string, number>();
    for (const t of project.tracks) m.set(t.id, t.mute || (anySolo && !t.solo) ? 0 : t.gain);
    return m;
  }

  /** (Re)build the event list. Safe to call while playing: playback carries on from the same spot. */
  load(project: Project, arr: Arrangement): void {
    this.tempo = project.tempo;
    this.lenTicks = arr.len;
    const spt = 60 / (project.tempo * PPQ);
    const newDur = arr.len * spt;
    const evs: Ev[] = [];
    const gains = this.gains(project);
    const synth = this.synth;
    if (synth.ready) {
      synth.removeMissing(new Set(project.tracks.map((t) => t.id)));
      for (const t of project.tracks) synth.channel(t.id, t.inst, t.variant, this.previewMuted ? 0 : gains.get(t.id)!, PAN[t.inst] ?? 0);
    }
    this.channels = new Set(project.tracks.map((t) => t.midi.channel - 1));
    const sampled = this.sampled();
    for (const t of project.tracks) {
      const part = arr.parts[t.id];
      if (!part) continue;
      const id = t.id;
      if (sampled) {
        // the sampled preview hears a General MIDI rendering of the part, whatever mapping the export uses
        const gain = this.previewMuted ? 0 : gains.get(id)!;
        const ch = t.midi.channel - 1;
        evs.push({ time: 0, fire: (when) => this.sf.send([0xb0 | ch, 7, Math.round(Math.sqrt(gain) * 118)], when) });
        if (gain > 0) {
          for (const e of renderEvents(part, { ...applyPreset(t.midi, 'gm'), velMin: 1, velMax: 127 }, project.tempo)) {
            const bytes = e.b;
            evs.push({ time: e.t * spt + e.o * 1e-5 + 1e-4, fire: (when) => this.sf.send(bytes, when) });
          }
        }
      } else
      for (const n of part.notes) {
        const dur = n.d * spt;
        evs.push({ time: n.t * spt, fire: (when) => synth.note(id, when, n.p, n.v, dur, n.art) });
      }
      if (!sampled) {
        for (const c of part.ctrl) {
          if (c.k === 'dyn') evs.push({ time: c.t * spt, fire: (when) => synth.dyn(id, when, c.v) });
          else if (c.k === 'vib') evs.push({ time: c.t * spt, fire: (when) => synth.vib(id, when, c.v) });
        }
        for (const b of part.bends) evs.push({ time: b.t * spt, fire: (when) => synth.bend(id, when, b.s) });
      }
      // live MIDI goes out exactly as the exported file would
      if (gains.get(id)! > 0) {
        for (const e of renderEvents(part, t.midi, project.tempo)) {
          const bytes = e.b;
          evs.push({
            time: e.t * spt + e.o * 1e-5,
            fire: (_when, perfNow) => {
              if (this.midiOut) this.midiOut.send(bytes, perfNow);
            },
          });
        }
      }
    }
    evs.sort((a, b) => a.time - b.time);
    if (this.playing && this.synth.ready && newDur > 0) {
      // keep our place
      const now = this.synth.ctx.currentTime;
      const pos = this.loopDur > 0 ? (now - this.startTime) % this.loopDur : 0;
      const frac = this.loopDur > 0 ? pos / this.loopDur : 0;
      const same = Math.abs(newDur - this.loopDur) < 1e-6;
      const newPos = same ? pos : Math.min(frac * newDur, newDur - 0.01);
      this.startTime = now - newPos;
      this.loopN = 0;
      this.evs = evs;
      this.loopDur = newDur;
      this.idx = this.firstAfter(newPos + LOOKAHEAD);
      if (this.idx >= evs.length) {
        this.idx = 0;
        this.loopN = 1;
      }
    } else {
      this.evs = evs;
      this.loopDur = newDur;
    }
  }

  private firstAfter(time: number): number {
    let lo = 0;
    let hi = this.evs.length;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      if (this.evs[mid].time < time) lo = mid + 1;
      else hi = mid;
    }
    return lo;
  }

  /** Is the sampled engine the one sounding? */
  sampled(): boolean {
    return this.engine === 'sampled' && this.sf.ready;
  }

  applyMix(project: Project): void {
    if (!this.synth.ready) return;
    const gains = this.gains(project);
    for (const t of project.tracks) {
      const g = this.previewMuted ? 0 : gains.get(t.id)!;
      if (this.sampled()) {
        const ch = t.midi.channel - 1;
        this.sf.now([0xb0 | ch, 7, Math.round(Math.sqrt(g) * 118)]);
        if (g === 0) this.sf.now([0xb0 | ch, 123, 0]);
      } else this.synth.setGain(t.id, g);
    }
  }

  /** Bring up the sampled instruments if they are wanted. Returns true when they are sounding. */
  async prepare(): Promise<boolean> {
    this.synth.init();
    if (this.engine !== 'sampled' || this.sf.failed) return false;
    if (!this.sf.ready) await this.sf.init(this.synth.ctx, this.synth.bus);
    return this.sf.ready;
  }

  async play(project: Project, arr: Arrangement, fromTick = 0): Promise<void> {
    this.synth.init();
    if (this.synth.ctx.state === 'suspended') await this.synth.ctx.resume();
    await this.prepare();
    this.stop(false);
    this.playing = false;
    this.load(project, arr);
    if (!this.evs.length || this.loopDur <= 0) return;
    const spt = 60 / (this.tempo * PPQ);
    const offset = Math.min(fromTick * spt, this.loopDur - 0.01);
    this.startTime = this.synth.ctx.currentTime + 0.06 - offset;
    this.loopN = 0;
    this.idx = this.firstAfter(offset);
    this.playing = true;
    this.pump();
    this.timer = window.setInterval(() => this.pump(), TICK_MS);
  }

  private pump(): void {
    if (!this.playing) return;
    const ctx = this.synth.ctx;
    const now = ctx.currentTime;
    const horizon = now + LOOKAHEAD;
    const perfBase = performance.now() - now * 1000;
    let guard = 0;
    while (guard++ < 20000) {
      if (this.idx >= this.evs.length) {
        if (!this.loop) {
          if (now > this.startTime + (this.loopN + 1) * this.loopDur) {
            this.stop();
            this.onEnd?.();
          }
          return;
        }
        this.idx = 0;
        this.loopN++;
      }
      const e = this.evs[this.idx];
      const when = this.startTime + this.loopN * this.loopDur + e.time;
      if (when > horizon) break;
      if (when > now - 0.03) e.fire(Math.max(when, now), perfBase + Math.max(when, now) * 1000);
      this.idx++;
    }
  }

  stop(panic = true): void {
    if (this.timer != null) window.clearInterval(this.timer);
    this.timer = null;
    const was = this.playing;
    this.playing = false;
    if (panic && was) {
      this.synth.panic();
      if (this.sf.ready) {
        this.sf.silence();
        for (const ch of this.channels) {
          this.sf.now([0xb0 | ch, 64, 0]);
          this.sf.now([0xe0 | ch, 0, 64]);
          this.sf.now([0xb0 | ch, 1, 0]);
          this.sf.now([0xb0 | ch, 11, 127]);
        }
      }
      this.silenceMidi();
    }
  }

  private silenceMidi(): void {
    if (!this.midiOut) return;
    for (const ch of this.channels) {
      try {
        this.midiOut.send([0xb0 | ch, 123, 0]);
        this.midiOut.send([0xb0 | ch, 64, 0]);
        this.midiOut.send([0xe0 | ch, 0, 64]);
      } catch {
        /* port went away */
      }
    }
  }

  /** Current position in ticks within the loop, or -1 when stopped. */
  position(): number {
    if (!this.playing || !this.synth.ready || this.loopDur <= 0) return -1;
    const t = this.synth.ctx.currentTime - this.startTime;
    if (t < 0) return 0;
    const pos = this.loop ? t % this.loopDur : Math.min(t, this.loopDur);
    return (pos / this.loopDur) * this.lenTicks;
  }
}

export const player = new Player();
