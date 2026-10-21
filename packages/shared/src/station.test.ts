import { describe, expect, it } from 'vitest';
import { connectionStatus, instructions, nearestNode, resolveEndpoint, routeBetween, routeTracks, toLocal, validateStationMap, type StationMap } from './station';

// A tiny two-platform station: a tunnel below with stairs and a slower lift up to each platform.
const map = (): StationMap => ({
  station_id: 't',
  name: 'Test C',
  updated: '2026-10-21',
  quality: 'hand_curated',
  sources: [],
  changelog: [],
  coord_system: 'local_m',
  origin: { lat: 59, lon: 18 },
  levels: [
    { id: 'L0', name: 'Platforms', order: 0 },
    { id: 'L-1', name: 'Tunnel', order: -1 },
  ],
  shapes: [],
  platforms: [
    { id: 'p1', ref: '1', tracks: ['1'], level: 'L0', geometry: [[[0, 0], [4, 0], [4, 100], [0, 100], [0, 0]]], node: 'p1' },
    { id: 'p2', ref: '2', tracks: ['2'], level: 'L0', geometry: [[[30, 0], [34, 0], [34, 100], [30, 100], [30, 0]]], node: 'p2' },
  ],
  nodes: [
    { id: 'p1', type: 'platform', level: 'L0', x: 2, y: 50 },
    { id: 'p2', type: 'platform', level: 'L0', x: 32, y: 50 },
    { id: 'a', type: 'junction', level: 'L-1', x: 2, y: 50 },
    { id: 'b', type: 'junction', level: 'L-1', x: 32, y: 50 },
  ],
  edges: [
    { from: 'p1', to: 'a', seconds: 20, step_free: false, kind: 'stairs' },
    { from: 'p1', to: 'a', seconds: 45, step_free: true, kind: 'lift' },
    { from: 'a', to: 'b', seconds: 25, step_free: true, kind: 'walk' },
    { from: 'b', to: 'p2', seconds: 20, step_free: false, kind: 'stairs' },
    { from: 'b', to: 'p2', seconds: 45, step_free: true, kind: 'lift' },
  ],
  pois: [],
});

describe('station map validation', () => {
  it('accepts a connected map and catches unreachable platforms and missing seconds', () => {
    expect(validateStationMap(map())).toEqual([]);
    const m = map();
    m.edges = m.edges.filter((e) => e.to !== 'p2');
    expect(validateStationMap(m)).toContain('platform 2: unreachable');
    const m2 = map();
    m2.edges[2]!.seconds = 0;
    expect(validateStationMap(m2)[0]).toMatch(/no seconds/);
  });
});

describe('walking routes', () => {
  it('takes the stairs by default, the lift when step-free, and slows down with luggage', () => {
    const r = routeTracks(map(), '1', '2b')!;
    expect(r.steps.map((s) => s.kind)).toEqual(['stairs', 'walk', 'stairs']);
    expect(r.seconds).toBe(65);
    const sf = routeTracks(map(), '1', '2', { pace: 'normal', stepFree: true, luggage: false })!;
    expect(sf.steps.map((s) => s.kind)).toEqual(['lift', 'walk', 'lift']);
    expect(routeTracks(map(), '1', '2', { pace: 'relaxed', stepFree: false, luggage: true })!.seconds).toBeGreaterThan(r.seconds);
  });

  it('finds no step-free route when there is no lift', () => {
    const m = map();
    m.edges = m.edges.filter((e) => e.kind !== 'lift');
    expect(routeTracks(m, '1', '2', { pace: 'normal', stepFree: true, luggage: false })).toBeNull();
  });

  it('describes the route from templates', () => {
    const m = map();
    expect(instructions(m, routeTracks(m, '1', '2')!, '1', '2').map((i) => i.key)).toEqual(['leave', 'stairs_down', 'walk', 'stairs_up', 'arrive']);
  });
});

