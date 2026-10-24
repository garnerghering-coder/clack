import { describe, expect, it } from 'vitest';
import table from '../../../data/delay_causes.json';
import en from '../locales/en.json';
import sv from '../locales/sv.json';
import { causeText, delayReasons, resolveCause } from './delayCauses';

const keys = (): string[] => {
  const all = [...Object.values(table.trv), ...Object.values(table.trvText), ...Object.values(table.dt)] as { key: string | null }[];
  return [...new Set(all.map((e) => e.key).filter((k): k is string => !!k))];
};

describe('the cause table', () => {
  it('has every key it uses in both languages, and no key left over', () => {
    for (const k of keys()) {
      const name = k.replace(/^cause\./, '');
      expect(k.startsWith('cause.'), k).toBe(true);
      expect((en.cause as Record<string, string>)[name], `en ${k}`).toBeTruthy();
      expect((sv.cause as Record<string, string>)[name], `sv ${k}`).toBeTruthy();
    }
    const names = new Set(keys().map((k) => k.replace(/^cause\./, '')));
    for (const name of Object.keys(en.cause)) expect(names.has(name), `unused ${name}`).toBe(true);
  });
  it("keeps Trafikverket's own Swedish text and marks our wording unverified", () => {
    expect(table.trv.ANA015.sv).toBe('Elfel');
    expect(table.trv.ANA050.sv).toBe('Signalfel');
    for (const e of Object.values(table.trv)) expect(e.verified).toBe(false);
  });
});

describe('resolving a cause', () => {
  it('translates by code, then by exact text, else shows the words as written', () => {
    expect(causeText({ src: 'trv', code: 'ANA015', text: 'Elfel' }, 'en')).toBe('Power fault');
    expect(causeText({ src: 'trv', code: 'ANA015', text: 'Elfel' }, 'sv')).toBe('Elfel');
    expect(causeText({ src: 'trv', text: 'Signalfel' }, 'en')).toBe('Signal fault');
    expect(causeText({ src: 'trv', text: 'Spårfel' }, 'en')).toBe('Track fault');
    expect(causeText({ src: 'trv', code: 'ANA999', text: 'Något nytt' }, 'en')).toBe('Något nytt');
    expect(causeText({ src: 'entur', text: 'Signal failure at Lillestrøm' }, 'sv')).toBe('Signal failure at Lillestrøm');
  });
  it('walks up Digitraffic codes and falls back to the Finnish name', () => {
    expect(causeText({ src: 'digitraffic', code: 'P109' }, 'en')).toBe('Points failure');
    expect(causeText({ src: 'digitraffic', code: 'P105' }, 'sv')).toBe('Anläggningsfel');
    expect(causeText({ src: 'digitraffic', code: 'X' }, 'en')).toBe('Rataliikennekeskukselle ilmoitettavat syyt');
    expect(causeText({ src: 'digitraffic', code: 'ZZ9' }, 'en')).toBeNull();
  });
  it('knows notices from causes', () => {
    expect(resolveCause({ src: 'trv', code: 'ANA055', text: 'Spårändrat' })).toMatchObject({ key: 'cause.platformChanged', kind: 'notice' });
    expect(resolveCause({ src: 'trv', code: 'ANA012' }).kind).toBe('notice');
  });
});

describe('why a train is late', () => {
  it('reads the reasons and leaves notices and unknown words out', () => {
    expect(delayReasons(['Spårändrat', 'Signalfel', 'Inställt', 'Signalfel', 'Kort tåg', 'Sen tågvänd.'])).toEqual(['signal fault', 'late turnaround']);
    expect(delayReasons(['Tågkö'], 'sv')).toEqual(['tågkö']);
    expect(delayReasons(['Spårändrat', 'Hpl C'])).toEqual([]);
    expect(delayReasons([{ src: 'digitraffic', code: 'P109' }, { src: 'entur', text: 'Delays' }], 'en')).toEqual(['points failure']);
  });
});
