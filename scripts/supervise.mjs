#!/usr/bin/env node
// Keeps the server running (docs/RELIABILITY_PLAN.md §3). Starts the command, and starts it again if it exits with an
// error, or if it stops answering its health check (a hung event loop answers nothing, so it's killed and
// restarted). Waits a little longer between restarts while it keeps failing, and says what happened each time.
// With --watch, it also restarts on code changes, so it replaces `tsx watch` for development.
//
//   node scripts/supervise.mjs [--watch=dir]... [--health=/api/health] -- <command> [args...]
//
// The health check goes to the server's own HOST and PORT, read from the repo's .env like the server does.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const envFile = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '.env');
if (fs.existsSync(envFile)) process.loadEnvFile(envFile);

const sep = process.argv.indexOf('--');
const flags = process.argv.slice(2, sep < 0 ? undefined : sep);
const [cmd, ...args] = sep < 0 ? [] : process.argv.slice(sep + 1);
if (!cmd) {
  console.error('usage: node scripts/supervise.mjs [--watch=dir]... [--health=/api/health] -- <command> [args...]');
  process.exit(2);
}
const watchDirs = flags.filter((f) => f.startsWith('--watch=')).map((f) => f.slice(8));
const healthPath = flags.find((f) => f.startsWith('--health='))?.slice(9);
const host = !process.env.HOST || process.env.HOST === '0.0.0.0' ? '127.0.0.1' : process.env.HOST;
const healthUrl = healthPath && `http://${host}:${process.env.PORT ?? 3001}${healthPath}`;

const HEALTH_EVERY_MS = Number(process.env.SUPERVISE_HEALTH_EVERY_MS ?? 30_000);
/** Health is only checked once the server has had time to start (the first import can keep it busy). */
const HEALTH_GRACE_MS = Number(process.env.SUPERVISE_HEALTH_GRACE_MS ?? 10 * 60_000);
/** Five minutes without an answer: long enough for a big import to finish a batch, short enough to matter. */
const HEALTH_FAILS = 10;
/** A run this long resets the back-off. */
const STABLE_MS = 5 * 60_000;

const say = (m) => console.log(`\x1b[1;33m[supervisor]\x1b[0m ${new Date().toLocaleTimeString()} ${m}`);
let child = null;
let startedAt = 0;
let failures = 0;
let restartTimer = null;
let stopping = false;
let healthFails = 0;
/** Why the current child is being stopped (so its exit isn't counted as a crash). */
let stopReason = null;

function start() {
  restartTimer = null;
  startedAt = Date.now();
  healthFails = 0;
  stopReason = null;
  child = spawn(cmd, args, { stdio: 'inherit', shell: process.platform === 'win32', env: process.env });
  child.on('exit', (code, signal) => {
    child = null;
    if (stopping) process.exit(0);
    if (stopReason === 'change') return start();
    if (Date.now() - startedAt > STABLE_MS) failures = 0;
    if (code === 0 && !stopReason) {
      say('server exited normally; not restarting');
      process.exit(0);
    }
    failures++;
    const wait = Math.min(30_000, 1000 * 2 ** Math.min(failures - 1, 5));
    say(`server ${stopReason === 'hung' ? 'stopped answering' : `exited (${signal ?? `code ${code}`})`}; restarting in ${Math.round(wait / 1000)} s`);
    restartTimer = setTimeout(start, wait);
  });
}

function stopChild(reason) {
  if (!child) return;
  stopReason = reason;
  child.kill('SIGTERM');
  const c = child;
  setTimeout(() => c.exitCode === null && c.signalCode === null && c.kill('SIGKILL'), 5000).unref();
}

let checking = false;
if (healthUrl)
  setInterval(async () => {
    if (checking || !child || stopReason || Date.now() - startedAt < HEALTH_GRACE_MS) return;
    checking = true;
    const run = child;
    try {
      const res = await fetch(healthUrl, { signal: AbortSignal.timeout(Math.min(10_000, HEALTH_EVERY_MS * 2)) });
      healthFails = res.ok ? 0 : healthFails + 1;
    } catch {
      healthFails++;
    } finally {
      checking = false;
    }
    if (run !== child || stopReason) return;
    if (healthFails >= HEALTH_FAILS) {
      say(`no answer from ${healthUrl} ${healthFails} times in a row`);
      stopChild('hung');
    }
  }, HEALTH_EVERY_MS).unref();

let changeTimer = null;
for (const dir of watchDirs)
  fs.watch(dir, { recursive: true }, (_e, file) => {
    if (!file || /(^|\/)(node_modules|\.git)\//.test(file) || !/\.(ts|js|json|sql)$/.test(file)) return;
    clearTimeout(changeTimer);
    changeTimer = setTimeout(() => {
      say(`${file} changed; restarting`);
      if (child) stopChild('change');
      else if (!restartTimer) start();
    }, 300);
  });

for (const sig of ['SIGINT', 'SIGTERM'])
  process.on(sig, () => {
    stopping = true;
    if (child) child.kill(sig);
    else process.exit(0);
  });

start();
