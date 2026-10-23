// The iOS app (docs/IOS.md): Capacitor wraps the built web app (dist/) in a native iOS project at ios/App, which opens
// in Xcode. `npm run ios` rebuilds the web app for the phone and copies it in.
import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  // The bundle id: must be unique and yours in the Apple Developer account. Change it here and in Xcode before the first
  // upload (it can't change after the app is on App Store Connect).
  appId: 'app.clack',
  appName: 'Clack',
  webDir: 'dist',
  ios: {
    // The page handles the safe areas itself (env(safe-area-inset-*) in styles.css).
    contentInset: 'never',
    backgroundColor: '#0a0a0a',
    // No pinch-zoom of the whole page; the maps zoom themselves.
    allowsLinkPreview: false,
  },
  plugins: {
    SplashScreen: { launchShowDuration: 0, backgroundColor: '#0a0a0a' },
  },
  // Trying the app before the server is online (docs/IOS.md, step 6): CLACK_DEV_URL=http://<your-mac>.local:5173 npx cap
  // sync ios makes the app load the dev server on the Mac (npm run dev:phone), which also passes /api on to the local
  // server. Leave it unset for a real build: the app then uses its own copy of the pages.
  ...(process.env.CLACK_DEV_URL ? { server: { url: process.env.CLACK_DEV_URL, cleartext: true } } : {}),
};

export default config;
