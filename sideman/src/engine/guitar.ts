// Guitar recipes: strums with real string order and timing, muted scratches,
// stabs with slide-ins, palm mutes, fingerpicking and single-note lines.

import { BAR, BEAT, S16 } from './types';
import type { Art, Note, Part, StyleId } from './types';

import { PB, chordAt, isPhraseEnd, nextChange, steps } from './perf';
import type { GenCtx } from './perf';
import { lerp, mod12, roleInterval } from './theory';
import { pickVoicing } from './fretboard';
import type { Voicing, VoicingKind } from './fretboard';
import type { PatternDef } from './patterns';
import { riffLine } from './lines';
import type { LineNote } from './lines';
import { bankComp, bankLine, guitarTokens, rfamOf } from './phrasebank';
import type { LineRole } from './phrasebank';

interface GtrDef {
  kind: VoicingKind;
  bars: string[];
  fills?: string[];
  /** strum-direction grid: down on the beat of this subdivision */
  sub: 8 | 16;
  forceDir?: 'D' | 'U';
  /** late attacks before a chord change play the next chord */
  antic?: boolean;
  lay?: number;
  vel?: number;
  /** probability scale for sliding into stabs from a fret below */
  slideIn?: number;
  /** slower, wider strums */
  lazy?: boolean;
  /** supply each bar's template directly (phrase bank) */
  tpl?: (bar: number) => string;
}

/*
  Strum tokens (16 per bar):
    F full strum (accent)     f light strum         m muted scratch
    S short stab (accent)     s short stab          P palm mute   p soft palm mute
    B bass string             b alternate bass      T pluck top strings   t soft pluck
    A pinch (bass + top)      1-6 pick one string (1 = lowest of the shape)
    - let ring                . stop the strings
*/

