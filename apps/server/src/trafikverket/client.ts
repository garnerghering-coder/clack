// Trafikverket Open API client. The key never leaves the server.
import { config } from '../env.js';

const URL = 'https://api.trafikinfo.trafikverket.se/v2/data.json';

export class TrafikverketError extends Error {}

/** POST one <QUERY> and return its result object (e.g. { TrainStation: [...] }). */
export async function trvQuery<T = Record<string, unknown[]>>(query: string, fetchImpl: typeof fetch = fetch): Promise<T> {
  if (!config.trafikverketApiKey) throw new TrafikverketError('TRAFIKVERKET_API_KEY is not set in .env');
  const body = `<REQUEST><LOGIN authenticationkey="${config.trafikverketApiKey}" />${query}</REQUEST>`;
  const res = await fetchImpl(URL, { method: 'POST', headers: { 'Content-Type': 'text/xml' }, body });
  const text = await res.text();
  if (!res.ok) throw new TrafikverketError(`Trafikverket ${res.status}: ${text.slice(0, 300)}`);
  const result = JSON.parse(text).RESPONSE.RESULT[0];
  if (result.ERROR) throw new TrafikverketError(`Trafikverket: ${result.ERROR.MESSAGE}`);
  return result as T;
}

export interface TrvStation {
  LocationSignature: string;
  AdvertisedLocationName: string;
  AdvertisedShortLocationName?: string;
  OfficialLocationName?: string;
  CountryCode?: string;
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
