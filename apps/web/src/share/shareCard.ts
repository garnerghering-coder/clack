// Static share cards (product brief §10): a picture of your rail travel, drawn on a canvas from Passport data,
// independent of the screen layout. 1080 × 1350 (4:5, fits most feeds and messages). The map is a real one (an
// off-screen snapshot of the app's basemap, see mapSnapshot.ts) with a lines-only fallback; medals are the same
// ones as on the Passport. Deliberately left out: times, ticket or booking details, train numbers, and anything
// about where you are now. Dates are month and year only.
import { decodePolyline, type LatLon } from '@clack/shared';
import type { MapSnapshot } from './mapSnapshot';

export const CARD_W = 1080;
export const CARD_H = 1350;
/** The map's box on a stats card, in card pixels (the snapshot is taken at half this, at pixel ratio 2). */
export const MAP_BOX = { w: 952, h: 500 };

const C = { bg: '#0a0a0a', surface: '#161616', text: '#ffffff', text2: '#a6a6a6', accent: '#f8d64a', onAccent: '#0a0a0a' };
const DISPLAY = "'Space Grotesk', 'Inter Variable', Inter, sans-serif";
const BODY = "'Inter Variable', Inter, -apple-system, sans-serif";
const M = 64;

export interface CardRoute {
  /** Encoded polyline along the track, or null (then a straight line between the ends). */
  geometry: string | null;
  ends: LatLon[];
}
export interface CardStat {
  value: string;
  label: string;
}
/** A medal as drawn on the Passport: its SVG as an image (without the number) and the number drawn on top. */
export interface CardMedal {
  image: HTMLImageElement;
  number: string | null;
  label: string;
  sub: string;
}
export interface CardData {
  layout: 'stats' | 'medal';
  kicker: string;
  title: string;
  hero: { value: string; unit: string };
  stats: CardStat[];
  routes: CardRoute[];
  /** Station names to label on the map (featured journey: the two ends). */
  labels?: { at: LatLon; text: string }[];
  map?: MapSnapshot | null;
  /** A row of medals under the stats (stats layout), or the one big medal (medal layout). */
  medals?: CardMedal[];
  sub?: string;
  tagline: string;
}

