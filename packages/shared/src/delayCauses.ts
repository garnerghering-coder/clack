// Why a train is late, in the reader's language. One table (data/delay_causes.json) maps Trafikverket's announcement
// codes and Digitraffic's cause codes to `cause.*` keys in the app's String Catalog (strings.ts); Entur gives only free text. A cause
// the table doesn't know is shown as the source wrote it, never dropped. The app has the same resolver in
// ClackCore/Logic/DelayCauses.swift, reading the same file.
import table from '../../../data/delay_causes.json';
import { appString } from './strings';

export type CauseSource = 'trv' | 'digitraffic' | 'entur';

/** One reason or notice on a stop: what the source said, structured. `code` is the source's own; `text` as written. */
export interface DelayCause {
  src: CauseSource;
  code?: string;
  text?: string;
}

export type CauseKind = 'cause' | 'notice';

interface Entry {
  key: string | null;
  kind?: CauseKind;
  sv?: string;
  fi?: string;
}

const trv = table.trv as Record<string, Entry>;
const trvText = table.trvText as Record<string, Entry>;
const dt = table.dt as Record<string, Entry>;
/** Trafikverket's announced Swedish text to its entry (the old exact-text lookup, built from the table). */
const trvBySv = new Map<string, Entry>(Object.values(trv).map((e) => [e.sv!.toLowerCase(), e]));

export interface ResolvedCause {
  /** The locale key, or null when only the source's own words are known. */
  key: string | null;
  kind: CauseKind;
  /** What to show when there is no key: the source's text (Digitraffic: the Finnish name). */
  text: string | null;
}

/** The codes above a Digitraffic code, most specific first: P109, P1, P. */
function dtChain(code: string): string[] {
  const c = code.trim().toUpperCase();
  return [...new Set([c, c.length > 2 ? c.slice(0, 2) : '', c.slice(0, 1)].filter(Boolean))];
}

/** Code first, then the exact text, then the raw words. */
export function resolveCause(cause: DelayCause): ResolvedCause {
  const code = cause.code?.trim();
  const text = cause.text?.trim() || null;
  if (cause.src === 'digitraffic' && code) {
    for (const c of dtChain(code)) {
      const e = dt[c];
      if (e?.key) return { key: e.key, kind: 'cause', text: null };
    }
    return { key: null, kind: 'cause', text: text ?? dt[code.toUpperCase()]?.fi ?? null };
  }
  if (cause.src === 'trv') {
    const e = (code ? trv[code.toUpperCase()] : undefined) ?? (text ? (trvBySv.get(text.toLowerCase()) ?? trvText[text]) : undefined);
    if (e?.key) return { key: e.key, kind: e.kind ?? 'cause', text };
  }
  return { key: null, kind: 'cause', text };
}

/** The words to show for a cause: translated when the table knows it, else as the source wrote it (null: nothing). */
export function causeText(cause: DelayCause, lang: 'en' | 'sv' = 'en'): string | null {
  const r = resolveCause(cause);
  if (r.key) {
    const t = appString(r.key, lang);
    if (t) return t;
  }
  return r.text;
}

/** Older servers and old saved legs have only Trafikverket's texts. */
export const causesFromDeviations = (deviations: string[]): DelayCause[] => deviations.map((text) => ({ src: 'trv', text }));

const lowerFirst = (s: string) => (s.length > 1 && s[1] === s[1]!.toUpperCase() && s[1] !== s[1]!.toLowerCase() ? s : s.charAt(0).toLowerCase() + s.slice(1));

/**
 * The reasons among a train's causes (not the notices), as phrases for a sentence, in the order seen, no repeats.
 * Accepts the old plain texts too.
 */
export function delayReasons(causes: (DelayCause | string)[], lang: 'en' | 'sv' = 'en'): string[] {
  const out = new Set<string>();
  for (const c of causes) {
    const cause: DelayCause = typeof c === 'string' ? { src: 'trv', text: c } : c;
    const r = resolveCause(cause);
    if (r.kind !== 'cause') continue;
    // Only what the table knows is a reason: unknown Trafikverket texts may be notices, and Entur's free text and
    // Finnish names don't fit a sentence in the reader's language.
    if (r.key === null) continue;
    const t = causeText(cause, lang);
    if (t) out.add(lowerFirst(t));
  }
  return [...out];
}
