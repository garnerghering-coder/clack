import { describe, expect, it } from 'vitest';
import { parseRuma, parseSituations, parseTrafikverket, STALE_MS, trvPoint } from '../src/livemap/disruptions.js';

const now = Date.parse('2026-11-15T10:00:00Z');
const iso = (t: number) => new Date(t).toISOString();
const H = 3600_000;

// Shaped like Trafikverket's OperativeEvent (archive 2026-11-14).
const event = (over: Record<string, unknown> = {}) => ({
  OperativeEventId: 'O1',
  EventType: { Description: 'Banarbete/transport', EventTypeCode: '16' },
  StartDateTime: iso(now - H),
  EndDateTime: iso(now + H),
  ModifiedDateTime: iso(now - H),
  Deleted: false,
  Geometry: { WGS84: 'POINT (57.81 12.25)' },
  EventSection: [{ FromLocation: { Signature: 'G' }, ToLocation: { Signature: 'A' } }],
  TrafficImpact: [{ PublicMessage: { Header: 'Banarbete Göteborg–Alingsås' } }],
  ...over,
});
const places: Record<string, { name: string; point: { id: string; lat: number; lon: number } }> = {
  G: { name: 'Göteborg C', point: { id: 'g', lat: 57.71, lon: 11.97 } },
  A: { name: 'Alingsås', point: { id: 'a', lat: 57.93, lon: 12.53 } },
};
const se = (events: unknown[]) => parseTrafikverket(events as never, now, (s) => places[s] ?? null, () => 'line');

describe('disruptions: Sweden', () => {
  it('reads the point latitude first, as Trafikverket sends it', () => {
    expect(trvPoint('POINT (57.81 12.25)')).toEqual({ lat: 57.81, lon: 12.25 });
    expect(trvPoint('POINT (12.25 57.81)')).toEqual({ lat: 57.81, lon: 12.25 });
    expect(trvPoint(undefined)).toBeNull();
  });

  it('track work is code 16, drawn along its stretch with its two ends named', () => {
    const [d] = se([event()]);
    expect(d).toMatchObject({ id: 'se:O1', kind: 'works', places: ['Göteborg C', 'Alingsås'], lines: ['line'], title: { sv: 'Banarbete Göteborg–Alingsås' } });
    expect(se([event({ EventType: { Description: 'Spårväxel', EventTypeCode: '20' } })])[0]!.kind).toBe('incident');
  });

  it('leaves out events that touch no train, have ended, or were left open', () => {
    expect(se([event({ TrafficImpact: [] })])).toEqual([]);
    expect(se([event({ EndDateTime: iso(now - 1) })])).toEqual([]);
    expect(se([event({ Deleted: true })])).toEqual([]);
    // No end and untouched for over a day: one from May was still "on" in November.
    expect(se([event({ EndDateTime: undefined, ModifiedDateTime: iso(now - STALE_MS - 1) })])).toEqual([]);
    expect(se([event({ EndDateTime: undefined, ModifiedDateTime: iso(now - H) })])).toHaveLength(1);
  });
});

describe('disruptions: Finland', () => {
  const line = { identifierRanges: [{ location: [[[21.52, 61.6], [21.53, 61.61]]] as [number, number][][] }] };
  it('a closed track is a closure; other restrictions and today\'s track work are works', () => {
    const out = parseRuma(
      [
        { id: 'r1', limitation: 'CLOSED_FROM_TRAFFIC', startDate: iso(now - H), endDate: iso(now + H), location: [21.52, 61.6], locations: [line] },
        { id: 'r2', limitation: 'SPEED_LIMIT', startDate: iso(now - H), location: [21.52, 61.6] },
        { id: 'r3', limitation: 'CLOSED_FROM_TRAFFIC', startDate: iso(now + H), location: [21.52, 61.6] },
      ],
      [
        { id: 'w1', state: 'ACTIVE', location: [25.04, 60.29], workParts: [{ startDay: '2026-11-15', locations: [line] }] },
        { id: 'w2', state: 'ACTIVE', location: [25.04, 60.29], workParts: [{ startDay: '2026-11-16' }] },
      ],
      now,
      '2026-11-15',
      () => 'Pori',
    );
    expect(out.map((d) => [d.id, d.kind])).toEqual([['fi:r1', 'closure'], ['fi:r2', 'works'], ['fi:w1', 'works']]);
    expect(out[0]).toMatchObject({ lat: 61.6, lon: 21.52, places: ['Pori'] });
    expect(out[0]!.lines).toHaveLength(1);
  });
});

describe('disruptions: Norway', () => {
  const stations: Record<string, { name: string; lat: number; lon: number }> = {
    'NSR:StopPlace:152': { name: 'Skøyen', lat: 59.92, lon: 10.68 },
    'NSR:StopPlace:288': { name: 'Oslo S', lat: 59.91, lon: 10.75 },
    'NSR:StopPlace:11272': { name: 'Vinstra skysstasjon', lat: 61.6, lon: 9.75 },
  };
  const stop = (id: string) => ({ AffectedStopPoint: { StopPointRef: { value: id } } });
  const sx = (participant: string, line: string, stops: string[]) => ({
    SituationNumber: { value: `${participant}:1` },
    ParticipantRef: { value: participant },
    Progress: 'open',
    ValidityPeriod: [{ StartTime: iso(now - H) }],
    Summary: [{ value: 'Fewer tracks: Skøyen', lang: 'EN' }, { value: 'Færre spor: Skøyen', lang: 'NO' }],
    Affects: { Networks: { AffectedNetwork: [{ AffectedLine: [{ LineRef: { value: line }, Routes: [{ StopPoints: stops.map(stop) }] }] }] } },
  });

  it('keeps train operators\' situations, pinned at the station named most, in both languages', () => {
    const out = parseSituations([sx('VYG', 'VYG:Line:L1', ['NSR:StopPlace:152', 'NSR:StopPlace:288', 'NSR:StopPlace:152'])] as never, now, (id) => stations[id] ?? null);
    expect(out).toHaveLength(1);
    expect(out[0]).toMatchObject({ country: 'NO', kind: 'incident', places: ['Skøyen'], title: { en: 'Fewer tracks: Skøyen', no: 'Færre spor: Skøyen' } });
  });

  it('leaves out buses, even at a stop we know', () => {
    expect(parseSituations([sx('INN', 'INN:Line:241', ['NSR:StopPlace:11272'])] as never, now, (id) => stations[id] ?? null)).toEqual([]);
  });
});
