// A station in search results and lists: round flag, name, and code • county (or country abroad).
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
          {/* Trafikverket's codes for foreign stations ("Dk.kd") are internal, so show them for Swedish stations only. */}
          <span className="caption">
            {[s.code && !s.code.includes('.') ? s.code : null, s.county ?? t(`countries.${s.country}`, { defaultValue: s.country })]
              .filter(Boolean)
              .join(' • ')}
          </span>
        </span>
        {trailing}
      </button>
    </li>
  );
}
