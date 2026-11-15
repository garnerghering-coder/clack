// Entur's open APIs (NORWAY_DATA_FINDINGS.md). No key, but every request names us (ET-Client-Name), and a quota hit
// is never retried inside its window: we wait for the reset time Entur sends.
import GtfsRealtimeBindings from 'gtfs-realtime-bindings';
import { config } from '../env.js';
import { feedFailed, feedOk } from '../lib/health.js';
import { isTimeout, isTransient, withRetry } from '../lib/retry.js';

const JP_URL = 'https://api.entur.io/journey-planner/v3/graphql';
const RT_URL = 'https://api.entur.io/realtime/v1/gtfs-rt';
const TIMEOUT_MS = 20_000;

export class EnturError extends Error {
  constructor(
    message: string,
    readonly status?: number,
  ) {
    super(message);
  }
}
/** Over the per-minute quota: nothing is sent until `until`. */
export class EnturRateLimited extends EnturError {
  constructor(readonly until: number) {
    super(`Entur quota reached; waiting until ${new Date(until).toISOString()}`, 429);
  }
}

/** The rail operators' datasource codes for the GTFS-RT feeds. */
export const RT_DATASOURCES = ['VYG', 'GOA', 'FLT', 'SJN'] as const;
export type RtDatasource = (typeof RT_DATASOURCES)[number];

let blockedUntil = 0;

/** When the quota resets: Entur's expiry header, else Retry-After, else a minute. */
export function resetAt(headers: Headers, now = Date.now()): number {
  const expiry = Date.parse(headers.get('rate-limit-expiry-time') ?? '');
  if (Number.isFinite(expiry) && expiry > now) return expiry;
  const after = Number(headers.get('retry-after'));
  if (Number.isFinite(after) && after > 0) return now + after * 1000;
  return now + 60_000;
}

/**
 * One request, tried again once after about a second on a 5xx or a network error (lib/retry.ts; not a timeout, which
 * already took 20 s). A 429 is never retried: it blocks every request until Entur's reset time, retries included.
 */
async function enturFetch(url: string, init: RequestInit = {}, fetchImpl: typeof fetch = fetch): Promise<Response> {
  if (Date.now() < blockedUntil) throw new EnturRateLimited(blockedUntil);
  try {
    const res = await withRetry(
      async () => {
        // Another request may have hit the quota while this one waited to retry.
        if (Date.now() < blockedUntil) throw new EnturRateLimited(blockedUntil);
        const res = await fetchImpl(url, {
          ...init,
          headers: { 'ET-Client-Name': config.enturClientName, ...(init.headers as Record<string, string> | undefined) },
          signal: AbortSignal.timeout(TIMEOUT_MS),
        });
        if (res.status === 429) {
          blockedUntil = resetAt(res.headers);
          throw new EnturRateLimited(blockedUntil);
        }
        if (!res.ok) throw new EnturError(`Entur ${res.status}: ${(await res.text()).slice(0, 300)}`, res.status);
        return res;
      },
      { attempts: 2, baseMs: 1000, retryOn: (e) => !(e instanceof EnturRateLimited) && !isTimeout(e) && isTransient(e) },
    );
    feedOk('entur');
    return res;
  } catch (e) {
    // A 4xx (not 429) is our request's fault, not the feed's.
    const status = (e as EnturError).status;
    if (e instanceof EnturRateLimited || status === undefined || status >= 500) feedFailed('entur', e);
    throw e;
  }
}

/** One Journey Planner GraphQL query. */
export async function jpQuery<T>(query: string, variables: Record<string, unknown> = {}, fetchImpl?: typeof fetch): Promise<T> {
  const res = await enturFetch(JP_URL, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ query, variables }) }, fetchImpl);
  const body = (await res.json()) as { data?: T; errors?: { message: string }[] };
  if (body.errors?.length) throw new EnturError(`Journey Planner: ${body.errors.map((e) => e.message).join('; ')}`);
  return body.data as T;
}

export type FeedMessage = GtfsRealtimeBindings.transit_realtime.FeedMessage;
export const ScheduleRelationship = GtfsRealtimeBindings.transit_realtime.TripDescriptor.ScheduleRelationship;
export const StopScheduleRelationship = GtfsRealtimeBindings.transit_realtime.TripUpdate.StopTimeUpdate.ScheduleRelationship;

/** One GTFS-RT feed for one operator (refreshed by Entur every 15 s). */
export async function gtfsRt(kind: 'vehicle-positions' | 'trip-updates', datasource: RtDatasource, fetchImpl?: typeof fetch): Promise<FeedMessage> {
  const res = await enturFetch(`${RT_URL}/${kind}?datasource=${datasource}`, {}, fetchImpl);
  return GtfsRealtimeBindings.transit_realtime.FeedMessage.decode(new Uint8Array(await res.arrayBuffer()));
}
