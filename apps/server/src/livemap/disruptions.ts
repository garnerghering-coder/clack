// Disruptions on the network now, for Network now's map (owner, 2026-11-15: "show track closure, where maintenance is
// happening"). Three sources, each only where it says something:
//  - Sweden, Trafikverket OperativeEvent (namespace ols.open 1.0; DATA_FINDINGS.md): live events with a time window,
//    a type (code 16 is "Banarbete/transport", track work) and the stretch they sit on (EventSection, from and to
//    location signatures). Only events with a traffic impact (TrafficImpact) are shown: the rest touch no train.
//  - Finland, Digitraffic's RUMA notices (FINLAND_DATA_FINDINGS.md): traffic restrictions (limitation
//    CLOSED_FROM_TRAFFIC is a closed track) and track-work notices with a part on today, each with its track geometry.
//  - Norway, Entur's SIRI-SX situations: rail ones are those whose affected stops are stations we know (by NSR stop
//    place); shown as a pin at the stop named most, in Entur's own words (English and Norwegian).
// Denmark: no structured source (Rejseplanen's notices are free text per journey), so none.
import { encodePolyline } from '@clack/shared';
import type { Db } from '../db/client.js';
import { stations, trvLocations } from '../db/schema.js';
import { segmentBetween, type StationPoint } from '../geo/trackSegments.js';
import { fetchJson } from '../digitraffic/client.js';
import { trvQuery } from '../trafikverket/client.js';
import { latestSituations } from '../observed/norway.js';

export type DisruptionKind = 'works' | 'closure' | 'incident';

export interface Disruption {
  id: string;
  country: 'SE' | 'NO' | 'FI';
  kind: DisruptionKind;
  /** The source's own short words for it, in its language(s); the app shows its kind first and this under it. */
  title: { sv?: string; en?: string; no?: string } | null;
  /** The stations at its ends (or the one it's at), by name. */
  places: string[];
  /** Epoch ms; null when the source gives none (open-ended). */
  from: number | null;
  to: number | null;
  /** Where to put its pin and centre the map. */
  lat: number;
  lon: number;
  /** The track it covers, as encoded polylines (empty for a pin only). */
  lines: string[];
  source: 'trafikverket' | 'digitraffic' | 'entur';
}

const ms = (s: unknown): number | null => {
  if (typeof s !== 'string') return null;
  const t = Date.parse(s);
  return Number.isFinite(t) ? t : null;
};

// ---------- Sweden ----------

interface TrvSection {
  FromLocation?: { Signature?: string };
  ToLocation?: { Signature?: string };
}
interface TrvOperativeEvent {
  OperativeEventId?: string;
  EventType?: { Description?: string; EventTypeCode?: string };
  StartDateTime?: string;
  EndDateTime?: string;
  ModifiedDateTime?: string;
  Deleted?: boolean;
  Geometry?: { WGS84?: string };
  EventSection?: TrvSection[];
  TrafficImpact?: { PublicMessage?: { Header?: string } }[];
}

/** An open-ended event not updated for this long is taken as left open. */
export const STALE_MS = 24 * 3600_000;

/** Trafikverket's event type for track work ("Banarbete/transport"). */
export const TRV_WORKS_CODE = '16';

/** "POINT (57.81 12.25)": Trafikverket's WGS84 point, latitude first (seen in the archived events, 2026-11-14). */
export function trvPoint(wkt: string | undefined): { lat: number; lon: number } | null {
  const m = wkt?.match(/POINT \(([-\d.]+) ([-\d.]+)\)/);
  if (!m) return null;
  const a = Number(m[1]);
  const b = Number(m[2]);
  // Latitude first in what Trafikverket sends; both orders checked against the Nordic box so a swap can't misplace it.
  if (a > 50 && a < 72 && b > 3 && b < 35) return { lat: a, lon: b };
  if (b > 50 && b < 72 && a > 3 && a < 35) return { lat: b, lon: a };
  return null;
}

