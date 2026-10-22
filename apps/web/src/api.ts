// The front end only ever talks to our own server (keys stay server-side).
import type { AmenityEntry, OnboardFacts, Settings, SizeClass, StationMap } from '@clack/shared';

export class ApiError extends Error {
  constructor(
    public status: number,
    public body: { error?: string; duplicateOf?: string },
  ) {
    super(body.error ?? `HTTP ${status}`);
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  // Only declare JSON when there is a body: Fastify rejects an empty body labelled application/json.
  const headers = init?.body ? { 'Content-Type': 'application/json', ...init.headers } : init?.headers;
  const res = await fetch(`/api${path}`, { ...init, headers });
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
  county?: string | null;
}

export interface Operator {
  id: string;
  name: string;
  shortName: string;
  brandColor: string;
  /** Set when the brand's app icon has been downloaded to this computer. */
  logoUrl?: string | null;
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
  trainType: string | null;
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
  /** Before the current timetable: the archive timetable for that day is ready, loading, failed or unavailable (before 2012-08-10). */
  history?: 'ready' | 'loading' | 'failed' | 'unavailable' | 'norway';
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

/** A train you're watching (not a trip). `train` is its live-map entry while it's running. */
export interface Follow {
  trainNumber: string;
  serviceDate: string;
  operatorId: string | null;
  label: string | null;
  train: { id: string; next: string | null; nextEta: number | null; delayMin: number | null; destination: string | null } | null;
}

/** One call of a live-map train, with what Trafikverket reports for it. */
export interface LiveTrainStop {
  seq: number;
  stationId: string;
  name: string;
  arr: number | null;
  dep: number | null;
  actualArr: number | null;
  actualDep: number | null;
  estimatedArr: number | null;
  estimatedDep: number | null;
  platform: string | null;
  canceled: boolean;
  passed: boolean;
}

export interface TimetableTrip {
  key: string;
  serviceDate: string;
  trainNumber: string | null;
  operatorId: string | null;
  category: string;
  product: Product;
  trainType: string | null;
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
  trainType: string | null;
  trainTypeSource: 'typical' | 'composition' | 'user' | null;
  /** Trafikverket's on-board facts where you boarded (catering, day-of notices). */
  onboard: OnboardFacts | null;
  countryCodes: string[];
  operator: Operator | null;
  origin: StationRef | null;
  destination: StationRef | null;
  notes: string | null;
  journeyId: string | null;
  live: LiveState | null;
  /** Did you ride it: pending | auto | confirmed | review | not_taken (server legs/recording.ts). */
  ride: 'pending' | 'auto' | 'confirmed' | 'review' | 'not_taken';
  rideReason: string | null;
  /** The reported stop nearest an unreported end abroad (Hyllie for København H), as evidence the train ran. */
  borderEvidence?: { board?: { stationId: string; at: number }; alight?: { stationId: string; at: number } } | null;
}

export interface Journey {
  id: string;
  legs: (Leg & { geometry: string | null })[];
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
  /** Who reports this stop live; null: nobody can (Denmark, SJ in Norway), so its times are the timetable's. */
  reportSource?: 'trafikverket' | 'entur' | null;
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

export interface TrainType {
  id: string;
  name: string;
  builder: string | null;
  max_kmh: number | null;
  since: number | null;
  art: string;
  about: string;
}

export interface LegRef {
  legId: string;
  from: string;
  to: string;
  distanceM: number;
  minutes: number;
  dep: number;
  arr: number;
  delayMin: number | null;
}
export interface CountRow {
  key: string;
  count: number;
  distanceM: number;
}
export interface Milestone {
  family: 'journeys' | 'distanceKm' | 'stations' | 'operators' | 'countries' | 'borderCrossings' | 'nightTrains';
  target: number;
  at?: number;
  legId?: string;
  value?: number;
}

export interface Passport {
  milestones: { achieved: Milestone[]; next: Milestone[] };
  /** Trips waiting for "Did you take this train?". */
  review: { legId: string; reason: string | null; dep: number | null; from: string; to: string; trainNumber: string | null }[];
  years: number[];
  scope: { year: number | null; includeCommuter: boolean };
  totals: { distanceM: number; minutes: number; trains: number; journeys: number; stations: number; countries: number; borderCrossings: number; cancellations: number };
  flavor: { earthLaps: number; swedenLengths: number; topRoute: { route: string; count: number } | null; busiestMonth: { month: string; count: number } | null; lateMinutes: number };
  records: {
    longestDistance: LegRef | null;
    longestDuration: LegRef | null;
    biggestDelay: LegRef | null;
    mostRiddenRoute: { route: string; count: number } | null;
    busiestStation: { id: string; name: string; count: number } | null;
    earliestDeparture: LegRef | null;
    latestArrival: LegRef | null;
  };
  operators: CountRow[];
  products: CountRow[];
  trainTypes: CountRow[];
  delays: { basedOn: number; onTimePct: number | null; totalLateMin: number; averageMin: number | null; worst: LegRef | null; bands: Record<'on_time' | 'slight' | 'late' | 'very_late', number>; cancellations: number };
  countries: { code: string; legs: number }[];
  stations: { id: string; name: string; country: string; lat: number; lon: number; count: number }[];
  co2: { comparison: string; trainKg: number; comparisonKg: number; savedKg: number };
  map: { legId: string; operatorId: string | null; geometry: string | null; stops: [number, number][] }[];
  refs: { operators: Record<string, Operator>; trainTypes: Record<string, TrainType> };
}

export interface StationInfo {
  id: string;
  name: string;
  code: string | null;
  country: string;
  tz: string;
  lat: number;
  lon: number;
  county: string | null;
  hasBoard: boolean;
  hasMap: boolean;
  /** For walk estimates when there's no station map. */
  sizeClass: SizeClass | null;
  favorite: boolean;
}

export type BoardType = 'departures' | 'arrivals';

export interface BoardRow {
  id: string;
  trainNumber: string;
  advertised: number;
  estimated: number | null;
  actual: number | null;
  done: boolean;
  delayMin: number | null;
  platform: string | null;
  platformChange: { from: string | null; at: number | null } | null;
  canceled: boolean;
  deviations: string[];
  endpoints: string[];
  via: string[];
  operatorId: string | null;
  productName: string | null;
  product: Product;
  trainType: string | null;
  onboard: OnboardFacts | null;
  trip: { key: string; serviceDate: string; seq: number } | null;
}

export interface Board {
  stationId: string;
  signature: string;
  type: BoardType;
  from: number;
  to: number;
  updatedAt: number;
  rows: BoardRow[];
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
  createManualLeg: (body: { fromStationId: string; toStationId: string; date: string; dep: string; arr: string; operatorId: string | null; trainNumber: string | null; category: string }) =>
    request<LegDetail>('/legs/manual', { method: 'POST', body: JSON.stringify(body) }),
  refreshLeg: (id: string) => request<LegDetail>(`/legs/${id}/refresh`, { method: 'POST' }),
  station: (id: string) => request<StationInfo>(`/stations/${id}`),
  stationMap: (id: string) => request<StationMap>(`/stations/${id}/map`),
  searchStations: (q: string, signal?: AbortSignal) => request<StationHit[]>(`/stations/search?q=${encodeURIComponent(q)}&limit=12`, { signal }),
  board: (id: string, type: BoardType, window?: { from: number; to: number }) =>
    request<Board>(`/stations/${id}/board?type=${type}${window ? `&from=${window.from}&to=${window.to}` : ''}`),
  setFavorite: (id: string, on: boolean) => request<{ favorite: boolean }>(`/stations/${id}/favorite`, { method: on ? 'PUT' : 'DELETE' }),
  stationViewed: (id: string) => request<void>(`/stations/${id}/viewed`, { method: 'POST' }),
  favoriteStations: () => request<StationHit[]>('/stations/favorites'),
  recentStations: () => request<StationHit[]>('/stations/recent'),
  liveTrain: (id: string) => request<{ train: never; trip: { key: string; serviceDate: string } | null; legId: string | null }>(`/live/trains/${encodeURIComponent(id)}`),
  follows: () => request<Follow[]>('/follows'),
  follow: (body: { trainNumber: string; serviceDate: string; operatorId: string | null; label: string | null }) => request<{ following: boolean }>('/follows', { method: 'PUT', body: JSON.stringify(body) }),
  unfollow: (number: string, date: string) => request<{ following: boolean }>(`/follows/${encodeURIComponent(number)}/${date}`, { method: 'DELETE' }),
  liveTrainStops: (id: string) => request<{ stops: LiveTrainStop[] }>(`/live/trains/${encodeURIComponent(id)}/stops`),
  journey: (id: string) => request<Journey>(`/journeys/${id}`),
  setTrainType: (id: string, trainType: string | null) => request<LegDetail>(`/legs/${id}`, { method: 'PATCH', body: JSON.stringify({ trainType }) }),
  trainTypes: () => request<TrainType[]>('/train-types'),
  amenities: () => request<AmenityEntry[]>('/amenities'),
  passport: (q: { year: number | null; commuter: boolean; comparison?: string }) =>
    request<Passport>(`/passport?year=${q.year ?? 'all'}&commuter=${q.commuter}${q.comparison ? `&comparison=${q.comparison}` : ''}`),
  answerRide: (id: string, answer: 'yes' | 'no' | 'undo') => request<LegDetail>(`/legs/${id}/ride`, { method: 'POST', body: JSON.stringify({ answer }) }),
  deleteLeg: (id: string) => request<void>(`/legs/${id}`, { method: 'DELETE' }),
};
