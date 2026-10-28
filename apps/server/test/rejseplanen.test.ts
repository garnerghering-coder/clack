import fs from 'node:fs';
import { describe, expect, it } from 'vitest';
import { TokenBucket } from '../src/digitraffic/client.js';
import { endsOf, hafasTime, journeyOf, localStamp, RejseplanenClient, RejseplanenUnavailable } from '../src/rejseplanen/client.js';
import { uicOfStation } from '../src/rejseplanen/match.js';

// Real answers from Rejseplanen's app backend, 2026-10-27 (trimmed).
const fixture = (f: string) => JSON.parse(fs.readFileSync(new URL(`./fixtures/rejseplanen/${f}`, import.meta.url), 'utf8'));

describe('Rejseplanen parsing', () => {
  it('reads times on the journey date, with a day offset, in Copenhagen time', () => {
    expect(hafasTime('20261027', '170400')).toBe(Date.UTC(2026, 9, 27, 16, 4));
    expect(hafasTime('20261027', '01002000')).toBe(Date.UTC(2026, 9, 27, 23, 20));
    expect(hafasTime('20261027', undefined)).toBeNull();
    expect(localStamp(Date.UTC(2026, 9, 27, 23, 20))).toEqual({ date: '20261028', time: '002000' });
  });
  it('reads the ends from a journey id', () => {
    expect(endsOf('2|#VN#1#ST#1#PI#0#ZI#59529#TA#0#DA#271026#1S#8600803#1T#1705#LS#8600677#LT#1814#PU#86#')).toEqual({ firstUic: '8600803', firstMin: 1025, lastUic: '8600677', lastMin: 1094 });
    // After midnight the id carries a day digit: 01:01 the next day is minute 1501, not 61 (NT Re 75, 27 Oct).
    expect(endsOf('2|#DA#271026#1S#8604115#1T#2347#LS#8600009#LT#10101#')).toEqual({ firstUic: '8604115', firstMin: 1427, lastUic: '8600009', lastMin: 1501 });
    expect(endsOf('garbage')).toBeNull();
  });
  it('maps station ids to UIC numbers', () => {
    expect(uicOfStation('860000626')).toBe('8600626');
    expect(uicOfStation('uic:7400003')).toBe('7400003');
    expect(uicOfStation('dk:000000123')).toBeNull();
    expect(uicOfStation('740000003')).toBe('7400003');
    expect(uicOfStation('fi:HKI')).toBeNull();
  });
  it('reads a board: live time, live platform, number', () => {
    const res = fixture('board-kh.json').svcResL[0].res;
    const j = res.jnyL[0];
    const journey = journeyOf(res.common, j);
    expect(journey.number).toBe('1099');
    expect(journey.category).toBe('Re');
    expect(journey.direction).toBe('Østerport');
  });
  it('reads positions, trains only, numbers from the line', () => {
    const res = fixture('geopos.json').svcResL[0].res;
    const js = res.jnyL.map((j: never) => journeyOf(res.common, j));
    const re = js.find((j: { category: string }) => j.category === 'Re');
    expect(re.number).toBe('1127');
    expect(re.pos.lat).toBeGreaterThan(54);
    const s = js.find((j: { category: string }) => j.category === 'S-Tog');
    expect(s.number).toBeNull();
    expect(s.line).toMatch(/^[A-Z]x?$/);
    // The first stop listed twice in the answer is kept once.
    expect(new Set(s.stops.map((x: { uic: string }) => x.uic)).size).toBe(s.stops.length);
  });
  it('reads a journey: every stop, planned and live', () => {
    const res = fixture('details.json').svcResL[0].res;
    const j = journeyOf(res.common, res.journey);
    expect(j.stops.length).toBe(21);
    expect(j.stops.every((s) => s.uic && s.lat)).toBe(true);
    expect(j.stops[1]!.depPlanned).not.toBeNull();
  });
});

describe('Rejseplanen client', () => {
  const ok = fixture('details.json');
  it('keeps to its limit and rests after repeated failures', async () => {
    let t = 0;
    let calls = 0;
    const fetchImpl = (async () => (calls++, new Response('nope', { status: 500 }))) as typeof fetch;
    const c = new RejseplanenClient({ fetchImpl, now: () => t, limiter: new TokenBucket(30, () => t) });
    for (let i = 0; i < 5; i++) await expect(c.journeyDetails('x')).rejects.toThrow('HTTP 500');
    await expect(c.journeyDetails('x')).rejects.toBeInstanceOf(RejseplanenUnavailable);
    expect(calls).toBe(5);
    t += 10 * 60_000 + 1;
    expect(c.available()).toBe(true);
  });
  it('skips rather than queues when the limit is used up', async () => {
    const t = 0;
    const fetchImpl = (async () => new Response(JSON.stringify(ok))) as typeof fetch;
    const c = new RejseplanenClient({ fetchImpl, now: () => t, limiter: new TokenBucket(2, () => t) });
    await c.journeyDetails('x');
    await c.journeyDetails('x');
    await expect(c.journeyDetails('x')).rejects.toBeInstanceOf(RejseplanenUnavailable);
  });
});

describe('Danish boards', () => {
  it('turns Rejseplanen board entries into rows: live time, platform, delay, no actual', async () => {
    const { normalizeDenmarkBoard } = await import('../src/boards/denmark.js');
    const res = fixture('board-kh.json').svcResL[0].res;
    const { journeyOf: jo } = await import('../src/rejseplanen/client.js');
    const entries = res.jnyL.map((j: { stbStop: unknown; date: string }) => ({ journey: jo(res.common, j as never), stop: undefined as never }));
    // Stops come through the client's parser; reuse it by asking for a board with a fake fetch.
    const c = new RejseplanenClient({ fetchImpl: (async () => new Response(JSON.stringify(fixture('board-kh.json')))) as typeof fetch });
    const board = await c.stationBoard('8600626', 'DEP', Date.UTC(2026, 9, 27, 15, 0), 120);
    expect(board.length).toBe(entries.length);
    const matcher = { match: () => null } as never;
    const rows = normalizeDenmarkBoard(board, { type: 'departures', now: Date.UTC(2026, 9, 27, 16, 0), from: 0, to: Infinity, calls: [], memory: new Map(), matcher, names: () => null });
    const re = rows.find((r) => r.trainNumber === '1099')!;
    expect(re.delayMin).toBe(5);
    expect(re.platform).toBe('1');
    expect(re.actual).toBeNull();
    expect(re.endpoints).toEqual(['Østerport']);
    expect(rows.every((r) => r.productName !== 'Togbus')).toBe(true);
  });
});
