import type { ReactNode } from "react";

export function Slider({
  label,
  value,
  onChange,
  min = 0,
  max = 1,
  step = 0.01,
  accent = false,
  hint,
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  min?: number;
  max?: number;
  step?: number;
  accent?: boolean;
  hint?: string;
}) {
  const pos = ((value - min) / (max - min)) * 100;
  return (
    <label className="flex min-w-0 flex-col gap-0.5" title={hint}>
      <span className="flex items-baseline justify-between text-[11px] text-ink-3">
        <span>{label}</span>
        <span className="font-mono tabular-nums text-ink-2">{Math.round(pos)}</span>
      </span>
      <input
        type="range"
        className="slider"
        min={min}
        max={max}
        step={step}
        value={value}
        style={{ "--pos": `${pos}%`, "--fill": accent ? "var(--accent)" : "var(--ink-2)" } as React.CSSProperties}
        onChange={(e) => onChange(Number(e.target.value))}
      />
    </label>
  );
}

export function IconButton({
  label,
  onClick,
  active = false,
  children,
  className = "",
}: {
  label: string;
  onClick: () => void;
  active?: boolean;
  children: ReactNode;
  className?: string;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      aria-pressed={active}
      title={label}
      onClick={onClick}
      className={`grid h-7 w-7 shrink-0 place-items-center rounded-ctl border transition-[background-color,color,transform] duration-150 active:scale-[0.94] ${
        active ? "border-transparent bg-ink text-bg" : "border-line text-ink-2 hover:bg-raise hover:text-ink"
      } ${className}`}
    >
      {children}
    </button>
  );
}

export function Field({ label, children, className = "" }: { label: string; children: ReactNode; className?: string }) {
  return (
    <label className={`flex min-w-0 flex-col gap-0.5 ${className}`}>
      <span className="text-[11px] leading-none text-ink-3">{label}</span>
      {children}
    </label>
  );
}

export const pickClass =
  "pick h-7 min-w-0 rounded-ctl border border-line bg-raise pl-2 text-[12px] text-ink transition-colors hover:border-line-strong";