function runGuitar(ctx: GenCtx, def: GtrDef): Part {
  const b = new PB(ctx);
  const rng = ctx.rng.fork('gtr');
  const cx = ctx.params.complexity;
  const ex = ctx.params.expression;
  const total = ctx.bars * 16;
  const tok: string[] = [];
  for (let bar = 0; bar < ctx.bars; bar++) {
    const r = rng.fork('bar' + bar);
    let tpl = def.tpl ? def.tpl(bar) : def.bars[bar % def.bars.length];
    if (def.tpl) {
      /* dealt bar by bar */
    } else if (def.fills && isPhraseEnd(ctx, bar) && r.chance(0.4 + cx * 0.4)) tpl = r.pick(def.fills);
    else if (def.bars.length > 1 && r.chance(cx * 0.2)) tpl = r.pick(def.bars);
    tok.push(...steps(tpl));
  }
  const isAttack = (c: string) => c !== '-' && c !== '.';
  const antic = new Set<number>();
  for (const sp of ctx.spans) {
    if (!sp.change || sp.t === 0) continue;
    const c = Math.round(sp.t / S16);
    if (c >= total || isAttack(tok[c])) continue;
    let a = -1;
    if (def.antic) {
      if (isAttack(tok[c - 1])) a = c - 1;
      else if (c >= 2 && isAttack(tok[c - 2]) && tok[c - 1] !== '.') a = c - 2;
    }
    if (a >= 0) antic.add(a);
    else if (tok[c] === '-') tok[c] = /[1-6]/.test(tok.join('')) ? '1' : 'f';
  }

  const twelve = ctx.variant === 'twelve';
  const ringing: (Note | null)[] = [null, null, null, null, null, null];
  const cutString = (s: number, at: number) => {
    const n = ringing[s];
    if (n && n.t + n.d > at - 2) n.d = Math.max(10, at - 2 - n.t);
    ringing[s] = null;
  };
  const cutAll = (at: number) => {
    for (let s = 0; s < 6; s++) cutString(s, at);
  };
  const pluck = (vo: Voicing, k: number, t: number, off: number, v: number, dur: number, art?: Art) => {
    const s = vo.strings[k];
    const startAbs = b.w(t) + off;
    cutString(s, startAbs);
    const n = b.note(t, dur, vo.pitches[k] + ctx.params.octave * 12, v, { art, off });
    if (art !== 'ghost' && art !== 'staccato' && art !== 'mute') ringing[s] = n;
    // twelve-string: the four lower courses carry an octave string, struck a hair later
    if (twelve && s <= 3) b.note(t, dur, vo.pitches[k] + 12 + ctx.params.octave * 12, v * 0.82, { art, off: off + b.ms(7) });
  };

  let voicing: Voicing | null = null;
  let voicingSym = '';
  for (let i = 0; i < total; i++) {
    const tk = tok[i];
    const t = i * S16;
    if (tk === '-') continue;
    if (tk === '.') {
      cutAll(b.w(t));
      continue;
    }
    const ch = (antic.has(i) ? nextChange(ctx, t).span : chordAt(ctx, t)).chord;
    if (ch.nc) {
      cutAll(b.w(t));
      continue;
    }
    if (ch.sym !== voicingSym) {
      voicing = pickVoicing(ch, def.kind, voicing, rng);
      voicingSym = ch.sym;
      cutAll(b.w(t) - b.ms(12));
    }
    const vo = voicing!;
    const n = vo.strings.length;
    let holds = 0;
    while (i + 1 + holds < total && tok[i + 1 + holds] === '-') holds++;
    const len = (1 + holds) * S16;
    const ring = len + BEAT; // rings on; the next attack on each string cuts it
    const step = i % 16;
    let dir: 'D' | 'U' = def.forceDir ?? (def.sub === 16 ? (step % 2 === 0 ? 'D' : 'U') : step % 4 === 0 ? 'D' : 'U');
    const back = step === 4 || step === 12 ? 4 : 0;
    const lay = b.ms(def.lay ?? 0) + b.jit(4.5);
    const vBase = def.vel ?? 0;

    const strum = (idx: number[], vel: number, dur: number, art: Art | undefined, spreadMs: number) => {
      const order = dir === 'D' ? idx : idx.slice().reverse();
      const gap = order.length > 1 ? b.ms(spreadMs) / (order.length - 1) : 0;
      const start = lay - b.ms(spreadMs) * 0.4;
      order.forEach((k, j) => {
        const off = start + j * gap * rng.range(0.85, 1.15);
        const v = vel * (1 - 0.04 * j) + rng.range(-3, 3);
        pluck(vo, k, t, off, v + vBase, dur, art);
      });
    };
    const all = vo.strings.map((_, k) => k);
    const top = (m: number) => all.slice(Math.max(0, n - m));
    const low = (m: number) => all.slice(0, Math.min(n, m));

    if (/[1-6]/.test(tk)) {
      const k = Math.min(n - 1, parseInt(tk, 10) - 1);
      const thumb = k <= 1;
      const v = (thumb ? 84 : 72) + (step % 4 === 0 ? 6 : 0);
      pluck(vo, k, t, lay, v + vBase, ring * 2, undefined);
      continue;
    }
    switch (tk) {
      case 'F': {
        const sp = (def.lazy ? 55 : lerp(24, 13, cx)) * rng.range(0.85, 1.2);
        if (dir === 'D') strum(all, 98 + back, ring, undefined, sp);
        else strum(top(Math.min(n, 4)), 88 + back, ring, undefined, sp * 0.7);
        break;
      }
      case 'f': {
        // light strokes catch fewer strings; sometimes they miss altogether
        if (holds === 0 && step % 4 !== 0 && rng.chance((1 - cx) * 0.12)) break;
        if (dir === 'D') strum(n >= 5 ? all.slice(0, n - 1) : all, 76, ring, undefined, def.lazy ? 45 : 20);
        else strum(top(3), 68, ring, undefined, 12);
        break;
      }
      case 'm': {
        cutAll(b.w(t) + lay - b.ms(8));
        const idx = dir === 'D' ? low(Math.min(n, 4)) : top(Math.min(n, 3));
        strum(idx, rng.range(40, 54), b.ms(32), 'ghost', 9);
        // scratch notes are absolute-length
        b.notes.slice(-idx.length).forEach((nn) => (nn.d = Math.max(10, Math.round(b.ms(32)))));
        break;
      }
      case 'S':
      case 's': {
        const acc = tk === 'S';
        cutAll(b.w(t) + lay - b.ms(10));
        const idx = n > 5 ? top(5) : all;
        const startAbs = b.w(t) + lay;
        if (def.slideIn && acc && rng.chance(ex * def.slideIn * 0.3 * ctx.traits.slide)) {
          b.bendRampAbs(startAbs - b.ms(12), startAbs + b.ms(42), -1, 0, 0.8);
          b.bendAbs(startAbs + b.ms(48), 0);
        }
        const d = Math.min(len, S16 * 2) * (acc ? 0.62 : 0.5);
        strum(idx, (acc ? 102 : 82) + back, d, 'staccato', acc ? 11 : 9);
        break;
      }
      case 'P':
      case 'p': {
        dir = 'D';
        const idx = low(3);
        idx.forEach((k) => cutString(vo.strings[k], b.w(t) + lay));
        strum(idx, tk === 'P' ? 92 : 74, Math.min(len, S16 * 2) * 0.55, 'mute', 6);
        break;
      }
      case 'B':
        pluck(vo, 0, t, lay, 92 + vBase, ring * 2);
        break;
      case 'b': {
        const fifthPc = mod12(ch.root + roleInterval(ch, '5'));
        let k = low(3).find((q) => q > 0 && mod12(vo.pitches[q]) === fifthPc) ?? Math.min(1, n - 1);
        if (k === 0 && n > 1) k = 1;
        pluck(vo, k, t, lay, 84 + vBase, ring * 2);
        break;
      }
      case 'T':
      case 't':
        dir = 'D';
        strum(top(3), tk === 'T' ? 84 : 68, ring, undefined, 4);
        break;
      case 'A':
        pluck(vo, 0, t, lay - b.ms(4), 90 + vBase, ring * 2);
        dir = 'D';
        strum(top(Math.min(3, n - 1)), 80, ring, undefined, 4);
        break;
    }
  }
  // let the last chord ring to the end only
  cutAll(ctx.len);
  return b.part();
}

