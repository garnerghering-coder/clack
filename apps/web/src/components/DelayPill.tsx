// Delay pill coloured by the owner-approved bands (DESIGN §2.1). Always shows text, never colour alone.
import { useTranslation } from 'react-i18next';
import { delayBand } from '@clack/shared';
import { fmtDelay } from '../format';

export function DelayPill({ delay, canceled = false, title }: { delay: number | null | undefined; canceled?: boolean; title?: string }) {
  const { t } = useTranslation();
  const band = delayBand(delay, canceled);
  const text = band === 'cancelled' ? t('delay.cancelled') : band === 'unknown' ? t('delay.unknown') : delay === 0 ? t('delay.on_time') : fmtDelay(delay);
  return (
    <span className={`delay-pill band-${band}`} title={title}>
      {text}
    </span>
  );
}

/** Text colour class for an actual time in the stop timeline. */
export const delayClass = (delay: number | null | undefined, canceled = false) => `delay-text band-${delayBand(delay, canceled)}`;
