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

  it('gives a corridor its stretches (track between the station ids) and its late trains, worst first', () => {
    const trains = [
      { ...train('1', 'Lund C', 14), nextId: 'lund' }, { ...train('4', 'Hässleholm C', 12), nextId: 'hassleholm' },
      { ...train('2', 'Malmö C', 22), nextId: 'malmo' }, { ...train('3', 'Lund C', 11), nextId: 'lund' },
    ];
    const ctx = new Map([
      ['1', { prev: 'Hässleholm C', prevId: 'hassleholm', causes: [] }],
      ['4', { prev: 'Lund C', prevId: 'lund', causes: [] }],
      ['2', { prev: 'Lund C', prevId: 'lund', causes: [{ src: 'trv' as const, code: 'ANA027', text: 'Signalfel' }] }],
      ['3', { prev: 'Malmö C', prevId: 'malmo', causes: [] }],
    ]);
    const asked: string[] = [];
    const s = networkStatus(trains, ctx, 0, (a, b) => {
      asked.push(`${a}>${b}`);
      return `poly:${a}>${b}`;
    });
    expect(s.corridors).toHaveLength(1);
    const c = s.corridors[0]!;
    expect(c.stations).toEqual(['Hässleholm C', 'Lund C', 'Malmö C']);
    // One stretch per neighbouring pair, in order, each with the ids and the polyline the geometry gave (asked once per stretch).
    expect(c.stretches.map((x) => [x.a, x.b, x.aId, x.bId, x.polyline])).toEqual([
      ['Hässleholm C', 'Lund C', 'hassleholm', 'lund', 'poly:hassleholm>lund'],
      ['Lund C', 'Malmö C', 'lund', 'malmo', 'poly:lund>malmo'],
    ]);
    expect(asked).toEqual(['hassleholm>lund', 'lund>malmo']);
    // The late trains on it (10+ only), worst first, with their reasons.
    expect(c.lateTrains.map((t) => [t.id, t.delayMin, t.next, t.causes.length])).toEqual([['2', 22, 'Malmö C', 1], ['1', 14, 'Lund C', 0], ['4', 12, 'Hässleholm C', 0], ['3', 11, 'Lund C', 0]]);
    // Without geometry: no polylines, same stretches.
    expect(networkStatus(trains, ctx, 0).corridors[0]!.stretches.map((x) => x.polyline)).toEqual([null, null]);
  });

  it('flags nothing on a quiet network', () => {
    const trains = [train('1', 'B', 0), train('2', 'A', 3)];
    const ctx = new Map([['1', { prev: 'A', causes: [] }], ['2', { prev: 'B', causes: [] }]]);
    expect(networkStatus(trains, ctx).corridors).toEqual([]);
  });
});
