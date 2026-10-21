// Static share cards (product brief §10): a picture of your rail travel, drawn on a canvas from Passport data,
// independent of the screen layout. 1080 × 1350 (4:5, fits most feeds and messages). Deliberately left out: times,
// ticket or booking details, train numbers, and anything about where you are now. Dates are month and year only.
import { decodePolyline, type LatLon } from '@clack/shared';

export const CARD_W = 1080;
export const CARD_H = 1350;

const C = { bg: '#0a0a0a', surface: '#161616', line: '#2a2a2a', text: '#ffffff', text2: '#a6a6a6', accent: '#f8d64a', onAccent: '#0a0a0a' };
const DISPLAY = "'Space Grotesk', 'Inter Variable', Inter, sans-serif";
const BODY = "'Inter Variable', Inter, -apple-system, sans-serif";

export interface CardRoute {
  /** Encoded polyline along the track, or null (then a straight line between the ends). */
  geometry: string | null;
  ends: LatLon[];
}
export interface CardStat {
  value: string;
  label: string;
}
export interface CardData {
  kicker: string;
  title: string;
  /** The big number and its unit ("1,429" "km"). */
  hero: { value: string; unit: string };
  stats: CardStat[];
  /** Short lines under the stats (milestones, operator). */
  notes: string[];
  routes: CardRoute[];
  /** Station names to label on the map (featured journey: the two ends). */
  labels?: { at: LatLon; text: string }[];
  tagline: string;
}

/** Shrinks the font until the text fits, then wraps to at most `lines` lines (ellipsis on the last). */
function fitText(g: CanvasRenderingContext2D, text: string, maxW: number, size: number, minSize: number, weight: number, family: string, lines = 2): { lines: string[]; size: number } {
  for (let s = size; s >= minSize; s -= 2) {
    g.font = `${weight} ${s}px ${family}`;
    if (g.measureText(text).width <= maxW) return { lines: [text], size: s };
  }
  g.font = `${weight} ${minSize}px ${family}`;
  const words = text.split(' ');
  const out: string[] = [];
  let cur = '';
  for (const w of words) {
    const next = cur ? `${cur} ${w}` : w;
    if (g.measureText(next).width <= maxW || !cur) cur = next;
    else {
      out.push(cur);
      cur = w;
    }
  }
  if (cur) out.push(cur);
  if (out.length > lines) {
    const kept = out.slice(0, lines);
    let last = kept[lines - 1]!;
    while (g.measureText(`${last}…`).width > maxW && last.length > 1) last = last.slice(0, -1);
    kept[lines - 1] = `${last}…`;
    return { lines: kept, size: minSize };
  }
  return { lines: out, size: minSize };
}

/** The routes, fitted into a box with an equirectangular projection (fine at country scale). */
function drawMap(g: CanvasRenderingContext2D, data: CardData, x: number, y: number, w: number, h: number) {
  g.save();
  g.beginPath();
  g.roundRect(x, y, w, h, 36);
  g.fillStyle = C.surface;
  g.fill();
  g.clip();
  const lines = data.routes.map((r) => {
    const pts = r.geometry ? decodePolyline(r.geometry) : r.ends;
    return pts.length > 1 ? pts : r.ends;
  });
  const all = lines.flat();
  if (all.length < 2) {
    // No map data: the dotted route motif instead of an empty box.
    g.strokeStyle = C.accent;
    g.lineWidth = 10;
    g.lineCap = 'round';
    g.setLineDash([2, 26]);
    g.beginPath();
    g.moveTo(x + w * 0.12, y + h * 0.7);
    g.bezierCurveTo(x + w * 0.35, y + h * 0.1, x + w * 0.65, y + h * 0.95, x + w * 0.88, y + h * 0.3);
    g.stroke();
    g.restore();
    return;
  }
  const lat0 = all.reduce((n, p) => n + p[0], 0) / all.length;
  const kx = Math.cos((lat0 * Math.PI) / 180);
  const px = (p: LatLon): [number, number] => [p[1] * kx, -p[0]];
  const xs = all.map((p) => px(p)[0]);
  const ys = all.map((p) => px(p)[1]);
  const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
  const pad = 90;
  const k = Math.min((w - pad * 2) / Math.max(x1 - x0, 0.05), (h - pad * 2) / Math.max(y1 - y0, 0.05));
  const ox = x + w / 2 - ((x0 + x1) / 2) * k;
  const oy = y + h / 2 - ((y0 + y1) / 2) * k;
  const to = (p: LatLon): [number, number] => {
    const [a, b] = px(p);
    return [ox + a * k, oy + b * k];
  };
  g.lineCap = 'round';
  g.lineJoin = 'round';
  for (const [width, color, alpha] of [
    [18, C.accent, 0.18],
    [7, C.accent, 1],
  ] as const) {
    g.strokeStyle = color;
    g.globalAlpha = alpha;
    g.lineWidth = width;
    for (const line of lines) {
      g.beginPath();
      line.forEach((p, i) => (i ? g.lineTo(...to(p)) : g.moveTo(...to(p))));
      g.stroke();
    }
  }
  g.globalAlpha = 1;
  for (const r of data.routes)
    for (const e of r.ends) {
      const [a, b] = to(e);
      g.beginPath();
      g.arc(a, b, 11, 0, Math.PI * 2);
      g.fillStyle = C.bg;
      g.fill();
      g.lineWidth = 5;
      g.strokeStyle = C.text;
      g.stroke();
    }
  for (const l of data.labels ?? []) {
    const [a, b] = to(l.at);
    g.font = `700 30px ${BODY}`;
    const tw = Math.min(g.measureText(l.text).width, w * 0.45);
    const lx = Math.max(x + 24, Math.min(a - tw / 2, x + w - tw - 24));
    const ly = b + (b < y + h / 2 ? -28 : 52);
    g.lineWidth = 8;
    g.strokeStyle = C.surface;
    g.strokeText(l.text, lx, ly, w * 0.45);
    g.fillStyle = C.text;
    g.fillText(l.text, lx, ly, w * 0.45);
  }
  g.restore();
}

