// Station tiers for the change rule (packages/shared/src/changes.ts): hub 15 min, mid 10, default 7. Worked out from
// one weekday's timetable, commuter trains left out (decided with the owner, 2026-10-27/28):
//  - rule 3, real changes possible, sets the tier: arrival/departure pairs 7–60 min apart where the second train
//    reaches a station the first neither goes on to nor came from;
//  - rule 1, distinct origin→destination routes, and rule 2, lines meeting plus trains starting or ending, cross-check
//    it. A hub also needs 45+ routes (else Oslo's and Copenhagen's inner commuter stations would be hubs).
// Stations where the rules disagree go on the review list in the file, with all three counts.
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';

export type Tier = 'hub' | 'mid' | 'default';
export const NAMED_HUBS: Record<string, string> = { 'fi:HKI': 'Helsinki: the capital terminus; the counts undersell a terminus (owner, 2026-10-27)' };
// Denmark and Finland get their own mid rule (owner, 2026-10-30): with Sweden's, Denmark's coastal and local lines
// (not marked commuter in the Danish feed) made 50 mid stations out of trains passing on one line, and Finland's sparse
// long-distance network reached only 3. A Danish mid is a real interchange: 150+ changes where lines meet (3+
// neighbours) or many trains start or end, on 15+ routes (or 50+ ends), or 1500+ changes anywhere (the Copenhagen
// core). A Finnish mid has 20+ trains and 10+ changes or 15+ trains starting or ending there.
export const NAMED_MIDS: Record<string, string> = {
  'fi:LH': 'Lahti: a large regional station whose counts are low because commuter trains are left out (owner, 2026-10-30)',
  'fi:KUO': 'Kuopio: a large regional station on a simple line (owner, 2026-10-30)',
};
export const NAMED_DEFAULTS: Record<string, string> = {
  '860000717': 'Tølløse: a junction of local lines only (owner, 2026-10-30)',
  '860000116': 'Lindholm: mainly local Nordjyske trains (owner, 2026-10-30)',
  '860000027': 'Skørping: mainly local Nordjyske trains (owner, 2026-10-30)',
  'fi:PAR': 'Parikkala: a real junction, but a small town (owner, 2026-10-30)',
  'fi:YV': 'Ylivieska: a real junction, but a small town (owner, 2026-10-30)',
  'fi:OV': 'Orivesi: a real junction, but a small town (owner, 2026-10-30)',
};

/** Whether a station is mid tier by its own country's rule (only Denmark and Finland differ from the general one). */
export function countryMid(country: string, c: { changes: number; routes: number; neighbours: number; ends: number; trains: number }): boolean {
  if (country === 'DK') return (c.changes >= 150 && (c.neighbours >= 3 || c.ends >= 20) && (c.routes >= 15 || c.ends >= 50)) || c.changes >= 1500;
  if (country === 'FI') return c.trains >= 20 && (c.changes >= 10 || c.ends >= 15);
  return c.changes >= MID_CHANGES;
}
const HUB_CHANGES = 1400, HUB_ROUTES = 45, MID_CHANGES = 150, MID_ROUTES = 20;

export interface StationTier { id: string; name: string; country: string; tier: Tier; changes: number; routes: number; neighbours: number; ends: number; trains: number; review?: string }

