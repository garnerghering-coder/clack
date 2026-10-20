// Q5 check: run data/category_overrides.json over every GTFS Sweden 3 rail trip on <date>, twice:
//   "live"       — with Trafikverket ProductInformation/TypeOfTraffic for that train+date
//   "historical" — GTFS-only (what we'd know for a past trip outside Trafikverket's window)
// Prints operator × category for both and where they disagree. Requires q3 (station mapping) first.
// Usage: node scripts/phase0/q5-classify.mjs 2026-10-20
import fs from 'node:fs';
import path from 'node:path';
import { ROOT } from './lib.mjs';
import { load, serviceDates, stopTimesByTrip, tripOperators } from './p0data.mjs';
import { parseCsvLine } from './gtfs.mjs';

const date = process.argv[2] ?? '2026-10-20';
const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/category_overrides.json'), 'utf8'));

// station mapping: gtfs parent id -> { sig, kind }
const csv = fs.readFileSync(path.join(ROOT, 'data/station_mapping.draft.csv'), 'utf8').trim().split('\n');
const head = parseCsvLine(csv[0]);
const mapping = {};
for (const line of csv.slice(1)) {
  const v = parseCsvLine(line);
  const r = Object.fromEntries(head.map((h, i) => [h, v[i]]));
  mapping[r.gtfs_stop_id] = { sig: r.trv_signature, kind: r.kind };
}

const asList = (x) => (Array.isArray(x) ? x : [x]);
/** Does `facts` satisfy every condition in `match`? Unknown facts (undefined) never match. */
function matches(match, f) {
  for (const [k, want] of Object.entries(match)) {
    switch (k) {
      case 'gtfs_route_type': case 'gtfs_operator': case 'gtfs_route_short_name': case 'trv_product': case 'trv_type_of_traffic': {
        const have = f[k] ?? [];
        if (!asList(have).some((h) => asList(want).includes(h))) return false;
        break;
      }
      case 'not_gtfs_route_short_name':
        if (asList(want).includes(f.gtfs_route_short_name)) return false;
        break;
      case 'has_non_rail_stop':
        if (f.has_non_rail_stop !== want) return false;
        break;
      case 'all_stops_trv_signature_in':
        if (!f.stop_sigs.length || !f.stop_sigs.every((s) => s && want.includes(s))) return false;
        break;
      default:
        throw new Error(`unknown match key ${k}`);
    }
  }
  return true;
}
export function classify(f) {
  for (const e of cfg.exclude) if (matches(e.match, f)) return `EXCLUDED`;
  for (const r of cfg.rules) if (matches(r.match, f)) return r.category;
  return 'UNCLASSIFIED';
}

const routes = Object.fromEntries(load('routes.json').map((r) => [r.route_id, r]));
const stops = Object.fromEntries(load('stops.json').map((s) => [s.stop_id, s]));
const ops = tripOperators();
const sd = serviceDates();
const st = stopTimesByTrip();
const ann = load(`trv_ann_${date}.json`).filter((a) => a.Advertised);
const trv = new Map();
for (const a of ann) {
  const e = trv.get(a.AdvertisedTrainIdent) ?? trv.set(a.AdvertisedTrainIdent, { product: new Set(), type: new Set() }).get(a.AdvertisedTrainIdent);
  for (const p of a.ProductInformation ?? []) e.product.add(p.Description);
  for (const p of a.TypeOfTraffic ?? []) e.type.add(p.Description);
}
const lookup = (n) => trv.get(n) ?? (n?.length === 5 ? trv.get(String(+n.slice(1))) : undefined);

const table = new Map();
const diffs = new Map();
for (const t of load('trips.json')) {
  if (!sd.get(t.service_id)?.has(date.replaceAll('-', ''))) continue;
  const r = routes[t.route_id];
  const sts = st.get(t.trip_id) ?? [];
  const parents = sts.map((s) => stops[s[2]].parent_station || s[2]);
  const base = {
    gtfs_route_type: r.route_type,
    gtfs_operator: ops[t.trip_id],
    gtfs_route_short_name: r.route_short_name,
    has_non_rail_stop: parents.some((p) => mapping[p]?.kind === 'bus_stop_or_unknown'),
    stop_sigs: parents.map((p) => mapping[p]?.sig),
  };
  const e = lookup(t.samtrafiken_internal_trip_number);
  const live = classify({ ...base, trv_product: e ? [...e.product] : undefined, trv_type_of_traffic: e ? [...e.type] : undefined });
  const hist = classify(base);
  const k = base.gtfs_operator;
  const row = table.get(k) ?? table.set(k, {}).get(k);
  row[live] = (row[live] ?? 0) + 1;
  if (live !== hist) {
    const dk = `${k}: live=${live} historical=${hist}`;
    diffs.set(dk, (diffs.get(dk) ?? 0) + 1);
  }
}
const cats = ['intercity', 'regional', 'commuter', 'heritage', 'EXCLUDED', 'UNCLASSIFIED'];
console.log(`# ${date} — category per operator (live, with Trafikverket facts)`);
console.log(`operator | ${cats.join(' | ')}`);
for (const [op, row] of [...table].sort()) console.log(`${op} | ${cats.map((c) => row[c] ?? 0).join(' | ')}`);
console.log(`\nlive vs historical (GTFS-only) disagreements: ${[...diffs.values()].reduce((a, b) => a + b, 0)}`);
for (const [k, n] of [...diffs].sort((a, b) => b[1] - a[1])) console.log(`  ${k}: ${n}`);
