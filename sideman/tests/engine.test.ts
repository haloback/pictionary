import { describe, expect, it } from 'vitest';
import { parseChord, detectKey, chordPcs, scaleFor } from '../src/engine/theory';
import { parseChart, expandChart, PROGRESSIONS } from '../src/engine/chart';
import { defaultProject, generate, smartRandomize, rerollTrack, exportMidi, makeTrack } from '../src/engine/arrange';
import type { Project } from '../src/engine/arrange';
import { PATTERNS, STYLES, INSTRUMENTS, patternsFor, patternsForStyle } from '../src/engine/library';
import { parseSMF, PROFILE_PRESETS, applyPreset } from '../src/engine/midi';
import { pickVoicing, fretString } from '../src/engine/fretboard';
import { chordsFromMidi } from '../src/engine/detect';
import { RNG } from '../src/engine/rng';
import { BAR } from '../src/engine/types';
import type { InstId } from '../src/engine/types';
import { HORN_RANGE } from '../src/engine/horns';

describe('chord parsing', () => {
  it('reads common symbols', () => {
    const cases: [string, number[]][] = [
      ['C', [0, 4, 7]],
      ['Am', [9, 0, 4]],
      ['Bbmaj7', [10, 2, 5, 9]],
      ['F#m7b5', [6, 9, 0, 4]],
      ['G13', [7, 11, 2, 5, 4, 9].sort((a, b) => a - b)],
      ['Dsus4', [2, 7, 9]],
      ['E7#9', [4, 8, 11, 2, 7]],
      ['Cdim7', [0, 3, 6, 9]],
      ['C6/9', [0, 4, 7, 9, 2]],
      ['D5', [2, 9]],
      ['AbM9', [8, 0, 3, 7, 10]],
      ['C-7', [0, 3, 7, 10]],
    ];
    for (const [sym, pcs] of cases) {
      const c = parseChord(sym);
      expect(c, sym).not.toBeNull();
      expect([...chordPcs(c!)].sort((a, b) => a - b), sym).toEqual([...pcs].sort((a, b) => a - b));
    }
    expect(parseChord('C/E')!.bass).toBe(4);
    expect(parseChord('H7')).toBeNull();
    expect(parseChord('Cxyz')).toBeNull();
  });
  it('detects keys', () => {
    const k = detectKey(expandChart(parseChart('Dm7 | G7 | Cmaj7 | Cmaj7')));
    expect(k).toEqual({ tonic: 0, minor: false });
    const k2 = detectKey(expandChart(parseChart('Am | F | C | G | Am | Dm | E7 | Am')));
    expect(k2).toEqual({ tonic: 9, minor: true });
  });
  it('chooses chord scales that contain the chord', () => {
    for (const sym of ['Cmaj7', 'D7#11', 'Em7', 'A7alt', 'Bm7b5', 'G13', 'F6', 'Csus4']) {
      const c = parseChord(sym)!;
      const sc = scaleFor(c, { tonic: 0, minor: false });
      expect(sc).toContain(0);
      if (c.third != null) expect(sc, sym).toContain(c.third);
    }
  });
});

describe('chart', () => {
  it('splits bars and holds', () => {
    const c = parseChart('C . . G | % | Dm7 G7\nCmaj7');
    expect(c.errors).toEqual([]);
    expect(c.bars.length).toBe(4);
    expect(c.bars[0].chords.map((x) => x.beats)).toEqual([3, 1]);
    expect(c.bars[1].chords.map((x) => x.sym)).toEqual(['C', 'G']);
    const spans = expandChart(c, 2);
    expect(spans[spans.length - 1].t + spans[spans.length - 1].d).toBe(8 * BAR);
  });
  it('reports bad chords without dying', () => {
    const c = parseChart('C | Zz | G');
    expect(c.errors.length).toBe(1);
    expect(c.bars.length).toBe(3); // the unreadable bar holds the previous chord so the form keeps its length
    expect(c.bars[1].chords[0].sym).toBe('C');
  });
});

