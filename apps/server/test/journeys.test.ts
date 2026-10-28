import { describe, expect, it } from 'vitest';
import { groupLegs } from '../src/legs/journeys.js';

const T = (d: string, hhmm: string) => Date.parse(`2026-10-${d}T${hhmm}:00+02:00`);
const leg = (id: string, from: string, to: string, d: string, dep: string, arr: string) => ({ id, originStationId: from, destStationId: to, dep: T(d, dep), arr: T(d, arr) });

describe('journey grouping (SPEC §13)', () => {
  it("joins the owner's Kolding → Nässjö → Jönköping day into one journey", () => {
    const g = groupLegs([leg('7256', 'N', 'Jö', '20', '19:20', '19:51'), leg('306', 'Kd', 'N', '20', '13:01', '18:25')]);
    expect(g.map((j) => j.map((l) => l.id))).toEqual([['306', '7256']]);
  });

  it('keeps legs apart when the station differs or the gap is over 4 hours', () => {
    expect(groupLegs([leg('a', 'A', 'B', '20', '08:00', '09:00'), leg('b', 'C', 'D', '20', '09:30', '10:00')])).toHaveLength(2);
    expect(groupLegs([leg('a', 'A', 'B', '20', '08:00', '09:00'), leg('b', 'B', 'C', '20', '13:30', '14:00')])).toHaveLength(2);
    expect(groupLegs([leg('a', 'A', 'B', '20', '21:00', '23:50'), leg('b', 'B', 'C', '21', '07:20', '08:00')])).toHaveLength(2);
  });

  it('carries a journey past midnight', () => {
    // The owner's Jönköping → Nässjö → Malmö C → CPH Airport, 28–29 Sept.
    const g = groupLegs([leg('547', 'N', 'M', '20', '21:57', '23:53'), leg('1165', 'M', 'Kac', '21', '00:35', '01:10'), leg('7261', 'Jö', 'N', '20', '21:06', '21:38')]);
    expect(g.map((j) => j.map((l) => l.id))).toEqual([['7261', '547', '1165']]);
  });

  it('chains three trains and starts a new journey after a long break', () => {
    const g = groupLegs([
      leg('a', 'A', 'B', '20', '08:00', '09:00'),
      leg('b', 'B', 'C', '20', '09:10', '10:00'),
      leg('c', 'C', 'D', '20', '11:00', '12:00'),
      leg('d', 'D', 'A', '20', '17:00', '18:00'),
    ]);
    expect(g.map((j) => j.length)).toEqual([3, 1]);
  });
});

describe('planned journeys stay whole', () => {
  it('keeps legs saved from one planned journey together, even with a wait over four hours', () => {
    const at = (h: number) => Date.UTC(2026, 9, 29, h);
    const a = { id: 'a', originStationId: 'jo', destStationId: 'ns', dep: at(6), arr: at(7), group: 'p1' };
    const b = { id: 'b', originStationId: 'ns', destStationId: 'kd', dep: at(12), arr: at(17), group: 'p1' };
    expect(groupLegs([a, b]).map((g) => g.map((l) => l.id))).toEqual([['a', 'b']]);
    // Without the group, the five-hour wait splits them, as before.
    expect(groupLegs([{ ...a, group: null }, { ...b, group: null }])).toHaveLength(2);
  });
});
