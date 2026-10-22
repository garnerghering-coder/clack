import { describe, expect, it } from 'vitest';
import { parseListing, riksId } from '../src/import/history.js';

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
});
