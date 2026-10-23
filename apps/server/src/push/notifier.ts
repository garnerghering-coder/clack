// Turns the live tracker's changes into alerts and Live Activity updates on people's phones (owner, 2026-10-23).
// Listens to the tracker, and every minute looks at the trips about to leave or running. What is due and what it says
// are in rules.ts; this loads the facts, sends once per alert (push_log), and forgets phones Apple says are gone.
import { and, asc, eq, gt, inArray, lt, ne } from 'drizzle-orm';
import { DEFAULT_SETTINGS, type Language, type Settings } from '@clack/shared';
import type { Db } from '../db/client.js';
import { devices, legs, liveActivities, liveState, operators, pushLog, stations, users } from '../db/schema.js';
import { liveBus, type LiveUpdate } from '../live/tracker.js';
import { alertPayload, type ApnsClient } from './apns.js';
import { change, fromEvents, getOff, reminder, type Alert, type Prefs, type TripFacts } from './rules.js';
import { t } from './text.js';

const MIN = 60_000;
const ms = (d: Date | null | undefined) => (d ? d.getTime() : null);

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
}

interface Loaded {
  userId: string;
  lang: Language;
  prefs: Prefs;
  facts: TripFacts;
  /** The leg that follows in the same journey, from where this one ends. */
  next: TripFacts | null;
  live: { status: string; nextStopId: string | null; eta: number | null; progress: number | null } | null;
  nextStopName: string | null;
  operatorColor: string | null;
}

export interface NotifierOptions {
  now?: () => number;
  log?: (m: string) => void;
}

export class Notifier {
  private lastActivity = new Map<string, { json: string; at: number }>();

  constructor(
    private db: Db,
    private apns: ApnsClient | null,
    private opts: NotifierOptions = {},
  ) {}

  private now() {
    return (this.opts.now ?? Date.now)();
  }

  private station(id: string) {
    return this.db.select({ name: stations.name, tz: stations.tz }).from(stations).where(eq(stations.id, id)).get();
  }

  private factsOf(row: typeof legs.$inferSelect, siblings: (typeof legs.$inferSelect)[]): TripFacts | null {
    const from = this.station(row.originStationId);
    const to = this.station(row.destStationId);
    if (!from || !to) return null;
    const live = this.db.select().from(liveState).where(eq(liveState.legId, row.id)).get();
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
  }

  load(legId: string): Loaded | null {
    const row = this.db.select().from(legs).where(eq(legs.id, legId)).get();
    if (!row) return null;
    const user = this.db.select({ settings: users.settings }).from(users).where(eq(users.id, row.userId)).get();
    const settings = { ...DEFAULT_SETTINGS, ...((user?.settings as Partial<Settings>) ?? {}) };
    const siblings = row.journeyId ? this.db.select().from(legs).where(eq(legs.journeyId, row.journeyId)).orderBy(asc(legs.schedDep)).all() : [row];
    const facts = this.factsOf(row, siblings);
    if (!facts) return null;
    const nextRow = siblings.find((s) => s.id !== row.id && (ms(s.schedDep) ?? 0) > (ms(row.schedDep) ?? 0) && s.originStationId === row.destStationId);
    const lv = this.db.select().from(liveState).where(eq(liveState.legId, legId)).get();
    return {
      userId: row.userId,
      lang: settings.language,
      prefs: settings,
      facts,
      next: nextRow ? this.factsOf(nextRow, siblings) : null,
      live: lv ? { status: lv.status, nextStopId: lv.nextStopId, eta: ms(lv.eta), progress: lv.progress } : null,
      nextStopName: lv?.nextStopId ? (this.station(lv.nextStopId)?.name ?? null) : null,
      operatorColor: row.operatorId ? (this.db.select({ c: operators.brandColor }).from(operators).where(eq(operators.id, row.operatorId)).get()?.c ?? null) : null,
    };
  }

