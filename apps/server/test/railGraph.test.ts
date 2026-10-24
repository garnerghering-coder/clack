import { describe, expect, it } from 'vitest';
import { encodePolyline, type LatLon } from '@clack/shared';
import { FLAG_SERVICE, RailGraph, railGraph, type RailGraphFile } from '../src/geo/railGraph.js';
import { haversineM } from '../src/lib/geo.js';

// A toy network on the 57th parallel (0.1° lon ≈ 6 km):
//   main line  0 ──── 1 ──── 2   (lat 57.000)
//   freight    0 ── 3 ── 2       (lat 57.010, a bit longer)
//   siding     1 ─── 2           (service track, straight but penalised)
const nodes: LatLon[] = [
  [57, 14.0],
  [57, 14.1],
  [57, 14.2],
  [57.01, 14.1],
];
const line = (...pts: LatLon[]) => encodePolyline(pts);
const file: RailGraphFile = {
  version: 1,
  generated: 'test',
  attribution: '© OpenStreetMap contributors',
  nodes: nodes.flat(),
  edges: [
    [0, 1, 0, line(nodes[0]!, [57, 14.05], nodes[1]!)],
    [1, 2, 0, line(nodes[1]!, [57.002, 14.15], nodes[2]!)],
    [0, 3, 0, line(nodes[0]!, nodes[3]!)],
    [3, 2, 0, line(nodes[3]!, nodes[2]!)],
    [1, 2, FLAG_SERVICE, line(nodes[1]!, nodes[2]!)],
  ],
};
const g = new RailGraph(file);

describe('rail graph routing', () => {
  it('snaps a station onto the middle of an edge, not just to its ends', () => {
    const c = g.snap(57.0005, 14.05);
    expect(c[0]!.d).toBeLessThan(60);
    expect(c[0]!.point[1]).toBeCloseTo(14.05, 3);
  });

  it('follows the track between stations and measures it', () => {
    const r = g.route([57, 14.02], [57, 14.18])!;
    expect(r).not.toBeNull();
    // Main line with its kink (via 57.002) beats the straight but penalised siding.
    expect(r.points.some(([la]) => la > 57.0015 && la < 57.0025)).toBe(true);
    const straight = haversineM(57, 14.02, 57, 14.18);
    expect(r.lengthM).toBeGreaterThan(straight);
    expect(r.lengthM).toBeLessThan(straight * 1.05);
  });

  it('rides along a single edge when both stations are on it, in either direction', () => {
    const ab = g.route([57, 14.01], [57, 14.04])!;
    const ba = g.route([57, 14.04], [57, 14.01])!;
    expect(ab.lengthM).toBeCloseTo(haversineM(57, 14.01, 57, 14.04), -1);
    expect(ba.points[0]).toEqual([57, 14.04]);
  });

  it('gives up on stations far from any track', () => {
    expect(g.route([58, 14], [57, 14.2])).toBeNull();
  });
});

describe('the committed OSM rail graph', () => {
  const real = railGraph();
  it('routes Stockholm C → Göteborg C along the Western Main Line (~455 km)', () => {
    expect(real).not.toBeNull();
    const r = real!.route([59.3301, 18.0582], [57.7089, 11.9733])!;
    expect(r.lengthM / 1000).toBeGreaterThan(440);
    expect(r.lengthM / 1000).toBeLessThan(470);
  });
  // Routed lengths recorded from the graph before Finland was added (Sweden/Denmark/Norway only); adding Finland
  // appends edges and must not change them.
  it('still routes Swedish and Norwegian legs exactly as before Finland was added', () => {
    const se = real!.route([59.3303, 18.0583], [57.7089, 11.973])!;
    expect(se.lengthM / 1000).toBeCloseTo(453.068, 2);
    const no = real!.route([59.911, 10.7527], [60.3905, 5.3335])!;
    expect(no.lengthM / 1000).toBeCloseTo(459.302, 2);
  });
  // Finnish station coordinates from Digitraffic /metadata/stations. The ranges are plausibility checks (the
  // track is longer than the straight line, shorter than a detour), not sourced distances.
  it('routes Finnish legs along the track: Helsinki → Tampere, Oulu, Turku, Leppävaara', () => {
    const hki: [number, number] = [60.1719, 24.9414];
    const tpe = real!.route(hki, [61.498236, 23.773454])!;
    expect(tpe.lengthM / 1000).toBeGreaterThan(170);
    expect(tpe.lengthM / 1000).toBeLessThan(205);
    const oulu = real!.route(hki, [65.012409, 25.486121])!;
    expect(oulu.lengthM / 1000).toBeGreaterThan(640);
    expect(oulu.lengthM / 1000).toBeLessThan(720);
    const tku = real!.route(hki, [60.456488, 22.260867])!;
    expect(tku.lengthM / 1000).toBeGreaterThan(165);
    expect(tku.lengthM / 1000).toBeLessThan(215);
    const lpv = real!.route(hki, [60.21948, 24.813541])!;
    expect(lpv.lengthM / 1000).toBeGreaterThan(9);
    expect(lpv.lengthM / 1000).toBeLessThan(14);
  });
  it('joins the Finnish and Swedish networks at Tornio–Haparanda', () => {
    const tornio: [number, number] = [65.84534, 24.163576];
    const haparanda: [number, number] = [65.828367, 24.131894];
    const r = real!.route(tornio, haparanda)!;
    expect(r.lengthM / 1000).toBeGreaterThan(2.4);
    expect(r.lengthM / 1000).toBeLessThan(5);
    // Oulu → Luleå crosses the border on track (no jump over the river).
    const oulu = real!.route([65.012409, 25.486121], [65.5843, 22.1555])!;
    expect(oulu.lengthM / 1000).toBeGreaterThan(280);
    expect(oulu.lengthM / 1000).toBeLessThan(380);
  });
  it('routes across the border: Kolding → Odense (Denmark)', () => {
    const r = real!.route([55.4904, 9.4834], [55.4017, 10.3866])!;
    expect(r.lengthM / 1000).toBeGreaterThan(65);
    expect(r.lengthM / 1000).toBeLessThan(85);
  });
});

describe('Finland has no light rail', () => {
  it('has no light_rail edge east of 20.5°E (the Helsinki metro and the Tampere tram are not trains)', async () => {
    const { gunzipSync } = await import('node:zlib');
    const { readFileSync } = await import('node:fs');
    const g = JSON.parse(gunzipSync(readFileSync(new URL('../../../data/osm/rail-graph.json.gz', import.meta.url))).toString('utf8'));
    const lonOf = (n: number) => g.nodes[2 * n + 1] as number;
    const lightEast = g.edges.filter((e: number[]) => ((e[2]! >> 1) & 3) === 1 && lonOf(e[0]!) >= 20.5 && lonOf(e[1]!) >= 20.5);
    expect(lightEast.length).toBe(0);
  });
});
