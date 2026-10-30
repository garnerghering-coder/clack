// What the positioning is worth, measured while it runs (BUILDOUT §A.8 and "Measuring it"; docs/POSITIONING.md).
// Kept in memory per server, saved to data/cache/live-quality.json now and then so a restart doesn't lose the day,
// and read by the admin-only GET /api/live/quality and the `position-check` command.
//
// Four things are counted, each per source (and product where it matters):
// - delivery lag: our receive time minus the fix's own timestamp;
// - timestamp offset: when the run of fixes passed a station's point minus the time the feed reported for that
//   passage (TimeAtLocationWithSeconds, Digitraffic actualTime); positive = the fixes' clock runs late;
// - the position check: how far the estimate (old rule and new rule, both worked out at the fix's time) is from the
//   GPS fix that arrived, and how far the platform point is from a fix of a train reported standing there;
// - track-side agreement: whether the raw fix lay nearer the track the running-side rule chose than the other one.
import { RunCurves } from './runCurves.js';
import fs from 'node:fs';
import path from 'node:path';
import { crossingTime, passageTime } from './positioning.js';

export type Source = 'trafikverket' | 'entur' | 'digitraffic' | 'rejseplanen';

/** Counts per bucket plus a bounded sample for percentiles (reservoir sampling, so the sample stays representative). */
export class Histogram {
  readonly counts: number[];
  n = 0;
  sum = 0;
  private sample: number[] = [];
  private static readonly SAMPLE = 4000;

  /** `edges` are upper bounds; everything above the last edge goes in one more bucket. */
  constructor(readonly edges: number[]) {
    this.counts = new Array(edges.length + 1).fill(0);
  }

  add(v: number) {
    if (!Number.isFinite(v)) return;
    this.n++;
    this.sum += v;
    let i = 0;
    while (i < this.edges.length && v > this.edges[i]!) i++;
    this.counts[i]!++;
    if (this.sample.length < Histogram.SAMPLE) this.sample.push(v);
    else {
      const j = Math.floor(Math.random() * this.n);
      if (j < Histogram.SAMPLE) this.sample[j] = v;
    }
  }

  percentile(p: number): number | null {
    if (!this.sample.length) return null;
    const s = [...this.sample].sort((a, b) => a - b);
    return s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))]!;
  }

  summary(): HistogramSummary {
    const buckets: Record<string, number> = {};
    this.edges.forEach((e, i) => {
      buckets[`≤${e}`] = this.counts[i]!;
    });
    buckets[`>${this.edges.at(-1)}`] = this.counts[this.edges.length]!;
    return { n: this.n, mean: this.n ? round(this.sum / this.n) : null, median: round(this.percentile(50)), p90: round(this.percentile(90)), buckets };
  }

  toJSON() {
    return { edges: this.edges, counts: this.counts, n: this.n, sum: this.sum, sample: this.sample };
  }

  static from(j: ReturnType<Histogram['toJSON']>): Histogram {
    const h = new Histogram(j.edges);
    j.counts.forEach((c, i) => (h.counts[i] = c));
    h.n = j.n;
    h.sum = j.sum;
    h.sample = j.sample.slice(0, Histogram.SAMPLE);
    return h;
  }
}

export interface HistogramSummary {
  n: number;
  mean: number | null;
  median: number | null;
  p90: number | null;
  buckets: Record<string, number>;
}

const round = (v: number | null) => (v === null ? null : Math.round(v * 10) / 10);

/** Seconds of delivery lag. */
const LAG_EDGES = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144];
/** Seconds of timestamp offset, signed. */
const OFFSET_EDGES = [-60, -30, -15, -8, -4, -2, 0, 2, 4, 8, 15, 30, 60];
/** Metres between an estimate and the fix that came. */
const ERR_EDGES = [25, 50, 100, 200, 400, 800, 1600, 3200];

interface Fix {
  lat: number;
  lon: number;
  at: number;
}

export interface QualityReport {
  /** Learned run curves: stretches seen, those with a curve in use, samples. */
  curves: { stretches: number; ready: number; samples: number };
  since: number;
  savedAt: number | null;
  delivery: Record<string, HistogramSummary>;
  offset: Record<string, HistogramSummary>;
  check: { running: Record<string, { old: HistogramSummary; new: HistogramSummary }>; standing: Record<string, HistogramSummary> };
  side: Record<string, { agree: number; disagree: number; agreeShare: number | null }>;
  fixesTracked: number;
}

export class LiveQuality {
  /** Learned run curves per stretch (live/runCurves.ts); saved with the counters, never pruned by them. */
  curves = new RunCurves();
  readonly since: number;
  private delivery = new Map<string, Histogram>();
  private offset = new Map<string, Histogram>();
  private checkOld = new Map<string, Histogram>();
  private checkNew = new Map<string, Histogram>();
  private standing = new Map<string, Histogram>();
  private side = new Map<string, { agree: number; disagree: number }>();
  /** The last fixes per train, for passage times. */
  private fixes = new Map<string, Fix[]>();
  /** Passages already measured, so a re-summarised train isn't counted twice. */
  private measured = new Map<string, number>();
  private savedAt: number | null = null;
  private static readonly RING = 40;

  constructor(private readonly now: () => number = Date.now) {
    this.since = now();
  }

  private get<T>(m: Map<string, T>, k: string, make: () => T): T {
    const v = m.get(k);
    if (v) return v;
    const n = make();
    m.set(k, n);
    return n;
  }

