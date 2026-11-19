import { ArrowsClockwise, DiceFive, DownloadSimple, Star, Trash, X } from '@phosphor-icons/react';
import { useApp } from './store';
import type { Tab } from './store';
import { IconBtn, NumberBox, Slider, TRACK_COLORS, Toggle } from './bits';
import { getPattern, instDef, patternsFor, styleDef } from '../engine/library';
import { fitsStyle } from '../engine/patterns';
import type { PatternDef } from '../engine/patterns';
import { ALL_ARTS, ART_LABEL, DEFAULT_KS, PROFILE_PRESETS } from '../engine/midi';
import type { ProfileId, VibTarget } from '../engine/midi';
import { noteName } from '../engine/theory';
import { isSectionPattern } from '../engine/horns';
import type { Track } from '../engine/arrange';

const DENSITY = ['', 'Sparse', 'Medium', 'Busy'];
const TABS: { id: Tab; label: string }[] = [
  { id: 'part', label: 'Part' },
  { id: 'feel', label: 'Feel' },
  { id: 'midi', label: 'MIDI' },
];

export function Inspector() {
  const s = useApp();
  const t = s.project.tracks.find((x) => x.id === s.selected);
  if (!t) {
    return (
      <aside className="inspector" aria-label="Inspector">
        <div className="empty">
          <strong>No player selected</strong>
          <p>Select a player to choose its part, shape its feel and set up its MIDI.</p>
        </div>
      </aside>
    );
  }
  const def = instDef(t.inst);
  const part = s.arr.parts[t.id];
  return (
    <aside className="inspector" aria-label="Inspector">
      <div className="insp-head" style={{ ['--tc' as string]: TRACK_COLORS[t.inst] }}>
        <div className="insp-title">
          <span className="swatch" />
          <h2>{def.name}</h2>
          <span className="insp-count">{part ? `${part.notes.length} notes` : ''}</span>
          <IconBtn label="Save this part as a MIDI file" onClick={() => void s.exportTrack(t.id)}>
            <DownloadSimple size={16} />
          </IconBtn>
          <IconBtn label="Remove this player" onClick={() => s.removeTrack(t.id)}>
            <Trash size={16} />
          </IconBtn>
        </div>
        {def.variants.length > 1 && (
          <select aria-label="Instrument type" value={t.variant} onChange={(e) => s.setVariant(t.id, e.target.value)}>
            {def.variants.map((v) => (
              <option key={v.id} value={v.id}>
                {v.name}
              </option>
            ))}
          </select>
        )}
        <div className="tabs" role="tablist">
          {TABS.map((tab) => (
            <button key={tab.id} type="button" role="tab" aria-selected={s.tab === tab.id} className={s.tab === tab.id ? 'is-on' : ''} onClick={() => s.setTab(tab.id)}>
              {tab.label}
            </button>
          ))}
        </div>
      </div>
      <div className="insp-body">
        {s.tab === 'part' && <PartTab t={t} />}
        {s.tab === 'feel' && <FeelTab t={t} />}
        {s.tab === 'midi' && <MidiTab t={t} />}
      </div>
    </aside>
  );
}

function PartTab({ t }: { t: Track }) {
  const s = useApp();
  const style = s.project.style;
  const all = patternsFor(t.inst);
  const fit = all.filter((p) => fitsStyle(p, style));
  const rest = all.filter((p) => !fitsStyle(p, style));
  const takes = s.takes.filter((k) => k.inst === t.inst && getPattern(k.patternId));
  const section = isSectionPattern(t.patternId);

  const row = (p: PatternDef) => {
    const on = p.id === t.patternId;
    return (
      <button key={p.id} type="button" className={`recipe ${on ? 'is-on' : ''}`} aria-pressed={on} onClick={() => s.setPattern(t.id, p.id)}>
        <span className="recipe-name">{p.name}</span>
        <span className="recipe-meta">{DENSITY[p.density]}</span>
        {on && <span className="recipe-desc">{p.desc}</span>}
      </button>
    );
  };

  return (
    <>
      <div className="row-actions">
        <button type="button" className="btn" onClick={() => s.reroll(t.id, 'recipe')}>
          <DiceFive size={15} />
          New recipe
        </button>
        <button type="button" className="btn" onClick={() => s.reroll(t.id, 'take')}>
          <ArrowsClockwise size={15} />
          New take
        </button>
        <button type="button" className="btn" onClick={() => s.saveTake(t.id)} title="Keep this exact performance in your takes">
          <Star size={15} />
          Save
        </button>
      </div>
      {section && <p className="note">Horns on the same section recipe are voiced together and share one take, so they phrase and breathe as a section.</p>}

      <h3>Fits {styleDef(style).name}</h3>
      <div className="recipes">{fit.map(row)}</div>
      {rest.length > 0 && (
        <>
          <h3>From other styles</h3>
          <div className="recipes">{rest.map(row)}</div>
        </>
      )}

      <h3>Your saved takes</h3>
      {takes.length === 0 ? (
        <p className="note">Nothing saved for this instrument yet. A saved take remembers the recipe, the exact performance and its feel settings, and re-fits itself to whatever chords you give it.</p>
      ) : (
        <div className="recipes">
          {takes.map((k) => (
            <div key={k.id} className="take">
              <button type="button" className="take-main" onClick={() => s.applyTake(k, t.id)} title="Use this take">
                <Star size={13} weight="fill" />
                <span className="recipe-name">{k.name}</span>
                <span className="recipe-meta">{styleDef(k.style).name}</span>
              </button>
              <IconBtn label={`Delete ${k.name}`} onClick={() => s.deleteTake(k.id)}>
                <X size={13} />
              </IconBtn>
            </div>
          ))}
        </div>
      )}
      <Toggle label="Deal saved takes into Randomize band" hint="Unlocked players sometimes get one of your takes" checked={s.useTakes} onChange={s.setUseTakes} />
    </>
  );
}

