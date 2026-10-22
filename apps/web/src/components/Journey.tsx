// Journeys (DESIGN §4 past list, §7 journey view): legs joined by transfer connectors.
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ms, type Leg } from '../api';
import { LegRow } from '../pages/TripsPage';
import { opColor } from '../map/style';

/** Planned transfer, and whether the real times made it tight or missed (DESIGN §7). */
export function transferOf(prev: Leg, next: Leg) {
  const planned = Math.round(((ms(next.schedDep) ?? 0) - (ms(prev.schedArr) ?? 0)) / 60_000);
  const arrived = ms(prev.actualArr);
  const left = ms(next.actualDep) ?? ms(next.schedDep);
  const missed = arrived !== null && left !== null && arrived > left;
  const actual = arrived !== null && left !== null ? Math.round((left - arrived) / 60_000) : null;
  return { planned, actual, missed, tight: !missed && (actual ?? planned) < 10, station: prev.destination?.name ?? '' };
}

export function TransferChip({ prev, next }: { prev: Leg; next: Leg }) {
  const { t } = useTranslation();
  const tr = transferOf(prev, next);
  const cls = tr.missed ? 'transfer missed' : tr.tight ? 'transfer tight' : 'transfer';
  return (
    <div className={cls}>
      <span className="transfer-line" aria-hidden="true" />
      <span className="caption">
        {t('journey.transfer', { min: tr.planned, station: tr.station })}
        {tr.actual !== null && tr.actual !== tr.planned && !tr.missed ? ` · ${t('journey.actually', { min: tr.actual })}` : ''}
        {tr.missed ? ` · ${t('journey.missed')}` : tr.tight ? ` · ${t('journey.tight')}` : ''}
      </span>
    </div>
  );
}

/** A multi-leg journey in the Trips list. Legs in travel order. */
export function JourneyCard({ legs }: { legs: Leg[] }) {
  const { t } = useTranslation();
  const first = legs[0]!;
  const last = legs.at(-1)!;
  // Each train's operator colour glows beside its own row and blends into the next: one card, no pills inside it.
  const glow = legs
    .map((l, i) => `radial-gradient(75% ${Math.round(110 / legs.length)}% at 100% ${Math.round(((i + 0.6) / legs.length) * 100)}%, color-mix(in srgb, ${opColor(l.operator?.brandColor)} 18%, transparent), transparent 70%)`)
    .join(', ');
  return (
    <section className="journey-card" style={{ background: `${glow}, var(--surface)` }}>
      <Link to={`/journeys/${first.journeyId}`} className="journey-head">
        <span className="caption upper">{t('journey.label', { count: legs.length })}</span>
        <span className="strong">
          {first.origin?.name} → {last.destination?.name}
        </span>
      </Link>
      {legs.map((l, i) => (
        <div key={l.id}>
          {i > 0 && <TransferChip prev={legs[i - 1]!} next={l} />}
          <LegRow leg={l} />
        </div>
      ))}
    </section>
  );
}
