// The app's texts for the few places the server shows them too (delay causes, the privacy page). They are read from
// the app's String Catalog, the only copy: apps/Clack/ClackKit/Sources/ClackCore/Resources/Localizable.xcstrings.
import fs from 'node:fs';
import type { Language } from './index';

/** Any of the app's languages; a text the catalog doesn't have in it reads English. */
export type StringsLang = Language;

interface Unit {
  stringUnit?: { value: string };
}
interface Catalog {
  strings: Record<string, { localizations?: Record<string, Unit> }>;
}

export const CATALOG_URL = new URL('../../../apps/Clack/ClackKit/Sources/ClackCore/Resources/Localizable.xcstrings', import.meta.url);

let catalog: Catalog | null = null;
const load = (): Catalog => (catalog ??= JSON.parse(fs.readFileSync(CATALOG_URL, 'utf8')) as Catalog);

/** The text for a key (a dot path, e.g. `cause.signalFault`) in a language, else in English; null when not there.
 * A language the catalog has no entry for (or only plural variations) also reads English, never an error. */
export function appString(key: string, lang: StringsLang = 'en'): string | null {
  const entry = load().strings[key]?.localizations;
  const value = (code: string) => {
    const v = entry?.[code]?.stringUnit?.value;
    return typeof v === 'string' && v.trim() ? v : undefined;
  };
  return value(lang) ?? value('en') ?? null;
}

/** The app language for a language tag ("da-DK", "nb", "no", "en-GB"): Norwegian's "no" is the app's "nb". Null
 * when the app doesn't have it. */
export function appLanguage(tag: string | null | undefined, languages: readonly StringsLang[]): StringsLang | null {
  const base = String(tag ?? '').trim().toLowerCase().split(/[-_;]/)[0] ?? '';
  const code = base === 'no' || base === 'nob' ? 'nb' : base;
  return languages.find((l) => l === code) ?? null;
}

/** Every key in the catalog that starts with `prefix` (e.g. `cause.`). */
export const appKeys = (prefix = ''): string[] => Object.keys(load().strings).filter((k) => k.startsWith(prefix));
