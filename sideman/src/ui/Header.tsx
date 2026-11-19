import { useEffect, useState } from 'react';
import {
  ArrowClockwise,
  ArrowCounterClockwise,
  CaretDown,
  DiceFive,
  DotsSixVertical,
  Export,
  FilePlus,
  FloppyDisk,
  FolderOpen,
  GearSix,
  ListMagnifyingGlass,
  Play,
  Trash,
  UsersThree,
  Repeat,
  Stop,
} from '@phosphor-icons/react';
import { useApp } from './store';
import { IconBtn, NumberBox, Popover, Toggle } from './bits';
import { STYLES, styleDef } from '../engine/library';
import { PROGRESSIONS } from '../engine/chart';
import { keyName, pcName } from '../engine/theory';
import { desktop, dragOut, isMac } from '../platform';
import { BAND_PRESETS } from '../engine/arrange';
import { GROOVE_COUNTS } from '../engine/livedrums';
import { bankTotal } from '../engine/phrasebank';

export function Toolbar() {
  const s = useApp();
  const p = s.project;
  const mod = isMac ? '⌘' : 'Ctrl+';
  return (
    <header className={`toolbar ${desktop && isMac ? 'has-lights' : ''}`}>
      <div className="brand">
        <span className="mark" aria-hidden="true">
          <i />
          <i />
          <i />
        </span>
        <input
          className="session-name"
          aria-label="Session name"
          value={p.name}
          spellCheck={false}
          onChange={(e) => s.update((q) => ({ ...q, name: e.target.value }), 'name')}
        />
      </div>

      <div className="transport">
        <button type="button" className={`play ${s.playing ? 'is-playing' : ''}`} onClick={() => s.togglePlay()} aria-label={s.playing ? 'Stop' : 'Play'} title={`${s.playing ? 'Stop' : 'Play'} (Space)`}>
          {s.playing ? <Stop weight="fill" size={15} /> : <Play weight="fill" size={15} />}
        </button>
        <IconBtn label={s.loop ? 'Loop is on' : 'Loop is off'} active={s.loop} onClick={() => s.setLoop(!s.loop)}>
          <Repeat size={16} />
        </IconBtn>
        <NumberBox label="Tempo" value={p.tempo} min={40} max={240} suffix="bpm" width={84} onChange={(v) => s.update((q) => ({ ...q, tempo: v }), 'tempo')} />
      </div>

      <div className="toolbar-right">
        <IconBtn label={`Undo (${mod}Z)`} disabled={!s.past.length} onClick={s.undo}>
          <ArrowCounterClockwise size={16} />
        </IconBtn>
        <IconBtn label={`Redo (${isMac ? '⇧⌘Z' : 'Ctrl+Shift+Z'})`} disabled={!s.future.length} onClick={s.redo}>
          <ArrowClockwise size={16} />
        </IconBtn>
        <button type="button" className="btn primary" onClick={s.randomizeAll} title="Deal a new band: every unlocked player gets a new part (R)">
          <DiceFive size={16} weight="fill" />
          Randomize band
        </button>
        <div
          className="drag-pill"
          draggable
          role="button"
          tabIndex={0}
          title="Drag the whole arrangement into your DAW or Finder as one multi-track MIDI file"
          onDragStart={(e) => dragOut(e, s.arr.len ? [{ name: s.midiName(), data: s.midiBytes() }] : [])}
        >
          <DotsSixVertical size={16} weight="bold" />
          Drag MIDI
        </div>
        <Popover
          align="right"
          button={(open, toggle) => (
            <button type="button" className={`btn ${open ? 'is-on' : ''}`} onClick={toggle} aria-haspopup="menu" aria-expanded={open}>
              <Export size={16} />
              File
              <CaretDown size={11} />
            </button>
          )}
        >
          {(close) => (
            <>
              <MenuItem icon={<Export size={15} />} label="Save MIDI file…" hint={`${mod}E`} onClick={() => (close(), void s.exportAll())} />
              <MenuItem icon={<Export size={15} />} label="Save each part as its own file…" onClick={() => (close(), void s.exportStems())} />
              <hr />
              <MenuItem icon={<FloppyDisk size={15} />} label="Save session…" hint={`${mod}S`} onClick={() => (close(), void s.saveSession())} />
              <MenuItem icon={<FolderOpen size={15} />} label="Open session, MIDI or chart…" hint={`${mod}O`} onClick={() => (close(), void s.openDialog())} />
              <MenuItem icon={<FilePlus size={15} />} label="New session" onClick={() => (close(), s.newSession())} />
            </>
          )}
        </Popover>
        <Popover
          align="right"
          button={(open, toggle) => (
            <IconBtn
              label="Sound and MIDI output"
              active={open || !!s.midiOutId}
              onClick={() => {
                toggle();
                void s.initMidi();
              }}
            >
              <GearSix size={17} />
            </IconBtn>
          )}
        >
          {() => <Settings />}
        </Popover>
      </div>
    </header>
  );
}

