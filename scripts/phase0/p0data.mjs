// Loads the extracted rail subset (see gtfs-extract-rail.mjs) with a few derived lookups.
import fs from 'node:fs';
import path from 'node:path';
import { CACHE } from './lib.mjs';

export const P0 = path.join(CACHE, 'phase0');
export const load = (name) => JSON.parse(fs.readFileSync(path.join(P0, name), 'utf8'));

/** service_id -> Set of YYYYMMDD dates it runs. */
export function serviceDates() {
  const map = new Map();
  const add = (sid, d) => (map.get(sid) ?? map.set(sid, new Set()).get(sid)).add(d);
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  for (const c of load('calendar.json')) {
    const start = new Date(`${c.start_date.slice(0, 4)}-${c.start_date.slice(4, 6)}-${c.start_date.slice(6)}T12:00:00Z`);
    const end = new Date(`${c.end_date.slice(0, 4)}-${c.end_date.slice(4, 6)}-${c.end_date.slice(6)}T12:00:00Z`);
    for (let d = start; d <= end; d = new Date(+d + 86400e3)) {
      if (c[days[d.getUTCDay()]] === '1') add(c.service_id, d.toISOString().slice(0, 10).replaceAll('-', ''));
    }
  }
  for (const cd of load('calendar_dates.json')) {
    if (cd.exception_type === '1') add(cd.service_id, cd.date);
    else map.get(cd.service_id)?.delete(cd.date);
  }
  return map;
}

/** trip_id -> operator name (attributions.txt organization_name, the real operator). */
export function tripOperators() {
  return Object.fromEntries(load('attributions.json').filter((a) => a.is_operator !== '0').map((a) => [a.trip_id, a.organization_name]));
}

/** trip_id -> stop_times rows sorted by sequence: [trip_id, seq, stop_id, arr, dep, pickup, dropoff, dist]. */
export function stopTimesByTrip() {
  const m = new Map();
  for (const st of load('stop_times.json')) (m.get(st[0]) ?? m.set(st[0], []).get(st[0])).push(st);
  for (const v of m.values()) v.sort((a, b) => a[1] - b[1]);
  return m;
}
