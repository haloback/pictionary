import { Shuffle } from "@phosphor-icons/react";
import { AnimatePresence, motion } from "motion/react";
import { useEffect, useState } from "react";
import { engine } from "../app/controller";
import { useApp } from "../app/store";
import { getGenre } from "../engine/genres";
import { NOTE_NAMES } from "../engine/theory";
import type { EngineView } from "../engine/types";
import { Keyboard } from "./Keyboard";
import { Roll } from "./Roll";

function useEngineView(): EngineView {
  const [view, setView] = useState(() => engine.getView(0));
  useEffect(() => {
    const id = setInterval(() => {
      const v = engine.getView(performance.now() / 1000);
      setView((p) =>
        p.playing === v.playing && p.chordIndex === v.chordIndex && p.bar === v.bar && Math.floor(p.step / p.pulse) === Math.floor(v.step / v.pulse) && p.chords === v.chords && p.chords.join() === v.chords.join()
          ? p
          : v,
      );
    }, 50);
    return () => clearInterval(id);
  }, []);
  return view;
}

const SCALE_LABEL: Record<string, string> = { major: "major", minor: "minor" };

export function Stage() {
  const genreId = useApp((s) => s.genreId);
  const keyRoot = useApp((s) => s.keyRoot);
  const bpm = useApp((s) => s.bpm);
  const progIndex = useApp((s) => s.progIndex);
  const setProg = useApp((s) => s.setProg);
  const audioReady = useApp((s) => s.audioReady);
  const midiIns = useApp((s) => s.midiIns);
  const g = getGenre(genreId);
  const view = useEngineView();
  const [touched, setTouched] = useState(false);
  useEffect(() => {
    if (view.playing) setTouched(true);
  }, [view.playing]);

  const chord = view.chords[view.playing ? view.chordIndex : 0] ?? "";
  const beats = Math.round(view.steps / view.pulse);
  const beat = Math.floor(view.step / view.pulse);

  return (
    <section className="flex min-h-0 min-w-0 flex-col gap-3 p-4 max-lg:min-h-[72dvh]">
      <div className="flex items-end justify-between gap-4">
        <div className="min-w-0">
          <AnimatePresence mode="wait" initial={false}>
            <motion.h1
              key={g.id}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -4 }}
              transition={{ duration: 0.18, ease: [0.16, 1, 0.3, 1] }}
              className="truncate text-[28px] font-semibold leading-[1.15] tracking-tight"
            >
              {g.name}
            </motion.h1>
          </AnimatePresence>
          <p className="mt-0.5 flex gap-3 text-[12px] text-ink-3">
            <span>
              {NOTE_NAMES[keyRoot]} {SCALE_LABEL[g.scale] ?? g.scale}
            </span>
            <span className="font-mono tabular-nums">{bpm} bpm</span>
            <span className="font-mono">{g.meter}</span>
            {g.swing > 0.05 && <span>swung</span>}
          </p>
        </div>

        <div className="flex shrink-0 items-center gap-2.5" aria-label="Beat">
          {Array.from({ length: beats }, (_, i) => (
            <span
              key={i}
              className={`h-2 rounded-full transition-all duration-100 ${
                view.playing && i === beat ? (i === 0 ? "w-5 bg-accent" : "w-5 bg-ink") : "w-2 bg-line-strong"
              }`}
            />
          ))}
        </div>
      </div>

      <div className="flex items-center gap-2">
        <div className="scroll-x flex min-w-0 flex-1 gap-1">
          {view.chords.map((c, i) => {
            const on = view.playing && i === view.chordIndex;
            return (
              <span
                key={i}
                className={`relative grid h-9 min-w-[52px] shrink-0 place-items-center rounded-ctl border px-2 font-mono text-[13px] transition-colors duration-150 ${
                  on ? "border-transparent bg-ink font-semibold text-bg" : "border-line text-ink-2"
                }`}
              >
                {c}
              </span>
            );
          })}
        </div>
        {g.progs.length > 1 && (
          <button
            type="button"
            onClick={() => setProg((progIndex + 1) % g.progs.length)}
            title="Try another chord progression for this genre"
            className="flex h-9 shrink-0 items-center gap-1.5 whitespace-nowrap rounded-ctl border border-line px-2.5 text-[12px] text-ink-2 transition-[background-color,transform] duration-150 hover:bg-raise hover:text-ink active:scale-[0.97]"
          >
            <Shuffle size={14} />
            Changes {progIndex + 1}/{g.progs.length}
          </button>
        )}
      </div>

      <div className="relative min-h-[180px] flex-1 overflow-hidden rounded-panel border border-line bg-sunk">
        <Roll />
        <div className="pointer-events-none absolute left-5 top-4">
          <div className="font-mono text-[44px] font-medium leading-none tracking-tight text-ink">{view.playing ? chord : ""}</div>
        </div>
        <AnimatePresence>
          {!touched && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0, transition: { duration: 0.5 } }}
              className="absolute inset-0 flex flex-col justify-center gap-2 px-8"
            >
              <h2 className="text-[40px] font-semibold leading-[1.05] tracking-tighter">Hit any keys.</h2>
              <p className="max-w-[46ch] text-[14px] leading-relaxed text-ink-2">
                Mash this keyboard or a MIDI controller. Every note lands in key and on the beat, and the band follows your hands.
              </p>
              <p className="mt-2 text-[12px] text-ink-3">
                {midiIns.length > 0
                  ? `Listening to ${midiIns.map((m) => m.name).join(", ")} and the computer keyboard.`
                  : "No MIDI controller found. The computer keyboard works on its own."}
                {audioReady ? "" : " Sound starts with your first key."}
              </p>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      <Keyboard />
    </section>
  );
}
