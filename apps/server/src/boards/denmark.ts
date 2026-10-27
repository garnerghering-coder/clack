// Departure and arrival boards for Danish stations, from Rejseplanen's live data (rejseplanen/client.ts), and the
// timetable-only board any station without a live source gets (rows straight from the timetable, no live times; the
// board says so with `live: false`). normalizeDenmarkBoard and timetableRows' row building are pure.
import { delayMinutes, type DelayCause } from '@clack/shared';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { deviationTexts } from '../legs/causes.js';
import { trainTypeFor } from '../legs/trainTypes.js';
import type { BoardEntry } from '../rejseplanen/client.js';
import type { TripMatcher } from '../rejseplanen/match.js';
import { rememberJourney } from '../rejseplanen/stops.js';
import type { Product, StationCall } from '../search/timetable.js';
import type { BoardRow, BoardType, PlatformMemory } from './board.js';

const minute = (ms: number) => Math.floor(ms / 60_000);

/** Rejseplanen's categories as Clack's products (DENMARK_DATA_FINDINGS.md lists them). */
export function productOfCategory(cat: string | null): Product {
  if (cat === 'IC' || cat === 'ICL' || cat === 'EC' || cat === 'ICE') return 'intercity';
  if (cat === 'S-Tog') return 'commuter';
  return 'regional';
}

/** Rejseplanen's service messages as causes, shown as written (no code table for Denmark). */
export const rejseplanenCauses = (messages: string[]): DelayCause[] => messages.map((text) => ({ src: 'rejseplanen', text }));

export interface DenmarkBoardContext {
  type: BoardType;
  now: number;
  from: number;
  to: number;
  calls: StationCall[];
  memory: PlatformMemory;
  matcher: TripMatcher;
  /** A station's name by UIC number. */
  names: (uic: string) => string | null;
}

export function normalizeDenmarkBoard(entries: BoardEntry[], ctx: DenmarkBoardContext): BoardRow[] {
  const dep = ctx.type === 'departures';
  const out: BoardRow[] = [];
  for (const { journey: j, stop: s } of entries) {
    if (j.category === 'Togbus') continue;
    const advertised = dep ? s.depPlanned : s.arrPlanned;
    if (advertised === null || advertised < ctx.from || advertised >= ctx.to) continue;
    const live = dep ? s.depLive : s.arrLive;
    const matched = ctx.matcher.match(j.date, j.ends);
    rememberJourney(j, matched?.tripKey ?? null);
    const call =
      (matched && ctx.calls.find((c) => c.tripKey === matched.tripKey && c.serviceDate === j.date)) ||
      // Trains Sweden's feed has (Öresundståg, SJ): by number and minute, any feed.
      ctx.calls.find((c) => j.number && c.trainNumber === j.number && minute((dep ? c.dep : c.arr) ?? 0) === minute(advertised)) ||
      null;
    const number = j.number ?? call?.trainNumber ?? matched?.trainNumber ?? j.line ?? '';
    const id = `dk:${number}|${j.date}|${s.uic}|${ctx.type}|${advertised}`;
    const platform = dep ? s.depPlatform : s.arrPlatform;
    const planned = dep ? s.depPlatformPlanned : s.arrPlatformPlanned;
    const canceled = j.cancelled || (dep ? s.depCancelled : s.arrCancelled);
    // A platform change: Rejseplanen gives the planned one next to the live one; otherwise noticed between polls.
    const seen = ctx.memory.get(id);
    let change: BoardRow['platformChange'] = null;
    if (planned) change = { from: planned, at: seen?.changedAt ?? ctx.now };
    else if (seen?.platform && platform && seen.platform !== platform) change = { from: seen.platform, at: ctx.now };
    else if (seen?.changedFrom) change = { from: seen.changedFrom, at: seen.changedAt };
    ctx.memory.set(id, { platform: platform ?? seen?.platform ?? null, changedFrom: change?.from ?? null, changedAt: change?.at ?? null });
    const endUic = dep ? j.ends?.lastUic : j.ends?.firstUic;
    const endName = (endUic && ctx.names(endUic)) || (dep ? j.direction : null);
    const product = call?.product ?? productOfCategory(j.category);
    const operatorId = call?.operatorId ?? matched?.operatorId ?? null;
    const causes = rejseplanenCauses(j.messages);
    // A live time in the past is when it happened as far as Rejseplanen knows; it stays an estimate until the
    // archive confirms it the next morning, so `actual` is never set from here.
    const done = live !== null ? live <= ctx.now : advertised + 60_000 <= ctx.now;
    out.push({
      id,
      trainNumber: number,
      advertised,
      estimated: live,
      actual: null,
      done,
      delayMin: canceled ? null : delayMinutes(advertised, live),
      platform,
      platformChange: change,
      canceled,
      deviations: deviationTexts(causes),
      causes,
      endpoints: endName ? [endName] : [],
      via: [],
      operatorId,
      productName: j.category,
      product,
      trainType: trainTypeFor(operatorId, product, number, null, endName ? [endName] : [], null),
      onboard: null,
      trip: call ? { key: call.tripKey, serviceDate: call.serviceDate, seq: call.seq } : null,
    });
  }
  return out.sort((a, b) => a.advertised - b.advertised || a.trainNumber.localeCompare(b.trainNumber));
}

