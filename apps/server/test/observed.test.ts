import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { readRaw, rawFiles, writeRaw } from '../src/observed/archive.js';
import { project as projectBigQuery } from '../src/observed/bigquery.js';
import { project as projectFinland } from '../src/observed/finland.js';
import { project as projectNorway, runIdOf, type JpJourney } from '../src/observed/norway.js';
import { cancelLevel, passage, saveRuns, type ObservedRun } from '../src/observed/store.js';
import { project as projectSweden, productOf, type Announcement } from '../src/observed/sweden.js';

// Shapes taken from real answers (Trafikverket and Digitraffic 2026-10-25, Entur 2026-10-26), cut down.
const trv = (o: Partial<Announcement>): Announcement =>
  ({
    ActivityType: 'Avgang',
    Advertised: true,
    AdvertisedTrainIdent: '537',
    LocationSignature: 'Cst',
    AdvertisedTimeAtLocation: '2026-10-25T13:20:00.000+01:00',
    ScheduledDepartureDateTime: '2026-10-25T00:00:00.000+02:00',
    Canceled: false,
    Deleted: false,
    Operator: 'SJ',
    ProductInformation: [{ Code: 'PNA014', Description: 'SJ Snabbtåg' }],
    ActivityId: 'x',
    WebLink: 'http://www.sj.se',
    ...o,
  }) as Announcement;

describe('Sweden (Trafikverket)', () => {
  const rows = [
    trv({ TimeAtLocationWithSeconds: '2026-10-25T13:20:36.000+01:00', TimeAtLocation: '2026-10-25T13:20:00.000+01:00', TrackAtLocation: '11', OperationalTransportIdentifiers: [{ ObjectType: 'TR', Core: '537' }] }),
    trv({ Advertised: false, ActivityType: 'Avgang', LocationSignature: 'Sci', AdvertisedTimeAtLocation: '2026-10-25T13:24:00.000+01:00', TimeAtLocation: '2026-10-25T13:25:00.000+01:00' }),
    trv({ ActivityType: 'Ankomst', LocationSignature: 'Söö', AdvertisedTimeAtLocation: '2026-10-25T13:40:00.000+01:00', TimeAtLocation: '2026-10-25T13:44:00.000+01:00', TrackAtLocation: 'x' }),
    trv({ LocationSignature: 'Söö', AdvertisedTimeAtLocation: '2026-10-25T13:41:00.000+01:00', TrackAtLocation: '8', Deviation: [{ Code: 'ANA055', Description: 'Spårändrat' }], OtherInformation: [{ Code: 'ONA124', Description: 'Buss ers.' }], OperationalTransportIdentifiers: [{ ObjectType: 'PA', Core: '6185' }] }),
    trv({ ActivityType: 'Ankomst', LocationSignature: 'M', AdvertisedTimeAtLocation: '2026-10-25T17:50:00.000+01:00', TimeAtLocation: '2026-10-25T18:23:00.000+01:00', TrackAtLocation: '2b' }),
    // A freight train: no announced stop, so raw archive only.
    trv({ AdvertisedTrainIdent: '41234', Advertised: false, LocationSignature: 'Hgl' }),
  ];
  const runs = projectSweden('2026-10-25', rows, new Map([['Cst', '740000001']]), false);

  it('makes one run per passenger train, stops merged per place, passages kept apart', () => {
    expect(runs.map((r) => r.runId)).toEqual(['537']);
    const r = runs[0]!;
    expect(r.calls.map((c) => c.location)).toEqual(['Cst', 'Söö', 'M']);
    expect(r.calls[0]!.stationId).toBe('740000001');
    expect(r.calls[0]!.actualDep).toBe(Date.parse('2026-10-25T13:20:36.000+01:00'));
    expect(r.calls[1]!.platform).toBe('8');
    expect(r.calls[1]!.causes).toEqual([{ src: 'trv', code: 'ANA055', text: 'Spårändrat' }]);
    expect(r.passages).toEqual([['Sci', 'D', Date.parse('2026-10-25T13:24:00.000+01:00') / 1000, 60]]);
  });

  it('keeps run-wide fields once, the railway ids as a set, and per-stop extras with their stop', () => {
    const r = runs[0]!;
    expect(r.operator).toBe('SJ');
    expect(r.product).toBe('SJ Snabbtåg');
    expect(r.info.OperationalTransportIdentifiers).toHaveLength(2);
    expect(r.calls[1]!.extra.d).toMatchObject({ OtherInformation: [{ Code: 'ONA124', Description: 'Buss ers.' }] });
    // Bookkeeping stays in the raw archive.
    expect(JSON.stringify(r)).not.toContain('ActivityId');
    expect(JSON.stringify(r)).not.toContain('WebLink');
  });

  it('names the product, not the line number', () => {
    expect(productOf([{ Code: 'PNA091', Description: '43' }, { Code: 'PNA054', Description: 'SL Pendeltåg' }])).toBe('SL Pendeltåg');
  });
});

