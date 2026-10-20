// Trafiklab's keyless rikshållplats -> Trafikverket signature file (Phase 0 §3, "official" method).
import fs from 'node:fs';
import path from 'node:path';
import { CACHE_DIR } from './downloads.js';

const URL = 'https://api.trafiklab.se/v2/samtrafiken/gtfs/extra/trafikverket_stops.txt';
export const OFFICIAL_FILE = path.join(CACHE_DIR, 'trafiklab/trafikverket_stops.txt');
const MAX_AGE_MS = 7 * 86400_000;

export function parseOfficialMapping(text: string): Map<string, string[]> {
  const map = new Map<string, string[]>();
  for (const line of text.replace(/^﻿/, '').split('\n').slice(1)) {
    const [riks, sig] = line.trim().split(',');
    if (!riks || !sig) continue;
    (map.get(riks) ?? map.set(riks, []).get(riks)!).push(sig);
  }
  return map;
}

/** Cached copy, refreshed weekly. Falls back to the cached copy if the download fails. */
export async function loadOfficialMapping(fetchImpl: typeof fetch = fetch): Promise<Map<string, string[]>> {
  const fresh = fs.existsSync(OFFICIAL_FILE) && Date.now() - fs.statSync(OFFICIAL_FILE).mtimeMs < MAX_AGE_MS;
  if (!fresh) {
    try {
      const res = await fetchImpl(URL);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      fs.mkdirSync(path.dirname(OFFICIAL_FILE), { recursive: true });
      fs.writeFileSync(OFFICIAL_FILE, await res.text());
    } catch (e) {
      if (!fs.existsSync(OFFICIAL_FILE)) throw new Error(`could not fetch trafikverket_stops.txt: ${String(e)}`);
    }
  }
  return parseOfficialMapping(fs.readFileSync(OFFICIAL_FILE, 'utf8'));
}
