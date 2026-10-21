import { describe, expect, it } from 'vitest';
import { cleanStopName, isReplacementBus, matchStation, sameSpelling, norwegianCategory, trainNumberFromTripId } from '../src/import/gtfs-no.js';

describe('Norway timetable import', () => {
  it('reads train numbers out of Entur trip ids', () => {
    expect(trainNumberFromTripId('VYG:ServiceJourney:135_443135-R')).toBe('135');
    expect(trainNumberFromTripId('GOA:ServiceJourney:725-LOD_67061-R')).toBe('725');
    expect(trainNumberFromTripId('SJN:ServiceJourney:1301_55229-R')).toBe('1301');
    expect(trainNumberFromTripId('FLT:ServiceJourney:1-2614-3815-20261021')).toBe('3815');
    expect(trainNumberFromTripId('GOA:ServiceJourney:B705-CI_72899-R')).toBeNull();
    expect(isReplacementBus('VYG:ServiceJourney:BUS-1104_776129-R')).toBe(true);
    expect(isReplacementBus('SJN:ServiceJourney:B42-A2_54592-R')).toBe(true);
    expect(isReplacementBus('VYG:ServiceJourney:135_443135-R')).toBe(false);
  });
  it('categorises by line, with overnight long-distance trains as night trains', () => {
    expect(norwegianCategory('L1', 8 * 3600, 9 * 3600)).toBe('commuter');
    expect(norwegianCategory('RE20', 8 * 3600, 11 * 3600)).toBe('regional');
    expect(norwegianCategory('F4', 8 * 3600, 15 * 3600)).toBe('intercity');
    expect(norwegianCategory('F5', 22 * 3600, 31 * 3600)).toBe('night');
    expect(norwegianCategory('FLY1', 8 * 3600, 9 * 3600)).toBe('regional');
  });
  it('reuses a station that already exists, and drops the "stasjon" in names', () => {
    const existing = [
      { id: '760000100', name: 'Oslo S', lat: 59.91099, lon: 10.75349, country: 'NO' },
      { id: '740000002', name: 'Göteborg C', lat: 57.7089, lon: 11.9733, country: 'SE' },
    ];
    expect(matchStation({ name: 'Oslo S', lat: 59.9111, lon: 10.7528 }, existing)?.id).toBe('760000100');
    expect(matchStation({ name: 'Göteborg Centralstasjon', lat: 57.7095, lon: 11.9740 }, existing)?.id).toBe('740000002');
    expect(matchStation({ name: 'Ski stasjon', lat: 59.7185, lon: 10.8338 }, existing)).toBeNull();
    expect(cleanStopName('Otta stasjon')).toBe('Otta');
  });

  it('renames only when the Norwegian name is the same place spelled differently', () => {
    expect(sameSpelling('Lilleström', 'Lillestrøm stasjon')).toBe(true);
    expect(sameSpelling('Björnfjell', 'Bjørnfjell')).toBe(true);
    expect(sameSpelling('Mysen', 'Mysen')).toBe(true);
    expect(sameSpelling('Oslo S', 'Oslo S Trelastgata')).toBe(false);
  });
});
