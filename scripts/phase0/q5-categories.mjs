// Q5: how to tell intercity / regional / commuter / heritage / bus apart.
// Prints GTFS Sweden 3 route_type x operator, and Trafikverket ProductInformation x TypeOfTraffic x Operator.
import { load, tripOperators, serviceDates } from './p0data.mjs';

const date = process.argv[2] ?? '2026-10-19';
const routes = Object.fromEntries(load('routes.json').map((r) => [r.route_id, r]));
const ops = tripOperators();
const sd = serviceDates();
const ymd = date.replaceAll('-', '');
const g = new Map();
for (const t of load('trips.json')) {
  const r = routes[t.route_id];
  const k = `${r.route_type}\t${ops[t.trip_id] ?? '?'}`;
  const e = g.get(k) ?? g.set(k, { all: 0, day: 0 }).get(k);
  e.all++;
  if (sd.get(t.service_id)?.has(ymd)) e.day++;
}
console.log(`GTFS Sweden 3: route_type | operator | trips in feed | trips on ${date}`);
for (const [k, e] of [...g].sort()) console.log(`  ${k.replace('\t', ' | ')} | ${e.all} | ${e.day}`);

const ann = load(`trv_ann_${date}.json`).filter((a) => a.Advertised);
const t = new Map();
for (const a of ann) {
  const k = `${(a.ProductInformation ?? []).map((p) => p.Description).join('/') || '-'}\t${(a.TypeOfTraffic ?? []).map((p) => p.Description).join('/') || '-'}\t${a.Operator ?? '-'}`;
  const s = t.get(k) ?? t.set(k, new Set()).get(k);
  s.add(a.AdvertisedTrainIdent);
}
console.log(`\nTrafikverket ${date}: ProductInformation | TypeOfTraffic | Operator | trains`);
for (const [k, s] of [...t].sort((a, b) => b[1].size - a[1].size)) console.log(`  ${k.replaceAll('\t', ' | ')} | ${s.size}`);
