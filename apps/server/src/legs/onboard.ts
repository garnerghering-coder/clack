// What Trafikverket says about on-board service for one departure (ONBOARD_DATA_FINDINGS.md §1): the planned
// catering in `Service`, day-of notices in `Deviation`, and VR's "Café i vagn B" in the coach order.
import type { CateringKind, OnboardFacts, OnboardNotice } from '@clack/shared';

type Desc = { Code?: string; Description?: string } | string;
const text = (d: Desc) => (typeof d === 'string' ? d : (d.Description ?? ''));
const code = (d: Desc) => (typeof d === 'string' ? '' : (d.Code ?? ''));

// Service codes from Trafikverket's ReasonCode list; the text is checked too, in case a code is missing.
const CATERING: [RegExp, string, CateringKind][] = [
  [/^bistro/i, 'SNA001', 'bistro'],
  [/^kiosk/i, 'SNA003', 'kiosk'],
  [/^restaurang/i, 'SNA004', 'restaurant'],
  [/^servering/i, 'SNA005', 'refreshments'],
  [/^krog/i, 'SNA006', 'restaurant'],
  [/^caf[eé]/i, 'SNA010', 'cafe'],
];
const SLEEPER = /^(sovvagn|sov- ?o liggv|liggvagn)/i;
const SLEEPER_CODES = new Set(['SNA007', 'SNA008', 'SNA009']);
const NOTICES: [RegExp, string, OnboardNotice][] = [
  [/^ej servering/i, 'ANA083', 'no_catering'],
  [/^ej toalett/i, 'ANA093', 'no_toilet'],
  [/^ej cykel/i, 'ANA079', 'no_bikes'],
  [/^1:a klass saknas/i, 'BNA028', 'no_first_class'],
  [/^ändrad tågtyp/i, 'ANA035', 'changed_type'],
];

export function onboardFromRow(row: { Service?: Desc[]; Deviation?: Desc[]; TrainComposition?: Desc[] }): OnboardFacts {
  let catering: CateringKind | null = null;
  let sleeper = false;
  for (const s of row.Service ?? []) {
    const hit = CATERING.find(([re, c]) => code(s) === c || re.test(text(s)));
    if (hit) catering ??= hit[2];
    if (SLEEPER_CODES.has(code(s)) || SLEEPER.test(text(s))) sleeper = true;
  }
  let cateringCar: string | null = null;
  for (const c of row.TrainComposition ?? []) {
    const m = text(c).match(/^caf[eé] i vagn (\w+)/i);
    if (m) {
      catering ??= 'cafe';
      cateringCar = m[1]!;
    }
  }
  const notices: OnboardNotice[] = [];
  for (const d of row.Deviation ?? []) {
    const hit = NOTICES.find(([re, c]) => code(d) === c || re.test(text(d)));
    if (hit && !notices.includes(hit[2])) notices.push(hit[2]);
  }
  // "Ej servering" today overrides the planned catering.
  if (notices.includes('no_catering')) {
    catering = null;
    cateringCar = null;
  }
  return { catering, cateringCar, sleeper, notices };
}

export const hasOnboardFacts = (f: OnboardFacts) => f.catering !== null || f.sleeper || f.notices.length > 0;
