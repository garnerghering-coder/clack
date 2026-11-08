// Station maps (ADDITIONS_01 C1–C3): the data format, its validator, walking routes and the connection status.
// One JSON file per station in data/stations/<station_id>.json; the format doesn't depend on the renderer.
//
// Coordinates are metres in a local frame around `origin` (x east, y south, so they map straight onto SVG); the
// spec allowed "schematic" or "wgs84", and local metres give real walking distances without a projection step.
//
// Schema 2 (build 54, docs/STATION_MAPPING.md) adds what a 3D view and platform-level positioning need, all optional
// so schema-1 files and older apps keep working: level heights, platform edges per track, building and platform
// heights, track numbers on the rails, escalator directions, and `_source` on every element (where the fact came
// from: an OSM way, a published plan, a video frame, a walk log). `validateStationMap` demands the sources and the
// exits only of files that say `schema: 2`.

export type Pt = [number, number];
export type StationNodeType = 'platform' | 'platform_access' | 'hall' | 'entrance' | 'stairs' | 'escalator' | 'lift' | 'gate' | 'junction';
/** "ramp": a step-free slope between two levels (a tunnel coming out at street level, a cycle path up from an underpass). */
export type EdgeKind = 'walk' | 'stairs' | 'escalator' | 'lift' | 'ramp';
export const POI_CATEGORIES = ['toilet', 'cafe', 'restaurant', 'kiosk', 'shop', 'ticket', 'locker', 'waiting', 'info', 'pharmacy', 'atm', 'taxi', 'bus', 'other'] as const;
export type PoiCategory = (typeof POI_CATEGORIES)[number];

/**
 * Where an element's facts come from (schema 2): "osm:way/123", "osm:node/45", "plan:<which plan>",
 * "video:<file> @ mm:ss", "walk:<log id>", "mapillary:<image id>", "commons:<file>", "manual:<note>", or
 * "derived:<how>" for things worked out from other sourced elements (a platform's middle). Several, comma-separated.
 */
export type SourceRef = string;

export interface StationLevel {
  id: string;
  name: string;
  /** Higher is further up; used for "up"/"down" in directions. */
  order: number;
  /** Floor height in metres above the reference level (the main platforms' level is 0), measured; absent when not known. */
  height_m?: number;
  _source?: SourceRef;
}
export interface StationShape {
  level: string;
  /** "track" is an open line (rails between platforms); the others are polygons. */
  /** "roof": a roof with open sides or an unknown underside (a platform canopy). "bridge": an enclosed footbridge
   *  between `base_m` (its underside) and `top_m`. */
  kind: 'building' | 'hall' | 'room' | 'shop' | 'track' | 'roof' | 'bridge';
  name?: string;
  points: Pt[];
  /** For "track": the track number, when the rails carry one (OSM railway:track_ref / ref). */
  ref?: string;
  /** For buildings: the height in metres when the source gives one (OSM height=). */
  height_m?: number;
  /** For buildings and roofs: the top, in metres above the platform surface (the reference level), measured. */
  top_m?: number;
  /** For buildings: the lowest ground at the outline; for bridges: the underside. Metres above the platform surface. */
  base_m?: number;
  _source?: SourceRef;
}
/** One side of a platform where trains stop: the line along the rails, with the track it serves when known. */
export interface PlatformEdge {
  /** The track id at this edge; null when the sources don't say which side is which (the review queue lists it). */
  track: string | null;
  points: Pt[];
  _source: SourceRef;
  note?: string;
}
export interface StationPlatform {
  id: string;
  /** Platform number as signed ("14", "15–16"). */
  ref: string;
  /** Trafikverket track ids served (TrackAtLocation, without sector letter). */
  tracks: string[];
  level: string;
  /** Outline polygons (OSM often maps one platform in a few pieces). */
  geometry: Pt[][];
  /** The node a route starts or ends at (type "platform", at the middle of the platform). */
  node: string;
  /** Platform surface above the rail head, metres, when a source gives it. */
  height_m?: number;
  /** The platform's edges along the tracks (schema 2). */
  edges?: PlatformEdge[];
  /** Lettered stopping sectors along the platform from a register (Entur's boarding positions): a point each, and the
   *  stretch it covers when the source draws one. */
  sectors?: SectorMark[];
  /** Drawn, but no walk to it is known: the sources don't connect it to the rest of the station. Never routed to. */
  unconnected?: boolean;
  _source?: SourceRef;
}
/** One lettered stopping sector ("A", "B") of a platform: where its sign stands, and the stretch when known. */
export interface SectorMark {
  ref: string;
  /** The track whose sector it is, when the platform serves more than one. */
  track?: string;
  point: Pt;
  from?: Pt;
  to?: Pt;
  _source: SourceRef;
}
/** How much of what a walk needs the map has, 0–1 each (scripts/stations/validate.ts writes it). */
export interface StationCoverage {
  /** Platforms that can be routed to. */
  platforms: number;
  /** Levels with platforms that a change of level (stairs, escalator, lift, ramp) reaches; 1 for a one-level map. */
  vertical: number;
  /** Platforms that reach an entrance. */
  entrances: number;
  /** Shops, cafés and the like with opening hours. */
  hours: number;
  /** Platforms whose edges say which track is which side. */
  sides: number;
  /** Platforms with stopping sectors (absent where no source has them). */
  sectors?: number;
}
export interface StationNode {
  id: string;
  type: StationNodeType;
  level: string;
  x: number;
  y: number;
  platform?: string;
  name?: string;
  _source?: SourceRef;
}
export interface StationEdge {
  from: string;
  to: string;
  /** Walking seconds at normal pace, no luggage (multipliers apply at runtime). */
  seconds: number;
  step_free: boolean;
  kind: EdgeKind;
  meters?: number;
  /** Polyline for drawing, from → to; straight when missing. */
  geometry?: Pt[];
  source?: 'osm' | 'manual';
  /** Escalators: which way they run (from → to), when the source says. */
  direction?: 'up' | 'down' | 'both';
  _source?: SourceRef;
}
export interface StationPoi {
  id: string;
  category: PoiCategory;
  /** A more specific pictogram than the category ("burger", "bakery", "books"…), when the tags say. */
  icon?: string;
  name: string;
  level: string;
  x: number;
  y: number;
  /** The walking-graph node it's reached from. */
  node: string;
  fee?: null | 'free' | { amount: number; currency: string };
  opening_hours?: string | null;
  hours_source: 'osm' | 'manual' | 'website' | null;
  /** When a person last checked the hours; null = taken from OpenStreetMap as is. */
  hours_verified: string | null;
  /** The place's own outline (a shop's unit), when it is mapped as one; otherwise it's drawn as a pin. */
  outline?: Pt[];
  /** The pin stands for a place described in words, not located: at the building, hall or entrance it names. */
  approximate?: boolean;
  /** The description it was placed from ("in the hall, by entrance A"), shown with an approximate pin. */
  where?: string;
  _source?: SourceRef;
}
export type StationSourceType = 'osm' | 'manual' | 'website' | 'trafikverket' | 'lantmateriet' | 'plan' | 'video' | 'walk' | 'mapillary' | 'commons'
  // The other countries' laser (heights, ground) and platform registers (the research passes).
  | 'helsinki' | 'nls' | 'kartverket' | 'sdfi' | 'digitraffic' | 'banenor' | 'banedanmark' | 'entur';
