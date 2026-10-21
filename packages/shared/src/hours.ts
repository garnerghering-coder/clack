// Opening hours for station amenities (ADDITIONS_01 C2). A small evaluator for the part of OSM's opening_hours
// syntax that station shops use: "24/7", weekday lists and ranges, several time spans, spans past midnight,
// "off"/"closed", and PH (Swedish public holidays). Anything else is "unknown", never a guess. Times are
// Europe/Stockholm wall-clock.

const DAYS = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'] as const;
const TZ = 'Europe/Stockholm';

interface Rule {
  /** Weekdays 0 = Monday … 6 = Sunday, or 'PH'. Empty = every day. */
  days: Set<number | 'PH'>;
  /** Minutes from midnight; end may exceed 1440 (past midnight). Empty = closed that day. */
  spans: [number, number][];
}

export interface Hours {
  rules: Rule[];
  always: boolean;
}

/** Parse; null when the text uses syntax we don't evaluate (shown as "hours unverified"). */
export function parseHours(text: string | null | undefined): Hours | null {
  if (!text) return null;
  const src = text.trim();
  if (src === '24/7') return { rules: [], always: true };
  const rules: Rule[] = [];
  // Rules are separated by ";", or by ", " before a weekday ("Su-Th 09:00-03:00, Fr,Sa 09:00-05:00").
  for (const part of src.split(/;|,\s+(?=(?:Mo|Tu|We|Th|Fr|Sa|Su|PH)\b)/).map((p) => p.trim()).filter(Boolean)) {
    const m = part.match(/^((?:(?:Mo|Tu|We|Th|Fr|Sa|Su|PH)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?)(?:\s*,\s*(?:Mo|Tu|We|Th|Fr|Sa|Su|PH)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?)*)?\s*(.*)$/);
    if (!m) return null;
    const days = new Set<number | 'PH'>();
    for (const d of (m[1] ?? '').split(',').map((x) => x.trim()).filter(Boolean)) {
      if (d === 'PH') {
        days.add('PH');
        continue;
      }
      const [a, b] = d.split('-') as [string, string | undefined];
      const ia = DAYS.indexOf(a as (typeof DAYS)[number]);
      const ib = b ? DAYS.indexOf(b as (typeof DAYS)[number]) : ia;
      if (ia < 0 || ib < 0) return null;
      for (let i = ia; ; i = (i + 1) % 7) {
        days.add(i);
        if (i === ib) break;
      }
    }
    const times = m[2]!.trim();
    let spans: [number, number][] = [];
    if (/^(off|closed)$/i.test(times)) spans = [];
    else if (times === '' && days.size) spans = [[0, 1440]];
    else {
      for (const t of times.split(',').map((x) => x.trim())) {
        const tm = t.match(/^(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})$/);
        if (!tm) return null;
        const start = Number(tm[1]) * 60 + Number(tm[2]);
        let end = Number(tm[3]) * 60 + Number(tm[4]);
        if (end <= start) end += 1440;
        spans.push([start, end]);
      }
    }
    rules.push({ days, spans });
  }
  return rules.length ? { rules, always: false } : null;
}

