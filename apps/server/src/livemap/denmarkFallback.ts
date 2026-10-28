// Danish trains for the map while Rejseplanen is unavailable (resting, blocked or switched off): placed from the
// European Train Archive's latest 15-minute file of Rejseplanen's live feed (train-archive.eu, permission by phone
// 2026-10-27). The file appears about 20 minutes after its window, so its predictions are 20–35 minutes old; each
// train is put on the track between its last and next stop by those predicted times, and drawn as estimated.
// At most one file every 5 minutes, only while the map is open and Rejseplanen is not answering.
import zlib from 'node:zlib';
import { parquetReadObjects } from 'hyparquet';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { danishStationId, uicOf } from '../import/gtfs-dk.js';
import { segmentBetween, type StationPoint } from '../geo/trackSegments.js';
import type { RailGraph } from '../geo/railGraph.js';
import { cumulative, pointAt } from '../live/progress.js';
import type { DenmarkTrain } from './denmark.js';
import { productOf, type Product } from '../search/timetable.js';

const TZ = 'Europe/Copenhagen';
const REFRESH_MS = 5 * 60_000;

interface Update { tripId: string; date: string; fetched: number; stops: { stopId: string; arr: number | null; dep: number | null }[] }
interface RawStu { stopId?: string; arrival?: { time?: number | bigint | null } | null; departure?: { time?: number | bigint | null } | null; scheduleRelationship?: unknown }
interface RawRow { trip_tripId?: string; trip_startDate?: string | null; fetchTime?: string | Date; stopTimeUpdate?: RawStu[] | null; trip_scheduleRelationship?: unknown }

const sec = (t: number | bigint | null | undefined) => (t === null || t === undefined ? null : Number(t) * 1000);

/** "HH-MM-00" windows of today, newest first, that should exist by now (each appears ~20 min after it ends). Pure. */
export function recentWindows(now: number): { date: string; name: string }[] {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
      .formatToParts(now)
      .map((x) => [x.type, x.value]),
  );
  const date = `${p.year}-${p.month}-${p.day}`;
  const f = (m: number) => `${String(Math.floor(m / 60)).padStart(2, '0')}-${String(m % 60).padStart(2, '0')}-00`;
  const latestEnd = Math.floor((Number(p.hour) * 60 + Number(p.minute) - 20) / 15) * 15;
  const out = [];
  for (let end = latestEnd; end >= 15 && out.length < 3; end -= 15) out.push({ date, name: `${f(end - 15)}_to_${f(end)}` });
  return out;
}

/** The newest update of each trip in a file's rows. Pure. */
export function latestUpdates(rows: RawRow[]): Map<string, Update> {
  const out = new Map<string, Update>();
  for (const r of rows) {
    if (!r.trip_tripId || !r.stopTimeUpdate?.length) continue;
    const fetched = r.fetchTime instanceof Date ? r.fetchTime.getTime() : Date.parse(String(r.fetchTime ?? ''));
    const have = out.get(r.trip_tripId);
    if (have && have.fetched >= fetched) continue;
    out.set(r.trip_tripId, {
      tripId: r.trip_tripId,
      date: /^\d{8}$/.test(r.trip_startDate ?? '') ? `${r.trip_startDate!.slice(0, 4)}-${r.trip_startDate!.slice(4, 6)}-${r.trip_startDate!.slice(6, 8)}` : '',
      fetched,
      stops: r.stopTimeUpdate.filter((s) => s.stopId).map((s) => ({ stopId: s.stopId!, arr: sec(s.arrival?.time), dep: sec(s.departure?.time) })),
    });
  }
  return out;
}

export class DenmarkArchiveFallback {
  private updates = new Map<string, Update>();
  private fetchedAt = 0;
  private trips = new Map<string, { key: string; number: string | null; operatorId: string | null; product: Product }>();
  private points = new Map<string, (StationPoint & { name: string }) | null>();
  upstreamAt = 0;

  constructor(
    private readonly db: Db,
    private readonly opts: { fetchImpl?: typeof fetch; now?: () => number; graph?: () => RailGraph | null } = {},
  ) {}

  private now() {
    return (this.opts.now ?? Date.now)();
  }

