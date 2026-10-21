// Creating, listing and deleting legs (SPEC §7, §9 step 4). A leg keeps the whole trip's stops, marked by role, so the
// timeline can show the full route, and is never dependent on the timetable afterwards (history is permanent).
import crypto from 'node:crypto';
import { and, asc, desc, eq, sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { legStops, legs, operators, stations } from '../db/schema.js';
import { haversineM } from '../lib/geo.js';
import { tripStops, type TripStop } from '../search/timetable.js';
import { attachLegGeometry } from '../geo/trackSegments.js';
import { withLogo } from '../import/brands.js';
import { liveFor, liveForMany } from '../live/tracker.js';

export type StopRole = 'before' | 'board' | 'through' | 'alight' | 'after';

export class LegError extends Error {
  constructor(
    message: string,
    public status: number,
    public body: Record<string, unknown> = {},
  ) {
    super(message);
  }
}

export function roleOf(seq: number, boardSeq: number, alightSeq: number): StopRole {
  if (seq < boardSeq) return 'before';
  if (seq === boardSeq) return 'board';
  if (seq < alightSeq) return 'through';
  if (seq === alightSeq) return 'alight';
  return 'after';
}

/** Straight-line distance along the ridden stops; the fallback until the leg is routed on the rail network. */
export function straightLineDistanceM(stops: Pick<TripStop, 'lat' | 'lon'>[]): number {
  let d = 0;
  for (let i = 1; i < stops.length; i++) d += haversineM(stops[i - 1]!.lat, stops[i - 1]!.lon, stops[i]!.lat, stops[i]!.lon);
  return d;
}

export interface CreateLegInput {
  tripKey: string;
  serviceDate: string;
  fromSeq: number;
  toSeq: number;
  /** Save even if the same train is already logged on that date. */
  force?: boolean;
}

export function createLeg(db: Db, userId: string, input: CreateLegInput, now = Date.now()): string {
  const found = tripStops(db, input.tripKey, input.serviceDate);
  if (!found) throw new LegError('That train is not in the timetable for that date', 404);
  const { trip, stops } = found;
  const board = stops.find((s) => s.seq === input.fromSeq);
  const alight = stops.find((s) => s.seq === input.toSeq);
  if (!board || !alight || board.seq >= alight.seq) throw new LegError('Choose where you got on before where you got off', 400);
  if (board.noPickup) throw new LegError(`The train doesn't take passengers at ${board.name}`, 400);
  if (alight.noDropoff) throw new LegError(`The train doesn't let passengers off at ${alight.name}`, 400);

  if (!input.force && trip.train_number) {
    const dup = db
      .select({ id: legs.id })
      .from(legs)
      .where(and(eq(legs.userId, userId), eq(legs.trainNumber, trip.train_number), eq(legs.serviceDate, input.serviceDate)))
      .get();
    if (dup) throw new LegError('You already added this train on this date', 409, { duplicateOf: dup.id });
  }

  const ridden = stops.filter((s) => s.seq >= board.seq && s.seq <= alight.seq);
  const schedDep = board.dep ?? board.arr;
  const schedArr = alight.arr ?? alight.dep;
  const id = crypto.randomUUID();
  db.transaction((tx) => {
    tx.insert(legs)
      .values({
        id,
        userId,
        status: schedArr !== null && schedArr < now ? 'completed' : 'planned',
        // Until actual times are attached (step 5), all we know is the timetable.
        dataQuality: 'scheduled_only',
        countryCodes: [...new Set(ridden.map((s) => s.country))],
        operatorId: trip.operator_id,
        trainNumber: trip.train_number,
        category: trip.category,
        timetableTripKey: trip.key,
        serviceDate: input.serviceDate,
        originStationId: board.stationId,
        destStationId: alight.stationId,
        schedDep: schedDep === null ? null : new Date(schedDep),
        schedArr: schedArr === null ? null : new Date(schedArr),
        distanceM: straightLineDistanceM(ridden),
        isEstimatedGeometry: true,
        createdAt: new Date(now),
      })
      .run();
    for (const s of stops) {
      const role = roleOf(s.seq, board.seq, alight.seq);
      tx.insert(legStops)
        .values({
          legId: id,
          seq: s.seq,
          stationId: s.stationId,
          schedArr: s.arr === null ? null : new Date(s.arr),
          schedDep: s.dep === null ? null : new Date(s.dep),
          passedThrough: role === 'through',
          role,
        })
        .run();
    }
  });
  // Track geometry and distance along the rail network (cached per station pair, so this is quick).
  attachLegGeometry(db, id);
  return id;
}

const legColumns = {
  id: legs.id,
  status: legs.status,
  dataQuality: legs.dataQuality,
  trainNumber: legs.trainNumber,
  category: legs.category,
  serviceDate: legs.serviceDate,
  schedDep: legs.schedDep,
  schedArr: legs.schedArr,
  actualDep: legs.actualDep,
  actualArr: legs.actualArr,
  depDelayMin: legs.depDelayMin,
  arrDelayMin: legs.arrDelayMin,
  depPlatform: legs.depPlatform,
  arrPlatform: legs.arrPlatform,
  canceled: legs.canceled,
  distanceM: legs.distanceM,
  isEstimatedGeometry: legs.isEstimatedGeometry,
  countryCodes: legs.countryCodes,
  operatorId: legs.operatorId,
  originStationId: legs.originStationId,
  destStationId: legs.destStationId,
  notes: legs.notes,
};

function attachRefs<T extends { operatorId: string | null; originStationId: string; destStationId: string }>(db: Db, rows: T[]) {
  const ops = new Map(db.select().from(operators).all().map((o) => [o.id, o]));
  const ids = [...new Set(rows.flatMap((r) => [r.originStationId, r.destStationId]))];
  const st = new Map(
    ids.length
      ? db
          .select({ id: stations.id, name: stations.name, code: stations.trvSignature, country: stations.country, tz: stations.tz })
          .from(stations)
          .where(sql`${stations.id} in (${sql.join(ids.map((i) => sql`${i}`), sql`, `)})`)
          .all()
          .map((s) => [s.id, s])
      : [],
  );
  return rows.map((r) => ({
    ...r,
    operator: r.operatorId && ops.get(r.operatorId) ? withLogo(ops.get(r.operatorId)!) : null,
    origin: st.get(r.originStationId) ?? null,
    destination: st.get(r.destStationId) ?? null,
  }));
}

export function listLegs(db: Db, userId: string) {
  const rows = db.select(legColumns).from(legs).where(eq(legs.userId, userId)).orderBy(desc(legs.schedDep)).all();
  const live = liveForMany(db, rows.map((r) => r.id));
  return attachRefs(db, rows).map((r) => ({ ...r, live: live.get(r.id) ?? null }));
}

export function getLeg(db: Db, userId: string, id: string) {
  const row = db.select(legColumns).from(legs).where(and(eq(legs.userId, userId), eq(legs.id, id))).get();
  if (!row) return null;
  const [leg] = attachRefs(db, [row]);
  const geometry = db.select({ g: legs.geometry }).from(legs).where(eq(legs.id, id)).get()?.g ?? null;
  const stops = db
    .select({
      seq: legStops.seq,
      role: legStops.role,
      stationId: legStops.stationId,
      name: stations.name,
      code: stations.trvSignature,
      country: stations.country,
      tz: stations.tz,
      lat: stations.lat,
      lon: stations.lon,
      schedArr: legStops.schedArr,
      schedDep: legStops.schedDep,
      actualArr: legStops.actualArr,
      actualDep: legStops.actualDep,
      estimatedArr: legStops.estimatedArr,
      estimatedDep: legStops.estimatedDep,
      platform: legStops.platform,
      canceled: legStops.canceled,
      deviations: legStops.deviations,
    })
    .from(legStops)
    .innerJoin(stations, eq(stations.id, legStops.stationId))
    .where(eq(legStops.legId, id))
    .orderBy(asc(legStops.seq))
    .all();
  return { ...leg!, geometry, stops, ...liveFor(db, id) };
}

export function deleteLeg(db: Db, userId: string, id: string): boolean {
  return db.delete(legs).where(and(eq(legs.userId, userId), eq(legs.id, id))).run().changes > 0;
}