/** Shrinks the font until the text fits, then wraps to at most `lines` lines (ellipsis on the last). */
function fitText(g: CanvasRenderingContext2D, text: string, maxW: number, size: number, minSize: number, weight: number, family: string, lines = 2): { lines: string[]; size: number } {
  for (let s = size; s >= minSize; s -= 2) {
    g.font = `${weight} ${s}px ${family}`;
    if (g.measureText(text).width <= maxW) return { lines: [text], size: s };
  }
  g.font = `${weight} ${minSize}px ${family}`;
  const out: string[] = [];
  let cur = '';
  for (const w of text.split(' ')) {
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

/** Dark card with a warm glow and faint guilloche rings, like the Passport's top card at night. */
function background(g: CanvasRenderingContext2D) {
  g.fillStyle = C.bg;
  g.fillRect(0, 0, CARD_W, CARD_H);
  const glow = g.createRadialGradient(CARD_W * 0.95, 0, 0, CARD_W * 0.95, 0, CARD_W);
  glow.addColorStop(0, 'rgba(248, 214, 74, 0.20)');
  glow.addColorStop(1, 'rgba(248, 214, 74, 0)');
  g.fillStyle = glow;
  g.fillRect(0, 0, CARD_W, CARD_H);
  g.save();
  g.strokeStyle = 'rgba(248, 214, 74, 0.05)';
  g.lineWidth = 1.5;
  for (let r = 40; r < 1500; r += 22) {
    g.beginPath();
    g.arc(CARD_W * 0.9, CARD_H * 0.05, r, 0, Math.PI * 2);
    g.stroke();
  }
  g.restore();
}

function wordmark(g: CanvasRenderingContext2D, x: number, y: number, size: number) {
  const tile = size * 0.95;
  [...'clack'].forEach((ch, i) => {
    const tx = x + i * (tile + 5);
    g.beginPath();
    g.roundRect(tx, y, tile, tile * 1.18, 7);
    g.fillStyle = i === 4 ? C.accent : '#1f1f1f';
    g.fill();
    g.fillStyle = i === 4 ? C.onAccent : C.text;
    g.font = `800 ${size}px ${BODY}`;
    g.textAlign = 'center';
    g.fillText(ch, tx + tile / 2, y + tile * 0.86);
  });
  g.textAlign = 'left';
  return x + 5 * (tile + 5);
}

function header(g: CanvasRenderingContext2D, data: CardData) {
  const end = wordmark(g, M, 52, 36);
  g.fillStyle = C.text2;
  g.font = `700 20px ${BODY}`;
  g.fillText(data.tagline, end + 14, 82);
  g.fillStyle = C.accent;
  g.font = `800 26px ${BODY}`;
  g.fillText(data.kicker.toUpperCase(), M, 168);
}

/** The map box: the real map snapshot when there is one, else the lines on a dark panel (or a motif). */
function drawMap(g: CanvasRenderingContext2D, data: CardData, x: number, y: number, w: number, h: number) {
  g.save();
  g.beginPath();
  g.roundRect(x, y, w, h, 32);
  g.fillStyle = C.surface;
  g.fill();
  g.clip();
  let place: ((p: LatLon, i: number) => [number, number]) | null = null;
  if (data.map) {
    // Cover the box, keeping the snapshot's aspect.
    const s = Math.max(w / data.map.width, h / data.map.height);
    const dw = data.map.width * s;
    const dh = data.map.height * s;
    const ox = x + (w - dw) / 2;
    const oy = y + (h - dh) / 2;
    g.drawImage(data.map.image, ox, oy, dw, dh);
    const pts = data.map.points;
    place = (_p, i) => [ox + pts[i]![0] * s, oy + pts[i]![1] * s];
  } else {
    const lines = data.routes.map((r) => (r.geometry ? decodePolyline(r.geometry) : r.ends)).filter((l) => l.length > 1);
    const all = lines.flat();
    if (all.length >= 2) {
      const lat0 = all.reduce((n, p) => n + p[0], 0) / all.length;
      const kx = Math.cos((lat0 * Math.PI) / 180);
      const px = (p: LatLon): [number, number] => [p[1] * kx, -p[0]];
      const xs = all.map((p) => px(p)[0]);
      const ys = all.map((p) => px(p)[1]);
      const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
      const k = Math.min((w - 180) / Math.max(x1 - x0, 0.05), (h - 180) / Math.max(y1 - y0, 0.05));
      const to = (p: LatLon): [number, number] => {
        const [a, b] = px(p);
        return [x + w / 2 + (a - (x0 + x1) / 2) * k, y + h / 2 + (b - (y0 + y1) / 2) * k];
      };
      g.lineCap = 'round';
      g.lineJoin = 'round';
      for (const [lw, alpha] of [
        [18, 0.18],
        [7, 1],
      ] as const) {
        g.strokeStyle = C.accent;
        g.globalAlpha = alpha;
        g.lineWidth = lw;
        for (const line of lines) {
          g.beginPath();
          line.forEach((p, i) => (i ? g.lineTo(...to(p)) : g.moveTo(...to(p))));
          g.stroke();
        }
      }
      g.globalAlpha = 1;
      place = (p) => to(p);
    } else {
      g.strokeStyle = C.accent;
      g.lineWidth = 10;
      g.lineCap = 'round';
      g.setLineDash([2, 26]);
      g.beginPath();
      g.moveTo(x + w * 0.12, y + h * 0.7);
      g.bezierCurveTo(x + w * 0.35, y + h * 0.1, x + w * 0.65, y + h * 0.95, x + w * 0.88, y + h * 0.3);
      g.stroke();
    }
  }
  if (place)
    (data.labels ?? []).forEach((l, i) => {
      const [a, b] = place!(l.at, i);
      g.font = `700 28px ${BODY}`;
      const tw = Math.min(g.measureText(l.text).width, w * 0.45);
      const lx = Math.max(x + 20, Math.min(a - tw / 2, x + w - tw - 20));
      const ly = b + (b < y + h / 2 ? -22 : 46);
      g.lineWidth = 7;
      g.strokeStyle = 'rgba(10,10,10,0.85)';
      g.strokeText(l.text, lx, ly, w * 0.45);
      g.fillStyle = C.text;
      g.fillText(l.text, lx, ly, w * 0.45);
    });
  g.restore();
  // A thin rim so the map reads as a window in the card.
  g.beginPath();
  g.roundRect(x + 0.5, y + 0.5, w - 1, h - 1, 32);
  g.strokeStyle = 'rgba(255,255,255,0.08)';
  g.lineWidth = 1;
  g.stroke();
}

/** A medal image (120 × 150 viewBox) with its number drawn in the card's font. */
function drawMedal(g: CanvasRenderingContext2D, md: CardMedal, x: number, y: number, w: number) {
  const s = w / 120;
  g.save();
  g.shadowColor = 'rgba(0,0,0,0.45)';
  g.shadowBlur = 18 * s;
  g.shadowOffsetY = 6 * s;
  g.drawImage(md.image, x, y, w, 150 * s);
  g.restore();
  if (md.number) {
    const long = md.number.length > 3;
    g.fillStyle = 'rgba(0,0,0,0.72)';
    g.font = `800 ${(long ? 21 : 26) * s}px ${DISPLAY}`;
    g.textAlign = 'center';
    g.fillText(md.number, x + 60 * s, y + (long ? 113 : 115) * s);
    g.textAlign = 'left';
  }
}

function statsRow(g: CanvasRenderingContext2D, stats: CardStat[], y: number, center = false) {
  const innerW = CARD_W - M * 2;
  const colW = innerW / Math.max(1, stats.length);
  stats.forEach((st, i) => {
    const sx = center ? M + i * colW + colW / 2 : M + i * colW;
    g.textAlign = center ? 'center' : 'left';
    g.fillStyle = C.text;
    g.font = `700 54px ${DISPLAY}`;
    g.fillText(st.value, sx, y, colW - 20);
    g.fillStyle = C.text2;
    g.font = `700 22px ${BODY}`;
    g.fillText(st.label.toUpperCase(), sx, y + 38, colW - 20);
  });
  g.textAlign = 'left';
}

export async function renderCard(canvas: HTMLCanvasElement, data: CardData): Promise<void> {
  // Draw with the app's fonts, not a fallback.
  await document.fonts?.ready;
  canvas.width = CARD_W;
  canvas.height = CARD_H;
  const g = canvas.getContext('2d')!;
  background(g);
  header(g, data);
  const innerW = CARD_W - M * 2;

  if (data.layout === 'medal') {
    const md = data.medals?.[0];
    if (md) drawMedal(g, md, CARD_W / 2 - 230, 210, 460);
    const title = fitText(g, data.title, innerW, 72, 44, 800, DISPLAY, 2);
    g.fillStyle = C.text;
    g.textAlign = 'center';
    g.font = `800 ${title.size}px ${DISPLAY}`;
    title.lines.forEach((l, i) => g.fillText(l, CARD_W / 2, 900 + title.size * i * 1.05));
    const after = 900 + title.size * (title.lines.length - 1) * 1.05;
    if (data.sub) {
      g.fillStyle = C.text2;
      g.font = `600 30px ${BODY}`;
      g.fillText(data.sub, CARD_W / 2, after + 56);
    }
    g.textAlign = 'left';
    g.fillStyle = 'rgba(255,255,255,0.08)';
    g.fillRect(M, after + 110, innerW, 2);
    statsRow(g, data.stats, after + 230, true);
    return;
  }

  const title = fitText(g, data.title, innerW, 72, 44, 800, DISPLAY, 2);
  g.fillStyle = C.text;
  g.font = `800 ${title.size}px ${DISPLAY}`;
  title.lines.forEach((l, i) => g.fillText(l, M, 172 + title.size * (i + 1) * 1.02));
  const titleBottom = 172 + title.size * title.lines.length * 1.02;
  const mapY = titleBottom + 30;
  const mapH = MAP_BOX.h - (title.lines.length - 1) * 70 - (data.medals?.length ? 0 : -40);
  drawMap(g, data, M, mapY, innerW, mapH);

  let y = mapY + mapH + 140;
  g.fillStyle = C.text;
  g.font = `700 140px ${DISPLAY}`;
  g.fillText(data.hero.value, M - 6, y);
  const hw = g.measureText(data.hero.value).width;
  g.font = `700 52px ${DISPLAY}`;
  g.fillStyle = C.text2;
  g.fillText(data.hero.unit, M + hw + 12, y);

  y += 78;
  statsRow(g, data.stats, y);

  const medals = (data.medals ?? []).slice(0, 4);
  if (medals.length) {
    const top = y + 74;
    const slot = innerW / 4;
    medals.forEach((md, i) => {
      const mx = M + i * slot;
      drawMedal(g, md, mx + (slot - 104) / 2, top, 104);
      g.textAlign = 'center';
      g.fillStyle = C.text;
      g.font = `700 20px ${BODY}`;
      g.fillText(md.label, mx + slot / 2, top + 150, slot - 12);
      g.textAlign = 'left';
    });
  }
}
