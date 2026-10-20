// Trips home (DESIGN §4): Upcoming | Past, a hero card for the next leg, rows grouped by month for the past.
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Plus } from 'lucide-react';
import { api, ms, type Leg } from '../api';
import { OperatorBadge } from '../components/OperatorBadge';
import { DelayPill } from '../components/DelayPill';
import { useSettings } from '../settings';
import { dayOffset, fmtDay, fmtDistance, fmtMonth, fmtTime } from '../format';

const tzOf = (leg: Leg) => leg.origin?.tz ?? 'Europe/Stockholm';
const arrivalOf = (leg: Leg) => ms(leg.actualArr) ?? ms(leg.schedArr) ?? 0;

export function countdown(t: (k: string, o?: Record<string, unknown>) => string, leg: Leg, now: number): string {
  const dep = ms(leg.actualDep) ?? ms(leg.schedDep) ?? 0;
  if (now >= arrivalOf(leg)) return t('trips.arrived');
  if (now >= dep) return t('trips.liveNow');
  if (dep - now <= 30 * 60_000) return t('trips.boarding');
  const mins = Math.round((dep - now) / 60_000);
  const d = Math.floor(mins / 1440);
  const h = Math.floor((mins % 1440) / 60);
  const m = mins % 60;
  return t('trips.departsIn', { time: d ? `${d}d ${h}h` : h ? `${h}h ${m}m` : `${m} min` });
}

function Times({ leg }: { leg: Leg }) {
  const { settings } = useSettings();
  const dep = ms(leg.schedDep);
  const arr = ms(leg.schedArr);
  const plus = dep && arr && leg.destination ? dayOffset(dep, tzOf(leg), arr, leg.destination.tz) : 0;
  return (
    <>
      {fmtTime(dep, tzOf(leg), settings.clock)}–{fmtTime(arr, leg.destination?.tz ?? tzOf(leg), settings.clock)}
      {plus > 0 && <sup>+{plus}</sup>}
    </>
  );
}

export function LegRow({ leg }: { leg: Leg }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const dep = ms(leg.schedDep);
  return (
    <Link to={`/trips/${leg.id}`} className="leg-row">
      <OperatorBadge operator={leg.operator} />
      <span className="leg-row-main">
        <span className="leg-row-route">
          {leg.origin?.name} → {leg.destination?.name}
        </span>
        <span className="leg-row-meta">
          {[[leg.operator?.name, leg.trainNumber].filter(Boolean).join(' ') || null, dep ? fmtDay(dep, tzOf(leg)) : null].filter(Boolean).join(' · ')} · <Times leg={leg} />
        </span>
      </span>
      <span className="leg-row-side">
        <DelayPill delay={leg.dataQuality === 'scheduled_only' && leg.status === 'planned' ? undefined : leg.arrDelayMin} canceled={leg.canceled} />
        <span className="caption">{leg.isEstimatedGeometry ? t('trips.approxDistance', { distance: fmtDistance(leg.distanceM, settings.distanceUnit) }) : fmtDistance(leg.distanceM, settings.distanceUnit)}</span>
      </span>
    </Link>
  );
}

function Hero({ leg }: { leg?: Leg }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(timer);
  }, []);
  if (!leg)
    return (
      <section className="hero hero-empty">
        <svg className="dotted-line" viewBox="0 0 300 60" aria-hidden="true">
          <path d="M10 45 C 80 5, 200 70, 290 15" />
          <circle cx="10" cy="45" r="5" />
          <circle cx="290" cy="15" r="5" />
        </svg>
        <h2>{t('trips.whereNext')}</h2>
        <p>{t('trips.whereNextBody')}</p>
        <Link to="/add" className="button primary">
          <Plus size={18} /> {t('nav.addTrain')}
        </Link>
      </section>
    );
  const color = leg.operator?.brandColor ?? '#4C8DFF';
  return (
    <Link to={`/trips/${leg.id}`} className="hero" style={{ ['--op' as string]: color }}>
      <div className="hero-top">
        <OperatorBadge operator={leg.operator} size={30} />
        <span className="hero-number">{[leg.operator?.name, leg.trainNumber].filter(Boolean).join(' ')}</span>
        {leg.category && <span className="chip">{t(`products.${leg.category}`)}</span>}
      </div>
      <h2 className="hero-route">
        {leg.origin?.name} → {leg.destination?.name}
      </h2>
      <div className="hero-times tabular">
        {fmtTime(ms(leg.schedDep), tzOf(leg), settings.clock)} → {fmtTime(ms(leg.schedArr), leg.destination?.tz ?? tzOf(leg), settings.clock)}
      </div>
      <div className="hero-bottom">
        <span className="pill">{countdown(t, leg, now)}</span>
        {leg.depPlatform && <span className="chip">{t('trips.platform', { platform: leg.depPlatform })}</span>}
        {leg.depDelayMin !== null && <DelayPill delay={leg.depDelayMin} canceled={leg.canceled} />}
      </div>
    </Link>
  );
}

export function TripsPage() {
  const { t } = useTranslation();
  const [legs, setLegs] = useState<Leg[] | null>(null);
  const [error, setError] = useState(false);
  const [tab, setTab] = useState<'upcoming' | 'past'>('upcoming');
  const load = useCallback(() => {
    setError(false);
    api.legs().then(setLegs, () => setError(true));
  }, []);
  useEffect(load, [load]);

  const now = Date.now();
  const upcoming = useMemo(() => (legs ?? []).filter((l) => arrivalOf(l) > now).sort((a, b) => (ms(a.schedDep) ?? 0) - (ms(b.schedDep) ?? 0)), [legs, now]);
  const past = useMemo(() => (legs ?? []).filter((l) => arrivalOf(l) <= now).sort((a, b) => (ms(b.schedDep) ?? 0) - (ms(a.schedDep) ?? 0)), [legs, now]);
  const months = useMemo(() => {
    const groups: { label: string; legs: Leg[] }[] = [];
    for (const l of past) {
      const label = fmtMonth(ms(l.schedDep) ?? 0, tzOf(l));
      if (groups.at(-1)?.label !== label) groups.push({ label, legs: [] });
      groups.at(-1)!.legs.push(l);
    }
    return groups;
  }, [past]);

  return (
    <main className="page">
      <header className="page-header">
        <h1>{t('trips.title')}</h1>
        <Link to="/add" className="icon-button" aria-label={t('nav.addTrain')}>
          <Plus size={22} />
        </Link>
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
          <Link to="/add" className="button primary">
            <Plus size={18} /> {t('nav.addTrain')}
          </Link>
        </section>
      )}
      {legs && legs.length > 0 && tab === 'upcoming' && (
        <>
          <Hero leg={upcoming[0]} />
          <div className="list">{upcoming.slice(1).map((l) => <LegRow key={l.id} leg={l} />)}</div>
        </>
      )}
      {legs && legs.length > 0 && tab === 'past' && (
        <div className="list">
          {past.length === 0 && <p className="muted">{t('trips.noPast')}</p>}
          {months.map((m) => (
            <section key={m.label}>
              <h3 className="month-header">{m.label}</h3>
              {m.legs.map((l) => (
                <LegRow key={l.id} leg={l} />
              ))}
            </section>
          ))}
        </div>
      )}
      <Link to="/add" className="fab" aria-label={t('nav.addTrain')}>
        <Plus size={26} />
      </Link>
    </main>
  );
}
