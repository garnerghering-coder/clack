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
