import { describe, expect, it } from 'vitest';
import { brandOnLine, parseComposition, trainTypeCatalog, trainTypeFor, typicalTrainType } from '../src/legs/trainTypes.js';
import { loadBrands } from '../src/dataFiles.js';

describe('typical train types', () => {
  it('knows the common Swedish services', () => {
    expect(typicalTrainType('sj', 'high_speed', '423')).toBe('x2000');
    expect(typicalTrainType('sj', 'night', '1')).toBe('rc6_sleeper');
    expect(typicalTrainType('sl', 'commuter', '2580')).toBe('x60');
    expect(typicalTrainType('vasttagen', 'commuter', '3592')).toBe('x61_vt');
    expect(typicalTrainType('vasttagen', 'regional', '7256')).toBe('regina');
    expect(typicalTrainType('snalltaget', 'intercity', '306')).toBe('loco_coaches');
  });

  it('returns nothing for an unknown operator rather than guessing', () => {
    expect(typicalTrainType('nobody', 'regional', '1')).toBeNull();
    // Krösatåg runs Itinos on some lines and older electric units on others: no single typical type.
    expect(typicalTrainType('krosatag', 'regional', '7600')).toBeNull();
  });

  it('tells Vy and SJ Nord lines apart by where the train starts or ends (Norske tog, jernbane.net, 2026-10-22)', () => {
    expect(typicalTrainType('vy', 'regional', '1027', ['Asker', 'Kongsvinger'])).toBe('no_flirt');
    expect(typicalTrainType('vy', 'intercity', '141', ['Oslo S', 'Göteborg C'])).toBe('no_type73');
    expect(typicalTrainType('vy', 'intercity', '61', ['Oslo S', 'Bergen'])).toBe('no_flirt');
    expect(typicalTrainType('vy', 'commuter', '2253', ['Lillestrøm', 'Spikkestad'])).toBe('no_type72');
    expect(typicalTrainType('vy', 'commuter', '2755', ['Stabekk', 'Ski'])).toBe('no_type69_72');
    expect(typicalTrainType('vy', 'regional', '2487', ['Notodden', 'Porsgrunn'])).toBe('no_type69');
    expect(typicalTrainType('sj-nord', 'regional', '1308', ['Storlien', 'Trondheim S'])).toBe('no_type73');
    expect(typicalTrainType('sj-nord', 'regional', '2380', ['Dombås', 'Åndalsnes'])).toBe('no_type93');
    // Without the ends, a line rule doesn't apply: the operator's typical type.
    expect(typicalTrainType('vy', 'commuter', '2253')).toBe('no_flirt');
  });

  it("labels Krösatåg by line: electric units on the electrified lines, railcars on the rest (owner's research, 2026-10-22)", () => {
    expect(typicalTrainType('krosatag', 'regional', '1', ['Tranås', 'Jönköping C'])).toBe('x11_x14');
    expect(typicalTrainType('krosatag', 'regional', '1', ['Hässleholm', 'Växjö'])).toBe('x11_x14');
    expect(typicalTrainType('krosatag', 'regional', '1', ['Karlskrona C', 'Emmaboda'])).toBe('x11_x14');
    expect(typicalTrainType('krosatag', 'regional', '1', ['Nässjö C', 'Halmstad C'])).toBe('itino_y2');
    expect(typicalTrainType('krosatag', 'regional', '1', ['Linköping C', 'Västervik'])).toBe('itino_y2');
    expect(typicalTrainType('krosatag', 'regional', '1', ['Kalmar C', 'Vimmerby'])).toBe('itino_y2');
    // Lines the sources don't name: no type rather than a guess.
    expect(typicalTrainType('krosatag', 'regional', '1', ['Jönköping C', 'Värnamo C'])).toBeNull();
    expect(typicalTrainType('krosatag', 'regional', '1', ['Emmaboda', 'Kalmar C'])).toBeNull();
    expect(typicalTrainType('krosatag', 'regional', '1', ['Värnamo C', 'Alvesta'])).toBeNull();
  });

  it('tells Göteborg pendeltåg and the Itino lines from Västtåg and Värmlandstrafik Reginas', () => {
    expect(typicalTrainType('vasttagen', 'regional', '1', ['Alingsås', 'Göteborg C'])).toBe('x61_vt');
    expect(typicalTrainType('vasttagen', 'regional', '1', ['Göteborg C', 'Kungsbacka'])).toBe('x61_vt');
    expect(typicalTrainType('vasttagen', 'regional', '1', ['Hallsberg', 'Lidköping'])).toBe('y31');
    expect(typicalTrainType('varmlandstrafik', 'regional', '1', ['Karlstad C', 'Torsby'])).toBe('y31');
    expect(typicalTrainType('vasttagen', 'regional', '1', ['Göteborg C', 'Töreboda'])).toBe('regina');
    expect(typicalTrainType('varmlandstrafik', 'regional', '1', ['Charlottenberg', 'Karlstad C'])).toBe('regina');
  });

  it("picks Flytoget's type from the set the live feed names, and says both without it", () => {
    expect(typicalTrainType('flytoget', 'airport', '3943', ['Drammen', 'Oslo lufthavn'], '71-03')).toBe('flytoget71');
    expect(typicalTrainType('flytoget', 'airport', '3943', ['Drammen', 'Oslo lufthavn'], '78-05')).toBe('flytoget78');
    expect(typicalTrainType('flytoget', 'airport', '3943', ['Drammen', 'Oslo lufthavn'])).toBe('flytoget');
  });

  it("puts SJ's Storlien–Trondheim trains under SJ Nord, who runs them", () => {
    expect(brandOnLine('sj', ['Storlien', 'Trondheim S'])).toBe('sj-nord');
    expect(brandOnLine('sj', ['Stockholm C', 'Storlien'])).toBe('sj');
    expect(brandOnLine('vy', ['Trondheim S'])).toBe('vy');
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
