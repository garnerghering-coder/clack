// Passport (SPEC §14, DESIGN §8): stats over the trains you've ridden, filtered by year and the commuter toggle.
// computePassport is pure (tests feed it legs directly); loadPassportLegs reads them from the database.
import { and, asc, eq, inArray } from 'drizzle-orm';
import { countedRide } from '../legs/recording.js';
import { ON_TIME_MAX_DELAY_MIN, punctualityBand, type Co2Comparison } from '@clack/shared';
import type { Db } from '../db/client.js';
import { legStops, legs, operators, stations, timetableTrips } from '../db/schema.js';
import { readDataFile } from '../dataFiles.js';
import { classifyProduct, kindLists } from '../legs/product.js';
import { trainTypeCatalog } from '../legs/trainTypes.js';
import { withLogo } from '../import/brands.js';
import { COUNTRIES, isCountryCode, type CountryCode } from '../lib/countries.js';

export interface PassportStop {
  stationId: string;
  name: string;
  country: string;
  lat: number;
  lon: number;
  role: string;
}

export interface PassportLeg {
  id: string;
  journeyId: string | null;
  dep: number;
  arr: number;
  schedDep: number;
  distanceM: number;
  operatorId: string | null;
  product: string;
  category: string | null;
  trainType: string | null;
  trainNumber: string | null;
  dataQuality: string;
  arrDelayMin: number | null;
  canceled: boolean;
  geometry: string | null;
  /** Ridden stops in order (board … alight). */
  stops: PassportStop[];
  /** The time zone of the stop you boarded at: which day, month and hour the trip is in. Sweden's when not given. */
  tz?: string;
}

/** Earth's equatorial circumference and Sweden's north–south extent (Treriksröset to Smygehuk ≈ 1,572 km). */
export const EARTH_KM = 40_075;
export const SWEDEN_KM = 1_572;

/**
 * Length of each home country, north to south, in km (the "× the length of your country" medal).
 * SE: Treriksröset to Smygehuk ≈ 1,572 km.
 * NO: Lindesnes to Nordkapp, 1,699 km in a straight line (Store norske leksikon, snl.no/Norge).
 * FI: Hanko to Utsjoki, the greatest length, 1,157 km (Statistics Finland, "Suomi lukuina 2026", from Maanmittauslaitos).
 * DK: 368 km north to south (Danish Wikipedia, "Danmarks geografi"); other sources give 356 km for Skagens Odde to Gedser
 *     Odde (skoven-i-skolen.dk "Danmark i tal"), so the figure is approximate.
 */
export const COUNTRY_LENGTH_KM: Record<CountryCode, number> = { SE: SWEDEN_KM, NO: 1_699, FI: 1_157, DK: 368 };

/**
 * Length of Europe, north to south, in km. No standard figure exists, so it is the great-circle distance between two named
 * extreme points of mainland Europe: Cape Nordkinn / Kinnarodden (71°08′02″N 27°39′00″E) and Punta de Tarifa
 * (36°00′15″N 5°36′37″W). Coordinates from Wikipedia's "Extreme points of Europe" and "Punta de Tarifa" articles.
 */