/** Play a single-note line: muted and percussive, or open and singing with bends, slides and vibrato. */
function renderLine(ctx: GenCtx, line: LineNote[], opts: { open?: boolean }): Part {
  const b = new PB(ctx);
  const rng = ctx.rng.fork('gline');
  const ex = ctx.params.expression;
  const tr = ctx.traits;
  let prevP = -1;
  let prevEnd = -1e9;
  line.forEach((n, i) => {
    const next = line[i + 1];
    const short = n.d <= S16 * 2;
    const off = b.jit(4);
    const startAbs = b.w(n.t) + off;
    const open = opts.open || (!short && !n.acc ? false : n.acc);
    let art: Art | undefined = open ? undefined : 'mute';
    // hammer-on feel: consecutive stepwise notes are slurred
    const slur = !!next && next.t - (n.t + n.d) < 10 && Math.abs(next.p - n.p) <= 2 && rng.chance(0.3 + ex * 0.3);
    if (open && slur) art = 'legato';
    if (open && tr.gliss > 0 && prevP >= 0 && startAbs - prevEnd < b.ms(70) && prevP !== n.p && Math.abs(prevP - n.p) <= 5 && rng.chance(Math.min(1, ex * 0.5 * tr.gliss))) {
      // slide from the previous note
      const gl = b.ms(rng.range(70, 130));
      b.bendRampAbs(startAbs - 2, startAbs + gl, Math.max(-2, Math.min(2, prevP - n.p)), 0, 0.8);
      b.bendAbs(startAbs + gl + 4, 0);
      art = 'gliss';
    } else if (open && n.d >= S16 * 2 && tr.bend > 0 && rng.chance(Math.min(1, ex * (n.d >= S16 * 3 ? 0.32 : 0.14) * tr.bend))) {
      // bend up into the note from a fret or two below
      const bl = b.ms(rng.range(110, 190));
      b.bendRampAbs(startAbs - 2, startAbs + bl, rng.chance(0.5) ? -2 : -1, 0, 0.7);
      b.bendAbs(startAbs + bl + 4, 0);
      art = 'bend';
    } else if (n.acc && rng.chance(ex * 0.3 * tr.slide)) {
      b.bendRampAbs(startAbs - 2, startAbs + b.ms(50), -1, 0, 0.7);
      b.bendAbs(startAbs + b.ms(56), 0);
      if (open) art = 'slide';
    }
    const d = open ? n.d * (slur ? 1.02 : 0.85) : Math.min(n.d, S16 * 2) * 0.5;
    b.note(n.t, d, n.p, n.acc ? 100 : 82 + (Math.round(n.t / S16) % 4 === 0 ? 5 : 0), { art, off });
    const end = b.w(n.t + d) + off;
    if (open && n.d >= BEAT && rng.chance(Math.min(1, ex * 0.6 * tr.vib))) {
      b.cAbs('vib', startAbs + (end - startAbs) * 0.4, 0);
      b.rampAbs('vib', startAbs + (end - startAbs) * 0.45, end - 10, 0, Math.min(1, 0.6 * Math.min(1.6, tr.vib)), 1, 50);
      b.cAbs('vib', end, 0);
    }
    prevP = n.p;
    prevEnd = end;
  });
  void BAR;
  return b.part();
}

