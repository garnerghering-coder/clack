// Live times for one train's Danish stops, from Rejseplanen (for a leg, and for a train's stop list on the map).
// The journey is found from what the map and boards have already seen, else from one board query at its first
// Danish stop; its details are kept 50 s, so a leg tracked every 20 s costs about one request a minute.
// A past time Rejseplanen marks PROGNOSED came from the train, so it counts as actual (its own app shows it as the
// time the train left); CALCULATED times are carried forward from an earlier stop and stay estimates. The next
// morning's archive (observed/dk-archive.ts) confirms or corrects them.
import type { Db } from '../db/client.js';
import { addCauses, deviationTexts } from '../legs/causes.js';
import type { StopActuals } from '../legs/actuals.js';
import { rejseplanenCauses } from '../boards/denmark.js';
import { rejseplanen, type Journey, type RejseplanenClient } from './client.js';
import { TripMatcher, uicOfStation } from './match.js';

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
  const causes = rejseplanenCauses(j.messages);
  for (const s of ref.stops) {
    const uic = uicOfStation(s.stationId);
    if (!uic) continue;
    const r = j.stops.find((x) => x.uic === uic && ((s.schedDep !== null && minute(x.depPlanned) === minute(s.schedDep)) || (s.schedArr !== null && minute(x.arrPlanned) === minute(s.schedArr))));
    if (!r) continue;
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
