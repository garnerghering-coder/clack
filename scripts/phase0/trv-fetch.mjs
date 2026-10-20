// Cache Trafikverket reference data for Phase 0 comparisons:
//   data/cache/phase0/trv_stations.json        all TrainStation rows
//   data/cache/phase0/trv_ann_<date>.json      advertised TrainAnnouncement rows for one date
// Usage: node scripts/phase0/trv-fetch.mjs stations | ann YYYY-MM-DD
import fs from 'node:fs';
import path from 'node:path';
import { CACHE, trvQuery } from './lib.mjs';

const OUT = path.join(CACHE, 'phase0');
fs.mkdirSync(OUT, { recursive: true });
const [what, date] = process.argv.slice(2);

if (what === 'stations') {
  let res;
  for (const v of ['1.5', '1.4']) {
    try {
      res = await trvQuery(`<QUERY objecttype="TrainStation" schemaversion="${v}"><FILTER/></QUERY>`);
      console.log(`TrainStation schemaversion ${v} ok`);
      break;
    } catch (e) {
      console.log(`TrainStation schemaversion ${v}: ${e.message.slice(0, 150)}`);
    }
  }
  const rows = res[0].TrainStation;
  fs.writeFileSync(path.join(OUT, 'trv_stations.json'), JSON.stringify(rows));
  console.log(`${rows.length} stations; sample:`, JSON.stringify(rows.find((s) => s.LocationSignature === 'Cst'), null, 1));
} else if (what === 'ann') {
  const fields = ['AdvertisedTrainIdent', 'LocationSignature', 'ActivityType', 'AdvertisedTimeAtLocation', 'TimeAtLocation',
    'TrackAtLocation', 'Canceled', 'Operator', 'InformationOwner', 'ProductInformation', 'ScheduledDepartureDateTime',
    'FromLocation', 'ToLocation', 'TypeOfTraffic', 'Advertised'];
  // Split the day into 4 chunks to keep each response modest.
  const rows = [];
  for (const [a, b] of [['00:00', '06:00'], ['06:00', '12:00'], ['12:00', '18:00'], ['18:00', '23:59:59']]) {
    const r = await trvQuery(`<QUERY objecttype="TrainAnnouncement" schemaversion="1.9">
      <FILTER><AND>
        <EQ name="ScheduledDepartureDateTime" value="${date}T00:00:00"/>
        <GTE name="AdvertisedTimeAtLocation" value="${date}T${a}"/>
        <LT name="AdvertisedTimeAtLocation" value="${date}T${b}"/>
      </AND></FILTER>
      ${fields.map((f) => `<INCLUDE>${f}</INCLUDE>`).join('')}
    </QUERY>`);
    rows.push(...(r[0].TrainAnnouncement ?? []));
  }
  // Also trains whose service day is `date` but that run past midnight.
  const late = await trvQuery(`<QUERY objecttype="TrainAnnouncement" schemaversion="1.9">
      <FILTER><AND><EQ name="ScheduledDepartureDateTime" value="${date}T00:00:00"/>
      <GT name="AdvertisedTimeAtLocation" value="${date}T23:59:59"/></AND></FILTER>
      ${fields.map((f) => `<INCLUDE>${f}</INCLUDE>`).join('')}</QUERY>`);
  rows.push(...(late[0].TrainAnnouncement ?? []));
  fs.writeFileSync(path.join(OUT, `trv_ann_${date}.json`), JSON.stringify(rows));
  const adv = rows.filter((r) => r.Advertised);
  console.log(`${date}: ${rows.length} rows (${adv.length} advertised), ${new Set(adv.map((r) => r.AdvertisedTrainIdent)).size} advertised trains`);
} else {
  console.error('usage: stations | ann YYYY-MM-DD');
}
