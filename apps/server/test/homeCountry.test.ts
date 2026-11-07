import { describe, expect, it } from 'vitest';
import { pickHomeCountry } from '../src/search/homeCountry.js';

// Whose "421" it is: the settings, then the first trip, then the phone's region, then Sweden (user test 2026-11-07,
// run 2: a new phone had no home country, so "421" said nothing about SJ 421).
describe('pickHomeCountry', () => {
  it('takes the setting first', () => {
    expect(pickHomeCountry('no', 'SE', 'FI')).toBe('NO');
  });
  it('then the country the first trip starts in', () => {
    expect(pickHomeCountry(null, 'DK', 'SE')).toBe('DK');
  });
  it("then the phone's region, when it is one of the four", () => {
    expect(pickHomeCountry(null, null, 'fi')).toBe('FI');
    expect(pickHomeCountry(undefined, undefined, 'US')).toBe('SE');
  });
  it('else Sweden', () => {
    expect(pickHomeCountry(null, null, null)).toBe('SE');
    expect(pickHomeCountry('XX', 'GB', '')).toBe('SE');
  });
});
