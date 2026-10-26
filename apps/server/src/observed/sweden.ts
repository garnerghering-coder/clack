// Sweden's observed record, from Trafikverket (DATA_FINDINGS.md). Trafikverket keeps actual times for about 4 days, so
// each night we fetch the whole of yesterday, and again 2 and 3 days on (actual times can arrive that late); the
// fetch 3 days on is final. Every field of every announcement is kept, including the timing points a train passes
// without stopping (Advertised=false), which let a trip be replayed on the map later without storing positions.
// Also kept each night: incidents (OperativeEvent), their reason-coded events (RailwayEvent) and platform-sign
// messages (TrainStationMessage), all as Trafikverket sent them.
//
// Measured 2026-10-26: one hour of a Sunday morning is ~3,600 announcements (2,200 at stops, 1,400 passages), 4.4 MB
// as JSON, 0.14 MB brotli, under a second per query.
import type { Db } from '../db/client.js';
import { actualTime, trvQuery } from '../trafikverket/client.js';
import { addDays, todayIn, zonedToUtc } from '../lib/time.js';
import { writeRaw } from './archive.js';
import { cancelLevel, fetchOf, passage, recordFetch, saveRuns, type ObservedCall, type ObservedCause, type ObservedRun, type Passage } from './store.js';

const TZ = 'Europe/Stockholm';
export const SOURCE = 'trafikverket';
/** A train that starts on day D can run into the next afternoon (night trains to Narvik and Luleå). */
const SPAN_HOURS = 38;
/** Trafikverket answers nationwide queries slowly past a few hours of data; an hour per query is quick. */
const SLICE_HOURS = 1;
/** The fetch this many days after the service day is final. */
export const FINAL_AFTER_DAYS = 3;

export type Announcement = Record<string, unknown> & {
  ActivityType: 'Ankomst' | 'Avgang';
  Advertised: boolean;
  AdvertisedTimeAtLocation: string;
  AdvertisedTrainIdent: string;
  LocationSignature: string;
  ScheduledDepartureDateTime?: string;
  DepartureDateOTN?: string;
  Canceled?: boolean;
  Deleted?: boolean;
  TimeAtLocation?: string;
  TimeAtLocationWithSeconds?: string;
  EstimatedTimeAtLocation?: string;
  TrackAtLocation?: string;
  Deviation?: { Code?: string; Description?: string }[];
  ProductInformation?: { Code?: string; Description?: string }[];
  Operator?: string;
};

/** The day a train started, as Trafikverket dates it (its local date). */
export const serviceDateOf = (a: Announcement) => (a.ScheduledDepartureDateTime ?? a.DepartureDateOTN ?? a.AdvertisedTimeAtLocation).slice(0, 10);

const iso = (ms: number) => new Date(ms).toISOString().replace(/\.\d+Z$/, 'Z');

/** Every announcement for trains that started on `date`, fetched an hour at a time. Throws if any hour fails. */
export async function fetchDay(date: string, opts: { fetchImpl?: typeof fetch } = {}): Promise<Announcement[]> {
  const [y, m, d] = date.split('-').map(Number) as [number, number, number];
  const start = zonedToUtc(y, m, d, 0, 0, 0, TZ);
  const out: Announcement[] = [];
  for (let h = 0; h < SPAN_HOURS; h += SLICE_HOURS) {
    const from = iso(start + h * 3600_000);
    const to = iso(start + (h + SLICE_HOURS) * 3600_000);
    const q = `<QUERY objecttype="TrainAnnouncement" schemaversion="1.9"><FILTER><AND><GTE name="AdvertisedTimeAtLocation" value="${from}"/><LT name="AdvertisedTimeAtLocation" value="${to}"/></AND></FILTER></QUERY>`;
    let rows: Announcement[] | undefined;
    for (let attempt = 1; !rows; attempt++) {
      try {
        rows = ((await trvQuery<{ TrainAnnouncement?: Announcement[] }>(q, opts.fetchImpl)).TrainAnnouncement ?? []) as Announcement[];
      } catch (e) {
        if (attempt >= 3) throw e;
        await new Promise((r) => setTimeout(r, 5_000 * attempt));
      }
    }
    for (const a of rows) if (serviceDateOf(a) === date) out.push(a);
  }
  return out;
}

