// How each upstream feed is doing (docs/RELIABILITY_PLAN.md §2): when it last answered, when it last failed and
// how many times in a row. The clients call these; /api/health reports them, and live views use them to say when
// data has gone quiet instead of showing old data as live.

export type Feed = 'trafikverket' | 'entur';

interface FeedState {
  okAt: number | null;
  failAt: number | null;
  failures: number;
  lastError: string | null;
}

const feeds = new Map<Feed, FeedState>();
const get = (f: Feed) => feeds.get(f) ?? feeds.set(f, { okAt: null, failAt: null, failures: 0, lastError: null }).get(f)!;

export function feedOk(f: Feed, now = Date.now()) {
  const s = get(f);
  s.okAt = now;
  s.failures = 0;
}

export function feedFailed(f: Feed, e: unknown, now = Date.now()) {
  const s = get(f);
  s.failAt = now;
  s.failures++;
  s.lastError = (e as Error)?.message?.slice(0, 200) ?? String(e);
}

/** After this many failures in a row, or this long without an answer while failing, a feed is down. */
const DOWN_AFTER = 3;
const QUIET_MS = 2 * 60_000;

export function feedHealth(now = Date.now()) {
  const out: Record<string, FeedState & { status: 'ok' | 'degraded' | 'down' | 'unknown' }> = {};
  for (const [f, s] of feeds) {
    const status = s.okAt === null && s.failAt === null ? 'unknown' : s.failures === 0 ? 'ok' : s.failures >= DOWN_AFTER || (s.okAt !== null && now - s.okAt > QUIET_MS) ? 'down' : 'degraded';
    out[f] = { ...s, status };
  }
  return out;
}

/** For tests. */
export function resetFeedHealth() {
  feeds.clear();
}
