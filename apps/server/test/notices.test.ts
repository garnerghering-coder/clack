import { describe, expect, it } from 'vitest';
import { noticesByStop, parseNotice, plainText } from '../src/rejseplanen/notices.js';

// Real Rejseplanen messages, 2026-10-28 (Re 2968, ICL 70062, S-tog 633160).
const lift = parseNotice(
  'Elevatoren på Horsens er ude af drift',
  'Elevatoren på Horsens Spor 3 er ude af drift til og med 06. november.<br><a href="https://www.dsb.dk/find-produkter-og-services/handicapservice-i-dsb/" target="_blank" rel="noopener">Læs om handicapservice</a> (Horsens St.)',
)!;
const coaches = parseNotice(
  'ICL70062kører med færre vogne mellem Fredericia og Kbh. Lufthavn',
  'ICL 70062 kører uden vognene 61-62 mellemFredericia og Kbh. Lufthavn. Har du pladsbillet til én af disse vogne, kan du læse om dine muligheder på www.dsb.dk/aflystplads (Fredericia St. - CPH Lufthavn)',
)!;

describe('Rejseplanen notices', () => {
  it('reads the heading, a plain body and the place it concerns', () => {
    expect(lift).toEqual({ head: 'Elevatoren på Horsens er ude af drift', body: 'Elevatoren på Horsens Spor 3 er ude af drift til og med 06. november.', where: ['Horsens St.'], facility: true });
    expect(coaches.where).toEqual(['Fredericia St.', 'CPH Lufthavn']);
    expect(coaches.facility).toBe(false);
    expect(parseNotice('Serviceinfo: Elevatoren på Trekroner spor 3-4 er ude af drift', '')!.head).toBe('Elevatoren på Trekroner spor 3-4 er ude af drift');
    expect(plainText('til og med {{tildato:30. oktober<br><a href="x">Læs</a>')).toBe('til og med 30. oktober');
  });

  it("keeps a station's lift notice off the train's stops and puts a train notice on its stretch only", () => {
    const stops = ['Aarhus H', 'Horsens', 'Vejle', 'Fredericia', 'Odense', 'CPH Airport'];
    const by = noticesByStop([lift, coaches], stops);
    expect(by[1]).toEqual([{ src: 'rejseplanen', text: lift.head, body: lift.body, lang: 'da', facility: true }]);
    expect(by.map((c) => c.filter((x) => !x.facility).length)).toEqual([0, 0, 0, 1, 1, 1]);
    // A lift at a station the train doesn't call at: nothing.
    expect(noticesByStop([parseNotice('Elevatoren på Ballerup er ude af drift', 'x (Ballerup St.)')!], stops).flat()).toEqual([]);
  });
});
