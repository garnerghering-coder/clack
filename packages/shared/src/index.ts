export * from './delay';
export * from './polyline';
export * from './counties';
export * from './onboard';
export * from './hours';

// Types and constants shared by the web app and the server.

export const CATEGORIES = ['intercity', 'regional', 'commuter', 'heritage'] as const;
export type Category = (typeof CATEGORIES)[number];

/** full = actual departure and arrival known; scheduled_only = timetable only; manual = entered by hand. */
export const DATA_QUALITIES = ['full', 'partial', 'scheduled_only', 'manual'] as const;
export type DataQuality = (typeof DATA_QUALITIES)[number];

export const LEG_STATUSES = ['planned', 'completed', 'snapshotted'] as const;
export type LegStatus = (typeof LEG_STATUSES)[number];

/** CO₂ comparison modes; factors live in data/co2_factors.json. */
export const CO2_COMPARISONS = ['flight', 'car_1', 'car_2', 'car_3', 'car_avg', 'ev_1', 'coach'] as const;
export type Co2Comparison = (typeof CO2_COMPARISONS)[number];

export const LANGUAGES = ['en', 'sv'] as const;
export type Language = (typeof LANGUAGES)[number];

/** Colour theme: follow the phone, or always dark / light. */
export const THEMES = ['system', 'dark', 'light'] as const;
export type Theme = (typeof THEMES)[number];

export interface Settings {
  /** Shown as initials in the avatar (Flighty-style). Empty = no initials. */
  displayName: string;
  language: Language;
  distanceUnit: 'km' | 'mi';
  clock: '24h' | '12h';
  co2Comparison: Co2Comparison;
  /** Passport: include commuter legs in stats by default. */
  includeCommuter: boolean;
  /** Map: show the faint rail-network layer by default. */
  showRailNetwork: boolean;
  theme: Theme;
}

export const DEFAULT_SETTINGS: Settings = {
  displayName: '',
  language: 'en',
  distanceUnit: 'km',
  clock: '24h',
  co2Comparison: 'car_1',
  includeCommuter: true,
  // Owner's choice (2026-10-21): all rail lines dimmed under your route, as in a transit map.
  showRailNetwork: true,
  theme: 'dark',
};

/** Validate and merge a partial settings update; unknown keys and invalid values are rejected. */
export function mergeSettings(current: Settings, patch: unknown): Settings {
  if (typeof patch !== 'object' || patch === null || Array.isArray(patch)) throw new Error('settings must be an object');
  const p = patch as Record<string, unknown>;
  const next: Settings = { ...current };
  for (const [key, value] of Object.entries(p)) {
    switch (key) {
      case 'displayName':
        if (typeof value !== 'string' || value.length > 60) throw new Error('displayName must be a string of at most 60 characters');
        next.displayName = value.trim();
        break;
      case 'theme':
        if (!THEMES.includes(value as Theme)) throw new Error(`invalid theme: ${String(value)}`);
        next.theme = value as Theme;
        break;
      case 'language':
        if (!LANGUAGES.includes(value as Language)) throw new Error(`invalid language: ${String(value)}`);
        next.language = value as Language;
        break;
      case 'distanceUnit':
        if (value !== 'km' && value !== 'mi') throw new Error(`invalid distanceUnit: ${String(value)}`);
        next.distanceUnit = value;
        break;
      case 'clock':
        if (value !== '24h' && value !== '12h') throw new Error(`invalid clock: ${String(value)}`);
        next.clock = value;
        break;
      case 'co2Comparison':
        if (!CO2_COMPARISONS.includes(value as Co2Comparison)) throw new Error(`invalid co2Comparison: ${String(value)}`);
        next.co2Comparison = value as Co2Comparison;
        break;
      case 'includeCommuter':
      case 'showRailNetwork':
        if (typeof value !== 'boolean') throw new Error(`${key} must be a boolean`);
        next[key] = value;
        break;
      default:
        throw new Error(`unknown setting: ${key}`);
    }
  }
  return next;
}
