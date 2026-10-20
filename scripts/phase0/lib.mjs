// Shared helpers for Phase 0 scripts: .env loading, Trafikverket queries, download logging.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const CACHE = path.join(ROOT, 'data/cache');

export function loadEnv() {
  const file = path.join(ROOT, '.env');
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}
loadEnv();

export const TRV_URL = 'https://api.trafikinfo.trafikverket.se/v2/data.json';

/** POST an XML <REQUEST> to Trafikverket. `query` is the inner <QUERY> XML. */
export async function trvQuery(query) {
  const key = process.env.TRAFIKVERKET_API_KEY;
  if (!key) throw new Error('TRAFIKVERKET_API_KEY missing');
  const body = `<REQUEST><LOGIN authenticationkey="${key}" />${query}</REQUEST>`;
  const res = await fetch(TRV_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'text/xml' },
    body,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`Trafikverket ${res.status}: ${text.slice(0, 500)}`);
  return JSON.parse(text).RESPONSE.RESULT;
}
