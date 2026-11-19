// Drum kit and percussion recipes. Patterns are step grids; the generator adds
// ghost notes, hand-to-hand velocity shapes, fills, crashes and micro-timing.

import { BAR, S16 } from './types';
import type { Part, StyleId } from './types';
import { PB, isPhraseEnd, steps } from './perf';
import type { GenCtx, Groove } from './perf';
import type { PatternDef } from './patterns';

/** General MIDI percussion map */
export const GM = {
  k: 36, // kick
  s: 38, // snare
  r: 37, // side stick
  clap: 39,
  h: 42, // closed hat
  p: 44, // pedal hat
  o: 46, // open hat
  R: 51, // ride
  bell: 53,
  c: 49, // crash
  t1: 50,
  t2: 47,
  t3: 43,
  tamb: 54,
  cow: 56,
  shk: 70,
  cab: 69,
  cm: 62, // conga mute/slap
  co: 63, // conga open
  cl: 64, // low conga
  clave: 75,
  agh: 67,
  agl: 68,
  bh: 60, // bongo hi
  bl: 61,
} as const;
type Voice = keyof typeof GM;
type Row = Partial<Record<Voice, string>>;

interface DrumDef {
  bars: Row[];
  /** phrase-end fills */
  fills?: boolean;
  /** probability scale of added snare ghost notes */
  ghost?: number;
  /** probability of opening the hat on the last eighth */
  openHat?: number;
  /** jazz-style random snare/kick comping */
  comp?: boolean;
  /** fill on eighths (swing) instead of sixteenths */
  fill8?: boolean;
  /** how far behind the beat the backbeat sits, in ms */
  laySnare?: number;
  crash?: boolean;
}

const HAND16 = [1, 0.52, 0.76, 0.5];

