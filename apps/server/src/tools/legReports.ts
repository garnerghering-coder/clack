// The "This is wrong" reports (legs/reports.ts), newest first, with the trip they are about: train, day, from → to,
// the note, and whether the record disagrees with what was shown where the report says which stop.
//
// Usage: npx tsx apps/server/src/tools/legReports.ts [--days=30]   (or npm run import -- leg-reports [--days=N])
import { fileURLToPath } from 'node:url';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';

export interface ReportRow {
  id: string;
  createdAt: number;
  userId: string;
  legId: string;
  trainNumber: string | null;
  serviceDate: string | null;
  from: string;
  to: string;
  note: string | null;
  shown: Record<string, unknown> | null;
  serverState: Record<string, unknown> | null;
}

/** Reports from the last `days` days (default 30), newest first. */
export function listLegReports(db: Db, opts: { days?: number; limit?: number } = {}): ReportRow[] {
  const since = Date.now() - (opts.days ?? 30) * 86400_000;
  const rows = db.all<{ id: string; created_at: number; user_id: string; leg_id: string; train_number: string | null; service_date: string | null; from_name: string; to_name: string; note: string | null; shown: string | null; server_state: string | null }>(sql`
    select r.id, r.created_at, r.user_id, r.leg_id, l.train_number, l.service_date, o.name from_name, d.name to_name, r.note, r.shown, r.server_state
    from leg_reports r join legs l on l.id = r.leg_id
    join stations o on o.id = l.origin_station_id join stations d on d.id = l.dest_station_id
    where r.created_at > ${since} order by r.created_at desc limit ${opts.limit ?? 200}`);
  const json = (s: string | null) => (s ? (JSON.parse(s) as Record<string, unknown>) : null);
  return rows.map((r) => ({ id: r.id, createdAt: r.created_at, userId: r.user_id, legId: r.leg_id, trainNumber: r.train_number, serviceDate: r.service_date, from: r.from_name, to: r.to_name, note: r.note, shown: json(r.shown), serverState: json(r.server_state) }));
}

/** One line per report, readable in a terminal: when, which trip, what was said, what the phone showed. Pure given the rows. */
export function formatReports(rows: ReportRow[]): string {
  if (!rows.length) return 'no reports';
  return rows
    .map((r) => {
      const when = new Date(r.createdAt).toISOString().slice(0, 16).replace('T', ' ');
      const trip = `${r.trainNumber ?? '?'} ${r.serviceDate ?? '?'} ${r.from} → ${r.to}`;
      const shown = r.shown ? ` shown ${JSON.stringify(r.shown)}` : '';
      return `${when}  ${trip}  leg ${r.legId}  user ${r.userId.slice(0, 8)}…${r.note ? `\n    "${r.note}"` : ''}${shown}`;
    })
    .join('\n');
}

export const legReportsText = (db: Db, opts: { days?: number } = {}) => formatReports(listLegReports(db, opts));

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const { openDb } = await import('../db/client.js');
  const { config } = await import('../env.js');
  const days = Number(process.argv.find((f) => f.startsWith('--days='))?.slice(7)) || undefined;
  console.log(legReportsText(openDb(config.databasePath), { days }));
}
