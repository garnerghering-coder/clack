// Station departure and arrival boards (ADDITIONS_01 B). Trafikverket TrainAnnouncement rows for one station and
// activity, normalised into board rows: estimated vs advertised time, platform (with change detection), delay,
// cancellation, destination/origin and via, brand, train type, and a link to the timetable trip so a row can be
// added to your trips. normalizeBoard is pure; fetchBoardRows talks to Trafikverket.
import { delayMinutes, type OnboardFacts } from '@clack/shared';
import { normName } from '../lib/geo.js';
import { actualTime, trvQuery } from '../trafikverket/client.js';
import type { Product, StationCall } from '../search/timetable.js';
import { parseComposition, trainTypeFor } from '../legs/trainTypes.js';
import { onboardFromRow } from '../legs/onboard.js';

export type BoardType = 'departures' | 'arrivals';

interface Loc {
  LocationName: string;
  Priority?: number;
  Order?: number;
}
interface Desc {
  Code?: string;
  Description: string;
}
export interface TrvBoardRow {
  ActivityId: string;
  ActivityType: 'Avgang' | 'Ankomst';
  AdvertisedTimeAtLocation: string;
  AdvertisedTrainIdent: string;
  Canceled?: boolean;
  Deleted?: boolean;
  EstimatedTimeAtLocation?: string;
  TimeAtLocation?: string;
  TrackAtLocation?: string;
  ToLocation?: Loc[];
  FromLocation?: Loc[];
  ViaToLocation?: Loc[];
  ViaFromLocation?: Loc[];
  ProductInformation?: Desc[];
  TypeOfTraffic?: Desc[];
  Deviation?: Desc[];
  OtherInformation?: Desc[];
  Operator?: string;
  TrainComposition?: Desc[];
  Service?: Desc[];
}

export interface BoardRow {
  id: string;
  trainNumber: string;
  advertised: number;
  estimated: number | null;
  actual: number | null;
  /** Departed (departures) or arrived (arrivals). */
  done: boolean;
  delayMin: number | null;
  platform: string | null;
  /** Set when the platform changed: the old one if we saw it, null if only Trafikverket's "Spårändrat" told us. */
  platformChange: { from: string | null; at: number | null } | null;
  canceled: boolean;
  deviations: string[];
  /** Destinations (departures) or origins (arrivals), as names. */
  endpoints: string[];
  via: string[];
  operatorId: string | null;
  productName: string | null;
  product: Product;
  trainType: string | null;
  /** On-board facts for this departure from Trafikverket (null on arrivals). */
  onboard: OnboardFacts | null;
  trip: { key: string; serviceDate: string; seq: number } | null;
}

export interface Board {
  stationId: string;
  signature: string;
  type: BoardType;
  from: number;
  to: number;
  updatedAt: number;
  rows: BoardRow[];
}

/** What a poller remembers between fetches, to notice platform changes. */
export type PlatformMemory = Map<string, { platform: string | null; changedFrom: string | null; changedAt: number | null }>;

export interface NormalizeContext {
  type: BoardType;
  now: number;
  /** Trafikverket signature -> station name. */
  names: (sig: string) => string;
  matchBrand: (text: string) => string | null;
  calls: StationCall[];
  memory: PlatformMemory;
}

const time = (s?: string) => (s ? Date.parse(s) : null);
const minute = (ms: number) => Math.floor(ms / 60_000);
const PLATFORM_CHANGED = 'spårändrat';

function productFromTrv(row: TrvBoardRow, brand: string | null): Product {
  const p = row.ProductInformation?.map((x) => x.Description).join(' ') ?? '';
  if (/snabbtåg/i.test(p)) return 'high_speed';
  if (/natt/i.test(p)) return 'night';
  if (/intercity/i.test(p)) return 'intercity';
  if (row.TypeOfTraffic?.some((t) => /pendeltåg/i.test(t.Description))) return 'commuter';
  if (brand && ['sl', 'pagatag', 'ostgotapendeln'].includes(brand)) return 'commuter';
  if (/museitåg|veteran/i.test(p)) return 'heritage';
  return 'regional';
}

/** Buses and taxis replacing trains appear in Trafikverket's data; the board only shows trains (SPEC §11). */
export const isTrain = (row: TrvBoardRow) => !row.TypeOfTraffic?.some((t) => /buss|taxi/i.test(t.Description));

