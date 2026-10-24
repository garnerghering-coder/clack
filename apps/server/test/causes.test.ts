import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { causeText, delayReasons } from '@clack/shared';
import { REPO_ROOT } from '../src/env.js';
import { normalizeBoard, type TrvBoardRow } from '../src/boards/board.js';
import { normalizeNorwayBoard, type JpBoardCall } from '../src/boards/norway.js';
import { callsToActuals, type NorwayCall } from '../src/entur/calls.js';
import { digitrafficCauses, enturCauses, parseCauses, pickSummary, trvCauses } from '../src/legs/causes.js';
import { matchAnnouncements, type AnnouncementRow, type StopForMatch } from '../src/legs/actuals.js';

const table = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'data/delay_causes.json'), 'utf8'));

describe('Trafikverket causes', () => {
  it('keeps the code next to the text', () => {
    expect(trvCauses([{ Code: 'ANA030', Description: 'Inväntat tåg' }, { Code: 'ANA030', Description: 'Inväntat tåg' }, { Description: 'Hpl C' }])).toEqual([
      { src: 'trv', code: 'ANA030', text: 'Inväntat tåg' },
      { src: 'trv', text: 'Hpl C' },
    ]);
    expect(trvCauses(undefined)).toEqual([]);
  });
  it('maps every code in the table to its official Swedish text and a key', () => {
    expect(table.trv.ANA015).toMatchObject({ key: 'cause.powerFault', sv: 'Elfel' });
    expect(table.trv.ANA034).toMatchObject({ key: 'cause.vehicleFault', sv: 'Fordonsfel' });
    expect(table.trv.ANA030.kind).toBe('cause');
    expect(table.trv.ANA055.kind).toBe('notice');
    expect(Object.keys(table.trv).length).toBeGreaterThan(70);
    // Bus-stop and gate names (ANA200 and up) are not causes.
    expect(Object.keys(table.trv).filter((c) => Number(c.slice(3)) >= 200)).toEqual([]);
  });
  it('shows the cause in the app language, by code, by text, or as written', () => {
    const [c] = trvCauses([{ Code: 'ANA015', Description: 'Elfel' }]);
    expect(causeText(c!, 'en')).toBe('Power fault');
    expect(causeText(c!, 'sv')).toBe('Elfel');
    expect(causeText({ src: 'trv', text: 'Växelfel' }, 'en')).toBe('Points failure');
    expect(causeText({ src: 'trv', code: 'ANA777', text: 'Okänd' }, 'en')).toBe('Okänd');
    expect(delayReasons(trvCauses([{ Code: 'ANA064', Description: 'Tågmöte' }, { Code: 'ANA055', Description: 'Spårändrat' }]), 'en')).toEqual(['trains meeting']);
  });
});

describe('Digitraffic causes', () => {
  it('takes the most specific code of each cause', () => {
    expect(
      digitrafficCauses([
        { categoryCode: 'P', detailedCategoryCode: 'P1', thirdCategoryCode: 'P109' },
        { categoryCode: 'L', detailedCategoryCode: 'L2' },
        { categoryCode: 'I' },
        { categoryCode: 'I' },
        {},
      ]),
    ).toEqual([
      { src: 'digitraffic', code: 'P109' },
      { src: 'digitraffic', code: 'L2' },
      { src: 'digitraffic', code: 'I' },
    ]);
    expect(digitrafficCauses(null)).toEqual([]);
  });
  it('falls back from the third level to the detailed level to the category', () => {
    expect(causeText({ src: 'digitraffic', code: 'P109' }, 'en')).toBe('Points failure');
    expect(causeText({ src: 'digitraffic', code: 'P105' }, 'en')).toBe('Infrastructure fault');
    expect(causeText({ src: 'digitraffic', code: 'P105' }, 'sv')).toBe('Anläggningsfel');
    expect(causeText({ src: 'digitraffic', code: 'H1' }, 'en')).toBe('Staff-related');
  });
  it('keeps the Finnish name for every code and marks our translations unverified', () => {
    for (const e of Object.values(table.dt) as { fi: string; key: string | null; verified?: boolean }[]) {
      expect(e.fi).toBeTruthy();
      if (e.key) expect(e.verified).toBe(false);
    }
    expect(Object.keys(table.dt).length).toBe(15 + 47 + 112);
  });
});

