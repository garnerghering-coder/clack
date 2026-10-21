// Passport (DESIGN §8): everything you've ridden, by year and with or without commuter trains.
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { CO2_COMPARISONS, type Co2Comparison } from '@clack/shared';
import { api, type CountRow, type Leg, type LegRef, type Passport } from '../api';
import { OperatorBadge } from '../components/OperatorBadge';
import { TrainArt } from '../components/TrainArt';
import { Flag } from '../components/Flag';
import { LegRow } from './TripsPage';
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
  const [commuter, setCommuter] = useState(settings.includeCommuter);
  const [comparison, setComparison] = useState<Co2Comparison>(settings.co2Comparison);
  const [data, setData] = useState<Passport | null>(null);
  const [legs, setLegs] = useState<Leg[]>([]);
  const [error, setError] = useState(false);
  const [flavorIx, setFlavorIx] = useState(0);
  const unit = settings.distanceUnit;

  useEffect(() => {
    setError(false);
    api.passport({ year, commuter, comparison }).then(setData, () => setError(true));
  }, [year, commuter, comparison]);
  useEffect(() => {
    api.legs().then(setLegs, () => undefined);
  }, []);

  const log = useMemo(() => {
    if (!data) return [];
    const ids = new Set(data.map.map((m) => m.legId));
    return legs.filter((l) => ids.has(l.id));
  }, [data, legs]);

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
    data.flavor.earthLaps >= 0.01 ? t('passport.flavor.earth', { n: data.flavor.earthLaps.toFixed(2) }) : null,
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
        <label className="switch-row">
          <input type="checkbox" role="switch" checked={commuter} onChange={(e) => setCommuter(e.target.checked)} />
          <span>{t('passport.includeCommuter')}</span>
        </label>
      </div>

      {tot.trains === 0 ? (
        <section className="empty">
          <h2>{t('passport.emptyTitle')}</h2>
          <p>{t('passport.empty')}</p>
          <Link to="/add" className="button primary">
            {t('nav.addTrain')}
          </Link>
        </section>
      ) : (
        <>
          <section className="passport-hero">
            <span className="caption upper">{year ? t('passport.yearPassport', { year }) : t('passport.allTimePassport')}</span>
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
          </section>

          <section className="card map-card">
            <MultiRouteMap
              className="passport-map"
              routes={data.map.map((m) => ({ color: opColor(m.operatorId ? ops[m.operatorId]?.brandColor : null), geometry: m.geometry, stops: m.stops }))}
              stations={data.stations.map((s) => ({ lat: s.lat, lon: s.lon, name: s.name, count: s.count }))}
              railNetwork={settings.showRailNetwork}
              label={t('passport.mapLabel', { count: tot.trains })}
            />
          </section>

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
                      <span className="type-art">{type && <TrainArt art={type.art} color={opColor(null)} height={22} />}</span>
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
            <h2 className="section-header">{t('passport.products')}</h2>
            <Bars rows={data.products} unit={unit} label={(r) => t(`products.${r.key}`)} color={() => 'var(--accent)'} />
          </section>

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

          <section className="card co2-card">
            <h2 className="section-header">{t('passport.co2')}</h2>
            <span className="passport-big tabular">
              {Math.round(data.co2.savedKg).toLocaleString(locale())} <small>kg</small>
            </span>
            <span className="caption">{t('passport.co2Saved', { mode: t(`passport.co2Modes.${data.co2.comparison}`) })}</span>
            <div className="chip-row">
              {CO2_COMPARISONS.map((c) => (
                <button key={c} className={c === comparison ? 'chip-button active' : 'chip-button'} onClick={() => setComparison(c)}>
                  {t(`passport.co2Modes.${c}`)}
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

          <section className="card">
            <h2 className="section-header">{t('passport.log')}</h2>
            <div className="list">
              {log.map((l) => (
                <LegRow key={l.id} leg={l} />
              ))}
            </div>
          </section>
        </>
      )}
    </main>
  );
}
