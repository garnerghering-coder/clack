// Which timetable trip a train on the map is (found 2026-10-22: SJ 441 Stockholm–Göteborg and SJ Nord's 441
// Melhus–Steinkjer share a number and the "sj" brand, and the map showed one train's header with the other's stops).
// A number is not an identity: the trip has to run where the train is, in its country, between its ends.
import type { LatLon } from '@clack/shared';
import { distanceToLineM } from '../live/tracker.js';
import { normName } from '../lib/geo.js';
import { countryOfLiveId } from '../lib/countries.js';

export interface TripCandidate {
  key: string;
  stops: { name: string; country: string; lat: number; lon: number }[];
}

export interface MapTrainRef {
  id: string;
  lat: number;
  lon: number;
  origin: string | null;
  destination: string | null;
}

/** A trip this far from where the train is can't be it. */
const NEAR_M = 30_000;

/** The candidate that fits the train, or undefined when none does (no trip beats the wrong one). Pure. */
export function matchTrip<T extends TripCandidate>(train: MapTrainRef, candidates: T[]): T | undefined {
  const country = countryOfLiveId(train.id);
  let best: { c: T; score: number } | undefined;
  for (const c of candidates) {
    if (!c.stops.length) continue;
    const line: LatLon[] = c.stops.map((s) => [s.lat, s.lon]);
    const near = distanceToLineM(train, line) <= NEAR_M;
    if (!near) continue;
    let score = 3;
    if (c.stops.some((s) => s.country === country)) score += 2;
    const names = new Set(c.stops.map((s) => normName(s.name)));
    if (train.origin && names.has(normName(train.origin))) score++;
    if (train.destination && names.has(normName(train.destination))) score++;
    if (!best || score > best.score) best = { c, score };
  }
  return best?.c;
}
