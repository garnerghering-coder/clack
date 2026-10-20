import { useTranslation } from 'react-i18next';

export function TripsPage() {
  const { t } = useTranslation();
  return (
    <main className="page">
      <header className="page-header">
        <h1>{t('trips.title')}</h1>
        <button className="icon-button" aria-label={t('trips.add')} disabled>
          +
        </button>
      </header>
      <div className="empty">
        <h2>{t('trips.empty.title')}</h2>
        <p>{t('trips.empty.body')}</p>
      </div>
    </main>
  );
}
