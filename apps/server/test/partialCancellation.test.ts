// A train cancelled for part of its way (build 86): the stop where it turns back or starts again is still served, a
// trip on it is cancelled only when none of its part runs, and the alerts say where it runs to or from. The same rules
// for every country's feed: Trafikverket (Sweden), Rejseplanen (Denmark), Entur (Norway), Digitraffic (Finland).
import { describe, expect, it } from 'vitest';
import { cancellationFor, directions, eventsFor, matchAnnouncements, mergeCanceled, type AnnouncementRow, type StopActuals, type StopForMatch } from '../src/legs/actuals.js';
import { callCanceled, rejseplanenFor, rememberJourney } from '../src/rejseplanen/stops.js';
import type { Journey, RejseplanenClient, Stop } from '../src/rejseplanen/client.js';
import { callsToActuals, type NorwayCall } from '../src/entur/calls.js';
import { digitrafficStops, type StopForDt } from '../src/digitraffic/trains.js';
import { diffEvents, liveView, type LegSummary, type LiveStop } from '../src/live/progress.js';
import { fromEvents, partialLine, type Prefs, type TripFacts } from '../src/push/rules.js';
import type { Db } from '../src/db/client.js';
import { trainFixture } from './finlandFixtures.js';

const T = (hhmm: string) => Date.parse(`2026-11-15T${hhmm}:00+01:00`);
const blank = (seq: number, extra: Partial<StopActuals> = {}): StopActuals => ({
  seq, actualArr: null, actualDep: null, estimatedArr: null, estimatedDep: null, platform: null, canceled: false, deviations: [], causes: [],
  trvTrainNumber: null, composition: null, onboard: null, source: null, ...extra,
});
type Stop4 = { seq: number; stationId: string; role: string; schedArr: number | null; schedDep: number | null };

