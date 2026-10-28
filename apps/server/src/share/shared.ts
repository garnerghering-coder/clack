// Sharing a journey by link. The traveller makes a token; anyone with it reads a cut-down copy of the journey, and a
// phone that follows it gets alerts. The copy built here is the only thing the public routes ever send: nothing in it
// names the traveller, and nothing about how they ride (seat, coach, ticket, notes, other trips) goes in.
import { randomBytes } from 'node:crypto';
import { and, eq, inArray } from 'drizzle-orm';
import type { DelayCause } from '@clack/shared';
import type { Db } from '../db/client.js';
import { journeyFollowers, legs, sharedJourneys } from '../db/schema.js';
import { getLeg, getJourney } from '../legs/legs.js';

const MIN = 60_000;
/** A share lives until this long after the last arrival. */
export const SHARE_AFTER_ARRIVAL_MS = 24 * 60 * MIN;
/** A change with less than this to spare is called tight (the same as the app's list: TripsLogic.transfer). */
export const TIGHT_MIN = 10;

export const newToken = () => randomBytes(16).toString('base64url');

export type Phase = 'upcoming' | 'underway' | 'atChange' | 'arrived' | 'cancelled';

export interface SharedStop {
  name: string;
  tz: string;
  /** Expected: actual, else the estimate, else the timetable. */
  arr: number | null;
  dep: number | null;
  schedArr: number | null;
  schedDep: number | null;
  platform: string | null;
  canceled: boolean;
  passed: boolean;
  /** Why it's late or changed here, as the source said it. */
  causes: DelayCause[];
}

export interface SharedLeg {
  operator: { id: string; name: string; shortName: string; brandColor: string; logoUrl: string | null } | null;
  trainNumber: string | null;
  /** The operating day (YYYY-MM-DD): what a follower's "follow this train" needs. */
  serviceDate: string | null;
  from: { name: string; tz: string };
  to: { name: string; tz: string };
  schedDep: number | null;
  schedArr: number | null;
  expDep: number | null;
  expArr: number | null;
  depPlatform: string | null;
  arrPlatform: string | null;
  depDelayMin: number | null;
  arrDelayMin: number | null;
  canceled: boolean;
  departed: boolean;
  arrived: boolean;
  /** The route as an encoded polyline, when the leg has one. */
  geometry: string | null;
  live: {
    status: string;
    lat: number | null;
    lon: number | null;
    bearing: number | null;
    /** gps | estimated */
    positionSource: string | null;
    progress: number | null;
    nextStop: string | null;
    nextStopAt: number | null;
    updatedAt: number;
  } | null;
  stops: SharedStop[];
}

export interface SharedChange {
  /** Between legs[index] and legs[index + 1]. */
  index: number;
  station: string;
  /** The trains meet at one station (else it is a walk between two). */
  sameStation: boolean;
  spareMin: number | null;
  arrPlatform: string | null;
  depPlatform: string | null;
  status: 'ok' | 'tight' | 'missed' | 'unknown';
}

export interface SharedJourney {
  token: string;
  expiresAt: number;
  summary: {
    phase: Phase;
    /** The leg now running, or the next to run. */
    legIndex: number;
    from: string;
    to: string;
    departureAt: number | null;
    arrivalAt: number | null;
    arrivalDelayMin: number | null;
    arrivalPlatform: string | null;
    /** While underway: the stop it left and the one it heads for. */
    between: { from: string; to: string } | null;
  };
  legs: SharedLeg[];
  changes: SharedChange[];
}

export type Row = { token: string; userId: string; legIds: string[]; expiresAt: Date; revokedAt: Date | null };

const ms = (d: Date | null | undefined) => (d ? d.getTime() : null);

// ---------- the traveller's side ----------

/** The legs a share covers: the whole journey of a leg, or the leg alone. Only the user's own. */
function legIdsOf(db: Db, userId: string, ref: { journeyId?: string; legId?: string }): string[] {
  if (ref.journeyId) return (getJourney(db, userId, ref.journeyId)?.legs ?? []).filter((l) => l.ride !== 'not_taken').map((l) => l.id);
  if (ref.legId) {
    const leg = db.select({ id: legs.id, journeyId: legs.journeyId }).from(legs).where(and(eq(legs.id, ref.legId), eq(legs.userId, userId))).get();
    if (!leg) return [];
    return leg.journeyId ? legIdsOf(db, userId, { journeyId: leg.journeyId }) : [leg.id];
  }
  return [];
}

/** The live share of these legs, if there is one. */
export function findShare(db: Db, userId: string, legIds: string[], now: number): Row | null {
  const key = [...legIds].sort().join(',');
  return (
    db
      .select()
      .from(sharedJourneys)
      .where(eq(sharedJourneys.userId, userId))
      .all()
      .find((r) => !r.revokedAt && r.expiresAt.getTime() > now && [...r.legIds].sort().join(',') === key) ?? null
  );
}

