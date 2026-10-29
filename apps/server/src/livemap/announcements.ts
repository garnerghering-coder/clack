// Delay, origin/destination and next stop for every running train, for the live map (ADDITIONS_01 A).
// One TrainAnnouncement window (an hour back to two ahead) loaded in full, then kept current with Trafikverket's
// `changeid` deltas, and re-based every 20 minutes so the window moves with the clock.
import { delayMinutes } from '@clack/shared';
import { actualTime, trvQuery } from '../trafikverket/client.js';
import { isTrain, type TrvBoardRow } from '../boards/board.js';
import { parseComposition, type Composition } from '../legs/trainTypes.js';
import { trvCauses } from '../legs/causes.js';
import type { DelayCause } from '@clack/shared';

interface AnnRow extends TrvBoardRow {
  LocationSignature: string;
  ScheduledDepartureDateTime?: string;
  /** The passage time to the second (TimeAtLocation is the minute). */
  TimeAtLocationWithSeconds?: string;
}

export interface TrainInfo {
  number: string;
  date: string;
  productName: string | null;
  operatorText: string | null;
  isTrain: boolean;
  originSig: string | null;
  destinationSig: string | null;
  /** Last stop passed (actual time known) and the next one ahead. */
  lastSig: string | null;
  /** When it passed the last stop, and whether that was arriving (so it's standing there now) or leaving. */
  lastAt: number | null;
  lastWasArrival: boolean;
  nextSig: string | null;
  nextEta: number | null;
  /** The advertised time at the next stop (before the train has left: its first departure), for "waiting" (BUILDOUT §A.3). */
  nextAdvertised: number | null;
  /** Tracks at the last stop passed and the next one (TrackAtLocation; "x" means none), for platform placement (§A.2). */
  lastTrack: string | null;
  nextTrack: string | null;
  /** When it passed the last stop, to the second, for the GPS timestamp check (§A.8); null when only the minute is known. */
  lastAtSeconds: number | null;
  delayMin: number | null;
  canceled: boolean;
  /** Planned coach order, from the first departure that has one. */
  composition: Composition | null;
  /** Trafikverket's reasons at the last stop passed and the next one ("Signalfel", "Olycka"); platform changes left out. */
  causes: DelayCause[];
}

const BEFORE_MS = 60 * 60_000;
const AFTER_MS = 2 * 3600_000;
const REBASE_MS = 20 * 60_000;
const SLICE_MS = 30 * 60_000;
const FIELDS = [
  'ActivityId',
  'ActivityType',
  'AdvertisedTimeAtLocation',
  'AdvertisedTrainIdent',
  'Canceled',
  'Deleted',
  'EstimatedTimeAtLocation',
  'TimeAtLocation',
  'LocationSignature',
  'ToLocation',
  'FromLocation',
  'ProductInformation',
  'TypeOfTraffic',
  'Operator',
  'ScheduledDepartureDateTime',
  'TrainComposition',
  'Deviation',
  'TrackAtLocation',
  'TimeAtLocationWithSeconds',
];

const track = (r: AnnRow | null) => (r?.TrackAtLocation && r.TrackAtLocation !== 'x' ? r.TrackAtLocation : null);

export const trainKey = (number: string, date: string) => `${number}|${date}`;

