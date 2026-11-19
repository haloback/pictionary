// MIDI in and out. Inputs come through Web MIDI. Output goes either to a
// Web MIDI port or to the "Hamfist" virtual port that the macOS app creates
// (so a DAW sees Hamfist as an instrument without any IAC setup).
import { DRUM_GM, type DrumVoice } from "../engine/patterns";
import type { Sink } from "../engine/types";

export interface PortInfo {
  id: string;
  name: string;
}

export interface MidiInputHandler {
  noteOn(id: string, pitch: number, vel: number): void;
  noteOff(id: string): void;
  sustain(on: boolean): void;
}

declare global {
  interface Window {
    hamfist?: {
      platform: string;
      virtualMidi(): Promise<boolean>;
      midiSend(bytes: number[], atEpochMs: number): void;
      saveMidi(name: string, bytes: Uint8Array): Promise<string | null>;
    };
  }
}

export const VIRTUAL_ID = "hamfist-virtual";

/** Our own virtual port shows up as a system MIDI source; never treat it as a device. */
const isSelf = (name: string | null) => !!name && name.includes("Hamfist");

export class Midi implements Sink {
  private access: MIDIAccess | null = null;
  private out: MIDIOutput | null = null;
  private outId = "";
  private virtual = false;
  private channels = new Map<string, number>();
  private programs = new Map<string, number>();
  private handler: MidiInputHandler | null = null;
  onPorts: (ins: PortInfo[], outs: PortInfo[]) => void = () => {};
  error: string | null = null;

  async init(handler: MidiInputHandler) {
    this.handler = handler;
    this.virtual = (await window.hamfist?.virtualMidi().catch(() => false)) ?? false;
    if (!navigator.requestMIDIAccess) {
      this.error = "This runtime has no MIDI support.";
      this.publish();
      return;
    }
    try {
      this.access = await navigator.requestMIDIAccess({ sysex: false });
    } catch {
      this.error = "MIDI access was denied.";
      this.publish();
      return;
    }
    this.access.onstatechange = () => this.bind();
    this.bind();
  }

  private bind() {
    if (!this.access) return;
    for (const input of this.access.inputs.values()) {
      // Never listen to our own virtual port: that would feed back.
      if (isSelf(input.name)) {
        input.onmidimessage = null;
        continue;
      }
      input.onmidimessage = (e) => this.receive(input.id, e.data);
    }
    if (this.outId && this.outId !== VIRTUAL_ID) this.out = this.access.outputs.get(this.outId) ?? null;
    this.publish();
  }

  private publish() {
    const ins: PortInfo[] = [];
    const outs: PortInfo[] = [];
    if (this.virtual) outs.push({ id: VIRTUAL_ID, name: "Hamfist (virtual port)" });
    if (this.access) {
      for (const i of this.access.inputs.values()) if (!isSelf(i.name)) ins.push({ id: i.id, name: i.name ?? "MIDI input" });
      for (const o of this.access.outputs.values()) if (!isSelf(o.name)) outs.push({ id: o.id, name: o.name ?? "MIDI output" });
    }
    this.onPorts(ins, outs);
  }

  private receive(port: string, data: Uint8Array | null) {
    if (!data || data.length < 2 || !this.handler) return;
    const status = data[0] & 0xf0;
    const id = `midi:${port}:${data[0] & 15}:${data[1]}`;
    if (status === 0x90 && data[2] > 0) this.handler.noteOn(id, data[1], data[2] / 127);
    else if (status === 0x80 || status === 0x90) this.handler.noteOff(id);
    else if (status === 0xb0 && data[1] === 64) this.handler.sustain(data[2] >= 64);
  }

  setOutput(id: string) {
    this.panic();
    this.outId = id;
    this.out = id && id !== VIRTUAL_ID ? (this.access?.outputs.get(id) ?? null) : null;
    for (const [layer, program] of this.programs) this.sendProgram(layer, program);
  }

  /** Channel is 1-16; program is a General MIDI number, ignored on channel 10. */
  configure(layer: string, channel: number, program: number) {
    const ch = Math.min(15, Math.max(0, channel - 1));
    const changed = this.channels.get(layer) !== ch || this.programs.get(layer) !== program;
    this.channels.set(layer, ch);
    this.programs.set(layer, program);
    if (changed) this.sendProgram(layer, program);
  }

  remove(layer: string) {
    this.channels.delete(layer);
    this.programs.delete(layer);
  }

  private sendProgram(layer: string, program: number) {
    const ch = this.channels.get(layer);
    if (ch === undefined || ch === 9) return;
    this.send([0xc0 | ch, program & 127], performance.now() / 1000);
  }

  private send(bytes: number[], time: number) {
    if (!this.outId) return;
    const ms = time * 1000;
    if (this.outId === VIRTUAL_ID) window.hamfist?.midiSend(bytes, performance.timeOrigin + ms);
    else {
      try {
        this.out?.send(bytes, Math.max(ms, performance.now()));
      } catch {
        /* port went away */
      }
    }
  }

  noteOn(layer: string, pitch: number, vel: number, time: number) {
    const ch = this.channels.get(layer);
    if (ch === undefined) return;
    this.send([0x90 | ch, pitch, Math.max(1, Math.round(vel * 127))], time);
  }

  noteOff(layer: string, pitch: number, time: number) {
    const ch = this.channels.get(layer);
    if (ch === undefined) return;
    this.send([0x80 | ch, pitch, 0], time);
  }

  drum(_layer: string, voice: DrumVoice, vel: number, time: number) {
    const key = DRUM_GM[voice];
    this.send([0x99, key, Math.max(1, Math.round(vel * 127))], time);
    this.send([0x89, key, 0], time + 0.06);
  }

  panic() {
    if (!this.outId) return;
    const now = performance.now() / 1000;
    for (let ch = 0; ch < 16; ch++) {
      this.send([0xb0 | ch, 123, 0], now);
      this.send([0xb0 | ch, 64, 0], now);
    }
  }
}
