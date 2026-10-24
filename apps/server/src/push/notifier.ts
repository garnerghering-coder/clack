// Turns the live tracker's changes into alerts and Live Activity updates on people's phones (owner, 2026-10-23).
// Listens to the tracker, and every minute looks at the trips about to leave or running. What is due and what it says
// are in rules.ts; this loads the facts, sends once per alert (push_log), and forgets phones Apple says are gone.
import { and, asc, desc, eq, gt, inArray, lt, ne } from 'drizzle-orm';
import { DEFAULT_SETTINGS, delayBand, type Language, type Settings } from '@clack/shared';
import type { Db } from '../db/client.js';
import { devices, legEvents, legs, liveActivities, liveState, operators, pushLog, stations, users } from '../db/schema.js';
import { liveBus, type LiveUpdate } from '../live/tracker.js';
import { alertPayload, backgroundPayload, WIDGET_PAYLOAD, type ApnsClient, type Environment } from './apns.js';
import { change, departureLine, fromEvents, getOff, momentOf, reminder, type Alert, type Moment, type Prefs, type TripFacts } from './rules.js';
import { t } from './text.js';

const MIN = 60_000;
const ms = (d: Date | null | undefined) => (d ? d.getTime() : null);

/** A Live Activity is ended by the system after 8 hours and kept on the Lock Screen at most 4 more (Apple, "Displaying live data with Live Activities"). */
const ACTIVITY_MAX_MS = 12 * 60 * MIN;
/** How long the card is good for without news. Each update moves it on; unchanged cards are refreshed before it passes. */
const STALE_SEC = 5 * 60;
const HEARTBEAT_MS = 4 * MIN;
/** An ended card stays on the Lock Screen this long. */
const DISMISS_SEC = 10 * 60;

/** At most one background push and one widget push per phone in this time, except for a cancellation. */
export const FRESH_EVERY_MS = 15 * MIN;

/** Why the app (or its widgets) should fetch again. */
export type FreshReason = 'delay' | 'platform' | 'cancelled' | 'phase' | 'finished';

/** What the app shows about a leg that a freshness push is about: its delay band, platforms, cancellation and phase. */
export interface FreshSignature {
  band: string;
  depPlatform: string | null;
  arrPlatform: string | null;
  canceled: boolean;
  phase: string;
}

export function freshSignature(L: Loaded, now: number): FreshSignature {
  const f = L.facts;
  return { band: delayBand(f.delayMin, f.canceled), depPlatform: f.depPlatform, arrPlatform: f.arrPlatform, canceled: f.canceled, phase: Notifier.moment(L, now).phase };
}

/** The most important thing that changed between two looks at a leg, if anything did. The first look is only a baseline. */
export function freshReason(prev: FreshSignature | undefined, next: FreshSignature, lastInJourney: boolean): FreshReason | null {
  if (!prev) return null;
  if (next.canceled && !prev.canceled) return 'cancelled';
  if (next.phase !== prev.phase && lastInJourney && next.phase === 'arrived') return 'finished';
  if (next.depPlatform !== prev.depPlatform || next.arrPlatform !== prev.arrPlatform) return 'platform';
  if (next.band !== prev.band) return 'delay';
  if (next.phase !== prev.phase) return 'phase';
  return null;
}

interface FreshJob {
  kind: 'background' | 'widgets';
  /** The phone (devices.token), what the throttle counts by. */
  device: string;
  /** Where the push goes: the phone's token, or its widget token. */
  token: string;
  environment: Environment;
  legId: string;
  reason: FreshReason;
}

/** What the Live Activity shows. Plain JSON numbers (ms since 1970), as Apple decodes the state with default coding. */
export interface ActivityState {
  status: string;
  delayMin: number | null;
  nextStop: string | null;
  nextStopAt: number | null;
  platform: string | null;
  /** departure | arrival: which end the platform is for. */
  platformFor: string;
  progress: number | null;
  departAt: number | null;
  arriveAt: number | null;
  canceled: boolean;
  /** The moment the trip is in (rules.ts momentOf): scheduled | leaveSoon | approaching | boarding | enRoute | getOffSoon | changing | arrived | cancelled. */
  phase: string;
  /** platformChanged for ten minutes after a platform change. */
  note: string | null;
  /** While changing trains: the next train's platform and when it leaves (ms). */
  changePlatform: string | null;
  changeAt: number | null;
  /**
   * The leg the card is showing. One card follows a whole journey, but its attributes (legId, train, from, to) are fixed
   * when it starts: after a change these say which train it is now on.
   */
  legId: string;
  train: string | null;
  from: string;
  to: string;
  fromTz: string;
  toTz: string;
}

