import { BEAT } from './types';
import type { Chord, ChordSpan } from './types';
import { parseChord } from './theory';

export interface ChartChord {
  sym: string;
  chord: Chord;
  /** start within the bar, in beats (0..4) */
  start: number;
  beats: number;
}
export interface ChartBar {
  chords: ChartChord[];
}
export interface Chart {
  bars: ChartBar[];
  errors: string[];
}

/**
 * Chart syntax:
 *   bars are separated by "|" or new lines
 *   several chords in a bar share it evenly:  "Dm7 G7"  ->  2 + 2 beats
 *   "." holds the previous chord for a slot:  "C . . G" ->  3 + 1 beats
 *   "%" repeats the previous bar
 */
export function parseChart(text: string): Chart {
  const errors: string[] = [];
  const bars: ChartBar[] = [];
  const rawBars = text
    .replace(/\r/g, '')
    .split(/[|\n]+/)
    .map((b) => b.trim())
    .filter((b) => b.length > 0);

  let lastChord: { sym: string; chord: Chord } | null = null;
  for (const raw of rawBars) {
    const tokens = raw.split(/\s+/).filter(Boolean);
    if (tokens.length === 1 && (tokens[0] === '%' || tokens[0] === '-')) {
      if (bars.length) bars.push({ chords: bars[bars.length - 1].chords.map((c) => ({ ...c })) });
      else errors.push('"%" has no bar to repeat');
      continue;
    }
    let slots = tokens.slice(0, 8);
    if (tokens.length > 8) errors.push(`Bar "${raw}" has more than 8 slots; extra chords ignored`);
    let slotBeats: number[];
    if (slots.length === 1) slotBeats = [4];
    else if (slots.length === 2) slotBeats = [2, 2];
    else if (slots.length === 3) slotBeats = [2, 1, 1];
    else if (slots.length === 4) slotBeats = [1, 1, 1, 1];
    else {
      while (slots.length < 8) slots = [...slots, '.'];
      slotBeats = slots.map(() => 0.5);
    }
    const chords: ChartChord[] = [];
    let pos = 0;
    slots.forEach((tok, i) => {
      const beats = slotBeats[i];
      if (tok === '.' || tok === '/' || tok === '%') {
        if (chords.length) chords[chords.length - 1].beats += beats;
        else if (lastChord) chords.push({ ...lastChord, start: pos, beats });
        else errors.push('Chart starts with a hold');
      } else {
        const chord = parseChord(tok);
        if (!chord) {
          errors.push(`Can't read chord "${tok}"`);
          if (chords.length) chords[chords.length - 1].beats += beats;
          else if (lastChord) chords.push({ ...lastChord, start: pos, beats });
        } else {
          lastChord = { sym: chord.sym, chord };
          chords.push({ sym: chord.sym, chord, start: pos, beats });
        }
      }
      pos += beats;
    });
    if (chords.length) bars.push({ chords });
  }
  return { bars, errors };
}

/** Flatten a chart into tick-based chord spans, looping it `repeats` times. */
export function expandChart(chart: Chart, repeats = 1): ChordSpan[] {
  const spans: ChordSpan[] = [];
  const n = chart.bars.length;
  for (let r = 0; r < repeats; r++) {
    chart.bars.forEach((bar, bi) => {
      const barIdx = r * n + bi;
      for (const c of bar.chords) {
        spans.push({
          t: Math.round((barIdx * 4 + c.start) * BEAT),
          d: Math.round(c.beats * BEAT),
          chord: c.chord,
          bar: barIdx,
          change: true,
        });
      }
    });
  }
  for (let i = 0; i < spans.length; i++) {
    const prev = spans[(i - 1 + spans.length) % spans.length];
    spans[i].change = i === 0 || prev.chord.sym !== spans[i].chord.sym;
  }
  return spans;
}

export function chartToText(chart: Chart): string {
  return chart.bars
    .map((b) => {
      if (b.chords.length === 1) return b.chords[0].sym;
      const even = b.chords.every((c) => c.beats === 4 / b.chords.length);
      if (even && [2, 4].includes(b.chords.length)) return b.chords.map((c) => c.sym).join(' ');
      // write explicit quarter-note slots
      const slots: string[] = [];
      for (const c of b.chords) {
        slots.push(c.sym);
        for (let i = 1; i < Math.round(c.beats); i++) slots.push('.');
      }
      return slots.join(' ');
    })
    .join(' | ');
}

export interface ProgressionPreset {
  name: string;
  text: string;
  style?: string;
  tempo?: number;
}

export const PROGRESSIONS: ProgressionPreset[] = [
  { name: 'Neo-soul turnaround', text: 'Dm9 | G13 | Cmaj9 | A7#9', style: 'neosoul', tempo: 84 },
  { name: 'Funk vamp', text: 'E9 | E9 | A13 | A13 B13', style: 'funk', tempo: 102 },
  { name: 'Soul changes', text: 'Bb | Gm7 | Eb | F7', style: 'soul', tempo: 108 },
  { name: 'Pop four-chord', text: 'C | G | Am | F', style: 'pop', tempo: 116 },
  { name: 'Jazz ii-V-I', text: 'Dm7 G7 | Cmaj7 A7b9 | Dm7 G7 | Cmaj7', style: 'jazz', tempo: 144 },
  { name: 'Rhythm changes A', text: 'Bbmaj7 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 | Fm7 Bb7 | Ebmaj7 Ebm6 | Dm7 G7 | Cm7 F7', style: 'jazz', tempo: 168 },
  { name: '12-bar blues', text: 'A7 | D7 | A7 | A7 | D7 | D7 | A7 | A7 | E7 | D7 | A7 | E7', style: 'blues', tempo: 112 },
  { name: 'Bossa in F', text: 'Fmaj7 | G7#11 | Gm7 | C7b9 | Am7 D7b9 | Gm7 C7 | Fmaj7 | Gm7 C7', style: 'bossa', tempo: 132 },
  { name: 'Reggae two-chord', text: 'Am | Am | G | G', style: 'reggae', tempo: 76 },
  { name: 'Ballad descent', text: 'Cmaj7 | G/B | Am7 | C/G | Fmaj7 | Em7 | Dm7 | Gsus4 G', style: 'ballad', tempo: 68 },
  { name: 'Afrobeat groove', text: 'Am7 | Am7 | D9 | D9', style: 'afrobeat', tempo: 112 },
  { name: 'Rock anthem', text: 'D5 | A5 | Bm | G', style: 'rock', tempo: 128 },
  { name: 'Minor soul', text: 'Cm7 | Fm7 | Abmaj7 | G7#9', style: 'soul', tempo: 96 },
];
