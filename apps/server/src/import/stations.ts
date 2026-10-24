// Builds the stations table from GTFS rail stops + Trafikverket locations (Phase 0 §3).
import type { StationOverride } from '../dataFiles.js';
import { haversineM, nameSimilarity } from '../lib/geo.js';
import { COUNTRIES } from '../lib/countries.js';

export interface GtfsParent {
  stopId: string;
  name: string;
  lat: number;
  lon: number;
  /** Platform stop ids under this parent that rail trips use. */
  childIds: string[];
  /** rikshållplats area id from stop_areas.txt, if any. */
  riks?: string;
}

export interface TrvLoc {
  signature: string;
  name: string;
  lat: number | null;
  lon: number | null;
  country: string;
}

export interface StationRow {
  id: string;
  name: string;
  country: string;
  lat: number;
  lon: number;
  tz: string;
  trvSignature: string | null;
  gtfsStopIds: string[];
  coordSource: 'gtfs' | 'trafikverket';
  kind: 'rail_station' | 'bus_stop';
  needsReview: boolean;
  /** How the signature was chosen (for logs). */
  method: 'override' | 'official' | 'geo_name' | 'geo_only' | 'none';
}

export const TZ_BY_COUNTRY: Record<string, string> = {
  SE: 'Europe/Stockholm',
  DK: 'Europe/Copenhagen',
  NO: 'Europe/Oslo',
  DE: 'Europe/Berlin',
  AT: 'Europe/Vienna',
  FI: COUNTRIES.FI.tz,
};

const GEO_NAME_RADIUS_M = 300;
const GEO_ONLY_RADIUS_M = 100;
/** Beyond this, GTFS and Trafikverket disagree enough that we trust Trafikverket's point (Notviken is 54 km off). */
const COORD_DISAGREE_M = 1000;
/** A Swedish stop with no Trafikverket location within this distance is a bus stop inside a "rail" trip. */
const BUS_STOP_M = 1000;

/**
 * Country from the source's own statement when it has one (`explicit`, e.g. Digitraffic's countryCode), else a
 * Trafikverket signature prefix ("Dk.kh"), a rikshållplats prefix, or a rough bounding box. The box only knows
 * Germany/Austria/Denmark/Norway and otherwise guesses Sweden, so a source that knows better must say so.
 */
export function countryOf(sig: string | null, riks: string | undefined, lat: number, lon: number, explicit?: string): string {
  if (explicit && /^[A-Za-z]{2}$/.test(explicit)) return explicit.toUpperCase();
  const prefix = sig?.match(/^([A-Za-z]{2})\./)?.[1]?.toUpperCase();
  if (prefix) return prefix;
  if (riks) {
    const p = riks.slice(0, 2);
    const byRiks: Record<string, string> = { '74': 'SE', '86': 'DK', '76': 'NO', '80': 'DE', '81': 'AT' };
    if (byRiks[p]) return byRiks[p];
  }
  if (lat < 54.5 && lon < 17.5 && lon > 5.5) return lat < 49 && lon > 9.5 ? 'AT' : 'DE';
  if (lat < 57.8 && lon < 12.7 && lon > 8) return 'DK';
  if (lon < 11.2 || (lat > 63 && lon < 12.2) || (lat > 68.4 && lon < 18)) return 'NO';
  return 'SE';
}

/** "Fredrikstad stasjon" -> "Fredrikstad", "Nässjö central" kept (Trafikverket names are used in Sweden anyway). */
export function cleanGtfsName(name: string): string {
  return name.replace(/\s+(station|Station|stasjon|stn)$/u, '').trim();
}

export interface BuiltStations {
  stations: StationRow[];
  /** GTFS parent stop id -> station id (several parents can share one rikshållplats). */
  stationOfParent: Map<string, string>;
}

