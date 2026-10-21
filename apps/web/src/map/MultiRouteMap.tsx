// Every ridden route on one map (Passport, DESIGN §8.3): each line in its operator colour, with a soft glow so
// lines you've ridden many times build up brighter, and station dots that grow with the number of visits.
import { useEffect, useRef, useState } from 'react';
import type { Map as MlMap } from 'maplibre-gl';
import { decodePolyline, type LatLon } from '@clack/shared';
import { RAIL_NETWORK_URL, baseStyle, railNetworkLayers } from './style';
import { loadMaplibre, mapStatus } from './RouteMap';
import 'maplibre-gl/dist/maplibre-gl.css';

export interface MultiRoute {
  color: string;
  geometry: string | null;
  /** Fallback when there's no routed geometry: just the end stations. */
  stops: LatLon[];
}

export interface MultiStation {
  lat: number;
  lon: number;
  name: string;
  count: number;
}

export function MultiRouteMap({
  routes,
  stations,
  railNetwork,
  className = '',
  label,
}: {
  routes: MultiRoute[];
  stations: MultiStation[];
  railNetwork: boolean;
  className?: string;
  label?: string;
}) {
  const el = useRef<HTMLDivElement>(null);
  const map = useRef<MlMap | null>(null);
  const [failed, setFailed] = useState(false);
  const key = routes.map((r) => r.geometry?.length ?? 0).join(',') + `|${stations.length}`;

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const [ml, status] = await Promise.all([loadMaplibre(), mapStatus()]);
      if (cancelled || !el.current) return;
      const lines = routes.map((r) => ({
        type: 'Feature' as const,
        properties: { color: r.color },
        geometry: { type: 'LineString' as const, coordinates: (r.geometry ? decodePolyline(r.geometry) : r.stops).map(([la, lo]) => [lo, la]) },
      }));
      const pts = lines.flatMap((f) => f.geometry.coordinates);
      if (!pts.length) return;
      const lons = pts.map((p) => p[0]!);
      const lats = pts.map((p) => p[1]!);
      let m: MlMap;
      try {
        m = new ml.Map({
          container: el.current,
          style: baseStyle(Boolean(status.basemap)),
          attributionControl: false,
          bounds: [
            [Math.min(...lons), Math.min(...lats)],
            [Math.max(...lons), Math.max(...lats)],
          ],
          fitBoundsOptions: { padding: 36, maxZoom: 10 },
          fadeDuration: 0,
        });
      } catch {
        setFailed(true);
        return;
      }
      map.current = m;
      m.on('load', () => {
        if (railNetwork) {
          m.addSource('rail-network', { type: 'geojson', data: RAIL_NETWORK_URL() });
          for (const layer of railNetworkLayers()) m.addLayer(layer);
        }
        m.addSource('routes', { type: 'geojson', data: { type: 'FeatureCollection', features: lines } });
        const round = { 'line-cap': 'round', 'line-join': 'round' } as const;
        // Low-opacity glow per ride: where rides overlap the glow stacks up and the line looks brighter.
        m.addLayer({
          id: 'routes-glow',
          type: 'line',
          source: 'routes',
          layout: round,
          paint: { 'line-color': ['get', 'color'], 'line-opacity': 0.22, 'line-width': 10, 'line-blur': 5 },
        });
        m.addLayer({
          id: 'routes-body',
          type: 'line',
          source: 'routes',
          layout: round,
          paint: { 'line-color': ['get', 'color'], 'line-opacity': 0.75, 'line-width': 2.5 },
        });
        m.addSource('stations', {
          type: 'geojson',
          data: {
            type: 'FeatureCollection',
            features: stations.map((s) => ({
              type: 'Feature',
              properties: { name: s.name, count: s.count },
              geometry: { type: 'Point', coordinates: [s.lon, s.lat] },
            })),
          },
        });
        m.addLayer({
          id: 'stations',
          type: 'circle',
          source: 'stations',
          paint: {
            'circle-radius': ['interpolate', ['linear'], ['get', 'count'], 1, 3, 10, 7, 50, 11],
            'circle-color': '#ffffff',
            'circle-stroke-color': '#0B0E13',
            'circle-stroke-width': 1.5,
          },
        });
      });
    })();
    return () => {
      cancelled = true;
      map.current?.remove();
      map.current = null;
    };
    // Rebuilt when the set of routes changes (year/commuter filters).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, railNetwork]);

  return (
    <div className={`route-map ${className}`} role="img" aria-label={label}>
      <div ref={el} className="route-map-canvas" />
      {failed && <div className="route-map-fallback caption">Map unavailable</div>}
      <span className="map-attrib">© OpenStreetMap contributors · Protomaps</span>
    </div>
  );
}
