// Server configuration. Secrets come from the repo-root .env (never sent to the browser).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');

const envFile = path.join(REPO_ROOT, '.env');
if (fs.existsSync(envFile)) process.loadEnvFile(envFile);

export const config = {
  port: Number(process.env.PORT ?? 3001),
  host: process.env.HOST ?? '127.0.0.1',
  databasePath: process.env.DATABASE_PATH ?? path.join(REPO_ROOT, 'data/app.db'),
  trafikverketApiKey: process.env.TRAFIKVERKET_API_KEY ?? '',
  gtfsSweden3Key: process.env.TRAFIKLAB_GTFS_SWEDEN3_KEY ?? '',
  gtfsSverige2Key: process.env.TRAFIKLAB_GTFS_SVERIGE2_KEY ?? '',
  /** Entur asks every client to identify itself as <company>-<application> (no key needed). */
  enturClientName: process.env.ENTUR_CLIENT_NAME ?? 'garner-clack',
};
