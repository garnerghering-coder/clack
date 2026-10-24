// Departure and arrival boards for Finnish stations, from Digitraffic Rail's /live-trains/station/{shortCode}
// (FINLAND_DATA_FINDINGS.md): scheduled, estimated and actual time, platform (`commercialTrack`), cancellation and
// causes per call, passenger trains only, commercial stops only (a technical stop or a pass-through is not a
// departure anyone can take). Same board rows as Trafikverket's and Entur's. normalizeFinlandBoard is pure.
import { delayMinutes } from '@clack/shared';
import { fetchStationTrains, isPassengerTrain, type DtRow, type DtTrain } from '../digitraffic/trains.js';
import type { DigitrafficOptions } from '../digitraffic/client.js';
import { finnishProduct } from '../import/gtfs-fi.js';
import { deviationTexts, digitrafficCauses } from '../legs/causes.js';
import { trainTypeFor } from '../legs/trainTypes.js';
import type { Product, StationCall } from '../search/timetable.js';
import type { BoardRow, BoardType, PlatformMemory } from './board.js';

const time = (s: string | undefined) => (s ? Date.parse(s) : null);
const minute = (ms: number) => Math.floor(ms / 60_000);

export interface FinlandBoardContext {
  type: BoardType;
  now: number;
  /** The station's Digitraffic short code (HKI). */
  code: string;
  /** Only calls scheduled inside this window are rows. */
  from: number;
  to: number;
  /** Station name for a short code (the destination or origin shown on a row). */
  names: (code: string) => string;
  calls: StationCall[];
  memory: PlatformMemory;
  /** The unit or locomotive type running a train, when known (/compositions). */
  vehicleOf?: (number: string, date: string) => string | null;
}

/** The train's commercial calls, first and last: where it starts and ends (what a row shows as origin and destination). */
const ends = (t: DtTrain) => {
  const rows = t.timeTableRows.filter((r) => r.commercialStop === true);
  return { first: rows[0]?.stationShortCode ?? null, last: rows.at(-1)?.stationShortCode ?? null };
};

export function normalizeFinlandBoard(trains: DtTrain[], ctx: FinlandBoardContext): BoardRow[] {
  const dep = ctx.type === 'departures';
  const want: DtRow['type'] = dep ? 'DEPARTURE' : 'ARRIVAL';
  const out: BoardRow[] = [];
  for (const t of trains) {
    if (!isPassengerTrain(t)) continue;
    const number = String(t.trainNumber);
    const { first, last } = ends(t);
    for (const r of t.timeTableRows) {
      if (r.stationShortCode !== ctx.code || r.type !== want || r.commercialStop !== true) continue;
      const advertised = Date.parse(r.scheduledTime);
      if (!Number.isFinite(advertised) || advertised < ctx.from || advertised >= ctx.to) continue;
      // A train's origin has no arrival row and its destination no departure row, so a train never lists itself as
      // going to the station it is leaving.
      const endpoint = dep ? last : first;
      if (!endpoint || endpoint === ctx.code) continue;
      const id = `fi:${number}|${t.departureDate}|${ctx.code}|${ctx.type}|${advertised}`;
      const actual = time(r.actualTime);
      const estimated = actual === null ? time(r.liveEstimateTime) : null;
      const platform = r.commercialTrack?.trim() || null;
      const canceled = Boolean(r.cancelled || t.cancelled);
      // Track changes, as noticed between polls (Digitraffic gives only the current track).
      const seen = ctx.memory.get(id);
      let change: BoardRow['platformChange'] = null;
      if (seen?.platform && platform && seen.platform !== platform) {
        ctx.memory.set(id, { platform, changedFrom: seen.platform, changedAt: ctx.now });
        change = { from: seen.platform, at: ctx.now };
      } else {
        ctx.memory.set(id, { platform: platform ?? seen?.platform ?? null, changedFrom: seen?.changedFrom ?? null, changedAt: seen?.changedAt ?? null });
        if (seen?.changedFrom) change = { from: seen.changedFrom, at: seen.changedAt };
      }
      // The timetable trip: same train number and day, and the call at this minute.
      const call = ctx.calls.find((c) => c.tripKey.startsWith('fi:') && c.trainNumber === number && c.serviceDate === t.departureDate && minute((dep ? c.dep : c.arr) ?? 0) === minute(advertised));
      const operatorId = call?.operatorId ?? (t.operatorShortCode === 'vr' ? 'vr-fi' : null);
      const product = (call?.product ?? finnishProduct(t.trainType).product ?? 'regional') as Product;
      const causes = digitrafficCauses(r.causes);
      const endName = ctx.names(endpoint);
      out.push({
        id,
        trainNumber: number,
        advertised,
        estimated,
        actual,
        done: actual !== null,
        delayMin: canceled ? null : delayMinutes(advertised, actual ?? estimated),
        platform,
        platformChange: change,
        canceled,
        deviations: deviationTexts(causes),
        causes,
        endpoints: [endName],
        via: [],
        operatorId,
        productName: null,
        product,
        trainType: trainTypeFor(operatorId, product, number, null, [endName], ctx.vehicleOf?.(number, t.departureDate) ?? null),
        onboard: null,
        trip: call ? { key: call.tripKey, serviceDate: call.serviceDate, seq: call.seq } : null,
      });
    }
  }
  return out.sort((a, b) => a.advertised - b.advertised || a.trainNumber.localeCompare(b.trainNumber));
}

/** The trains calling at a station, from Digitraffic (cached 30 s). */
export const fetchFinlandBoardTrains = (code: string, opts: DigitrafficOptions & { now?: number } = {}) => fetchStationTrains(code, opts);
