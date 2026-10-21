import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { CO2_COMPARISONS, LANGUAGES, type Settings, THEMES } from '@clack/shared';
import { useSettings } from '../settings';
import { ChevronRight } from 'lucide-react';
import { useEffect, useState } from 'react';

function Choice<K extends keyof Settings>({ field, options, label }: { field: K; options: readonly Settings[K][]; label: (v: Settings[K]) => string }) {
  const { t } = useTranslation();
  const { settings, update } = useSettings();
  return (
    <label className="row">
      <span>{t(`settings.${field}`)}</span>
      <select aria-label={t(`settings.${field}`)} value={String(settings[field])} onChange={(e) => update({ [field]: options.find((o) => String(o) === e.target.value) } as Partial<Settings>)}>
        {options.map((o) => (
          <option key={String(o)} value={String(o)}>
            {label(o)}
          </option>
        ))}
      </select>
    </label>
  );
}

function Toggle({ field }: { field: 'includeCommuter' | 'showRailNetwork' }) {
  const { t } = useTranslation();
  const { settings, update } = useSettings();
  return (
    <label className="row">
      <span>{t(`settings.${field}`)}</span>
      <input type="checkbox" role="switch" aria-label={t(`settings.${field}`)} checked={settings[field]} onChange={(e) => update({ [field]: e.target.checked })} />
    </label>
  );
}

function NameField() {
  const { t } = useTranslation();
  const { settings, update } = useSettings();
  const [value, setValue] = useState(settings.displayName);
  useEffect(() => setValue(settings.displayName), [settings.displayName]);
  return (
    <label className="row">
      <span>{t('settings.displayName')}</span>
      <input className="text-input" aria-label={t('settings.displayName')} placeholder={t('settings.displayNamePlaceholder')} value={value} maxLength={60} onChange={(e) => setValue(e.target.value)} onBlur={() => value !== settings.displayName && update({ displayName: value })} />
    </label>
  );
}

/** Appearance: a three-way switch rather than a menu, since it's the one people flip to compare. */
function ThemeSwitch() {
  const { t } = useTranslation();
  const { settings, update } = useSettings();
  return (
    <div className="row theme-row">
      <span id="theme-label">{t('settings.theme')}</span>
      <div className="segmented small" role="radiogroup" aria-labelledby="theme-label">
        {THEMES.map((v) => (
          <button key={v} role="radio" aria-checked={settings.theme === v} className={settings.theme === v ? 'active' : ''} onClick={() => update({ theme: v })}>
            {t(`settings.themes.${v}`)}
          </button>
        ))}
      </div>
    </div>
  );
}

export function SettingsPage() {
  const { t } = useTranslation();
  const { error } = useSettings();
  return (
    <main className="page">
      <header className="page-header">
        <h1>{t('settings.title')}</h1>
      </header>
      {error && <p className="banner error">{t('settings.saveError')}</p>}
      <section className="card">
        <ThemeSwitch />
      </section>
      <section className="card">
        <NameField />
        <Choice field="language" options={LANGUAGES} label={(v) => t(`settings.languages.${v}`)} />
        <Choice field="distanceUnit" options={['km', 'mi'] as const} label={(v) => t(`settings.units.${v}`)} />
        <Choice field="clock" options={['24h', '12h'] as const} label={(v) => t(`settings.clocks.${v}`)} />
        <Choice field="co2Comparison" options={CO2_COMPARISONS} label={(v) => t(`settings.co2.${v}`)} />
      </section>
      <section className="card">
        <Toggle field="includeCommuter" />
        <Toggle field="showRailNetwork" />
      </section>
      <section className="card">
        <Link className="row link" to="/about">
          <span>{t('settings.about')}</span>
          <ChevronRight size={18} />
        </Link>
      </section>
    </main>
  );
}
