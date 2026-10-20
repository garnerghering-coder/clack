import { describe, expect, it } from 'vitest';
import { encodePolyline, type LatLon } from '@clack/shared';
import { openDb } from '../src/db/client.js';
import { stations, trackSegments } from '../src/db/schema.js';
import { RailGraph } from '../src/geo/railGraph.js';
import { pathThrough, segmentBetween } from '../src/geo/trackSegments.js';

const pts: LatLon[] = [
  [57, 14.0],
  [57.003, 14.05],
  [57, 14.1],
];
const graph = new RailGraph({ version: 1, generated: 't', attribution: '', nodes: [...pts[0]!, ...pts[2]!], edges: [[0, 1, 0, encodePolyline(pts)]] });

function setup() {
  const db = openDb(':memory:');
  for (const [id, lon] of [['b', 14.0], ['a', 14.05], ['c', 14.1], ['far', 20]] as const)
    db.insert(stations).values({ id, name: id, country: 'SE', lat: id === 'a' ? 57.003 : 57, lon, tz: 'Europe/Stockholm' }).run();
  return db;
}
const st = (id: string, lat: number, lon: number) => ({ id, lat, lon });

describe('track segments', () => {
  it('routes once, caches by sorted pair, and flips for the other direction', () => {
    const db = setup();
    const ab = segmentBetween(db, st('b', 57, 14.0), st('c', 57, 14.1), graph);
    expect(ab.estimated).toBe(false);
    expect(ab.points.some(([la]) => la > 57.002)).toBe(true);
    expect(db.select().from(trackSegments).all()).toHaveLength(1);
    const ba = segmentBetween(db, st('c', 57, 14.1), st('b', 57, 14.0), graph);
    expect(ba.points[0]).toEqual(ab.points.at(-1));
    expect(ba.lengthM).toBeCloseTo(ab.lengthM, 0);
    expect(db.select().from(trackSegments).all()).toHaveLength(1);
  });

  it('falls back to a straight, estimated line when a station is off the network', () => {
    const db = setup();
    const s = segmentBetween(db, st('b', 57, 14.0), st('far', 57, 20), graph);
    expect(s.estimated).toBe(true);
    expect(s.points).toHaveLength(2);
  });

  it('joins consecutive segments into one line for a leg', () => {
    const db = setup();
    const p = pathThrough(db, [st('b', 57, 14.0), st('a', 57.003, 14.05), st('c', 57, 14.1)], graph);
    expect(p.segments).toHaveLength(2);
    expect(p.points[0]).toEqual([57, 14.0]);
    expect(p.points.at(-1)).toEqual([57, 14.1]);
    expect(p.lengthM).toBeCloseTo(p.segments[0]!.lengthM + p.segments[1]!.lengthM, 6);
  });
});
