import { config } from './env.js';
import { openDb } from './db/client.js';
import { buildApp } from './app.js';

const db = openDb(config.databasePath);
const app = buildApp(db, { logger: true });
await app.listen({ port: config.port, host: config.host });
