import { describe, expect, it } from 'vitest';
import { loadBrands } from '../src/dataFiles.js';
import { buildOperatorMatcher, parseQuery } from '../src/search/parse.js';

const match = buildOperatorMatcher(loadBrands());
const p = (s: string) => parseQuery(s, match);

describe('search input parsing', () => {
  it('reads operator + number in any spacing or case', () => {
    expect(p('SJ 523')).toMatchObject({ operatorId: 'sj', trainNumber: '523' });
    expect(p('SJ 523').fromText).toBeUndefined();
    expect(p('sj523')).toMatchObject({ operatorId: 'sj', trainNumber: '523' });
    expect(p('Snälltåget 3943')).toMatchObject({ operatorId: 'snalltaget', trainNumber: '3943' });
    expect(p('snalltaget 306')).toMatchObject({ operatorId: 'snalltaget', trainNumber: '306' });
    expect(p('Tåg i Bergslagen 8001')).toMatchObject({ operatorId: 'tib', trainNumber: '8001' });
    expect(p('MTRX 2031')).toMatchObject({ operatorId: 'vr', trainNumber: '2031' });
  });
  it('reads a bare number as a train number on any operator', () => {
    expect(p('523')).toMatchObject({ trainNumber: '523' });
    expect(p('523').operatorId).toBeUndefined();
    expect(p(' 7256 ')).toMatchObject({ trainNumber: '7256' });
  });
  it('reads routes with arrows, dashes and "to"', () => {
    for (const s of ['Stockholm → Göteborg', 'Stockholm -> Göteborg', 'Stockholm - Göteborg', 'Stockholm to Göteborg', 'Stockholm till Göteborg', 'Stockholm – Göteborg'])
      expect(p(s), s).toMatchObject({ fromText: 'Stockholm', toText: 'Göteborg', hasSeparator: true });
  });
  it('keeps the route half-typed', () => {
    expect(p('Stockholm C →')).toMatchObject({ fromText: 'Stockholm C', toText: '', hasSeparator: true });
  });
  it('reads operator + route', () => {
    expect(p('Snälltåget Stockholm → Malmö')).toMatchObject({ operatorId: 'snalltaget', fromText: 'Stockholm', toText: 'Malmö' });
    expect(p('Snälltåget Stockholm Malmö')).toMatchObject({ operatorId: 'snalltaget', fromText: 'Stockholm Malmö', splittable: true });
  });
  it('leaves plain station text alone', () => {
    expect(p('Göteb')).toMatchObject({ fromText: 'Göteb', splittable: false, hasSeparator: false });
    expect(p('Stockholm City')).toMatchObject({ fromText: 'Stockholm City', splittable: true });
    expect(p('')).toEqual({ hasSeparator: false, splittable: false });
  });
  it('does not mistake station names containing operator words', () => {
    // "Vy" is an operator alias, but "Vyborg" is not "Vy" + "borg".
    expect(p('Vyborg')).toMatchObject({ fromText: 'Vyborg' });
    expect(p('Vyborg').operatorId).toBeUndefined();
  });
});

describe('a train number before a route', () => {
  it('reads "1165 Malmö C → København H" as the number and both stations', async () => {
    const { parseQuery, buildOperatorMatcher } = await import('../src/search/parse.js');
    const q = parseQuery('1165 Malmö C → København H', buildOperatorMatcher([]));
    expect([q.trainNumber, q.fromText, q.toText]).toEqual(['1165', 'Malmö C', 'København H']);
    // A number on its own before the arrow stays the station text being typed.
    expect(parseQuery('1165 →', buildOperatorMatcher([])).trainNumber).toBeUndefined();
  });
});
