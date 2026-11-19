import { useEffect, useRef } from "react";
import { capture, engine } from "../app/controller";
import { useApp } from "../app/store";
import { LEAD_ID } from "../engine/types";

const WINDOW = 9; // seconds of history on screen
const LO = 26;
const HI = 100;
const DRUM_H = 46;

/**
 * Scrolling piano roll. Hollow rings are the keys you actually hit, the
 * accent bars are what Hamfist turned them into, grey bars are the layers.
 * Drawn on a canvas straight from the capture buffer, outside React.
 */
export function Roll() {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current!;
    const ctx = canvas.getContext("2d")!;
    let raf = 0;
    let w = 0;
    let h = 0;
    let colors = { accent: "#f50", ink: "#fff", ink3: "#888", line: "#333", strong: "#555" };

    const readTheme = () => {
      const cs = getComputedStyle(document.documentElement);
      const v = (n: string) => cs.getPropertyValue(n).trim();
      colors = { accent: v("--accent"), ink: v("--ink"), ink3: v("--ink-3"), line: v("--line"), strong: v("--line-strong") };
    };
    readTheme();
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    mq.addEventListener("change", readTheme);

    const resize = () => {
      const r = canvas.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      w = r.width;
      h = r.height;
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);
    resize();

    const still = window.matchMedia("(prefers-reduced-motion: reduce)");

    const draw = () => {
      raf = requestAnimationFrame(draw);
      if (!w || !h) return;
      const now = performance.now() / 1000;
      const nowX = w * 0.88;
      const pps = nowX / WINDOW;
      const x = (t: number) => nowX - (now - t) * pps;
      const rollH = h - DRUM_H - 8;
      const y = (p: number) => 6 + (1 - (p - LO) / (HI - LO)) * (rollH - 12);
      const layerIds = useApp.getState().layers.map((l) => l.id);

      ctx.clearRect(0, 0, w, h);

      // Bar lines, heavier where the chord changes.
      const grid = engine.getGrid();
      if (grid.playing && grid.bar > 0.2) {
        const first = Math.max(0, Math.ceil((now - WINDOW - grid.t0) / grid.bar));
        const last = Math.floor((now + 1.5 - grid.t0) / grid.bar);
        for (let b = first; b <= last; b++) {
          const gx = Math.round(x(grid.t0 + b * grid.bar)) + 0.5;
          ctx.strokeStyle = b % grid.span === 0 ? colors.strong : colors.line;
          ctx.globalAlpha = b % grid.span === 0 ? 0.5 : 1;
          ctx.beginPath();
          ctx.moveTo(gx, 0);
          ctx.lineTo(gx, h);
          ctx.stroke();
        }
        ctx.globalAlpha = 1;
      }

      // Layers first, the player on top.
      for (const pass of [0, 1]) {
        for (const n of capture.notes) {
          const isLead = n.layer === LEAD_ID;
          if ((pass === 1) !== isLead) continue;
          const x0 = x(n.start);
          const x1 = Math.min(x(Math.min(n.end, now)), nowX);
          if (x1 < 0 || x0 > nowX) continue;
          const yy = y(n.pitch);
          if (isLead) {
            ctx.fillStyle = colors.accent;
            ctx.globalAlpha = n.end > now ? 1 : 0.85;
            ctx.beginPath();
            ctx.roundRect(x0, yy - 3, Math.max(4, x1 - x0), 6, 3);
            ctx.fill();
          } else {
            const li = Math.max(0, layerIds.indexOf(n.layer));
            ctx.fillStyle = colors.ink;
            ctx.globalAlpha = Math.max(0.14, 0.42 - li * 0.06);
            ctx.beginPath();
            ctx.roundRect(x0, yy - 2, Math.max(3, x1 - x0), 4, 2);
            ctx.fill();
          }
        }
      }

      // The correction: from the key you hit to the note you got.
      ctx.lineWidth = 1;
      for (const l of capture.links) {
        const lx = x(l.time);
        if (lx < 0) continue;
        const age = now - l.time;
        ctx.globalAlpha = Math.max(0, 0.5 - age * 0.12);
        ctx.strokeStyle = colors.accent;
        ctx.beginPath();
        ctx.moveTo(lx, y(l.raw));
        ctx.lineTo(lx, y(l.pitch));
        ctx.stroke();
      }
      for (const hit of capture.hits) {
        const hx = x(hit.time);
        if (hx < -4 || hx > nowX + 2) continue;
        if (hit.kind === "raw") {
          ctx.globalAlpha = Math.max(0.15, 0.9 - (now - hit.time) * 0.25);
          ctx.strokeStyle = colors.ink3;
          ctx.beginPath();
          ctx.arc(hx, y(hit.pitch), 2.5, 0, Math.PI * 2);
          ctx.stroke();
        } else {
          ctx.globalAlpha = 0.2 + hit.vel * 0.45;
          ctx.fillStyle = colors.ink;
          ctx.fillRect(hx, h - 8 - hit.pitch * 5, 2, 4);
        }
      }
      ctx.globalAlpha = 1;

      // Now line, once there is something to read against it.
      if (grid.playing || capture.notes.length) {
        ctx.strokeStyle = colors.strong;
        ctx.beginPath();
        ctx.moveTo(Math.round(nowX) + 0.5, 0);
        ctx.lineTo(Math.round(nowX) + 0.5, h);
        ctx.stroke();
      }

      if (still.matches) {
        // Reduced motion: repaint twice a second instead of every frame.
        cancelAnimationFrame(raf);
        raf = window.setTimeout(() => (raf = requestAnimationFrame(draw)), 500) as unknown as number;
      }
    };
    raf = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(raf);
      ro.disconnect();
      mq.removeEventListener("change", readTheme);
    };
  }, []);

  return <canvas ref={ref} className="absolute inset-0 h-full w-full" aria-hidden />;
}
