// Passport (SPEC §14, DESIGN §8): stats over the trains you've ridden, filtered by year and the commuter toggle.
// computePassport is pure (tests feed it legs directly); loadPassportLegs reads them from the database.
import { asc, eq, inArray } from 'drizzle-orm';
import { ON_TIME_MAX_DELAY_MIN, delayBand, type Co2Comparison } from '@clack/shared';
import type { Db } from '../db/client.js';
import { legStops, legs, operators, stations, timetableTrips } from '../db/schema.js';
import { readDataFile } from '../dataFiles.js';
import { productOf } from '../search/timetable.js';
import { trainTypeCatalog } from '../legs/trainTypes.js';
import { withLogo } from '../import/brands.js';

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
}

/** Earth's equatorial circumference and Sweden's north–south extent (Treriksröset to Smygehuk ≈ 1,572 km). */
export const EARTH_KM = 40_075;
export const SWEDEN_KM = 1_572;

type Co2Factors = Record<string, { train: { g_per_pkm: number }; comparisons: Record<string, { g_per_pkm: number; source: string }> }>;
let factors: Co2Factors | null = null;
export const co2Factors = () => (factors ??= readDataFile<Co2Factors>('co2_factors.json'));

export function co2(distanceKm: number, comparison: Co2Comparison, f = co2Factors().SE!) {
  const train = (distanceKm * f.train.g_per_pkm) / 1000;
  const other = (distanceKm * (f.comparisons[comparison]?.g_per_pkm ?? 0)) / 1000;
  return { trainKg: train, comparisonKg: other, savedKg: other - train };
}

const localParts = (ms: number) => {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Stockholm', year: 'numeric', month: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false })
      .formatToParts(ms)
      .map((x) => [x.type, x.value]),
  );
  return { year: Number(p.year), month: `${p.year}-${p.month}`, minutes: (Number(p.hour) % 24) * 60 + Number(p.minute) };
};

export interface PassportOptions {
  year?: number | null;
  includeCommuter: boolean;
  comparison: Co2Comparison;
}

export function computePassport(all: PassportLeg[], opts: PassportOptions) {
  const years = [...new Set(all.map((l) => localParts(l.schedDep).year))].sort((a, b) => b - a);
  const inScope = all.filter((l) => (opts.year ? localParts(l.schedDep).year === opts.year : true) && (opts.includeCommuter || l.category !== 'commuter'));
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
  const months = group((l) => localParts(l.schedDep).month);
  const byDistance = [...rides].sort((a, b) => b.distanceM - a.distanceM)[0];
  const byDuration = [...rides].sort((a, b) => b.arr - b.dep - (a.arr - a.dep))[0];
  const earliest = [...rides].sort((a, b) => localParts(a.dep).minutes - localParts(b.dep).minutes)[0];
  const latest = [...rides].sort((a, b) => localParts(b.arr).minutes - localParts(a.arr).minutes)[0];

  // Delays only from trains with real arrival times (SPEC §14).
  const timed = rides.filter((l) => l.dataQuality === 'full' && l.arrDelayMin !== null);
  const bands = { on_time: 0, slight: 0, late: 0, very_late: 0 };
  for (const l of timed) {
    const b = delayBand(l.arrDelayMin);
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
    co2: { comparison: opts.comparison, ...co2(totalKm, opts.comparison) },
    map: rides.map((l) => ({
      legId: l.id,
      operatorId: l.operatorId,
      geometry: l.geometry,
      stops: [l.stops[0], l.stops.at(-1)].filter(Boolean).map((s) => [s!.lat, s!.lon]),
    })),
  };
}

/** Legs you've ridden (arrived by now), with their ridden stops. */
export function loadPassportLegs(db: Db, userId: string, now = Date.now()): PassportLeg[] {
  const rows = db
    .select({ l: legs, routeType: timetableTrips.routeType })
    .from(legs)
    .leftJoin(timetableTrips, eq(timetableTrips.key, legs.timetableTripKey))
    .where(eq(legs.userId, userId))
    .all()
    .filter(({ l }) => (l.actualArr ?? l.schedArr)!.getTime() <= now);
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
  const byLeg = new Map<string, PassportStop[]>();
  for (const s of stops)
    if (s.role === 'board' || s.role === 'through' || s.role === 'alight') (byLeg.get(s.legId) ?? byLeg.set(s.legId, []).get(s.legId)!).push(s);
  return rows.map(({ l, routeType }) => ({
    id: l.id,
    journeyId: l.journeyId,
    dep: (l.actualDep ?? l.schedDep)!.getTime(),
    arr: (l.actualArr ?? l.schedArr)!.getTime(),
    schedDep: l.schedDep!.getTime(),
    distanceM: l.distanceM ?? 0,
    operatorId: l.operatorId,
    product: productOf(routeType ?? '', l.category ?? 'regional'),
    category: l.category,
    trainType: l.trainType,
    trainNumber: l.trainNumber,
    dataQuality: l.dataQuality,
    arrDelayMin: l.arrDelayMin,
    canceled: l.canceled,
    geometry: l.geometry,
    stops: byLeg.get(l.id) ?? [],
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