describe('Entur causes', () => {
  const summary = [
    { value: 'Forsinkelse', language: 'no' },
    { value: 'Delay', language: 'en' },
  ];
  it('prefers the app language, then English, then the first', () => {
    expect(pickSummary(summary, 'en')).toBe('Delay');
    expect(pickSummary(summary, 'sv')).toBe('Delay');
    expect(pickSummary(summary, 'no')).toBe('Forsinkelse');
    expect(pickSummary([{ value: 'Forsinkelse', language: 'no' }], 'en')).toBe('Forsinkelse');
    expect(pickSummary([], 'en')).toBeNull();
    expect(enturCauses([{ summary }, { summary }], 'sv')).toEqual([{ src: 'entur', text: 'Delay' }]);
  });
  const jp = (p: Partial<JpBoardCall> = {}): JpBoardCall => ({
    aimedArrivalTime: null,
    aimedDepartureTime: '2026-10-22T08:00:00+02:00',
    expectedArrivalTime: null,
    expectedDepartureTime: '2026-10-22T08:04:00+02:00',
    actualArrivalTime: null,
    actualDepartureTime: null,
    cancellation: false,
    quay: { publicCode: '3' },
    destinationDisplay: { frontText: 'Bergen', via: [] },
    situations: [{ summary }],
    serviceJourney: { id: 'VYG:ServiceJourney:61-LOD_1-R', privateCode: '61', quays: [{ name: 'Oslo S' }] },
    date: '2026-10-22',
    ...p,
  });
  it('is on Norwegian board rows, in the chosen language, beside the plain deviations', () => {
    const ctx = { type: 'departures' as const, now: 0, calls: [], memory: new Map() };
    const [row] = normalizeNorwayBoard([jp()], ctx);
    expect(row).toMatchObject({ deviations: ['Delay'], causes: [{ src: 'entur', text: 'Delay' }] });
    const [no] = normalizeNorwayBoard([jp()], { ...ctx, memory: new Map(), language: 'no' });
    expect(no!.causes).toEqual([{ src: 'entur', text: 'Forsinkelse' }]);
  });
  it('is on a Norwegian train’s stops', () => {
    const call: NorwayCall = { pos: 0, stopPlace: 'NSR:StopPlace:1', aimedArr: null, aimedDep: Date.parse('2026-10-22T06:00:00Z'), expectedArr: null, expectedDep: null, actualArr: null, actualDep: null, platform: null, canceled: false, realtime: true, situations: [{ summary }] };
    const m = callsToActuals([{ seq: 1, schedArr: null, schedDep: call.aimedDep, nsrId: 'NSR:StopPlace:1' }], [call], Date.now());
    expect(m.get(1)).toMatchObject({ deviations: ['Delay'], causes: [{ src: 'entur', text: 'Delay' }] });
  });
});

describe('structured causes from the normalisers', () => {
  it('Trafikverket announcements keep the code on the stop', () => {
    const rows = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'data/fixtures/trv/2026-10-20/train-306.json'), 'utf8')).rows.filter((r: { Advertised: boolean }) => r.Advertised) as AnnouncementRow[];
    const at = (hhmm: string) => Date.parse(`2026-10-20T${hhmm}:00+02:00`);
    const stops: StopForMatch[] = [
      { seq: 5, role: 'through', sig: 'Mc', schedArr: at('15:35'), schedDep: at('16:18') },
      { seq: 10, role: 'alight', sig: 'N', schedArr: at('18:25'), schedDep: at('18:25') },
    ];
    const n = matchAnnouncements(stops, rows, '306').get(10)!;
    expect(n.deviations).toContain('Spårändrat');
    expect(n.causes).toContainEqual({ src: 'trv', code: 'ANA055', text: 'Spårändrat' });
  });
  it('board rows keep codes but leave the platform change to platformChange', () => {
    const row = {
      ActivityId: 'a', ActivityType: 'Avgang', AdvertisedTimeAtLocation: '2026-10-22T10:00:00.000+02:00', AdvertisedTrainIdent: '1', LocationSignature: 'Cst',
      Deviation: [{ Code: 'ANA055', Description: 'Spårändrat' }, { Code: 'ANA050', Description: 'Signalfel' }],
    } as unknown as TrvBoardRow;
    const [r] = normalizeBoard([row], { type: 'departures', now: 0, names: (s) => s, matchBrand: () => null, calls: [], memory: new Map() });
    expect(r!.causes).toEqual([{ src: 'trv', code: 'ANA050', text: 'Signalfel' }]);
    expect(r!.deviations).toEqual(['Signalfel']);
  });
  it('rows saved before causes existed fall back to their plain texts', () => {
    expect(parseCauses(null, ['Elfel'])).toEqual([{ src: 'trv', text: 'Elfel' }]);
    expect(parseCauses('[{"src":"trv","code":"ANA015"}]', ['Elfel'])).toEqual([{ src: 'trv', code: 'ANA015' }]);
    expect(parseCauses('not json', [])).toEqual([]);
  });
});
