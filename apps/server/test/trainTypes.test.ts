import { describe, expect, it } from 'vitest';
import { trainTypeCatalog, typicalTrainType } from '../src/legs/trainTypes.js';
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
  });

  it('only refers to types and operators that exist', () => {
    const { types, rules } = trainTypeCatalog();
    const ids = new Set(types.map((t) => t.id));
    const brands = new Set(loadBrands().map((b) => b.id));
    for (const r of rules) {
      expect(ids.has(r.type), r.type).toBe(true);
      if (r.match.operator) expect(brands.has(r.match.operator), r.match.operator).toBe(true);
    }
  });
});
