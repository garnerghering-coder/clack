// Replacement buses that Sweden's timetable files as trains (DATA_FINDINGS §5). GTFS can't always tell: a bus that
// only calls at railway stations, under its own number, looks like a train. Trafikverket says (TypeOfTraffic "Buss")
// for the days it has announcements (yesterday to about two weeks ahead), so after each import those trips are taken
// off the dates Trafikverket runs them as buses. Older and later dates rely on the category rules.
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { trvQuery } from '../trafikverket/client.js';
import { addDays, todayIn } from '../lib/time.js';

interface BusRow {
  AdvertisedTrainIdent: string;
  LocationSignature: string;
  AdvertisedTimeAtLocation: string;
}

const localDate = (iso: string) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Stockholm' }).format(new Date(iso));

/** Buses per (number, local date): the stations they call at. Pure. */
export function busesByDay(rows: BusRow[]): Map<string, Set<string>> {
  const out = new Map<string, Set<string>>();
  for (const r of rows) {
    const k = `${r.AdvertisedTrainIdent}|${localDate(r.AdvertisedTimeAtLocation)}`;
    (out.get(k) ?? out.set(k, new Set()).get(k)!).add(r.LocationSignature.toLowerCase());
  }
  return out;
}

/**
 * Removes Swedish timetable trips from the dates Trafikverket runs them as buses: same number on the same day, and
 * at least two of the trip's stations among the bus's (so a train sharing a number with a bus elsewhere stays).
 * Returns how many trip-dates were removed.
 */
export async function dropTrafikverketBuses(db: Db, opts: { now?: number; fetchImpl?: typeof fetch; log?: (m: string) => void } = {}): Promise<number> {
  const today = todayIn('Europe/Stockholm', opts.now);
  const [from, to] = [addDays(today, -1), addDays(today, 15)];
  const r = await trvQuery<{ TrainAnnouncement?: BusRow[] }>(
    `<QUERY objecttype="TrainAnnouncement" schemaversion="1.9"><FILTER><EQ name="TypeOfTraffic.Description" value="Buss"/>` +
      `<GTE name="AdvertisedTimeAtLocation" value="${from}T00:00:00"/><LT name="AdvertisedTimeAtLocation" value="${to}T00:00:00"/></FILTER>` +
      `<INCLUDE>AdvertisedTrainIdent</INCLUDE><INCLUDE>LocationSignature</INCLUDE><INCLUDE>AdvertisedTimeAtLocation</INCLUDE></QUERY>`,
    opts.fetchImpl,
  );
  const buses = busesByDay(r.TrainAnnouncement ?? []);
  if (!buses.size) return 0;
  const numbers = [...new Set([...buses.keys()].map((k) => k.split('|')[0]!))];
  const candidates = db.all<{ key: string; train_number: string; service_date: string }>(sql`
    select t.key, t.train_number, d.service_date from timetable_trips t join timetable_trip_dates d on d.trip_key = t.key
    where t.source in ('gtfs_se3', 'gtfs_sv2') and d.service_date >= ${from} and d.service_date < ${to}
      and t.train_number in (${sql.join(numbers.map((n) => sql`${n}`), sql`, `)})`);
  const sigsOf = new Map<string, string[]>();
  const drop = db.$client.prepare(`delete from timetable_trip_dates where trip_key = ? and service_date = ?`);
  let removed = 0;
  db.transaction(() => {
    for (const c of candidates) {
      const bus = buses.get(`${c.train_number}|${c.service_date}`);
      if (!bus) continue;
      const sigs =
        sigsOf.get(c.key) ??
        sigsOf
          .set(
            c.key,
            db
              .all<{ sig: string | null }>(sql`select s.trv_signature as sig from timetable_stop_times st join stations s on s.id = st.station_id where st.trip_key = ${c.key}`)
              .map((x) => x.sig?.toLowerCase())
              .filter((x): x is string => !!x),
          )
          .get(c.key)!;
      if (sigs.filter((s) => bus.has(s)).length >= Math.min(2, sigs.length)) removed += drop.run(c.key, c.service_date).changes;
    }
  });
  if (removed) opts.log?.(`Replacement buses: ${removed} trip-dates that Trafikverket runs as buses taken out of the timetable`);
  return removed;
}
