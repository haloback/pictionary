// Rhythm vocabulary shared by every genre.
//
// Pattern strings are one character per grid step. A pattern shorter than the
// bar tiles; longer patterns span several bars.
//
// Drums:  x hit, X accent, o ghost, . rest
// Bass:   1 root, 3 third, 5 fifth, 6 sixth, 7 seventh, 8 octave,
//         a approach note into the next chord, n next chord root (anticipation),
//         - hold, . rest
// Comp:   x stab, X accent, - hold, . rest

export type DrumVoice = "k" | "s" | "h" | "oh" | "c" | "r" | "t" | "p" | "cb" | "rd" | "cr";

/** How essential each voice is. Low rank plays first as energy rises. */
export const DRUM_RANK: Record<DrumVoice, number> = {
  k: 0,
  h: 0.12,
  s: 0.2,
  r: 0.2,
  rd: 0.15,
  c: 0.3,
  p: 0.4,
  cb: 0.45,
  oh: 0.5,
  t: 0.6,
  cr: 0.7,
};

/** General MIDI percussion keys, used for MIDI out and file export. */
export const DRUM_GM: Record<DrumVoice, number> = {
  k: 36,
  s: 38,
  h: 42,
  oh: 46,
  c: 39,
  r: 37,
  t: 45,
  p: 70,
  cb: 56,
  rd: 51,
  cr: 49,
};

export type DrumPattern = Partial<Record<DrumVoice, string>>;

