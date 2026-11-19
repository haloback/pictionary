// Keyboard recipes: voice-led right-hand chords, left-hand bass figures, rolled
// chords, sustain pedalling, organ swells.

import { BEAT, S16 } from './types';
import type { Chord, Part, StyleId } from './types';
import { PB, chordAt, isPhraseEnd, nextChange, steps } from './perf';
import type { GenCtx } from './perf';
import { clamp, mod12, pitchAtOrAbove, roleInterval, scalePcsFor, scaleStep } from './theory';
import { chordVoicing } from './voicing';
import type { PatternDef } from './patterns';
import { bankComp, keysTokens, rfamOf } from './phrasebank';

interface KeysDef {
  rh: string[];
  lh?: string[];
  fills?: string[];
  rich: 0 | 1 | 2;
  antic?: boolean;
  pedal?: boolean;
  /** roll chords from the bottom over this many ms */
  roll?: number;
  lay?: number;
  center?: number;
  vel?: number;
  /** sustained organ: expression swells instead of velocity */
  organ?: boolean;
  /** gate for held chords */
  gate?: number;
  /** supply each bar's templates directly (phrase bank) */
  tpl?: (bar: number) => { rh: string; lh: string };
}

/*
  Right hand:  C chord (accent)  c chord  S stab (accent)  s stab  t top note
               o top note in octaves  a next arpeggio note up  d arpeggio note down
               g ghosted low notes  - hold  . release
  Left hand:   R root  r soft root  O octaves  5 fifth  8 octave up  3 tenth  7 seventh
               a approach to next root  n next root  - hold  . release
*/

