// Q9: Trafikverket server-sent events (sseurl="true") vs incremental polling (changeid) for TrainAnnouncement,
// run side by side on the same running trains, plus a TrainPosition stream at the same time.
// Usage: node scripts/phase0/q9-stream-vs-poll.mjs [seconds=120] [trains=8]
import { trvQuery } from './lib.mjs';

const SECONDS = Number(process.argv[2] ?? 120);
const N = Number(process.argv[3] ?? 8);
const iso = (ms) => new Date(ms).toISOString();

// Pick N trains (not buses) with a stop in the next 20 minutes.
const r0 = await trvQuery(`<QUERY objecttype="TrainAnnouncement" schemaversion="1.9">
  <FILTER><EQ name="Advertised" value="true"/><GT name="AdvertisedTimeAtLocation" value="${iso(Date.now())}"/>
  <LT name="AdvertisedTimeAtLocation" value="${iso(Date.now() + 20 * 60e3)}"/></FILTER>
  <INCLUDE>AdvertisedTrainIdent</INCLUDE><INCLUDE>TypeOfTraffic</INCLUDE></QUERY>`);
const trains = [...new Set((r0[0].TrainAnnouncement ?? []).filter((a) => !(a.TypeOfTraffic ?? []).some((t) => t.Description === 'Buss')).map((a) => a.AdvertisedTrainIdent))].slice(0, N);
console.log(`tracking ${trains.length} trains: ${trains.join(', ')}`);
const filter = `<FILTER><OR>${trains.map((t) => `<EQ name="AdvertisedTrainIdent" value="${t}"/>`).join('')}</OR>
  <GT name="AdvertisedTimeAtLocation" value="${iso(Date.now() - 6 * 3600e3)}"/>
  <LT name="AdvertisedTimeAtLocation" value="${iso(Date.now() + 6 * 3600e3)}"/></FILTER>`;
const annQuery = (attrs) => `<QUERY objecttype="TrainAnnouncement" schemaversion="1.9" ${attrs}>${filter}</QUERY>`;

// ---- SSE
async function openStream(label, query, onRows) {
  const r = await trvQuery(query);
  const url = r[0].INFO?.SSEURL;
  if (!url) throw new Error(`${label}: no SSEURL in response: ${JSON.stringify(r[0].INFO)}`);
  console.log(`${label}: initial rows ${Object.values(r[0]).find(Array.isArray)?.length ?? 0}, SSEURL host ${new URL(url).host}`);
  const ctrl = new AbortController();
  const stats = { events: 0, rows: 0, lags: [], ids: 0, comments: 0, bytes: 0, opened: Date.now(), error: null };
  (async () => {
    try {
      const res = await fetch(url, { headers: { Accept: 'text/event-stream' }, signal: ctrl.signal });
      console.log(`${label}: stream HTTP ${res.status} ${res.headers.get('content-type')}`);
      const dec = new TextDecoder();
      let buf = '';
      for await (const chunk of res.body) {
        stats.bytes += chunk.length;
        if (!stats.sample) stats.sample = dec.decode(chunk.slice(0, 160));
        buf += dec.decode(chunk, { stream: true }).replace(/\r\n?/g, '\n');
        let i;
        while ((i = buf.indexOf('\n\n')) >= 0) {
          const block = buf.slice(0, i);
          buf = buf.slice(i + 2);
          if (block.startsWith(':')) { stats.comments++; continue; }
          if (/^id:/m.test(block)) stats.ids++;
          const data = block.split('\n').filter((l) => l.startsWith('data:')).map((l) => l.slice(5)).join('');
          if (!data) continue;
          stats.events++;
          const rows = Object.values(JSON.parse(data).RESPONSE.RESULT[0]).find(Array.isArray) ?? [];
          stats.rows += rows.length;
          for (const row of rows) if (row.ModifiedTime) stats.lags.push((Date.now() - Date.parse(row.ModifiedTime)) / 1000);
          onRows?.(rows);
        }
      }
      stats.error = 'stream ended by server';
    } catch (e) {
      if (e.name !== 'AbortError') stats.error = String(e);
    }
  })();
  return { stats, close: () => ctrl.abort() };
}

const sseAnn = await openStream('SSE TrainAnnouncement', annQuery('sseurl="true"'));
const ssePos = await openStream(
  'SSE TrainPosition',
  `<QUERY objecttype="TrainPosition" namespace="järnväg.trafikinfo" schemaversion="1.1" sseurl="true"><FILTER><OR>${trains
    .map((t) => `<EQ name="Train.AdvertisedTrainNumber" value="${t}"/>`)
    .join('')}</OR></FILTER></QUERY>`,
);

// ---- Polling with changeid (only rows changed since the last call come back)
const poll = { calls: 0, rows: 0, lags: [], errors: 0 };
let changeId = '0';
const first = await trvQuery(annQuery(`changeid="${changeId}"`));
changeId = first[0].INFO?.LASTCHANGEID ?? '0';
console.log(`poll: initial rows ${first[0].TrainAnnouncement?.length ?? 0}, LASTCHANGEID ${changeId}`);
const timer = setInterval(async () => {
  try {
    const t = Date.now();
    const r = await trvQuery(annQuery(`changeid="${changeId}"`));
    poll.calls++;
    changeId = r[0].INFO?.LASTCHANGEID ?? changeId;
    const rows = r[0].TrainAnnouncement ?? [];
    poll.rows += rows.length;
    for (const row of rows) if (row.ModifiedTime) poll.lags.push((t - Date.parse(row.ModifiedTime)) / 1000);
  } catch {
    poll.errors++;
  }
}, 20e3);

await new Promise((r) => setTimeout(r, SECONDS * 1000));
clearInterval(timer);
sseAnn.close();
ssePos.close();

const med = (a) => { const s = [...a].sort((x, y) => x - y); return s.length ? s[s.length >> 1].toFixed(1) : '-'; };
const p90 = (a) => { const s = [...a].sort((x, y) => x - y); return s.length ? s[Math.floor(s.length * 0.9)].toFixed(1) : '-'; };
for (const [label, s] of [['SSE TrainAnnouncement', sseAnn.stats], ['SSE TrainPosition', ssePos.stats]]) {
  console.log(`${label} first bytes: ${JSON.stringify(s.sample)}`);
  console.log(`${label}: ${s.events} events, ${s.rows} rows, ${s.comments} keep-alive comments, events with id: ${s.ids}, ${(s.bytes / 1024).toFixed(0)} KiB; lag (receive − ModifiedTime) median ${med(s.lags)} s, p90 ${p90(s.lags)} s; ${s.error ?? 'open until closed'}`);
}
console.log(`POLL (every 20 s, changeid): ${poll.calls} calls, ${poll.rows} changed rows, ${poll.errors} errors; lag median ${med(poll.lags)} s, p90 ${p90(poll.lags)} s`);