/** The laser sources whose credit the map must show where their heights are drawn. */
export const LASER_SOURCES: StationSourceType[] = ['lantmateriet', 'helsinki', 'nls', 'kartverket', 'sdfi'];
export interface StationMap {
  /** 1 (or absent): the original format; 2: with sources on every element, heights and platform edges. */
  schema?: 1 | 2;
  station_id: string;
  name: string;
  updated: string;
  /** "hand_curated" once someone has checked it end to end; "osm_draft" straight from the draft script. */
  quality: 'osm_draft' | 'hand_curated';
  sources: { type: StationSourceType; license?: string; retrieved?: string; url?: string; note?: string }[];
  changelog: { date: string; who: string; what: string }[];
  coord_system: 'local_m';
  origin: { lat: number; lon: number };
  /** Default view: rotate so the platforms run up the screen. */
  view?: { rotation: number };
  levels: StationLevel[];
  shapes: StationShape[];
  platforms: StationPlatform[];
  nodes: StationNode[];
  edges: StationEdge[];
  pois: StationPoi[];
  /** What the map covers, 0–1 each; absent in files written before build 63. */
  coverage?: StationCoverage;
  /** When the opening hours were last re-read from their sources (scripts/stations/hours_recheck.ts), YYYY-MM-DD. */
  hours_checked?: string;
  /** The ground as a grid in the map's frame: heights in metres above the platform surface at x0 + i·step,
   *  y0 + j·step (heights[j][i]); null where the source has no value. */
  terrain?: { x0: number; y0: number; step: number; cols: number; rows: number; heights: (number | null)[][]; _source: SourceRef };
}

// ---------- Validation (the build fails on any of these) ----------
export function validateStationMap(m: StationMap): string[] {
  const errors: string[] = [];
  const levels = new Set(m.levels.map((l) => l.id));
  const nodes = new Map(m.nodes.map((n) => [n.id, n]));
  if (nodes.size !== m.nodes.length) errors.push('duplicate node ids');
  for (const n of m.nodes) if (!levels.has(n.level)) errors.push(`node ${n.id}: unknown level ${n.level}`);
  for (const e of m.edges) {
    if (!nodes.has(e.from) || !nodes.has(e.to)) errors.push(`edge ${e.from}→${e.to}: unknown node`);
    if (!(typeof e.seconds === 'number' && e.seconds > 0 && Number.isFinite(e.seconds))) errors.push(`edge ${e.from}→${e.to}: no seconds`);
  }
  const adj = adjacency(m);
  // Everything must be reachable from the first connected platform (one walking graph), apart from platforms marked
  // `unconnected` and what hangs off them (their own piece of the graph).
  const seen = reachable(adj, m.platforms.filter((p) => !p.unconnected).map((p) => p.node).slice(0, 1));
  const islands = reachable(adj, m.platforms.filter((p) => p.unconnected).map((p) => p.node));
  if (m.platforms.length && m.platforms.every((p) => p.unconnected)) errors.push('every platform is unconnected');
  for (const p of m.platforms) {
    if (!levels.has(p.level)) errors.push(`platform ${p.ref}: unknown level ${p.level}`);
    if (!nodes.has(p.node)) errors.push(`platform ${p.ref}: unknown node ${p.node}`);
    else if (!p.unconnected && !seen.has(p.node)) errors.push(`platform ${p.ref}: unreachable`);
    if (!p.tracks.length) errors.push(`platform ${p.ref}: no tracks`);
  }
  for (const p of m.pois) {
    if (!nodes.has(p.node)) errors.push(`poi ${p.id}: unknown node ${p.node}`);
    else if (!seen.has(p.node) && !islands.has(p.node)) errors.push(`poi ${p.id}: unreachable`);
    if (!levels.has(p.level)) errors.push(`poi ${p.id}: unknown level ${p.level}`);
  }
  if ((m.schema ?? 1) >= 2) errors.push(...validateSchema2(m, nodes));
  if (m.quality === 'hand_curated') errors.push(...handCuratedProblems(m).map((p) => `hand_curated, but ${p}`));
  return errors;
}

/**
 * Schema 2's stricter rules: every element says where it comes from; a change of level is stairs, an escalator or
 * a lift, never a plain walk; a platform edge names a track the platform serves. A platform with no known way to an
 * entrance is not an error (build 64: such maps ship, and say so): `stationReview` lists it and the coverage counts it.
 */