// ---------- Swedish public holidays (helgdagar), the days PH refers to ----------
function easter(y: number): [number, number] {
  const a = y % 19, b = Math.floor(y / 100), c = y % 100, d = Math.floor(b / 4), e = b % 4;
  const f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3), h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  return [month, ((h + l - 7 * m + 114) % 31) + 1];
}
const iso = (y: number, m: number, d: number) => new Date(Date.UTC(y, m - 1, d)).toISOString().slice(0, 10);
const addDays = (s: string, n: number) => new Date(Date.parse(`${s}T00:00:00Z`) + n * 86400_000).toISOString().slice(0, 10);
/** The first given weekday (0 = Monday) on or after a date. */
const onOrAfter = (s: string, wd: number) => {
  for (let i = 0; i < 7; i++) {
    const d = addDays(s, i);
    if ((new Date(`${d}T00:00:00Z`).getUTCDay() + 6) % 7 === wd) return d;
  }
  return s;
};
const holidayCache = new Map<number, Set<string>>();
/** Röda dagar plus midsommar-, jul- and nyårsafton, which shops and stations treat as holidays. */
export function swedishHolidays(y: number): Set<string> {
  let s = holidayCache.get(y);
  if (s) return s;
  const [em, ed] = easter(y);
  const e = iso(y, em, ed);
  const midsummerEve = addDays(onOrAfter(iso(y, 6, 20), 5), -1);
  s = new Set([
    iso(y, 1, 1), iso(y, 1, 6), addDays(e, -2), e, addDays(e, 1), iso(y, 5, 1), addDays(e, 39), addDays(e, 49),
    iso(y, 6, 6), midsummerEve, addDays(midsummerEve, 1), onOrAfter(iso(y, 10, 31), 5), iso(y, 12, 24), iso(y, 12, 25), iso(y, 12, 26), iso(y, 12, 31),
  ]);
  holidayCache.set(y, s);
  return s;
}

// ---------- Evaluation ----------
const fmt = new Intl.DateTimeFormat('en-GB', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23', weekday: 'short' });
function local(ms: number): { date: string; weekday: number; minute: number } {
  const p = Object.fromEntries(fmt.formatToParts(ms).map((x) => [x.type, x.value]));
  return { date: `${p.year}-${p.month}-${p.day}`, weekday: DAYS.indexOf(p.weekday!.slice(0, 2) as (typeof DAYS)[number]), minute: Number(p.hour) * 60 + Number(p.minute) };
}

/** Spans (minutes from that day's midnight) open on a local date; later rules override earlier ones, as in OSM. */
function spansOn(h: Hours, date: string, weekday: number): [number, number][] {
  const ph = swedishHolidays(Number(date.slice(0, 4))).has(date);
  let out: [number, number][] = [];
  for (const r of h.rules) {
    const applies = r.days.size === 0 || (ph && r.days.has('PH')) || (r.days.has(weekday) && !(ph && h.rules.some((x) => x.days.has('PH'))));
    if (applies) out = r.spans;
  }
  return out;
}

export function isOpenAt(h: Hours, ms: number): boolean {
  if (h.always) return true;
  const now = local(ms);
  if (spansOn(h, now.date, now.weekday).some(([a, b]) => now.minute >= a && now.minute < b)) return true;
  // Yesterday's span that runs past midnight.
  const y = local(ms - 86400_000);
  return spansOn(h, y.date, y.weekday).some(([, b]) => b > 1440 && now.minute < b - 1440);
}

export type OpenState = 'open' | 'closing_soon' | 'closed' | 'unknown';

/**
 * State at a moment (default rule: "closes soon" = within 30 min), or over a window (layover): open for all of it,
 * open part of it (closing_soon, with when it closes), or closed throughout. Checked minute by minute — windows
 * are short.
 */
export function openState(text: string | null | undefined, from: number, to = from, soonMin = 30): { state: OpenState; closesAt: number | null } {
  const h = parseHours(text);
  if (!h) return { state: 'unknown', closesAt: null };
  if (h.always) return { state: 'open', closesAt: null };
  const step = 60_000;
  const end = to === from ? from + soonMin * 60_000 : to;
  const openNow = isOpenAt(h, from);
  let closesAt: number | null = null;
  let anyOpen = openNow;
  for (let t = from + step; t <= end; t += step) {
    const o = isOpenAt(h, t);
    if (o) anyOpen = true;
    if (!o && closesAt === null && (openNow || anyOpen)) closesAt = t;
  }
  if (to === from) {
    if (!openNow) return { state: 'closed', closesAt: null };
    return closesAt === null ? { state: 'open', closesAt: null } : { state: 'closing_soon', closesAt };
  }
  if (openNow && closesAt === null) return { state: 'open', closesAt: null };
  return anyOpen ? { state: 'closing_soon', closesAt } : { state: 'closed', closesAt: null };
}
