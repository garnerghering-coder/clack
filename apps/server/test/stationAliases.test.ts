import { describe, expect, it } from 'vitest';
import { loadStationAliases } from '../src/dataFiles.js';
import { buildStationIndex, searchStations } from '../src/search/stations.js';
import { openDb } from '../src/db/client.js';
import { createSmartSearch } from '../src/search/smartSearch.js';

// Stations as the hosted server has them (2026-10-27), with the real alias file.
const STATIONS = [
  { id: '740000003', name: 'Malmö C', trvSignature: 'M', country: 'SE', departuresPerDay: 900 },
  { id: '740000120', name: 'Lund C', trvSignature: 'Lu', country: 'SE', departuresPerDay: 700 },
  { id: '860000626', name: 'København H', trvSignature: 'Dk.kh', country: 'DK', departuresPerDay: 120 },
  { id: '860000858', name: 'CPH Airport', trvSignature: 'Dk.cph', country: 'DK', departuresPerDay: 120 },
  { id: '860000646', name: 'København Nørreport', trvSignature: 'Dk.kn', country: 'DK', departuresPerDay: 60 },
  { id: '860000650', name: 'København Østerport', trvSignature: 'Dk.kk', country: 'DK', departuresPerDay: 60 },
  { id: 'fi:HKI', name: 'Helsinki', trvSignature: null, country: 'FI', departuresPerDay: 400 },
  { id: 'fi:TPE', name: 'Tampere', trvSignature: null, country: 'FI', departuresPerDay: 150 },
  { id: 'fi:TKU', name: 'Turku', trvSignature: null, country: 'FI', departuresPerDay: 40 },
  { id: 'fi:LEN', name: 'Lentoasema', trvSignature: null, country: 'FI', departuresPerDay: 200 },
];
const index = buildStationIndex(STATIONS, loadStationAliases());
const top = (q: string) => searchStations(index, q, 1)[0]?.name;

describe('Swedish and English names for Danish and Finnish stations', () => {
  it('finds Copenhagen by the names SJ tickets and Swedish travellers use', () => {
    for (const q of ['Köpenhamn', 'Köpenhamn H', 'Köpenhamns central', 'Copenhagen']) expect(top(q)).toBe('København H');
    for (const q of ['Copenhagen Airport', 'Kastrup flygplats', 'Köpenhamn Kastrup']) expect(top(q)).toBe('CPH Airport');
    expect(top('Köpenhamn Österport')).toBe('København Østerport');
  });

  it('finds Finnish stations by their Swedish names', () => {
    expect(top('Helsingfors')).toBe('Helsinki');
    expect(top('Tammerfors')).toBe('Tampere');
    expect(top('Åbo')).toBe('Turku');
    expect(top('Helsinki Airport')).toBe('Lentoasema');
  });

  it('reads a ticket\'s "Malmö C Köpenhamn H" as two stations', () => {
    const search = createSmartSearch(openDb(':memory:'), () => index);
    const r = search('Malmö C Köpenhamn H', '2099-01-01');
    expect([r.interpretation.from?.name, r.interpretation.to?.name]).toEqual(['Malmö C', 'København H']);
    const f = search('Helsingfors Tammerfors', '2099-01-01');
    expect([f.interpretation.from?.name, f.interpretation.to?.name]).toEqual(['Helsinki', 'Tampere']);
  });
});