function validateSchema2(m: StationMap, nodes: Map<string, StationNode>): string[] {
  const errors: string[] = [];
  const need = (what: string, src: SourceRef | undefined) => {
    if (!src || !src.trim()) errors.push(`${what}: no _source`);
  };
  for (const l of m.levels) need(`level ${l.id}`, l._source);
  m.sources.forEach((s, i) => { if (!s.type) errors.push(`source ${i}: no type (the app needs one)`); });
  m.shapes.forEach((s, i) => need(`shape ${i} (${s.kind}${s.name ? ` ${s.name}` : ''})`, s._source));
  m.shapes.forEach((s, i) => {
    if (s.kind === 'roof' && s.top_m === undefined) errors.push(`shape ${i} (roof${s.name ? ` ${s.name}` : ''}): a roof needs top_m`);
    if (s.kind === 'bridge' && (s.top_m === undefined || s.base_m === undefined)) errors.push(`shape ${i} (bridge${s.name ? ` ${s.name}` : ''}): a bridge needs top_m and base_m`);
    if (s.top_m !== undefined && s.base_m !== undefined && s.top_m <= s.base_m) errors.push(`shape ${i}: top_m is not above base_m`);
  });
  if (m.terrain) {
    const t = m.terrain;
    need('terrain', t._source);
    if (t.heights.length !== t.rows || t.heights.some((r) => r.length !== t.cols)) errors.push('terrain: heights do not match cols × rows');
  }
  for (const p of m.platforms) {
    need(`platform ${p.ref}`, p._source);
    for (const e of p.edges ?? []) {
      need(`platform ${p.ref} edge`, e._source);
      if (e.track !== null && !p.tracks.includes(e.track.toLowerCase().replace(/[a-z]+$/, ''))) errors.push(`platform ${p.ref}: edge track ${e.track} is not one of its tracks`);
      if (e.points.length < 2) errors.push(`platform ${p.ref}: an edge with fewer than 2 points`);
    }
  }
  for (const n of m.nodes) need(`node ${n.id}`, n._source);
  for (const e of m.edges) {
    need(`edge ${e.from}→${e.to}`, e._source);
    const a = nodes.get(e.from);
    const b = nodes.get(e.to);
    if (a && b && a.level !== b.level && e.kind === 'walk') errors.push(`edge ${e.from}→${e.to}: changes level (${a.level}→${b.level}) but is a walk, not stairs, an escalator, a lift or a ramp`);
  }
  for (const p of m.pois) need(`poi ${p.id}`, p._source);
  return errors;
}

/**
 * What a map is still missing, for the review queue (docs/STATION_MAPPING.md): not errors, but things a walk, a
 * plan or a video can settle. `knownTracks`: the tracks the timetable or the boards use at this station, when known.
 */
export function stationReview(m: StationMap, knownTracks?: string[] | null): string[] {
  const out: string[] = [];
  const base = (t: string) => t.toLowerCase().replace(/[a-z]+$/, '');
  const mapped = new Set(m.platforms.flatMap((p) => p.tracks.map(base)));
  for (const t of new Set((knownTracks ?? []).map(base))) if (t && !mapped.has(t)) out.push(`track ${t} is used in the timetable or boards but no platform in the map serves it`);
  for (const p of m.platforms) {
    if (p.unconnected) out.push(`platform ${p.ref}: drawn but not connected (no path, stairs or lift to it in the sources)`);
    if ((m.schema ?? 1) >= 2 && !p.edges?.length) out.push(`platform ${p.ref}: no platform edges (which side the trains stop at)`);
    for (const e of p.edges ?? []) if (e.track === null) out.push(`platform ${p.ref}: an edge whose track is not known (${e.note ?? 'island platform: which side is which track'})`);
    if (p.height_m === undefined && (m.schema ?? 1) >= 2) out.push(`platform ${p.ref}: height above rail not known`);
  }
  if (m.levels.length > 1) for (const l of m.levels) if (l.height_m === undefined) out.push(`level ${l.id} (${l.name}): height not measured`);
  const levelsWithPlatforms = new Set(m.platforms.map((p) => p.level));
  const vertical = m.edges.filter((e) => e.kind !== 'walk');
  if (m.levels.length > 1 && !vertical.length) out.push('several levels but no stairs, escalators or lifts between them');
  if (!m.nodes.some((n) => n.type === 'entrance')) out.push('no entrances mapped');
  else {
    const adj = adjacency(m);
    const entrances = new Set(m.nodes.filter((n) => n.type === 'entrance').map((n) => n.id));
    for (const p of m.platforms.filter((p) => !p.unconnected)) if (![...reachable(adj, [p.node])].some((n) => entrances.has(n))) out.push(`platform ${p.ref}: no way to an entrance`);
  }
  for (const p of m.platforms)
    if (m.levels.length > 1 && !m.edges.some((e) => e.kind !== 'walk' && (m.nodes.find((n) => n.id === e.from)?.platform === p.id || m.nodes.find((n) => n.id === e.to)?.platform === p.id)) && levelsWithPlatforms.size < m.levels.length)
      out.push(`platform ${p.ref}: no stairs, escalator or lift of its own (reached along the platform level only)`);
  for (const poi of m.pois) if (!poi.opening_hours && ['cafe', 'restaurant', 'kiosk', 'shop', 'pharmacy', 'waiting'].includes(poi.category)) out.push(`${poi.category} ${poi.name || poi.id}: no opening hours`);
  return out;
}

/** Every node reachable from `starts`. */
/** Categories whose opening hours a traveller needs (the review queue asks for them). */
const HOURS_CATEGORIES: PoiCategory[] = ['cafe', 'restaurant', 'kiosk', 'shop', 'pharmacy', 'waiting'];

/** What the map covers, 0–1 each, rounded to two places: the numbers behind data/stations/COVERAGE.md and the
 *  sentence under a draft map's name. */
export function stationCoverage(m: StationMap): StationCoverage {
  const r = (n: number, d: number) => (d ? Math.round((n / d) * 100) / 100 : 1);
  const adj = adjacency(m);
  const ps = m.platforms;
  const connected = ps.filter((p) => !p.unconnected);
  const byId = new Map(m.nodes.map((n) => [n.id, n]));
  const platformLevels = [...new Set(ps.map((p) => p.level))];
  const verticalLevels = new Set(m.edges.filter((e) => e.kind !== 'walk').flatMap((e) => [byId.get(e.from)?.level, byId.get(e.to)?.level]));
  const entrances = new Set(m.nodes.filter((n) => n.type === 'entrance').map((n) => n.id));
  const reachesExit = connected.filter((p) => [...reachable(adj, [p.node])].some((n) => entrances.has(n))).length;
  const hoursPois = m.pois.filter((p) => HOURS_CATEGORIES.includes(p.category));
  const sided = ps.filter((p) => p.edges?.length && p.edges.every((e) => e.track !== null)).length;
  const hasSectors = (p: StationPlatform) => !!p.sectors?.length || (p.edges ?? []).some((e) => !!e.track && /^\d+[a-z]$/.test(e.track));
  const out: StationCoverage = {
    platforms: r(connected.length, ps.length),
    vertical: m.levels.length <= 1 ? 1 : r(platformLevels.filter((l) => verticalLevels.has(l)).length, platformLevels.length),
    entrances: r(reachesExit, ps.length),
    hours: r(hoursPois.filter((p) => !!p.opening_hours).length, hoursPois.length),
    sides: r(sided, ps.length),
  };
  if (ps.some(hasSectors)) out.sectors = r(ps.filter(hasSectors).length, ps.length);
  return out;
}