/** The newest platform change on a leg: when, and what it said. */
interface PlatformChange {
  at: number;
  which: 'departure' | 'arrival';
  from: string;
  to: string;
}

export interface Loaded {
  userId: string;
  lang: Language;
  prefs: Prefs;
  facts: TripFacts;
  /** The leg that follows in the same journey, from where this one ends. */
  next: TripFacts | null;
  /** The leg after this one in its journey (by departure), wherever it leaves from: where a card moves on to. */
  afterId: string | null;
  /** Every leg of the journey, this one included. */
  journeyLegIds: string[];
  live: { status: string; nextStopId: string | null; eta: number | null; progress: number | null } | null;
  nextStopName: string | null;
  operatorColor: string | null;
  /** When the platform last changed (ms), if it has. */
  lastPlatformChangeAt: number | null;
  lastPlatformChange: PlatformChange | null;
  /** Operator and train number, the line under an alert's title ("SJ 547"). */
  subtitle: string | undefined;
}

export interface NotifierOptions {
  now?: () => number;
  log?: (m: string) => void;
}

type LegRow = typeof legs.$inferSelect;

export class Notifier {
  private lastActivity = new Map<string, { words: string; full: string; at: number }>();
  /** The last look at each tracked leg, for freshness pushes. In memory: after a restart the first look is a new baseline. */
  private seen = new Map<string, { sig: FreshSignature; at: number }>();
  /** When each phone last got a background (`background:<token>`) or widget (`widgets:<token>`) push, and what waits. */
  private freshLast = new Map<string, number>();
  private freshPending = new Map<string, FreshJob>();

  constructor(
    private db: Db,
    private apns: ApnsClient | null,
    private opts: NotifierOptions = {},
  ) {}

  private now() {
    return (this.opts.now ?? Date.now)();
  }

  // ---------- loading ----------