/** Fields that have their own column in observed_calls, so they aren't repeated in `extra`. */
const CALL_FIELDS = new Set([
  'ActivityType',
  'Advertised',
  'AdvertisedTimeAtLocation',
  'AdvertisedTrainIdent',
  'LocationSignature',
  'Canceled',
  'Deleted',
  'TimeAtLocation',
  'TimeAtLocationWithSeconds',
  'EstimatedTimeAtLocation',
  'TrackAtLocation',
  'Deviation',
  'ScheduledDepartureDateTime',
  'DepartureDateOTN',
]);

/**
 * Bookkeeping that repeats at every stop and says nothing about how the train ran: ids, web links, the "via" lists
 * shown on signs, the per-stop copy of the schedule date. Left to the raw archive (which keeps every field) rather
 * than copied into the projection, where it was three quarters of the size (40 MB for a day, measured 2026-10-26).
 */
const RAW_ONLY = new Set(['OperationalTransportIdentifiers', 'ActivityId', 'ModifiedTime', 'LocationDateTimeOTN', 'WebLink', 'WebLinkName', 'MobileWebLink', 'ViaToLocation', 'ViaFromLocation']);

const ms = (s: unknown) => (typeof s === 'string' ? Date.parse(s) : null);
const actual = (a: Announcement) => actualTime(a.TimeAtLocationWithSeconds ?? a.TimeAtLocation, a.AdvertisedTimeAtLocation);
const track = (a?: Announcement) => (a?.TrackAtLocation && a.TrackAtLocation.toLowerCase() !== 'x' ? a.TrackAtLocation : null);

function causesOf(rows: (Announcement | undefined)[]): ObservedCause[] {
  const seen = new Set<string>();
  const out: ObservedCause[] = [];
  for (const r of rows)
    for (const d of r?.Deviation ?? []) {
      const k = `${d.Code ?? ''}|${d.Description ?? ''}`;
      if (seen.has(k)) continue;
      seen.add(k);
      out.push({ src: 'trv', ...(d.Code ? { code: d.Code } : {}), ...(d.Description ? { text: d.Description } : {}) });
    }
  return out;
}

/** The product's name: the first ProductInformation entry that isn't just a line number. */
export function productOf(info: Announcement['ProductInformation']): string | null {
  return info?.find((p) => p.Description && !/^\d+$/.test(p.Description))?.Description ?? info?.[0]?.Description ?? null;
}

/**
 * One service day's announcements as runs: one per train number, with its stops (arrival and departure merged per
 * place, in order) and the places it passed. Trains with no announced stop (freight, empty runs) stay in the raw
 * archive only. Fields that are the same at every stop go in the run's `info`; the rest stay with their stop.
 */
