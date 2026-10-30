// How trains really run each stretch between two stops, learned from the GPS feeds (Sweden, Norway, Finland;
// docs/POSITIONING.md "Learned run curves"). Every fresh fix snapped onto a stretch, while the feed has the train between
// its departure and its expected arrival, is one sample: the share of the time gone (0–1) against the share of the
// track covered (0–1). Kept per stretch in BINS bins of time (sum and count only: no train, no time of day, no fix).
// Once a stretch has MIN_SAMPLES and every bin MIN_PER_BIN, an estimated train on it is placed on the learned curve
// instead of the textbook run profile; until then nothing changes. Riders' reports are not learned from.
export const BINS = 10;
export const MIN_SAMPLES = 60;
export const MIN_PER_BIN = 4;
/** At most this many stretches are kept (the busiest by samples when trimmed). */
export const MAX_STRETCHES = 20_000;

type Curve = { sum: number[]; n: number[] };

export class RunCurves {
  private curves = new Map<string, Curve>();

  static key(prevId: string, nextId: string) {
    return `${prevId}>${nextId}`;
  }

  /** One sample. Ignored outside 0–1 (a feed whose times don't fit the fix). */
  record(key: string, timeShare: number, progress: number) {
    if (!(timeShare > 0 && timeShare < 1 && progress >= 0 && progress <= 1)) return;
    let c = this.curves.get(key);
    if (!c) {
      if (this.curves.size >= MAX_STRETCHES) this.trim();
      c = { sum: Array(BINS).fill(0), n: Array(BINS).fill(0) };
      this.curves.set(key, c);
    }
    const b = Math.min(BINS - 1, Math.floor(timeShare * BINS));
    c.sum[b]! += progress;
    c.n[b]!++;
  }

  /** The learned share of the track at this share of the time, or null while the stretch has too few samples. */
  progressAt(key: string, timeShare: number): number | null {
    const c = this.curves.get(key);
    if (!c || c.n.reduce((a, b) => a + b, 0) < MIN_SAMPLES || c.n.some((n) => n < MIN_PER_BIN)) return null;
    // Bin means at bin middles, never going backwards, pinned at 0 and 1 at the ends.
    const xs = [0], ys = [0];
    let top = 0;
    for (let b = 0; b < BINS; b++) {
      top = Math.max(top, c.sum[b]! / c.n[b]!);
      xs.push((b + 0.5) / BINS);
      ys.push(top);
    }
    xs.push(1);
    ys.push(Math.max(top, 1));
    const t = Math.min(1, Math.max(0, timeShare));
    let i = 1;
    while (i < xs.length - 1 && xs[i]! < t) i++;
    const f = (t - xs[i - 1]!) / (xs[i]! - xs[i - 1]!);
    return Math.min(1, ys[i - 1]! + (ys[i]! - ys[i - 1]!) * f);
  }

  /** How many stretches have a curve in use, for the quality report. */
  summary() {
    let ready = 0, samples = 0;
    for (const [k, c] of this.curves) {
      samples += c.n.reduce((a, b) => a + b, 0);
      if (this.progressAt(k, 0.5) !== null) ready++;
    }
    return { stretches: this.curves.size, ready, samples };
  }

  private trim() {
    const by = [...this.curves].sort((a, b) => a[1].n.reduce((x, y) => x + y, 0) - b[1].n.reduce((x, y) => x + y, 0));
    for (const [k] of by.slice(0, Math.ceil(by.length / 10))) this.curves.delete(k);
  }

  toJSON() {
    return Object.fromEntries(this.curves);
  }

  static from(o: Record<string, Curve> | undefined): RunCurves {
    const r = new RunCurves();
    for (const [k, c] of Object.entries(o ?? {})) if (Array.isArray(c?.sum) && c.sum.length === BINS) r.curves.set(k, { sum: [...c.sum], n: [...c.n] });
    return r;
  }
}
