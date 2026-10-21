import { describe, expect, it } from 'vitest';
import { typicalAmenities, type AmenityEntry } from '@clack/shared';
import { onboardFromRow } from '../src/legs/onboard.js';
import { trainTypeCatalog } from '../src/legs/trainTypes.js';
import { loadBrands } from '../src/dataFiles.js';

// Shapes as Trafikverket sent them on 2026-10-21 (ONBOARD_DATA_FINDINGS.md §1).
describe("Trafikverket's on-board facts for a departure", () => {
  it('reads the planned catering', () => {
    expect(onboardFromRow({ Service: [{ Code: 'SNA001', Description: 'Bistro' }] })).toEqual({ catering: 'bistro', cateringCar: null, sleeper: false, notices: [] });
    expect(onboardFromRow({ Service: [{ Code: 'SNA006', Description: 'Krog' }] }).catering).toBe('restaurant');
    expect(onboardFromRow({ Service: [{ Description: 'Servering' }] }).catering).toBe('refreshments');
  });

  it("finds VR's café car in the coach order", () => {
    expect(onboardFromRow({ TrainComposition: [{ Description: 'Vagnsordning A-B-C-D-E' }, { Description: 'Café i vagn B' }] })).toMatchObject({ catering: 'cafe', cateringCar: 'B' });
  });

  it('lets "Ej servering" today cancel the planned bistro, and keeps the other notices', () => {
    const f = onboardFromRow({ Service: [{ Code: 'SNA001', Description: 'Bistro' }], Deviation: [{ Code: 'ANA083', Description: 'Ej servering' }, { Code: 'ANA093', Description: 'Ej toalett' }] });
    expect(f).toEqual({ catering: null, cateringCar: null, sleeper: false, notices: ['no_catering', 'no_toilet'] });
  });

  it('says nothing when Trafikverket says nothing (no Service is not "no catering")', () => {
    expect(onboardFromRow({})).toEqual({ catering: null, cateringCar: null, sleeper: false, notices: [] });
  });
});

describe('typical amenities', () => {
  const src = { source: 'https://example.se', verified: '2026-10-21' };
  const table: AmenityEntry[] = [
    { match: { operator: 'norrtag' }, claims: { wifi: { value: true, ...src }, catering: { value: 'Bistro', ...src } } },
    { match: { operator: 'norrtag', type: 'regina' }, claims: { step_free: { value: 'partial', ...src } } },
    { match: { operator: 'norrtag', type: 'x62' }, claims: { step_free: { value: true, ...src } } },
    { match: { operator: 'sj', type: 'x2000' }, claims: { wifi: { value: true, source: 'https://sj.se', verified: '2024-01-01' } } },
  ];
  const now = Date.parse('2026-10-22T12:00:00Z');

  it('layers the type over the operator', () => {
    expect(Object.keys(typicalAmenities(table, 'norrtag', 'regina', now)).sort()).toEqual(['catering', 'step_free', 'wifi']);
    expect(typicalAmenities(table, 'norrtag', 'regina', now).step_free!.value).toBe('partial');
    expect(typicalAmenities(table, 'norrtag', 'x62', now).step_free!.value).toBe(true);
  });

  it('hides claims nobody has checked for a year, and guesses nothing for unknown trains', () => {
    expect(typicalAmenities(table, 'sj', 'x2000', now)).toEqual({});
    expect(typicalAmenities(table, null, null, now)).toEqual({});
  });

  it('only uses operators and types that exist, with a source and a date', () => {
    const ids = new Set(trainTypeCatalog().types.map((t) => t.id));
    const brands = new Set(loadBrands().map((b) => b.id));
    for (const e of trainTypeCatalog().amenities ?? []) {
      expect(brands.has(e.match.operator), e.match.operator).toBe(true);
      if (e.match.type) expect(ids.has(e.match.type), e.match.type).toBe(true);
      for (const [k, c] of Object.entries(e.claims)) {
        expect(c!.source, k).toMatch(/^https:\/\//);
        expect(Number.isNaN(Date.parse(c!.verified)), k).toBe(false);
      }
    }
  });
});
