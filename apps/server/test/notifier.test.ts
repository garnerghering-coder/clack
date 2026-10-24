import crypto from 'node:crypto';
import { describe, expect, it, vi } from 'vitest';
import { eq } from 'drizzle-orm';
import { DEFAULT_SETTINGS } from '@clack/shared';
import { openDb } from '../src/db/client.js';
import { devices, journeys, legEvents, legs, liveActivities, liveState, pushLog, stations, users } from '../src/db/schema.js';
import { ApnsClient, type Transport, type TransportRequest } from '../src/push/apns.js';
import { freshReason, Notifier } from '../src/push/notifier.js';
import type { LiveUpdate } from '../src/live/tracker.js';

const { privateKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'P-256' });
const cfg = { keyId: 'K', teamId: 'T', keyPem: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(), topic: 'com.example.Clack' };

const U = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
const TOKEN = 'a'.repeat(64);
const NOW = Date.parse('2026-10-20T11:00:00Z'); // 13:00 in Stockholm

function setup(opts: { notify?: boolean; status?: number } = {}) {
  const db = openDb(':memory:');
  const sent: TransportRequest[] = [];
  const transport: Transport = async (r) => {
    sent.push(r);
    return { status: opts.status ?? 200, body: opts.status === 410 ? '{"reason":"Unregistered"}' : '' };
  };
  const base = { country: 'SE', lat: 57, lon: 14, tz: 'Europe/Stockholm', coordSource: 'gtfs' as const };
  db.insert(stations).values([{ id: 'N', name: 'Nässjö C', ...base }, { id: 'J', name: 'Jönköping C', ...base }]).run();
  db.insert(users).values({ id: U, settings: { ...DEFAULT_SETTINGS, notify: opts.notify ?? true } }).run();
  db.insert(devices).values({ token: TOKEN, userId: U, environment: 'sandbox', lastSeenAt: new Date(NOW) }).run();
  db.insert(journeys).values({ id: 'j-L1', userId: U }).run();
  const dep = NOW + 60 * 60_000; // leaves in an hour
  db.insert(legs)
    .values({ id: 'L1', userId: U, journeyId: 'j-L1', dataQuality: 'full', originStationId: 'N', destStationId: 'J', trainNumber: '7205', schedDep: new Date(dep), schedArr: new Date(dep + 33 * 60_000), depPlatform: '5' })
    .run();
  const notifier = new Notifier(db, new ApnsClient(cfg, transport, () => NOW), { now: () => NOW });
  return { db, sent, notifier };
}

const bodies = (sent: TransportRequest[]) => sent.map((r) => JSON.parse(r.body) as { aps: { alert?: { title: string; body: string }; event?: string }; kind?: string });

