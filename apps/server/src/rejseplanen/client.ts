// Rejseplanen's live data, from the backend its own phone app uses (HAFAS "mgate"; DENMARK_DATA_FINDINGS.md). No key
// or login: the AID is the one published in hafas-client's `rejseplanen` profile. It is not an API Rejseplanen has
// granted us (the API 2.0 key is pending), so Clack keeps its use light and can do without it:
//  - one shared limit of 30 requests a minute; callers that find none left skip their turn rather than queue;
//  - after 5 failures in a row it rests for 10 minutes (boards fall back to the timetable, the map to estimates);
//  - REJSEPLANEN_LIVE=off turns it off.
// Positions are worked out by Rejseplanen from live delays, not GPS, so Clack shows them as estimated.
// Times are "HHMMSS", or "DDHHMMSS" with a day offset, local (Copenhagen) to the journey's date.
import { TokenBucket } from '../digitraffic/client.js';
import { feedFailed, feedOk } from '../lib/health.js';
import { serviceTimeToUtc, ymdToIso } from '../lib/time.js';

export const ENDPOINT = 'https://mobilapps.rejseplanen.dk/bin/iphone.exe';
const BODY = { auth: { type: 'AID', aid: 'irkmpm9mdznstenr-android' }, client: { type: 'AND', id: 'DK' }, ext: 'DK.9', ver: '1.43', lang: 'dan' };
const TZ = 'Europe/Copenhagen';
/** Trains only: IC, ICL, regional (with Lokaltog), Øresund, S-tog (hafas-client's rejseplanen products). */
export const TRAIN_PRODUCTS = 31;
export const MAX_REQUESTS_PER_MINUTE = 30;
const FAILS_TO_REST = 5;
const REST_MS = 10 * 60_000;
const TIMEOUT_MS = 15_000;

export class RejseplanenUnavailable extends Error {}

export interface ClientOptions {
  fetchImpl?: typeof fetch;
  now?: () => number;
  limiter?: TokenBucket;
}

/** One client per process: the limit and the rest are shared by the map, the boards and the legs. */
export class RejseplanenClient {
  private readonly fetchImpl: typeof fetch;
  private readonly now: () => number;
  private readonly limiter: TokenBucket;
  private fails = 0;
  private restUntil = 0;
  calls = 0;

  constructor(opts: ClientOptions = {}) {
    this.fetchImpl = opts.fetchImpl ?? fetch;
    this.now = opts.now ?? Date.now;
    this.limiter = opts.limiter ?? new TokenBucket(MAX_REQUESTS_PER_MINUTE, this.now);
  }

  /** Whether a request may be made now (switched on, not resting). */
  available(): boolean {
    return !/^(0|false|no|off)$/i.test(process.env.REJSEPLANEN_LIVE ?? '') && this.now() >= this.restUntil;
  }

  async call<T = Record<string, unknown>>(meth: string, req: unknown): Promise<{ res: T; common: Common }> {
    if (!this.available()) throw new RejseplanenUnavailable('Rejseplanen is resting or switched off');
    if (!this.limiter.tryTake(this.now())) throw new RejseplanenUnavailable('Rejseplanen request limit reached');
    this.calls++;
    try {
      const r = await this.fetchImpl(ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'User-Agent': 'Clack (+https://getclack.app)' },
        body: JSON.stringify({ ...BODY, svcReqL: [{ meth, req }] }),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      const body = (await r.json()) as { err?: string; svcResL?: { err?: string; errTxt?: string; res?: T & { common?: Common } }[] };
      const s = body.svcResL?.[0];
      if (body.err && body.err !== 'OK') throw new Error(body.err);
      if (!s || s.err !== 'OK' || !s.res) throw new Error(`${meth}: ${s?.err ?? 'no answer'} ${s?.errTxt ?? ''}`.trim());
      this.fails = 0;
      feedOk('rejseplanen', this.now());
      return { res: s.res, common: s.res.common ?? {} };
    } catch (e) {
      if (++this.fails >= FAILS_TO_REST) this.restUntil = this.now() + REST_MS;
      feedFailed('rejseplanen', e, this.now());
      throw e;
    }
  }

  /** Departures (or arrivals) at a station for `durMin` minutes from `from`. */
  async stationBoard(uic: string, type: 'DEP' | 'ARR', from: number, durMin: number): Promise<BoardEntry[]> {
    const { date, time } = localStamp(from);
    const { res, common } = await this.call<{ jnyL?: RawJourney[] }>('StationBoard', {
      type, date, time, dur: durMin, maxJny: 200, stbLoc: { type: 'S', lid: `A=1@L=${uic}@` },
      jnyFltrL: [{ type: 'PROD', mode: 'INC', value: String(TRAIN_PRODUCTS) }],
    });
    return (res.jnyL ?? []).filter((j) => j.stbStop).map((j) => ({ journey: journeyOf(common, j), stop: stopOf(common, j.stbStop!, j.date) }));
  }

