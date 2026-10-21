// Share card preview (product brief §10): pick a card, see exactly the image that will be shared, then save or
// share it. Nothing is sent anywhere unless you tap one of those; there's no public profile. Four cards: the year,
// all time, one journey and one medal (a token for a milestone).
import { useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useTranslation } from 'react-i18next';
import { Download, Share2, X } from 'lucide-react';
import type { LatLon } from '@clack/shared';
import { api, ms, type Leg, type Milestone, type Passport } from '../api';
import { useSettings } from '../settings';
import { fmtDistance, fmtDuration, locale } from '../format';
import { milestoneLabel } from '../pages/PassportPage';
import { centre, Medal } from '../components/Medal';
import { MAP_BOX, renderCard, type CardData, type CardMedal, type CardRoute } from './shareCard';
import { snapshotMap, type MapSnapshot } from './mapSnapshot';

type Variant = 'year' | 'all' | 'journey' | 'medal';
const TZ = 'Europe/Stockholm';
const monthYear = (t: number) => new Date(t).toLocaleDateString(locale(), { month: 'long', year: 'numeric', timeZone: TZ });
const medalKey = (m: Milestone) => `${m.family}:${m.target}`;

/** The medal's SVG (as drawn on the Passport) turned into an image the canvas can draw. */
async function medalImage(svg: SVGSVGElement): Promise<HTMLImageElement> {
  const img = new Image();
  img.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(new XMLSerializer().serializeToString(svg))}`;
  await img.decode();
  return img;
}

/** Map snapshots are slow-ish (a second or two), so each set of routes is drawn once per sheet. */
const snapshots = new Map<string, Promise<MapSnapshot | null>>();

export function ShareSheet({ year, commuter, legs, onClose }: { year: number | null; commuter: boolean; legs: Leg[]; onClose: () => void }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const unit = settings.distanceUnit;
  const [variant, setVariant] = useState<Variant>('year');
  const [all, setAll] = useState<Passport | null>(null);
  const [yearData, setYearData] = useState<Passport | null>(null);
  const [legId, setLegId] = useState<string | null>(null);
  const [medalId, setMedalId] = useState<string | null>(null);
  const [url, setUrl] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const canvas = useRef<HTMLCanvasElement | null>(null);
  const medalBox = useRef<HTMLDivElement>(null);

  useEffect(() => {
    api.passport({ year: null, commuter, comparison: settings.co2Comparison }).then((p) => {
      setAll(p);
      setLegId((id) => id ?? p.records.longestDistance?.legId ?? p.map[0]?.legId ?? null);
      setMedalId((id) => id ?? (p.milestones.achieved[0] ? medalKey(p.milestones.achieved[0]) : null));
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
  const achieved = all?.milestones.achieved ?? [];

  // What goes on the card, before the slow parts (map snapshot, medal images).
  const plan = useMemo(() => {
    if (!all) return null;
    const tagline = t('share.tagline');
    const km = (m: number) => fmtDistance(m, unit).replace(/\s?(km|mi)$/, '');
    const totals = (p: Passport) => [
      { value: String(p.totals.journeys), label: t('passport.journeys') },
      { value: String(p.totals.stations), label: t('passport.stations') },
      { value: String(p.totals.countries), label: t('share.countries') },
    ];
    if (variant === 'medal') {
      const md = achieved.find((m) => medalKey(m) === medalId) ?? achieved[0];
      if (!md) return null;
      return {
        data: { layout: 'medal' as const, kicker: t('share.medalKicker'), title: milestoneLabel(t, md), sub: md.at ? t('share.unlocked', { date: monthYear(md.at) }) : undefined, hero: { value: '', unit: '' }, stats: [{ value: km(all.totals.distanceM), label: unit }, ...totals(all).slice(0, 2)], routes: [], tagline },
        medals: [md],
        routes: [] as CardRoute[],
        labels: [] as { at: LatLon; text: string }[],
      };
    }
    if (variant === 'journey') {
      const leg = counted.find((l) => l.id === legId) ?? counted[0];
      const m = all.map.find((x) => x.legId === leg?.id);
      if (!leg || !m) return null;
      const dep = ms(leg.schedDep);
      const labels = m.stops.length === 2 ? [
        { at: m.stops[0]!, text: leg.origin?.name ?? '' },
        { at: m.stops[1]!, text: leg.destination?.name ?? '' },
      ] : [];
      const routes = [{ geometry: m.geometry, ends: m.stops }];
      return {
        data: {
          layout: 'stats' as const,
          kicker: [t('share.featured'), dep ? monthYear(dep) : null].filter(Boolean).join(' · '),
          title: `${leg.origin?.name ?? ''} → ${leg.destination?.name ?? ''}`,
          hero: { value: km(leg.distanceM ?? 0), unit },
          stats: [
            { value: dep && ms(leg.schedArr) ? fmtDuration(((ms(leg.actualArr) ?? ms(leg.schedArr)!) - (ms(leg.actualDep) ?? dep)) / 60_000) : '—', label: t('share.onBoard') },
            { value: leg.operator?.name ?? '—', label: t('share.operator') },
          ],
          routes,
          labels,
          tagline,
        },
        // The medals this trip earned.
        medals: achieved.filter((x) => x.legId === leg.id),
        routes,
        labels,
      };
    }
    const p = variant === 'year' ? yearData : all;
    if (!p) return null;
    const routes = p.map.map((x) => ({ geometry: x.geometry, ends: x.stops }));
    const inYear = (m: Milestone) => m.at !== undefined && new Date(m.at).toLocaleDateString('sv-SE', { timeZone: TZ }).startsWith(String(shownYear));
    return {
      data:
        variant === 'year'
          ? { layout: 'stats' as const, kicker: t('share.yearKicker'), title: t('share.yearTitle', { year: shownYear }), hero: { value: km(p.totals.distanceM), unit }, stats: [{ value: String(p.totals.journeys), label: t('passport.journeys') }, { value: fmtDuration(p.totals.minutes), label: t('share.onBoard') }, { value: String(p.totals.stations), label: t('passport.stations') }], routes, tagline }
          : { layout: 'stats' as const, kicker: t('share.allKicker'), title: t('share.allTitle'), hero: { value: km(p.totals.distanceM), unit }, stats: totals(p), routes, tagline },
      medals: (variant === 'year' ? achieved.filter(inYear) : achieved).slice(0, 4),
      routes,
      labels: [] as { at: LatLon; text: string }[],
    };
  }, [variant, all, yearData, legId, medalId, counted, unit, t, shownYear, achieved]);

  // Draw: map snapshot and medal images first, then the card.
  useEffect(() => {
    setUrl(null);
    if (!plan) return;
    let live = true;
    (async () => {
      const key = `${variant}|${JSON.stringify(plan.routes.map((r) => r.geometry?.slice(0, 40) ?? r.ends))}`;
      if (plan.routes.length && !snapshots.has(key))
        snapshots.set(key, snapshotMap(plan.routes, MAP_BOX.w / 2, MAP_BOX.h / 2, plan.labels.map((l) => l.at)));
      const map = plan.routes.length ? await snapshots.get(key)! : null;
      const medals: CardMedal[] = [];
      for (const m of plan.medals) {
        const svg = medalBox.current?.querySelector<SVGSVGElement>(`[data-medal="${medalKey(m)}"]`);
        if (svg) medals.push({ image: await medalImage(svg), number: centre(m), label: milestoneLabel(t, m), sub: m.at ? monthYear(m.at) : '' });
      }
      const data: CardData = { ...plan.data, map, medals };
      const c = (canvas.current ??= document.createElement('canvas'));
      await renderCard(c, data);
      if (live) setUrl(c.toDataURL('image/png'));
    })();
    return () => {
      live = false;
    };
  }, [plan]);

  const blob = () => new Promise<Blob | null>((res) => canvas.current?.toBlob(res, 'image/png') ?? res(null));
  const name = `clack-${variant === 'year' ? shownYear : variant === 'all' ? 'passport' : variant}.png`;
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
          {(['year', 'all', 'journey', 'medal'] as const).map((v) => (
            <button key={v} role="tab" aria-selected={variant === v} className={variant === v ? 'active' : ''} onClick={() => setVariant(v)} disabled={v === 'medal' && !achieved.length}>
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
        {variant === 'medal' && achieved.length > 0 && (
          <select className="share-pick" value={medalId ?? ''} onChange={(e) => setMedalId(e.target.value)} aria-label={t('share.pickMedal')}>
            {achieved.map((m) => (
              <option key={medalKey(m)} value={medalKey(m)}>
                {milestoneLabel(t, m)}
              </option>
            ))}
          </select>
        )}
        <div className="share-preview">{url ? <img src={url} alt={t('share.previewAlt')} /> : plan === null && all ? <p className="caption">{t('share.nothing')}</p> : <div className="skeleton-card share-skeleton" />}</div>
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
        {/* The medals, rendered once off screen so the card can copy them exactly. */}
        <div ref={medalBox} className="offscreen" aria-hidden="true">
          {achieved.map((m) => (
            <Medal key={medalKey(m)} m={m} size={240} bare />
          ))}
        </div>
      </section>
    </div>,
    document.body,
  );
}