/**
 * Why a map may not (yet) say `hand_curated` (docs/STATION_MAPPING.md): every platform's sides name their tracks from
 * a register; every level with platforms has a change of level whose source is not OpenStreetMap alone; no entrance
 * stands in from a footway end; every level has a measured height (or there is one level); no unconnected platform.
 */
export function handCuratedProblems(m: StationMap): string[] {
  const out: string[] = [];
  const byId = new Map(m.nodes.map((n) => [n.id, n]));
  for (const p of m.platforms) {
    if (p.unconnected) out.push(`platform ${p.ref}: unconnected`);
    if (!p.edges?.length || p.edges.some((e) => e.track === null)) out.push(`platform ${p.ref}: sides without tracks`);
    else if (p.edges.every((e) => /^osm:/.test(e._source.trim()))) out.push(`platform ${p.ref}: sides from OpenStreetMap only, not a register`);
  }
  const osmOnly = (src: string | undefined) => !src || src.split(',').every((x) => /^\s*osm:/.test(x));
  for (const l of new Set(m.platforms.map((p) => p.level)))
    if (m.levels.length > 1 && !m.edges.some((e) => e.kind !== 'walk' && !osmOnly(e._source) && (byId.get(e.from)?.level === l || byId.get(e.to)?.level === l)))
      out.push(`level ${l}: no change of level from a source other than OpenStreetMap`);
  for (const n of m.nodes) if (n.type === 'entrance' && (/^derived:/.test(n._source ?? '') || /footway end/.test(n._source ?? ''))) out.push(`entrance ${n.id}: stands in from a footway end`);
  if (m.levels.length > 1) for (const l of m.levels) if (l.height_m === undefined) out.push(`level ${l.id}: no measured height`);
  return out;
}

function reachable(adj: Map<string, [string, StationEdge][]>, starts: string[]): Set<string> {
  const seen = new Set<string>();
  const stack = [...starts];
  while (stack.length) {
    const n = stack.pop()!;
    if (seen.has(n)) continue;
    seen.add(n);
    for (const [to] of adj.get(n) ?? []) stack.push(to);
  }
  return seen;
}

function adjacency(m: StationMap): Map<string, [string, StationEdge][]> {
  const adj = new Map<string, [string, StationEdge][]>();
  for (const e of m.edges) {
    (adj.get(e.from) ?? adj.set(e.from, []).get(e.from)!).push([e.to, e]);
    (adj.get(e.to) ?? adj.set(e.to, []).get(e.to)!).push([e.from, e]);
  }
  return adj;
}

// ---------- Walking profile and routes (C3) ----------
export const PACES = ['relaxed', 'normal', 'brisk'] as const;
export type Pace = (typeof PACES)[number];
export const PACE_FACTOR: Record<Pace, number> = { relaxed: 1.25, normal: 1, brisk: 0.8 };
export interface WalkProfile {
  pace: Pace;
  stepFree: boolean;
  luggage: boolean;
}
export const DEFAULT_PROFILE: WalkProfile = { pace: 'normal', stepFree: false, luggage: false };

/** Seconds for one edge for this person; null = not allowed (stairs when step-free only). */
export function edgeSeconds(e: StationEdge, p: WalkProfile): number | null {
  if (p.stepFree && !e.step_free) return null;
  let s = e.seconds;
  if (e.kind === 'walk' || e.kind === 'ramp') s *= PACE_FACTOR[p.pace];
  if (e.kind === 'stairs') s = s * PACE_FACTOR[p.pace] * (p.luggage ? 1.8 : 1) + (p.luggage ? 15 : 0);
  if (e.kind === 'escalator') s = s * (p.luggage ? 1.2 : 1) + (p.luggage ? 5 : 0);
  return s;
}

export interface RouteStep {
  kind: EdgeKind;
  from: StationNode;
  to: StationNode;
  seconds: number;
  edge: StationEdge;
}
export interface StationRoute {
  nodes: StationNode[];
  steps: RouteStep[];
  seconds: number;
  meters: number;
  levels: string[];
}

/** Shortest walk between two nodes (Dijkstra; station graphs are a few hundred nodes). */
export function routeNodes(m: StationMap, from: string, to: string, p: WalkProfile = DEFAULT_PROFILE): StationRoute | null {
  const adj = adjacency(m);
  const byId = new Map(m.nodes.map((n) => [n.id, n]));
  if (!byId.has(from) || !byId.has(to)) return null;
  const dist = new Map<string, number>([[from, 0]]);
  const prev = new Map<string, [string, StationEdge]>();
  const done = new Set<string>();
  // A plain array as the queue: fine at this size.
  const queue: [number, string][] = [[0, from]];
  while (queue.length) {
    let bi = 0;
    for (let i = 1; i < queue.length; i++) if (queue[i]![0] < queue[bi]![0]) bi = i;
    const [d, n] = queue.splice(bi, 1)[0]!;
    if (done.has(n)) continue;
    done.add(n);
    if (n === to) break;
    for (const [next, e] of adj.get(n) ?? []) {
      const s = edgeSeconds(e, p);
      if (s === null || done.has(next)) continue;
      const nd = d + s;
      if (nd < (dist.get(next) ?? Infinity)) {
        dist.set(next, nd);
        prev.set(next, [n, e]);
        queue.push([nd, next]);
      }
    }
  }
  if (!done.has(to)) return null;
  const path: string[] = [to];
  const edges: StationEdge[] = [];
  while (path[0] !== from) {
    const [pn, e] = prev.get(path[0]!)!;
    path.unshift(pn);
    edges.unshift(e);
  }
  const nodes = path.map((id) => byId.get(id)!);
  const steps = edges.map((e, i) => ({ kind: e.kind, from: nodes[i]!, to: nodes[i + 1]!, seconds: edgeSeconds(e, p)!, edge: e }));
  const levels: string[] = [];
  for (const n of nodes) if (levels.at(-1) !== n.level) levels.push(n.level);
  return {
    nodes,
    steps,
    seconds: Math.round(dist.get(to)!),
    meters: Math.round(edges.reduce((s, e) => s + (e.meters ?? Math.hypot(byId.get(e.from)!.x - byId.get(e.to)!.x, byId.get(e.from)!.y - byId.get(e.to)!.y)), 0)),
    levels,
  };
}

