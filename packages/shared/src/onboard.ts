// On-board amenities (ADDITIONS_01 D, outcome B; ONBOARD_DATA_FINDINGS.md). Two kinds, never mixed up:
// - facts for one departure, from Trafikverket (catering, and "no catering / no toilet / no bikes" notices);
// - what a train type *typically* has at one operator, from the operator's own pages, with a source and the date
//   someone checked it (data/train_types.json "amenities"). Shown as "Typically", never as a promise.

export const AMENITY_KEYS = [
  'catering',
  'wifi',
  'power',
  'quiet_car',
  'first_class',
  'family_area',
  'pets_area',
  'bikes',
  'wheelchair_space',
  'step_free',
  'accessible_toilet',
  'sleeper',
] as const;
export type AmenityKey = (typeof AMENITY_KEYS)[number];

export interface AmenityClaim {
  /** true / false (only when the operator says so) / "partial" / a short text such as "Bistro". */
  value: boolean | string;
  note?: string;
  source: string;
  verified: string;
}
export interface AmenityEntry {
  match: { operator: string; type?: string };
  claims: Partial<Record<AmenityKey, AmenityClaim>>;
}

/** Trafikverket's catering kinds (Service codes SNA001–SNA010, and "Café i vagn B" in the coach order). */
export const CATERING_KINDS = ['bistro', 'cafe', 'kiosk', 'refreshments', 'restaurant'] as const;
export type CateringKind = (typeof CATERING_KINDS)[number];
export const ONBOARD_NOTICES = ['no_catering', 'no_toilet', 'no_bikes', 'no_first_class', 'changed_type'] as const;
export type OnboardNotice = (typeof ONBOARD_NOTICES)[number];

/** What Trafikverket says about one departure. */
export interface OnboardFacts {
  catering: CateringKind | null;
  /** Where the café is, when the coach order says ("B"). */
  cateringCar: string | null;
  sleeper: boolean;
  notices: OnboardNotice[];
}

/** Claims older than this are hidden until someone checks the operator's page again. */
export const CLAIM_MAX_AGE_DAYS = 365;

/**
 * The typical amenities of a train type at an operator: claims for the operator as a whole, overridden by claims
 * for that type. Stale claims are left out.
 */
export function typicalAmenities(table: AmenityEntry[], operatorId: string | null, typeId: string | null, now = Date.now()): Partial<Record<AmenityKey, AmenityClaim>> {
  if (!operatorId) return {};
  const out: Partial<Record<AmenityKey, AmenityClaim>> = {};
  const fresh = (c: AmenityClaim) => now - Date.parse(c.verified) <= CLAIM_MAX_AGE_DAYS * 86400_000;
  const layers = [
    ...table.filter((e) => e.match.operator === operatorId && !e.match.type),
    ...table.filter((e) => e.match.operator === operatorId && e.match.type && e.match.type === typeId),
  ];
  for (const e of layers) for (const [k, c] of Object.entries(e.claims) as [AmenityKey, AmenityClaim][]) if (c && fresh(c)) out[k] = c;
  return out;
}