/** What one train's announcements say about it now. Pure, for tests. */
export function summarizeTrain(rows: AnnRow[], now: number): TrainInfo | null {
  if (!rows.length) return null;
  const sorted = [...rows].sort((a, b) => Date.parse(a.AdvertisedTimeAtLocation) - Date.parse(b.AdvertisedTimeAtLocation) || (a.ActivityType === 'Ankomst' ? -1 : 1));
  const first = sorted[0]!;
  let last: AnnRow | null = null;
  for (const r of sorted) if (r.TimeAtLocation) last = r;
  const lastAdv = last ? Date.parse(last.AdvertisedTimeAtLocation) : -Infinity;
  const ahead = sorted.filter((r) => !r.TimeAtLocation && Date.parse(r.AdvertisedTimeAtLocation) >= lastAdv);
  const next = ahead.find((r) => !r.Canceled) ?? null;
  const lastDelay = last ? delayMinutes(Date.parse(last.AdvertisedTimeAtLocation), actualTime(last.TimeAtLocation, last.AdvertisedTimeAtLocation)) : null;
  const est = next?.EstimatedTimeAtLocation ? Date.parse(next.EstimatedTimeAtLocation) : null;
  const nextAdv = next ? Date.parse(next.AdvertisedTimeAtLocation) : null;
  const delayMin = est !== null && nextAdv !== null ? delayMinutes(nextAdv, est) : lastDelay;
  return {
    number: first.AdvertisedTrainIdent,
    date: (first.ScheduledDepartureDateTime ?? first.AdvertisedTimeAtLocation).slice(0, 10),
    productName: first.ProductInformation?.[0]?.Description ?? null,
    operatorText: first.Operator ?? null,
    isTrain: sorted.every(isTrain),
    originSig: first.FromLocation?.[0]?.LocationName ?? null,
    destinationSig: first.ToLocation?.[0]?.LocationName ?? null,
    lastSig: last?.LocationSignature ?? null,
    lastAt: last ? actualTime(last.TimeAtLocation, last.AdvertisedTimeAtLocation) : null,
    lastWasArrival: last?.ActivityType === 'Ankomst',
    nextSig: next?.LocationSignature ?? null,
    nextEta: est ?? (nextAdv !== null ? nextAdv + (lastDelay ?? 0) * 60_000 : null),
    nextAdvertised: nextAdv,
    lastTrack: track(last),
    nextTrack: track(next),
    lastAtSeconds: last?.TimeAtLocationWithSeconds ? actualTime(last.TimeAtLocationWithSeconds, last.AdvertisedTimeAtLocation) : null,
    delayMin,
    // Everything still ahead is cancelled (and something is ahead): the train isn't running any more.
    composition: sorted.map((r) => (r.ActivityType === 'Avgang' ? parseComposition(r.TrainComposition) : null)).find(Boolean) ?? null,
    causes: [...new Map([last, next].flatMap((r) => trvCauses(r?.Deviation)).filter((c) => c.code?.toUpperCase() !== 'ANA055' && c.text?.toLowerCase() !== 'spårändrat').map((c) => [c.code ?? c.text, c])).values()],
    canceled: ahead.length > 0 && ahead.every((r) => r.Canceled) && now < Date.parse(ahead.at(-1)!.AdvertisedTimeAtLocation) + 30 * 60_000,
  };
}

export class AnnouncementCache {
  private rows = new Map<string, AnnRow>();
  private byTrain = new Map<string, Set<string>>();
  private changeId = '0';
  private windowFrom = 0;
  private lastFull = 0;
  private summaries = new Map<string, TrainInfo>();
  private dirty = true;

  constructor(private opts: { fetchImpl?: typeof fetch; now?: () => number; log?: (m: string) => void } = {}) {}

  private now() {
    return (this.opts.now ?? Date.now)();
  }

  private keyOf(r: AnnRow) {
    return trainKey(r.AdvertisedTrainIdent, (r.ScheduledDepartureDateTime ?? r.AdvertisedTimeAtLocation).slice(0, 10));
  }

  private put(r: AnnRow) {
    const old = this.rows.get(r.ActivityId);
    if (old) this.byTrain.get(this.keyOf(old))?.delete(r.ActivityId);
    if (r.Deleted) {
      this.rows.delete(r.ActivityId);
      return;
    }
    this.rows.set(r.ActivityId, r);
    const k = this.keyOf(r);
    (this.byTrain.get(k) ?? this.byTrain.set(k, new Set()).get(k)!).add(r.ActivityId);
  }

