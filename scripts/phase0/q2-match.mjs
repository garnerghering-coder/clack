// Q2 (final): match each GTFS Sweden 3 rail trip to Trafikverket announcements and measure how many
// stop events would get actual times. Match key = (Trafikverket signature, activity, advertised local
// time); the train number is used to pick between candidates, but is not required, because numbers
// change mid-journey (Snälltåget Berlin night train = 300 to Malmö, then 3940 to Stockholm) and GTFS
// adds prefix digits (51168, 21376).
//
// Tiers per trip:  number   — the GTFS number itself has >= 2 matching stop events
//                  stripped — the 5-digit number minus its first digit has >= 2 matching events
//                  station  — some other Trafikverket train has >= 2 matching events
// Needs trv_ann_<date>.json for the date and its neighbours (after-midnight runs) and the station mapping.
// Usage: node scripts/phase0/q2-match.mjs 2026-10-19 2026-10-20
import fs from 'node:fs';
import path from 'node:path';
import { ROOT } from './lib.mjs';
import { load, P0, serviceDates, stopTimesByTrip, tripOperators } from './p0data.mjs';
import { gtfsTimeToSec, parseCsvLine } from './gtfs.mjs';

const dates = process.argv.slice(2);
// Not on Trafikverket's network at all (see DATA_FINDINGS §2): reported separately.
const NOT_IN_TRV = new Set(['Transdev', 'AB Stockholms Spårvägar', 'Arlanda Express']);

const csv = fs.readFileSync(path.join(ROOT, 'data/station_mapping.draft.csv'), 'utf8').trim().split('\n');
const head = parseCsvLine(csv[0]);
const sigOf = {};
for (const line of csv.slice(1)) {
  const r = Object.fromEntries(head.map((h, i) => [h, parseCsvLine(line)[i]]));
  if (r.trv_signature) sigOf[r.gtfs_stop_id] = r.trv_signature.toLowerCase();
}

// Pool every advertised row we have, keyed by (sig, activity, local minute).
const index = new Map();
const withActual = new Set(); // "train|event key" rows that carry TimeAtLocation
const typeOf = new Map(); // train ident -> Set(TypeOfTraffic)
for (const f of fs.readdirSync(P0).filter((f) => /^trv_ann_\d{4}-\d{2}-\d{2}\.json$/.test(f))) {
  for (const a of load(f)) {
    if (!a.Advertised) continue;
    const k = `${a.LocationSignature.toLowerCase()}|${a.ActivityType}|${a.AdvertisedTimeAtLocation.slice(0, 16)}`;
    (index.get(k) ?? index.set(k, []).get(k)).push(a.AdvertisedTrainIdent);
    if (a.TimeAtLocation) withActual.add(`${a.AdvertisedTrainIdent}|${k}`);
    const s = typeOf.get(a.AdvertisedTrainIdent) ?? typeOf.set(a.AdvertisedTrainIdent, new Set()).get(a.AdvertisedTrainIdent);
    for (const t of a.TypeOfTraffic ?? []) s.add(t.Description);
  }
}

/** GTFS service date + "HH:MM:SS" (may exceed 24h) -> local "YYYY-MM-DDTHH:MM". No DST change in the test dates. */
function localMinute(date, t) {
  const sec = gtfsTimeToSec(t);
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCSeconds(sec);
  return d.toISOString().slice(0, 16);
}

const stops = Object.fromEntries(load('stops.json').map((s) => [s.stop_id, s]));
const sd = serviceDates();
const st = stopTimesByTrip();
const ops = tripOperators();
const trips = load('trips.json');

