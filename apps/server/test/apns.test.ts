import crypto from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { alertPayload, ApnsClient, backgroundPayload, buildRequest, providerToken, WIDGET_PAYLOAD, type ApnsConfig, type Transport } from '../src/push/apns.js';

const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'P-256' });
const cfg: ApnsConfig = { keyId: 'ABC123DEFG', teamId: 'TEAM123456', keyPem: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(), topic: 'com.example.Clack' };

describe('APNs', () => {
  it('signs a provider token Apple can verify', () => {
    const jwt = providerToken(cfg, 1_800_000_000);
    const [h, p, s] = jwt.split('.') as [string, string, string];
    expect(JSON.parse(Buffer.from(h, 'base64url').toString())).toEqual({ alg: 'ES256', kid: 'ABC123DEFG' });
    expect(JSON.parse(Buffer.from(p, 'base64url').toString())).toEqual({ iss: 'TEAM123456', iat: 1_800_000_000 });
    const ok = crypto.verify('sha256', Buffer.from(`${h}.${p}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(s, 'base64url'));
    expect(ok).toBe(true);
  });

  it('builds an alert request for the right host and topic', () => {
    const r = buildRequest(cfg, { token: 'dead', environment: 'sandbox', pushType: 'alert', payload: { a: 1 }, collapseId: 'x' }, 'JWT');
    expect(r.host).toBe('api.sandbox.push.apple.com');
    expect(r.path).toBe('/3/device/dead');
    expect(r.headers['apns-topic']).toBe('com.example.Clack');
    expect(r.headers['apns-push-type']).toBe('alert');
    expect(r.headers['apns-collapse-id']).toBe('x');
    expect(r.headers.authorization).toBe('bearer JWT');
  });

  it('uses the liveactivity topic and the production host for Live Activities', () => {
    const r = buildRequest(cfg, { token: 't', environment: 'production', pushType: 'liveactivity', payload: {} }, 'JWT');
    expect(r.host).toBe('api.push.apple.com');
    expect(r.headers['apns-topic']).toBe('com.example.Clack.push-type.liveactivity');
  });

  it('sends background pushes to the bundle id, always at priority 5', () => {
    const r = buildRequest(cfg, { token: 't', environment: 'sandbox', pushType: 'background', priority: 10, expiration: 99, payload: backgroundPayload({ legId: 'L', reason: 'delay' }) }, 'JWT');
    expect(r.headers['apns-topic']).toBe('com.example.Clack');
    expect(r.headers['apns-push-type']).toBe('background');
    expect(r.headers['apns-priority']).toBe('5');
    expect(r.headers['apns-expiration']).toBe('99');
    expect(JSON.parse(r.body)).toEqual({ aps: { 'content-available': 1 }, clack: { legId: 'L', reason: 'delay' } });
  });

  it('sends widget pushes to the widgets topic with content-changed', () => {
    const r = buildRequest(cfg, { token: 'w', environment: 'production', pushType: 'widgets', expiration: 99, payload: WIDGET_PAYLOAD }, 'JWT');
    expect(r.host).toBe('api.push.apple.com');
    expect(r.path).toBe('/3/device/w');
    expect(r.headers['apns-topic']).toBe('com.example.Clack.push-type.widgets');
    expect(r.headers['apns-push-type']).toBe('widgets');
    expect(r.headers['apns-priority']).toBeUndefined();
    expect(JSON.parse(r.body)).toEqual({ aps: { 'content-changed': true } });
  });

  it('reports a dead address so it can be forgotten', async () => {
    const dead: Transport = async () => ({ status: 410, body: '{"reason":"Unregistered"}' });
    const r = await new ApnsClient(cfg, dead).send({ token: 't', environment: 'sandbox', pushType: 'alert', payload: {} });
    expect(r).toMatchObject({ ok: false, status: 410, reason: 'Unregistered', dead: true });
    const bad: Transport = async () => ({ status: 400, body: '{"reason":"BadDeviceToken"}' });
    expect((await new ApnsClient(cfg, bad).send({ token: 't', environment: 'sandbox', pushType: 'alert', payload: {} })).dead).toBe(true);
    const busy: Transport = async () => ({ status: 429, body: '{"reason":"TooManyRequests"}' });
    expect((await new ApnsClient(cfg, busy).send({ token: 't', environment: 'sandbox', pushType: 'alert', payload: {} })).dead).toBe(false);
  });

  it('survives a network failure and reuses the token', async () => {
    let calls = 0;
    const seen: string[] = [];
    const flaky: Transport = async (r) => {
      calls++;
      seen.push(r.headers.authorization!);
      if (calls === 1) throw new Error('down');
      return { status: 200, body: '' };
    };
    const client = new ApnsClient(cfg, flaky);
    expect((await client.send({ token: 't', environment: 'sandbox', pushType: 'alert', payload: {} })).ok).toBe(false);
    expect((await client.send({ token: 't', environment: 'sandbox', pushType: 'alert', payload: {} })).ok).toBe(true);
    expect(seen[0]).toBe(seen[1]);
  });

  it('puts the trip and urgency in the alert payload', () => {
    const p = alertPayload({ title: 'T', body: 'B', legId: 'L', kind: 'cancel', journeyId: 'j-L', timeSensitive: true }) as { aps: Record<string, unknown>; legId: string; journeyId: string };
    expect(p.aps['interruption-level']).toBe('time-sensitive');
    expect(p.aps['thread-id']).toBe('L');
    expect(p.legId).toBe('L');
    expect(p.journeyId).toBe('j-L');
  });
});
