import { describe, expect, it } from 'vitest';
import { buildStationIndex, searchStations, type SearchableStation } from '../src/search/stations.js';

const st = (id: string, name: string, sig: string | null, dep: number, country = 'SE'): SearchableStation => ({ id, name, trvSignature: sig, departuresPerDay: dep, country });
const index = buildStationIndex(
  [
    st('1', 'Stockholm C', 'Cst', 300),
    st('2', 'Stockholm City', 'Sci', 460),
    st('3', 'Stockholms S', 'Sst', 459),
    st('4', 'Göteborg C', 'G', 250),
    st('5', 'Göteborg Olskroken', 'Gk', 5),
    st('6', 'Malmö C', 'Mc', 550),
    st('7', 'Nässjö C', 'N', 120),
    st('8', 'Jönköping C', 'Jö', 90),
    st('9', 'København H', 'Dk.kh', 200, 'DK'),
    st('10', 'Mora C', 'Mo', 12),
  ],
  { Cst: ['Stockholm', 'Sthlm'], G: ['Gothenburg'], 'Dk.kh': ['Copenhagen'] },
);
const first = (q: string) => searchStations(index, q)[0]?.name;

describe('station search', () => {
  it('is accent-insensitive', () => {
    expect(first('Goteborg')).toBe('Göteborg C');
    expect(first('nassjo')).toBe('Nässjö C');
    expect(first('JONKOPING')).toBe('Jönköping C');
  });
  it('maps city names to the main station via aliases and popularity', () => {
    expect(first('Stockholm')).toBe('Stockholm C');
    expect(first('Malmö')).toBe('Malmö C');
    expect(first('Gothenburg')).toBe('Göteborg C');
    expect(first('Copenhagen')).toBe('København H');
    expect(first('kobenhavn')).toBe('København H');
  });
  it('finds prefixes and word prefixes', () => {
    expect(first('Göteb')).toBe('Göteborg C');
    expect(searchStations(index, 'stockholm').map((h) => h.name)).toEqual(['Stockholm C', 'Stockholm City', 'Stockholms S']);
    expect(first('olsk')).toBe('Göteborg Olskroken');
  });
  it('tolerates typos', () => {
    expect(first('Gotebrog')).toBe('Göteborg C');
    expect(first('Jonkoping')).toBe('Jönköping C');
    expect(first('Nasjo')).toBe('Nässjö C');
  });
  it('finds Trafikverket signatures', () => {
    expect(first('Cst')).toBe('Stockholm C');
    expect(first('dk kh')).toBe('København H');
  });
  it('returns nothing for empty or unknown input', () => {
    expect(searchStations(index, '  ')).toEqual([]);
    expect(searchStations(index, 'zzzzzz')).toEqual([]);
  });
});

describe('station search fuzziness', () => {
  it('does not match a different word that differs in the first letter', () => {
    const idx = buildStationIndex([st('1', 'Göteborg C', 'G', 250), st('2', 'Rotebro', 'R', 100)], {});
    expect(searchStations(idx, 'goteb').map((h) => h.name)).toEqual(['Göteborg C']);
  });
});
