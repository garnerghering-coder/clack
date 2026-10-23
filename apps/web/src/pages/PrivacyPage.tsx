// The privacy policy (App Review 5.1.1(i): linked in App Store Connect and reachable in the app). Plain statements of
// what is true of the code: keep it in step when data handling changes (docs/APP_STORE.md).
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeft } from 'lucide-react';

const CONTACT = import.meta.env.VITE_SUPPORT_EMAIL as string | undefined;

export function PrivacyPage() {
  const { t } = useTranslation();
  const parts = ['stored', 'phone', 'alerts', 'location', 'notCollected', 'sharing', 'deletion'] as const;
  return (
    <main className="page">
      <Link to="/settings" className="link-button back-link">
        <ArrowLeft size={18} /> {t('settings.title')}
      </Link>
      <header className="page-header">
        <h1>{t('privacy.title')}</h1>
      </header>
      <section className="card prose">
        <p>{t('privacy.intro')}</p>
        {parts.map((p) => (
          <div key={p}>
            <h2 className="section-header">{t(`privacy.${p}Title`)}</h2>
            <p>{t(`privacy.${p}Body`)}</p>
          </div>
        ))}
        {CONTACT && (
          <>
            <h2 className="section-header">{t('privacy.contactTitle')}</h2>
            <p>
              {t('privacy.contactBody')} <a href={`mailto:${CONTACT}`}>{CONTACT}</a>
            </p>
          </>
        )}
        <p className="caption">{t('privacy.updated', { date: '2026-10-23' })}</p>
      </section>
    </main>
  );
}
