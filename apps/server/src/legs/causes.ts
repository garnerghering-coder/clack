// Structured causes for a stop or a board row (data/delay_causes.json, packages/shared/src/delayCauses.ts): what each
// source said, with its own code kept so the app can show it in the reader's language. Pure functions.
import { causesFromDeviations, type DelayCause } from '@clack/shared';

/** Adds `more` to `into` without repeating a cause (same source, code and text). */
export function addCauses(into: DelayCause[], more: DelayCause[]): DelayCause[] {
  for (const c of more) if (!into.some((x) => x.src === c.src && x.code === c.code && x.text === c.text)) into.push(c);
  return into;
}

/** Trafikverket's `Deviation` items ({Code: 'ANA030', Description: 'Inväntat tåg'}). */
export function trvCauses(deviation: { Code?: string; Description?: string }[] | undefined): DelayCause[] {
  const out: DelayCause[] = [];
  for (const d of deviation ?? []) {
    const text = d.Description?.trim();
    const code = d.Code?.trim();
    if (!text && !code) continue;
    addCauses(out, [{ src: 'trv', ...(code ? { code } : {}), ...(text ? { text } : {}) }]);
  }
  return out;
}

/** One entry of a Digitraffic timeTableRow's `causes`. Only the codes are ever sent; names exist only in Finnish. */
export interface DigitrafficCause {
  categoryCode?: string | null;
  detailedCategoryCode?: string | null;
  thirdCategoryCode?: string | null;
}

/**
 * Digitraffic's causes for a timetable row, each as its most specific code (third level, else detailed, else
 * category). The reader's text comes from data/delay_causes.json, walking up to the parent code when a level has no
 * translation. Pure; call it with `timeTableRows[].causes`.
 */
export function digitrafficCauses(causes: DigitrafficCause[] | null | undefined): DelayCause[] {
  const out: DelayCause[] = [];
  for (const c of causes ?? []) {
    const code = (c.thirdCategoryCode || c.detailedCategoryCode || c.categoryCode || '').trim();
    if (code) addCauses(out, [{ src: 'digitraffic', code }]);
  }
  return out;
}

export interface EnturSituation {
  summary: { value: string; language: string | null }[];
}

/** A situation's summary in the app's language when Entur has it, else English, else the first one (usually Norwegian). */
export function pickSummary(summary: EnturSituation['summary'], language: string = 'en'): string | null {
  const by = (l: string) => summary.find((s) => s.language === l && s.value.trim())?.value.trim();
  return by(language) ?? by('en') ?? summary.find((s) => s.value.trim())?.value.trim() ?? null;
}

/**
 * Entur gives free text only, with no codes: one `entur` cause per situation, in the app's language where Entur wrote
 * it. Swedish readers therefore get English or Norwegian text (a limit of the source, not translated by us).
 */
export function enturCauses(situations: EnturSituation[] | undefined, language: string = 'en'): DelayCause[] {
  const out: DelayCause[] = [];
  for (const s of situations ?? []) {
    const text = pickSummary(s.summary, language);
    if (text) addCauses(out, [{ src: 'entur', text }]);
  }
  return out;
}

/** A stored `leg_stops.causes` value; rows saved before causes existed fall back to their plain deviation texts. */
export function parseCauses(stored: string | null | undefined, deviations: string[]): DelayCause[] {
  if (stored) {
    try {
      const v: unknown = JSON.parse(stored);
      if (Array.isArray(v)) return v as DelayCause[];
    } catch {
      // Fall through to the plain texts.
    }
  }
  return causesFromDeviations(deviations);
}

/** The older plain-text list that goes with the causes, for app builds that don't read `causes` yet. */
export const deviationTexts = (causes: DelayCause[]): string[] => causes.map((c) => c.text).filter((t): t is string => !!t);