  /** Everything the rules need for these legs, in a fixed handful of queries however many legs there are. */
  loadMany(legIds: string[]): Map<string, Loaded> {
    const out = new Map<string, Loaded>();
    const ids = [...new Set(legIds)];
    if (!ids.length) return out;
    const rows = this.db.select().from(legs).where(inArray(legs.id, ids)).all();
    if (!rows.length) return out;
    const journeyIds = [...new Set(rows.map((r) => r.journeyId).filter((j): j is string => j !== null))];
    const byJourney = new Map<string, LegRow[]>();
    if (journeyIds.length)
      for (const s of this.db.select().from(legs).where(inArray(legs.journeyId, journeyIds)).orderBy(asc(legs.schedDep)).all()) {
        const list = byJourney.get(s.journeyId!) ?? [];
        list.push(s);
        byJourney.set(s.journeyId!, list);
      }
    const all = new Map<string, LegRow>(rows.map((r) => [r.id, r]));
    for (const list of byJourney.values()) for (const s of list) all.set(s.id, s);
    const allIds = [...all.keys()];
    const lives = new Map(this.db.select().from(liveState).where(inArray(liveState.legId, allIds)).all().map((l) => [l.legId, l]));
    const stationIds = new Set<string>();
    for (const r of all.values()) stationIds.add(r.originStationId).add(r.destStationId);
    for (const l of lives.values()) if (l.nextStopId) stationIds.add(l.nextStopId);
    const stationOf = new Map(
      this.db.select({ id: stations.id, name: stations.name, tz: stations.tz }).from(stations).where(inArray(stations.id, [...stationIds])).all().map((s) => [s.id, s]),
    );
    const userIds = [...new Set(rows.map((r) => r.userId))];
    const settingsOf = new Map(this.db.select({ id: users.id, settings: users.settings }).from(users).where(inArray(users.id, userIds)).all().map((u) => [u.id, u.settings]));
    const operatorIds = [...new Set(rows.map((r) => r.operatorId).filter((o): o is string => o !== null))];
    const operatorOf = new Map(
      operatorIds.length
        ? this.db.select({ id: operators.id, n: operators.shortName, c: operators.brandColor }).from(operators).where(inArray(operators.id, operatorIds)).all().map((o) => [o.id, o])
        : [],
    );
    const changes = new Map<string, PlatformChange>();
    for (const e of this.db
      .select({ legId: legEvents.legId, ts: legEvents.ts, payload: legEvents.payload })
      .from(legEvents)
      .where(and(inArray(legEvents.legId, ids), eq(legEvents.type, 'platform_changed')))
      .orderBy(desc(legEvents.ts))
      .all()) {
      if (changes.has(e.legId)) continue;
      const p = e.payload ?? {};
      changes.set(e.legId, { at: e.ts.getTime(), which: p.which === 'arrival' ? 'arrival' : 'departure', from: String(p.from ?? ''), to: String(p.to ?? '') });
    }

    const factsOf = (row: LegRow, siblings: LegRow[]): TripFacts | null => {
      const from = stationOf.get(row.originStationId);
      const to = stationOf.get(row.destStationId);
      if (!from || !to) return null;
      const live = lives.get(row.id);
      const dep = ms(row.schedDep);
      const arr = ms(row.schedArr);
      return {
        legId: row.id,
        journeyId: row.journeyId,
        train: row.trainNumber,
        from: from.name,
        to: to.name,
        fromTz: from.tz,
        toTz: to.tz,
        toStationId: row.destStationId,
        expDep: ms(row.actualDep) ?? (dep === null ? null : dep + (row.depDelayMin ?? 0) * MIN),
        expArr: ms(row.actualArr) ?? ms(live?.arrivalEta) ?? (arr === null ? null : arr + (row.arrDelayMin ?? 0) * MIN),
        depPlatform: row.depPlatform,
        arrPlatform: row.arrPlatform,
        departed: row.actualDep !== null,
        arrived: row.actualArr !== null,
        canceled: row.canceled,
        delayMin: live?.arrivalDelayMin ?? row.arrDelayMin,
        lastInJourney: !siblings.some((s) => s.id !== row.id && (ms(s.schedDep) ?? 0) > (dep ?? 0)),
      };
    };

    for (const row of rows) {
      const settings = { ...DEFAULT_SETTINGS, ...((settingsOf.get(row.userId) as Partial<Settings> | undefined) ?? {}) };
      const siblings = row.journeyId ? (byJourney.get(row.journeyId) ?? [row]) : [row];
      const facts = factsOf(row, siblings);
      if (!facts) continue;
      const dep = ms(row.schedDep) ?? 0;
      const later = siblings.filter((s) => s.id !== row.id && (ms(s.schedDep) ?? 0) > dep);
      const nextRow = later.find((s) => s.originStationId === row.destStationId);
      const lv = lives.get(row.id);
      const op = row.operatorId ? operatorOf.get(row.operatorId) : undefined;
      const pc = changes.get(row.id) ?? null;
      out.set(row.id, {
        userId: row.userId,
        lang: settings.language,
        prefs: settings,
        facts,
        next: nextRow ? factsOf(nextRow, siblings) : null,
        afterId: later[0]?.id ?? null,
        journeyLegIds: siblings.map((s) => s.id),
        live: lv ? { status: lv.status, nextStopId: lv.nextStopId, eta: ms(lv.eta), progress: lv.progress } : null,
        nextStopName: lv?.nextStopId ? (stationOf.get(lv.nextStopId)?.name ?? null) : null,
        lastPlatformChangeAt: pc?.at ?? null,
        lastPlatformChange: pc,
        subtitle: [op?.n ?? null, facts.train].filter(Boolean).join(' ') || undefined,
        operatorColor: op?.c ?? null,
      });
    }
    return out;
  }

  load(legId: string): Loaded | null {
    return this.loadMany([legId]).get(legId) ?? null;
  }

  /** The tracker saw changes on a leg. */
  async onUpdate(u: LiveUpdate) {
    const L = this.load(u.legId);
    if (!L) return;
    for (const a of fromEvents(L.facts, u.events, L.prefs, L.lang)) await this.deliver(L, a);
    await this.checks(L);
    await this.pushActivity(L);
    await this.fresh(L);
  }

