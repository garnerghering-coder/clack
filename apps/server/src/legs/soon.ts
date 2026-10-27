// Trains leaving soon, for the first screen (owner, 2026-10-25: "in the first 60 seconds we want the user adding a
// journey"): real trains from the stations near you (or the big hubs), leaving in the next hour, one per destination,
// long-distance and regional before commuter. Each is a whole run from that station to the train's last stop, ready
// for POST /legs. Nothing is invented: these are timetable trips.
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { COUNTRIES, COUNTRY_CODES } from '../lib/countries.js';
import { serviceTimeToUtc, todayIn } from '../lib/time.js';

export interface SoonTrain {
  tripKey: string;
  serviceDate: string;
  fromSeq: number;
  toSeq: number;
  trainNumber: string | null;
  operatorId: string | null;
  category: string;
  from: { id: string; name: string };
  to: { id: string; name: string };
  /** Epoch ms (timetable). */
  dep: number;
  arr: number;
}

interface Hub { id: string; name: string; lat: number; lon: number }

let hubCache: { at: number; hubs: Hub[] } | null = null;

/** The busiest stations by long-distance and regional trains, a few per country (cached for an hour). */
function hubs(db: Db, now: number): Hub[] {
  if (hubCache && now - hubCache.at < 3600_000) return hubCache.hubs;
  // Ranked within each country, so one country's timetable (Denmark's has years of history) can't crowd out the others.
  const picked = db.all<Hub & { country: string; n: number }>(sql`
    select id, name, lat, lon, country, n from (
      select s.id, s.name, s.lat, s.lon, s.country, count(*) as n,
             row_number() over (partition by s.country order by count(*) desc) as rk
      from stations s
      join timetable_stop_times st on st.station_id = s.id
      join timetable_trips t on t.key = st.trip_key and t.category <> 'commuter'
      where s.kind = 'rail_station' and s.country in (${sql.join(COUNTRY_CODES.map((c) => sql`${c}`), sql`, `)})
      group by s.id)
    where rk <= 3
    order by n desc`);
  // Sweden first (the app's home), then the others in COUNTRIES order.
  const order: string[] = COUNTRY_CODES;
  picked.sort((a, b) => order.indexOf(a.country) - order.indexOf(b.country));
  hubCache = { at: now, hubs: picked };
  return picked;
}

/** The rail stations nearest a point (straight-line, within 60 km). */
function nearest(db: Db, lat: number, lon: number, count: number): Hub[] {
  const rows = db.all<Hub>(sql`
    select id, name, lat, lon from stations
    where kind = 'rail_station' and lat between ${lat - 0.6} and ${lat + 0.6} and lon between ${lon - 1.2} and ${lon + 1.2}`);
  const km = (h: Hub) => Math.hypot((h.lat - lat) * 111, (h.lon - lon) * 111 * Math.cos((lat * Math.PI) / 180));
  return rows.filter((h) => km(h) <= 60).sort((a, b) => km(a) - km(b)).slice(0, count);
}

export function trainsSoon(db: Db, opts: { lat?: number; lon?: number; now?: number; limit?: number } = {}): SoonTrain[] {
  const now = opts.now ?? Date.now();
  const limit = opts.limit ?? 5;
  const near = opts.lat != null && opts.lon != null ? nearest(db, opts.lat, opts.lon, 4) : [];
  const stations = near.length ? near : hubs(db, now);
  if (!stations.length) return [];
  const ids = stations.map((s) => s.id);
  const out: (SoonTrain & { rank: number })[] = [];
  for (const tz of [...new Set(Object.values(COUNTRIES).map((c) => c.tz))]) {
    const date = todayIn(tz, now);
    const base = serviceTimeToUtc(date, 0, tz);
    const from = Math.floor((now + 10 * 60_000 - base) / 1000);
    const to = Math.floor((now + 60 * 60_000 - base) / 1000);
    const rows = db.all<{
      key: string; seq: number; dep_sec: number; station_id: string; from_name: string; train_number: string | null;
      operator_id: string | null; category: string; last_seq: number; last_station: string; last_name: string; last_arr: number;
    }>(sql`
      select t.key, st.seq, st.dep_sec, st.station_id, fs.name as from_name, t.train_number, t.operator_id, t.category,
             l.seq as last_seq, l.station_id as last_station, ls.name as last_name, l.arr_sec as last_arr
      from timetable_stop_times st
      join timetable_trips t on t.key = st.trip_key and t.tz = ${tz}
      join timetable_trip_dates d on d.trip_key = t.key and d.service_date = ${date}
      join stations fs on fs.id = st.station_id
      join timetable_stop_times l on l.trip_key = t.key and l.seq = (select max(seq) from timetable_stop_times where trip_key = t.key)
      join stations ls on ls.id = l.station_id
      where st.station_id in (${sql.join(ids.map((i) => sql`${i}`), sql`, `)})
        and st.no_pickup = 0 and st.dep_sec between ${from} and ${to} and l.seq > st.seq
      order by st.dep_sec
      limit 200`);
    for (const r of rows) {
      // A ride worth logging: at least 20 minutes to the train's last stop.
      if ((r.last_arr ?? 0) - r.dep_sec < 20 * 60) continue;
      out.push({
        tripKey: r.key, serviceDate: date, fromSeq: r.seq, toSeq: r.last_seq, trainNumber: r.train_number, operatorId: r.operator_id,
        category: r.category, from: { id: r.station_id, name: r.from_name }, to: { id: r.last_station, name: r.last_name },
        dep: serviceTimeToUtc(date, r.dep_sec, tz), arr: serviceTimeToUtc(date, r.last_arr ?? r.dep_sec, tz),
        rank: r.category === 'commuter' ? 1 : 0,
      });
    }
  }
  // Long-distance and regional first; from the hubs, Sweden's before the others; then the soonest. One per destination.
  const hubOrder = new Map(stations.map((s, i) => [s.id, near.length ? 0 : Math.floor(i / 3)]));
  out.sort((a, b) => a.rank - b.rank || (hubOrder.get(a.from.id) ?? 9) - (hubOrder.get(b.from.id) ?? 9) || a.dep - b.dep);
  const seen = new Set<string>();
  const picked: SoonTrain[] = [];
  for (const { rank, ...t } of out) {
    void rank;
    if (seen.has(t.to.id)) continue;
    seen.add(t.to.id);
    picked.push(t);
    if (picked.length >= limit) break;
  }
  return near.length ? picked.sort((a, b) => a.dep - b.dep) : picked;
}
