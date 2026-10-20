// Q1: how far back does Trafikverket keep TrainAnnouncement rows, and actual times (TimeAtLocation)?
// Usage: node scripts/phase0/trv-history-window.mjs [trainIdent...]
import { trvQuery } from './lib.mjs';

const trains = process.argv.slice(2).length ? process.argv.slice(2) : ['423', '523'];
const OFFSETS = [1, 2, 3, 5, 7, 10, 14, 21, 30, 60, 90, 180, 365];

function isoDate(daysAgo) {
  const d = new Date(Date.now() - daysAgo * 86400e3);
  return d.toISOString().slice(0, 10);
}

async function day(train, date) {
  const r = await trvQuery(`<QUERY objecttype="TrainAnnouncement" schemaversion="1.9">
    <FILTER>
      <EQ name="AdvertisedTrainIdent" value="${train}"/>
      <GTE name="AdvertisedTimeAtLocation" value="${date}T00:00:00"/>
      <LT name="AdvertisedTimeAtLocation" value="${date}T23:59:59"/>
    </FILTER>
    <INCLUDE>LocationSignature</INCLUDE><INCLUDE>ActivityType</INCLUDE>
    <INCLUDE>TimeAtLocation</INCLUDE><INCLUDE>TrackAtLocation</INCLUDE>
    <INCLUDE>Canceled</INCLUDE><INCLUDE>Advertised</INCLUDE>
  </QUERY>`);
  const rows = r[0].TrainAnnouncement ?? [];
  return {
    rows: rows.length,
    advertised: rows.filter((a) => a.Advertised).length,
    withActual: rows.filter((a) => a.TimeAtLocation).length,
    withTrack: rows.filter((a) => a.TrackAtLocation).length,
    canceled: rows.filter((a) => a.Canceled).length,
  };
}

async function earliest(train) {
  const r = await trvQuery(`<QUERY objecttype="TrainAnnouncement" schemaversion="1.9" orderby="AdvertisedTimeAtLocation" limit="1">
    <FILTER><EQ name="AdvertisedTrainIdent" value="${train}"/></FILTER>
    <INCLUDE>AdvertisedTimeAtLocation</INCLUDE><INCLUDE>TimeAtLocation</INCLUDE>
  </QUERY>`);
  return r[0].TrainAnnouncement?.[0];
}

async function latest(train) {
  const r = await trvQuery(`<QUERY objecttype="TrainAnnouncement" schemaversion="1.9" orderby="AdvertisedTimeAtLocation desc" limit="1">
    <FILTER><EQ name="AdvertisedTrainIdent" value="${train}"/></FILTER>
    <INCLUDE>AdvertisedTimeAtLocation</INCLUDE>
  </QUERY>`);
  return r[0].TrainAnnouncement?.[0];
}

for (const train of trains) {
  console.log(`\n## Train ${train}`);
  console.log('earliest row:', JSON.stringify(await earliest(train)));
  console.log('latest row:  ', JSON.stringify(await latest(train)));
  console.log('days_ago | date       | rows | advertised | with TimeAtLocation | with track | canceled');
  for (const off of OFFSETS) {
    const date = isoDate(off);
    const s = await day(train, date);
    console.log(`${String(off).padStart(8)} | ${date} | ${String(s.rows).padStart(4)} | ${String(s.advertised).padStart(10)} | ${String(s.withActual).padStart(19)} | ${String(s.withTrack).padStart(10)} | ${s.canceled}`);
  }
}
