// The front end only ever talks to our own server (keys stay server-side).
import type { Settings } from '@clack/shared';

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...init?.headers },
  });
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
  return res.json() as Promise<T>;
}

export const api = {
  getSettings: () => request<Settings>('/settings'),
  updateSettings: (patch: Partial<Settings>) => request<Settings>('/settings', { method: 'PATCH', body: JSON.stringify(patch) }),
};
