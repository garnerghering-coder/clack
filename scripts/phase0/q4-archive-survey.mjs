// Q4: survey the keyless GTFS Sverige 2 archive: snapshots per year, biggest gaps between snapshots,
// and (with --windows) the service-date window of one snapshot per year, to check that every past date
// is covered by some snapshot. Downloads with --windows go to data/cache/sv2_archive/survey/ and are
// deleted after reading.
// Usage: node scripts/phase0/q4-archive-survey.mjs [--windows]
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { CACHE } from './lib.mjs';
import { readAll, readGtfs } from './gtfs.mjs';

const BASE = 'https://data.samtrafiken.se/trafiklab/gtfs-sverige-2';
async function listing(url) {
  for (let attempt = 0; attempt < 4; attempt++) {
    try {
      const res = await fetch(url);
      if (res.ok) return await res.text();
    } catch {}
    await new Promise((r) => setTimeout(r, 2000 * 2 ** attempt));
  }
  throw new Error(`listing failed: ${url}`);
}
const snaps = [];
for (let y = 2012; y <= 2026; y++) {
  for (const m of [...(await listing(`${BASE}/${y}/`)).matchAll(/href="(\d\d)\/"/g)].map((x) => x[1])) {
    const html = await listing(`${BASE}/${y}/${m}/`);
    for (const x of html.matchAll(/href="((?:trafiklab|sweden)-(\d{8})\.zip)"[^\n]*?\s(\d+[KMG]?)\s*$/gm)) {
      snaps.push({ file: `${y}/${m}/${x[1]}`, date: x[2], size: x[3] });
    }
  }
}
snaps.sort((a, b) => a.date.localeCompare(b.date));
const toDate = (s) => new Date(`${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6)}T00:00:00Z`);
console.log(`snapshots: ${snaps.length}, first ${snaps[0].date}, last ${snaps.at(-1).date}`);
const perYear = {};
for (const s of snaps) perYear[s.date.slice(0, 4)] = (perYear[s.date.slice(0, 4)] ?? 0) + 1;
console.log('per year:', Object.entries(perYear).map(([y, n]) => `${y}:${n}`).join(' '));
const gaps = [];
for (let i = 1; i < snaps.length; i++) gaps.push({ days: (toDate(snaps[i].date) - toDate(snaps[i - 1].date)) / 86400e3, from: snaps[i - 1].date, to: snaps[i].date });
gaps.sort((a, b) => b.days - a.days);
console.log('largest gaps between snapshots:', gaps.slice(0, 10).map((g) => `${g.days}d (${g.from}→${g.to})`).join(', '));

if (process.argv.includes('--windows')) {
  const dir = path.join(CACHE, 'sv2_archive/survey');
  fs.mkdirSync(dir, { recursive: true });
  // One snapshot per year (first available), plus the snapshots just before the largest gaps.
  const pick = new Map();
  for (const s of snaps) if (!pick.has(s.date.slice(0, 4))) pick.set(s.date.slice(0, 4), s);
  for (const g of gaps.slice(0, 3)) { const s = snaps.find((x) => x.date === g.from); pick.set(`gap-${g.from}`, s); }
  console.log('\nsnapshot | service window | days | rail trips');
  for (const s of pick.values()) {
    const f = path.join(dir, path.basename(s.file));
    execFileSync('curl', ['-sS', '-m', '900', '--retry', '3', '-o', f, `${BASE}/${s.file}`]);
    let min = '99999999', max = '0';
    for (const c of await readAll(f, 'calendar.txt')) { if (c.start_date < min) min = c.start_date; if (c.end_date > max) max = c.end_date; }
    for await (const c of readGtfs(f, 'calendar_dates.txt')) { if (c.exception_type !== '1') continue; if (c.date < min) min = c.date; if (c.date > max) max = c.date; }
    const routes = new Map((await readAll(f, 'routes.txt')).map((r) => [r.route_id, r.route_type]));
    let rail = 0;
    for await (const t of readGtfs(f, 'trips.txt')) { const rt = routes.get(t.route_id); if (rt === '2' || (+rt >= 100 && +rt < 200)) rail++; }
    console.log(`${s.date} | ${min}..${max} | ${(toDate(max) - toDate(min)) / 86400e3} | ${rail}`);
    fs.unlinkSync(f);
  }
}
