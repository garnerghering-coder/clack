// Disruptions on a saved trip (owner, 2026-10-22): what happened, what it does to the rest of the journey, how urgent
// it is for you right now, and what you may be entitled to. Deterministic rules over the trip's own data; no guessing.

export type DisruptionKind =
  /** The train doesn't run on any of your part of the route. */
  | 'canceled'
  /** It starts later on your part of the route than where you get on (`PartialRun.runsFrom`, it starts there). */
  | 'starts_later'
  /** It ends before where you get off (`PartialRun.runsTo`, it ends there). */
  | 'ends_early'
  /** No train on a stretch in the middle of your part (`PartialRun.gaps`). */
  | 'gap'
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

/**
 * A train that runs only part of your way (build 86: a partly cancelled train read as wholly cancelled). From the
 * stops' arrival and departure cancellations where the feed gives them apart, else their `canceled` flag, which is per
 * role (`stopCanceled`).
 */
export interface PartialRun {
  /** full: it doesn't run on your part at all. partial: it runs some of it. */
  kind: 'full' | 'partial';
  /** The first stop of your part it leaves from, when that isn't where you get on. */
  runsFrom: string | null;
  /** The last stop of your part it arrives at, when that isn't where you get off. */
  runsTo: string | null;
  /** It is known to start at `runsFrom` for you (nothing runs from before your stop through it). */
  startsThere: boolean;
  /** It is known to end at `runsTo` for you (nothing runs on through your stop). */
  endsThere: boolean;
  /** Stretches of your part with no train: it stops at `from`, and runs again from `to` (a bus, often). */
  gaps: { from: string; to: string }[];
}

export interface CallFlag {
  stationId: string;
  /** before | board | through | alight | after */
  role: string;
  canceled: boolean;
  /** The arrival and the departure apart, when the feed says which (absent or null: only `canceled` is known). */
  arrCanceled?: boolean | null;
  depCanceled?: boolean | null;
}

/** The stop's `canceled` flag from its arrival and departure (null: not known), by its role on the trip. */
export function stopCanceled(role: string, arr: boolean | null, dep: boolean | null): boolean {
  if (role === 'board') return dep === true;
  if (role === 'alight') return arr === true;
  const known = [arr, dep].filter((x): x is boolean => x !== null);
  return known.length > 0 && known.every(Boolean);
}

const arrOff = (s: CallFlag) => s.arrCanceled ?? s.canceled;
const depOff = (s: CallFlag) => s.depCanceled ?? s.canceled;

/** How much of your part the train runs; null when it runs all of it (a stop it only skips on the way included). */
export function cancellationOf(stops: CallFlag[]): PartialRun | null {
  const r = stops.filter((s) => s.role === 'board' || s.role === 'through' || s.role === 'alight');
  const n = r.length;
  if (n < 2) return null;
  const leaves = (i: number) => i < n - 1 && !depOff(r[i]!);
  const reaches = (i: number) => i > 0 && !arrOff(r[i]!);
  const idx = [...r.keys()];
  const first = idx.find(leaves);
  const last = [...idx].reverse().find(reaches);
  const none = { runsFrom: null, runsTo: null, startsThere: false, endsThere: false, gaps: [] };
  // Nothing of your part runs, or it would only arrive where it can't leave from: there's nothing left to ride.
  if (first === undefined || last === undefined || first >= last) return { kind: 'full', ...none };
  // A stop it reaches but doesn't leave, with a later one it leaves again from: no train in between.
  const gaps: { from: string; to: string }[] = [];
  for (let i = first + 1; i < last; i++) {
    if (!reaches(i) || leaves(i)) continue;
    const k = idx.find((j) => j > i && j < last && leaves(j));
    if (k !== undefined) gaps.push({ from: r[i]!.stationId, to: r[k]!.stationId });
  }
  const runsFrom = first > 0 ? r[first]!.stationId : null;
  const runsTo = last < n - 1 ? r[last]!.stationId : null;
  if (!runsFrom && !runsTo && !gaps.length) return null;
  const before = stops[stops.indexOf(r[0]!) - 1];
  const after = stops[stops.indexOf(r[n - 1]!) + 1];
  return {
    kind: 'partial',
    runsFrom,
    runsTo,
    // It starts there for you when nothing runs into it from your stop: its own arrival there is cancelled, the stop
    // before yours is cancelled too, or it arrives at yours and goes no further. It ends there when it doesn't leave
    // that stop, doesn't reach the one after yours, or leaves yours again. Else it may only skip your stop.
    startsThere: Boolean(runsFrom) && (r[first]!.arrCanceled === true || !before || depOff(before) || r[0]!.arrCanceled === false),
    endsThere: Boolean(runsTo) && (r[last]!.depCanceled === true || !after || arrOff(after) || r[n - 1]!.depCanceled === false),
    gaps,
  };
}

export interface DisruptionInput {
  canceled: boolean;
  boardCanceled: boolean;
  alightCanceled: boolean;
  /** The train runs only part of your way (`cancellationOf`); wins over the two flags above when given. */
  partial?: PartialRun | null;
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
const SEVERE: DisruptionKind[] = ['canceled', 'starts_later', 'ends_early', 'gap', 'skips_board', 'skips_alight', 'connection_missed'];

export function assessDisruption(d: DisruptionInput, now: number): { kinds: DisruptionKind[]; urgency: Urgency | null } {
  const kinds: DisruptionKind[] = [];
  const p = d.partial;
  // A train the stops show running part of your way isn't wholly cancelled, whatever an older flag says.
  if (p?.kind === 'full' || (d.canceled && p?.kind !== 'partial')) kinds.push('canceled');
  else {
    if (p?.kind === 'partial') {
      if (p.runsFrom) kinds.push(p.startsThere ? 'starts_later' : 'skips_board');
      if (p.runsTo) kinds.push(p.endsThere ? 'ends_early' : 'skips_alight');
      if (p.gaps.length) kinds.push('gap');
    } else {
      if (d.boardCanceled) kinds.push('skips_board');
      if (d.alightCanceled) kinds.push('skips_alight');
    }
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
 * Norway isn't covered here (no rules checked yet): the operator's own terms apply. Nor are trips within Finland or
 * within Denmark (which of their services the EU rules cover, and the national rules on top, are not checked): the
 * operator's terms, as the app says. `canceled` is whether your own journey on this train is cancelled: also when it
 * runs only part of your way (it doesn't take you from where you get on, or to where you get off).
 */
export type Rights =
  | { regime: 'eu'; claim: 'refund_or_reroute' | 'compensation_25' | 'compensation_50' | null }
  | { regime: 'se_short'; claim: 'price_reduction' | null }
  | { regime: 'operator'; claim: null };

export function passengerRights(r: { countries: string[]; journeyKm: number; arrDelayMin: number | null; canceled: boolean }): Rights {
  const international = new Set(r.countries).size > 1;
  if (!international && ['NO', 'FI', 'DK'].some((x) => r.countries.every((c) => c === x))) return { regime: 'operator', claim: null };
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
