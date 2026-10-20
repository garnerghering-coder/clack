// Loads the user's settings once and shares them; updates are saved to the server.
import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { DEFAULT_SETTINGS, type Settings } from '@clack/shared';
import { api } from './api';
import i18n from './i18n';

interface SettingsState {
  settings: Settings;
  loaded: boolean;
  error: boolean;
  update: (patch: Partial<Settings>) => Promise<void>;
}

const SettingsContext = createContext<SettingsState | null>(null);

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<Settings>(DEFAULT_SETTINGS);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState(false);

  useEffect(() => {
    api.getSettings().then(
      (s) => { setSettings(s); setLoaded(true); },
      () => { setError(true); setLoaded(true); },
    );
  }, []);

  useEffect(() => {
    void i18n.changeLanguage(settings.language);
  }, [settings.language]);

  const update = useCallback(async (patch: Partial<Settings>) => {
    const previous = settings;
    setSettings({ ...settings, ...patch });
    try {
      setSettings(await api.updateSettings(patch));
      setError(false);
    } catch {
      setSettings(previous);
      setError(true);
    }
  }, [settings]);

  return <SettingsContext.Provider value={{ settings, loaded, error, update }}>{children}</SettingsContext.Provider>;
}

export function useSettings() {
  const ctx = useContext(SettingsContext);
  if (!ctx) throw new Error('useSettings outside SettingsProvider');
  return ctx;
}
