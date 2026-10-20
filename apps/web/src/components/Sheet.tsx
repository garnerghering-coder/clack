// The Flighty layout: a dark sheet over the map with a huge title, round action buttons and the avatar.
import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useSettings } from '../settings';

export function Avatar() {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const initials = settings.displayName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]!.toUpperCase())
    .join('');
  return (
    <Link to="/settings" className="avatar" aria-label={t('nav.settings')}>
      {initials || <span className="avatar-dot" />}
    </Link>
  );
}

export function Sheet({ title, subtitle, actions, children, full = false }: { title: string; subtitle?: string; actions?: ReactNode; children: ReactNode; full?: boolean }) {
  return (
    <section className={full ? 'sheet sheet-full' : 'sheet'}>
      <header className="sheet-header">
        <div>
          <h1 className="sheet-title">{title}</h1>
          {subtitle && <p className="sheet-subtitle">{subtitle}</p>}
        </div>
        <div className="sheet-actions">{actions}</div>
      </header>
      <div className="sheet-body">{children}</div>
    </section>
  );
}