function runKeys(ctx: GenCtx, def: KeysDef): Part {
  const b = new PB(ctx);
  const rng = ctx.rng.fork('keys');
  const cx = ctx.params.complexity;
  const ex = ctx.params.expression;
  const total = ctx.bars * 16;
  const oct = ctx.params.octave * 12;
  const rh: string[] = [];
  const lh: string[] = [];
  for (let bar = 0; bar < ctx.bars; bar++) {
    const r = rng.fork('bar' + bar);
    if (def.tpl) {
      const got = def.tpl(bar);
      rh.push(...steps(got.rh));
      lh.push(...steps(got.lh));
      continue;
    }
    let idx = bar % def.rh.length;
    if (def.rh.length > 1 && r.chance(cx * 0.3)) idx = r.int(0, def.rh.length - 1);
    let tpl = def.rh[idx];
    if (def.fills && isPhraseEnd(ctx, bar) && r.chance(0.35 + cx * 0.4)) tpl = r.pick(def.fills);
    rh.push(...steps(tpl));
    lh.push(...steps(def.lh ? def.lh[idx % def.lh.length] : ''));
  }
  const isAtk = (c: string) => c !== '-' && c !== '.';
  const anticR = new Set<number>();
  const anticL = new Set<number>();
  for (const sp of ctx.spans) {
    if (!sp.change || sp.t === 0) continue;
    const c = Math.round(sp.t / S16);
    if (c >= total) continue;
    for (const [row, antic, fallback] of [
      [rh, anticR, 'c'],
      [lh, anticL, 'R'],
    ] as [string[], Set<number>, string][]) {
      if (isAtk(row[c])) continue;
      let a = -1;
      if (def.antic) {
        if (isAtk(row[c - 1])) a = c - 1;
        else if (c >= 2 && isAtk(row[c - 2]) && row[c - 1] !== '.') a = c - 2;
      }
      if (a >= 0) antic.add(a);
      else if (row[c] === '-') row[c] = fallback;
    }
  }

  const center = (def.center ?? 64) + oct;
  let voicing: number[] | null = null;
  let voicingSym = '';
  let arp = 0;
  const lay = def.lay ?? 0;
  const vAdd = def.vel ?? 0;
  const pedalTimes: number[] = [];

  // ---- right hand
  for (let i = 0; i < total; i++) {
    const tk = rh[i];
    if (!isAtk(tk)) continue;
    const t = i * S16;
    const ch = (anticR.has(i) ? nextChange(ctx, t).span : chordAt(ctx, t)).chord;
    if (ch.nc) continue;
    if (ch.sym !== voicingSym) {
      voicing = chordVoicing(ch, ctx.key, def.rich, voicing, center, 48 + oct, 82 + oct);
      voicingSym = ch.sym;
      arp = 0;
      pedalTimes.push(b.w(t) + b.ms(lay));
    }
    const vo = voicing!;
    if (!vo.length) continue;
    let holds = 0;
    while (i + 1 + holds < total && rh[i + 1 + holds] === '-') holds++;
    const len = (1 + holds) * S16;
    const step = i % 16;
    const metric = step === 0 ? 6 : step % 4 === 0 ? 3 : step % 2 === 0 ? 0 : -4;
    const baseOff = b.ms(lay) + b.jit(5);
    const gate = def.gate ?? (def.pedal ? 0.98 : 0.92);
    const top = vo.length - 1;

    const chord = (vel: number, dur: number, short: boolean) => {
      const roll = def.roll && !short ? b.ms(def.roll * rng.range(0.6, 1.3)) : 0;
      vo.forEach((p, k) => {
        const v = vel + (k === top ? 6 : k === 0 ? -1 : -6) + vAdd + metric;
        const off = baseOff + (roll ? (k / Math.max(1, top)) * roll - roll * 0.3 : b.jit(2.5));
        b.note(t, dur, p, def.organ ? 92 + vAdd : v, { off, art: short ? 'staccato' : undefined });
      });
      // crushed grace note into the top voice
      if (!short && !def.organ && rng.chance(ex * cx * 0.28)) {
        const g = scaleStep(vo[top], scalePcsFor(ch, ctx.key), -1);
        b.note(t, b.ms(45), g, vel - 10 + vAdd, { abs: true, off: baseOff - b.ms(34) });
      }
    };

    switch (tk) {
      case 'C':
        chord(92, len * gate, false);
        break;
      case 'c':
        chord(76, len * gate, false);
        break;
      case 'S':
        chord(98, Math.min(len, S16 * 2) * 0.55, true);
        break;
      case 's':
        chord(78, Math.min(len, S16 * 2) * 0.5, true);
        break;
      case 't':
        b.note(t, len * gate, vo[top], 80 + vAdd + metric, { off: baseOff });
        break;
      case 'o':
        b.note(t, len * gate, vo[top], 90 + vAdd + metric, { off: baseOff });
        b.note(t, len * gate, vo[top] - 12, 82 + vAdd + metric, { off: baseOff + b.jit(2) });
        break;
      case 'a':
      case 'd': {
        if (tk === 'a') arp = (arp + 1) % (vo.length + 1);
        else arp = (arp - 1 + vo.length + 1) % (vo.length + 1);
        const p = arp === vo.length ? vo[0] + 12 : vo[arp];
        b.note(t, def.pedal ? len + BEAT : len * gate, p, 72 + vAdd + metric, { off: baseOff });
        break;
      }
      case 'g':
        vo.slice(0, 2).forEach((p) => b.note(t, b.ms(50), p, rng.range(36, 48), { abs: true, off: baseOff, art: 'ghost' }));
        break;
    }
  }

  // ---- left hand
  const lhBase = 36 + oct;
  let prevRoot = lhBase + 5;
  const rootOf = (ch: Chord): number => {
    let p = pitchAtOrAbove(ch.bass, lhBase);
    if (p - prevRoot > 7 && p - 12 >= lhBase - 5) p -= 12;
    return p;
  };
  for (let i = 0; i < total; i++) {
    const tk = lh[i];
    if (!isAtk(tk)) continue;
    const t = i * S16;
    const ch = (anticL.has(i) ? nextChange(ctx, t).span : chordAt(ctx, t)).chord;
    if (ch.nc) continue;
    let holds = 0;
    while (i + 1 + holds < total && lh[i + 1 + holds] === '-') holds++;
    const len = (1 + holds) * S16;
    const root = rootOf(ch);
    const off = b.ms(lay) + b.jit(5);
    const step = i % 16;
    let v = (step === 0 ? 90 : step % 4 === 0 ? 82 : 74) + vAdd;
    const gate = def.pedal ? 0.98 : 0.9;
    const above = (iv: number) => root + mod12(ch.root + iv - root) + (mod12(ch.root + iv - root) === 0 ? 12 : 0);
    let ps: number[] = [root];
    switch (tk) {
      case 'R':
        prevRoot = root;
        break;
      case 'r':
        v -= 14;
        prevRoot = root;
        break;
      case 'O':
        ps = [root - 12 >= 24 ? root - 12 : root, root - 12 >= 24 ? root : root + 12];
        prevRoot = root;
        break;
      case '5':
        ps = [above(roleInterval(ch, '5'))];
        v -= 6;
        break;
      case '8':
        ps = [root + 12];
        v -= 6;
        break;
      case '3':
        ps = [above(roleInterval(ch, '3')) + 12];
        v -= 8;
        break;
      case '7':
        ps = [above(roleInterval(ch, '7'))];
        v -= 6;
        break;
      case '6':
        ps = [above(roleInterval(ch, '6'))];
        v -= 6;
        break;
      case 'n':
      case 'a': {
        const next = nextChange(ctx, t).span.chord;
        const tp = pitchAtOrAbove(next.nc ? ch.bass : next.bass, lhBase);
        ps = [tk === 'n' ? tp : rng.pick([tp - 1, tp + 1, scaleStep(tp, scalePcsFor(next.nc ? ch : next, ctx.key), -1)])];
        v -= 8;
        break;
      }
    }
    ps.forEach((p, k) => b.note(t, len * gate, clamp(p, 21, 72), def.organ ? 88 : v - k * 3, { off: off + (k ? b.jit(2) : 0) }));
  }

  // ---- sustain pedal: lift on the change, catch just after
  if (def.pedal && pedalTimes.length) {
    pedalTimes.forEach((pt, k) => {
      if (k > 0) b.cAbs('ped', pt + b.ms(12), 0);
      b.cAbs('ped', pt + b.ms(85), 1);
    });
    b.cAbs('ped', ctx.len - 12, 0);
  }
  // ---- organ swell pedal
  if (def.organ) {
    const srng = rng.fork('swell');
    for (let bar = 0; bar < ctx.bars; bar++) {
      const t0 = b.w(bar * 1920);
      const lowV = 0.5 + ctx.energy * 0.15;
      const hiV = clamp(lowV + 0.2 + ex * 0.25 * srng.range(0.6, 1.2), 0, 1);
      if (bar % 2 === 0) b.rampAbs('dyn', t0, t0 + 1900, lowV, hiV, 1.4, 80);
      else b.rampAbs('dyn', t0, t0 + 1900, hiV, lowV, 0.8, 80);
    }
  }
  return b.part();
}

