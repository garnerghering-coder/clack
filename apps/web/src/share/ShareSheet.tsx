// Share card preview (product brief §10): pick a card, see exactly the image that will be shared, then save or
// share it. Nothing is sent anywhere unless you tap one of those; there's no public profile.
import { useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useTranslation } from 'react-i18next';
import { Download, Share2, X } from 'lucide-react';
import { api, ms, type Leg, type Passport } from '../api';
import { useSettings } from '../settings';
import { fmtDistance, fmtDuration, locale } from '../format';
import { milestoneLabel } from '../pages/PassportPage';
import { renderCard, type CardData } from './shareCard';

type Variant = 'year' | 'all' | 'journey';
const monthYear = (t: number) => new Date(t).toLocaleDateString(locale(), { month: 'long', year: 'numeric', timeZone: 'Europe/Stockholm' });

export function ShareSheet({ year, commuter, legs, onClose }: { year: number | null; commuter: boolean; legs: Leg[]; onClose: () => void }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const unit = settings.distanceUnit;
  const [variant, setVariant] = useState<Variant>('year');
  const [all, setAll] = useState<Passport | null>(null);
  const [yearData, setYearData] = useState<Passport | null>(null);
  const [legId, setLegId] = useState<string | null>(null);
  const [url, setUrl] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const canvas = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    api.passport({ year: null, commuter, comparison: settings.co2Comparison }).then((p) => {
      setAll(p);
      setLegId((id) => id ?? p.records.longestDistance?.legId ?? p.map[0]?.legId ?? null);
    }, () => undefined);
  }, [commuter]);
  const shownYear = year ?? all?.years[0] ?? null;
  useEffect(() => {
    if (shownYear) api.passport({ year: shownYear, commuter, comparison: settings.co2Comparison }).then(setYearData, () => undefined);
  }, [shownYear, commuter]);

  // Only trips that count can be featured.
  const counted = useMemo(() => {
    const ids = new Set(all?.map.map((m) => m.legId) ?? []);
    return legs.filter((l) => ids.has(l.id)).sort((a, b) => (ms(b.schedDep) ?? 0) - (ms(a.schedDep) ?? 0));
  }, [all, legs]);

  const card = useMemo((): CardData | null => {
    const tagline = t('share.tagline');
    const km = (m: number) => fmtDistance(m, unit).replace(/\s?(km|mi)$/, '');
    if (variant === 'journey') {
      const leg = counted.find((l) => l.id === legId) ?? counted[0];
      const m = all?.map.find((x) => x.legId === leg?.id);
      if (!leg || !m) return null;
      const dep = ms(leg.schedDep);
      return {
        kicker: t('share.featured'),
        title: `${leg.origin?.name ?? ''} → ${leg.destination?.name ?? ''}`,
        hero: { value: km(leg.distanceM ?? 0), unit },
        stats: [
          { value: dep && ms(leg.schedArr) ? fmtDuration(((ms(leg.actualArr) ?? ms(leg.schedArr)!) - (ms(leg.actualDep) ?? dep)) / 60_000) : '—', label: t('share.onBoard') },
          { value: leg.operator?.name ?? '—', label: t('share.operator') },
        ],
        notes: [dep ? monthYear(dep) : ''],
        routes: [{ geometry: m.geometry, ends: m.stops }],
        labels: m.stops.length === 2 ? [
          { at: m.stops[0]!, text: leg.origin?.name ?? '' },
          { at: m.stops[1]!, text: leg.destination?.name ?? '' },
        ] : [],
        tagline,
      };
    }
    const p = variant === 'year' ? yearData : all;
    if (!p) return null;
    const routes = p.map.map((x) => ({ geometry: x.geometry, ends: x.stops }));
    if (variant === 'year')
      return {
        kicker: t('share.yearKicker'),
        title: t('share.yearTitle', { year: shownYear }),
        hero: { value: km(p.totals.distanceM), unit },
        stats: [
          { value: String(p.totals.journeys), label: t('passport.journeys') },
          { value: fmtDuration(p.totals.minutes), label: t('share.onBoard') },
          { value: String(p.totals.stations), label: t('passport.stations') },
        ],
        notes: [],
        routes,
        tagline,
      };
    return {
      kicker: t('share.allKicker'),
      title: t('share.allTitle'),
      hero: { value: km(p.totals.distanceM), unit },
      stats: [
        { value: String(p.totals.journeys), label: t('passport.journeys') },
        { value: String(p.totals.stations), label: t('passport.stations') },
        { value: String(p.totals.countries), label: t('share.countries') },
      ],
      // Two milestones, biggest first.
      notes: p.milestones.achieved.slice(0, 2).map((m) => `★ ${milestoneLabel(t, m)}`),
      routes,
      tagline,
    };
  }, [variant, all, yearData, legId, counted, unit, t, shownYear]);

  useEffect(() => {
    setUrl(null);
    if (!card) return;
    let live = true;
    const c = (canvas.current ??= document.createElement('canvas'));
    renderCard(c, card).then(() => live && setUrl(c.toDataURL('image/png')));
    return () => {
      live = false;
    };
  }, [card]);

  const blob = () => new Promise<Blob | null>((res) => canvas.current?.toBlob(res, 'image/png') ?? res(null));
  const name = `clack-${variant === 'year' ? shownYear : variant === 'all' ? 'passport' : 'journey'}.png`;
  const save = async () => {
    const b = await blob();
    if (!b) return;
    const a = document.createElement('a');
    a.href = URL.createObjectURL(b);
    a.download = name;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 5000);
  };
  const share = async () => {
    const b = await blob();
    if (!b) return;
    const file = new File([b], name, { type: 'image/png' });
    if (navigator.canShare?.({ files: [file] })) {
      try {
        await navigator.share({ files: [file], title: t('share.title') });
      } catch {
        // Cancelled.
      }
    } else {
      await save();
      setStatus(t('share.savedInstead'));
    }
  };

  return createPortal(
    <div className="sheet-backdrop" onClick={onClose}>
      <section className="board-sheet share-sheet" role="dialog" aria-modal="true" aria-label={t('share.title')} onClick={(e) => e.stopPropagation()}>
        <header className="board-sheet-head">
          <span className="board-sheet-title">{t('share.title')}</span>
          <button className="icon-button small" onClick={onClose} aria-label={t('common.close')}>
            <X size={18} />
          </button>
        </header>
        <div className="segmented" role="tablist">
          {(['year', 'all', 'journey'] as const).map((v) => (
            <button key={v} role="tab" aria-selected={variant === v} className={variant === v ? 'active' : ''} onClick={() => setVariant(v)}>
              {v === 'year' ? (shownYear ?? t('share.year')) : t(`share.variant.${v}`)}
            </button>
          ))}
        </div>
        {variant === 'journey' && counted.length > 0 && (
          <select className="share-pick" value={legId ?? ''} onChange={(e) => setLegId(e.target.value)} aria-label={t('share.pickJourney')}>
            {counted.map((l) => (
              <option key={l.id} value={l.id}>
                {l.origin?.name} → {l.destination?.name} · {ms(l.schedDep) ? monthYear(ms(l.schedDep)!) : ''}
              </option>
            ))}
          </select>
        )}
        <div className="share-preview">{url ? <img src={url} alt={t('share.previewAlt')} /> : card === null && all ? <p className="caption">{t('share.nothing')}</p> : <div className="skeleton-card" />}</div>
        <p className="caption">{t('share.privacy')}</p>
        {status && <p className="caption">{status}</p>}
        <div className="row-actions">
          <button className="button" onClick={save} disabled={!url}>
            <Download size={16} /> {t('share.save')}
          </button>
          <button className="button primary" onClick={share} disabled={!url}>
            <Share2 size={16} /> {t('share.share')}
          </button>
        </div>
      </section>
    </div>,
    document.body,
  );
}