  /** Reminders, "get off soon", changes, and starting Live Activities: things that happen with the clock, not an event. */
  private async checks(L: Loaded) {
    const now = this.now();
    const r = reminder(L.facts, L.prefs, now, L.lang);
    if (r) await this.deliver(L, r);
    if (L.live) {
      const g = getOff(L.facts, L.live, L.prefs, now, L.lang);
      if (g) await this.deliver(L, g);
    }
    if (L.next) {
      const c = change(L.facts, L.next, L.prefs, now, L.lang);
      if (c) await this.deliver(L, c);
    }
  }

  /** Every minute: trips leaving within the next 4 hours or still running, and every card that is up. */
  async tick() {
    const now = this.now();
    // Cards older than Apple lets one live are gone from the phone: stop sending to them.
    this.db.delete(liveActivities).where(lt(liveActivities.createdAt, new Date(now - ACTIVITY_MAX_MS))).run();
    const withDevice = new Set(this.db.select({ id: devices.userId }).from(devices).all().map((d) => d.id));
    const due = withDevice.size
      ? this.db
          .select({ id: legs.id, userId: legs.userId })
          .from(legs)
          .where(and(ne(legs.status, 'snapshotted'), eq(legs.canceled, false), lt(legs.schedDep, new Date(now + 4 * 60 * MIN)), gt(legs.schedArr, new Date(now - 30 * MIN))))
          .all()
          .filter((r) => withDevice.has(r.userId))
      : [];
    const cards = [...new Set(this.db.select({ legId: liveActivities.legId }).from(liveActivities).all().map((a) => a.legId))];
    for (const [legId, s] of this.seen) if (now - s.at > 6 * 60 * MIN) this.seen.delete(legId);
    const loaded = due.length || cards.length ? this.loadMany([...due.map((r) => r.id), ...cards]) : new Map<string, Loaded>();
    for (const L of loaded.values()) await this.fresh(L);
    await this.flushFresh();
    for (const r of due) {
      const L = loaded.get(r.id);
      if (!L || !L.prefs.notify) continue;
      await this.checks(L);
      await this.startActivity(L);
    }
    // Every card that is up, including trips the tracker has let go (changing trains, just arrived): move them on, end them when over.
    for (const legId of cards) {
      const L = loaded.get(legId);
      if (L) await this.pushActivity(L);
    }
  }

  start(): () => void {
    const onUpdate = (u: LiveUpdate) => void this.onUpdate(u).catch((e) => this.opts.log?.(`push: ${(e as Error).message}`));
    liveBus.on('update', onUpdate);
    const timer = setInterval(() => void this.tick().catch((e) => this.opts.log?.(`push tick: ${(e as Error).message}`)), MIN);
    timer.unref();
    return () => {
      liveBus.off('update', onUpdate);
      clearInterval(timer);
    };
  }

  // ---------- sending ----------

  private devicesOf(userId: string) {
    return this.db.select().from(devices).where(eq(devices.userId, userId)).all();
  }

  /** Apple says this phone is gone: forget it, and the cards that ran on it. */
  private forget(deviceToken: string) {
    this.db.delete(devices).where(eq(devices.token, deviceToken)).run();
    for (const kind of ['background', 'widgets']) {
      this.freshLast.delete(`${kind}:${deviceToken}`);
      this.freshPending.delete(`${kind}:${deviceToken}`);
    }
    for (const a of this.db.select({ token: liveActivities.token }).from(liveActivities).where(eq(liveActivities.deviceToken, deviceToken)).all()) this.lastActivity.delete(a.token);
    this.db.delete(liveActivities).where(eq(liveActivities.deviceToken, deviceToken)).run();
  }

  private logged(legId: string, kind: string, key: string) {
    return !!this.db.select({ k: pushLog.kind }).from(pushLog).where(and(eq(pushLog.legId, legId), eq(pushLog.kind, kind), eq(pushLog.key, key))).get();
  }

  private log(legId: string, kind: string, key: string) {
    this.db.insert(pushLog).values({ legId, kind, key, sentAt: new Date(this.now()) }).onConflictDoNothing().run();
  }

