import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Sheet } from '../components/Sheet';
import { ChevronLeft } from '../components/icons';

export function AboutPage() {
  const { t } = useTranslation();
  const sources = ['trafikverket', 'gtfsSweden3', 'gtfsSverige2', 'osm'] as const;
  return (
    <Sheet
      full
      title={t('about.title')}
      actions={
        <Link to="/settings" className="round-button" aria-label={t('common.back')}>
          <ChevronLeft size={28} />
        </Link>
      }
    >
      <section className="card prose">
        <p>{t('about.intro')}</p>
        <h2 className="section-header">{t('about.sourcesTitle')}</h2>
        <ul>
          {sources.map((s) => (
            <li key={s}>{t(`about.sources.${s}`)}</li>
          ))}
        </ul>
        <h2 className="section-header">{t('about.co2Title')}</h2>
        <p>{t('about.co2Body')}</p>
      </section>
    </Sheet>
  );
}
