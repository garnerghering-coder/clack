// What a follower of a shared journey is told (owner, 2026-10-25). The traveller's alerts are about "you"; these are about
// someone else's journey, so they say which train and where, and leave out what only the traveller needs (leave now,
// get off soon, the Live Activity). Pure, like rules.ts: the notifier finds the followers and sends.
import { DELAY_ALERT_MIN, type Language } from '@clack/shared';
import { changesOf, type SharedJourney, type SharedLeg } from '../share/shared.js';
import { clock, t } from './text.js';
import type { Alert, Prefs } from './rules.js';

type Event = { type: string; payload: Record<string, unknown> };

const name = (l: SharedLeg) => [l.operator?.shortName, l.trainNumber].filter(Boolean).join(' ') || `${l.from.name} → ${l.to.name}`;

/** The alerts for what the tracker just saw on leg `index` of the journey. `kind` is prefixed `follow-` so it never meets the traveller's own in the push log. */
export function followerAlerts(j: SharedJourney, index: number, events: Event[], p: Prefs, lang: Language): Alert[] {
  if (!p.notify) return [];
  const leg = j.legs[index];
  if (!leg) return [];
  const out: Alert[] = [];
  const route = t(lang, 'route', { from: j.summary.from, to: j.summary.to });
  const train = name(leg);
  const last = index === j.legs.length - 1;
  for (const e of events) {
    const x = e.payload;
    switch (e.type) {
      case 'platform_set':
      case 'platform_changed': {
        if (!p.notifyPlatform || leg.canceled) break;
        const which = x.which === 'arrival' ? 'arrival' : 'departure';
        const to = String(x.to);
        out.push({
          kind: 'follow-platform',
          key: `${index}:${which}:${to}`,
          title: route,
          body: t(lang, which === 'arrival' ? 'followPlatformArr' : 'followPlatformDep', { train, to, station: which === 'arrival' ? leg.to.name : leg.from.name }),
        });
        break;
      }
      case 'delayed': {
        const d = Number(x.delayMin);
        if (!p.notifyDelay || leg.canceled || !Number.isFinite(d) || d < DELAY_ALERT_MIN || leg.expArr === null) break;
        out.push({ kind: 'follow-delay', key: `${index}:${d}`, title: route, body: t(lang, 'followDelayed', { train, delay: d, station: leg.to.name, time: clock(leg.expArr, leg.to.tz) }) });
        break;
      }
      case 'cancelled':
        if (p.notifyCancel) out.push({ kind: 'follow-cancel', key: `${index}:cancelled`, title: t(lang, 'followCancelledTitle', { from: leg.from.name, to: leg.to.name }), body: t(lang, 'followCancelled', { train }), timeSensitive: true });
        break;
      case 'short_turned':
        if (p.notifyCancel && !leg.canceled) out.push({ kind: 'follow-cancel', key: `${index}:short:${[x.stationIds].flat().join(',')}`, title: route, body: t(lang, 'followShortTurned', { train }), timeSensitive: true });
        break;
      case 'arrived':
        if (p.notifyArrival && last && !leg.canceled)
          out.push({ kind: 'follow-arrival', key: '', title: t(lang, 'followArrivedTitle', { station: leg.to.name }), body: t(lang, 'followArrived', { time: clock(Number(x.at) || leg.expArr || 0, leg.to.tz) }) });
        break;
    }
  }
  // A delay or a cancellation on this train may have put the change after it in danger (or the change before it).
  if (p.notifyChange && events.some((e) => e.type === 'delayed' || e.type === 'cancelled' || e.type === 'arrived')) {
    for (const c of changesOf(j.legs).filter((c) => c.index === index || c.index === index - 1)) {
      const b = j.legs[c.index + 1]!;
      if (b.departed) continue;
      if (b.canceled)
        out.push({ kind: 'follow-change', key: `${c.index}:cancelled`, title: t(lang, 'followMissTitle', { station: c.station }), body: t(lang, 'followConnectionCancelled', { to: b.to.name }), timeSensitive: true });
      else if (c.status === 'missed' && c.spareMin !== null)
        out.push({ kind: 'follow-change', key: `${c.index}:missed:${Math.floor(c.spareMin / 3)}`, title: t(lang, 'followMissTitle', { station: c.station }), body: t(lang, 'followMiss', { late: -c.spareMin }), timeSensitive: true });
      else if (c.status === 'tight' && c.spareMin !== null)
        out.push({ kind: 'follow-change', key: `${c.index}:tight:${Math.floor(c.spareMin / 3)}`, title: t(lang, 'followTightTitle', { station: c.station }), body: t(lang, 'followTight', { spare: c.spareMin }) });
    }
  }
  return out;
}