  /** One alert, once: the log says whether it has gone out. */
  async deliver(L: Loaded, a: Alert) {
    if (!this.apns || !L.prefs.notify) return;
    const phones = this.devicesOf(L.userId);
    if (!phones.length) return;
    const first = this.db.insert(pushLog).values({ legId: L.facts.legId, kind: a.kind, key: a.key, sentAt: new Date(this.now()) }).onConflictDoNothing().run().changes;
    if (!first) return;
    let delivered = false;
    for (const d of phones) {
      const r = await this.apns.send({
        token: d.token,
        environment: d.environment as 'sandbox' | 'production',
        pushType: 'alert',
        collapseId: `${L.facts.legId}:${a.kind}`,
        expiration: Math.floor(this.now() / 1000) + 3600,
        payload: alertPayload({ ...a, subtitle: L.subtitle, legId: L.facts.legId, journeyId: L.facts.journeyId }),
      });
      if (r.ok) delivered = true;
      else if (r.dead) this.forget(d.token);
      else this.opts.log?.(`push: ${a.kind} to ${d.token.slice(0, 8)}… failed: ${r.status} ${r.reason ?? ''}`);
    }
    // Nothing got through (a network problem, not a dead phone): let a later tick try again.
    if (!delivered)
      this.db.delete(pushLog).where(and(eq(pushLog.legId, L.facts.legId), eq(pushLog.kind, a.kind), eq(pushLog.key, a.key))).run();
  }

  // ---------- Freshness: background and widget pushes ----------

  /**
   * A tracked leg changed in a way the app or its widgets show (delay band, platform, cancellation, phase, or the journey
   * finished): wake the app with a background push, and tell WidgetKit to reload, on each of the person's phones.
   */
  private async fresh(L: Loaded) {
    if (!this.apns) return;
    const now = this.now();
    const sig = freshSignature(L, now);
    const prev = this.seen.get(L.facts.legId)?.sig;
    this.seen.set(L.facts.legId, { sig, at: now });
    const reason = freshReason(prev, sig, L.facts.lastInJourney);
    if (!reason) return;
    for (const d of this.devicesOf(L.userId)) {
      const env = d.environment as Environment;
      await this.freshSend({ kind: 'background', device: d.token, token: d.token, environment: env, legId: L.facts.legId, reason });
      if (d.widgetToken) await this.freshSend({ kind: 'widgets', device: d.token, token: d.widgetToken, environment: env, legId: L.facts.legId, reason });
    }
  }

  /** Sends now, or keeps the newest job for when the phone's 15 minutes are up. A cancellation goes at once. */
  private async freshSend(job: FreshJob) {
    if (!this.apns) return;
    const now = this.now();
    const key = `${job.kind}:${job.device}`;
    const last = this.freshLast.get(key);
    if (job.reason !== 'cancelled' && last !== undefined && now - last < FRESH_EVERY_MS) {
      this.freshPending.set(key, job);
      return;
    }
    this.freshPending.delete(key);
    const r = await this.apns.send({
      token: job.token,
      environment: job.environment,
      pushType: job.kind,
      // Not 0: Apple may hold these until the phone can take them; one held is enough, and an hour old is still worth a refresh.
      expiration: Math.floor(now / 1000) + 3600,
      payload: job.kind === 'background' ? backgroundPayload({ legId: job.legId, reason: job.reason }) : WIDGET_PAYLOAD,
    });
    if (r.ok) this.freshLast.set(key, now);
    else if (r.dead) {
      if (job.kind === 'background') this.forget(job.device);
      else this.db.update(devices).set({ widgetToken: null }).where(eq(devices.token, job.device)).run();
    } else {
      this.opts.log?.(`push: ${job.kind} to ${job.token.slice(0, 8)}… failed: ${r.status} ${r.reason ?? ''}`);
      this.freshPending.set(key, job);
    }
  }

  /** Every minute: the pushes held back by the 15 minutes (or a failure) whose time has come. */
  private async flushFresh() {
    const now = this.now();
    for (const [key, job] of [...this.freshPending]) {
      const last = this.freshLast.get(key);
      if (last === undefined || now - last >= FRESH_EVERY_MS) await this.freshSend(job);
    }
  }

