// Turns one free-text query + date into an interpretation (shown as chips), station suggestions and train results.
import type { Db } from '../db/client.js';
import { normName } from '../lib/geo.js';
import type { HistoryState } from '../import/history.js';
import { loadBrands } from '../dataFiles.js';
import { addDays, todayIn } from '../lib/time.js';
import { COUNTRIES, tzOf } from '../lib/countries.js';
import { danishDays } from './danishDays.js';
import { buildOperatorMatcher, parseQuery } from './parse.js';
import { searchStations, type StationHit, type StationIndex } from './stations.js';
import { daysWithNumber, searchByNumber, searchByRoute, searchConnections, type Connection, type TripResult } from './timetable.js';

/** A station text resolves to its best match only above this score (60 = every word is a prefix of the name). */
const RESOLVE = 60;
/** Splitting "Stockholm Malmö" into two stations needs both halves to be strong (name prefix or better). */
const SPLIT = 80;

export interface SmartSearchResult {
  date: string;
  interpretation: {
    operator?: { id: string; text: string };
    trainNumber?: string;
    from?: StationHit;
    to?: StationHit;
    /** Which station the user is typing now (drives the suggestions list). */
    typing: 'from' | 'to' | null;
  };
  suggestions: StationHit[];
  results: TripResult[] | null;
  /** No direct train between the two stations: trains with one change (timetable only). */
  connections?: Connection[];
  /** Journeys with up to two changes, direct trains among them (search/planner.ts); filled by the route. */
  journeys?: import('./planner.js').PlannedJourney[];
  /** The time window the journeys cover (epoch ms, start inclusive), so the app can page earlier and later. */
  window?: { start: number; end: number };
  /** The date is before the current timetable (historical archive search is a later step). */
  outsideTimetable: boolean;
  /** For a date before the current timetable: whether its archive timetable is ready, loading or unavailable. */
  history?: HistoryState['state'] | 'norway' | 'finland' | 'denmark';
  /** With `norway`, `finland` or `denmark`: the first day that country's record has (YYYY-MM-DD), for the message. */
  historyFrom?: string;
  /** With `denmark`: the stretches after `historyFrom` that no copy of Denmark's timetable covers (inclusive dates). */
  historyGaps?: { from: string; to: string }[];
  /** A train number with nothing on `date`: the nearby days (service dates) it does run, for the message. */
  otherDays?: string[];
  /** With results only from abroad: `otherDays` are the days the number runs in this country (the home country). */
  otherDaysCountry?: string;
}

/** What the app already knows, and how much it wants. */
export interface SearchOptions {
  /** Stations already picked in the app (their ids): used as they are, and the text only adds an operator, a number or,
   * with `fromId` alone, the destination being typed. An id the index doesn't have is ignored. */
  fromId?: string;
  toId?: string;
  /** Only read the text: the interpretation and the station suggestions, no timetable (the app asks this while you
   * type, and searches once the route or the number is chosen). */
  suggestOnly?: boolean;
}

/** Older Norwegian and Finnish days, from the observed record (observed/timetable.ts). */
export interface RecordDays {
  ensure: (country: 'NO' | 'FI', date: string) => 'ready' | 'loading' | 'failed' | 'unavailable';
  from: (country: 'NO' | 'FI') => string;
}