  private query(from: number, to: number, changeId: string) {
    return trvQuery<{ TrainAnnouncement?: AnnRow[]; INFO?: { LASTCHANGEID?: string } }>(
      `<QUERY objecttype="TrainAnnouncement" schemaversion="1.9" changeid="${changeId}"><FILTER>` +
        `<EQ name="Advertised" value="true"/><GTE name="AdvertisedTimeAtLocation" value="${new Date(from).toISOString()}"/>` +
        `<LT name="AdvertisedTimeAtLocation" value="${new Date(to).toISOString()}"/></FILTER>${FIELDS.map((f) => `<INCLUDE>${f}</INCLUDE>`).join('')}</QUERY>`,
      this.opts.fetchImpl,
    );
  }

  /**
   * Full reload (first time and every 20 minutes) or a cheap delta since the last change id. The full load goes in
   * half-hour slices, all at once, each retried once: a nationwide query takes Trafikverket 10–60 s whatever its
   * size and sometimes fails with "Internal error". Slices that arrive are used straight away, and what's already
   * known is kept until replaced, so one failed slice doesn't blank the map. Until every slice has come through,
   * the next refresh tries the full load again.
   */
  async refresh(): Promise<void> {
    const now = this.now();
    if (now - this.lastFull > REBASE_MS) {
      const from = now - BEFORE_MS;
      const starts: number[] = [];
      for (let t = from; t < from + BEFORE_MS + AFTER_MS; t += SLICE_MS) starts.push(t);
      const ids: (string | null)[] = await Promise.all(
        starts.map(async (t) => {
          for (let attempt = 0; ; attempt++) {
            try {
              const r = await this.query(t, t + SLICE_MS, '0');
              for (const row of r.TrainAnnouncement ?? []) this.put(row);
              this.dirty = true;
              return r.INFO?.LASTCHANGEID ?? null;
            } catch (e) {
              if (attempt >= 1) {
                this.opts.log?.(`live map: announcements ${new Date(t).toISOString().slice(11, 16)}+30 min failed: ${(e as Error).message.slice(0, 120)}`);
                return null;
              }
            }
          }
        }),
      );
      // Rows that slid out of the window.
      for (const [id, row] of this.rows) if (Date.parse(row.AdvertisedTimeAtLocation) < from) this.put({ ...row, ActivityId: id, Deleted: true });
      this.windowFrom = from;
      if (ids.every((id) => id !== null)) {
        this.lastFull = now;
        // The lowest id of the slices: deltas from there may repeat a row, but never miss one.
        this.changeId = ids.reduce((lo, id) => (BigInt(id!) < BigInt(lo!) ? id : lo))!;
      }
    } else {
      // Deltas keep the same window as the last full load; trains entering it later arrive with the next re-base.
      const r = await this.query(this.windowFrom, this.windowFrom + BEFORE_MS + AFTER_MS, this.changeId);
      for (const row of r.TrainAnnouncement ?? []) this.put(row);
      if (r.INFO?.LASTCHANGEID) this.changeId = r.INFO.LASTCHANGEID;
    }
    this.dirty = true;
  }

  /** The train behind a position report, by advertised number and date. */
  info(number: string, date: string): TrainInfo | null {
    if (this.dirty) {
      this.summaries.clear();
      this.dirty = false;
    }
    const k = trainKey(number, date);
    let s = this.summaries.get(k);
    if (s === undefined) {
      const ids = this.byTrain.get(k);
      s = summarizeTrain(ids ? [...ids].map((id) => this.rows.get(id)!).filter(Boolean) : [], this.now()) ?? undefined;
      if (s) this.summaries.set(k, s);
    }
    return s ?? null;
  }

  /** Every train in the window, as [number, date]. */
  *trains(): Generator<[string, string]> {
    for (const k of this.byTrain.keys()) yield k.split('|') as [string, string];
  }

  /** Every slice of the window has loaded at least once. */
  get complete() {
    return this.lastFull > 0;
  }

  get size() {
    return this.rows.size;
  }
}
