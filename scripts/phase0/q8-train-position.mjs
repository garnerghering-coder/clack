// Q8: which running trains report a live position (Trafikverket TrainPosition 1.1), how fresh, how often?
// Takes N samples, 30 s apart. Compares against trains advertised around "now" in TrainAnnouncement.
// Usage: node scripts/phase0/q8-train-position.mjs [samples=4]
import { trvQuery } from './lib.mjs';

const samples = Number(process.argv[2] ?? 4);
const iso = (ms) => new Date(ms).toISOString();

async function positions() {
  const since = iso(Date.now() - 15 * 60e3);
  const r = await trvQuery(`<QUERY objecttype="TrainPosition" namespace="järnväg.trafikinfo" schemaversion="1.1">
    <FILTER><GT name="TimeStamp" value="${since}"/></FILTER></QUERY>`);
  return r[0].TrainPosition ?? [];
}

async function runningTrains() {
  // Trains with an advertised stop within ±20 min of now, not cancelled: "should be running".
  const r = await trvQuery(`<QUERY objecttype="TrainAnnouncement" schemaversion="1.9">
    <FILTER><EQ name="Advertised" value="true"/><EQ name="Canceled" value="false"/>
      <GT name="AdvertisedTimeAtLocation" value="${iso(Date.now() - 20 * 60e3)}"/>
      <LT name="AdvertisedTimeAtLocation" value="${iso(Date.now() + 20 * 60e3)}"/></FILTER>
    <INCLUDE>AdvertisedTrainIdent</INCLUDE><INCLUDE>ProductInformation</INCLUDE><INCLUDE>TypeOfTraffic</INCLUDE><INCLUDE>Operator</INCLUDE></QUERY>`);
  const m = new Map();
  for (const a of r[0].TrainAnnouncement ?? []) {
    const product = (a.ProductInformation ?? []).map((p) => p.Description).join('/') || '-';
    const type = (a.TypeOfTraffic ?? []).map((p) => p.Description).join('/') || '-';
    m.set(a.AdvertisedTrainIdent, { product, type, operator: a.Operator ?? '-' });
  }
  return m;
}

const seen = new Map(); // train -> list of TimeStamps
let lastRunning;
for (let i = 0; i < samples; i++) {
  const t0 = Date.now();
  const [pos, running] = await Promise.all([positions(), runningTrains()]);
  lastRunning = running;
  const ages = pos.map((p) => (t0 - Date.parse(p.TimeStamp)) / 1000).sort((a, b) => a - b);
  const active = pos.filter((p) => p.Status?.Active).length;
  for (const p of pos) {
    const n = p.Train.AdvertisedTrainNumber ?? p.Train.OperationalTrainNumber;
    (seen.get(n) ?? seen.set(n, []).get(n)).push(p.TimeStamp);
  }
  console.log(`sample ${i + 1} @ ${new Date(t0).toISOString()}: ${pos.length} positions in last 15 min (${active} Active=true); age median ${ages[ages.length >> 1]?.toFixed(0)} s, p90 ${ages[Math.floor(ages.length * 0.9)]?.toFixed(0)} s; ${running.size} trains advertised ±20 min`);
  if (i < samples - 1) await new Promise((r) => setTimeout(r, 30e3));
}

// Coverage by product: running trains that had a position in any sample.
const by = new Map();
for (const [n, info] of lastRunning) {
  const k = `${info.product} | ${info.type} | ${info.operator}`;
  const e = by.get(k) ?? by.set(k, { n: 0, pos: 0 }).get(k);
  e.n++;
  if (seen.has(n)) e.pos++;
}
console.log('\nproduct | type | operator | running trains | with position');
for (const [k, e] of [...by].sort((a, b) => b[1].n - a[1].n)) console.log(`  ${k} | ${e.n} | ${e.pos} (${((100 * e.pos) / e.n).toFixed(0)}%)`);
const tot = [...by.values()].reduce((a, e) => ({ n: a.n + e.n, pos: a.pos + e.pos }), { n: 0, pos: 0 });
console.log(`TOTAL ${tot.pos}/${tot.n} running trains had a position (${((100 * tot.pos) / tot.n).toFixed(0)}%)`);

// Update interval: distinct TimeStamps per train across samples.
const gaps = [];
for (const ts of seen.values()) {
  const u = [...new Set(ts)].map(Date.parse).sort((a, b) => a - b);
  for (let i = 1; i < u.length; i++) gaps.push((u[i] - u[i - 1]) / 1000);
}
gaps.sort((a, b) => a - b);
console.log(`position updates between samples: ${gaps.length}; interval median ${gaps[gaps.length >> 1]?.toFixed(0)} s, p90 ${gaps[Math.floor(gaps.length * 0.9)]?.toFixed(0)} s`);
const unchanged = [...seen.values()].filter((ts) => ts.length === samples && new Set(ts).size === 1).length;
console.log(`trains seen in every sample with an unchanged timestamp (stale/parked): ${unchanged}`);
