// Nightly copy of the server's database (docs/SERVER.md "Backups"). SQLite's online backup is safe while the server
// writes. Usage: node scripts/backup/backup-db.mjs <database> <backup dir>
// Keeps 7 daily copies and 4 weekly ones (Sundays), each compressed with zstd; Garner's Mac pulls them (pull.sh).
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(new URL('../../apps/server/package.json', import.meta.url));
const Database = require('better-sqlite3');

const [dbFile, dir] = process.argv.slice(2);
if (!dbFile || !dir) throw new Error('usage: backup-db.mjs <database> <backup dir>');
fs.mkdirSync(dir, { recursive: true });
const day = new Date().toISOString().slice(0, 10);
const out = path.join(dir, `app-${day}.db`);
const db = new Database(dbFile, { readonly: true, fileMustExist: true });
await db.backup(`${out}.part`);
db.close();
fs.renameSync(`${out}.part`, out);
execFileSync('zstd', ['-q', '-f', '-T0', '--rm', '-10', out, '-o', `${out}.zst`]);

// Keep the newest 7, plus the newest 4 made on a Sunday.
const copies = fs.readdirSync(dir).filter((f) => /^app-\d{4}-\d{2}-\d{2}\.db\.zst$/.test(f)).sort().reverse();
const sundays = copies.filter((f) => new Date(`${f.slice(4, 14)}T12:00:00Z`).getUTCDay() === 0).slice(0, 4);
const keep = new Set([...copies.slice(0, 7), ...sundays]);
for (const f of copies) if (!keep.has(f)) fs.rmSync(path.join(dir, f));
console.log(`backup ${out}.zst (${(fs.statSync(`${out}.zst`).size / 1e6).toFixed(1)} MB); kept ${keep.size}`);
