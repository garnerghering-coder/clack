import { describe, expect, it } from 'vitest';
import { compositionOf } from '../src/digitraffic/trains.js';

describe('Digitraffic compositions', () => {
  it('counts the cars of a multiple unit Digitraffic lists as one wagon', () => {
    // As /compositions/2026-10-30: 1527 one Sm5 (a 4-car Flirt), 9704 three Sm4 (2 cars each), 9 a Pendolino car by car.
    const one = (n: number, wagons: { wagonType: string; length: number }[]) => ({ trainNumber: n, departureDate: '2026-10-30', journeySections: [{ locomotives: [{ locomotiveType: wagons[0]!.wagonType }], wagons }] });
    expect(compositionOf(one(1527, [{ wagonType: 'Sm5', length: 7520 }])).cars).toBe(4);
    expect(compositionOf(one(9704, Array(3).fill({ wagonType: 'Sm4', length: 5440 }))).cars).toBe(6);
    expect(compositionOf(one(9, Array(6).fill({ wagonType: 'Sm3', length: 2590 }))).cars).toBe(6);
    expect(compositionOf(one(428, Array(2).fill({ wagonType: 'Dm12', length: 2520 }))).cars).toBe(2);
    expect(compositionOf(null).cars).toBeNull();
  });
});
