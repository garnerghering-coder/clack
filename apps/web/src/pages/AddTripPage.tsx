// Add a train (DESIGN §5): date → one smart search field → results → "Where did you get on and off?" → saved.
import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, X } from 'lucide-react';
import { decodePolyline, type LatLon } from '@clack/shared';
import { ApiError, api, type LegDetail, type SearchResponse, type StationHit, type TimetableTrip, type TripGeometry, type TripResult } from '../api';
import { OperatorBadge } from '../components/OperatorBadge';
import { StationRow } from '../components/StationRow';
import { ManualTrip } from '../components/ManualTrip';
import { useOperators, useTrainTypes } from '../data';
import { TrainArt } from '../components/TrainArt';
import { useSettings } from '../settings';
import { RouteMap, type MapStop } from '../map/RouteMap';
import { addDaysIso, dayOffset, fmtDay, fmtDistance, fmtDuration, fmtTime, isoToNoonMs, todayIso } from '../format';
import { opColor } from '../map/style';

const EXAMPLES = ['SJ 523', 'Stockholm → Göteborg', 'Snälltåget Stockholm Malmö'];
const SEPARATOR = /\s*(?:→|->|=>|>|–|—|\s-\s|\bto\b|\btill\b)\s*.*$/i;
type Filter = 'all' | 'long' | 'regional' | 'commuter';
const inFilter = (r: TripResult, f: Filter) =>
  f === 'all' || (f === 'long' ? ['high_speed', 'intercity', 'night'].includes(r.product) : f === 'regional' ? ['regional', 'heritage'].includes(r.product) : r.product === 'commuter');

