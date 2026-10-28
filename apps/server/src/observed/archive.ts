// The raw archive: every answer an observed-record collector gets, exactly as the source sent it, one file per fetch.
// Files are written once and never changed (a refetch of the same day is a new file; the newest is the most complete),
// so nothing the projection leaves out is ever lost and any day can be re-derived later. NDJSON, one record per line,
// brotli-compressed (built into Node; a Swedish day of Trafikverket announcements is ~4 MB raw per hour, ~0.14 MB packed).
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { promisify } from 'node:util';

const brotli = promisify(zlib.brotliCompress);
import { REPO_ROOT } from '../env.js';

export const OBSERVED_DIR = process.env.OBSERVED_DIR ?? path.join(REPO_ROOT, 'data/observed');

/** data/observed/<source>/<yyyy>/<date>/ */
export function dayDir(source: string, date: string, root = OBSERVED_DIR): string {
  return path.join(root, source, date.slice(0, 4), date);
}

/**
 * Write one fetch's records. `kind` names what was fetched (announcements, messages, trains, compositions …), so a
 * day's folder holds e.g. `announcements-2026-10-27T03-10-00Z.ndjson.br`. Written to a temporary name first, then
 * renamed, so a half-written file never looks complete. Returns the file's path.
 */
/**
 * Brotli runs on the thread pool (not the event loop): a day's Swedish record compressed in-line held the server for
 * ~15 s (profiled 2026-10-28).
 */
export async function writeRaw(source: string, date: string, kind: string, records: unknown[], opts: { root?: string; now?: number } = {}): Promise<string> {
  const dir = dayDir(source, date, opts.root);
  fs.mkdirSync(dir, { recursive: true });
  const stamp = new Date(opts.now ?? Date.now()).toISOString().replace(/:/g, '-').replace(/\.\d+Z$/, 'Z');
  let file = path.join(dir, `${kind}-${stamp}.ndjson.br`);
  for (let i = 2; fs.existsSync(file); i++) file = path.join(dir, `${kind}-${stamp}-${i}.ndjson.br`);
  const body = records.map((r) => JSON.stringify(r)).join('\n') + (records.length ? '\n' : '');
  const packed = await brotli(body, { params: { [zlib.constants.BROTLI_PARAM_QUALITY]: 9, [zlib.constants.BROTLI_PARAM_SIZE_HINT]: body.length } });
  fs.writeFileSync(`${file}.part`, packed);
  fs.renameSync(`${file}.part`, file);
  return file;
}

/** Read one raw file back. */
export function readRaw<T = unknown>(file: string): T[] {
  const text = zlib.brotliDecompressSync(fs.readFileSync(file)).toString('utf8');
  return text
    .split('\n')
    .filter(Boolean)
    .map((l) => JSON.parse(l) as T);
}

/** The raw files for one day and kind, oldest first. */
export function rawFiles(source: string, date: string, kind: string, root = OBSERVED_DIR): string[] {
  const dir = dayDir(source, date, root);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.startsWith(`${kind}-`) && f.endsWith('.ndjson.br'))
    .sort()
    .map((f) => path.join(dir, f));
}
