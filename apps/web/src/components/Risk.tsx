// Journey risk on an upcoming trip (owner, 2026-10-22): warnings from what can be observed (server legs/risk.ts),
// each saying what it's based on, and never called a prediction. Nothing shows when the evidence is weak.
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Activity } from 'lucide-react';
import { AlertCard } from './Alert';
import { api, ms, type Leg, type LegDetail, type LegRisk, type RiskWarning } from '../api';
import { fmtTime } from '../format';
import { useSettings } from '../settings';

export function RiskCard({ leg }: { leg: LegDetail }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const [risk, setRisk] = useState<LegRisk | null>(null);
  const [next, setNext] = useState<Leg | null>(null);
  useEffect(() => {
    let live = true;
    const load = () => api.legRisk(leg.id).then((r) => live && setRisk(r), () => undefined);
    load();
    const timer = setInterval(load, 5 * 60_000);
    return () => {
      live = false;
      clearInterval(timer);
    };
  }, [leg.id]);
  useEffect(() => {
    if (!leg.journeyId) return;
    api.journey(leg.journeyId).then((j) => {
      const i = j.legs.findIndex((l) => l.id === leg.id);
      const n = j.legs[i + 1];
      setNext(n && n.origin?.id === leg.destination?.id ? n : null);
    }, () => undefined);
  }, [leg.id, leg.journeyId, leg.destination?.id]);
  if (!risk) return null;
  const nowWarn = risk.warnings.some((w) => w.kind !== 'train_pattern');
  // A short planned change is what a late-running line puts at risk.
  const change = next ? Math.round(((ms(next.schedDep) ?? 0) - (ms(leg.schedArr) ?? 0)) / 60_000) : null;
  const changeAtRisk = nowWarn && change !== null && change < 10;
  // Nothing to warn about (or nothing could be checked): nothing to show.
  if (!risk.warnings.length) return null;
  const line = (w: RiskWarning) => {
    if (w.kind === 'route_now') return t('risk.routeNow', { late: w.late, trains: w.trains, canceled: w.canceled, median: w.medianMin, window: w.windowMin });
    if (w.kind === 'station_now') return t('risk.stationNow', { station: w.station, late: w.late, trains: w.trains, median: w.medianMin, window: w.windowMin });
    return t('risk.pattern', { station: w.station, late: w.lateDays, days: w.days, median: w.medianMin });
  };
  return (
    <AlertCard tone="watch" icon={<Activity size={16} />} title={nowWarn ? t('risk.titleNow') : t('risk.titlePattern')} dismissKey={`risk:${leg.id}:${risk.warnings.map((w) => w.kind).join(',')}`}>
      <ul className="disruption-lines">
        {risk.warnings.map((w) => (
          <li key={w.kind}>
            <span className="chip">{t(`risk.kind.${w.kind}`)}</span> {line(w)}
          </li>
        ))}
        {changeAtRisk && next && <li>{t('risk.change', { min: change, station: next.origin?.name ?? '' })}</li>}
      </ul>
      <p className="caption">{t('risk.honest', { time: fmtTime(risk.checkedAt, 'Europe/Stockholm', settings.clock) })}</p>
    </AlertCard>
  );
}