export function parseTrafikverket(
  events: TrvOperativeEvent[],
  now: number,
  place: (signature: string) => { name: string; point: StationPoint } | null,
  track: (a: StationPoint, b: StationPoint) => string | null,
): Disruption[] {
  const out: Disruption[] = [];
  for (const e of events) {
    if (e.Deleted || !e.OperativeEventId || !e.TrafficImpact?.length) continue;
    const from = ms(e.StartDateTime);
    const to = ms(e.EndDateTime);
    if ((to !== null && to <= now) || (from !== null && from > now + 24 * 3600_000)) continue;
    // An event with no end that nobody has touched for a day is one left open (one from May was still "on" in
    // November): only open-ended events updated within STALE_MS count.
    const touched = ms(e.ModifiedDateTime) ?? from;
    if (to === null && (touched === null || now - touched > STALE_MS)) continue;
    const section = e.EventSection?.[0];
    const a = section?.FromLocation?.Signature ? place(section.FromLocation.Signature) : null;
    const b = section?.ToLocation?.Signature ? place(section.ToLocation.Signature) : null;
    const point = trvPoint(e.Geometry?.WGS84) ?? (a ? { lat: a.point.lat, lon: a.point.lon } : null);
    if (!point) continue;
    const line = a && b && a.point.id !== b.point.id ? track(a.point, b.point) : null;
    const header = e.TrafficImpact.map((t) => t.PublicMessage?.Header).find((h) => h);
    out.push({
      id: `se:${e.OperativeEventId}`,
      country: 'SE',
      kind: e.EventType?.EventTypeCode === TRV_WORKS_CODE ? 'works' : 'incident',
      title: { sv: header ?? e.EventType?.Description },
      places: [...new Set([a?.name, b?.name].filter((n): n is string => !!n))],
      from,
      to,
      lat: point.lat,
      lon: point.lon,
      lines: line ? [line] : [],
      source: 'trafikverket',
    });
  }
  return out;
}

// ---------- Finland ----------

type LonLat = [number, number];
interface RumaLocation {
  location?: LonLat[][] | LonLat;
  identifierRanges?: { location?: LonLat[][] }[];
}
interface RumaRestriction {
  id?: string;
  state?: string;
  limitation?: string;
  startDate?: string;
  endDate?: string;
  location?: LonLat;
  locations?: RumaLocation[];
}
interface RumaWork {
  id?: string;
  state?: string;
  location?: LonLat;
  workParts?: { startDay?: string; locations?: RumaLocation[] }[];
}

/** Restrictions that close a track to trains (RUMA `limitation`; the electric one closes it to electric trains). */
const CLOSING = new Set(['CLOSED_FROM_TRAFFIC', 'CLOSED_FROM_ELECTRIC_ROLLING_STOCK']);

function rumaLines(locations: RumaLocation[] | undefined): string[] {
  const out: string[] = [];
  for (const l of locations ?? [])
    for (const r of l.identifierRanges ?? [])
      for (const part of r.location ?? []) if (part.length > 1) out.push(encodePolyline(part.map(([lon, lat]) => [lat, lon] as [number, number])));
  return out;
}

export function parseRuma(
  restrictions: RumaRestriction[],
  works: RumaWork[],
  now: number,
  today: string,
  nearest: (lat: number, lon: number) => string | null,
): Disruption[] {
  const out: Disruption[] = [];
  for (const r of restrictions) {
    const from = ms(r.startDate);
    const to = ms(r.endDate);
    if (!r.id || !r.location || (from !== null && from > now) || (to !== null && to <= now)) continue;
    const [lon, lat] = r.location;
    const near = nearest(lat, lon);
    out.push({
      id: `fi:${r.id}`, country: 'FI', kind: CLOSING.has(r.limitation ?? '') ? 'closure' : 'works', title: null,
      places: near ? [near] : [], from, to, lat, lon, lines: rumaLines(r.locations), source: 'digitraffic',
    });
  }
  for (const w of works) {
    const parts = (w.workParts ?? []).filter((p) => p.startDay === today);
    if (!w.id || !w.location || w.state !== 'ACTIVE' || !parts.length) continue;
    const [lon, lat] = w.location;
    const near = nearest(lat, lon);
    out.push({
      id: `fi:${w.id}`, country: 'FI', kind: 'works', title: null, places: near ? [near] : [], from: null, to: null,
      lat, lon, lines: parts.flatMap((p) => rumaLines(p.locations)), source: 'digitraffic',
    });
  }
  return out;
}

