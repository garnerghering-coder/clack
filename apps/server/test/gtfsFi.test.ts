// Finland's timetable import. The zip in fixtures/ is a cut-down copy of Digitraffic's gtfs-passenger.zip
// (2026-10-24 feed): four real trips (IC 401 to Haparanda, commuter A 8192, S 13, night train PYO 264) and one
// synthetic cargo-type trip (T 9001, same stops as IC 401) to check freight is left out.
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { stations } from '../src/db/schema.js';
import type { Brand } from '../src/dataFiles.js';
import { commuterLineOf, FI_AGENCY_BRANDS, finnishProduct, findFiStation, importGtfsFinland, serviceDates, trainNumberOf, trainTypeFromRouteId } from '../src/import/gtfs-fi.js';
import { parseFiStations, usableFiStation } from '../src/import/fi-stations.js';

const ZIP = path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures/gtfs-fi-mini.zip');
const brand = (id: string, name: string): Brand => ({ id, name, short_name: name, color: '#000000', country: 'FI', gtfs_operators: [], aliases: [] });
const BRANDS = [brand('vr-fi', 'VR'), brand('hsl', 'HSL')];

describe('Finnish trip identifiers', () => {
  it('reads the train number from the trip id, then from the short name', () => {
    expect(trainNumberOf('8192_20261212', 'A (HL 8192)')).toBe('8192');
    expect(trainNumberOf('13_20261108', 'S 13')).toBe('13');
    expect(trainNumberOf('178_20261106_replacement', 'S 178')).toBe('178');
    expect(trainNumberOf('odd-id', 'A (HL 8192)')).toBe('8192');
    expect(trainNumberOf('odd-id', 'IC 27')).toBe('27');
    expect(trainNumberOf('odd-id', 'nothing')).toBeNull();
  });
  it('keeps the commuter line letter apart from the number', () => {
    expect(commuterLineOf('A (HL 8192)')).toBe('A');
    expect(commuterLineOf('IC 27')).toBeNull();
  });
  it('reads the train type from the route id', () => {
    expect(trainTypeFromRouteId('TPE_HKI_22_IC_10')).toBe('IC');
    expect(trainTypeFromRouteId('LPV_HKI_A_HL_10')).toBe('HL');
    expect(trainTypeFromRouteId('SK_ÄHT_480_HDM_10')).toBe('HDM');
    expect(trainTypeFromRouteId('garbage')).toBeNull();
  });
  it('maps agencies to our brands, heritage railways to none', () => {
    expect(FI_AGENCY_BRANDS['10']).toBe('vr-fi');
    expect(FI_AGENCY_BRANDS['9995']).toBe('hsl');
    expect(FI_AGENCY_BRANDS['3184']).toBeUndefined();
  });
});

describe('product of a Finnish train type', () => {
  it('maps the passenger types', () => {
    for (const t of ['HL', 'HV', 'HLV']) expect(finnishProduct(t)).toEqual({ product: 'commuter', known: true });
    expect(finnishProduct('S').product).toBe('high_speed');
    expect(finnishProduct('IC').product).toBe('intercity');
    expect(finnishProduct('IC2').product).toBe('intercity');
    expect(finnishProduct('PYO').product).toBe('night');
    for (const t of ['MV', 'MUS', 'V']) expect(finnishProduct(t).product).toBe('heritage');
    for (const t of ['H', 'P', 'HDM', 'HSM', 'AE', 'PVS', 'PVV']) expect(finnishProduct(t)).toEqual({ product: 'regional', known: true });
  });
  it('leaves out freight, locomotive moves, shunting, track machines and test drives', () => {
    for (const t of ['T', 'RJ', 'VET', 'PAR', 'W', 'TYO', 'LIV']) expect(finnishProduct(t)).toEqual({ product: null, known: true });
  });
  it('treats an unknown type as regional and says it is unknown', () => {
    expect(finnishProduct('ZZZ')).toEqual({ product: 'regional', known: false });
  });
});