function FeelTab({ t }: { t: Track }) {
  const s = useApp();
  const p = t.params;
  const fam = instDef(t.inst).family;
  const exprHint =
    fam === 'horn'
      ? 'Scoops, fall-offs, vibrato depth and grace notes.'
      : fam === 'bass'
        ? 'Slides into roots, hammer-ons and vibrato on long notes.'
        : fam === 'guitar'
          ? 'Slide-ins on stabs, slurs and vibrato on lead notes.'
          : fam === 'keys'
            ? 'Crushed grace notes and organ swell depth.'
            : 'Not used by this instrument.';
  const set = (key: keyof typeof p) => (v: number) => s.setParams(t.id, { [key]: v }, 'param' + t.id + key);
  return (
    <>
      <Slider id="p-cx" label="Complexity" value={p.complexity} onChange={set('complexity')} hint="How busy the part is: fills, ghost notes, variations between bars." />
      <Slider id="p-dy" label="Dynamics" value={p.dynamics} onChange={set('dynamics')} hint="Overall intensity: note velocities and the level of the dynamics curve." />
      <Slider id="p-hu" label="Humanize" value={p.humanize} onChange={set('humanize')} hint="Looseness of timing and touch. At zero the part sits exactly on the grid." />
      <Slider id="p-ex" label="Expression" value={p.expression} onChange={set('expression')} hint={exprHint} />
      <div className="field">
        <div className="field-head">
          <label>Octave</label>
        </div>
        <div className="segmented" role="group" aria-label="Octave">
          {[-1, 0, 1].map((o) => (
            <button key={o} type="button" className={p.octave === o ? 'is-on' : ''} aria-pressed={p.octave === o} onClick={() => s.setParams(t.id, { octave: o })}>
              {o === 0 ? 'Normal' : o > 0 ? 'Up' : 'Down'}
            </button>
          ))}
        </div>
      </div>
      <Slider id="p-gain" label="Preview volume" value={t.gain} onChange={(v) => s.setTrack(t.id, { gain: v }, 'gain' + t.id)} hint="Level of the built-in sound only. It does not change the MIDI." />
    </>
  );
}

