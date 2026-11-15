// One retry rule for the outbound feeds (Trafikverket, Entur, Digitraffic, Rejseplanen): a failed call is tried again
// after an exponential wait (base, 2 × base, 4 × base …, capped), with full jitter (a random wait between 0 and that) so
// clients that failed together don't come back together, unless the server said when to come back (Retry-After, also
// capped). A client error (4xx other than 429) is our request's fault and isn't retried.

/** What an error may say about the failed request; the feeds' error classes carry these. */
export interface RetryInfo {
  /** The HTTP status, when there was an answer. */
  status?: number;
  /** The server's Retry-After, already read as a wait in ms (retryAfterMs). */
  retryAfterMs?: number | null;
}

export interface RetryOptions {
  /** Tries in all, the first included (1 = no retry). */
  attempts?: number;
  /** The first wait; each next one doubles. */
  baseMs?: number;
  /** The longest backoff wait. */
  capMs?: number;
  /** The longest wait a Retry-After may ask for. */
  retryAfterCapMs?: number;
  /** A 429 without Retry-After waits at least this long. */
  rateLimitedMinMs?: number;
  /** Whether this error (on this attempt, from 1) is worth another try. Default: isTransient. */
  retryOn?: (err: unknown, attempt: number) => boolean;
  /** 'full' (default): a random wait up to the backoff; 'none': the backoff itself. */
  jitter?: 'full' | 'none';
  /** For tests. */
  sleep?: (ms: number) => Promise<void>;
  random?: () => number;
  /** Called before each wait (e.g. to log it). */
  onRetry?: (err: unknown, attempt: number, waitMs: number) => void;
}

export const realSleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

/** A request that ran out of time (AbortSignal.timeout) or was aborted. */
export const isTimeout = (e: unknown) => e instanceof Error && (e.name === 'TimeoutError' || e.name === 'AbortError');

/** The default rule: no answer at all (a network error), a 429 or a 5xx. */
export function isTransient(e: unknown): boolean {
  const status = (e as RetryInfo | null)?.status;
  if (status === undefined) return true;
  return status === 429 || status >= 500;
}

/** Seconds or an HTTP date in Retry-After, as a wait in ms (capped); null when absent or unreadable. */
export function retryAfterMs(h: string | null | undefined, now = Date.now(), capMs = 60_000): number | null {
  if (!h) return null;
  const secs = Number(h);
  const ms = Number.isFinite(secs) ? secs * 1000 : Date.parse(h) - now;
  return Number.isFinite(ms) && ms >= 0 ? Math.min(ms, capMs) : null;
}

/** How long to wait before attempt `attempt + 1` (attempt from 1). */
export function retryWait(err: unknown, attempt: number, opts: RetryOptions = {}): number {
  const info = (err ?? {}) as RetryInfo;
  const backoff = Math.min(opts.capMs ?? 30_000, (opts.baseMs ?? 1000) * 2 ** (attempt - 1));
  if (info.retryAfterMs != null) return Math.min(info.retryAfterMs, opts.retryAfterCapMs ?? 60_000);
  const wait = (opts.jitter ?? 'full') === 'full' ? Math.floor((opts.random ?? Math.random)() * backoff) : backoff;
  return info.status === 429 ? Math.max(wait, opts.rateLimitedMinMs ?? 0) : wait;
}

/** Run `fn` (given the attempt number, from 1) until it succeeds, an error isn't worth retrying, or the tries run out. */
export async function withRetry<T>(fn: (attempt: number) => Promise<T>, opts: RetryOptions = {}): Promise<T> {
  const attempts = Math.max(1, opts.attempts ?? 3);
  const retryOn = opts.retryOn ?? isTransient;
  const sleep = opts.sleep ?? realSleep;
  for (let attempt = 1; ; attempt++) {
    try {
      return await fn(attempt);
    } catch (e) {
      if (attempt >= attempts || !retryOn(e, attempt)) throw e;
      const wait = retryWait(e, attempt, opts);
      opts.onRetry?.(e, attempt, wait);
      await sleep(wait);
    }
  }
}
