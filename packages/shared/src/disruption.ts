// Disruptions on a saved trip (owner, 2026-10-22): what happened, what it does to the rest of the journey, how urgent
// it is for you right now, and what you may be entitled to. Deterministic rules over the trip's own data; no guessing.

export type DisruptionKind =
  /** The whole train is cancelled. */
  | 'canceled'
  /** The train runs, but not from where you get on. */
  | 'skips_board'
  /** The train runs, but doesn't stop where you get off. */
  | 'skips_alight'
  /** Trafikverket says buses replace the train for part of the way. */
  | 'replacement'
  /** 15 minutes or more late (expected or actual). */
  | 'delayed'
  /** Your change to the next train won't work on current times. */
  | 'connection_missed'
  /** Your change is under 5 minutes on current times. */
  | 'connection_at_risk';

/** act_now: you need to do something soon. heads_up: worth knowing before you go. info: for the record. */
export type Urgency = 'act_now' | 'heads_up' | 'info';

export interface DisruptionInput {
  canceled: boolean;
  boardCanceled: boolean;
  alightCanceled: boolean;
  /** Trafikverket's deviation texts on the stops you travel through. */
  deviations: string[];
  /** Best known delays in minutes (actual, else expected), or null. */
  depDelayMin: number | null;
  arrDelayMin: number | null;
  schedDep: number;
  /** You've arrived (or the trip is over). */
  arrived: boolean;
  /** The change to your next train, from the connection check: 'miss' | 'broken' | 'tight' | anything else. */
  connection?: string | null;
}

export const SIGNIFICANT_DELAY_MIN = 15;
const REPLACEMENT = /ersättningsbuss|buss(ar)? ersätter|ersätts med buss|replacement bus/i;
const SEVERE: DisruptionKind[] = ['canceled', 'skips_board', 'skips_alight', 'connection_missed'];

export function assessDisruption(d: DisruptionInput, now: number): { kinds: DisruptionKind[]; urgency: Urgency | null } {
  const kinds: DisruptionKind[] = [];
  if (d.canceled) kinds.push('canceled');
  else {
    if (d.boardCanceled) kinds.push('skips_board');
    if (d.alightCanceled) kinds.push('skips_alight');
    if (d.deviations.some((x) => REPLACEMENT.test(x))) kinds.push('replacement');
    if (Math.max(d.depDelayMin ?? 0, d.arrDelayMin ?? 0) >= SIGNIFICANT_DELAY_MIN) kinds.push('delayed');
  }
  if (d.connection === 'miss' || d.connection === 'broken') kinds.push('connection_missed');
  else if (d.connection === 'tight') kinds.push('connection_at_risk');
  if (!kinds.length) return { kinds, urgency: null };
  if (d.arrived) return { kinds, urgency: 'info' };
  const soon = d.schedDep - now <= 3 * 3600_000;
  const days = d.schedDep - now <= 48 * 3600_000;
  const severe = kinds.some((k) => SEVERE.includes(k));
  const urgency: Urgency = severe ? (soon ? 'act_now' : days ? 'heads_up' : 'info') : soon ? 'heads_up' : 'info';
  return { kinds, urgency };
}

/**
 * What you may be able to claim, as the rules are written (checked 2026-10-22):
 * - Konsumentverket: train journeys of 15 mil (150 km) or more, and any journey to another EU country, fall under the
 *   EU train regulation; shorter Swedish journeys under the law on public transport passengers' rights, which gives a
 *   price reduction from 20 minutes late.
 * - EU (Your Europe): arriving 60–119 minutes late, 25% of the ticket price; 120 or more, 50%; a cancellation that
 *   would make you over 60 minutes late gives a refund or re-routing.
 * Norway isn't covered here (no rules checked yet): the operator's own terms apply.
 */
export type Rights =
  | { regime: 'eu'; claim: 'refund_or_reroute' | 'compensation_25' | 'compensation_50' | null }
  | { regime: 'se_short'; claim: 'price_reduction' | null }
  | { regime: 'operator'; claim: null };

export function passengerRights(r: { countries: string[]; journeyKm: number; arrDelayMin: number | null; canceled: boolean }): Rights {
  const international = new Set(r.countries).size > 1;
  if (!international && r.countries.every((c) => c === 'NO')) return { regime: 'operator', claim: null };
  const late = r.arrDelayMin ?? 0;
  if (international || r.journeyKm >= 150) {
    if (r.canceled) return { regime: 'eu', claim: 'refund_or_reroute' };
    return { regime: 'eu', claim: late >= 120 ? 'compensation_50' : late >= 60 ? 'compensation_25' : null };
  }
  return { regime: 'se_short', claim: r.canceled || late >= 20 ? 'price_reduction' : null };
}

export const RIGHTS_LINKS = {
  eu: { en: 'https://europa.eu/youreurope/citizens/travel/passenger-rights/rail/index_en.htm', sv: 'https://europa.eu/youreurope/citizens/travel/passenger-rights/rail/index_sv.htm' },
  se: 'https://www.konsumentverket.se/varor-och-tjanster-process/forsenat-eller-installt-tag/',
} as const;

// Why a train is late (delayReasons) lives in delayCauses.ts, driven by data/delay_causes.json.
