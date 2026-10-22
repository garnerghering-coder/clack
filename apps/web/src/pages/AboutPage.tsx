import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeft } from 'lucide-react';
import { ON_TIME_MAX_DELAY_MIN } from '@clack/shared';

export function AboutPage() {
  const { t } = useTranslation();
  const sources = ['trafikverket', 'gtfsSweden3', 'gtfsSverige2', 'entur', 'osm', 'stationMaps', 'onboard'] as const;
  return (
    <main className="page">
      <Link to="/settings" className="link-button back-link">
        <ArrowLeft size={18} /> {t('settings.title')}
      </Link>
      <header className="page-header">
        <h1>{t('about.title')}</h1>
      </header>
      <section className="card prose">
        <p>{t('about.intro')}</p>
        <h2 className="section-header">{t('about.sourcesTitle')}</h2>
        <ul>
          {sources.map((s) => (
            <li key={s}>{t(`about.sources.${s}`)}</li>
          ))}
        </ul>
        <h2 className="section-header">{t('about.delaysTitle')}</h2>
        <p>{t('about.delaysBody', { max: ON_TIME_MAX_DELAY_MIN })}</p>
        <h2 className="section-header">{t('about.co2Title')}</h2>
        <p>{t('about.co2Body')}</p>
      </section>
    </main>
  );
}
