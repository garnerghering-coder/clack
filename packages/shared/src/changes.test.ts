import { describe, expect, it } from 'vitest';
import { comfortOf, comfortWithHistory, typicalLateMin } from './changes.js';

// The same cases as ClackCore's ChangeRuleTests (history part): both sides must agree.
describe('history-aware change comfort', () => {
  it('allows for the usual lateness only with a week or more of record', () => {
    expect(typicalLateMin(6, 12)).toBeNull();
    expect(typicalLateMin(7, 12)).toBe(12);
    expect(typicalLateMin(28, 0)).toBe(0);
    expect(typicalLateMin(28, 7.6)).toBe(8);
  });

  it('takes the usual lateness off the gap before judging', () => {
    // 25 min gap at a hub (15): normal by the plain rule (10 spare)...
    expect(comfortOf(25, 15)).toBe('normal');
    // ...tight once the train is usually 3 min late (7 spare, under half the minimum), risky once it is usually 11.
    expect(comfortWithHistory(25, 15, 3)).toBe('tight');
    expect(comfortWithHistory(25, 15, 11)).toBe('risky');
    // No history: the plain rule.
    expect(comfortWithHistory(25, 15, null)).toBe('normal');
    // A train usually on time changes nothing.
    expect(comfortWithHistory(40, 10, 0)).toBe('relaxed');
  });
});
