// Minimal Standard MIDI File (format 1) writer.
import { DRUM_GM, type DrumVoice } from "./patterns";

export interface Take {
  bpm: number;
  tracks: TakeTrack[];
}

export interface TakeTrack {
  name: string;
  /** 0-15. Channel 9 is percussion. */
  channel: number;
  program: number;
  events: TakeEvent[];
}

export type TakeEvent =
  | { kind: "on"; time: number; pitch: number; vel: number }
  | { kind: "off"; time: number; pitch: number }
  | { kind: "drum"; time: number; voice: DrumVoice; vel: number };

const PPQ = 480;

function vlq(n: number): number[] {
  const out = [n & 0x7f];
  while ((n >>= 7) > 0) out.unshift((n & 0x7f) | 0x80);
  return out;
}

function chunk(id: string, data: number[]): number[] {
  const len = data.length;
  return [...id].map((c) => c.charCodeAt(0)).concat([(len >>> 24) & 255, (len >>> 16) & 255, (len >>> 8) & 255, len & 255], data);
}

const text = (s: string) => [...new TextEncoder().encode(s)];

export function writeMidi(take: Take): Uint8Array {
  const ticksPerSec = (PPQ * take.bpm) / 60;
  let start = Infinity;
  for (const t of take.tracks) for (const e of t.events) start = Math.min(start, e.time);
  if (!Number.isFinite(start)) start = 0;
  const tick = (time: number) => Math.max(0, Math.round((time - start) * ticksPerSec));

  const usPerBeat = Math.round(60_000_000 / take.bpm);
  const tempoTrack = [
    0x00, 0xff, 0x03, ...vlq(7), ...text("Hamfist"),
    0x00, 0xff, 0x51, 0x03, (usPerBeat >> 16) & 255, (usPerBeat >> 8) & 255, usPerBeat & 255,
    0x00, 0xff, 0x2f, 0x00,
  ];
  const chunks = [chunk("MTrk", tempoTrack)];

  for (const track of take.tracks) {
    const ch = track.channel & 15;
    const msgs: { tick: number; order: number; bytes: number[] }[] = [];
    for (const e of track.events) {
      if (e.kind === "on") {
        msgs.push({ tick: tick(e.time), order: 1, bytes: [0x90 | ch, e.pitch & 127, Math.max(1, Math.round(e.vel * 127))] });
      } else if (e.kind === "off") {
        msgs.push({ tick: tick(e.time), order: 0, bytes: [0x80 | ch, e.pitch & 127, 0] });
      } else {
        const key = DRUM_GM[e.voice];
        const at = tick(e.time);
        msgs.push({ tick: at, order: 1, bytes: [0x99, key, Math.max(1, Math.round(e.vel * 127))] });
        msgs.push({ tick: at + PPQ / 8, order: 0, bytes: [0x89, key, 0] });
      }
    }
    if (!msgs.length) continue;
    msgs.sort((a, b) => a.tick - b.tick || a.order - b.order);
    const name = text(track.name);
    const data: number[] = [0x00, 0xff, 0x03, ...vlq(name.length), ...name];
    if (ch !== 9) data.push(0x00, 0xc0 | ch, track.program & 127);
    let last = 0;
    for (const m of msgs) {
      data.push(...vlq(m.tick - last), ...m.bytes);
      last = m.tick;
    }
    data.push(0x00, 0xff, 0x2f, 0x00);
    chunks.push(chunk("MTrk", data));
  }

  const n = chunks.length;
  const header = chunk("MThd", [0, 1, (n >> 8) & 255, n & 255, (PPQ >> 8) & 255, PPQ & 255]);
  return new Uint8Array(header.concat(...chunks));
}
