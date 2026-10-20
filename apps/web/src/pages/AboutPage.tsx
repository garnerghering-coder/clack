import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';

export function AboutPage() {
  const { t } = useTranslation();
  const sources = ['trafikverket', 'gtfsSweden3', 'gtfsSverige2', 'osm'] as const;
  return (
    <main className="page">
      <header className="page-header">
        <Link to="/settings" className="back">
          ‹ {t('common.back')}
        </Link>
        <h1>{t('about.title')}</h1>
      </header>
      <section className="card prose">
        <p>{t('about.intro')}</p>
        <h2>{t('about.sourcesTitle')}</h2>
        <ul>
          {sources.map((s) => (
            <li key={s}>{t(`about.sources.${s}`)}</li>
          ))}
        </ul>
        <h2>{t('about.co2Title')}</h2>
        <p>{t('about.co2Body')}</p>
      </section>
    </main>
  );
}
