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
    expect(endsOf('2|#VN#1#ST#1#PI#0#ZI#59529#TA#0#DA#271026#1S#8600803#1T#1705#LS#8600677#LT#1814#PU#86#')).toEqual({ firstUic: '8600803', firstHhmm: '1705', lastUic: '8600677', lastHhmm: '1814' });
    expect(endsOf('garbage')).toBeNull();
  });
  it('maps station ids to UIC numbers', () => {
    expect(uicOfStation('860000626')).toBe('8600626');
    expect(uicOfStation('uic:7400003')).toBe('7400003');
    expect(uicOfStation('dk:000000123')).toBeNull();
    expect(uicOfStation('740000001')).toBeNull();
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
