import crypto from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { DEFAULT_SETTINGS } from '@clack/shared';
import { openDb } from '../src/db/client.js';
import { devices, journeys, legs, liveActivities, liveState, pushLog, stations, users } from '../src/db/schema.js';
import { ApnsClient, type Transport, type TransportRequest } from '../src/push/apns.js';
import { Notifier } from '../src/push/notifier.js';
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
    expect(aps['content-state']).toMatchObject({ status: 'en_route', delayMin: 6, nextStop: 'Jönköping C', progress: 0.4, platformFor: 'departure' });
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
