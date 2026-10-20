// Trip detail (DESIGN §6): the route map on top, then times, the live module while the train runs, tiles, the stop
// timeline, the activity log and details.
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, RefreshCw, Repeat, Trash2 } from 'lucide-react';
import { decodePolyline, delayMinutes, type LatLon } from '@clack/shared';
import { api, ms, type LegDetail, type LegEvent, type LegStop, type LiveState } from '../api';
import { OperatorBadge } from '../components/OperatorBadge';
import { DelayPill, delayClass } from '../components/DelayPill';
import { useSettings } from '../settings';
import { RouteMap, type MapStop } from '../map/RouteMap';
import { ActivityLog, LiveChip, LiveModule, eventText } from '../components/Live';
import { isLive, statusKey, useLiveUpdates, useNow } from '../live';
import { dayOffset, fmtDistance, fmtDuration, fmtLongDate, fmtTime } from '../format';

function TimeBlock({
  label,
  sched,
  actual,
  tz,
  platform,
  delay,
  canceled,
  extraDays,
}: {
  label: string;
  sched: number | null;
  actual: number | null;
  tz: string;
  platform: string | null;
  delay: number | null;
  canceled: boolean;
  extraDays?: number;
}) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const changed = actual !== null && sched !== null && Math.floor(actual / 60000) !== Math.floor(sched / 60000);
  return (
    <div className="time-block">
      <span className="caption upper">{label}</span>
      {changed && <span className="sched-struck tabular">{fmtTime(sched, tz, settings.clock)}</span>}
      <span className={`time-big tabular ${canceled ? 'struck' : ''}`}>
        {fmtTime(actual ?? sched, tz, settings.clock)}
        {extraDays ? <sup>+{extraDays}</sup> : null}
      </span>
      <span className="time-block-meta">
        {platform && <span className="chip">{t('trips.platform', { platform })}</span>}
        <DelayPill delay={delay} canceled={canceled} />
      </span>
    </div>
  );
}

function StopRow({ s, color }: { s: LegStop; color: string }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const ridden = s.role === 'board' || s.role === 'through' || s.role === 'alight';
  const sched = s.role === 'board' ? (ms(s.schedDep) ?? ms(s.schedArr)) : (ms(s.schedArr) ?? ms(s.schedDep));
  const real = s.role === 'board' ? ms(s.actualDep) : (ms(s.actualArr) ?? ms(s.actualDep));
  // While the train runs, Trafikverket's estimate stands in (shown in italics) until the real time is known.
  const estimate = s.role === 'board' ? ms(s.estimatedDep) : (ms(s.estimatedArr) ?? ms(s.estimatedDep));
  const actual = real ?? estimate;
  const delay = delayMinutes(sched, actual);
  const platformChanged = s.deviations.includes('Spårändrat');
  return (
    <li className={`tl-stop ${s.role} ${ridden ? 'ridden' : 'dim'}`} style={{ ['--op' as string]: color }}>
      <span className="tl-dot" />
      <span className="tl-main">
        <span className={`tl-name ${s.canceled ? 'struck' : ''}`}>{s.name}</span>
        {s.role === 'board' && <span className="caption accent-text">{t('detail.gotOn')}</span>}
        {s.role === 'alight' && <span className="caption accent-text">{t('detail.gotOff')}</span>}
        {s.deviations.filter((d) => d !== 'Spårändrat').length > 0 && (
          <span className="caption">{s.deviations.filter((d) => d !== 'Spårändrat').join(' · ')}</span>
        )}
      </span>
      <span className="tl-times tabular">
        <span className={actual !== null ? 'tl-sched small' : 'tl-sched'}>{fmtTime(sched, s.tz, settings.clock)}</span>
        {actual !== null && (
          <span className={`${delayClass(delay, s.canceled)} ${real === null ? 'estimate' : ''}`}>{fmtTime(actual, s.tz, settings.clock)}</span>
        )}
      </span>
      <span className="tl-platform tabular">
        {s.platform ?? ''}
        {platformChanged && <Repeat size={12} aria-label="Platform changed" />}
      </span>
    </li>
  );
}