function runDrums(ctx: GenCtx, def: DrumDef): { part: Part; groove: Groove } {
  const b = new PB(ctx);
  const rng = ctx.rng.fork('drums');
  const groove: Groove = { kicks: [], snares: [] };
  const cx = ctx.params.complexity;
  const en = ctx.energy;
  const lay = def.laySnare ?? 0;

  const hit = (voice: Voice, t: number, v: number, jitMs = 3, offMs = 0) => {
    b.note(t, 60, GM[voice], v, { off: b.jit(jitMs) + b.ms(offMs), abs: true });
  };

  for (let bar = 0; bar < ctx.bars; bar++) {
    const t0 = bar * BAR;
    const row = def.bars[bar % def.bars.length];
    const phraseEnd = isPhraseEnd(ctx, bar);
    // decide the fill
    let fillFrom = 16;
    if (def.fills && phraseEnd && ctx.bars > 1) {
      const big = (bar + 1) % (ctx.phrase * 2) === 0 || bar === ctx.bars - 1;
      const r = rng.f();
      const lean = cx * 0.5 + en * 0.3 + (big ? 0.25 : 0);
      if (r < 0.12 - lean * 0.1) fillFrom = 16;
      else if (r < 0.55 - lean * 0.2) fillFrom = 12;
      else if (r < 0.9 - lean * 0.15) fillFrom = 8;
      else fillFrom = big ? 0 : 8;
      if (def.fill8 && fillFrom < 8) fillFrom = 8;
    }

    const voices = Object.keys(row) as Voice[];
    for (const voice of voices) {
      const st = steps(row[voice]!);
      const hatLike = voice === 'h' || voice === 'R' || voice === 'shk' || voice === 'cab';
      const every16 = hatLike && st.filter((c) => c !== '.').length > 9;
      for (let i = 0; i < 16; i++) {
        let ch = st[i];
        if (ch === '.') continue;
        const inFill = i >= fillFrom;
        const t = t0 + i * S16;
        if (voice === 'k') {
          if (inFill && i % 4 !== 0 && rng.chance(0.6)) continue;
          // occasionally drop a syncopated kick for breathing room
          if (i % 4 !== 0 && rng.chance(0.06 + (1 - cx) * 0.08)) continue;
          const v = ch === 'X' ? 116 : ch === 'm' ? 42 : i === 0 ? 108 : i % 4 === 0 ? 100 : 90;
          hit('k', t, v, 2.2);
          if (ch !== 'm') groove.kicks.push(t);
        } else if (voice === 's' || voice === 'r') {
          if (inFill) continue;
          if (ch === 'g') {
            hit(voice, t, rng.range(22, 36), 3.5, lay * 0.4);
          } else {
            hit(voice, t, ch === 'X' ? 112 : 98, 2.5, lay);
            groove.snares.push(t);
          }
        } else if (hatLike) {
          if (inFill && voice !== 'shk' && voice !== 'cab') continue;
          let v: number;
          if (ch === 'X') v = 104;
          else if (ch === 'm') v = 58;
          else if (every16) v = 92 * HAND16[i % 4];
          else if (voice === 'R') v = i % 8 === 4 ? 96 : i % 4 === 0 ? 84 : 66;
          else v = i % 4 === 0 ? 92 : i % 2 === 0 ? 64 : 54;
          let vv: Voice = voice;
          if (voice === 'h' && (ch === 'o' || (i === 14 && def.openHat && rng.chance(def.openHat * (0.5 + cx))))) {
            vv = 'o';
            v = Math.max(v, 86);
          }
          hit(vv, t, v + en * 8, 3.5, voice === 'h' ? -1.5 : 0);
        } else {
          if (inFill && (voice === 'o' || voice === 'p' || voice === 'bell')) continue;
          const v = ch === 'X' ? 108 : ch === 'g' ? rng.range(28, 44) : ch === 'm' ? 62 : 88;
          hit(voice, t, v, 3.5);
        }
      }
    }

    // added snare ghost notes on the weak sixteenths
    if (def.ghost && row.s) {
      const st = steps(row.s);
      for (let i = 1; i < Math.min(16, fillFrom); i += 1) {
        if (st[i] !== '.' || i % 4 === 0) continue;
        const nearBack = st[(i + 1) % 16] !== '.' || st[(i + 15) % 16] !== '.';
        const p = def.ghost * cx * (nearBack ? 0.5 : 0.22) * (i % 2 === 1 ? 1 : 0.5);
        if (rng.chance(p)) hit('s', t0 + i * S16, rng.range(20, 34), 4, lay * 0.4);
      }
    }
    // occasional extra kick pushing into the next beat
    if (row.k && !def.comp && rng.chance(cx * 0.22)) {
      const i = rng.pick([7, 10, 15]);
      if (i < fillFrom && steps(row.k)[i] === '.') {
        hit('k', t0 + i * S16, 82, 2.5);
        groove.kicks.push(t0 + i * S16);
      }
    }
    // jazz comping: soft snare chatter and the odd kick "bomb"
    if (def.comp) {
      for (let i = 2; i < Math.min(16, fillFrom); i += 2) {
        if (rng.chance(0.1 + cx * 0.22)) hit('s', t0 + i * S16, i % 4 === 2 ? rng.range(40, 66) : rng.range(26, 44), 4);
      }
      if (rng.chance(0.12 + cx * 0.2)) hit('k', t0 + rng.pick([6, 14, 10]) * S16, rng.range(70, 92), 3);
    }

    // the fill itself
    if (fillFrom < 16) {
      const stepSize = def.fill8 ? 2 : 1;
      const n = (16 - fillFrom) / stepSize;
      const order: Voice[] = n > 4 ? ['s', 's', 't1', 't1', 't2', 't3'] : rng.chance(0.5) ? ['s', 's', 't1', 't3'] : ['s', 's', 's', 's'];
      const dens = 0.62 + cx * 0.3 + en * 0.1;
      let any = false;
      for (let j = 0; j < n; j++) {
        const i = fillFrom + j * stepSize;
        const last = j === n - 1;
        if (!last && j > 0 && !rng.chance(dens)) continue;
        const x = n > 1 ? j / (n - 1) : 1;
        const voice = order[Math.min(order.length - 1, Math.floor(x * order.length * 0.999))];
        const v = 72 + x * 38 + (i % 4 === 0 ? 6 : 0);
        hit(voice, t0 + i * S16, v, 3);
        // a quick drag before the last accent
        if (last && rng.chance(0.25 + cx * 0.3)) b.note(t0 + i * S16, 30, GM.s, 38, { off: -b.ms(32), abs: true });
        any = true;
      }
      if (any && def.crash !== false && bar + 1 < ctx.bars) {
        hit('c', (bar + 1) * BAR, 104 + en * 12, 2);
        if (!groove.kicks.includes((bar + 1) * BAR)) hit('k', (bar + 1) * BAR, 104, 2);
      }
    }
  }
  if (def.crash !== false && def.fills && ctx.bars >= 4) b.note(0, 60, GM.c, 100, { abs: true });
  return { part: b.part(), groove };
}