const NORDKINN = { lat: 71 + 8 / 60 + 2 / 3600, lon: 27 + 39 / 60 };
const TARIFA = { lat: 36 + 15 / 3600, lon: -(5 + 36 / 60 + 37 / 3600) };
const greatCircleKm = (a: { lat: number; lon: number }, b: { lat: number; lon: number }) => {
  const r = Math.PI / 180;
  const h = Math.sin(((b.lat - a.lat) * r) / 2) ** 2 + Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin(((b.lon - a.lon) * r) / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
};
export const EUROPE_KM = Math.round(greatCircleKm(NORDKINN, TARIFA));

/** The Arctic Circle: 66°33′51.1″N (Wikipedia, "Arctic Circle"; it drifts by metres a year). */
export const ARCTIC_CIRCLE_LAT = 66 + 33 / 60 + 51.1 / 3600;
/** The mean distance from the Earth to the Moon, 384,400 km (NASA, Moon fact sheet:
 * https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html, "Mean distance from Earth"). */
export const MOON_KM = 384_400;
/** The Nordic capitals' main stations, for the capitals medal: Stockholm C, Oslo S, København H, Helsinki. */
export const NORDIC_CAPITALS = ['740000001', '760000100', '860000626', 'fi:HKI'] as const;
/** The four Nordic countries the app covers. */
export const NORDICS = ['SE', 'NO', 'DK', 'FI'] as const;
/** Where the far-north medal counts from: 59°N. */
export const FAR_NORTH_FROM = 59;

/** The kinds of train "Every kind of train" asks for; heritage trains are left out. */
export const KINDS_OF_TRAIN = ['high_speed', 'intercity', 'night', 'regional', 'commuter'] as const;

type Co2Factor = { g_per_pkm: number; source?: string };
type Co2Factors = Record<string, { train: Co2Factor; by_product?: Record<string, Co2Factor>; comparisons?: Record<string, Co2Factor> }>;
let factors: Co2Factors | null = null;
export const co2Factors = () => (factors ??= readDataFile<Co2Factors>('co2_factors.json'));

/**
 * Emission factors for a country (data/co2_factors.json, each with its source). Sweden's are IVL's; Denmark, Norway
 * and Finland have their own operators' or government's published train figures, used as estimates (polish pass 1,
 * owner: "estimates are fine"). The car and flight comparisons are Sweden's everywhere. A country with no entry uses
 * Sweden's train figure too. `product` picks a kind's own figure where the source gives one (Denmark's S-tog).
 */
export function co2FactorsFor(country: string | null | undefined, product?: string | null) {
  const all = co2Factors();
  const se = all.SE!;
  const own = all[country ?? 'SE'] ?? se;
  const train = (product && own.by_product?.[product]) || own.train;
  return { train, comparisons: own.comparisons ?? se.comparisons ?? {} };
}

export function co2(distanceKm: number, comparison: Co2Comparison, f: { train: Co2Factor; comparisons: Record<string, Co2Factor> } = co2FactorsFor('SE')) {
  const train = (distanceKm * f.train.g_per_pkm) / 1000;
  const other = (distanceKm * (f.comparisons[comparison]?.g_per_pkm ?? 0)) / 1000;
  return { trainKg: train, comparisonKg: other, savedKg: other - train };
}

/** The CO2 of a set of rides, each with the factors of the country it starts in (see co2FactorsFor). */
function co2ForLegs(rides: PassportLeg[], comparison: Co2Comparison) {
  const sum = { trainKg: 0, comparisonKg: 0, savedKg: 0 };
  for (const l of rides) {
    const c = co2(l.distanceM / 1000, comparison, co2FactorsFor(l.stops[0]?.country, l.product));
    sum.trainKg += c.trainKg;
    sum.comparisonKg += c.comparisonKg;
    sum.savedKg += c.savedKg;
  }
  return sum;
}

/** A moment as a local day: its date, Monday = 0 to Sunday = 6, month 1–12, year and minutes past midnight. */
const localDay = (ms: number, tz: string = COUNTRIES.SE.tz) => {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit', weekday: 'short', hour: '2-digit', minute: '2-digit', hour12: false })
      .formatToParts(ms)
      .map((x) => [x.type, x.value]),
  );
  const weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexOf(p.weekday!);
  return { date: `${p.year}-${p.month}-${p.day}`, weekday, monthNumber: Number(p.month), year: Number(p.year), minutes: (Number(p.hour) % 24) * 60 + Number(p.minute) };
};

/** How many days in a row, ending on `date`, are in `days` (dates "YYYY-MM-DD"). */
function streakEnding(days: Set<string>, date: string): number {
  let n = 0;
  let d = new Date(`${date}T12:00:00Z`);
  while (days.has(d.toISOString().slice(0, 10))) {
    n++;
    d = new Date(d.getTime() - 86_400_000);
  }
  return n;
}

const localParts = (ms: number, tz: string = COUNTRIES.SE.tz) => {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', { timeZone: tz, year: 'numeric', month: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false })
      .formatToParts(ms)
      .map((x) => [x.type, x.value]),
  );
  return { year: Number(p.year), month: `${p.year}-${p.month}`, minutes: (Number(p.hour) % 24) * 60 + Number(p.minute) };
};

export interface PassportOptions {
  year?: number | null;
  includeCommuter: boolean;
  comparison: Co2Comparison;
  /** Home country, for the length-of-your-country line. Sweden's when not given. */
  home?: CountryCode;
}

