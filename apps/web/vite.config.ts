import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.svg', 'icons/apple-touch-icon.png'],
      manifest: {
        name: 'Clack',
        short_name: 'Clack',
        description: 'Log every train you ride.',
        theme_color: '#0b0f14',
        background_color: '#0b0f14',
        display: 'standalone',
        start_url: '/',
        icons: [
          { src: 'icons/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icons/icon-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'icons/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      // The API is always live data: never serve it from the service-worker cache.
      workbox: { navigateFallbackDenylist: [/^\/api\//] },
    }),
  ],
  server: {
    port: 5173,
    // CLACK_API lets a second copy (say, a simulation server on another port) run side by side.
    proxy: { '/api': process.env.CLACK_API ?? 'http://127.0.0.1:3001' },
  },
});
