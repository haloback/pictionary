import { ChatsCircle, HandFist, Headphones, Metronome, Minus, MusicNotes, PianoKeys, Plus, Repeat, SpeakerHigh, SpeakerSlash, Steps, Trash, Waves, WaveSine, X, type Icon } from "@phosphor-icons/react";
import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { capture } from "../app/controller";
import { AUTO, resolveInstrument, ROLE_INFO, ROLES, useApp } from "../app/store";
import { getKit, getPreset, KITS, PRESET_CATS, PRESETS } from "../audio/presets";
import { getGenre, type Genre } from "../engine/genres";
import { LEAD_ID, type LayerConfig, type Role } from "../engine/types";
import { IconButton, pickClass, Slider } from "./controls";

const ROLE_ICON: Record<Role, Icon> = {
  drums: Metronome,
  bass: WaveSine,
  chords: PianoKeys,
  arp: Steps,
  harmony: MusicNotes,
  echo: Repeat,
  drone: Waves,
  counter: ChatsCircle,
};

const DENSITY_LABEL: Record<Role, string> = {
  drums: "Complexity",
  bass: "Movement",
  chords: "Voices",
  arp: "Range",
  harmony: "Voices",
  echo: "Repeats",
  drone: "Fullness",
  counter: "Chattiness",
};