function MidiTab({ t }: { t: Track }) {
  const s = useApp();
  const m = t.midi;
  const preset = PROFILE_PRESETS.find((x) => x.id === m.preset);
  const isDrums = t.inst === 'drums' || t.inst === 'perc';
  const toggleCC = (n: number) => s.setMidi(t.id, { dynCC: m.dynCC.includes(n) ? m.dynCC.filter((x) => x !== n) : [...m.dynCC, n].sort((a, b) => a - b) });
  return (
    <>
      <div className="field">
        <div className="field-head">
          <label htmlFor="m-preset">Controller mapping</label>
        </div>
        <select id="m-preset" value={m.preset} onChange={(e) => e.target.value !== 'custom' && s.setPreset(t.id, e.target.value as ProfileId)}>
          {PROFILE_PRESETS.map((x) => (
            <option key={x.id} value={x.id}>
              {x.name}
            </option>
          ))}
          {m.preset === 'custom' && <option value="custom">Custom</option>}
        </select>
        <p className="hint">{preset?.desc ?? 'Your own mapping. Pick a preset above to start again from a known layout.'}</p>
      </div>

      <div className="grid-2">
        <div className="field">
          <div className="field-head">
            <label>Channel</label>
          </div>
          <NumberBox label="MIDI channel" value={m.channel} min={1} max={16} onChange={(v) => s.setMidi(t.id, { channel: v })} />
        </div>
        <div className="field">
          <div className="field-head">
            <label>Program</label>
          </div>
          <NumberBox label="Program number" value={m.program + 1} min={1} max={128} onChange={(v) => s.setMidi(t.id, { program: v - 1 })} />
        </div>
      </div>
      <Toggle label="Send program change" hint="Selects the General MIDI sound at the start" checked={m.sendProgram} onChange={(v) => s.setMidi(t.id, { sendProgram: v })} />

      {!isDrums && (
        <>
          <h3>Dynamics</h3>
          <div className="field">
            <div className="field-head">
              <label>Send the dynamics curve to</label>
            </div>
            <div className="chips" role="group" aria-label="Dynamics controllers">
              {[
                [11, 'Expression'],
                [1, 'Mod wheel'],
                [2, 'Breath'],
                [7, 'Volume'],
              ].map(([n, name]) => (
                <button key={n} type="button" className={m.dynCC.includes(n as number) ? 'is-on' : ''} aria-pressed={m.dynCC.includes(n as number)} onClick={() => toggleCC(n as number)}>
                  CC{n} <small>{name}</small>
                </button>
              ))}
            </div>
          </div>
          <div className="grid-2">
            <div className="field">
              <div className="field-head">
                <label>Softest velocity</label>
              </div>
              <NumberBox label="Minimum velocity" value={m.velMin} min={1} max={m.velMax} onChange={(v) => s.setMidi(t.id, { velMin: v })} />
            </div>
            <div className="field">
              <div className="field-head">
                <label>Hardest velocity</label>
              </div>
              <NumberBox label="Maximum velocity" value={m.velMax} min={m.velMin} max={127} onChange={(v) => s.setMidi(t.id, { velMax: v })} />
            </div>
          </div>

          <h3>Vibrato and pitch</h3>
          <div className="grid-2">
            <div className="field">
              <div className="field-head">
                <label htmlFor="m-vib">Vibrato as</label>
              </div>
              <select id="m-vib" value={m.vibTarget} onChange={(e) => s.setMidi(t.id, { vibTarget: e.target.value as VibTarget })}>
                <option value="cc">A controller</option>
                <option value="bend">Pitch bend</option>
                <option value="aftertouch">Aftertouch</option>
                <option value="off">Off</option>
              </select>
            </div>
            {m.vibTarget === 'cc' && (
              <div className="field">
                <div className="field-head">
                  <label>Vibrato CC</label>
                </div>
                <NumberBox label="Vibrato controller number" value={m.vibCC} min={0} max={119} onChange={(v) => s.setMidi(t.id, { vibCC: v })} />
              </div>
            )}
            {m.vibTarget === 'bend' && (
              <div className="field">
                <div className="field-head">
                  <label>Depth, cents</label>
                </div>
                <NumberBox label="Vibrato depth in cents" value={Math.round(m.vibDepth * 100)} min={2} max={100} onChange={(v) => s.setMidi(t.id, { vibDepth: v / 100 })} />
              </div>
            )}
          </div>
          <Toggle label="Send pitch bends" hint="Slides, scoops and fall-offs" checked={m.sendBends} onChange={(v) => s.setMidi(t.id, { sendBends: v })} />
          {m.sendBends && (
            <div className="grid-2">
              <div className="field">
                <div className="field-head">
                  <label>Bend range, semitones</label>
                </div>
                <NumberBox label="Bend range in semitones" value={m.bendRange} min={1} max={24} onChange={(v) => s.setMidi(t.id, { bendRange: v })} />
              </div>
              <div className="field is-end">
                <Toggle label="Tell the synth" hint="Sends RPN 0" checked={m.sendBendRange} onChange={(v) => s.setMidi(t.id, { sendBendRange: v })} />
              </div>
            </div>
          )}
          {t.inst === 'keys' && <Toggle label="Send sustain pedal" hint="CC64, lifted and caught on each chord change" checked={m.pedal} onChange={(v) => s.setMidi(t.id, { pedal: v })} />}

          <h3>Articulations</h3>
          <Toggle label="Send keyswitches" hint="A short note before each change of articulation" checked={m.keyswitch} onChange={(v) => s.setMidi(t.id, { keyswitch: v })} />
          {m.keyswitch && (
            <div className="ks">
              {ALL_ARTS.map((a) => {
                const val = m.ksMap[a] ?? DEFAULT_KS[a];
                return (
                  <div key={a} className="ks-row">
                    <span>{ART_LABEL[a]}</span>
                    <NumberBox label={`${ART_LABEL[a]} keyswitch note`} value={val} min={0} max={127} onChange={(v) => s.setMidi(t.id, { ksMap: { ...m.ksMap, [a]: v } })} />
                    <code>{noteName(val)}</code>
                  </div>
                );
              })}
            </div>
          )}
        </>
      )}
      {isDrums && <p className="note">Drums and percussion use the General MIDI drum map on channel 10, which every drum instrument understands. Ghost notes, accents and fills are carried by velocity.</p>}
    </>
  );
}
