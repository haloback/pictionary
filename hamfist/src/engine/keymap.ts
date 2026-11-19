// Computer keyboard layout. Every key gets a nominal pitch: left to right
// climbs in whole steps, each row up starts a fifth higher. The exact notes
// do not matter (the engine re-pitches everything); only the shape does.
const ROWS: string[][] = [
  ["KeyZ", "KeyX", "KeyC", "KeyV", "KeyB", "KeyN", "KeyM", "Comma", "Period", "Slash"],
  ["KeyA", "KeyS", "KeyD", "KeyF", "KeyG", "KeyH", "KeyJ", "KeyK", "KeyL", "Semicolon", "Quote"],
  ["KeyQ", "KeyW", "KeyE", "KeyR", "KeyT", "KeyY", "KeyU", "KeyI", "KeyO", "KeyP", "BracketLeft", "BracketRight", "Backslash"],
  ["Backquote", "Digit1", "Digit2", "Digit3", "Digit4", "Digit5", "Digit6", "Digit7", "Digit8", "Digit9", "Digit0", "Minus", "Equal"],
];

const LABELS: Record<string, string> = {
  Comma: ",", Period: ".", Slash: "/", Semicolon: ";", Quote: "'", BracketLeft: "[", BracketRight: "]",
  Backslash: "\\", Backquote: "`", Minus: "-", Equal: "=", Space: "space",
};

export interface KeyDef {
  code: string;
  label: string;
  row: number;
  col: number;
  raw: number;
}

export const KEYS: KeyDef[] = [];
ROWS.forEach((codes, row) =>
  codes.forEach((code, col) => {
    const label = LABELS[code] ?? code.replace(/^Key|^Digit/, "");
    KEYS.push({ code, label, row, col, raw: 45 + row * 7 + col * 2 });
  }),
);
KEYS.push({ code: "Space", label: "space", row: -1, col: 0, raw: 38 });

export const KEY_ROWS: KeyDef[][] = [3, 2, 1, 0].map((r) => KEYS.filter((k) => k.row === r));

const index = new Map(KEYS.map((k) => [k.code, k]));

export function keyForCode(code: string): KeyDef | undefined {
  return index.get(code);
}
