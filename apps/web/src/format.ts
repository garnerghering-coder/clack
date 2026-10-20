// Display formatting. Times are shown in the station's own time zone (SPEC §7).
import type { Settings } from '@clack/shared';

export function fmtTime(ms: number | null | undefined, tz: string, clock: Settings['clock']): string {
  if (ms === null || ms === undefined) return '--:--';
  if (clock === '12h') return new Intl.DateTimeFormat('en-US', { timeZone: tz, hour: 'numeric', minute: '2-digit', hour12: true }).format(ms).replace(/\s?([AP])M$/, (_, p: string) => ` ${p.toLowerCase()}m`);
  return new Intl.DateTimeFormat('en-GB', { timeZone: tz, hour: '2-digit', minute: '2-digit', hour12: false }).format(ms);
}

/** "Fri 17 Oct" (adds the year when it isn't the current one). */
export function fmtDay(ms: number, tz: string, now = Date.now()): string {
  const sameYear = new Intl.DateTimeFormat('en-GB', { timeZone: tz, year: 'numeric' }).format(ms) === new Intl.DateTimeFormat('en-GB', { timeZone: tz, year: 'numeric' }).format(now);
  return new Intl.DateTimeFormat('en-GB', { timeZone: tz, weekday: 'short', day: 'numeric', month: 'short', ...(sameYear ? {} : { year: 'numeric' }) }).format(ms).replace(',', '');
}

export function fmtLongDate(ms: number, tz: string): string {
  return new Intl.DateTimeFormat('en-GB', { timeZone: tz, weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }).format(ms).replace(',', '');
}

export function fmtMonth(ms: number, tz: string): string {
  return new Intl.DateTimeFormat('en-GB', { timeZone: tz, month: 'long', year: 'numeric' }).format(ms);
}

/** Local calendar date (YYYY-MM-DD) of an instant in a time zone. */
export function localDate(ms: number, tz: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' }).format(ms);
}

/** Days between the local dates of two instants: "+1" for an arrival after midnight. */
export function dayOffset(fromMs: number, fromTz: string, toMs: number, toTz: string): number {
  return Math.round((Date.parse(localDate(toMs, toTz)) - Date.parse(localDate(fromMs, fromTz))) / 86400_000);
}

export function fmtDuration(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = Math.round(minutes % 60);
  if (h >= 24) return `${Math.floor(h / 24)}d ${h % 24}h`;
  return h ? `${h}h ${String(m).padStart(2, '0')}m` : `${m}m`;
}

export function fmtDistance(meters: number | null | undefined, unit: Settings['distanceUnit']): string {
  if (meters === null || meters === undefined) return '—';
  const v = unit === 'mi' ? meters / 1609.344 : meters / 1000;
  return `${Math.round(v).toLocaleString('en-GB')} ${unit}`;
}

export function fmtDelay(min: number | null | undefined): string {
  if (min === null || min === undefined) return '—';
  if (min === 0) return '0';
  return min > 0 ? `+${min}` : `−${Math.abs(min)}`;
}

export const todayIso = (tz = 'Europe/Stockholm') => localDate(Date.now(), tz);
export const addDaysIso = (iso: string, days: number) => new Date(Date.parse(`${iso}T12:00:00Z`) + days * 86400_000).toISOString().slice(0, 10);
export const isoToNoonMs = (iso: string) => Date.parse(`${iso}T12:00:00Z`);
