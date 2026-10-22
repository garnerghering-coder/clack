// Hand-maintained configuration in the repo's data/ folder (see DATA_FINDINGS.md).
import fs from 'node:fs';
import path from 'node:path';
import { REPO_ROOT } from './env.js';

export const readDataFile = <T>(name: string): T => JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'data', name), 'utf8')) as T;
const read = readDataFile;

export type Match = Record<string, unknown>;
export interface CategoryRules {
  exclude: { match: Match; reason: string }[];
  rules: { match: Match; category: string; note?: string }[];
}
export interface Brand {
  id: string;
  name: string;
  short_name: string;
  color: string;
  country: string;
  gtfs_operators: string[];
  /** What people type in search ("sj", "mtrx", "pågatågen"). */
  aliases: string[];
  /** Site whose app icon is used as the logo (downloaded locally, see import/logos.ts). */
  website?: string;
  /** Direct icon URL when the site's own links don't point at a good one. */
  icon_url?: string;
  /**
   * Where to buy a ticket: the operator's own booking page (default: its website). `deep_link` is a template with
   * {from}, {to}, {date} (YYYY-MM-DD) and {time} (HH:MM), only once someone has checked the operator's site takes it.
   */
  tickets?: { url?: string; deep_link?: string; checked?: string } | null;
}
export interface StationOverride {
  name: string;
  trv_signature: string | null;
  kind: 'rail_station' | 'bus_stop' | 'foreign_not_in_trv';
  note?: string;
}

export const loadCategoryRules = () => read<CategoryRules>('category_overrides.json');
export const loadBrands = () => read<{ brands: Brand[] }>('operators.json').brands;
export const loadStationOverrides = (): Record<string, StationOverride> => {
  const { _comment, ...rest } = read<Record<string, StationOverride> & { _comment?: string }>('station_overrides.json');
  void _comment;
  return rest as Record<string, StationOverride>;
};
export const loadStationAliases = () => read<{ aliases: Record<string, string[]> }>('station_aliases.json').aliases;
