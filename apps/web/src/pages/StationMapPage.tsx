// Station map and Layover Guide (ADDITIONS_01 C1–C3). Opened from a station page, or from a connection with
// ?from=<track>&to=<track>&arr=<ms>&dep=<ms>&a=<operator>&b=<operator>: then it shows the walk between the two
// platforms, how much time is left, and which amenities are open during the layover and close to the way.
import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, Clock, List, Map as MapIcon, Radar, Route as RouteIcon, TrainFront, X } from 'lucide-react';
import {
  connectionStatus,
  instructions,
  openState,
  parseHours,
  platformForTrack,
  routeTracks,
  secondsFrom,
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
import { POI_ICONS, StationScene, type PlatformMark } from '../map/StationScene';
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
  const route = useMemo(() => (map && from && to ? routeTracks(map, from, to, profile) : null), [map, from, to, profile.pace, profile.stepFree, profile.luggage]);
  // Reference time for open/closed: the layover window, a picked time, or now.
  const window_: [number, number] = arr && dep ? [arr, dep] : picked ? [picked, picked] : [now, now];
  const poiState = (p: StationPoi): OpenState => openState(p.opening_hours, window_[0], window_[1]).state;
  const detours = useMemo(() => (map && route && along ? secondsFrom(map, route.nodes.map((n) => n.id), profile) : null), [map, route, along]);
  const dimPoi = (p: StationPoi) => (filter !== null && !FILTERS[filter]!.includes(p.category)) || (detours !== null && !((detours.get(p.node) ?? Infinity) <= ALONG_SECONDS));

  useEffect(() => {
    if (!map || level) return;
    const start = platformForTrack(map, from);
    setLevel(start?.level ?? map.levels.find((l) => l.order === 0)?.id ?? map.levels[0]!.id);
  }, [map, from, level]);

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
  const fromP = platformForTrack(map, from);
  const toP = platformForTrack(map, to);
  const marks: PlatformMark[] = [];
  if (fromP && from) marks.push({ platformId: fromP.id, color: opColor(params.get('a') ? ops.get(params.get('a')!)?.brandColor : null), label: arr ? t('stationMap.arriveChip', { track: from, time: fmtTime(arr, TZ, settings.clock) }) : t('stationMap.fromChip', { track: from }) });
  if (toP && to) marks.push({ platformId: toP.id, color: opColor(params.get('b') ? ops.get(params.get('b')!)?.brandColor : null), label: dep ? t('stationMap.departChip', { track: to, time: fmtTime(dep, TZ, settings.clock) }) : t('stationMap.toChip', { track: to }) });
  const conn =
    arr && dep && from && to
      ? connectionStatus({ arrival: arr, departure: dep, arrivalPlatform: from, departurePlatform: to, canceledA: params.get('xa') === '1', canceledB: params.get('xb') === '1', walkSeconds: route?.seconds ?? null, sizeClass: info?.sizeClass ?? 'large' })
      : null;
  const steps = route ? instructions(map, route, from, to) : [];
  const setRoute = (f: string | null, tt: string | null) => {
    const q = new URLSearchParams(params);
    if (f) q.set('from', f);
    else q.delete('from');
    if (tt) q.set('to', tt);
    else q.delete('to');
    setParams(q, { replace: true });
  };
  const tracks = [...new Set(map.platforms.flatMap((p) => p.tracks))].sort((a, b) => Number(a) - Number(b) || a.localeCompare(b));
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
          poiState={poiState}
          dimPoi={dimPoi}
          onPoi={setPoi}
          onPlatform={() => undefined}
          fitTo={`${from}|${to}|${level}`}
          insets={{ top: 140, bottom: from && to ? 230 : 150 }}
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
        <Link className="map-button" to={`/stations/${map.station_id}`} aria-label={t('stationMap.departures')} title={t('stationMap.departures')}>
          <TrainFront size={18} />
        </Link>
        <Link className="map-button" to="/live" aria-label={t('liveMap.showAll')} title={t('liveMap.showAll')}>
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

      {/* Bottom: the walk (Layover Guide), or "Plan a change" and the reference time. */}
      <section className="station-map-bottom card">
        {from && to ? (
          <>
            <div className="walk-head">
              <span className="walk-big tabular">{route ? t('stationMap.walk', { min: Math.max(1, Math.round(route.seconds / 60)) }) : '—'}</span>
              {conn && <ConnectionChip result={conn} />}
              <button className="icon-button small" onClick={() => setRoute(null, null)} aria-label={t('common.close')}>
                <X size={16} />
              </button>
            </div>
            {!route && <p className="caption">{settings.stepFree ? t('stationMap.noStepFree') : t('stationMap.noRoute')}</p>}
            {arr && dep && <p className="caption">{t('stationMap.layover', { from: fmtTime(arr, TZ, settings.clock), to: fmtTime(dep, TZ, settings.clock), min: Math.round((dep - arr) / 60_000) })}</p>}
            {route && (
              <div className="chip-row">
                <button className="chip-button" onClick={() => setShowSteps(!showSteps)} aria-expanded={showSteps}>
                  <RouteIcon size={14} /> {t('stationMap.steps')}
                </button>
                <button className={along ? 'chip-button active' : 'chip-button'} onClick={() => setAlong(!along)} aria-pressed={along}>
                  {t('stationMap.alongPath')}
                </button>
              </div>
            )}
            {showSteps && (
              <ol className="walk-steps">
                {steps.map((s, i) => (
                  <li key={i}>{t(`stationMap.step.${s.key}`, { track: s.track, level: s.level ? levelName(s.level) : '', min: Math.max(1, Math.round(s.seconds / 60)) })}</li>
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
        ) : planning ? (
          <div className="plan-change">
            <label>
              <span className="caption">{t('stationMap.fromTrack')}</span>
              <select value={from ?? ''} onChange={(e) => setRoute(e.target.value || null, to)}>
                <option value="">—</option>
                {tracks.map((x) => (
                  <option key={x}>{x}</option>
                ))}
              </select>
            </label>
            <label>
              <span className="caption">{t('stationMap.toTrack')}</span>
              <select value={to ?? ''} onChange={(e) => setRoute(from, e.target.value || null)}>
                <option value="">—</option>
                {tracks.map((x) => (
                  <option key={x}>{x}</option>
                ))}
              </select>
            </label>
          </div>
        ) : (
          <div className="chip-row">
            <button className="chip-button" onClick={() => setPlanning(true)}>
              <RouteIcon size={14} /> {t('stationMap.planChange')}
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

      {poi && <PoiSheet p={poi} state={openState(poi.opening_hours, window_[0], window_[1])} level={levelName(poi.level)} detour={detours?.get(poi.node) ?? null} onClose={() => setPoi(null)} />}
    </div>
  );
}

function stateLabel(t: (k: string, o?: Record<string, unknown>) => string, s: { state: OpenState; closesAt: number | null }, clock: '24h' | '12h') {
  if (s.state === 'closing_soon') return s.closesAt ? t('stationMap.closesAt', { time: fmtTime(s.closesAt, TZ, clock) }) : t('stationMap.state.closing_soon');
  return t(`stationMap.state.${s.state}`);
}

function PoiRow({ p, state, level, detour, onClick }: { p: StationPoi; state: OpenState; level: string; detour: number | null; onClick: () => void }) {
  const { t } = useTranslation();
  const Icon = POI_ICONS[p.category];
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

function PoiSheet({ p, state, level, detour, onClose }: { p: StationPoi; state: { state: OpenState; closesAt: number | null }; level: string; detour: number | null; onClose: () => void }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const Icon = POI_ICONS[p.category];
  const stale = p.hours_verified ? Date.now() - Date.parse(p.hours_verified) > STALE_DAYS * 86400_000 : false;
  const fee = p.fee === 'free' ? t('stationMap.free') : p.fee ? t('stationMap.fee', { amount: p.fee.amount }) : null;
  return (
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
      </section>
    </div>
  );
}