function drawWordmark(g: CanvasRenderingContext2D, x: number, y: number, tagline: string) {
  const size = 44;
  const tile = size * 0.95;
  [...'clack'].forEach((ch, i) => {
    const tx = x + i * (tile + 6);
    g.beginPath();
    g.roundRect(tx, y, tile, tile * 1.18, 8);
    g.fillStyle = i === 4 ? C.accent : C.surface;
    g.fill();
    g.fillStyle = i === 4 ? C.onAccent : C.text;
    g.font = `800 ${size}px ${BODY}`;
    g.textAlign = 'center';
    g.fillText(ch, tx + tile / 2, y + tile * 0.86);
  });
  g.textAlign = 'left';
  g.fillStyle = C.text2;
  g.font = `700 24px ${BODY}`;
  g.fillText(tagline, x + 5 * (tile + 6) + 18, y + tile * 0.78);
}

export async function renderCard(canvas: HTMLCanvasElement, data: CardData): Promise<void> {
  // Draw with the app's fonts, not a fallback.
  await document.fonts?.ready;
  canvas.width = CARD_W;
  canvas.height = CARD_H;
  const g = canvas.getContext('2d')!;
  g.fillStyle = C.bg;
  g.fillRect(0, 0, CARD_W, CARD_H);
  const M = 72;
  const innerW = CARD_W - M * 2;

  g.fillStyle = C.accent;
  g.font = `800 28px ${BODY}`;
  g.fillText(data.kicker.toUpperCase(), M, 120);

  const title = fitText(g, data.title, innerW, 72, 44, 800, DISPLAY, 2);
  g.fillStyle = C.text;
  g.font = `800 ${title.size}px ${DISPLAY}`;
  title.lines.forEach((l, i) => g.fillText(l, M, 120 + 24 + title.size * (i + 1) * 1.05));
  const titleBottom = 120 + 24 + title.size * title.lines.length * 1.05;

  const mapY = titleBottom + 40;
  const mapH = 520 - (title.lines.length - 1) * 60;
  drawMap(g, data, M, mapY, innerW, mapH);

  let y = mapY + mapH + 160;
  g.fillStyle = C.text;
  g.font = `700 150px ${DISPLAY}`;
  g.fillText(data.hero.value, M - 6, y);
  const hw = g.measureText(data.hero.value).width;
  g.font = `700 54px ${DISPLAY}`;
  g.fillStyle = C.text2;
  g.fillText(data.hero.unit, M + hw + 12, y);

  y += 70;
  const colW = innerW / Math.max(1, data.stats.length);
  data.stats.forEach((st, i) => {
    const sx = M + i * colW;
    g.fillStyle = C.text;
    g.font = `700 56px ${DISPLAY}`;
    g.fillText(st.value, sx, y + 40, colW - 20);
    g.fillStyle = C.text2;
    g.font = `700 24px ${BODY}`;
    g.fillText(st.label.toUpperCase(), sx, y + 80, colW - 20);
  });

  y += 140;
  g.fillStyle = C.text;
  g.font = `600 30px ${BODY}`;
  for (const n of data.notes.slice(0, 2)) {
    g.fillText(n, M, y, innerW);
    y += 44;
  }

  drawWordmark(g, M, CARD_H - 120, data.tagline);
}
