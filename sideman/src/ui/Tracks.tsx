import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { ArrowsClockwise, DiceFive, DotsSixVertical, LockSimple, LockSimpleOpen, Plus } from '@phosphor-icons/react';
import { useApp } from './store';
import { IconBtn, Popover, TRACK_COLORS } from './bits';
import { drawRoll } from './roll';
import { BAR } from '../engine/types';
import type { InstId, Part } from '../engine/types';
import type { Track } from '../engine/arrange';
import { INSTRUMENTS, getPattern, instDef } from '../engine/library';
import { isSectionPattern } from '../engine/horns';
import { dragOut } from '../platform';
import { player } from '../audio/player';

const HEAD_W = 252;
const MIN_BAR = 104;

export function Tracks() {
  const project = useApp((s) => s.project);
  const arr = useApp((s) => s.arr);
  const selected = useApp((s) => s.selected);
  const theme = useApp((s) => s.theme);
  const playing = useApp((s) => s.playing);
  const togglePlay = useApp((s) => s.togglePlay);
  const addTrack = useApp((s) => s.addTrack);
  const scrollRef = useRef<HTMLDivElement>(null);
  const headRef = useRef<HTMLDivElement>(null);
  const [viewW, setViewW] = useState(900);
  const [scheme, setScheme] = useState('');

  // redraw the lanes when the system appearance flips
  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const fn = () => setScheme(mq.matches ? 'd' : 'l');
    mq.addEventListener('change', fn);
    return () => mq.removeEventListener('change', fn);
  }, []);

  useLayoutEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setViewW(el.clientWidth));
    ro.observe(el);
    setViewW(el.clientWidth);
    return () => ro.disconnect();
  }, []);

  const bars = Math.max(1, arr.bars);
  const laneW = Math.max(viewW - HEAD_W - 1, bars * MIN_BAR);
  const pxPerTick = arr.len ? laneW / arr.len : 0;

  // playhead: moved outside React so playback never re-renders the tree
  useEffect(() => {
    const el = headRef.current;
    if (!el) return;
    if (!playing) {
      el.style.opacity = '0';
      return;
    }
    let raf = 0;
    const tick = () => {
      const pos = player.position();
      if (pos >= 0) {
        el.style.opacity = '1';
        el.style.transform = `translateX(${HEAD_W + pos * pxPerTick}px)`;
        const sc = scrollRef.current;
        if (sc) {
          const x = HEAD_W + pos * pxPerTick;
          if (x > sc.scrollLeft + sc.clientWidth - 40 || x < sc.scrollLeft + HEAD_W) sc.scrollLeft = Math.max(0, x - HEAD_W - 40);
        }
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [playing, pxPerTick]);

  const chartBars = bars / Math.max(1, project.repeats);
  const labels = arr.spans.filter((sp) => sp.change || sp.t % (chartBars * BAR) === 0);

  return (
    <div className="tracks" ref={scrollRef}>
      <div className="tracks-inner" style={{ width: HEAD_W + laneW }}>
        <div className="ruler-row">
          <div className="corner" style={{ width: HEAD_W }}>
            <span>Players</span>
            <span className="corner-count">{project.tracks.length}</span>
          </div>
          <div
            className="ruler"
            style={{ width: laneW }}
            title="Click to play from here"
            onClick={(e) => {
              if (!arr.len) return;
              const rect = e.currentTarget.getBoundingClientRect();
              const tick = ((e.clientX - rect.left) / laneW) * arr.len;
              togglePlay(Math.floor(tick / BAR) * BAR);
            }}
          >
            {Array.from({ length: bars }, (_, i) => (
              <span key={i} className={`bar-no ${i % chartBars === 0 ? 'is-top' : ''}`} style={{ left: i * BAR * pxPerTick }}>
                {i + 1}
              </span>
            ))}
            {labels.map((sp, i) => (
              <span key={i} className={`chord ${sp.chord.nc ? 'is-nc' : ''}`} style={{ left: sp.t * pxPerTick }}>
                {sp.chord.sym}
              </span>
            ))}
          </div>
        </div>

        {project.tracks.map((t) => (
          <TrackRow key={t.id} track={t} part={arr.parts[t.id]} len={arr.len} laneW={laneW} selected={t.id === selected} theme={theme + scheme} anySolo={project.tracks.some((x) => x.solo)} />
        ))}

        {project.tracks.length > 0 && !arr.len && (
          <div className="empty is-over" style={{ left: HEAD_W, width: Math.max(200, viewW - HEAD_W) }}>
            <strong>No chords yet</strong>
            <p>Type a progression above, pick one from Progressions, or drop a MIDI file to read its chords.</p>
          </div>
        )}

        {!project.tracks.length && (
          <div className="empty" style={{ width: viewW }}>
            <strong>The stage is empty</strong>
            <p>Add a player to start building the band.</p>
          </div>
        )}

        <div className="add-row" style={{ width: HEAD_W }}>
          <Popover
            button={(open, toggle) => (
              <button type="button" className={`btn ghost ${open ? 'is-on' : ''}`} onClick={toggle} aria-haspopup="menu" aria-expanded={open}>
                <Plus size={15} />
                Add player
              </button>
            )}
          >
            {(close) => (
              <>
                {INSTRUMENTS.map((inst) => (
                  <button
                    key={inst.id}
                    type="button"
                    role="menuitem"
                    className="menu-item"
                    onClick={() => {
                      close();
                      addTrack(inst.id as InstId);
                    }}
                  >
                    <span className="swatch" style={{ background: TRACK_COLORS[inst.id] }} />
                    <span>{inst.name}</span>
                  </button>
                ))}
              </>
            )}
          </Popover>
        </div>
        <div className="playhead" ref={headRef} aria-hidden="true" />
      </div>
    </div>
  );
}

function TrackRow(props: { track: Track; part: Part | undefined; len: number; laneW: number; selected: boolean; theme: string; anySolo: boolean }) {
  const { track: t, part } = props;
  const s = useApp.getState();
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const def = instDef(t.inst);
  const pat = getPattern(t.patternId);
  const color = TRACK_COLORS[t.inst];
  const silent = t.mute || (props.anySolo && !t.solo);
  const section = isSectionPattern(t.patternId);

  useEffect(() => {
    const c = canvasRef.current;
    if (!c) return;
    const cs = getComputedStyle(c);
    drawRoll(c, part, {
      len: props.len,
      width: props.laneW,
      height: 72,
      color,
      grid: cs.getPropertyValue('--grid').trim() || 'rgba(128,128,128,0.12)',
      gridStrong: cs.getPropertyValue('--grid-strong').trim() || 'rgba(128,128,128,0.3)',
      muted: silent,
      drums: def.family === 'drums' || def.family === 'perc',
    });
  }, [part, props.len, props.laneW, color, silent, props.theme, def.family]);

  const drag = (e: React.DragEvent) => dragOut(e, props.len ? [{ name: s.midiName(t.id), data: s.midiBytes([t.id]) }] : []);
  const stop = (fn: () => void) => (e: React.MouseEvent) => {
    e.stopPropagation();
    fn();
  };

  return (
    <div className={`track ${props.selected ? 'is-selected' : ''} ${silent ? 'is-silent' : ''}`} onClick={() => s.select(t.id)}>
      <div className="track-head" style={{ width: HEAD_W, ['--tc' as string]: color }}>
        <div className="track-title">
          <strong>{def.name}</strong>
          {section && <span className="tag" title="Voiced together with the other horns on this recipe">Section</span>}
          <button type="button" className="recipe-link" onClick={stop(() => s.select(t.id, 'part'))} title="Choose a recipe from the library">
            {pat?.name.replace(/^(Section|Solo): /, '') ?? 'Choose a part'}
          </button>
        </div>
        <div className="track-btns">
          <IconBtn label={section ? 'New recipe for the whole section' : 'New recipe from the library'} onClick={stop(() => s.reroll(t.id, 'recipe'))}>
            <DiceFive size={15} />
          </IconBtn>
          <IconBtn label="New take of this recipe" onClick={stop(() => s.reroll(t.id, 'take'))}>
            <ArrowsClockwise size={15} />
          </IconBtn>
          <IconBtn label={t.locked ? 'Locked: Randomize band will keep this part' : 'Lock this part'} active={t.locked} onClick={stop(() => s.setTrack(t.id, { locked: !t.locked }))}>
            {t.locked ? <LockSimple size={15} weight="fill" /> : <LockSimpleOpen size={15} />}
          </IconBtn>
          <IconBtn label="Mute" active={t.mute} className="txt" onClick={stop(() => s.setTrack(t.id, { mute: !t.mute }))}>
            M
          </IconBtn>
          <IconBtn label="Solo" active={t.solo} className="txt" onClick={stop(() => s.setTrack(t.id, { solo: !t.solo }))}>
            S
          </IconBtn>
          <span className="grip" draggable onDragStart={drag} role="button" tabIndex={0} aria-label={`Drag ${def.name} MIDI`} title="Drag this part into your DAW or Finder">
            <DotsSixVertical size={16} weight="bold" />
          </span>
        </div>
      </div>
      <div className="lane" style={{ width: props.laneW }} draggable onDragStart={drag} title="Drag this part into your DAW or Finder">
        <canvas ref={canvasRef} style={{ width: props.laneW, height: 72 }} />
      </div>
    </div>
  );
}