/** Walking seconds from the nearest of `sources` to every node (for "along my path": detours to amenities). */
export function secondsFrom(m: StationMap, sources: string[], p: WalkProfile = DEFAULT_PROFILE): Map<string, number> {
  const adj = adjacency(m);
  const dist = new Map<string, number>(sources.map((s) => [s, 0]));
  const done = new Set<string>();
  const queue: [number, string][] = sources.map((s) => [0, s]);
  while (queue.length) {
    let bi = 0;
    for (let i = 1; i < queue.length; i++) if (queue[i]![0] < queue[bi]![0]) bi = i;
    const [d, n] = queue.splice(bi, 1)[0]!;
    if (done.has(n)) continue;
    done.add(n);
    for (const [next, e] of adj.get(n) ?? []) {
      const s = edgeSeconds(e, p);
      if (s === null || done.has(next)) continue;
      if (d + s < (dist.get(next) ?? Infinity)) {
        dist.set(next, d + s);
        queue.push([d + s, next]);
      }
    }
  }
  return dist;
}

/** The platform serving a Trafikverket track ("17b" → the platform with track 17). */
export function platformForTrack(m: StationMap, track: string | null | undefined): StationPlatform | null {
  if (!track) return null;
  // A track that is only letters (Oslo S's "B") is matched whole: stripping would leave nothing.
  const base = track.toLowerCase().replace(/[a-z]+$/, '') || track.toLowerCase();
  return m.platforms.find((p) => p.tracks.includes(base)) ?? null;
}

export function routeTracks(m: StationMap, fromTrack: string | null | undefined, toTrack: string | null | undefined, p: WalkProfile = DEFAULT_PROFILE): StationRoute | null {
  const track = (t: string | null | undefined) => (t && !t.includes(':') ? resolveEndpoint(m, t) : null);
  return routeBetween(m, track(fromTrack), track(toTrack), p);
}

// ---------- Endpoints: where a walk starts or ends ----------
// As a URL value: a track ("11", "17b"), an amenity ("p:<poi id>"), any node such as an entrance ("n:<node id>"),
// or the walker's own position snapped to the map ("me:<node id>").
export type EndpointKind = 'track' | 'poi' | 'node' | 'me';
export interface Endpoint {
  spec: string;
  kind: EndpointKind;
  node: StationNode;
  track?: string;
  platform?: StationPlatform;
  poi?: StationPoi;
}

export function resolveEndpoint(m: StationMap, spec: string | null | undefined): Endpoint | null {
  if (!spec) return null;
  const node = (id: string) => m.nodes.find((n) => n.id === id) ?? null;
  const colon = spec.indexOf(':');
  const [kind, id] = colon < 0 ? ['track', spec] : [spec.slice(0, colon), spec.slice(colon + 1)];
  if (kind === 'track') {
    const platform = platformForTrack(m, id);
    const n = platform && node(platform.node);
    return n ? { spec, kind: 'track', node: n, track: id, platform: platform! } : null;
  }
  if (kind === 'p') {
    const poi = m.pois.find((p) => p.id === id);
    const n = poi && node(poi.node);
    return n ? { spec, kind: 'poi', node: n, poi } : null;
  }
  if (kind === 'n' || kind === 'me') {
    const n = node(id);
    return n ? { spec, kind: kind === 'n' ? 'node' : 'me', node: n } : null;
  }
  return null;
}

export function routeBetween(m: StationMap, a: Endpoint | null, b: Endpoint | null, p: WalkProfile = DEFAULT_PROFILE): StationRoute | null {
  if (!a || !b) return null;
  // The same platform (or the same spot): no walk to speak of.
  if ((a.platform && a.platform.id === b.platform?.id) || a.node.id === b.node.id)
    return { nodes: [a.node], steps: [], seconds: a.platform ? 30 : 0, meters: 0, levels: [a.node.level] };
  // A platform the sources don't connect: no route is known, and none is made up.
  if (a.platform?.unconnected || b.platform?.unconnected) return null;
  return routeNodes(m, a.node.id, b.node.id, p);
}

/** WGS84 to the map's local metres (x east, y south); an equirectangular step is plenty inside one station. */
export function toLocal(m: StationMap, lat: number, lon: number): Pt {
  const kx = 111_320 * Math.cos((m.origin.lat * Math.PI) / 180);
  return [(lon - m.origin.lon) * kx, -(lat - m.origin.lat) * 110_574];
}

/** The map's local metres back to WGS84 (the inverse of toLocal). */
export function fromLocal(m: StationMap, x: number, y: number): [number, number] {
  const kx = 111_320 * Math.cos((m.origin.lat * Math.PI) / 180);
  return [m.origin.lat - y / 110_574, m.origin.lon + x / kx];
}

/**
 * Where a train standing at a track is drawn, in WGS84: for a sector ("2a") the middle of that sector's edge when the
 * map has one (owner, 2026-10-30: trains wait at their part of the platform), else the platform's node (its middle);
 * null when the map doesn't know the track.
 */
export function platformPoint(m: StationMap, track: string | null | undefined): [number, number] | null {
  const p = platformForTrack(m, track);
  if (!p) return null;
  const sector = (track ?? '').trim().toLowerCase();
  const edge = /[a-z]$/.test(sector) ? p.edges?.find((e) => e.track === sector && e.points.length >= 2) : undefined;
  if (edge) {
    const [x, y] = midpointAlong(edge.points);
    return fromLocal(m, x, y);
  }
  const n = m.nodes.find((x) => x.id === p.node);
  return n ? fromLocal(m, n.x, n.y) : null;
}

/** The point halfway along a polyline, by length. */
export function midpointAlong(pts: Pt[]): Pt {
  const seg = pts.slice(1).map((q, i) => Math.hypot(q[0] - pts[i]![0], q[1] - pts[i]![1]));
  let left = seg.reduce((a, b) => a + b, 0) / 2;
  for (let i = 0; i < seg.length; i++) {
    if (left <= seg[i]!) {
      const f = seg[i]! > 0 ? left / seg[i]! : 0;
      const a = pts[i]!, b = pts[i + 1]!;
      return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f];
    }
    left -= seg[i]!;
  }
  return pts[pts.length - 1]!;
}

/** The walking-graph node closest to a point on a level, if one is within `maxMeters`. */
export function nearestNode(m: StationMap, level: string, x: number, y: number, maxMeters = Infinity): StationNode | null {
  const reachable = new Set(m.edges.flatMap((e) => [e.from, e.to]));
  let best: StationNode | null = null;
  let bd = maxMeters;
  for (const n of m.nodes) {
    if (n.level !== level || !reachable.has(n.id)) continue;
    const d = Math.hypot(n.x - x, n.y - y);
    if (d <= bd) [best, bd] = [n, d];
  }
  return best;
}