interface DrumRecipe {
  id: string;
  name: string;
  styles: StyleId[] | '*';
  density: 1 | 2 | 3;
  desc: string;
  def: DrumDef;
}

const H8 = 'x.x.|x.x.|x.x.|x.x.';
const H16 = 'xxxx|xxxx|xxxx|xxxx';
const BACK = '....|X...|....|X...';

const KITS: DrumRecipe[] = [
  {
    id: 'd.straight8',
    name: 'Straight Eight',
    styles: ['pop', 'rock', 'soul', 'ballad', 'blues'],
    density: 2,
    desc: 'Kick on 1 and 3, backbeat snare, eighth-note hats.',
    def: {
      fills: true,
      ghost: 0.5,
      openHat: 0.25,
      bars: [
        { k: 'x...|....|x.x.|....', s: BACK, h: H8 },
        { k: 'x...|...x|x.x.|....', s: BACK, h: H8 },
      ],
    },
  },
  {
    id: 'd.drive',
    name: 'Driving Rock',
    styles: ['rock', 'pop'],
    density: 3,
    desc: 'Pushed kick on the off-beats with hard accents.',
    def: {
      fills: true,
      ghost: 0.3,
      openHat: 0.4,
      bars: [
        { k: 'x...|..x.|x...|..x.', s: BACK, h: 'X.x.|X.x.|X.x.|X.x.' },
        { k: 'x...|..x.|x.x.|..x.', s: BACK, h: 'X.x.|X.x.|X.x.|X.x.' },
      ],
    },
  },
  {
    id: 'd.pocket16',
    name: 'Pocket Sixteenths',
    styles: ['funk', 'neosoul', 'afrobeat'],
    density: 3,
    desc: 'Two-handed sixteenth hats with ghosted snare and a syncopated kick.',
    def: {
      fills: true,
      ghost: 1,
      openHat: 0.5,
      bars: [
        { k: 'x..x|..x.|..x.|.x..', s: '....|X..g|.g..|X..g', h: H16 },
        { k: 'x..x|....|.xx.|...x', s: '....|X..g|.g..|X.g.', h: H16 },
      ],
    },
  },
  {
    id: 'd.syncfunk',
    name: 'Syncopated Funk',
    styles: ['funk', 'soul', 'afrobeat'],
    density: 2,
    desc: 'Eighth hats, displaced kicks, snare ghosts around the backbeat.',
    def: {
      fills: true,
      ghost: 0.9,
      openHat: 0.45,
      bars: [
        { k: 'x...|...x|.x..|..x.', s: '....|X...|...g|X.g.', h: H8 },
        { k: 'x..x|....|.x.x|....', s: '....|X..g|....|X...', h: H8 },
      ],
    },
  },
  {
    id: 'd.motown',
    name: 'Four on the Snare',
    styles: ['soul', 'pop'],
    density: 2,
    desc: 'Snare on every beat with tambourine, classic soul drive.',
    def: {
      fills: true,
      ghost: 0.2,
      bars: [
        { k: 'x...|....|x.x.|....', s: 'x...|X...|x...|X...', h: H8, tamb: '....|x...|....|x...' },
        { k: 'x...|..x.|x.x.|....', s: 'x...|X...|x...|X...', h: H8, tamb: '....|x...|....|x.x.' },
      ],
    },
  },
  {
    id: 'd.disco',
    name: 'Four on the Floor',
    styles: ['funk', 'pop', 'soul', 'afrobeat'],
    density: 2,
    desc: 'Kick on every beat with open hats on the off-beats.',
    def: {
      fills: true,
      ghost: 0.3,
      bars: [{ k: 'x...|x...|x...|x...', s: BACK, h: 'x.o.|x.o.|x.o.|x.o.' }],
    },
  },
  {
    id: 'd.swing',
    name: 'Swing Ride',
    styles: ['jazz'],
    density: 2,
    desc: 'Spang-a-lang ride, hat on 2 and 4, feathered kick, snare comping.',
    def: {
      fills: true,
      fill8: true,
      comp: true,
      crash: false,
      bars: [{ R: 'x...|x.x.|x...|x.x.', p: '....|x...|....|x...', k: 'm...|m...|m...|m...' }],
    },
  },
  {
    id: 'd.shuffle',
    name: 'Shuffle',
    styles: ['blues', 'jazz'],
    density: 2,
    desc: 'Swung eighths on the hat with shuffled snare ghosts.',
    def: {
      fills: true,
      fill8: true,
      ghost: 0.4,
      bars: [
        { k: 'x...|....|x.x.|....', s: '..g.|X.g.|..g.|X.g.', h: H8 },
        { k: 'x...|..x.|x...|....', s: '..g.|X.g.|..g.|X.g.', h: H8 },
      ],
    },
  },
  {
    id: 'd.bossa',
    name: 'Bossa Nova',
    styles: ['bossa'],
    density: 2,
    desc: 'Cross-stick clave over a steady eighth-note hat and surdo-style kick.',
    def: {
      crash: false,
      bars: [
        { k: 'x.....x.|x.....x.', r: 'x.....x.|....x...', h: 'm.m.|m.m.|m.m.|m.m.', p: '....|x...|....|x...' },
        { k: 'x.....x.|x.....x.', r: '....x...|..x.....', h: 'm.m.|m.m.|m.m.|m.m.', p: '....|x...|....|x...' },
      ],
    },
  },
  {
    id: 'd.onedrop',
    name: 'One Drop',
    styles: ['reggae'],
    density: 1,
    desc: 'Kick and cross-stick together on beat 3; nothing on the one.',
    def: {
      fills: true,
      crash: false,
      bars: [
        { k: '....|....|x...|....', r: '....|....|X...|....', h: 'x.x.|X.x.|x.x.|X.xx' },
        { k: '....|....|x...|....', r: '....|....|X...|..g.', h: 'x.x.|X.xx|x.x.|X.x.' },
      ],
    },
  },
  {
    id: 'd.steppers',
    name: 'Steppers',
    styles: ['reggae', 'afrobeat'],
    density: 2,
    desc: 'Four-to-the-floor reggae with the stick on 3.',
    def: {
      fills: true,
      crash: false,
      bars: [{ k: 'x...|x...|x...|x...', r: '....|....|X...|....', h: 'x.x.|X.x.|x.x.|X.x.' }],
    },
  },
  {
    id: 'd.ballad',
    name: 'Ballad Cross-stick',
    styles: ['ballad', 'neosoul', 'soul', 'bossa'],
    density: 1,
    desc: 'Soft hats, side stick on 2 and 4, sparse kick.',
    def: {
      fills: true,
      bars: [
        { k: 'x...|....|..x.|....', r: '....|x...|....|x...', h: 'm.m.|m.m.|m.m.|m.m.' },
        { k: 'x...|....|x.x.|....', r: '....|x...|....|x...', h: 'm.m.|m.m.|m.m.|m.m.' },
      ],
    },
  },
  {
    id: 'd.halftime',
    name: 'Half-time',
    styles: ['rock', 'ballad', 'neosoul', 'pop', 'blues'],
    density: 1,
    desc: 'Snare on 3 for a wide, heavy feel.',
    def: {
      fills: true,
      ghost: 0.5,
      openHat: 0.2,
      bars: [
        { k: 'x...|...x|....|..x.', s: '....|....|X...|....', h: H8 },
        { k: 'x...|..x.|....|.x..', s: '....|....|X...|...g', h: H8 },
      ],
    },
  },
  {
    id: 'd.laidback',
    name: 'Laid-back Pocket',
    styles: ['neosoul', 'soul', 'funk'],
    density: 2,
    desc: 'Lazy backbeat that sits behind the click, broken hat pattern.',
    def: {
      fills: true,
      ghost: 0.8,
      laySnare: 14,
      openHat: 0.3,
      bars: [
        { k: 'x...|...x|..x.|....', s: '....|X...|....|X..g', h: 'x.xx|x.x.|x.xx|x.x.' },
        { k: 'x..x|....|..x.|.x..', s: '....|X..g|....|X...', h: 'x.x.|x.xx|x.x.|x.xx' },
      ],
    },
  },
  {
    id: 'd.afrobeat',
    name: 'Afrobeat Kit',
    styles: ['afrobeat', 'funk'],
    density: 3,
    desc: 'Rolling hats with a conversational kick and snare.',
    def: {
      fills: true,
      ghost: 0.9,
      openHat: 0.5,
      bars: [
        { k: 'x...|...x|..x.|....', s: '..g.|x...|.g.x|..g.', h: 'x.xx|x.xx|x.xx|x.xx' },
        { k: 'x..x|....|..x.|..x.', s: '..g.|x..g|...x|..g.', h: 'x.xx|x.xx|x.xx|x.xx' },
      ],
    },
  },
];