export function computePassport(all: PassportLeg[], opts: PassportOptions) {
  const home = opts.home ?? 'SE';
  const years = [...new Set(all.map((l) => localParts(l.schedDep, l.tz).year))].sort((a, b) => b - a);
  const inScope = all.filter((l) => (opts.year ? localParts(l.schedDep, l.tz).year === opts.year : true) && (opts.includeCommuter || l.category !== 'commuter'));
  // A cancelled train you didn't ride adds nothing but the cancellation count.
  const rides = inScope.filter((l) => !l.canceled);
  const km = (m: number) => m / 1000;

  const distanceM = rides.reduce((n, l) => n + l.distanceM, 0);
  const minutes = rides.reduce((n, l) => n + Math.max(0, (l.arr - l.dep) / 60_000), 0);
  const journeys = new Set(rides.map((l) => l.journeyId ?? l.id)).size;

  // Stations where you got on or off; passing through doesn't count as a visit.
  const visits = new Map<string, { id: string; name: string; country: string; lat: number; lon: number; count: number }>();
  const countries = new Map<string, number>();
  let borderCrossings = 0;
  for (const l of rides) {
    for (const s of l.stops) {
      if (s.role !== 'board' && s.role !== 'alight') continue;
      const v =
        visits.get(s.stationId) ??
        visits.set(s.stationId, { id: s.stationId, name: s.name, country: s.country, lat: s.lat, lon: s.lon, count: 0 }).get(s.stationId)!;
      v.count++;
    }
    for (const c of new Set(l.stops.map((s) => s.country))) countries.set(c, (countries.get(c) ?? 0) + 1);
    for (let i = 1; i < l.stops.length; i++) if (l.stops[i]!.country !== l.stops[i - 1]!.country) borderCrossings++;
  }

  const group = <K extends string>(key: (l: PassportLeg) => K | null) => {
    const m = new Map<K, { count: number; distanceM: number }>();
    for (const l of rides) {
      const k = key(l);
      if (k === null) continue;
      const e = m.get(k) ?? m.set(k, { count: 0, distanceM: 0 }).get(k)!;
      e.count++;
      e.distanceM += l.distanceM;
    }
    return [...m].map(([k, v]) => ({ key: k, ...v })).sort((a, b) => b.count - a.count || b.distanceM - a.distanceM);
  };

  const routes = group((l) => {
    const a = l.stops[0]?.name;
    const b = l.stops.at(-1)?.name;
    return a && b ? ([a, b].sort().join(' ⇄ ') as string) : null;
  });
  const months = group((l) => localParts(l.schedDep, l.tz).month);
  const byDistance = [...rides].sort((a, b) => b.distanceM - a.distanceM)[0];
  const byDuration = [...rides].sort((a, b) => b.arr - b.dep - (a.arr - a.dep))[0];
  const earliest = [...rides].sort((a, b) => localParts(a.dep, a.tz).minutes - localParts(b.dep, b.tz).minutes)[0];
  const latest = [...rides].sort((a, b) => localParts(b.arr, b.tz).minutes - localParts(a.arr, a.tz).minutes)[0];

  // Delays only from trains with real arrival times (SPEC §14).
  const timed = rides.filter((l) => l.dataQuality === 'full' && l.arrDelayMin !== null);
  const bands = { on_time: 0, slight: 0, late: 0, very_late: 0 };
  for (const l of timed) {
    const b = punctualityBand(l.arrDelayMin);
    if (b in bands) bands[b as keyof typeof bands]++;
  }
  const late = timed.map((l) => Math.max(0, l.arrDelayMin!));
  const worst = [...timed].sort((a, b) => b.arrDelayMin! - a.arrDelayMin!)[0];

  const ref = (l: PassportLeg | undefined) =>
    l
      ? {
          legId: l.id,
          from: l.stops[0]?.name ?? '',
          to: l.stops.at(-1)?.name ?? '',
          distanceM: l.distanceM,
          minutes: Math.round((l.arr - l.dep) / 60_000),
          dep: l.dep,
          arr: l.arr,
          delayMin: l.arrDelayMin,
        }
      : null;
  const totalKm = km(distanceM);
  const busiestMonth = [...months].sort((a, b) => b.count - a.count)[0];

  return {
    years,
    home,
    scope: { year: opts.year ?? null, includeCommuter: opts.includeCommuter },
    totals: {
      distanceM,
      minutes: Math.round(minutes),
      trains: rides.length,
      journeys,
      stations: visits.size,
      countries: countries.size,
      borderCrossings,
      cancellations: inScope.length - rides.length,
    },
    flavor: {
      earthLaps: totalKm / EARTH_KM,
      swedenLengths: totalKm / SWEDEN_KM,
      homeLengths: totalKm / COUNTRY_LENGTH_KM[home],
      europeLengths: totalKm / EUROPE_KM,
      topRoute: routes[0] && routes[0].count > 1 ? { route: routes[0].key, count: routes[0].count } : null,
      busiestMonth: busiestMonth && busiestMonth.count > 1 ? { month: busiestMonth.key, count: busiestMonth.count } : null,
      lateMinutes: late.reduce((n, d) => n + d, 0),
    },
    records: {
      longestDistance: ref(byDistance),
      longestDuration: ref(byDuration),
      biggestDelay: worst && worst.arrDelayMin! > 0 ? ref(worst) : null,
      mostRiddenRoute: routes[0] ? { route: routes[0].key, count: routes[0].count } : null,
      busiestStation: [...visits.values()].sort((a, b) => b.count - a.count)[0] ?? null,
      earliestDeparture: ref(earliest),
      latestArrival: ref(latest),
    },
    operators: group((l) => l.operatorId),
    products: group((l) => l.product),
    trainTypes: group((l) => l.trainType),
    delays: {
      basedOn: timed.length,
      onTimePct: timed.length ? Math.round((100 * timed.filter((l) => l.arrDelayMin! <= ON_TIME_MAX_DELAY_MIN).length) / timed.length) : null,
      totalLateMin: late.reduce((n, d) => n + d, 0),
      averageMin: timed.length ? Math.round((10 * timed.reduce((n, l) => n + l.arrDelayMin!, 0)) / timed.length) / 10 : null,
      worst: worst ? ref(worst) : null,
      bands,
      cancellations: inScope.length - rides.length,
    },
    countries: [...countries].map(([code, count]) => ({ code, legs: count })).sort((a, b) => b.legs - a.legs),
    stations: [...visits.values()].sort((a, b) => b.count - a.count),
    co2: { comparison: opts.comparison, ...co2ForLegs(rides, opts.comparison) },
    // The year in rail (build 80): trains and distance month by month, oldest first, and what was new this year.
    months: [...months].sort((a, b) => (a.key < b.key ? -1 : 1)).map((m) => ({ month: m.key, trains: m.count, distanceM: m.distanceM })),
    firsts: opts.year ? firstsOf(all, opts.year, opts.includeCommuter, visits, countries) : null,
    map: rides.map((l) => ({
      legId: l.id,
      operatorId: l.operatorId,
      geometry: l.geometry,
      stops: [l.stops[0], l.stops.at(-1)].filter(Boolean).map((s) => [s!.lat, s!.lon]),
    })),
  };
}