  /** One journey's stops with live times. */
  async journeyDetails(jid: string): Promise<Journey | null> {
    const { res, common } = await this.call<{ journey?: RawJourney }>('JourneyDetails', { jid, getPolyline: false });
    return res.journey ? journeyOf(common, res.journey) : null;
  }

  /** Every train in a box (all of Denmark by default) with its position. */
  async journeyGeoPos(box: Box = DENMARK): Promise<Journey[]> {
    const { res, common } = await this.call<{ jnyL?: RawJourney[] }>('JourneyGeoPos', {
      rect: { llCrd: { x: Math.round(box.minLon * 1e6), y: Math.round(box.minLat * 1e6) }, urCrd: { x: Math.round(box.maxLon * 1e6), y: Math.round(box.maxLat * 1e6) } },
      perSize: 30000, perStep: 5000, onlyRT: false, jnyFltrL: [{ type: 'PROD', mode: 'INC', value: String(TRAIN_PRODUCTS) }],
    });
    return (res.jnyL ?? []).map((j) => journeyOf(common, j));
  }
}

export interface Box { minLat: number; minLon: number; maxLat: number; maxLon: number }
export const DENMARK: Box = { minLat: 54.5, minLon: 8.0, maxLat: 57.8, maxLon: 15.2 };

let shared: RejseplanenClient | null = null;
export const rejseplanen = () => (shared ??= new RejseplanenClient());

// ---- The answer, as Clack uses it -------------------------------------------------------------------------------

export interface Stop {
  uic: string | null;
  name: string | null;
  lat: number | null;
  lon: number | null;
  arrPlanned: number | null;
  arrLive: number | null;
  depPlanned: number | null;
  depLive: number | null;
  arrPlatform: string | null;
  depPlatform: string | null;
  /** The platform before a change, when the live one differs from the planned one. */
  arrPlatformPlanned: string | null;
  depPlatformPlanned: string | null;
  arrCancelled: boolean;
  depCancelled: boolean;
  /** Rejseplanen's kind of live time: PROGNOSED (from the train) or CALCULATED (carried forward); null without one. */
  prognosis: string | null;
}

export interface Journey {
  jid: string;
  /** Service date, YYYY-MM-DD. */
  date: string;
  name: string | null;
  /** Train number when Rejseplanen gives one (S-tog runs often have only a line letter). */
  number: string | null;
  line: string | null;
  /** Rejseplanen's category: IC, ICL, Re, RA, RX, S-Tog, Lokalbane, Pågatog, Togbus … */
  category: string | null;
  operator: string | null;
  /** Rejseplanen's administration code for the operator ("000087" = DSB Vores Tog), from the product or its line id. */
  admin: string | null;
  direction: string | null;
  cancelled: boolean;
  stops: Stop[];
  /** Service messages (HIM) on the journey or its line, as text. */
  messages: string[];
  pos: { lat: number; lon: number } | null;
  /** From the journey id: its first and last stop and their planned times (HHMM), for matching the timetable. */
  ends: JourneyEnds | null;
}

/** The first and last stop and their planned times, in minutes after the journey date's midnight (past 1440 after it). */
export interface JourneyEnds { firstUic: string; firstMin: number; lastUic: string; lastMin: number }

// ---- Parsing (pure) ---------------------------------------------------------------------------------------------

interface Common {
  locL?: { extId?: string; name?: string; crd?: { x: number; y: number } }[];
  prodL?: { name?: string; number?: string; nameS?: string; oprX?: number; prodCtx?: { num?: string; line?: string; catOutL?: string; admin?: string; lineId?: string }; himIdL?: string[] }[];
  opL?: { name?: string }[];
  himL?: { hid?: string; head?: string; text?: string }[];
}
interface Platform { txt?: string }
interface RawStop {
  locX?: number;
  aTimeS?: string; aTimeR?: string; dTimeS?: string; dTimeR?: string;
  aPltfS?: Platform; aPltfR?: Platform; dPltfS?: Platform; dPltfR?: Platform;
  aPlatfS?: string; aPlatfR?: string; dPlatfS?: string; dPlatfR?: string;
  aCncl?: boolean; dCncl?: boolean; aProgType?: string; dProgType?: string;
}
interface RawJourney {
  jid: string; date: string; prodX?: number; dirTxt?: string; isCncl?: boolean;
  stopL?: RawStop[]; stbStop?: RawStop; pos?: { x: number; y: number }; msgL?: { type?: string; himX?: number }[];
}

/** "HHMMSS" or "DDHHMMSS" on a journey date "YYYYMMDD" → epoch ms. Pure. */
export function hafasTime(date: string, t: string | undefined): number | null {
  const m = /^(\d\d)?(\d\d)(\d\d)(\d\d)$/.exec(t ?? '');
  if (!m) return null;
  const sec = Number(m[1] ?? 0) * 86400 + Number(m[2]) * 3600 + Number(m[3]) * 60 + Number(m[4]);
  return serviceTimeToUtc(ymdToIso(date), sec, TZ);
}

