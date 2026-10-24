// When an alert is due and what it says (owner, 2026-10-23). Pure: the notifier loads the facts and sends the result.
// Nothing is guessed: a platform that isn't announced is left out, a time that isn't known makes no alert.
import { DELAY_ALERT_MIN, type Language, type Settings } from '@clack/shared';
import { clock, t } from './text.js';

export interface Alert {
  /** reminder | platform | delay | cancel | change | getoff | arrival */
  kind: string;
  /** Tells repeats of one kind apart (a new platform is a new alert; the same one again is not). */
  key: string;
  title: string;
  body: string;
  timeSensitive?: boolean;
}

/** What the rules need to know about one leg. Times are epoch ms. */
export interface TripFacts {
  legId: string;
  journeyId: string | null;
  train: string | null;
  from: string;
  to: string;
  fromTz: string;
  toTz: string;
  toStationId: string;
  /** Expected departure and arrival: actual, else live estimate, else timetable plus delay. */
  expDep: number | null;
  expArr: number | null;
  depPlatform: string | null;
  arrPlatform: string | null;
  departed: boolean;
  arrived: boolean;
  canceled: boolean;
  /** Minutes late at the arrival (negative = early). */
  delayMin: number | null;
  /** Nothing follows this leg in its journey. */
  lastInJourney: boolean;
}

export type Prefs = Pick<Settings, 'notify' | 'notifyLeadMin' | 'notifyPlatform' | 'notifyDelay' | 'notifyCancel' | 'notifyChange' | 'notifyGetOff' | 'notifyArrival'>;

const MIN = 60_000;

/** Not an alert for a train that's gone, or a person who has the switch off. */
const live = (f: TripFacts, p: Prefs) => p.notify && !f.canceled;

/** "Leaves 14:32 from platform 5": once, when the lead time before the expected departure is reached. */
export function reminder(f: TripFacts, p: Prefs, now: number, lang: Language): Alert | null {
  if (!live(f, p) || p.notifyLeadMin <= 0 || f.departed || f.expDep === null) return null;
  if (now < f.expDep - p.notifyLeadMin * MIN || f.expDep - now < 3 * MIN) return null;
  return { kind: 'reminder', key: '', title: t(lang, 'route', { from: f.from, to: f.to }), body: departureLine(f, f.expDep, lang) };
}

/** "Leaves 14:32 (6 min late) from platform 5.": the reminder's words, also the body of a Live Activity that starts by push. */
export function departureLine(f: Pick<TripFacts, 'fromTz' | 'delayMin' | 'depPlatform'>, expDep: number, lang: Language): string {
  const time = clock(expDep, f.fromTz);
  const late = f.delayMin !== null && f.delayMin >= DELAY_ALERT_MIN ? f.delayMin : null;
  const key = late !== null ? (f.depPlatform ? 'reminderLate' : 'reminderLateNoPlatform') : f.depPlatform ? 'reminderPlatform' : 'reminderNoPlatform';
  return t(lang, key, { time, delay: late ?? 0, platform: f.depPlatform ?? '' });
}

/** Alerts for the events the live tracker just saw on a leg. */
export function fromEvents(f: TripFacts, events: { type: string; payload: Record<string, unknown> }[], p: Prefs, lang: Language): Alert[] {
  if (!p.notify) return [];
  const out: Alert[] = [];
  const route = t(lang, 'route', { from: f.from, to: f.to });
  for (const e of events) {
    const x = e.payload;
    switch (e.type) {
      case 'platform_set':
      case 'platform_changed': {
        if (!p.notifyPlatform || f.canceled || f.arrived) break;
        const which = x.which === 'arrival' ? 'arrival' : 'departure';
        if (which === 'departure' && f.departed) break;
        const to = String(x.to);
        const changed = e.type === 'platform_changed';
        const key = `platform${which === 'arrival' ? 'Arr' : 'Dep'}${changed ? 'Changed' : 'Set'}`;
        out.push({ kind: 'platform', key: `${which}:${to}`, title: route, body: t(lang, key, { to, from: String(x.from ?? ''), station: which === 'arrival' ? f.to : f.from }) });
        break;
      }
      case 'delayed': {
        const d = Number(x.delayMin);
        if (!p.notifyDelay || f.canceled || !Number.isFinite(d) || d < DELAY_ALERT_MIN || f.expArr === null) break;
        out.push({ kind: 'delay', key: String(d), title: route, body: t(lang, 'delayed', { delay: d, time: clock(f.expArr, f.toTz) }) });
        break;
      }
      case 'cancelled':
        if (p.notifyCancel) out.push({ kind: 'cancel', key: 'cancelled', title: t(lang, 'cancelledTitle', { from: f.from, to: f.to }), body: t(lang, 'cancelled'), timeSensitive: true });
        break;
      case 'short_turned':
        if (p.notifyCancel && !f.canceled) out.push({ kind: 'cancel', key: `short:${[x.stationIds].flat().join(',')}`, title: route, body: t(lang, 'shortTurned'), timeSensitive: true });
        break;
      case 'arrived':
        if (p.notifyArrival && f.lastInJourney && !f.canceled)
          out.push({ kind: 'arrival', key: '', title: t(lang, 'welcome', { station: f.to }), body: t(lang, 'welcomeBody', { time: clock(Number(x.at) || f.expArr || 0, f.toTz) }) });
        break;
    }
  }
  return out;
}