/** Directions from templates (i18n keys + values), merging consecutive walking. Never generated text. */
export interface Instruction {
  key: 'leave' | 'start' | 'walk' | 'stairs_up' | 'stairs_down' | 'escalator_up' | 'escalator_down' | 'lift_up' | 'lift_down' | 'ramp_up' | 'ramp_down' | 'arrive' | 'reach';
  level?: string;
  seconds: number;
  track?: string;
  /** For start / reach: the endpoint (the caller turns it into a name). */
  endpoint?: Endpoint;
}
/** `from` / `to` are tracks (as before) or endpoints; a track endpoint reads "Leave track 11", others "Start at …". */
export function instructions(m: StationMap, r: StationRoute, from?: string | Endpoint | null, to?: string | Endpoint | null): Instruction[] {
  const order = new Map(m.levels.map((l) => [l.id, l.order]));
  const end = (e: string | Endpoint | null | undefined, track: 'leave' | 'arrive', place: 'start' | 'reach'): Instruction => {
    if (!e || typeof e === 'string') return { key: track, seconds: 0, ...(e ? { track: e } : {}) };
    return e.kind === 'track' ? { key: track, seconds: 0, track: e.track! } : { key: place, seconds: 0, endpoint: e };
  };
  const out: Instruction[] = [end(from, 'leave', 'start')];
  for (const s of r.steps) {
    const up = (order.get(s.to.level) ?? 0) > (order.get(s.from.level) ?? 0);
    const key: Instruction['key'] = s.kind === 'walk' ? 'walk' : (`${s.kind}_${up ? 'up' : 'down'}` as Instruction['key']);
    const last = out.at(-1)!;
    if (key === 'walk' && last.key === 'walk') last.seconds += s.seconds;
    else if (key !== 'walk' && last.key === key) last.seconds += s.seconds;
    else out.push({ key, seconds: s.seconds, ...(key === 'walk' ? {} : { level: s.to.level }) });
  }
  out.push(end(to, 'arrive', 'reach'));
  return out.map((i) => ({ ...i, seconds: Math.round(i.seconds) }));
}

// ---------- Connections (Layover Guide, C3) ----------
export type SizeClass = 'small' | 'medium' | 'large';
/** Walk estimate when there's no station map (or the two platforms aren't connected in it). */
export const SIZE_WALK_SECONDS: Record<SizeClass, number> = { small: 120, medium: 240, large: 420 };
/** Station size from the number of distinct base tracks (Trafikverket PlatformLine): ≤ 4 small, ≤ 10 medium. */
export const sizeClass = (baseTracks: number): SizeClass => (baseTracks <= 4 ? 'small' : baseTracks <= 10 ? 'medium' : 'large');

export const DEBOARD_SECONDS = 60;
export const BOARD_SECONDS = 30;

/**
 * easy: mapped walk, live times, ≥ 5 min spare. tight: under 5 min spare. miss: no time left. margin: enough time
 * on paper, but the walk is an estimate or the times aren't live yet, so it's stated as a margin, not a promise
 * (product brief §7). broken: a train is cancelled. unknown: not enough to say.
 */
export type ConnectionStatus = 'easy' | 'tight' | 'miss' | 'unknown' | 'broken' | 'margin';
export interface ConnectionInput {
  /** Expected arrival of the first train and departure of the second (best estimate, ms). */
  arrival: number | null;
  departure: number | null;
  arrivalPlatform: string | null;
  departurePlatform: string | null;
  canceledA?: boolean;
  canceledB?: boolean;
  /** Walking seconds from the station map, or null when there isn't one / no path. */
  walkSeconds: number | null;
  /** Fallback when walkSeconds is null. */
  sizeClass?: SizeClass | null;
  /** Both times come from real-time data (actuals or Trafikverket's estimates), not just the timetable. Default true. */
  timesLive?: boolean;
}
export interface ConnectionResult {
  status: ConnectionStatus;
  layoverSeconds: number | null;
  walkSeconds: number | null;
  slackSeconds: number | null;
  /** The walk is an estimate from the station's size, not a route on a map. */
  estimated: boolean;
}

/**
 * Pure, so a platform change or delay can recompute it instantly (and push notifications can reuse it):
 * slack = layover − walk − deboard − board buffers. Green ≥ 5 min only with a mapped walk and live times; yellow
 * 0–5; red < 0. With an estimated walk or timetable-only times it's a neutral "margin" with the minutes.
 */
export function connectionStatus(c: ConnectionInput): ConnectionResult {
  const layover = c.arrival !== null && c.departure !== null ? Math.round((c.departure - c.arrival) / 1000) : null;
  const estimated = c.walkSeconds === null;
  const walk = c.walkSeconds ?? (c.sizeClass ? SIZE_WALK_SECONDS[c.sizeClass] : null);
  if (c.canceledA || c.canceledB) return { status: 'broken', layoverSeconds: layover, walkSeconds: walk, slackSeconds: null, estimated };
  if (layover === null || walk === null || (!estimated && (!c.arrivalPlatform || !c.departurePlatform)))
    return { status: 'unknown', layoverSeconds: layover, walkSeconds: walk, slackSeconds: null, estimated };
  const slack = layover - walk - DEBOARD_SECONDS - BOARD_SECONDS;
  let status: ConnectionStatus;
  if (slack < 0) status = 'miss';
  else if (slack < 5 * 60) status = 'tight';
  else if (estimated || c.timesLive === false) status = 'margin';
  else status = 'easy';
  return { status, layoverSeconds: layover, walkSeconds: walk, slackSeconds: slack, estimated };
}

/** One lettered part of a platform ("2a"): where its label goes, inside the platform, and its middle line along it. */
export interface PlatformSector {
  sector: string;
  label: Pt;
  /** The middle of the platform along the sector, every 10 m (where the platform is beside the sector's line). */
  line: Pt[];
}

/**
 * A platform's lettered sectors (edges with tracks "2a", "2b") and the lines across the platform where one meets the
 * next, in the map's metres (owner, 2026-10-30: the a and b pieces marked separately on the zoomed map). A sector's
 * line is its track line (BanInfo) or the platform edge; the divider is the platform's cross-section halfway between
 * the two sectors' facing ends. Empty when the platform has fewer than two sectors.
 */