describe('notifier', () => {
  it('sends the departure reminder once, with the platform', async () => {
    const { sent, notifier } = setup();
    await notifier.tick();
    await notifier.tick();
    expect(sent).toHaveLength(1);
    expect(sent[0]!.path).toBe(`/3/device/${TOKEN}`);
    expect(sent[0]!.host).toBe('api.sandbox.push.apple.com');
    expect(bodies(sent)[0]!.aps.alert).toEqual({ title: 'Nässjö C → Jönköping C', subtitle: '7205', body: 'Leaves 14:00 from platform 5.' });
    expect((JSON.parse(sent[0]!.body) as { aps: { sound: string } }).aps.sound).toBe('sbb_jingle.wav');
  });

  it('says nothing to someone who has alerts off, or before the lead time', async () => {
    const off = setup({ notify: false });
    await off.notifier.tick();
    expect(off.sent).toHaveLength(0);
    const early = setup();
    early.db.update(users).set({ settings: { ...DEFAULT_SETTINGS, notify: true, notifyLeadMin: 30 } }).run();
    await early.notifier.tick();
    expect(early.sent).toHaveLength(0);
  });

  it('turns a tracker event into an alert and does not repeat it', async () => {
    const { sent, notifier } = setup();
    const update: LiveUpdate = {
      legId: 'L1',
      live: { status: 'boarding' } as LiveUpdate['live'],
      events: [{ type: 'platform_changed', ts: NOW, payload: { which: 'departure', from: '5', to: '7' } }],
    };
    await notifier.onUpdate(update);
    await notifier.onUpdate(update);
    const platform = bodies(sent).filter((b) => b.kind === 'platform');
    expect(platform).toHaveLength(1);
    expect(platform[0]!.aps.alert!.body).toBe('Platform changed: now platform 7, was 5.');
  });

  it('forgets a phone Apple says is gone', async () => {
    const { db, notifier } = setup({ status: 410 });
    await notifier.tick();
    expect(db.select().from(devices).all()).toHaveLength(0);
  });

  it('retries later when nothing got through', async () => {
    const { db, notifier } = setup({ status: 500 });
    await notifier.tick();
    expect(db.select().from(pushLog).all()).toHaveLength(0);
    expect(db.select().from(devices).all()).toHaveLength(1);
  });

  it('welcomes you only when the whole journey is done', async () => {
    const { db, sent, notifier } = setup();
    const dep = NOW + 60 * 60_000;
    db.insert(legs)
      .values({ id: 'L2', userId: U, journeyId: 'j-L1', dataQuality: 'full', originStationId: 'J', destStationId: 'N', schedDep: new Date(dep + 50 * 60_000), schedArr: new Date(dep + 80 * 60_000) })
      .run();
    const arrived = (legId: string): LiveUpdate => ({ legId, live: { status: 'arrived' } as LiveUpdate['live'], events: [{ type: 'arrived', ts: NOW, payload: { at: NOW } }] });
    await notifier.onUpdate(arrived('L1'));
    expect(bodies(sent).filter((b) => b.kind === 'arrival')).toHaveLength(0);
    await notifier.onUpdate(arrived('L2'));
    expect(bodies(sent).find((b) => b.kind === 'arrival')!.aps.alert!.title).toBe('Welcome to Nässjö C');
  });

  it('keeps a running Live Activity up to date and ends it on arrival', async () => {
    const { db, sent, notifier } = setup();
    db.insert(liveActivities).values({ token: 'b'.repeat(64), userId: U, legId: 'L1', environment: 'sandbox' }).run();
    db.insert(liveState).values({ legId: 'L1', updatedAt: new Date(NOW), status: 'en_route', progress: 0.4, nextStopId: 'J', eta: new Date(NOW + 600_000), arrivalDelayMin: 6 }).run();
    await notifier.onUpdate({ legId: 'L1', live: { status: 'en_route' } as LiveUpdate['live'], events: [] });
    const la = sent.find((r) => r.headers['apns-push-type'] === 'liveactivity')!;
    expect(la.headers['apns-topic']).toBe('com.example.Clack.push-type.liveactivity');
    const aps = (JSON.parse(la.body) as { aps: { event: string; 'content-state': Record<string, unknown> } }).aps;
    expect(aps.event).toBe('update');
    expect(aps['content-state']).toMatchObject({ status: 'en_route', delayMin: 6, nextStop: 'Jönköping C', progress: 0.4, platformFor: 'departure', phase: 'getOffSoon' });
    db.update(legs).set({ actualDep: new Date(NOW - 30 * 60_000), actualArr: new Date(NOW) }).run();
    await notifier.onUpdate({ legId: 'L1', live: { status: 'arrived' } as LiveUpdate['live'], events: [{ type: 'arrived', ts: NOW, payload: { at: NOW } }] });
    expect(sent.filter((r) => r.headers['apns-push-type'] === 'liveactivity').map((r) => (JSON.parse(r.body) as { aps: { event: string } }).aps.event)).toEqual(['update', 'end']);
    expect(db.select().from(liveActivities).all()).toHaveLength(0);
  });

  it('starts a Live Activity on a phone that can be started remotely', async () => {
    const { db, sent, notifier } = setup();
    db.update(devices).set({ startToken: 'c'.repeat(64) }).run();
    db.update(legs).set({ schedDep: new Date(NOW + 20 * 60_000), schedArr: new Date(NOW + 53 * 60_000) }).run();
    await notifier.tick();
    await notifier.tick();
    const starts = bodies(sent).filter((b) => b.aps.event === 'start');
    expect(starts).toHaveLength(1);
    expect(sent.find((r) => r.path.includes('c'.repeat(64)))!.headers['apns-push-type']).toBe('liveactivity');
  });
});

