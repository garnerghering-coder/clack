// Turns one free-text query + date into an interpretation (shown as chips), station suggestions and train results.
import type { Db } from '../db/client.js';
import { loadBrands } from '../dataFiles.js';
import { addDays, todayIn } from '../lib/time.js';
import { buildOperatorMatcher, parseQuery } from './parse.js';
import { searchStations, type StationHit, type StationIndex } from './stations.js';
import { searchByNumber, searchByRoute, type TripResult } from './timetable.js';

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
  /** The date is before the current timetable (historical archive search is a later step). */
  outsideTimetable: boolean;
}

export function createSmartSearch(db: Db, index: () => StationIndex) {
  const matchOperator = buildOperatorMatcher(loadBrands());
  const best = (text: string | undefined, min = RESOLVE) => {
    if (!text?.trim()) return undefined;
    const hit = searchStations(index(), text, 1)[0];
    return hit && hit.score >= min ? hit : undefined;
  };
  const strip = <T extends { score?: number }>(h: T | undefined) => (h ? (({ score, ...rest }) => (void score, rest))(h) : undefined) as StationHit | undefined;

  return (query: string, date: string): SmartSearchResult => {
    const q = parseQuery(query, matchOperator);
    const out: SmartSearchResult = { date, interpretation: { typing: null }, suggestions: [], results: null, outsideTimetable: false };
    if (q.operatorId) out.interpretation.operator = { id: q.operatorId, text: q.operatorText! };
    if (q.trainNumber) out.interpretation.trainNumber = q.trainNumber;

    let from: StationHit | undefined;
    let to: StationHit | undefined;
    if (q.hasSeparator) {
      from = strip(best(q.fromText));
      to = strip(best(q.toText));
      out.interpretation.typing = 'to';
      if (q.toText) out.suggestions = searchStations(index(), q.toText, 6).map((h) => strip(h)!);
    } else if (q.fromText) {
      const whole = searchStations(index(), q.fromText, 1)[0];
      if (q.splittable && !(whole && whole.score >= SPLIT)) {
        // "Snälltåget Stockholm Malmö": try every split into two strong station matches.
        const words = q.fromText.split(' ');
        let bestSplit: { a: StationHit; b: StationHit; score: number } | null = null;
        for (let i = 1; i < words.length; i++) {
          const a = best(words.slice(0, i).join(' '), SPLIT);
          const b = best(words.slice(i).join(' '), SPLIT);
          if (a && b && a.id !== b.id && (!bestSplit || a.score + b.score > bestSplit.score)) bestSplit = { a, b, score: a.score + b.score };
        }
        if (bestSplit) {
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

    const windowStart = addDays(todayIn('Europe/Stockholm'), -1);
    if (date < windowStart && (q.trainNumber || (from && to))) {
      out.outsideTimetable = true;
      out.results = [];
      return out;
    }
    if (q.trainNumber) out.results = searchByNumber(db, q.trainNumber, date, { operatorId: q.operatorId, fromId: from?.id, toId: to?.id });
    else if (from && to) out.results = searchByRoute(db, from.id, to.id, date, { operatorId: q.operatorId });
    return out;
  };
}
