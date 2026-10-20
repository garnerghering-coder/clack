// Minimal streaming GTFS reader: reads a .txt entry straight out of the zip via `unzip -p`
// (no need to extract the 3 GB shapes.txt to disk) and yields rows as objects.
import { spawn, execFileSync } from 'node:child_process';
import readline from 'node:readline';

/** Parse one CSV line (RFC 4180 quoting; GTFS rows never span lines in this feed). */
export function parseCsvLine(line) {
  const out = [];
  let cur = '';
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (quoted) {
      if (ch === '"') {
        if (line[i + 1] === '"') { cur += '"'; i++; } else quoted = false;
      } else cur += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') { out.push(cur); cur = ''; }
    else cur += ch;
  }
  out.push(cur);
  return out;
}

const entryCache = new Map();
/** Resolve `name` to the real entry path; old Sverige 2 archives nest files in a folder. */
export function resolveEntry(zipPath, name) {
  if (!entryCache.has(zipPath)) {
    const names = execFileSync('unzip', ['-Z1', zipPath], { encoding: 'utf8', maxBuffer: 64e6 }).split('\n').filter(Boolean);
    entryCache.set(zipPath, names);
  }
  const names = entryCache.get(zipPath);
  return names.find((n) => n === name) ?? names.find((n) => n.endsWith('/gtfs-sweden/' + name)) ?? names.find((n) => n.endsWith('/' + name)) ?? name;
}

/** Async iterator over rows of `entry` inside `zipPath`. */
export async function* readGtfs(zipPath, entry) {
  const proc = spawn('unzip', ['-p', zipPath, resolveEntry(zipPath, entry)]);
  const rl = readline.createInterface({ input: proc.stdout, crlfDelay: Infinity });
  let header;
  for await (let line of rl) {
    if (!header) {
      header = parseCsvLine(line.replace(/^﻿/, ''));
      continue;
    }
    if (!line) continue;
    const vals = parseCsvLine(line);
    const row = {};
    for (let i = 0; i < header.length; i++) row[header[i]] = vals[i] ?? '';
    yield row;
  }
}

export async function readAll(zipPath, entry, filter = () => true) {
  const rows = [];
  for await (const r of readGtfs(zipPath, entry)) if (filter(r)) rows.push(r);
  return rows;
}

/** "25:13:00" -> seconds after service-day midnight (GTFS allows > 24h). */
export function gtfsTimeToSec(t) {
  if (!t) return null;
  const [h, m, s] = t.split(':').map(Number);
  return h * 3600 + m * 60 + s;
}