// ---------- Live Activities: start, priorities, one card per journey ----------

type Reply = { status: number; body?: string };
interface Aps {
  event?: string;
  timestamp?: number;
  'stale-date'?: number;
  'dismissal-date'?: number;
  alert?: { title: string; body: string };
  'content-state'?: Record<string, unknown>;
}

/** A journey of two legs, Nässjö → Jönköping → Nässjö, a phone, and a clock that can be moved. */
function world(o: { reply?: (r: TransportRequest) => Reply; startToken?: boolean } = {}) {
  const db = openDb(':memory:');
  const clock = { now: NOW };
  const sent: TransportRequest[] = [];
  const transport: Transport = async (r) => {
    sent.push(r);
    const x = o.reply?.(r) ?? { status: 200 };
    return { status: x.status, body: x.body ?? '' };
  };
  const base = { country: 'SE', lat: 57, lon: 14, tz: 'Europe/Stockholm', coordSource: 'gtfs' as const };
  db.insert(stations).values([{ id: 'N', name: 'Nässjö C', ...base }, { id: 'J', name: 'Jönköping C', ...base }]).run();
  db.insert(users).values({ id: U, settings: { ...DEFAULT_SETTINGS, notify: true } }).run();
  db.insert(devices).values({ token: TOKEN, userId: U, environment: 'sandbox', startToken: o.startToken === false ? null : START, lastSeenAt: new Date(NOW) }).run();
  db.insert(journeys).values({ id: 'j1', userId: U }).run();
  const leg = { userId: U, journeyId: 'j1', dataQuality: 'full' as const };
  db.insert(legs)
    .values([
      { id: 'L1', ...leg, originStationId: 'N', destStationId: 'J', trainNumber: '7205', schedDep: new Date(NOW + 20 * MIN_), schedArr: new Date(NOW + 53 * MIN_), depPlatform: '5' },
      { id: 'L2', ...leg, originStationId: 'J', destStationId: 'N', trainNumber: '7230', schedDep: new Date(NOW + 70 * MIN_), schedArr: new Date(NOW + 100 * MIN_), depPlatform: '2' },
    ])
    .run();
  const notifier = new Notifier(db, new ApnsClient(cfg, transport, () => clock.now), { now: () => clock.now });
  const aps = (r: TransportRequest) => (JSON.parse(r.body) as { aps: Aps }).aps;
  const activity = () => sent.filter((r) => r.headers['apns-push-type'] === 'liveactivity');
  return { db, sent, clock, notifier, aps, activity };
}
const MIN_ = 60_000;
const START = 'c'.repeat(64);
const CARD = 'b'.repeat(64);

