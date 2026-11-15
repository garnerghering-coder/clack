import { describe, expect, it } from 'vitest';
import { assessDisruption, cancellationOf, passengerRights, stopCanceled, type DisruptionInput } from './disruption';

const NOW = Date.parse('2026-10-22T12:00:00Z');
const base: DisruptionInput = { canceled: false, boardCanceled: false, alightCanceled: false, deviations: [], depDelayMin: null, arrDelayMin: null, schedDep: NOW + 3600_000, arrived: false };

describe('disruptions on a saved trip', () => {
  it('stays quiet when nothing is wrong', () => {
    expect(assessDisruption(base, NOW)).toEqual({ kinds: [], urgency: null });
    expect(assessDisruption({ ...base, arrDelayMin: 9 }, NOW).kinds).toEqual([]);
  });

  it('asks you to act on a cancellation soon, and only lets you know about one days away', () => {
    expect(assessDisruption({ ...base, canceled: true }, NOW)).toEqual({ kinds: ['canceled'], urgency: 'act_now' });
    expect(assessDisruption({ ...base, canceled: true, schedDep: NOW + 24 * 3600_000 }, NOW).urgency).toBe('heads_up');
    expect(assessDisruption({ ...base, canceled: true, schedDep: NOW + 5 * 86400_000 }, NOW).urgency).toBe('info');
    expect(assessDisruption({ ...base, canceled: true, arrived: true }, NOW).urgency).toBe('info');
  });

  it('reads stops it skips, replacement buses, delays and a broken change', () => {
    const a = assessDisruption({ ...base, alightCanceled: true, deviations: ['Ersättningsbuss Hallsberg–Örebro'], arrDelayMin: 22, connection: 'miss' }, NOW);
    expect(a.kinds).toEqual(['skips_alight', 'replacement', 'delayed', 'connection_missed']);
    expect(a.urgency).toBe('act_now');
    expect(assessDisruption({ ...base, depDelayMin: 18 }, NOW).urgency).toBe('heads_up');
    expect(assessDisruption({ ...base, connection: 'tight' }, NOW).kinds).toEqual(['connection_at_risk']);
  });
});

describe('passenger rights', () => {
  it('uses the EU rules from 150 km and across borders', () => {
    expect(passengerRights({ countries: ['SE'], journeyKm: 455, arrDelayMin: 75, canceled: false })).toEqual({ regime: 'eu', claim: 'compensation_25' });
    expect(passengerRights({ countries: ['SE'], journeyKm: 455, arrDelayMin: 130, canceled: false })).toEqual({ regime: 'eu', claim: 'compensation_50' });
    expect(passengerRights({ countries: ['SE', 'DK'], journeyKm: 40, arrDelayMin: 45, canceled: false })).toEqual({ regime: 'eu', claim: null });
    expect(passengerRights({ countries: ['SE'], journeyKm: 455, arrDelayMin: null, canceled: true }).claim).toBe('refund_or_reroute');
  });

  it("uses Sweden's 20-minute rule for shorter trips, and the operator's terms in Norway", () => {
    expect(passengerRights({ countries: ['SE'], journeyKm: 43, arrDelayMin: 21, canceled: false })).toEqual({ regime: 'se_short', claim: 'price_reduction' });
    expect(passengerRights({ countries: ['SE'], journeyKm: 43, arrDelayMin: 12, canceled: false }).claim).toBeNull();
    expect(passengerRights({ countries: ['NO'], journeyKm: 300, arrDelayMin: 90, canceled: false })).toEqual({ regime: 'operator', claim: null });
  });
});

// Stop lists shaped like each country's feeds after actuals.ts has made their flags per role.
const stop = (stationId: string, role: string, canceled = false) => ({ stationId, role, canceled });

