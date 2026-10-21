// A real map for share cards: an off-screen MapLibre map (the app's dark basemap and rail network, your routes in
// signal yellow), drawn once and copied into a canvas. Falls back to null (the card then draws the lines alone)
// when maps can't load.
import { decodePolyline, type LatLon } from '@clack/shared';
import type { CardRoute } from './shareCard';
import { loadMaplibre, mapStatus } from '../map/RouteMap';
import { baseStyle, RAIL_NETWORK_URL, railNetworkLayers } from '../map/style';

export interface MapSnapshot {
  image: HTMLCanvasElement;
  /** Where each requested point landed, in the snapshot's CSS pixels. */
  points: [number, number][];
  width: number;
  height: number;
}

const ACCENT = '#f8d64a';

export async function snapshotMap(routes: CardRoute[], width: number, height: number, points: LatLon[] = []): Promise<MapSnapshot | null> {
  const lines = routes.map((r) => (r.geometry ? decodePolyline(r.geometry) : r.ends)).filter((l) => l.length > 1);
  const all = lines.flat();
  if (all.length < 2) return null;
  const div = document.createElement('div');
  Object.assign(div.style, { position: 'fixed', left: '-10000px', top: '0', width: `${width}px`, height: `${height}px` });
  document.body.appendChild(div);
  let map: import('maplibre-gl').Map | null = null;
  try {
    const [ml, status] = await Promise.all([loadMaplibre(), mapStatus()]);
    map = new ml.Map({
      container: div,
      style: baseStyle(Boolean(status.basemap), 'dark'),
      interactive: false,
      attributionControl: false,
      fadeDuration: 0,
      pixelRatio: 2,
      canvasContextAttributes: { preserveDrawingBuffer: true },
    });
    const m = map;
    await new Promise<void>((res, rej) => {
      m.once('load', () => res());
      m.once('error', (e) => rej(e.error));
      setTimeout(() => rej(new Error('map load timeout')), 10_000);
    });
    m.addSource('rail-network', { type: 'geojson', data: RAIL_NETWORK_URL() });
    for (const layer of railNetworkLayers('dark')) m.addLayer(layer.id === 'rail-stations' ? { ...layer, minzoom: 24 } : layer);
    m.addSource('routes', { type: 'geojson', data: { type: 'FeatureCollection', features: lines.map((l) => ({ type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: l.map(([la, lo]) => [lo, la]) } })) } });
    m.addSource('ends', { type: 'geojson', data: { type: 'FeatureCollection', features: routes.flatMap((r) => r.ends.map((e) => ({ type: 'Feature' as const, properties: {}, geometry: { type: 'Point' as const, coordinates: [e[1], e[0]] } }))) } });
    const round = { 'line-cap': 'round', 'line-join': 'round' } as const;
    m.addLayer({ id: 'r-glow', type: 'line', source: 'routes', layout: round, paint: { 'line-color': ACCENT, 'line-width': 12, 'line-opacity': 0.3, 'line-blur': 6 } });
    m.addLayer({ id: 'r-line', type: 'line', source: 'routes', layout: round, paint: { 'line-color': ACCENT, 'line-width': 4 } });
    m.addLayer({ id: 'r-ends', type: 'circle', source: 'ends', paint: { 'circle-radius': 5, 'circle-color': '#0a0a0a', 'circle-stroke-color': '#ffffff', 'circle-stroke-width': 2.5 } });
    const lons = all.map((p) => p[1]);
    const lats = all.map((p) => p[0]);
    m.fitBounds(
      [
        [Math.min(...lons), Math.min(...lats)],
        [Math.max(...lons), Math.max(...lats)],
      ],
      { padding: { top: 56, bottom: 56, left: 64, right: 64 }, maxZoom: 10, animate: false },
    );
    await new Promise<void>((res) => {
      const done = () => res();
      m.once('idle', done);
      setTimeout(done, 8000);
    });
    const src = m.getCanvas();
    const image = document.createElement('canvas');
    image.width = src.width;
    image.height = src.height;
    image.getContext('2d')!.drawImage(src, 0, 0);
    const pts = points.map((p) => {
      const q = m.project([p[1], p[0]]);
      return [q.x, q.y] as [number, number];
    });
    return { image, points: pts, width, height };
  } catch {
    return null;
  } finally {
    map?.remove();
    div.remove();
  }
}
