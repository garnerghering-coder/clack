import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { routeTracks, validateStationMap, type StationMap } from '@clack/shared';
import { REPO_ROOT } from '../src/env.js';

// Every committed station map must pass the validator (ADDITIONS_01 C: "the validator fails the build").
const dir = path.join(REPO_ROOT, 'data/stations');
const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.json')) : [];

describe('station maps in data/stations', () => {
  it('exist', () => expect(files.length).toBeGreaterThan(0));
  for (const f of files) {
    it(`${f} is valid`, () => {
      const m = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')) as StationMap;
      expect(validateStationMap(m)).toEqual([]);
    });
  }

  it('Stockholm C: every main-line track reaches every other, and step-free never uses stairs', () => {
    const m = JSON.parse(fs.readFileSync(path.join(dir, '740000001.json'), 'utf8')) as StationMap;
    const tracks = ['1', '2', '3', '4', '5', '6', '7', '8', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19'];
    for (const a of tracks)
      for (const b of tracks) {
        const r = routeTracks(m, a, b);
        expect(r, `${a}→${b}`).not.toBeNull();
        // Inside one station: well under a quarter of an hour.
        expect(r!.seconds, `${a}→${b}`).toBeLessThan(15 * 60);
        const sf = routeTracks(m, a, b, { pace: 'normal', stepFree: true, luggage: false });
        if (sf) expect(sf.steps.some((s) => s.kind === 'stairs' || s.kind === 'escalator'), `${a}→${b}`).toBe(false);
      }
    // Across the tunnel: down, along, up.
    const r = routeTracks(m, '11', '18')!;
    expect(r.levels).toEqual(['L0', 'L-1', 'L0']);
  });
});
