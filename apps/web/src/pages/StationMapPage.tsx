// Station map and Layover Guide (ADDITIONS_01 C1–C3). Opened from a station page, or from a connection with
// ?from=<track>&to=<track>&arr=<ms>&dep=<ms>&a=<operator>&b=<operator>: then it shows the walk between the two
// platforms, how much time is left, and which amenities are open during the layover and close to the way.
// from / to can also be any point on the map (see resolveEndpoint): an amenity, an entrance or "my location",
// picked from the search.
import { useEffect, useMemo, useState } from 'react';
import { createPortal } from 'react-dom';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowDownUp, ArrowLeft, Clock, DoorOpen, List, LocateFixed, Map as MapIcon, Radar, Route as RouteIcon, Search, TrainFront, X } from 'lucide-react';
import {
  connectionStatus,
  instructions,
  nearestNode,
  openState,
  parseHours,
  resolveEndpoint,
  routeBetween,
  secondsFrom,
  toLocal,
  type Endpoint,
  type OpenState,
  type PoiCategory,
  type StationMap,
  type StationPoi,
} from '@clack/shared';
import { api, type StationInfo } from '../api';
import { useOperators } from '../data';
import { useNow } from '../live';
import { useSettings } from '../settings';
import { fmtDay, fmtTime } from '../format';
import { opColor } from '../map/style';
import { poiIcon, StationScene, type PlacePin, type PlatformMark } from '../map/StationScene';
import { ConnectionChip, profileOf } from '../components/Connection';

const TZ = 'Europe/Stockholm';
const FILTERS: Record<string, PoiCategory[]> = {
  toilets: ['toilet'],
  food: ['cafe', 'restaurant', 'kiosk'],
  shops: ['shop', 'pharmacy'],
  tickets: ['ticket'],
  lockers: ['locker'],
  info: ['info', 'waiting', 'atm'],
};
/** "Along my path": amenities at most this many seconds' walk from the route. */
const ALONG_SECONDS = 40;
const STALE_DAYS = 365;
/** "My location" only counts when it's this close to the walking graph: further out, you're not in the station. */
const NEAR_METERS = 120;

type Tr = (k: string, o?: Record<string, unknown>) => string;
const fold = (s: string) => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

