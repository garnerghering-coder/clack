// Where our server is. On the web the app and the API share an origin, so paths stay relative ("/api/..."). In the
// iOS app the pages are served from the app bundle, so VITE_API_BASE names the server, e.g. https://api.clack.app
// (docs/IOS.md).
export const API_BASE = (import.meta.env.VITE_API_BASE ?? '').replace(/\/+$/, '');
const BASE = API_BASE;

/**
 * An absolute-or-relative URL for a server path ("/api/..."); other URLs pass through. On a shared server it carries the
 * phone's id as ?u=, for requests that can't set a header (EventSource, <img>).
 */
export function apiUrl(path: string): string {
  if (!(path.startsWith('/api/') || path === '/api')) return path;
  const id = deviceId();
  return BASE + path + (id ? `${path.includes('?') ? '&' : '?'}u=${id}` : '');
}

/** The server's origin, for libraries that need a full URL (map tiles). */
export const apiOrigin = () => BASE || window.location.origin;

/**
 * This phone's id, when the app talks to a shared server (the iOS app): a random UUID made on first launch and kept on
 * the phone. It stands in for an account (no sign-in); "Delete my data" in Settings removes everything under it.
 * The laptop demo (no VITE_API_BASE) has no id and acts as the local user.
 */
const ID_KEY = 'clack.user';
export function deviceId(): string | null {
  if (!BASE) return null;
  try {
    let id = localStorage.getItem(ID_KEY);
    if (!id) {
      id = crypto.randomUUID();
      localStorage.setItem(ID_KEY, id);
    }
    return id;
  } catch {
    return null;
  }
}

/** Forget this phone's id (after its data was deleted): the next request starts a fresh, empty user. */
export function forgetDeviceId() {
  try {
    localStorage.removeItem(ID_KEY);
  } catch {
    // Nothing kept.
  }
}
