// The front end only ever talks to our own server (keys stay server-side).
import type { Settings } from '@clack/shared';

export class ApiError extends Error {
  constructor(
    public status: number,
    public body: { error?: string; duplicateOf?: string },
  ) {
    super(body.error ?? `HTTP ${status}`);
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api${path}`, { ...init, headers: { 'Content-Type': 'application/json', ...init?.headers } });
  if (res.status === 204) return undefined as T;
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new ApiError(res.status, body);
  return body as T;
}

export interface StationHit {
  id: string;
  name: string;
  /** Trafikverket signature, e.g. "Cst". */
  code: string | null;
  country: string;
}

export interface Operator {
  id: string;
  name: string;
  shortName: string;
  brandColor: string;
  logoPath: string | null;
}

export type Product = 'high_speed' | 'intercity' | 'night' | 'regional' | 'commuter' | 'heritage';

export interface StopRef {
  seq: number;
  stationId: string;
  name: string;
  code: string | null;
  country: string;
  tz: string;
  time: number;
}

export interface TripResult {
  key: string;
  serviceDate: string;
  trainNumber: string | null;
  operatorId: string | null;
  category: string;
  product: Product;
  routeName: string | null;
  from: StopRef;
  to: StopRef;
  durationMin: number;
  stopsBetween: number;
  alsoKnownAs: string[];
}

export interface SearchResponse {
  date: string;
  interpretation: { operator?: { id: string; text: string }; trainNumber?: string; from?: StationHit; to?: StationHit; typing: 'from' | 'to' | null };
  suggestions: StationHit[];
  results: TripResult[] | null;
  outsideTimetable: boolean;
}

export interface TripStop {
  seq: number;
  stationId: string;
  name: string;
  code: string | null;
  country: string;
  tz: string;
  lat: number;
  lon: number;
  arr: number | null;
  dep: number | null;
  noPickup: boolean;
  noDropoff: boolean;
}

export interface TimetableTrip {
  key: string;
  serviceDate: string;
  trainNumber: string | null;
  operatorId: string | null;
  category: string;
  stops: TripStop[];
}

interface StationRef {
  id: string;
  name: string;
  code: string | null;
  country: string;
  tz: string;
}

export interface Leg {
  id: string;
  status: 'planned' | 'completed' | 'snapshotted';
  dataQuality: 'full' | 'partial' | 'scheduled_only' | 'manual';
  trainNumber: string | null;
  category: string | null;
  serviceDate: string | null;
  schedDep: string | null;
  schedArr: string | null;
  actualDep: string | null;
  actualArr: string | null;
  depDelayMin: number | null;
  arrDelayMin: number | null;
  depPlatform: string | null;
  arrPlatform: string | null;
  canceled: boolean;
  distanceM: number | null;
  isEstimatedGeometry: boolean;
  countryCodes: string[];
  operator: Operator | null;
  origin: StationRef | null;
  destination: StationRef | null;
  notes: string | null;
  live: LiveState | null;
}

export type LiveStatus = 'scheduled' | 'boarding' | 'en_route' | 'at_stop' | 'arrived' | 'cancelled';

/** Times are ISO strings from the REST API and epoch ms from the live stream; use ms() on either. */
export interface LiveState {
  updatedAt: string | number;
  status: LiveStatus;
  lat: number | null;
  lon: number | null;
  bearing: number | null;
  speedKmh: number | null;
  positionSource: 'gps' | 'estimated' | null;
  positionAt: string | number | null;
  progress: number | null;
  prevStopId: string | null;
  nextStopId: string | null;
  eta: string | number | null;
  arrivalEta: string | number | null;
  arrivalDelayMin: number | null;
}

export interface LegEvent {
  id?: number;
  type: 'delayed' | 'platform_changed' | 'cancelled' | 'short_turned' | 'departed' | 'arrived';
  ts: string | number;
  payload: Record<string, unknown>;
}

export interface LiveUpdate {
  legId: string;
  live: LiveState;
  events: LegEvent[];
}

export interface LegStop {
  seq: number;
  role: 'before' | 'board' | 'through' | 'alight' | 'after';
  stationId: string;
  name: string;
  code: string | null;
  country: string;
  tz: string;
  lat: number;
  lon: number;
  schedArr: string | null;
  schedDep: string | null;
  actualArr: string | null;
  actualDep: string | null;
  estimatedArr: string | null;
  estimatedDep: string | null;
  platform: string | null;
  canceled: boolean;
  deviations: string[];
}

export interface LegDetail extends Leg {
  /** Encoded polyline of the ridden route along the track (null until routed). */
  geometry: string | null;
  stops: LegStop[];
  events: LegEvent[];
}

export interface TripGeometry {
  segments: { fromSeq: number; toSeq: number; polyline: string; lengthM: number; estimated: boolean }[];
}

export const ms = (t: string | number | null | undefined) => (t === null || t === undefined || t === '' ? null : typeof t === 'number' ? t : Date.parse(t));

export const api = {
  getSettings: () => request<Settings>('/settings'),
  updateSettings: (patch: Partial<Settings>) => request<Settings>('/settings', { method: 'PATCH', body: JSON.stringify(patch) }),
  popularStations: () => request<StationHit[]>('/stations/popular'),
  search: (q: string, date: string, signal?: AbortSignal) => request<SearchResponse>(`/search?q=${encodeURIComponent(q)}&date=${date}`, { signal }),
  timetableTrip: (key: string, date: string) => request<TimetableTrip>(`/timetable/trips/${encodeURIComponent(key)}?date=${date}`),
  timetableTripGeometry: (key: string, date: string) => request<TripGeometry>(`/timetable/trips/${encodeURIComponent(key)}/geometry?date=${date}`),
  operators: () => request<Operator[]>('/operators'),
  legs: () => request<Leg[]>('/legs'),
  leg: (id: string) => request<LegDetail>(`/legs/${id}`),
  createLeg: (body: { tripKey: string; serviceDate: string; fromSeq: number; toSeq: number; force?: boolean }) => request<LegDetail>('/legs', { method: 'POST', body: JSON.stringify(body) }),
  refreshLeg: (id: string) => request<LegDetail>(`/legs/${id}/refresh`, { method: 'POST' }),
  deleteLeg: (id: string) => request<void>(`/legs/${id}`, { method: 'DELETE' }),
};