export function platformSectors(p: StationPlatform): { sectors: PlatformSector[]; dividers: [Pt, Pt][] } {
  const base = p.ref.trim().toLowerCase();
  const lines = (p.edges ?? []).flatMap((e) => (e.track && /^\d+[a-z]$/.test(e.track) && e.track.slice(0, -1) === base && e.points.length >= 2 ? [{ ...e, track: e.track }] : []));
  const rings = p.geometry ?? [];
  if (lines.length < 2 || !rings.length) return { sectors: [], dividers: [] };
  // The platform's direction: from the first sector's start to its end, the others' order along it.
  const all = lines.flatMap((e) => e.points);
  const a = all[0]!, b = all[all.length - 1]!;
  let dir: Pt = [b[0] - a[0], b[1] - a[1]];
  const len = Math.hypot(dir[0], dir[1]) || 1;
  dir = [dir[0] / len, dir[1] / len];
  const along = (q: Pt) => (q[0] - a[0]) * dir[0] + (q[1] - a[1]) * dir[1];
  const sorted = lines.map((e) => {
    const t = e.points.map(along);
    return { e, lo: Math.min(...t), hi: Math.max(...t) };
  }).sort((x, y) => x.lo - y.lo);
  const sectors = sorted.map(({ e }) => {
    const mid = midpointAlong(e.points);
    const cut = crossSection(rings, mid, localDir(e.points, mid));
    const line: Pt[] = [];
    for (const q of resample(e.points, 10)) {
      const c = crossSection(rings, q, localDir(e.points, q));
      if (c) line.push([(c[0][0] + c[1][0]) / 2, (c[0][1] + c[1][1]) / 2]);
    }
    return { sector: e.track, label: cut ? [(cut[0][0] + cut[1][0]) / 2, (cut[0][1] + cut[1][1]) / 2] as Pt : mid, line };
  });
  const dividers: [Pt, Pt][] = [];
  for (let i = 0; i + 1 < sorted.length; i++) {
    const t = (sorted[i]!.hi + sorted[i + 1]!.lo) / 2;
    // The point at that distance on either sector's line (whichever comes closest), across the platform there.
    const pts = [...sorted[i]!.e.points, ...sorted[i + 1]!.e.points];
    const ordered = [...pts].sort((x, y) => along(x) - along(y));
    const j = Math.max(1, ordered.findIndex((q) => along(q) >= t));
    const q0 = ordered[j - 1]!, q1 = ordered[Math.min(j, ordered.length - 1)]!;
    const f = along(q1) - along(q0) > 1e-6 ? (t - along(q0)) / (along(q1) - along(q0)) : 0;
    const at: Pt = [q0[0] + (q1[0] - q0[0]) * f, q0[1] + (q1[1] - q0[1]) * f];
    const cut = crossSection(rings, at, norm([q1[0] - q0[0], q1[1] - q0[1]]) ?? dir);
    if (cut) dividers.push(cut);
  }
  // Each sector's line reaches the divider(s) beside it, so its name runs right up to where the next begins.
  for (const [a, b] of dividers) {
    const mid: Pt = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
    for (const sc of sectors) {
      if (!sc.line.length) continue;
      const dFirst = Math.hypot(sc.line[0]![0] - mid[0], sc.line[0]![1] - mid[1]);
      const dLast = Math.hypot(sc.line.at(-1)![0] - mid[0], sc.line.at(-1)![1] - mid[1]);
      if (Math.min(dFirst, dLast) >= 120) continue;
      if (dFirst < dLast) sc.line.unshift(mid);
      else sc.line.push(mid);
    }
  }
  return { sectors, dividers };
}

/** Points every `step` metres along a polyline, both ends included. */
function resample(pts: Pt[], step: number): Pt[] {
  const out: Pt[] = [pts[0]!];
  let carry = 0;
  for (let i = 0; i + 1 < pts.length; i++) {
    const a = pts[i]!, b = pts[i + 1]!;
    const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    let d = step - carry;
    while (d <= len) {
      out.push([a[0] + ((b[0] - a[0]) * d) / len, a[1] + ((b[1] - a[1]) * d) / len]);
      d += step;
    }
    carry = len - (d - step);
  }
  const last = pts[pts.length - 1]!;
  if (Math.hypot(out.at(-1)![0] - last[0], out.at(-1)![1] - last[1]) > 1) out.push(last);
  return out;
}

function norm(v: Pt): Pt | null {
  const l = Math.hypot(v[0], v[1]);
  return l > 1e-6 ? [v[0] / l, v[1] / l] : null;
}

/** The direction of a polyline at its point nearest `q`. */
function localDir(pts: Pt[], q: Pt): Pt {
  let best = 0, bestD = Infinity;
  for (let i = 0; i + 1 < pts.length; i++) {
    const d = Math.hypot((pts[i]![0] + pts[i + 1]![0]) / 2 - q[0], (pts[i]![1] + pts[i + 1]![1]) / 2 - q[1]);
    if (d < bestD && norm([pts[i + 1]![0] - pts[i]![0], pts[i + 1]![1] - pts[i]![1]])) [best, bestD] = [i, d];
  }
  return norm([pts[best + 1]![0] - pts[best]![0], pts[best + 1]![1] - pts[best]![1]]) ?? [1, 0];
}

/**
 * The platform's width at `q` across direction `d`: where the line through `q` square to `d` crosses the outline, the
 * stretch nearest `q` (q may lie just off the platform, on its track line). Null when the line misses the platform.
 */
export function crossSection(rings: Pt[][], q: Pt, d: Pt): [Pt, Pt] | null {
  const n: Pt = [-d[1], d[0]];
  const ts: number[] = [];
  for (const ring of rings) {
    // Every side, the closing one too (a closed ring's last side has no length and is skipped).
    for (let i = 0; i < ring.length; i++) {
      const p0 = ring[i]!, p1 = ring[(i + 1) % ring.length]!;
      const ex = p1[0] - p0[0], ey = p1[1] - p0[1];
      const den = n[0] * ey - n[1] * ex;
      if (Math.abs(den) < 1e-9) continue;
      // q + t·n = p0 + s·e
      const t = ((p0[0] - q[0]) * ey - (p0[1] - q[1]) * ex) / den;
      const s = ((p0[0] - q[0]) * n[1] - (p0[1] - q[1]) * n[0]) / den;
      if (s >= 0 && s <= 1) ts.push(t);
    }
  }
  ts.sort((x, y) => x - y);
  // Inside-stretches are consecutive pairs; the one holding q, else the nearest within 15 m.
  const gap = ([lo, hi]: [number, number]) => (lo <= 0 && hi >= 0 ? 0 : Math.min(Math.abs(lo), Math.abs(hi)));
  let best: [number, number] | null = null;
  for (let i = 0; i + 1 < ts.length; i += 2) {
    const span: [number, number] = [ts[i]!, ts[i + 1]!];
    if (span[1] - span[0] >= 0.3 && (!best || gap(span) < gap(best))) best = span;
  }
  if (!best || gap(best) > 15) return null;
  return [[q[0] + n[0] * best[0], q[1] + n[1] * best[0]], [q[0] + n[0] * best[1], q[1] + n[1] * best[1]]];
}

