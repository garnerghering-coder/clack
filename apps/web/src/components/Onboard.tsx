// On board (ADDITIONS_01 D): Trafikverket's facts for this departure first, then what the train typically has,
// labelled "Typically" with where it comes from and when it was checked. Never a promise, never a guess.
import { useTranslation } from 'react-i18next';
import { Accessibility, Baby, BedDouble, Bike, Coffee, Crown, DoorOpen, PawPrint, Plug, Toilet, TriangleAlert, VolumeX, Wifi, type LucideIcon } from 'lucide-react';
import { typicalAmenities, type AmenityClaim, type AmenityKey, type OnboardFacts } from '@clack/shared';
import { useAmenities } from '../data';
import { fmtDay } from '../format';

const ICONS: Record<AmenityKey, LucideIcon> = {
  catering: Coffee,
  wifi: Wifi,
  power: Plug,
  quiet_car: VolumeX,
  first_class: Crown,
  family_area: Baby,
  pets_area: PawPrint,
  bikes: Bike,
  wheelchair_space: Accessibility,
  step_free: DoorOpen,
  accessible_toilet: Toilet,
  sleeper: BedDouble,
};

const host = (url: string) => {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return url;
  }
};

export function Onboard({ facts, operatorId, trainType, compact = false }: { facts: OnboardFacts | null; operatorId: string | null; trainType: string | null; compact?: boolean }) {
  const { t } = useTranslation();
  const table = useAmenities();
  const typical = typicalAmenities(table, operatorId, trainType);
  // Today's facts win over the typical claim for the same thing.
  if (facts?.catering || facts?.notices.includes('no_catering')) delete typical.catering;
  if (facts?.sleeper) delete typical.sleeper;
  const typicalList = (Object.entries(typical) as [AmenityKey, AmenityClaim][]).filter(([, c]) => c.value !== false);
  const hasFacts = Boolean(facts && (facts.catering || facts.sleeper || facts.notices.length));
  if (!hasFacts && !typicalList.length) return compact ? null : <p className="caption">{t('onboard.unknown')}</p>;

  const sources = [...new Map(typicalList.map(([, c]) => [host(c.source), c])).values()];
  const label = (k: AmenityKey, c: AmenityClaim) => {
    const base = t(`onboard.keys.${k}`);
    if (typeof c.value === 'string' && c.value !== 'partial') return `${base}: ${c.value}`;
    return c.value === 'partial' ? t('onboard.partial', { what: base }) : base;
  };

  return (
    <div className={compact ? 'onboard compact' : 'onboard'}>
      {hasFacts && facts && (
        <div className="chip-row onboard-facts">
          {facts.catering && (
            <span className="chip onboard-fact">
              <Coffee size={14} /> {facts.cateringCar ? t('onboard.cateringInCar', { what: t(`onboard.catering.${facts.catering}`), car: facts.cateringCar }) : t(`onboard.catering.${facts.catering}`)}
            </span>
          )}
          {facts.sleeper && (
            <span className="chip onboard-fact">
              <BedDouble size={14} /> {t('onboard.keys.sleeper')}
            </span>
          )}
          {facts.notices.map((n) => (
            <span key={n} className="chip onboard-notice">
              <TriangleAlert size={14} /> {t(`onboard.notices.${n}`)}
            </span>
          ))}
        </div>
      )}
      {typicalList.length > 0 && (
        <>
          <p className="caption upper">{t('onboard.typically')}</p>
          <ul className="onboard-list">
            {typicalList.map(([k, c]) => {
              const Icon = ICONS[k];
              return (
                <li key={k}>
                  <Icon size={16} />
                  <span>
                    {label(k, c)}
                    {c.note && !compact && <span className="caption"> · {c.note}</span>}
                  </span>
                </li>
              );
            })}
          </ul>
          {!compact && (
            <p className="caption">
              {t('onboard.source')}{' '}
              {sources.map((c, i) => (
                <span key={c.source}>
                  {i > 0 && ', '}
                  <a className="link-button" href={c.source} target="_blank" rel="noreferrer">
                    {host(c.source)}
                  </a>
                </span>
              ))}{' '}
              · {t('onboard.checked', { date: fmtDay(Date.parse(sources[0]!.verified), 'Europe/Stockholm') })}
            </p>
          )}
        </>
      )}
    </div>
  );
}