  async refresh(): Promise<void> {
    const token = process.env.TRAIN_ARCHIVE_TOKEN;
    const now = this.now();
    if (!token || now - this.fetchedAt < REFRESH_MS) return;
    this.fetchedAt = now;
    const fetchImpl = this.opts.fetchImpl ?? fetch;
    for (const w of recentWindows(now)) {
      const r = await fetchImpl(`https://data.train-archive.eu/provider=dk-rejseplanen/service=TripUpdate/date=${w.date}/${w.name}.parquet`, {
        headers: { 'X-Api-Key': token },
        signal: AbortSignal.timeout(60_000),
      });
      if (r.status === 404) continue;
      if (!r.ok) throw new Error(`train-archive.eu ${w.name}: HTTP ${r.status}`);
      const rows = (await parquetReadObjects({
        file: await r.arrayBuffer(),
        columns: ['trip_tripId', 'trip_startDate', 'fetchTime', 'stopTimeUpdate'],
        compressors: { BROTLI: (input: Uint8Array) => new Uint8Array(zlib.brotliDecompressSync(input)) },
      })) as RawRow[];
      this.updates = latestUpdates(rows);
      this.loadTrips([...this.updates.keys()]);
      this.upstreamAt = now;
      return;
    }
  }

  /** The Danish timetable's trips for these GTFS trip ids (indexed on source and trip id), in batches. */
  private loadTrips(ids: string[]) {
    const missing = ids.filter((id) => !this.trips.has(id));
    for (let i = 0; i < missing.length; i += 500) {
      const list = sql.join(missing.slice(i, i + 500).map((id) => sql`${id}`), sql`, `);
      for (const r of this.db.all<{ trip_id: string; key: string; train_number: string | null; operator_id: string | null; route_type: string; category: string }>(sql`
        select trip_id, key, train_number, operator_id, route_type, category from timetable_trips where source = 'gtfs_dk' and trip_id in (${list})`))
        this.trips.set(r.trip_id, { key: r.key, number: r.train_number, operatorId: r.operator_id, product: productOf(r.route_type, r.category) });
    }
    if (this.trips.size > 50_000) this.trips.clear();
  }

  private point(stopId: string) {
    if (!this.points.has(stopId)) {
      const uic = uicOf(stopId);
      const id = uic ? (uic.startsWith('86') ? danishStationId(uic) : `uic:${uic}`) : null;
      const s = id ? this.db.all<{ id: string; lat: number; lon: number; name: string }>(sql`select id, lat, lon, name from stations where id = ${id}`)[0] : undefined;
      this.points.set(stopId, s ?? null);
    }
    return this.points.get(stopId)!;
  }

  trains(): DenmarkTrain[] {
    const now = this.now();
    const graph = this.opts.graph?.() ?? null;
    const out: DenmarkTrain[] = [];
    if (!this.upstreamAt || now - this.upstreamAt > 60 * 60_000) return out;
    for (const u of this.updates.values()) {
      const trip = this.trips.get(u.tripId);
      if (!trip?.number || !u.date) continue;
      const times = u.stops.map((s) => ({ ...s, at: s.dep ?? s.arr }));
      const i = times.findIndex((s) => (s.arr ?? s.dep ?? 0) > now);
      // Not running now: not started yet, or finished.
      if (i <= 0 || (times[0]!.dep ?? 0) > now) continue;
      const prev = this.point(times[i - 1]!.stopId);
      const next = this.point(times[i]!.stopId);
      if (!prev || !next) continue;
      const left = times[i - 1]!.dep ?? times[i - 1]!.arr!;
      const arriving = times[i]!.arr ?? times[i]!.dep!;
      let pos = { lat: prev.lat, lon: prev.lon, bearing: null as number | null };
      if (now >= left) {
        const seg = segmentBetween(this.db, prev, next, graph);
        const cum = cumulative(seg.points);
        const f = Math.min(0.95, Math.max(0, (now - left) / Math.max(1, arriving - left)));
        const pt = pointAt(seg.points, cum, f * cum.at(-1)!);
        pos = { lat: pt.lat, lon: pt.lon, bearing: Math.round(pt.bearing) };
      }
      const first = this.point(times[0]!.stopId);
      const last = this.point(times.at(-1)!.stopId);
      out.push({
        ref: `tt.${trip.key}`,
        jid: null,
        number: trip.number,
        date: u.date,
        lat: pos.lat,
        lon: pos.lon,
        bearing: pos.bearing,
        at: this.upstreamAt,
        operatorId: trip.operatorId,
        productName: null,
        product: trip.product,
        origin: first?.name ?? null,
        destination: last?.name ?? null,
        next: next.name,
        prev: prev.name,
        nextEta: arriving,
        delayMin: null,
        tripKey: trip.key,
        inDanishTimetable: true,
      });
    }
    return out;
  }
}
