// Finland's stations from Digitraffic's /metadata/stations (FINLAND_DATA_FINDINGS.md): 563 stations, 215 with
// passenger traffic, each with a short code (HKI), a UIC code, coordinates and a country (FI, a few SE and RU).
// The pure part (parse, filter, clean names) is here so tests need no network; fetchFiStations does the one call.
import { fetchJson, type DigitrafficOptions } from '../digitraffic/client.js';

export interface FiStation {
  /** stationShortCode: also the parent stop_id in Digitraffic's GTFS. */
  code: string;
  uic: number | null;
  name: string;
  lat: number;
  lon: number;
  /** FI, SE or RU as Digitraffic states it. */
  country: string;
  passengerTraffic: boolean;
}

interface RawStation {
  stationShortCode?: unknown;
  stationUICCode?: unknown;
  stationName?: unknown;
  latitude?: unknown;
  longitude?: unknown;
  countryCode?: unknown;
  passengerTraffic?: unknown;
}

/** "Helsinki asema" → "Helsinki" (Digitraffic names carry the word "asema", station). */
export const cleanFiName = (s: string) => s.replace(/\s+asema$/i, '').trim();

/** Rows with a code, a name and coordinates, in our shape; anything else in the feed is dropped. */
export function parseFiStations(raw: unknown): FiStation[] {
  if (!Array.isArray(raw)) return [];
  const out: FiStation[] = [];
  for (const r of raw as RawStation[]) {
    const lat = Number(r.latitude);
    const lon = Number(r.longitude);
    if (typeof r.stationShortCode !== 'string' || typeof r.stationName !== 'string' || !Number.isFinite(lat) || !Number.isFinite(lon)) continue;
    out.push({
      code: r.stationShortCode,
      uic: Number.isFinite(Number(r.stationUICCode)) ? Number(r.stationUICCode) : null,
      name: cleanFiName(r.stationName),
      lat,
      lon,
      country: typeof r.countryCode === 'string' ? r.countryCode.toUpperCase() : 'FI',
      passengerTraffic: r.passengerTraffic === true,
    });
  }
  return out;
}

/**
 * The stations we use: passenger traffic only, and only the ones in Finland plus Haparanda's (HPA, countryCode SE),
 * where the Oulu trains end. Russian stations (Vainikkala border trains) are not ours.
 */
export const usableFiStation = (s: FiStation) => s.passengerTraffic && (s.country === 'FI' || s.code === 'HPA');

export async function fetchFiStations(opts: DigitrafficOptions = {}): Promise<FiStation[]> {
  return parseFiStations(await fetchJson<unknown>('metadata/stations', opts));
}
