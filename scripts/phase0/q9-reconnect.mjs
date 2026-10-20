// Q9 (reconnect): does Trafikverket's SSE stream resume after a disconnect, and does Last-Event-ID replay
// what was missed? Opens a TrainPosition stream for running trains, drops it, waits, reconnects with the last id.
import { trvQuery } from './lib.mjs';

const r = await trvQuery(`<QUERY objecttype="TrainPosition" namespace="järnväg.trafikinfo" schemaversion="1.1" sseurl="true">
  <FILTER><GT name="TimeStamp" value="${new Date(Date.now() - 60e3).toISOString()}"/></FILTER></QUERY>`);
const url = r[0].INFO.SSEURL;

async function listen(seconds, lastId) {
  const ctrl = new AbortController();
  const out = { events: 0, firstId: null, lastId: null, oldest: null, status: null };
  const done = (async () => {
    try {
      const res = await fetch(url, { headers: { Accept: 'text/event-stream', ...(lastId ? { 'Last-Event-ID': lastId } : {}) }, signal: ctrl.signal });
      out.status = res.status;
      const dec = new TextDecoder();
      let buf = '';
      for await (const chunk of res.body) {
        buf += dec.decode(chunk, { stream: true }).replace(/\r\n?/g, '\n');
        let i;
        while ((i = buf.indexOf('\n\n')) >= 0) {
          const block = buf.slice(0, i);
          buf = buf.slice(i + 2);
          const id = block.match(/^id:\s*(.*)$/m)?.[1];
          const data = block.split('\n').filter((l) => l.startsWith('data:')).map((l) => l.slice(5)).join('');
          if (!data) continue;
          out.events++;
          out.firstId ??= id;
          out.lastId = id ?? out.lastId;
          for (const row of JSON.parse(data).RESPONSE.RESULT[0].TrainPosition ?? []) {
            const t = Date.parse(row.ModifiedTime);
            if (!out.oldest || t < out.oldest) out.oldest = t;
          }
        }
      }
    } catch (e) {
      if (e.name !== 'AbortError') out.status = String(e);
    }
  })();
  await new Promise((r) => setTimeout(r, seconds * 1000));
  ctrl.abort();
  await done;
  return out;
}

const a = await listen(25);
console.log(`first connection: HTTP ${a.status}, ${a.events} events, ids ${a.firstId} … ${a.lastId}`);
const gapStart = Date.now();
await new Promise((r) => setTimeout(r, 20e3));
const b = await listen(15, a.lastId);
console.log(`reconnect after 20 s with Last-Event-ID: HTTP ${b.status}, ${b.events} events, first id ${b.firstId}`);
console.log(`replayed data from the gap: ${b.oldest && b.oldest < gapStart ? `yes (oldest ModifiedTime ${Math.round((gapStart - b.oldest) / 1000)} s before reconnect)` : 'no (only new data after reconnect)'}`);
const c = await listen(10);
console.log(`same SSEURL reused later without id: HTTP ${c.status}, ${c.events} events`);
