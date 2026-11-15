// A part-way train as stored and served (build 86): the stops keep their arrival and departure cancellations apart,
// the trip keeps how much of your part runs, and the alerts name the station. Finland's IC 142 on 2026-10-23 (real
// Digitraffic answer: no train between Pieksämäki and Jyväskylä) on three rides.
import { describe, expect, it } from 'vitest';
import { LOCAL_USER_ID, openDb } from '../src/db/client.js';
import { refreshLegActuals } from '../src/legs/actuals.js';
import { createLeg, getLeg } from '../src/legs/legs.js';
import { resetDigitrafficCaches } from '../src/digitraffic/trains.js';
import { partialLine } from '../src/push/rules.js';
import { fakeDigitraffic, seedFinland, seedTrip, trainFixture } from './finlandFixtures.js';

const ic142 = trainFixture('ic-142-short-turned');
const NOW = Date.parse('2026-10-23T12:00:00Z');

async function ride(fromCode: string, toCode: string) {
  resetDigitrafficCaches();
  const db = openDb(':memory:');
  seedFinland(db);
  const key = seedTrip(db, ic142);
  const codes = ic142.timeTableRows.filter((r) => r.commercialStop === true).map((r) => r.stationShortCode).filter((c, i, a) => a.indexOf(c) === i);
  const id = createLeg(db, LOCAL_USER_ID, { tripKey: key, serviceDate: ic142.departureDate, fromSeq: codes.indexOf(fromCode) + 1, toSeq: codes.indexOf(toCode) + 1 }, Date.parse('2026-10-22T10:00:00Z'));
  const { fetchImpl } = fakeDigitraffic({ [`trains/${ic142.departureDate}/${ic142.trainNumber}`]: [ic142], 'compositions/*': { trainNumber: ic142.trainNumber, departureDate: ic142.departureDate, journeySections: [] } });
  await refreshLegActuals(db, id, { now: NOW, fetchImpl });
  return getLeg(db, LOCAL_USER_ID, id)!;
}

describe('a part-way train, stored', () => {
  it('Kuopio → Tampere runs, with no train Pieksämäki–Jyväskylä; the two stations around the gap are not cancelled', async () => {
    const leg = await ride('KUO', 'TPE');
    expect(leg.canceled).toBe(false);
    const byCode = (c: string) => leg.stops.find((s) => s.stationId === `fi:${c}`)!;
    expect(byCode('PM')).toMatchObject({ canceled: false, arrCanceled: false, depCanceled: true });
    expect(byCode('HKS')).toMatchObject({ canceled: true });
    expect(byCode('JY')).toMatchObject({ canceled: false, arrCanceled: true, depCanceled: false });
    expect(leg.cancellation).toMatchObject({ kind: 'partial', runsFrom: null, runsTo: null, gaps: [{ from: 'fi:PM', to: 'fi:JY' }] });
  });

  it('Kuopio → Hankasalmi runs only to Pieksämäki', async () => {
    const leg = await ride('KUO', 'HKS');
    expect(leg.canceled).toBe(false);
    expect(leg.cancellation).toMatchObject({ kind: 'partial', runsTo: 'fi:PM', endsThere: true });
    expect(leg.cancellation!.runsToName).toBeTruthy();
  });

  it('Pieksämäki → Tampere starts from Jyväskylä for you (it arrives at Pieksämäki and goes no further)', async () => {
    const leg = await ride('PM', 'TPE');
    expect(leg.canceled).toBe(false);
    expect(leg.cancellation).toMatchObject({ kind: 'partial', runsFrom: 'fi:JY', startsThere: true });
  });

  it('Hankasalmi → Jyväskylä: nothing of it runs', async () => {
    const leg = await ride('HKS', 'JY');
    expect(leg.canceled).toBe(true);
    expect(leg.cancellation?.kind).toBe('full');
  });
});

describe('the alert for a part-way train, in words', () => {
  const f = { from: 'Malmö C', to: 'Göteborg C' };
  it('says where it runs to or from, in English and Swedish', () => {
    expect(partialLine(f, { runsToName: 'Helsingborg C', endsThere: true }, 'en')).toBe('Runs only to Helsingborg C today, not to Göteborg C. Open Clack for ways on from there.');
    expect(partialLine(f, { runsToName: 'Helsingborg C', endsThere: true }, 'sv')).toBe('Går bara till Helsingborg C i dag, inte till Göteborg C. Öppna Clack för hur du kommer vidare.');
    expect(partialLine(f, { runsFromName: 'Lund C', startsThere: true }, 'en')).toBe('Starts from Lund C today, not from Malmö C. Open Clack for ways to get there.');
    expect(partialLine(f, { runsToName: 'Varberg', endsThere: false }, 'en')).toBe('Won’t stop at Göteborg C today. The last stop before it is Varberg.');
    expect(partialLine(f, { runsFromName: 'Lund C', startsThere: false }, 'sv')).toBe('Stannar inte i Malmö C i dag. Första stoppet på din väg är Lund C.');
  });
});
