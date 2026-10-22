import { describe, expect, it } from 'vitest';
import { assessDisruption, passengerRights, type DisruptionInput } from './disruption';

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

describe('why a train is late', () => {
  it("reads Trafikverket's reason codes and leaves notices out", async () => {
    const { delayReasons } = await import('./disruption');
    expect(delayReasons(['Spårändrat', 'Signalfel', 'Inställt', 'Signalfel', 'Kort tåg', 'Sen tågvänd.'])).toEqual(['a signal fault', 'the train arrived late for this trip']);
    expect(delayReasons(['Tågkö'], 'sv')).toEqual(['tågkö']);
    expect(delayReasons(['Spårändrat', 'Hpl C'])).toEqual([]);
  });
});
