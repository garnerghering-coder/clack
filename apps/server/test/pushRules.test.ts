import { describe, expect, it } from 'vitest';
import { DEFAULT_SETTINGS } from '@clack/shared';
import { change, fromEvents, getOff, momentOf, reminder, spareMinutes, type Prefs, type TripFacts } from '../src/push/rules.js';

const T = (hhmm: string) => Date.parse(`2026-10-20T${hhmm}:00+02:00`);
const prefs: Prefs = { ...DEFAULT_SETTINGS, notify: true };

const facts = (over: Partial<TripFacts> = {}): TripFacts => ({
  legId: 'L1', journeyId: 'j-L1', train: '307', from: 'Nässjö', to: 'Kolding', fromTz: 'Europe/Stockholm', toTz: 'Europe/Copenhagen', toStationId: 'KD',
  expDep: T('13:32'), expArr: T('18:52'), depPlatform: '5', arrPlatform: '2', departed: false, arrived: false, canceled: false, delayMin: 0, lastInJourney: true,
  ...over,
});

describe('departure reminder', () => {
  it('waits for the lead time, then says time and platform', () => {
    expect(reminder(facts(), prefs, T('12:31'), 'en')).toBeNull();
    const a = reminder(facts(), prefs, T('12:32'), 'en')!;
    expect(a.body).toBe('Leaves 13:32 from platform 5.');
    expect(a.title).toBe('Nässjö → Kolding');
  });
  it('says so when the platform is not announced, and never guesses', () => {
    expect(reminder(facts({ depPlatform: null }), prefs, T('12:40'), 'en')!.body).toBe('Leaves 13:32. Platform not announced yet.');
  });
  it('follows a delay and speaks Swedish', () => {
    const a = reminder(facts({ expDep: T('13:50'), delayMin: 18 }), prefs, T('12:55'), 'sv')!;
    expect(a.body).toBe('Avgår 13:50 (18 min försenat) från spår 5.');
  });
  it('stays quiet when off, cancelled, departed, or about to leave', () => {
    expect(reminder(facts(), { ...prefs, notify: false }, T('13:00'), 'en')).toBeNull();
    expect(reminder(facts(), { ...prefs, notifyLeadMin: 0 }, T('13:00'), 'en')).toBeNull();
    expect(reminder(facts({ canceled: true }), prefs, T('13:00'), 'en')).toBeNull();
    expect(reminder(facts({ departed: true }), prefs, T('13:40'), 'en')).toBeNull();
    expect(reminder(facts(), prefs, T('13:30'), 'en')).toBeNull();
  });
});