describe('Finland (Digitraffic)', () => {
  const row = (o: Record<string, unknown>) => ({ type: 'DEPARTURE', stationShortCode: 'HKI', stationUICCode: 1, countryCode: 'FI', scheduledTime: '2026-10-25T04:54:00.000Z', trainStopping: true, commercialStop: true, cancelled: false, causes: [], ...o });
  const trains = [
    {
      trainNumber: 1,
      departureDate: '2026-10-25',
      operatorShortCode: 'vr',
      trainType: 'S',
      trainCategory: 'Long-distance',
      commuterLineID: '',
      cancelled: false,
      timeTableRows: [
        row({ actualTime: '2026-10-25T04:54:30.000Z', commercialTrack: '9', differenceInMinutes: 0 }),
        row({ type: 'ARRIVAL', stationShortCode: 'PSL', scheduledTime: '2026-10-25T04:59:00.000Z', trainStopping: false, commercialStop: false, actualTime: '2026-10-25T05:00:00.000Z' }),
        row({ type: 'ARRIVAL', stationShortCode: 'JNS', scheduledTime: '2026-10-25T09:36:00.000Z', actualTime: '2026-10-25T09:40:00.000Z', commercialTrack: '2', causes: [{ categoryCode: 'L', detailedCategoryCode: 'L2', thirdCategoryCode: 'L201' }], stopSector: 'C2' }),
      ],
    },
    { trainNumber: 5000, departureDate: '2026-10-25', trainType: 'T', trainCategory: 'Cargo', timeTableRows: [row({})] },
  ];
  const comps = [{ trainNumber: 1, departureDate: '2026-10-25', version: 7, journeySections: [{ wagons: [{ wagonType: 'Sm3', pet: true }] }] }];
  const runs = projectFinland('2026-10-25', trains as never, comps, new Map([['HKI', 'fi:HKI']]), true);

  it('keeps passenger trains, stops vs passages, the most specific cause and the composition', () => {
    expect(runs.map((r) => r.runId)).toEqual(['1']);
    const r = runs[0]!;
    expect(r.calls.map((c) => c.location)).toEqual(['HKI', 'JNS']);
    expect(r.passages).toEqual([passage('PSL', 'A', Date.parse('2026-10-25T04:59:00.000Z'), Date.parse('2026-10-25T05:00:00.000Z'))]);
    expect(r.calls[1]!.causes).toEqual([{ src: 'dt', code: 'L201' }]);
    expect(r.calls[1]!.extra.a).toMatchObject({ stopSector: 'C2', causes: [{ thirdCategoryCode: 'L201' }] });
    expect(r.calls[0]!.extra).toEqual({});
    expect(r.info.composition).toMatchObject({ version: 7 });
    expect(r.final).toBe(true);
  });
});

