import { describe, expect, it } from 'vitest';
import { CO2_COMPARISONS, LANGUAGES } from './index';
import { appString } from './strings';

// The rest of the catalog's checks (every key in both languages, same placeholders) are in the app's tests
// (ClackCoreTests/L10nTests.swift).
describe('the app strings the server reads', () => {
  it('has a label for every shared option', () => {
    for (const c of CO2_COMPARISONS) expect(appString(`settings.co2.${c}`), c).toBeTruthy();
    for (const l of LANGUAGES) expect(appString(`settings.languages.${l}`), l).toBeTruthy();
  });
  it('falls back to English and gives null for a missing key', () => {
    expect(appString('trips.title', 'sv')).not.toBe(appString('trips.title', 'en'));
    expect(appString('no.such.key')).toBeNull();
  });
});