function lineRange(ctx: GenCtx) {
  const oct = ctx.params.octave * 12;
  return { center: 62 + oct, lo: 52 + oct, hi: 76 + oct };
}
/** Muted single-note line: a pentatonic riff picked with the palm on the bridge. */
function mutedLine(ctx: GenCtx, opts: { answer?: boolean; open?: boolean }): Part {
  return renderLine(ctx, riffLine(ctx, { ...lineRange(ctx), answer: opts.answer }), opts);
}
/** A line dealt from the phrase bank in the given role. */
function bankLinePart(ctx: GenCtx, role: LineRole): Part {
  const got = bankLine(ctx, role, lineRange(ctx));
  const part = renderLine(ctx, got.notes, { open: role !== 'riff' });
  part.phrases = got.uses;
  return part;
}
/** Comping dealt from the phrase bank, sharing accents with the rest of the band. */
function bankCompPart(ctx: GenCtx): Part {
  const fam = rfamOf(ctx.style);
  const got = bankComp(ctx, 'guitar');
  const sixteenths = fam === 'funk';
  const part = runGuitar(ctx, {
    kind: fam === 'swing' ? 'shell' : fam === 'funk' || fam === 'latin' ? 'top4' : 'full',
    sub: sixteenths ? 16 : 8,
    antic: true,
    slideIn: 1,
    bars: [],
    tpl: (bar) => guitarTokens(got.rhythms[bar], got.shapes[bar], sixteenths),
  });
  part.phrases = got.uses;
  return part;
}

interface GtrRecipe {
  id: string;
  name: string;
  styles: StyleId[] | '*';
  density: 1 | 2 | 3;
  role: 'rhythm' | 'pad' | 'line';
  desc: string;
  variant?: string;
  def?: GtrDef;
  gen?: (ctx: GenCtx) => Part;
}

