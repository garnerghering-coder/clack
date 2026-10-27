// Reading the observed record for a saved trip: what actually happened at each of its stops, once the live sources
// have forgotten (Trafikverket after ~4 days, Entur after the day, Digitraffic for days older than it is asked about).
// A stop is matched to a recorded call by station and scheduled minute, the way live reports are.
import type { DelayCause } from '@clack/shared';
import type { Db } from '../db/client.js';
import type { StopActuals } from '../legs/actuals.js';
import { addDays } from '../lib/time.js';
import { bigQueryEnabled, HISTORY_START as NO_HISTORY_START } from './bigquery.js';
import { HISTORY_START as DK_HISTORY_START } from './dk-archive.js';
import { HISTORY_START as FI_HISTORY_START } from './finland.js';

export interface StopForRecord {
  seq: number;
  stationId: string;
  schedArr: number | null;
  schedDep: number | null;
}

interface CallRow {
  station_id: string | null;
  sched_arr: number | null;
  sched_dep: number | null;
  actual_arr: number | null;
  actual_dep: number | null;
  platform: string | null;
  canceled_arr: number;
  canceled_dep: number;
  causes: string;
  source: string;
  run_id: string;
}

const SOURCE_NAME: Record<string, StopActuals['source']> = { trafikverket: 'trafikverket', digitraffic: 'digitraffic', entur: 'entur', 'entur-bigquery': 'entur', train_archive_dk: 'rejseplanen' };
const minute = (t: number | null) => (t === null ? null : Math.floor(t / 60_000));

/** The record's causes in the form legs store them (the app maps codes to its own words). */
function legCauses(stored: string): DelayCause[] {
  try {
    return (JSON.parse(stored) as { src: string; code?: string; text?: string }[]).map((c) =>
      c.src === 'dt' ? { src: 'digitraffic', ...(c.code ? { code: c.code } : {}) } : c.src === 'entur' ? { src: 'entur', ...(c.text ? { text: c.text } : {}) } : (c as DelayCause),
    );
  } catch {
    return [];
  }
}

/**
 * What the record has for a trip's stops: train `number` on `serviceDate` (and the day before, for a train that
 * started then). Stops with nothing recorded are left out.
 */
export function recordedStops(db: Db, q: { trainNumber: string | null; serviceDate: string; stops: StopForRecord[] }): Map<number, StopActuals> {
  const out = new Map<number, StopActuals>();
  if (!q.trainNumber) return out;
  const calls = db.$client
    .prepare(
      `select c.station_id, c.sched_arr, c.sched_dep, c.actual_arr, c.actual_dep, c.platform, c.canceled_arr, c.canceled_dep, c.causes, r.source, r.run_id
       from observed_runs r join observed_calls c on c.country = r.country and c.service_date = r.service_date and c.run_id = r.run_id
       where r.train_number = ? and r.service_date in (?, ?)`,
    )
    .all(q.trainNumber, q.serviceDate, addDays(q.serviceDate, -1)) as CallRow[];
  if (!calls.length) return out;
  const used = new Set<CallRow>();
  for (const s of q.stops) {
    const c = calls.find(
      (c) =>
        !used.has(c) &&
        c.station_id === s.stationId &&
        ((s.schedDep !== null && minute(c.sched_dep) === minute(s.schedDep)) || (s.schedArr !== null && minute(c.sched_arr) === minute(s.schedArr))),
    );
    if (!c) continue;
    used.add(c);
    const causes = legCauses(c.causes);
    out.set(s.seq, {
      seq: s.seq,
      actualArr: c.actual_arr,
      actualDep: c.actual_dep,
      estimatedArr: null,
      estimatedDep: null,
      platform: c.platform,
      canceled: Boolean(c.canceled_arr || c.canceled_dep),
      deviations: causes.map((x) => x.text).filter((t): t is string => !!t),
      causes,
      trvTrainNumber: c.source === 'trafikverket' ? c.run_id : null,
      composition: null,
      onboard: null,
      source: SOURCE_NAME[c.source] ?? null,
    });
  }
  return out;
}

/**
 * Could the record still bring this day's actual times for a trip in `country`? True while a backfill hasn't reached
 * the day yet (Norway back to 2020 once BigQuery is set up, Finland back to 2016) or the day isn't final; a trip isn't
 * frozen as timetable-only while that's so.
 */
export function recordPending(db: Db, country: string, serviceDate: string): boolean {
  const fetch = (source: string, kind: string) =>
    db.$client.prepare(`select final from observed_fetches where source = ? and kind = ? and date = ?`).get(source, kind, serviceDate) as { final: number } | undefined;
  if (country === 'FI') return serviceDate >= FI_HISTORY_START && !fetch('digitraffic', 'trains')?.final;
  // Denmark's finished days come from train-archive.eu each morning, from the archive's first day.
  if (country === 'DK') return serviceDate >= DK_HISTORY_START && !fetch('train_archive_dk', 'tripupdate')?.final;
  if (country === 'NO') return bigQueryEnabled() && serviceDate >= NO_HISTORY_START && !fetch('entur-bigquery', 'siri-et');
  return false;
}