export async function stationTiers(db: Db, date: string): Promise<{ date: string; stations: StationTier[] }> {
  const rows = db.all<{ k: string; s: string; a: number | null; d: number | null; np: number; nd: number }>(sql`
    select st.trip_key k, st.station_id s, st.arr_sec a, st.dep_sec d, st.no_pickup np, st.no_dropoff nd
    from timetable_stop_times st
    join timetable_trip_dates td on td.trip_key = st.trip_key and td.service_date = ${date}
    join timetable_trips t on t.key = st.trip_key and t.category <> 'commuter'
    order by st.trip_key, st.seq`);
  const byTrip = new Map<string, typeof rows>();
  for (const r of rows) (byTrip.get(r.k) ?? byTrip.set(r.k, []).get(r.k)!).push(r);
  type Arr = { t: number; k: string; before: Set<string>; after: Set<string> };
  type Dep = { t: number; k: string; after: string[] };
  const arr = new Map<string, Arr[]>(), dep = new Map<string, Dep[]>();
  const routes = new Map<string, Set<string>>(), nb = new Map<string, Set<string>>(), ends = new Map<string, number>(), trains = new Map<string, number>();
  const add = <T>(m: Map<string, Set<T>>, k: string, v: T) => (m.get(k) ?? m.set(k, new Set()).get(k)!).add(v);
  for (const [k, st] of byTrip) {
    const od = `${st[0]!.s}>${st.at(-1)!.s}`;
    ends.set(st[0]!.s, (ends.get(st[0]!.s) ?? 0) + 1);
    ends.set(st.at(-1)!.s, (ends.get(st.at(-1)!.s) ?? 0) + 1);
    st.forEach((r, i) => {
      add(routes, r.s, od);
      trains.set(r.s, (trains.get(r.s) ?? 0) + 1);
      if (i > 0) add(nb, r.s, st[i - 1]!.s);
      if (i < st.length - 1) add(nb, r.s, st[i + 1]!.s);
      if (i > 0 && r.a !== null && !r.nd) (arr.get(r.s) ?? arr.set(r.s, []).get(r.s)!).push({ t: r.a, k, before: new Set(st.slice(0, i).map((x) => x.s)), after: new Set(st.slice(i + 1).map((x) => x.s)) });
      if (i < st.length - 1 && r.d !== null && !r.np) (dep.get(r.s) ?? dep.set(r.s, []).get(r.s)!).push({ t: r.d, k, after: st.slice(i + 1).map((x) => x.s) });
    });
  }
  const names = new Map(db.all<{ id: string; name: string; country: string }>(sql`select id, name, country from stations where kind = 'rail_station'`).map((r) => [r.id, r]));
  const out: StationTier[] = [];
  let n = 0;
  for (const [s, info] of names) {
    if (!trains.has(s)) continue;
    // The pair count is the heavy part: give the event loop a turn every 200 stations (this runs on the server too).
    if (++n % 200 === 0) await new Promise((r) => setImmediate(r));
    let changes = 0;
    const ds = (dep.get(s) ?? []).sort((a, b) => a.t - b.t);
    for (const a of arr.get(s) ?? []) {
      let lo = 0, hi = ds.length;
      while (lo < hi) { const m = (lo + hi) >> 1; if (ds[m]!.t < a.t + 420) lo = m + 1; else hi = m; }
      for (let j = lo; j < ds.length && ds[j]!.t <= a.t + 3600; j++) {
        const d = ds[j]!;
        if (d.k !== a.k && d.after.some((x) => !a.after.has(x) && !a.before.has(x))) changes++;
      }
    }
    const r = routes.get(s)?.size ?? 0;
    const nbs = nb.get(s)?.size ?? 0, e = ends.get(s) ?? 0;
    const named = NAMED_HUBS[s] ?? NAMED_MIDS[s] ?? NAMED_DEFAULTS[s];
    const mid = countryMid(info.country, { changes, routes: r, neighbours: nbs, ends: e, trains: trains.get(s) ?? 0 });
    const tier: Tier = NAMED_HUBS[s] || (changes >= HUB_CHANGES && r >= HUB_ROUTES) ? 'hub' : NAMED_DEFAULTS[s] ? 'default' : NAMED_MIDS[s] || mid ? 'mid' : 'default';
    const byRoutes: Tier = r >= HUB_ROUTES ? 'hub' : r >= MID_ROUTES ? 'mid' : 'default';
    const byLines: Tier = e >= 150 ? 'hub' : e >= 20 || nbs >= 5 ? 'mid' : 'default';
    const disagree = [byRoutes !== tier ? `routes say ${byRoutes}` : null, byLines !== tier ? `lines/ends say ${byLines}` : null].filter(Boolean);
    out.push({ id: s, name: info.name, country: info.country, tier, changes, routes: r, neighbours: nbs, ends: e, trains: trains.get(s) ?? 0, ...(named ? { review: named } : disagree.length && tier !== 'default' || byRoutes !== 'default' && tier === 'default' ? { review: disagree.join('; ') } : {}) });
  }
  out.sort((a, b) => b.changes - a.changes);
  return { date, stations: out };
}
