// A route map (DESIGN §2.4): dark basemap, the ridden route as a glowing line in the operator colour, stop dots,
// an optional faint rest-of-route, the rail-network toggle and a draw-on animation. While a train is live it also
// shows the train marker, the part still ahead as a dimmed dashed line, and Follow train. MapLibre loads lazily so
// the rest of the app stays light.
import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Layers, LocateFixed, Navigation } from 'lucide-react';
import type { GeoJSONSource, Map as MlMap, Marker } from 'maplibre-gl';
import type { LatLon } from '@clack/shared';
import { RAIL_NETWORK_URL, baseStyle, railNetworkLayers, routeLayers } from './style';
import { useResolvedTheme } from '../theme';
import 'maplibre-gl/dist/maplibre-gl.css';
import { apiUrl } from '../apiBase';

export interface MapStop {
  lat: number;
  lon: number;
  name: string;
  /** end = where you got on/off (big dot + label); mid = a stop you rode through. */
  kind: 'end' | 'mid';
}

interface Props {
  color: string;
  route: LatLon[];
  /** Parts of the train's route you didn't ride, drawn faintly (confirm step). */
  context?: LatLon[][];
  stops: MapStop[];
  animate?: boolean;
  interactive?: boolean;
  controls?: boolean;
  railNetwork?: boolean;
  className?: string;
  label?: string;
  /** Live train position; estimated positions draw as a hollow marker (DESIGN §2.4). */
  train?: { lat: number; lon: number; bearing: number | null; estimated: boolean } | null;
  /** Share of the route already travelled (0–1): splits the line into travelled and ahead. */
  progress?: number | null;
}

let statusPromise: Promise<{ basemap: unknown }> | null = null;
/** Shared with the other maps. */
export const mapStatus = () =>
  (statusPromise ??= fetch(apiUrl('/api/map/status')).then(
    (r) => (r.ok ? r.json() : { basemap: null }),
    () => ({ basemap: null }),
  ));

let protocolReady: Promise<typeof import('maplibre-gl')> | null = null;
export function loadMaplibre() {
  protocolReady ??= Promise.all([import('maplibre-gl'), import('pmtiles'), import('maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url')]).then(
    ([ml, pm, worker]) => {
      // MapLibre finds its worker relative to its own file, which bundling moves; point it at Vite's worker build.
      ml.setWorkerUrl(worker.default);
      ml.addProtocol('pmtiles', new pm.Protocol().tile);
      return ml;
    },
  );
  return protocolReady;
}

const lineFeature = (pts: LatLon[]) => ({
  type: 'Feature' as const,
  properties: {},
  geometry: { type: 'LineString' as const, coordinates: pts.map(([la, lo]) => [lo, la]) },
});
const lines = (parts: LatLon[][]) => ({ type: 'FeatureCollection' as const, features: parts.filter((p) => p.length > 1).map(lineFeature) });
const points = (stops: MapStop[]) => ({
  type: 'FeatureCollection' as const,
  features: stops.map((s) => ({
    type: 'Feature' as const,
    properties: { name: s.name, kind: s.kind },
    geometry: { type: 'Point' as const, coordinates: [s.lon, s.lat] },
  })),
});

function boundsOf(pts: LatLon[]): [[number, number], [number, number]] | null {
  if (!pts.length) return null;
  let [minLa, minLo, maxLa, maxLo] = [90, 180, -90, -180];
  for (const [la, lo] of pts) {
    minLa = Math.min(minLa, la);
    maxLa = Math.max(maxLa, la);
    minLo = Math.min(minLo, lo);
    maxLo = Math.max(maxLo, lo);
  }
  return [
    [minLo, minLa],
    [maxLo, maxLa],
  ];
}

/** The first `frac` of a line by length, for the draw-on animation. */
function partOf(pts: LatLon[], frac: number): LatLon[] {
  if (frac >= 1 || pts.length < 2) return pts;
  const seg: number[] = [];
  let total = 0;
  for (let i = 1; i < pts.length; i++) {
    const d = Math.hypot(pts[i]![0] - pts[i - 1]![0], (pts[i]![1] - pts[i - 1]![1]) * Math.cos((pts[i]![0] * Math.PI) / 180));
    seg.push(d);
    total += d;
  }
  let left = total * frac;
  const out: LatLon[] = [pts[0]!];
  for (let i = 1; i < pts.length; i++) {
    const d = seg[i - 1]!;
    if (left >= d) {
      out.push(pts[i]!);
      left -= d;
      continue;
    }
    const t = d ? left / d : 0;
    out.push([pts[i - 1]![0] + t * (pts[i]![0] - pts[i - 1]![0]), pts[i - 1]![1] + t * (pts[i]![1] - pts[i - 1]![1])]);
    break;
  }
  return out;
}

