// Read chords out of a MIDI file so a dropped clip becomes a chart.

import { parseSMF } from './midi';
import { mod12, pcName } from './theory';

const TEMPLATES: { suffix: string; ivs: number[]; bias: number }[] = [
  { suffix: '', ivs: [0, 4, 7], bias: 0.3 },
  { suffix: 'm', ivs: [0, 3, 7], bias: 0.3 },
  { suffix: '7', ivs: [0, 4, 7, 10], bias: 0.1 },
  { suffix: 'maj7', ivs: [0, 4, 7, 11], bias: 0.1 },
  { suffix: 'm7', ivs: [0, 3, 7, 10], bias: 0.1 },
  { suffix: 'm7b5', ivs: [0, 3, 6, 10], bias: 0 },
  { suffix: 'dim', ivs: [0, 3, 6], bias: 0 },
  { suffix: 'dim7', ivs: [0, 3, 6, 9], bias: -0.1 },
  { suffix: 'aug', ivs: [0, 4, 8], bias: -0.1 },
  { suffix: 'sus4', ivs: [0, 5, 7], bias: 0 },
  { suffix: 'sus2', ivs: [0, 2, 7], bias: -0.05 },
  { suffix: '6', ivs: [0, 4, 7, 9], bias: -0.05 },
  { suffix: 'm6', ivs: [0, 3, 7, 9], bias: -0.05 },
  { suffix: '9', ivs: [0, 4, 7, 10, 2], bias: 0 },
  { suffix: 'maj9', ivs: [0, 4, 7, 11, 2], bias: 0 },
  { suffix: 'm9', ivs: [0, 3, 7, 10, 2], bias: 0 },
  { suffix: '13', ivs: [0, 4, 10, 2, 9], bias: -0.05 },
  { suffix: 'add9', ivs: [0, 4, 7, 2], bias: -0.05 },
  { suffix: '5', ivs: [0, 7], bias: -0.2 },
];

function nameChord(weights: number[], bassPc: number | null): string | null {
  const total = weights.reduce((a, b) => a + b, 0);
  if (total <= 0) return null;
  let best = '';
  let bestScore = -Infinity;
  for (let root = 0; root < 12; root++) {
    for (const tp of TEMPLATES) {
      let inside = 0;
      let missing = 0;
      for (const iv of tp.ivs) {
        const w = weights[mod12(root + iv)];
        inside += w;
        if (w <= total * 0.06) missing++;
      }
      const outside = total - inside;
      let score = inside / total - (outside / total) * 1.1 - missing * 0.28 + tp.bias * 0.2;
      if (bassPc === root) score += 0.22;
      if (score > bestScore) {
        bestScore = score;
        const flats = [0, 5, 10, 3, 8, 1].includes(root) || tp.suffix.startsWith('m');
        best = pcName(root, flats) + tp.suffix;
        if (bassPc != null && bassPc !== root && tp.ivs.map((i) => mod12(root + i)).includes(bassPc) && weights[bassPc] > total * 0.2) {
          best += '/' + pcName(bassPc, flats);
        }
      }
    }
  }
  return bestScore > 0.2 ? best : null;
}

export interface DetectResult {
  chart: string;
  tempo: number;
  bars: number;
}

/** Analyse a MIDI file half a bar at a time and write the chords as a chart. */
export function chordsFromMidi(bytes: Uint8Array): DetectResult {
  const smf = parseSMF(bytes);
  const notes = smf.notes.filter((n) => n.ch !== 9);
  if (!notes.length) throw new Error('No pitched notes found in that MIDI file');
  const bar = smf.ppq * 4;
  const half = bar / 2;
  const end = Math.max(...notes.map((n) => n.t + n.d));
  const nBars = Math.min(64, Math.max(1, Math.ceil((end - smf.ppq / 4) / bar)));
  const out: string[] = [];
  let lastName = '';
  for (let b = 0; b < nBars; b++) {
    const names: (string | null)[] = [];
    for (let h = 0; h < 2; h++) {
      const s = b * bar + h * half;
      const e = s + half;
      const weights = new Array(12).fill(0);
      const low = new Array(12).fill(0);
      let lowest = 999;
      for (const n of notes) {
        const ov = Math.min(n.t + n.d, e) - Math.max(n.t, s);
        if (ov <= 0) continue;
        weights[mod12(n.p)] += ov * (n.p < 52 ? 1.6 : 1);
        if (n.p < 52) low[mod12(n.p)] += ov;
        if (n.p < lowest && ov > half * 0.2) lowest = n.p;
      }
      // the bass note is whichever low pitch is held longest, so a passing tone does not rename the chord
      const lowMax = Math.max(...low);
      const bassPc = lowMax > 0 ? low.indexOf(lowMax) : lowest < 999 ? mod12(lowest) : null;
      names.push(nameChord(weights, bassPc));
    }
    const a = names[0] ?? names[1] ?? lastName;
    const c = names[1] ?? a;
    if (!a) {
      out.push('N.C.');
      continue;
    }
    // the same chord over a moving bass is one chord, not two
    const same = a.split('/')[0] === c.split('/')[0];
    out.push(same ? (a.includes('/') && !c.includes('/') ? c : a) : `${a} ${c}`);
    lastName = c || a;
  }
  // drop trailing empty bars
  while (out.length > 1 && out[out.length - 1] === 'N.C.') out.pop();
  return { chart: out.join(' | '), tempo: Math.round(smf.tempo), bars: out.length };
}
