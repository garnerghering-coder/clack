import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { compareRuns, comparePair, dayToCheck, KIND, PAIRS, runCrossSource, type SourceCall, type SourceRun } from '../src/audit/crossSource.js';
import { writeRaw } from '../src/observed/archive.js';
import { saveRuns, type ObservedRun } from '../src/observed/store.js';

const T = (hhmm: string) => Date.parse(`2026-11-05T${hhmm}:00Z`);
const M = 60_000;
const call = (o: Partial<SourceCall> & { location: string }): SourceCall => ({ stationId: null, schedArr: null, schedDep: null, actualArr: null, actualDep: null, canceledArr: false, canceledDep: false, ...o });
const run = (source: string, trainNumber: string, calls: SourceCall[], canceled = 0): SourceRun => ({ source, runId: trainNumber, trainNumber, canceled, calls });

// Öresundståg 1072 on 2026-11-05 at Hyllie: Trafikverket says it arrived 19:41:20 and left 19:43:05 (UTC); the Danish
// archive, in whole minutes, 19:41 and 19:43. At København H only the archive has a time.
const trv = run('trafikverket', '1072', [
  call({ location: 'Hie', stationId: '740001586', schedArr: T('19:38'), schedDep: T('19:40'), actualArr: T('19:41') + 20_000, actualDep: T('19:43') + 5_000 }),
]);
const dk = run('train_archive_dk', '1072', [
  call({ location: '000007401585', stationId: '740001586', schedArr: T('19:38'), schedDep: T('19:40'), actualArr: T('19:41'), actualDep: T('19:43') }),
  call({ location: '000008600626', stationId: '860000626', schedArr: T('20:16'), actualArr: T('20:21') }),
]);

describe('comparing two sources on one run', () => {
  it('agrees within a minute, counts the run-level cancellation once, and ignores stops only one side has', () => {
    const c = compareRuns('2026-11-05', trv, dk);
    expect(c).toMatchObject({ agree: 3, disagree: 0, missing: 0, differences: [] });
  });

  it('says what differs: the station, the field, both values and both sources', () => {
    const late = run('train_archive_dk', '1072', [call({ ...dk.calls[0]!, actualArr: T('19:45') })]);
    const c = compareRuns('2026-11-05', trv, late);
    expect(c.agree).toBe(2);
    expect(c.disagree).toBe(1);
    expect(c.differences).toEqual([{ train: '1072', date: '2026-11-05', station: '740001586', field: 'arr', verdict: 'disagree', a: '19:41', b: '19:45', sources: ['trafikverket', 'train_archive_dk'] }]);
  });

  it('counts a time one side lacks as missing, and a cancellation the sides disagree on', () => {
    const silent = run('train_archive_dk', '1072', [call({ ...dk.calls[0]!, actualArr: null, canceledDep: true })], 1);
    const c = compareRuns('2026-11-05', trv, silent);
    expect(c).toMatchObject({ agree: 1, disagree: 2, missing: 1 });
    expect(c.differences.map((d) => [d.field, d.verdict, d.a, d.b])).toEqual([
      ['arr', 'missing', '19:41', null],
      ['canceled', 'disagree', 'no', 'yes'],
      ['canceled', 'disagree', 'no', 'yes'],
    ]);
  });

  it('aligns calls by scheduled minute when one side has no station (the archive read raw)', () => {
    const noStation = run('entur-bigquery', '62', [call({ location: 'NSR:Quay:1', schedArr: T('19:38'), schedDep: T('19:40'), actualArr: T('19:41') + 50_000 })]);
    const live = run('entur', '62', [call({ location: 'NSR:Quay:1', stationId: 'NSR:StopPlace:1', schedArr: T('19:38'), schedDep: T('19:40'), actualArr: T('19:41'), actualDep: T('19:43') })]);
    const c = compareRuns('2026-11-05', live, noStation);
    expect(c).toMatchObject({ agree: 2, disagree: 0, missing: 1 });
    expect(c.differences[0]).toMatchObject({ field: 'dep', station: 'NSR:StopPlace:1', a: '19:43', b: null });
  });

  it('sums a pair up: runs in both, only in one, and the counts', () => {
    const r = comparePair(PAIRS.oresund, '2026-11-05', [trv, run('trafikverket', '1074', [])], [dk, run('train_archive_dk', '1076', [])], (x) => x.trainNumber);
    expect(r.summary).toEqual({ pair: 'trafikverket~train_archive_dk', date: '2026-11-05', runs: { both: 1, onlyA: 1, onlyB: 1 }, agree: 3, disagree: 0, missing: 0 });
  });

  it('checks the day before yesterday, when every feed has fetched it', () => {
    expect(dayToCheck(Date.parse('2026-11-08T02:30:00Z'))).toBe('2026-11-06');
  });
});

const observed = (o: Partial<ObservedRun> & Pick<ObservedRun, 'country' | 'runId' | 'source' | 'trainNumber'>): ObservedRun => ({
  serviceDate: '2026-11-05',
  operator: null,
  product: null,
  canceled: 0,
  info: {},
  passages: [],
  final: true,
  calls: [],
  ...o,
});
const oc = (seq: number, c: SourceCall) => ({ seq, platform: null, estArr: null, estDep: null, causes: [], extra: {}, ...c });

