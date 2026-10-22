// Buying a ticket happens on the operator's own site (owner, 2026-10-22): no checkout, payments or affiliate links in
// Clack. The button opens the operator's booking page with the journey written next to it (and prefilled, where an
// operator's link format has been checked); coming back, Clack offers to add the train to your trips. Opening a
// booking site never means you bought a ticket, so nothing is saved without you saying so.
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ExternalLink } from 'lucide-react';
import { ApiError, api } from '../api';
import { useOperators } from '../data';
import { fmtDay, fmtTime } from '../format';
import { useSettings } from '../settings';

/** One train, from where to where: enough to search the operator's site and to add it to your trips afterwards. */
export interface TicketTrip {
  operatorId: string | null;
  trainNumber: string | null;
  from: { name: string; time: number; tz: string; seq: number };
  to: { name: string; time: number; tz: string; seq: number };
  tripKey: string | null;
  serviceDate: string | null;
}

const PENDING_KEY = 'clack.ticketPending';
const PENDING_MAX_MS = 3 * 3600_000;

interface Pending extends TicketTrip {
  at: number;
  site: string;
}

function readPending(): Pending | null {
  try {
    const p = JSON.parse(localStorage.getItem(PENDING_KEY) ?? 'null') as Pending | null;
    return p && Date.now() - p.at < PENDING_MAX_MS ? p : null;
  } catch {
    return null;
  }
}
function writePending(p: Pending | null) {
  try {
    if (p) localStorage.setItem(PENDING_KEY, JSON.stringify(p));
    else localStorage.removeItem(PENDING_KEY);
  } catch {
    // Private mode: no offer when you come back, nothing else lost.
  }
}

const hostOf = (url: string) => {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return url;
  }
};

/** The link to the operator's site; filled from the journey only where its link format is known to work. */
export function ticketHref(base: string, deepLink: string | null, trip: TicketTrip): string {
  if (!deepLink) return base;
  const local = (ms: number, tz: string, opts: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat('sv-SE', { timeZone: tz, ...opts }).format(ms);
  return deepLink
    .replaceAll('{from}', encodeURIComponent(trip.from.name))
    .replaceAll('{to}', encodeURIComponent(trip.to.name))
    .replaceAll('{date}', local(trip.from.time, trip.from.tz, { year: 'numeric', month: '2-digit', day: '2-digit' }))
    .replaceAll('{time}', local(trip.from.time, trip.from.tz, { hour: '2-digit', minute: '2-digit' }));
}

/** "Buy ticket at sj.se" with the journey to search for underneath. Nothing when the operator has no site. */
export function BuyTicket({ trip, inTrips = false }: { trip: TicketTrip; inTrips?: boolean }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const ops = useOperators();
  const op = trip.operatorId ? ops.get(trip.operatorId) : undefined;
  if (!op?.ticketUrl || trip.to.time < Date.now()) return null;
  const site = hostOf(op.ticketUrl);
  const href = ticketHref(op.ticketUrl, op.ticketDeepLink ?? null, trip);
  return (
    <div className="buy-ticket">
      <a
        className="button"
        href={href}
        target="_blank"
        rel="noopener noreferrer"
        onClick={() => {
          // Only to offer adding it when you're back; never taken as a purchase.
          if (!inTrips && trip.tripKey && trip.serviceDate) writePending({ ...trip, at: Date.now(), site });
        }}
      >
        <ExternalLink size={16} /> {t('tickets.buyAt', { site })}
      </a>
      <span className="caption">
        {t('tickets.searchFor', {
          from: trip.from.name,
          to: trip.to.name,
          day: fmtDay(trip.from.time, trip.from.tz),
          time: fmtTime(trip.from.time, trip.from.tz, settings.clock),
          train: [op.name, trip.trainNumber].filter(Boolean).join(' '),
        })}
      </span>
    </div>
  );
}

/** Back from an operator's site: offer (once) to add that train to your trips. Mounted once, in the app shell. */
export function TicketReturnPrompt() {
  const { t } = useTranslation();
  const [offer, setOffer] = useState<Pending | null>(null);
  const [state, setState] = useState<'ask' | 'saving' | 'added' | 'already' | 'error'>('ask');
  useEffect(() => {
    const check = () => {
      if (document.visibilityState !== 'visible') return;
      const p = readPending();
      // Give it a moment: tapping the link itself fires a focus change before you've gone anywhere.
      if (p && Date.now() - p.at > 5000) {
        setOffer(p);
        setState('ask');
      }
    };
    document.addEventListener('visibilitychange', check);
    window.addEventListener('focus', check);
    return () => {
      document.removeEventListener('visibilitychange', check);
      window.removeEventListener('focus', check);
    };
  }, []);
  if (!offer) return null;
  const close = () => {
    writePending(null);
    setOffer(null);
  };
  const add = async () => {
    if (!offer.tripKey || !offer.serviceDate) return close();
    setState('saving');
    try {
      await api.createLeg({ tripKey: offer.tripKey, serviceDate: offer.serviceDate, fromSeq: offer.from.seq, toSeq: offer.to.seq });
      setState('added');
    } catch (e) {
      setState(e instanceof ApiError && e.status === 409 ? 'already' : 'error');
    }
    writePending(null);
  };
  return (
    <div className="ticket-return card" role="dialog" aria-live="polite" aria-label={t('tickets.backTitle', { site: offer.site })}>
      {state === 'ask' || state === 'saving' ? (
        <>
          <p className="strong">{t('tickets.backTitle', { site: offer.site })}</p>
          <p className="caption">{t('tickets.backBody', { from: offer.from.name, to: offer.to.name, train: offer.trainNumber ?? '' })}</p>
          <div className="row-actions">
            <button className="button" onClick={close}>
              {t('tickets.notNow')}
            </button>
            <button className="button primary" onClick={add} disabled={state === 'saving'}>
              {t('tickets.addToTrips')}
            </button>
          </div>
        </>
      ) : (
        <>
          <p className="strong">{state === 'added' ? t('tickets.added') : state === 'already' ? t('tickets.already') : t('tickets.failed')}</p>
          <div className="row-actions">
            <button className="button" onClick={() => setOffer(null)}>
              {t('common.close')}
            </button>
          </div>
        </>
      )}
    </div>
  );
}
