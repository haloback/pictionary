import { DownloadSimple, HandFist, Lock, LockOpen, Stop } from "@phosphor-icons/react";
import { saveTake, stopAll } from "../app/controller";
import { useApp } from "../app/store";
import { NOTE_NAMES } from "../engine/theory";
import { Field, IconButton, pickClass, Slider } from "./controls";

export function TopBar() {
  const s = useApp();
  return (
    <header className="drag traffic-gap flex h-[60px] shrink-0 items-center gap-4 border-b border-line bg-panel px-4">
      <div className="flex items-center gap-2 pr-2">
        <HandFist size={20} weight="fill" className="text-accent" aria-hidden />
        <span className="text-[15px] font-semibold tracking-tight">Hamfist</span>
      </div>

      <Field label="Key" className="w-[68px]">
        <select className={pickClass} value={s.keyRoot} onChange={(e) => s.setKey(Number(e.target.value))}>
          {NOTE_NAMES.map((n, i) => (
            <option key={n} value={i}>
              {n}
            </option>
          ))}
        </select>
      </Field>

      <Field label="Tempo" className="w-[112px]">
        <span className="flex items-center gap-1">
          <input
            type="number"
            min={40}
            max={240}
            value={s.bpm}
            onChange={(e) => s.setBpm(Number(e.target.value) || s.bpm)}
            className="h-7 w-[68px] rounded-ctl border border-line bg-raise px-2 font-mono text-[12px] tabular-nums text-ink"
          />
          <IconButton
            label={s.tempoLocked ? "Tempo is locked. Click to follow the genre." : "Tempo follows the genre. Click to lock."}
            active={s.tempoLocked}
            onClick={() => s.setTempoLocked(!s.tempoLocked)}
          >
            {s.tempoLocked ? <Lock size={14} /> : <LockOpen size={14} />}
          </IconButton>
        </span>
      </Field>

      <div className="w-[150px]">
        <Slider
          label="Tighten timing"
          value={s.tighten}
          onChange={s.setTighten}
          accent
          hint="How firmly your hits are pulled onto the beat. Zero plays exactly when you press."
        />
      </div>

      <Field label="Band" className="w-[136px]">
        <select className={pickClass} value={s.autoStop ? "wait" : "run"} onChange={(e) => s.setAutoStop(e.target.value === "wait")}>
          <option value="wait">Waits for you</option>
          <option value="run">Keeps playing</option>
        </select>
      </Field>

      <div className="flex-1" />

      <Field label="MIDI out" className="w-[180px]">
        <select className={pickClass} value={s.midiOut} onChange={(e) => s.setMidiOut(e.target.value)}>
          <option value="">Built-in sounds only</option>
          {s.midiOuts.map((o) => (
            <option key={o.id} value={o.id}>
              {o.name}
            </option>
          ))}
        </select>
      </Field>

      <button
        type="button"
        onClick={() => void saveTake()}
        className="flex h-8 items-center gap-1.5 whitespace-nowrap rounded-ctl bg-accent px-3 text-[12px] font-semibold text-accent-ink transition-transform duration-150 hover:brightness-105 active:scale-[0.97]"
      >
        <DownloadSimple size={15} weight="bold" />
        Save MIDI
      </button>
      <IconButton label="Stop everything (Esc)" onClick={stopAll} className="h-8 w-8">
        <Stop size={14} weight="fill" />
      </IconButton>
    </header>
  );
}
