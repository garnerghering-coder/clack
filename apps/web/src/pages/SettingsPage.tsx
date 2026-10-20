import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { CO2_COMPARISONS, LANGUAGES, type Settings } from '@clack/shared';
import { useSettings } from '../settings';

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
          <span aria-hidden="true">›</span>
        </Link>
      </section>
    </main>
  );
}
