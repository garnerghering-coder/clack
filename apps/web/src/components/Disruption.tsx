// Disruption help on a trip (owner, 2026-10-22): when a train is cancelled, skips your stop, runs late or breaks your
// change, say what happened, what it does to the rest of the journey, what you can do now, and what you may be
// entitled to. Calm and specific; the rules are in @clack/shared (disruption.ts), the alternatives come from the
// timetable and each one opens its live view.
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { AlertTriangle, ChevronDown, ChevronUp, Info } from 'lucide-react';
import { AlertCard, type AlertTone } from './Alert';
import { assessDisruption, delayReasons, passengerRights, RIGHTS_LINKS, type DisruptionKind } from '@clack/shared';
import { api, ms, type Connection, type Leg, type LegDetail, type TripResult } from '../api';
import { useOperators } from '../data';
import { fmtDay, fmtTime } from '../format';
import { useNow } from '../live';
import { useSettings } from '../settings';
import { useConnection } from './Connection';
import { OperatorBadge } from './OperatorBadge';

const SEVERE: DisruptionKind[] = ['canceled', 'skips_board', 'skips_alight', 'connection_missed'];

/** The trip's disruption card, or nothing when all is well. Loads the rest of the journey to judge the change. */
export function DisruptionCard({ leg }: { leg: LegDetail }) {
  const [journey, setJourney] = useState<Leg[] | null>(null);
  useEffect(() => {
    if (leg.journeyId) api.journey(leg.journeyId).then((j) => setJourney(j.legs), () => setJourney(null));
  }, [leg.journeyId]);
  const legs = journey ?? [leg];
  const i = legs.findIndex((l) => l.id === leg.id);
  const next = i >= 0 && legs[i + 1]?.origin?.id === leg.destination?.id ? legs[i + 1] : undefined;
  return next ? <WithChange leg={leg} next={next} journey={legs} /> : <Card leg={leg} next={undefined} connection={null} journey={legs} />;
}

function WithChange({ leg, next, journey }: { leg: LegDetail; next: Leg; journey: Leg[] }) {
  const { result } = useConnection(leg, next);
  // A change the operators planned is theirs to judge: only a delay (or a cancellation) makes it a disruption here,
  // not our walking estimate on its own.
  const delayed = (leg.arrDelayMin ?? 0) > 0 || (ms(leg.actualArr) ?? 0) > (ms(leg.schedArr) ?? Infinity) || (next.depDelayMin ?? 0) < 0 || next.canceled;
  return <Card leg={leg} next={next} connection={delayed || result.status === 'broken' ? result.status : null} journey={journey} />;
}