export const DRUMS: Record<string, DrumPattern> = {
  none: {},
  // straight 4/4, 16 steps
  rock: { k: "x.......x.x.....", s: "....X.......X...", h: "x.x.x.x.x.x.x.x.", cr: "x..............................." },
  rockHard: { k: "x.....x.x.x.....", s: "....X.......X...", h: "X.x.X.x.X.x.X.x.", cr: "x..............................." },
  pop: { k: "x.....x...x.....", s: "....X.......X...", h: "x.x.x.x.x.x.x.x.", c: "............x...", p: "..o...o...o...o." },
  ballad: { k: "x.........x.....", r: "....x.......x...", h: "x.x.x.x.x.x.x.x." },
  motown: { k: "x.......x.x.....", s: "....X.......X...", h: "x.x.x.x.x.x.x.x.", p: "x...x...x...x..." },
  four: { k: "X...X...X...X...", c: "....x.......x...", h: "x.x.x.x.x.x.x.x.", oh: "..x...x...x...x." },
  house: { k: "X...X...X...X...", c: "....x.......x...", h: "xoxoxoxoxoxoxoxo", oh: "..x...x...x...x.", p: "...o..o....o..o." },
  disco: { k: "X...X...X...X...", s: "....X.......X...", h: "x.xxx.xxx.xxx.xx", oh: "..x...x...x...x." },
  techno: { k: "X...X...X...X...", c: "....x.......x...", h: "..x...x...x...x.", rd: "x.x.x.x.x.x.x.x.", p: ".o..o..o.o..o..o" },
  trance: { k: "X...X...X...X...", c: "....x.......x...", h: "xxoxxxoxxxoxxxox", oh: "..X...X...X...X.", cr: "x..............................................................." },
  hardstyle: { k: "X...X...X...X...", s: "....x.......x...", oh: "..X...X...X...X.", h: "x.x.x.x.x.x.x.x." },
  garage: { k: "x.........x.....", s: "....X.......X...", h: "..x...x.x.x...x.", oh: "......x.......x.", r: ".......o.....o.." },
  dnb: { k: "x.........x.....", s: "....X.......X...", h: "x.x.x.x.x.x.x.x.", p: ".......o.o.....o" },
  jungle: { k: "x.....x...x..x..", s: "....X..o.o..X..o", h: "x.x.x.x.x.x.x.x.", oh: "..............x." },
  breaks: { k: "x.....x...x.....", s: "....X..o....X..o", h: "x.x.x.x.x.x.x.x.", oh: "......x........." },
  halftime: { k: "x.........x..x..", s: "........X.......", h: "x.x.x.x.x.x.x.x.", oh: "..............x." },
  boombap: { k: "x......x.xx.....", s: "....X.......X...", h: "x.x.x.x.x.x.x.x.", oh: "..............x." },
  lofi: { k: "x......x..x.....", r: "....x.......x...", h: "x.x.x.x.x.x.x.x.", p: "...o.......o...." },
  trap: { k: "x......x..x.....", s: "........X.......", c: "........x.......", h: "x.x.x.xxx.x.xxxx", oh: "......x........." },
  drill: { k: "x......x..x..x..", s: "....X.........X.", h: "x..x..x.x..x..x.", oh: "..........x....." },
  dembow: { k: "X...X...X...X...", s: "...x..x....x..x.", h: "x.x.x.x.x.x.x.x.", p: "..o...o...o...o." },
  dancehall: { k: "x.....x.x.....x.", s: "...x..x....x..x.", h: "x.x.x.x.x.x.x.x.", c: "............x..." },
  onedrop: { k: "........X.......", r: "........x.......", h: "x.xxx.xxx.xxx.xx", oh: "..............x." },
  steppers: { k: "x...x...x...x...", r: "........x.......", h: "x.x.x.x.x.x.x.x.", oh: "..x...x...x...x." },
  ska: { k: "x.......x.......", s: "....X.......X...", h: "..x...x...x...x.", oh: "..............x." },
  funk: { k: "x..x..x...x..x..", s: "....X..o.o..X..o", h: "xxxxxxxxxxxxxxxx", oh: "..............x." },
  gogo: { k: "x..x....x.x.....", s: "....X.......X...", h: "x.x.x.x.x.x.x.x.", p: "x.xx.xx.x.xx.xx.", cb: "..x...x...x...x." },
  newjack: { k: "x..x....x.x.....", s: "....X.......X...", h: "xxxxxxxxxxxxxxxx", c: "....x.......x..." },
  bossa: { k: "x..x....x..x....", r: "x..x..x...x..x..", h: "x.x.x.x.x.x.x.x." },
  samba: { k: "x..xx..xx..xx..x", r: "x.x..x.x.x..x.x.", h: "xxxxxxxxxxxxxxxx", p: "x.xx.xx.x.xx.xx.", cb: "x...x.x...x.x..." },
  salsa: { k: "...x..x....x..x.", cb: "x..x..x...x.x...", p: "..x...xx..x...xx", h: "x.x.x.x.x.x.x.x.", r: "x..x..x...x.x..." },
  cumbia: { k: "x...x...x...x...", p: "x.xxx.xxx.xxx.xx", cb: "....x.......x...", s: "..x...x...x...x." },
  merengue: { k: "x...x...x...x...", s: "x.xxx.xxx.xxxxxx", p: "..x...x...x...x.", cb: "x...x...x...x..." },
  bachata: { k: "x...x...x...x...", r: "..x...x...x...x.", p: "x.xxx.xxx.xxx.xx", cb: "....x.......x..." },
  tango: { k: "x...x...x...x.x.", s: "............x.xx", r: "x...x...x...x..." },
  afrobeat: { k: "x.....x.x.....x.", s: "....x..x....x...", h: "x.xxx.xxx.xxx.xx", p: "xxxxxxxxxxxxxxxx", cb: "x..x..x...x.x..." },
  afrobeats: { k: "x..x..x.x..x..x.", r: "...x..x....x..x.", h: "x.x.x.x.x.x.x.x.", p: "..x..x....x..x..", c: "....x.......x..." },
  amapiano: { k: "x...x...x...x...", p: "x.xx.xx.x.xx.xx.", r: "...x..x...x..x..", h: "..x...x...x...x.", c: "............x..." },
  highlife: { k: "x.......x.....x.", s: "....x.......x...", h: "x.x.x.x.x.x.x.x.", cb: "x..x..x...x.x...", p: "..x...x...x...x." },
  soca: { k: "X...X...X...X...", s: "...x..x....x..x.", h: "x.xxx.xxx.xxx.xx", cb: "..x...x...x...x." },
  baile: { k: "x..x...x..x.x...", s: "...x..x....x..x.", p: "x.x.x.x.x.x.x.x.", c: "....x.......x..." },
  jersey: { k: "x...x...x..x..x.", c: "....x.......x...", h: "x.x.x.x.x.x.x.x.", p: "..x...x...x...x." },
  footwork: { k: "x..x..x...x..x..", c: "....x.......x...", h: "x.xxx.xxx.xxx.xx", t: "......x.......x." },
  bhangra: { k: "x..x..x.x..x..x.", s: "....x.......x...", p: "x.xx.xx.x.xx.xx.", t: "..x...x...x...x." },
  arabic: { k: "x..x....x.......", s: "......x.....x...", p: "..x.x.x...x.x.x.", t: "....x.......x..." },
  train: { k: "x...x...x...x...", s: "x.xxX.xxx.xxX.xx", h: "..x...x...x...x." },
  twostep: { k: "x.......x.......", s: "....X.......X...", h: "x.x.x.x.x.x.x.x." },
  polka: { k: "x.......x.......", s: "....x.......x...", h: "....x.......x...", cr: "x..............................." },
  punk: { k: "x.....x.x.....x.", s: "....X.......X...", h: "X.X.X.X.X.X.X.X.", cr: "x..............................." },
  dbeat: { k: "x..x..x.x..x..x.", s: "....X.......X...", cr: "x.x.x.x.x.x.x.x." },
  metal: { k: "xxxxxxxxxxxxxxxx", s: "....X.......X...", h: "X...X...X...X...", cr: "x..............................." },
  blast: { k: "x.x.x.x.x.x.x.x.", s: ".x.x.x.x.x.x.x.x", cr: "x...x...x...x..." },
  doom: { k: "x.............x.", s: "........X.......", rd: "x...x...x...x...", cr: "x..............................." },
  march: { k: "x.......x.......", s: "x.xxx.x.x.xxxxxx", cr: "x..............................................................." },
  synthwave: { k: "x.......x.x.....", s: "....X.......X...", h: "xxxxxxxxxxxxxxxx", t: "..............xx" },
  electro: { k: "x.....x...x.....", s: "....X.......X...", h: "x.xxx.xxx.xxx.xx", cb: "..x.....x.x....." },
  idm: { k: "x..x......x...x.", s: "....X....x..X.o.", h: "x.xx.xxx.xx.x.xx", p: "......o.o......o" },
  minimal: { k: "x...x...x...x...", r: "....x.......x...", h: "..x...x...x...x.", p: ".o....o..o....o." },
  // triplet grid, 12 steps to the bar
  swing: { rd: "x..x.xx..x.x", h: "...x.....x..", k: "o.....o.....", s: ".....o.....o" },
  swingHot: { rd: "x..x.xx..x.x", h: "...x.....x..", k: "x.....x.....", s: "...x.o...x.o" },
  shuffle: { k: "x.....x.....", s: "...X.....X..", h: "x.xx.xx.xx.x" },
  slow12: { k: "x.....x..x..", s: "...X.....X..", h: "xxxxxxxxxxxx" },
  afro68: { k: "x.....x.....", cb: "x.x.xx.x.x.x", p: "..x..x..x..x", s: "......x....." },
  flamenco: { c: "..X..X.X.X.X", p: "x.xx.xx.x.x.", k: "..x..x.x.x.x" },
  // 3/4, 12 sixteenth steps
  waltz: { k: "x...........", s: "....x...x...", h: "x...x...x..." },
  // 6/8 feel in 12 sixteenth steps
  jig: { k: "x.....x.....", s: "....x.....x.", h: "x.x.x.x.x.x." },
  // 7/8, 14 steps (2+2+3)
  balkan7: { k: "x...x...x.....", s: "..x...x...x.x.", h: "x.x.x.x.x.x.x." },
  // 5/4, 20 steps
  five: { rd: "x...x.x.x...x...x...", k: "x.........x.........", s: "......x.......x....." },
};

