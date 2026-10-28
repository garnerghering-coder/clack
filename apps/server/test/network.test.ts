import { describe, expect, it } from 'vitest';
import { networkStatus } from '../src/livemap/network.js';
import type { LiveTrain } from '../src/livemap/ingest.js';

const train = (id: string, next: string, delayMin: number | null, lat = 56, lon = 13): LiveTrain => ({
  id, number: id, date: '2026-10-28', lat, lon, bearing: null, speedKmh: null, at: 0, estimated: false, operatorId: 'sj',
  productName: null, product: 'regional', trainType: null, origin: null, destination: null, next, nextEta: null, delayMin, mine: false,
});

describe('network status', () => {
  it('flags a stretch where most trains are 10+ late, joins stretches that touch, and counts reasons', () => {
    const trains = [
      train('1', 'Lund C', 14), train('2', 'Hässleholm C', 22), // Hässleholm – Lund, both directions
      train('3', 'Malmö C', 11), train('4', 'Lund C', 30), // Lund – Malmö
      train('5', 'Nässjö C', 2), train('6', 'Nässjö C', 12), // Jönköping – Nässjö: half late, not most
      train('7', 'Alvesta', 40), // alone on its stretch
    ];
    const prev: Record<string, string> = { '1': 'Hässleholm C', '2': 'Lund C', '3': 'Lund C', '4': 'Malmö C', '5': 'Jönköping C', '6': 'Jönköping C', '7': 'Växjö' };
    const signal = { src: 'trv' as const, code: 'ANA027', text: 'Signalfel' };
    const ctx = new Map(trains.map((t) => [t.id, { prev: prev[t.id]!, causes: ['1', '2', '4'].includes(t.id) ? [signal] : [] }]));
    const s = networkStatus(trains, ctx, 0);
    expect(s.corridors).toHaveLength(1);
    const c = s.corridors[0]!;
    expect(c.stations).toEqual(['Hässleholm C', 'Lund C', 'Malmö C']);
    expect([c.trains, c.late, c.maxDelay, c.medianDelay]).toEqual([4, 4, 30, 18]);
    expect(c.causes).toEqual([{ ...signal, trains: 3 }]);
    expect(s.countries.SE).toEqual({ trains: 7, known: 7, late: 6 });
    // Outside the corridor: the lone Alvesta train, then the Nässjö one.
    expect(s.late.map((t) => [t.number, t.delayMin, t.prev, t.next])).toEqual([['7', 40, 'Växjö', 'Alvesta'], ['6', 12, 'Jönköping C', 'Nässjö C']]);
  });

  it('flags nothing on a quiet network', () => {
    const trains = [train('1', 'B', 0), train('2', 'A', 3)];
    const ctx = new Map([['1', { prev: 'A', causes: [] }], ['2', { prev: 'B', causes: [] }]]);
    expect(networkStatus(trains, ctx).corridors).toEqual([]);
  });
});