describe('the nightly check end to end', () => {
  const roots: string[] = [];
  afterEach(() => {
    for (const r of roots) fs.rmSync(r, { recursive: true, force: true });
  });

  it('writes a summary and the differences per pair and day to diagnostics, and runs again without doubling', async () => {
    const db = openDb(':memory:');
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'clack-xs-'));
    roots.push(root);
    saveRuns(db, [
      observed({ country: 'SE', runId: '1072', source: 'trafikverket', trainNumber: '1072', calls: trv.calls.map((c, i) => oc(i + 1, c)) }),
      observed({ country: 'DK', runId: '168912999', source: 'train_archive_dk', trainNumber: '1072', info: { matchedBy: 'se-stop-times' }, calls: dk.calls.map((c, i) => oc(i + 1, { ...c, actualArr: i === 0 ? T('19:47') : c.actualArr })) }),
      observed({ country: 'DK', runId: '168913000', source: 'train_archive_dk', trainNumber: '1080', info: { matchedBy: 'se-stop-times' }, calls: [] }),
      // A Danish train whose number a Swedish one shares (NT 75 and a Pågatåg): named by gtfs_dk, so not compared.
      observed({ country: 'DK', runId: '168913001', source: 'train_archive_dk', trainNumber: '75', info: { matchedBy: 'gtfs_dk' }, calls: [] }),
      observed({ country: 'SE', runId: '75', source: 'trafikverket', trainNumber: '75', calls: [] }),
      observed({ country: 'DK', runId: '169', source: 'train_archive_dk', trainNumber: null, calls: [] }),
      // Norway: Vy 62 recorded live; the archive's version (raw rows as BigQuery sends them) has the stop a minute later.
      observed({ country: 'NO', runId: 'VYG:62', source: 'entur', trainNumber: '62', calls: [oc(1, call({ location: 'NSR:Quay:1', stationId: 'p1', schedDep: T('10:00'), actualDep: T('10:00') })), oc(2, call({ location: 'NSR:Quay:2', stationId: 'p2', schedArr: T('11:00'), actualArr: T('11:02') }))] }),
    ]);
    const bqRow = (seq: string, o: Record<string, string | null>) => ({ serviceJourneyId: 'VYG:ServiceJourney:62-1', datedServiceJourneyId: 'VYG:DatedServiceJourney:62_OSL-BRG_26-11-05', operatorRef: 'VYG:Operator:VY', lineRef: 'VYG:Line:F4', sequenceNr: seq, estimated: 'false', stopCancellation: 'false', journeyCancellation: 'false', aimedArrivalTime: null, aimedDepartureTime: null, arrivalTime: null, departureTime: null, ...o });
    await writeRaw('entur-bigquery', '2026-11-05', 'siri-et', [
      bqRow('1', { stopPointRef: 'NSR:Quay:1', aimedDepartureTime: String(T('10:00') / 1000), departureTime: String(T('10:00') / 1000) }),
      bqRow('2', { stopPointRef: 'NSR:Quay:2', aimedArrivalTime: String(T('11:00') / 1000), arrivalTime: String(T('11:04') / 1000) }),
    ], { root });

    const summaries = await runCrossSource(db, { date: '2026-11-05', observedRoot: root });
    expect(summaries).toEqual([
      { pair: PAIRS.oresund, date: '2026-11-05', runs: { both: 1, onlyA: 0, onlyB: 1 }, agree: 2, disagree: 1, missing: 0 },
      { pair: PAIRS.norway, date: '2026-11-05', runs: { both: 1, onlyA: 0, onlyB: 0 }, agree: 2, disagree: 1, missing: 0 },
    ]);
    const rows = () => db.$client.prepare(`select build, signature, count from diagnostics where day = '2026-11-05' and kind = ? order by build, signature`).all(KIND) as { build: string; signature: string; count: number }[];
    const first = rows();
    expect(first).toHaveLength(4);
    expect(first.find((r) => r.build === PAIRS.oresund && r.signature.startsWith('summary '))!.signature).toBe('summary {"runs":{"both":1,"onlyA":0,"onlyB":1},"agree":2,"disagree":1,"missing":0}');
    expect(JSON.parse(first.find((r) => r.build === PAIRS.norway && !r.signature.startsWith('summary'))!.signature)).toEqual({ train: '62', station: 'p2', field: 'arr', verdict: 'disagree', a: '11:02', b: '11:04', sources: ['entur', 'entur-bigquery'] });
    await runCrossSource(db, { date: '2026-11-05', observedRoot: root });
    expect(rows()).toEqual(first);
  });

  it('says when a side has nothing for the day', async () => {
    const db = openDb(':memory:');
    const [oresund, norway] = await runCrossSource(db, { date: '2026-11-05', observedRoot: path.join(os.tmpdir(), 'clack-xs-none') });
    expect(oresund!.note).toBe("no Danish runs named from Sweden's feed for the day");
    expect(norway!.note).toBe('no BigQuery archive file for the day');
    expect(norway!.runs).toEqual({ both: 0, onlyA: 0, onlyB: 0 });
  });
});