/** A board from the timetable alone: every call in the window, with its planned platform and the trip's far end. */
export function timetableRows(db: Db, stationId: string, calls: StationCall[], type: BoardType, from: number, to: number, now: number): BoardRow[] {
  const dep = type === 'departures';
  const inWindow = calls.filter((c) => {
    const t = dep ? c.dep : c.arr;
    return t !== null && t >= from && t < to;
  });
  if (!inWindow.length) return [];
  const keys = [...new Set(inWindow.map((c) => c.tripKey))];
  const info = new Map<string, { firstSeq: number; lastSeq: number; first: string; last: string }>();
  const platforms = new Map<string, string | null>();
  for (let i = 0; i < keys.length; i += 400) {
    const chunk = keys.slice(i, i + 400);
    const list = sql.join(chunk.map((k) => sql`${k}`), sql`, `);
    for (const r of db.all<{ k: string; fs: number; ls: number; f: string; l: string }>(sql`
      select t.k, t.fs, t.ls, fs.name as f, ls.name as l from (
        select trip_key as k, min(seq) as fs, max(seq) as ls from timetable_stop_times where trip_key in (${list}) group by trip_key) t
      join timetable_stop_times a on a.trip_key = t.k and a.seq = t.fs join stations fs on fs.id = a.station_id
      join timetable_stop_times b on b.trip_key = t.k and b.seq = t.ls join stations ls on ls.id = b.station_id`))
      info.set(r.k, { firstSeq: r.fs, lastSeq: r.ls, first: r.f, last: r.l });
    for (const r of db.all<{ k: string; seq: number; platform: string | null }>(sql`
      select trip_key as k, seq, platform from timetable_stop_times where trip_key in (${list}) and station_id = ${stationId}`))
      platforms.set(`${r.k}|${r.seq}`, r.platform);
  }
  const out: BoardRow[] = [];
  for (const c of inWindow) {
    const t = info.get(c.tripKey);
    // A train doesn't depart from its last stop or arrive at its first.
    if (!t || (dep ? c.seq === t.lastSeq : c.seq === t.firstSeq)) continue;
    const advertised = (dep ? c.dep : c.arr)!;
    const end = dep ? t.last : t.first;
    const number = c.trainNumber ?? '';
    out.push({
      id: `tt:${c.tripKey}|${c.serviceDate}|${type}`,
      trainNumber: number,
      advertised,
      estimated: null,
      actual: null,
      done: advertised + 60_000 <= now,
      delayMin: null,
      platform: platforms.get(`${c.tripKey}|${c.seq}`) ?? null,
      platformChange: null,
      canceled: false,
      deviations: [],
      causes: [],
      endpoints: [end],
      via: [],
      operatorId: c.operatorId,
      productName: null,
      product: c.product,
      trainType: trainTypeFor(c.operatorId, c.product, number, null, [end], null),
      onboard: null,
      trip: { key: c.tripKey, serviceDate: c.serviceDate, seq: c.seq },
    });
  }
  return out.sort((a, b) => a.advertised - b.advertised || a.trainNumber.localeCompare(b.trainNumber));
}