describe('Live Activities', () => {
  it('starts with a stale date and an alert that always says something', async () => {
    const w = world();
    w.db.update(legs).set({ depPlatform: null }).where(eq(legs.id, 'L1')).run();
    await w.notifier.tick();
    const start = w.activity().find((r) => r.path.endsWith(START))!;
    expect(start.headers['apns-priority']).toBe('10');
    expect(start.headers['apns-topic']).toBe('com.example.Clack.push-type.liveactivity');
    const a = w.aps(start);
    expect(a.event).toBe('start');
    expect(a['stale-date']).toBe(Math.floor(NOW / 1000) + 300);
    expect(a['dismissal-date']).toBeUndefined();
    expect(a.alert).toEqual({ title: 'Nässjö C → Jönköping C', body: 'Leaves 13:20. Platform not announced yet.' });
    expect(a['content-state']).toMatchObject({ legId: 'L1', train: '7205', from: 'Nässjö C', to: 'Jönköping C', phase: 'leaveSoon' });
  });

  it('tries a failed start again on the next tick, and logs it only once Apple took it', async () => {
    let fail = true;
    const w = world({ reply: (r) => (r.path.endsWith(START) && fail ? { status: 503, body: '{"reason":"ServiceUnavailable"}' } : { status: 200 }) });
    await w.notifier.tick();
    expect(w.db.select().from(pushLog).where(eq(pushLog.kind, 'activity')).all()).toHaveLength(0);
    fail = false;
    await w.notifier.tick();
    await w.notifier.tick();
    expect(w.activity().filter((r) => r.path.endsWith(START))).toHaveLength(2);
    expect(w.db.select().from(pushLog).where(eq(pushLog.kind, 'activity')).all()).toHaveLength(1);
  });

  it('forgets a dead start address but keeps the phone', async () => {
    const w = world({ reply: (r) => (r.path.endsWith(START) ? { status: 410, body: '{"reason":"Unregistered"}' } : { status: 200 }) });
    await w.notifier.tick();
    const d = w.db.select().from(devices).get()!;
    expect(d.startToken).toBeNull();
    expect(d.token).toBe(TOKEN);
  });

  it('sends routine updates at priority 5 with a fresh stale date, and 10 only with an alert', async () => {
    const w = world({ startToken: false });
    w.db.insert(liveActivities).values({ token: CARD, userId: U, legId: 'L1', environment: 'sandbox' }).run();
    await w.notifier.tick();
    let u = w.activity().at(-1)!;
    expect(u.headers['apns-priority']).toBe('5');
    expect(w.aps(u)).toMatchObject({ event: 'update', 'stale-date': Math.floor(NOW / 1000) + 300 });
    expect(w.aps(u).alert).toBeUndefined();
    // Nothing changed a minute later: nothing sent. Four minutes on: the same again, so the card doesn't go stale.
    const n = w.activity().length;
    w.clock.now += MIN_;
    await w.notifier.tick();
    expect(w.activity()).toHaveLength(n);
    w.clock.now += 3 * MIN_;
    await w.notifier.tick();
    expect(w.activity()).toHaveLength(n + 1);
    expect(w.aps(w.activity().at(-1)!)['stale-date']).toBe(Math.floor(w.clock.now / 1000) + 300);
    // The platform changes: lights the screen once, at priority 10.
    w.db.update(legs).set({ depPlatform: '7' }).where(eq(legs.id, 'L1')).run();
    w.db.insert(legEvents).values({ legId: 'L1', ts: new Date(w.clock.now), type: 'platform_changed', payload: { which: 'departure', from: '5', to: '7' } }).run();
    await w.notifier.onUpdate({ legId: 'L1', live: null as unknown as LiveUpdate['live'], events: [] });
    u = w.activity().at(-1)!;
    expect(u.headers['apns-priority']).toBe('10');
    expect(w.aps(u).alert).toEqual({ title: 'Nässjö C → Jönköping C', body: 'Platform changed: now platform 7, was 5.' });
    w.clock.now += 5 * MIN_;
    await w.notifier.tick();
    u = w.activity().at(-1)!;
    expect(u.headers['apns-priority']).toBe('5');
    expect(w.aps(u).alert).toBeUndefined();
  });

  it('keeps the card when an end fails for a passing reason, and ends it on a later tick', async () => {
    let fail = true;
    const w = world({ startToken: false, reply: (r) => (r.path.endsWith(CARD) && fail ? { status: 500, body: '{"reason":"InternalServerError"}' } : { status: 200 }) });
    w.db.insert(liveActivities).values({ token: CARD, userId: U, legId: 'L2', environment: 'sandbox' }).run();
    w.db.update(legs).set({ canceled: true }).where(eq(legs.id, 'L2')).run();
    await w.notifier.tick();
    expect(w.aps(w.activity().at(-1)!).event).toBe('end');
    expect(w.db.select().from(liveActivities).all()).toHaveLength(1);
    fail = false;
    await w.notifier.tick();
    const end = w.activity().at(-1)!;
    expect(w.aps(end)).toMatchObject({ event: 'end', 'dismissal-date': Math.floor(NOW / 1000) + 600 });
    expect(w.aps(end).alert?.title).toBe('Cancelled: Jönköping C → Nässjö C');
    expect(end.headers['apns-priority']).toBe('10');
    expect(w.db.select().from(liveActivities).all()).toHaveLength(0);
  });

  it('forgets a dead phone together with the cards that ran on it, not other phones’ cards', async () => {
    const w = world({ startToken: false, reply: (r) => (r.path.endsWith(TOKEN) ? { status: 410, body: '{"reason":"Unregistered"}' } : { status: 200 }) });
    const OTHER = 'd'.repeat(64);
    w.db.insert(devices).values({ token: OTHER, userId: U, environment: 'sandbox', lastSeenAt: new Date(NOW) }).run();
    w.db.insert(liveActivities).values([
      { token: CARD, userId: U, legId: 'L1', environment: 'sandbox', deviceToken: TOKEN },
      { token: 'e'.repeat(64), userId: U, legId: 'L1', environment: 'sandbox', deviceToken: OTHER },
    ]).run();
    // The reminder (an hour's lead) goes to both phones; Apple says the first is gone.
    await w.notifier.tick();
    expect(w.db.select().from(devices).all().map((d) => d.token)).toEqual([OTHER]);
    expect(w.db.select().from(liveActivities).all().map((a) => a.deviceToken)).toEqual([OTHER]);
  });

  it('keeps one card for the whole journey: changing trains, then the next train, then the end', async () => {
    const w = world();
    await w.notifier.tick();
    expect(w.activity().filter((r) => w.aps(r).event === 'start')).toHaveLength(1);
    // The phone registers the started card's update address.
    w.db.insert(liveActivities).values({ token: CARD, userId: U, legId: 'L1', environment: 'sandbox', deviceToken: TOKEN }).run();
    // L1 arrives; L2 leaves 17 minutes later from the same station: the card shows the change.
    w.clock.now = NOW + 53 * MIN_;
    w.db.update(legs).set({ actualDep: new Date(NOW + 20 * MIN_), actualArr: new Date(NOW + 53 * MIN_) }).where(eq(legs.id, 'L1')).run();
    await w.notifier.tick();
    let last = w.aps(w.activity().at(-1)!);
    expect(last.event).toBe('update');
    expect(last['content-state']).toMatchObject({ phase: 'changing', legId: 'L1', changePlatform: '2', changeAt: NOW + 70 * MIN_ });
    // No second card for the second leg, though it is now within half an hour.
    expect(w.activity().filter((r) => w.aps(r).event === 'start')).toHaveLength(1);
    // L2 has left: the same card now shows L2.
    w.clock.now = NOW + 72 * MIN_;
    w.db.update(legs).set({ actualDep: new Date(NOW + 71 * MIN_) }).where(eq(legs.id, 'L2')).run();
    w.db.insert(liveState).values({ legId: 'L2', updatedAt: new Date(w.clock.now), status: 'en_route', progress: 0.1, nextStopId: 'N', eta: new Date(NOW + 100 * MIN_) }).run();
    await w.notifier.tick();
    last = w.aps(w.activity().at(-1)!);
    expect(w.activity().at(-1)!.path.endsWith(CARD)).toBe(true);
    expect(last.event).toBe('update');
    expect(last['content-state']).toMatchObject({ legId: 'L2', train: '7230', from: 'Jönköping C', to: 'Nässjö C', phase: 'enRoute', platformFor: 'arrival' });
    expect(w.db.select().from(liveActivities).get()!.legId).toBe('L2');
    expect(w.activity().filter((r) => w.aps(r).event === 'start')).toHaveLength(1);
    // L2 arrives: the journey is over, the card ends and leaves the Lock Screen ten minutes later.
    w.clock.now = NOW + 100 * MIN_;
    w.db.update(legs).set({ actualArr: new Date(NOW + 100 * MIN_) }).where(eq(legs.id, 'L2')).run();
    await w.notifier.tick();
    last = w.aps(w.activity().at(-1)!);
    expect(last).toMatchObject({ event: 'end', 'dismissal-date': Math.floor(w.clock.now / 1000) + 600 });
    expect(last['content-state']).toMatchObject({ legId: 'L2', phase: 'arrived' });
    expect(w.db.select().from(liveActivities).all()).toHaveLength(0);
  });

  it('moves straight on to the next leg when the change is more than an hour away', async () => {
    const w = world({ startToken: false });
    w.db.update(legs).set({ schedDep: new Date(NOW + 200 * MIN_), schedArr: new Date(NOW + 230 * MIN_) }).where(eq(legs.id, 'L2')).run();
    w.db.update(legs).set({ actualDep: new Date(NOW - 30 * MIN_), actualArr: new Date(NOW) }).where(eq(legs.id, 'L1')).run();
    w.db.insert(liveActivities).values({ token: CARD, userId: U, legId: 'L1', environment: 'sandbox' }).run();
    await w.notifier.tick();
    const last = w.aps(w.activity().at(-1)!);
    expect(last.event).toBe('update');
    expect(last['content-state']).toMatchObject({ legId: 'L2', phase: 'scheduled', platform: '2', platformFor: 'departure' });
  });

  it('loads all the due trips together, not one by one', async () => {
    const w = world();
    w.db.insert(liveActivities).values({ token: CARD, userId: U, legId: 'L1', environment: 'sandbox' }).run();
    const many = vi.spyOn(w.notifier, 'loadMany');
    const one = vi.spyOn(w.notifier, 'load');
    await w.notifier.tick();
    expect(many).toHaveBeenCalledTimes(1);
    expect(many.mock.calls[0]![0]).toEqual(expect.arrayContaining(['L1', 'L2']));
    expect(one).not.toHaveBeenCalled();
  });

  it('stops sending to a card older than Apple keeps one', async () => {
    const w = world({ startToken: false });
    w.db.insert(liveActivities).values({ token: CARD, userId: U, legId: 'L1', environment: 'sandbox', createdAt: new Date(NOW - 13 * 60 * MIN_) }).run();
    await w.notifier.tick();
    expect(w.db.select().from(liveActivities).all()).toHaveLength(0);
    expect(w.activity()).toHaveLength(0);
  });
});

