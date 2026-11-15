// The shared retry rule (lib/retry.ts) as Trafikverket's and Entur's clients use it. Digitraffic's and Rejseplanen's
// are in their own tests.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { config } from '../src/env.js';
import { trvQuery, TrafikverketError } from '../src/trafikverket/client.js';
import { EnturError, EnturRateLimited, jpQuery } from '../src/entur/client.js';

const noWait = { sleep: async () => {} };
const trvOk = () => new Response(JSON.stringify({ RESPONSE: { RESULT: [{ TrainStation: [{ Signature: 'Cst' }] }] } }));

describe('trvQuery', () => {
  const saved = config.trafikverketApiKey;
  beforeEach(() => (config.trafikverketApiKey = 'test-key'));
  afterEach(() => (config.trafikverketApiKey = saved));

  it('tries a 5xx again once, by default', async () => {
    let n = 0;
    const fetchImpl = (async () => (n++ === 0 ? new Response('busy', { status: 503 }) : trvOk())) as typeof fetch;
    const r = await trvQuery<{ TrainStation: unknown[] }>('<QUERY/>', fetchImpl, noWait);
    expect(r.TrainStation).toHaveLength(1);
    expect(n).toBe(2);
  });

  it('does not retry a 4xx or an error inside a 200 answer (the query\'s fault)', async () => {
    let n = 0;
    const bad = (async () => (n++, new Response('bad', { status: 400 }))) as typeof fetch;
    await expect(trvQuery('<QUERY/>', bad, noWait)).rejects.toThrow('Trafikverket 400');
    expect(n).toBe(1);
    n = 0;
    const err = (async () => (n++, new Response(JSON.stringify({ RESPONSE: { RESULT: [{ ERROR: { MESSAGE: 'no such field' } }] } })))) as typeof fetch;
    await expect(trvQuery('<QUERY/>', err, noWait)).rejects.toBeInstanceOf(TrafikverketError);
    expect(n).toBe(1);
  });

  it('a caller that can wait passes its own rule (any failure, more tries)', async () => {
    let n = 0;
    const fetchImpl = (async () => (n++ < 2 ? new Response(JSON.stringify({ RESPONSE: { RESULT: [{ ERROR: { MESSAGE: 'Internal error' } }] } })) : trvOk())) as typeof fetch;
    await trvQuery('<QUERY/>', fetchImpl, { ...noWait, attempts: 3, retryOn: () => true });
    expect(n).toBe(3);
  });
});

describe('Entur', () => {
  beforeEach(() => vi.useFakeTimers({ toFake: ['Date', 'setTimeout'] }));
  afterEach(() => vi.useRealTimers());

  it('tries a 5xx again once after about a second, not a 4xx', async () => {
    let n = 0;
    const flaky = (async () => (n++ === 0 ? new Response('busy', { status: 502 }) : new Response(JSON.stringify({ data: { ok: 1 } })))) as typeof fetch;
    const p = jpQuery<{ ok: number }>('{ ok }', {}, flaky);
    await vi.advanceTimersByTimeAsync(1000);
    await expect(p).resolves.toEqual({ ok: 1 });
    expect(n).toBe(2);
    n = 0;
    const bad = (async () => (n++, new Response('bad', { status: 400 }))) as typeof fetch;
    await expect(jpQuery('{ ok }', {}, bad)).rejects.toBeInstanceOf(EnturError);
    expect(n).toBe(1);
  });

  it('a 429 is not retried, and blocks every request until the reset', async () => {
    let n = 0;
    const limited = (async () => (n++, new Response('slow down', { status: 429, headers: { 'x-ratelimit-reset': '30' } }))) as typeof fetch;
    await expect(jpQuery('{ ok }', {}, limited)).rejects.toBeInstanceOf(EnturRateLimited);
    expect(n).toBe(1);
    // Blocked: nothing is sent.
    const ok = (async () => (n++, new Response(JSON.stringify({ data: { ok: 1 } })))) as typeof fetch;
    await expect(jpQuery('{ ok }', {}, ok)).rejects.toBeInstanceOf(EnturRateLimited);
    expect(n).toBe(1);
    // After the reset (a minute at most), it sends again.
    vi.setSystemTime(Date.now() + 61_000);
    await expect(jpQuery('{ ok }', {}, ok)).resolves.toEqual({ ok: 1 });
    expect(n).toBe(2);
  });
});
