import { beforeEach, describe, expect, it } from 'vitest';
import { DIGITRAFFIC_BASE, DigitrafficError, TokenBucket, digitrafficFetch, digitrafficHeaders, fetchBuffer, fetchJson, retryAfterMs } from '../src/digitraffic/client.js';
import { feedHealth, resetFeedHealth } from '../src/lib/health.js';
import { COUNTRIES, countryOfKey, countryOfLiveId, tzOf } from '../src/lib/countries.js';

type Call = { url: string; headers: Record<string, string> };
const scripted = (responses: (Response | Error)[]) => {
  const calls: Call[] = [];
  const impl = (async (url: string, init?: RequestInit) => {
    calls.push({ url, headers: init?.headers as Record<string, string> });
    const r = responses[Math.min(calls.length - 1, responses.length - 1)]!;
    if (r instanceof Error) throw r;
    return r.clone();
  }) as unknown as typeof fetch;
  return { impl, calls };
};
const slept: number[] = [];
const sleep = async (ms: number) => void slept.push(ms);
const free = () => new TokenBucket(1000);
const ok = (body = '{"a":1}') => new Response(body, { status: 200 });

beforeEach(() => {
  slept.length = 0;
  resetFeedHealth();
});

describe('Digitraffic headers', () => {
  it('sends exactly "Accept-Encoding: gzip" and a static Digitraffic-User, nothing personal', async () => {
    const { impl, calls } = scripted([ok()]);
    await fetchJson('metadata/stations', { fetchImpl: impl, sleep, limiter: free(), user: 'clack' });
    expect(calls[0]!.url).toBe(`${DIGITRAFFIC_BASE}metadata/stations`);
    expect(calls[0]!.headers['Accept-Encoding']).toBe('gzip');
    expect(calls[0]!.headers['Digitraffic-User']).toBe('clack');
    expect(JSON.stringify(calls[0]!.headers)).not.toMatch(/@/);
  });
  it('defaults the user to clack', () => {
    expect(digitrafficHeaders()['Digitraffic-User']).toBe('clack');
  });
  it('fetches binary bodies too, and accepts a full url', async () => {
    const { impl, calls } = scripted([new Response(new Uint8Array([0x50, 0x4b]), { status: 200 })]);
    const b = await fetchBuffer(`${DIGITRAFFIC_BASE}trains/gtfs-passenger.zip`, { fetchImpl: impl, sleep, limiter: free() });
    expect([...b]).toEqual([0x50, 0x4b]);
    expect(calls[0]!.headers.Accept).toBe('*/*');
    expect(calls[0]!.headers['Accept-Encoding']).toBe('gzip');
  });
});

describe('Digitraffic retries', () => {
  it('backs off and retries on 5xx, then succeeds, and reports the feed ok', async () => {
    const { impl, calls } = scripted([new Response('x', { status: 503 }), new Response('x', { status: 500 }), ok()]);
    expect(await fetchJson('trains/2026-10-24', { fetchImpl: impl, sleep, limiter: free() })).toEqual({ a: 1 });
    expect(calls).toHaveLength(3);
    expect(slept).toEqual([1000, 2000]);
    expect(feedHealth().digitraffic!.status).toBe('ok');
  });
  it('waits for Retry-After on 429', async () => {
    const { impl } = scripted([new Response('slow down', { status: 429, headers: { 'retry-after': '7' } }), ok()]);
    await digitrafficFetch('x', { fetchImpl: impl, sleep, limiter: free() });
    expect(slept).toEqual([7000]);
  });
  it('retries network errors, and gives up after the attempts with the feed marked failing', async () => {
    const { impl, calls } = scripted([new Error('reset')]);
    await expect(digitrafficFetch('x', { fetchImpl: impl, sleep, limiter: free(), maxAttempts: 3 })).rejects.toThrow('reset');
    expect(calls).toHaveLength(3);
    expect(feedHealth().digitraffic).toMatchObject({ status: 'degraded', failures: 1, lastError: 'reset' });
  });
  it('does not retry a 4xx (406 is a missing gzip header, 404 a wrong path)', async () => {
    const { impl, calls } = scripted([new Response('Use of gzip compression is required with Accept-Encoding: gzip header', { status: 406 })]);
    await expect(digitrafficFetch('x', { fetchImpl: impl, sleep, limiter: free() })).rejects.toMatchObject({ status: 406 });
    expect(calls).toHaveLength(1);
    expect(slept).toEqual([]);
  });
  it('reads Retry-After as seconds or a date, capped at a minute', () => {
    expect(retryAfterMs('3')).toBe(3000);
    expect(retryAfterMs('9999')).toBe(60_000);
    expect(retryAfterMs(new Date(10_000 + 5000).toUTCString(), 10_000)).toBeLessThanOrEqual(5000);
    expect(retryAfterMs(null)).toBeNull();
    expect(retryAfterMs('soon')).toBeNull();
  });
  it('turns unreadable JSON into a DigitrafficError', async () => {
    const { impl } = scripted([ok('not json')]);
    await expect(fetchJson('x', { fetchImpl: impl, sleep, limiter: free() })).rejects.toBeInstanceOf(DigitrafficError);
  });
});

