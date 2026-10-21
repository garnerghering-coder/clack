// Live map of all trains (ADDITIONS_01 A): a calm radar view. Positions come from the server's single Trafikverket
// stream, filtered to what this map shows; markers glide between updates instead of jumping.
import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, Info, X } from 'lucide-react';
import type { GeoJSONSource, Map as MlMap, MapMouseEvent } from 'maplibre-gl';
import { decodePolyline, delayBand, type LatLon } from '@clack/shared';
import { api, type TripGeometry } from '../api';
import { OperatorBadge } from '../components/OperatorBadge';
import { DelayPill } from '../components/DelayPill';
import { TrainArt } from '../components/TrainArt';
import { useOperators, useTrainTypes } from '../data';
import { agoKey, useNow } from '../live';
import { useSettings } from '../settings';
import { fmtTime } from '../format';
import { baseStyle, MAP_COLORS, RAIL_NETWORK_URL, railNetworkLayers, routeLayers } from '../map/style';
import { loadMaplibre, mapStatus, splitAt } from '../map/RouteMap';
import 'maplibre-gl/dist/maplibre-gl.css';

interface LiveTrain {
  id: string;
  number: string;
  date: string;
  lat: number;
  lon: number;
  bearing: number | null;
  speedKmh: number | null;
  at: number;
  estimated: boolean;
  operatorId: string | null;
  productName: string | null;
  product: string;
  trainType: string | null;
  origin: string | null;
  destination: string | null;
  next: string | null;
  nextEta: number | null;
  delayMin: number | null;
  mine: boolean;
}
/** Server delta shorthand for a train whose only change is its position. */
type Moved = [id: string, lat: number, lon: number, bearing: number | null, speedKmh: number | null, at: number, estimated: boolean];
interface Detail {
  train: LiveTrain;
  trip: { key: string; serviceDate: string } | null;
  legId: string | null;
}

const BAND_COLORS: Record<string, string> = { slight: '#F5D90A', late: '#FF9500', very_late: '#FF453A' };
const PRODUCTS = ['high_speed', 'intercity', 'regional', 'commuter', 'night'] as const;
const GLIDE_MS = 1500;
const STALE_MS = 60_000;
const TZ = 'Europe/Stockholm';

/** Where each marker is drawn: glides from the previous position to the new one. */
interface Anim {
  from: LatLon;
  to: LatLon;
  start: number;
}

function headingImage(): ImageData {
  const c = document.createElement('canvas');
  c.width = c.height = 32;
  const g = c.getContext('2d')!;
  g.fillStyle = '#ffffff';
  g.beginPath();
  g.moveTo(16, 1);
  g.lineTo(21, 9);
  g.lineTo(11, 9);
  g.closePath();
  g.fill();
  return g.getImageData(0, 0, 32, 32);
}