/** "Get off at X in about N min": the next stop is where you get off and it is at most ten minutes away. */
export function getOff(f: TripFacts, live_: { status: string; nextStopId: string | null; eta: number | null }, p: Prefs, now: number, lang: Language): Alert | null {
  if (!live(f, p) || !p.notifyGetOff || f.arrived || !f.departed) return null;
  if (live_.nextStopId !== f.toStationId || live_.eta === null) return null;
  if (live_.status !== 'en_route' && live_.status !== 'at_stop') return null;
  const min = Math.ceil((live_.eta - now) / MIN);
  if (min > 10 || min < 0) return null;
  return { kind: 'getoff', key: '', title: t(lang, 'route', { from: f.from, to: f.to }), body: t(lang, 'getOff', { station: f.to, min: Math.max(min, 1) }) };
}

/** Whole minutes between arriving on `a` and `b` leaving the same station; negative = you'd miss it. */
export function spareMinutes(a: TripFacts, b: TripFacts): number | null {
  if (a.expArr === null || b.expDep === null) return null;
  return Math.round((b.expDep - a.expArr) / MIN);
}

/** The change from `a` to `b` at a's destination: once it is close (15 min before arriving), and again when it changes. */
export function change(a: TripFacts, b: TripFacts, p: Prefs, now: number, lang: Language): Alert | null {
  if (!p.notify || !p.notifyChange || a.canceled || b.departed || a.expArr === null) return null;
  if (now < a.expArr - 15 * MIN) return null;
  const station = a.to;
  if (b.canceled) return { kind: 'change', key: 'cancelled', title: t(lang, 'changeTitle', { station }), body: t(lang, 'connectionCancelled', { to: b.to }), timeSensitive: true };
  const spare = spareMinutes(a, b);
  if (spare === null) return null;
  const key = `${a.arrPlatform ?? '-'}>${b.depPlatform ?? '-'}:${Math.floor(spare / 3)}`;
  if (spare < 0) return { kind: 'change', key, title: t(lang, 'missTitle'), body: t(lang, 'miss', { late: -spare, to: b.to, station }), timeSensitive: true };
  const body = t(lang, a.arrPlatform && b.depPlatform ? 'changeBoth' : a.arrPlatform ? 'changeArrOnly' : b.depPlatform ? 'changeDepOnly' : 'changeNone', { a: a.arrPlatform ?? '', b: b.depPlatform ?? '', spare });
  return { kind: 'change', key, title: t(lang, spare < 5 ? 'changeTight' : 'changeTitle', { station }), body };
}

/** Where a trip is, for the card on the Lock Screen and the Dynamic Island (owner, 2026-10-24). */
export type Phase = 'scheduled' | 'leaveSoon' | 'approaching' | 'boarding' | 'enRoute' | 'getOffSoon' | 'changing' | 'arrived' | 'cancelled';

export interface Moment {
  phase: Phase;
  /** `platformChanged` for ten minutes after the platform changed, before the train has left. */
  note: 'platformChanged' | null;
  /** In the `changing` phase: where the next train leaves from and when. */
  changePlatform: string | null;
  changeAt: number | null;
}

/**
 * The one moment the trip is in, in order of importance: cancelled, changing trains (arrived, and the next train leaves within an
 * hour), arrived, boarding, approaching (the train is on its way to your stop), the last ten minutes before you get off, running,
 * about to leave (30 minutes), and further off. Pure, so the server, the card and the tests agree.
 */
export function momentOf(
  f: TripFacts,
  live: { status: string; nextStopId: string | null; eta: number | null } | null,
  next: TripFacts | null,
  lastPlatformChangeAt: number | null,
  now: number,
): Moment {
  const base = { note: null, changePlatform: null, changeAt: null } as const;
  if (f.canceled) return { ...base, phase: 'cancelled' };
  if (f.arrived) {
    const changing = next && !next.canceled && !next.departed && next.expDep !== null && next.expDep > now && next.expDep - now <= 60 * MIN;
    return changing ? { phase: 'changing', note: null, changePlatform: next.depPlatform, changeAt: next.expDep } : { ...base, phase: 'arrived' };
  }
  const changedRecently = lastPlatformChangeAt !== null && now - lastPlatformChangeAt <= 10 * MIN && !f.departed;
  const note = changedRecently ? 'platformChanged' : null;
  if (live?.status === 'boarding') return { ...base, phase: 'boarding', note };
  if (live?.status === 'approaching') return { ...base, phase: 'approaching', note };
  if (live?.status === 'en_route' || live?.status === 'at_stop') {
    const soon = live.nextStopId === f.toStationId && live.eta !== null && live.eta - now <= 10 * MIN && live.eta - now >= 0;
    return { ...base, phase: soon ? 'getOffSoon' : 'enRoute' };
  }
  return { ...base, phase: f.expDep !== null && f.expDep - now <= 30 * MIN ? 'leaveSoon' : 'scheduled', note };
}
