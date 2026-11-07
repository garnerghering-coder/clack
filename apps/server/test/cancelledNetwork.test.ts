import { describe, expect, it } from 'vitest';
import { cancelledPart } from '../src/livemap/announcements.js';
import { cancelledGroups, type CancelledRun } from '../src/livemap/network.js';

// Jönköping C, 2026-11-07: Västtågen cancelled with "Buss ersätter" (ANA007) towards Skövde and Nässjö. The network
// status showed nothing, because cancelled trains never run on the map.
const at = (hhmm: string) => `2026-11-07T${hhmm}:00.000+01:00`;
const row = (id: string, sig: string, type: 'Avgang' | 'Ankomst', time: string, canceled: boolean, bus = true) =>
  ({
    ActivityId: id,
    ActivityType: type,
    AdvertisedTrainIdent: '7248',
    AdvertisedTimeAtLocation: at(time),
    LocationSignature: sig,
    Canceled: canceled,
    Operator: 'Västtrafik',
    ProductInformation: [{ Description: 'Västtågen' }],
    Deviation: canceled && bus ? [{ Code: 'ANA007', Description: 'Buss ersätter' }] : [],
  }) as never;
const now = Date.parse(at('17:30'));

describe('cancelledPart', () => {
  it('finds the cancelled stretch and the bus', () => {
    const part = cancelledPart([row('1', 'Jö', 'Avgang', '18:03', true), row('2', 'F', 'Ankomst', '18:40', true), row('3', 'Sk', 'Ankomst', '19:10', true)], now, 2 * 3600_000);
    expect(part).toMatchObject({ number: '7248', fromSig: 'Jö', toSig: 'Sk', bus: true, causes: [] });
  });
  it('is nothing for a train running as planned, or cancelled long ago', () => {
    expect(cancelledPart([row('1', 'Jö', 'Avgang', '18:03', false)], now, 2 * 3600_000)).toBeNull();
    expect(cancelledPart([row('1', 'Jö', 'Avgang', '16:00', true)], now, 2 * 3600_000)).toBeNull();
  });
  it('says no bus when the source does not', () => {
    expect(cancelledPart([row('1', 'Jö', 'Avgang', '18:03', true, false)], now, 2 * 3600_000)?.bus).toBe(false);
  });
});

describe('cancelledGroups', () => {
  const run = (number: string, from: string, to: string, bus: boolean): CancelledRun => ({ number, date: '2026-11-07', from, to, operatorId: 'vasttagen', firstAt: now, bus, causes: [] });
  it('groups both directions of a stretch, most trains first', () => {
    const groups = cancelledGroups([run('7248', 'Jönköping C', 'Skövde C', true), run('7251', 'Skövde C', 'Jönköping C', true), run('3049', 'Göteborg C', 'Borås C', false)]);
    expect(groups[0]).toMatchObject({ trains: 2, bus: 2, operatorIds: ['vasttagen'], numbers: ['7248', '7251'] });
    expect(groups[1]).toMatchObject({ trains: 1, bus: 0 });
  });
  it("joins one company's stretches that share a station", () => {
    const groups = cancelledGroups([run('7248', 'Nässjö C', 'Skövde C', true), run('7252', 'Nässjö C', 'Skövde C', true), run('7253', 'Sandhem', 'Nässjö C', true), run('500', 'Göteborg C', 'Mölndal', true)]);
    expect(groups[0]).toMatchObject({ stations: ['Nässjö C', 'Skövde C'], trains: 3, bus: 3 });
    expect(groups).toHaveLength(2);
  });
});
