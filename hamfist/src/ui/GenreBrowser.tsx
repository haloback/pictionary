import { MagnifyingGlass, X } from "@phosphor-icons/react";
import { useEffect, useMemo, useRef, useState } from "react";
import { useApp } from "../app/store";
import { GENRES, GROUPS } from "../engine/genres";

export function GenreBrowser() {
  const genreId = useApp((s) => s.genreId);
  const setGenre = useApp((s) => s.setGenre);
  const [query, setQuery] = useState("");
  const [group, setGroup] = useState("All");
  const listRef = useRef<HTMLDivElement>(null);

  const shown = useMemo(() => {
    const q = query.trim().toLowerCase();
    return GENRES.filter((g) => (group === "All" || g.group === group) && (!q || g.name.toLowerCase().includes(q) || g.group.toLowerCase().includes(q)));
  }, [query, group]);

  // Arrow keys step through the visible list, so genres can be flipped mid-performance.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.code !== "ArrowDown" && e.code !== "ArrowUp") return;
      const tag = (e.target as HTMLElement).tagName;
      if (tag === "SELECT" || tag === "TEXTAREA" || (tag === "INPUT" && (e.target as HTMLInputElement).type !== "text")) return;
      if (!shown.length) return;
      e.preventDefault();
      const i = shown.findIndex((g) => g.id === useApp.getState().genreId);
      const next = shown[(i + (e.code === "ArrowDown" ? 1 : -1) + shown.length) % shown.length];
      setGenre(next.id);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [shown, setGenre]);

  useEffect(() => {
    listRef.current?.querySelector<HTMLElement>('[aria-current="true"]')?.scrollIntoView({ block: "nearest" });
  }, [genreId]);

  let lastGroup = "";
  return (
    <aside className="flex min-h-0 flex-col border-line bg-panel max-lg:max-h-[46dvh] max-lg:border-t lg:border-r">
      <div className="flex flex-col gap-2.5 p-3 pb-2">
        <label className="flex flex-col gap-1">
          <span className="flex items-baseline justify-between">
            <span className="text-[13px] font-semibold tracking-tight">Genres</span>
            <span className="font-mono text-[11px] tabular-nums text-ink-3">
              {shown.length === GENRES.length ? GENRES.length : `${shown.length} of ${GENRES.length}`}
            </span>
          </span>
          <span className="relative">
            <MagnifyingGlass size={14} className="pointer-events-none absolute left-2 top-1/2 -translate-y-1/2 text-ink-3" aria-hidden />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="bossa, drill, waltz"
              spellCheck={false}
              className="h-8 w-full select-text rounded-ctl border border-line bg-raise pl-7 pr-7 text-[12px] text-ink placeholder:text-ink-3"
            />
            {query && (
              <button
                type="button"
                aria-label="Clear search"
                onClick={() => setQuery("")}
                className="absolute right-1.5 top-1/2 grid h-5 w-5 -translate-y-1/2 place-items-center rounded-full text-ink-3 hover:text-ink"
              >
                <X size={12} weight="bold" />
              </button>
            )}
          </span>
        </label>

        <div className="scroll-x -mx-3 flex gap-1 px-3 [mask-image:linear-gradient(to_right,black_85%,transparent)]" role="tablist" aria-label="Genre groups">
          {["All", ...GROUPS].map((g) => (
            <button
              key={g}
              type="button"
              role="tab"
              aria-selected={group === g}
              onClick={() => setGroup(g)}
              className={`h-6 shrink-0 whitespace-nowrap rounded-full px-2.5 text-[11px] transition-colors duration-150 last:mr-8 ${
                group === g ? "bg-ink font-medium text-bg" : "border border-line text-ink-2 hover:text-ink"
              }`}
            >
              {g}
            </button>
          ))}
        </div>
      </div>

      <div ref={listRef} className="scroll-y min-h-0 flex-1 px-1.5 pb-3">
        {shown.length === 0 && (
          <div className="px-3 py-8 text-center text-ink-3">
            <p className="text-ink-2">No genre matches "{query}".</p>
            <button type="button" className="mt-2 text-ink underline underline-offset-2" onClick={() => { setQuery(""); setGroup("All"); }}>
              Show everything
            </button>
          </div>
        )}
        {shown.map((g) => {
          const head = group === "All" && !query && g.group !== lastGroup;
          lastGroup = g.group;
          const active = g.id === genreId;
          return (
            <div key={g.id}>
              {head && <div className="sticky top-0 z-[1] bg-panel px-2 pb-1 pt-3 text-[11px] font-medium text-ink-3">{g.group}</div>}
              <button
                type="button"
                aria-current={active}
                onClick={() => setGenre(g.id)}
                className={`group relative flex h-7 w-full items-center justify-between rounded-ctl px-2 text-left text-[12.5px] transition-colors duration-100 ${
                  active ? "bg-accent-soft font-medium text-ink" : "text-ink-2 hover:bg-raise hover:text-ink"
                }`}
              >
                {active && <span className="absolute inset-y-1.5 left-0 w-[3px] rounded-full bg-accent" />}
                <span className="truncate pl-1">{g.name}</span>
                <span className={`font-mono text-[10.5px] tabular-nums ${active ? "text-ink-2" : "text-ink-3"}`}>{g.bpm}</span>
              </button>
            </div>
          );
        })}
      </div>
    </aside>
  );
}