describe('alerts from events', () => {
  it('announces a new platform and a changed one, differently', () => {
    const set = fromEvents(facts(), [{ type: 'platform_set', payload: { which: 'departure', to: '5' } }], prefs, 'en');
    expect(set[0]!.body).toBe('Leaves from platform 5.');
    const changed = fromEvents(facts(), [{ type: 'platform_changed', payload: { which: 'departure', from: '5', to: '7' } }], prefs, 'en');
    expect(changed[0]!.body).toBe('Platform changed: now platform 7, was 5.');
    expect(changed[0]!.key).toBe('departure:7');
    const arr = fromEvents(facts(), [{ type: 'platform_changed', payload: { which: 'arrival', from: '2', to: '3' } }], prefs, 'en');
    expect(arr[0]!.body).toContain('Kolding');
  });
  it('does not announce a departure platform once the train has left', () => {
    expect(fromEvents(facts({ departed: true }), [{ type: 'platform_changed', payload: { which: 'departure', from: '5', to: '7' } }], prefs, 'en')).toEqual([]);
  });
  it('alerts for delays of five minutes or more only', () => {
    expect(fromEvents(facts(), [{ type: 'delayed', payload: { delayMin: 4 } }], prefs, 'en')).toEqual([]);
    const a = fromEvents(facts(), [{ type: 'delayed', payload: { delayMin: 12 } }], prefs, 'en')[0]!;
    expect(a.body).toBe('12 min late, now arriving 18:52.');
    expect(a.kind).toBe('delay');
  });
  it('cancellations are time-sensitive', () => {
    const a = fromEvents(facts(), [{ type: 'cancelled', payload: {} }], prefs, 'en')[0]!;
    expect(a.timeSensitive).toBe(true);
    expect(a.title).toBe('Cancelled: Nässjö → Kolding');
  });
  it('welcomes you only at the end of a whole journey', () => {
    const e = [{ type: 'arrived', payload: { at: T('18:52') } }];
    expect(fromEvents(facts(), e, prefs, 'en')[0]!.title).toBe('Welcome to Kolding');
    expect(fromEvents(facts({ lastInJourney: false }), e, prefs, 'en')).toEqual([]);
  });
  it('each type can be switched off', () => {
    const e = [
      { type: 'platform_set', payload: { which: 'departure', to: '5' } },
      { type: 'delayed', payload: { delayMin: 12 } },
      { type: 'cancelled', payload: {} },
      { type: 'arrived', payload: { at: 1 } },
    ];
    expect(fromEvents(facts(), e, { ...prefs, notifyPlatform: false, notifyDelay: false, notifyCancel: false, notifyArrival: false }, 'en')).toEqual([]);
    expect(fromEvents(facts(), e, { ...prefs, notify: false }, 'en')).toEqual([]);
  });
});

describe('getting off', () => {
  const live = { status: 'en_route', nextStopId: 'KD', eta: T('18:45') };
  it('speaks up in the last ten minutes before the stop where you get off', () => {
    expect(getOff(facts({ departed: true }), live, prefs, T('18:34'), 'en')).toBeNull();
    expect(getOff(facts({ departed: true }), live, prefs, T('18:36'), 'en')!.body).toBe('Get off at Kolding in about 9 min.');
  });
  it('not for another stop, or a train that has not left', () => {
    expect(getOff(facts({ departed: true }), { ...live, nextStopId: 'X' }, prefs, T('18:40'), 'en')).toBeNull();
    expect(getOff(facts(), live, prefs, T('18:40'), 'en')).toBeNull();
  });
});

describe('changes', () => {
  const a = facts({ legId: 'A', to: 'Nässjö', toStationId: 'N', expArr: T('13:20'), arrPlatform: '3', lastInJourney: false });
  const b = (over: Partial<TripFacts> = {}) => facts({ legId: 'B', from: 'Nässjö', to: 'Kolding', expDep: T('13:32'), depPlatform: '5', ...over });
  it('says platforms and minutes to spare, only once the change is close', () => {
    expect(change(a, b(), prefs, T('13:00'), 'en')).toBeNull();
    const c = change(a, b({ expDep: T('13:31') }), prefs, T('13:10'), 'en')!;
    expect(c.title).toBe('Change at Nässjö');
    expect(c.body).toBe('Arrive platform 3, leave platform 5. 11 min to spare.');
  });
  it('leaves out a platform it does not know', () => {
    expect(change(a, b({ depPlatform: null, expDep: T('13:31') }), prefs, T('13:10'), 'en')!.body).toBe('Arrive platform 3. 11 min to spare.');
    expect(change({ ...a, arrPlatform: null }, b({ depPlatform: null, expDep: T('13:31') }), prefs, T('13:10'), 'en')!.body).toBe('11 min to spare.');
  });
  it('calls a tight change tight and a missed one a time-sensitive warning', () => {
    expect(change(a, b({ expDep: T('13:24') }), prefs, T('13:10'), 'en')!.title).toBe('Tight change at Nässjö');
    const miss = change(a, b({ expDep: T('13:17') }), prefs, T('13:10'), 'en')!;
    expect(miss.timeSensitive).toBe(true);
    expect(miss.body).toBe('You arrive 3 min after the train to Kolding leaves Nässjö.');
  });
  it('a later delay is a new alert, the same situation is not', () => {
    const k1 = change(a, b({ expDep: T('13:31') }), prefs, T('13:10'), 'en')!.key;
    const k2 = change({ ...a, expArr: T('13:27') }, b({ expDep: T('13:31') }), prefs, T('13:13'), 'en')!.key;
    expect(k2).not.toBe(k1);
    expect(change(a, b({ expDep: T('13:31') }), prefs, T('13:12'), 'en')!.key).toBe(k1);
  });
  it('warns when the next train is cancelled', () => {
    expect(change(a, b({ canceled: true }), prefs, T('13:10'), 'en')!.body).toBe('Your next train to Kolding is cancelled.');
  });
  it('measures the spare time', () => {
    expect(spareMinutes(a, b())).toBe(12);
    expect(spareMinutes({ ...a, expArr: null }, b())).toBeNull();
  });
});

