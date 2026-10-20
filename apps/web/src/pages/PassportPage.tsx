import { useTranslation } from 'react-i18next';
import { Avatar, Sheet } from '../components/Sheet';

export function PassportPage() {
  const { t } = useTranslation();
  return (
    <Sheet title={t('passport.title')} actions={<Avatar />}>
      <div className="empty">
        <p>{t('passport.empty')}</p>
      </div>
    </Sheet>
  );
}
