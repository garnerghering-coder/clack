import { execFileSync } from 'node:child_process';
import { REPO_ROOT } from '../env.js';

/** The commit this server is running (short hash), so the app can show whether it is up to date. */
export const SERVER_VERSION: string = (() => {
  try {
    return execFileSync('git', ['rev-parse', '--short', 'HEAD'], { cwd: REPO_ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim() || 'unknown';
  } catch {
    return 'unknown';
  }
})();
