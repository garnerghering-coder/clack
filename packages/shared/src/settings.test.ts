import { describe, expect, it } from 'vitest';
import { DEFAULT_SETTINGS, mergeSettings } from './index';

describe('mergeSettings', () => {
  it('applies valid changes', () => {
    expect(mergeSettings(DEFAULT_SETTINGS, { distanceUnit: 'mi', includeCommuter: false })).toEqual({
      ...DEFAULT_SETTINGS,
      distanceUnit: 'mi',
      includeCommuter: false,
    });
  });
  it('rejects unknown keys and bad values', () => {
    expect(() => mergeSettings(DEFAULT_SETTINGS, { theme: 'light' })).toThrow('unknown setting');
    expect(() => mergeSettings(DEFAULT_SETTINGS, { clock: '25h' })).toThrow('invalid clock');
    expect(() => mergeSettings(DEFAULT_SETTINGS, { showRailNetwork: 'yes' })).toThrow('boolean');
    expect(() => mergeSettings(DEFAULT_SETTINGS, null)).toThrow('object');
  });
  it('does not mutate the input', () => {
    const before = { ...DEFAULT_SETTINGS };
    mergeSettings(DEFAULT_SETTINGS, { clock: '12h' });
    expect(DEFAULT_SETTINGS).toEqual(before);
  });
});
