// Delay colour bands (DESIGN §2.1, owner-approved) and the on-time threshold (SPEC §14). Tune here only.

export const ON_TIME_MAX_DELAY_MIN = 5;

export type DelayBand = 'on_time' | 'slight' | 'late' | 'very_late' | 'cancelled' | 'unknown';

/** Band for a delay in whole minutes (negative = early). */
export function delayBand(delayMin: number | null | undefined, canceled = false): DelayBand {
  if (canceled) return 'cancelled';
  if (delayMin === null || delayMin === undefined) return 'unknown';
  if (delayMin <= 0) return 'on_time';
  if (delayMin <= 15) return 'slight';
  if (delayMin <= 30) return 'late';
  return 'very_late';
}

/** Delay = actual − advertised, in whole minutes (SPEC §10). Both are minute-precision times from Trafikverket. */
export function delayMinutes(advertisedMs: number | null | undefined, actualMs: number | null | undefined): number | null {
  if (advertisedMs === null || advertisedMs === undefined || actualMs === null || actualMs === undefined) return null;
  return Math.round((Math.floor(actualMs / 60000) * 60000 - Math.floor(advertisedMs / 60000) * 60000) / 60000);
}

/**
 * The Passport's punctuality bands: the same four colours, but "on time" up to ON_TIME_MAX_DELAY_MIN, so the
 * Passport's big on-time number and its bar agree (polish pass 1: "67% on time" over a bar whose green said 50%).
 * Elsewhere a delay keeps `delayBand` (colour marks any lateness).
 */
export function punctualityBand(delayMin: number | null | undefined): Exclude<DelayBand, 'cancelled'> {
  if (delayMin === null || delayMin === undefined) return 'unknown';
  if (delayMin <= ON_TIME_MAX_DELAY_MIN) return 'on_time';
  if (delayMin <= 15) return 'slight';
  if (delayMin <= 30) return 'late';
  return 'very_late';
}

export const isOnTime = (delayMin: number | null) => delayMin !== null && delayMin <= ON_TIME_MAX_DELAY_MIN;
