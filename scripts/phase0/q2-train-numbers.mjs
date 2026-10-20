// Q2: which GTFS field holds the public train number, and does it match Trafikverket's AdvertisedTrainIdent?
// Usage: node scripts/phase0/q2-train-numbers.mjs 2026-10-19 [2026-10-20 ...]
import { load, serviceDates, tripOperators, stopTimesByTrip } from './p0data.mjs';
import { gtfsTimeToSec } from './gtfs.mjs';

const routes = Object.fromEntries(load('routes.json').map((r) => [r.route_id, r]));
const trips = load('trips.json');
const ops = tripOperators();
const sd = serviceDates();
const stByTrip = stopTimesByTrip();

/** Local HH:MM of a GTFS time on service date (ignoring DST edge cases, fine for a spike). */
const hhmm = (t) => {
  const s = gtfsTimeToSec(t) % 86400;
  return `${String(Math.floor(s / 3600)).padStart(2, '0')}:${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}`;
};

for (const date of process.argv.slice(2)) {
  const ymd = date.replaceAll('-', '');
  const ann = load(`trv_ann_${date}.json`).filter((a) => a.Advertised);
  // train ident -> Set of advertised departure HH:MM and owners/operators
  const trv = new Map();
  for (const a of ann) {
    const e = trv.get(a.AdvertisedTrainIdent) ?? trv.set(a.AdvertisedTrainIdent, { times: new Set(), ops: new Set(), products: new Set() }).get(a.AdvertisedTrainIdent);
    e.times.add(a.AdvertisedTimeAtLocation.slice(11, 16));
    e.ops.add(a.Operator ?? a.InformationOwner);
    for (const p of a.ProductInformation ?? []) e.products.add(p.Description);
  }
  const active = trips.filter((t) => sd.get(t.service_id)?.has(ymd));
  console.log(`\n# ${date}: ${active.length} active GTFS rail trips, ${trv.size} advertised Trafikverket trains`);

  const fields = {
    samtrafiken_internal_trip_number: (t) => t.samtrafiken_internal_trip_number,
    trip_short_name: (t) => t.trip_short_name,
    route_short_name: (t) => routes[t.route_id].route_short_name,
  };
  for (const [name, get] of Object.entries(fields)) {
    let filled = 0, inTrv = 0, timeOk = 0;
    for (const t of active) {
      const n = get(t);
      if (!n) continue;
      filled++;
      const e = trv.get(n);
      if (!e) continue;
      inTrv++;
      const st = stByTrip.get(t.trip_id) ?? [];
      if (st.some((s) => e.times.has(hhmm(s[4])) || e.times.has(hhmm(s[3])))) timeOk++;
    }
    console.log(`${name.padEnd(34)} filled ${filled}/${active.length}, number found in TRV ${inTrv}, number+time match ${timeOk} (${((100 * timeOk) / active.length).toFixed(1)}% of active)`);
  }

  // Per-operator detail using samtrafiken_internal_trip_number, with fallback trip_short_name.
  const per = new Map();
  const misses = new Map();
  const matchedTrv = new Set();
  for (const t of active) {
    const op = ops[t.trip_id] ?? '?';
    const p = per.get(op) ?? per.set(op, { n: 0, ok: 0, okShort: 0 }).get(op);
    p.n++;
    const st = stByTrip.get(t.trip_id) ?? [];
    const check = (num) => {
      const e = num && trv.get(num);
      return e && st.some((s) => e.times.has(hhmm(s[4])) || e.times.has(hhmm(s[3])));
    };
    if (check(t.samtrafiken_internal_trip_number)) { p.ok++; matchedTrv.add(t.samtrafiken_internal_trip_number); }
    else if (check(t.trip_short_name)) { p.okShort++; matchedTrv.add(t.trip_short_name); }
    else {
      const m = misses.get(op) ?? misses.set(op, []).get(op);
      if (m.length < 5) m.push(`${t.samtrafiken_internal_trip_number}/${t.trip_short_name || '-'} ${hhmm(st[0]?.[4] ?? '00:00:00')}`);
    }
  }
  console.log('\noperator | active trips | match via internal number | extra via trip_short_name | unmatched examples (internal/short dep)');
  for (const [op, p] of [...per].sort((a, b) => b[1].n - a[1].n)) {
    console.log(`${op} | ${p.n} | ${p.ok} (${((100 * p.ok) / p.n).toFixed(0)}%) | ${p.okShort} | ${(misses.get(op) ?? []).join(', ')}`);
  }
  // Trafikverket trains with no GTFS counterpart
  const orphan = new Map();
  for (const [id, e] of trv) {
    if (matchedTrv.has(id)) continue;
    const k = [...e.ops].join('/') + ' — ' + [...e.products].join('/');
    (orphan.get(k) ?? orphan.set(k, []).get(k)).push(id);
  }
  console.log(`\nTrafikverket advertised trains without a GTFS match: ${[...orphan.values()].reduce((s, v) => s + v.length, 0)}`);
  for (const [k, v] of [...orphan].sort((a, b) => b[1].length - a[1].length).slice(0, 25)) console.log(`  ${k}: ${v.length} e.g. ${v.slice(0, 6).join(', ')}`);
}
