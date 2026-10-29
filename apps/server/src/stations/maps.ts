// Station maps (ADDITIONS_01 C): data/stations/<station_id>.json, validated on load. Small, so kept in memory.
import fs from 'node:fs';
import path from 'node:path';
import { sizeClass, validateStationMap, type SizeClass, type StationMap } from '@clack/shared';
import { REPO_ROOT } from '../env.js';

const DIR = path.join(REPO_ROOT, 'data/stations');
const cache = new Map<string, { mtime: number; map: StationMap | null }>();

/** The station's map, or null when there isn't one (or it doesn't validate; that's logged). */
export function stationMap(stationId: string, log: (m: string) => void = console.warn): StationMap | null {
  if (!/^[\w:-]+$/.test(stationId)) return null;
  // Finnish ids carry a colon ("fi:HKI"); the file is named with an underscore instead (fi_HKI.json).
  const file = path.join(DIR, `${stationId.replace(/:/g, '_')}.json`);
  let mtime: number;
  try {
    mtime = fs.statSync(file).mtimeMs;
  } catch {
    return null;
  }
  const hit = cache.get(stationId);
  if (hit && hit.mtime === mtime) return hit.map;
  const map = JSON.parse(fs.readFileSync(file, 'utf8')) as StationMap;
  const errors = validateStationMap(map);
  if (errors.length) log(`station map ${stationId} is invalid: ${errors.slice(0, 3).join('; ')}`);
  cache.set(stationId, { mtime, map: errors.length ? null : map });
  return errors.length ? null : map;
}

export const hasStationMap = (stationId: string) => stationMap(stationId) !== null;

/** Size class for walk estimates without a map, from Trafikverket's track list. */
export const stationSize = (baseTracks: number | null | undefined): SizeClass | null => (baseTracks ? sizeClass(baseTracks) : null);
