// Time-zone maths without a date library. GTFS times are "HH:MM:SS" counted from noon minus 12 h on the
// service day in the agency's time zone, so they stay correct across DST changes and can exceed 24:00.

// One formatter per zone: building an Intl.DateTimeFormat costs far more than using one (a station board's 1,159
// calls spent ~190 ms here, measured 2026-10-27).
const formatters = new Map<string, Intl.DateTimeFormat>();
const formatterFor = (tz: string) =>
  formatters.get(tz) ??
  formatters
    .set(
      tz,
      new Intl.DateTimeFormat('en-US', { timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' }),
    )
    .get(tz)!;

/** Offset of `tz` from UTC at instant `ms`, in milliseconds (e.g. +7_200_000 for CEST). */
export function tzOffsetMs(ms: number, tz: string): number {
  const parts = formatterFor(tz).formatToParts(new Date(ms));
  const get = (t: string) => Number(parts.find((p) => p.type === t)!.value);
  const asUtc = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour'), get('minute'), get('second'));
  return asUtc - Math.floor(ms / 1000) * 1000;
}

/** UTC instant of a wall-clock time in `tz`. For non-existent/ambiguous DST times, picks the earlier offset. */
export function zonedToUtc(y: number, mo: number, d: number, h: number, mi: number, s: number, tz: string): number {
  const guess = Date.UTC(y, mo - 1, d, h, mi, s);
  let ms = guess - tzOffsetMs(guess, tz);
  ms = guess - tzOffsetMs(ms, tz);
  return ms;
}

export function parseGtfsTime(t: string): number | null {
  if (!t) return null;
  const [h, m, s] = t.split(':').map(Number);
  if (h === undefined || m === undefined || s === undefined || [h, m, s].some(Number.isNaN)) return null;
  return h * 3600 + m * 60 + s;
}

/** GTFS service date (YYYY-MM-DD) + seconds since "noon minus 12h" -> UTC epoch ms. */
export function serviceTimeToUtc(serviceDate: string, seconds: number, tz: string): number {
  // Every time of a service day counts from the same base, so it is worked out once per day and zone: the planner
  // converts ~1.6 million stop times a day, and the time-zone lookup (Intl) behind it held the server for seconds
  // at a time (profiled 2026-10-28).
  const k = `${serviceDate}|${tz}`;
  let base = serviceBase.get(k);
  if (base === undefined) {
    const [y, mo, d] = serviceDate.split('-').map(Number) as [number, number, number];
    base = zonedToUtc(y, mo, d, 12, 0, 0, tz) - 12 * 3600_000;
    if (serviceBase.size > 20_000) serviceBase.clear();
    serviceBase.set(k, base);
  }
  return base + seconds * 1000;
}

const serviceBase = new Map<string, number>();

export const ymdToIso = (ymd: string) => `${ymd.slice(0, 4)}-${ymd.slice(4, 6)}-${ymd.slice(6, 8)}`;

/** Today's date in `tz` as YYYY-MM-DD. */
export function todayIn(tz: string, now = Date.now()): string {
  return new Date(now + tzOffsetMs(now, tz)).toISOString().slice(0, 10);
}

export function addDays(isoDate: string, days: number): string {
  return new Date(Date.parse(`${isoDate}T12:00:00Z`) + days * 86400_000).toISOString().slice(0, 10);
}
