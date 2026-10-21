import { describe, expect, it } from 'vitest';
import { CO2_COMPARISONS, LANGUAGES } from '@clack/shared';
import en from './locales/en.json';
import sv from './locales/sv.json';

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

describe('sv locale', () => {
  const paths = (o: unknown, p = ''): Map<string, string> =>
    new Map(
      typeof o === 'string'
        ? [[p, o]]
        : Object.entries(o as Record<string, unknown>).flatMap(([k, v]) => [...paths(v, p ? `${p}.${k}` : k)]),
    );
  const enPaths = paths(en);
  const svPaths = paths(sv);
  it('translates every English string, and nothing else', () => {
    expect([...svPaths.keys()].sort()).toEqual([...enPaths.keys()].sort());
  });
  it('keeps the same placeholders', () => {
    const vars = (s: string) => [...s.matchAll(/{{\s*(\w+)\s*}}/g)].map((m) => m[1]).sort();
    for (const [k, v] of enPaths) expect(vars(svPaths.get(k) ?? ''), k).toEqual(vars(v));
  });
});
