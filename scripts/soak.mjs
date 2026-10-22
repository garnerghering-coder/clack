#!/usr/bin/env node
// Soak test (docs/RELIABILITY_PLAN.md §3): keeps the live map and trip streams open against a running server for a
// long time, the way a phone left on the map would, and samples /api/health every minute. Reports memory over time,
// restarts (uptime going back), stream drops and feed failures.
//
//   node scripts/soak.mjs [minutes=120] [base=http://127.0.0.1:3001] [--out=file.jsonl]
import fs from 'node:fs';

const minutes = Number(process.argv[2] ?? 120);
const base = process.argv[3] && !process.argv[3].startsWith('--') ? process.argv[3] : 'http://127.0.0.1:3001';
const out = process.argv.find((a) => a.startsWith('--out='))?.slice(6);
const end = Date.now() + minutes * 60_000;
const samples = [];
const drops = { map: 0, live: 0 };
const events = { map: 0, live: 0 };

/** Keeps an SSE stream open, reconnecting like a browser does, and counts what arrives. */
async function stream(name, path) {
  while (Date.now() < end) {
    try {
      const res = await fetch(base + path, { headers: { Accept: 'text/event-stream' }, signal: AbortSignal.timeout(end - Date.now()) });
      const reader = res.body.getReader();
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        events[name] += (new TextDecoder().decode(value).match(/\ndata:/g) ?? []).length;
      }
    } catch {
      // Timed out at the end, or the server went away.
    }
    if (Date.now() < end) {
      drops[name]++;
      await new Promise((r) => setTimeout(r, 5000));
    }
  }
}

async function sample() {
  const at = Date.now();
  try {
    const h = await (await fetch(`${base}/api/health`, { signal: AbortSignal.timeout(10_000) })).json();
    const s = { at, ok: true, uptimeS: h.uptimeS, rss: h.memoryMb.rss, heap: h.memoryMb.heap, feeds: Object.fromEntries(Object.entries(h.feeds).map(([k, v]) => [k, v.status])), gps: h.gps, events: { ...events }, drops: { ...drops } };
    samples.push(s);
    if (out) fs.appendFileSync(out, JSON.stringify(s) + '\n');
  } catch (e) {
    samples.push({ at, ok: false, error: e.message });
  }
}

void stream('map', '/api/live/trains/stream');
void stream('live', '/api/live/stream');
await sample();
const timer = setInterval(sample, 60_000);
await new Promise((r) => setTimeout(r, end - Date.now()));
clearInterval(timer);
await sample();

const ok = samples.filter((s) => s.ok);
const restarts = ok.filter((s, i) => i > 0 && s.uptimeS < ok[i - 1].uptimeS).length;
const half = Math.floor(ok.length / 2);
const avg = (xs) => (xs.length ? Math.round(xs.reduce((a, b) => a + b, 0) / xs.length) : null);
const notOk = ok.flatMap((s) => Object.entries(s.feeds).filter(([, v]) => v !== 'ok').map(([k, v]) => `${new Date(s.at).toISOString().slice(11, 16)} ${k} ${v}`));
console.log(
  JSON.stringify(
    {
      minutes,
      samples: samples.length,
      unanswered: samples.length - ok.length,
      restarts,
      rssMb: { first: ok[0]?.rss, last: ok.at(-1)?.rss, max: Math.max(...ok.map((s) => s.rss)), firstHalfAvg: avg(ok.slice(0, half).map((s) => s.rss)), secondHalfAvg: avg(ok.slice(half).map((s) => s.rss)) },
      heapMb: { first: ok[0]?.heap, last: ok.at(-1)?.heap, max: Math.max(...ok.map((s) => s.heap)) },
      streamEvents: events,
      streamDrops: drops,
      feedNotOk: notOk.slice(0, 20),
      gps: ok.at(-1)?.gps,
    },
    null,
    2,
  ),
);
process.exit(0);
