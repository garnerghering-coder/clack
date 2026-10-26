import { describe, expect, it } from 'vitest';
import { tripProgress, type PassportLeg } from '../src/stats/passport.js';

const stop = (stationId: string, role: string, country = 'SE') => ({ stationId, name: stationId, role, country, lat: 0, lon: 0 });
const leg = (id: string, from: string, to: string, km: number, operatorId: string, dep: number, country = 'SE'): PassportLeg =>
  ({ id, journeyId: null, dep, arr: dep + 3600_000, schedDep: dep, distanceM: km * 1000, operatorId, product: 'regional', category: 'regional', trainType: null, trainNumber: '1', dataQuality: 'full', arrDelayMin: 0, canceled: false, geometry: null, stops: [stop(from, 'board'), stop(to, 'alight', country)] }) as unknown as PassportLeg;

describe('what a trip did for your Passport', () => {
  const others = [leg('a', 'Cst', 'U', 70, 'sj', 1), leg('b', 'U', 'Gä', 90, 'sj', 2)];
  it('names its firsts and the milestones it unlocked', () => {
    const p = tripProgress([...others, leg('c', 'Gä', 'Oslo', 300, 'vy', 3, 'NO')], 'c');
    expect(p.counted).toBe(true);
    if (!p.counted) return;
    expect(p.firsts).toEqual({ stations: ['Oslo'], operator: 'vy', countries: ['NO'] });
    expect(p.unlocked.map((m) => `${m.family}:${m.target}`).sort()).toEqual(['borderCrossings:1', 'countries:2', 'longestTrainKm:300']);
  });
  it('a back-catalogue trip counts the same, whatever its date', () => {
    const p = tripProgress([...others, leg('old', 'Cst', 'M', 600, 'sj', 0)], 'old');
    if (!p.counted) throw new Error('should count');
    expect(p.moved.find((m) => m.family === 'distanceKm')).toMatchObject({ before: 160, after: 760, target: 1000 });
  });
  it("says so when the trip doesn't count", () => {
    expect(tripProgress(others, 'nope')).toEqual({ counted: false });
  });
});
