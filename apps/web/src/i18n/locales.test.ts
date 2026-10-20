import { describe, expect, it } from 'vitest';
import { CO2_COMPARISONS, LANGUAGES } from '@clack/shared';
import en from './locales/en.json';

describe('en locale', () => {
  it('has a label for every shared option', () => {
    for (const c of CO2_COMPARISONS) expect(en.settings.co2[c], c).toBeTruthy();
    for (const l of LANGUAGES) expect(en.settings.languages[l], l).toBeTruthy();
  });
  it('has no empty strings', () => {
    const walk = (o: unknown, p: string): void => {
      if (typeof o === 'string') expect(o.trim(), p).not.toBe('');
      else if (o && typeof o === 'object') for (const [k, v] of Object.entries(o)) walk(v, `${p}.${k}`);
    };
    walk(en, 'en');
  });
});
