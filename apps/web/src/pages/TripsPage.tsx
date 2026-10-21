// Trips home (DESIGN §4, product brief §5): Upcoming | Past. Upcoming leads with one featured card (route map on
// top, the journey under it) for the train you're on, else the next one; the rest are compact rows. Past is grouped
// by month.
import { Fragment, useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { decodePolyline, type LatLon } from '@clack/shared';
import { Clock, Compass, Eye, Map as MapIcon, Plus, Search, Stamp } from 'lucide-react';
import { api, ms, type Follow, type Leg, type LegDetail } from '../api';
import { OperatorBadge } from '../components/OperatorBadge';
import { DelayPill } from '../components/DelayPill';
import { useSettings } from '../settings';
import { LiveChip, LiveModule } from '../components/Live';
import { JourneyCard } from '../components/Journey';
import { isLive, useLiveUpdates, useNow } from '../live';
import { isActive } from '../landing';
import { dayOffset, fmtDay, fmtDistance, fmtDuration, fmtMonth, fmtTime } from '../format';
import { opColor } from '../map/style';
import { ConnectionChip, connectionTimes, stationMapHref, useConnection, useStationMap } from '../components/Connection';
import { FlapTime } from '../components/SplitFlap';
import { useOperators } from '../data';
import { RouteMap, type MapStop } from '../map/RouteMap';
import { SettingsLink } from '../components/AppShell';
import { isFresh } from '../live';

const tzOf = (leg: Leg) => leg.origin?.tz ?? 'Europe/Stockholm';
// A late train that is still running counts as upcoming until it actually arrives.
const arrivalOf = (leg: Leg) => ms(leg.actualArr) ?? Math.max(ms(leg.schedArr) ?? 0, isLive(leg.live) ? (ms(leg.live?.arrivalEta) ?? 0) : 0);

export function countdown(t: (k: string, o?: Record<string, unknown>) => string, leg: Leg, now: number): string {
  const dep = ms(leg.actualDep) ?? ms(leg.schedDep) ?? 0;
  if (leg.canceled || leg.live?.status === 'cancelled') return t('status.cancelled');
  if (now >= arrivalOf(leg)) return t('trips.arrived');
  if (now >= dep) return t('trips.liveNow');
  if (dep - now <= 30 * 60_000) return t('trips.boarding');
  const mins = Math.round((dep - now) / 60_000);
  const d = Math.floor(mins / 1440);
  const h = Math.floor((mins % 1440) / 60);
  const m = mins % 60;
  return t('trips.departsIn', { time: d ? `${d}d ${h}h` : h ? `${h}h ${m}m` : `${m} min` });
}

/** Best-known departure and arrival: actual, else the live estimate, else the timetable shifted by the known delay. */
function expected(leg: Leg) {
  const dep = ms(leg.schedDep);
  const arr = ms(leg.schedArr);
  return {
    dep: ms(leg.actualDep) ?? (dep !== null ? dep + (leg.depDelayMin ?? 0) * 60_000 : null),
    arr: ms(leg.actualArr) ?? ms(leg.live?.arrivalEta) ?? (arr !== null ? arr + (leg.arrDelayMin ?? 0) * 60_000 : null),
  };
}

/** Departure – arrival on flip cards; a changed time shows the timetabled one struck through. */
function Times({ leg, size = 'sm', intro = false }: { leg: Leg; size?: 'sm' | 'md' | 'lg'; intro?: boolean }) {
  const { settings } = useSettings();
  const dep = ms(leg.schedDep);
  const arr = ms(leg.schedArr);
  const x = expected(leg);
  const plus = dep && arr && leg.destination ? dayOffset(dep, tzOf(leg), arr, leg.destination.tz) : 0;
  return (
    <span className="flap-range">
      <FlapTime time={x.dep} sched={dep} tz={tzOf(leg)} clock={settings.clock} size={size} intro={intro} />
      <span className="flap-range-sep">–</span>
      <FlapTime time={x.arr} sched={arr} tz={leg.destination?.tz ?? tzOf(leg)} clock={settings.clock} size={size} intro={intro} />
      {plus > 0 && <sup>+{plus}</sup>}
    </span>
  );
}

/**
 * A trip as a gradient pill (the featured card's look, smaller and quieter): used for upcoming trips under the
 * featured one, past trips, the Passport log and journeys. Upcoming ones lead with the countdown.
 */
export function LegRow({ leg, upcoming = false }: { leg: Leg; upcoming?: boolean }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const now = useNow(60_000);
  const dep = ms(leg.schedDep);
  const service = [leg.operator?.name, leg.trainNumber].filter(Boolean).join(' ');
  return (
    <Link to={`/trips/${leg.id}`} className={leg.ride === 'not_taken' ? 'leg-pill not-taken' : 'leg-pill'} style={{ ['--op' as string]: opColor(leg.operator?.brandColor) }}>
      <OperatorBadge operator={leg.operator} size={32} />
      <span className="leg-pill-main">
        {upcoming && <span className="leg-pill-when">{countdown(t, leg, now)}</span>}
        <span className="leg-pill-route">
          {leg.origin?.name} → {leg.destination?.name}
        </span>
        <span className="leg-row-meta">
          {dep ? fmtDay(dep, tzOf(leg)) : null} · <Times leg={leg} />
          {dep && ms(leg.schedArr) ? ` · ${fmtDuration(((ms(leg.schedArr) ?? 0) - dep) / 60_000)}` : ''}
        </span>
        <span className="leg-row-meta">{[service || null, upcoming && leg.depPlatform ? t('trips.platform', { platform: leg.depPlatform }) : null].filter(Boolean).join(' · ')}</span>
      </span>
      <span className="leg-row-side">
        {leg.ride === 'review' && <span className="chip review-chip">{t('record.needsCheck')}</span>}
        {leg.ride === 'not_taken' && <span className="chip">{t('record.notTaken')}</span>}
        {upcoming ? (
          leg.depDelayMin !== null && <DelayPill delay={leg.depDelayMin} canceled={leg.canceled} />
        ) : (
          <>
            <DelayPill delay={leg.dataQuality === 'scheduled_only' && leg.status === 'planned' ? undefined : leg.arrDelayMin} canceled={leg.canceled} />
            <span className="caption">{leg.isEstimatedGeometry ? t('trips.approxDistance', { distance: fmtDistance(leg.distanceM, settings.distanceUnit) }) : fmtDistance(leg.distanceM, settings.distanceUnit)}</span>
          </>
        )}
      </span>
    </Link>
  );
}

/**
 * Between two trips that meet at a station (brief §7): how long you have there, the arrival and departure on flip
 * cards (a delay strikes the timetabled time), the tracks when known. With a station map it opens the Layover
 * Guide: the walk, the time left, and what's open on the way.
 */
function Layover({ a, b }: { a: Leg; b: Leg }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const stationId = a.destination?.id ?? null;
  const { info } = useStationMap(stationId);
  const { arrival, departure } = connectionTimes(a, b);
  if (arrival === null || departure === null) return null;
  const min = Math.round((departure - arrival) / 60_000);
  const schedA = ms(a.schedArr);
  const schedB = ms(b.schedDep);
  const schedMin = schedA !== null && schedB !== null ? Math.round((schedB - schedA) / 60_000) : null;
  const tracks = a.arrPlatform || b.depPlatform ? t('connection.tracks', { from: a.arrPlatform ?? '?', to: b.depPlatform ?? '?' }) : null;
  const tz = a.destination?.tz ?? 'Europe/Stockholm';
  const body = (
    <>
      <span className="layover-line" aria-hidden="true" />
      <span className="layover-main">
        <span className="layover-text">
          <Clock size={14} aria-hidden="true" />
          {min < 0 ? (
            t('trips.layoverMissed', { station: a.destination?.name ?? '' })
          ) : (
            <>
              {schedMin !== null && schedMin !== min && <s className="flap-old">{fmtDuration(schedMin)}</s>}
              <span className={schedMin !== null && schedMin !== min ? 'accent-text' : undefined}>{fmtDuration(min)}</span> {t('trips.layoverAt', { station: a.destination?.name ?? '' })}
            </>
          )}
        </span>
        <span className="layover-times caption">
          <FlapTime time={arrival} sched={schedA} tz={tz} clock={settings.clock} />
          <span>→</span>
          <FlapTime time={departure} sched={schedB} tz={tz} clock={settings.clock} />
          {tracks && <span>· {tracks}</span>}
        </span>
        {info?.hasMap && (
          <span className="layover-open">
            <MapIcon size={14} /> {t('trips.layoverMap')} ›
          </span>
        )}
      </span>
    </>
  );
  const cls = min < 0 ? 'layover at-risk' : 'layover';
  return info?.hasMap && stationId ? (
    <Link to={stationMapHref(stationId, a, b)} className={`${cls} linked`} aria-label={t('trips.layoverOpen', { station: a.destination?.name ?? '' })}>
      {body}
    </Link>
  ) : (
    <div className={cls}>{body}</div>
  );
}

/** Do these two trips meet: off one and onto the next at the same station, within half a day? */
export function meets(a: Leg, b: Leg): boolean {
  if (!a.destination || a.destination.id !== b.origin?.id) return false;
  const arr = ms(a.actualArr) ?? ms(a.schedArr);
  const dep = ms(b.schedDep);
  return arr !== null && dep !== null && dep - arr < 12 * 3600_000 && dep - arr > -2 * 3600_000;
}

/** The featured card's full leg (stops for the live module, geometry for the map), fetched once per leg. */
const details = new Map<string, LegDetail>();

/** How long after arriving a trip stays featured (as "arrived", with its Passport link) when nothing is ahead. */
const RECENT_ARRIVAL_MS = 6 * 3600_000;

/** The featured journey (brief §5.2): one tappable card, route map on top, the journey under it. */
function Featured({ leg, next, state }: { leg: Leg; next?: Leg; state: 'upcoming' | 'active' | 'arrived' }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const now = useNow(state === 'active' ? 1000 : 30_000);
  const [detail, setDetail] = useState<LegDetail | undefined>(details.get(leg.id));
  useEffect(() => {
    if (details.has(leg.id)) return setDetail(details.get(leg.id));
    let live = true;
    api.leg(leg.id).then((d) => {
      details.set(leg.id, d);
      if (live) setDetail(d);
    }, () => undefined);
    return () => {
      live = false;
    };
  }, [leg.id]);
  const color = opColor(leg.operator?.brandColor);
  const geo = useMemo(() => {
    if (!detail) return null;
    const ridden = detail.stops.filter((x) => x.role === 'board' || x.role === 'through' || x.role === 'alight');
    const route: LatLon[] = detail.geometry ? decodePolyline(detail.geometry) : ridden.map((x) => [x.lat, x.lon]);
    const ends: MapStop[] = ridden.filter((x) => x.role !== 'through').map((x) => ({ lat: x.lat, lon: x.lon, name: x.name, kind: 'end' }));
    return { route, stops: ends };
  }, [detail]);
  const live = leg.live;
  // Only a fresh position draws the train, and only then is the route split into travelled and ahead (brief §5.2).
  const grounded = state === 'active' && live && isFresh(live, now) && live.lat !== null && live.lon !== null && live.positionSource !== null;
  const train = grounded ? { lat: live!.lat!, lon: live!.lon!, bearing: live!.bearing, estimated: live!.positionSource === 'estimated' } : null;
  const service = [leg.operator?.name, leg.trainNumber].filter(Boolean).join(' ');
  return (
    <Link to={`/trips/${leg.id}`} className={`featured ${state}`} style={{ ['--op' as string]: color }} aria-label={t('trips.viewJourney', { from: leg.origin?.name, to: leg.destination?.name })}>
      <div className="featured-map" aria-hidden="true">
        {geo && geo.route.length > 1 ? (
          <RouteMap color={color} route={geo.route} stops={geo.stops} interactive={false} controls={false} train={train} progress={grounded ? live!.progress : null} />
        ) : (
          <div className="featured-map-empty" />
        )}
        <span className="featured-map-tag caption">
          {state === 'upcoming' ? t('trips.routePreview') : state === 'arrived' ? t('trips.routeSummary') : grounded ? (train!.estimated ? t('live.estimatedPosition') : t('live.livePosition')) : t('trips.noPositionShort')}
        </span>
      </div>
      <div className="featured-body">
        <div className="hero-top">
          <OperatorBadge operator={leg.operator} size={28} />
          <span className="hero-number">{service || t('trips.train')}</span>
          {state === 'upcoming' && <span className="chip">{t('trips.planned')}</span>}
          {state === 'arrived' && <span className="chip">{t('trips.arrived')}</span>}
          {state === 'active' && live && <LiveChip live={live} now={now} />}
        </div>
        <h2 className="hero-route">
          {leg.origin?.name} → {leg.destination?.name}
        </h2>
        <div className="hero-times tabular">
          <Times leg={leg} size="lg" intro />
        </div>
        {state === 'active' && live ? (
          <>
            <div className="hero-bottom">
              <DelayPill delay={live.arrivalDelayMin} canceled={leg.canceled} />
            </div>
            {next ? <HeroConnection a={leg} b={next} /> : <LiveModule leg={leg} live={live} stops={detail?.stops ?? []} now={now} compact />}
          </>
        ) : state === 'arrived' ? (
          <div className="hero-bottom">
            <span className="caption">{leg.actualArr ? t('trips.arrivedAt', { time: fmtTime(ms(leg.actualArr), leg.destination?.tz ?? tzOf(leg), settings.clock) }) : t('trips.scheduledTimes')}</span>
            <span className="featured-link caption">
              <Stamp size={14} /> {t('trips.inPassport')}
            </span>
          </div>
        ) : (
          <div className="hero-bottom">
            <span className="pill">{countdown(t, leg, now)}</span>
            {leg.depPlatform && <span className="chip">{t('trips.platform', { platform: leg.depPlatform })}</span>}
            {leg.depDelayMin !== null && <DelayPill delay={leg.depDelayMin} canceled={leg.canceled} />}
          </div>
        )}
      </div>
    </Link>
  );
}

/** Nothing featured: say so, and offer the two ways on. */
function NothingAhead() {
  const { t } = useTranslation();
  return (
    <section className="hero hero-empty">
      <svg className="dotted-line" viewBox="0 0 300 60" aria-hidden="true">
        <path d="M10 45 C 80 5, 200 70, 290 15" />
        <circle cx="10" cy="45" r="5" />
        <circle cx="290" cy="15" r="5" />
      </svg>
      <h2>{t('trips.whereNext')}</h2>
      <p>{t('trips.whereNextBody')}</p>
      <div className="empty-actions">
        <Link to="/add" className="button primary">
          <Plus size={18} /> {t('trips.findTrain')}
        </Link>
        <Link to="/explore" className="button">
          <Compass size={18} /> {t('trips.exploreTrains')}
        </Link>
      </div>
    </section>
  );
}

/** Trains you follow on Explore: watched, not travelled, so they sit apart from your trips and never count. */
function Following({ follows }: { follows: Follow[] }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const ops = useOperators();
  if (!follows.length) return null;
  return (
    <section className="following-section">
      <h3 className="month-header">{t('trips.following')}</h3>
      {follows.map((f) => {
        const op = f.operatorId ? ops.get(f.operatorId) : undefined;
        return (
          <Link
            key={`${f.trainNumber}|${f.serviceDate}`}
            to={`/explore?${new URLSearchParams({ train: f.trainNumber, date: f.serviceDate })}`}
            className="leg-pill following-pill"
            style={{ ['--op' as string]: opColor(op?.brandColor) }}
          >
            <OperatorBadge operator={op} size={30} />
            <span className="leg-pill-main">
              <span className="leg-pill-route">{f.label ?? t('liveMap.train', { number: f.trainNumber })}</span>
              <span className="leg-row-meta">{[op?.name, f.trainNumber].filter(Boolean).join(' ')}</span>
              <span className="leg-row-meta">{f.train?.next ? t('live.nextStop', { name: f.train.next, time: fmtTime(f.train.nextEta, 'Europe/Stockholm', settings.clock) }) : t('trips.notRunning')}</span>
            </span>
            <span className="leg-row-side">
              <span className="chip following-chip">
                <Eye size={12} /> {t('trips.followingChip')}
              </span>
              {f.train && <DelayPill delay={f.train.delayMin} />}
            </span>
          </Link>
        );
      })}
      <p className="caption">{t('trips.followingNote')}</p>
    </section>
  );
}

/** "Did you take this train?" (brief §8.3): trips whose reports don't settle it, with a one-tap answer. */
export function ReviewCard({ leg, onAnswer }: { leg: Leg; onAnswer: (l: Leg) => void }) {
  const { t } = useTranslation();
  const [busy, setBusy] = useState(false);
  const answer = async (a: 'yes' | 'no') => {
    setBusy(true);
    try {
      onAnswer(await api.answerRide(leg.id, a));
    } finally {
      setBusy(false);
    }
  };
  const dep = ms(leg.schedDep);
  return (
    <div className="review-card card">
      <span className="caption upper">{t('record.question')}</span>
      <Link to={`/trips/${leg.id}`} className="strong">
        {[leg.operator?.name, leg.trainNumber].filter(Boolean).join(' ')} · {leg.origin?.name} → {leg.destination?.name}
      </Link>
      <span className="caption">
        {dep ? fmtDay(dep, tzOf(leg)) : ''} · {t(`record.why.${leg.rideReason ?? 'no_reports'}`)}
      </span>
      <div className="chip-row">
        <button className="button primary small" disabled={busy} onClick={() => answer('yes')}>
          {t('record.yes')}
        </button>
        <button className="button small" disabled={busy} onClick={() => answer('no')}>
          {t('record.no')}
        </button>
      </div>
    </div>
  );
}

/** The leg you change to after this one, if they're one journey and meet at the same station. */
function nextInJourney(legs: Leg[], leg: Leg): Leg | undefined {
  if (!leg.journeyId) return undefined;
  const arr = ms(leg.schedArr) ?? 0;
  return legs
    .filter((l) => l.journeyId === leg.journeyId && l.id !== leg.id && (ms(l.schedDep) ?? 0) >= arr && l.origin?.id === leg.destination?.id)
    .sort((x, y) => (ms(x.schedDep) ?? 0) - (ms(y.schedDep) ?? 0))[0];
}

/** The next event is a change (ADDITIONS_01 C3): "Change at Hässleholm · Track 2 → 5 · 6 min walk · Tight". */
function HeroConnection({ a, b }: { a: Leg; b: Leg }) {
  const { t } = useTranslation();
  const { result } = useConnection(a, b);
  const walk = result.walkSeconds !== null ? t('connection.walk', { min: Math.max(1, Math.round(result.walkSeconds / 60)) }) : null;
  const tracks = a.arrPlatform || b.depPlatform ? t('connection.tracks', { from: a.arrPlatform ?? '?', to: b.depPlatform ?? '?' }) : null;
  return (
    <div className="hero-connection">
      <span>{[t('connection.changeAt', { station: a.destination?.name ?? '' }), tracks, walk].filter(Boolean).join(' · ')}</span>
      <ConnectionChip result={result} />
    </div>
  );
}

export function TripsPage() {
  const { t } = useTranslation();
  const [legs, setLegs] = useState<Leg[] | null>(null);
  const [error, setError] = useState(false);
  const [params] = useSearchParams();
  const [tab, setTab] = useState<'upcoming' | 'past'>(params.get('tab') === 'past' ? 'past' : 'upcoming');
  const [follows, setFollows] = useState<Follow[]>([]);
  useEffect(() => {
    api.follows().then(setFollows, () => undefined);
  }, []);
  const load = useCallback(() => {
    setError(false);
    api.legs().then(setLegs, () => setError(true));
  }, []);
  useEffect(load, [load]);
  // Live ticks: merge the new live state into the list, so the hero's progress moves without a reload.
  useLiveUpdates((u) => setLegs((ls) => ls && ls.map((l) => (l.id === u.legId ? { ...l, live: u.live } : l))));
  const now = Date.now();
  const upcoming = useMemo(() => (legs ?? []).filter((l) => arrivalOf(l) > now).sort((a, b) => (ms(a.schedDep) ?? 0) - (ms(b.schedDep) ?? 0)), [legs, now]);
  const past = useMemo(() => (legs ?? []).filter((l) => arrivalOf(l) <= now).sort((a, b) => (ms(b.schedDep) ?? 0) - (ms(a.schedDep) ?? 0)), [legs, now]);
  // Featured (brief §5.2): the train you're on, else the next departure, else one that arrived in the last hours.
  const active = upcoming.find((l) => isActive(l, now));
  const recent = past.find((l) => !l.canceled && now - arrivalOf(l) < RECENT_ARRIVAL_MS);
  const hero = active ?? upcoming[0] ?? recent;
  const heroState: 'upcoming' | 'active' | 'arrived' = hero === active && active ? 'active' : hero && hero === recent && !upcoming.includes(hero) ? 'arrived' : 'upcoming';
  const months = useMemo(() => {
    // Legs of one journey are shown together in a journey card, in travel order (DESIGN §4).
    const byJourney = new Map<string, Leg[]>();
    for (const l of past) if (l.journeyId) (byJourney.get(l.journeyId) ?? byJourney.set(l.journeyId, []).get(l.journeyId)!).push(l);
    const groups: { label: string; items: Leg[][] }[] = [];
    const done = new Set<string>();
    for (const l of past) {
      if (done.has(l.id)) continue;
      const together = (l.journeyId && byJourney.get(l.journeyId)) || [l];
      const item = [...together].sort((a, b) => (ms(a.schedDep) ?? 0) - (ms(b.schedDep) ?? 0));
      for (const x of item) done.add(x.id);
      const label = fmtMonth(ms(item[0]!.schedDep) ?? 0, tzOf(item[0]!));
      if (groups.at(-1)?.label !== label) groups.push({ label, items: [] });
      groups.at(-1)!.items.push(item);
    }
    return groups;
  }, [past]);

  return (
    <main className="page">
      <header className="page-header">
        <h1>{t('trips.title')}</h1>
        <span className="header-actions">
          <Link to="/stations" className="icon-button" aria-label={t('nav.stations')} title={t('nav.stations')}>
            <Search size={20} />
          </Link>
          <Link to="/add" className="icon-button" aria-label={t('nav.addTrain')} title={t('nav.addTrain')}>
            <Plus size={22} />
          </Link>
          <SettingsLink />
        </span>
      </header>
      <div className="segmented" role="tablist">
        {(['upcoming', 'past'] as const).map((k) => (
          <button key={k} role="tab" aria-selected={tab === k} className={tab === k ? 'active' : ''} onClick={() => setTab(k)}>
            {t(`trips.${k}`)}
          </button>
        ))}
      </div>
      {error && (
        <p className="banner error">
          {t('trips.loadError')}{' '}
          <button className="link-button" onClick={load}>
            {t('trips.retry')}
          </button>
        </p>
      )}
      {legs === null && !error && <div className="skeleton-list">{[0, 1, 2].map((i) => <div key={i} className="skeleton-row" />)}</div>}
      {legs && legs.length === 0 && (
        <section className="empty">
          <svg className="dotted-line" viewBox="0 0 300 60" aria-hidden="true">
            <path d="M10 45 C 80 5, 200 70, 290 15" />
          </svg>
          <h2>{t('trips.emptyTitle')}</h2>
          <p>{t('trips.emptyBody')}</p>
          <div className="empty-actions">
            <Link to="/add" className="button primary">
              <Plus size={18} /> {t('trips.findTrain')}
            </Link>
            <Link to="/explore" className="button">
              <Compass size={18} /> {t('trips.exploreTrains')}
            </Link>
          </div>
        </section>
      )}
      {legs && legs.length === 0 && tab === 'upcoming' && <Following follows={follows} />}
      {legs && legs.length > 0 && tab === 'upcoming' && (
        <>
          {hero ? <Featured leg={hero} state={heroState} next={heroState === 'active' ? nextInJourney(legs, hero) : undefined} /> : <NothingAhead />}
          {hero && !upcoming.length && <NothingAhead />}
          <div className="pill-list">
            {(() => {
              // A layover line between trips that meet at a station, including from the featured one.
              const rest = upcoming.filter((l) => l !== hero);
              return rest.map((l, i) => {
                const before = i === 0 ? hero : rest[i - 1];
                return (
                  <Fragment key={l.id}>
                    {before && meets(before, l) && <Layover a={before} b={l} />}
                    <LegRow leg={l} upcoming />
                  </Fragment>
                );
              });
            })()}
          </div>
          <Following follows={follows} />
        </>
      )}
      {legs && legs.length > 0 && tab === 'past' && (
        <div className="pill-list">
          {past.filter((l) => l.ride === 'review').map((l) => (
            <ReviewCard key={`r${l.id}`} leg={l} onAnswer={(d) => setLegs((ls) => ls && ls.map((x) => (x.id === d.id ? { ...x, ride: d.ride, rideReason: d.rideReason } : x)))} />
          ))}
          {past.length === 0 && <p className="muted">{t('trips.noPast')}</p>}
          {months.map((m) => (
            <section key={m.label}>
              <h3 className="month-header">{m.label}</h3>
              {m.items.map((it) => (it.length > 1 ? <JourneyCard key={it[0]!.id} legs={it} /> : <LegRow key={it[0]!.id} leg={it[0]!} />))}
            </section>
          ))}
        </div>
      )}
    </main>
  );
}
