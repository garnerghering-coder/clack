import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it, vi } from 'vitest';
import { openDb } from '../src/db/client.js';
import { localMs, parseCsv, project, stationOfStop } from '../src/observed/dk-archive.js';

// Rows as in train-archive.eu's dk-rejseplanen file for 2026-10-26 (shortened).
const CSV = `"service_date","provider","feed_id","route","trip_id","trip_start_time","stop_sequence","stop_id","stop_name","scheduled_arrival","scheduled_departure","arrival_delay_min","departure_delay_min","predicted_arrival","predicted_departure","observed_at","trip_status","stop_status","delay_source","route_id","timetable_version"
"2026-10-26","dk-rejseplanen","a","802 ","168912360",,18,"000008600857","Tårnby St.","2026-10-26 21:07:00","2026-10-26 21:08:00",22,24,"2026-10-26 21:29:00","2026-10-26 21:32:00","2026-10-26 21:33:38","scheduled",,"feed","25657_2","v1"
"2026-10-26","dk-rejseplanen","a","802 ","168912360",,17,"000008600858","CPH, Lufthavn","2026-10-26 20:58:00","2026-10-26 21:05:00",23,20,"2026-10-26 21:21:00","2026-10-26 21:25:00","2026-10-26 21:27:37","scheduled",,"feed","25657_2","v1"
"2026-10-26","dk-rejseplanen","a","802 ","168912360",,19,"000008600856","Ørestad St.","2026-10-26 21:10:00","2026-10-26 21:11:00",,,,,"2026-10-26 21:42:38","scheduled","skipped","propagated","25657_2","v1"
"2026-10-26","dk-rejseplanen","b","B ","169","",1,"000008600688","Emdrup St.","","2026-10-26 08:11:00",,,,,"2026-10-26 10:37:37","cancelled",,"","16449_109","v1"
`;

describe('train-archive.eu Danish day', () => {
  const rows = parseCsv(CSV);
  it('parses quoted fields and commas inside them', () => {
    expect(rows).toHaveLength(4);
    expect(rows[1]!.stop_name).toBe('CPH, Lufthavn');
  });
  it('reads Danish local time (CET after 25 Oct, UTC+1)', () => {
    expect(localMs('2026-10-26 21:07:00')).toBe(Date.UTC(2026, 9, 26, 20, 7));
    expect(localMs('')).toBeNull();
  });
  it('maps stops to our station ids', () => {
    expect(stationOfStop('000008600857', new Set(['860000857']))).toBe('860000857');
    expect(stationOfStop('000008600857', new Set())).toBeNull();
  });
  it('projects runs: actuals only from the feed, skipped and cancelled stops marked', () => {
    const runs = project('2026-10-26', rows, new Map([['168912360', { number: '802', operator: 'DSB S-tog' }]]), new Set(['860000857']), true);
    expect(runs).toHaveLength(2);
    const r = runs.find((x) => x.runId === '168912360')!;
    expect(r.trainNumber).toBe('802');
    expect(r.calls.map((c) => c.seq)).toEqual([1, 2, 3]);
    expect(r.calls[0]!.location).toBe('000008600858');
    expect(r.calls[1]!.stationId).toBe('860000857');
    expect(r.calls[1]!.actualDep! - r.calls[1]!.schedDep!).toBe(24 * 60_000);
    expect(r.calls[2]!.actualArr).toBeNull();
    expect(r.calls[2]!.canceledArr).toBe(true);
    expect(r.canceled).toBe(1);
    const c = runs.find((x) => x.runId === '169')!;
    expect(c.canceled).toBe(2);
    expect(c.trainNumber).toBeNull();
  });
});

describe('train-archive.eu catch-up', () => {
  it('fetches each missing day once, skips finished ones, and survives a missing day', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'clack-dk-'));
    vi.stubEnv('OBSERVED_DIR', root);
    vi.stubEnv('TRAIN_ARCHIVE_TOKEN', 'test');
    vi.resetModules();
    const dk = await import('../src/observed/dk-archive.js');
    const db = openDb(':memory:');
    const asked: string[] = [];
    const fetchImpl = (async (url: string) => {
      const date = /date=([\d-]+)/.exec(url)![1]!;
      asked.push(date);
      if (date === '2026-10-25') return new Response('', { status: 404 });
      return new Response(CSV.replaceAll('2026-10-26', date));
    }) as typeof fetch;
    try {
      await dk.backfillRange(db, { from: '2026-10-24', to: '2026-10-26', fetchImpl, log: () => {} });
      expect(asked).toEqual(['2026-10-24', '2026-10-25', '2026-10-26']);
      const runs = db.$client.prepare(`select service_date, count(*) n from observed_runs where country = 'DK' group by 1 order by 1`).all();
      expect(runs).toEqual([
        { service_date: '2026-10-24', n: 2 },
        { service_date: '2026-10-26', n: 2 },
      ]);
      asked.length = 0;
      await dk.backfillRange(db, { from: '2026-10-24', to: '2026-10-26', fetchImpl, log: () => {} });
      expect(asked).toEqual(['2026-10-25']);
    } finally {
      vi.unstubAllEnvs();
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
});