export function project(date: string, rows: Announcement[], stationBySig: Map<string, string>, final: boolean): ObservedRun[] {
  const byTrain = new Map<string, Announcement[]>();
  for (const a of rows) {
    if (a.Deleted) continue;
    (byTrain.get(a.AdvertisedTrainIdent) ?? byTrain.set(a.AdvertisedTrainIdent, []).get(a.AdvertisedTrainIdent)!).push(a);
  }
  const runs: ObservedRun[] = [];
  for (const [ident, all] of byTrain) {
    const sorted = [...all].sort(
      (a, b) => Date.parse(a.AdvertisedTimeAtLocation) - Date.parse(b.AdvertisedTimeAtLocation) || (a.ActivityType === 'Ankomst' ? -1 : 1) - (b.ActivityType === 'Ankomst' ? -1 : 1),
    );
    const advertised = sorted.filter((a) => a.Advertised);
    if (!advertised.length) continue;

    // Run-wide fields: present at every announced stop with the same value.
    const info: Record<string, unknown> = {};
    const keys = new Set(advertised.flatMap((a) => Object.keys(a)));
    for (const k of keys) {
      if (CALL_FIELDS.has(k) || RAW_ONLY.has(k)) continue;
      const first = JSON.stringify(advertised[0]![k]);
      if (advertised.every((a) => k in a && JSON.stringify(a[k]) === first)) info[k] = advertised[0]![k];
    }
    // The railway's ids for this train, its path and its company (TAF/TAP). They can differ along the route (a train
    // that changes number), so every distinct one is kept, once for the run rather than at each stop.
    const ids = new Map<string, unknown>();
    for (const a of sorted) for (const id of (a.OperationalTransportIdentifiers as unknown[] | undefined) ?? []) ids.set(JSON.stringify(id), id);
    if (ids.size) info.OperationalTransportIdentifiers = [...ids.values()];
    const rest = (a: Announcement | undefined) => {
      if (!a) return undefined;
      const o: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(a)) if (!CALL_FIELDS.has(k) && !RAW_ONLY.has(k) && !(k in info)) o[k] = v;
      return o;
    };

    // Stops: an arrival opens one; the departure from the same place right after it joins it.
    const pairs: { arr?: Announcement; dep?: Announcement }[] = [];
    for (const a of advertised) {
      const cur = pairs.at(-1);
      if (a.ActivityType === 'Avgang' && cur && !cur.dep && cur.arr?.LocationSignature === a.LocationSignature) cur.dep = a;
      else pairs.push(a.ActivityType === 'Ankomst' ? { arr: a } : { dep: a });
    }
    const calls: ObservedCall[] = pairs.map((p, i) => {
      const any = (p.arr ?? p.dep)!;
      const extra: Record<string, unknown> = {};
      const ea = rest(p.arr);
      const ed = rest(p.dep);
      if (ea && Object.keys(ea).length) extra.a = ea;
      if (ed && Object.keys(ed).length) extra.d = ed;
      return {
        seq: i + 1,
        location: any.LocationSignature,
        stationId: stationBySig.get(any.LocationSignature) ?? null,
        schedArr: p.arr ? ms(p.arr.AdvertisedTimeAtLocation) : null,
        schedDep: p.dep ? ms(p.dep.AdvertisedTimeAtLocation) : null,
        estArr: p.arr ? ms(p.arr.EstimatedTimeAtLocation) : null,
        estDep: p.dep ? ms(p.dep.EstimatedTimeAtLocation) : null,
        actualArr: p.arr ? actual(p.arr) : null,
        actualDep: p.dep ? actual(p.dep) : null,
        platform: track(p.dep) ?? track(p.arr),
        canceledArr: Boolean(p.arr?.Canceled),
        canceledDep: Boolean(p.dep?.Canceled),
        causes: causesOf([p.arr, p.dep]),
        extra,
      };
    });
    const passages: Passage[] = sorted
      .filter((a) => !a.Advertised)
      .map((a) => passage(a.LocationSignature, a.ActivityType === 'Ankomst' ? 'A' : 'D', Date.parse(a.AdvertisedTimeAtLocation), actual(a)));
    runs.push({
      country: 'SE',
      serviceDate: date,
      runId: ident,
      trainNumber: ident,
      source: SOURCE,
      operator: (info.Operator as string | undefined) ?? (advertised.find((a) => a.Operator)?.Operator ?? null),
      product: productOf((info.ProductInformation as Announcement['ProductInformation']) ?? advertised.find((a) => a.ProductInformation)?.ProductInformation),
      canceled: cancelLevel(calls, advertised.every((a) => a.Canceled)),
      info,
      passages,
      calls,
      final,
    });
  }
  return runs;
}

export function stationsBySignature(db: Db): Map<string, string> {
  const rows = db.$client.prepare(`select id, trv_signature from stations where trv_signature is not null`).all() as { id: string; trv_signature: string }[];
  return new Map(rows.map((r) => [r.trv_signature, r.id]));
}

