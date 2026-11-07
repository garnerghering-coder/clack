import { describe, expect, it } from 'vitest';
import { streamIntervalMs } from '../src/routes/livemap.js';

// A city or a line gets every update; a country or more gets them gathered every 10 s (user test 2026-11-07, run 2:
// ~600 KB a minute zoomed out).
describe('streamIntervalMs', () => {
  it('sends a narrow view every update', () => {
    expect(streamIntervalMs([17.9, 59.2, 18.3, 59.45])).toBe(2_000);
  });
  it('gathers a wide view', () => {
    expect(streamIntervalMs([4, 54, 32, 71])).toBe(10_000);
    expect(streamIntervalMs([10, 55, 14, 61])).toBe(10_000);
  });
  it('treats no view as the whole map', () => {
    expect(streamIntervalMs(null)).toBe(10_000);
  });
});