/** Shares the journey (or leg): the live token again if there already is one. Null when it isn't theirs or has no legs. */
export function createShare(db: Db, userId: string, ref: { journeyId?: string; legId?: string }, now: number): Row | null {
  const legIds = legIdsOf(db, userId, ref);
  if (!legIds.length) return null;
  const existing = findShare(db, userId, legIds, now);
  if (existing) return existing;
  const rows = db.select({ arr: legs.schedArr, actual: legs.actualArr }).from(legs).where(inArray(legs.id, legIds)).all();
  const lastArrival = Math.max(now, ...rows.map((r) => r.actual?.getTime() ?? r.arr?.getTime() ?? 0));
  const token = newToken();
  const expiresAt = new Date(lastArrival + SHARE_AFTER_ARRIVAL_MS);
  db.insert(sharedJourneys).values({ token, userId, legIds, expiresAt }).run();
  return { token, userId, legIds, expiresAt, revokedAt: null };
}

/** Stops sharing: the link stops working and the followers' alerts stop. */
export function revokeShare(db: Db, userId: string, token: string, now: number): boolean {
  const changed = db
    .update(sharedJourneys)
    .set({ revokedAt: new Date(now) })
    .where(and(eq(sharedJourneys.token, token), eq(sharedJourneys.userId, userId)))
    .run().changes;
  return changed > 0;
}

// ---------- the public side ----------

/** A share that works now (not revoked, not expired). */
export function liveShare(db: Db, token: string, now: number): Row | null {
  const row = db.select().from(sharedJourneys).where(eq(sharedJourneys.token, token)).get();
  if (!row || row.revokedAt || row.expiresAt.getTime() <= now) return null;
  return row;
}

/** The cut-down journey for a token, or null when the link is dead. */
export function publicJourney(db: Db, token: string, now: number): SharedJourney | null {
  return publicJourneyWithIds(db, token, now)?.journey ?? null;
}

/** The same, with the id of each leg in the same order (for the server's own use; the ids never leave it). */
export function publicJourneyWithIds(db: Db, token: string, now: number): { journey: SharedJourney; legIds: string[] } | null {
  const share = liveShare(db, token, now);
  if (!share) return null;
  const full = share.legIds
    .map((id) => getLeg(db, share.userId, id))
    .filter((l): l is NonNullable<typeof l> => !!l)
    .filter((l) => l.ride !== 'not_taken')
    .sort((a, b) => (a.schedDep?.getTime() ?? 0) - (b.schedDep?.getTime() ?? 0));
  if (!full.length) return null;
  const built = full.map((l) => toSharedLeg(l, now));
  return {
    journey: { token, expiresAt: share.expiresAt.getTime(), summary: summarize(built, now), legs: built, changes: changesOf(built) },
    legIds: full.map((l) => l.id),
  };
}

/** The live shares that cover a leg, with who follows each. */
export function followersOfLeg(db: Db, legId: string, now: number): { token: string; followers: string[] }[] {
  return db
    .select()
    .from(sharedJourneys)
    .all()
    .filter((s) => !s.revokedAt && s.expiresAt.getTime() > now && s.legIds.includes(legId))
    .map((s) => ({ token: s.token, followers: db.select({ id: journeyFollowers.userId }).from(journeyFollowers).where(eq(journeyFollowers.token, s.token)).all().map((r) => r.id) }))
    .filter((s) => s.followers.length > 0);
}

type Full = NonNullable<ReturnType<typeof getLeg>>;

