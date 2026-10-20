// A route map (DESIGN §2.4): dark basemap, the ridden route as a glowing line in the operator colour, stop dots,
// an optional faint rest-of-route, the rail-network toggle and a draw-on animation. MapLibre loads lazily so the
// rest of the app stays light.
import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Layers, LocateFixed } from 'lucide-react';
import type { GeoJSONSource, Map as MlMap } from 'maplibre-gl';
import type { LatLon } from '@clack/shared';
import { RAIL_NETWORK_URL, baseStyle, railNetworkLayers, routeLayers } from './style';
import 'maplibre-gl/dist/maplibre-gl.css';

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
}

let statusPromise: Promise<{ basemap: unknown }> | null = null;
const mapStatus = () =>
  (statusPromise ??= fetch('/api/map/status').then(
    (r) => (r.ok ? r.json() : { basemap: null }),
    () => ({ basemap: null }),
  ));

let protocolReady: Promise<typeof import('maplibre-gl')> | null = null;
function loadMaplibre() {
  protocolReady ??= Promise.all([import('maplibre-gl'), import('pmtiles'), import('maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url')]).then(([ml, pm, worker]) => {
    // MapLibre finds its worker relative to its own file, which bundling moves; point it at Vite's worker build.
    ml.setWorkerUrl(worker.default);
    ml.addProtocol('pmtiles', new pm.Protocol().tile);
    return ml;
  });
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
const PADDING = { top: 72, bottom: 96, left: 64, right: 72 };
const MINI_PADDING = { top: 28, bottom: 28, left: 56, right: 56 };
const reducedMotion = () => window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;

export function RouteMap({
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
}: Props) {
  const { t } = useTranslation();
  const el = useRef<HTMLDivElement>(null);
  const map = useRef<MlMap | null>(null);
  const [ready, setReady] = useState(false);
  const [failed, setFailed] = useState(false);
  const [showRail, setShowRail] = useState(railNetwork);
  const fitPoints = route.length ? route : stops.map((s) => [s.lat, s.lon] as LatLon);
  const latest = useRef({ route, context, stops, fitPoints });
  latest.current = { route, context, stops, fitPoints };

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
      const [ml, status] = await Promise.all([loadMaplibre(), mapStatus()]);
      if (cancelled || !el.current) return;
      let m: MlMap;
      try {
        const b = boundsOf(latest.current.fitPoints);
        m = new ml.Map({
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
      m.on('load', () => {
        if (cancelled) return;
        const { route: r, context: c, stops: s } = latest.current;
        const draw = animate && !reducedMotion() && r.length > 1;
        m.addSource('route-context', { type: 'geojson', data: lines(c) });
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
    (m.getSource('route') as GeoJSONSource | undefined)?.setData(lines([route]));
    (m.getSource('route-context') as GeoJSONSource | undefined)?.setData(lines(context));
    (m.getSource('stops') as GeoJSONSource | undefined)?.setData(points(stops));
    fit(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [routeKey, ready]);

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
          <button className="map-button map-recenter" aria-label={t('map.recenter')} title={t('map.recenter')} onClick={() => fit(true)}>
            <LocateFixed size={18} />
          </button>
        </>
      )}
      <span className="map-attrib">© OpenStreetMap contributors · Protomaps</span>
    </div>
  );
}