function MenuItem(props: { icon?: React.ReactNode; label: string; hint?: string; onClick: () => void }) {
  return (
    <button type="button" role="menuitem" className="menu-item" onClick={props.onClick}>
      {props.icon}
      <span>{props.label}</span>
      {props.hint && <kbd>{props.hint}</kbd>}
    </button>
  );
}

function Settings() {
  const s = useApp();
  useEffect(() => {
    void s.initMidi();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return (
    <div className="settings">
      <div className="field">
        <div className="field-head">
          <label htmlFor="midi-out">Live MIDI output</label>
        </div>
        <select id="midi-out" value={s.midiOutId ?? ''} onChange={(e) => s.setMidiOut(e.target.value || null)}>
          <option value="">None</option>
          {s.midiOutputs.map((o) => (
            <option key={o.id} value={o.id}>
              {o.name}
            </option>
          ))}
        </select>
        <p className="hint">
          {s.midiError ??
            (s.midiOutputs.length
              ? 'Playback is sent to this port on each track’s channel, with all controllers, so your own instruments play the parts.'
              : 'No MIDI ports found. On a Mac, enable the IAC Driver in Audio MIDI Setup to route into your DAW.')}
        </p>
      </div>
      <div className="field">
        <div className="field-head">
          <label htmlFor="engine">Preview sound</label>
        </div>
        <select id="engine" value={s.engine} onChange={(e) => s.setEngine(e.target.value as 'sampled' | 'sketch')}>
          <option value="sampled">Sampled instruments</option>
          <option value="sketch">Built-in synth</option>
        </select>
        <p className="hint">
          {s.engine === 'sampled'
            ? s.sampledState === 'missing'
              ? 'The sound bank is not installed in this build, so the built-in synth is playing instead.'
              : 'A General MIDI sound bank plays the performance exactly as the exported file carries it: expression, vibrato, bends and pedal.'
            : 'A light synthesised sketch of each instrument.'}
        </p>
      </div>
      <Toggle label="Mute preview sound" hint="Use when your own synths are playing" checked={s.previewMuted} onChange={s.setPreviewMuted} />
      <div className="field">
        <div className="field-head">
          <label htmlFor="theme">Appearance</label>
        </div>
        <select id="theme" value={s.theme} onChange={(e) => s.setTheme(e.target.value as 'auto' | 'light' | 'dark')}>
          <option value="auto">Match system</option>
          <option value="dark">Dark</option>
          <option value="light">Light</option>
        </select>
      </div>
      <p className="hint">
        The library holds {bankTotal().toLocaleString('en-US')} combinable phrases and {(GROOVE_COUNTS.grooveBars + GROOVE_COUNTS.fills).toLocaleString('en-US')} recorded drum bars. Recorded drumming comes from the Groove MIDI Dataset (Gillick et al., 2019), used under CC BY 4.0.
      </p>
    </div>
  );
}

function Bands({ close }: { close: () => void }) {
  const s = useApp();
  const [name, setName] = useState('');
  return (
    <div className="bands">
      <form
        className="bands-save"
        onSubmit={(e) => {
          e.preventDefault();
          s.saveBand(name);
          setName('');
        }}
      >
        <input aria-label="Name for the current band" placeholder="Name the current band" value={name} onChange={(e) => setName(e.target.value)} />
        <button type="submit" className="btn">
          Save
        </button>
      </form>
      <div className="menu-scroll">
        {s.bands.map((b) => (
          <div key={b.id} className="take">
            <button
              type="button"
              role="menuitem"
              className="menu-item is-tall"
              onClick={() => {
                close();
                s.applyBand(b);
              }}
            >
              <span>
                {b.name}
                <small>{b.desc}</small>
              </span>
            </button>
            <button type="button" className="icon-btn" aria-label={`Delete ${b.name}`} title={`Delete ${b.name}`} onClick={() => s.deleteBand(b.id)}>
              <Trash size={14} />
            </button>
          </div>
        ))}
        {s.bands.length > 0 && <hr />}
        {BAND_PRESETS.map((b) => (
          <button
            key={b.id}
            type="button"
            role="menuitem"
            className="menu-item is-tall"
            onClick={() => {
              close();
              s.applyBand(b);
            }}
          >
            <span>
              {b.name}
              <small>{b.desc}</small>
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}

export function SongBar() {
  const s = useApp();
  const p = s.project;
  // an empty chart is a starting point, not a mistake
  const blank = !p.chart.trim();
  const errors = blank ? [] : s.arr.errors;
  const style = styleDef(p.style);
  const swing = p.swing ?? style.swing;
  return (
    <section className="songbar" aria-label="Song">
      <div className="chart-field">
        <div className="field-head">
          <label htmlFor="chart">Chord progression</label>
          <span className={`chart-status ${errors.length ? 'is-error' : ''}`} role={errors.length ? 'alert' : undefined}>
            {blank ? 'Waiting for chords' : errors.length ? errors[0] : `${s.arr.bars / Math.max(1, p.repeats)} bars, played ${p.repeats} time${p.repeats === 1 ? '' : 's'} in ${keyName(s.arr.key)}`}
          </span>
        </div>
        <div className="chart-row">
          <input
            id="chart"
            className="chart-input"
            value={p.chart}
            spellCheck={false}
            autoComplete="off"
            placeholder="Dm7 G7 | Cmaj7 | Am7 . . D7 | %"
            onChange={(e) => s.setChart(e.target.value)}
          />
          <Popover
            align="right"
            button={(open, toggle) => (
              <button type="button" className={`btn ${open ? 'is-on' : ''}`} onClick={toggle} aria-haspopup="menu" aria-expanded={open} title="Ready-made bands for each genre">
                <UsersThree size={16} />
                Bands
              </button>
            )}
          >
            {(close) => <Bands close={close} />}
          </Popover>
          <Popover
            align="right"
            button={(open, toggle) => (
              <button type="button" className={`btn ${open ? 'is-on' : ''}`} onClick={toggle} aria-haspopup="menu" aria-expanded={open} title="Starter progressions">
                <ListMagnifyingGlass size={16} />
                Progressions
              </button>
            )}
          >
            {(close) => (
              <div className="menu-scroll">
                {PROGRESSIONS.map((pr) => (
                  <button
                    key={pr.name}
                    type="button"
                    role="menuitem"
                    className="menu-item is-tall"
                    onClick={() => {
                      close();
                      s.loadPreset(pr);
                    }}
                  >
                    <span>
                      {pr.name}
                      <small>{pr.text}</small>
                    </span>
                  </button>
                ))}
              </div>
            )}
          </Popover>
        </div>
        <p className="hint">
          Separate bars with <code>|</code>. Chords in one bar share it evenly, <code>.</code> holds a chord for another beat, <code>%</code> repeats the bar. You can also drop a MIDI file here to read its chords.
        </p>
      </div>

      <div className="song-fields">
        <div className="field">
          <div className="field-head">
            <label htmlFor="style">Genre</label>
          </div>
          <select id="style" value={p.style} onChange={(e) => s.setStyle(e.target.value)} title={style.desc}>
            {[...new Set(STYLES.map((st) => st.group))].map((group) => (
              <optgroup key={group} label={group}>
                {STYLES.filter((st) => st.group === group).map((st) => (
                  <option key={st.id} value={st.id}>
                    {st.name}
                  </option>
                ))}
              </optgroup>
            ))}
          </select>
        </div>
        <div className="field">
          <div className="field-head">
            <label htmlFor="key">Key</label>
          </div>
          <select
            id="key"
            value={p.key ? `${p.key.tonic}${p.key.minor ? 'm' : 'M'}` : 'auto'}
            onChange={(e) => {
              const v = e.target.value;
              s.update((q) => ({ ...q, key: v === 'auto' ? null : { tonic: parseInt(v, 10), minor: v.endsWith('m') } }));
            }}
          >
            <option value="auto">Auto: {keyName(s.arr.key)}</option>
            {[false, true].map((minor) =>
              Array.from({ length: 12 }, (_, pc) => (
                <option key={`${pc}${minor}`} value={`${pc}${minor ? 'm' : 'M'}`}>
                  {pcName(pc)} {minor ? 'minor' : 'major'}
                </option>
              )),
            )}
          </select>
        </div>
        <div className="field">
          <div className="field-head">
            <label>Repeats</label>
          </div>
          <NumberBox label="Repeats" value={p.repeats} min={1} max={16} suffix="×" width={64} onChange={(v) => s.update((q) => ({ ...q, repeats: v }), 'repeats')} />
        </div>
        <div className="field is-slider">
          <div className="field-head">
            <label htmlFor="swing">Swing</label>
            <output>{Math.round(swing * 100)}%</output>
          </div>
          <input
            id="swing"
            type="range"
            min={0}
            max={1}
            step={0.01}
            value={swing}
            style={{ ['--pct' as string]: swing * 100 + '%' }}
            onChange={(e) => s.update((q) => ({ ...q, swing: parseFloat(e.target.value) }), 'swing')}
          />
        </div>
        <div className="field is-slider">
          <div className="field-head">
            <label htmlFor="energy">Energy</label>
            <output>{Math.round(p.energy * 100)}%</output>
          </div>
          <input
            id="energy"
            type="range"
            min={0}
            max={1}
            step={0.01}
            value={p.energy}
            style={{ ['--pct' as string]: p.energy * 100 + '%' }}
            onChange={(e) => s.update((q) => ({ ...q, energy: parseFloat(e.target.value) }), 'energy')}
          />
        </div>
      </div>
    </section>
  );
}