/** Stations and countries first visited in `year`: in it, and in no trip before it. */
function firstsOf(all: PassportLeg[], year: number, includeCommuter: boolean, visits: Map<string, unknown>, countries: Map<string, number>) {
  const before = all.filter((l) => !l.canceled && localParts(l.schedDep, l.tz).year < year && (includeCommuter || l.category !== 'commuter'));
  const seenStations = new Set(before.flatMap((l) => l.stops.filter((s) => s.role === 'board' || s.role === 'alight').map((s) => s.stationId)));
  const seenCountries = new Set(before.flatMap((l) => l.stops.map((s) => s.country)));
  return {
    stations: [...visits.keys()].filter((id) => !seenStations.has(id)).length,
    countries: [...countries.keys()].filter((c) => !seenCountries.has(c)),
  };
}

// ---------- Milestones (product brief §9.3): explicit criteria, all-time, from counted trips only ----------

/** Each family's thresholds. The label says exactly what earns it ("10 journeys", "1,000 km"). */
export const MILESTONES = {
  journeys: [1, 10, 25, 50, 100, 250, 500, 1000],
  distanceKm: [100, 500, 1000, 2500, 5000, 10_000, EARTH_KM, 100_000, MOON_KM],
  stations: [10, 25, 50, 100, 200, 300, 500],
  operators: [3, 5, 10, 15, 20],
  countries: [2, 3, 5],
  borderCrossings: [1, 5, 10, 25],
  nightTrains: [1, 5, 10, 25],
  /** The longest single train ride, in km (a maximum, not a sum). */
  longestTrainKm: [300, 500, 1000],
  hoursOnBoard: [10, 50, 100, 250, 500, 1000],
  /** Distinct known train types; trips with no known type never count. */
  trainTypes: [5, 10, 20],
  /** Distinct kinds of train ridden, out of KINDS_OF_TRAIN. */
  kindsOfTrain: [KINDS_OF_TRAIN.length],
  /** Times a ridden line crossed the Arctic Circle. */
  arcticCircle: [1],
  /** Total km as a multiple of the home country's length, and of Europe's. */
  homeLength: [1],
  europeLength: [1],
  // Polish pass 1 (owner, 2026-11-14: "significantly increase the medals… get creative"), every one from the trips'
  // own times, stops and kinds; nothing guessed.
  /** Trains that left before 06:00, local time where you got on. */
  earlyBird: [1, 5, 25],
  /** Trains that arrived between midnight and 04:00, local time. */
  nightOwl: [1, 5, 25],
  /** Trains on a Saturday or a Sunday. */
  weekender: [5, 25, 100],
  /** Trains in all four seasons (Dec–Feb, Mar–May, Jun–Aug, Sep–Nov) of one calendar year. */
  fourSeasons: [4],
  /** Trains in all twelve months of one calendar year. */
  everyMonth: [12],
  /** Days in a row with a train. */
  streak: [3, 7, 14],
  /** The same route (where you got on and off, either way) ridden this many times. */
  regular: [10, 50, 100],
  /** The Nordic capitals' main stations got on or off at (NORDIC_CAPITALS). */
  capitals: [4],
  /** Times a ridden line crossed between Sweden and Denmark (the Öresund link is the only rail between them). */
  oresund: [1, 10],
  /** The farthest north reached, in degrees north of FAR_NORTH_FROM (59°N, Oslo and Stockholm), so progress starts
   * where most people live: 8 is 67°N (Kiruna, Bodø), 9 is 68°N (Narvik). */
  farNorth: [8, 9],
  /** A station south of 55.5°N (Trelleborg, Ystad, Lolland and Falster): 1 when reached. */
  farSouth: [1],
  /** Km on high-speed trains. */
  highSpeedKm: [500, 1000, 5000],
  /** Heritage trains. */
  heritage: [1, 5],
  /** The most hours on trains in one day. */
  longDay: [8, 12],
  /** Trains that arrived an hour or more late (patience, recorded kindly). */
  patient: [1],
  /** Trips in a row that arrived at most 5 min late (trips with real times). */
  onTimeRun: [10, 25],
  /** All four Nordic countries ridden in. */
  allNordics: [4],
} as const;

