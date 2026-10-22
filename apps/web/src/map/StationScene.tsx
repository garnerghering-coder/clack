// The station map (ADDITIONS_01 C1): an SVG scene, not MapLibre: a designed, schematic plan of one level at a
// time with pan, pinch and wheel zoom. Geometry is in metres (data/stations/*.json); labels and pins keep their
// screen size and stay upright however the plan is rotated or zoomed.
import { memo, useEffect, useMemo, useRef, useState, type ReactElement } from 'react';
import {
  Armchair,
  ArrowUpDown,
  Banknote,
  ShoppingBasket,
  Bus,
  CarTaxiFront,
  Coffee,
  Info,
  Luggage,
  MapPin,
  Pill,
  ShoppingBag,
  Ticket,
  Toilet,
  UtensilsCrossed,
  type LucideIcon,
} from 'lucide-react';
import type { OpenState, PoiCategory, Pt, StationMap, StationPoi, StationRoute } from '@clack/shared';

export const POI_ICONS: Record<PoiCategory, LucideIcon> = {
  toilet: Toilet,
  cafe: Coffee,
  restaurant: UtensilsCrossed,
  kiosk: ShoppingBasket,
  shop: ShoppingBag,
  ticket: Ticket,
  locker: Luggage,
  waiting: Armchair,
  info: Info,
  pharmacy: Pill,
  atm: Banknote,
  taxi: CarTaxiFront,
  bus: Bus,
  other: MapPin,
};

/**
 * One pictogram per kind of place (owner feedback 2026-10-21: standard icons, not one per brand or cuisine), so a
 * café always looks like a café. Kiosks and convenience stores share the basket.
 */
export const poiIcon = (p: { category: PoiCategory }): LucideIcon => POI_ICONS[p.category];

export interface PlatformMark {
  platformId: string;
  label: string;
  color: string;
}

/** A walk's start or end that isn't a platform: an amenity, an entrance, or the walker ("me"). */
export interface PlacePin {
  x: number;
  y: number;
  level: string;
  label: string;
  kind: 'from' | 'to' | 'me';
}

interface View {
  tx: number;
  ty: number;
  k: number;
}

const rotate = (p: Pt, deg: number): Pt => {
  const r = (deg * Math.PI) / 180;
  return [p[0] * Math.cos(r) - p[1] * Math.sin(r), p[0] * Math.sin(r) + p[1] * Math.cos(r)];
};

/** World points of one route step, for drawing. */
function stepPoints(m: StationMap, step: StationRoute['steps'][number]): Pt[] {
  const g = step.edge.geometry;
  const pts: Pt[] = g && g.length > 1 ? g : [[step.from.x, step.from.y], [step.to.x, step.to.y]];
  // Edge geometry runs from → to as stored; flip when the route walks it the other way.
  return step.edge.from === step.from.id ? pts : [...pts].reverse();
}

