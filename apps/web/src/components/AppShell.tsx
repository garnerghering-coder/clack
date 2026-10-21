// Navigation (DESIGN §3): bottom tab bar on phones; left sidebar with a big "Add train" button from 1024 px.
import type { ReactNode } from 'react';
import { Link, NavLink } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Plus, Search, Settings, Stamp, TrainFront } from 'lucide-react';

const tabs = [
  { to: '/', key: 'trips', Icon: TrainFront },
  { to: '/passport', key: 'passport', Icon: Stamp },
  { to: '/settings', key: 'settings', Icon: Settings },
] as const;

export function Wordmark() {
  return (
    <span className="wordmark" aria-label="clack">
      <span className="wordmark-tile">c</span>lack
    </span>
  );
}

export function AppShell({ children }: { children: ReactNode }) {
  const { t } = useTranslation();
  return (
    <div className="app">
      <aside className="sidebar">
        <Wordmark />
        <nav aria-label={t('nav.label')}>
          {tabs.map(({ to, key, Icon }) => (
            <NavLink key={key} to={to} end={to === '/'} className={({ isActive }) => (isActive ? 'side-link active' : 'side-link')}>
              <Icon size={20} strokeWidth={1.75} />
              {t(`nav.${key}`)}
            </NavLink>
          ))}
          <NavLink to="/stations" className={({ isActive }) => (isActive ? 'side-link active' : 'side-link')}>
            <Search size={20} strokeWidth={1.75} />
            {t('nav.stations')}
          </NavLink>
        </nav>
        <Link to="/add" className="button primary wide">
          <Plus size={20} strokeWidth={2} />
          {t('nav.addTrain')}
        </Link>
      </aside>
      <div className="main">{children}</div>
      <nav className="tabbar" aria-label={t('nav.label')}>
        {tabs.map(({ to, key, Icon }) => (
          <NavLink key={key} to={to} end={to === '/'} className={({ isActive }) => (isActive ? 'tab active' : 'tab')}>
            <Icon size={22} strokeWidth={1.75} />
            <span>{t(`nav.${key}`)}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}