describe('guitar voicings', () => {
  it('finds playable shapes', () => {
    const rng = new RNG(1);
    expect(fretString(pickVoicing(parseChord('G')!, 'full', null, rng))).toMatch(/^3200[03]3$/);
    expect(fretString(pickVoicing(parseChord('C')!, 'full', null, rng))).toBe('x32010');
    for (const sym of ['F#m7b5', 'Bb13', 'Ebmaj9', 'C7#9', 'Abm7', 'D/F#', 'Gsus4', 'B7alt']) {
      for (const kind of ['full', 'top4', 'triad', 'shell', 'power'] as const) {
        const v = pickVoicing(parseChord(sym)!, kind, null, rng);
        expect(v.strings.length, sym + kind).toBeGreaterThanOrEqual(3);
        const fretted = v.frets.filter((f) => f > 0);
        expect(Math.max(...fretted) - Math.min(...fretted), sym + kind).toBeLessThanOrEqual(3);
      }
    }
  });
});

function allCombos(): Project[] {
  const out: Project[] = [];
  for (const style of STYLES) {
    for (const prog of PROGRESSIONS) {
      const p = defaultProject();
      p.style = style.id;
      p.tempo = style.tempo;
      p.chart = prog.text;
      p.repeats = 2;
      p.tracks = [];
      for (const inst of INSTRUMENTS) p.tracks.push(makeTrack(inst.id, style.id, p.tracks, new RNG(5)));
      out.push(p);
    }
  }
  return out;
}