function haversineM(a: { lat: number; lon: number }, b: { lat: number; lon: number }) {
  const R = 6371008.8;
  const rad = Math.PI / 180;
  const x = Math.sin(((b.lat - a.lat) * rad) / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(((b.lon - a.lon) * rad) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
}

function DateRow({ date, setDate }: { date: string; setDate: (d: string) => void }) {
  const { t } = useTranslation();
  const today = todayIso();
  const picker = useRef<HTMLInputElement>(null);
  const isToday = date === today;
  const isTomorrow = date === addDaysIso(today, 1);
  const [manual, setManual] = useState(false);
  const openPicker = () => {
    const el = picker.current;
    try {
      if (el && typeof el.showPicker === 'function') {
        el.showPicker();
        return;
      }
    } catch {
      // Some browsers refuse showPicker (e.g. inside iframes); fall back to the visible field.
    }
    setManual(true);
    setTimeout(() => el?.focus(), 0);
  };
  return (
    <div className="date-row">
      <button className={isToday ? 'chip-button active' : 'chip-button'} onClick={() => setDate(today)}>
        {t('add.today')}
      </button>
      <button className={isTomorrow ? 'chip-button active' : 'chip-button'} onClick={() => setDate(addDaysIso(today, 1))}>
        {t('add.tomorrow')}
      </button>
      <button className={!isToday && !isTomorrow ? 'chip-button active' : 'chip-button'} onClick={openPicker}>
        {t('add.pickDate')}
      </button>
      {/* Opened from the button; shown as a plain field only where the browser can't open its picker programmatically. */}
      <input
        ref={picker}
        type="date"
        value={date}
        max={addDaysIso(today, 365)}
        onChange={(e) => e.target.value && setDate(e.target.value)}
        className={manual ? 'date-field' : 'date-input'}
        aria-label={t('add.pickDate')}
        tabIndex={manual ? 0 : -1}
      />
      <span className="date-label">
        {fmtDay(isoToNoonMs(date), 'UTC')}
        {date < today && <span className="hint"> · {t('add.pastTrip')}</span>}
      </span>
    </div>
  );
}

function ResultCard({ r, onPick }: { r: TripResult; onPick: () => void }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const ops = useOperators();
  const types = useTrainTypes();
  const op = r.operatorId ? ops.get(r.operatorId) : undefined;
  const type = r.trainType ? types.get(r.trainType) : undefined;
  const plus = dayOffset(r.from.time, r.from.tz, r.to.time, r.to.tz);
  return (
    <button className="result-card" onClick={onPick}>
      <div className="result-times tabular">
        <span className="big-time">{fmtTime(r.from.time, r.from.tz, settings.clock)}</span>
        <span className="duration">{fmtDuration(r.durationMin)}</span>
        <span className="big-time">
          {fmtTime(r.to.time, r.to.tz, settings.clock)}
          {plus > 0 && <sup>+{plus}</sup>}
        </span>
      </div>
      <div className="result-stations">
        <span>{r.from.name}</span>
        <span>{r.to.name}</span>
      </div>
      {type && (
        <div className="result-train">
          <TrainArt art={type.art} color={opColor(op?.brandColor)} height={22} />
          <span className="caption">{type.name}</span>
        </div>
      )}
      <div className="result-meta">
        <OperatorBadge operator={op} size={26} />
        <span className="result-op">{op?.name ?? r.routeName}</span>
        <span className="caption strong">{r.trainNumber}</span>
        <span className="chip">{t(`products.${r.product}`)}</span>
        <span className="caption">{r.stopsBetween ? t('add.stopsBetween', { count: r.stopsBetween }) : t('add.direct')}</span>
        {r.alsoKnownAs.length > 0 && <span className="caption">{t('add.alsoKnownAs', { numbers: r.alsoKnownAs.join(', ') })}</span>}
      </div>
    </button>
  );
}

function Confirm({ result, onBack, onSaved, backLabel }: { result: TripResult; onBack: () => void; onSaved: (leg: LegDetail) => void; backLabel?: string }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const ops = useOperators();
  const [trip, setTrip] = useState<TimetableTrip | null>(null);
  const [fromSeq, setFrom] = useState(result.from.seq);
  const [toSeq, setTo] = useState(result.to.seq);
  // Two explicit selectors (DESIGN §5.3). "To" is active first: most people only change where they got off.
  const [picking, setPicking] = useState<'from' | 'to'>('to');
  const [duplicate, setDuplicate] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [geometry, setGeometry] = useState<TripGeometry | null>(null);
  useEffect(() => {
    api.timetableTrip(result.key, result.serviceDate).then(setTrip, (e: Error) => setError(e.message));
    // The mini map is a nice-to-have: without it the summary falls back to straight-line distance.
    api.timetableTripGeometry(result.key, result.serviceDate).then(setGeometry, () => setGeometry(null));
  }, [result]);

  const tap = (seq: number) => {
    const s = trip?.stops.find((x) => x.seq === seq);
    if (!s || !trip) return;
    if (picking === 'from') {
      if (s.noPickup || seq >= toSeq) return;
      setFrom(seq);
      setPicking('to');
    } else {
      if (s.noDropoff || seq <= fromSeq) return;
      setTo(seq);
    }
    setDuplicate(false);
  };

  const from = trip?.stops.find((s) => s.seq === fromSeq);
  const to = trip?.stops.find((s) => s.seq === toSeq);
  const ridden = trip?.stops.filter((s) => s.seq >= fromSeq && s.seq <= toSeq) ?? [];
  const decoded = useMemo(() => geometry?.segments.map((g) => ({ ...g, points: decodePolyline(g.polyline) })) ?? null, [geometry]);
  const inside = decoded?.filter((g) => g.fromSeq >= fromSeq && g.toSeq <= toSeq) ?? null;
  const distance = inside ? inside.reduce((d, g) => d + g.lengthM, 0) : ridden.slice(1).reduce((d, s, i) => d + haversineM(ridden[i]!, s), 0);
  const approx = !inside || inside.some((g) => g.estimated);
  const join = (segs: { points: LatLon[] }[]) => segs.flatMap((g, i) => (i ? g.points.slice(1) : g.points));
  const mapRoute: LatLon[] = inside ? join(inside) : ridden.map((s) => [s.lat, s.lon]);
  const mapContext: LatLon[][] = decoded
    ? [join(decoded.filter((g) => g.toSeq <= fromSeq)), join(decoded.filter((g) => g.fromSeq >= toSeq))]
    : [];
  const mapStops: MapStop[] = ridden.map((s) => ({ lat: s.lat, lon: s.lon, name: s.name, kind: s.seq === fromSeq || s.seq === toSeq ? 'end' : 'mid' }));
  const dep = from?.dep ?? from?.arr ?? null;
  const arr = to?.arr ?? to?.dep ?? null;

  const save = async (force = false) => {
    setSaving(true);
    setError(null);
    try {
      onSaved(await api.createLeg({ tripKey: result.key, serviceDate: result.serviceDate, fromSeq, toSeq, force }));
    } catch (e) {
      if (e instanceof ApiError && e.status === 409) setDuplicate(true);
      else setError((e as Error).message);
    } finally {
      setSaving(false);
    }
  };
  const op = result.operatorId ? ops.get(result.operatorId) : undefined;

  return (
    <>
      <button className="link-button back-link" onClick={onBack}>
        <ArrowLeft size={18} /> {backLabel ?? t('add.back')}
      </button>
      <h2 className="section-title">{t('add.confirmTitle')}</h2>
      {trip && (
        <RouteMap
          className="mini"
          color={opColor(op?.brandColor)}
          route={mapRoute}
          context={mapContext}
          stops={mapStops}
          interactive={false}
          label={from && to ? t('detail.mapLabel', { from: from.name, to: to.name }) : undefined}
        />
      )}
      <div className="confirm-head">
        <OperatorBadge operator={op} size={30} />
        <span className="strong">{[op?.name, result.trainNumber].filter(Boolean).join(' ')}</span>
        <span className="chip">{t(`products.${result.product}`)}</span>
      </div>
      {from && to && dep !== null && arr !== null && (
        <p className="confirm-summary">
          <span className="strong">
            {from.name} → {to.name}
          </span>{' '}
          · {approx ? '≈ ' : ''}
          {fmtDistance(distance, settings.distanceUnit)} · {fmtDuration((arr - dep) / 60000)}
        </p>
      )}
      <div className="segmented end-picker" role="tablist" aria-label={t('add.tapToChoose')}>
        {(['from', 'to'] as const).map((end) => (
          <button key={end} role="tab" aria-selected={picking === end} className={picking === end ? 'active' : ''} onClick={() => setPicking(end)}>
            <span className="caption upper">{t(`add.${end}`)}</span>
            <span className="end-name">{(end === 'from' ? from : to)?.name ?? '—'}</span>
          </button>
        ))}
      </div>
      <p className="caption">{picking === 'from' ? t('add.tapFrom') : t('add.tapTo')}</p>
      <ol className="stop-picker">
        {trip?.stops.map((s) => {
          const role = s.seq === fromSeq ? 'from' : s.seq === toSeq ? 'to' : s.seq > fromSeq && s.seq < toSeq ? 'between' : 'outside';
          const time = s.seq === toSeq ? (s.arr ?? s.dep) : (s.dep ?? s.arr);
          // Only stops that can become the end being chosen are tappable.
          const selectable = picking === 'from' ? !s.noPickup && s.seq < toSeq : !s.noDropoff && s.seq > fromSeq;
          const restriction = picking === 'from' && s.noPickup && s.seq < toSeq ? t('add.noBoarding') : picking === 'to' && s.noDropoff && s.seq > fromSeq ? t('add.noAlighting') : null;
          return (
            <li key={s.seq}>
              <button className={`stop-pick ${role}`} onClick={() => tap(s.seq)} disabled={!selectable && role !== 'from' && role !== 'to'} style={{ ['--op' as string]: opColor(op?.brandColor) }}>
                <span className="stop-dot" />
                <span className="stop-name">{s.name}</span>
                {(role === 'from' || role === 'to') && <span className="chip accent">{t(`add.${role}`)}</span>}
                {restriction && <span className="caption">{restriction}</span>}
                <span className="stop-time tabular">{fmtTime(time, s.tz, settings.clock)}</span>
              </button>
            </li>
          );
        })}
      </ol>
      {duplicate && (
        <div className="banner warn">
          {t('add.duplicate')}
          <div className="banner-actions">
            <button className="button primary small" onClick={() => save(true)} disabled={saving}>
              {t('add.addAnyway')}
            </button>
            <button className="button small" onClick={() => setDuplicate(false)}>
              {t('add.cancel')}
            </button>
          </div>
        </div>
      )}
      {error && <p className="banner error">{t('add.saveError', { message: error })}</p>}
      <div className="sticky-actions">
        <button className="button primary wide" onClick={() => save(false)} disabled={!trip || saving || duplicate}>
          {t('add.addToClack')}
        </button>
      </div>
    </>
  );
}

function Done({ leg, onAnother }: { leg: LegDetail; onAnother: () => void }) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  return (
    <section className="done">
      <svg className="check-draw" viewBox="0 0 52 52" aria-hidden="true">
        <circle cx="26" cy="26" r="24" />
        <path d="M15 27 l7 7 l15 -16" />
      </svg>
      <h2>{t('add.added')}</h2>
      <p className="strong">
        {leg.origin?.name} → {leg.destination?.name}
      </p>
      <p className="caption">{[leg.operator?.name, leg.trainNumber].filter(Boolean).join(' ')}</p>
      <div className="done-actions">
        <button className="button primary" onClick={() => navigate(`/trips/${leg.id}`)}>
          {t('add.viewTrip')}
        </button>
        <button className="button" onClick={onAnother}>
          {t('add.addAnother')}
        </button>
      </div>
    </section>
  );
}

export function AddTripPage() {
  const { t } = useTranslation();
  const [date, setDate] = useState(todayIso());
  const [query, setQuery] = useState('');
  const [resp, setResp] = useState<SearchResponse | null>(null);
  const [popular, setPopular] = useState<StationHit[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  const [filter, setFilter] = useState<Filter>('all');
  // Bumped to ask again while an older day's timetable is fetched from the archive.
  const [retry, setRetry] = useState(0);
  const [manual, setManual] = useState(false);
  const [picked, setPicked] = useState<TripResult | null>(null);
  const [saved, setSaved] = useState<LegDetail | null>(null);
  const input = useRef<HTMLInputElement>(null);
  const navigate = useNavigate();
  const [params] = useSearchParams();
  // Opened from a station board ("Add to my trips"): go straight to the confirm step for that train.
  const prefill = params.get('trip');
  useEffect(() => {
    const key = params.get('trip');
    const day = params.get('date');
    if (!key || !day) return;
    api.timetableTrip(key, day).then((trip) => {
      const pick = (seq: string | null, fallback: TimetableTrip['stops'][number]) => trip.stops.find((s) => String(s.seq) === seq) ?? fallback;
      const from = pick(params.get('from'), trip.stops[0]!);
      const to = pick(params.get('to'), trip.stops.at(-1)!);
      const ref = (s: TimetableTrip['stops'][number], time: number | null) => ({ seq: s.seq, stationId: s.stationId, name: s.name, code: s.code, country: s.country, tz: s.tz, time: time ?? 0 });
      const dep = from.dep ?? from.arr;
      const arr = to.arr ?? to.dep;
      setDate(day);
      setPicked({
        key: trip.key,
        serviceDate: trip.serviceDate,
        trainNumber: trip.trainNumber,
        operatorId: trip.operatorId,
        category: trip.category,
        product: trip.product,
        trainType: trip.trainType,
        routeName: null,
        from: ref(from, dep),
        to: ref(to, arr),
        durationMin: dep && arr ? Math.round((arr - dep) / 60_000) : 0,
        stopsBetween: trip.stops.filter((s) => s.seq > from.seq && s.seq < to.seq).length,
        alsoKnownAs: [],
      });
    }, () => setError(true));
  }, [params]);

  useEffect(() => {
    input.current?.focus();
    api.popularStations().then(setPopular, () => undefined);
  }, []);

  useEffect(() => {
    if (!query.trim()) {
      setResp(null);
      return;
    }
    const ctrl = new AbortController();
    setLoading(true);
    const timer = setTimeout(() => {
      api.search(query, date, ctrl.signal).then(
        (r) => {
          setResp(r);
          setError(false);
          setLoading(false);
        },
        (e: Error) => {
          if (e.name !== 'AbortError') {
            setError(true);
            setLoading(false);
          }
        },
      );
    }, 150);
    return () => {
      clearTimeout(timer);
      ctrl.abort();
    };
  }, [query, date, retry]);

  // An older day's timetable is on its way: ask again until it's in.
  useEffect(() => {
    if (resp?.history !== 'loading' && resp?.history !== 'failed') return;
    const timer = setTimeout(() => setRetry((n) => n + 1), resp.history === 'loading' ? 3000 : 15_000);
    return () => clearTimeout(timer);
  }, [resp]);

  const interp = resp?.interpretation;
  const pickStation = (s: StationHit) => {
    if (interp?.typing === 'to') setQuery(query.replace(SEPARATOR, ` → ${s.name}`));
    else setQuery(`${interp?.operator ? `${interp.operator.text} ` : ''}${s.name} → `);
    input.current?.focus();
  };
  const rebuild = (parts: { op?: string; number?: string; from?: string; to?: string }) => {
    const head = [parts.op, parts.number].filter(Boolean).join(' ');
    const route = parts.from || parts.to ? `${parts.from ?? ''} → ${parts.to ?? ''}` : '';
    setQuery([head, route].filter(Boolean).join(' ').trim());
    input.current?.focus();
  };
  const parts = { op: interp?.operator?.text, number: interp?.trainNumber, from: interp?.from?.name, to: interp?.to?.name };
  const results = useMemo(() => resp?.results?.filter((r) => inFilter(r, filter)) ?? null, [resp, filter]);

  const reset = () => {
    setSaved(null);
    setManual(false);
    setPicked(null);
    setQuery('');
    setTimeout(() => input.current?.focus(), 0);
  };

  return (
    <div className="sheet-page">
      <section className="sheet" role="dialog" aria-label={t('add.title')}>
        <header className="sheet-header">
          <h1>{t('add.title')}</h1>
          <Link to="/" className="icon-button" aria-label={t('common.close')}>
            <X size={22} />
          </Link>
        </header>
        <div className="sheet-body">
          {saved ? (
            <Done leg={saved} onAnother={reset} />
          ) : manual ? (
            <ManualTrip date={date} from={interp?.from} to={interp?.to} onBack={() => setManual(false)} onSaved={setSaved} />
          ) : picked ? (
            <Confirm result={picked} onBack={() => (prefill ? navigate(-1) : setPicked(null))} backLabel={prefill ? t('common.back') : undefined} onSaved={setSaved} />
          ) : (
            <>
              <DateRow date={date} setDate={setDate} />
              <input
                ref={input}
                className="search-field"
                type="search"
                enterKeyHint="search"
                autoComplete="off"
                autoCorrect="off"
                spellCheck={false}
                placeholder={t('add.placeholder')}
                aria-label={t('add.placeholder')}
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
              {!query && (
                <div className="chip-row">
                  <span className="caption">{t('add.examples')}</span>
                  {EXAMPLES.map((ex) => (
                    <button key={ex} className="chip-button" onClick={() => setQuery(ex)}>
                      {ex}
                    </button>
                  ))}
                </div>
              )}
              {query && interp && (interp.operator || interp.trainNumber || interp.from || interp.to) && (
                <div className="chip-row interpretation" aria-live="polite">
                  {interp.operator && (
                    <button className="chip-button removable" onClick={() => rebuild({ ...parts, op: undefined })}>
                      {interp.operator.text} <X size={14} />
                    </button>
                  )}
                  {interp.trainNumber && (
                    <button className="chip-button removable" onClick={() => rebuild({ ...parts, number: undefined })}>
                      {t('add.trainNumber', { number: interp.trainNumber })} <X size={14} />
                    </button>
                  )}
                  {interp.from && (
                    <button className="chip-button removable" onClick={() => rebuild({ ...parts, from: undefined })}>
                      {interp.from.name} <X size={14} />
                    </button>
                  )}
                  {(interp.from || interp.to) && <span className="caption">→</span>}
                  {interp.to && (
                    <button className="chip-button removable" onClick={() => rebuild({ ...parts, to: undefined })}>
                      {interp.to.name} <X size={14} />
                    </button>
                  )}
                </div>
              )}
              {error && <p className="banner error">{t('add.searchError')}</p>}

              {!query && (
                <>
                  <h2 className="section-header">{t('add.popular')}</h2>
                  <ul className="station-list">{popular.map((s) => <StationRow key={s.id} s={s} onPick={() => pickStation(s)} />)}</ul>
                </>
              )}
              {query && resp && resp.suggestions.length > 0 && !(interp?.to && resp.suggestions[0]?.id === interp.to.id && resp.results?.length) && (
                <>
                  <h2 className="section-header">{t('add.stations')}</h2>
                  <ul className="station-list">{resp.suggestions.map((s) => <StationRow key={s.id} s={s} onPick={() => pickStation(s)} />)}</ul>
                </>
              )}

              {resp?.outsideTimetable && (
                <p className="banner" role="status">
                  {t(resp.history === 'loading' ? 'add.historyLoading' : resp.history === 'failed' ? 'add.historyFailed' : resp.history === 'norway' ? 'add.historyNorway' : 'add.historyUnavailable')}
                </p>
              )}
              {resp?.results && resp.results.length > 0 && (
                <>
                  <div className="chip-row filters">
                    {(['all', 'long', 'regional', 'commuter'] as const).map((f) => (
                      <button key={f} className={filter === f ? 'chip-button active' : 'chip-button'} onClick={() => setFilter(f)}>
                        {t(`add.filter${f === 'all' ? 'All' : f === 'long' ? 'Long' : f === 'regional' ? 'Regional' : 'Commuter'}`)}
                      </button>
                    ))}
                  </div>
                  <div className="results">{results?.map((r) => <ResultCard key={`${r.key}:${r.from.seq}:${r.serviceDate}`} r={r} onPick={() => setPicked(r)} />)}</div>
                </>
              )}
              {resp?.results && resp.results.length === 0 && !resp.outsideTimetable && (
                <p className="muted">{interp?.trainNumber ? t('add.noTrain', { number: interp.trainNumber }) : t('add.noDirect')}</p>
              )}
              {query && resp && (resp.outsideTimetable ? resp.history !== 'loading' : resp.results !== null) && (
                <button className="link-button manual-link" onClick={() => setManual(true)}>
                  {t('manual.cta')}
                </button>
              )}
              {loading && !resp && <div className="skeleton-list">{[0, 1].map((i) => <div key={i} className="skeleton-card" />)}</div>}
            </>
          )}
        </div>
      </section>
    </div>
  );
}

