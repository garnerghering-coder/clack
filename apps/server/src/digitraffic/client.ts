// Digitraffic Rail, Finland's open train API (FINLAND_DATA_FINDINGS.md). No key. Two things it insists on:
//  - `Accept-Encoding: gzip` exactly (Node's default "gzip, deflate, br" is refused with HTTP 406 and the body
//    "Use of gzip compression is required with Accept-Encoding: gzip header"); Node's fetch unzips the answer.
//  - a `Digitraffic-User` header naming the client (static, no personal data).
// Limits: 60 requests a minute per client; we keep to 40. Licence CC BY 4.0: "Source: Fintraffic / digitraffic.fi,
// license CC 4.0 BY".
import { config } from '../env.js';
import { feedFailed, feedOk } from '../lib/health.js';
import { realSleep, retryAfterMs as readRetryAfter, withRetry } from '../lib/retry.js';

export const DIGITRAFFIC_BASE = 'https://rata.digitraffic.fi/api/v1/';
export const DIGITRAFFIC_CREDIT = 'Source: Fintraffic / digitraffic.fi, license CC 4.0 BY';

/** Our share of Digitraffic's 60 requests a minute. */
export const MAX_REQUESTS_PER_MINUTE = 40;
const TIMEOUT_MS = 30_000;
const MAX_ATTEMPTS = 4;
const BACKOFF_MS = 1000;
const MAX_WAIT_MS = 60_000;

export class DigitrafficError extends Error {
  constructor(
    message: string,
    readonly status?: number,
    readonly retryAfterMs: number | null = null,
  ) {
    super(message);
  }
}

/** The headers every Digitraffic request carries. */
export function digitrafficHeaders(user: string = config.digitrafficUser, accept = 'application/json'): Record<string, string> {
  return { 'Digitraffic-User': user, 'Accept-Encoding': 'gzip', Accept: accept };
}

/** At most `perMinute` requests a minute, with room for a short burst of the same size. */
export class TokenBucket {
  private tokens: number;
  private at: number;
  constructor(
    private readonly perMinute: number,
    private readonly clock: () => number = Date.now,
  ) {
    this.tokens = perMinute;
    this.at = clock();
  }
  private refill(now: number) {
    this.tokens = Math.min(this.perMinute, this.tokens + ((now - this.at) / 60_000) * this.perMinute);
    this.at = now;
  }
  /** Take a token if there is one. */
  tryTake(now = this.clock()): boolean {
    this.refill(now);
    if (this.tokens < 1) return false;
    this.tokens -= 1;
    return true;
  }
  /** Milliseconds until the next token exists (0 if one does now). */
  waitMs(now = this.clock()): number {
    this.refill(now);
    return this.tokens >= 1 ? 0 : Math.ceil(((1 - this.tokens) / this.perMinute) * 60_000);
  }
}

const sharedLimiter = new TokenBucket(MAX_REQUESTS_PER_MINUTE);

export interface DigitrafficOptions {
  fetchImpl?: typeof fetch;
  /** For tests: replaces setTimeout-based waiting. */
  sleep?: (ms: number) => Promise<void>;
  limiter?: TokenBucket;
  user?: string;
  accept?: string;
  maxAttempts?: number;
  timeoutMs?: number;
}

/** Seconds or an HTTP date in Retry-After, as a wait in ms (capped at a minute); null when absent or unreadable. */
export const retryAfterMs = (h: string | null, now = Date.now()) => readRetryAfter(h, now, MAX_WAIT_MS);

/**
 * GET `path` (relative to the API base, or a full URL) with the right headers, the limiter and retries on 429/5xx and
 * network errors (lib/retry.ts): 1, 2, 4 s without jitter, Retry-After on a 429 (else at least 10 s), every try
 * taking a token from the limiter.
 */
export async function digitrafficFetch(path: string, opts: DigitrafficOptions = {}): Promise<Response> {
  const url = /^https?:/.test(path) ? path : DIGITRAFFIC_BASE + path.replace(/^\//, '');
  const fetchImpl = opts.fetchImpl ?? fetch;
  const sleep = opts.sleep ?? realSleep;
  const limiter = opts.limiter ?? sharedLimiter;
  try {
    return await withRetry(
      async () => {
        for (let w = limiter.waitMs(); w > 0; w = limiter.waitMs()) await sleep(w);
        limiter.tryTake();
        const res = await fetchImpl(url, { headers: digitrafficHeaders(opts.user, opts.accept), signal: AbortSignal.timeout(opts.timeoutMs ?? TIMEOUT_MS) });
        if (res.ok) {
          feedOk('digitraffic');
          return res;
        }
        const body = (await res.text().catch(() => '')).slice(0, 200);
        throw new DigitrafficError(`Digitraffic ${res.status}: ${body}`, res.status, res.status === 429 ? retryAfterMs(res.headers.get('retry-after')) : null);
      },
      // 4xx other than 429 is our mistake (wrong path, missing header): retrying won't help.
      { attempts: opts.maxAttempts ?? MAX_ATTEMPTS, baseMs: BACKOFF_MS, capMs: MAX_WAIT_MS, jitter: 'none', rateLimitedMinMs: 10_000, retryAfterCapMs: MAX_WAIT_MS, sleep },
    );
  } catch (e) {
    feedFailed('digitraffic', e);
    throw e;
  }
}

export async function fetchJson<T>(path: string, opts: DigitrafficOptions = {}): Promise<T> {
  const res = await digitrafficFetch(path, opts);
  try {
    return (await res.json()) as T;
  } catch (e) {
    feedFailed('digitraffic', e);
    throw new DigitrafficError(`Digitraffic sent unreadable JSON for ${path}: ${(e as Error).message}`);
  }
}

export async function fetchBuffer(path: string, opts: DigitrafficOptions = {}): Promise<Buffer> {
  const res = await digitrafficFetch(path, { accept: '*/*', ...opts });
  return Buffer.from(await res.arrayBuffer());
}
