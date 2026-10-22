import { describe, expect, it } from 'vitest';
import { parseComposition, trainTypeCatalog, trainTypeFor, typicalTrainType } from '../src/legs/trainTypes.js';
import { loadBrands } from '../src/dataFiles.js';

describe('typical train types', () => {
  it('knows the common Swedish services', () => {
    expect(typicalTrainType('sj', 'high_speed', '423')).toBe('x2000');
    expect(typicalTrainType('sj', 'night', '1')).toBe('rc6_sleeper');
    expect(typicalTrainType('sl', 'commuter', '2580')).toBe('x60');
    expect(typicalTrainType('vasttagen', 'commuter', '3592')).toBe('x61');
    expect(typicalTrainType('vasttagen', 'regional', '7256')).toBe('regina');
    expect(typicalTrainType('snalltaget', 'intercity', '306')).toBe('loco_coaches');
  });

  it('returns nothing for an unknown operator rather than guessing', () => {
    expect(typicalTrainType('nobody', 'regional', '1')).toBeNull();
    // Krösatåg runs Itinos on some lines and older electric units on others: no single typical type.
    expect(typicalTrainType('krosatag', 'regional', '7600')).toBeNull();
  });

  it('only refers to types and operators that exist', () => {
    const { types, rules } = trainTypeCatalog();
    const ids = new Set(types.map((t) => t.id));
    const brands = new Set(loadBrands().map((b) => b.id));
    for (const r of [...rules, ...(trainTypeCatalog().composition_rules ?? [])]) {
      expect(ids.has(r.type), r.type).toBe(true);
      if (r.match.operator) expect(brands.has(r.match.operator), r.match.operator).toBe(true);
    }
  });
});

// Real coach orders from Trafikverket, 2026-10-21.
const vo = (s: string) => [{ Description: `Vagnsordning ${s}` }];
describe('train type from the planned coach order', () => {
  it('reads cars, units and locomotives', () => {
    expect(parseComposition(vo('1-3-4-5-6-7'))).toEqual({ locomotive: false, cars: 6, units: 1 });
    expect(parseComposition(vo('1-3-4-5-6-7, 8-10-11-12-13-14'))).toEqual({ locomotive: false, cars: 6, units: 2 });
    expect(parseComposition(vo('Lok-[-6]-5-4-3-2'))).toEqual({ locomotive: true, cars: 5, units: 1 });
    expect(parseComposition(vo('9,10,11,12,13,14,216,217,218'))).toEqual({ locomotive: false, cars: 9, units: 1 });
    expect(parseComposition([{ Description: 'Långt tåg.' }, { Description: 'Vagnsordning A-B-C-D-E' }, { Description: 'Café i vagn B' }])).toMatchObject({ cars: 5 });
    expect(parseComposition([{ Description: 'Långt tåg.' }])).toBeNull();
    expect(parseComposition(undefined)).toBeNull();
  });

  it('tells X2000 from SJ 3000', () => {
    expect(trainTypeFor('sj', 'high_speed', '445', parseComposition(vo('1-3-4-5-6-7')))).toBe('x2000');
    expect(trainTypeFor('sj', 'high_speed', '582', parseComposition(vo('4-3-2-1')))).toBe('x55');
    expect(trainTypeFor('sj', 'high_speed', '443', parseComposition(vo('1-3-4-5-6-7, 8-10-11-12-13-14')))).toBe('x2000');
  });

  it('spots locomotive-hauled SJ trains', () => {
    expect(trainTypeFor('sj', 'regional', '131', parseComposition(vo('Lok-9-8-7-6-5-4-3-2')))).toBe('rc6_coaches');
    expect(trainTypeFor('sj', 'night', '92', parseComposition(vo('Lok-17-18-20-21-22-23-24-25')))).toBe('rc6_sleeper');
    expect(trainTypeFor('sj', 'regional', '1000', parseComposition(vo('1-2-3')))).toBe('x40');
  });

  it('falls back to the typical type when the coach order says nothing new', () => {
    expect(trainTypeFor('sj', 'high_speed', '445', null)).toBe('x2000');
    expect(trainTypeFor('vr', 'high_speed', '2035', parseComposition(vo('A-B-C-D-E')))).toBe(typicalTrainType('vr', 'high_speed', '2035'));
  });
});