function Card({ leg, next, connection, journey }: { leg: LegDetail; next: Leg | undefined; connection: string | null; journey: Leg[] }) {
  const { t, i18n } = useTranslation();
  const { settings } = useSettings();
  const ops = useOperators();
  const now = useNow(30_000);
  const board = leg.stops.find((s) => s.role === 'board');
  const alight = leg.stops.find((s) => s.role === 'alight');
  const ridden = leg.stops.filter((s) => s.role === 'board' || s.role === 'through' || s.role === 'alight');
  const deviations = [...new Set(ridden.flatMap((s) => s.deviations))];
  const schedDep = ms(leg.schedDep) ?? 0;
  const schedArr = ms(leg.schedArr) ?? 0;
  const arrived = Boolean(ms(leg.actualArr)) || (leg.status !== 'planned' && schedArr < now);
  const { kinds, urgency } = assessDisruption(
    { canceled: leg.canceled, boardCanceled: Boolean(board?.canceled), alightCanceled: Boolean(alight?.canceled), deviations, depDelayMin: leg.depDelayMin, arrDelayMin: leg.arrDelayMin, schedDep, arrived, connection },
    now,
  );
  const severe = kinds.some((k) => SEVERE.includes(k));
  // Where you're really going: the end of the journey this train is part of.
  const final = journey.at(-1)!;
  // The full operator record (with its site), not the trip's short copy.
  const op = leg.operator ? (ops.get(leg.operator.id) ?? leg.operator) : null;
  const train = [op?.name, leg.trainNumber].filter(Boolean).join(' ');
  // Other ways: from where you are (your station, or the change you'll miss) to the journey's end.
  const search = !arrived && severe
    ? kinds.includes('connection_missed') && next && !kinds.includes('canceled')
      ? { from: next.origin?.id, to: final.destination?.id, after: (ms(leg.actualArr) ?? schedArr + (leg.arrDelayMin ?? 0) * 60_000) + 5 * 60_000, exclude: next.timetableTripKey }
      : { from: leg.origin?.id, to: final.destination?.id, after: Math.max(now, schedDep - 30 * 60_000), exclude: leg.timetableTripKey }
    : null;
  const [alts, setAlts] = useState<{ direct: TripResult[]; connections: Connection[] } | null>(null);
  const [showAlts, setShowAlts] = useState(false);
  const searchKey = search ? `${search.from}|${search.to}|${Math.round(search.after / 60_000)}|${search.exclude}` : null;
  useEffect(() => {
    if (!search?.from || !search.to) return setAlts(null);
    api.alternatives(search.from, search.to, search.after, search.exclude ?? null).then(setAlts, () => setAlts(null));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchKey]);
  if (!urgency) return null;

  const km = journey.reduce((d, l) => d + (l.distanceM ?? 0), 0) / 1000;
  const countries = [...new Set(journey.flatMap((l) => [l.origin?.country, l.destination?.country]).filter((c): c is string => !!c))];
  const finalDelay = final.id === leg.id ? leg.arrDelayMin : final.arrDelayMin;
  const rights = passengerRights({ countries, journeyKm: km, arrDelayMin: kinds.includes('connection_missed') ? null : finalDelay, canceled: leg.canceled });
  const tz = board?.tz ?? 'Europe/Stockholm';
  // Alternatives can be tomorrow's: say so rather than show 04:55 as if it were today.
  const localDay = (when: number, zone: string) => new Intl.DateTimeFormat('en-CA', { timeZone: zone }).format(when);
  const otherDay = (when: number, zone: string) => (localDay(when, zone) !== localDay(Math.max(now, schedDep), tz) ? fmtDay(when, zone) : null);
  const line = (k: DisruptionKind) => {
    switch (k) {
      case 'canceled':
        return t('disruption.canceled', { train });
      case 'skips_board':
        return t('disruption.skipsBoard', { train, station: board?.name ?? '' });
      case 'skips_alight':
        return t('disruption.skipsAlight', { train, station: alight?.name ?? '' });
      case 'replacement':
        return t('disruption.replacement');
      case 'delayed':
        return arrived && leg.arrDelayMin !== null
          ? t('disruption.arrivedLate', { min: leg.arrDelayMin, station: alight?.name ?? '' })
          : t('disruption.delayed', { min: Math.max(leg.depDelayMin ?? 0, leg.arrDelayMin ?? 0), station: alight?.name ?? '' });
      case 'connection_missed':
        return t('disruption.connectionMissed', { station: next?.origin?.name ?? '', next: [next?.operator?.name, next?.trainNumber].filter(Boolean).join(' '), time: fmtTime(ms(next?.schedDep ?? null), tz, settings.clock) });
      case 'connection_at_risk':
        return t('disruption.connectionAtRisk', { station: next?.origin?.name ?? '' });
    }
  };
  // Why, when Trafikverket says (its reason codes, from a fixed table).
  const reasons = delayReasons(deviations, i18n.language.startsWith('sv') ? 'sv' : 'en');
  const tone: AlertTone = arrived ? 'info' : severe || kinds.includes('replacement') ? 'severe' : 'warn';
  const altCount = alts ? alts.direct.length + alts.connections.length : null;
  return (
    <AlertCard
      tone={tone}
      icon={tone === 'info' ? <Info size={16} /> : <AlertTriangle size={16} />}
      title={t(arrived && kinds[0] === 'delayed' ? 'disruption.title.delayed_past' : `disruption.title.${kinds[0]}`)}
      dismissKey={`disruption:${leg.id}:${kinds.join(',')}`}
    >
      <ul className="disruption-lines">
        {kinds.map((k) => (
          <li key={k}>{line(k)}</li>
        ))}
      </ul>
      {reasons.length > 0 && <p className="alert-why">{t('disruption.why', { reasons: reasons.join(t('disruption.and')) })}</p>}

      {search && (
        <div className="disruption-alts">
          <button className="alt-toggle" onClick={() => setShowAlts(!showAlts)} aria-expanded={showAlts} disabled={!altCount}>
            <span>
              {altCount === null ? t('disruption.looking') : altCount === 0 ? t('disruption.noAlternatives') : showAlts ? t('disruption.hideSuggested') : t('disruption.viewSuggested')}
            </span>
            {altCount ? showAlts ? <ChevronUp size={18} aria-hidden="true" /> : <ChevronDown size={18} aria-hidden="true" /> : null}
          </button>
          {altCount === 0 && <p className="caption">{t('disruption.noneFound')}</p>}
          {showAlts && alts && altCount !== 0 && (
            <>
              {final.id !== leg.id && <p className="caption">{t('disruption.journeyContinues', { station: final.destination?.name ?? '' })}</p>}
              <ul className="alt-list">
                {alts.direct.map((r) => (
                  <li key={`${r.key}|${r.serviceDate}`} className="alt-row">
                    <OperatorBadge operator={r.operatorId ? ops.get(r.operatorId) : undefined} size={24} />
                    <span className="alt-main">
                      <span className="strong tabular">
                        {fmtTime(r.from.time, r.from.tz, settings.clock)} → {fmtTime(r.to.time, r.to.tz, settings.clock)}
                      </span>
                      <span className="caption">{[[r.operatorId ? ops.get(r.operatorId)?.name : r.routeName, r.trainNumber].filter(Boolean).join(' '), otherDay(r.from.time, r.from.tz)].filter(Boolean).join(' · ')}</span>
                    </span>
                    <span className="alt-actions">
                      <Link className="button small" to={`/explore?${new URLSearchParams({ train: r.trainNumber ?? '', date: r.serviceDate, key: r.key })}`}>
                        {t('disruption.live')}
                      </Link>
                      <Link className="button small primary" to={`/add?${new URLSearchParams({ trip: r.key, date: r.serviceDate, from: String(r.from.seq), to: String(r.to.seq), replace: leg.id })}`}>
                        {t('disruption.useInstead')}
                      </Link>
                    </span>
                  </li>
                ))}
                {alts.connections.map((c) => (
                  <li key={`${c.first.key}|${c.second.key}`} className="alt-row">
                    <OperatorBadge operator={c.first.operatorId ? ops.get(c.first.operatorId) : undefined} size={24} />
                    <span className="alt-main">
                      <span className="strong tabular">
                        {fmtTime(c.first.from.time, c.first.from.tz, settings.clock)} → {fmtTime(c.second.to.time, c.second.to.tz, settings.clock)}
                      </span>
                      <span className="caption">{[t('add.changeAt', { station: c.changeAt.name, min: c.changeMin }), otherDay(c.first.from.time, c.first.from.tz)].filter(Boolean).join(' · ')}</span>
                    </span>
                    <span className="alt-actions">
                      <Link className="button small" to={`/explore?${new URLSearchParams({ train: c.first.trainNumber ?? '', date: c.first.serviceDate, key: c.first.key })}`}>
                        {t('disruption.live')}
                      </Link>
                    </span>
                  </li>
                ))}
              </ul>
              <p className="caption">{t('disruption.altsNote', { operator: op?.name ?? t('disruption.theOperator') })}</p>
            </>
          )}
        </div>
      )}

      <div className="disruption-rights">
        <h3 className="section-header">{t('disruption.rightsTitle')}</h3>
        <p className="caption">
          {rights.regime === 'operator'
            ? t('disruption.rightsOperator', { operator: op?.name ?? t('disruption.theOperator') })
            : rights.regime === 'se_short'
              ? rights.claim
                ? t('disruption.rightsSeShortClaim')
                : t('disruption.rightsSeShort')
              : rights.claim
                ? t(`disruption.rightsEu_${rights.claim}`)
                : t('disruption.rightsEu')}
        </p>
        <p className="caption rights-links">
          {rights.regime !== 'operator' && (
            <a href={rights.regime === 'eu' ? RIGHTS_LINKS.eu[i18n.language.startsWith('sv') ? 'sv' : 'en'] : RIGHTS_LINKS.se} target="_blank" rel="noopener noreferrer">
              {rights.regime === 'eu' ? t('disruption.linkEu') : t('disruption.linkSe')}
            </a>
          )}
          {op?.ticketUrl && (
            <a href={op.ticketUrl} target="_blank" rel="noopener noreferrer">
              {t('disruption.linkOperator', { operator: op.name })}
            </a>
          )}
        </p>
      </div>
      {leg.canceled && <p className="caption">{t('disruption.passportNote')}</p>}
    </AlertCard>
  );
}
