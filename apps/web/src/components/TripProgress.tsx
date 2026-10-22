// What a trip did for your Passport (owner, 2026-10-22): after adding a past trip, and on arriving. Milestones it
// unlocked pop in, the families it moved fill from where they were to where they are, and its firsts are named.
// Counted trips only (server stats/passport.ts tripProgress); a trip that doesn't count yet says why.
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api, type Milestone, type TripProgress as Progress } from '../api';
import { useOperators } from '../data';
import { Medal } from './Medal';
import { milestoneLabel } from '../pages/PassportPage';

const COUNTRY: Record<string, string> = { SE: 'Sweden', NO: 'Norway', DK: 'Denmark', DE: 'Germany', FI: 'Finland' };

export function TripProgress({ legId, quietIfNothing = false }: { legId: string; quietIfNothing?: boolean }) {
  const { t } = useTranslation();
  const ops = useOperators();
  const [p, setP] = useState<Progress | null>(null);
  // Start empty, then fill: the bars animate from where you were.
  const [filled, setFilled] = useState(false);
  useEffect(() => {
    api.tripProgress(legId).then(setP, () => setP(null));
  }, [legId]);
  useEffect(() => {
    if (!p) return;
    const id = requestAnimationFrame(() => requestAnimationFrame(() => setFilled(true)));
    return () => cancelAnimationFrame(id);
  }, [p]);
  if (!p) return null;
  if (!p.counted) return quietIfNothing ? null : <p className="caption">{t('progress.notCounted')}</p>;
  const firsts = [
    ...p.firsts.stations.map((s) => t('progress.firstStation', { name: s })),
    ...(p.firsts.operator ? [t('progress.firstOperator', { name: ops.get(p.firsts.operator)?.name ?? p.firsts.operator })] : []),
    ...p.firsts.countries.map((c) => t('progress.firstCountry', { name: t(`countries.${c}`, { defaultValue: COUNTRY[c] ?? c }) })),
  ];
  if (quietIfNothing && !p.unlocked.length && !p.moved.length && !firsts.length) return null;
  return (
    <section className="trip-progress" aria-live="polite">
      {p.unlocked.length > 0 && (
        <div className="progress-unlocked">
          <span className="caption upper">{p.unlocked.length === 1 ? t('progress.unlockedOne') : t('progress.unlocked', { count: p.unlocked.length })}</span>
          <ul className="medals">
            {p.unlocked.map((m: Milestone, i) => (
              <li key={`${m.family}:${m.target}`} style={{ ['--i' as string]: i }} className="medal-tile unlocked-pop">
                <Medal m={m} size={84} />
                <span className="medal-label">{milestoneLabel(t, m)}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
      {firsts.length > 0 && (
        <ul className="chip-row firsts">
          {firsts.map((f) => (
            <li key={f} className="chip accent">
              {f}
            </li>
          ))}
        </ul>
      )}
      {p.moved.length > 0 && (
        <ul className="progress-moved">
          {p.moved.map((m) => {
            const reached = m.after >= m.target;
            const pct = (v: number) => `${Math.min(100, (v / m.target) * 100)}%`;
            return (
              <li key={m.family}>
                <span className="progress-row">
                  <span>{milestoneLabel(t, { family: m.family, target: m.target })}</span>
                  <span className="caption tabular">{reached ? t('progress.reached') : t('passport.progressOf', { value: Math.floor(m.after), target: m.target })}</span>
                </span>
                <span className="progress-track" aria-hidden="true">
                  <span className="progress-before" style={{ width: pct(m.before) }} />
                  <span className="progress-after" style={{ width: filled ? pct(m.after) : pct(m.before) }} />
                </span>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
