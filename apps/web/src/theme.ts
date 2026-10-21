// Light and dark (owner, 2026-10-21). The choice lives in settings; a copy in localStorage lets index.html apply it
// before the app loads (no flash) and keeps the laptop phone frame and the app inside it in step.
import { useEffect, useState } from 'react';
import type { Theme } from '@clack/shared';

export type ResolvedTheme = 'dark' | 'light';
const KEY = 'clack.theme';
const EVENT = 'clack-theme';

const systemTheme = (): ResolvedTheme => (window.matchMedia?.('(prefers-color-scheme: light)').matches ? 'light' : 'dark');

export function storedTheme(): Theme {
  try {
    const v = localStorage.getItem(KEY);
    if (v === 'system' || v === 'dark' || v === 'light') return v;
  } catch {
    // Storage blocked: fall through to the default.
  }
  return 'dark';
}

export const resolveTheme = (t: Theme): ResolvedTheme => (t === 'system' ? systemTheme() : t);
export const currentTheme = (): ResolvedTheme => (document.documentElement.dataset.theme === 'light' ? 'light' : 'dark');

/** Apply a theme to this page now and remember it. */
export function applyTheme(t: Theme) {
  try {
    localStorage.setItem(KEY, t);
  } catch {
    // Not remembered across reloads; still applied.
  }
  const resolved = resolveTheme(t);
  const root = document.documentElement;
  if (root.dataset.theme === resolved) return;
  root.dataset.theme = resolved;
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', resolved === 'light' ? '#ffffff' : '#0a0a0a');
  window.dispatchEvent(new Event(EVENT));
}

/** Follow the phone's setting while the choice is "system"; follow other tabs and the phone frame either way. */
export function watchTheme() {
  window.matchMedia?.('(prefers-color-scheme: light)').addEventListener('change', () => {
    if (storedTheme() === 'system') applyTheme('system');
  });
  window.addEventListener('storage', (e) => {
    if (e.key === KEY) applyTheme(storedTheme());
  });
}

/** The theme in effect; components that draw maps re-create them when it changes. */
export function useResolvedTheme(): ResolvedTheme {
  const [t, setT] = useState(currentTheme);
  useEffect(() => {
    const on = () => setT(currentTheme());
    window.addEventListener(EVENT, on);
    return () => window.removeEventListener(EVENT, on);
  }, []);
  return t;
}
