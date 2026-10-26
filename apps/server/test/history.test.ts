import { describe, expect, it } from 'vitest';
import { datesToFill, parseListing, riksId, trustedDates } from '../src/import/history.js';

describe('Sverige 2 archive', () => {
  it('reads both file name styles from a month listing, oldest first', () => {
    const html = '<a href="../">../</a><a href="sweden-20250311.zip">x</a><a href="trafiklab-extra-20250311.zip">x</a><a href="sweden-20250310.zip">x</a>';
    expect(parseListing(html, 'https://a/2025/03/')).toEqual([
      { ymd: '20250310', url: 'https://a/2025/03/sweden-20250310.zip', extraUrl: 'https://a/2025/03/trafiklab-extra-20250310.zip' },
      { ymd: '20250311', url: 'https://a/2025/03/sweden-20250311.zip', extraUrl: 'https://a/2025/03/trafiklab-extra-20250311.zip' },
    ]);
    expect(parseListing('<a href="trafiklab-20140310.zip">', 'd/')[0]!.ymd).toBe('20140310');
  });

  it('turns 2012–2016 rikshållplats ids into today\'s', () => {
    expect(riksId('7400001')).toBe('740000001');
    expect(riksId('740000001')).toBe('740000001');
  });

  it("doesn't count days before an import's snapshot as filled", () => {
    // Searching 5 Oct first took 21 Sep–19 Oct from the 5 Oct snapshot; it only holds 5 Oct on in full.
    const notes = { snapshot: '20261005', dates: ['2026-09-28', '2026-10-04', '2026-10-05', '2026-10-06'] };
    expect(trustedDates(notes)).toEqual(['2026-10-05', '2026-10-06']);
    expect(trustedDates({ dates: ['2026-09-28'] })).toEqual(['2026-09-28']);
  });

  it('fills from the snapshot day on, around the asked-for date', () => {
    const days = datesToFill('2026-09-28', '2026-09-28', '2026-10-19', new Set(['2026-10-05']));
    expect(days[0]).toBe('2026-09-28');
    expect(days.at(-1)).toBe('2026-10-12');
    expect(days).not.toContain('2026-10-05');
    // A snapshot from a few days before: those days are in too, and nothing on or after today's feed.
    expect(datesToFill('2026-10-10', '2026-10-08', '2026-10-19', new Set())).toEqual(
      ['2026-10-08', '2026-10-09', '2026-10-10', '2026-10-11', '2026-10-12', '2026-10-13', '2026-10-14', '2026-10-15', '2026-10-16', '2026-10-17', '2026-10-18'],
    );
  });
});

describe('Sverige 2 archive: storage and fetching', () => {
  it('gives an unchanged train the same key in every snapshot, and a changed one its own', async () => {
    const { historyKey } = await import('../src/import/history.js');
    const t = { number: '421', operator: 'sj', routeType: '102', category: 'long_distance', routeName: 'Stockholm - Malmö', headsign: null, stops: [['740000001', 100, 200, false, false, '11', null]] };
    expect(historyKey(t)).toBe(historyKey({ ...t }));
    expect(historyKey(t)).not.toBe(historyKey({ ...t, stops: [['740000001', 100, 200, true, false, '11', null]] }));
    expect(historyKey(t)).not.toBe(historyKey({ ...t, stops: [['740000001', 100, 200, false, false, '12', null]] }));
    expect(historyKey(t)).toMatch(/^sv2:[0-9a-f]{14}$/);
  });

  it("fills a backfill block from the snapshot's day on", async () => {
    const { datesToFill } = await import('../src/import/history.js');
    const days = datesToFill('2025-01-01', '2025-01-03', '2026-10-19', new Set(['2025-01-10']), { from: '2025-01-01', to: '2025-01-28' });
    expect(days[0]).toBe('2025-01-03');
    expect(days.at(-1)).toBe('2025-01-28');
    expect(days).not.toContain('2025-01-10');
  });

  it('asks for a past month once, the current one again after an hour', async () => {
    const { listSnapshots, resetListingCache } = await import('../src/import/history.js');
    resetListingCache();
    let calls = 0;
    const f = (async () => {
      calls++;
      return new Response('<a href="sweden-20250310.zip">');
    }) as typeof fetch;
    const now = Date.parse('2026-10-26T12:00:00Z');
    await listSnapshots(2025, 3, f, now);
    await listSnapshots(2025, 3, f, now + 86400_000);
    expect(calls).toBe(1);
    await listSnapshots(2026, 10, f, now);
    await listSnapshots(2026, 10, f, now + 10 * 60_000);
    expect(calls).toBe(2);
    await listSnapshots(2026, 10, f, now + 2 * 3600_000);
    expect(calls).toBe(3);
  });

  it("says a day the current feed should have covered can't be filled, instead of loading for ever", async () => {
    const { ensureHistory } = await import('../src/import/history.js');
    const { openDb } = await import('../src/db/client.js');
    const db = openDb(':memory:');
    db.$client.exec(`insert into timetable_trips (key, source, trip_id, route_type, category, tz) values ('se3:x', 'gtfs_se3', 'x', '102', 'regional', 'Europe/Stockholm');
      insert into timetable_trip_dates (trip_key, service_date) values ('se3:x', '2026-10-20');`);
    expect(ensureHistory(db, '2026-10-22').state).toBe('unavailable');
    expect(ensureHistory(db, '2026-10-20').state).toBe('ready');
  });
});
