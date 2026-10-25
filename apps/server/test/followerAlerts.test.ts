import crypto from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { eq } from 'drizzle-orm';
import { DEFAULT_SETTINGS } from '@clack/shared';
import { openDb } from '../src/db/client.js';
import { devices, journeys, legs, pushLog, stations, users } from '../src/db/schema.js';
import { ApnsClient, type Transport, type TransportRequest } from '../src/push/apns.js';
import { Notifier } from '../src/push/notifier.js';
import { createShare, follow, revokeShare } from '../src/share/shared.js';
import type { LiveUpdate } from '../src/live/tracker.js';

const { privateKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'P-256' });
const cfg = { keyId: 'K', teamId: 'T', keyPem: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(), topic: 'com.example.Clack' };
const TRAVELLER = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
const FOLLOWER = '9a8b7c6d-5e4f-4a3b-9c2d-1e0f2a3b4c5d';
const PHONE = 'b'.repeat(64);
const NOW = Date.parse('2026-10-20T11:00:00Z');
const MIN = 60_000;

/** Nässjö → Jönköping → Göteborg: two trains, 10 min between them, the first one under way. */
function setup(followerSettings: Record<string, unknown> = { notify: true }) {
  const db = openDb(':memory:');
  const sent: TransportRequest[] = [];
  const transport: Transport = async (r) => {
    sent.push(r);
    return { status: 200, body: '' };
  };
  const base = { country: 'SE', lat: 57, lon: 14, tz: 'Europe/Stockholm', coordSource: 'gtfs' as const };
  db.insert(stations).values([{ id: 'N', name: 'Nässjö C', ...base }, { id: 'J', name: 'Jönköping C', ...base }, { id: 'G', name: 'Göteborg C', ...base }]).run();
  db.insert(users).values([{ id: TRAVELLER, settings: { ...DEFAULT_SETTINGS, notify: false } }, { id: FOLLOWER, settings: { ...DEFAULT_SETTINGS, ...followerSettings } }]).run();
  db.insert(devices).values({ token: PHONE, userId: FOLLOWER, environment: 'sandbox', lastSeenAt: new Date(NOW) }).run();
  db.insert(journeys).values({ id: 'j1', userId: TRAVELLER }).run();
  const leg = (id: string, from: string, to: string, dep: number, arr: number, n: string) => ({
    id, userId: TRAVELLER, journeyId: 'j1', dataQuality: 'full', originStationId: from, destStationId: to, trainNumber: n, schedDep: new Date(dep), schedArr: new Date(arr),
  });
  db.insert(legs).values([leg('a', 'N', 'J', NOW - 20 * MIN, NOW + 10 * MIN, '7205'), leg('b', 'J', 'G', NOW + 20 * MIN, NOW + 80 * MIN, '540')]).run();
  const notifier = new Notifier(db, new ApnsClient(cfg, transport, () => NOW), { now: () => NOW });
  const share = createShare(db, TRAVELLER, { legId: 'a' }, NOW)!;
  follow(db, FOLLOWER, share.token, NOW);
  return { db, sent, notifier, token: share.token };
}

const update = (legId: string, events: LiveUpdate['events']): LiveUpdate => ({ legId, live: { status: 'en_route' } as LiveUpdate['live'], events });
const alerts = (sent: TransportRequest[]) => sent.map((r) => JSON.parse(r.body) as { aps: { alert: { title: string; body: string }; 'thread-id': string }; shareToken?: string; legId: string });

describe('alerts for someone following a shared journey', () => {
  it('tells them about a delay once, in the words of a follower, and opens the journey', async () => {
    const { sent, notifier, token } = setup();
    const u = update('a', [{ type: 'delayed', ts: NOW, payload: { delayMin: 8 } }]);
    await notifier.onUpdate(u);
    await notifier.onUpdate(u);
    expect(sent).toHaveLength(1);
    const [a] = alerts(sent);
    expect(a!.aps.alert.title).toBe('Nässjö C → Göteborg C');
    expect(a!.aps.alert.body).toMatch(/^7205 is 8 min late, now arriving Jönköping C \d\d:\d\d\.$/);
    expect(a!.shareToken).toBe(token);
    expect(a!.aps['thread-id']).toBe(token);
    expect(sent[0]!.path).toBe(`/3/device/${PHONE}`);
  });

  it('uses the follower’s own language and switches', async () => {
    const sv = setup({ notify: true, language: 'sv' });
    await sv.notifier.onUpdate(update('a', [{ type: 'platform_changed', ts: NOW, payload: { which: 'arrival', from: '1', to: '3' } }]));
    expect(alerts(sv.sent)[0]!.aps.alert.body).toBe('7205 ankommer nu till Jönköping C på spår 3.');
    const off = setup({ notify: true, notifyPlatform: false });
    await off.notifier.onUpdate(update('a', [{ type: 'platform_changed', ts: NOW, payload: { which: 'arrival', from: '1', to: '3' } }]));
    expect(off.sent).toHaveLength(0);
    const none = setup({ notify: false });
    await none.notifier.onUpdate(update('a', [{ type: 'cancelled', ts: NOW, payload: {} }]));
    expect(none.sent).toHaveLength(0);
  });

  it('warns when a delay puts the change in danger, and not when there is time', async () => {
    const late = setup();
    // Train a is now 5 min late: arrives 15 min after the timetable would say, the next leaves in 10: a miss by 5.
    late.db.update(legs).set({ arrDelayMin: 15 }).run();
    late.db.update(legs).set({ arrDelayMin: null, depDelayMin: null }).where(eq(legs.id, 'b')).run();
    await late.notifier.onUpdate(update('a', [{ type: 'delayed', ts: NOW, payload: { delayMin: 15 } }]));
    const bodies = alerts(late.sent).map((a) => a.aps.alert.body);
    expect(bodies.some((b) => /leaves \d+ min before this one arrives/.test(b))).toBe(true);
    const fine = setup();
    await fine.notifier.onUpdate(update('a', [{ type: 'delayed', ts: NOW, payload: { delayMin: 6 } }]));
    expect(alerts(fine.sent)).toHaveLength(1);
  });

  it('stops when the traveller stops sharing, and never mixes with the traveller’s own log', async () => {
    const { db, sent, notifier, token } = setup();
    revokeShare(db, TRAVELLER, token, NOW);
    await notifier.onUpdate(update('a', [{ type: 'delayed', ts: NOW, payload: { delayMin: 9 } }]));
    expect(sent).toHaveLength(0);
    const again = setup();
    await again.notifier.onUpdate(update('a', [{ type: 'delayed', ts: NOW, payload: { delayMin: 9 } }]));
    expect(again.db.select().from(pushLog).all().map((r) => [r.kind, r.key])).toEqual([['follow-delay', `${FOLLOWER}:0:9`]]);
  });

  it('says the journey arrived when its last train does', async () => {
    const { sent, notifier } = setup();
    await notifier.onUpdate(update('b', [{ type: 'arrived', ts: NOW, payload: { at: NOW } }]));
    expect(alerts(sent)[0]!.aps.alert.title).toBe('Arrived in Göteborg C');
  });
});
