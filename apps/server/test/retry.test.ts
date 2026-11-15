// The shared retry rule for the outbound feeds (lib/retry.ts), with fake timers.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { isTransient, retryAfterMs, retryWait, withRetry } from '../src/lib/retry.js';

const httpError = (status: number, retryAfterMs: number | null = null) => Object.assign(new Error(`HTTP ${status}`), { status, retryAfterMs });

describe('withRetry', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('returns the first success without waiting', async () => {
    const fn = vi.fn(async () => 'ok');
    await expect(withRetry(fn)).resolves.toBe('ok');
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('waits base, 2 × base, 4 × base (no jitter) between tries, then gives up with the last error', async () => {
    const fn = vi.fn(async (attempt: number) => {
      throw httpError(503 + attempt);
    });
    const p = withRetry(fn, { attempts: 4, baseMs: 1000, jitter: 'none' });
    const settled = p.catch((e: Error) => e);
    await vi.advanceTimersByTimeAsync(0);
    expect(fn).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(999);
    expect(fn).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(1);
    expect(fn).toHaveBeenCalledTimes(2);
    await vi.advanceTimersByTimeAsync(2000);
    expect(fn).toHaveBeenCalledTimes(3);
    await vi.advanceTimersByTimeAsync(3999);
    expect(fn).toHaveBeenCalledTimes(3);
    await vi.advanceTimersByTimeAsync(1);
    expect(fn).toHaveBeenCalledTimes(4);
    expect(((await settled) as Error).message).toBe('HTTP 507');
  });

  it('full jitter: a random wait between 0 and the backoff, capped', async () => {
    const waits: number[] = [];
    const fn = vi.fn(async () => {
      throw httpError(500);
    });
    const p = withRetry(fn, { attempts: 4, baseMs: 1000, capMs: 3000, random: () => 0.5, onRetry: (_e, _a, w) => waits.push(w) }).catch(() => null);
    await vi.runAllTimersAsync();
    await p;
    // 0.5 × 1000, 0.5 × 2000, 0.5 × min(4000, 3000)
    expect(waits).toEqual([500, 1000, 1500]);
  });

  it('honours Retry-After (capped) instead of the backoff', async () => {
    const waits: number[] = [];
    let n = 0;
    const p = withRetry(
      async () => {
        if (++n === 1) throw httpError(429, 7000);
        if (n === 2) throw httpError(429, 600_000);
        return 'ok';
      },
      { attempts: 3, baseMs: 1000, retryAfterCapMs: 20_000, onRetry: (_e, _a, w) => waits.push(w) },
    );
    await vi.runAllTimersAsync();
    await expect(p).resolves.toBe('ok');
    expect(waits).toEqual([7000, 20_000]);
  });

  it('a 429 without Retry-After waits at least the given minimum', () => {
    expect(retryWait(httpError(429), 1, { baseMs: 1000, jitter: 'none', rateLimitedMinMs: 10_000 })).toBe(10_000);
    expect(retryWait(httpError(503), 1, { baseMs: 1000, jitter: 'none', rateLimitedMinMs: 10_000 })).toBe(1000);
  });

  it('does not retry a 4xx other than 429, by default', async () => {
    for (const status of [400, 401, 403, 404]) {
      const fn = vi.fn(async () => {
        throw httpError(status);
      });
      await expect(withRetry(fn, { attempts: 3 })).rejects.toThrow(`HTTP ${status}`);
      expect(fn).toHaveBeenCalledTimes(1);
    }
  });

  it('retries network errors, 429 and 5xx by default', () => {
    expect(isTransient(new TypeError('fetch failed'))).toBe(true);
    expect(isTransient(httpError(429))).toBe(true);
    expect(isTransient(httpError(502))).toBe(true);
    expect(isTransient(httpError(404))).toBe(false);
  });

  it('asks retryOn with the attempt number, and stops when it says no', async () => {
    const asked: number[] = [];
    const fn = vi.fn(async () => {
      throw httpError(500);
    });
    const p = withRetry(fn, { attempts: 5, baseMs: 10, retryOn: (_e, a) => (asked.push(a), a < 2) }).catch((e: Error) => e);
    await vi.runAllTimersAsync();
    await p;
    expect(asked).toEqual([1, 2]);
    expect(fn).toHaveBeenCalledTimes(2);
  });

  it('attempts: 1 means a single try', async () => {
    const fn = vi.fn(async () => {
      throw httpError(500);
    });
    await expect(withRetry(fn, { attempts: 1 })).rejects.toThrow('HTTP 500');
    expect(fn).toHaveBeenCalledTimes(1);
  });
});

describe('retryAfterMs', () => {
  it('reads seconds or an HTTP date, capped, and nothing else', () => {
    const now = Date.parse('2026-11-15T12:00:00Z');
    expect(retryAfterMs('5', now)).toBe(5000);
    expect(retryAfterMs('0', now)).toBe(0);
    expect(retryAfterMs('3600', now)).toBe(60_000);
    expect(retryAfterMs('3600', now, 10_000)).toBe(10_000);
    expect(retryAfterMs('Sun, 15 Nov 2026 12:00:30 GMT', now)).toBe(30_000);
    expect(retryAfterMs('Sun, 15 Nov 2026 11:59:00 GMT', now)).toBeNull();
    expect(retryAfterMs('soon', now)).toBeNull();
    expect(retryAfterMs(null, now)).toBeNull();
  });
});
