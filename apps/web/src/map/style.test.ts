import { describe, expect, it } from 'vitest';
import { lighten } from './style';

describe('route core colour', () => {
  it('mixes toward white', () => {
    expect(lighten('#000000', 0.5)).toBe('#808080');
    expect(lighten('#4C8DFF', 0)).toBe('#4c8dff');
    expect(lighten('#4C8DFF', 1)).toBe('#ffffff');
  });
});
