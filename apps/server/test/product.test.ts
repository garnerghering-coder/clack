import { describe, expect, it } from 'vitest';
import { classifyProduct, type KindFacts, type KindLists } from '../src/legs/product.js';

// Shaped like the real lists (data/night_trains.json and the feeds, 2026-11-15).
const lists: KindLists = {
  night: { SE: new Set(['94', '92', '300', '301']), NO: new Set(['605', '606', '405', '475']), FI: new Set(['265', '273']), DK: new Set() },
  seHighSpeed: new Set(['529', '7877']),
};
const facts = (f: Partial<KindFacts>): KindFacts => ({ country: 'SE', operatorId: 'sj', trainNumber: '1', category: 'intercity', routeType: null, userProduct: null, ...f });
const kind = (f: Partial<KindFacts>) => classifyProduct(facts(f), lists);

describe('kind of train', () => {
  it('a night train is one sold as such, in every year: SJ 94 in the old feed (no sleeper type) too', () => {
    expect(kind({ trainNumber: '94', routeType: '102' })).toEqual({ product: 'night', source: 'rule' });
    expect(kind({ trainNumber: '94', routeType: '105' })).toEqual({ product: 'night', source: 'feed' });
    // Vy's 92 to Narvik in the old feed: the same national number.
    expect(kind({ operatorId: 'vy', trainNumber: '92', routeType: '102' }).product).toBe('night');
  });

  it('Snälltåget\'s Berlin train is a night train wherever it starts', () => {
    expect(kind({ country: 'DK', operatorId: 'snalltaget', trainNumber: '300' }).product).toBe('night');
  });

  it('a late seated train is not a night train (DSB IC 1130 København 23:00, an old clock-rule "night")', () => {
    expect(kind({ country: 'DK', operatorId: 'dsb', trainNumber: '1130', category: 'night' })).toEqual({ product: 'intercity', source: 'rule' });
    expect(kind({ country: 'NO', operatorId: 'vy', trainNumber: '605', category: 'intercity' }).product).toBe('night');
  });

  it('Finland: a PYO run past midnight is a night train, a daytime one (904) is not', () => {
    expect(kind({ country: 'FI', operatorId: 'vr-fi', trainNumber: '273', category: 'night' }).product).toBe('night');
    expect(kind({ country: 'FI', operatorId: 'vr-fi', trainNumber: '904', category: 'night' }).product).toBe('intercity');
  });

  it('high speed follows the feed: Arlanda Express (101), and X2000 numbers in older feeds', () => {
    expect(kind({ operatorId: 'arlanda-express', trainNumber: '7877', category: 'regional', routeType: '101' })).toEqual({ product: 'high_speed', source: 'feed' });
    expect(kind({ trainNumber: '529', routeType: '2' })).toEqual({ product: 'high_speed', source: 'rule' });
    expect(kind({ country: 'FI', category: 'high_speed' }).product).toBe('high_speed');
  });

  it('the owner\'s choice wins; anything else keeps the feed\'s kind', () => {
    expect(kind({ trainNumber: '94', userProduct: 'intercity' })).toEqual({ product: 'intercity', source: 'user' });
    expect(kind({ userProduct: 'not-a-kind', category: 'commuter' }).product).toBe('commuter');
    expect(kind({ category: 'heritage', trainNumber: '94' }).product).toBe('heritage');
  });
});
