// Navigation (product brief §3): three destinations, Trips, Explore and Passport, as a bottom tab bar on phones and
// a left sidebar with a big "Add train" button from 1024 px. Settings is a gear on each tab's header (and at the
// foot of the sidebar), not a tab of its own.
import { useEffect, useRef, type ReactNode } from 'react';
import { Link, NavLink, useLocation, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Compass, Plus, Search, Settings, Stamp, TrainFront } from 'lucide-react';
import { Wordmark } from './Brand';
import { api } from '../api';
import { readLastTab, resolveLanding, saveLastTab, TAB_PATHS, tabForPath } from '../landing';

const tabs = [
  { to: '/', key: 'trips', Icon: TrainFront },
  { to: '/explore', key: 'explore', Icon: Compass },
  { to: '/passport', key: 'passport', Icon: Stamp },
] as const;

/**
 * Once per app start: open where it matters (a train running or about to leave → Trips, else the tab you used
 * last, else Explore). Only from the plain start URL, and never after you've touched anything.
 */
function useLanding() {
  const location = useLocation();
  const navigate = useNavigate();
  const touched = useRef(false);
  useEffect(() => {
    const started = (() => {
      try {
        if (sessionStorage.getItem('clack.landed')) return true;
        sessionStorage.setItem('clack.landed', '1');
      } catch {
        // No session storage: decide every load, which is still only at start.
      }
      return false;
    })();
    if (started || location.pathname !== '/' || location.search) return;
    const mark = () => (touched.current = true);
    window.addEventListener('pointerdown', mark, { once: true });
    window.addEventListener('keydown', mark, { once: true });
    const lastTab = readLastTab();
    api.legs().then(
      (legs) => {
        const tab = resolveLanding({ legs, now: Date.now(), lastTab });
        if (!touched.current && tab !== 'trips' && window.location.pathname === '/') navigate(TAB_PATHS[tab], { replace: true });
      },
      () => {
        if (!touched.current && lastTab && lastTab !== 'trips' && window.location.pathname === '/') navigate(TAB_PATHS[lastTab], { replace: true });
      },
    );
    return () => {
      window.removeEventListener('pointerdown', mark);
      window.removeEventListener('keydown', mark);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  // Remember the tab you're on, for next time.
  useEffect(() => {
    const tab = tabForPath(location.pathname);
    if (tab) saveLastTab(tab);
  }, [location.pathname]);
}

/** The secondary way into Settings, for page headers. */
export function SettingsLink() {
  const { t } = useTranslation();
  return (
    <Link to="/settings" className="icon-button" aria-label={t('nav.settings')} title={t('nav.settings')}>
      <Settings size={20} />
    </Link>
  );
}

import { TicketReturnPrompt } from './Tickets';

export function AppShell({ children }: { children: ReactNode }) {
  const { t } = useTranslation();
  useLanding();
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
        <NavLink to="/settings" className={({ isActive }) => (isActive ? 'side-link side-settings active' : 'side-link side-settings')}>
          <Settings size={18} strokeWidth={1.75} />
          {t('nav.settings')}
        </NavLink>
      </aside>
      <div className="main">{children}</div>
      <TicketReturnPrompt />
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
