import { describe, expect, it } from 'vitest';
import { busesByDay } from '../src/import/busCheck.js';

describe('replacement buses from Trafikverket', () => {
  it('groups bus calls by number and local day', () => {
    const m = busesByDay([
      { AdvertisedTrainIdent: '60621', LocationSignature: 'Khn', AdvertisedTimeAtLocation: '2026-10-22T08:25:00.000+02:00' },
      { AdvertisedTrainIdent: '60621', LocationSignature: 'Ks', AdvertisedTimeAtLocation: '2026-10-22T09:05:00.000+02:00' },
      // 00:30 local is still the 23rd in Sweden, though it's the 22nd in UTC.
      { AdvertisedTrainIdent: '60621', LocationSignature: 'Khn', AdvertisedTimeAtLocation: '2026-10-22T22:30:00.000Z' },
    ]);
    expect([...m.get('60621|2026-10-22')!]).toEqual(['khn', 'ks']);
    expect(m.has('60621|2026-10-23')).toBe(true);
  });
});
