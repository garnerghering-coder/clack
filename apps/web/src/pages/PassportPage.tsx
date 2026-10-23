// Passport (DESIGN §8, product brief §9): everything you've ridden, by year; commuter trains per the setting.
// Collection first: the summary and your map, milestones, collections and records, then the detailed statistics
// (the trips themselves are on Trips). Every number comes from trips recorded as travelled (see apps/server/src/legs/recording.ts).
import { useEffect, useMemo, useRef, useState } from 'react';
import { SettingsLink } from '../components/AppShell';
import { ShareSheet } from '../share/ShareSheet';
import { Medal } from '../components/Medal';
import { Share2, TrainFront } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { CO2_CHOICES, type Co2Comparison } from '@clack/shared';
import { api, type CountRow, type Leg, type LegRef, type Milestone, type Passport } from '../api';
import { OperatorBadge } from '../components/OperatorBadge';
import { TrainPicture } from '../components/trains/TrainPicture';
import { Flag } from '../components/Flag';
import { MultiRouteMap } from '../map/MultiRouteMap';
import { useSettings } from '../settings';
import { fmtDistance, fmtDuration, fmtTime, locale } from '../format';
import { opColor } from '../map/style';

function Bars({
  rows,
  label,
  color,
  lead,
  unit,
}: {
  rows: CountRow[];
  label: (r: CountRow) => string;
  color: (r: CountRow) => string;
  lead?: (r: CountRow) => React.ReactNode;
  unit: 'km' | 'mi';
}) {
  const { t } = useTranslation();
  const max = Math.max(1, ...rows.map((r) => r.count));
  return (
    <ul className="bars">
      {rows.map((r) => (
        <li key={r.key} className="bar-row">
          {lead?.(r)}
          <span className="bar-main">
            <span className="bar-label">
              <span className="strong">{label(r)}</span>
              <span className="caption tabular">
                {t('passport.trainsCount', { count: r.count })} · {fmtDistance(r.distanceM, unit)}
              </span>
            </span>
            <span className="bar-track">
              <span className="bar-fill" style={{ width: `${(100 * r.count) / max}%`, background: color(r) }} />
            </span>
          </span>
        </li>
      ))}
    </ul>
  );
}

/** What a milestone takes, in words ("10 journeys", "1,000 km", "First border crossing"). */
export function milestoneLabel(t: (k: string, o?: Record<string, unknown>) => string, m: Milestone): string {
  if (m.family === 'distanceKm') return m.target >= 40_000 ? t('passport.milestone.earth') : t('passport.milestone.distanceKm', { n: m.target.toLocaleString(locale()) });
  if (m.family === 'journeys' && m.target === 1) return t('passport.milestone.firstJourney');
  return t(`passport.milestone.${m.family}`, { count: m.target });
}