/**
 * One metal language (owner, 2026-11-14): the tier of each level, said once and the same everywhere. Bronze is a first
 * step, silver is a regular rider, gold a dedicated one, platinum exceptional. Same length as each family's levels.
 */
export const MILESTONE_TIERS: Record<keyof typeof MILESTONES, readonly ('bronze' | 'silver' | 'gold' | 'platinum')[]> = {
  journeys: ['bronze', 'bronze', 'silver', 'silver', 'gold', 'gold', 'platinum', 'platinum'],
  distanceKm: ['bronze', 'bronze', 'silver', 'silver', 'gold', 'gold', 'platinum', 'platinum', 'platinum'],
  stations: ['bronze', 'silver', 'silver', 'gold', 'gold', 'platinum', 'platinum'],
  operators: ['bronze', 'silver', 'gold', 'platinum', 'platinum'],
  countries: ['bronze', 'silver', 'gold'],
  borderCrossings: ['bronze', 'silver', 'gold', 'platinum'],
  nightTrains: ['bronze', 'silver', 'gold', 'platinum'],
  longestTrainKm: ['bronze', 'silver', 'gold'],
  hoursOnBoard: ['bronze', 'silver', 'silver', 'gold', 'platinum', 'platinum'],
  trainTypes: ['bronze', 'silver', 'gold'],
  kindsOfTrain: ['gold'],
  arcticCircle: ['gold'],
  homeLength: ['gold'],
  europeLength: ['platinum'],
  earlyBird: ['bronze', 'silver', 'gold'],
  nightOwl: ['bronze', 'silver', 'gold'],
  weekender: ['bronze', 'silver', 'gold'],
  fourSeasons: ['gold'],
  everyMonth: ['platinum'],
  streak: ['silver', 'gold', 'platinum'],
  regular: ['silver', 'gold', 'platinum'],
  capitals: ['gold'],
  oresund: ['bronze', 'silver'],
  farNorth: ['silver', 'gold'],
  farSouth: ['silver'],
  highSpeedKm: ['bronze', 'silver', 'gold'],
  heritage: ['silver', 'gold'],
  longDay: ['silver', 'gold'],
  patient: ['bronze'],
  onTimeRun: ['silver', 'gold'],
  allNordics: ['gold'],
};
export type MilestoneFamily = keyof typeof MILESTONES;

export interface Milestone {
  family: MilestoneFamily;
  target: number;
  /** When and on which trip it was reached (achieved ones only). */
  at?: number;
  legId?: string;
  /** Where you are now towards it (upcoming ones). */
  value?: number;
}

/** Running counts behind every milestone family; computeMilestones, milestoneTotals and the flavor lines share it. */
class Tally {
  journeys = new Set<string>();
  stations = new Set<string>();
  operators = new Set<string>();
  countries = new Set<string>();
  types = new Set<string>();
  kinds = new Set<string>();
  km = 0;
  borders = 0;
  nights = 0;
  arctic = 0;
  longestKm = 0;
  hours = 0;
  early = 0;
  owl = 0;
  weekend = 0;
  seasonsByYear = new Map<number, Set<number>>();
  monthsByYear = new Map<number, Set<number>>();
  days = new Set<string>();
  bestStreak = 0;
  routes = new Map<string, number>();
  capitals = new Set<string>();
  oresund = 0;
  maxLat = -90;
  minLat = 90;
  highSpeedKm = 0;
  heritage = 0;
  hoursByDay = new Map<string, number>();
  patient = 0;
  onTimeRun = 0;
  bestOnTimeRun = 0;
  constructor(private readonly home: CountryCode) {}