export function StationScene({
  map,
  level,
  route,
  marks,
  pins = [],
  poiState,
  dimPoi,
  onPoi,
  onPlatform,
  fitTo,
  selectedPoi = null,
  insets: insetsIn = { top: 130, bottom: 140 },
}: {
  map: StationMap;
  level: string;
  route: StationRoute | null;
  marks: PlatformMark[];
  pins?: PlacePin[];
  poiState: (p: StationPoi) => OpenState;
  dimPoi: (p: StationPoi) => boolean;
  onPoi: (p: StationPoi) => void;
  onPlatform: (platformId: string) => void;
  /** Change this to re-fit the view (e.g. when a route appears). */
  fitTo: string;
  /** The place whose sheet is open: its outline (when it has one) is highlighted. */
  selectedPoi?: string | null;
  /** Screen space taken by overlays at the top and bottom, kept clear when fitting. */
  insets?: { top: number; bottom: number; right?: number };
}) {
  // The floor buttons down the right-hand side.
  const insets = { right: 60, ...insetsIn };
  const el = useRef<SVGSVGElement>(null);
  const rot = map.view?.rotation ?? 0;
  const [size, setSize] = useState({ w: 393, h: 700 });
  const [view, setView] = useState<View>({ tx: 0, ty: 0, k: 1 });
  const moved = useRef(false);

  useEffect(() => {
    const svg = el.current;
    if (!svg) return;
    const ro = new ResizeObserver(() => setSize({ w: svg.clientWidth, h: svg.clientHeight }));
    ro.observe(svg);
    return () => ro.disconnect();
  }, []);

  // Fit the route, or else the halls with their amenities.
  useEffect(() => {
    // The halls are where the amenities are; the outline of the whole station runs far along the tracks.
    const pois = map.pois.map((p) => [p.x, p.y] as Pt);
    // Just one end chosen so far: centre on it (and its chip) with some of the surroundings.
    const ends: Pt[] = [
      ...pins.filter((p) => p.level === level).map((p) => [p.x, p.y] as Pt),
      ...marks.flatMap((mk) => {
        const pl = map.platforms.find((x) => x.id === mk.platformId);
        const n = pl && pl.level === level ? map.nodes.find((x) => x.id === pl.node) : null;
        return n ? [[n.x, n.y] as Pt] : [];
      }),
    ];
    const pts: Pt[] = route?.nodes.length ? route.nodes.map((n) => [n.x, n.y] as Pt) : ends.length ? ends : pois.length ? pois : map.platforms.flatMap((p) => p.geometry.flat());
    if (!pts.length) return;
    const r = pts.map((p) => rotate(p, rot));
    const xs = r.map((p) => p[0]).sort((a, b) => a - b);
    const ys = r.map((p) => p[1]).sort((a, b) => a - b);
    // Without a route: the middle 70 % of the amenities plus 25 m (a few sit far out along the platforms).
    const q = (v: number[], f: number) => v[Math.min(v.length - 1, Math.max(0, Math.round(f * (v.length - 1))))]!;
    const [x0, x1, y0, y1] = route?.nodes.length
      ? [xs[0]!, xs.at(-1)!, ys[0]!, ys.at(-1)!]
      : ends.length
        ? [xs[0]! - 60, xs.at(-1)! + 60, ys[0]! - 60, ys.at(-1)! + 60]
        : [q(xs, 0.15) - 25, q(xs, 0.85) + 25, q(ys, 0.15) - 25, q(ys, 0.85) + 25];
    // Routes leave room at the sides for the arrive / depart chips; a short walk isn't zoomed in all the way.
    const [padX, padY] = route ? [marks.length ? 110 : 70, 40] : [16, 16];
    const w = size.w - insets.right - padX * 2;
    const h = size.h - insets.top - insets.bottom - padY * 2;
    const k = Math.min(route ? 9 : 40, Math.max(0.5, w / Math.max(x1 - x0, 20)), Math.max(0.5, h / Math.max(y1 - y0, 20)));
    setView({ k, tx: padX + w / 2 - ((x0 + x1) / 2) * k, ty: insets.top + padY + h / 2 - ((y0 + y1) / 2) * k });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fitTo, size.w, size.h, map, insets.top, insets.bottom, insets.right]);

  // ---- Pan and zoom: one finger pans, two pinch, the wheel zooms around the pointer ----
  const pointers = useRef(new Map<number, { x: number; y: number }>());
  const onDown = (e: React.PointerEvent) => {
    (e.target as Element).setPointerCapture?.(e.pointerId);
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
    moved.current = false;
  };
  const onMove = (e: React.PointerEvent) => {
    const ps = pointers.current;
    const prev = ps.get(e.pointerId);
    if (!prev) return;
    const next = { x: e.clientX, y: e.clientY };
    if (ps.size === 1) {
      const dx = next.x - prev.x;
      const dy = next.y - prev.y;
      if (Math.abs(dx) + Math.abs(dy) > 1) moved.current = true;
      setView((v) => ({ ...v, tx: v.tx + dx, ty: v.ty + dy }));
    } else if (ps.size === 2) {
      const [a, b] = [...ps.entries()].map(([id, p]) => (id === e.pointerId ? next : p)) as [{ x: number; y: number }, { x: number; y: number }];
      const [pa, pb] = [...ps.values()] as [{ x: number; y: number }, { x: number; y: number }];
      const d0 = Math.hypot(pa.x - pb.x, pa.y - pb.y);
      const d1 = Math.hypot(a.x - b.x, a.y - b.y);
      const rect = el.current!.getBoundingClientRect();
      const cx = (a.x + b.x) / 2 - rect.left;
      const cy = (a.y + b.y) / 2 - rect.top;
      zoomAt(cx, cy, d0 > 0 ? d1 / d0 : 1);
      moved.current = true;
    }
    ps.set(e.pointerId, next);
  };
  const onUp = (e: React.PointerEvent) => pointers.current.delete(e.pointerId);
  const zoomAt = (cx: number, cy: number, f: number) =>
    setView((v) => {
      const k = Math.min(40, Math.max(0.3, v.k * f));
      const g = k / v.k;
      return { k, tx: cx - (cx - v.tx) * g, ty: cy - (cy - v.ty) * g };
    });
  useEffect(() => {
    const svg = el.current;
    if (!svg) return;
    const wheel = (e: WheelEvent) => {
      e.preventDefault();
      const rect = svg.getBoundingClientRect();
      zoomAt(e.clientX - rect.left, e.clientY - rect.top, Math.exp(-e.deltaY / 400));
    };
    svg.addEventListener('wheel', wheel, { passive: false });
    return () => svg.removeEventListener('wheel', wheel);
  }, []);
  const tap = (fn: () => void) => () => {
    if (!moved.current) fn();
  };

  const transform = `translate(${view.tx} ${view.ty}) scale(${view.k}) rotate(${rot})`;
  /** Keeps a label upright and at screen size at a world point. */
  const at = (x: number, y: number) => `translate(${x} ${y}) rotate(${-rot}) scale(${1 / view.k})`;
  const routeOnLevel = route?.steps.filter((s) => s.from.level === level && s.to.level === level) ?? [];
  const levelChanges = route?.steps.filter((s) => s.from.level !== s.to.level) ?? [];
  const markFor = new Map(marks.map((m) => [m.platformId, m]));
  const platformChips = useMemo(() => {
    const chips: { id: string; x: number; y: number; label: string; mark?: PlatformMark; sx: number; sy: number }[] = [];
    for (const p of map.platforms.filter((p) => p.level === level)) {
      const n = map.nodes.find((x) => x.id === p.node)!;
      const [sx, sy] = rotate([n.x, n.y], rot).map((v) => v * view.k) as Pt;
      const mk = markFor.get(p.id);
      const near = mk ? undefined : chips.find((c) => !c.mark && Math.hypot(c.sx - sx, c.sy - sy) < 28);
      if (near) near.label = [near.label, p.ref].sort((a, b) => Number(a) - Number(b)).join('/');
      else chips.push({ id: p.id, x: n.x, y: n.y, label: mk ? mk.label : p.ref, mark: mk, sx, sy });
    }
    // Arrive / depart chips win: drawn last, and plain numbers right under them are left out.
    const marked = chips.filter((c) => c.mark);
    return [...chips.filter((c) => !c.mark && !marked.some((m) => Math.abs(m.sx - c.sx) < ((m.label.length * 6.6 + 16) / 2 + 14) && Math.abs(m.sy - c.sy) < 24)), ...marked];
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map, level, view.k, rot, marks]);
  // Pins that would overlap at this zoom: keep one per 26 px cell, toilets and open places first.
  const shownPois = useMemo(() => {
    const rank = (p: StationPoi) => (p.category === 'toilet' ? 0 : 1) * 10 + ({ open: 0, closing_soon: 1, unknown: 2, closed: 3 } as const)[poiState(p)] + (dimPoi(p) ? 20 : 0);
    const taken = new Set<string>();
    const out = new Set<string>();
    for (const p of [...map.pois].filter((p) => p.level === level).sort((a, b) => rank(a) - rank(b))) {
      const [x, y] = rotate([p.x, p.y], rot);
      const cell = `${Math.round((x * view.k) / 26)},${Math.round((y * view.k) / 26)}`;
      if (taken.has(cell)) continue;
      taken.add(cell);
      out.add(p.id);
    }
    // Names only when zoomed in, and only where one fits: one per 96 × 30 px cell, below its pin.
    const named = new Set<string>();
    if (view.k > 3.2) {
      const slots = new Set<string>();
      for (const p of [...map.pois].filter((p) => out.has(p.id) && p.name).sort((a, b) => rank(a) - rank(b))) {
        const [x, y] = rotate([p.x, p.y], rot);
        const cell = `${Math.round((x * view.k) / 96)},${Math.round((y * view.k + 24) / 30)}`;
        if (slots.has(cell)) continue;
        slots.add(cell);
        named.add(p.id);
      }
    }
    return { shown: out, named };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [map, level, view.k, rot, poiState, dimPoi]);

  return (
    <svg ref={el} className="station-scene" onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp} role="img" aria-label={map.name}>
      <g transform={transform}>
        <Plan map={map} level={level} k={view.k} />
        {/* The open place's unit, outlined over the plan. */}
        {map.pois
          .filter((p) => p.id === selectedPoi && p.level === level && p.outline)
          .map((p) => (
            <polygon key={`sel${p.id}`} points={p.outline!.map((q) => q.join(',')).join(' ')} className="station-unit selected" strokeWidth={2 / view.k} />
          ))}
        {/* The route: dots marching toward the destination (static with reduced motion). */}
        {routeOnLevel.length > 0 && (
          <g className="station-path">
            {routeOnLevel.map((s, i) => {
              const d = stepPoints(map, s).map((p) => p.join(',')).join(' ');
              return (
                <g key={i}>
                  <polyline points={d} className="station-path-glow" strokeWidth={10 / view.k} />
                  <polyline points={d} className="station-path-dots" strokeWidth={4.5 / view.k} strokeDasharray={`0 ${10 / view.k}`} />
                </g>
              );
            })}
          </g>
        )}
        {/* Where the route changes level: a glyph on this level. */}
        {levelChanges
          .filter((s) => s.from.level === level || s.to.level === level)
          .map((s, i) => {
            const n = s.from.level === level ? s.from : s.to;
            return (
              <g key={`lc${i}`} transform={at(n.x, n.y)} className="station-level-change">
                <circle r={11} />
                <ArrowUpDown x={-7} y={-7} width={14} height={14} strokeWidth={2.2} />
              </g>
            );
          })}
        {/* Platforms: their number (island halves that would overlap share one chip), or the arrive / depart chip. */}
        {platformChips.map((c) => {
          const w = c.mark ? Math.max(40, c.label.length * 6.6 + 16) : Math.max(22, c.label.length * 7.5 + 10);
          return (
            <g key={c.id} transform={at(c.x, c.y)} className={c.mark ? 'station-platform-chip marked' : 'station-platform-chip'} onClick={tap(() => onPlatform(c.id))}>
              <rect x={-w / 2} y={-11} width={w} height={22} rx={11} style={c.mark ? { fill: c.mark.color } : undefined} />
              <text y={4}>{c.label}</text>
            </g>
          );
        })}
        {/* Amenities: open = bright with a green dot, closing soon = amber dot, closed = dim, unknown = "?". */}
        {map.pois
          .filter((p) => p.level === level && shownPois.shown.has(p.id))
          .map((p) => {
            const st = poiState(p);
            const Icon = poiIcon(p);
            const dim = dimPoi(p) || st === 'closed';
            return (
              <g key={p.id} transform={at(p.x, p.y)} className={`station-poi cat-${p.category}${dim ? ' dim' : ''}`} onClick={tap(() => onPoi(p))} role="button" aria-label={p.name || p.category}>
                <circle r={12} />
                <Icon x={-7.5} y={-7.5} width={15} height={15} strokeWidth={2} />
                {shownPois.named.has(p.id) && (
                  <text y={24} className="station-poi-name">
                    {p.name.length > 18 ? `${p.name.slice(0, 17)}…` : p.name}
                  </text>
                )}
                {st === 'unknown' ? (
                  <text x={9} y={-6} className="station-poi-q">
                    ?
                  </text>
                ) : (
                  <circle cx={9} cy={-9} r={3.6} className={`station-poi-dot ${st}`} />
                )}
              </g>
            );
          })}
        {/* Start / end pins for points that aren't platforms, drawn on top. */}
        {pins
          .filter((p) => p.level === level)
          .map((p, i) => {
            const w = Math.min(190, p.label.length * 6.4 + 18);
            return (
              <g key={`pin${i}`} transform={at(p.x, p.y)} className={`station-pin ${p.kind}`}>
                {p.kind === 'me' && <circle r={16} className="station-pin-halo" />}
                <circle r={6.5} className="station-pin-dot" />
                <g transform="translate(0 -24)">
                  <rect x={-w / 2} y={-11} width={w} height={22} rx={11} />
                  <text y={4}>{p.label.length > 28 ? `${p.label.slice(0, 27)}…` : p.label}</text>
                </g>
              </g>
            );
          })}
      </g>
    </svg>
  );
}

