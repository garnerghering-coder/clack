import { describe, expect, it } from 'vitest';
import { buildApp } from '../src/app.js';
import { openDb } from '../src/db/client.js';
import { addDays, todayIn } from '../src/lib/time.js';

describe('/history/prepare', () => {
  const app = buildApp(openDb(':memory:'));
  const get = (date: string) => app.inject({ url: `/api/history/prepare?date=${date}` });

  it('says ready for days the current timetable covers', async () => {
    const res = await get(todayIn('Europe/Stockholm'));
    expect(res.json()).toEqual({ sweden: 'ready', norway: 'ready', finland: 'ready' });
    expect((await get(addDays(todayIn('Europe/Stockholm'), -1))).json()).toEqual({ sweden: 'ready', norway: 'ready', finland: 'ready' });
  });

  it('answers at once for days before the archive, and refuses a bad date', async () => {
    // Before Sweden's archive (2012), Finland's record (2016) and Norway's (2020).
    expect((await get('2011-05-01')).json()).toEqual({ sweden: 'unavailable', norway: 'unavailable', finland: 'unavailable' });
    expect((await get('yesterday')).statusCode).toBe(400);
  });
});
