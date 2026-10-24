import { describe, expect, it } from 'vitest';
import { buildStations, countryOf, TZ_BY_COUNTRY, type GtfsParent, type TrvLoc } from '../src/import/stations.js';

const trv: TrvLoc[] = [
  { signature: 'Cst', name: 'Stockholm C', lat: 59.33, lon: 18.0573, country: 'SE' },
  { signature: 'Nvn', name: 'Notviken', lat: 65.6107, lon: 22.1187, country: 'SE' },
  { signature: 'Dk.kh', name: 'Köpenhamn H', lat: 55.6726, lon: 12.5646, country: 'DK' },
];
const parent = (p: Partial<GtfsParent> & { stopId: string; name: string; lat: number; lon: number }): GtfsParent => ({ childIds: [], ...p });

describe('buildStations', () => {
  it('maps via the official file, keys by rikshållplats and uses the Trafikverket name in Sweden', () => {
    const { stations } = buildStations(
      [parent({ stopId: '1', name: 'Stockholm Centralstation', lat: 59.3315, lon: 18.0549, riks: '740000001', childIds: ['9022'] })],
      trv,
      new Map([['740000001', ['CST']]]),
      {},
    );
    expect(stations[0]).toMatchObject({ id: '740000001', name: 'Stockholm C', trvSignature: 'Cst', method: 'official', tz: 'Europe/Stockholm', gtfsStopIds: ['1', '9022'] });
  });
  it('matches foreign stations named differently by Trafikverket, keeping the GTFS name', () => {
    const { stations } = buildStations([parent({ stopId: '25315', name: 'København H', lat: 55.6729, lon: 12.565, riks: '860000626' })], trv, new Map(), {});
    expect(stations[0]).toMatchObject({ trvSignature: 'Dk.kh', country: 'DK', name: 'København H', tz: 'Europe/Copenhagen' });
  });
  it("uses Trafikverket's coordinate when GTFS is far off (Notviken)", () => {
    const { stations } = buildStations(
      [parent({ stopId: '57766', name: 'Notviken Station', lat: 65.1306, lon: 22.0011, riks: '740057766' })],
      trv,
      new Map(),
      { '57766': { name: 'Notviken', trv_signature: 'Nvn', kind: 'rail_station' } },
    );
    expect(stations[0]).toMatchObject({ trvSignature: 'Nvn', coordSource: 'trafikverket', lat: 65.6107 });
  });
  it('marks Swedish stops far from any Trafikverket location as bus stops, and merges shared rikshållplats', () => {
    const { stations, stationOfParent } = buildStations(
      [
        parent({ stopId: '491', name: 'Funäsdalen busstation', lat: 62.54, lon: 12.55, riks: '740000491' }),
        parent({ stopId: 'a', name: 'Stockholm C', lat: 59.33, lon: 18.0573, riks: '740000001' }),
        parent({ stopId: 'b', name: 'Stockholm C spår 19', lat: 59.3301, lon: 18.0574, riks: '740000001' }),
      ],
      trv,
      new Map(),
      {},
    );
    expect(stations.find((s) => s.id === '740000491')).toMatchObject({ kind: 'bus_stop', needsReview: false });
    expect(stations.filter((s) => s.id === '740000001')).toHaveLength(1);
    expect(stationOfParent.get('b')).toBe('740000001');
  });
  it('derives countries', () => {
    expect(countryOf('No.osl', undefined, 59.9, 10.7)).toBe('NO');
    expect(countryOf(null, '860000626', 55.6, 12.5)).toBe('DK');
    expect(countryOf(null, undefined, 47.32, 12.79)).toBe('AT');
    expect(countryOf(null, undefined, 52.52, 13.37)).toBe('DE');
    expect(countryOf(null, undefined, 61.0, 14.5)).toBe('SE');
  });
  it('takes the source\'s own country when it states one (Finland is not Sweden)', () => {
    expect(countryOf(null, undefined, 60.17, 24.94, 'FI')).toBe('FI');
    expect(countryOf(null, undefined, 65.83, 24.13, 'se')).toBe('SE'); // Haparanda, as Digitraffic says
    expect(countryOf(null, undefined, 61.0, 14.5, 'not a code')).toBe('SE'); // unusable: falls back as before
  });
  it('has a time zone for Finland', () => {
    expect(TZ_BY_COUNTRY.FI).toBe('Europe/Helsinki');
    expect(TZ_BY_COUNTRY.SE).toBe('Europe/Stockholm');
  });
});

describe('buildStations merging', () => {
  it('merges two GTFS stops that map to the same Trafikverket station, keeping the rikshållplats id', () => {
    const trvMora: TrvLoc[] = [{ signature: 'Mo', name: 'Mora C', lat: 61.009, lon: 14.5602, country: 'SE' }];
    const { stations, stationOfParent } = buildStations(
      [
        { stopId: '46506', name: 'Mora C', lat: 61.0086, lon: 14.5584, childIds: ['x'] },
        { stopId: '302', name: 'Mora C', lat: 61.009, lon: 14.5602, childIds: ['y'], riks: '740000302' },
      ],
      trvMora,
      new Map([['740000302', ['MO']]]),
      {},
    );
    expect(stations).toHaveLength(1);
    expect(stations[0]).toMatchObject({ id: '740000302', gtfsStopIds: ['302', 'y', '46506', 'x'] });
    expect(stationOfParent.get('46506')).toBe('740000302');
  });
});