function InstrumentPick({ role, value, genre, onChange }: { role: Role | "lead"; value: string; genre: Genre; onChange: (v: string) => void }) {
  const auto = resolveInstrument(role, AUTO, genre);
  if (role === "drums") {
    return (
      <select aria-label="Drum kit" className={`${pickClass} w-full`} value={value} onChange={(e) => onChange(e.target.value)}>
        <option value={AUTO}>Genre pick: {getKit(auto).name}</option>
        {KITS.map((k) => (
          <option key={k.id} value={k.id}>
            {k.name}
          </option>
        ))}
      </select>
    );
  }
  return (
    <select aria-label="Instrument" className={`${pickClass} w-full`} value={value} onChange={(e) => onChange(e.target.value)}>
      <option value={AUTO}>Genre pick: {getPreset(auto).name}</option>
      {PRESET_CATS.map((cat) => (
        <optgroup key={cat} label={cat}>
          {PRESETS.filter((p) => p.cat === cat).map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </optgroup>
      ))}
    </select>
  );
}

function Octave({ value, onChange }: { value: number; onChange: (v: number) => void }) {
  return (
    <div className="flex items-center gap-1" title="Octave shift">
      <IconButton label="Octave down" onClick={() => onChange(Math.max(-3, value - 1))} className="h-6 w-6">
        <Minus size={11} weight="bold" />
      </IconButton>
      <span className="w-9 text-center font-mono text-[11px] tabular-nums text-ink-2">
        {value > 0 ? `+${value}` : value} oct
      </span>
      <IconButton label="Octave up" onClick={() => onChange(Math.min(3, value + 1))} className="h-6 w-6">
        <Plus size={11} weight="bold" />
      </IconButton>
    </div>
  );
}

/** Thin bar on the strip edge that flashes when the layer sounds. */
function useActivity(ids: string[]) {
  const bars = useRef(new Map<string, HTMLElement>());
  const key = ids.join("|");
  useEffect(() => {
    let raf = 0;
    const level = new Map<string, number>();
    const tick = () => {
      raf = requestAnimationFrame(tick);
      const now = performance.now() / 1000;
      for (const id of ids) level.set(id, (level.get(id) ?? 0) * 0.88);
      for (let i = capture.notes.length - 1, n = 0; i >= 0 && n < 80; i--, n++) {
        const e = capture.notes[i];
        if (now - e.start < 0.09 && now >= e.start) level.set(e.layer, 1);
      }
      for (let i = capture.hits.length - 1, n = 0; i >= 0 && n < 40; i--, n++) {
        const e = capture.hits[i];
        if (e.kind === "drum" && now - e.time < 0.07 && now >= e.time) level.set(e.layer, Math.max(level.get(e.layer) ?? 0, e.vel));
      }
      for (const [id, el] of bars.current) el.style.opacity = String(0.12 + 0.88 * (level.get(id) ?? 0));
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return (id: string) => (el: HTMLElement | null) => {
    if (el) bars.current.set(id, el);
    else bars.current.delete(id);
  };
}

function Strip({ layer, genre, anySolo, meter }: { layer: LayerConfig; genre: Genre; anySolo: boolean; meter: (el: HTMLElement | null) => void }) {
  const update = useApp((s) => s.updateLayer);
  const remove = useApp((s) => s.removeLayer);
  const info = ROLE_INFO[layer.role];
  const RoleIcon = ROLE_ICON[layer.role];
  const quiet = layer.mute || (anySolo && !layer.solo);
  const set = (p: Partial<LayerConfig>) => update(layer.id, p);
  return (
    <motion.li
      layout
      initial={{ opacity: 0, y: 10, scale: 0.98 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, scale: 0.96, transition: { duration: 0.14 } }}
      transition={{ type: "spring", stiffness: 420, damping: 34 }}
      className="relative overflow-hidden rounded-panel border border-line bg-raise p-3 pl-4"
    >
      <span ref={meter} className="absolute inset-y-0 left-0 w-[3px] bg-ink" style={{ opacity: 0.12 }} />
      <div className={`flex flex-col gap-2.5 transition-opacity duration-200 ${quiet ? "opacity-45" : ""}`}>
        <div className="flex items-center gap-2">
          <RoleIcon size={16} className="shrink-0 text-ink-2" aria-hidden />
          <span className="min-w-0 flex-1 truncate text-[13px] font-semibold tracking-tight" title={info.blurb}>
            {info.name}
          </span>
          <IconButton label={layer.mute ? "Unmute" : "Mute"} active={layer.mute} onClick={() => set({ mute: !layer.mute })} className="h-6 w-6">
            {layer.mute ? <SpeakerSlash size={12} /> : <SpeakerHigh size={12} />}
          </IconButton>
          <IconButton label={layer.solo ? "Unsolo" : "Solo"} active={layer.solo} onClick={() => set({ solo: !layer.solo })} className="h-6 w-6">
            <Headphones size={12} />
          </IconButton>
          <IconButton label={`Remove ${info.name}`} onClick={() => remove(layer.id)} className="h-6 w-6">
            <Trash size={12} />
          </IconButton>
        </div>
        <InstrumentPick role={layer.role} value={layer.instrument} genre={genre} onChange={(instrument) => set({ instrument })} />
        <div className="grid grid-cols-3 gap-3">
          <Slider label="Volume" value={layer.volume} onChange={(volume) => set({ volume })} />
          <Slider
            label="Follow"
            value={layer.follow}
            onChange={(follow) => set({ follow })}
            accent
            hint="At 100 this layer only plays while you do. At 0 it plays no matter what."
          />
          <Slider label={DENSITY_LABEL[layer.role]} value={layer.density} onChange={(density) => set({ density })} />
        </div>
        {layer.role !== "drums" && (
          <div className="flex items-center justify-between">
            <Octave value={layer.octave} onChange={(octave) => set({ octave })} />
            <label className="flex items-center gap-1.5 text-[11px] text-ink-3">
              MIDI ch
              <select
                className={`${pickClass} h-6 w-[52px] font-mono`}
                value={layer.channel}
                onChange={(e) => set({ channel: Number(e.target.value) })}
              >
                {Array.from({ length: 16 }, (_, i) => i + 1)
                  .filter((c) => c !== 10)
                  .map((c) => (
                    <option key={c} value={c}>
                      {c}
                    </option>
                  ))}
              </select>
            </label>
          </div>
        )}
      </div>
    </motion.li>
  );
}

export function LayerRack() {
  const layers = useApp((s) => s.layers);
  const lead = useApp((s) => s.lead);
  const setLead = useApp((s) => s.setLead);
  const addLayer = useApp((s) => s.addLayer);
  const genre = getGenre(useApp((s) => s.genreId));
  const [adding, setAdding] = useState(false);
  const anySolo = layers.some((l) => l.solo);
  const meter = useActivity([LEAD_ID, ...layers.map((l) => l.id)]);
  const endRef = useRef<HTMLDivElement>(null);

  return (
    <aside className="flex min-h-0 flex-col border-line bg-panel max-lg:border-t lg:border-l">
      <div className="flex items-baseline justify-between p-3 pb-2">
        <h2 className="text-[13px] font-semibold tracking-tight">Layers</h2>
        <span className="font-mono text-[11px] tabular-nums text-ink-3">{layers.length} following</span>
      </div>

      <div className="scroll-y min-h-0 flex-1 px-3 pb-3">
        <div className="relative mb-2 overflow-hidden rounded-panel border border-line bg-raise p-3 pl-4">
          <span ref={meter(LEAD_ID)} className="absolute inset-y-0 left-0 w-[3px] bg-accent" style={{ opacity: 0.12 }} />
          <div className="flex flex-col gap-2.5">
            <div className="flex items-center gap-2">
              <HandFist size={16} weight="fill" className="shrink-0 text-accent" aria-hidden />
              <span className="flex-1 text-[13px] font-semibold tracking-tight">You</span>
              <Octave value={lead.octave} onChange={(octave) => setLead({ octave })} />
            </div>
            <InstrumentPick role="lead" value={lead.instrument} genre={genre} onChange={(instrument) => setLead({ instrument })} />
            <Slider label="Volume" value={lead.volume} onChange={(volume) => setLead({ volume })} accent />
          </div>
        </div>

        <ul className="flex flex-col gap-2">
          <AnimatePresence initial={false} mode="popLayout">
            {layers.map((l) => (
              <Strip key={l.id} layer={l} genre={genre} anySolo={anySolo} meter={meter(l.id)} />
            ))}
          </AnimatePresence>
        </ul>

        {layers.length === 0 && !adding && (
          <p className="px-1 py-5 text-[12px] leading-relaxed text-ink-3">
            You are playing alone. Add a layer and it will follow your chords, your timing and how hard you play.
          </p>
        )}

        <div ref={endRef} className="mt-2">
          {adding ? (
            <motion.div
              key="menu"
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.16 }}
              onAnimationComplete={() => endRef.current?.scrollIntoView({ block: "nearest", behavior: "smooth" })}
              className="rounded-panel border border-line-strong bg-raise p-1.5"
              style={{ boxShadow: "var(--shadow)" }}
            >
              <div className="flex items-center justify-between px-2 pb-1 pt-1">
                <span className="text-[12px] font-medium text-ink-2">What should follow you?</span>
                <IconButton label="Close" onClick={() => setAdding(false)} className="h-6 w-6 border-transparent">
                  <X size={12} weight="bold" />
                </IconButton>
              </div>
              {ROLES.map((role) => {
                const RoleIcon = ROLE_ICON[role];
                return (
                  <button
                    key={role}
                    type="button"
                    onClick={() => {
                      addLayer(role);
                      setAdding(false);
                    }}
                    className="flex w-full items-start gap-2.5 rounded-ctl px-2 py-1.5 text-left transition-colors duration-100 hover:bg-accent-soft"
                  >
                    <RoleIcon size={16} className="mt-0.5 shrink-0 text-ink-2" aria-hidden />
                    <span className="min-w-0">
                      <span className="block text-[12.5px] font-medium text-ink">{ROLE_INFO[role].name}</span>
                      <span className="block text-[11px] leading-snug text-ink-3">{ROLE_INFO[role].blurb}</span>
                    </span>
                  </button>
                );
              })}
            </motion.div>
          ) : (
            <motion.button
              key="add"
              type="button"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.12 }}
              onClick={() => setAdding(true)}
              className="flex h-10 w-full items-center justify-center gap-1.5 rounded-panel border border-dashed border-line-strong text-[12.5px] font-medium text-ink-2 transition-[background-color,color,transform] duration-150 hover:bg-raise hover:text-ink active:scale-[0.98]"
            >
              <Plus size={14} weight="bold" />
              Add layer
            </motion.button>
          )}
        </div>
      </div>
    </aside>
  );
}