export function TripDetailPage() {
  const { id } = useParams();
  const { t } = useTranslation();
  const { settings } = useSettings();
  const navigate = useNavigate();
  const [leg, setLeg] = useState<LegDetail | null>(null);
  const [missing, setMissing] = useState(false);
  const [fullRoute, setFullRoute] = useState(false);
  const [explain, setExplain] = useState(false);
  const [busy, setBusy] = useState(false);
  const [live, setLive] = useState<LiveState | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const now = useNow(1000);
  const geo = useMemo(() => {
    if (!leg) return null;
    const ridden = leg.stops.filter((s) => s.role === 'board' || s.role === 'through' || s.role === 'alight');
    const route: LatLon[] = leg.geometry ? decodePolyline(leg.geometry) : ridden.map((s) => [s.lat, s.lon]);
    const stops: MapStop[] = ridden.map((s) => ({ lat: s.lat, lon: s.lon, name: s.name, kind: s.role === 'through' ? 'mid' : 'end' }));
    return { route, stops };
  }, [leg]);

  const load = useCallback(() => {
    if (id)
      api.leg(id).then(
        (l) => {
          setLeg(l);
          setLive(l.live);
        },
        () => setMissing(true),
      );
  }, [id]);
  useEffect(load, [load]);

  // Every live tick: move the marker straight away, then refetch the leg so stop times and the log stay current.
  useLiveUpdates((u) => {
    if (u.legId !== id) return;
    setLive(u.live);
    load();
    const shown = u.events.find((e: LegEvent) => e.type !== 'departed');
    if (shown && leg) setToast(eventText(t, shown, leg, leg.stops));
  });
  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 6000);
    return () => clearTimeout(timer);
  }, [toast]);

  if (missing)
    return (
      <main className="page">
        <Link to="/" className="link-button back-link">
          <ArrowLeft size={18} /> {t('nav.trips')}
        </Link>
        <p className="muted">{t('detail.notFound')}</p>
      </main>
    );
  if (!leg)
    return (
      <main className="page">
        <div className="skeleton-card" />
      </main>
    );

  const tz = leg.origin?.tz ?? 'Europe/Stockholm';
  const dtz = leg.destination?.tz ?? tz;
  const color = leg.operator?.brandColor ?? '#4C8DFF';
  const schedDep = ms(leg.schedDep);
  const schedArr = ms(leg.schedArr);
  const dep = ms(leg.actualDep) ?? schedDep;
  const arr = ms(leg.actualArr) ?? schedArr;
  const extraDays = schedDep && schedArr ? dayOffset(schedDep, tz, schedArr, dtz) : 0;
  const stops = fullRoute ? leg.stops : leg.stops.filter((s) => s.role !== 'before' && s.role !== 'after');
  const hasHidden = leg.stops.some((s) => s.role === 'before' || s.role === 'after');
  const arrDelay = leg.arrDelayMin;
  const explainText =
    arrDelay === null
      ? t('delay.explainUnknown')
      : arrDelay > 0
        ? t('delay.explainLate', { count: arrDelay })
        : arrDelay < 0
          ? t('delay.explainEarly', { count: -arrDelay })
          : t('delay.explainOnTime');

  const status = statusKey(leg, live, now);
  const boardStop = leg.stops.find((x) => x.role === 'board');
  const boardEstimate = ms(boardStop?.estimatedDep);
  const tracking = isLive(live) && live !== null;
  const train =
    tracking && live.lat !== null && live.lon !== null
      ? { lat: live.lat, lon: live.lon, bearing: live.bearing, estimated: live.positionSource !== 'gps' }
      : null;

  const refresh = async () => {
    setBusy(true);
    try {
      setLeg(await api.refreshLeg(leg.id));
    } finally {
      setBusy(false);
    }
  };
  const remove = async () => {
    if (!window.confirm(t('detail.deleteConfirm'))) return;
    await api.deleteLeg(leg.id);
    navigate('/');
  };

  return (
    <>
      <div className="detail-map">
        {geo && (
          <RouteMap
            color={color}
            route={geo.route}
            stops={geo.stops}
            animate
            railNetwork={settings.showRailNetwork}
            train={train}
            progress={tracking ? live.progress : null}
            label={t('detail.mapLabel', { from: leg.origin?.name, to: leg.destination?.name })}
          />
        )}
        <Link to="/" className="map-button map-back" aria-label={t('nav.trips')}>
          <ArrowLeft size={18} />
        </Link>
        {leg.isEstimatedGeometry && <span className="map-chip caption">{t('detail.estimatedRoute')}</span>}
      </div>
      <main className="page detail">
        <div className="detail-head">
          <OperatorBadge operator={leg.operator} size={32} />
          <span className="strong">{[leg.operator?.name, leg.trainNumber].filter(Boolean).join(' ')}</span>
          {leg.category && <span className="chip">{t(`products.${leg.category}`)}</span>}
          {tracking ? <LiveChip live={live} now={now} /> : <span className={`chip status-${status}`}>{t(`status.${status}`)}</span>}
        </div>
        {toast && (
          <p className="toast" role="status">
            {toast}
          </p>
        )}
        <h1 className="detail-route">
          {leg.origin?.name} → {leg.destination?.name}
        </h1>
        {schedDep && <p className="muted">{fmtLongDate(schedDep, tz)}</p>}

        <section className="times-row">
          <TimeBlock
            label={t('detail.departure')}
            sched={schedDep}
            actual={ms(leg.actualDep) ?? (tracking ? boardEstimate : null)}
            tz={tz}
            platform={leg.depPlatform}
            delay={leg.depDelayMin ?? (tracking ? delayMinutes(schedDep, boardEstimate) : null)}
            canceled={leg.canceled}
          />
          <TimeBlock
            label={t('detail.arrival')}
            sched={schedArr}
            actual={ms(leg.actualArr) ?? (tracking ? ms(live.arrivalEta) : null)}
            tz={dtz}
            platform={leg.arrPlatform}
            delay={leg.arrDelayMin ?? (tracking ? live.arrivalDelayMin : null)}
            canceled={leg.canceled}
            extraDays={extraDays}
          />
        </section>

        {tracking && <LiveModule leg={leg} live={live} stops={leg.stops} now={now} />}

        <section className="tiles">
          <div className="tile">
            <span className="caption upper">{t('detail.distance')}</span>
            <span className="tile-value tabular">
              {leg.isEstimatedGeometry ? '≈ ' : ''}
              {fmtDistance(leg.distanceM, settings.distanceUnit)}
            </span>
          </div>
          <div className="tile">
            <span className="caption upper">{t('detail.duration')}</span>
            <span className="tile-value tabular">{dep && arr ? fmtDuration((arr - dep) / 60000) : '—'}</span>
          </div>
          <button className="tile" onClick={() => setExplain(!explain)}>
            <span className="caption upper">{t('detail.delay')}</span>
            <span className="tile-value">
              <DelayPill delay={arrDelay ?? (tracking ? live.arrivalDelayMin : null)} canceled={leg.canceled} />
            </span>
          </button>
        </section>
        {explain && <p className="caption">{explainText}</p>}

        <section className="card">
          <h2 className="section-header">{t('detail.stops')}</h2>
          <ol className="timeline">
            {stops.map((s) => (
              <StopRow key={s.seq} s={s} color={color} />
            ))}
          </ol>
          {hasHidden && (
            <button className="link-button" onClick={() => setFullRoute(!fullRoute)}>
              {fullRoute ? t('detail.hideFullRoute') : t('detail.showFullRoute')}
            </button>
          )}
        </section>

        {(tracking || leg.events.length > 0) && <ActivityLog leg={leg} events={leg.events} stops={leg.stops} />}

        <section className="card details">
          {leg.dataQuality !== 'full' && (
            <p>
              <span className="chip">{t(`detail.quality.${leg.dataQuality}`)}</span>{' '}
              <span className="caption">{t(`detail.qualityNote.${leg.dataQuality}`)}</span>
            </p>
          )}
          {leg.isEstimatedGeometry && <p className="caption">{t('detail.estimatedDistance')}</p>}
          <p className="caption">{t('detail.source')}</p>
        </section>

        <div className="actions">
          {leg.status !== 'snapshotted' && (
            <button className="button" onClick={refresh} disabled={busy}>
              <RefreshCw size={16} /> {t('detail.refresh')}
            </button>
          )}
          <button className="button danger" onClick={remove}>
            <Trash2 size={16} /> {t('detail.delete')}
          </button>
        </div>
      </main>
    </>
  );
}