/** Fetch, archive and project one service day. */
export async function collectDay(db: Db, date: string, opts: { now?: number; fetchImpl?: typeof fetch; log?: (m: string) => void } = {}) {
  const now = opts.now ?? Date.now();
  const final = date <= addDays(todayIn(TZ, now), -FINAL_AFTER_DAYS);
  const t0 = Date.now();
  const rows = await fetchDay(date, opts);
  // Nothing back means Trafikverket no longer (or not yet) has the day, not that no train ran: don't call it done.
  if (!rows.length) {
    opts.log?.(`observed SE ${date}: Trafikverket has nothing for this day`);
    return { records: 0, runs: 0 };
  }
  const file = writeRaw(SOURCE, date, 'announcements', rows, { now });
  const runs = project(date, rows, stationsBySignature(db), final);
  const written = saveRuns(db, runs, now);
  recordFetch(db, { source: SOURCE, kind: 'announcements', date, records: rows.length, runs: written, file, final }, now);
  opts.log?.(`observed SE ${date}: ${rows.length} announcements, ${runs.length} trains${final ? ' (final)' : ''} in ${Math.round((Date.now() - t0) / 1000)} s`);
  return { records: rows.length, runs: runs.length };
}

/** Incidents, reason-coded events and platform-sign messages changed on `date` (Stockholm day), kept as sent. */
export async function collectEvents(db: Db, date: string, opts: { now?: number; fetchImpl?: typeof fetch; log?: (m: string) => void } = {}) {
  const now = opts.now ?? Date.now();
  const [y, m, d] = date.split('-').map(Number) as [number, number, number];
  const from = iso(zonedToUtc(y, m, d, 0, 0, 0, TZ));
  const to = iso(zonedToUtc(y, m, d + 1, 0, 0, 0, TZ));
  const kinds: [kind: string, objecttype: string, ns: string, version: string][] = [
    ['operative-events', 'OperativeEvent', 'ols.open', '1.0'],
    ['railway-events', 'RailwayEvent', 'ols.open', '1.0'],
    ['station-messages', 'TrainStationMessage', '', '1.0'],
  ];
  for (const [kind, obj, ns, ver] of kinds) {
    const q = `<QUERY objecttype="${obj}"${ns ? ` namespace="${ns}"` : ''} schemaversion="${ver}"><FILTER><AND><GTE name="ModifiedTime" value="${from}"/><LT name="ModifiedTime" value="${to}"/></AND></FILTER></QUERY>`;
    const rows = ((await trvQuery<Record<string, unknown[]>>(q, opts.fetchImpl))[obj] ?? []) as unknown[];
    const file = writeRaw(SOURCE, date, kind, rows, { now });
    recordFetch(db, { source: SOURCE, kind, date, records: rows.length, file, final: true }, now);
    opts.log?.(`observed SE ${date}: ${rows.length} ${kind}`);
  }
}

/** Trafikverket's code list (deviation, product and reason codes with their descriptions), kept weekly. */
export async function collectReasonCodes(db: Db, opts: { now?: number; fetchImpl?: typeof fetch } = {}) {
  const now = opts.now ?? Date.now();
  const rows = ((await trvQuery<{ ReasonCode?: unknown[] }>(`<QUERY objecttype="ReasonCode" schemaversion="1"><FILTER/></QUERY>`, opts.fetchImpl)).ReasonCode ?? []) as unknown[];
  const date = todayIn(TZ, now);
  const file = writeRaw(SOURCE, date, 'reason-codes', rows, { now });
  recordFetch(db, { source: SOURCE, kind: 'reason-codes', date, records: rows.length, file, final: true }, now);
}

/**
 * The nightly round: yesterday, plus every day back to `FINAL_AFTER_DAYS + 1` that isn't final yet (Trafikverket still
 * has ~4 days, so the first run fills those too), and yesterday's events.
 */
export async function runSweden(db: Db, opts: { now?: number; fetchImpl?: typeof fetch; log?: (m: string) => void } = {}) {
  const now = opts.now ?? Date.now();
  const today = todayIn(TZ, now);
  for (let back = FINAL_AFTER_DAYS + 1; back >= 1; back--) {
    const date = addDays(today, -back);
    if (fetchOf(db, SOURCE, 'announcements', date)?.final) continue;
    try {
      await collectDay(db, date, opts);
    } catch (e) {
      opts.log?.(`observed SE ${date} failed: ${(e as Error).message}`);
    }
    if (!fetchOf(db, SOURCE, 'operative-events', date))
      await collectEvents(db, date, opts).catch((e) => opts.log?.(`observed SE events ${date} failed: ${(e as Error).message}`));
  }
}