/**
 * The first and last stop with their times, from a journey id ("…#1S#8600803#1T#1705#LS#8600677#LT#1814#…"). A time
 * after midnight carries a day digit in front ("LT#10101" is 01:01 the next day). Pure.
 */
export function endsOf(jid: string): JourneyEnds | null {
  const f = (k: string) => new RegExp(`#${k}#([^#]+)#`).exec(jid)?.[1];
  const [firstUic, first, lastUic, last] = [f('1S'), f('1T'), f('LS'), f('LT')];
  const firstMin = minutesOf(first), lastMin = minutesOf(last);
  return firstUic && lastUic && firstMin !== null && lastMin !== null ? { firstUic, firstMin, lastUic, lastMin } : null;
}

/** "1705" → 1025, "905" → 545, "10101" → 1501 (day 1, 01:01). Pure. */
export function minutesOf(t: string | undefined): number | null {
  if (!t || !/^\d{3,6}$/.test(t)) return null;
  const s = t.padStart(4, '0');
  return Number(s.slice(0, -4) || 0) * 1440 + Number(s.slice(-4, -2)) * 60 + Number(s.slice(-2));
}

const platform = (p: Platform | undefined, s: string | undefined) => p?.txt ?? s ?? null;

function stopOf(c: Common, s: RawStop, date: string): Stop {
  const loc = s.locX !== undefined ? c.locL?.[s.locX] : undefined;
  const arrS = platform(s.aPltfS, s.aPlatfS);
  const arrR = platform(s.aPltfR, s.aPlatfR);
  const depS = platform(s.dPltfS, s.dPlatfS);
  const depR = platform(s.dPltfR, s.dPlatfR);
  return {
    uic: loc?.extId ?? null,
    name: loc?.name ?? null,
    lat: loc?.crd ? loc.crd.y / 1e6 : null,
    lon: loc?.crd ? loc.crd.x / 1e6 : null,
    arrPlanned: hafasTime(date, s.aTimeS),
    arrLive: hafasTime(date, s.aTimeR),
    depPlanned: hafasTime(date, s.dTimeS),
    depLive: hafasTime(date, s.dTimeR),
    arrPlatform: arrR ?? arrS,
    depPlatform: depR ?? depS,
    arrPlatformPlanned: arrR && arrS && arrR !== arrS ? arrS : null,
    depPlatformPlanned: depR && depS && depR !== depS ? depS : null,
    arrCancelled: !!s.aCncl,
    depCancelled: !!s.dCncl,
    prognosis: s.dProgType ?? s.aProgType ?? null,
  };
}

export function journeyOf(c: Common, j: RawJourney): Journey {
  const prod = j.prodX !== undefined ? c.prodL?.[j.prodX] : undefined;
  const him = new Map((c.himL ?? []).map((h) => [h.hid, h]));
  const texts = [
    ...(j.msgL ?? []).filter((m) => m.type === 'HIM' && m.himX !== undefined).map((m) => c.himL?.[m.himX!]),
    ...(prod?.himIdL ?? []).map((id) => him.get(id)),
  ]
    .map((h) => [h?.head, h?.text].filter(Boolean).join(': '))
    .filter((t) => t.length > 0);
  // Duplicates happen (the first stop can be listed twice in a position answer).
  const stops: Stop[] = [];
  for (const s of j.stopL ?? []) {
    const st = stopOf(c, s, j.date);
    const prev = stops.at(-1);
    if (prev && prev.uic === st.uic && prev.depPlanned === st.depPlanned) continue;
    stops.push(st);
  }
  // Position answers carry the number only as the "line" (Re 1127 → line "1127"); S-tog lines are letters.
  const num = prod?.prodCtx?.num ?? prod?.number ?? prod?.prodCtx?.line ?? null;
  return {
    jid: j.jid,
    date: ymdToIso(j.date),
    name: prod?.name ?? null,
    number: num && /^\d+$/.test(num) ? String(Number(num)) : null,
    line: prod?.prodCtx?.line ?? null,
    category: prod?.prodCtx?.catOutL?.trim() ?? null,
    operator: prod?.oprX !== undefined ? (c.opL?.[prod.oprX]?.name ?? null) : null,
    admin: prod?.prodCtx?.admin ?? /^\d+_(\d{6})_/.exec(prod?.prodCtx?.lineId ?? '')?.[1] ?? null,
    direction: j.dirTxt ?? null,
    cancelled: !!j.isCncl,
    stops,
    messages: [...new Set(texts)],
    pos: j.pos ? { lat: j.pos.y / 1e6, lon: j.pos.x / 1e6 } : null,
    ends: endsOf(j.jid),
  };
}

export interface BoardEntry { journey: Journey; stop: Stop }

/** Local date and time for a request ("YYYYMMDD", "HHMMSS"). Pure. */
export function localStamp(ms: number): { date: string; time: string } {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' })
      .formatToParts(ms)
      .map((x) => [x.type, x.value]),
  );
  return { date: `${p.year}${p.month}${p.day}`, time: `${p.hour}${p.minute}${p.second}` };
}