function Milestones({ data }: { data: Passport }) {
  const { t } = useTranslation();
  const tz = 'Europe/Stockholm';
  const { achieved, next } = data.milestones;
  const [all, setAll] = useState(false);
  return (
    <section className="card">
      <h2 className="section-header">{t('passport.milestones')}</h2>
      {achieved.length > 0 && (
        <ul className="medals">
          {achieved.slice(0, all ? undefined : 6).map((m, i) => (
            <li key={`${m.family}:${m.target}`} style={{ ['--i' as string]: i }}>
              <Link to={`/trips/${m.legId}`} className="medal-tile" aria-label={milestoneLabel(t, m)}>
                <Medal m={m} />
                <span className="medal-label">{milestoneLabel(t, m)}</span>
                <span className="caption">{m.at ? new Date(m.at).toLocaleDateString(locale(), { month: 'short', year: 'numeric', timeZone: tz }) : ''}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
      {achieved.length > 6 && (
        <button className="link-button" onClick={() => setAll(!all)}>
          {all ? t('passport.showFewer') : t('passport.showAllMilestones', { count: achieved.length })}
        </button>
      )}
      {next.length > 0 && (
        <>
          <span className="caption upper">{t('passport.nextMilestones')}</span>
          <ul className="medals">
            {next.map((m) => (
              <li key={`${m.family}:${m.target}`}>
                <div className="medal-tile" aria-label={`${milestoneLabel(t, m)}: ${t('passport.progressOf', { value: Math.floor(m.value ?? 0), target: m.target })}`}>
                  <Medal m={m} locked />
                  <span className="medal-label">{milestoneLabel(t, m)}</span>
                  <span className="caption tabular">{t('passport.progressOf', { value: Math.floor(m.value ?? 0).toLocaleString(locale()), target: m.target.toLocaleString(locale()) })}</span>
                </div>
              </li>
            ))}
          </ul>
        </>
      )}
      <p className="caption">{t('passport.milestonesNote')}</p>
    </section>
  );
}

/** The Passport's top card: a passport page (gradient, guilloche, sheen) that tilts a little under the pointer. */
function PassportCard({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLElement>(null);
  const move = (e: React.PointerEvent) => {
    const el = ref.current;
    if (!el || window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return;
    const r = el.getBoundingClientRect();
    el.style.setProperty('--rx', `${((e.clientY - r.top) / r.height - 0.5) * -6}deg`);
    el.style.setProperty('--ry', `${((e.clientX - r.left) / r.width - 0.5) * 8}deg`);
    el.style.setProperty('--mx', `${((e.clientX - r.left) / r.width) * 100}%`);
  };
  const leave = () => {
    ref.current?.style.setProperty('--rx', '0deg');
    ref.current?.style.setProperty('--ry', '0deg');
  };
  return (
    <section ref={ref} className="passport-hero" onPointerMove={move} onPointerLeave={leave}>
      {children}
    </section>
  );
}

function Record({ label, value, sub, to }: { label: string; value: string; sub?: string; to?: string }) {
  const body = (
    <>
      <span className="caption upper">{label}</span>
      <span className="strong">{value}</span>
      {sub && <span className="caption">{sub}</span>}
    </>
  );
  return to ? (
    <Link to={to} className="record">
      {body}
    </Link>
  ) : (
    <div className="record">{body}</div>
  );
}

export function PassportPage() {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const [year, setYear] = useState<number | null>(null);
  // Commuter trains follow the setting (Settings → Include commuter trains); no switch on this page.
  const commuter = settings.includeCommuter;
  // Old settings may hold a comparison no longer offered; show it as a petrol car.
  const initial: Co2Comparison = (CO2_CHOICES as readonly string[]).includes(settings.co2Comparison) ? settings.co2Comparison : 'car_1';
  const [comparison, setComparison] = useState<Co2Comparison>(initial);
  const [data, setData] = useState<Passport | null>(null);
  const [legs, setLegs] = useState<Leg[]>([]);
  const [error, setError] = useState(false);
  const [flavorIx, setFlavorIx] = useState(0);
  const [showAllStations, setShowAllStations] = useState(false);
  const [sharing, setSharing] = useState(false);
  const unit = settings.distanceUnit;

  useEffect(() => {
    setError(false);
    api.passport({ year, commuter, comparison }).then(setData, () => setError(true));
  }, [year, commuter, comparison]);
  useEffect(() => {
    api.legs().then(setLegs, () => undefined);
  }, []);


  if (error)
    return (
      <main className="page">
        <header className="page-header">
          <h1>{t('passport.title')}</h1>
        </header>
        <p className="banner error">{t('passport.loadError')}</p>
      </main>
    );
  if (!data)
    return (
      <main className="page">
        <header className="page-header">
          <h1>{t('passport.title')}</h1>
        </header>
        <div className="skeleton-card" />
      </main>
    );

  const tot = data.totals;
  const ops = data.refs.operators;
  const types = data.refs.trainTypes;
  const km = tot.distanceM / 1000;
  const flavors = [
    // Under one lap a share reads better than "0.04×"; tiny distances get no comparison at all.
    data.flavor.earthLaps >= 1
      ? t('passport.flavor.earth', { n: data.flavor.earthLaps.toFixed(1) })
      : data.flavor.earthLaps >= 0.01
        ? t('passport.flavor.earthPct', { pct: Math.round(data.flavor.earthLaps * 100) })
        : null,
    data.flavor.swedenLengths >= 0.05 ? t('passport.flavor.sweden', { n: data.flavor.swedenLengths.toFixed(1) }) : null,
    tot.minutes ? t('passport.flavor.time', { time: fmtDuration(tot.minutes) }) : null,
    data.flavor.topRoute ? t('passport.flavor.route', { route: data.flavor.topRoute.route, count: data.flavor.topRoute.count }) : null,
    data.flavor.busiestMonth
      ? t('passport.flavor.month', {
          month: new Date(`${data.flavor.busiestMonth.month}-15`).toLocaleDateString(locale(), { month: 'long', year: 'numeric' }),
          count: data.flavor.busiestMonth.count,
        })
      : null,
    data.flavor.lateMinutes >= 30 ? t('passport.flavor.late', { time: fmtDuration(data.flavor.lateMinutes) }) : null,
  ].filter((f): f is string => !!f);
  const tz = 'Europe/Stockholm';
  const legLink = (r: LegRef | null) => (r ? `/trips/${r.legId}` : undefined);
  const bandsTotal = Object.values(data.delays.bands).reduce((n, v) => n + v, 0);

  return (
    <main className="page passport">
      <header className="page-header">
        <h1>{t('passport.title')}</h1>
        <span className="header-actions">
          {tot.trains > 0 && (
            <button className="icon-button" onClick={() => setSharing(true)} aria-label={t('share.title')} title={t('share.title')}>
              <Share2 size={20} />
            </button>
          )}
          <SettingsLink />
        </span>
      </header>

      <div className="passport-controls">
        <div className="chip-row year-chips" role="tablist" aria-label={t('passport.year')}>
          <button role="tab" aria-selected={year === null} className={year === null ? 'chip-button active' : 'chip-button'} onClick={() => setYear(null)}>
            {t('passport.allTime')}
          </button>
          {data.years.map((y) => (
            <button key={y} role="tab" aria-selected={year === y} className={year === y ? 'chip-button active' : 'chip-button'} onClick={() => setYear(y)}>
              {y}
            </button>
          ))}
        </div>
      </div>

      {data.review.length > 0 && (
        <Link to="/?tab=past" className="banner review-banner">
          {t('passport.reviewBanner', { count: data.review.length })}
        </Link>
      )}
      {tot.trains === 0 ? (
        <section className="empty">
          <h2>{t('passport.emptyTitle')}</h2>
          <p>{t('passport.emptyHow')}</p>
          <div className="empty-actions">
            <Link to="/add" className="button primary">
              {t('trips.findTrain')}
            </Link>
            <Link to="/explore" className="button">
              {t('trips.exploreTrains')}
            </Link>
          </div>
        </section>
      ) : (
        <>
          <PassportCard>
            <div className="passport-hero-head">
              <span className="passport-hero-brand">
                <span className="caption upper">{t('passport.railPassport')}</span>
                <span className="passport-hero-kind">{year ? t('passport.yearPassport', { year }) : t('passport.allTimePassport')}</span>
              </span>
              <span className="passport-emblem" aria-hidden="true">
                <TrainFront size={22} strokeWidth={2} />
              </span>
            </div>
            <span className="passport-distance tabular">
              {Math.round(unit === 'mi' ? km / 1.609344 : km).toLocaleString(locale())}
              <small> {unit}</small>
            </span>
            {flavors.length > 0 && (
              <button className="flavor" onClick={() => setFlavorIx((i) => i + 1)} title={t('passport.nextFact')}>
                {flavors[flavorIx % flavors.length]}
              </button>
            )}
            <div className="passport-tiles">
              <div>
                <span className="tile-value tabular">{tot.trains}</span>
                <span className="caption upper">{t('passport.trains')}</span>
              </div>
              <div>
                <span className="tile-value tabular">{tot.journeys}</span>
                <span className="caption upper">{t('passport.journeys')}</span>
              </div>
              <div>
                <span className="tile-value tabular">{fmtDuration(tot.minutes)}</span>
                <span className="caption upper">{t('passport.timeOnTrains')}</span>
              </div>
              <div>
                <span className="tile-value tabular">{tot.stations}</span>
                <span className="caption upper">{t('passport.stations')}</span>
              </div>
            </div>
            {/* A machine-readable-zone look, spelled out from your own totals (decoration; nothing personal). */}
            <span className="passport-mrz" aria-hidden="true">
              {`P<CLACK<<${year ?? 'ALL'}<<KM${Math.round(km)}<<J${tot.journeys}<<S${tot.stations}<<C${tot.countries}`.padEnd(44, '<').slice(0, 44)}
            </span>
          </PassportCard>

          <section className="card map-card">
            <MultiRouteMap
              className="passport-map"
              routes={data.map.map((m) => ({ color: opColor(m.operatorId ? ops[m.operatorId]?.brandColor : null), geometry: m.geometry, stops: m.stops }))}
              stations={data.stations.map((s) => ({ lat: s.lat, lon: s.lon, name: s.name, count: s.count }))}
              railNetwork={settings.showRailNetwork}
              label={t('passport.mapLabel', { count: tot.trains })}
            />
          </section>

          <Milestones data={data} />

          <h2 className="passport-group">{t('passport.collections')}</h2>
          <section className="card">
            <h2 className="section-header">{t('passport.operators')}</h2>
            <Bars
              rows={data.operators}
              unit={unit}
              label={(r) => ops[r.key]?.name ?? r.key}
              color={(r) => opColor(ops[r.key]?.brandColor)}
              lead={(r) => <OperatorBadge operator={ops[r.key]} size={30} />}
            />
          </section>

          {data.trainTypes.length > 0 && (
            <section className="card">
              <h2 className="section-header">{t('passport.trainTypes')}</h2>
              <ul className="type-list">
                {data.trainTypes.map((r) => {
                  const type = types[r.key];
                  return (
                    <li key={r.key} className="type-row">
                      <span className="type-art"><TrainPicture type={type} operatorId={null} /></span>
                      <span className="bar-label">
                        <span className="strong">{type?.name ?? r.key}</span>
                        <span className="caption tabular">
                          {t('passport.trainsCount', { count: r.count })} · {fmtDistance(r.distanceM, unit)}
                        </span>
                      </span>
                    </li>
                  );
                })}
              </ul>
              <p className="caption">{t('passport.typesNote')}</p>
            </section>
          )}

          <section className="card">
            <h2 className="section-header">{t('passport.countries')}</h2>
            <ul className="country-list">
              {data.countries.map((c) => (
                <li key={c.code}>
                  <Flag country={c.code} size={24} decorative />
                  <span className="strong">{t(`countries.${c.code}`, { defaultValue: c.code })}</span>
                  <span className="caption">{t('passport.trainsCount', { count: c.legs })}</span>
                </li>
              ))}
            </ul>
            <p className="caption">{t('passport.borders', { count: tot.borderCrossings })}</p>
          </section>

          <section className="card">
            <h2 className="section-header">{t('passport.stationsVisited')}</h2>
            <ul className="station-collection">
              {data.stations.slice(0, showAllStations ? undefined : 12).map((st) => (
                <li key={st.id}>
                  <Link to={`/stations/${st.id}`}>{st.name}</Link>
                  <span className="caption tabular">×{st.count}</span>
                </li>
              ))}
            </ul>
            {data.stations.length > 12 && (
              <button className="link-button" onClick={() => setShowAllStations(!showAllStations)}>
                {showAllStations ? t('passport.showFewer') : t('passport.showAllStations', { count: data.stations.length })}
              </button>
            )}
            <p className="caption">{t('passport.stationsNote')}</p>
          </section>
          <section className="card">
            <h2 className="section-header">{t('passport.products')}</h2>
            <Bars rows={data.products} unit={unit} label={(r) => t(`products.${r.key}`)} color={() => 'var(--accent)'} />
          </section>


          <h2 className="passport-group">{t('passport.records')}</h2>
          <section className="card">
            <h2 className="section-header">{t('passport.records')}</h2>
            <div className="records">
              {data.records.longestDistance && (
                <Record
                  label={t('passport.longestTrip')}
                  value={fmtDistance(data.records.longestDistance.distanceM, unit)}
                  sub={`${data.records.longestDistance.from} → ${data.records.longestDistance.to}`}
                  to={legLink(data.records.longestDistance)}
                />
              )}
              {data.records.longestDuration && (
                <Record
                  label={t('passport.longestTime')}
                  value={fmtDuration(data.records.longestDuration.minutes)}
                  sub={`${data.records.longestDuration.from} → ${data.records.longestDuration.to}`}
                  to={legLink(data.records.longestDuration)}
                />
              )}
              {data.records.biggestDelay && (
                <Record
                  label={t('passport.biggestDelay')}
                  value={t('passport.minutesLate', { count: data.records.biggestDelay.delayMin ?? 0 })}
                  sub={`${data.records.biggestDelay.from} → ${data.records.biggestDelay.to}`}
                  to={legLink(data.records.biggestDelay)}
                />
              )}
              {data.records.mostRiddenRoute && (
                <Record
                  label={t('passport.mostRidden')}
                  value={data.records.mostRiddenRoute.route}
                  sub={t('passport.timesCount', { count: data.records.mostRiddenRoute.count })}
                />
              )}
              {data.records.busiestStation && (
                <Record
                  label={t('passport.busiestStation')}
                  value={data.records.busiestStation.name}
                  sub={t('passport.visitsCount', { count: data.records.busiestStation.count })}
                />
              )}
              {data.records.earliestDeparture && (
                <Record
                  label={t('passport.earliest')}
                  value={fmtTime(data.records.earliestDeparture.dep, tz, settings.clock)}
                  sub={data.records.earliestDeparture.from}
                  to={legLink(data.records.earliestDeparture)}
                />
              )}
              {data.records.latestArrival && (
                <Record
                  label={t('passport.latest')}
                  value={fmtTime(data.records.latestArrival.arr, tz, settings.clock)}
                  sub={data.records.latestArrival.to}
                  to={legLink(data.records.latestArrival)}
                />
              )}
            </div>
          </section>

          <h2 className="passport-group">{t('passport.moreStats')}</h2>
          <section className="card">
            <h2 className="section-header">{t('passport.delays')}</h2>
            {data.delays.basedOn === 0 ? (
              <p className="caption">{t('passport.noDelayData')}</p>
            ) : (
              <>
                <div className="delay-hero">
                  <span className="passport-big tabular">{data.delays.onTimePct}%</span>
                  <span className="caption">{t('passport.onTime')}</span>
                </div>
                <div className="band-bar" aria-hidden="true">
                  {(['on_time', 'slight', 'late', 'very_late'] as const).map((b) =>
                    data.delays.bands[b] ? <span key={b} className={`band band-${b}`} style={{ flexGrow: data.delays.bands[b] }} /> : null,
                  )}
                </div>
                <ul className="band-legend caption">
                  {(['on_time', 'slight', 'late', 'very_late'] as const).map((b) => (
                    <li key={b}>
                      <span className={`dot band-${b}`} /> {t(`passport.bands.${b}`)} · {data.delays.bands[b]} (
                      {bandsTotal ? Math.round((100 * data.delays.bands[b]) / bandsTotal) : 0}%)
                    </li>
                  ))}
                </ul>
                <div className="records">
                  <Record label={t('passport.timeLost')} value={fmtDuration(data.delays.totalLateMin)} />
                  <Record label={t('passport.averageDelay')} value={t('passport.minutesShort', { n: data.delays.averageMin })} />
                  {data.delays.worst && (
                    <Record
                      label={t('passport.worstDelay')}
                      value={t('passport.minutesLate', { count: data.delays.worst.delayMin ?? 0 })}
                      sub={`${data.delays.worst.from} → ${data.delays.worst.to}`}
                      to={legLink(data.delays.worst)}
                    />
                  )}
                  <Record label={t('passport.cancellations')} value={String(data.delays.cancellations)} />
                </div>
                <p className="caption">{t('passport.basedOn', { count: data.delays.basedOn })}</p>
              </>
            )}
          </section>

          <section className="card co2-card">
            <h2 className="section-header">{t('passport.co2')}</h2>
            <span className="passport-big tabular">
              {Math.round(data.co2.savedKg).toLocaleString(locale())} <small>kg</small>
            </span>
            <span className="caption">{t('passport.co2Saved', { mode: t(`passport.co2Modes.${data.co2.comparison}`) })}</span>
            {/* Flying or a petrol car (owner feedback 2026-10-21). */}
            <div className="segmented small" role="tablist" aria-label={t('passport.co2Compare')}>
              {CO2_CHOICES.map((c) => (
                <button key={c} role="tab" aria-selected={comparison === c} className={comparison === c ? 'active' : ''} onClick={() => setComparison(c)}>
                  {c === 'flight' ? t('passport.co2Flying') : t('passport.co2Car')}
                </button>
              ))}
            </div>
            <p className="caption">
              {t('passport.co2Detail', {
                train: data.co2.trainKg < 10 ? data.co2.trainKg.toFixed(1) : Math.round(data.co2.trainKg),
                other: Math.round(data.co2.comparisonKg).toLocaleString(locale()),
                mode: t(`passport.co2Modes.${data.co2.comparison}`),
              })}{' '}
              <Link to="/about" className="accent-text">
                {t('passport.howWeCalculate')}
              </Link>
            </p>
          </section>

        </>
      )}
      {sharing && <ShareSheet year={year} commuter={commuter} legs={legs} onClose={() => setSharing(false)} />}
    </main>
  );
}
