import { describe, expect, it } from 'vitest';
import { ticketHref, type TicketTrip } from './components/Tickets';

const trip: TicketTrip = {
  operatorId: 'sj',
  trainNumber: '421',
  from: { name: 'Stockholm C', time: Date.parse('2026-10-23T05:13:00Z'), tz: 'Europe/Stockholm', seq: 1 },
  to: { name: 'Göteborg C', time: Date.parse('2026-10-23T08:13:00Z'), tz: 'Europe/Stockholm', seq: 5 },
  tripKey: 'k',
  serviceDate: '2026-10-23',
};

describe('ticket links', () => {
  it("is the operator's own page when no link format has been checked", () => {
    expect(ticketHref('https://www.sj.se', null, trip)).toBe('https://www.sj.se');
  });
  it('fills a checked format with the journey, in local time', () => {
    expect(ticketHref('https://x.se', 'https://x.se/s?f={from}&t={to}&d={date}&h={time}', trip)).toBe('https://x.se/s?f=Stockholm%20C&t=G%C3%B6teborg%20C&d=2026-10-23&h=07:13');
  });
});
