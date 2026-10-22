// Live tracking pieces (DESIGN §9.5): the LIVE chip, the live module with progress, and the activity log.
import { useTranslation } from 'react-i18next';
import { FlapTime } from './SplitFlap';
import { ms, type Leg, type LegEvent, type LiveState } from '../api';
import { agoKey, isFresh } from '../live';
import { useSettings } from '../settings';
import { fmtDelay, fmtTime } from '../format';
import { DelayPill } from './DelayPill';
import { opColor } from '../map/style';

export function LiveChip({ live, now }: { live: LiveState; now: number }) {
  const { t } = useTranslation();
  const fresh = isFresh(live, now);
  if (fresh)
    return (
      <span className="chip live-chip">
        <span className="live-dot" aria-hidden="true" />
        {t('live.chip')}
      </span>
    );
  return <span className="chip stale-chip">{t('live.stale', { ago: agoKey(t, ms(live.updatedAt) ?? now, now) })}</span>;
}

interface StopName {
  stationId: string;
  name: string;
  tz: string;
}

/** Progress bar, where the train is, next stop and arrival, freshness and position source. */
export function LiveModule({ leg, live, stops, now, compact = false }: { leg: Leg; live: LiveState; stops: StopName[]; now: number; compact?: boolean }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const name = (id: string | null) => stops.find((s) => s.stationId === id)?.name ?? '';
  const tzOf = (id: string | null) => stops.find((s) => s.stationId === id)?.tz ?? leg.origin?.tz ?? 'Europe/Stockholm';
  const destTz = leg.destination?.tz ?? 'Europe/Stockholm';
  const progress = Math.max(0, Math.min(1, live.progress ?? 0));
  const where =
    live.status === 'boarding'
      ? t('live.boardingAt', { name: leg.origin?.name })
      : live.status === 'at_stop'
        ? t('live.atStop', { name: name(live.prevStopId) })
        : live.prevStopId && live.nextStopId
          ? t('live.between', { a: name(live.prevStopId), b: name(live.nextStopId) })
          : '';
  const delay = live.arrivalDelayMin;
  const next =
    live.nextStopId && live.status !== 'boarding' ? (
      <span className="next-stop">
        {t('live.nextStopName', { name: name(live.nextStopId) })} <FlapTime time={ms(live.eta)} tz={tzOf(live.nextStopId)} clock={settings.clock} />
      </span>
    ) : null;
  const source =
    live.positionSource === 'gps' ? t('live.livePosition') : live.positionSource === 'estimated' ? t('live.estimatedPosition') : t('live.noPosition');

  return (
    <section className={`live-module ${compact ? 'compact' : ''}`} style={{ ['--op' as string]: opColor(leg.operator?.brandColor) }} aria-live="polite">
      <div
        className="live-progress"
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.round(progress * 100)}
        aria-label={t('live.progressLabel', { percent: Math.round(progress * 100), name: leg.destination?.name })}
      >
        <span className="live-progress-fill" style={{ width: `${progress * 100}%` }} />
        <span className={`live-progress-dot ${live.positionSource === 'estimated' ? 'hollow' : ''}`} style={{ left: `${progress * 100}%` }} />
      </div>
      {where && <p className="strong">{where}</p>}
      {next && <p>{next}</p>}
      {!compact && (
        <p className="live-arrives">
          {t('live.arrivesLabel')} <FlapTime time={ms(live.arrivalEta)} tz={destTz} clock={settings.clock} /> <DelayPill delay={delay} />
        </p>
      )}
      <p className="caption">
        {t('live.updated', { ago: agoKey(t, ms(live.updatedAt) ?? now, now) })} · {source}
      </p>
    </section>
  );
}

export function eventText(t: (k: string, o?: Record<string, unknown>) => string, e: LegEvent, leg: Leg, stops: StopName[]): string {
  const p = e.payload;
  switch (e.type) {
    case 'departed':
      return t('activity.departed', { station: leg.origin?.name });
    case 'arrived':
      return typeof p.delayMin === 'number' && p.delayMin > 0
        ? t('activity.arrivedLate', { station: leg.destination?.name, delay: p.delayMin })
        : t('activity.arrived', { station: leg.destination?.name });
    case 'delayed':
      return typeof p.delayMin === 'number' && p.delayMin <= 0
        ? t('activity.delayedOnTime', { station: leg.destination?.name })
        : t('activity.delayed', { delay: fmtDelay(p.delayMin as number), station: leg.destination?.name });
    case 'platform_changed':
      return t(p.which === 'departure' ? 'activity.platformDeparture' : 'activity.platformArrival', { from: p.from, to: p.to });
    case 'cancelled':
      return t('activity.cancelled');
    case 'short_turned':
      return t('activity.shortTurned', {
        stations: ((p.stationIds as string[]) ?? []).map((id) => stops.find((s) => s.stationId === id)?.name ?? id).join(', '),
      });
  }
}

export function ActivityLog({ leg, events, stops }: { leg: Leg; events: LegEvent[]; stops: StopName[] }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const tz = leg.origin?.tz ?? 'Europe/Stockholm';
  return (
    <section className="card">
      <h2 className="section-header">{t('activity.title')}</h2>
      {events.length === 0 ? (
        <p className="caption">{t('activity.empty')}</p>
      ) : (
        <ol className="activity">
          {events.map((e, i) => (
            <li key={e.id ?? `${e.ts}-${i}`} className={`activity-item ${e.type}`}>
              <span className="activity-time tabular">{fmtTime(ms(e.ts), tz, settings.clock)}</span>
              <span>{eventText(t, e, leg, stops)}</span>
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}
