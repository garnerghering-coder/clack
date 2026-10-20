// Floating capsule tab bar with the separate round search button (which opens Add Trip), as in Flighty.
import { Link, NavLink } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { PassportIcon, SearchIcon, TrainIcon } from './icons';

export function TabBar() {
  const { t } = useTranslation();
  return (
    <nav className="tabbar" aria-label={t('nav.label')}>
      <div className="tabbar-capsule">
        <NavLink to="/" end className={({ isActive }) => (isActive ? 'tab active' : 'tab')}>
          <TrainIcon size={26} />
          <span>{t('nav.trips')}</span>
        </NavLink>
        <NavLink to="/passport" className={({ isActive }) => (isActive ? 'tab active' : 'tab')}>
          <PassportIcon size={26} />
          <span>{t('nav.passport')}</span>
        </NavLink>
      </div>
      <Link to="/add" className="tabbar-search" aria-label={t('nav.add')}>
        <SearchIcon size={28} />
      </Link>
    </nav>
  );
}