export function buildStations(
  parents: GtfsParent[],
  trv: TrvLoc[],
  officialSigs: Map<string, string[]>,
  overrides: Record<string, StationOverride>,
): BuiltStations {
  const trvBySig = new Map(trv.map((t) => [t.signature.toLowerCase(), t]));
  const located = trv.filter((t) => t.lat !== null && t.lon !== null) as (TrvLoc & { lat: number; lon: number })[];
  const byId = new Map<string, StationRow>();
  const stationOfParent = new Map<string, string>();

  for (const p of parents) {
    let method: StationRow['method'] = 'none';
    let sig: string | null = null;
    const ov = overrides[p.stopId];
    let nearest: { t: TrvLoc; d: number } | null = null;
    for (const t of located) {
      const d = haversineM(p.lat, p.lon, t.lat, t.lon);
      if (!nearest || d < nearest.d) nearest = { t, d };
    }

    if (ov) {
      method = 'override';
      sig = ov.trv_signature ? (trvBySig.get(ov.trv_signature.toLowerCase())?.signature ?? ov.trv_signature) : null;
    } else {
      const official = (p.riks ? officialSigs.get(p.riks) : undefined)?.map((s) => trvBySig.get(s.toLowerCase())).find(Boolean);
      if (official) {
        method = 'official';
        sig = official.signature;
      } else {
        let best: { t: TrvLoc; score: number } | null = null;
        for (const t of located) {
          const d = haversineM(p.lat, p.lon, t.lat, t.lon);
          if (d > GEO_NAME_RADIUS_M) continue;
          const sim = nameSimilarity(p.name, t.name);
          const score = sim - d / 3000;
          if (sim >= 0.5 && (!best || score > best.score)) best = { t, score };
        }
        if (best) {
          method = 'geo_name';
          sig = best.t.signature;
        } else if (nearest && nearest.d <= GEO_ONLY_RADIUS_M) {
          method = 'geo_only';
          sig = nearest.t.signature;
        }
      }
    }

    const t = sig ? trvBySig.get(sig.toLowerCase()) : undefined;
    let lat = p.lat;
    let lon = p.lon;
    let coordSource: StationRow['coordSource'] = 'gtfs';
    if (t && t.lat !== null && t.lon !== null && haversineM(p.lat, p.lon, t.lat, t.lon) > COORD_DISAGREE_M) {
      lat = t.lat;
      lon = t.lon;
      coordSource = 'trafikverket';
    }
    const country = countryOf(sig, p.riks, lat, lon);
    let kind: StationRow['kind'] = 'rail_station';
    if (ov?.kind === 'bus_stop') kind = 'bus_stop';
    else if (!sig && country === 'SE' && (!nearest || nearest.d > BUS_STOP_M)) kind = 'bus_stop';
    const name = country === 'SE' && t ? t.name : cleanGtfsName(p.name);
    const id = p.riks ?? `gtfs:${p.stopId}`;
    stationOfParent.set(p.stopId, id);

    const existing = byId.get(id);
    if (existing) {
      // Two GTFS parents in the same rikshållplats: one station.
      existing.gtfsStopIds.push(p.stopId, ...p.childIds);
      continue;
    }
    byId.set(id, {
      id,
      name,
      country,
      lat,
      lon,
      tz: TZ_BY_COUNTRY[country] ?? 'Europe/Stockholm',
      trvSignature: sig,
      gtfsStopIds: [p.stopId, ...p.childIds],
      coordSource,
      kind,
      // A Swedish rail station with no Trafikverket match needs a human look (spec §8.4).
      needsReview: kind === 'rail_station' && !sig && country === 'SE',
      method,
    });
  }
  // Two GTFS parents for one physical station (e.g. two "Mora C" stops) end up with the same signature:
  // merge them into the one with a rikshållplats id and the most specific mapping.
  const rank = (r: StationRow) => (r.id.startsWith('gtfs:') ? 0 : 2) + (r.method === 'official' || r.method === 'override' ? 1 : 0);
  const bySig = new Map<string, StationRow>();
  for (const r of byId.values()) {
    if (!r.trvSignature || r.kind !== 'rail_station') continue;
    const key = r.trvSignature.toLowerCase();
    const other = bySig.get(key);
    if (!other) {
      bySig.set(key, r);
      continue;
    }
    const [keep, drop] = rank(r) > rank(other) ? [r, other] : [other, r];
    keep.gtfsStopIds.push(...drop.gtfsStopIds);
    byId.delete(drop.id);
    for (const [parent, sid] of stationOfParent) if (sid === drop.id) stationOfParent.set(parent, keep.id);
    bySig.set(key, keep);
  }
  return { stations: [...byId.values()], stationOfParent };
}
