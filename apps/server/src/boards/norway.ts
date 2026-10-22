// Departure and arrival boards for Norwegian stations, from Entur's Journey Planner (NORWAY_DATA_FINDINGS.md):
// aimed, expected and actual times, track, cancellations and notices per call, trains only. Same board rows as
// Trafikverket's boards. normalizeNorwayBoard is pure; fetchNorwayCalls talks to Entur.
import { delayMinutes } from '@clack/shared';
import { jpQuery } from '../entur/client.js';
import { cleanStopName } from '../import/gtfs-no.js';
import { trainTypeFor } from '../legs/trainTypes.js';
import type { StationCall } from '../search/timetable.js';
import type { BoardRow, BoardType, PlatformMemory } from './board.js';

export interface JpBoardCall {
  aimedArrivalTime: string | null;
  aimedDepartureTime: string | null;
  expectedArrivalTime: string | null;
  expectedDepartureTime: string | null;
  actualArrivalTime: string | null;
  actualDepartureTime: string | null;
  cancellation: boolean;
  quay: { publicCode: string | null } | null;
  destinationDisplay: { frontText: string | null; via: string[] | null } | null;
  situations: { summary: { value: string; language: string | null }[] }[];
  serviceJourney: { id: string; privateCode: string | null; quays: { name: string }[] };
  date: string;
}

const QUERY = `query($id: String!, $start: DateTime!, $range: Int!, $type: ArrivalDeparture!) {
  stopPlace(id: $id) { estimatedCalls(startTime: $start, timeRange: $range, numberOfDepartures: 300, arrivalDeparture: $type,
    whiteListedModes: [rail], includeCancelledTrips: true) {
    aimedArrivalTime aimedDepartureTime expectedArrivalTime expectedDepartureTime actualArrivalTime actualDepartureTime
    cancellation date quay { publicCode } destinationDisplay { frontText via } situations { summary { value language } }
    serviceJourney { id privateCode quays { name } } } } }`;

export async function fetchNorwayCalls(nsrId: string, type: BoardType, from: number, to: number, fetchImpl?: typeof fetch): Promise<JpBoardCall[]> {
  const data = await jpQuery<{ stopPlace: { estimatedCalls: JpBoardCall[] } | null }>(
    QUERY,
    { id: nsrId, start: new Date(from).toISOString(), range: Math.round((to - from) / 1000), type },
    fetchImpl,
  );
  return data.stopPlace?.estimatedCalls ?? [];
}

/** The operator from the service journey's codespace (VYG:ServiceJourney:… is Vy). */
const BRAND: Record<string, string> = { VYG: 'vy', GOA: 'go-ahead-norge', FLT: 'flytoget', SJN: 'sj-nord' };
const time = (s: string | null) => (s ? Date.parse(s) : null);
const minute = (ms: number) => Math.floor(ms / 60_000);

/** Notices in English when Entur has them, otherwise in Norwegian. */
function notices(c: JpBoardCall): string[] {
  return c.situations.map((s) => (s.summary.find((x) => x.language === 'en') ?? s.summary[0])?.value).filter((v): v is string => !!v);
}

export function normalizeNorwayBoard(calls: JpBoardCall[], ctx: { type: BoardType; now: number; calls: StationCall[]; memory: PlatformMemory }): BoardRow[] {
  const dep = ctx.type === 'departures';
  const out: BoardRow[] = [];
  for (const c of calls) {
    const advertised = time(dep ? c.aimedDepartureTime : c.aimedArrivalTime);
    if (advertised === null) continue;
    const id = `${c.serviceJourney.id}|${c.date}|${ctx.type}`;
    const actual = time(dep ? c.actualDepartureTime : c.actualArrivalTime);
    const expected = time(dep ? c.expectedDepartureTime : c.expectedArrivalTime);
    const platform = c.quay?.publicCode || null;
    // Track changes, as noticed between polls (Journey Planner gives only the current track).
    const seen = ctx.memory.get(id);
    let change: BoardRow['platformChange'] = null;
    if (seen?.platform && platform && seen.platform !== platform) {
      ctx.memory.set(id, { platform, changedFrom: seen.platform, changedAt: ctx.now });
      change = { from: seen.platform, at: ctx.now };
    } else {
      ctx.memory.set(id, { platform: platform ?? seen?.platform ?? null, changedFrom: seen?.changedFrom ?? null, changedAt: seen?.changedAt ?? null });
      if (seen?.changedFrom) change = { from: seen.changedFrom, at: seen.changedAt };
    }
    // The timetable trip: Norway's trip ids are Entur's service journey ids.
    const call = ctx.calls.find((x) => x.tripKey.startsWith(`no:${c.serviceJourney.id}:`) && x.serviceDate === c.date && minute((dep ? x.dep : x.arr) ?? 0) === minute(advertised));
    const number = c.serviceJourney.privateCode ?? call?.trainNumber ?? '';
    const operatorId = call?.operatorId ?? BRAND[c.serviceJourney.id.split(':')[0]!] ?? null;
    const product = call?.product ?? 'regional';
    const origin = c.serviceJourney.quays[0]?.name;
    out.push({
      id,
      trainNumber: number,
      advertised,
      estimated: actual === null ? expected : null,
      actual,
      done: actual !== null,
      delayMin: c.cancellation ? null : delayMinutes(advertised, actual ?? expected),
      platform,
      platformChange: change,
      canceled: c.cancellation,
      deviations: notices(c),
      endpoints: dep ? [c.destinationDisplay?.frontText ?? ''].filter(Boolean) : origin ? [cleanStopName(origin)] : [],
      via: dep ? (c.destinationDisplay?.via ?? []).slice(0, 3) : [],
      operatorId,
      productName: null,
      product,
      trainType: trainTypeFor(operatorId, product, number, null),
      onboard: null,
      trip: call ? { key: call.tripKey, serviceDate: call.serviceDate, seq: call.seq } : null,
    });
  }
  return out.sort((a, b) => a.advertised - b.advertised || a.trainNumber.localeCompare(b.trainNumber));
}