/** Comping dealt from the phrase bank, interlocking with the guitar on the band's accents. */
function bankKeys(ctx: GenCtx): Part {
  const fam = rfamOf(ctx.style);
  const got = bankComp(ctx, 'keys');
  const part = runKeys(ctx, {
    rich: fam === 'swing' || fam === 'latin' ? 2 : 1,
    antic: true,
    pedal: fam === 'slow',
    roll: fam === 'slow' ? 24 : 0,
    rh: [],
    tpl: (bar) => {
      const t = keysTokens(got.rhythms[bar], got.shapes[bar]);
      return fam === 'swing' ? { rh: t.rh, lh: '' } : t;
    },
  });
  part.phrases = got.uses;
  return part;
}

interface KeysRecipe {
  id: string;
  name: string;
  styles: StyleId[] | '*';
  density: 1 | 2 | 3;
  role: 'rhythm' | 'pad';
  desc: string;
  variant?: string;
  def?: KeysDef;
  gen?: (ctx: GenCtx) => Part;
}

const RECIPES: KeysRecipe[] = [
  {
    id: 'k.bank',
    name: 'Phrase bank: Comping',
    styles: ['funk', 'soul', 'pop', 'rock', 'neosoul', 'afrobeat', 'reggae', 'bossa', 'jazz', 'blues', 'ballad'],
    density: 2,
    role: 'rhythm',
    desc: 'Chord figures dealt from the phrase bank. Trades the band accents with the guitar bar by bar so the two interlock.',
    gen: bankKeys,
  },
  {
    id: 'k.pop8',
    name: 'Pop Eighths',
    styles: ['pop', 'rock', 'soul'],
    density: 2,
    role: 'rhythm',
    variant: 'grand',
    desc: 'Pulsing right-hand chords over left-hand octaves.',
    def: {
      rich: 0,
      pedal: true,
      rh: ['C-c-|c-c-|C-c-|c-c-', 'C-c-|c-c-|C-c-|c-t-', 'C--c|-.c-|C-c-|-c-.'],
      lh: ['O---|----|O---|--5-', 'O---|----|O---|----', 'O---|--R-|----|R---'],
      fills: ['C-c-|c-c-|C-C-|o-o-'],
    },
  },
  {
    id: 'k.ballad',
    name: 'Ballad Arpeggios',
    styles: ['ballad', 'pop', 'soul', 'neosoul'],
    density: 2,
    role: 'rhythm',
    variant: 'grand',
    desc: 'Rolling left-hand tenths under held chords, full sustain pedal.',
    def: {
      rich: 1,
      pedal: true,
      lay: 4,
      roll: 22,
      rh: ['C---|----|c---|--t-', 'C---|----|----|c---', 'C---|--t-|c---|----'],
      lh: ['R-5-|8-3-|8-5-|8---', 'R-5-|8-5-|3-8-|5---', 'R-5-|8---|R-5-|3---'],
    },
  },
  {
    id: 'k.pad',
    name: 'Held Chords',
    styles: '*',
    density: 1,
    role: 'pad',
    variant: 'rhodes',
    desc: 'One voice-led chord per change, gently rolled.',
    def: {
      rich: 1,
      roll: 28,
      lay: 5,
      vel: -6,
      rh: ['C---|----|----|----', 'C---|----|----|--c-', 'C---|----|--c-|----'],
      lh: ['R---|----|----|----'],
    },
  },
  {
    id: 'k.jazzcomp',
    name: 'Rootless Comping',
    styles: ['jazz', 'blues', 'bossa'],
    density: 2,
    role: 'rhythm',
    variant: 'grand',
    desc: 'Rootless left-hand voicings in conversational, anticipated rhythms.',
    def: {
      rich: 2,
      antic: true,
      center: 60,
      vel: -6,
      rh: ['S...|..s.|....|....', '....|..S.|....|..s.', 'S...|....|..s.|....', '..s.|....|S...|..s.', '....|S...|....|..S.', '..S.|....|..s.|....', '....|....|S...|..s.'],
    },
  },
  {
    id: 'k.clav',
    name: 'Clav Sixteenths',
    styles: ['funk', 'afrobeat'],
    density: 3,
    role: 'rhythm',
    variant: 'clav',
    desc: 'Percussive two-handed stabs with ghosted notes between.',
    def: {
      rich: 1,
      antic: true,
      center: 60,
      rh: ['s.sg|.s.s|g.s.|sg.s', 'S.gs|..sg|.s.S|g.s.', 's.s.|gs.s|.gs.|S.gs'],
      lh: ['R..R|....|R...|..R.', 'R...|.R..|..R.|R...', 'R..R|...R|....|R...'],
    },
  },
  {
    id: 'k.soul',
    name: 'Soul Stabs',
    styles: ['soul', 'funk', 'neosoul', 'pop', 'reggae', 'afrobeat'],
    density: 2,
    role: 'rhythm',
    variant: 'wurli',
    desc: 'Syncopated chord pushes with crushed grace notes.',
    def: {
      rich: 1,
      antic: true,
      rh: ['C--c|-.c-|C---|-.cc', 'c-.C|--.c|-.c-|C---', 'C---|-.c-|-c-.|C-c-'],
      lh: ['R---|--R-|R---|--5-', 'R---|----|R-.R|----', 'R---|--R-|----|R-n-'],
    },
  },
  {
    id: 'k.neosoul',
    name: 'Lush Rhodes',
    styles: ['neosoul', 'soul', 'ballad', 'jazz'],
    density: 1,
    role: 'pad',
    variant: 'rhodes',
    desc: 'Wide extended voicings, rolled and placed late.',
    def: {
      rich: 2,
      roll: 40,
      lay: 14,
      antic: true,
      center: 65,
      rh: ['C---|---c|-...|..c-', 'C---|----|-.c-|----', 'c---|--C-|----|..t-', 'C---|-..c|----|--..'],
      lh: ['R---|----|..R-|....', 'R---|----|----|--n-', 'R---|--7-|----|....'],
    },
  },
  {
    id: 'k.organpad',
    name: 'Organ Swells',
    styles: ['soul', 'rock', 'blues', 'reggae', 'ballad', 'funk', 'pop', 'afrobeat'],
    density: 1,
    role: 'pad',
    variant: 'organ',
    desc: 'Sustained drawbar chords that breathe with the expression pedal.',
    def: { rich: 1, organ: true, gate: 0.99, center: 62, rh: ['C---|----|----|----'], lh: ['R---|----|----|----'] },
  },
  {
    id: 'k.bubble',
    name: 'Organ Bubble',
    styles: ['reggae'],
    density: 3,
    role: 'rhythm',
    variant: 'organ',
    desc: 'The reggae shuffle: soft-loud-soft sixteenths around every off-beat.',
    def: { rich: 0, center: 62, vel: -6, rh: ['.sSs|.sSs|.sSs|.sSs'], lh: ['..r.|..r.|..r.|..r.'] },
  },
  {
    id: 'k.skank',
    name: 'Piano Skank',
    styles: ['reggae', 'afrobeat'],
    density: 2,
    role: 'rhythm',
    variant: 'grand',
    desc: 'Bright off-beat chords locked with the guitar.',
    def: { rich: 0, center: 67, rh: ['..S.|..S.|..S.|..S.', '..S.|..S.|..S.|..Ss'] },
  },
  {
    id: 'k.montuno',
    name: 'Montuno',
    styles: ['bossa', 'afrobeat', 'funk'],
    density: 3,
    role: 'rhythm',
    variant: 'grand',
    desc: 'Octaves answered by inner chord tones in the two-bar Latin figure.',
    def: {
      rich: 0,
      antic: true,
      center: 67,
      rh: ['o.s.|o.s.|..o.|s.o.', '..s.|o.s.|..o.|s.o.'],
    },
  },
  {
    id: 'k.bossa',
    name: 'Bossa Comp',
    styles: ['bossa', 'jazz'],
    density: 2,
    role: 'rhythm',
    variant: 'rhodes',
    desc: 'Soft rootless chords on the bossa clave.',
    def: {
      rich: 2,
      antic: true,
      center: 62,
      vel: -8,
      rh: ['c-..|..c-|....|c-..', '..c-|..c-|....|c-c.'],
    },
  },
  {
    id: 'k.rock8',
    name: 'Hammered Eighths',
    styles: ['rock', 'pop', 'blues'],
    density: 3,
    role: 'rhythm',
    variant: 'grand',
    desc: 'Straight driving chords, both hands.',
    def: {
      rich: 0,
      rh: ['C-c-|C-c-|C-c-|C-c-', 'C-c-|C-c-|C-c-|C-C-'],
      lh: ['O---|----|O---|----', 'O---|--R-|O---|----'],
      fills: ['C-c-|C-c-|C-C-|o-o-'],
    },
  },
  {
    id: 'k.boogie',
    name: 'Boogie Left Hand',
    styles: ['blues', 'jazz', 'rock'],
    density: 3,
    role: 'rhythm',
    variant: 'grand',
    desc: 'Walking left-hand figure with right-hand chord jabs.',
    def: {
      rich: 1,
      rh: ['..s.|..S.|..s.|..S.', 'S...|..s.|..S.|....', '..s.|S...|..s.|S.s.'],
      lh: ['R-R-|5-5-|6-6-|5-5-', 'R-R-|3-3-|5-5-|6-5-', 'R-8-|5-8-|6-8-|5-8-'],
    },
  },
  {
    id: 'k.arp16',
    name: 'Broken Chords',
    styles: ['ballad', 'pop', 'neosoul', 'bossa'],
    density: 3,
    role: 'rhythm',
    variant: 'rhodes',
    desc: 'Flowing right-hand arpeggios up and down the voicing.',
    def: {
      rich: 1,
      pedal: true,
      vel: -4,
      rh: ['a-a-|a-a-|d-d-|d-a-', 'a-a-|a-d-|a-a-|d-d-'],
      lh: ['R---|----|----|----', 'R---|----|5---|----'],
    },
  },
];

export const KEYS_PATTERNS: PatternDef[] = RECIPES.map((r) => ({
  id: r.id,
  name: r.name,
  family: 'keys',
  styles: r.styles,
  density: r.density,
  role: r.role,
  desc: r.desc,
  variant: r.variant,
  bank: r.id === 'k.bank',
  gen: r.gen ?? ((ctx) => runKeys(ctx, r.def!)),
}));
