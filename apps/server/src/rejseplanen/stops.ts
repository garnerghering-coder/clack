// Live times for one train's Danish stops, from Rejseplanen (for a leg, and for a train's stop list on the map).
// The journey is found from what the map and boards have already seen, else from one board query at its first
// Danish stop; its details are kept 50 s, so a leg tracked every 20 s costs about one request a minute.
// A past time Rejseplanen marks PROGNOSED came from the train, so it counts as actual (its own app shows it as the
// time the train left); CALCULATED times are carried forward from an earlier stop and stay estimates. The next
// morning's archive (observed/dk-archive.ts) confirms or corrects them.
import type { Db } from '../db/client.js';
import { addCauses, deviationTexts } from '../legs/causes.js';
import type { StopActuals } from '../legs/actuals.js';
import { noticesByStop } from './notices.js';
import { rejseplanen, RejseplanenUnavailable, type Journey, type RejseplanenClient } from './client.js';
import { stationOfUic, TripMatcher, uicOfStation } from './match.js';
import type { TrainStopView } from '../livemap/trainStops.js';

const DETAILS_TTL_MS = 50_000;
const jids = new Map<string, string>();
const details = new Map<string, { at: number; journey: Journey | null }>();
let matcher: TripMatcher | null = null;

/** Remember a journey the map or a board saw, so a leg on it needs no search (keys: trip key and number, per day). */
export function rememberJourney(j: Journey, tripKey: string | null) {
  if (tripKey) jids.set(`${tripKey}|${j.date}`, j.jid);
  if (j.number) jids.set(`${j.number}|${j.date}`, j.jid);
  if (jids.size > 20_000) jids.delete(jids.keys().next().value!);
}

const minute = (ms: number | null) => (ms === null ? null : Math.floor(ms / 60_000));

export interface RejseplanenRef {
  tripKey: string | null;
  trainNumber: string | null;
  serviceDate: string;
  stops: { seq: number; stationId: string; schedArr: number | null; schedDep: number | null }[];
}

async function findJid(db: Db, ref: RejseplanenRef, client: RejseplanenClient): Promise<string | null> {
  const known = (ref.tripKey && jids.get(`${ref.tripKey}|${ref.serviceDate}`)) || (ref.trainNumber && jids.get(`${ref.trainNumber}|${ref.serviceDate}`));
  if (known) return known;
  const first = ref.stops.find((s) => uicOfStation(s.stationId) && s.schedDep !== null);
  if (!first) return null;
  matcher ??= new TripMatcher(db);
  const entries = await client.stationBoard(uicOfStation(first.stationId)!, 'DEP', first.schedDep! - 60_000, 3);
  const hit = entries.find(({ journey: j }) => (ref.tripKey && matcher!.match(j.date, j.ends)?.tripKey === ref.tripKey) || (ref.trainNumber && j.number === ref.trainNumber));
  if (!hit) return null;
  rememberJourney(hit.journey, ref.tripKey);
  return hit.journey.jid;
}

/** Rejseplanen's live state of a train's stops that have a UIC number (Danish stops, and others it lists). */
export async function rejseplanenFor(db: Db, ref: RejseplanenRef, opts: { now?: number; client?: RejseplanenClient } = {}): Promise<Map<number, StopActuals>> {
  const out = new Map<number, StopActuals>();
  const client = opts.client ?? rejseplanen();
  const now = opts.now ?? Date.now();
  if (!client.available() || !ref.stops.some((s) => uicOfStation(s.stationId))) return out;
  const jid = await findJid(db, ref, client);
  if (!jid) return out;
  let cached = details.get(jid);
  if (!cached || now - cached.at > DETAILS_TTL_MS) {
    cached = { at: now, journey: await client.journeyDetails(jid) };
    details.set(jid, cached);
    if (details.size > 500) details.delete(details.keys().next().value!);
  }
  const j = cached.journey;
  if (!j) return out;
  // Each stop's notices: the train's on the stretch they name, a station's own (lifts) on that station only.
  const byStop = noticesByStop(j.notices, j.stops.map((x) => x.name));
  for (const s of ref.stops) {
    const uic = uicOfStation(s.stationId);
    if (!uic) continue;
    const r = j.stops.find((x) => x.uic === uic && ((s.schedDep !== null && minute(x.depPlanned) === minute(s.schedDep)) || (s.schedArr !== null && minute(x.arrPlanned) === minute(s.schedArr))));
    if (!r) continue;
    const causes = byStop[j.stops.indexOf(r)] ?? [];
    const reported = r.prognosis === 'PROGNOSED';
    const past = (t: number | null) => t !== null && t <= now;
    out.set(s.seq, {
      seq: s.seq,
      actualArr: reported && past(r.arrLive) ? r.arrLive : null,
      actualDep: reported && past(r.depLive) ? r.depLive : null,
      estimatedArr: reported && past(r.arrLive) ? null : r.arrLive,
      estimatedDep: reported && past(r.depLive) ? null : r.depLive,
      platform: r.depPlatform ?? r.arrPlatform,
      canceled: j.cancelled || r.arrCancelled || r.depCancelled,
      deviations: deviationTexts(causes),
      causes: addCauses([], causes),
      trvTrainNumber: null,
      composition: null,
      onboard: null,
      source: 'rejseplanen',
    });
  }
  return out;
}