describe('the moment a trip is in (card and island)', () => {
  const run = { status: 'en_route', nextStopId: 'X', eta: T('14:30') };
  const live = (status: string, over: Partial<typeof run> = {}) => ({ ...run, status, ...over });
  const next = (over: Partial<TripFacts> = {}) => facts({ legId: 'B', from: 'Kolding', to: 'Odense', expDep: T('19:20'), depPlatform: '5', ...over });

  it('is scheduled far off and leaveSoon in the last 30 minutes', () => {
    expect(momentOf(facts(), null, null, null, T('12:00')).phase).toBe('scheduled');
    expect(momentOf(facts(), null, null, null, T('13:05')).phase).toBe('leaveSoon');
  });
  it('follows the live status: approaching, boarding, running', () => {
    expect(momentOf(facts(), live('approaching'), null, null, T('13:10')).phase).toBe('approaching');
    expect(momentOf(facts(), live('boarding'), null, null, T('13:25')).phase).toBe('boarding');
    expect(momentOf(facts({ departed: true }), live('en_route'), null, null, T('14:00')).phase).toBe('enRoute');
  });
  it('says get off soon only when the next stop is where you get off, within ten minutes', () => {
    const f = facts({ departed: true });
    expect(momentOf(f, live('en_route', { nextStopId: 'KD', eta: T('18:45') }), null, null, T('18:34')).phase).toBe('enRoute');
    expect(momentOf(f, live('en_route', { nextStopId: 'KD', eta: T('18:45') }), null, null, T('18:36')).phase).toBe('getOffSoon');
    expect(momentOf(f, live('en_route', { nextStopId: 'OTHER', eta: T('18:45') }), null, null, T('18:40')).phase).toBe('enRoute');
  });
  it('notes a platform change for ten minutes, before the train has left', () => {
    expect(momentOf(facts(), null, null, T('13:00'), T('13:05')).note).toBe('platformChanged');
    expect(momentOf(facts(), null, null, T('13:00'), T('13:15')).note).toBeNull();
    expect(momentOf(facts({ departed: true }), live('en_route'), null, T('13:00'), T('13:05')).note).toBeNull();
  });
  it('is changing trains once arrived with the next train leaving within the hour, else arrived', () => {
    const arrived = facts({ arrived: true, departed: true });
    const m = momentOf(arrived, null, next({ expDep: T('19:20') }), null, T('18:55'));
    expect(m).toMatchObject({ phase: 'changing', changePlatform: '5', changeAt: T('19:20') });
    expect(momentOf(arrived, null, next({ expDep: T('21:00') }), null, T('18:55')).phase).toBe('arrived');
    expect(momentOf(arrived, null, next({ departed: true }), null, T('19:30')).phase).toBe('arrived');
    expect(momentOf(arrived, null, null, null, T('18:55')).phase).toBe('arrived');
  });
  it('cancelled wins over everything', () => {
    expect(momentOf(facts({ canceled: true, arrived: true }), live('boarding'), next(), T('13:00'), T('13:05')).phase).toBe('cancelled');
  });
});