export function createSmartSearch(
  db: Db,
  index: () => StationIndex,
  history: (date: string) => HistoryState = () => ({ state: 'unavailable' }),
  record: RecordDays = { ensure: () => 'unavailable', from: () => '9999-12-31' },
) {
  const matchOperator = buildOperatorMatcher(loadBrands());
  const best = (text: string | undefined, min = RESOLVE) => {
    if (!text?.trim()) return undefined;
    const hit = searchStations(index(), text, 1)[0];
    return hit && hit.score >= min ? hit : undefined;
  };
  const strip = <T extends { score?: number }>(h: T | undefined) => (h ? (({ score, ...rest }) => (void score, rest))(h) : undefined) as StationHit | undefined;

  /** Up to two other stations named after the same town, busiest first. */
  const sameTown = (s: StationHit): StationHit[] => {
    const town = normName(s.name.split(/\s+/)[0]!);
    return searchStations(index(), town, 8)
      .filter((h) => h.id !== s.id && normName(h.name).startsWith(`${town} `))
      .slice(0, 2)
      .map((h) => strip(h)!);
  };

  const byId = (id: string | undefined): StationHit | undefined => {
    if (!id) return undefined;
    const s = index().entries.find((e) => e.station.id === id)?.station;
    return s ? { id: s.id, name: s.name, code: s.trvSignature, country: s.country, county: s.county ?? null } : undefined;
  };

  return (query: string, date: string, opts: SearchOptions = {}): SmartSearchResult => {
    const q = parseQuery(query, matchOperator);
    const out: SmartSearchResult = { date, interpretation: { typing: null }, suggestions: [], results: null, outsideTimetable: false };
    if (q.operatorId) out.interpretation.operator = { id: q.operatorId, text: q.operatorText! };
    if (q.trainNumber) out.interpretation.trainNumber = q.trainNumber;

    let from = byId(opts.fromId);
    let to = from ? byId(opts.toId) : undefined;
    if (from && to) {
      // Both picked: nothing to read but the operator or number.
    } else if (from) {
      // The origin is picked and the text is the destination being typed.
      const text = q.hasSeparator ? q.toText : q.fromText;
      out.interpretation.typing = 'to';
      if (text) {
        to = opts.suggestOnly ? undefined : strip(best(text));
        out.suggestions = searchStations(index(), text, 6).filter((h) => h.id !== from!.id).map((h) => strip(h)!);
      }
    } else if (q.hasSeparator) {
      from = strip(best(q.fromText));
      to = strip(best(q.toText));
      out.interpretation.typing = 'to';
      if (q.toText) out.suggestions = searchStations(index(), q.toText, 6).map((h) => strip(h)!);
    } else if (q.fromText) {
      const whole = searchStations(index(), q.fromText, 1)[0];
      if (q.splittable && !(whole && whole.score >= SPLIT)) {
        // "Snälltåget Stockholm Malmö": try every split into two strong station matches.
        const words = q.fromText.split(' ');
        let bestSplit: { a: StationHit; b: StationHit; score: number; cut: number } | null = null;
        for (let i = 1; i < words.length; i++) {
          const a = best(words.slice(0, i).join(' '), SPLIT);
          const b = best(words.slice(i).join(' '), SPLIT);
          if (a && b && a.id !== b.id && (!bestSplit || a.score + b.score > bestSplit.score)) bestSplit = { a, b, score: a.score + b.score, cut: i };
        }
        if (bestSplit && opts.suggestOnly) {
          // While typing, the second half is the destination still being written: suggest stations for it rather than
          // settle on one ("Uppsala Sto" is Uppsala C and a list of Sto…).
          const rest = words.slice(bestSplit.cut).join(' ');
          from = strip(bestSplit.a);
          out.interpretation.typing = 'to';
          out.suggestions = searchStations(index(), rest, 6).filter((h) => h.id !== from!.id).map((h) => strip(h)!);
        } else if (bestSplit) {
          from = strip(bestSplit.a);
          to = strip(bestSplit.b);
        }
      }
      if (!from) {
        out.interpretation.typing = 'from';
        out.suggestions = searchStations(index(), q.fromText, 6).map((h) => strip(h)!);
      }
    }
    if (from) out.interpretation.from = from;
    if (to) out.interpretation.to = to;
    if (opts.suggestOnly) return out;

    // "Today" is the day where the search starts: Helsinki is an hour ahead of Stockholm and Oslo.
    const windowStart = addDays(todayIn(tzOf((from ?? to)?.country) ?? COUNTRIES.SE.tz), -1);
    if (date < windowStart && (q.trainNumber || (from && to))) {
      // Older days: Sweden's from its archive (fetched the first time a day is asked for), Norway's and Finland's
      // from the observed record (SPEC §5.6). The countries of the stations, or all three for a train number alone.
      // Denmark's past days are in its own timetable (every imported copy keeps its dates, old copies from the
      // Mobility Database too: DENMARK_DATA_FINDINGS.md), so a day is ready when that timetable has trains on it; any
      // other day is answered with the first day it has and the stretches no copy covers (search/danishDays.ts).
      type Where = 'SE' | 'NO' | 'FI' | 'DK';
      const danish = () => {
        const dk = danishDays(db);
        return dk.days.has(date) ? ('ready' as const) : dk.from ? ('denmark' as const) : ('unavailable' as const);
      };
      const where = (c: string | undefined): Where => (c === 'NO' || c === 'FI' || c === 'DK' ? c : 'SE');
      const countries: Where[] = from || to ? [...new Set([from, to].filter(Boolean).map((s) => where(s!.country)))] : ['SE', 'NO', 'FI', 'DK'];
      const states = countries.map((c) => ({ c, state: c === 'SE' ? history(date).state : c === 'DK' ? danish() : record.ensure(c, date) }));
      if (states.some((s) => s.state === 'loading')) out.history = 'loading';
      else if (states.some((s) => s.state === 'ready')) out.history = 'ready';
      else {
        // None has the day: say why for the first (Norway and Finland name the day their record starts, Denmark that
        // day and its gaps).
        const s = states[0]!;
        const rec = s.c === 'NO' || s.c === 'FI' ? s.c : null;
        out.history = rec && s.state === 'unavailable' ? (rec === 'NO' ? 'norway' : 'finland') : s.state;
        if (rec && s.state === 'unavailable') out.historyFrom = record.from(rec);
        if (s.state === 'denmark') {
          const dk = danishDays(db);
          out.historyFrom = dk.from!;
          out.historyGaps = dk.gaps;
        }
      }
      if (out.history !== 'ready') {
        out.outsideTimetable = true;
        out.results = [];
        return out;
      }
    }
    if (q.trainNumber) {
      out.results = searchByNumber(db, q.trainNumber, date, { operatorId: q.operatorId, fromId: from?.id, toId: to?.id });
      if (!out.results.length) out.otherDays = daysWithNumber(db, q.trainNumber, date, { operatorId: q.operatorId });
    }
    else if (from && to) {
      out.results = searchByRoute(db, from.id, to.id, date, { operatorId: q.operatorId });
      // Nothing between those two stations: try the town's other stations ("Stockholm" for a commuter train means
      // Stockholm City, not Stockholm C; "Södertälje" may be Södertälje Centrum).
      if (!out.results.length) {
        const seen = new Set<string>();
        const merged = [];
        for (const a of [from, ...sameTown(from)])
          for (const b of [to, ...sameTown(to)]) {
            if (a.id === from.id && b.id === to.id) continue;
            for (const r of searchByRoute(db, a.id, b.id, date, { operatorId: q.operatorId }))
              // One row per train: the first (busiest) pair of stations that has it.
              if (!seen.has(`${r.key}|${r.serviceDate}`)) {
                seen.add(`${r.key}|${r.serviceDate}`);
                merged.push(r);
              }
          }
        out.results = merged.sort((x, y) => x.from.time - y.from.time);
      }
      // Still nothing: two trains with a change (Alvesta → Rocksjön is Alvesta → Värnamo, then Värnamo → Rocksjön).
      if (!out.results.length) out.connections = searchConnections(db, from.id, to.id, date, { operatorId: q.operatorId });
    }
    return out;
  };
}
