// The Clack wordmark (owner's design, 2026-10-21): "clack" on split-flap tiles, the last one signal yellow.
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useSettings } from '../settings';

export function Wordmark({ rule = false }: { rule?: boolean }) {
  return (
    <span className="wordmark-wrap">
      <span className="wordmark" role="img" aria-label="clack">
        {['c', 'l', 'a', 'c', 'k'].map((ch, i) => (
          <span key={i} className={i === 4 ? 'wordmark-tile accent' : 'wordmark-tile'} aria-hidden="true">
            {ch}
          </span>
        ))}
      </span>
      {rule && <span className="wordmark-rule" aria-hidden="true" />}
    </span>
  );
}

/** Launch screen: shown until settings have loaded, and at least long enough for the tiles to flip in. */
export function Splash() {
  const { t } = useTranslation();
  const { loaded } = useSettings();
  const [minDone, setMinDone] = useState(false);
  const [gone, setGone] = useState(false);
  useEffect(() => {
    const timer = setTimeout(() => setMinDone(true), 900);
    return () => clearTimeout(timer);
  }, []);
  const hide = loaded && minDone;
  useEffect(() => {
    if (!hide) return;
    const timer = setTimeout(() => setGone(true), 400);
    return () => clearTimeout(timer);
  }, [hide]);
  if (gone) return null;
  return (
    <div className={hide ? 'splash gone' : 'splash'} aria-hidden={hide}>
      <div className="splash-mark">
        <Wordmark rule />
      </div>
      <p className="splash-tagline">{t('app.tagline')}</p>
    </div>
  );
}