function toSharedLeg(l: Full, now: number): SharedLeg {
  const schedDep = ms(l.schedDep);
  const schedArr = ms(l.schedArr);
  const expDep = ms(l.actualDep) ?? (schedDep !== null ? schedDep + (l.depDelayMin ?? 0) * MIN : null);
  const expArr = ms(l.actualArr) ?? ms(l.live?.arrivalEta) ?? (schedArr !== null ? schedArr + (l.arrDelayMin ?? 0) * MIN : null);
  const arrived = l.actualArr != null || (expArr !== null && expArr <= now && !l.canceled);
  const departed = l.actualDep != null || (expDep !== null && expDep <= now);
  const next = l.live?.nextStopId ? l.stops.find((s) => s.stationId === l.live!.nextStopId) : undefined;
  return {
    operator: l.operator ? { id: l.operator.id, name: l.operator.name, shortName: l.operator.shortName, brandColor: l.operator.brandColor, logoUrl: l.operator.logoUrl } : null,
    trainNumber: l.trainNumber,
    serviceDate: l.serviceDate,
    from: { name: l.origin?.name ?? '', tz: l.origin?.tz ?? 'Europe/Stockholm' },
    to: { name: l.destination?.name ?? '', tz: l.destination?.tz ?? 'Europe/Stockholm' },
    schedDep,
    schedArr,
    expDep,
    expArr,
    depPlatform: l.depPlatform,
    arrPlatform: l.arrPlatform,
    depDelayMin: l.depDelayMin,
    arrDelayMin: l.live?.arrivalDelayMin ?? l.arrDelayMin,
    canceled: l.canceled,
    departed,
    arrived,
    geometry: l.geometry,
    live: l.live
      ? {
          status: l.live.status,
          lat: l.live.lat,
          lon: l.live.lon,
          bearing: l.live.bearing,
          positionSource: l.live.positionSource,
          progress: l.live.progress,
          nextStop: next?.name ?? null,
          nextStopAt: ms(l.live.eta),
          updatedAt: l.live.updatedAt.getTime(),
        }
      : null,
    stops: l.stops
      .filter((s) => s.role !== 'before' && s.role !== 'after')
      .map((s) => {
        const arr = ms(s.actualArr) ?? ms(s.estimatedArr) ?? ms(s.schedArr);
        const dep = ms(s.actualDep) ?? ms(s.estimatedDep) ?? ms(s.schedDep);
        const at = dep ?? arr;
        return {
          name: s.name,
          tz: s.tz,
          arr,
          dep,
          schedArr: ms(s.schedArr),
          schedDep: ms(s.schedDep),
          platform: s.platform,
          canceled: s.canceled,
          causes: s.causes ?? [],
          passed: s.actualDep != null || s.actualArr != null || (at !== null && at <= now && departed),
        };
      }),
  };
}

/** Where the journey is, in the facts the pages put into words. */
export function summarize(list: SharedLeg[], now: number): SharedJourney['summary'] {
  const first = list[0]!;
  const last = list[list.length - 1]!;
  const running = list.findIndex((l) => l.departed && !l.arrived && !l.canceled);
  const coming = list.findIndex((l) => !l.departed && !l.canceled);
  let phase: Phase;
  let legIndex: number;
  if (list.every((l) => l.canceled)) [phase, legIndex] = ['cancelled', 0];
  else if (last.arrived || (last.canceled && list.every((l) => l.arrived || l.canceled))) [phase, legIndex] = ['arrived', list.length - 1];
  else if (running >= 0) [phase, legIndex] = ['underway', running];
  else if (coming > 0) [phase, legIndex] = ['atChange', coming];
  else [phase, legIndex] = ['upcoming', Math.max(coming, 0)];
  const current = list[legIndex]!;
  const underway = phase === 'underway' ? current : null;
  const passed = underway?.stops.filter((s) => s.passed) ?? [];
  const head = underway ? underway.stops.find((s) => !s.passed) : undefined;
  return {
    phase,
    legIndex,
    from: first.from.name,
    to: last.to.name,
    departureAt: first.expDep,
    arrivalAt: last.expArr,
    arrivalDelayMin: last.arrDelayMin,
    arrivalPlatform: last.arrPlatform,
    between: underway && passed.length && head ? { from: passed[passed.length - 1]!.name, to: head.name } : null,
  };
}

/** One entry for each place two trains meet. Never guessed: with a time missing the spare time is unknown. */
export function changesOf(list: SharedLeg[]): SharedChange[] {
  const out: SharedChange[] = [];
  for (let i = 0; i + 1 < list.length; i++) {
    const a = list[i]!;
    const b = list[i + 1]!;
    const spareMin = a.expArr !== null && b.expDep !== null ? Math.round((b.expDep - a.expArr) / MIN) : null;
    const status = spareMin === null || a.canceled || b.canceled ? (spareMin !== null && spareMin < 0 ? 'missed' : 'unknown') : spareMin < 0 ? 'missed' : spareMin < TIGHT_MIN ? 'tight' : 'ok';
    out.push({ index: i, station: a.to.name, sameStation: a.to.name === b.from.name, spareMin, arrPlatform: a.arrPlatform, depPlatform: b.depPlatform, status });
  }
  return out;
}

// ---------- followers ----------

export function follow(db: Db, userId: string, token: string, now: number): boolean {
  const share = liveShare(db, token, now);
  if (!share) return false;
  db.insert(journeyFollowers).values({ token, userId }).onConflictDoNothing().run();
  return true;
}

export function unfollow(db: Db, userId: string, token: string) {
  db.delete(journeyFollowers).where(and(eq(journeyFollowers.token, token), eq(journeyFollowers.userId, userId))).run();
}

/** The journeys this user follows that still work, as the public copy. */
export function following(db: Db, userId: string, now: number): SharedJourney[] {
  return db
    .select({ token: journeyFollowers.token })
    .from(journeyFollowers)
    .where(eq(journeyFollowers.userId, userId))
    .all()
    .map((r) => publicJourney(db, r.token, now))
    .filter((j): j is SharedJourney => !!j);
}