// ---------- Norway ----------

interface SxText {
  value?: string;
  lang?: string;
}
interface SxSituation {
  SituationNumber?: { value?: string };
  ParticipantRef?: { value?: string };
  Progress?: string;
  ValidityPeriod?: { StartTime?: string; EndTime?: string }[];
  Summary?: SxText[];
  Affects?: unknown;
}

/** Every NSR stop place an SX situation names, as often as it names it. */
function stopPlaces(affects: unknown): string[] {
  const found: string[] = [];
  const walk = (v: unknown) => {
    if (typeof v === 'string') {
      const m = v.match(/^NSR:StopPlace:\d+$/);
      if (m) found.push(v);
    } else if (Array.isArray(v)) v.forEach(walk);
    else if (v && typeof v === 'object') Object.values(v).forEach(walk);
  };
  walk(affects);
  return found;
}

/** Entur codespaces of Norway's train operators (as they appear in the archived situations, 2026-11): Vy's trains
 * (NSB, VYG), Go-Ahead Nordic (GOA), Flytoget (FLT), SJ Norge (SJN). Buses, boats and trams have their own. */
export const RAIL_CODESPACES = new Set(['NSB', 'VYG', 'GOA', 'FLT', 'SJN']);

/** A situation about trains: posted by a train operator, or naming one's lines or journeys. */
function isRail(s: SxSituation): boolean {
  if (RAIL_CODESPACES.has(s.ParticipantRef?.value ?? '')) return true;
  return [...JSON.stringify(s.Affects ?? {}).matchAll(/"([A-Z]{3}):(?:Line|DatedServiceJourney|ServiceJourney):/g)].some((m) => RAIL_CODESPACES.has(m[1]!));
}

export function parseSituations(situations: SxSituation[], now: number, station: (nsrId: string) => { name: string; lat: number; lon: number } | null): Disruption[] {
  const out: Disruption[] = [];
  for (const s of situations) {
    if ((s.Progress && s.Progress !== 'open') || !isRail(s)) continue;
    const period = s.ValidityPeriod?.[0];
    const from = ms(period?.StartTime);
    const to = ms(period?.EndTime);
    if ((from !== null && from > now) || (to !== null && to <= now)) continue;
    // Rail: the stops it names that are our stations; the one named most carries the pin.
    const counts = new Map<string, number>();
    for (const id of stopPlaces(s.Affects)) if (station(id)) counts.set(id, (counts.get(id) ?? 0) + 1);
    if (!counts.size) continue;
    const top = [...counts].sort((x, y) => y[1] - x[1])[0]![0];
    const at = station(top)!;
    const text = (lang: string) => s.Summary?.find((t) => t.lang?.toUpperCase() === lang)?.value;
    out.push({
      id: `no:${s.SituationNumber?.value ?? `${top}:${from}`}`, country: 'NO', kind: 'incident',
      title: { en: text('EN'), no: text('NO') ?? text('NB') }, places: [at.name], from, to, lat: at.lat, lon: at.lon,
      lines: [], source: 'entur',
    });
  }
  return out;
}

// ---------- fetching ----------

const REFRESH_MS = 5 * 60_000;

/** The disruptions now, asked of each source at most every five minutes; a source that fails keeps its last answer. */
export class Disruptions {
  private bySource = new Map<string, Disruption[]>();
  private at = 0;
  private running: Promise<void> | null = null;

  constructor(
    private readonly db: Db,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  /** What is known now; starts a refresh in the background when it is due. */
  current(now = Date.now()): Disruption[] {
    if (now - this.at > REFRESH_MS && !this.running) {
      this.at = now;
      this.running = this.refresh(now).finally(() => (this.running = null));
    }
    return [...this.bySource.values()].flat();
  }

  async refresh(now = Date.now()) {
    await Promise.all([
      this.keep('trafikverket', () => this.sweden(now)),
      this.keep('digitraffic', () => this.finland(now)),
      this.keep('entur', () => this.norway(now)),
    ]);
  }

  private async keep(source: string, load: () => Promise<Disruption[]>) {
    try {
      this.bySource.set(source, await load());
    } catch {
      // The last answer stays; the next refresh tries again.
    }
  }

  private async sweden(now: number) {
    const at = new Date(now).toISOString();
    const q = `<QUERY objecttype="OperativeEvent" namespace="ols.open" schemaversion="1.0"><FILTER><AND><EQ name="Deleted" value="false"/><OR><GT name="EndDateTime" value="${at}"/><EXISTS name="EndDateTime" value="false"/></OR></AND></FILTER></QUERY>`;
    const events = ((await trvQuery<{ OperativeEvent?: TrvOperativeEvent[] }>(q, this.fetchImpl)).OperativeEvent ?? []) as TrvOperativeEvent[];
    const locations = new Map(this.db.select().from(trvLocations).all().map((l) => [l.signature, l]));
    const bySignature = new Map(this.db.select({ id: stations.id, name: stations.name, sig: stations.trvSignature, lat: stations.lat, lon: stations.lon }).from(stations).all().filter((s) => s.sig).map((s) => [s.sig!, s]));
    return parseTrafikverket(
      events,
      now,
      (sig) => {
        const s = bySignature.get(sig);
        if (s) return { name: s.name, point: { id: s.id, lat: s.lat, lon: s.lon } };
        const l = locations.get(sig);
        return l && l.lat !== null && l.lon !== null ? { name: l.name, point: { id: `trv:${sig}`, lat: l.lat, lon: l.lon } } : null;
      },
      (a, b) => encodePolyline(segmentBetween(this.db, a, b).points),
    );
  }

  private async finland(now: number) {
    const opts = { fetchImpl: this.fetchImpl };
    const [restrictions, works] = await Promise.all([
      fetchJson<RumaRestriction[]>('trafficrestriction-notifications.json?state=SENT', opts),
      fetchJson<RumaWork[]>('trackwork-notifications.json?state=ACTIVE', opts),
    ]);
    const fi = this.db.select({ name: stations.name, lat: stations.lat, lon: stations.lon, country: stations.country }).from(stations).all().filter((s) => s.country === 'FI');
    const today = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Helsinki' }).format(now);
    return parseRuma(restrictions, works, now, today, (lat, lon) => nearestName(fi, lat, lon));
  }

  private async norway(now: number) {
    // The list the archive's poll fetched last (observed/norway.ts), not a second ask: Entur limits how often a client
    // may ask. Older than 20 minutes (the poll failing) counts as none.
    const last = latestSituations();
    if (!last || now - last.at > 20 * 60_000) return [];
    const byNsr = new Map(this.db.select({ nsr: stations.nsrId, name: stations.name, lat: stations.lat, lon: stations.lon }).from(stations).all().filter((s) => s.nsr).map((s) => [s.nsr!, s]));
    return parseSituations(last.situations as SxSituation[], now, (id) => byNsr.get(id) ?? null);
  }
}

/** The name of the station nearest a point, within 25 km. */
function nearestName(list: { name: string; lat: number; lon: number }[], lat: number, lon: number): string | null {
  let best: { name: string; d: number } | null = null;
  const k = Math.cos((lat * Math.PI) / 180);
  for (const s of list) {
    const d = Math.hypot(s.lat - lat, (s.lon - lon) * k) * 111;
    if (d < 25 && (!best || d < best.d)) best = { name: s.name, d };
  }
  return best?.name ?? null;
}