export const BASS: Record<string, string> = {
  none: "",
  hold: "1---------------",
  half: "1-------1-------",
  root4: "1...1...1...1...",
  root8: "1.1.1.1.1.1.1.1.",
  rock: "1.1.1.1.1.1.1.5.",
  pop: "1-----1.1-..5-..",
  octaves: "1.8.1.8.1.8.1.8.",
  offbeat: "..1...1...1...1.",
  rolling: ".111.111.111.111",
  sixteenths: "1111111111111111",
  gallop: "1.111.111.111.11",
  rootfive: "1.......5.......",
  rootfiveQ: "1...5...1...5...",
  reggae: "1.....1.5...3...",
  dub: "1--.1.....5-3-..",
  funk: "1..1..8.....7.8.",
  slap: "1.....1..8.7.5.8",
  tumbao: "1.....5.....n---",
  bossa: "1-----1.5-----5.",
  samba: "1--5-.1.1--5-.1.",
  hiphop: "1------1..1.....",
  sub: "1--------.1...3.",
  drill: "1-----8..1--a-..",
  reese: "1-------..1-5---",
  dembow: "1.....1.1.....1.",
  synth: "1.1.8.1.1.1.8.1.",
  twostep: "1.....1...1-....",
  afro: "1..1.5..1..1.57.",
  log: "1.....1..1.8....",
  highlife: "1..5..8.5..3..5.",
  motown: "1..1.5..6.5.3.a.",
  disco: "1.8.1.85.1.8.7.8",
  acid: "1.18.1.1.71.8.11",
  cumbia: "1...5.5.1...5.5.",
  tango: "1...1...1...5.a.",
  march: "1...5...1...5...",
  // 12-step grids
  walking: "1..3..5..a..",
  twofeel: "1.....5.....",
  boogie: "1.13.35.56.5",
  shuffle: "1.11.15.11.a",
  slow12: "1.....1..5..",
  waltz: "1...........",
  jig: "1.....5.....",
  afro68: "1..5..8..5..",
  // odd meters
  balkan7: "1...5...1.5...",
  five: "1.....5...1...5.....",
};

