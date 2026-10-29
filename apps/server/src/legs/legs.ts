// Creating, listing and deleting legs (SPEC §7, §9 step 4). A leg keeps the whole trip's stops, marked by role, so the
// timeline can show the full route, and is never dependent on the timetable afterwards (history is permanent).
import crypto from 'node:crypto';
import { and, asc, desc, eq, sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { legStops, legs, operators, stations, timetableTrips } from '../db/schema.js';
import { haversineM } from '../lib/geo.js';
import { productOf, tripStops, type TripStop } from '../search/timetable.js';
import { typicalTrainType } from './trainTypes.js';
import { regroupJourneys } from './journeys.js';
import { attachLegGeometry } from '../geo/trackSegments.js';
import { withLogo } from '../import/brands.js';
import { liveFor, liveForMany } from '../live/tracker.js';
import { updateRides } from './recording.js';
import { parseCauses } from './causes.js';
import { comfortOf, comfortWithHistory, countryOfStops, minChangeMin, typicalLateMin } from '@clack/shared';
import { punctuality, type Punctuality } from '../stats/punctuality.js';
import { tierOf } from '../search/planner.js';
import { zonedToUtc } from '../lib/time.js';

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

/** Longest coach or seat the owner can write ("12A", "Vagn 5" is too long: the coach is just "5"). */
export const MAX_SEAT_FIELD = 8;

/**
 * A coach or seat from a request: undefined stays undefined (absent), null and a blank string clear it, anything else
 * is trimmed. Not a string, or longer than 8 characters, is a 400.
 */
export function cleanSeatField(value: unknown, name: 'coach' | 'seat'): string | null | undefined {
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (typeof value !== 'string') throw new LegError(`${name} must be text or null`, 400);
  const t = value.trim();
  if (t.length > MAX_SEAT_FIELD) throw new LegError(`${name} can be at most ${MAX_SEAT_FIELD} characters`, 400);
  return t === '' ? null : t;
}

export interface CreateLegInput {
  tripKey: string;
  serviceDate: string;
  fromSeq: number;
  toSeq: number;
  /** Save even if the same train is already logged on that date. */
  force?: boolean;
  /** Saved from one planned journey: legs with the same group stay one journey (legs/journeys.ts). */
  group?: string | null;
  /** Where you sat, optional. */
  coach?: string | null;
  seat?: string | null;
}

export function createLeg(db: Db, userId: string, input: CreateLegInput, now = Date.now()): string {
  const coach = cleanSeatField(input.coach, 'coach') ?? null;
  const seat = cleanSeatField(input.seat, 'seat') ?? null;
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
        plannedGroup: input.group ?? null,
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
        trainType: typicalTrainType(trip.operator_id, productOf(trip.route_type, trip.category), trip.train_number),
        trainTypeSource: 'typical',
        coach,
        seat,
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
  // A trip saved after it arrived is you saying you rode it; a future one waits for the evidence.
  updateRides(db, { legId: id, now });
  // Track geometry and distance along the rail network (cached per station pair, so this is quick).
  attachLegGeometry(db, id);
  regroupJourneys(db, userId);
  return id;
}

export interface ManualLegInput {
  fromStationId: string;
  toStationId: string;
  /** Local date where you got on, YYYY-MM-DD. */
  date: string;
  /** Local times, HH:MM, in each station's own time zone. An arrival before the departure is the next day. */
  dep: string;
  arr: string;
  operatorId?: string | null;
  trainNumber?: string | null;
  category?: string | null;
  coach?: string | null;
  seat?: string | null;
}

const HHMM = /^([01]\d|2[0-3]):([0-5]\d)$/;
const CATEGORIES = new Set(['high_speed', 'intercity', 'night', 'regional', 'commuter', 'heritage']);

/**
 * A trip added by hand, for a train no timetable we have can find (Norway before yesterday, a heritage run, a train
 * abroad). Only where you got on and off; the route is drawn along the rail network. Kept as "manual" data, and
 * counted as travelled once its time has passed, since you're the one saying you took it.
 */
export function createManualLeg(db: Db, userId: string, input: ManualLegInput, now = Date.now()): string {
  const coach = cleanSeatField(input.coach, 'coach') ?? null;
  const seat = cleanSeatField(input.seat, 'seat') ?? null;
  const st = (id: string) => db.select().from(stations).where(eq(stations.id, id)).get();
  const from = st(input.fromStationId);
  const to = st(input.toStationId);
  if (!from || !to) throw new LegError('Choose both stations', 400);
  if (from.id === to.id) throw new LegError('Choose two different stations', 400);
  const d = /^(\d{4})-(\d{2})-(\d{2})$/.exec(input.date ?? '');
  const dm = HHMM.exec(input.dep ?? '');
  const am = HHMM.exec(input.arr ?? '');
  if (!d || !dm || !am) throw new LegError('Date must be YYYY-MM-DD and times HH:MM', 400);
  const [y, mo, day] = [Number(d[1]), Number(d[2]), Number(d[3])];
  const dep = zonedToUtc(y, mo, day, Number(dm[1]), Number(dm[2]), 0, from.tz);
  let arr = zonedToUtc(y, mo, day, Number(am[1]), Number(am[2]), 0, to.tz);
  // Overnight: arriving "earlier" than leaving means the next day.
  while (arr <= dep) arr += 86400_000;
  if (arr - dep > 48 * 3600_000) throw new LegError('That trip is longer than two days', 400);
  if (input.operatorId && !db.select({ id: operators.id }).from(operators).where(eq(operators.id, input.operatorId)).get()) throw new LegError('Unknown operator', 400);
  const trainNumber = input.trainNumber?.trim() || null;
  if (trainNumber && !/^[\w-]{1,10}$/.test(trainNumber)) throw new LegError('Train numbers are letters and digits only', 400);
  const category = input.category && CATEGORIES.has(input.category) ? input.category : 'regional';

  const id = crypto.randomUUID();
  db.transaction((tx) => {
    tx.insert(legs)
      .values({
        id,
        userId,
        status: arr < now ? 'completed' : 'planned',
        dataQuality: 'manual',
        countryCodes: [...new Set([from.country, to.country])],
        operatorId: input.operatorId ?? null,
        trainNumber,
        category,
        timetableTripKey: null,
        serviceDate: input.date,
        originStationId: from.id,
        destStationId: to.id,
        schedDep: new Date(dep),
        schedArr: new Date(arr),
        distanceM: straightLineDistanceM([from, to]),
        isEstimatedGeometry: true,
        trainType: typicalTrainType(input.operatorId ?? null, category, trainNumber),
        trainTypeSource: 'typical',
        coach,
        seat,
        createdAt: new Date(now),
      })
      .run();
    tx.insert(legStops).values({ legId: id, seq: 1, stationId: from.id, schedArr: null, schedDep: new Date(dep), passedThrough: false, role: 'board' }).run();
    tx.insert(legStops).values({ legId: id, seq: 2, stationId: to.id, schedArr: new Date(arr), schedDep: null, passedThrough: false, role: 'alight' }).run();
  });
  updateRides(db, { legId: id, now });
  attachLegGeometry(db, id);
  regroupJourneys(db, userId);
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
  // A source's platform, else the one the owner typed (shown the same way).
  depPlatform: sql<string | null>`coalesce(${legs.depPlatform}, ${legs.userDepPlatform})`,
  arrPlatform: sql<string | null>`coalesce(${legs.arrPlatform}, ${legs.userArrPlatform})`,
  /** Whether the shown platform came from a source; only one that didn't may be typed in. */
  depPlatformFromSource: sql<boolean>`${legs.depPlatform} is not null`.mapWith(Boolean),
  arrPlatformFromSource: sql<boolean>`${legs.arrPlatform} is not null`.mapWith(Boolean),
  canceled: legs.canceled,
  distanceM: legs.distanceM,
  isEstimatedGeometry: legs.isEstimatedGeometry,
  trainType: legs.trainType,
  trainTypeSource: legs.trainTypeSource,
  onboard: legs.onboard,
  countryCodes: legs.countryCodes,
  journeyId: legs.journeyId,
  timetableTripKey: legs.timetableTripKey,
  operatorId: legs.operatorId,
  originStationId: legs.originStationId,
  destStationId: legs.destStationId,
  notes: legs.notes,
  coach: legs.coach,
  seat: legs.seat,
  ride: legs.ride,
  rideReason: legs.rideReason,
  borderEvidence: legs.borderEvidence,
};

/** How the train usually arrives at the leg's last stop (BUILDOUT O4), from the observed record; null without one. */
export function arrivalHistoryOf(db: Db, leg: { trainNumber: string | null; serviceDate: string | null; destStationId: string }): Punctuality | null {
  if (!leg.trainNumber || !leg.serviceDate) return null;
  return punctuality(db, { trainNumber: leg.trainNumber, stationId: leg.destStationId, before: leg.serviceDate });
}

function attachRefs<T extends { id: string; operatorId: string | null; originStationId: string; destStationId: string; trainNumber: string | null; serviceDate: string | null }>(db: Db, rows: T[]) {
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
  // For the change rule in the app (ClackCore ChangeRule): the country most of each leg's stops are in.
  const countries = new Map<string, (string | null)[]>();
  for (let i = 0; i < rows.length; i += 500) {
    const chunk = rows.slice(i, i + 500).map((r) => r.id);
    for (const c of db.all<{ id: string; country: string; n: number }>(sql`
      select ls.leg_id id, s.country, count(*) n from leg_stops ls join stations s on s.id = ls.station_id
      where ls.leg_id in (${sql.join(chunk.map((x) => sql`${x}`), sql`, `)}) group by ls.leg_id, s.country`))
      for (let k = 0; k < c.n; k++) (countries.get(c.id) ?? countries.set(c.id, []).get(c.id)!).push(c.country);
  }
  return rows.map((r) => ({
    ...r,
    operator: r.operatorId && ops.get(r.operatorId) ? withLogo(ops.get(r.operatorId)!) : null,
    origin: st.get(r.originStationId) ?? null,
    destination: st.get(r.destStationId) ?? null,
    arrivalHistory: arrivalHistoryOf(db, r),
    /** The change rule's tier of the station the leg starts at (hub / mid / default), and the train's country. */
    originTier: tierOf(r.originStationId),
    trainCountry: countryOfStops(countries.get(r.id) ?? []),
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
  const extra = db.select({ g: legs.geometry, userDep: legs.userDepPlatform, userArr: legs.userArrPlatform }).from(legs).where(eq(legs.id, id)).get();
  const geometry = extra?.g ?? null;
  // Where you got on and off, a stop without a reported platform shows the one you typed.
  const typed = (role: string, platform: string | null) =>
    platform ?? (role === 'board' ? extra?.userDep ?? null : role === 'alight' ? extra?.userArr ?? null : null);
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
      causes: legStops.causes,
      reportSource: legStops.reportSource,
    })
    .from(legStops)
    .innerJoin(stations, eq(stations.id, legStops.stationId))
    .where(eq(legStops.legId, id))
    .orderBy(asc(legStops.seq))
    .all();
  return { ...leg!, geometry, stops: stops.map((s) => ({ ...s, platform: typed(s.role, s.platform), causes: parseCauses(s.causes, s.deviations) })), ...liveFor(db, id) };
}

/** The owner says which train it actually was (null resets to the typical type). */
export function setTrainType(db: Db, userId: string, id: string, trainType: string | null): boolean {
  const leg = db.select({ operatorId: legs.operatorId, trainNumber: legs.trainNumber, key: legs.timetableTripKey }).from(legs).where(and(eq(legs.userId, userId), eq(legs.id, id))).get();
  if (!leg) return false;
  if (trainType === null) {
    const trip = leg.key ? db.select().from(timetableTrips).where(eq(timetableTrips.key, leg.key)).get() : undefined;
    const typical = typicalTrainType(leg.operatorId, productOf(trip?.routeType ?? '', trip?.category ?? ''), leg.trainNumber);
    db.update(legs).set({ trainType: typical, trainTypeSource: 'typical' }).where(eq(legs.id, id)).run();
  } else db.update(legs).set({ trainType, trainTypeSource: 'user' }).where(eq(legs.id, id)).run();
  return true;
}

/** The owner's coach and seat. A field left undefined is unchanged; null clears it. */
export function setCoachSeat(db: Db, userId: string, id: string, fields: { coach?: string | null; seat?: string | null }): boolean {
  const set: { coach?: string | null; seat?: string | null } = {};
  if (fields.coach !== undefined) set.coach = fields.coach;
  if (fields.seat !== undefined) set.seat = fields.seat;
  if (!Object.keys(set).length) return !!db.select({ id: legs.id }).from(legs).where(and(eq(legs.userId, userId), eq(legs.id, id))).get();
  return db.update(legs).set(set).where(and(eq(legs.userId, userId), eq(legs.id, id))).run().changes > 0;
}

/** Longest platform the owner can type ("12b", "4A"). */
export const MAX_PLATFORM = 6;

/** A typed platform from a request: undefined stays absent, null or blank clears, else trimmed text; throws when too long. */
export function cleanPlatform(value: unknown, name: 'depPlatform' | 'arrPlatform'): string | null | undefined {
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (typeof value !== 'string') throw new LegError(`${name} must be text or null`, 400);
  const v = value.trim();
  if (v.length > MAX_PLATFORM) throw new LegError(`${name} can be at most ${MAX_PLATFORM} characters`, 400);
  return v === '' ? null : v;
}

/**
 * The owner's platform for where they got on or off. Refused ('known') where a source already has one: the source
 * wins and isn't edited. False when the leg isn't theirs.
 */
export function setUserPlatforms(db: Db, userId: string, id: string, fields: { dep?: string | null; arr?: string | null }): true | false | 'known' {
  const row = db.select({ dep: legs.depPlatform, arr: legs.arrPlatform }).from(legs).where(and(eq(legs.userId, userId), eq(legs.id, id))).get();
  if (!row) return false;
  if ((fields.dep !== undefined && row.dep !== null) || (fields.arr !== undefined && row.arr !== null)) return 'known';
  const set: { userDepPlatform?: string | null; userArrPlatform?: string | null } = {};
  if (fields.dep !== undefined) set.userDepPlatform = fields.dep;
  if (fields.arr !== undefined) set.userArrPlatform = fields.arr;
  if (Object.keys(set).length) db.update(legs).set(set).where(eq(legs.id, id)).run();
  return true;
}

export function deleteLeg(db: Db, userId: string, id: string): boolean {
  const gone = db.delete(legs).where(and(eq(legs.userId, userId), eq(legs.id, id))).run().changes > 0;
  if (gone) regroupJourneys(db, userId);
  return gone;
}

/** A journey's legs in order, each with its track geometry (for the combined map). */
export function getJourney(db: Db, userId: string, journeyId: string) {
  const list = listLegs(db, userId).filter((l) => l.journeyId === journeyId);
  if (!list.length) return null;
  const geo = new Map(
    db
      .select({ id: legs.id, geometry: legs.geometry })
      .from(legs)
      .where(eq(legs.journeyId, journeyId))
      .all()
      .map((r) => [r.id, r.geometry]),
  );
  const ordered = list.sort((a, b) => (a.schedDep?.getTime() ?? 0) - (b.schedDep?.getTime() ?? 0)).map((l) => ({ ...l, geometry: geo.get(l.id) ?? null }));
  return { id: journeyId, legs: ordered, changes: journeyChanges(db, ordered) };
}

/**
 * Each change in a journey, judged by the change rule (packages/shared/src/changes.ts), the same one the planner
 * uses: the real gap with the latest times (actual, else planned plus the delay), the minimum, and how comfortable it
 * is. Risky shows when a delay eats into a change.
 */
export function journeyChanges(db: Db, list: { trainNumber?: string | null; serviceDate?: string | null; originStationId: string; destStationId: string; timetableTripKey: string | null; schedDep: Date | null; schedArr: Date | null; actualDep: Date | null; actualArr: Date | null; depDelayMin: number | null; arrDelayMin: number | null }[]) {
  const countryOf = (key: string | null) =>
    key ? countryOfStops((db.$client.prepare(`select s.country c from timetable_stop_times st join stations s on s.id = st.station_id where st.trip_key = ?`).all(key) as { c: string }[]).map((r) => r.c)) : null;
  const expected = (actual: Date | null, sched: Date | null, delay: number | null) => actual?.getTime() ?? (sched ? sched.getTime() + (delay ?? 0) * 60_000 : null);
  return list.slice(1).map((next, i) => {
    const prev = list[i]!;
    const arr = expected(prev.actualArr, prev.schedArr, prev.arrDelayMin), dep = expected(next.actualDep, next.schedDep, next.depDelayMin);
    const planned = prev.schedArr && next.schedDep ? Math.round((next.schedDep.getTime() - prev.schedArr.getTime()) / 60_000) : null;
    const gapMin = arr !== null && dep !== null ? Math.round((dep - arr) / 60_000) : planned;
    const minMin = minChangeMin(tierOf(next.originStationId), countryOf(prev.timetableTripKey), countryOf(next.timetableTripKey));
    // The incoming train's usual lateness here (BUILDOUT O4) is taken off the gap, as the planner does.
    const history = arrivalHistoryOf(db, { trainNumber: prev.trainNumber ?? null, serviceDate: prev.serviceDate ?? null, destStationId: prev.destStationId });
    const typical = history ? typicalLateMin(history.days, history.p80Min) : null;
    return {
      index: i, stationId: next.originStationId, sameStation: prev.destStationId === next.originStationId, gapMin, plannedGapMin: planned, minMin,
      comfort: gapMin === null ? null : comfortWithHistory(gapMin, minMin, typical), typicalLateMin: typical, historyDays: history?.days ?? 0,
    };
  });
}