describe('generation', () => {
  it('is deterministic', () => {
    const p = defaultProject();
    expect(JSON.stringify(generate(p).parts)).toBe(JSON.stringify(generate(p).parts));
  });

  it('every recipe produces valid, in-range notes for every style', () => {
    const chart = 'Dm9 G13 | Cmaj9 | F#m7b5 B7alt | Em7 A7#9 | Bb/D | N.C. | Gsus4 . . G | C6';
    let checked = 0;
    for (const style of STYLES) {
      for (const pat of PATTERNS) {
        const insts = INSTRUMENTS.filter((i) => i.family === pat.family);
        const p = defaultProject();
        p.style = style.id;
        p.tempo = style.tempo;
        p.chart = chart;
        p.repeats = 1;
        p.tracks = insts.map((i, k) => ({ ...makeTrack(i.id, style.id, [], new RNG(3 + k)), patternId: pat.id }));
        const arr = generate(p);
        expect(arr.errors).toEqual([]);
        for (const t of p.tracks) {
          const part = arr.parts[t.id];
          expect(part.notes.length, `${pat.id} ${style.id} ${t.inst}`).toBeGreaterThan(0);
          for (const n of part.notes) {
            expect(Number.isFinite(n.t) && Number.isFinite(n.d) && Number.isFinite(n.p), pat.id).toBe(true);
            expect(n.t).toBeGreaterThanOrEqual(0);
            expect(n.t + n.d).toBeLessThanOrEqual(arr.len);
            expect(n.d).toBeGreaterThan(0);
            expect(n.v).toBeGreaterThanOrEqual(1);
            expect(n.v).toBeLessThanOrEqual(127);
            expect(n.p).toBeGreaterThanOrEqual(21);
            expect(n.p).toBeLessThanOrEqual(108);
          }
          // nothing sounds during the N.C. bar except drums
          if (pat.family !== 'drums' && pat.family !== 'perc') {
            const inNc = part.notes.filter((n) => n.t >= 5 * BAR + 120 && n.t < 6 * BAR - 240);
            expect(inNc.length, `${pat.id} ${style.id} plays through N.C.`).toBe(0);
          }
          for (const c of part.ctrl) {
            expect(c.v).toBeGreaterThanOrEqual(0);
            expect(c.v).toBeLessThanOrEqual(1);
            expect(Number.isFinite(c.t)).toBe(true);
          }
          for (const bd of part.bends) expect(Math.abs(bd.s)).toBeLessThanOrEqual(2.01);
          if (pat.family === 'horn') {
            const r = HORN_RANGE[t.inst as keyof typeof HORN_RANGE];
            for (const n of part.notes) {
              expect(n.p, `${pat.id} ${t.inst} low`).toBeGreaterThanOrEqual(r.lo - 2);
              expect(n.p, `${pat.id} ${t.inst} high`).toBeLessThanOrEqual(r.hi + 1);
            }
          }
          if (pat.family === 'bass') for (const n of part.notes) expect(n.p, pat.id).toBeLessThanOrEqual(67);
          checked++;
        }
      }
    }
    expect(checked).toBeGreaterThan(500);
  });

  it('same pitch never overlaps itself', () => {
    for (const p of allCombos().slice(0, 40)) {
      const arr = generate(smartRandomize(p, 77));
      for (const t of p.tracks) {
        const byPitch = new Map<number, number>();
        for (const n of arr.parts[t.id].notes) {
          const end = byPitch.get(n.p) ?? -1;
          expect(n.t, `${t.inst} ${p.style}`).toBeGreaterThanOrEqual(end);
          byPitch.set(n.p, n.t + n.d);
        }
      }
    }
  });

  it('bass plays the root when the harmony changes', () => {
    let hits = 0;
    let total = 0;
    for (const p of allCombos()) {
      const q = smartRandomize(p, 11);
      const arr = generate(q);
      const bass = q.tracks.find((t) => t.inst === 'bass')!;
      const notes = arr.parts[bass.id].notes.filter((n) => n.art !== 'ghost');
      for (const s of arr.spans) {
        if (!s.change || s.chord.nc) continue;
        total++;
        const near = notes.filter((n) => n.t > s.t - 300 && n.t < s.t + 200 && n.p % 12 === s.chord.bass);
        if (near.length) hits++;
      }
    }
    // reggae and ballad lines sometimes leave the downbeat open by design
    expect(hits / total).toBeGreaterThan(0.85);
  });

  it('randomise respects locks and changes the rest', () => {
    const p = defaultProject();
    p.tracks[1].locked = true;
    const q = smartRandomize(p, 4242);
    expect(q.tracks[1]).toEqual(p.tracks[1]);
    expect(JSON.stringify(q.tracks)).not.toBe(JSON.stringify(p.tracks));
    const a1 = generate(p).parts[p.tracks[1].id];
    const a2 = generate(q).parts[q.tracks[1].id];
    // bass depends on the drummer's kick, so only compare when the drummer is locked too
    const p2 = { ...p, tracks: p.tracks.map((t, i) => (i === 0 ? { ...t, locked: true } : t)) };
    const q2 = smartRandomize(p2, 4242);
    expect(JSON.stringify(generate(q2).parts[p.tracks[1].id])).toBe(JSON.stringify(generate(p2).parts[p.tracks[1].id]));
    void a1;
    void a2;
  });

  it('a new take changes the notes but keeps the recipe', () => {
    const p = defaultProject();
    for (const t of p.tracks) {
      const q = rerollTrack(p, t.id, 'take', 9);
      expect(q.tracks.find((x) => x.id === t.id)!.patternId).toBe(t.patternId);
      expect(JSON.stringify(generate(q).parts[t.id]), t.inst).not.toBe(JSON.stringify(generate(p).parts[t.id]));
      const r = rerollTrack(p, t.id, 'recipe', 9);
      expect(r.tracks.find((x) => x.id === t.id)!.patternId, t.inst).not.toBe(t.patternId);
    }
  });

  it('section horns play the same rhythm', () => {
    const p = defaultProject();
    const horns = p.tracks.filter((t) => ['trumpet', 'alto', 'tenor', 'trombone'].includes(t.inst));
    p.tracks = p.tracks.map((t) => (horns.includes(t) ? { ...t, patternId: 'hs.stabs' } : t));
    const arr = generate(p);
    const counts = horns.map((h) => arr.parts[h.id].notes.length);
    expect(new Set(counts).size).toBe(1);
    expect(counts[0]).toBeGreaterThan(4);
    // voices do not double the lead's pitch class on a seventh chord hit
    const lead = arr.parts[horns[0].id].notes;
    const second = arr.parts[horns[1].id].notes;
    const same = lead.filter((n, i) => second[i] && second[i].p % 12 === n.p % 12).length;
    expect(same / lead.length).toBeLessThan(0.3);
  });
});