// DESIGN: fit with 48 px; extra room at the top for the floating buttons and at the sides for station labels.
/** The route split at a share of its length: [travelled, ahead]. */
export function splitAt(pts: LatLon[], frac: number): [LatLon[], LatLon[]] {
  const before = partOf(pts, Math.max(0, Math.min(1, frac)));
  if (before.length < 2 || frac >= 1) return [pts, []];
  const cut = before.at(-1)!;
  const rest = pts.slice(before.length - 1);
  rest[0] = cut;
  return [before, rest];
}

const PADDING = { top: 72, bottom: 96, left: 64, right: 72 };
const MINI_PADDING = { top: 28, bottom: 28, left: 56, right: 56 };
const reducedMotion = () => window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;

function RouteMapInner({
  color,
  route,
  context = [],
  stops,
  animate = false,
  interactive = true,
  controls = true,
  railNetwork = false,
  className = '',
  label,
  train = null,
  progress = null,
}: Props) {
  const { t } = useTranslation();
  const el = useRef<HTMLDivElement>(null);
  const map = useRef<MlMap | null>(null);
  const [ready, setReady] = useState(false);
  const [failed, setFailed] = useState(false);
  const [showRail, setShowRail] = useState(railNetwork);
  const [follow, setFollow] = useState(false);
  const marker = useRef<Marker | null>(null);
  const ml = useRef<typeof import('maplibre-gl') | null>(null);
  const fitPoints = route.length ? route : stops.map((s) => [s.lat, s.lon] as LatLon);
  const latest = useRef({ route, context, stops, fitPoints, progress });
  latest.current = { route, context, stops, fitPoints, progress };

  const fit = (animateCamera: boolean) => {
    const m = map.current;
    const b = boundsOf(latest.current.fitPoints);
    if (!m || !b) return;
    m.fitBounds(b, { padding: controls && interactive ? PADDING : MINI_PADDING, maxZoom: 13, duration: animateCamera && !reducedMotion() ? 1200 : 0 });
  };

  // Create the map once.
  useEffect(() => {
    let cancelled = false;
    let frame = 0;
    (async () => {
      const [lib, status] = await Promise.all([loadMaplibre(), mapStatus()]);
      if (cancelled || !el.current) return;
      ml.current = lib;
      let m: MlMap;
      try {
        const b = boundsOf(latest.current.fitPoints);
        m = new lib.Map({
          container: el.current,
          style: baseStyle(Boolean(status.basemap)),
          attributionControl: false,
          interactive,
          ...(b ? { bounds: b, fitBoundsOptions: { padding: controls && interactive ? PADDING : MINI_PADDING, maxZoom: 13 } } : { center: [15, 62], zoom: 4 }),
          fadeDuration: 0,
        });
      } catch {
        setFailed(true);
        return;
      }
      map.current = m;
      // Dragging the map means you want to look around: stop following the train.
      m.on('dragstart', () => setFollow(false));
      m.on('load', () => {
        if (cancelled) return;
        const { route: r, context: c, stops: s } = latest.current;
        const draw = animate && !reducedMotion() && r.length > 1 && latest.current.progress === null;
        m.addSource('route-context', { type: 'geojson', data: lines(c) });
        m.addSource('route-ahead', { type: 'geojson', data: lines([]) });
        m.addSource('route', { type: 'geojson', data: lines([draw ? r.slice(0, 1) : r]) });
        m.addSource('stops', { type: 'geojson', data: points(draw ? s.filter((x) => x.kind === 'end').slice(0, 1) : s) });
        for (const layer of routeLayers(color)) m.addLayer(layer);
        setReady(true);
        if (draw) {
          const start = performance.now();
          const step = (now: number) => {
            const k = Math.min(1, (now - start) / 1200);
            const eased = 1 - (1 - k) ** 3;
            (m.getSource('route') as GeoJSONSource | undefined)?.setData(lines([partOf(latest.current.route, eased)]));
            if (k < 1) frame = requestAnimationFrame(step);
            else (m.getSource('stops') as GeoJSONSource | undefined)?.setData(points(latest.current.stops));
          };
          frame = requestAnimationFrame(step);
        }
      });
    })();
    return () => {
      cancelled = true;
      cancelAnimationFrame(frame);
      marker.current?.remove();
      marker.current = null;
      map.current?.remove();
      map.current = null;
    };
    // The map is built once; later prop changes go through the effects below.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // New route or stops (the confirm step changes the ridden part as you pick stations).
  const routeKey = `${route.length}:${route[0]?.join()}:${route.at(-1)?.join()}:${context.length}:${stops.length}`;
  useEffect(() => {
    const m = map.current;
    if (!m || !ready) return;
    (m.getSource('route-context') as GeoJSONSource | undefined)?.setData(lines(context));
    (m.getSource('stops') as GeoJSONSource | undefined)?.setData(points(stops));
    if (!follow) fit(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [routeKey, ready]);

  // Travelled vs ahead (live) or the whole line.
  const progressKey = progress === null ? 'none' : progress.toFixed(4);
  useEffect(() => {
    const m = map.current;
    if (!m || !ready) return;
    const [done, ahead] = progress === null ? [route, []] : splitAt(route, progress);
    (m.getSource('route') as GeoJSONSource | undefined)?.setData(lines([done]));
    (m.getSource('route-ahead') as GeoJSONSource | undefined)?.setData(lines([ahead]));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [routeKey, progressKey, ready]);

  // The train marker: operator dot with a heading chevron and pulsing halo; hollow when estimated.
  useEffect(() => {
    const m = map.current;
    const lib = ml.current;
    if (!m || !lib || !ready) return;
    if (!train) {
      marker.current?.remove();
      marker.current = null;
      return;
    }
    if (!marker.current) {
      const node = document.createElement('div');
      node.className = 'train-marker';
      node.innerHTML = '<span class="train-halo"></span><span class="train-chevron"></span><span class="train-dot"></span>';
      node.style.setProperty('--op', color);
      marker.current = new lib.Marker({ element: node }).setLngLat([train.lon, train.lat]).addTo(m);
    }
    const node = marker.current.getElement();
    node.classList.toggle('estimated', train.estimated);
    node.title = train.estimated ? t('live.estimatedPosition') : t('live.livePosition');
    const chevron = node.querySelector<HTMLElement>('.train-chevron');
    if (chevron) {
      chevron.style.display = train.bearing === null ? 'none' : '';
      chevron.style.transform = `rotate(${train.bearing ?? 0}deg)`;
    }
    marker.current.setLngLat([train.lon, train.lat]);
    if (follow) m.easeTo({ center: [train.lon, train.lat], duration: reducedMotion() ? 0 : 800 });
  }, [train?.lat, train?.lon, train?.bearing, train?.estimated, ready, follow, color, t, train]);

  // Rail network layer, fetched the first time it's switched on.
  useEffect(() => {
    const m = map.current;
    if (!m || !ready) return;
    if (showRail && !m.getSource('rail-network')) {
      m.addSource('rail-network', { type: 'geojson', data: RAIL_NETWORK_URL() });
      for (const layer of railNetworkLayers()) m.addLayer(layer, 'route-context');
    }
    for (const id of ['rail-network', 'rail-stations']) if (m.getLayer(id)) m.setLayoutProperty(id, 'visibility', showRail ? 'visible' : 'none');
  }, [showRail, ready]);

  return (
    <div className={`route-map ${className}`} role="img" aria-label={label}>
      <div ref={el} className="route-map-canvas" />
      {failed && <div className="route-map-fallback caption">{t('map.unavailable')}</div>}
      {controls && interactive && (
        <>
          <button
            className="map-button map-layers"
            aria-pressed={showRail}
            aria-label={t('map.railNetwork')}
            title={t('map.railNetwork')}
            onClick={() => setShowRail(!showRail)}
          >
            <Layers size={18} />
          </button>
          {train && (
            <button
              className="map-button map-follow"
              aria-pressed={follow}
              aria-label={t('live.follow')}
              title={t('live.follow')}
              onClick={() => setFollow(!follow)}
            >
              <Navigation size={18} />
            </button>
          )}
          <button
            className="map-button map-recenter"
            aria-label={t('map.recenter')}
            title={t('map.recenter')}
            onClick={() => {
              setFollow(false);
              fit(true);
            }}
          >
            <LocateFixed size={18} />
          </button>
        </>
      )}
      <span className="map-attrib">© OpenStreetMap contributors · Protomaps</span>
    </div>
  );
}

/** Re-created when the theme changes: the basemap and every layer take their colours from it. */
export function RouteMap(props: Props) {
  const theme = useResolvedTheme();
  return <RouteMapInner key={theme} {...props} />;
}
