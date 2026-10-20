import { describe, expect, it } from 'vitest';
import { decodePolyline, encodePolyline } from './polyline';

describe('polyline', () => {
  it('matches the reference encoding', () => {
    // Example from Google's polyline documentation.
    expect(encodePolyline([[38.5, -120.2], [40.7, -120.95], [43.252, -126.453]])).toBe('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
  });
  it('round-trips at ~1 m precision', () => {
    const pts: [number, number][] = [[57.78, 14.16], [57.7826, 14.1618], [59.33, 18.06]];
    expect(decodePolyline(encodePolyline(pts))).toEqual(pts);
  });
});