  /** A fix accepted from a feed: its delivery lag, and the fix into the train's ring. */
  recordFix(source: Source, key: string, fix: Fix, receivedAt: number) {
    this.get(this.delivery, source, () => new Histogram(LAG_EDGES)).add((receivedAt - fix.at) / 1000);
    const ring = this.get(this.fixes, key, () => []);
    if (ring.length && ring.at(-1)!.at >= fix.at) return;
    ring.push({ lat: fix.lat, lon: fix.lon, at: fix.at });
    if (ring.length > LiveQuality.RING) ring.shift();
  }

  /**
   * The feed reported the train at `station` at `reportedAt` (seconds precision): compare with when its fixes got
   * there. An arrival is compared with the fixes first coming within 150 m of the point, a departure with their last
   * leaving it, and a passage without a stop with the closest approach. Each (train, station, kind, time) is measured
   * once. Returns the offset in seconds (positive: the fixes' clock runs late), or null when the fixes don't cover it.
   */
  recordPassage(source: Source, product: string, key: string, station: { lat: number; lon: number }, reportedAt: number, kind: 'arr' | 'dep' | 'pass'): number | null {
    const id = `${key}|${kind}|${station.lat.toFixed(4)},${station.lon.toFixed(4)}`;
    if (this.measured.get(id) === reportedAt) return null;
    const ring = this.fixes.get(key);
    if (!ring) return null;
    const passed = kind === 'pass' ? passageTime(ring, station) : crossingTime(ring, station, kind === 'arr' ? 'in' : 'out');
    if (passed === null) return null;
    this.measured.set(id, reportedAt);
    if (this.measured.size > 20_000) this.measured.delete(this.measured.keys().next().value!);
    const s = (passed - reportedAt) / 1000;
    this.get(this.offset, `${source}|${product}|${kind}`, () => new Histogram(OFFSET_EDGES)).add(s);
    return s;
  }

  /** A fix arrived for a train that had an estimate: how far off each rule was. */
  recordCheck(product: string, oldErrM: number, newErrM: number) {
    this.get(this.checkOld, product, () => new Histogram(ERR_EDGES)).add(oldErrM);
    this.get(this.checkNew, product, () => new Histogram(ERR_EDGES)).add(newErrM);
  }

  /** A fix for a train reported standing at a mapped station: how far it was from the platform point we would draw. */
  recordStanding(stationName: string, errM: number) {
    this.get(this.standing, stationName, () => new Histogram(ERR_EDGES)).add(errM);
  }

  /** Whether the raw fix was nearer the chosen track than the parallel one. */
  recordSide(country: string, agree: boolean) {
    const s = this.get(this.side, country, () => ({ agree: 0, disagree: 0 }));
    if (agree) s.agree++;
    else s.disagree++;
  }

  prune(before: number) {
    for (const [k, ring] of this.fixes) if (ring.at(-1)!.at < before) this.fixes.delete(k);
  }

  report(): QualityReport {
    const sum = (m: Map<string, Histogram>) => Object.fromEntries([...m].sort().map(([k, h]) => [k, h.summary()]));
    const running: QualityReport['check']['running'] = {};
    for (const [k, h] of [...this.checkOld].sort()) running[k] = { old: h.summary(), new: this.checkNew.get(k)!.summary() };
    const side: QualityReport['side'] = {};
    for (const [k, s] of [...this.side].sort()) side[k] = { ...s, agreeShare: s.agree + s.disagree ? Math.round((100 * s.agree) / (s.agree + s.disagree)) / 100 : null };
    return { since: this.since, savedAt: this.savedAt, delivery: sum(this.delivery), offset: sum(this.offset), check: { running, standing: sum(this.standing) }, side, fixesTracked: this.fixes.size, curves: this.curves.summary() };
  }

  /** Written to disk (and read back on start) so a restart keeps the day's numbers. Fix rings are not kept. */
  save(file: string) {
    const j = (m: Map<string, Histogram>) => Object.fromEntries([...m].map(([k, h]) => [k, h.toJSON()]));
    this.savedAt = this.now();
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify({ since: this.since, savedAt: this.savedAt, delivery: j(this.delivery), offset: j(this.offset), checkOld: j(this.checkOld), checkNew: j(this.checkNew), standing: j(this.standing), side: Object.fromEntries(this.side), curves: this.curves.toJSON() }));
  }

  static load(file: string, now: () => number = Date.now): LiveQuality {
    const q = new LiveQuality(now);
    try {
      const j = JSON.parse(fs.readFileSync(file, 'utf8')) as Record<string, Record<string, ReturnType<Histogram['toJSON']>>> & { since: number; savedAt: number | null };
      const back = (m: Map<string, Histogram>, o: Record<string, ReturnType<Histogram['toJSON']>> | undefined) => {
        for (const [k, h] of Object.entries(o ?? {})) m.set(k, Histogram.from(h));
      };
      (q as { since: number }).since = j.since;
      q.savedAt = j.savedAt;
      back(q.delivery, j.delivery);
      back(q.offset, j.offset);
      back(q.checkOld, j.checkOld);
      back(q.checkNew, j.checkNew);
      back(q.standing, j.standing);
      for (const [k, s] of Object.entries((j.side ?? {}) as unknown as Record<string, { agree: number; disagree: number }>)) q.side.set(k, { ...s });
      q.curves = RunCurves.from((j as unknown as { curves?: Parameters<typeof RunCurves.from>[0] }).curves);
    } catch {
      // No file yet, or an older shape: start fresh.
    }
    return q;
  }
}
