// The audit's sample (docs/RELIABILITY_PLAN.md §1): one person's trips are too few to measure accuracy by, so a
// hidden user follows a couple of real trains every hour, picked across long-distance, regional, commuter,
// Norwegian and Finnish trains. They're tracked like anyone's trip and audited the same way; nobody sees them in the app.
import { and, eq, lt, sql } from 'drizzle-orm';
import { DEFAULT_SETTINGS } from '@clack/shared';
import type { Db } from '../db/client.js';
import { legs, users } from '../db/schema.js';
import { createLeg } from '../legs/legs.js';
import { attachLegGeometry } from '../geo/trackSegments.js';
import { serviceTimeToUtc, todayIn } from '../lib/time.js';
import { COUNTRIES } from '../lib/countries.js';

export const AUDIT_USER_ID = 'audit-sample';
/** Trains added per hourly run (AUDIT_SAMPLE_PER_HOUR; 0 turns the sample off). */
export const SAMPLE_PER_HOUR = Number(process.env.AUDIT_SAMPLE_PER_HOUR ?? 2);
/** Sample trips are deleted (with their audits) after this long. */
const KEEP_MS = 8 * 86400_000;

const BUCKETS = [
  { name: 'long-distance', where: sql`t.source = 'gtfs_se3' and t.category in ('intercity', 'night')` },
  { name: 'regional', where: sql`t.source = 'gtfs_se3' and t.category = 'regional'` },
  { name: 'commuter', where: sql`t.source = 'gtfs_se3' and t.category = 'commuter' and t.route_type <> '900'` },
  { name: 'norway', where: sql`t.source = 'gtfs_no'` },
  { name: 'finland', where: sql`t.source = ${COUNTRIES.FI.timetableSource}` },
] as const;

/**
 * Trips whose first departure is 20–80 minutes away (so they're followed from before they leave), in one bucket,
 * in random order. Whole trips, first stop to last.
 */
function candidates(db: Db, bucket: (typeof BUCKETS)[number], now: number) {
  const out: { key: string; date: string; first: number; last: number }[] = [];
  for (const tz of [...new Set(Object.values(COUNTRIES).map((c) => c.tz))]) {
    const date = todayIn(tz, now);
    const base = serviceTimeToUtc(date, 0, tz);
    const from = Math.floor((now + 20 * 60_000 - base) / 1000);
    const to = Math.floor((now + 80 * 60_000 - base) / 1000);
    const rows = db.all<{ key: string; first_seq: number; last_seq: number }>(sql`
      select t.key,
             (select min(seq) from timetable_stop_times where trip_key = t.key) as first_seq,
             (select max(seq) from timetable_stop_times where trip_key = t.key) as last_seq
      from timetable_trips t
      join timetable_trip_dates d on d.trip_key = t.key and d.service_date = ${date}
      where t.tz = ${tz} and ${bucket.where}
        and (select dep_sec from timetable_stop_times where trip_key = t.key order by seq limit 1) between ${from} and ${to}
      order by random() limit 10`);
    for (const r of rows) out.push({ key: r.key, date, first: r.first_seq, last: r.last_seq });
  }
  return out.sort(() => Math.random() - 0.5);
}

/** Add this hour's sample trains, and drop old sample trips. Returns how many were added. */
export function sampleTrains(db: Db, opts: { now?: number; perHour?: number; log?: (m: string) => void } = {}): number {
  const now = opts.now ?? Date.now();
  const perHour = opts.perHour ?? SAMPLE_PER_HOUR;
  db.insert(users).values({ id: AUDIT_USER_ID, settings: DEFAULT_SETTINGS }).onConflictDoNothing().run();
  db.delete(legs)
    .where(and(eq(legs.userId, AUDIT_USER_ID), lt(legs.schedArr, new Date(now - KEEP_MS))))
    .run();
  let added = 0;
  // A different pair of kinds each hour, so a day covers them all.
  const hour = Math.floor(now / 3600_000);
  for (let i = 0; i < perHour; i++) {
    const bucket = BUCKETS[(hour * perHour + i) % BUCKETS.length]!;
    for (const c of candidates(db, bucket, now)) {
      try {
        const id = createLeg(db, AUDIT_USER_ID, { tripKey: c.key, serviceDate: c.date, fromSeq: c.first, toSeq: c.last }, now);
        // On the track like anyone's trip, so progress and GPS matching work the same.
        attachLegGeometry(db, id);
        added++;
        break;
      } catch {
        // Already sampled, or a trip that can't be saved whole (no pick-up at its first stop): try the next one.
      }
    }
  }
  if (added) opts.log?.(`accuracy audit: following ${added} sample train(s)`);
  return added;
}