describe('midi export', () => {
  it('writes a file that parses back to the same notes', () => {
    const p = defaultProject();
    const arr = generate(p);
    const bytes = exportMidi(p, arr);
    const smf = parseSMF(bytes);
    expect(smf.format).toBe(1);
    expect(smf.nTracks).toBe(p.tracks.length + 1);
    expect(Math.round(smf.tempo)).toBe(p.tempo);
    expect(smf.ends.every((e) => e === arr.len)).toBe(true);
    p.tracks.forEach((t, i) => {
      const got = smf.notes.filter((n) => n.track === i + 1);
      expect(got.length, t.inst).toBe(arr.parts[t.id].notes.length);
      expect(got.every((n) => n.ch === t.midi.channel - 1)).toBe(true);
    });
    expect(smf.markers.map((m) => m.text).slice(0, 4)).toEqual(['Dm9', 'G13', 'Cmaj9', 'A7#9']);
    expect(smf.cc.some((c) => c.num === 11)).toBe(true);
    expect(smf.bends.length).toBeGreaterThan(0);
  });
  it('single-track export is format 0 and loops exactly', () => {
    const p = defaultProject();
    const arr = generate(p);
    const smf = parseSMF(exportMidi(p, arr, [p.tracks[4].id]));
    expect(smf.format).toBe(0);
    expect(smf.ends[0]).toBe(arr.len);
    expect(smf.notes.length).toBe(arr.parts[p.tracks[4].id].notes.length);
  });
  it('profiles route dynamics and vibrato to different controllers', () => {
    const p = defaultProject();
    const horn = p.tracks.find((t) => t.inst === 'trumpet')!;
    p.tracks = p.tracks.map((t) => (t.inst === 'trumpet' ? { ...t, patternId: 'h.long' } : t));
    const arr = generate(p);
    const ccNums = (preset: (typeof PROFILE_PRESETS)[number]['id']) => {
      const q = { ...p, tracks: p.tracks.map((t) => (t.id === horn.id ? { ...t, midi: applyPreset(t.midi, preset) } : t)) };
      const smf = parseSMF(exportMidi(q, arr, [horn.id]));
      return { cc: new Set(smf.cc.map((c) => c.num)), bends: smf.bends.length, notes: smf.notes.length };
    };
    const gm = ccNums('gm');
    expect(gm.cc.has(11) && gm.cc.has(1)).toBe(true);
    const breath = ccNums('breath');
    expect(breath.cc.has(2) && breath.cc.has(11)).toBe(true);
    const lib = ccNums('mod');
    expect(lib.cc.has(1) && lib.cc.has(21)).toBe(true);
    const any = ccNums('anysynth');
    expect(any.cc.has(7)).toBe(true);
    expect(any.bends).toBeGreaterThan(gm.bends);
    const notes = ccNums('notes');
    expect(notes.cc.size).toBe(0);
    expect(notes.bends).toBe(0);
    const ks = ccNums('keyswitch');
    expect(ks.notes).toBeGreaterThan(gm.notes);
  });
  it('recovers the chords from an exported file', () => {
    const p = defaultProject();
    p.chart = 'C | Am | F | G7';
    p.repeats = 1;
    p.tracks = p.tracks.filter((t) => t.inst === 'keys' || t.inst === 'bass').map((t) => (t.inst === 'keys' ? { ...t, patternId: 'k.pop8' } : { ...t, patternId: 'b.pump8' }));
    const arr = generate(p);
    const res = chordsFromMidi(exportMidi(p, arr));
    expect(res.chart).toBe('C | Am | F | G7');
    expect(res.tempo).toBe(p.tempo);
  });
});

describe('library', () => {
  it('every instrument has recipes for every style', () => {
    for (const inst of INSTRUMENTS) {
      expect(patternsFor(inst.id as InstId).length).toBeGreaterThanOrEqual(5);
      for (const s of STYLES) expect(patternsForStyle(inst.id as InstId, s.id).length, `${inst.id} ${s.id}`).toBeGreaterThanOrEqual(2);
    }
    expect(new Set(PATTERNS.map((p) => p.id)).size).toBe(PATTERNS.length);
  });
});
