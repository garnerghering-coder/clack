// Trafikverket Open API client. The key never leaves the server.
import { config } from '../env.js';
import { feedFailed, feedOk } from '../lib/health.js';
import { isTimeout, isTransient, retryAfterMs, withRetry, type RetryOptions } from '../lib/retry.js';

const URL = 'https://api.trafikinfo.trafikverket.se/v2/data.json';

export class TrafikverketError extends Error {
  constructor(
    message: string,
    /** The HTTP status; none for an error in a 200 answer (the query's fault). */
    readonly status?: number,
    readonly retryAfterMs: number | null = null,
  ) {
    super(message);
  }
}

/**
 * Nationwide queries take Trafikverket 10–60 s (measured 2026-10-21; one station is under a second), and past
 * about a minute it answers "Internal error". Give up a little after that rather than hang.
 */
const TIMEOUT_MS = 90_000;

/**
 * Retried by default (lib/retry.ts): a 5xx, a 429 or a network error, once, after about a second. Not a timeout (a
 * second 90 s wait helps no one waiting on a board) nor a 4xx or an error in the answer (the query's fault). Callers
 * that can wait pass their own (observed/sweden.ts, livemap/announcements.ts).
 */
const TRV_RETRY: RetryOptions = { attempts: 2, baseMs: 1000, retryOn: (e) => !isTimeout(e) && isTransient(e) };

/** POST one <QUERY> and return its result object (e.g. { TrainStation: [...] }). */
export async function trvQuery<T = Record<string, unknown[]>>(query: string, fetchImpl: typeof fetch = fetch, retry: RetryOptions = {}): Promise<T> {
  if (!config.trafikverketApiKey) throw new TrafikverketError('TRAFIKVERKET_API_KEY is not set in .env');
  const body = `<REQUEST><LOGIN authenticationkey="${config.trafikverketApiKey}" />${query}</REQUEST>`;
  try {
    const result = await withRetry(async () => {
      const res = await fetchImpl(URL, { method: 'POST', headers: { 'Content-Type': 'text/xml' }, body, signal: AbortSignal.timeout(TIMEOUT_MS) });
      const text = await res.text();
      if (!res.ok) throw new TrafikverketError(`Trafikverket ${res.status}: ${text.slice(0, 300)}`, res.status, retryAfterMs(res.headers.get('retry-after')));
      const r = JSON.parse(text).RESPONSE.RESULT[0];
      // An error inside a 2xx answer (RESULT[0].ERROR) keeps that status: not retried by default, the feed is up.
      if (r.ERROR) throw new TrafikverketError(`Trafikverket: ${r.ERROR.MESSAGE}`, res.status);
      return r as T;
    }, { ...TRV_RETRY, ...retry });
    feedOk('trafikverket');
    return result;
  } catch (e) {
    const status = (e as TrafikverketError).status;
    // The feed answered: the query's fault (a 4xx says nothing about the feed either way).
    if (status !== undefined && status < 300) feedOk('trafikverket');
    else if (status === undefined || status >= 500 || status === 429) feedFailed('trafikverket', e);
    throw e;
  }
}

export interface TrvStation {
  LocationSignature: string;
  AdvertisedLocationName: string;
  AdvertisedShortLocationName?: string;
  OfficialLocationName?: string;
  CountryCode?: string;
  CountyNo?: number[];
  /** Track ids at the station ("1", "2a", "2b"…). */
  PlatformLine?: string[];
  Advertised: boolean;
  Deleted?: boolean;
  Geometry?: { WGS84?: string };
  ModifiedTime?: string;
}

export async function fetchTrainStations(fetchImpl?: typeof fetch): Promise<TrvStation[]> {
  // Schema 1.4 is the newest accepted (Phase 0).
  const r = await trvQuery<{ TrainStation?: TrvStation[] }>('<QUERY objecttype="TrainStation" schemaversion="1.4"><FILTER/></QUERY>', fetchImpl);
  return r.TrainStation ?? [];
}

/** "POINT (lon lat)" -> [lat, lon] */
export function parseWgs84(point?: string): [number, number] | null {
  const m = point?.match(/POINT \(([-\d.]+) ([-\d.]+)\)/);
  return m ? [Number(m[2]), Number(m[1])] : null;
}

/**
 * Actual times as epoch ms, guarding against a Trafikverket data fault seen on 2026-10-21: `TimeAtLocation` values
 * arrived shifted back by the UTC offset once or twice ("10:00+02:00" or "08:00+02:00" for a departure at 12:00
 * local), mixed with correct ones for the same train. Trains don't leave or arrive 45+ minutes ahead of the timetable,
 * so an actual that early is shifted forward by one, then two, times its stated offset, and the first plausible
 * reading wins. Correct data passes through unchanged.
 */
export function actualTime(value: string | undefined, advertised: string | number): number | null {
  if (!value) return null;
  const parsed = Date.parse(value);
  const adv = typeof advertised === 'number' ? advertised : Date.parse(advertised);
  const EARLY = 45 * 60_000;
  if (parsed - adv > -EARLY) return parsed;
  const m = /([+-])(\d\d):(\d\d)$/.exec(value);
  const offset = m ? (m[1] === '-' ? -1 : 1) * (Number(m[2]) * 3600_000 + Number(m[3]) * 60_000) : 0;
  for (const k of [1, 2]) {
    const c = parsed + k * offset;
    if (c - adv > -EARLY && c - adv < 12 * 3600_000) return c;
  }
  return parsed;
}