  add(l: PassportLeg) {
    this.journeys.add(l.journeyId ?? l.id);
    this.km += l.distanceM / 1000;
    this.longestKm = Math.max(this.longestKm, l.distanceM / 1000);
    this.hours += Math.max(0, l.arr - l.dep) / 3_600_000;
    for (const st of l.stops) {
      if (st.role === 'board' || st.role === 'alight') this.stations.add(st.stationId);
      this.countries.add(st.country);
    }
    if (l.operatorId) this.operators.add(l.operatorId);
    if (l.trainType) this.types.add(l.trainType);
    if ((KINDS_OF_TRAIN as readonly string[]).includes(l.product)) this.kinds.add(l.product);
    for (let i = 1; i < l.stops.length; i++) {
      const a = l.stops[i - 1]!;
      const b = l.stops[i]!;
      if (a.country !== b.country) this.borders++;
      if (a.lat >= ARCTIC_CIRCLE_LAT !== b.lat >= ARCTIC_CIRCLE_LAT) this.arctic++;
    }
    if (l.product === 'night') this.nights++;

    // Polish pass 1's families, from the trip's own local times, stops and kind.
    const dep = localDay(l.dep, l.tz);
    const arr = localDay(l.arr, l.tz);
    if (dep.minutes < 6 * 60) this.early++;
    if (arr.minutes < 4 * 60 && arr.date !== dep.date) this.owl++;
    if (dep.weekday >= 5) this.weekend++;
    const season = Math.floor((dep.monthNumber % 12) / 3); // Dec–Feb 0, Mar–May 1, Jun–Aug 2, Sep–Nov 3
    if (!this.seasonsByYear.has(dep.year)) this.seasonsByYear.set(dep.year, new Set());
    this.seasonsByYear.get(dep.year)!.add(season);
    if (!this.monthsByYear.has(dep.year)) this.monthsByYear.set(dep.year, new Set());
    this.monthsByYear.get(dep.year)!.add(dep.monthNumber);
    this.days.add(dep.date);
    this.bestStreak = Math.max(this.bestStreak, streakEnding(this.days, dep.date));
    const ends = l.stops.filter((st) => st.role === 'board' || st.role === 'alight').map((st) => st.stationId).sort();
    if (ends.length === 2) this.routes.set(ends.join('|'), (this.routes.get(ends.join('|')) ?? 0) + 1);
    for (const st of l.stops) {
      if ((st.role === 'board' || st.role === 'alight') && (NORDIC_CAPITALS as readonly string[]).includes(st.stationId)) this.capitals.add(st.stationId);
      this.maxLat = Math.max(this.maxLat, st.lat);
      this.minLat = Math.min(this.minLat, st.lat);
    }
    for (let i = 1; i < l.stops.length; i++) {
      const pair = [l.stops[i - 1]!.country, l.stops[i]!.country].sort().join('');
      if (pair === 'DKSE') this.oresund++;
    }
    if (l.product === 'high_speed') this.highSpeedKm += l.distanceM / 1000;
    if (l.product === 'heritage' || l.category === 'heritage') this.heritage++;
    this.hoursByDay.set(dep.date, (this.hoursByDay.get(dep.date) ?? 0) + Math.max(0, l.arr - l.dep) / 3_600_000);
    if (l.arrDelayMin !== null && l.arrDelayMin !== undefined && l.dataQuality === 'full') {
      if (l.arrDelayMin >= 60) this.patient++;
      this.onTimeRun = l.arrDelayMin <= ON_TIME_MAX_DELAY_MIN ? this.onTimeRun + 1 : 0;
      this.bestOnTimeRun = Math.max(this.bestOnTimeRun, this.onTimeRun);
    }
  }

  value(f: MilestoneFamily): number {
    switch (f) {
      case 'journeys': return this.journeys.size;
      case 'distanceKm': return this.km;
      case 'stations': return this.stations.size;
      case 'operators': return this.operators.size;
      case 'countries': return this.countries.size;
      case 'borderCrossings': return this.borders;
      case 'nightTrains': return this.nights;
      case 'longestTrainKm': return this.longestKm;
      case 'hoursOnBoard': return this.hours;
      case 'trainTypes': return this.types.size;
      case 'kindsOfTrain': return this.kinds.size;
      case 'arcticCircle': return this.arctic;
      case 'homeLength': return this.km / COUNTRY_LENGTH_KM[this.home];
      case 'europeLength': return this.km / EUROPE_KM;
      case 'earlyBird': return this.early;
      case 'nightOwl': return this.owl;
      case 'weekender': return this.weekend;
      case 'fourSeasons': return Math.max(0, ...[...this.seasonsByYear.values()].map((x) => x.size));
      case 'everyMonth': return Math.max(0, ...[...this.monthsByYear.values()].map((x) => x.size));
      case 'streak': return this.bestStreak;
      case 'regular': return Math.max(0, ...this.routes.values());
      case 'capitals': return this.capitals.size;
      case 'oresund': return this.oresund;
      case 'farNorth': return Math.max(0, this.maxLat - FAR_NORTH_FROM);
      case 'farSouth': return this.minLat < 55.5 ? 1 : 0;
      case 'highSpeedKm': return this.highSpeedKm;
      case 'heritage': return this.heritage;
      case 'longDay': return Math.max(0, ...this.hoursByDay.values());
      case 'patient': return this.patient;
      case 'onTimeRun': return this.bestOnTimeRun;
      case 'allNordics': return NORDICS.filter((c) => this.countries.has(c)).length;
    }
  }
}

