// `npm run import -- position-check`: the numbers behind docs/POSITIONING.md (BUILDOUT "Measuring it").
// Either runs the Swedish live-map ingest here for a few minutes (Trafikverket's stream, this machine's key) and
// reports what live/quality.ts counted, or asks a running server for its counters (--server, --admin). Nothing is
// written to the database. The report is Markdown, to paste into the docs.
import type { Db } from '../db/client.js';
import { railGraph } from '../geo/railGraph.js';
import { LiveMapIngest } from '../livemap/ingest.js';
import type { HistogramSummary, QualityReport } from '../live/quality.js';

export interface PositionCheckOptions {
  /** How long to listen to Trafikverket here (default 10). Ignored with --server. */
  minutes?: number;
  /** A running server to read the counters from, with its admin token. */
  server?: string;
  admin?: string;
  log?: (m: string) => void;
}

export async function positionCheck(db: Db, opts: PositionCheckOptions = {}): Promise<{ report: QualityReport; markdown: string }> {
  const log = opts.log ?? (() => {});
  let report: QualityReport;
  if (opts.server) {
    const res = await fetch(`${opts.server.replace(/\/$/, '')}/api/live/quality`, { headers: { 'x-clack-admin': opts.admin ?? '' } });
    if (!res.ok) throw new Error(`${opts.server}: HTTP ${res.status} (is the admin token right?)`);
    report = (await res.json()) as QualityReport;
  } else {
    const minutes = opts.minutes ?? 10;
    const ingest = new LiveMapIngest(db, { graph: railGraph, norway: false, finland: false, denmark: false, qualityFile: null, log });
    ingest.acquire();
    const until = Date.now() + minutes * 60_000;
    while (Date.now() < until) {
      await new Promise((r) => setTimeout(r, 30_000));
      const r = ingest.quality.report();
      log(`${new Date().toISOString().slice(11, 19)} trains ${ingest.trains.size}, fixes ${r.delivery.trafikverket?.n ?? 0}, check samples ${Object.values(r.check.running).reduce((n, x) => n + x.old.n, 0)}`);
    }
    ingest.stop();
    report = ingest.quality.report();
  }
  return { report, markdown: formatReport(report) };
}

const num = (v: number | null) => (v === null ? '–' : String(v));
const row = (cells: (string | number | null)[]) => `| ${cells.map((c) => (typeof c === 'number' || c === null ? num(c) : c)).join(' | ')} |`;
const histRows = (title: string, hists: Record<string, HistogramSummary>, unit: string) => {
  const keys = Object.keys(hists);
  if (!keys.length) return [`### ${title}`, '', 'No samples yet.', ''];
  const edges = Object.keys(hists[keys[0]!]!.buckets);
  return [
    `### ${title}`,
    '',
    row(['', 'n', `median ${unit}`, `p90 ${unit}`, ...edges]),
    row(['---', '---', '---', '---', ...edges.map(() => '---')]),
    ...keys.map((k) => row([k, hists[k]!.n, hists[k]!.median, hists[k]!.p90, ...edges.map((e) => hists[k]!.buckets[e] ?? 0)])),
    '',
  ];
};

/** The report as Markdown, for docs/POSITIONING.md. Pure. */
export function formatReport(r: QualityReport): string {
  const lines: string[] = [`Counting since ${new Date(r.since).toISOString()}${r.savedAt ? `, last saved ${new Date(r.savedAt).toISOString()}` : ''}; ${r.fixesTracked} trains with fixes in the ring.`, ''];
  lines.push(...histRows('Delivery lag per source (receive time − fix timestamp, seconds)', r.delivery, 's'));
  lines.push(...histRows('Timestamp offset per source, product and passage kind (fixes passed − reported, seconds; positive: the fixes run late)', r.offset, 's'));
  const running = Object.keys(r.check.running);
  lines.push('### Position check: estimate vs the fix that came (metres)', '');
  if (!running.length) lines.push('No samples yet.', '');
  else {
    lines.push(row(['product', 'n', 'old median', 'old p90', 'new median', 'new p90']), row(['---', '---', '---', '---', '---', '---']));
    for (const k of running) {
      const c = r.check.running[k]!;
      lines.push(row([k, c.old.n, c.old.median, c.old.p90, c.new.median, c.new.p90]));
    }
    lines.push('');
  }
  lines.push(...histRows('Standing placement: platform point vs the fix of a train reported standing there (metres)', r.check.standing, 'm'));
  lines.push('### Track side: raw fix nearer the chosen track than the parallel one', '');
  const sides = Object.keys(r.side);
  if (!sides.length) lines.push('No double-track samples yet.', '');
  else {
    lines.push(row(['country', 'agree', 'disagree', 'share']), row(['---', '---', '---', '---']));
    for (const c of sides) lines.push(row([c, r.side[c]!.agree, r.side[c]!.disagree, r.side[c]!.agreeShare]));
    lines.push('');
  }
  return lines.join('\n');
}
