// Journey view (DESIGN §7): door-to-door summary, a combined map, and the legs joined by transfer connectors.
import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeft } from 'lucide-react';
import { api, ms, type Journey } from '../api';
import { LegRow } from './TripsPage';
import { TransferChip } from '../components/Journey';
import { MultiRouteMap } from '../map/MultiRouteMap';
import { useSettings } from '../settings';
import { fmtDistance, fmtDuration, fmtLongDate } from '../format';
import { opColor } from '../map/style';

export function JourneyPage() {
  const { id } = useParams();
  const { t } = useTranslation();
  const { settings } = useSettings();
  const [j, setJ] = useState<Journey | null>(null);
  const [missing, setMissing] = useState(false);
  useEffect(() => {
    if (id) api.journey(id).then(setJ, () => setMissing(true));
  }, [id]);

  if (missing)
    return (
      <main className="page">
        <Link to="/" className="link-button back-link">
          <ArrowLeft size={18} /> {t('nav.trips')}
        </Link>
        <p className="muted">{t('journey.notFound')}</p>
      </main>
    );
  if (!j)
    return (
      <main className="page">
        <div className="skeleton-card" />
      </main>
    );

  const first = j.legs[0]!;
  const last = j.legs.at(-1)!;
  const dep = ms(first.actualDep) ?? ms(first.schedDep) ?? 0;
  const arr = ms(last.actualArr) ?? ms(last.schedArr) ?? 0;
  const distance = j.legs.reduce((n, l) => n + (l.distanceM ?? 0), 0);

  return (
    <main className="page journey">
      <Link to="/" className="link-button back-link">
        <ArrowLeft size={18} /> {t('nav.trips')}
      </Link>
      <h1 className="detail-route">
        {first.origin?.name} → {last.destination?.name}
      </h1>
      <p className="muted">{fmtLongDate(dep, first.origin?.tz ?? 'Europe/Stockholm')}</p>
      <section className="tiles">
        <div className="tile">
          <span className="caption upper">{t('journey.doorToDoor')}</span>
          <span className="tile-value tabular">{fmtDuration((arr - dep) / 60_000)}</span>
        </div>
        <div className="tile">
          <span className="caption upper">{t('passport.trains')}</span>
          <span className="tile-value tabular">{j.legs.length}</span>
        </div>
        <div className="tile">
          <span className="caption upper">{t('detail.distance')}</span>
          <span className="tile-value tabular">{fmtDistance(distance, settings.distanceUnit)}</span>
        </div>
      </section>
      <section className="card map-card">
        <MultiRouteMap
          className="journey-map"
          routes={j.legs.map((l) => ({ color: opColor(l.operator?.brandColor), geometry: l.geometry, stops: [] }))}
          stations={[]}
          railNetwork={settings.showRailNetwork}
          label={t('journey.mapLabel')}
        />
      </section>
      <section className="journey-card">
        {j.legs.map((l, i) => (
          <div key={l.id}>
            {i > 0 && <TransferChip prev={j.legs[i - 1]!} next={l} />}
            <LegRow leg={l} />
          </div>
        ))}
      </section>
    </main>
  );
}