export function computeMilestones(all: PassportLeg[], home: CountryCode = 'SE'): { achieved: Milestone[]; next: Milestone[]; values: Partial<Record<MilestoneFamily, number>> } {
  const rides = [...all].filter((l) => !l.canceled).sort((a, b) => a.dep - b.dep);
  const tally = new Tally(home);
  const families = Object.keys(MILESTONES) as MilestoneFamily[];
  const achieved: Milestone[] = [];
  const reached = new Set<string>();
  for (const l of rides) {
    tally.add(l);
    for (const f of families)
      for (const target of MILESTONES[f]) {
        const k = `${f}:${target}`;
        // Visiting one country isn't a milestone; "countries" starts at 2.
        if (!reached.has(k) && tally.value(f) >= target) {
          reached.add(k);
          achieved.push({ family: f, target, at: l.arr, legId: l.id });
        }
      }
  }
  // The next step in each family, nearest first.
  const next = families
    .map((f) => {
      const v = tally.value(f);
      const target = MILESTONES[f].find((x) => v < x);
      return target === undefined ? null : ({ family: f, target, value: Math.floor(v * 10) / 10 } as Milestone & { value: number });
    })
    .filter((m): m is Milestone & { value: number } => m !== null)
    .sort((a, b) => b.value / b.target - a.value / a.target);
  // Every family's current value (rounded down to a tenth, as `next`), for the full ladder: `next` only carries three.
  const values = Object.fromEntries(families.map((f) => [f, Math.floor(tally.value(f) * 10) / 10])) as Partial<Record<MilestoneFamily, number>>;
  return { achieved: achieved.reverse(), next: next.slice(0, 3), values };
}

/** Running totals behind the milestones (same counting as computeMilestones). */
function milestoneTotals(all: PassportLeg[], home: CountryCode): Record<MilestoneFamily, number> {
  const tally = new Tally(home);
  for (const l of all) if (!l.canceled) tally.add(l);
  return Object.fromEntries((Object.keys(MILESTONES) as MilestoneFamily[]).map((f) => [f, Math.floor(tally.value(f) * 10) / 10])) as Record<MilestoneFamily, number>;
}

/**
 * What one trip did for your Passport (the moment after adding it, or arriving): milestones it unlocked, how far each
 * family moved, and its firsts (stations, operator, countries you hadn't been to). Everything from counted trips only;
 * a trip that doesn't count (yet) says so instead. Pure.
 */
export function tripProgress(all: PassportLeg[], legId: string, home: CountryCode = 'SE') {
  const leg = all.find((l) => l.id === legId);
  if (!leg || leg.canceled) return { counted: false as const };
  const others = all.filter((l) => l.id !== legId);
  const before = milestoneTotals(others, home);
  const after = milestoneTotals(all, home);
  const had = new Set(computeMilestones(others, home).achieved.map((m) => `${m.family}:${m.target}`));
  const unlocked = computeMilestones(all, home).achieved.filter((m) => !had.has(`${m.family}:${m.target}`));
  // Each family that moved, against its next target (or the one just reached).
  const moved = (Object.keys(MILESTONES) as MilestoneFamily[])
    .filter((f) => after[f] > before[f])
    .map((f) => {
      const target = MILESTONES[f].find((x) => after[f] < x) ?? [...MILESTONES[f]].reverse().find((x) => after[f] >= x)!;
      return { family: f, before: before[f], after: after[f], target };
    })
    .sort((a, b) => b.after / b.target - a.after / a.target);
  const seenStations = new Set(others.flatMap((l) => l.stops.filter((s) => s.role === 'board' || s.role === 'alight').map((s) => s.stationId)));
  const seenCountries = new Set(others.flatMap((l) => l.stops.map((s) => s.country)));
  const ends = leg.stops.filter((s) => s.role === 'board' || s.role === 'alight');
  return {
    counted: true as const,
    unlocked,
    moved: moved.slice(0, 4),
    firsts: {
      stations: [...new Map(ends.filter((s) => !seenStations.has(s.stationId)).map((s) => [s.stationId, s.name])).values()],
      operator: leg.operatorId && !others.some((l) => l.operatorId === leg.operatorId) ? leg.operatorId : null,
      countries: [...new Set(leg.stops.map((s) => s.country).filter((c) => !seenCountries.has(c)))],
    },
  };
}