describe('Norway (Journey Planner and BigQuery)', () => {
  const call = (o: Record<string, unknown>) => ({
    stopPositionInPattern: 0,
    aimedArrivalTime: null,
    aimedDepartureTime: null,
    expectedArrivalTime: null,
    expectedDepartureTime: null,
    actualArrivalTime: null,
    actualDepartureTime: null,
    cancellation: false,
    realtime: true,
    quay: { id: 'NSR:Quay:554', publicCode: '3', stopPlace: { id: 'NSR:StopPlace:337' } },
    ...o,
  });
  const journey: JpJourney = {
    id: 'VYG:ServiceJourney:61-LOD_617015-R',
    privateCode: '61',
    line: { id: 'VYG:Line:F4', publicCode: 'F4' },
    estimatedCalls: [
      call({ aimedDepartureTime: '2026-10-26T06:25:00+01:00', actualDepartureTime: '2026-10-26T06:25:30+01:00' }),
      call({ aimedArrivalTime: '2026-10-26T13:00:00+01:00', expectedArrivalTime: '2026-10-26T13:05:00+01:00', actualArrivalTime: '2026-10-26T13:04:00+01:00', situations: [{ situationNumber: 'VYG:SituationNumber:1', summary: [{ value: 'Signalfeil', language: 'no' }] }], quay: { id: 'NSR:Quay:1', publicCode: '5', stopPlace: { id: 'NSR:StopPlace:548' } } }),
    ] as never,
  };

  it('ids runs by codespace and number, and never stores a future "actual" as one', () => {
    expect(runIdOf(journey.id, '61')).toBe('VYG:61');
    const r = projectNorway('2026-10-26', journey, new Map([['NSR:StopPlace:337', '760000100']]), Date.parse('2026-10-26T12:00:00+01:00'))!;
    expect(r.runId).toBe('VYG:61');
    expect(r.product).toBe('F4');
    expect(r.calls[0]!.stationId).toBe('760000100');
    expect(r.calls[0]!.actualDep).toBe(Date.parse('2026-10-26T06:25:30+01:00'));
    // Arrival at 13:04 seen at 12:00 is a forecast.
    expect(r.calls[1]!.actualArr).toBeNull();
    expect(r.calls[1]!.estArr).toBe(Date.parse('2026-10-26T13:05:00+01:00'));
    expect(r.calls[1]!.causes).toEqual([{ src: 'entur', code: 'VYG:SituationNumber:1', text: 'Signalfeil' }]);
  });

  it("keeps BigQuery's estimated times out of actual times", () => {
    const rows = [
      { datedServiceJourneyId: 'd1', serviceJourneyId: 'VYG:ServiceJourney:61-LOD_617015-R', sequenceNr: '1', stopPointRef: 'NSR:Quay:554', aimedDepartureTime: '2026-10-24T05:25:00Z', departureTime: '2026-10-24T05:26:00Z', estimated: 'false', dataSource: 'VYG', lineRef: 'VYG:Line:F4' },
      { datedServiceJourneyId: 'd1', serviceJourneyId: 'VYG:ServiceJourney:61-LOD_617015-R', sequenceNr: '2', stopPointRef: 'NSR:Quay:1', aimedArrivalTime: '2026-10-24T12:00:00Z', arrivalTime: '2026-10-24T12:00:00Z', estimated: 'true', dataSource: 'VYG', lineRef: 'VYG:Line:F4' },
    ];
    const [r] = projectBigQuery('2026-10-24', rows as never, new Map([['NSR:Quay:554', ['3', 'NSR:StopPlace:337']]]), new Map([['NSR:StopPlace:337', '760000100']]));
    expect(r!.runId).toBe('VYG:61');
    expect(r!.calls[0]).toMatchObject({ actualDep: Date.parse('2026-10-24T05:26:00Z'), platform: '3', stationId: '760000100' });
    expect(r!.calls[1]).toMatchObject({ actualArr: null, estArr: Date.parse('2026-10-24T12:00:00Z') });
  });
});

describe('the record', () => {
  it('writes raw files once and reads them back intact', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'obs-'));
    const recs = [{ a: 1, s: 'Göteborg' }, { b: [1, 2] }];
    writeRaw('test', '2026-10-25', 'trains', recs, { root, now: 0 });
    writeRaw('test', '2026-10-25', 'trains', recs, { root, now: 0 });
    const files = rawFiles('test', '2026-10-25', 'trains', root);
    expect(files).toHaveLength(2);
    expect(readRaw(files[0]!)).toEqual(recs);
  });

  it('never replaces a final run with a later non-final one, nor our own Norwegian record with the archive', () => {
    const db = openDb(':memory:');
    const run = (o: Partial<ObservedRun>): ObservedRun => ({ country: 'NO', serviceDate: '2026-10-24', runId: 'VYG:61', trainNumber: '61', source: 'entur', operator: 'VYG', product: 'F4', canceled: 0, info: {}, passages: [], calls: [], final: false, ...o });
    saveRuns(db, [run({ final: true, product: 'kept' })]);
    expect(saveRuns(db, [run({ product: 'later' })])).toBe(0);
    saveRuns(db, [run({ runId: 'VYG:62', product: 'ours' })]);
    expect(saveRuns(db, [run({ runId: 'VYG:62', source: 'entur-bigquery', final: true, product: 'archive' })], Date.now(), { keepSources: ['entur'] })).toBe(0);
    const products = db.$client.prepare(`select run_id, product from observed_runs order by run_id`).all();
    expect(products).toEqual([
      { run_id: 'VYG:61', product: 'kept' },
      { run_id: 'VYG:62', product: 'ours' },
    ]);
  });

  it('calls a train cancelled throughout only when every stop is', () => {
    const c = (a: boolean, d: boolean) => ({ canceledArr: a, canceledDep: d }) as never;
    expect(cancelLevel([c(false, true), c(true, true), c(true, false)])).toBe(2);
    expect(cancelLevel([c(false, false), c(true, true), c(true, false)])).toBe(1);
    expect(cancelLevel([c(false, false), c(false, false)])).toBe(0);
  });
});