// ---------- Freshness: background and widget pushes ----------

describe('freshness pushes', () => {
  const WIDGET = 'f'.repeat(64);
  const fresh = (w: ReturnType<typeof world>) => {
    const of = (type: string) => w.sent.filter((r) => r.headers['apns-push-type'] === type);
    return { bg: of('background'), widgets: of('widgets') };
  };
  const setup = (reply?: (r: TransportRequest) => Reply) => {
    const w = world({ startToken: false, reply });
    w.db.update(devices).set({ widgetToken: WIDGET }).run();
    return w;
  };

  it('wakes the app and reloads the widgets when the delay band changes, not on the first look', async () => {
    const w = setup();
    await w.notifier.tick();
    expect(fresh(w).bg).toHaveLength(0);
    // No delay known → 4 min late: a new band (packages/shared delayBand).
    w.db.update(legs).set({ arrDelayMin: 4 }).where(eq(legs.id, 'L1')).run();
    w.clock.now += MIN_;
    await w.notifier.tick();
    const { bg, widgets } = fresh(w);
    expect(bg).toHaveLength(1);
    expect(bg[0]!.path).toBe(`/3/device/${TOKEN}`);
    expect(bg[0]!.headers).toMatchObject({ 'apns-push-type': 'background', 'apns-priority': '5', 'apns-topic': 'com.example.Clack', 'apns-expiration': String(Math.floor(w.clock.now / 1000) + 3600) });
    expect(JSON.parse(bg[0]!.body)).toEqual({ aps: { 'content-available': 1 }, clack: { legId: 'L1', reason: 'delay' } });
    expect(widgets).toHaveLength(1);
    expect(widgets[0]!.path).toBe(`/3/device/${WIDGET}`);
    expect(widgets[0]!.host).toBe('api.sandbox.push.apple.com');
    expect(widgets[0]!.headers['apns-topic']).toBe('com.example.Clack.push-type.widgets');
    expect(widgets[0]!.headers['apns-priority']).toBeUndefined();
    expect(JSON.parse(widgets[0]!.body)).toEqual({ aps: { 'content-changed': true } });
    // More minutes in the same band: nothing new.
    w.db.update(legs).set({ arrDelayMin: 9 }).where(eq(legs.id, 'L1')).run();
    w.clock.now += MIN_;
    await w.notifier.tick();
    expect(fresh(w).bg).toHaveLength(1);
  });

  it('sends at most one per phone in 15 minutes, holding the newest for later', async () => {
    const w = setup();
    await w.notifier.tick();
    w.db.update(legs).set({ arrDelayMin: 20 }).where(eq(legs.id, 'L1')).run();
    await w.notifier.tick();
    const t0 = w.clock.now;
    expect(fresh(w).bg).toHaveLength(1);
    w.clock.now = t0 + 5 * MIN_;
    w.db.update(legs).set({ depPlatform: '7' }).where(eq(legs.id, 'L1')).run();
    await w.notifier.tick();
    w.clock.now = t0 + 10 * MIN_;
    await w.notifier.tick();
    expect(fresh(w).bg).toHaveLength(1);
    expect(fresh(w).widgets).toHaveLength(1);
    w.clock.now = t0 + 15 * MIN_;
    await w.notifier.tick();
    const { bg, widgets } = fresh(w);
    expect(bg).toHaveLength(2);
    expect(JSON.parse(bg[1]!.body).clack).toEqual({ legId: 'L1', reason: 'platform' });
    expect(widgets).toHaveLength(2);
  });

  it('sends a cancellation at once, whatever the throttle', async () => {
    const w = setup();
    await w.notifier.tick();
    w.db.update(legs).set({ arrDelayMin: 20 }).where(eq(legs.id, 'L1')).run();
    await w.notifier.tick();
    w.clock.now += 2 * MIN_;
    w.db.update(legs).set({ canceled: true }).where(eq(legs.id, 'L1')).run();
    await w.notifier.onUpdate({ legId: 'L1', live: null as unknown as LiveUpdate['live'], events: [{ type: 'cancelled', ts: w.clock.now, payload: {} }] });
    const { bg, widgets } = fresh(w);
    expect(bg.map((r) => JSON.parse(r.body).clack.reason)).toEqual(['delay', 'cancelled']);
    expect(widgets).toHaveLength(2);
  });

  it('says when the journey is finished', async () => {
    const w = setup();
    w.clock.now = NOW + 95 * MIN_;
    w.db.update(legs).set({ actualDep: new Date(NOW + 20 * MIN_), actualArr: new Date(NOW + 53 * MIN_) }).where(eq(legs.id, 'L1')).run();
    w.db.update(legs).set({ actualDep: new Date(NOW + 70 * MIN_) }).where(eq(legs.id, 'L2')).run();
    await w.notifier.tick();
    w.clock.now = NOW + 100 * MIN_;
    w.db.update(legs).set({ actualArr: new Date(NOW + 100 * MIN_) }).where(eq(legs.id, 'L2')).run();
    await w.notifier.onUpdate({ legId: 'L2', live: null as unknown as LiveUpdate['live'], events: [{ type: 'arrived', ts: w.clock.now, payload: { at: w.clock.now } }] });
    expect(fresh(w).bg.map((r) => JSON.parse(r.body).clack)).toContainEqual({ legId: 'L2', reason: 'finished' });
  });

  it('forgets a dead widget address but keeps the phone', async () => {
    const w = setup((r) => (r.path.endsWith(WIDGET) ? { status: 410, body: '{"reason":"Unregistered"}' } : { status: 200 }));
    await w.notifier.tick();
    w.db.update(legs).set({ arrDelayMin: 20 }).where(eq(legs.id, 'L1')).run();
    await w.notifier.tick();
    const d = w.db.select().from(devices).get()!;
    expect(d.token).toBe(TOKEN);
    expect(d.widgetToken).toBeNull();
  });

  it('works out the reason in order of importance', () => {
    const base = { band: 'on_time', depPlatform: '5', arrPlatform: null, canceled: false, phase: 'scheduled' };
    expect(freshReason(undefined, base, true)).toBeNull();
    expect(freshReason(base, base, true)).toBeNull();
    expect(freshReason(base, { ...base, band: 'cancelled', canceled: true, phase: 'cancelled' }, true)).toBe('cancelled');
    expect(freshReason(base, { ...base, phase: 'arrived' }, true)).toBe('finished');
    expect(freshReason(base, { ...base, phase: 'arrived' }, false)).toBe('phase');
    expect(freshReason(base, { ...base, depPlatform: '6', band: 'late' }, true)).toBe('platform');
    expect(freshReason(base, { ...base, band: 'late', phase: 'leaveSoon' }, true)).toBe('delay');
  });
});
