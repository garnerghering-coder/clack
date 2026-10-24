// The app's texts for the few places the server shows them too (delay causes, the privacy page). They are read from
// the app's String Catalog, the only copy: apps/Clack/ClackKit/Sources/ClackCore/Resources/Localizable.xcstrings.
import fs from 'node:fs';

export type StringsLang = 'en' | 'sv';

interface Unit {
  stringUnit?: { value: string };
}
interface Catalog {
  strings: Record<string, { localizations?: Record<string, Unit> }>;
}

export const CATALOG_URL = new URL('../../../apps/Clack/ClackKit/Sources/ClackCore/Resources/Localizable.xcstrings', import.meta.url);

let catalog: Catalog | null = null;
const load = (): Catalog => (catalog ??= JSON.parse(fs.readFileSync(CATALOG_URL, 'utf8')) as Catalog);

/** The text for a key (a dot path, e.g. `cause.signalFault`) in a language, else in English; null when not there. */
export function appString(key: string, lang: StringsLang = 'en'): string | null {
  const entry = load().strings[key]?.localizations;
  return entry?.[lang]?.stringUnit?.value ?? entry?.en?.stringUnit?.value ?? null;
}

/** Every key in the catalog that starts with `prefix` (e.g. `cause.`). */
export const appKeys = (prefix = ''): string[] => Object.keys(load().strings).filter((k) => k.startsWith(prefix));
