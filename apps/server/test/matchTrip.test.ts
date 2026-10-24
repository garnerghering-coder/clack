import { describe, expect, it } from 'vitest';
import { matchTrip } from '../src/livemap/match.js';

// 2026-10-22: SJ 441 Stockholm C → Göteborg C and SJ Nord's 441 Melhus → Steinkjer run the same day under the same
// number and brand; the map once showed one's header with the other's stops.
const sj441 = {
  key: 'se3:441',
  stops: [
    { name: 'Stockholm C', country: 'SE', lat: 59.33, lon: 18.06 },
    { name: 'Katrineholm C', country: 'SE', lat: 58.996, lon: 16.205 },
    { name: 'Göteborg C', country: 'SE', lat: 57.709, lon: 11.973 },
  ],
};
const sjn441 = {
  key: 'no:441',
  stops: [
    { name: 'Melhus skysstasjon', country: 'NO', lat: 63.285, lon: 10.278 },
    { name: 'Trondheim S', country: 'NO', lat: 63.436, lon: 10.399 },
    { name: 'Steinkjer', country: 'NO', lat: 64.014, lon: 11.495 },
  ],
};

describe('which trip a train on the map is', () => {
  it('picks the trip that runs where the train is, whatever order they come in', () => {
    const nearSodertalje = { id: '441|2026-10-22', lat: 59.15, lon: 17.8, origin: 'Stockholm C', destination: 'Göteborg C' };
    expect(matchTrip(nearSodertalje, [sjn441, sj441])?.key).toBe('se3:441');
    const nearTrondheim = { id: 'no:441|2026-10-22', lat: 63.4, lon: 10.35, origin: null, destination: null };
    expect(matchTrip(nearTrondheim, [sj441, sjn441])?.key).toBe('no:441');
  });

  it('knows a Finnish train by its id, and prefers the trip with stops in Finland', () => {
    // Finnish train 441 (a made-up number that collides with SJ's) near Oulu.
    const fi441 = {
      key: 'fi:441_20261024:abc',
      stops: [
        { name: 'Oulu', country: 'FI', lat: 64.93, lon: 25.48 },
        { name: 'Kemi', country: 'FI', lat: 65.74, lon: 24.55 },
      ],
    };
    const near = { id: 'fi:441|2026-10-24', lat: 65.3, lon: 25.0, origin: null, destination: null };
    expect(matchTrip(near, [sj441, sjn441, fi441])?.key).toBe('fi:441_20261024:abc');
    // Finland's train near Stockholm would be wrong, though it is the only one that runs in Finland.
    expect(matchTrip({ ...near, lat: 59.15, lon: 17.8 }, [sj441, fi441])?.key).toBe('se3:441');
  });

  it('gives no trip rather than a wrong one', () => {
    expect(matchTrip({ id: '441|2026-10-22', lat: 55.6, lon: 13.0, origin: null, destination: null }, [sj441, sjn441])).toBeUndefined();
  });
});