export function StationMapPage() {
  const { id } = useParams();
  const { t } = useTranslation();
  const { settings } = useSettings();
  const navigate = useNavigate();
  const ops = useOperators();
  const now = useNow(30_000);
  const [params, setParams] = useSearchParams();
  const [map, setMap] = useState<StationMap | null | undefined>(undefined);
  const [info, setInfo] = useState<StationInfo | null>(null);
  const [level, setLevel] = useState<string | null>(null);
  const [filter, setFilter] = useState<string | null>(null);
  const [listView, setListView] = useState(false);
  const [poi, setPoi] = useState<StationPoi | null>(null);
  const [picked, setPicked] = useState<number | null>(null);
  const [planning, setPlanning] = useState(false);
  /** The search sheet: just looking ("find"), or choosing where a walk starts or ends. */
  const [picking, setPicking] = useState<'find' | 'from' | 'to' | null>(null);
  const [along, setAlong] = useState(false);
  const [showSteps, setShowSteps] = useState(false);

  useEffect(() => {
    if (!id) return;
    api.station(id).then(setInfo, () => setInfo(null));
    api.stationMap(id).then(setMap, () => setMap(null));
  }, [id]);

  const from = params.get('from');
  const to = params.get('to');
  const arr = params.get('arr') ? Number(params.get('arr')) : null;
  const dep = params.get('dep') ? Number(params.get('dep')) : null;
  const profile = profileOf(settings);
  const fromE = useMemo(() => (map ? resolveEndpoint(map, from) : null), [map, from]);
  const toE = useMemo(() => (map ? resolveEndpoint(map, to) : null), [map, to]);
  const route = useMemo(() => (map ? routeBetween(map, fromE, toE, profile) : null), [map, fromE, toE, profile.pace, profile.stepFree, profile.luggage]);
  // Reference time for open/closed: the layover window, a picked time, or now.
  const window_: [number, number] = arr && dep ? [arr, dep] : picked ? [picked, picked] : [now, now];
  const poiState = (p: StationPoi): OpenState => openState(p.opening_hours, window_[0], window_[1]).state;
  const detours = useMemo(() => (map && route && along ? secondsFrom(map, route.nodes.map((n) => n.id), profile) : null), [map, route, along]);
  const dimPoi = (p: StationPoi) => (filter !== null && !FILTERS[filter]!.includes(p.category)) || (detours !== null && !((detours.get(p.node) ?? Infinity) <= ALONG_SECONDS));

  // Show the level the walk starts on (or the main level), and again whenever the start changes.
  useEffect(() => {
    if (!map) return;
    const start = fromE ?? toE;
    if (start) setLevel(start.node.level);
    else setLevel((l) => l ?? map.levels.find((x) => x.order === 0)?.id ?? map.levels[0]!.id);
  }, [map, fromE?.spec, toE?.spec]);

  if (map === undefined) return <main className="page"><div className="skeleton-card" /></main>;
  if (map === null || !level)
    return (
      <main className="page">
        <button className="link-button back-link" onClick={() => navigate(-1)}>
          <ArrowLeft size={18} /> {t('common.back')}
        </button>
        <p className="muted">{t('stationMap.none')}</p>
      </main>
    );

  const levelName = (lid: string) => map.levels.find((l) => l.id === lid)?.name ?? lid;
  const label = (e: Endpoint) => endpointLabel(t, e, levelName);
  // Track ends get a chip on their platform; any other end a pin on its spot.
  const marks: PlatformMark[] = [];
  const pins: PlacePin[] = [];
  const layover = Boolean(arr && dep);
  if (fromE?.platform) marks.push({ platformId: fromE.platform.id, color: opColor(params.get('a') ? ops.get(params.get('a')!)?.brandColor : null), label: arr ? t('stationMap.arriveChip', { track: fromE.track, time: fmtTime(arr, TZ, settings.clock) }) : t('stationMap.fromChip', { track: fromE.track }) });
  else if (fromE) pins.push({ x: fromE.poi?.x ?? fromE.node.x, y: fromE.poi?.y ?? fromE.node.y, level: fromE.node.level, label: label(fromE), kind: fromE.kind === 'me' ? 'me' : 'from' });
  if (toE?.platform) marks.push({ platformId: toE.platform.id, color: opColor(params.get('b') ? ops.get(params.get('b')!)?.brandColor : null), label: dep ? t('stationMap.departChip', { track: toE.track, time: fmtTime(dep, TZ, settings.clock) }) : t('stationMap.toChip', { track: toE.track }) });
  else if (toE) pins.push({ x: toE.poi?.x ?? toE.node.x, y: toE.poi?.y ?? toE.node.y, level: toE.node.level, label: label(toE), kind: 'to' });
  const conn =
    layover && from && to && fromE?.kind === 'track' && toE?.kind === 'track'
      ? connectionStatus({ arrival: arr, departure: dep, arrivalPlatform: from, departurePlatform: to, canceledA: params.get('xa') === '1', canceledB: params.get('xb') === '1', walkSeconds: route?.seconds ?? null, sizeClass: info?.sizeClass ?? 'large', timesLive: params.get('live') === '1' })
      : null;
  const steps = route ? instructions(map, route, fromE, toE) : [];
  const setRoute = (f: string | null, tt: string | null) => {
    const q = new URLSearchParams(params);
    if (f) q.set('from', f);
    else q.delete('from');
    if (tt) q.set('to', tt);
    else q.delete('to');
    // A layover's times only belong to the two tracks they came with.
    if (!(f && tt && !f.includes(':') && !tt.includes(':'))) for (const k of ['arr', 'dep', 'a', 'b', 'xa', 'xb']) q.delete(k);
    setParams(q, { replace: true });
  };
  /** Set one end without the search open (from an amenity's sheet). */
  const pickAs = (end: 'from' | 'to', spec: string) => {
    if (end === 'from') setRoute(spec, to === spec ? null : to);
    else setRoute(from === spec ? null : from, spec);
    setPlanning(true);
    setPicking(null);
  };
  // From the search: a start when choosing one, otherwise where to go.
  const pick = (spec: string) => pickAs(picking === 'from' ? 'from' : 'to', spec);
  const clearRoute = () => {
    setRoute(null, null);
    setPlanning(false);
    setAlong(false);
    setShowSteps(false);
  };
  const quality = map.quality === 'hand_curated' ? t('stationMap.quality.hand_curated', { date: fmtDay(Date.parse(map.updated), TZ) }) : t('stationMap.quality.osm_draft');
  const poisSorted = [...map.pois].sort((a, b) => {
    const rank = (p: StationPoi) => ({ open: 0, closing_soon: 1, unknown: 2, closed: 3 })[poiState(p)];
    return rank(a) - rank(b) || a.category.localeCompare(b.category) || a.name.localeCompare(b.name);
  });

  return (
    <div className="station-map-page">
      {listView ? (
        <main className="page station-list-view">
          <ul className="poi-list">
            {poisSorted
              .filter((p) => !dimPoi(p))
              .map((p) => (
                <PoiRow key={p.id} p={p} state={poiState(p)} level={levelName(p.level)} detour={detours?.get(p.node) ?? null} onClick={() => setPoi(p)} />
              ))}
          </ul>
        </main>
      ) : (
        <StationScene
          map={map}
          level={level}
          route={route}
          marks={marks}
          pins={pins}
          poiState={poiState}
          dimPoi={dimPoi}
          onPoi={setPoi}
          onPlatform={() => undefined}
          fitTo={`${from}|${to}|${level}`}
          insets={{ top: 140, bottom: layover ? 250 : from || to || planning ? 320 : 150 }}
        />
      )}

      <header className="station-map-head">
        <button className="map-button" onClick={() => navigate(-1)} aria-label={t('common.back')}>
          <ArrowLeft size={18} />
        </button>
        <div className="station-map-title">
          <h1>{map.name}</h1>
          <span className="caption">{quality}</span>
        </div>
        <button className="map-button" onClick={() => setPicking('find')} aria-label={t('stationMap.search')} title={t('stationMap.search')}>
          <Search size={18} />
        </button>
        <Link className="map-button" to={`/stations/${map.station_id}`} aria-label={t('stationMap.departures')} title={t('stationMap.departures')}>
          <TrainFront size={18} />
        </Link>
        <Link className="map-button" to="/explore" aria-label={t('liveMap.showAll')} title={t('liveMap.showAll')}>
          <Radar size={18} />
        </Link>
      </header>

      <div className="station-map-filters chip-row">
        {Object.keys(FILTERS).map((f) => (
          <button key={f} className={filter === f ? 'chip-button active' : 'chip-button'} aria-pressed={filter === f} onClick={() => setFilter(filter === f ? null : f)}>
            {t(`stationMap.filters.${f}`)}
          </button>
        ))}
      </div>

      <div className="station-map-side">
        {map.levels.length > 1 &&
          !listView &&
          [...map.levels]
            .sort((a, b) => b.order - a.order)
            .map((l) => (
              <button key={l.id} className={l.id === level ? 'level-chip active' : 'level-chip'} onClick={() => setLevel(l.id)} aria-pressed={l.id === level} title={l.name}>
                {l.order > 0 ? `+${l.order}` : l.order}
              </button>
            ))}
        <button className="map-button small" onClick={() => setListView(!listView)} aria-label={listView ? t('stationMap.map') : t('stationMap.list')} title={listView ? t('stationMap.map') : t('stationMap.list')}>
          {listView ? <MapIcon size={16} /> : <List size={16} />}
        </button>
      </div>

      <div className="station-map-level caption">{levelName(level)}</div>

      {/* Bottom: the walk (Layover Guide or any two points), or "Directions" and the reference time. */}
      <section className="station-map-bottom card">
        {from || to || planning ? (
          <>
            {layover ? (
              <div className="walk-head">
                <span className="walk-big tabular">{route ? t('stationMap.walk', { min: Math.max(1, Math.round(route.seconds / 60)) }) : '—'}</span>
                {conn && <ConnectionChip result={conn} />}
                <button className="icon-button small" onClick={clearRoute} aria-label={t('common.close')}>
                  <X size={16} />
                </button>
              </div>
            ) : (
              <div className="route-ends">
                <EndButton caption={t('stationMap.from')} value={fromE ? label(fromE) : null} me={fromE?.kind === 'me'} onClick={() => setPicking('from')} />
                <button className="icon-button small" onClick={clearRoute} aria-label={t('common.close')}>
                  <X size={16} />
                </button>
                <EndButton caption={t('stationMap.to')} value={toE ? label(toE) : null} me={toE?.kind === 'me'} onClick={() => setPicking('to')} />
                <button className="icon-button small" onClick={() => setRoute(to, from)} aria-label={t('stationMap.swap')} title={t('stationMap.swap')} disabled={!from && !to}>
                  <ArrowDownUp size={16} />
                </button>
              </div>
            )}
            {!layover && fromE && toE && route && (
              <span className="walk-big tabular">{route.seconds < 30 ? t('stationMap.here') : t('stationMap.walk', { min: Math.max(1, Math.round(route.seconds / 60)) })}</span>
            )}
            {fromE && toE && !route && <p className="caption">{settings.stepFree ? t('stationMap.noStepFree') : t('stationMap.noRoute')}</p>}
            {(fromE?.kind === 'me' || toE?.kind === 'me') && <p className="caption">{t('stationMap.locationNote', { level: levelName((fromE?.kind === 'me' ? fromE : toE)!.node.level) })}</p>}
            {layover && <p className="caption">{t('stationMap.layover', { from: fmtTime(arr!, TZ, settings.clock), to: fmtTime(dep!, TZ, settings.clock), min: Math.round((dep! - arr!) / 60_000) })}</p>}
            {route && route.steps.length > 0 && (
              <div className="chip-row">
                <button className="chip-button" onClick={() => setShowSteps(!showSteps)} aria-expanded={showSteps}>
                  <RouteIcon size={14} /> {t('stationMap.steps')}
                </button>
                <button className={along ? 'chip-button active' : 'chip-button'} onClick={() => setAlong(!along)} aria-pressed={along}>
                  {t('stationMap.alongPath')}
                </button>
              </div>
            )}
            {showSteps && route && (
              <ol className="walk-steps">
                {steps.map((s, i) => (
                  <li key={i}>
                    {t(`stationMap.step.${s.key}`, { track: s.track, place: s.endpoint ? label(s.endpoint) : '', level: s.level ? levelName(s.level) : '', min: Math.max(1, Math.round(s.seconds / 60)) })}
                  </li>
                ))}
              </ol>
            )}
            {showSteps && route && route.levels.length > 1 && (
              <div className="chip-row">
                {route.levels.map((l, i) => (
                  <button key={i} className={l === level ? 'level-chip active small' : 'level-chip small'} onClick={() => setLevel(l)}>
                    {i + 1}. {levelName(l)}
                  </button>
                ))}
              </div>
            )}
          </>
        ) : (
          <div className="chip-row">
            <button className="chip-button" onClick={() => setPlanning(true)}>
              <RouteIcon size={14} /> {t('stationMap.directions')}
            </button>
            <label className="chip-button time-chip">
              <Clock size={14} />
              {picked ? fmtTime(picked, TZ, settings.clock) : t('stationMap.now')}
              <input
                type="time"
                aria-label={t('stationMap.pickTime')}
                onChange={(e) => {
                  const [h, mi] = e.target.value.split(':').map(Number);
                  if (h === undefined || mi === undefined || Number.isNaN(h)) return setPicked(null);
                  const d = new Date();
                  d.setHours(h, mi, 0, 0);
                  setPicked(d.getTime());
                }}
              />
            </label>
            {picked && (
              <button className="chip-button" onClick={() => setPicked(null)}>
                {t('stationMap.now')}
              </button>
            )}
          </div>
        )}
        <p className="caption map-attrib-inline">{t('stationMap.hoursNote')} · © OpenStreetMap contributors</p>
      </section>

      {picking && (
        <PlaceSearch
          map={map}
          mode={picking}
          level={level}
          levelName={levelName}
          poiState={poiState}
          onPick={pick}
          onPoi={(p) => {
            setPicking(null);
            setPoi(p);
          }}
          onClose={() => setPicking(null)}
        />
      )}

      {poi && (
        <PoiSheet
          p={poi}
          state={openState(poi.opening_hours, window_[0], window_[1])}
          level={levelName(poi.level)}
          detour={detours?.get(poi.node) ?? null}
          onClose={() => setPoi(null)}
          onRoute={(end) => {
            setPoi(null);
            pickAs(end, `p:${poi.id}`);
          }}
        />
      )}
    </div>
  );
}

