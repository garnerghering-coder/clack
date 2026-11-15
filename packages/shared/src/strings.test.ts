import { describe, expect, it } from 'vitest';
import { CO2_COMPARISONS, LANGUAGES } from './index';
import { appLanguage, appString } from './strings';

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
  it('reads English for every language the catalog does not have a text in yet', () => {
    for (const l of LANGUAGES) {
      const text = appString('trips.title', l);
      expect(text, l).toBeTruthy();
      if (l !== 'en' && l !== 'sv') expect(typeof text).toBe('string');
    }
    // A code the catalog has never heard of still reads English, never throws.
    expect(appString('trips.title', 'xx' as never)).toBe(appString('trips.title', 'en'));
    expect(appString('no.such.key', 'pl')).toBeNull();
  });
  it('maps a language tag to one of the app languages, Norwegian "no" as "nb"', () => {
    expect(appLanguage('da-DK', LANGUAGES)).toBe('da');
    expect(appLanguage('no', LANGUAGES)).toBe('nb');
    expect(appLanguage('nb-NO', LANGUAGES)).toBe('nb');
    expect(appLanguage('fr-CA;q=0.8', LANGUAGES)).toBe('fr');
    expect(appLanguage('es', LANGUAGES)).toBeNull();
    expect(appLanguage(undefined, LANGUAGES)).toBeNull();
  });
});
