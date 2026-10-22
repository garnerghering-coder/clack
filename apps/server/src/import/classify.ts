// Applies data/category_overrides.json (validated in Phase 0 with scripts/phase0/q5-classify.mjs).
// Rules are evaluated top to bottom; first match wins. Unknown facts never match.
import type { Category } from '@clack/shared';
import type { CategoryRules, Match } from '../dataFiles.js';

export interface TripFacts {
  gtfs_route_type: string;
  gtfs_operator?: string;
  gtfs_route_short_name?: string;
  /** The public train number (replacement buses have their own ranges, e.g. SJ 6xxxx). */
  train_number?: string | null;
  /** Trafikverket ProductInformation / TypeOfTraffic, only known inside Trafikverket's window. */
  trv_product?: string[];
  trv_type_of_traffic?: string[];
  has_non_rail_stop: boolean;
  /** Trafikverket signature per stop (undefined where unmapped). */
  stop_sigs: (string | undefined)[];
}

export type Classification = { excluded: true; reason: string } | { excluded: false; category: Category };

const asList = (x: unknown): unknown[] => (Array.isArray(x) ? x : [x]);

export function matches(match: Match, f: TripFacts): boolean {
  for (const [key, want] of Object.entries(match)) {
    switch (key) {
      case 'gtfs_route_type':
      case 'gtfs_operator':
      case 'gtfs_route_short_name':
      case 'trv_product':
      case 'trv_type_of_traffic': {
        const have = f[key];
        if (have === undefined) return false;
        if (!asList(have).some((h) => asList(want).includes(h))) return false;
        break;
      }
      case 'train_number_pattern':
        if (!f.train_number || !new RegExp(String(want)).test(f.train_number)) return false;
        break;
      case 'not_gtfs_route_short_name':
        if (asList(want).includes(f.gtfs_route_short_name)) return false;
        break;
      case 'has_non_rail_stop':
        if (f.has_non_rail_stop !== want) return false;
        break;
      case 'all_stops_trv_signature_in': {
        const allowed = asList(want);
        if (!f.stop_sigs.length || !f.stop_sigs.every((s) => s !== undefined && allowed.includes(s))) return false;
        break;
      }
      default:
        throw new Error(`category_overrides.json: unknown match key "${key}"`);
    }
  }
  return true;
}

export function classify(rules: CategoryRules, f: TripFacts): Classification {
  for (const e of rules.exclude) if (matches(e.match, f)) return { excluded: true, reason: e.reason };
  for (const r of rules.rules) if (matches(r.match, f)) return { excluded: false, category: r.category as Category };
  // Anything rail-typed that no rule names is still a train.
  return { excluded: false, category: 'regional' };
}

/** Is this GTFS route a candidate rail route at all (before the rules run)? */
export function isRailRoute(routeType: string, routeShortName: string, agencyName: string): boolean {
  const t = Number(routeType);
  if (t >= 100 && t < 200) return true;
  if (t === 2) return true; // basic GTFS "rail", used by older Sverige 2 snapshots
  // SL's narrow-gauge suburban lines are filed as trams (900): Saltsjöbanan 25/26, Roslagsbanan 27–29.
  return t === 900 && agencyName === 'AB SL Kundtjänst' && ['25', '26', '27', '27S', '28', '28S', '29'].includes(routeShortName);
}
