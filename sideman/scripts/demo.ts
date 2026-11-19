// Prints a text view of a generated arrangement, and writes it as MIDI.
import { writeFileSync } from 'node:fs';
import { defaultProject, generate, exportMidi, smartRandomize } from '../src/engine/arrange';
import { noteName } from '../src/engine/theory';
import { getPattern } from '../src/engine/library';
import { BAR } from '../src/engine/types';

const p0 = defaultProject();
const style = (process.argv[2] as any) || p0.style;
const chart = process.argv[3] || p0.chart;
const seed = Number(process.argv[4] || 1);
let p = { ...p0, style, chart, repeats: 1 };
p = smartRandomize(p, seed);
const arr = generate(p);
console.log(`style=${p.style} key=${JSON.stringify(arr.key)} bars=${arr.bars}`);
for (const t of p.tracks) {
  const part = arr.parts[t.id];
  console.log(`\n== ${t.inst} :: ${getPattern(t.patternId)?.name} (${t.variant}) notes=${part.notes.length} ctrl=${part.ctrl.length} bends=${part.bends.length}`);
  if (t.inst === 'drums') continue;
  for (let b = 0; b < Math.min(arr.bars, 4); b++) {
    const ns = part.notes.filter((n) => n.t >= b * BAR - 40 && n.t < (b + 1) * BAR - 40);
    const byT = new Map<number, string[]>();
    for (const n of ns) {
      const k = Math.round((n.t - b * BAR) / 120);
      if (!byT.has(k)) byT.set(k, []);
      byT.get(k)!.push(noteName(n.p) + (n.art ? `(${n.art[0]})` : ''));
    }
    console.log(`  bar ${b + 1}: ` + [...byT.entries()].sort((a, c) => a[0] - c[0]).map(([k, v]) => `${k}:${v.join('+')}`).join('  '));
  }
}
if (process.argv[5]) writeFileSync(process.argv[5], exportMidi(p, arr));