  // ---------- Live Activities ----------

  static state(L: Loaded, now: number): ActivityState {
    const f = L.facts;
    return {
      status: f.canceled ? 'cancelled' : f.arrived ? 'arrived' : (L.live?.status ?? 'scheduled'),
      delayMin: f.delayMin,
      nextStop: L.nextStopName,
      nextStopAt: L.live?.eta ?? null,
      platform: f.departed ? f.arrPlatform : f.depPlatform,
      platformFor: f.departed ? 'arrival' : 'departure',
      progress: L.live?.progress ?? null,
      departAt: f.expDep,
      arriveAt: f.expArr,
      canceled: f.canceled,
      ...Notifier.moment(L, now),
      legId: f.legId,
      train: f.train,
      from: f.from,
      to: f.to,
      fromTz: f.fromTz,
      toTz: f.toTz,
    };
  }

  static moment(L: Loaded, now: number): { phase: string; note: string | null; changePlatform: string | null; changeAt: number | null } {
    const m: Moment = momentOf(L.facts, L.live, L.next, L.lastPlatformChangeAt, now);
    return { phase: m.phase, note: m.note, changePlatform: m.changePlatform, changeAt: m.changeAt };
  }

  /**
   * The few updates worth lighting the screen for: a platform change before leaving, the train cancelled, and "get off
   * soon". Each once per leg (push_log, kind `activityAlert`), and only when the person has that alert switched on.
   */
  static activityAlert(L: Loaded, state: ActivityState, now: number): { key: string; title: string; body: string } | null {
    const f = L.facts;
    const p = L.prefs;
    const route = t(L.lang, 'route', { from: f.from, to: f.to });
    if (state.phase === 'cancelled') return p.notifyCancel ? { key: 'cancelled', title: t(L.lang, 'cancelledTitle', { from: f.from, to: f.to }), body: t(L.lang, 'cancelled') } : null;
    if (state.phase === 'getOffSoon' && L.live?.eta != null)
      return p.notifyGetOff ? { key: 'getoff', title: route, body: t(L.lang, 'getOff', { station: f.to, min: Math.max(Math.ceil((L.live.eta - now) / MIN), 1) }) } : null;
    const c = L.lastPlatformChange;
    if (state.note === 'platformChanged' && c && c.to && p.notifyPlatform) {
      const key = `platform${c.which === 'arrival' ? 'Arr' : 'Dep'}Changed`;
      return { key: `platform:${c.which}:${c.to}`, title: route, body: t(L.lang, key, { to: c.to, from: c.from, station: c.which === 'arrival' ? f.to : f.from }) };
    }
    return null;
  }