  /** The tracker saw changes on a leg. */
  async onUpdate(u: LiveUpdate) {
    const L = this.load(u.legId);
    if (!L) return;
    for (const a of fromEvents(L.facts, u.events, L.prefs, L.lang)) await this.deliver(L, a);
    await this.checks(L);
    await this.pushActivity(L, u.events.some((e) => e.type === 'arrived') ? 'end' : 'update');
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

  /** Every minute: trips leaving within the next 4 hours or still running. */
  async tick() {
    const now = this.now();
    const withDevice = new Set(this.db.select({ id: devices.userId }).from(devices).all().map((d) => d.id));
    if (!withDevice.size) return;
    const rows = this.db
      .select({ id: legs.id, userId: legs.userId })
      .from(legs)
      .where(and(ne(legs.status, 'snapshotted'), eq(legs.canceled, false), lt(legs.schedDep, new Date(now + 4 * 60 * MIN)), gt(legs.schedArr, new Date(now - 30 * MIN))))
      .all()
      .filter((r) => withDevice.has(r.userId));
    for (const r of rows) {
      const L = this.load(r.id);
      if (!L || !L.prefs.notify) continue;
      await this.checks(L);
      await this.startActivity(L);
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

  private forget(token: string) {
    this.db.delete(devices).where(eq(devices.token, token)).run();
    this.db.delete(liveActivities).where(eq(liveActivities.token, token)).run();
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
        payload: alertPayload({ ...a, legId: L.facts.legId, journeyId: L.facts.journeyId }),
      });
      if (r.ok) delivered = true;
      else if (r.dead) this.forget(d.token);
      else this.opts.log?.(`push: ${a.kind} to ${d.token.slice(0, 8)}… failed: ${r.status} ${r.reason ?? ''}`);
    }
    // Nothing got through (a network problem, not a dead phone): let a later tick try again.
    if (!delivered)
      this.db.delete(pushLog).where(and(eq(pushLog.legId, L.facts.legId), eq(pushLog.kind, a.kind), eq(pushLog.key, a.key))).run();
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
    };
  }

  /** The live card for a trip that already has one running: new numbers only when something a person reads changed. */
  async pushActivity(L: Loaded, event: 'update' | 'end') {
    if (!this.apns || !L.prefs.notify) return;
    const rows = this.db.select().from(liveActivities).where(eq(liveActivities.legId, L.facts.legId)).all();
    const now = this.now();
    const state = Notifier.state(L, now);
    for (const row of rows) {
      const { progress: _p, ...shown } = state;
      const json = JSON.stringify(shown);
      const prev = this.lastActivity.get(row.token);
      // The line moves all the time; the words change rarely. At most one update a minute for a moving line.
      if (event === 'update' && prev && prev.json === json && now - prev.at < MIN) continue;
      const sec = Math.floor(now / 1000);
      const r = await this.apns.send({
        token: row.token,
        environment: row.environment as 'sandbox' | 'production',
        pushType: 'liveactivity',
        priority: 10,
        payload: { aps: { timestamp: sec, event, 'content-state': state, 'stale-date': sec + 15 * 60, ...(event === 'end' ? { 'dismissal-date': sec + 10 * 60 } : {}) } },
      });
      if (r.ok) this.lastActivity.set(row.token, { json, at: now });
      if (event === 'end' || r.dead) {
        this.db.delete(liveActivities).where(eq(liveActivities.token, row.token)).run();
        this.lastActivity.delete(row.token);
      }
    }
  }

  /** From half an hour before departure, start the card on phones that can be started remotely (iOS 17.2+). */
  private async startActivity(L: Loaded) {
    const f = L.facts;
    if (!this.apns || f.canceled || f.arrived || f.expDep === null || f.expDep - this.now() > 30 * MIN) return;
    if (this.db.select().from(liveActivities).where(eq(liveActivities.legId, f.legId)).get()) return;
    const starts = this.devicesOf(L.userId).filter((d) => d.startToken);
    if (!starts.length) return;
    const first = this.db.insert(pushLog).values({ legId: f.legId, kind: 'activity', key: '', sentAt: new Date(this.now()) }).onConflictDoNothing().run().changes;
    if (!first) return;
    const sec = Math.floor(this.now() / 1000);
    for (const d of starts) {
      await this.apns.send({
        token: d.startToken!,
        environment: d.environment as 'sandbox' | 'production',
        pushType: 'liveactivity',
        priority: 10,
        payload: {
          aps: {
            timestamp: sec,
            event: 'start',
            'content-state': Notifier.state(L, this.now()),
            'attributes-type': 'TripActivityAttributes',
            attributes: { legId: f.legId, journeyId: f.journeyId, train: f.train, from: f.from, to: f.to, fromTz: f.fromTz, toTz: f.toTz, color: L.operatorColor },
            'input-push-token': 1,
            alert: { title: t(L.lang, 'route', { from: f.from, to: f.to }), body: f.depPlatform ? t(L.lang, 'reminderPlatform', { time: new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: f.fromTz }).format(new Date(f.expDep)), platform: f.depPlatform }) : '' },
          },
        },
      });
    }
  }
}


