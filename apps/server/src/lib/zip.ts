// Streams CSV files straight out of a GTFS zip (no extraction: sweden.zip unpacks to ~4 GB).
import readline from 'node:readline';
import type { Readable } from 'node:stream';
import yauzl from 'yauzl';
import { parseCsvLine } from './csv.js';

export type Row = Record<string, string>;

/** Entry names in the zip. Old Sverige 2 archives nest files in a folder, so match on the basename too. */
export async function listEntries(zipPath: string): Promise<string[]> {
  // openPromise uses autoClose: the file closes once all entries (and open streams) are done.
  const zip = await yauzl.openPromise(zipPath);
  const names: string[] = [];
  for await (const entry of zip.eachEntry()) names.push(entry.fileName);
  return names;
}

export function resolveEntry(names: string[], name: string): string | undefined {
  return names.find((n) => n === name) ?? names.find((n) => n.endsWith(`/${name}`));
}

/** Async iterator over the rows of one CSV file in the zip. Yields nothing if the file is missing. */
export async function* readCsv(zipPath: string, name: string): AsyncGenerator<Row> {
  const zip = await yauzl.openPromise(zipPath);
  for await (const entry of zip.eachEntry()) {
    if (entry.fileName !== name && !entry.fileName.endsWith(`/${name}`)) continue;
    {
      const stream: Readable = await zip.openReadStreamPromise(entry);
      const lines = readline.createInterface({ input: stream, crlfDelay: Infinity });
      let header: string[] | undefined;
      for await (const line of lines) {
        if (!header) {
          header = parseCsvLine(line.replace(/^\uFEFF/, ''));
          continue;
        }
        if (!line) continue;
        const values = parseCsvLine(line);
        const row: Row = {};
        for (let i = 0; i < header.length; i++) row[header[i]!] = values[i] ?? '';
        yield row;
      }
      return;
    }
  }
}

export async function readAll(zipPath: string, name: string, keep: (r: Row) => boolean = () => true): Promise<Row[]> {
  const rows: Row[] = [];
  for await (const r of readCsv(zipPath, name)) if (keep(r)) rows.push(r);
  return rows;
}
