// Drops the `poi_hours` in a station's edits that the app's opening-hours parser can't read (packages/shared/src/hours.ts),
// so a researched string never turns into "hours not known" on screen. Usage: npx tsx scripts/stations/station3d/check_hours.ts <id>…
import fs from 'node:fs';
import { parseHours } from '../../../packages/shared/src/hours.js';

for (const id of process.argv.slice(2)) {
  const p = `scripts/stations/${id}.edits.json`;
  const e = JSON.parse(fs.readFileSync(p, 'utf8'));
  const hours: Record<string, { opening_hours: string }> = e.poi_hours ?? {};
  const bad = Object.entries(hours).filter(([, h]) => !parseHours(h.opening_hours));
  for (const [k] of bad) delete hours[k];
  fs.writeFileSync(p, JSON.stringify(e, null, 2) + '\n');
  console.log(`${id}: ${Object.keys(hours).length} hours kept, ${bad.length} dropped${bad.length ? ': ' + bad.map(([, h]) => h.opening_hours).slice(0, 3).join(' | ') : ''}`);
}
