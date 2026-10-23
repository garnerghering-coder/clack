// The iOS app's native pieces (docs/IOS.md). On the web every call here is a no-op.
import { Capacitor } from '@capacitor/core';
import { StatusBar, Style } from '@capacitor/status-bar';
import type { ResolvedTheme } from './theme';

export const isNativeApp = () => Capacitor.isNativePlatform();

/** Status bar text to match the theme: light text on the dark theme, dark text on the light one. */
export function syncStatusBar(theme: ResolvedTheme) {
  if (!isNativeApp()) return;
  StatusBar.setStyle({ style: theme === 'light' ? Style.Light : Style.Dark }).catch(() => {});
}
