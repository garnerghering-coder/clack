// Denmark's timetable import. The zip in fixtures/ is a cut-down copy of Rejseplanen's GTFS (2026-10-27): one DSB
// InterCity, one S-tog, one Lokaltog train, RegioJet's Prague train, a Metro trip, and two Öresundståg runs (one into
// Sweden, one within Denmark).
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { stations } from '../src/db/schema.js';
import { cleanDanishName, danishCategory, danishStationId, danishTrainNumber, importGtfsDenmark, uicOf } from '../src/import/gtfs-dk.js';

const ZIP = path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures/gtfs-dk-mini.zip');

describe("Rejseplanen's ids and names", () => {
  it('reads train numbers without their zero padding', () => {
    expect(danishTrainNumber('000100')).toBe('100');
    expect(danishTrainNumber('005701')).toBe('5701');
    expect(danishTrainNumber('1022')).toBe('1022');
    expect(danishTrainNumber('')).toBeNull();
    expect(danishTrainNumber('000000')).toBeNull();
  });

  it('keys Danish stations by UIC number the way Sweden\'s feed does', () => {
    expect(uicOf('000008600626')).toBe('8600626');
    expect(danishStationId('8600626')).toBe('860000626');
    expect(uicOf('Kh')).toBeNull();
    expect(cleanDanishName('Odense St.')).toBe('Odense');
    expect(cleanDanishName('København H')).toBe('København H');
  });

  it('calls the S-tog commuter, IC intercity (night when late and long), the rest regional', () => {
    expect(danishCategory('109', 'A', 5 * 3600, 6 * 3600)).toBe('commuter');
    expect(danishCategory('2', 'IC', 8 * 3600, 11 * 3600)).toBe('intercity');
    expect(danishCategory('2', 'RJ', 21 * 3600, 33 * 3600)).toBe('night');
    expect(danishCategory('2', 'RE', 8 * 3600, 9 * 3600)).toBe('regional');
    expect(danishCategory('2', '930R', 8 * 3600, 9 * 3600)).toBe('regional');
  });
});

describe('importing Rejseplanen', () => {
  it('keeps Danish trains and the S-tog, leaves trains that also run in Sweden to its feed, and no Metro', async () => {
    const db = openDb(':memory:');
    // København H as Sweden's feed already has it.
    db.insert(stations).values({ id: '860000626', name: 'København H', country: 'DK', lat: 55.672778, lon: 12.564444, tz: 'Europe/Copenhagen', trvSignature: 'Dk.kh' }).run();
    const r = await importGtfsDenmark(db, ZIP, { today: '2026-10-28' });
    expect(r.excluded.abroad).toBe(1);
    const trips = db.$client.prepare(`select train_number n, operator_id op, category c, line from timetable_trips where source = 'gtfs_dk' order by n`).all();
    expect(trips).toEqual([
      { n: '100', op: 'dsb', c: 'intercity', line: 'IC' },
      { n: '1054', op: 'oresundstag', c: 'regional', line: '805' },
      { n: '250004', op: 'lokaltog', c: 'regional', line: '930R' },
      { n: '382', op: null, c: expect.any(String), line: 'RJ' },
      { n: '611215', op: 'dsb', c: 'commuter', line: 'A' },
    ]);
    // København H kept its id and name; new Danish stations take their UIC-based id, without "St.".
    const kh = db.$client.prepare(`select count(*) n from timetable_stop_times where station_id = '860000626'`).get() as { n: number };
    expect(kh.n).toBeGreaterThan(0);
    const odense = db.$client.prepare(`select id, name, country, tz from stations where id = '860000512'`).get();
    expect(odense).toEqual({ id: '860000512', name: 'Odense', country: 'DK', tz: 'Europe/Copenhagen' });
    // RegioJet's train starts in Germany (UIC 80…): a German station, in Berlin time.
    const german = db.$client.prepare(`select country, tz from stations where id = 'uic:8001305'`).get();
    expect(german).toEqual({ country: 'DE', tz: 'Europe/Berlin' });
  });
});
