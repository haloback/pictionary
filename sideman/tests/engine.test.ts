import { describe, expect, it } from 'vitest';
import { parseChord, detectKey, chordPcs, scaleFor } from '../src/engine/theory';
import { parseChart, expandChart, PROGRESSIONS } from '../src/engine/chart';
import { defaultProject, generate, smartRandomize, rerollTrack, exportMidi, makeTrack, swapPhrase, applyBandPreset, presetFromProject, BAND_PRESETS } from '../src/engine/arrange';
import type { Project } from '../src/engine/arrange';
import { PATTERNS, STYLES, INSTRUMENTS, patternsFor, patternsForStyle, getPattern, variantDef } from '../src/engine/library';
import { bankSize, bankTotal, rhythmsOf, makePlan } from '../src/engine/phrasebank';
import { GROOVE_COUNTS } from '../src/engine/livedrums';
import { parseSMF, PROFILE_PRESETS, applyPreset } from '../src/engine/midi';
import { pickVoicing, fretString } from '../src/engine/fretboard';
import { chordsFromMidi } from '../src/engine/detect';
import { RNG } from '../src/engine/rng';
import { BAR } from '../src/engine/types';
import type { InstId } from '../src/engine/types';
import { HORN_RANGE, rangeOf } from '../src/engine/horns';

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
    const onePerFamily = STYLES.filter((s, i) => STYLES.findIndex((x) => x.family === s.family) === i);
    expect(onePerFamily.length).toBe(11);
    for (const style of onePerFamily) {
      for (const pat of PATTERNS) {
        const insts = INSTRUMENTS.filter((i) => i.family === pat.family);
        const p = defaultProject();
        p.style = style.id;
        p.tempo = style.tempo;
        p.chart = chart;
        p.repeats = 1;
        p.tracks = insts.flatMap((i, k) => i.variants.slice(0, pat.family === 'horn' ? 9 : 1).map((v) => ({ ...makeTrack(i.id, style.id, [], new RNG(3 + k)), patternId: pat.id, variant: v.id })));
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
            const r = rangeOf(t.inst as keyof typeof HORN_RANGE, variantDef(t.inst, t.variant).shift ?? 0);
            for (const n of part.notes) {
              expect(n.p, `${pat.id} ${t.inst} low`).toBeGreaterThanOrEqual(r.lo - 2);
              expect(n.p, `${pat.id} ${t.inst} high`).toBeLessThanOrEqual(r.hi + 1);
            }
          }
          if (pat.family === 'bass') for (const n of part.notes) expect(n.p, pat.id).toBeLessThanOrEqual(67);
          // an instrument type never plays an articulation it does not have
          const arts = new Set(variantDef(t.inst, t.variant).arts);
          for (const n of part.notes) if (n.art) expect(arts.has(n.art), `${t.inst}/${t.variant} played ${n.art}`).toBe(true);
          checked++;
        }
      }
    }
    expect(checked).toBeGreaterThan(1500);
  }, 180000);

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
    const hornIds = p.tracks.filter((t) => ['trumpet', 'alto', 'tenor', 'trombone'].includes(t.inst)).map((t) => t.id);
    p.tracks = p.tracks.map((t) => (hornIds.includes(t.id) ? { ...t, patternId: 'hs.stabs' } : t));
    const horns = p.tracks.filter((t) => hornIds.includes(t.id));
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

describe('recorded drummer', () => {
  it('ships a few thousand real bars', () => {
    expect(GROOVE_COUNTS.grooveBars).toBeGreaterThan(2500);
    expect(GROOVE_COUNTS.fills).toBeGreaterThan(600);
  });
  it('plays every recorded style at any tempo and swing, with kicks for the bass to lock to', () => {
    for (const pat of PATTERNS.filter((x) => x.tag)) {
      for (const [tempo, swing] of [[70, 0], [120, 0.3], [200, 0.6]] as const) {
        const p = defaultProject();
        p.tempo = tempo;
        p.swing = swing;
        p.chart = 'C | F | G | C';
        p.tracks = p.tracks.filter((t) => t.inst === 'drums' || t.inst === 'bass').map((t) => (t.inst === 'drums' ? { ...t, patternId: pat.id } : { ...t, patternId: 'b.kicklock' }));
        const arr = generate(p);
        const drums = arr.parts[p.tracks[0].id].notes;
        expect(drums.length, pat.id).toBeGreaterThan(40);
        expect(drums.some((n) => n.p === 36), pat.id + ' kick').toBe(true);
        expect(arr.parts[p.tracks[1].id].notes.length, pat.id + ' bass').toBeGreaterThan(8);
        // the drummer is in from the first beat
        expect(drums.some((n) => n.t < 480), pat.id).toBe(true);
      }
    }
  });
  it('humanize at zero snaps the performance to the grid', () => {
    const p = defaultProject();
    p.swing = 0;
    p.tracks = p.tracks.filter((t) => t.inst === 'drums').map((t) => ({ ...t, patternId: 'dl.funk', params: { ...t.params, humanize: 0 } }));
    const notes = generate(p).parts[p.tracks[0].id].notes;
    expect(notes.every((n) => n.t % 120 === 0)).toBe(true);
    const loose = generate({ ...p, tracks: p.tracks.map((t) => ({ ...t, params: { ...t.params, humanize: 0.5 } })) }).parts[p.tracks[0].id].notes;
    expect(loose.some((n) => n.t % 120 !== 0)).toBe(true);
  });
});