  /**
   * The live card for a journey that already has one: new numbers when something a person reads changed, the line at
   * most once a minute, and the same again every few minutes so the card doesn't go stale while the server is up.
   * One card follows the whole journey: when a leg is over and another follows, the card moves on to it.
   */
  async pushActivity(L0: Loaded) {
    if (!this.apns || !L0.prefs.notify) return;
    let rows = this.db.select().from(liveActivities).where(eq(liveActivities.legId, L0.facts.legId)).all();
    if (!rows.length) return;
    const now = this.now();
    let L = L0;
    let state = Notifier.state(L, now);
    // Arrived with nothing left to show for this leg (no change to make here, or it is time to go): on to the next leg.
    while (state.phase === 'arrived' && L.afterId) {
      const nx = this.load(L.afterId);
      if (!nx) break;
      this.db.update(liveActivities).set({ legId: nx.facts.legId }).where(eq(liveActivities.legId, L.facts.legId)).run();
      L = nx;
      state = Notifier.state(L, now);
    }
    rows = rows.map((r) => ({ ...r, legId: L.facts.legId }));
    // The card ends once the journey is over: the last leg arrived, or the train it is on cancelled.
    const event: 'update' | 'end' = state.phase === 'arrived' || state.phase === 'cancelled' ? 'end' : 'update';
    const alert = Notifier.activityAlert(L, state, now);
    const alertDue = alert !== null && !this.logged(L.facts.legId, 'activityAlert', alert.key);
    const { progress: _p, ...shown } = state;
    const words = JSON.stringify(shown);
    const full = JSON.stringify(state);
    const sec = Math.floor(now / 1000);
    let alerted = false;
    for (const row of rows) {
      const prev = this.lastActivity.get(row.token);
      if (event === 'update' && !alertDue && prev) {
        if (prev.full === full && now - prev.at < HEARTBEAT_MS) continue;
        // The line moves all the time; the words change rarely. At most one update a minute for a moving line.
        if (prev.words === words && now - prev.at < MIN) continue;
      }
      const r = await this.apns.send({
        token: row.token,
        environment: row.environment as 'sandbox' | 'production',
        pushType: 'liveactivity',
        // Apple budgets priority 10; 5 doesn't count. Only an update that lights the screen needs 10.
        priority: alertDue ? 10 : 5,
        payload: {
          aps: {
            timestamp: sec,
            event,
            'content-state': state,
            ...(event === 'end' ? { 'dismissal-date': sec + DISMISS_SEC } : { 'stale-date': sec + STALE_SEC }),
            ...(alertDue ? { alert: { title: alert.title, body: alert.body } } : {}),
          },
        },
      });
      if (r.ok) {
        alerted ||= alertDue;
        if (event === 'end') {
          this.db.delete(liveActivities).where(eq(liveActivities.token, row.token)).run();
          this.lastActivity.delete(row.token);
        } else this.lastActivity.set(row.token, { words, full, at: now });
      } else if (r.dead) {
        this.db.delete(liveActivities).where(eq(liveActivities.token, row.token)).run();
        this.lastActivity.delete(row.token);
      } else {
        // Not delivered, but the card is still there: keep its address and try again on the next tick.
        this.opts.log?.(`push: activity ${event} to ${row.token.slice(0, 8)}… failed: ${r.status} ${r.reason ?? ''}`);
      }
    }
    if (alerted) this.log(L.facts.legId, 'activityAlert', alert!.key);
  }

  /**
   * From half an hour before departure, start the card on phones that can be started remotely (iOS 17.2+). One card per
   * journey: none if any leg of it has one or has had one started. Logged only once Apple took it, so a failed start is
   * tried again on the next tick.
   */
  private async startActivity(L: Loaded) {
    const f = L.facts;
    const now = this.now();
    if (!this.apns || f.canceled || f.arrived || f.expDep === null || f.expDep - now > 30 * MIN) return;
    const journey = L.journeyLegIds.length ? L.journeyLegIds : [f.legId];
    if (this.db.select({ t: liveActivities.token }).from(liveActivities).where(inArray(liveActivities.legId, journey)).get()) return;
    if (this.db.select({ k: pushLog.kind }).from(pushLog).where(and(inArray(pushLog.legId, journey), eq(pushLog.kind, 'activity'))).get()) return;
    const starts = this.devicesOf(L.userId).filter((d) => d.startToken);
    if (!starts.length) return;
    const sec = Math.floor(now / 1000);
    const route = t(L.lang, 'route', { from: f.from, to: f.to });
    // Apple wants an alert with every remote start. Never empty: when the train has left, the route says what it is.
    const alert = f.departed ? { title: L.subtitle ?? route, body: route } : { title: route, body: departureLine(f, f.expDep, L.lang) };
    let started = false;
    for (const d of starts) {
      const r = await this.apns.send({
        token: d.startToken!,
        environment: d.environment as 'sandbox' | 'production',
        pushType: 'liveactivity',
        priority: 10,
        payload: {
          aps: {
            timestamp: sec,
            event: 'start',
            'content-state': Notifier.state(L, now),
            'stale-date': sec + STALE_SEC,
            'attributes-type': 'TripActivityAttributes',
            attributes: { legId: f.legId, journeyId: f.journeyId, train: f.train, from: f.from, to: f.to, fromTz: f.fromTz, toTz: f.toTz, color: L.operatorColor },
            'input-push-token': 1,
            alert,
          },
        },
      });
      if (r.ok) started = true;
      else if (r.dead) this.db.update(devices).set({ startToken: null }).where(eq(devices.token, d.token)).run();
      else this.opts.log?.(`push: activity start to ${d.startToken!.slice(0, 8)}… failed: ${r.status} ${r.reason ?? ''}`);
    }
    if (started) this.log(f.legId, 'activity', '');
  }
}