const RECIPES: GtrRecipe[] = [
  {
    id: 'g.strum8',
    name: 'Campfire Strum',
    styles: ['pop', 'rock', 'ballad', 'soul', 'reggae'],
    density: 2,
    role: 'rhythm',
    variant: 'steel',
    desc: 'Down, down-up, up-down-up on full open chords.',
    def: {
      kind: 'full',
      sub: 8,
      bars: ['F---|F-f-|--f-|F-f-', 'F---|F-f-|--f-|f-f-', 'F---|f-f-|--f-|F-f-'],
      fills: ['F---|F-f-|F-f-|F-F-'],
    },
  },
  {
    id: 'g.bank',
    name: 'Phrase bank: Comping',
    styles: ['funk', 'soul', 'pop', 'rock', 'neosoul', 'afrobeat', 'reggae', 'bossa', 'jazz', 'blues', 'ballad'],
    density: 2,
    role: 'rhythm',
    variant: 'clean',
    desc: 'Comping figures dealt from the phrase bank. Every other bar joins the band on its shared accents; the bars between stay out of their way.',
    gen: bankCompPart,
  },
  {
    id: 'g.banklead',
    name: 'Phrase bank: Lead lines',
    styles: ['funk', 'soul', 'pop', 'rock', 'neosoul', 'afrobeat', 'reggae', 'bossa', 'jazz', 'blues', 'ballad'],
    density: 3,
    role: 'line',
    variant: 'overdrive',
    desc: 'Lead phrases from the bank. Speaks in the bars the band plan gives to the lead, and joins the tutti bars.',
    gen: (ctx) => bankLinePart(ctx, 'lead'),
  },
  {
    id: 'g.bankanswer',
    name: 'Phrase bank: Answers',
    styles: ['funk', 'soul', 'pop', 'rock', 'neosoul', 'afrobeat', 'reggae', 'bossa', 'jazz', 'blues', 'ballad'],
    density: 1,
    role: 'line',
    variant: 'clean',
    desc: 'Replies from the bank in the bars a lead player leaves open.',
    gen: (ctx) => bankLinePart(ctx, 'answer'),
  },
  {
    id: 'g.bankriff',
    name: 'Phrase bank: Riffs',
    styles: ['funk', 'afrobeat', 'rock', 'soul', 'reggae', 'pop', 'blues', 'neosoul'],
    density: 2,
    role: 'line',
    variant: 'muted',
    desc: 'A two-bar riff built from two bank phrases, with a tag to close each four bars.',
    gen: (ctx) => bankLinePart(ctx, 'riff'),
  },
  {
    id: 'g.strum16',
    name: 'Sixteenth Strum',
    styles: ['pop', 'rock', 'soul', 'funk', 'afrobeat'],
    density: 3,
    role: 'rhythm',
    variant: 'steel',
    desc: 'Constant hand motion with muted scratches between the chords.',
    def: {
      kind: 'full',
      sub: 16,
      bars: ['F-fm|m-ff|-mfm|F-fm', 'F-fm|F-mf|-mfm|m-ff', 'F--f|m-ff|-ff-|F-fm'],
      fills: ['F-fm|F-fm|FmFm|FfFf'],
    },
  },
  {
    id: 'g.ballad',
    name: 'Slow Rolled Chords',
    styles: ['ballad', 'neosoul', 'bossa', 'soul', 'jazz'],
    density: 1,
    role: 'pad',
    variant: 'nylon',
    desc: 'One unhurried strum per chord, strings rolled from bass to treble.',
    def: { kind: 'full', sub: 8, lazy: true, lay: 6, bars: ['F---|----|----|----', 'F---|----|--f-|----', 'F---|----|----|--t-'] },
  },
  {
    id: 'g.arp',
    name: 'Arpeggio Eighths',
    styles: ['ballad', 'pop', 'rock', 'soul', 'neosoul'],
    density: 2,
    role: 'rhythm',
    variant: 'clean',
    desc: 'Broken chords across the strings, left ringing.',
    def: { kind: 'full', sub: 8, bars: ['1-3-|4-5-|6-5-|4-3-', '1-3-|4-5-|4-3-|4-5-', '1-4-|5-6-|5-4-|2-4-'] },
  },
  {
    id: 'g.travis',
    name: 'Travis Picking',
    styles: ['pop', 'ballad', 'blues', 'rock'],
    density: 3,
    role: 'rhythm',
    variant: 'steel',
    desc: 'Alternating thumb bass with syncopated finger notes on top.',
    def: { kind: 'full', sub: 8, bars: ['1-5-|3-46|1-5-|3-4-', '1-6-|3-45|2-6-|3-4-', '1-5-|3-4-|2-56|3-4-'] },
  },
  {
    id: 'g.funk16',
    name: 'Scratch Sixteenths',
    styles: ['funk', 'afrobeat', 'neosoul', 'soul'],
    density: 3,
    role: 'rhythm',
    variant: 'clean',
    desc: 'Tight upper-string chord stabs inside a stream of muted scratches.',
    def: {
      kind: 'top4',
      sub: 16,
      antic: true,
      slideIn: 1,
      bars: ['mmSm|mSmm|SmmS|mmSm', 'S.mS|m.Sm|mmS.|mSmm', 'mmSm|mmsS|.mSm|mSm.', 'S.mm|sSm.|mSmm|S.ms'],
      fills: ['SmmS|mmSm|mSmS|SsSs'],
    },
  },
  {
    id: 'g.chops',
    name: 'Backbeat Chops',
    styles: ['soul', 'pop', 'funk', 'reggae', 'blues', 'neosoul'],
    density: 1,
    role: 'rhythm',
    variant: 'clean',
    desc: 'Short chord chops on 2 and 4, sliding in from a fret below.',
    def: {
      kind: 'top4',
      sub: 8,
      forceDir: 'D',
      slideIn: 1.6,
      bars: ['....|S...|....|S...', '....|S...|....|S.s.', '....|S...|..s.|S...'],
      fills: ['....|S...|..s.|S.sS'],
    },
  },
  {
    id: 'g.skank',
    name: 'Off-beat Skank',
    styles: ['reggae', 'afrobeat'],
    density: 2,
    role: 'rhythm',
    variant: 'clean',
    desc: 'Clipped upstrokes on every off-beat.',
    def: {
      kind: 'triad',
      sub: 8,
      forceDir: 'U',
      bars: ['..S.|..S.|..S.|..S.', '..S.|..S.|..S.|..Ss', '..Ss|..S.|..S.|..S.'],
    },
  },
  {
    id: 'g.pm8',
    name: 'Palm-mute Drive',
    styles: ['rock', 'pop'],
    density: 2,
    role: 'rhythm',
    variant: 'overdrive',
    desc: 'Chugging muted eighths on power chords, opened up for the accents.',
    def: {
      kind: 'power',
      sub: 8,
      forceDir: 'D',
      bars: ['F-P-|P-P-|F-P-|P-P-', 'F-P-|P-F-|P-P-|F-P-', 'P-P-|F-P-|P-P-|F-P-'],
      fills: ['F-P-|P-P-|F-F-|F-F-'],
    },
  },
  {
    id: 'g.power',
    name: 'Power Chords',
    styles: ['rock'],
    density: 1,
    role: 'pad',
    variant: 'overdrive',
    desc: 'Big sustained fifths with pushed re-strikes.',
    def: {
      kind: 'power',
      sub: 8,
      forceDir: 'D',
      antic: true,
      bars: ['F---|----|----|--F-', 'F---|--F-|----|----', 'F---|----|F---|--F-'],
    },
  },
  {
    id: 'g.four',
    name: 'Four to the Bar',
    styles: ['jazz', 'blues'],
    density: 2,
    role: 'rhythm',
    variant: 'jazz',
    desc: 'Three-note shell voicings on every beat, leaning on 2 and 4.',
    def: { kind: 'shell', sub: 8, forceDir: 'D', vel: -8, bars: ['s...|S...|s...|S...'] },
  },
  {
    id: 'g.charleston',
    name: 'Charleston Comp',
    styles: ['jazz', 'blues', 'bossa'],
    density: 1,
    role: 'rhythm',
    variant: 'jazz',
    desc: 'Sparse syncopated stabs that anticipate the changes.',
    def: {
      kind: 'shell',
      sub: 8,
      forceDir: 'D',
      antic: true,
      bars: ['S...|..s.|....|....', '....|..S.|....|..s.', 'S...|....|..s.|....', '..s.|....|S...|..s.', '....|S...|....|..S.'],
    },
  },
  {
    id: 'g.bossa',
    name: 'Bossa Fingerstyle',
    styles: ['bossa', 'jazz'],
    density: 2,
    role: 'rhythm',
    variant: 'nylon',
    desc: 'Thumb on the bass strings against plucked chords in the classic two-bar pattern.',
    def: {
      kind: 'full',
      sub: 8,
      antic: true,
      bars: ['A-..|..T.|B...|T...', 'B.T.|..T.|b...|T.t.'],
    },
  },
  {
    id: 'g.highlife',
    name: 'Highlife Picking',
    styles: ['afrobeat', 'reggae', 'pop', 'soul'],
    density: 3,
    role: 'rhythm',
    variant: 'clean',
    desc: 'Bright interlocking arpeggios on the top three strings.',
    def: { kind: 'triad', sub: 16, bars: ['1.3.|2.3.|1.3.|2.31', '3.2.|1.2.|3.1.|2.1.', '1.32|.3.1|.32.|3.2.'] },
  },
  {
    id: 'g.muteline',
    name: 'Muted Single-note Riff',
    styles: ['funk', 'afrobeat', 'neosoul', 'soul', 'pop'],
    density: 2,
    role: 'line',
    variant: 'muted',
    desc: 'A percussive pentatonic riff that follows the chords.',
    gen: (ctx) => mutedLine(ctx, {}),
  },
  {
    id: 'g.answers',
    name: 'Answer Licks',
    styles: ['blues', 'soul', 'rock', 'funk', 'neosoul', 'reggae'],
    density: 1,
    role: 'line',
    variant: 'clean',
    desc: 'Open, singing licks in every second bar, leaving room for the band.',
    gen: (ctx) => mutedLine(ctx, { answer: true, open: true }),
  },
  {
    id: 'g.boomchick',
    name: 'Boom-chick',
    styles: ['pop', 'blues', 'reggae', 'ballad'],
    density: 2,
    role: 'rhythm',
    variant: 'steel',
    desc: 'Bass note on the beat, chord on the off-beat, alternating bass.',
    def: { kind: 'full', sub: 8, bars: ['B---|f---|b---|f---', 'B---|f-f-|b---|f---', 'B---|f---|b---|f-f-'] },
  },
];

export const GUITAR_PATTERNS: PatternDef[] = RECIPES.map((r) => ({
  id: r.id,
  name: r.name,
  family: 'guitar',
  styles: r.styles,
  density: r.density,
  role: r.role,
  desc: r.desc,
  variant: r.variant,
  bank: r.id.startsWith('g.bank'),
  gen: r.gen ?? ((ctx) => runGuitar(ctx, r.def!)),
}));
