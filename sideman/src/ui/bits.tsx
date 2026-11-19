import { useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';

export const TRACK_COLORS: Record<string, string> = {
  drums: '#8d97a6',
  perc: '#a79c8a',
  bass: '#45b3a3',
  guitar: '#7db868',
  keys: '#6a9be0',
  trumpet: '#dcb04a',
  alto: '#dd7d8f',
  tenor: '#a98ddb',
  trombone: '#cf9160',
  bari: '#7f93e0',
  flute: '#b6c468',
};

export function IconBtn(props: {
  label: string;
  onClick?: (e: React.MouseEvent) => void;
  active?: boolean;
  tone?: 'accent';
  disabled?: boolean;
  children: ReactNode;
  className?: string;
}) {
  return (
    <button
      type="button"
      className={`icon-btn ${props.active ? 'is-on' : ''} ${props.tone === 'accent' ? 'is-accent' : ''} ${props.className ?? ''}`}
      aria-label={props.label}
      aria-pressed={props.active}
      title={props.label}
      disabled={props.disabled}
      onClick={props.onClick}
    >
      {props.children}
    </button>
  );
}

export function Slider(props: {
  label: string;
  value: number;
  min?: number;
  max?: number;
  step?: number;
  onChange: (v: number) => void;
  format?: (v: number) => string;
  hint?: string;
  id: string;
}) {
  const { min = 0, max = 1, step = 0.01 } = props;
  const pct = ((props.value - min) / (max - min)) * 100;
  return (
    <div className="field">
      <div className="field-head">
        <label htmlFor={props.id}>{props.label}</label>
        <output>{props.format ? props.format(props.value) : Math.round(pct) + '%'}</output>
      </div>
      <input
        id={props.id}
        type="range"
        min={min}
        max={max}
        step={step}
        value={props.value}
        style={{ ['--pct' as string]: pct + '%' }}
        onChange={(e) => props.onChange(parseFloat(e.target.value))}
      />
      {props.hint && <p className="hint">{props.hint}</p>}
    </div>
  );
}

export function Toggle(props: { label: string; checked: boolean; onChange: (v: boolean) => void; hint?: string }) {
  return (
    <label className="toggle">
      <input type="checkbox" checked={props.checked} onChange={(e) => props.onChange(e.target.checked)} />
      <span className="toggle-track" aria-hidden="true" />
      <span className="toggle-text">
        {props.label}
        {props.hint && <small>{props.hint}</small>}
      </span>
    </label>
  );
}

/** Small anchored menu that closes on outside click or Escape. */
export function Popover(props: { button: (open: boolean, toggle: () => void) => ReactNode; children: (close: () => void) => ReactNode; align?: 'left' | 'right'; className?: string }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);
  return (
    <div className={`popover-wrap ${props.className ?? ''}`} ref={ref}>
      {props.button(open, () => setOpen((o) => !o))}
      {open && (
        <div className={`popover ${props.align === 'right' ? 'align-right' : ''}`} role="menu">
          {props.children(() => setOpen(false))}
        </div>
      )}
    </div>
  );
}

/** Number box that also responds to arrow keys and the scroll wheel. */
export function NumberBox(props: { value: number; min: number; max: number; onChange: (v: number) => void; label: string; suffix?: string; width?: number }) {
  const [text, setText] = useState(String(props.value));
  useEffect(() => setText(String(props.value)), [props.value]);
  const commit = (s: string) => {
    const v = parseInt(s, 10);
    if (Number.isFinite(v)) props.onChange(Math.max(props.min, Math.min(props.max, v)));
    else setText(String(props.value));
  };
  return (
    <span className="numbox" style={{ width: props.width }}>
      <input
        aria-label={props.label}
        inputMode="numeric"
        value={text}
        onChange={(e) => setText(e.target.value)}
        onBlur={(e) => commit(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === 'Enter') (e.target as HTMLInputElement).blur();
          if (e.key === 'ArrowUp') {
            e.preventDefault();
            props.onChange(Math.min(props.max, props.value + 1));
          }
          if (e.key === 'ArrowDown') {
            e.preventDefault();
            props.onChange(Math.max(props.min, props.value - 1));
          }
        }}
      />
      {props.suffix && <span className="numbox-suffix">{props.suffix}</span>}
    </span>
  );
}
