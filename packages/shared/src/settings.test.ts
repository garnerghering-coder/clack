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
    expect(() => mergeSettings(DEFAULT_SETTINGS, { fontSize: 'large' })).toThrow('unknown setting');
    expect(() => mergeSettings(DEFAULT_SETTINGS, { theme: 'sepia' })).toThrow();
    expect(mergeSettings(DEFAULT_SETTINGS, { theme: 'light' }).theme).toBe('light');
    expect(() => mergeSettings(DEFAULT_SETTINGS, { clock: '25h' })).toThrow('invalid clock');
    expect(() => mergeSettings(DEFAULT_SETTINGS, { showRailNetwork: 'yes' })).toThrow('boolean');
    expect(() => mergeSettings(DEFAULT_SETTINGS, null)).toThrow('object');
  });
  it('takes the alert settings and rejects a lead time that is not offered', () => {
    expect(DEFAULT_SETTINGS.notify).toBe(false);
    expect(DEFAULT_SETTINGS.notifyLeadMin).toBe(60);
    const next = mergeSettings(DEFAULT_SETTINGS, { notify: true, notifyLeadMin: 120, notifyDelay: false });
    expect([next.notify, next.notifyLeadMin, next.notifyDelay]).toEqual([true, 120, false]);
    expect(() => mergeSettings(DEFAULT_SETTINGS, { notifyLeadMin: 45 })).toThrow('invalid notifyLeadMin');
    expect(() => mergeSettings(DEFAULT_SETTINGS, { notifyArrival: 'yes' })).toThrow('true or false');
  });
  it('does not mutate the input', () => {
    const before = { ...DEFAULT_SETTINGS };
    mergeSettings(DEFAULT_SETTINGS, { clock: '12h' });
    expect(DEFAULT_SETTINGS).toEqual(before);
  });
});
