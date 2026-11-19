// Always-on capture: everything that sounds is remembered, so a good
// accident can be saved after the fact. Also feeds the stage visualiser.
import type { DrumVoice } from "../engine/patterns";
import type { TakeEvent } from "../engine/smf";
import type { Sink } from "../engine/types";

export interface VizNote {
  layer: string;
  pitch: number;
  start: number;
  end: number;
  vel: number;
}

export interface VizHit {
  time: number;
  /** Raw key pitch, or a drum voice lane. */
  pitch: number;
  kind: "raw" | "drum";
  vel: number;
  layer: string;
}

const KEEP_SECONDS = 600;
const DRUM_LANE: Record<DrumVoice, number> = { k: 0, t: 1, s: 2, r: 2, c: 3, p: 4, cb: 5, h: 6, oh: 6, rd: 7, cr: 7 };

export class Capture implements Sink {
  events = new Map<string, TakeEvent[]>();
  notes: VizNote[] = [];
  hits: VizHit[] = [];
  private open = new Map<string, VizNote[]>();
  /** Raw key pitch to the note it became, for the correction lines. */
  links: { raw: number; pitch: number; time: number }[] = [];
  private pendingRaw: { raw: number; time: number } | null = null;

  private push(layer: string, e: TakeEvent) {
    let list = this.events.get(layer);
    if (!list) this.events.set(layer, (list = []));
    list.push(e);
  }

  raw(pitch: number, time: number) {
    this.hits.push({ time, pitch, kind: "raw", vel: 1, layer: "raw" });
    this.pendingRaw = { raw: pitch, time };
  }

  noteOn(layer: string, pitch: number, vel: number, time: number) {
    this.push(layer, { kind: "on", time, pitch, vel });
    const n: VizNote = { layer, pitch, start: time, end: Infinity, vel };
    this.notes.push(n);
    const k = `${layer}:${pitch}`;
    const stack = this.open.get(k);
    if (stack) stack.push(n);
    else this.open.set(k, [n]);
    if (this.pendingRaw && layer === "lead") {
      this.links.push({ raw: this.pendingRaw.raw, pitch, time });
      this.pendingRaw = null;
    }
  }

  noteOff(layer: string, pitch: number, time: number) {
    this.push(layer, { kind: "off", time, pitch });
    const stack = this.open.get(`${layer}:${pitch}`);
    const n = stack?.shift();
    if (n) n.end = Math.max(time, n.start + 0.02);
  }

  drum(layer: string, voice: DrumVoice, vel: number, time: number) {
    this.push(layer, { kind: "drum", time, voice, vel });
    this.hits.push({ time, pitch: DRUM_LANE[voice], kind: "drum", vel, layer });
  }

  panic() {
    const now = performance.now() / 1000;
    for (const stack of this.open.values()) for (const n of stack) n.end = Math.min(n.end, now);
    this.open.clear();
  }

  /** Drop anything older than the capture window. */
  trim(now: number) {
    const vizCut = now - 14;
    if (this.notes.length > 400) this.notes = this.notes.filter((n) => n.end > vizCut);
    if (this.hits.length > 400) this.hits = this.hits.filter((h) => h.time > vizCut);
    if (this.links.length > 200) this.links = this.links.filter((l) => l.time > vizCut);
    const cut = now - KEEP_SECONDS;
    for (const [layer, list] of this.events) {
      if (list.length > 5000 && list[0].time < cut) this.events.set(layer, list.filter((e) => e.time >= cut));
    }
  }

  seconds(): number {
    let lo = Infinity;
    let hi = -Infinity;
    for (const list of this.events.values()) {
      if (!list.length) continue;
      lo = Math.min(lo, list[0].time);
      hi = Math.max(hi, list[list.length - 1].time);
    }
    return hi > lo ? hi - lo : 0;
  }

  clear() {
    this.events.clear();
  }
}
