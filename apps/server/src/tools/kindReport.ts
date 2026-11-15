// Which saved trips change their kind of train under legs/product.ts, against the old rule (the timetable's route_type,
// else the trip's category). Read-only; counts and train numbers only, no users.
//     npx tsx src/tools/kindReport.ts <db file>
import { openDb } from '../db/client.js';
import { legs, stations } from '../db/schema.js';
import { classifyProduct, kindLists, routeTypes } from '../legs/product.js';
import { productOf } from '../search/timetable.js';

const db = openDb(process.argv[2] ?? 'data/app.db');
const rows = db.select({ op: legs.operatorId, n: legs.trainNumber, cat: legs.category, key: legs.timetableTripKey, user: legs.userProduct, origin: legs.originStationId }).from(legs).all();
const country = new Map(db.select({ id: stations.id, c: stations.country }).from(stations).all().map((s) => [s.id, s.c]));
const types = routeTypes(db, rows.map((r) => r.key));
const lists = kindLists(db);
const moves = new Map<string, { count: number; trains: Set<string> }>();
for (const r of rows) {
  const rt = (r.key && types.get(r.key)) || null;
  const before = productOf(rt ?? '', r.cat ?? 'regional');
  const after = classifyProduct({ country: country.get(r.origin) ?? null, operatorId: r.op, trainNumber: r.n, category: r.cat, routeType: rt, userProduct: r.user }, lists).product;
  if (before === after) continue;
  const k = `${before} → ${after}`;
  const m = moves.get(k) ?? moves.set(k, { count: 0, trains: new Set() }).get(k)!;
  m.count++;
  m.trains.add(`${r.op ?? '?'} ${r.n ?? '?'}`);
}
console.log(`${rows.length} trips; ${[...moves.values()].reduce((n, m) => n + m.count, 0)} change kind`);
for (const [k, m] of [...moves].sort((a, b) => b[1].count - a[1].count)) console.log(`${k}: ${m.count} (${[...m.trains].slice(0, 12).join(', ')})`);