const PERC: DrumRecipe[] = [
  {
    id: 'p.shaker',
    name: 'Shaker Sixteenths',
    styles: '*',
    density: 2,
    desc: 'Steady shaker with a natural forward-back accent.',
    def: { bars: [{ shk: H16 }] },
  },
  {
    id: 'p.tamb',
    name: 'Tambourine Backbeat',
    styles: ['soul', 'pop', 'rock', 'funk', 'blues', 'ballad'],
    density: 1,
    desc: 'Tambourine on 2 and 4 with the odd pickup.',
    def: { bars: [{ tamb: '....|X...|....|X...' }, { tamb: '....|X...|....|X.m.' }] },
  },
  {
    id: 'p.tamb16',
    name: 'Tambourine Drive',
    styles: ['soul', 'pop', 'funk', 'rock'],
    density: 3,
    desc: 'Driving sixteenths accented on the backbeat.',
    def: { bars: [{ tamb: 'm.mm|X.mm|m.mm|X.mm' }] },
  },
  {
    id: 'p.conga',
    name: 'Conga Tumbao',
    styles: ['bossa', 'funk', 'soul', 'afrobeat', 'neosoul', 'pop', 'reggae', 'jazz'],
    density: 2,
    desc: 'Heel-toe ghost strokes, a slap on 2 and open tones on 4.',
    def: {
      bars: [
        { cm: 'g.g.|X.g.|g.g.|....', co: '....|....|....|x.x.' },
        { cm: 'g.g.|X.g.|g...|....', cl: '....|....|..x.|....', co: '....|....|....|x.x.' },
      ],
    },
  },
  {
    id: 'p.clave',
    name: 'Son Clave 3-2',
    styles: ['bossa', 'afrobeat', 'funk'],
    density: 1,
    desc: 'The two-bar clave that glues Latin grooves together.',
    def: { bars: [{ clave: 'x.....x.|....x...' }, { clave: '....x...|x.......' }] },
  },
  {
    id: 'p.cowbell',
    name: 'Cowbell Quarters',
    styles: ['funk', 'rock', 'afrobeat', 'pop'],
    density: 1,
    desc: 'Quarter-note bell, accented on the beat.',
    def: { bars: [{ cow: 'X...|x...|X...|x...' }] },
  },
  {
    id: 'p.afrobell',
    name: 'Bell and Shaker',
    styles: ['afrobeat', 'bossa', 'funk', 'reggae'],
    density: 3,
    desc: 'Agogo bell pattern over cabasa sixteenths.',
    def: { bars: [{ agh: 'x..x|..x.|....|x...', agl: '....|....|x.x.|..x.', cab: H16 }] },
  },
  {
    id: 'p.latin',
    name: 'Latin Set',
    styles: ['bossa', 'afrobeat', 'funk', 'neosoul'],
    density: 3,
    desc: 'Congas, shaker and clave together.',
    def: {
      bars: [
        { cm: 'g.g.|X.g.|g.g.|....', co: '....|....|....|x.x.', shk: H16, clave: 'x.....x.|....x...' },
        { cm: 'g.g.|X.g.|g...|....', cl: '....|....|..x.|....', co: '....|....|....|x.x.', shk: H16, clave: '....x...|x.......' },
      ],
    },
  },
  {
    id: 'p.bongos',
    name: 'Bongo Martillo',
    styles: ['bossa', 'afrobeat', 'neosoul', 'reggae', 'ballad', 'jazz'],
    density: 2,
    desc: 'The steady eighth-note martillo with an open low tone on 4.',
    def: { bars: [{ bh: 'X.m.|x.m.|X.m.|..m.', bl: '....|....|....|x...' }] },
  },
];

function toPattern(r: DrumRecipe, family: 'drums' | 'perc'): PatternDef {
  return {
    id: r.id,
    name: r.name,
    family,
    styles: r.styles,
    density: r.density,
    role: 'groove',
    desc: r.desc,
    gen: (ctx) => runDrums(ctx, r.def).part,
  };
}

export const DRUM_PATTERNS: PatternDef[] = KITS.map((r) => toPattern(r, 'drums'));
export const PERC_PATTERNS: PatternDef[] = PERC.map((r) => toPattern(r, 'perc'));

/** Kick/snare placement for a kit recipe, used to lock the bass to the drums. */
export function grooveFor(patternId: string, ctx: GenCtx): Groove {
  const r = KITS.find((k) => k.id === patternId);
  if (!r) return { kicks: [], snares: [] };
  return runDrums(ctx, r.def).groove;
}
