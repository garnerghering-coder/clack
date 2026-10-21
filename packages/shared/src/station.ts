// Station maps (ADDITIONS_01 C1–C3): the data format, its validator, walking routes and the connection status.
// One JSON file per station in data/stations/<station_id>.json; the format doesn't depend on the renderer.
//
// Coordinates are metres in a local frame around `origin` (x east, y south, so they map straight onto SVG); the
// spec allowed "schematic" or "wgs84", and local metres give real walking distances without a projection step.

export type Pt = [number, number];
export type StationNodeType = 'platform' | 'platform_access' | 'hall' | 'entrance' | 'stairs' | 'escalator' | 'lift' | 'gate' | 'junction';
export type EdgeKind = 'walk' | 'stairs' | 'escalator' | 'lift';
export const POI_CATEGORIES = ['toilet', 'cafe', 'restaurant', 'kiosk', 'shop', 'ticket', 'locker', 'waiting', 'info', 'pharmacy', 'atm', 'taxi', 'bus', 'other'] as const;
export type PoiCategory = (typeof POI_CATEGORIES)[number];

export interface StationLevel {
  id: string;
  name: string;
  /** Higher is further up; used for "up"/"down" in directions. */
  order: number;
}
export interface StationShape {
  level: string;
  kind: 'building' | 'hall' | 'room' | 'shop';
  name?: string;
  points: Pt[];
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
}
export interface StationNode {
  id: string;
  type: StationNodeType;
  level: string;
  x: number;
  y: number;
  platform?: string;
  name?: string;
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
}
export interface StationPoi {
  id: string;
  category: PoiCategory;
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
}
export interface StationMap {
  station_id: string;
  name: string;
  updated: string;
  /** "hand_curated" once someone has checked it end to end; "osm_draft" straight from the draft script. */
  quality: 'osm_draft' | 'hand_curated';
  sources: { type: 'osm' | 'manual' | 'website' | 'trafikverket'; license?: string; retrieved?: string; url?: string; note?: string }[];
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
  // Everything must be reachable from the first platform (one connected walking graph).
  const start = m.platforms[0]?.node;
  const seen = new Set<string>();
  if (start) {
    const stack = [start];
    while (stack.length) {
      const n = stack.pop()!;
      if (seen.has(n)) continue;
      seen.add(n);
      for (const [to] of adj.get(n) ?? []) stack.push(to);
    }
  }
  for (const p of m.platforms) {
    if (!levels.has(p.level)) errors.push(`platform ${p.ref}: unknown level ${p.level}`);
    if (!nodes.has(p.node)) errors.push(`platform ${p.ref}: unknown node ${p.node}`);
    else if (!seen.has(p.node)) errors.push(`platform ${p.ref}: unreachable`);
    if (!p.tracks.length) errors.push(`platform ${p.ref}: no tracks`);
  }
  for (const p of m.pois) {
    if (!nodes.has(p.node)) errors.push(`poi ${p.id}: unknown node ${p.node}`);
    else if (!seen.has(p.node)) errors.push(`poi ${p.id}: unreachable`);
    if (!levels.has(p.level)) errors.push(`poi ${p.id}: unknown level ${p.level}`);
  }
  return errors;
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
  if (e.kind === 'walk') s *= PACE_FACTOR[p.pace];
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
  const base = track.toLowerCase().replace(/[a-z]+$/, '');
  return m.platforms.find((p) => p.tracks.includes(base)) ?? null;
}

export function routeTracks(m: StationMap, fromTrack: string | null | undefined, toTrack: string | null | undefined, p: WalkProfile = DEFAULT_PROFILE): StationRoute | null {
  const a = platformForTrack(m, fromTrack);
  const b = platformForTrack(m, toTrack);
  if (!a || !b) return null;
  if (a.id === b.id) return { nodes: [m.nodes.find((n) => n.id === a.node)!], steps: [], seconds: 30, meters: 0, levels: [a.level] };
  return routeNodes(m, a.node, b.node, p);
}

/** Directions from templates (i18n keys + values), merging consecutive walking. Never generated text. */
export interface Instruction {
  key: 'leave' | 'walk' | 'stairs_up' | 'stairs_down' | 'escalator_up' | 'escalator_down' | 'lift_up' | 'lift_down' | 'arrive';
  level?: string;
  seconds: number;
  track?: string;
}
export function instructions(m: StationMap, r: StationRoute, fromTrack?: string | null, toTrack?: string | null): Instruction[] {
  const order = new Map(m.levels.map((l) => [l.id, l.order]));
  const out: Instruction[] = [{ key: 'leave', seconds: 0, ...(fromTrack ? { track: fromTrack } : {}) }];
  for (const s of r.steps) {
    const up = (order.get(s.to.level) ?? 0) > (order.get(s.from.level) ?? 0);
    const key: Instruction['key'] = s.kind === 'walk' ? 'walk' : (`${s.kind}_${up ? 'up' : 'down'}` as Instruction['key']);
    const last = out.at(-1)!;
    if (key === 'walk' && last.key === 'walk') last.seconds += s.seconds;
    else if (key !== 'walk' && last.key === key) last.seconds += s.seconds;
    else out.push({ key, seconds: s.seconds, ...(key === 'walk' ? {} : { level: s.to.level }) });
  }
  out.push({ key: 'arrive', seconds: 0, ...(toTrack ? { track: toTrack } : {}) });
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

export type ConnectionStatus = 'easy' | 'tight' | 'miss' | 'unknown' | 'broken' | 'check_signs' | 'probably_ok';
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
 * slack = layover − walk − deboard − board buffers. Green ≥ 5 min, yellow 0–5, red < 0. Estimated walks are
 * never green: under 15 min of slack it's "check signs" (grey), above it "probably fine" (yellow).
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
  else if (estimated) status = slack >= 15 * 60 ? 'probably_ok' : 'check_signs';
  else status = slack >= 5 * 60 ? 'easy' : 'tight';
  return { status, layoverSeconds: layover, walkSeconds: walk, slackSeconds: slack, estimated };
}
