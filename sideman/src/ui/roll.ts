// Canvas drawing for a track lane: notes shaded by velocity, articulations
// drawn differently, with the dynamics curve and pitch bends underneath.

import { BAR, BEAT } from '../engine/types';
import type { Part } from '../engine/types';

export interface RollOpts {
  len: number;
  width: number;
  height: number;
  color: string;
  grid: string;
  gridStrong: string;
  muted: boolean;
  drums: boolean;
}

function hexToRgb(hex: string): [number, number, number] {
  const h = hex.replace('#', '');
  const n = parseInt(h.length === 3 ? h.split('').map((c) => c + c).join('') : h, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

export function drawRoll(canvas: HTMLCanvasElement, part: Part | undefined, o: RollOpts): void {
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const W = Math.max(1, Math.floor(o.width));
  const H = Math.max(1, Math.floor(o.height));
  if (canvas.width !== W * dpr || canvas.height !== H * dpr) {
    canvas.width = W * dpr;
    canvas.height = H * dpr;
  }
  const g = canvas.getContext('2d');
  if (!g) return;
  g.setTransform(dpr, 0, 0, dpr, 0, 0);
  g.clearRect(0, 0, W, H);
  if (!o.len) return;
  const px = W / o.len;

  // grid
  for (let t = 0; t <= o.len; t += BEAT) {
    const bar = t % BAR === 0;
    g.fillStyle = bar ? o.gridStrong : o.grid;
    g.fillRect(Math.round(t * px), 0, 1, H);
  }
  if (!part || !part.notes.length) return;

  const [r, gr, b] = hexToRgb(o.color);
  const alphaScale = o.muted ? 0.35 : 1;
  const hasCurve = part.ctrl.some((c) => c.k === 'dyn');
  const curveH = hasCurve ? 14 : 0;
  const top = 5;
  const bottom = H - 5 - curveH;

  // vertical mapping
  let rows: Map<number, number> | null = null;
  let lo = 127;
  let hi = 0;
  if (o.drums) {
    const pitches = [...new Set(part.notes.map((n) => n.p))].sort((a, c) => a - c);
    rows = new Map(pitches.map((p, i) => [p, i]));
    lo = 0;
    hi = Math.max(1, pitches.length - 1);
  } else {
    for (const n of part.notes) {
      if (n.p < lo) lo = n.p;
      if (n.p > hi) hi = n.p;
    }
    if (hi - lo < 12) {
      const pad = Math.ceil((12 - (hi - lo)) / 2);
      lo -= pad;
      hi += pad;
    }
  }
  const span = Math.max(1, hi - lo);
  const noteH = Math.max(2, Math.min(6, (bottom - top) / (span + 1)));
  const yOf = (p: number) => {
    const v = rows ? rows.get(p) ?? 0 : p - lo;
    return bottom - noteH - (v / span) * (bottom - top - noteH);
  };

  for (const n of part.notes) {
    const x = n.t * px;
    const y = yOf(n.p);
    const a = (0.3 + (n.v / 127) * 0.7) * alphaScale;
    if (o.drums) {
      g.fillStyle = `rgba(${r},${gr},${b},${a})`;
      const s = n.v < 50 ? 2 : n.v > 104 ? 4 : 3;
      g.fillRect(Math.round(x), Math.round(y + (noteH - s) / 2), s, s);
      continue;
    }
    const w = Math.max(1.5, n.d * px - 0.6);
    if (n.art === 'ghost') {
      g.strokeStyle = `rgba(${r},${gr},${b},${0.8 * alphaScale})`;
      g.lineWidth = 1;
      g.strokeRect(x + 0.5, y + 0.5, Math.max(2, Math.min(w, 4)), noteH - 1);
    } else if (n.art === 'mute') {
      g.fillStyle = `rgba(${r},${gr},${b},${a * 0.75})`;
      g.fillRect(x, y + noteH * 0.25, w, Math.max(1.5, noteH * 0.5));
    } else {
      g.fillStyle = `rgba(${r},${gr},${b},${a})`;
      g.fillRect(x, y, w, noteH);
      if (n.art === 'fall') {
        // a tail dropping away from the note
        g.strokeStyle = `rgba(${r},${gr},${b},${0.8 * alphaScale})`;
        g.lineWidth = 1;
        g.beginPath();
        g.moveTo(x + w, y + noteH / 2);
        g.quadraticCurveTo(x + w + 5, y + noteH / 2 + 1, x + w + 7, y + noteH / 2 + 8);
        g.stroke();
      }
    }
  }

  // pitch bends as small notches above the curve area
  if (part.bends.length) {
    g.fillStyle = `rgba(${r},${gr},${b},${0.55 * alphaScale})`;
    let lastX = -10;
    for (const bd of part.bends) {
      if (Math.abs(bd.s) < 0.05) continue;
      const x = Math.round(bd.t * px);
      if (x === lastX) continue;
      lastX = x;
      const h = Math.min(8, Math.abs(bd.s) * 4);
      g.fillRect(x, bottom + 1, 1, h);
    }
  }

  // dynamics curve
  if (hasCurve) {
    const y0 = H - 3;
    const ch = curveH - 3;
    g.beginPath();
    let started = false;
    let lastV = 0;
    for (const c of part.ctrl) {
      if (c.k !== 'dyn') continue;
      const x = c.t * px;
      const y = y0 - c.v * ch;
      if (!started) {
        g.moveTo(x, y);
        started = true;
      } else {
        g.lineTo(x, y0 - lastV * ch);
        g.lineTo(x, y);
      }
      lastV = c.v;
    }
    g.lineTo(W, y0 - lastV * ch);
    g.strokeStyle = `rgba(${r},${gr},${b},${0.7 * alphaScale})`;
    g.lineWidth = 1;
    g.stroke();
    // vibrato as a wavy underline where it is active
    g.strokeStyle = `rgba(${r},${gr},${b},${0.5 * alphaScale})`;
    const vibs = part.ctrl.filter((c) => c.k === 'vib');
    for (let i = 0; i < vibs.length - 1; i++) {
      if (vibs[i].v <= 0.02 && vibs[i + 1].v <= 0.02) continue;
      const xa = vibs[i].t * px;
      const xb = vibs[i + 1].t * px;
      g.beginPath();
      for (let x = xa; x <= xb; x += 1) {
        const depth = vibs[i].v + ((vibs[i + 1].v - vibs[i].v) * (x - xa)) / Math.max(1, xb - xa);
        const y = top - 1 + Math.sin(x * 1.1) * depth * 2.2;
        if (x === xa) g.moveTo(x, y);
        else g.lineTo(x, y);
      }
      g.stroke();
    }
  }
}