/** Trafikverket rows -> board rows. Updates `memory` (platform history) as a side effect. */
export function normalizeBoard(rows: TrvBoardRow[], ctx: NormalizeContext): BoardRow[] {
  const dep = ctx.type === 'departures';
  // Timetable calls by minute, to link rows to trips (same idea as actual-times matching, Phase 0 §2).
  const byMinute = new Map<number, StationCall[]>();
  for (const c of ctx.calls) {
    const t = dep ? c.dep : c.arr;
    if (t === null) continue;
    (byMinute.get(minute(t)) ?? byMinute.set(minute(t), []).get(minute(t))!).push(c);
  }
  const out: BoardRow[] = [];
  for (const r of rows) {
    if (r.Deleted || !isTrain(r)) continue;
    const advertised = Date.parse(r.AdvertisedTimeAtLocation);
    const actual = actualTime(r.TimeAtLocation, advertised);
    const estimated = time(r.EstimatedTimeAtLocation);
    const platform = r.TrackAtLocation && r.TrackAtLocation !== 'x' ? r.TrackAtLocation : null;
    const deviations = (r.Deviation ?? []).map((d) => d.Description);
    const productName = r.ProductInformation?.[0]?.Description ?? null;
    const brand = (productName && ctx.matchBrand(productName)) || (r.Operator && ctx.matchBrand(r.Operator)) || null;

    // Platform change: remembered from an earlier poll, or flagged by Trafikverket.
    const seen = ctx.memory.get(r.ActivityId);
    let change: BoardRow['platformChange'] = null;
    if (seen && seen.platform && platform && seen.platform !== platform) {
      ctx.memory.set(r.ActivityId, { platform, changedFrom: seen.platform, changedAt: ctx.now });
      change = { from: seen.platform, at: ctx.now };
    } else {
      if (!seen || platform)
        ctx.memory.set(r.ActivityId, {
          platform: platform ?? seen?.platform ?? null,
          changedFrom: seen?.changedFrom ?? null,
          changedAt: seen?.changedAt ?? null,
        });
      if (seen?.changedFrom) change = { from: seen.changedFrom, at: seen.changedAt };
    }
    if (!change && deviations.some((d) => d.toLowerCase() === PLATFORM_CHANGED)) change = { from: null, at: null };

    // Link to the timetable: same minute, preferring the same train number (also with GTFS's 5-digit prefix).
    const candidates = byMinute.get(minute(advertised)) ?? [];
    const n = r.AdvertisedTrainIdent;
    const sameNumber = candidates.filter(
      (c) => c.trainNumber === n || (c.trainNumber?.length === 5 && String(Number(c.trainNumber.slice(1))) === n) || (n.length === 5 && c.trainNumber === String(Number(n.slice(1)))),
    );
    const call = sameNumber[0] ?? (candidates.length === 1 && (!brand || candidates[0]!.operatorId === brand) ? candidates[0] : undefined);

    const product = call?.product ?? productFromTrv(r, brand);
    const operatorId = call?.operatorId ?? brand;
    const ends = (dep ? r.ToLocation : r.FromLocation) ?? [];
    const via = [...((dep ? r.ViaToLocation : r.ViaFromLocation) ?? [])].sort((a, b) => (a.Order ?? 0) - (b.Order ?? 0));
    out.push({
      id: r.ActivityId,
      trainNumber: n,
      advertised,
      estimated,
      actual,
      done: actual !== null,
      delayMin: r.Canceled ? null : delayMinutes(advertised, actual ?? estimated),
      platform,
      platformChange: change,
      canceled: Boolean(r.Canceled),
      deviations: deviations.filter((d) => d.toLowerCase() !== PLATFORM_CHANGED),
      endpoints: ends.map((l) => ctx.names(l.LocationName)),
      via: via.slice(0, 3).map((l) => ctx.names(l.LocationName)),
      operatorId,
      productName,
      product,
      trainType: trainTypeFor(operatorId, product, call?.trainNumber ?? n, parseComposition(r.TrainComposition)),
      onboard: dep ? onboardFromRow(r) : null,
      trip: call ? { key: call.tripKey, serviceDate: call.serviceDate, seq: call.seq } : null,
    });
  }
  return out.sort((a, b) => a.advertised - b.advertised || a.trainNumber.localeCompare(b.trainNumber));
}

const FIELDS = [
  'ActivityId',
  'ActivityType',
  'AdvertisedTimeAtLocation',
  'AdvertisedTrainIdent',
  'Canceled',
  'Deleted',
  'EstimatedTimeAtLocation',
  'TimeAtLocation',
  'TrackAtLocation',
  'ToLocation',
  'FromLocation',
  'ViaToLocation',
  'ViaFromLocation',
  'ProductInformation',
  'TypeOfTraffic',
  'Deviation',
  'OtherInformation',
  'Operator',
  'TrainComposition',
  'Service',
];

export async function fetchBoardRows(signature: string, type: BoardType, from: number, to: number, fetchImpl?: typeof fetch): Promise<TrvBoardRow[]> {
  const r = await trvQuery<{ TrainAnnouncement?: TrvBoardRow[] }>(
    // No orderby: Trafikverket answers ~30% faster without it, and normalizeBoard sorts anyway.
    `<QUERY objecttype="TrainAnnouncement" schemaversion="1.9"><FILTER>` +
      `<EQ name="LocationSignature" value="${signature}"/><EQ name="ActivityType" value="${type === 'departures' ? 'Avgang' : 'Ankomst'}"/>` +
      `<EQ name="Advertised" value="true"/>` +
      `<GTE name="AdvertisedTimeAtLocation" value="${new Date(from).toISOString()}"/><LT name="AdvertisedTimeAtLocation" value="${new Date(to).toISOString()}"/>` +
      `</FILTER>${FIELDS.map((f) => `<INCLUDE>${f}</INCLUDE>`).join('')}</QUERY>`,
    fetchImpl,
  );
  return r.TrainAnnouncement ?? [];
}

/** Brand from Trafikverket's product text ("SJ Snabbtåg", "Pågatågen", "SL Pendeltåg 41"). */
export function brandMatcher(brands: { id: string; name: string; aliases: string[] }[]) {
  const keys: [string, string][] = [];
  for (const b of brands) for (const a of [b.name, ...b.aliases]) keys.push([normName(a), b.id]);
  keys.sort((a, b) => b[0].length - a[0].length);
  return (text: string): string | null => {
    const t = normName(text);
    for (const [k, id] of keys) if (t === k || t.startsWith(`${k} `)) return id;
    return null;
  };
}