describe('Sweden (Trafikverket): arrival and departure apart', () => {
  // Øresundståg-shaped: Malmö C → Lund C → Helsingborg C → Ängelholm → Göteborg C, with Halmstad after; it turns at
  // Helsingborg (its arrival runs, its departure and everything after it is cancelled).
  const stops: (StopForMatch & { stationId: string })[] = [
    { seq: 1, role: 'before', sig: 'Kk', stationId: 'Kk', schedArr: null, schedDep: T('09:40') },
    { seq: 2, role: 'board', sig: 'M', stationId: 'M', schedArr: T('09:58'), schedDep: T('10:00') },
    { seq: 3, role: 'through', sig: 'Lu', stationId: 'Lu', schedArr: T('10:11'), schedDep: T('10:12') },
    { seq: 4, role: 'through', sig: 'Hb', stationId: 'Hb', schedArr: T('10:40'), schedDep: T('10:43') },
    { seq: 5, role: 'through', sig: 'Ä', stationId: 'Ä', schedArr: T('11:00'), schedDep: T('11:01') },
    { seq: 6, role: 'alight', sig: 'G', stationId: 'G', schedArr: T('12:40'), schedDep: T('12:45') },
    { seq: 7, role: 'after', sig: 'Fa', stationId: 'Fa', schedArr: T('13:30'), schedDep: null },
  ];
  const row = (sig: string, activity: 'Ankomst' | 'Avgang', at: number, canceled = false): AnnouncementRow => ({
    AdvertisedTrainIdent: '1047', LocationSignature: sig, ActivityType: activity, AdvertisedTimeAtLocation: new Date(at).toISOString(), Canceled: canceled,
  });

  it('looks up only what it did: departures where you can get on, arrivals where you can get off', () => {
    const ev = eventsFor(stops);
    expect(ev.filter((e) => e.seq === 1 || e.seq === 7)).toEqual([]);
    expect(ev.filter((e) => e.seq === 2).map((e) => e.activity)).toEqual(['Avgang']);
    expect(ev.filter((e) => e.seq === 4).map((e) => e.activity)).toEqual(['Ankomst', 'Avgang']);
  });

  it('keeps the turning station served and makes the trip run only to it', () => {
    const rows = [
      row('Kk', 'Avgang', T('09:40')), row('M', 'Ankomst', T('09:58')), row('M', 'Avgang', T('10:00')), row('Lu', 'Ankomst', T('10:11')), row('Lu', 'Avgang', T('10:12')),
      row('Hb', 'Ankomst', T('10:40')), row('Hb', 'Avgang', T('10:43'), true), row('Ä', 'Ankomst', T('11:00'), true), row('Ä', 'Avgang', T('11:01'), true),
      row('G', 'Ankomst', T('12:40'), true), row('G', 'Avgang', T('12:45'), true), row('Fa', 'Ankomst', T('13:30'), true),
    ];
    const m = matchAnnouncements(stops, rows, '1047');
    expect(directions(m.get(4)!)).toEqual({ arr: false, dep: true });
    expect(directions(m.get(2)!)).toEqual({ arr: null, dep: false });
    expect(m.has(7)).toBe(false);
    const run = cancellationFor(stops, m);
    expect([2, 3, 4, 5, 6].map((s) => m.get(s)!.canceled)).toEqual([false, false, false, true, true]);
    // It doesn't leave Helsingborg: it ends there, whatever happens after your stop.
    expect(run).toEqual({ kind: 'partial', runsFrom: null, runsTo: 'Hb', startsThere: false, endsThere: true, gaps: [] });
  });

  it('says it only skips where you get off when the stop after yours is served', () => {
    const rows = [row('M', 'Avgang', T('10:00')), row('Hb', 'Ankomst', T('10:40')), row('Hb', 'Avgang', T('10:43')), row('Ä', 'Ankomst', T('11:00')), row('Ä', 'Avgang', T('11:01')), row('G', 'Ankomst', T('12:40'), true), row('Fa', 'Ankomst', T('13:30'))];
    const run = cancellationFor(stops, matchAnnouncements(stops, rows, '1047'));
    expect(run).toMatchObject({ kind: 'partial', runsTo: 'Ä', endsThere: false });
  });

  it('is a cancelled trip only when nothing of your part runs', () => {
    const rows = [row('M', 'Avgang', T('10:00'), true), row('Lu', 'Ankomst', T('10:11'), true), row('Lu', 'Avgang', T('10:12'), true), row('Hb', 'Ankomst', T('10:40'), true), row('G', 'Ankomst', T('12:40'), true)];
    expect(cancellationFor(stops, matchAnnouncements(stops, rows, '1047'))?.kind).toBe('full');
  });
});

describe('Denmark (Rejseplanen): starts later than where you get on', () => {
  const s = (uic: string, arr: string | null, dep: string | null, arrCancelled = false, depCancelled = false): Stop => ({
    uic, name: uic, lat: null, lon: null, arrPlanned: arr ? T(arr) : null, arrLive: null, depPlanned: dep ? T(dep) : null, depLive: null,
    arrPlatform: null, depPlatform: null, arrPlatformPlanned: null, depPlatformPlanned: null, arrCancelled, depCancelled, prognosis: null,
  });
  // Østerport → København H → Kastrup → Malmö: cancelled to Kastrup, runs from there (arrival there cancelled, departure kept).
  const journey: Journey = {
    jid: 'J1', date: '2026-11-15', name: 'Øresundståg 1047', number: '1047', cancelled: false, notices: [],
    stops: [s('8600650', null, '09:20', false, true), s('8600626', '09:25', '09:28', true, true), s('8600858', '09:40', '09:42', true, false), s('7400003', '10:00', null)],
  } as unknown as Journey;
  const client = { available: () => true, journeyDetails: async () => journey } as unknown as RejseplanenClient;
  const ours: Stop4[] = [
    { seq: 1, stationId: '860000650', role: 'board', schedArr: null, schedDep: T('09:20') },
    { seq: 2, stationId: '860000626', role: 'through', schedArr: T('09:25'), schedDep: T('09:28') },
    { seq: 3, stationId: '860000858', role: 'through', schedArr: T('09:40'), schedDep: T('09:42') },
    { seq: 4, stationId: '740000003', role: 'alight', schedArr: T('10:00'), schedDep: null },
  ];

  it('a stop is cancelled only when each of its arrival and departure is', () => {
    expect(callCanceled(false, journey.stops[2]!)).toBe(false);
    expect(callCanceled(false, journey.stops[1]!)).toBe(true);
    expect(callCanceled(false, journey.stops[0]!)).toBe(true);
    expect(callCanceled(true, journey.stops[3]!)).toBe(true);
  });

  it('starts from Kastrup on your trip', async () => {
    rememberJourney(journey, 'dk:trip');
    const m = await rejseplanenFor(null as unknown as Db, { tripKey: 'dk:trip', trainNumber: '1047', serviceDate: '2026-11-15', stops: ours }, { now: T('09:00'), client });
    expect(directions(m.get(3)!)).toEqual({ arr: true, dep: false });
    const run = cancellationFor(ours, m);
    expect(m.get(3)!.canceled).toBe(false);
    expect(m.get(1)!.canceled).toBe(true);
    expect(run).toMatchObject({ kind: 'partial', runsFrom: '860000858', startsThere: true, runsTo: null });
  });
});

