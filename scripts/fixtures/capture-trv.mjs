// Save Trafikverket's raw TrainAnnouncement rows (all fields, advertised and passage points) for
// given trains on a date, before they expire from Trafikverket's ~4-day window. Used as test fixtures.
// Usage: node scripts/fixtures/capture-trv.mjs 2026-10-20 306 7256
// Writes data/fixtures/trv/<date>/train-<n>.json (overwrites, so it can be re-run once a trip finishes).
import fs from 'node:fs';
import path from 'node:path';
import { ROOT, trvQuery } from '../phase0/lib.mjs';

const [date, ...trains] = process.argv.slice(2);
const dir = path.join(ROOT, 'data/fixtures/trv', date);
fs.mkdirSync(dir, { recursive: true });
const next = new Date(Date.parse(`${date}T12:00:00Z`) + 86400e3).toISOString().slice(0, 10);
for (const n of trains) {
  // Calendar day plus early next morning, to include runs that pass midnight.
  const r = await trvQuery(`<QUERY objecttype="TrainAnnouncement" schemaversion="1.9" orderby="AdvertisedTimeAtLocation">
    <FILTER><EQ name="AdvertisedTrainIdent" value="${n}"/>
      <GTE name="AdvertisedTimeAtLocation" value="${date}T00:00:00"/><LT name="AdvertisedTimeAtLocation" value="${next}T06:00:00"/></FILTER>
  </QUERY>`);
  const rows = r[0].TrainAnnouncement ?? [];
  const out = { captured_at: new Date().toISOString(), date, train: n, source: 'Trafikverket TrainAnnouncement 1.9', rows };
  fs.writeFileSync(path.join(dir, `train-${n}.json`), JSON.stringify(out, null, 1));
  const adv = rows.filter((x) => x.Advertised);
  console.log(`${n}: ${rows.length} rows (${adv.length} advertised, ${adv.filter((x) => x.TimeAtLocation).length} with actual time)`);
}