describe('walks between any two points', () => {
  const withPoi = () => {
    const m = map();
    m.pois.push({ id: 'wc', category: 'toilet', name: '', level: 'L-1', x: 30, y: 52, node: 'b', hours_source: null, hours_verified: null });
    return m;
  };
  it('reads tracks, amenities, nodes and "me" from their URL form', () => {
    const m = withPoi();
    expect(resolveEndpoint(m, '2b')).toMatchObject({ kind: 'track', track: '2b', node: { id: 'p2' } });
    expect(resolveEndpoint(m, 'p:wc')).toMatchObject({ kind: 'poi', node: { id: 'b' } });
    expect(resolveEndpoint(m, 'n:a')).toMatchObject({ kind: 'node' });
    expect(resolveEndpoint(m, 'me:a')).toMatchObject({ kind: 'me' });
    expect(resolveEndpoint(m, 'p:nope')).toBeNull();
    expect(resolveEndpoint(m, '9')).toBeNull();
  });
  it('routes from a track to an amenity and words the ends by kind', () => {
    const m = withPoi();
    const a = resolveEndpoint(m, '1');
    const b = resolveEndpoint(m, 'p:wc');
    const r = routeBetween(m, a, b)!;
    expect(r.steps.map((s) => s.kind)).toEqual(['stairs', 'walk']);
    expect(instructions(m, r, a, b).map((i) => i.key)).toEqual(['leave', 'stairs_down', 'walk', 'reach']);
    expect(instructions(m, routeBetween(m, b, a)!, b, a).map((i) => i.key)).toEqual(['start', 'walk', 'stairs_up', 'arrive']);
  });
  it('snaps a position to the nearest node on its level', () => {
    const m = map();
    const [x, y] = toLocal(m, 59 - 50 / 110_574, 18 + 31 / (111_320 * Math.cos((59 * Math.PI) / 180)));
    expect(x).toBeCloseTo(31, 3);
    expect(y).toBeCloseTo(50, 3);
    expect(nearestNode(m, 'L0', x, y)!.id).toBe('p2');
    expect(nearestNode(m, 'L-1', x, y)!.id).toBe('b');
    expect(nearestNode(m, 'L0', 500, 500, 100)).toBeNull();
  });
});

describe('connection status (Layover Guide)', () => {
  const t = (min: number) => Date.parse('2026-10-21T12:00:00Z') + min * 60_000;
  const base = { arrival: t(0), departure: t(20), arrivalPlatform: '1', departurePlatform: '2', walkSeconds: 120 };
  it('easy, tight and likely to miss', () => {
    expect(connectionStatus(base).status).toBe('easy');
    expect(connectionStatus({ ...base, departure: t(6) }).status).toBe('tight');
    expect(connectionStatus({ ...base, departure: t(3) }).status).toBe('miss');
    expect(connectionStatus(base).slackSeconds).toBe(20 * 60 - 120 - 90);
  });
  it('unknown without a platform, broken when a train is cancelled', () => {
    expect(connectionStatus({ ...base, departurePlatform: null }).status).toBe('unknown');
    expect(connectionStatus({ ...base, canceledB: true }).status).toBe('broken');
  });
  it('never green on an estimate (no station map) or on timetable-only times: just the margin', () => {
    const est = { ...base, walkSeconds: null, sizeClass: 'large' as const };
    expect(connectionStatus(est)).toMatchObject({ status: 'margin', estimated: true, walkSeconds: 420 });
    expect(connectionStatus({ ...est, departure: t(40) }).status).toBe('margin');
    expect(connectionStatus({ ...est, departure: t(12) }).status).toBe('tight');
    expect(connectionStatus({ ...est, departure: t(5) }).status).toBe('miss');
    expect(connectionStatus({ ...base, timesLive: false }).status).toBe('margin');
    expect(connectionStatus({ ...base, departure: t(6), timesLive: false }).status).toBe('tight');
  });
});
