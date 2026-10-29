import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { REPO_ROOT } from '../src/env.js';
import { matchAnnouncements, type AnnouncementRow, type StopForMatch } from '../src/legs/actuals.js';

const fixture = (n: string) =>
  JSON.parse(fs.readFileSync(path.join(REPO_ROOT, `data/fixtures/trv/2026-10-20/train-${n}.json`), 'utf8')).rows.filter((r: { Advertised: boolean }) => r.Advertised) as AnnouncementRow[];
const at = (hhmm: string) => Date.parse(`2026-10-20T${hhmm}:00+02:00`);

// Snälltåget 306 on 2026-10-20 as the owner rode it: Kolding (DK) 13:01 → Nässjö C 18:25 (timetable).
const leg306: StopForMatch[] = [
  { seq: 2, role: 'board', sig: 'Dk.kd', schedArr: at('13:01'), schedDep: at('13:01') },
  { seq: 5, role: 'through', sig: 'Mc', schedArr: at('15:35'), schedDep: at('16:18') },
  { seq: 6, role: 'through', sig: 'Lu', schedArr: at('16:30'), schedDep: at('16:30') },
  { seq: 7, role: 'through', sig: 'E', schedArr: at('16:41'), schedDep: at('16:41') },
  { seq: 8, role: 'through', sig: 'Hm', schedArr: at('17:05'), schedDep: at('17:05') },
  { seq: 9, role: 'through', sig: 'Av', schedArr: at('17:45'), schedDep: at('17:45') },
  { seq: 10, role: 'alight', sig: 'N', schedArr: at('18:25'), schedDep: at('18:25') },
  { seq: 11, role: 'after', sig: 'Lp', schedArr: at('19:22'), schedDep: at('19:22') },
];

describe('matching Trafikverket announcements to a leg', () => {
  const m = matchAnnouncements(leg306, fixture('306'), '306');

  it('finds the real arrival at Nässjö: 19:04, platform 4, platform-change notice', () => {
    const n = m.get(10)!;
    expect(new Date(n.actualArr!).toISOString()).toBe('2026-10-20T17:04:00.000Z');
    expect(n.platform).toBe('4');
    expect(n.deviations).toContain('Spårändrat');
    expect(n.trvTrainNumber).toBe('306');
  });

  it('has no actual time at Kolding: Trafikverket does not cover Danish stops', () => {
    expect(m.has(2)).toBe(false);
  });

  it('fills the Swedish stops in between and ignores stops after alighting', () => {
    expect(new Date(m.get(5)!.actualDep!).toISOString()).toBe('2026-10-20T14:43:00.000Z');
    expect(m.get(9)!.platform).toBe('2');
    expect(m.has(11)).toBe(false);
  });

  it('ignores another train calling at the same station minute (needs two matching stops)', () => {
    const intruder: AnnouncementRow = { AdvertisedTrainIdent: '9999', LocationSignature: 'N', ActivityType: 'Ankomst', AdvertisedTimeAtLocation: '2026-10-20T18:25:00.000+02:00', TimeAtLocation: '2026-10-20T18:30:00.000+02:00' };
    const only = matchAnnouncements(leg306, [intruder], '306');
    expect(only.size).toBe(0);
  });

  it('ignores a train meeting ours at a station: its arrival and departure there are one stop, not two', () => {
    // SL 2855 southbound and 2858 northbound both call at Vega at 16:15 (2026-10-22).
    const row = (n: string, sig: string, type: 'Ankomst' | 'Avgang', hhmm: string): AnnouncementRow => ({
      AdvertisedTrainIdent: n, LocationSignature: sig, ActivityType: type, AdvertisedTimeAtLocation: `2026-10-20T${hhmm}:00.000+02:00`, TimeAtLocation: `2026-10-20T${hhmm}:30.000+02:00`,
    });
    const leg: StopForMatch[] = [
      { seq: 1, role: 'board', sig: 'Skg', schedArr: null, schedDep: at('16:11') },
      { seq: 2, role: 'through', sig: 'Vga', schedArr: at('16:15'), schedDep: at('16:15') },
      { seq: 3, role: 'alight', sig: 'Hnd', schedArr: at('16:18'), schedDep: null },
    ];
    const rows = [row('2858', 'Vga', 'Ankomst', '16:15'), row('2858', 'Vga', 'Avgang', '16:15'), row('2855', 'Skg', 'Avgang', '16:11'), row('2855', 'Vga', 'Ankomst', '16:15'), row('2855', 'Vga', 'Avgang', '16:15'), row('2855', 'Hnd', 'Ankomst', '16:18')];
    const got = matchAnnouncements(leg, rows, '2855');
    expect([...got.values()].map((g) => g.trvTrainNumber)).toEqual(['2855', '2855', '2855']);
    // Without our number to go by (e.g. a 5-digit timetable number), the train matching more stops wins.
    expect([...matchAnnouncements(leg, rows, null).values()].map((g) => g.trvTrainNumber)).toEqual(['2855', '2855', '2855']);
  });

  it('keeps the planned coach order of the departure, not the arrival', () => {
    const sx = (sig: string, type: 'Ankomst' | 'Avgang', hhmm: string, comp?: string): AnnouncementRow => ({
      AdvertisedTrainIdent: '582',
      LocationSignature: sig,
      ActivityType: type,
      AdvertisedTimeAtLocation: `2026-10-20T${hhmm}:00.000+02:00`,
      ...(comp ? { TrainComposition: [{ Description: comp }] } : {}),
    });
    const leg: StopForMatch[] = [
      { seq: 1, role: 'board', sig: 'Cst', schedArr: null, schedDep: at('10:00') },
      { seq: 2, role: 'alight', sig: 'U', schedArr: at('10:40'), schedDep: null },
    ];
    const got = matchAnnouncements(leg, [sx('Cst', 'Avgang', '10:00', 'Vagnsordning 4-3-2-1'), sx('U', 'Ankomst', '10:40')], '582');
    expect(got.get(1)!.composition).toEqual({ locomotive: false, cars: 4, units: 1, totalCars: 4, unitCars: [4] });
    expect(got.get(2)!.composition).toBeNull();
  });
});
