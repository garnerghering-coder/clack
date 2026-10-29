import { describe, expect, it } from 'vitest';
import { cacheKey, parseBbox, platformFeatures } from '../src/geo/stationDetail.js';
import type { StationMap } from '@clack/shared';

describe('station detail', () => {
  it('reads a bbox and refuses one too wide for a station', () => {
    expect(parseBbox('14.15,57.77,14.18,57.79')).toEqual({ w: 14.15, s: 57.77, e: 14.18, n: 57.79 });
    expect(parseBbox('14,57,15,58')).toBeNull();
    expect(parseBbox('x')).toBeNull();
    expect(parseBbox(undefined)).toBeNull();
    // Rounded to about 100 m: neighbouring asks share an answer.
    expect(cacheKey({ w: 14.15049, s: 57.7704, e: 14.1803, n: 57.7901 })).toBe('14.150,57.770,14.180,57.790');
  });

  it('turns a platform polygon from local metres into lon/lat with its number and tracks', () => {
    const m = {
      schema: 2, station_id: 'x', name: 'X', origin: { lat: 57.0, lon: 14.0 }, coord_system: 'local_m', levels: [], shapes: [], nodes: [{ id: 'n1', x: 50, y: -2, level: 'L0' }], edges: [],
      quality: 'osm_draft',
      platforms: [{ id: 'p1', ref: '2a', tracks: ['2'], level: 'L0', node: 'n1', geometry: [[[0, 0], [100, 0], [100, -5], [0, -5]]], _source: 't' }],
    } as unknown as StationMap;
    const [f] = platformFeatures(m, 'x');
    expect(f!.properties.ref).toBe('2a');
    expect(f!.properties.tracks).toEqual(['2']);
    expect(f!.properties.draft).toBe(true);
    expect(f!.properties.node![1]).toBeGreaterThan(57);
    const ring = f!.geometry.coordinates[0]!;
    expect(ring[0]).toEqual([14, 57]);
    // 100 m east is about 0.00164° of longitude at 57°N; y is south in local metres, so −5 m is north of the origin.
    expect(ring[1]![0]).toBeGreaterThan(14.0016);
    expect(ring[1]![0]).toBeLessThan(14.0017);
    expect(ring[2]![1]).toBeGreaterThan(57);
  });
});