describe('Norway (Entur): one cancellation per call', () => {
  const call = (pos: number, aimedArr: string | null, aimedDep: string | null, canceled: boolean): NorwayCall => ({
    pos, stopPlace: '', aimedArr: aimedArr ? T(aimedArr) : null, aimedDep: aimedDep ? T(aimedDep) : null, expectedArr: null, expectedDep: null, actualArr: null, actualDep: null, platform: null, canceled, realtime: true,
  });
  const ours: Stop4[] = [
    { seq: 1, stationId: 'OSL', role: 'board', schedArr: null, schedDep: T('08:00') },
    { seq: 2, stationId: 'LLS', role: 'through', schedArr: T('08:20'), schedDep: T('08:21') },
    { seq: 3, stationId: 'SKI', role: 'alight', schedArr: T('08:30'), schedDep: T('08:31') },
    { seq: 4, stationId: 'MOSS', role: 'after', schedArr: T('09:00'), schedDep: null },
  ];
  it('ends at Lillestrøm when the calls after it are cancelled, and only skips Ski when Moss is served', () => {
    const ended = callsToActuals(ours, [call(0, null, '08:00', false), call(1, '08:20', '08:21', false), call(2, '08:30', '08:31', true), call(3, '09:00', null, true)]);
    expect(cancellationFor(ours, ended)).toMatchObject({ kind: 'partial', runsTo: 'LLS', endsThere: true });
    const skipped = callsToActuals(ours, [call(0, null, '08:00', false), call(1, '08:20', '08:21', false), call(2, '08:30', '08:31', true), call(3, '09:00', null, false)]);
    expect(cancellationFor(ours, skipped)).toMatchObject({ kind: 'partial', runsTo: 'LLS', endsThere: false });
  });
});

describe('Finland (Digitraffic)', () => {
  const ic142 = trainFixture('ic-142-short-turned');
  const row = (code: string, type: 'ARRIVAL' | 'DEPARTURE') => ic142.timeTableRows.find((r) => r.stationShortCode === code && r.type === type)!;
  it('IC 142 Kuopio → Tampere on 2026-10-23 still runs: not a cancelled trip', () => {
    const ours: (StopForDt & { stationId: string })[] = [
      { seq: 1, role: 'board', sig: null, fi: 'KUO', stationId: 'fi:KUO', schedArr: null, schedDep: Date.parse(row('KUO', 'DEPARTURE').scheduledTime) },
      { seq: 2, role: 'through', sig: null, fi: 'PM', stationId: 'fi:PM', schedArr: Date.parse(row('PM', 'ARRIVAL').scheduledTime), schedDep: Date.parse(row('PM', 'DEPARTURE').scheduledTime) },
      { seq: 3, role: 'through', sig: null, fi: 'HKS', stationId: 'fi:HKS', schedArr: Date.parse(row('HKS', 'ARRIVAL').scheduledTime), schedDep: Date.parse(row('HKS', 'DEPARTURE').scheduledTime) },
      { seq: 4, role: 'through', sig: null, fi: 'JY', stationId: 'fi:JY', schedArr: Date.parse(row('JY', 'ARRIVAL').scheduledTime), schedDep: Date.parse(row('JY', 'DEPARTURE').scheduledTime) },
      { seq: 5, role: 'alight', sig: null, fi: 'TPE', stationId: 'fi:TPE', schedArr: Date.parse(row('TPE', 'ARRIVAL').scheduledTime), schedDep: null },
    ];
    const run = cancellationFor(ours, digitrafficStops(ours, ic142, Date.parse('2026-10-23T12:00:00Z')));
    expect(run?.kind).not.toBe('full');
  });
});

