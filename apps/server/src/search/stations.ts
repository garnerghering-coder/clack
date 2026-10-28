// Station autocomplete (spec §9 step 2): accent-insensitive, typo-tolerant, busiest stations first.
import { editDistance, nameTokens, normName } from '../lib/geo.js';

export interface SearchableStation {
  id: string;
  name: string;
  trvSignature: string | null;
  country: string;
  departuresPerDay: number;
  /** County (län) or town, shown under the name in results. */
  county?: string | null;
}

export interface StationHit {
  id: string;
  name: string;
  code: string | null;
  country: string;
  county?: string | null;
  score?: number;
}

interface Entry {
  station: SearchableStation;
  names: { norm: string; tokens: string[]; alias: boolean }[];
  code: string | null;
}

export interface StationIndex {
  entries: Entry[];
}

/**
 * Search-only spelling: "airport" in any of the languages station names use (Oslo lufthavn, Helsinki's Lentoasema,
 * Flughafen) is one word, so "Aalborg Airport" finds Aalborg Lufthavn.
 */
const searchNorm = (s: string) => normName(s).replace(/\b(airport|flygplats|lufthavn|lufthamn|lentoasema|flughafen|lotnisko)\b/g, 'airport');

/**
 * "Central" (normName's "c") is also Denmark's "H", Germany's "Hbf" and Norway's "S", and a station named after its
 * town alone (Odense, Gothenburg's alias): the query is tried with each, keeping the best score.
 */
function variants(q: string): string[] {
  const tokens = q.split(' ');
  if (tokens.length < 2 || tokens.at(-1) !== 'c') return [q];
  const town = tokens.slice(0, -1).join(' ');
  return [q, `${town} h`, `${town} hbf`, `${town} s`, town];
}

export function buildStationIndex(stations: SearchableStation[], aliases: Record<string, string[]>): StationIndex {
  const aliasBySig = new Map(Object.entries(aliases).map(([sig, list]) => [sig.toLowerCase(), list]));
  return {
    entries: stations.map((station) => {
      // Aliases are keyed by Trafikverket signature, or by station id for stations without one (Norway).
      const extra = [...(station.trvSignature ? (aliasBySig.get(station.trvSignature.toLowerCase()) ?? []) : []), ...(aliasBySig.get(station.id.toLowerCase()) ?? [])];
      return {
        station,
        code: station.trvSignature?.toLowerCase() ?? null,
        names: [
          { norm: searchNorm(station.name), tokens: nameTokens(searchNorm(station.name)), alias: false },
          ...extra.map((a) => ({ norm: searchNorm(a), tokens: nameTokens(searchNorm(a)), alias: true })),
        ],
      };
    }),
  };
}

/** Score one query against one name; 0 = no match. */
function scoreName(q: string, qTokens: string[], name: { norm: string; tokens: string[]; alias: boolean }): number {
  if (!q) return 0;
  if (name.norm === q) return name.alias ? 105 : 100;
  if (name.norm.startsWith(q)) return 80;
  // Every query word is the start of some word in the name ("gbg c", "malmo c").
  if (qTokens.every((qt) => name.tokens.some((t) => t.startsWith(qt)))) return 60;
  // Typos: each query word within 1 edit (2 for long words) of some name word or its prefix.
  const fuzzy = qTokens.every((qt) => {
    if (qt.length < 4) return name.tokens.some((t) => t.startsWith(qt));
    const max = qt.length >= 7 ? 2 : 1;
    // Typos rarely hit the first letter, and requiring it stops "goteb" matching "Rotebro".
    return name.tokens.some((t) => t[0] === qt[0] && (editDistance(qt, t, max) <= max || editDistance(qt, t.slice(0, qt.length), max) <= max));
  });
  return fuzzy ? 40 : 0;
}

export function searchStations(index: StationIndex, query: string, limit = 8): (StationHit & { score: number })[] {
  const q = searchNorm(query);
  if (!q.split(' ').filter(Boolean).length) return [];
  const qs = variants(q).map((v) => ({ v, tokens: v.split(' ').filter(Boolean) }));
  const hits: (StationHit & { score: number })[] = [];
  for (const e of index.entries) {
    // The query as typed scores a little above its variants, so "Lund C" still prefers Lund C.
    let score = Math.max(...qs.flatMap((x, i) => e.names.map((n) => scoreName(x.v, x.tokens, n) - (i ? 1 : 0))), 0);
    // Typing a Trafikverket signature ("Cst", "G") finds that station directly.
    if (e.code && e.code === q.replace(/ /g, '.')) score = Math.max(score, 90);
    if (!score) continue;
    // Busier stations win ties: "Stockholm" -> Stockholm C before smaller "Stockholm …" halts.
    score += Math.log10(1 + e.station.departuresPerDay) * 4;
    hits.push({ id: e.station.id, name: e.station.name, code: e.station.trvSignature, country: e.station.country, county: e.station.county ?? null, score });
  }
  return hits.sort((a, b) => b.score - a.score || a.name.localeCompare(b.name, 'sv')).slice(0, limit);
}