/** The static plan of a level (memoised: panning doesn't redraw it). Other levels show as a faint ghost. */
const Plan = memo(function Plan({ map, level, k }: { map: StationMap; level: string; k: number }): ReactElement {
  const poly = (pts: Pt[]) => pts.map((p) => p.join(',')).join(' ');
  const onLevel = map.shapes.filter((s) => s.level === level);
  return (
    <g>
      {map.shapes
        .filter((s) => s.kind === 'building')
        .map((s, i) => (
          <polygon key={`b${i}`} points={poly(s.points)} className="station-building" />
        ))}
      {/* Other levels' platforms, for orientation. */}
      {map.platforms
        .filter((p) => p.level !== level)
        .flatMap((p) => p.geometry.map((g, i) => <polygon key={`g${p.id}${i}`} points={poly(g)} className="station-ghost" />))}
      {onLevel
        .filter((s) => s.kind === 'hall' || s.kind === 'room' || s.kind === 'shop')
        .map((s, i) => (
          <polygon key={`s${i}`} points={poly(s.points)} className={`station-${s.kind}`} strokeWidth={0.6 / k} />
        ))}
      {onLevel
        .filter((s) => s.kind === 'track')
        .map((s, i) => (
          <polyline key={`t${i}`} points={poly(s.points)} className="station-track" strokeWidth={1.1 / k} />
        ))}
      {/* Places mapped as their own unit (a shop's room) are drawn in their real shape, tinted by kind. */}
      {map.pois
        .filter((p) => p.level === level && p.outline)
        .map((p) => (
          <polygon key={`u${p.id}`} points={poly(p.outline!)} className={`station-unit cat-${p.category}`} strokeWidth={0.6 / k} />
        ))}
      {/* Platform pieces in one fill with no outline, so a platform reads as one shape. */}
      {map.platforms
        .filter((p) => p.level === level)
        .flatMap((p) => p.geometry.map((g, i) => <polygon key={`p${p.id}${i}`} points={poly(g)} className="station-platform" strokeWidth={0.5 / k} />))}
      {k > 2.2 &&
        map.nodes
          .filter((n) => n.level === level && (n.type === 'stairs' || n.type === 'escalator' || n.type === 'lift'))
          .map((n) => <rect key={n.id} x={n.x - 2.5 / k} y={n.y - 2.5 / k} width={5 / k} height={5 / k} rx={1.2 / k} className={`station-vertical ${n.type}`} />)}
    </g>
  );
});
