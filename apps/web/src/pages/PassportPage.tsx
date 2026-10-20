import { useTranslation } from 'react-i18next';

export function PassportPage() {
  const { t } = useTranslation();
  return (
    <main className="page">
      <header className="page-header">
        <h1>{t('passport.title')}</h1>
      </header>
      <section className="empty">
        <p>{t('passport.empty')}</p>
      </section>
    </main>
  );
}
