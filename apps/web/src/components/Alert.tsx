// Alerts on a trip (disruption help and delay warnings): set apart from the ordinary cards by a tinted header band and
// body in the alert's tone, with a close button. Closing one hides it for that trip and situation; if the situation
// changes (another kind of disruption, a new warning), the new alert shows.
import { useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { X } from 'lucide-react';

/** severe: you need to act (cancelled, skipped stop, missed change, buses). warn: late or tight. watch: a warning ahead. info: for the record. */
export type AlertTone = 'severe' | 'warn' | 'watch' | 'info';

const KEY = 'clack.dismissedAlerts';
function dismissed(): string[] {
  try {
    return JSON.parse(localStorage.getItem(KEY) ?? '[]') as string[];
  } catch {
    return [];
  }
}

export function AlertCard({ tone, icon, title, dismissKey, children }: { tone: AlertTone; icon: ReactNode; title: string; dismissKey: string; children: ReactNode }) {
  const { t } = useTranslation();
  const [hidden, setHidden] = useState(() => dismissed().includes(dismissKey));
  if (hidden) return null;
  const close = () => {
    setHidden(true);
    try {
      localStorage.setItem(KEY, JSON.stringify([...dismissed().slice(-200), dismissKey]));
    } catch {
      // Private mode: closed for this visit only.
    }
  };
  return (
    <section className={`card alert-card alert-${tone}`} aria-live="polite">
      <header className="alert-head">
        <span className="alert-icon" aria-hidden="true">
          {icon}
        </span>
        <h2>{title}</h2>
        <button className="icon-button small alert-close" onClick={close} aria-label={t('common.close')}>
          <X size={16} />
        </button>
      </header>
      <div className="alert-body">{children}</div>
    </section>
  );
}