export function LiveMapPage() {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const ops = useOperators();
  const types = useTrainTypes();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const el = useRef<HTMLDivElement>(null);
  const map = useRef<MlMap | null>(null);
  const trains = useRef(new Map<string, LiveTrain>());
  const anims = useRef(new Map<string, Anim>());
  const frame = useRef(0);
  const [ready, setReady] = useState(false);
  const [count, setCount] = useState<{ shown: number; total: number }>({ shown: 0, total: 0 });
  const [upstreamAt, setUpstreamAt] = useState(0);
  const [bbox, setBbox] = useState<string | null>(null);
  const [selected, setSelected] = useState<Detail | null>(null);
  const [legend, setLegend] = useState(false);
  const [productFilter, setProductFilter] = useState<Set<string>>(new Set());
  const [opFilter, setOpFilter] = useState<Set<string>>(new Set());
  const [onlyDelayed, setOnlyDelayed] = useState(false);
  const [onlyMine, setOnlyMine] = useState(false);
  const [showOps, setShowOps] = useState(false);
  const focus = params.get('train');
  const now = useNow(5000);
  const filters = useRef({ productFilter, opFilter, onlyDelayed, onlyMine });
  filters.current = { productFilter, opFilter, onlyDelayed, onlyMine };
  const opsRef = useRef(ops);
  opsRef.current = ops;

  const visible = (tr: LiveTrain) => {
    const f = filters.current;
    if (f.onlyMine && !tr.mine) return false;
    if (f.onlyDelayed && !((tr.delayMin ?? 0) > 5)) return false;
    if (f.productFilter.size && !f.productFilter.has(tr.product)) return false;
    if (f.opFilter.size && (!tr.operatorId || !f.opFilter.has(tr.operatorId))) return false;
    return true;
  };

  /** Push current (glided) positions into the map source. */
  const render = () => {
    frame.current = 0;
    const m = map.current;
    const src = m?.getSource('trains') as GeoJSONSource | undefined;
    if (!src) return;
    const nowMs = performance.now();
    let moving = false;
    const feats = [];
    for (const tr of trains.current.values()) {
      if (!visible(tr)) continue;
      const a = anims.current.get(tr.id);
      let pos: LatLon = [tr.lat, tr.lon];
      if (a) {
        const k = Math.min(1, (nowMs - a.start) / GLIDE_MS);
        const e = 1 - (1 - k) ** 3;
        pos = [a.from[0] + (a.to[0] - a.from[0]) * e, a.from[1] + (a.to[1] - a.from[1]) * e];
        if (k < 1) moving = true;
        else anims.current.delete(tr.id);
      }
      const band = delayBand(tr.delayMin);
      feats.push({
        type: 'Feature' as const,
        id: undefined,
        properties: {
          id: tr.id,
          number: tr.number,
          label: tr.destination ? `${tr.number} · ${tr.destination}` : tr.number,
          color: (tr.operatorId && opsRef.current.get(tr.operatorId)?.brandColor) || '#4C8DFF',
          ring: BAND_COLORS[band] ?? '',
          estimated: tr.estimated,
          mine: tr.mine,
          bearing: tr.bearing ?? 0,
          hasBearing: tr.bearing !== null,
        },
        geometry: { type: 'Point' as const, coordinates: [pos[1], pos[0]] },
      });
    }
    src.setData({ type: 'FeatureCollection', features: feats });
    setCount((c) => (c.shown === feats.length ? c : { ...c, shown: feats.length }));
    if (moving) frame.current = requestAnimationFrame(render);
  };
  const scheduleRender = () => {
    if (!frame.current) frame.current = requestAnimationFrame(render);
  };

  const apply = (list: LiveTrain[], removed: string[], replace: boolean) => {
    const start = performance.now();
    if (replace) {
      const keep = new Set(list.map((x) => x.id));
      for (const id of trains.current.keys()) if (!keep.has(id)) trains.current.delete(id);
    }
    for (const id of removed) trains.current.delete(id);
    // Only trains on screen, close enough in to see them move, glide; the rest jump (saves redrawing 1000 points a frame).
    const m = map.current;
    const view = m && m.getZoom() >= 7 ? m.getBounds() : null;
    for (const tr of list) {
      const old = trains.current.get(tr.id);
      if (old && view && (old.lat !== tr.lat || old.lon !== tr.lon) && view.contains([tr.lon, tr.lat]))
        anims.current.set(tr.id, { from: [old.lat, old.lon], to: [tr.lat, tr.lon], start });
      else anims.current.delete(tr.id);
      trains.current.set(tr.id, tr);
    }
    scheduleRender();
  };

  // Create the map once.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const [ml, status] = await Promise.all([loadMaplibre(), mapStatus()]);
      if (cancelled || !el.current) return;
      const m = new ml.Map({ container: el.current, style: baseStyle(Boolean(status.basemap)), attributionControl: false, center: [15.5, 61.5], zoom: 4.2, fadeDuration: 0 });
      map.current = m;
      // Dev builds only: lets browser tests read the map (markers are drawn on a canvas, not in the DOM).
      if (import.meta.env.DEV) (window as unknown as { __liveMap?: MlMap }).__liveMap = m;
      const updateBbox = () => {
        const b = m.getBounds();
        setBbox([b.getWest(), b.getSouth(), b.getEast(), b.getNorth()].map((v) => v.toFixed(3)).join(','));
      };
      m.on('load', () => {
        m.addImage('heading', headingImage(), { pixelRatio: 2 });
        m.addSource('rail-network', { type: 'geojson', data: RAIL_NETWORK_URL() });
        for (const layer of railNetworkLayers()) m.addLayer(layer);
        m.addSource('trains', { type: 'geojson', data: { type: 'FeatureCollection', features: [] }, cluster: true, clusterMaxZoom: 6, clusterRadius: 36 });
        m.addLayer({
          id: 'clusters',
          type: 'circle',
          source: 'trains',
          filter: ['has', 'point_count'],
          paint: { 'circle-color': 'rgba(76,141,255,0.22)', 'circle-stroke-color': 'rgba(76,141,255,0.7)', 'circle-stroke-width': 1, 'circle-radius': ['step', ['get', 'point_count'], 12, 10, 16, 50, 21] },
        });
        m.addLayer({
          id: 'cluster-count',
          type: 'symbol',
          source: 'trains',
          filter: ['has', 'point_count'],
          layout: { 'text-field': ['get', 'point_count_abbreviated'], 'text-font': ['Noto Sans Medium'], 'text-size': 11, 'text-allow-overlap': true },
          paint: { 'text-color': '#F2F4F8' },
        });
        const single: ['!', ['has', string]] = ['!', ['has', 'point_count']];
        m.addLayer({ id: 'train-mine', type: 'circle', source: 'trains', filter: ['all', single, ['==', ['get', 'mine'], true]], paint: { 'circle-radius': 13, 'circle-color': 'rgba(76,141,255,0.25)', 'circle-stroke-color': '#4C8DFF', 'circle-stroke-width': 1.5 } });
        m.addLayer({ id: 'train-glow', type: 'circle', source: 'trains', filter: single, paint: { 'circle-radius': 9, 'circle-color': ['get', 'color'], 'circle-opacity': 0.22, 'circle-blur': 0.6 } });
        m.addLayer({
          id: 'train-ring',
          type: 'circle',
          source: 'trains',
          filter: ['all', single, ['!=', ['get', 'ring'], '']],
          paint: { 'circle-radius': 7.5, 'circle-color': 'rgba(0,0,0,0)', 'circle-stroke-color': ['get', 'ring'], 'circle-stroke-width': 2 },
        });
        m.addLayer({
          id: 'train-dot',
          type: 'circle',
          source: 'trains',
          filter: single,
          // Your own trains are drawn on top.
          layout: { 'circle-sort-key': ['case', ['==', ['get', 'mine'], true], 1, 0] },
          paint: {
            'circle-radius': ['case', ['==', ['get', 'mine'], true], 6.5, 5],
            'circle-color': ['case', ['==', ['get', 'estimated'], true], MAP_COLORS.bg, ['get', 'color']],
            'circle-stroke-color': ['case', ['==', ['get', 'estimated'], true], ['get', 'color'], '#ffffff'],
            'circle-stroke-width': ['case', ['==', ['get', 'estimated'], true], 2, 1],
          },
        });
        // The selected train: a larger marker under its dot (ADDITIONS_01 A, "the marker enlarges").
        m.addLayer(
          { id: 'train-selected', type: 'circle', source: 'trains', filter: ['==', ['get', 'id'], ''], paint: { 'circle-radius': 11, 'circle-color': ['get', 'color'], 'circle-opacity': 0.35, 'circle-stroke-color': '#ffffff', 'circle-stroke-width': 2 } },
          'train-dot',
        );
        m.addLayer({
          id: 'train-heading',
          type: 'symbol',
          source: 'trains',
          minzoom: 7,
          filter: ['all', single, ['==', ['get', 'hasBearing'], true]],
          layout: { 'icon-image': 'heading', 'icon-rotate': ['get', 'bearing'], 'icon-rotation-alignment': 'map', 'icon-allow-overlap': true, 'icon-ignore-placement': true, 'icon-size': 0.9 },
        });
        m.addLayer({
          id: 'train-label',
          type: 'symbol',
          source: 'trains',
          minzoom: 9,
          filter: single,
          layout: {
            'text-field': ['step', ['zoom'], ['get', 'number'], 11, ['get', 'label']],
            'text-font': ['Noto Sans Medium'],
            'text-size': 11,
            'text-offset': [0, 1.3],
            'text-anchor': 'top',
            'text-optional': true,
          },
          paint: { 'text-color': '#F2F4F8', 'text-halo-color': MAP_COLORS.bg, 'text-halo-width': 1.4 },
        });
        m.on('click', 'clusters', (e: MapMouseEvent) => m.easeTo({ center: e.lngLat, zoom: m.getZoom() + 2 }));
        // Trains bunch up at stations: of the dots under the finger, take the one nearest to it.
        m.on('click', 'train-dot', (e) => {
          const hits = m.queryRenderedFeatures(
            [
              [e.point.x - 10, e.point.y - 10],
              [e.point.x + 10, e.point.y + 10],
            ],
            { layers: ['train-dot'] },
          );
          const dist = (f: (typeof hits)[number]) => {
            const p = m.project((f.geometry as unknown as { coordinates: [number, number] }).coordinates);
            return Math.hypot(p.x - e.point.x, p.y - e.point.y);
          };
          const best = hits.sort((a, b) => dist(a) - dist(b))[0];
          if (best) select(String(best.properties.id));
        });
        for (const l of ['train-dot', 'clusters']) {
          m.on('mouseenter', l, () => (m.getCanvas().style.cursor = 'pointer'));
          m.on('mouseleave', l, () => (m.getCanvas().style.cursor = ''));
        }
        m.on('moveend', updateBbox);
        updateBbox();
        setReady(true);
      });
    })();
    return () => {
      cancelled = true;
      cancelAnimationFrame(frame.current);
      frame.current = 0;
      map.current?.remove();
      map.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Subscribe to the trains in view; re-subscribes (debounced) when you pan or zoom.
  useEffect(() => {
    if (!ready || !bbox) return;
    let es: EventSource | null = null;
    const timer = setTimeout(() => {
      es = new EventSource(`/api/live/trains/stream?bbox=${bbox}`);
      es.addEventListener('snapshot', (e) => {
        const d = JSON.parse((e as MessageEvent<string>).data) as { trains: LiveTrain[]; total: number; upstreamAt: number };
        apply(d.trains, [], true);
        setCount((c) => ({ ...c, total: d.total }));
        setUpstreamAt(d.upstreamAt);
      });
      es.addEventListener('delta', (e) => {
        const d = JSON.parse((e as MessageEvent<string>).data) as { changed: LiveTrain[]; moved?: Moved[]; removed: string[]; total: number; upstreamAt: number };
        // A "moved" train only changed position: lay that over what we already have.
        const movedTrains = (d.moved ?? []).flatMap(([id, lat, lon, bearing, speedKmh, at, estimated]) => {
          const old = trains.current.get(id);
          return old ? [{ ...old, lat, lon, bearing, speedKmh, at, estimated }] : [];
        });
        apply([...d.changed, ...movedTrains], d.removed, false);
        setCount((c) => ({ ...c, total: d.total }));
        setUpstreamAt(d.upstreamAt);
      });
    }, 400);
    return () => {
      clearTimeout(timer);
      es?.close();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, bbox]);

  // Filters change what's drawn.
  useEffect(() => scheduleRender(), [productFilter, opFilter, onlyDelayed, onlyMine, ops]);

  // Opened from a board row ("Show on map"): select that train once it's on the map.
  useEffect(() => {
    if (!focus || !ready || selected) return;
    const tr = [...trains.current.values()].find((x) => x.number === focus);
    if (tr) select(tr.id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [focus, ready, count.total]);

  const clearRoute = () => {
    const m = map.current;
    if (!m) return;
    for (const id of ['stops-label', 'stops-end', 'stops-mid', 'route-core', 'route-body', 'route-glow', 'route-ahead', 'route-context']) if (m.getLayer(id)) m.removeLayer(id);
    for (const id of ['route', 'route-ahead', 'route-context', 'stops']) if (m.getSource(id)) m.removeSource(id);
  };

  const select = async (id: string) => {
    let d: Detail;
    try {
      d = await api.liveTrain(id);
    } catch {
      return;
    }
    setSelected(d);
    const m = map.current;
    if (!m) return;
    m.setFilter('train-selected', ['==', ['get', 'id'], id]);
    m.easeTo({ center: [d.train.lon, d.train.lat], zoom: Math.max(m.getZoom(), 8) });
    clearRoute();
    if (!d.trip) return;
    // The train's whole route, along the tracks: travelled part solid, the rest dashed (DESIGN §2.4).
    const geo: TripGeometry = await api.timetableTripGeometry(d.trip.key, d.trip.serviceDate);
    const line: LatLon[] = geo.segments.flatMap((s, i) => {
      const p = decodePolyline(s.polyline);
      return i ? p.slice(1) : p;
    });
    if (line.length < 2 || !map.current) return;
    let best = 0;
    let bd = Infinity;
    line.forEach(([la, lo], i) => {
      const dd = (la - d.train.lat) ** 2 + (lo - d.train.lon) ** 2;
      if (dd < bd) {
        bd = dd;
        best = i;
      }
    });
    const [done, ahead] = splitAt(line, best / (line.length - 1));
    const color = (d.train.operatorId && opsRef.current.get(d.train.operatorId)?.brandColor) || '#4C8DFF';
    const fc = (pts: LatLon[]) => ({ type: 'FeatureCollection' as const, features: pts.length > 1 ? [{ type: 'Feature' as const, properties: {}, geometry: { type: 'LineString' as const, coordinates: pts.map(([la, lo]) => [lo, la]) } }] : [] });
    clearRoute();
    m.addSource('route-context', { type: 'geojson', data: fc([]) });
    m.addSource('route-ahead', { type: 'geojson', data: fc(ahead) });
    m.addSource('route', { type: 'geojson', data: fc(done) });
    m.addSource('stops', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } });
    for (const layer of routeLayers(color)) m.addLayer(layer, 'train-mine');
  };
  const deselect = () => {
    setSelected(null);
    clearRoute();
    map.current?.setFilter('train-selected', ['==', ['get', 'id'], '']);
  };

  const operatorsShown = useMemo(() => [...new Set([...trains.current.values()].map((x) => x.operatorId).filter((o): o is string => !!o))].sort(), [count.total]);
  const toggle = (set: Set<string>, v: string, apply_: (s: Set<string>) => void) => {
    const n = new Set(set);
    if (n.has(v)) n.delete(v);
    else n.add(v);
    apply_(n);
  };
  const stale = upstreamAt > 0 && now - upstreamAt > STALE_MS;
  const sel = selected?.train;
  const selOp = sel?.operatorId ? ops.get(sel.operatorId) : undefined;
  const selType = sel?.trainType ? types.get(sel.trainType) : undefined;

  return (
    <div className="live-page">
      <div ref={el} className="live-canvas" />
      <Link to="/" className="map-button live-back" aria-label={t('nav.trips')}>
        <ArrowLeft size={18} />
      </Link>
      <div className="live-filters chip-row">
        {PRODUCTS.map((p) => (
          <button key={p} className={productFilter.has(p) ? 'chip-button active' : 'chip-button'} onClick={() => toggle(productFilter, p, setProductFilter)} aria-pressed={productFilter.has(p)}>
            {t(`products.${p}`)}
          </button>
        ))}
        <button className={opFilter.size ? 'chip-button active' : 'chip-button'} onClick={() => setShowOps(!showOps)} aria-expanded={showOps}>
          {opFilter.size ? t('liveMap.operatorsN', { count: opFilter.size }) : t('liveMap.operators')}
        </button>
        <button className={onlyDelayed ? 'chip-button active' : 'chip-button'} onClick={() => setOnlyDelayed(!onlyDelayed)} aria-pressed={onlyDelayed}>
          {t('liveMap.onlyDelayed')}
        </button>
        <button className={onlyMine ? 'chip-button active' : 'chip-button'} onClick={() => setOnlyMine(!onlyMine)} aria-pressed={onlyMine}>
          {t('liveMap.onlyMine')}
        </button>
      </div>
      {showOps && (
        <div className="live-ops card">
          {operatorsShown.map((o) => (
            <label key={o} className="switch-row">
              <input type="checkbox" checked={opFilter.has(o)} onChange={() => toggle(opFilter, o, setOpFilter)} />
              <OperatorBadge operator={ops.get(o)} size={20} />
              <span>{ops.get(o)?.name ?? o}</span>
            </label>
          ))}
        </div>
      )}
      <div className="live-counter">
        {stale ? (
          <span className="chip stale-chip">{t('liveMap.delayedData', { ago: agoKey(t, upstreamAt, now) })}</span>
        ) : (
          <span className="chip live-chip">
            <span className="live-dot" aria-hidden="true" />
            {t('liveMap.trainsLive', { count: count.total })}
          </span>
        )}
        <button className="map-button small" onClick={() => setLegend(!legend)} aria-expanded={legend} aria-label={t('liveMap.legend')}>
          <Info size={16} />
        </button>
      </div>
      {legend && (
        <div className="live-legend card caption">
          <p>
            <span className="lg-dot solid" /> {t('liveMap.legendGps')}
          </p>
          <p>
            <span className="lg-dot hollow" /> {t('liveMap.legendEstimated')}
          </p>
          <p>
            <span className="lg-ring" style={{ borderColor: BAND_COLORS.slight }} /> {t('liveMap.legendSlight')}
          </p>
          <p>
            <span className="lg-ring" style={{ borderColor: BAND_COLORS.late }} /> {t('liveMap.legendLate')}
          </p>
          <p>
            <span className="lg-ring" style={{ borderColor: BAND_COLORS.very_late }} /> {t('liveMap.legendVeryLate')}
          </p>
          <p>{t('liveMap.legendNote')}</p>
        </div>
      )}
      <span className="map-attrib live-attrib">© OpenStreetMap contributors · Protomaps · Trafikverket</span>

      {sel && (
        <section className="live-sheet card" aria-live="polite">
          <header className="board-sheet-head">
            <OperatorBadge operator={selOp} size={32} />
            <span className="strong">{sel.productName || selOp ? [sel.productName ?? selOp?.name, sel.number].join(' ') : t('liveMap.train', { number: sel.number })}</span>
            <button className="icon-button small" onClick={deselect} aria-label={t('common.close')}>
              <X size={18} />
            </button>
          </header>
          {selType && (
            <div className="live-sheet-art">
              <TrainArt art={selType.art} color={selOp?.brandColor ?? '#4C8DFF'} height={22} />
              <span className="caption">{selType.name}</span>
            </div>
          )}
          {(sel.origin || sel.destination) && (
            <p className="strong">
              {sel.origin ?? '…'} → {sel.destination ?? '…'}
            </p>
          )}
          {!sel.origin && !sel.destination && !sel.next && <p className="caption">{t('liveMap.detailsLoading')}</p>}
          {sel.next && <p>{t('live.nextStop', { name: sel.next, time: fmtTime(sel.nextEta, TZ, settings.clock) })}</p>}
          <div className="chip-row">
            {sel.delayMin !== null && <DelayPill delay={sel.delayMin} />}
            {sel.speedKmh !== null && <span className="chip tabular">{sel.speedKmh} km/h</span>}
            <span className="chip">{sel.estimated ? t('live.estimatedPosition') : t('live.livePosition')}</span>
            <span className="caption">{t('live.updated', { ago: agoKey(t, sel.at, now) })}</span>
          </div>
          <div className="sheet-actions row-actions">
            {selected?.legId && (
              <button className="button" onClick={() => navigate(`/trips/${selected.legId}`)}>
                {t('liveMap.openDetail')}
              </button>
            )}
            <button
              className="button primary"
              disabled={!selected?.trip}
              onClick={() => selected?.trip && navigate(`/add?${new URLSearchParams({ trip: selected.trip.key, date: selected.trip.serviceDate })}`)}
            >
              {t('board.addToTrips')}
            </button>
          </div>
          {!selected?.trip && <p className="caption">{t('board.notInTimetable')}</p>}
        </section>
      )}
    </div>
  );
}