describe('request limiter', () => {
  it('allows a burst up to the per-minute rate, then one token per rate interval', () => {
    const b = new TokenBucket(40, () => 0);
    for (let i = 0; i < 40; i++) expect(b.tryTake(0)).toBe(true);
    expect(b.tryTake(0)).toBe(false);
    expect(b.waitMs(0)).toBe(1500);
    expect(b.tryTake(1500)).toBe(true);
    expect(b.tryTake(1500)).toBe(false);
    // A long pause refills to the cap, no further.
    expect(b.waitMs(10 * 60_000)).toBe(0);
    for (let i = 0; i < 40; i++) expect(b.tryTake(10 * 60_000)).toBe(true);
    expect(b.tryTake(10 * 60_000)).toBe(false);
  });
  it('makes fetches wait when the bucket is empty', async () => {
    let t = 1_000_000;
    const limiter = new TokenBucket(2, () => t);
    const { impl, calls } = scripted([ok()]);
    const tick = async (ms: number) => {
      slept.push(ms);
      t += ms;
    };
    for (let i = 0; i < 3; i++) await digitrafficFetch('x', { fetchImpl: impl, sleep: tick, limiter });
    expect(calls).toHaveLength(3);
    expect(slept).toEqual([30_000]); // two at once, the third waits for a token (2 a minute)
  });
});

describe('country table', () => {
  it('gives each country its zone, key prefix and live id prefix', () => {
    expect(COUNTRIES.FI).toMatchObject({ tz: 'Europe/Helsinki', timetableSource: 'gtfs_fi', keyPrefix: 'fi', liveIdPrefix: 'fi:' });
    expect(tzOf('NO')).toBe('Europe/Oslo');
    expect(tzOf('SE')).toBe('Europe/Stockholm');
    expect(tzOf('DK')).toBe('Europe/Copenhagen');
    expect(tzOf('DE')).toBeUndefined();
    expect(tzOf(null)).toBeUndefined();
  });
  it('reads the country from a trip key and a live id', () => {
    expect(countryOfKey('fi:8192_20261212:610387f28f')).toBe('FI');
    expect(countryOfKey('no:VYG:ServiceJourney:1_2:abc')).toBe('NO');
    expect(countryOfKey('se3:123:abc')).toBe('SE');
    expect(countryOfKey('sv2:123:abc')).toBe('SE');
    expect(countryOfKey('xx:1')).toBeNull();
    expect(countryOfLiveId('fi:IC 27|2026-10-24')).toBe('FI');
    expect(countryOfLiveId('no:123|2026-10-24')).toBe('NO');
    expect(countryOfLiveId('123|2026-10-24')).toBe('SE');
  });
});
