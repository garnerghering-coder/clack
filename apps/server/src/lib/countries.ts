// The countries Clack covers and what differs between them: one table instead of `startsWith('no:')` and
// "Europe/Stockholm unless told otherwise" scattered through the server. Finland is +1 h from Sweden and Norway, so
// time zones must come from here (or from the station/leg), never from a default.
export type CountryCode = 'SE' | 'NO' | 'FI';

export interface Country {
  code: CountryCode;
  /** IANA zone of the country's stations. (Haparanda, Sweden, is SE and keeps Europe/Stockholm, 1 h behind Tornio.) */
  tz: string;
  /** import_log / timetable_trips.source of the country's timetable feed. */
  timetableSource: string;
  /** Prefix of timetable_trips.key (`<prefix>:<trip_id>:<hash>`). */
  keyPrefix: string;
  /** Prefix of a live train id (`<prefix><number>|<date>`); Sweden's ids carry none. */
  liveIdPrefix: string;
}

export const COUNTRIES: Record<CountryCode, Country> = {
  SE: { code: 'SE', tz: 'Europe/Stockholm', timetableSource: 'gtfs_se3', keyPrefix: 'se3', liveIdPrefix: '' },
  NO: { code: 'NO', tz: 'Europe/Oslo', timetableSource: 'gtfs_no', keyPrefix: 'no', liveIdPrefix: 'no:' },
  FI: { code: 'FI', tz: 'Europe/Helsinki', timetableSource: 'gtfs_fi', keyPrefix: 'fi', liveIdPrefix: 'fi:' },
};

export const COUNTRY_CODES = Object.keys(COUNTRIES) as CountryCode[];

export const isCountryCode = (c: unknown): c is CountryCode => typeof c === 'string' && c in COUNTRIES;

/** The time zone of a country; undefined for countries we don't cover (Denmark, Germany: see TZ_BY_COUNTRY). */
export const tzOf = (code: string | null | undefined): string | undefined => (isCountryCode(code) ? COUNTRIES[code].tz : undefined);

/**
 * The country whose timetable feed a trip key (`se3:…`, `sv2:…`, `no:…`, `fi:…`) belongs to, or null when the key
 * has no known prefix. Sweden's older Sverige 2 feed ('sv2') is Swedish too.
 */
export function countryOfKey(key: string): CountryCode | null {
  const prefix = key.split(':', 1)[0];
  if (prefix === 'sv2') return 'SE';
  return COUNTRY_CODES.find((c) => COUNTRIES[c].keyPrefix === prefix) ?? null;
}

/** The country of a live train id (`no:123|2026-10-24`, `fi:IC 27|…`); ids without a prefix are Swedish. */
export function countryOfLiveId(id: string): CountryCode {
  return COUNTRY_CODES.find((c) => COUNTRIES[c].liveIdPrefix && id.startsWith(COUNTRIES[c].liveIdPrefix)) ?? 'SE';
}
