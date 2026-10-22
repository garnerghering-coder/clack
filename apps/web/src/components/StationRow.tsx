// A station in search results and lists: round flag, name, and county (or country abroad).
import { useTranslation } from 'react-i18next';
import type { StationHit } from '../api';
import { Flag } from './Flag';

export function StationRow({ s, onPick, trailing }: { s: StationHit; onPick: () => void; trailing?: React.ReactNode }) {
  const { t } = useTranslation();
  return (
    <li>
      <button className="station-row" onClick={onPick}>
        <Flag country={s.country} size={32} decorative />
        <span className="station-text">
          <span className="station-name">{s.name}</span>
          {/* Trafikverket's codes ("Cst", "Jö") are internal shorthand, so they stay out of the list (owner feedback). */}
          <span className="caption">{s.county ?? t(`countries.${s.country}`, { defaultValue: s.country })}</span>
        </span>
        {trailing}
      </button>
    </li>
  );
}
