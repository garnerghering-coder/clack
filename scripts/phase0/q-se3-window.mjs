// How many rail trips does GTFS Sweden 3 schedule per date? Defines the "live timetable window".
import { load, serviceDates } from './p0data.mjs';
const trips = load('trips.json');
const sd = serviceDates();
const counts = new Map();
for (const t of trips) for (const d of sd.get(t.service_id) ?? []) counts.set(d, (counts.get(d) ?? 0) + 1);
const days = [...counts.keys()].sort();
console.log(`dates with rail trips: ${days[0]} .. ${days.at(-1)} (${days.length} days)`);
const pick = ['20260403', '20260501', '20260901', '20261001', '20261010', '20261013', '20261015', '20261017', '20261019', '20261020', '20261021', '20261101', '20261213', '20261214', '20270101', '20270301', '20270601', '20271201'];
for (const d of pick) console.log(`  ${d}: ${counts.get(d) ?? 0}`);
// first date with at least 50% of the median weekday volume
const vals = days.map((d) => counts.get(d)).sort((a, b) => a - b);
const median = vals[Math.floor(vals.length / 2)];
const full = days.filter((d) => counts.get(d) >= median * 0.5);
console.log(`median ${median}/day; days with >=50% of median: ${full[0]} .. ${full.at(-1)}`);
