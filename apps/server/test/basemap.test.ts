import { describe, expect, it } from 'vitest';
import { deserializeDirectory, serializeDirectory, wantedTileIds, NORDIC_BBOX } from '../src/import/basemap.js';
import { slimTile } from '../src/import/mvtFilter.js';

// Minimal protobuf writer for building test tiles.
const varint = (v: number) => {
  const out: number[] = [];
  while (v >= 0x80) {
    out.push((v & 0x7f) | 0x80);
    v >>>= 7;
  }
  out.push(v);
  return out;
};
const field = (num: number, payload: number[]) => [...varint(num * 8 + 2), ...varint(payload.length), ...payload];
const str = (num: number, s: string) => field(num, [...Buffer.from(s)]);
const feature = (tags: number[]) => field(2, [...field(2, tags.flatMap(varint)), ...varint(3 * 8), 2, ...field(4, [9, 0, 0])]);
const layer = (name: string, keys: string[], values: string[], features: number[][]) =>
  field(3, [...varint(15 * 8), 2, ...str(1, name), ...features.flat(), ...keys.flatMap((k) => str(3, k)), ...values.flatMap((v) => field(4, str(1, v))), ...varint(5 * 8), ...varint(4096)]);

const text = (tile: Uint8Array) => Buffer.from(tile).toString('latin1');

describe('slimming vector tiles', () => {
  const tile = Uint8Array.from([
    ...layer('earth', ['kind'], ['earth'], [feature([0, 0])]),
    ...layer('buildings', ['kind'], ['building'], [feature([0, 0])]),
    ...layer('roads', ['kind', 'ref'], ['minor_road', 'highway', 'E4'], [feature([0, 0]), feature([0, 1, 1, 2]), feature([0, 0])]),
    ...layer('pois', ['kind'], ['cafe'], [feature([0, 0])]),
  ]);

  it('keeps land, drops buildings and POIs, and keeps only motorways from roads', () => {
    const slim = slimTile(tile);
    expect(text(slim)).toContain('earth');
    expect(text(slim)).toContain('roads');
    expect(text(slim)).not.toContain('buildings');
    expect(text(slim)).not.toContain('cafe');
    // Of three road features only the kind=highway one is left; keys/values stay so its tags still resolve.
    const kept = slimTile(Uint8Array.from(layer('roads', ['kind', 'ref'], ['minor_road', 'highway', 'E4'], [feature([0, 0]), feature([0, 1, 1, 2]), feature([0, 0])])));
    const oneFeature = Uint8Array.from(layer('roads', ['kind', 'ref'], ['minor_road', 'highway', 'E4'], [feature([0, 1, 1, 2])]));
    expect(Buffer.from(kept).equals(Buffer.from(oneFeature))).toBe(true);
  });

  it('drops a filtered layer that ends up empty', () => {
    const onlyMinor = Uint8Array.from(layer('roads', ['kind'], ['minor_road'], [feature([0, 0])]));
    expect(slimTile(onlyMinor).length).toBe(0);
  });
});

describe('PMTiles directories', () => {
  it('round-trip, including contiguous offsets and runs', () => {
    const entries = [
      { tileId: 0, offset: 0, length: 100, runLength: 1 },
      { tileId: 1, offset: 100, length: 50, runLength: 1 },
      { tileId: 5, offset: 0, length: 100, runLength: 3 },
      { tileId: 1000, offset: 4096, length: 10, runLength: 0 },
    ];
    expect(deserializeDirectory(serializeDirectory(entries))).toEqual(entries);
  });

  it('wants the whole world at low zoom and only the Nordics above it', () => {
    const z4 = wantedTileIds(NORDIC_BBOX, 4);
    expect(z4.length).toBe(1 + 4 + 16 + 64 + 256);
    const z6 = wantedTileIds(NORDIC_BBOX, 6);
    expect(z6.length - z4.length).toBeLessThan(400);
    expect([...z6].every((v, i, a) => i === 0 || a[i - 1]! < v)).toBe(true);
  });
});