for (const date of dates) {
  const per = new Map();
  const examples = [];
  for (const t of trips) {
    if (!sd.get(t.service_id)?.has(date.replaceAll('-', ''))) continue;
    const op = ops[t.trip_id];
    const sts = st.get(t.trip_id) ?? [];
    const events = [];
    sts.forEach((s, i) => {
      const sig = sigOf[stops[s[2]].parent_station || s[2]];
      if (!sig || sig.includes('.')) return; // unmapped or foreign (dk.kh, no.osl …): Trafikverket only reports Swedish stops reliably
      // Trafikverket doesn't advertise departures where boarding is forbidden (pickup_type=1) or arrivals
      // where alighting is forbidden (drop_off_type=1); passengers can't start/end a leg there anyway.
      if (i > 0 && s[6] !== '1') events.push(`${sig}|Ankomst|${localMinute(date, s[3])}`);
      if (i < sts.length - 1 && s[5] !== '1') events.push(`${sig}|Avgang|${localMinute(date, s[4])}`);
    });
    const hits = new Map(); // train -> Set(event idx)
    events.forEach((e, i) => { for (const n of index.get(e) ?? []) (hits.get(n) ?? hits.set(n, new Set()).get(n)).add(i); });
    const need = Math.min(2, events.length);
    const num = t.samtrafiken_internal_trip_number;
    const stripped = num.length === 5 ? String(+num.slice(1)) : null;
    let tier = 'none';
    const accepted = [];
    if (events.length && (hits.get(num)?.size ?? 0) >= need) { tier = 'number'; accepted.push(num); }
    else if (stripped && (hits.get(stripped)?.size ?? 0) >= need) { tier = 'stripped'; accepted.push(stripped); }
    // Other trains covering the remaining events (number changes mid-journey) also count.
    for (const [n, s] of hits) if (!accepted.includes(n) && s.size >= need && need > 0) accepted.push(n);
    if (tier === 'none' && accepted.length) tier = 'station';
    const covered = new Set();
    const actual = new Set();
    for (const n of accepted) for (const i of hits.get(n)) { covered.add(i); if (withActual.has(`${n}|${events[i]}`)) actual.add(i); }
    const isBus = accepted.length > 0 && accepted.every((n) => typeOf.get(n)?.has('Buss'));
    const p = per.get(op) ?? per.set(op, { trips: 0, number: 0, stripped: 0, station: 0, none: 0, bus: 0, ev: 0, cov: 0, act: 0 }).get(op);
    p.trips++; p[tier]++; p.ev += events.length; p.cov += covered.size; p.act += actual.size; if (isBus) p.bus++;
    if (process.env.DEBUG_OP === op) for (let i = 0; i < events.length; i++) if (!covered.has(i)) console.log(`  uncovered ${op} ${num}: ${events[i]} (trains hitting this trip: ${[...hits.keys()].join(',') || '-'})`);
    if ((tier === 'station' || accepted.length > 1) && examples.length < 12) examples.push(`${op} ${num}: ${tier}, Trafikverket trains ${accepted.join('+')} cover ${covered.size}/${events.length} events`);
  }
  console.log(`\n# ${date}`);
  console.log('operator | trips | by number | by stripped number | by station+time only | unmatched | of which bus | stop events matched | …with actual time');
  const tot = { trips: 0, matched: 0, ev: 0, cov: 0, act: 0 };
  for (const [op, p] of [...per].sort((a, b) => b[1].trips - a[1].trips)) {
    console.log(`${op}${NOT_IN_TRV.has(op) ? ' (not in TRV)' : ''} | ${p.trips} | ${p.number} | ${p.stripped} | ${p.station} | ${p.none} | ${p.bus} | ${p.ev ? ((100 * p.cov) / p.ev).toFixed(1) : '-'}% of ${p.ev} | ${p.ev ? ((100 * p.act) / p.ev).toFixed(1) : '-'}%`);
    if (NOT_IN_TRV.has(op) || op === 'Taxi') continue;
    tot.trips += p.trips; tot.matched += p.trips - p.none; tot.ev += p.ev; tot.cov += p.cov; tot.act += p.act;
  }
  console.log(`\nTOTAL excl. operators not in Trafikverket: trips matched ${tot.matched}/${tot.trips} (${((100 * tot.matched) / tot.trips).toFixed(1)}%), Swedish stop events matched ${tot.cov}/${tot.ev} (${((100 * tot.cov) / tot.ev).toFixed(2)}%), with an actual time ${tot.act}/${tot.ev} (${((100 * tot.act) / tot.ev).toFixed(2)}%; only meaningful for fully past dates)`);
  console.log('examples (multi-train / station-only matches):');
  for (const e of examples) console.log('  ' + e);
}
