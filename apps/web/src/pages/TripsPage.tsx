import { useTranslation } from 'react-i18next';
import { Avatar, Sheet } from '../components/Sheet';

export function TripsPage() {
  const { t } = useTranslation();
  return (
    <Sheet title={t('trips.title')} actions={<Avatar />}>
      <div className="empty">
        <h2>{t('trips.empty.title')}</h2>
        <p>{t('trips.empty.body')}</p>
      </div>
    </Sheet>
  );
}