// ---------- Walk mode: directions with distance, turn and landmark (twin of ClackCore RouteGuide.swift) ----------
export type GuideTurn = 'left' | 'right' | 'straight' | 'u_turn';
export interface GuideStep {
  key: Instruction['key'];
  distanceM: number;
  turn?: GuideTurn;
  landmark?: { poiId: string; name: string; side: 'left' | 'right' };
  at: Pt;
  level: string;
  seconds: number;
  points: Pt[];
}
const GUIDE_TURN_DEG = 35, GUIDE_STEP_M = 2, GUIDE_WINDOW_M = 6, GUIDE_LANDMARK_M = 10;
const len = (pts: Pt[]) => pts.slice(1).reduce((s, q, i) => s + Math.hypot(q[0] - pts[i]![0], q[1] - pts[i]![1]), 0);
/** Degrees clockwise from north (up, −y). */
const bearing = (a: Pt, b: Pt) => ((Math.atan2(b[0] - a[0], -(b[1] - a[1])) * 180) / Math.PI + 360) % 360;
const turnDelta = (a: number, b: number) => ((((b - a) % 360) + 540) % 360) - 180;

/** The route as walk-mode steps: walks on one level cut where they bend by more than 35°, and the level changes. */
export function guide(m: StationMap, r: StationRoute): GuideStep[] {
  const order = new Map(m.levels.map((l) => [l.id, l.order]));
  const out: GuideStep[] = [];
  let run: Pt[] = [], runSec = 0, runLevel = '';
  const flush = () => {
    if (run.length > 1) out.push(...splitWalk(m, run, runLevel, runSec));
    run = [];
    runSec = 0;
  };
  for (const s of r.steps) {
    const g = s.edge.geometry && s.edge.geometry.length > 1 ? s.edge.geometry : ([[s.from.x, s.from.y], [s.to.x, s.to.y]] as Pt[]);
    const pts = s.edge.from === s.from.id ? g : [...g].reverse();
    if (s.kind === 'walk' && s.from.level === s.to.level) {
      if (runLevel !== s.from.level) flush();
      runLevel = s.from.level;
      const last = run.at(-1);
      run.push(...(last && Math.abs(last[0] - pts[0]![0]) < 0.01 && Math.abs(last[1] - pts[0]![1]) < 0.01 ? pts.slice(1) : pts));
      runSec += s.seconds;
    } else {
      flush();
      const up = (order.get(s.to.level) ?? 0) > (order.get(s.from.level) ?? 0);
      const key = `${s.kind}_${up ? 'up' : 'down'}` as Instruction['key'];
      const prev = out.at(-1);
      if (prev && prev.key === key) {
        prev.distanceM += len(pts);
        prev.seconds += s.seconds;
        prev.level = s.to.level;
        prev.points.push(...pts.slice(1));
      } else out.push({ key, distanceM: len(pts), at: pts[0]!, level: s.to.level, seconds: s.seconds, points: [...pts] });
    }
  }
  flush();
  return out;
}

function splitWalk(m: StationMap, pts: Pt[], level: string, seconds: number): GuideStep[] {
  const s = resample(pts, GUIDE_STEP_M);
  if (s.length <= 2) return [{ key: 'walk', distanceM: len(pts), at: pts[0]!, level, seconds, points: pts }];
  const w = GUIDE_WINDOW_M / GUIDE_STEP_M;
  const cuts: { i: number; a: number }[] = [];
  const bend = (i: number) => turnDelta(bearing(s[i - w]!, s[i]!), bearing(s[i]!, s[i + w]!));
  for (let i = w; i < s.length - w; ) {
    const d = bend(i);
    if (Math.abs(d) <= GUIDE_TURN_DEG) { i++; continue; }
    let best = { i, a: d };
    let j = i + 1;
    for (; j < s.length - w; j++) {
      const dj = bend(j);
      if (Math.abs(dj) <= GUIDE_TURN_DEG) break;
      if (Math.abs(dj) > Math.abs(best.a)) best = { i: j, a: dj };
    }
    cuts.push(best);
    i = j + w;
  }
  const total = len(s);
  const ends = [...cuts.map((c) => c.i), s.length - 1];
  const out: GuideStep[] = [];
  let start = 0;
  ends.forEach((end, n) => {
    const piece = s.slice(start, end + 1);
    const dist = len(piece);
    const from = s[Math.max(start - w, 0)]!, at = s[start]!, ahead = s[Math.min(start + w, s.length - 1)]!;
    const dir: Pt = n === 0 ? [ahead[0] - at[0], ahead[1] - at[1]] : [at[0] - from[0], at[1] - from[1]];
    const a = cuts[n - 1]?.a;
    const turn: GuideTurn | undefined = n === 0 ? undefined : Math.abs(a!) > 150 ? 'u_turn' : a! > 0 ? 'right' : 'left';
    const lm = m.pois
      .filter((p) => p.level === level && p.name && !p.approximate)
      .map((p) => ({ p, d: Math.hypot(p.x - at[0], p.y - at[1]) }))
      .filter((x) => x.d <= GUIDE_LANDMARK_M)
      .sort((x, y) => x.d - y.d)[0];
    const side = lm ? (dir[0] * (lm.p.y - at[1]) - dir[1] * (lm.p.x - at[0]) > 0 ? 'right' : 'left') : undefined;
    out.push({ key: 'walk', distanceM: dist, ...(turn ? { turn } : {}), ...(lm ? { landmark: { poiId: lm.p.id, name: lm.p.name, side: side! } } : {}), at, level, seconds: total > 0 ? (seconds * dist) / total : 0, points: piece });
    start = end;
  });
  return out;
}