/** Trips waiting for "Did you take this train?". */
export function reviewQueue(db: Db, userId: string) {
  const rows = db
    .select({ id: legs.id, reason: legs.rideReason, schedDep: legs.schedDep, from: legs.originStationId, to: legs.destStationId, trainNumber: legs.trainNumber })
    .from(legs)
    .where(and(eq(legs.userId, userId), eq(legs.ride, 'review')))
    .all();
  const names = new Map(db.select({ id: stations.id, name: stations.name }).from(stations).where(inArray(stations.id, [...new Set(rows.flatMap((r) => [r.from, r.to]))].concat(['']))).all().map((x) => [x.id, x.name]));
  return rows.map((r) => ({ legId: r.id, reason: r.reason, dep: r.schedDep?.getTime() ?? null, from: names.get(r.from) ?? '', to: names.get(r.to) ?? '', trainNumber: r.trainNumber }));
}

/** Legs you've ridden: arrived, and recorded as travelled (auto from Trafikverket's reports, or confirmed by you). */
export function loadPassportLegs(db: Db, userId: string, now = Date.now()): PassportLeg[] {
  const rows = db
    .select({ l: legs, routeType: timetableTrips.routeType })
    .from(legs)
    .leftJoin(timetableTrips, eq(timetableTrips.key, legs.timetableTripKey))
    .where(eq(legs.userId, userId))
    .all()
    .filter(({ l }) => (l.actualArr ?? l.schedArr)!.getTime() <= now && countedRide(l.ride));
  if (!rows.length) return [];
  const stops = db
    .select({
      legId: legStops.legId,
      role: legStops.role,
      stationId: stations.id,
      name: stations.name,
      country: stations.country,
      lat: stations.lat,
      lon: stations.lon,
      tz: stations.tz,
    })
    .from(legStops)
    .innerJoin(stations, eq(stations.id, legStops.stationId))
    .where(
      inArray(
        legStops.legId,
        rows.map((r) => r.l.id),
      ),
    )
    .orderBy(asc(legStops.legId), asc(legStops.seq))
    .all();
  const byLeg = new Map<string, (PassportStop & { tz: string })[]>();
  for (const s of stops)
    if (s.role === 'board' || s.role === 'through' || s.role === 'alight') (byLeg.get(s.legId) ?? byLeg.set(s.legId, []).get(s.legId)!).push(s);
  const lists = kindLists(db);
  return rows.map(({ l, routeType }) => ({
    id: l.id,
    journeyId: l.journeyId,
    dep: (l.actualDep ?? l.schedDep)!.getTime(),
    arr: (l.actualArr ?? l.schedArr)!.getTime(),
    schedDep: l.schedDep!.getTime(),
    distanceM: l.distanceM ?? 0,
    operatorId: l.operatorId,
    // One kind for every screen (legs/product.ts): the owner's choice, else the feeds' and the sourced lists'.
    product: classifyProduct(
      { country: byLeg.get(l.id)?.[0]?.country ?? null, operatorId: l.operatorId, trainNumber: l.trainNumber, category: l.category, routeType: routeType ?? null, userProduct: l.userProduct },
      lists,
    ).product,
    category: l.category,
    trainType: l.trainType,
    trainNumber: l.trainNumber,
    dataQuality: l.dataQuality,
    arrDelayMin: l.arrDelayMin,
    canceled: l.canceled,
    geometry: l.geometry,
    stops: (byLeg.get(l.id) ?? []).map(({ tz: _tz, ...s }) => s),
    tz: byLeg.get(l.id)?.[0]?.tz ?? COUNTRIES.SE.tz,
  }));
}

/** Names, colours, logos and train-type details the Passport screen needs alongside the numbers. */
export function passportRefs(db: Db) {
  return {
    operators: Object.fromEntries(
      db
        .select()
        .from(operators)
        .all()
        .map((o) => [o.id, withLogo(o)]),
    ),
    trainTypes: Object.fromEntries(trainTypeCatalog().types.map((t) => [t.id, t])),
  };
}

/** The home country: the setting, else the country you first boarded in, else Sweden. */
export function homeCountryOf(setting: string | undefined, all: PassportLeg[]): CountryCode {
  if (isCountryCode(setting)) return setting;
  const first = [...all].filter((l) => !l.canceled).sort((a, b) => a.dep - b.dep)[0]?.stops[0]?.country;
  return isCountryCode(first) ? first : 'SE';
}