/** How old a remembered stop list may be when Rejseplanen can't answer now. */
const STALE_MS = 10 * 60_000;

/**
 * JourneyDetails for a train sheet: when the shared limit is used up (the map's polls, boards), waits for the next
 * token (one every 2 s) up to twice before giving up. Undefined when there was no answer.
 */
async function detailsSoon(client: RejseplanenClient, jid: string): Promise<Journey | null | undefined> {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      return await client.journeyDetails(jid);
    } catch (e) {
      if (!(e instanceof RejseplanenUnavailable) || !/limit/.test(e.message) || attempt === 2) return undefined;
      await new Promise((r) => setTimeout(r, 2100));
    }
  }
  return undefined;
}

/**
 * A train's whole stop list from Rejseplanen alone, for trains no timetable of ours has (Snälltåget 21509 Malmö →
 * Berlin on 27 Oct). Live times as in `rejseplanenFor`; names as Rejseplanen gives them where we don't know the station.
 */
export async function journeyStopsView(db: Db, jid: string, opts: { now?: number; client?: RejseplanenClient } = {}): Promise<TrainStopView[] | null> {
  const client = opts.client ?? rejseplanen();
  const now = opts.now ?? Date.now();
  let cached = details.get(jid);
  if (!cached || now - cached.at > DETAILS_TTL_MS) {
    const fresh = client.available() ? await detailsSoon(client, jid) : undefined;
    // No answer (the shared request limit, Rejseplanen resting): the last list, up to STALE_MS old, beats none.
    if (fresh === undefined) {
      if (!cached || now - cached.at > STALE_MS) return null;
    } else {
      cached = { at: now, journey: fresh };
      details.set(jid, cached);
      if (details.size > 500) details.delete(details.keys().next().value!);
    }
  }
  const j = cached.journey;
  if (!j?.stops.length) return null;
  const byStop = noticesByStop(j.notices, j.stops.map((x) => x.name));
  const out = j.stops.map((s, i): TrainStopView => {
    const causes = addCauses([], byStop[i] ?? []);
    const ours = s.uic ? stationOfUic(db, s.uic) : null;
    const reported = s.prognosis === 'PROGNOSED';
    const past = (t: number | null) => t !== null && t <= now;
    const last = i === j.stops.length - 1;
    const actualArr = reported && past(s.arrLive) ? s.arrLive : null;
    const actualDep = reported && past(s.depLive) ? s.depLive : null;
    return {
      seq: i + 1,
      stationId: ours?.id ?? (s.uic ? `uic:${s.uic}` : `rp:${i}`),
      name: ours?.name ?? s.name ?? '',
      arr: s.arrPlanned,
      dep: s.depPlanned,
      actualArr,
      actualDep,
      estimatedArr: actualArr === null ? s.arrLive : null,
      estimatedDep: actualDep === null ? s.depLive : null,
      platform: s.depPlatform ?? s.arrPlatform,
      canceled: j.cancelled || s.arrCancelled || s.depCancelled,
      passed: Boolean(last ? actualArr : actualDep) || ((last ? (s.arrLive ?? s.arrPlanned) : (s.depLive ?? s.depPlanned)) ?? Infinity) + 2 * 60_000 < now,
      source: 'rejseplanen',
      causes,
    };
  });
  // A stop before a passed one is passed too (as mergeStops does).
  let seen = false;
  for (let i = out.length - 1; i >= 0; i--) {
    if (out[i]!.passed) seen = true;
    else if (seen) out[i]!.passed = true;
  }
  return out;
}
