// Where a standing or waiting train is drawn (BUILDOUT §A.2): at its platform when the station is mapped and the
// track is known, otherwise at the station's point snapped onto the nearest running track, so it sits on rails and
// not on the station building. Also the parallel-track choice for a point on the line (§A.5). Looks things up
// (station maps, the rail graph) and caches them; the rules themselves are in positioning.ts.
import { platformPoint, type LatLon } from '@clack/shared';
import type { RailGraph } from '../geo/railGraph.js';
import { stationMap } from '../stations/maps.js';
import type { CountryCode } from '../lib/countries.js';
import { haversineM } from '../lib/geo.js';
import { PARALLEL_M, pickTrack, runningSide, type Side } from './positioning.js';

export interface Placed {
  lat: number;
  lon: number;
  /** "platform": the mapped platform; "track": the station point snapped to the line; "station": the point itself. */
  how: 'platform' | 'track' | 'station';
}

export class Placement {
  private trackPoints = new Map<string, LatLon | null>();

  constructor(private readonly graph: () => RailGraph | null) {}

  /** Where a train standing at `track` of station `id` (at lat/lon) is drawn. */
  standing(id: string | null, lat: number, lon: number, track: string | null | undefined): Placed {
    if (id && track) {
      const m = stationMap(id);
      const p = m && platformPoint(m, track);
      if (p) return { lat: p[0], lon: p[1], how: 'platform' };
    }
    const t = this.trackPoint(id, lat, lon);
    return t ? { lat: t[0], lon: t[1], how: 'track' } : { lat, lon, how: 'station' };
  }

  /** The station's point on the nearest running track (cached per station), or null without a graph or a track within reach. */
  trackPoint(id: string | null, lat: number, lon: number): LatLon | null {
    const key = id ?? `${lat.toFixed(5)},${lon.toFixed(5)}`;
    const hit = this.trackPoints.get(key);
    if (hit !== undefined) return hit;
    const g = this.graph();
    const c = g?.snap(lat, lon)[0];
    const p: LatLon | null = c && c.d <= 400 ? c.point : null;
    this.trackPoints.set(key, p);
    if (this.trackPoints.size > 20_000) this.trackPoints.delete(this.trackPoints.keys().next().value!);
    return p;
  }

  /**
   * A point on the line moved onto the right one of two parallel tracks, by the country's running side and the
   * heading of travel. Returns the point unchanged when there is no parallel track, heading or rule. `agree` says
   * whether `raw` (the GPS fix, when there was one) lay nearer the chosen track than the other, for the counters.
   */
  onSide(country: CountryCode | null, lat: number, lon: number, heading: number | null, raw?: { lat: number; lon: number } | null): { lat: number; lon: number; side: Side | null; agree: boolean | null } {
    const side = runningSide(country, lat, lon);
    const g = this.graph();
    if (!g || side === null || heading === null) return { lat, lon, side: null, agree: null };
    const cands = g.snap(lat, lon).filter((c) => c.d <= PARALLEL_M + 2);
    if (cands.length < 2) return { lat, lon, side, agree: null };
    const chosen = pickTrack(cands, heading, side);
    if (!chosen) return { lat, lon, side, agree: null };
    let agree: boolean | null = null;
    if (raw) {
      const other = cands.filter((c) => c !== chosen).reduce((a, b) => (haversineM(raw.lat, raw.lon, b.point[0], b.point[1]) < haversineM(raw.lat, raw.lon, a.point[0], a.point[1]) ? b : a));
      agree = haversineM(raw.lat, raw.lon, chosen.point[0], chosen.point[1]) <= haversineM(raw.lat, raw.lon, other.point[0], other.point[1]);
    }
    return { lat: chosen.point[0], lon: chosen.point[1], side, agree };
  }
}
