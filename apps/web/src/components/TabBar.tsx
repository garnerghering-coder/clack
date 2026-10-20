import { NavLink } from 'react-router-dom';
import { useTranslation } from 'react-i18next';

const icons = {
  trips: <path d="M4 17h16M7 17l1.5-9h7L17 17M9 21l1-4m5 4-1-4M9.5 8V5h5v3" />,
  passport: <path d="M6 3h12v18H6zM9 7h6M12 11a3 3 0 1 0 0 6 3 3 0 0 0 0-6z" />,
  settings: <path d="M4 7h10M18 7h2M4 17h4M12 17h8M14 5v4M8 15v4" />,
};

export function TabBar() {
  const { t } = useTranslation();
  const tabs = [
    { to: '/', key: 'trips' as const },
    { to: '/passport', key: 'passport' as const },
    { to: '/settings', key: 'settings' as const },
  ];
  return (
    <nav className="tabbar">
      {tabs.map((tab) => (
        <NavLink key={tab.key} to={tab.to} end className={({ isActive }) => (isActive ? 'tab active' : 'tab')}>
          <svg viewBox="0 0 24 24" aria-hidden="true">{icons[tab.key]}</svg>
          <span>{t(`nav.${tab.key}`)}</span>
        </NavLink>
      ))}
    </nav>
  );
}
