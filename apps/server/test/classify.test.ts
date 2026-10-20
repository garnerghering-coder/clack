import { describe, expect, it } from 'vitest';
import { loadCategoryRules } from '../src/dataFiles.js';
import { classify, isRailRoute, type TripFacts } from '../src/import/classify.js';

const rules = loadCategoryRules();
const base: TripFacts = { gtfs_route_type: '106', has_non_rail_stop: false, stop_sigs: ['Cst', 'U'] };
const cat = (f: Partial<TripFacts>) => {
  const r = classify(rules, { ...base, ...f });
  return r.excluded ? 'EXCLUDED' : r.category;
};

describe('category rules', () => {
  it('classifies the main brands', () => {
    expect(cat({ gtfs_route_type: '101', gtfs_operator: 'SJ AB' })).toBe('intercity');
    expect(cat({ gtfs_route_type: '105', gtfs_operator: 'Snälltåget' })).toBe('intercity');
    expect(cat({ gtfs_route_type: '106', gtfs_operator: 'SL' })).toBe('commuter');
    expect(cat({ gtfs_route_type: '106', gtfs_operator: 'Pågatåg' })).toBe('commuter');
    expect(cat({ gtfs_route_type: '106', gtfs_operator: 'Mälartåg' })).toBe('regional');
    expect(cat({ gtfs_route_type: '100', gtfs_operator: 'Lennakatten' })).toBe('heritage');
  });
  it('puts Arlanda Express in regional even though GTFS says high speed', () => {
    expect(cat({ gtfs_route_type: '101', gtfs_operator: 'Arlanda Express' })).toBe('regional');
  });
  it('makes Västtågen commuter only on the Göteborg commuter network', () => {
    expect(cat({ gtfs_operator: 'Västtågen', stop_sigs: ['G', 'Mdn', 'Kb'] })).toBe('commuter');
    expect(cat({ gtfs_operator: 'Västtågen', stop_sigs: ['N', 'Jö'] })).toBe('regional');
    expect(cat({ gtfs_operator: 'Västtågen', stop_sigs: ['G', undefined] })).toBe('regional');
  });
  it('excludes buses, taxis and trams', () => {
    expect(cat({ gtfs_operator: 'SJ AB', has_non_rail_stop: true })).toBe('EXCLUDED');
    expect(cat({ gtfs_route_type: '100', gtfs_operator: 'Taxi' })).toBe('EXCLUDED');
    expect(cat({ trv_type_of_traffic: ['Buss'] })).toBe('EXCLUDED');
    expect(cat({ gtfs_route_type: '900', gtfs_route_short_name: '7' })).toBe('EXCLUDED');
  });
  it('lets Trafikverket product decide over route_type when known', () => {
    expect(cat({ gtfs_route_type: '100', gtfs_operator: 'SJ AB', trv_product: ['SJ Regional'] })).toBe('regional');
    expect(cat({ gtfs_route_type: '106', gtfs_operator: 'Västtågen', trv_type_of_traffic: ['Pendeltåg'] })).toBe('commuter');
  });
  it('recognises rail routes including SL narrow gauge', () => {
    expect(isRailRoute('106', '40', 'AB SL Kundtjänst')).toBe(true);
    expect(isRailRoute('900', '28', 'AB SL Kundtjänst')).toBe(true);
    expect(isRailRoute('900', '7', 'AB SL Kundtjänst')).toBe(false);
    expect(isRailRoute('700', '1', 'SJ AB')).toBe(false);
    expect(isRailRoute('2', '', 'SJ')).toBe(true);
  });
});
