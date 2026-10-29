import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { forgetPunctuality, punctuality, summarise } from '../src/stats/punctuality.js';

/** A run of train 421 with one call at Alvesta on a day, `delayMin` late (null: not yet reported), or cancelled. */
function run(db: ReturnType<typeof openDb>, date: string, delayMin: number | null, opts: { canceled?: boolean; country?: string } = {}) {
  const c = db.$client;
  const sched = Date.parse(`${date}T10:00:00Z`);
  c.prepare(
    `insert into observed_runs (country, service_date, run_id, train_number, source, canceled, fetched_at, final) values (?, ?, ?, ?, 'test', ?, ?, 1)`,
  ).run(opts.country ?? 'SE', date, `r${date}`, '421', opts.canceled ? 1 : 0, sched);
  c.prepare(
    `insert into observed_calls (country, service_date, run_id, seq, location, station_id, sched_arr, actual_arr, sched_dep, actual_dep) values (?, ?, ?, 3, 'Av', '740000004', ?, ?, ?, ?)`,
  ).run(opts.country ?? 'SE', date, `r${date}`, sched, delayMin === null ? null : sched + delayMin * 60_000, sched + 120_000, delayMin === null ? null : sched + 120_000 + delayMin * 60_000);
}

describe('punctuality from the observed record', () => {
  it('counts late days, cancellations and the quantiles over the window, first call per day', () => {
    forgetPunctuality();
    const db = openDb(':memory:');
    // 10 days: delays 0,0,2,6,8,10,15,20,25 and one cancellation; one day not yet reported (left out).
    const delays = [0, 0, 2, 6, 8, 10, 15, 20, 25];
    delays.forEach((d, i) => run(db, `2026-10-${String(1 + i).padStart(2, '0')}`, d));
    run(db, '2026-10-10', null, { canceled: true });
    run(db, '2026-10-11', null);
    const p = punctuality(db, { trainNumber: '421', stationId: '740000004', before: '2026-10-29', days: 28 })!;
    expect(p.days).toBe(10);
    expect(p.lateDays).toBe(7); // 6,8,10,15,20,25 and the cancellation
    expect(p.onTimeDays).toBe(3);
    expect(p.canceledDays).toBe(1);
    expect([p.lowMin, p.medianMin, p.highMin, p.p80Min]).toEqual([2, 8, 15, 20]);
    expect([p.from, p.to]).toEqual(['2026-10-01', '2026-10-28']);
    // Outside the window, or another station: nothing.
    expect(punctuality(db, { trainNumber: '421', stationId: '740000004', before: '2026-10-01' })).toBeNull();
    expect(punctuality(db, { trainNumber: '421', stationId: '740000001', before: '2026-10-29' })).toBeNull();
  });

  it('uses departures when asked, and for a first stop with no arrival', () => {
    const dep = summarise(
      [
        { d: '2026-10-01', sa: null, aa: null, sd: 0, ad: 7 * 60_000, ca: 0, cd: 0, rc: 0 },
        { d: '2026-10-02', sa: 0, aa: 60_000, sd: 120_000, ad: 120_000 + 9 * 60_000, ca: 0, cd: 0, rc: 0 },
      ],
      'dep', '2026-10-01', '2026-10-28',
    )!;
    expect([dep.days, dep.lateDays, dep.medianMin]).toEqual([2, 2, 7]);
    const arr = summarise([{ d: '2026-10-01', sa: null, aa: null, sd: 0, ad: 7 * 60_000, ca: 0, cd: 0, rc: 0 }], 'arr', '2026-10-01', '2026-10-28')!;
    expect(arr.medianMin).toBe(7);
    // Early never counts as negative.
    expect(summarise([{ d: 'x', sa: 600_000, aa: 0, sd: null, ad: null, ca: 0, cd: 0, rc: 0 }], 'arr', 'a', 'b')!.medianMin).toBe(0);
  });
});