describe('service dates', () => {
  const cal = { days: [false, true, true, true, true, true, false], start: '20261019', end: '20261030' }; // Mon-Fri
  it('follows the weekly pattern inside the window, adds and removes dates', () => {
    expect(serviceDates(cal, [], new Set(), '20261022', '20261102')).toEqual(['20261022', '20261023', '20261026', '20261027', '20261028', '20261029', '20261030']);
    expect(serviceDates(cal, ['20261024', '20261101', '20261201'], new Set(['20261023']), '20261022', '20261102')).toEqual(['20261022', '20261024', '20261026', '20261027', '20261028', '20261029', '20261030', '20261101']);
  });
  it('has dates only from calendar_dates when there is no weekly pattern', () => {
    expect(serviceDates(undefined, ['20261024'], new Set(), '20261022', '20261102')).toEqual(['20261024']);
  });
});

describe('Digitraffic stations', () => {
  const raw = [
    { stationShortCode: 'HKI', stationUICCode: 1, stationName: 'Helsinki asema', countryCode: 'FI', latitude: 60.171356, longitude: 24.941444, passengerTraffic: true },
    { stationShortCode: 'HPA', stationUICCode: 10726, stationName: 'Haaparanta pohjoinen', countryCode: 'SE', latitude: 65.828226, longitude: 24.130219, passengerTraffic: true },
    { stationShortCode: 'AHO', stationUICCode: 1343, stationName: 'Ahonpää', countryCode: 'FI', latitude: 64.537118, longitude: 25.006783, passengerTraffic: false },
    { stationShortCode: 'BOR', stationName: 'Border', countryCode: 'RU', latitude: 60.9, longitude: 28.3, passengerTraffic: true },
    { stationShortCode: 'BAD', stationName: 'No coordinates', countryCode: 'FI' },
  ];
  it('cleans names, drops rows without coordinates, and keeps passenger stations in Finland plus Haparanda', () => {
    const all = parseFiStations(raw);
    expect(all.map((s) => s.code)).toEqual(['HKI', 'HPA', 'AHO', 'BOR']);
    expect(all[0]!.name).toBe('Helsinki');
    expect(all.filter(usableFiStation).map((s) => s.code)).toEqual(['HKI', 'HPA']);
  });
  it('finds a station by its Finnish code, then by distance, and never twice', () => {
    const existing = [
      { id: '740000372', name: 'Haparanda', lat: 65.828367, lon: 24.131894, country: 'SE', fiId: null },
      { id: 'fi:HKI', name: 'Helsinki', lat: 60.171356, lon: 24.941444, country: 'FI', fiId: 'HKI' },
      { id: '740000999', name: 'Torneå', lat: 65.84, lon: 24.16, country: 'SE', fiId: null },
    ];
    const hpa = { code: 'HPA', name: 'Haaparanta pohjoinen', lat: 65.828226, lon: 24.130219 };
    expect(findFiStation({ code: 'HKI', name: 'Helsinki', lat: 0, lon: 0 }, existing)?.id).toBe('fi:HKI');
    expect(findFiStation(hpa, existing)?.id).toBe('740000372');
    // Already claimed by another code in this run: not matched a second time.
    expect(findFiStation(hpa, existing, new Set(['740000372']))).toBeNull();
    // Tornio is 2 km from Haparanda and has another name: a station of its own.
    expect(findFiStation({ code: 'TOR', name: 'Tornio', lat: 65.84534, lon: 24.163576 }, existing.slice(0, 1))).toBeNull();
  });
});

