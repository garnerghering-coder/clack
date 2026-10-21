// Where the app opens (product brief §4): deterministic, testable rules, applied once per app start and never
// while you're using the app. The attention window lives here and nowhere else.
import type { Leg } from './api';
import { ms } from './api';

export const PRIMARY_TABS = ['trips', 'explore', 'passport'] as const;
export type PrimaryTab = (typeof PRIMARY_TABS)[number];
export const TAB_PATHS: Record<PrimaryTab, string> = { trips: '/', explore: '/explore', passport: '/passport' };

export const LANDING = {
  /** A departure this close (or a train running now) makes the app open on Trips. */
  attentionWindowMs: 3 * 3600_000,
  /** A late train still counts as running until this long after its expected arrival when nothing better is known. */
  arrivalGraceMs: 10 * 60_000,
};

type LandingLeg = Pick<Leg, 'schedDep' | 'schedArr' | 'actualDep' | 'actualArr' | 'depDelayMin' | 'canceled' | 'live'>;

/** Best-known departure and arrival: actual, else live estimate, else timetable shifted by the known delay. */
function times(l: LandingLeg): { dep: number | null; arr: number | null } {
  const schedDep = ms(l.schedDep);
  const dep = ms(l.actualDep) ?? (schedDep !== null ? schedDep + (l.depDelayMin ?? 0) * 60_000 : null);
  const arr = ms(l.actualArr) ?? ms(l.live?.arrivalEta) ?? ms(l.schedArr);
  return { dep, arr };
}

/** On the train now: the tracker says so, or the clock is between departure and (expected) arrival. */
export function isActive(l: LandingLeg, now: number): boolean {
  if (l.canceled || l.live?.status === 'cancelled') return false;
  if (l.live?.status === 'en_route' || l.live?.status === 'at_stop') return true;
  if (l.live?.status === 'arrived' || l.actualArr) return false;
  const { dep, arr } = times(l);
  return dep !== null && arr !== null && now >= dep && now <= arr + LANDING.arrivalGraceMs;
}

/** Departing within the attention window (cancelled ones too: that's news you need). Legs without times never count. */
export function isImminent(l: LandingLeg, now: number, windowMs = LANDING.attentionWindowMs): boolean {
  const { dep } = times(l);
  return dep !== null && dep > now && dep - now <= windowMs;
}

export function resolveLanding(input: { legs: LandingLeg[]; now: number; lastTab: PrimaryTab | null; windowMs?: number }): PrimaryTab {
  const { legs, now } = input;
  if (legs.some((l) => isActive(l, now))) return 'trips';
  if (legs.some((l) => isImminent(l, now, input.windowMs))) return 'trips';
  if (input.lastTab) return input.lastTab;
  return 'explore';
}

const LAST_TAB_KEY = 'clack.lastTab';
export function readLastTab(): PrimaryTab | null {
  try {
    const v = localStorage.getItem(LAST_TAB_KEY);
    return (PRIMARY_TABS as readonly string[]).includes(v ?? '') ? (v as PrimaryTab) : null;
  } catch {
    return null;
  }
}
export function saveLastTab(tab: PrimaryTab) {
  try {
    localStorage.setItem(LAST_TAB_KEY, tab);
  } catch {
    // Private mode: the app just opens by the other rules.
  }
}
export function tabForPath(path: string): PrimaryTab | null {
  if (path === '/') return 'trips';
  if (path === '/explore') return 'explore';
  if (path === '/passport') return 'passport';
  return null;
}