describe('a train that runs only part of your way', () => {
  it('Sweden (Trafikverket): turns back before where you get off', () => {
    // Malmö C → Göteborg C; it turns at Helsingborg C (arrival kept, departure cancelled: not a cancelled stop).
    const stops = [stop('se:M', 'board'), stop('se:Hb', 'through'), stop('se:Av', 'through', true), stop('se:G', 'alight', true)];
    expect(cancellationOf(stops)).toEqual({ kind: 'partial', runsFrom: null, runsTo: 'se:Hb', startsThere: false, endsThere: true, gaps: [] });
    expect(assessDisruption({ ...base, canceled: false, partial: cancellationOf(stops) }, NOW).kinds).toEqual(['ends_early']);
  });

  it('Denmark (Rejseplanen): starts later than where you get on', () => {
    const stops = [stop('dk:KH', 'board', true), stop('dk:CPH', 'through', true), stop('dk:Tårnby', 'through'), stop('se:Malmö', 'alight')];
    expect(cancellationOf(stops)).toEqual({ kind: 'partial', runsFrom: 'dk:Tårnby', runsTo: null, startsThere: true, endsThere: false, gaps: [] });
    // An older stored flag saying the whole train is cancelled gives way to what the stops show.
    expect(assessDisruption({ ...base, canceled: true, partial: cancellationOf(stops) }, NOW).kinds).toEqual(['starts_later']);
  });

  it('Norway (Entur): skips where you get off, and runs on after it', () => {
    const stops = [stop('no:OSL', 'board'), stop('no:LLS', 'through'), stop('no:Ski', 'alight', true), stop('no:Moss', 'after')];
    const p = cancellationOf(stops)!;
    expect(p).toMatchObject({ kind: 'partial', runsTo: 'no:LLS', endsThere: false });
    expect(assessDisruption({ ...base, partial: p }, NOW).kinds).toEqual(['skips_alight']);
  });

  it('Finland (Digitraffic): nothing of your part runs, or only one stop of it', () => {
    expect(cancellationOf([stop('fi:HKI', 'board', true), stop('fi:PSL', 'through', true), stop('fi:TPE', 'alight', true)])?.kind).toBe('full');
    expect(cancellationOf([stop('fi:HKI', 'board', true), stop('fi:PSL', 'through'), stop('fi:TPE', 'alight', true)])?.kind).toBe('full');
    expect(assessDisruption({ ...base, partial: cancellationOf([stop('fi:HKI', 'board', true), stop('fi:TPE', 'alight', true)]) }, NOW).kinds).toEqual(['canceled']);
  });

  it('Finland (Digitraffic, IC 142 on 2026-10-23): no train between Pieksämäki and Jyväskylä, with the two directions apart', () => {
    const c = (stationId: string, role: string, arrCanceled: boolean | null, depCanceled: boolean | null) => ({ stationId, role, canceled: stopCanceled(role, arrCanceled, depCanceled), arrCanceled, depCanceled });
    const stops = [c('fi:KUO', 'board', null, false), c('fi:PM', 'through', false, true), c('fi:HKS', 'through', true, true), c('fi:JY', 'through', true, false), c('fi:TPE', 'alight', false, null)];
    expect(stops.map((s) => s.canceled)).toEqual([false, false, true, false, false]);
    expect(cancellationOf(stops)).toEqual({ kind: 'partial', runsFrom: null, runsTo: null, startsThere: false, endsThere: false, gaps: [{ from: 'fi:PM', to: 'fi:JY' }] });
    expect(assessDisruption({ ...base, partial: cancellationOf(stops) }, NOW).kinds).toEqual(['gap']);
    // Riding only to Pieksämäki: untouched.
    expect(cancellationOf([c('fi:KUO', 'board', null, false), c('fi:PM', 'alight', false, null)])).toBeNull();
  });

  it('says nothing about a stop skipped in the middle, and knows where it starts only when the feed says so', () => {
    expect(cancellationOf([stop('a', 'board'), stop('b', 'through', true), stop('c', 'alight')])).toBeNull();
    // A stop before yours that isn't reported cancelled: it may only skip yours.
    expect(cancellationOf([stop('x', 'before'), stop('a', 'board', true), stop('b', 'through'), stop('c', 'alight')])).toMatchObject({ runsFrom: 'b', startsThere: false });
    expect(cancellationOf([stop('x', 'before', true), stop('a', 'board', true), stop('b', 'through'), stop('c', 'alight')])).toMatchObject({ runsFrom: 'b', startsThere: true });
  });

  it('makes a stop cancelled by its role: departure where you get on, arrival where you get off, else the whole call', () => {
    expect(stopCanceled('board', false, true)).toBe(true);
    expect(stopCanceled('board', true, false)).toBe(false);
    expect(stopCanceled('alight', true, null)).toBe(true);
    expect(stopCanceled('through', false, true)).toBe(false);
    expect(stopCanceled('through', true, true)).toBe(true);
    expect(stopCanceled('before', null, true)).toBe(true);
    expect(stopCanceled('after', null, null)).toBe(false);
  });

  it('counts a part-way train as a cancelled journey for passenger rights, and leaves Finland and Denmark to the operator', () => {
    expect(passengerRights({ countries: ['FI'], journeyKm: 400, arrDelayMin: 90, canceled: false })).toEqual({ regime: 'operator', claim: null });
    expect(passengerRights({ countries: ['DK'], journeyKm: 200, arrDelayMin: 90, canceled: false })).toEqual({ regime: 'operator', claim: null });
    expect(passengerRights({ countries: ['DK', 'SE'], journeyKm: 40, arrDelayMin: null, canceled: true }).claim).toBe('refund_or_reroute');
  });
});
