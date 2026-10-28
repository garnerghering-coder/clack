// The drawing list for the owner (docs/TRAIN_ART_NEEDED.md): which trains show a stand-in or no picture, ranked by
// how many run on a normal weekday, so the most-seen trains get drawn first. Reads the timetable for one day, the type
// rules (data/train_types.json via trainTypeFor), the drawings that exist (assets/trains/<model>-<livery>.svg) and
// which type uses which drawing (ClackCore's TrainArt.swift, `detailed`). Drawings are measured from photos, never
// guessed (docs/TRAIN_ART.md); the photo links are searches to start from, not checked sources.
import fs from 'node:fs';
import path from 'node:path';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { REPO_ROOT } from '../env.js';
import { loadBrands } from '../dataFiles.js';
import { trainTypeFor } from '../legs/trainTypes.js';
import { productOf, type Product } from '../search/timetable.js';

interface TypeInfo { id: string; name: string; uncertain?: boolean }

/**
 * typeId → the drawn model, its liveries and the livery each operator gets (`liveryOf`, e.g. Vores Tog → `arriva`), as
 * TrainArt.swift's `detailed` table says.
 */
export function drawnModels(swift: string): Map<string, { model: string; liveries: string[]; liveryOf: Record<string, string> }> {
  const out = new Map<string, { model: string; liveries: string[]; liveryOf: Record<string, string> }>();
  for (const m of swift.matchAll(/"([a-z0-9_]+)": Detailed\(model: "([a-z0-9_]+)", liveries: \[([^\]]*)\](?:, notFor: \[[^\]]*\])?(?:, liveryOf: \[([^\]]*)\])?/g)) {
    const liveryOf = Object.fromEntries([...(m[4] ?? '').matchAll(/"([^"]+)": "([^"]+)"/g)].map((x) => [x[1]!, x[2]!]));
    out.set(m[1]!, { model: m[2]!, liveries: [...m[3]!.matchAll(/"([^"]+)"/g)].map((x) => x[1]!), liveryOf });
  }
  return out;
}

/** Uncertain typeId → the drawn models it may be (TrainArt.swift's `candidates`). */
export function candidateModels(swift: string): Map<string, string[]> {
  const block = swift.slice(swift.indexOf('candidates: [String: [String]] = ['));
  const body = block.slice(0, block.indexOf('\n    ]'));
  return new Map([...body.matchAll(/"([a-z0-9_]+)": \[([^\]]*)\]/g)].map((m) => [m[1]!, [...m[2]!.matchAll(/"([^"]+)"/g)].map((x) => x[1]!)]));
}

export function artNeeded(db: Db, date: string): string {
  const types = new Map((JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'data/train_types.json'), 'utf8')).types as TypeInfo[]).map((t) => [t.id, t]));
  const brands = new Map(loadBrands().map((b) => [b.id, b]));
  const swift = fs.readFileSync(path.join(REPO_ROOT, 'apps/Clack/ClackKit/Sources/ClackCore/Logic/TrainArt.swift'), 'utf8');
  const drawn = drawnModels(swift);
  const candidates = candidateModels(swift);
  const files = new Set(fs.readdirSync(path.join(REPO_ROOT, 'assets/trains')).map((f) => f.replace(/\.svg$/, '')));
  // One row per trip running that day: operator, product, number and its two ends (for the type rules).
  const rows = db.all<{ op: string | null; route_type: string; category: string; number: string | null; country: string; first: string; last: string }>(sql`
    with d as (select trip_key from timetable_trip_dates where service_date = ${date}),
    e as (select st.trip_key, min(st.seq) fs, max(st.seq) ls from timetable_stop_times st join d on d.trip_key = st.trip_key group by st.trip_key)
    select t.operator_id op, t.route_type, t.category, t.train_number number, a.country, a.name first, b.name last
    from e join timetable_trips t on t.key = e.trip_key
    join timetable_stop_times x on x.trip_key = e.trip_key and x.seq = e.fs join stations a on a.id = x.station_id
    join timetable_stop_times y on y.trip_key = e.trip_key and y.seq = e.ls join stations b on b.id = y.station_id`);
  const groups = new Map<string, { op: string; type: string | null; product: Product; byCountry: Map<string, number>; total: number }>();
  for (const r of rows) {
    if (!r.op) continue;
    const product = productOf(r.route_type, r.category);
    const type = trainTypeFor(r.op, product, r.number, null, [r.first, r.last], null);
    const k = `${r.op}|${type ?? '-'}`;
    const g = groups.get(k) ?? groups.set(k, { op: r.op, type, product, byCountry: new Map(), total: 0 }).get(k)!;
    g.total++;
    g.byCountry.set(r.country, (g.byCountry.get(r.country) ?? 0) + 1);
  }
  const need = [...groups.values()].filter((g) => {
    if (!g.type) return true;
    // Painted when the type, or one of the models an uncertain type names, is drawn in this operator's livery.
    return ![g.type, ...(candidates.get(g.type) ?? [])].some((id) => {
      const d = drawn.get(id);
      return d && d.liveries.includes(g.op) && files.has(`${d.model}-${d.liveryOf[g.op] ?? g.op}`);
    });
  });
  need.sort((a, b) => b.total - a.total);
  const country = (g: (typeof need)[number]) => [...g.byCountry].sort((a, b) => b[1] - a[1]).map(([c, n]) => `${c} ${n}`).join(', ');
  const search = (q: string) => `https://commons.wikimedia.org/w/index.php?search=${encodeURIComponent(q)}`;
  const lines = [
    '# Train drawings needed',
    '',
    `Generated by \`npm run import -- art-needed\` from the timetable for ${date} (a normal weekday). Ranked by trains that day.`,
    'Each row is a train type in an operator\'s livery that the app can\'t show painted yet. Drawings are measured from photos,',
    'never guessed (docs/TRAIN_ART.md); the photo links are Wikimedia Commons searches to start from, not checked sources.',
    '',
    '## Known type, no drawing in this livery',
    '',
    '| Trains/day | Operator | Type | Countries | Drawing today | Photos |',
    '|---|---|---|---|---|---|',
  ];
  for (const g of need.filter((x) => x.type)) {
    const t = types.get(g.type!)!;
    const d = drawn.get(g.type!);
    const today = d ? `${d.model} drawn in ${d.liveries.join(', ')}; not in ${g.op}` : 'none (faded stand-in)';
    const brand = brands.get(g.op)?.name ?? g.op;
    lines.push(`| ${g.total} | ${brand} | ${t.name}${t.uncertain ? ' (one of these)' : ''} | ${country(g)} | ${today} | [search](${search(`${brand} ${t.name.split(' or ')[0]}`)}) |`);
  }
  lines.push('', '## No type known yet (a type rule is needed before a drawing)', '', '| Trains/day | Operator | Product | Countries |', '|---|---|---|---|');
  for (const g of need.filter((x) => !x.type)) lines.push(`| ${g.total} | ${brands.get(g.op)?.name ?? g.op} | ${g.product} | ${country(g)} |`);
  return lines.join('\n') + '\n';
}