/** What to call a point in the UI: "Track 11", the shop's name, "North-west entrance · Upper hall". */
function endpointLabel(t: Tr, e: Endpoint, levelName: (id: string) => string): string {
  if (e.kind === 'track') return t('stationMap.trackN', { track: e.track });
  if (e.kind === 'poi') return e.poi!.name || t(`stationMap.cat.${e.poi!.category}`);
  if (e.kind === 'me') return t('stationMap.myLocationApprox');
  return nodeLabel(t, e.node, levelName);
}

/** Unnamed entrances are told apart by where they are from the station's middle (true north). */
function nodeLabel(t: Tr, n: StationMap['nodes'][number], levelName: (id: string) => string, centre?: [number, number]): string {
  if (n.name) return n.name;
  if (n.type !== 'entrance') return levelName(n.level);
  if (!centre) return t('stationMap.entranceOn', { level: levelName(n.level) });
  const deg = (Math.atan2(n.x - centre[0], centre[1] - n.y) * 180) / Math.PI;
  const dir = ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw'][Math.round(((deg + 360) % 360) / 45) % 8]!;
  return t('stationMap.entranceDir', { dir: t(`stationMap.compass.${dir}`), level: levelName(n.level) });
}

function EndButton({ caption, value, me, onClick }: { caption: string; value: string | null; me?: boolean; onClick: () => void }) {
  const { t } = useTranslation();
  return (
    <button className="route-end" onClick={onClick}>
      <span className="caption">{caption}</span>
      {me && <LocateFixed size={14} />}
      <span className={value ? 'route-end-value' : 'route-end-value placeholder'}>{value ?? t('stationMap.choose')}</span>
    </button>
  );
}