describe('Finland timetable import', () => {
  const metadata = parseFiStations([
    { stationShortCode: 'HPA', stationUICCode: 10726, stationName: 'Haaparanta pohjoinen', countryCode: 'SE', latitude: 65.828226, longitude: 24.130219, passengerTraffic: true },
    { stationShortCode: 'OL', stationUICCode: 130, stationName: 'Oulu asema', countryCode: 'FI', latitude: 65.012409, longitude: 25.486121, passengerTraffic: true },
  ]);
  const setup = () => {
    const db = openDb(':memory:');
    db.insert(stations)
      .values({ id: '740000372', name: 'Haparanda', country: 'SE', lat: 65.828367, lon: 24.131894, tz: 'Europe/Stockholm', trvSignature: 'Hp', gtfsStopIds: [], coordSource: 'trafikverket', kind: 'rail_station' })
      .run();
    return db;
  };
  const rows = (db: ReturnType<typeof openDb>, sql: string, ...p: unknown[]) => db.$client.prepare(sql).all(...p) as Record<string, unknown>[];

  it('imports passenger trains with numbers, products, operators and Helsinki time', async () => {
    const db = setup();
    const s = await importGtfsFinland(db, ZIP, { today: '2026-11-07', stations: metadata, brands: BRANDS });
    expect(s.trips).toBe(4);
    expect(s.excluded).toBe(1); // the cargo-type trip
    expect(s.window).toEqual(['2026-11-06', '2027-02-05']);
    const trips = rows(db, `select train_number n, category c, operator_id o, route_name r, route_type t, tz, key from timetable_trips where source = 'gtfs_fi' order by cast(train_number as int)`);
    expect(trips.map((t) => [t.n, t.c, t.o])).toEqual([
      ['13', 'high_speed', 'vr-fi'],
      ['264', 'night', 'vr-fi'],
      ['401', 'intercity', 'vr-fi'],
      ['8192', 'commuter', 'vr-fi'], // route LPV_HKI_A_HL_10: agency 10 (VR) runs most commuter lines; HSL (9995) a few,
    ]);
    expect(trips.every((t) => t.tz === 'Europe/Helsinki' && String(t.key).startsWith('fi:'))).toBe(true);
    expect(trips.find((t) => t.n === '8192')!.r).toMatch(/^A /); // the commuter line letter stays in the name
    expect(trips.find((t) => t.n === '8192')!.t).toBe('109');
    expect(rows(db, `select group_concat(id) n from operators where id in ('vr-fi','hsl')`)[0]!.n).toBe('vr-fi');
  });

  it('leaves freight out', async () => {
    const db = setup();
    await importGtfsFinland(db, ZIP, { today: '2026-11-07', stations: metadata, brands: BRANDS });
    expect(rows(db, `select count(*) n from timetable_trips where train_number = '9001'`)[0]!.n).toBe(0);
  });

  it('reuses Haparanda for HPA and makes Finnish stations for the rest', async () => {
    const db = setup();
    const s = await importGtfsFinland(db, ZIP, { today: '2026-11-07', stations: metadata, brands: BRANDS });
    expect(s.stations.matched).toBe(1);
    const hpa = rows(db, `select * from stations where fi_id = 'HPA'`);
    expect(hpa).toHaveLength(1);
    expect(hpa[0]).toMatchObject({ id: '740000372', name: 'Haparanda', country: 'SE', tz: 'Europe/Stockholm', trv_signature: 'Hp', fi_uic: 10726 });
    expect(rows(db, `select * from stations where id = 'fi:OL'`)[0]).toMatchObject({ name: 'Oulu', country: 'FI', tz: 'Europe/Helsinki', fi_id: 'OL', fi_uic: 130 });
    // IC 401 ends at the reused Haparanda station.
    const last = rows(db, `select station_id s from timetable_stop_times where trip_key like 'fi:401_%' order by seq desc limit 1`)[0]!;
    expect(last.s).toBe('740000372');
  });

  it('is repeatable: a second run changes nothing', async () => {
    const db = setup();
    await importGtfsFinland(db, ZIP, { today: '2026-11-07', stations: metadata, brands: BRANDS });
    const count = () => rows(db, `select (select count(*) from timetable_trips) t, (select count(*) from timetable_trip_dates) d, (select count(*) from stations) s, (select count(*) from timetable_stop_times) st`)[0];
    const first = count();
    await importGtfsFinland(db, ZIP, { today: '2026-11-07', stations: metadata, brands: BRANDS });
    expect(count()).toEqual(first);
  });

  it('keeps dates from before yesterday when a later import replaces the window', async () => {
    const db = setup();
    await importGtfsFinland(db, ZIP, { today: '2026-11-07', stations: metadata, brands: BRANDS });
    const early = rows(db, `select count(*) n from timetable_trip_dates where service_date = '2026-11-06'`)[0]!.n as number;
    expect(early).toBeGreaterThan(0);
    await importGtfsFinland(db, ZIP, { today: '2026-11-10', stations: metadata, brands: BRANDS });
    expect(rows(db, `select count(*) n from timetable_trip_dates where service_date = '2026-11-06'`)[0]!.n).toBe(early);
    expect(rows(db, `select max(service_date) m from timetable_trip_dates`)[0]!.m).toBe('2026-12-12');
  });

  it('uses no operator when the brand is not in the data yet', async () => {
    const db = setup();
    await importGtfsFinland(db, ZIP, { today: '2026-11-07', stations: metadata, brands: [] });
    expect(rows(db, `select count(*) n from timetable_trips where operator_id is not null`)[0]!.n).toBe(0);
  });
});