describe('phrase bank', () => {
  it('holds thousands of distinct phrases', () => {
    for (const s of STYLES) {
      const size = bankSize(s.family);
      expect(size.rhythms, s.id).toBeGreaterThan(40);
      expect(size.total, s.id).toBeGreaterThan(1500);
    }
    expect(bankTotal()).toBeGreaterThan(10000);
    for (const fam of ['funk', 'eight', 'swing', 'slow', 'latin'] as const) {
      const rs = rhythmsOf(fam);
      expect(new Set(rs.map((r) => r.s)).size).toBe(rs.length);
      expect(new Set(rs.map((r) => r.id)).size).toBe(rs.length);
      for (const r of rs) expect(r.s.length).toBe(16);
    }
  });
  it('a bank lead and a bank answer trade bars instead of talking over each other', () => {
    const p = defaultProject();
    p.repeats = 4;
    const tp = p.tracks.find((t) => t.inst === 'trumpet')!;
    const ts = p.tracks.find((t) => t.inst === 'tenor')!;
    p.tracks = p.tracks.map((t) => (t.id === tp.id ? { ...t, patternId: 'h.banklead', plan: 77 } : t.id === ts.id ? { ...t, patternId: 'h.bankanswer', plan: 77 } : t));
    const arr = generate(p);
    const plan = makePlan(77, arr.bars, 'soul');
    const barsOf = (id: string) => new Set(arr.parts[id].phrases!.map((u) => u.bar));
    const lead = barsOf(tp.id);
    const ans = barsOf(ts.id);
    expect(lead.size).toBeGreaterThan(3);
    expect(ans.size).toBeGreaterThan(1);
    for (let b = 0; b < arr.bars; b++) {
      if (plan.slots[b] === 'T') continue; // tutti bars are shared on purpose
      expect(lead.has(b) && ans.has(b), `bar ${b} slot ${plan.slots[b]}`).toBe(false);
    }
    // in a tutti bar both play the same phrase
    const t = plan.slots.findIndex((s) => s === 'T');
    if (t >= 0) {
      const a = arr.parts[tp.id].phrases!.find((u) => u.bar === t);
      const c = arr.parts[ts.id].phrases!.find((u) => u.bar === t);
      expect(a?.id).toBe(c?.id);
    }
  });
  it('swapping a phrase changes that bar and leaves the others alone', () => {
    const p = defaultProject();
    for (const [inst, recipe] of [['bass', 'b.bank'], ['guitar', 'g.banklead'], ['keys', 'k.bank'], ['tenor', 'h.banklead'], ['guitar', 'g.bank']] as const) {
      const t = p.tracks.find((x) => x.inst === inst)!;
      const q = { ...p, tracks: p.tracks.map((x) => (x.id === t.id ? { ...x, patternId: recipe } : x)) };
      const a = generate(q).parts[t.id];
      expect(a.phrases?.length, recipe).toBeGreaterThan(2);
      const bar = a.phrases![1].bar;
      const b = generate(swapPhrase(q, t.id, bar)).parts[t.id];
      const name = (part: typeof a, n: number) => part.phrases!.find((u) => u.bar === n)?.id;
      expect(name(b, bar), recipe).not.toBe(name(a, bar));
      for (const u of a.phrases!) if (u.bar !== bar) expect(name(b, u.bar), recipe + ' bar ' + u.bar).toBe(u.id);
    }
  });
});

