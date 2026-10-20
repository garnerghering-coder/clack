// Hand-maintained configuration in the repo's data/ folder (see DATA_FINDINGS.md).
import fs from 'node:fs';
import path from 'node:path';
import { REPO_ROOT } from './env.js';

const read = <T>(name: string): T => JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'data', name), 'utf8')) as T;

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
