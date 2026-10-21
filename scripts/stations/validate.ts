// Checks every station map in data/stations (ADDITIONS_01 C). Also runs in `npm test` (apps/server/test/stationMaps.test.ts).
// Usage: npm run stations:validate
import fs from 'node:fs';
import path from 'node:path';
import { validateStationMap, type StationMap } from '../../packages/shared/src/station.ts';

const dir = path.join(import.meta.dirname, '../../data/stations');
let bad = 0;
for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.json'))) {
  const m = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')) as StationMap;
  const errors = validateStationMap(m);
  console.log(`${errors.length ? '✗' : '✓'} ${m.name} (${f}): ${m.platforms.length} platforms, ${m.nodes.length} nodes, ${m.edges.length} edges, ${m.pois.length} amenities`);
  for (const e of errors) console.log(`    ${e}`);
  if (errors.length) bad++;
}
process.exit(bad ? 1 : 0);