describe('sources merged', () => {
  it('keeps each direction, either source saying cancelled wins, and a one-flag source counts for both', () => {
    const have = blank(1, { arrCanceled: false });
    mergeCanceled(have, blank(1, { depCanceled: true }));
    expect(directions(have)).toEqual({ arr: false, dep: true });
    const legacy = blank(2);
    mergeCanceled(legacy, blank(2, { canceled: true }));
    expect(directions(legacy)).toEqual({ arr: true, dep: true });
  });
});

describe('following a part-way train live', () => {
  const stop = (id: string, lon: number, arr: string | null, dep: string | null, canceled = false): LiveStop => ({
    stationId: id, name: id, lat: 57, lon, schedArr: arr ? T(arr) : null, schedDep: dep ? T(dep) : null, actualArr: null, actualDep: null, estimatedArr: null, estimatedDep: null, platform: null, canceled,
  });
  const line: [number, number][] = [[57, 14.0], [57, 14.1], [57, 14.2], [57, 14.3]];
  it('runs to where it ends instead of reading as cancelled', () => {
    const v = liveView([stop('A', 14.0, null, '10:00'), stop('B', 14.1, '10:10', '10:12'), stop('C', 14.2, '10:22', '10:23', true), stop('D', 14.3, '10:30', null, true)], line, null, T('10:05'));
    expect(v.status).toBe('en_route');
    expect(v.nextStopId).toBe('B');
    expect(v.arrivalEta).toBe(T('10:10'));
  });
  it('is cancelled when nothing of your part runs', () => {
    expect(liveView([stop('A', 14.0, null, '10:00', true), stop('B', 14.1, '10:10', null, true)], line, null, T('09:50')).status).toBe('cancelled');
    // Only one stop of it served: nothing to ride either.
    expect(liveView([stop('A', 14.0, null, '10:00', true), stop('B', 14.1, '10:10', '10:12'), stop('C', 14.2, '10:22', null, true)], line, null, T('09:50')).status).toBe('cancelled');
  });
  it('says where it now ends in the short-turn event', () => {
    const base: LegSummary = { arrivalDelayMin: 0, depPlatform: null, arrPlatform: null, canceled: false, canceledStops: [], departedAt: null, arrivedAt: null };
    const stops = [
      { stationId: 'M', name: 'Malmö C', role: 'board', canceled: false },
      { stationId: 'Hb', name: 'Helsingborg C', role: 'through', canceled: false },
      { stationId: 'G', name: 'Göteborg C', role: 'alight', canceled: true },
    ];
    const [e] = diffEvents(base, { ...base, canceledStops: ['G'], stops });
    expect(e).toEqual({ type: 'short_turned', payload: { stationIds: ['G'], runsFrom: null, runsFromName: null, startsThere: false, runsTo: 'Hb', runsToName: 'Helsingborg C', endsThere: true } });
  });
});

describe('the alert for a part-way train', () => {
  const facts = { from: 'Malmö C', to: 'Göteborg C' } as TripFacts;
  const prefs = { notify: true, notifyCancel: true } as Prefs;
  it('never says cancelled for a train that still runs some of your way', () => {
    const [a] = fromEvents({ ...facts, canceled: false }, [{ type: 'short_turned', payload: { stationIds: ['G'], runsTo: 'Hb', runsToName: 'Helsingborg C', endsThere: true } }], prefs, 'en');
    expect(a!.kind).toBe('cancel');
    expect(a!.body).not.toMatch(/is cancelled/);
    // Without where it ends: the general line.
    expect(partialLine(facts, { stationIds: ['Lu'] }, 'en')).toBe('Some stops on this train are cancelled. Open Clack for the details.');
  });
});