export const COMP: Record<string, string> = {
  none: "",
  pad: "x---------------",
  half: "x-------x-------",
  quarters: "x...x...x...x...",
  eighths: "x.x.x.x.x.x.x.x.",
  push: "x-----x---x-----",
  skank: "..x...x...x...x.",
  backbeat: "....x.......x...",
  house: "..x..x....x..x..",
  piano: "x..x..x...x..x..",
  funk: "x.xx.o.xx.o.xx.o",
  clav: "x.o.xx.ox.o.x.xo",
  montuno: "x.xx.x.xx.x.x.x.",
  tresillo: "x..x..x.x..x..x.",
  strum: "x...x.x.x...x.x.",
  chug: "x.x.x.x.x.x.x.x.",
  gallop: "x.xxx.xxx.xxx.xx",
  gate: "x.xx.xx.x.xx.xx.",
  soul: "x------x.x------",
  stab: "x...............",
  amapiano: "x..x....x..x....",
  offhold: "..x-..x-..x-..x-",
  trap: "x-----------x---",
  bossa: "x..x..x...x..x..",
  // 12-step grids
  charleston: "x....x......",
  swing: "...x.x...x..",
  shuffle: "x.xx.xx.xx.x",
  slow12: "x.xx.xx.xx.x",
  waltz: "....x...x...",
  jig: "x..x.xx..x.x",
  hold12: "x-----------",
  flamenco: "x.xx.xX.X.X.",
  afro68: "x..x.x..x.x.",
  // odd meters
  balkan7: "x...x...x.x...",
  five: "x.....x...x...x.....",
};

export type ArpShape = "up" | "down" | "updown" | "converge" | "random" | "broken" | "alberti";

export interface Meter {
  id: string;
  /** Grid steps per bar. */
  steps: number;
  /** Length of one step in quarter notes. */
  stepBeats: number;
  /** Steps between strong pulses. */
  pulse: number;
  label: string;
}

export const METERS: Record<string, Meter> = {
  "4/4": { id: "4/4", steps: 16, stepBeats: 0.25, pulse: 4, label: "4/4" },
  "12/8": { id: "12/8", steps: 12, stepBeats: 1 / 3, pulse: 3, label: "12/8" },
  "3/4": { id: "3/4", steps: 12, stepBeats: 0.25, pulse: 4, label: "3/4" },
  "6/8": { id: "6/8", steps: 12, stepBeats: 0.25, pulse: 6, label: "6/8" },
  "7/8": { id: "7/8", steps: 14, stepBeats: 0.25, pulse: 4, label: "7/8" },
  "5/4": { id: "5/4", steps: 20, stepBeats: 0.25, pulse: 4, label: "5/4" },
};
