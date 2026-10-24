import { describe, expect, it } from 'vitest';
import { loadBrands } from '../src/dataFiles.js';
import { normName } from '../src/lib/geo.js';

describe('operator brands', () => {
  const brands = loadBrands();

  it('has unique ids', () => {
    const ids = brands.map((b) => b.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('never gives two brands the same search alias or id (search takes the last one silently)', () => {
    const owner = new Map<string, string>();
    for (const b of brands) {
      for (const key of new Set([b.id, ...b.aliases].map(normName))) {
        const prev = owner.get(key);
        expect(prev === undefined || prev === b.id, `"${key}" is used by ${prev} and ${b.id}`).toBe(true);
        owner.set(key, b.id);
      }
    }
  });

  it('never gives two brands the same GTFS operator string', () => {
    const owner = new Map<string, string>();
    for (const b of brands) {
      for (const g of b.gtfs_operators) {
        const prev = owner.get(g);
        expect(prev === undefined || prev === b.id, `"${g}" is used by ${prev} and ${b.id}`).toBe(true);
        owner.set(g, b.id);
      }
    }
  });

  it('keeps VR Finland apart from the Swedish VR Snabbtåg (ex-MTR Express)', () => {
    const byId = new Map(brands.map((b) => [b.id, b]));
    const fi = byId.get('vr-fi')!;
    const se = byId.get('vr')!;
    expect(fi.country).toBe('FI');
    expect(se.country).toBe('SE');
    expect(se.gtfs_operators).toEqual(['MTR Express AB']);
    expect(fi.gtfs_operators).toEqual(['VR']);
    expect(fi.aliases.map(normName)).not.toContain('vr');
    expect(byId.get('oresundstag')!.gtfs_operators).toContain('VR Sverige AB');
    expect(byId.get('hsl')!.country).toBe('FI');
  });
});
