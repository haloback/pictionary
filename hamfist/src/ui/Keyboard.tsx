import { useEffect, useRef } from "react";
import { onKey, pressKey, releaseKey } from "../app/controller";
import { KEY_ROWS, KEYS, type KeyDef } from "../engine/keymap";

/** On-screen keys. They light up when hit and show the note each key became. */
export function Keyboard() {
  const caps = useRef(new Map<string, HTMLButtonElement>());

  useEffect(
    () =>
      onKey((code, down, note) => {
        const el = caps.current.get(code);
        if (!el) return;
        el.dataset.on = down ? "1" : "0";
        const label = el.dataset.label ?? "";
        el.firstElementChild!.textContent = down && note ? note : label;
      }),
    [],
  );

  const cap = (k: KeyDef, wide = false) => (
    <button
      key={k.code}
      type="button"
      tabIndex={-1}
      ref={(el) => {
        if (el) caps.current.set(k.code, el);
      }}
      data-label={k.label}
      data-on="0"
      aria-label={`Play key ${k.label}`}
      onPointerDown={(e) => {
        e.currentTarget.setPointerCapture(e.pointerId);
        pressKey(k.code, k.raw);
      }}
      onPointerUp={() => releaseKey(k.code)}
      onPointerCancel={() => releaseKey(k.code)}
      className={`cap grid h-8 place-items-center rounded-key border border-line bg-raise font-mono text-[10.5px] uppercase text-ink-3 ${
        wide ? "w-[46%]" : "min-w-0 flex-1"
      }`}
    >
      <span>{k.label}</span>
    </button>
  );

  const space = KEYS.find((k) => k.code === "Space")!;
  return (
    <div className="mx-auto flex w-full max-w-[720px] flex-col gap-1" aria-label="Playable keys">
      {KEY_ROWS.map((row, i) => (
        <div key={i} className="flex gap-1" style={{ paddingLeft: `${[0, 3, 5, 8][i]}%`, paddingRight: `${[0, 0, 5, 12][i]}%` }}>
          {row.map((k) => cap(k))}
        </div>
      ))}
      <div className="flex justify-center">{cap(space, true)}</div>
    </div>
  );
}
