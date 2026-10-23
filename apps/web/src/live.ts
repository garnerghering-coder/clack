// Live tracking in the browser (DESIGN §9): one shared EventSource to our server, plus helpers for freshness.
import { useEffect, useRef, useState } from 'react';
import { ms, type Leg, type LiveState, type LiveUpdate } from './api';
import { apiUrl } from './apiBase';

type Listener = (u: LiveUpdate) => void;
const listeners = new Set<Listener>();
let source: EventSource | null = null;

function connect() {
  if (source || typeof EventSource === 'undefined') return;
  // EventSource reconnects on its own; the server sends a full live state every tick, so nothing needs replaying.
  source = new EventSource(apiUrl('/api/live/stream'));
  source.addEventListener('live', (e) => {
    const u = JSON.parse((e as MessageEvent<string>).data) as LiveUpdate;
    for (const l of listeners) l(u);
  });
}

/** Calls `onUpdate` for every live update while the component is mounted. */
export function useLiveUpdates(onUpdate: Listener) {
  const ref = useRef(onUpdate);
  ref.current = onUpdate;
  useEffect(() => {
    const l: Listener = (u) => ref.current(u);
    listeners.add(l);
    connect();
    return () => {
      listeners.delete(l);
      if (!listeners.size) {
        source?.close();
        source = null;
      }
    };
  }, []);
}

/** Re-renders every `everyMs` so "Updated 12 s ago" stays true. */
export function useNow(everyMs = 1000) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), everyMs);
    return () => clearInterval(t);
  }, [everyMs]);
  return now;
}

/** Live data older than this shows as stale (DESIGN §9.5). */
export const STALE_MS = 2 * 60_000;

/** When the trip's data last came from the feeds (our server ticks on even when they don't answer). */
export const dataAt = (live: LiveState) => ms(live.reportedAt ?? null) ?? ms(live.updatedAt) ?? 0;

export const isFresh = (live: LiveState | null | undefined, now: number) => !!live && now - dataAt(live) < STALE_MS;

/** Speeds come with GPS fixes about every 30 s; one older than this isn't shown. */
export const SPEED_FRESH_MS = 60_000;

/** Is this leg being followed live right now (tracked and not yet arrived)? */
export const isLive = (live: LiveState | null | undefined) => !!live && (live.status === 'boarding' || live.status === 'en_route' || live.status === 'at_stop');

/** Status chip (DESIGN §6): Upcoming / Boarding / Live / Arrived / Cancelled. */
export function statusKey(leg: Leg, live: LiveState | null | undefined, now: number): 'planned' | 'boarding' | 'live' | 'completed' | 'cancelled' {
  if (leg.canceled || live?.status === 'cancelled') return 'cancelled';
  if (live && isFresh(live, now)) {
    if (live.status === 'boarding') return 'boarding';
    if (live.status === 'en_route' || live.status === 'at_stop') return 'live';
    if (live.status === 'arrived') return 'completed';
  }
  const dep = ms(leg.actualDep) ?? ms(leg.schedDep) ?? 0;
  const arr = ms(leg.actualArr) ?? ms(leg.schedArr) ?? 0;
  if (leg.status !== 'planned' || now >= arr) return 'completed';
  if (now >= dep) return 'live';
  if (dep - now <= 30 * 60_000) return 'boarding';
  return 'planned';
}

export function agoKey(t: (k: string, o?: Record<string, unknown>) => string, then: number, now: number): string {
  const s = Math.max(0, Math.round((now - then) / 1000));
  if (s < 5) return t('live.justNow');
  if (s < 90) return t('live.secondsAgo', { n: s });
  return t('live.minutesAgo', { n: Math.round(s / 60) });
}