describe('instrument types', () => {
  const play = (inst: string, variant: string, recipe: string, style = 'soul') => {
    const expression = 1;
    const p = defaultProject();
    p.repeats = 6;
    p.style = style;
    const t = p.tracks.find((x) => x.inst === inst)!;
    p.tracks = [{ ...t, variant, patternId: recipe, params: { ...t.params, expression, complexity: 0.7 } }];
    return generate(p).parts[t.id];
  };
  const arts = (part: ReturnType<typeof play>) => new Set(part.notes.map((n) => n.art).filter(Boolean));
  it('give each type its own articulations', () => {
    expect(arts(play('trumpet', 'leadtp', 'h.long')).has('shake')).toBe(true);
    expect(arts(play('trumpet', 'flugel', 'h.long')).has('shake')).toBe(false);
    expect(arts(play('trumpet', 'muted', 'h.lead')).has('shake')).toBe(false);
    expect(arts(play('trumpet', 'muted', 'h.lead')).has('fall')).toBe(false);
    expect(arts(play('trombone', 'trombone', 'h.lead')).has('gliss')).toBe(true);
    expect(arts(play('tenor', 'tenorhonk', 'h.blues')).has('growl')).toBe(true);
    expect(arts(play('tenor', 'tenorbreathy', 'h.long')).has('subtone')).toBe(true);
    expect(arts(play('tenor', 'tenorbreathy', 'h.blues')).has('growl')).toBe(false);
    expect(arts(play('bass', 'fretless', 'b.soul')).has('gliss')).toBe(true);
    expect(arts(play('bass', 'slap', 'b.slap', 'funk')).has('pop')).toBe(true);
    expect(arts(play('bass', 'synth', 'b.funk16', 'funk')).has('ghost')).toBe(false);
    expect(arts(play('guitar', 'lead', 'g.banklead')).has('bend')).toBe(true);
    expect(arts(play('guitar', 'slideguitar', 'g.banklead')).has('gliss')).toBe(true);
  });
  it('twelve-string doubles the low courses an octave up', () => {
    const six = play('guitar', 'steel', 'g.strum8').notes.length;
    const twelve = play('guitar', 'twelve', 'g.strum8').notes.length;
    expect(twelve).toBeGreaterThan(six * 1.4);
  });
  it('range shifts move the part', () => {
    const mean = (part: ReturnType<typeof play>) => part.notes.reduce((a, n) => a + n.p, 0) / part.notes.length;
    expect(mean(play('trumpet', 'flugel', 'h.lead'))).toBeLessThan(mean(play('trumpet', 'leadtp', 'h.lead')) - 3);
    expect(Math.min(...play('bass', 'fivestring', 'b.pump8').notes.map((n) => n.p))).toBeLessThan(28);
  });
});

describe('genres and presets', () => {
  it('every genre deals a valid band', () => {
    for (const g of STYLES) {
      const p = defaultProject();
      p.style = g.id;
      p.tempo = g.tempo;
      p.chart = 'Am7 D9 | Gmaj7 | F#m7b5 B7 | Em';
      p.tracks = INSTRUMENTS.map((i) => makeTrack(i.id, g.id, [], new RNG(9)));
      const q = smartRandomize(p, 31);
      const arr = generate(q);
      for (const t of q.tracks) {
        expect(getPattern(t.patternId), g.id).toBeTruthy();
        expect(arr.parts[t.id].notes.length, `${g.id} ${t.inst} ${t.patternId}`).toBeGreaterThan(0);
      }
    }
    let live = 0;
    for (let s = 1; s <= 40; s++) {
      const p = smartRandomize({ ...defaultProject(), style: 'funk' }, s);
      if (getPattern(p.tracks[0].patternId)?.tag) live++;
    }
    expect(live).toBeGreaterThan(20);
  });
  it('every preset builds the band it describes', () => {
    expect(BAND_PRESETS.length).toBeGreaterThanOrEqual(25);
    for (const preset of BAND_PRESETS) {
      const p = applyBandPreset(defaultProject(), preset, 5);
      expect(p.tracks.length, preset.id).toBe(preset.players.length);
      preset.players.forEach((pl, i) => {
        expect(p.tracks[i].inst).toBe(pl.inst);
        if (pl.recipe) expect(p.tracks[i].patternId, `${preset.id} ${pl.recipe}`).toBe(pl.recipe);
        if (pl.variant) expect(p.tracks[i].variant, `${preset.id} ${pl.variant}`).toBe(pl.variant);
      });
      if (preset.genre) expect(p.style).toBe(preset.genre);
      const pitched = p.tracks.filter((t) => t.midi.channel !== 10).map((t) => t.midi.channel);
      expect(new Set(pitched).size, preset.id + ' channels').toBe(pitched.length);
      const arr = generate(p);
      expect(arr.errors).toEqual([]);
      for (const t of p.tracks) expect(arr.parts[t.id].notes.length, `${preset.id} ${t.inst}`).toBeGreaterThan(0);
      // exports cleanly
      expect(parseSMF(exportMidi(p, arr)).nTracks).toBe(p.tracks.length + 1);
    }
  }, 60000);
  it('a saved band comes back as it was', () => {
    const p = smartRandomize(defaultProject(), 3);
    const preset = presetFromProject(p, 'Mine');
    const q = applyBandPreset({ ...defaultProject(), style: 'punk' }, preset, 8);
    expect(q.style).toBe(p.style);
    expect(q.tracks.map((t) => [t.inst, t.variant, t.patternId])).toEqual(p.tracks.map((t) => [t.inst, t.variant, t.patternId]));
  });
});
