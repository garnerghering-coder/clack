// Connections (ADDITIONS_01 C3, the Layover Guide outside the map): platforms, walk time and a status chip for a
// change between two legs at the same station. Uses the station map when there is one, otherwise an estimate from
// the station's size, and says so.
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Footprints, Map as MapIcon } from 'lucide-react';
import { connectionStatus, routeTracks, type ConnectionResult, type StationMap, type WalkProfile } from '@clack/shared';
import { api, ms, type Leg, type StationInfo } from '../api';
import { useSettings } from '../settings';

const maps = new Map<string, Promise<StationMap | null>>();
const infos = new Map<string, Promise<StationInfo | null>>();
/** The station's map (null when it has none), cached for the session. */
export function useStationMap(stationId: string | null | undefined): { map: StationMap | null; info: StationInfo | null; ready: boolean } {
  const [state, setState] = useState<{ map: StationMap | null; info: StationInfo | null; ready: boolean }>({ map: null, info: null, ready: false });
  useEffect(() => {
    if (!stationId) return;
    if (!infos.has(stationId)) infos.set(stationId, api.station(stationId).catch(() => null));
    void infos.get(stationId)!.then((info) => {
      if (!info?.hasMap) return setState({ map: null, info, ready: true });
      if (!maps.has(stationId)) maps.set(stationId, api.stationMap(stationId).catch(() => null));
      void maps.get(stationId)!.then((map) => setState({ map, info, ready: true }));
    });
  }, [stationId]);
  return state;
}

export const profileOf = (s: { walkPace: WalkProfile['pace']; stepFree: boolean; heavyLuggage: boolean }): WalkProfile => ({ pace: s.walkPace, stepFree: s.stepFree, luggage: s.heavyLuggage });

/** Best current estimate of when leg A arrives and leg B leaves. */
export function connectionTimes(a: Leg, b: Leg) {
  const arrival = ms(a.actualArr) ?? ms(a.live?.arrivalEta) ?? (ms(a.schedArr) !== null ? ms(a.schedArr)! + (a.arrDelayMin ?? 0) * 60_000 : null);
  // Before it leaves, a live leg's next stop is the one you board at: its ETA is the expected departure.
  const boardingEta = b.live && (b.live.status === 'scheduled' || b.live.status === 'boarding') ? ms(b.live.eta) : null;
  const departure = ms(b.actualDep) ?? boardingEta ?? (ms(b.schedDep) !== null ? ms(b.schedDep)! + (b.depDelayMin ?? 0) * 60_000 : null);
  return { arrival, departure };
}

export function useConnection(a: Leg, b: Leg): { result: ConnectionResult; map: StationMap | null; stationId: string | null; noPath: boolean } {
  const { settings } = useSettings();
  const stationId = a.destination?.id ?? null;
  const { map, info } = useStationMap(stationId);
  const { arrival, departure } = connectionTimes(a, b);
  const route = map ? routeTracks(map, a.arrPlatform, b.depPlatform, profileOf(settings)) : null;
  // A map that can't connect the two platforms falls back to the size estimate (and is a data bug to fix).
  const noPath = Boolean(map && a.arrPlatform && b.depPlatform && !route);
  if (noPath) console.warn(`station map ${stationId}: no ${settings.stepFree ? 'step-free ' : ''}path from track ${a.arrPlatform} to ${b.depPlatform}`);
  const result = connectionStatus({
    arrival,
    departure,
    arrivalPlatform: a.arrPlatform,
    departurePlatform: b.depPlatform,
    canceledA: a.canceled,
    canceledB: b.canceled,
    walkSeconds: route ? route.seconds : null,
    sizeClass: info?.sizeClass ?? (map ? 'large' : 'medium'),
  });
  return { result, map, stationId, noPath };
}

const BAND: Record<ConnectionResult['status'], string> = {
  easy: 'on_time',
  tight: 'slight',
  miss: 'very_late',
  broken: 'very_late',
  unknown: 'unknown',
  check_signs: 'unknown',
  probably_ok: 'slight',
};

