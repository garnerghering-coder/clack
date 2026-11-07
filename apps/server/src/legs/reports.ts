// "This is wrong" reports from a trip page (owner, 2026-11-07). A report is the traveller's word against the data: it
// changes nothing on the trip, it is kept for the owner to check against the record (tools/legReports.ts). Each one
// holds what the phone showed (as sent) and what the server held for the leg at that moment, so the two can be told
// apart later even after the leg has been refreshed.
import crypto from 'node:crypto';
import { and, asc, eq, gt } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { legReports, legs, legStops, shownValues } from '../db/schema.js';

export const MAX_NOTE = 500;
/** The biggest `shown` object kept, as JSON; the app sends a handful of values. */
export const MAX_SHOWN_BYTES = 8_000;
/** One report per leg per traveller in this long: a second tap isn't a second fact. */
export const REPORT_GAP_MS = 10 * 60_000;

export class ReportError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

export interface ReportInput {
  note?: unknown;
  shown?: unknown;
}

const isPlainObject = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

/** The note trimmed, null when empty; refuses anything but a string of at most MAX_NOTE characters. Pure. */
export function cleanNote(v: unknown): string | null {
  if (v === undefined || v === null) return null;
  if (typeof v !== 'string') throw new ReportError(400, 'note must be a string');
  const s = v.trim();
  if (s.length > MAX_NOTE) throw new ReportError(400, `note must be at most ${MAX_NOTE} characters`);
  return s || null;
}

/** The shown values as a plain object of modest size, null when absent. Pure. */
export function cleanShown(v: unknown): Record<string, unknown> | null {
  if (v === undefined || v === null) return null;
  if (!isPlainObject(v)) throw new ReportError(400, 'shown must be an object');
  if (JSON.stringify(v).length > MAX_SHOWN_BYTES) throw new ReportError(400, 'shown is too large');
  return v;
}

/**
 * What the server holds for the leg now: its stored times and platforms, each stop's, and the last value the tracker
 * recorded as shown per stop and field (shown_values), so the report can be read against the record later.
 */
export function serverState(db: Db, legId: string): Record<string, unknown> {
  const leg = db
    .select({
      status: legs.status,
      dataQuality: legs.dataQuality,
      trainNumber: legs.trainNumber,
      serviceDate: legs.serviceDate,
      schedDep: legs.schedDep,
      schedArr: legs.schedArr,
      actualDep: legs.actualDep,
      actualArr: legs.actualArr,
      depPlatform: legs.depPlatform,
      arrPlatform: legs.arrPlatform,
      canceled: legs.canceled,
    })
    .from(legs)
    .where(eq(legs.id, legId))
    .get();
  const stops = db
    .select({
      seq: legStops.seq,
      stationId: legStops.stationId,
      role: legStops.role,
      schedArr: legStops.schedArr,
      schedDep: legStops.schedDep,
      actualArr: legStops.actualArr,
      actualDep: legStops.actualDep,
      estimatedArr: legStops.estimatedArr,
      estimatedDep: legStops.estimatedDep,
      platform: legStops.platform,
      canceled: legStops.canceled,
      reportSource: legStops.reportSource,
    })
    .from(legStops)
    .where(eq(legStops.legId, legId))
    .orderBy(asc(legStops.seq))
    .all();
  // The last shown value per stop and field (rows come oldest first, so the last write wins).
  const lastShown: Record<string, { value: string | null; shownAt: number }> = {};
  for (const r of db.select().from(shownValues).where(eq(shownValues.legId, legId)).orderBy(asc(shownValues.shownAt)).all())
    lastShown[`${r.seq}.${r.field}`] = { value: r.value, shownAt: r.shownAt.getTime() };
  const ms = (d: Date | null | undefined) => d?.getTime() ?? null;
  return {
    leg: leg ? { ...leg, schedDep: ms(leg.schedDep), schedArr: ms(leg.schedArr), actualDep: ms(leg.actualDep), actualArr: ms(leg.actualArr) } : null,
    stops: stops.map((s) => ({ ...s, schedArr: ms(s.schedArr), schedDep: ms(s.schedDep), actualArr: ms(s.actualArr), actualDep: ms(s.actualDep), estimatedArr: ms(s.estimatedArr), estimatedDep: ms(s.estimatedDep) })),
    shownValues: lastShown,
  };
}

/**
 * File a report on a leg the caller owns (the route checks that). 429 when this traveller reported the same leg in the
 * last REPORT_GAP_MS. Returns the stored report's id and time.
 */
export function fileReport(db: Db, userId: string, legId: string, input: ReportInput, now = Date.now()): { id: string; createdAt: number } {
  const note = cleanNote(input.note);
  const shown = cleanShown(input.shown);
  const recent = db
    .select({ id: legReports.id })
    .from(legReports)
    .where(and(eq(legReports.legId, legId), eq(legReports.userId, userId), gt(legReports.createdAt, new Date(now - REPORT_GAP_MS))))
    .get();
  if (recent) throw new ReportError(429, 'already reported a few minutes ago');
  const id = crypto.randomUUID();
  db.insert(legReports).values({ id, legId, userId, createdAt: new Date(now), note, shown, serverState: serverState(db, legId) }).run();
  return { id, createdAt: now };
}