/** Search the station: tracks, entrances and amenities. Picking a start or an end also offers "My location". */
function PlaceSearch({
  map,
  mode,
  level,
  levelName,
  poiState,
  onPick,
  onPoi,
  onClose,
}: {
  map: StationMap;
  mode: 'find' | 'from' | 'to';
  level: string;
  levelName: (id: string) => string;
  poiState: (p: StationPoi) => OpenState;
  onPick: (spec: string) => void;
  onPoi: (p: StationPoi) => void;
  onClose: () => void;
}) {
  const { t } = useTranslation();
  const [q, setQ] = useState('');
  const [loc, setLoc] = useState<'idle' | 'busy' | 'far' | 'denied'>('idle');
  const query = fold(q.trim());
  const centre = useMemo<[number, number]>(() => {
    const ns = map.platforms.map((p) => map.nodes.find((n) => n.id === p.node)!);
    return [ns.reduce((s, n) => s + n.x, 0) / ns.length, ns.reduce((s, n) => s + n.y, 0) / ns.length];
  }, [map]);
  const tracks = useMemo(() => [...new Set(map.platforms.flatMap((p) => p.tracks))].sort((a, b) => Number(a) - Number(b) || a.localeCompare(b)), [map]);
  const entrances = useMemo(() => {
    const seen = new Set<string>();
    return map.nodes
      .filter((n) => n.type === 'entrance')
      .map((n) => ({ n, label: nodeLabel(t, n, levelName, centre) }))
      .filter((e) => !seen.has(e.label) && seen.add(e.label));
  }, [map, centre, t]);
  const matches = (...texts: (string | undefined)[]) => !query || texts.some((x) => x && fold(x).includes(query));
  const shownTracks = tracks.filter((x) => !query || x === query || x.startsWith(query) || fold(t('stationMap.trackN', { track: x })).includes(query));
  const shownEntrances = entrances.filter((e) => matches(e.label, t('stationMap.entrance')));
  const shownPois = map.pois
    .filter((p) => matches(p.name, t(`stationMap.cat.${p.category}`), p.icon?.replace('_', ' ')))
    .sort((a, b) => {
      const rank = (p: StationPoi) => ({ open: 0, closing_soon: 1, unknown: 2, closed: 3 })[poiState(p)];
      return rank(a) - rank(b) || (a.name || a.category).localeCompare(b.name || b.category, 'sv');
    });

  const locate = () => {
    if (!('geolocation' in navigator)) return setLoc('denied');
    setLoc('busy');
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const [x, y] = toLocal(map, pos.coords.latitude, pos.coords.longitude);
        // Indoors the fix is rough, so the radius grows with the reported accuracy.
        const n = nearestNode(map, level, x, y, NEAR_METERS + Math.min(pos.coords.accuracy ?? 0, 150));
        if (!n) return setLoc('far');
        setLoc('idle');
        onPick(`me:${n.id}`);
      },
      () => setLoc('denied'),
      { enableHighAccuracy: true, timeout: 12_000, maximumAge: 30_000 },
    );
  };

  const title = mode === 'from' ? t('stationMap.pickFrom') : mode === 'to' ? t('stationMap.pickTo') : t('stationMap.searchTitle', { station: map.name });
  // Portalled: the map page is its own stacking context under the tab bar.
  return createPortal(
    <div className="sheet-backdrop" onClick={onClose}>
      <section className="board-sheet place-search" role="dialog" aria-modal="true" aria-label={title} onClick={(e) => e.stopPropagation()}>
        <header className="board-sheet-head">
          <span className="board-sheet-title">{title}</span>
          <button className="icon-button small" onClick={onClose} aria-label={t('common.close')}>
            <X size={18} />
          </button>
        </header>
        <input className="search-field" type="search" autoFocus value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('stationMap.searchPlaceholder')} aria-label={t('stationMap.search')} />
        {mode !== 'find' && !query && (
          <button className="poi-row" onClick={locate} disabled={loc === 'busy'}>
            <span className="poi-badge me">
              <LocateFixed size={16} />
            </span>
            <span className="poi-main">
              <span className="strong">{t('stationMap.myLocation')}</span>
              <span className="caption">
                {loc === 'busy' ? t('stationMap.locating') : loc === 'far' ? t('stationMap.notHere', { station: map.name }) : loc === 'denied' ? t('stationMap.noLocation') : t('stationMap.myLocationHint', { level: levelName(level) })}
              </span>
            </span>
          </button>
        )}
        {shownTracks.length > 0 && (
          <div className="place-group">
            <span className="caption upper">{t('stationMap.tracks')}</span>
            <div className="track-grid">
              {shownTracks.map((x) => (
                <button key={x} className="chip-button track-pick" onClick={() => onPick(x)}>
                  {x}
                </button>
              ))}
            </div>
          </div>
        )}
        {shownEntrances.length > 0 && (
          <div className="place-group">
            <span className="caption upper">{t('stationMap.entrances')}</span>
            <ul className="poi-list">
              {shownEntrances.map(({ n, label }) => (
                <li key={n.id}>
                  <button className="poi-row" onClick={() => onPick(`n:${n.id}`)}>
                    <span className="poi-badge">
                      <DoorOpen size={16} />
                    </span>
                    <span className="poi-main">
                      <span className="strong">{label}</span>
                      <span className="caption">{levelName(n.level)}</span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          </div>
        )}
        {shownPois.length > 0 && (
          <div className="place-group">
            <span className="caption upper">{t('stationMap.places')}</span>
            <ul className="poi-list">
              {shownPois.map((p) => (
                <PoiRow key={p.id} p={p} state={poiState(p)} level={levelName(p.level)} detour={null} onClick={() => (mode === 'find' ? onPoi(p) : onPick(`p:${p.id}`))} />
              ))}
            </ul>
          </div>
        )}
        {query && !shownTracks.length && !shownEntrances.length && !shownPois.length && <p className="muted">{t('stationMap.noResults', { q: q.trim() })}</p>}
      </section>
    </div>,
    document.body,
  );
}

function stateLabel(t: (k: string, o?: Record<string, unknown>) => string, s: { state: OpenState; closesAt: number | null }, clock: '24h' | '12h') {
  if (s.state === 'closing_soon') return s.closesAt ? t('stationMap.closesAt', { time: fmtTime(s.closesAt, TZ, clock) }) : t('stationMap.state.closing_soon');
  return t(`stationMap.state.${s.state}`);
}

function PoiRow({ p, state, level, detour, onClick }: { p: StationPoi; state: OpenState; level: string; detour: number | null; onClick: () => void }) {
  const { t } = useTranslation();
  const Icon = poiIcon(p);
  return (
    <li>
      <button className={`poi-row ${state}`} onClick={onClick}>
        <span className={`poi-badge cat-${p.category}`}>
          <Icon size={16} />
        </span>
        <span className="poi-main">
          <span className="strong">{p.name || t(`stationMap.cat.${p.category}`)}</span>
          <span className="caption">
            {t(`stationMap.cat.${p.category}`)} · {level}
            {detour !== null && detour <= ALONG_SECONDS ? ` · ${t('stationMap.detour', { min: Math.max(1, Math.ceil((detour * 2) / 60)) })}` : ''}
          </span>
        </span>
        <span className={`poi-state ${state}`}>{t(`stationMap.state.${state}`)}</span>
      </button>
    </li>
  );
}

function PoiSheet({
  p,
  state,
  level,
  detour,
  onClose,
  onRoute,
}: {
  p: StationPoi;
  state: { state: OpenState; closesAt: number | null };
  level: string;
  detour: number | null;
  onClose: () => void;
  onRoute: (end: 'from' | 'to') => void;
}) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const Icon = poiIcon(p);
  const stale = p.hours_verified ? Date.now() - Date.parse(p.hours_verified) > STALE_DAYS * 86400_000 : false;
  const fee = p.fee === 'free' ? t('stationMap.free') : p.fee ? t('stationMap.fee', { amount: p.fee.amount }) : null;
  return createPortal(
    <div className="sheet-backdrop" onClick={onClose}>
      <section className="board-sheet" role="dialog" aria-modal="true" aria-label={p.name} onClick={(e) => e.stopPropagation()}>
        <header className="board-sheet-head">
          <span className={`poi-badge cat-${p.category}`}>
            <Icon size={18} />
          </span>
          <span className="strong">{p.name || t(`stationMap.cat.${p.category}`)}</span>
          <button className="icon-button small" onClick={onClose} aria-label={t('common.close')}>
            <X size={18} />
          </button>
        </header>
        <div className="chip-row">
          <span className={`chip poi-state ${state.state}`}>{stateLabel(t, state, settings.clock)}</span>
          <span className="chip">{t(`stationMap.cat.${p.category}`)}</span>
          <span className="chip">{level}</span>
          {fee && <span className="chip">{fee}</span>}
          {detour !== null && detour <= ALONG_SECONDS && <span className="chip">{t('stationMap.detour', { min: Math.max(1, Math.ceil((detour * 2) / 60)) })}</span>}
        </div>
        {p.opening_hours ? (
          <p>
            <span className="caption upper">{t('stationMap.hours')}</span>
            <br />
            <span className="tabular">{parseHours(p.opening_hours) ? p.opening_hours.replace(/;\s*/g, ' · ') : p.opening_hours}</span>
          </p>
        ) : (
          <p className="caption">{t('stationMap.hoursUnverified')}</p>
        )}
        <p className="caption">
          {p.hours_verified ? t('stationMap.verified', { date: fmtDay(Date.parse(p.hours_verified), TZ) }) : p.hours_source === 'osm' ? t('stationMap.fromOsm') : t('stationMap.hoursUnverified')}
          {stale ? ` · ${t('stationMap.stale')}` : ''}
        </p>
        <p className="caption">{t('stationMap.hoursNote')}</p>
        <div className="chip-row">
          <button className="button small" onClick={() => onRoute('to')}>
            <RouteIcon size={14} /> {t('stationMap.routeHere')}
          </button>
          <button className="chip-button" onClick={() => onRoute('from')}>
            {t('stationMap.startHere')}
          </button>
        </div>
      </section>
    </div>,
    document.body,
  );
}