export function ConnectionChip({ result }: { result: ConnectionResult }) {
  const { t } = useTranslation();
  const spare = result.slackSeconds !== null && result.slackSeconds >= 0 && result.status !== 'broken' ? ` · ${t('connection.spare', { min: Math.floor(result.slackSeconds / 60) })}` : '';
  return <span className={`delay-pill band-${BAND[result.status]} connection-chip`}>{t(`connection.status.${result.status}`) + spare}</span>;
}

/** Map link with everything the Layover Guide needs. */
export function stationMapHref(stationId: string, a: Leg, b: Leg) {
  const { arrival, departure } = connectionTimes(a, b);
  const q = new URLSearchParams();
  if (a.arrPlatform) q.set('from', a.arrPlatform);
  if (b.depPlatform) q.set('to', b.depPlatform);
  if (arrival) q.set('arr', String(arrival));
  if (departure) q.set('dep', String(departure));
  if (a.operator?.id) q.set('a', a.operator.id);
  if (b.operator?.id) q.set('b', b.operator.id);
  if (a.canceled) q.set('xa', '1');
  if (b.canceled) q.set('xb', '1');
  return `/stations/${stationId}/map?${q}`;
}

export function ConnectionCard({ a, b, compact = false }: { a: Leg; b: Leg; compact?: boolean }) {
  const { t } = useTranslation();
  const { result, map, stationId } = useConnection(a, b);
  const walkMin = result.walkSeconds !== null ? Math.max(1, Math.round(result.walkSeconds / 60)) : null;
  const tracks = a.arrPlatform || b.depPlatform ? t('connection.tracks', { from: a.arrPlatform ?? '?', to: b.depPlatform ?? '?' }) : null;
  return (
    <div className={compact ? 'connection compact' : 'connection card'}>
      <div className="connection-head">
        <span className="strong">{t('connection.changeAt', { station: a.destination?.name ?? '' })}</span>
        <ConnectionChip result={result} />
      </div>
      <p className="caption">
        {[tracks, walkMin !== null ? t('connection.walk', { min: walkMin }) : null, result.layoverSeconds !== null ? t('connection.layover', { min: Math.round(result.layoverSeconds / 60) }) : null]
          .filter(Boolean)
          .join(' · ')}
      </p>
      {result.estimated && result.status !== 'broken' && (
        <p className="caption connection-estimate">
          <Footprints size={13} /> {t('connection.estimated')}
        </p>
      )}
      {result.status === 'broken' && <p className="banner error">{t('connection.brokenBanner')}</p>}
      {map && stationId && (
        <Link className="button small" to={stationMapHref(stationId, a, b)}>
          <MapIcon size={16} /> {t('connection.openMap')}
        </Link>
      )}
    </div>
  );
}

/** On a trip's page: the change into it and out of it, when it's part of a journey (ADDITIONS_01 C3). */
export function JourneyConnections({ legId, journeyId }: { legId: string; journeyId: string | null }) {
  const [legs, setLegs] = useState<Leg[] | null>(null);
  useEffect(() => {
    if (journeyId) api.journey(journeyId).then((j) => setLegs(j.legs), () => setLegs(null));
  }, [journeyId]);
  if (!legs) return null;
  const i = legs.findIndex((l) => l.id === legId);
  if (i < 0) return null;
  const pairs: [Leg, Leg][] = [];
  if (i > 0 && legs[i - 1]!.destination?.id === legs[i]!.origin?.id) pairs.push([legs[i - 1]!, legs[i]!]);
  if (i < legs.length - 1 && legs[i]!.destination?.id === legs[i + 1]!.origin?.id) pairs.push([legs[i]!, legs[i + 1]!]);
  return (
    <>
      {pairs.map(([a, b]) => (
        <ConnectionCard key={`${a.id}-${b.id}`} a={a} b={b} />
      ))}
    </>
  );
}
