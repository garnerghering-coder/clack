// Station departure and arrival board (ADDITIONS_01 B). Live while open: the server polls Trafikverket once for
// everyone watching this station and pushes the board over SSE.
import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, Map as MapIcon, Star, X } from 'lucide-react';
import { api, type Board, type BoardRow, type BoardType, type StationInfo, type TimetableTrip } from '../api';
import { OperatorBadge } from '../components/OperatorBadge';
import { DelayPill } from '../components/DelayPill';
import { SplitFlap } from '../components/SplitFlap';
import { useOperators, useTrainTypes } from '../data';
import { agoKey, useNow } from '../live';
import { useSettings } from '../settings';
import { fmtTime } from '../format';
import { Onboard } from '../components/Onboard';

type Window = '1h' | '3h' | 'day';
const WINDOW_MS: Record<Window, number> = { '1h': 3600_000, '3h': 3 * 3600_000, day: 24 * 3600_000 };
const PAST_MS = 10 * 60_000;
const CHANGED_RECENT_MS = 15 * 60_000;
const FILTER_PRODUCTS = ['high_speed', 'intercity', 'regional', 'commuter', 'night'] as const;
const TZ = 'Europe/Stockholm';

const shownTime = (r: BoardRow) => r.actual ?? r.estimated ?? r.advertised;
const minuteOf = (ms: number) => Math.floor(ms / 60_000);

function RowSheet({ row, type, station, onClose }: { row: BoardRow; type: BoardType; station: StationInfo; onClose: () => void }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const ops = useOperators();
  const types = useTrainTypes();
  const navigate = useNavigate();
  const [trip, setTrip] = useState<TimetableTrip | null>(null);
  useEffect(() => {
    if (row.trip) api.timetableTrip(row.trip.key, row.trip.serviceDate).then(setTrip, () => undefined);
  }, [row]);
  const op = row.operatorId ? ops.get(row.operatorId) : undefined;
  const add = () => {
    if (!row.trip) return;
    const q = new URLSearchParams({ trip: row.trip.key, date: row.trip.serviceDate });
    // Departures: you get on here. Arrivals: you get off here.
    q.set(type === 'departures' ? 'from' : 'to', String(row.trip.seq));
    navigate(`/add?${q}`);
  };
  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <section
        className="board-sheet"
        role="dialog"
        aria-modal="true"
        aria-label={`${row.productName ?? ''} ${row.trainNumber}`}
        onClick={(e) => e.stopPropagation()}
      >
        <header className="board-sheet-head">
          <OperatorBadge operator={op} size={32} />
          <span className="strong">{[row.productName ?? op?.name, row.trainNumber].filter(Boolean).join(' ')}</span>
          <button className="icon-button small" onClick={onClose} aria-label={t('common.close')}>
            <X size={18} />
          </button>
        </header>
        <h2 className="board-sheet-title">
          {type === 'departures' ? `${station.name} → ${row.endpoints.join(', ')}` : `${row.endpoints.join(', ')} → ${station.name}`}
        </h2>
        <div className="chip-row">
          {row.platform && <span className="chip">{t('trips.platform', { platform: row.platform })}</span>}
          {(row.delayMin !== null || row.canceled) && <DelayPill delay={row.delayMin} canceled={row.canceled} />}
          {row.trainType && types.get(row.trainType) && <span className="chip">{types.get(row.trainType)!.name}</span>}
        </div>
        {row.deviations.length > 0 && <p className="caption">{row.deviations.join(' · ')}</p>}
        {type === 'departures' && <Onboard facts={row.onboard} operatorId={row.operatorId} trainType={row.trainType} compact />}
        {trip ? (
          <ol className="sheet-stops">
            {trip.stops.map((s) => {
              const here = s.seq === row.trip?.seq;
              const time = s.dep ?? s.arr;
              return (
                <li key={s.seq} className={here ? 'here' : ''}>
                  <span className="tabular caption">{fmtTime(time, s.tz, settings.clock)}</span>
                  <span className={here ? 'strong' : ''}>{s.name}</span>
                </li>
              );
            })}
          </ol>
        ) : row.trip ? (
          <div className="skeleton-row" />
        ) : (
          <p className="caption">{t('board.notInTimetable')}</p>
        )}
        <div className="sheet-actions row-actions">
          {!row.done && !row.canceled && (
            <button className="button" onClick={() => navigate(`/live?train=${encodeURIComponent(row.trainNumber)}`)}>
              {t('liveMap.showOnMap')}
            </button>
          )}
          <button className="button primary" onClick={add} disabled={!row.trip}>
            {t('board.addToTrips')}
          </button>
        </div>
      </section>
    </div>
  );
}

function Row({ row, type, now, onOpen }: { row: BoardRow; type: BoardType; now: number; onOpen: () => void }) {
  const { t } = useTranslation();
  const { settings } = useSettings();
  const ops = useOperators();
  const types = useTrainTypes();
  const op = row.operatorId ? ops.get(row.operatorId) : undefined;
  const big = shownTime(row);
  const moved = minuteOf(big) !== minuteOf(row.advertised);
  const past = big < now && !row.canceled;
  const changed = row.platformChange && (row.platformChange.at === null || now - row.platformChange.at < CHANGED_RECENT_MS);
  const type_ = row.trainType ? types.get(row.trainType) : undefined;
  return (
    <li>
      <button className={`board-row ${past ? 'past' : ''} ${row.canceled ? 'cancelled' : ''}`} onClick={onOpen}>
        <span className="board-time">
          <SplitFlap value={fmtTime(big, TZ, settings.clock)} className="board-flap" />
          {moved && <span className="sched-struck tabular">{fmtTime(row.advertised, TZ, settings.clock)}</span>}
        </span>
        <span className="board-main">
          <span className="board-dest">{row.endpoints.join(', ') || '—'}</span>
          {row.via.length > 0 && (
            <span className="caption board-via">{t(type === 'departures' ? 'board.via' : 'board.from', { stops: row.via.join(', ') })}</span>
          )}
          <span className="board-meta caption">
            <OperatorBadge operator={op} size={18} />
            <span>{[row.productName ?? op?.name, row.trainNumber].filter(Boolean).join(' ')}</span>
            {type_ && <span>· {type_.name}</span>}
          </span>
          {row.deviations.length > 0 && <span className="caption board-dev">{row.deviations.slice(0, 2).join(' · ')}</span>}
        </span>
        <span className="board-side">
          {row.platform && (
            <span className={`platform-chip ${changed ? 'changed' : ''}`} title={changed ? t('board.platformChanged') : undefined}>
              {changed && row.platformChange?.from && <s>{row.platformChange.from}</s>}
              <span className="tabular">{row.platform}</span>
            </span>
          )}
          {changed && <span className="caption changed-label">{t('board.changed')}</span>}
          {row.canceled ? (
            <DelayPill delay={null} canceled />
          ) : row.delayMin !== null && (row.estimated !== null || row.actual !== null) ? (
            <DelayPill delay={row.delayMin} />
          ) : null}
          {row.done && <span className="caption">{t(type === 'departures' ? 'board.departed' : 'board.arrived')}</span>}
        </span>
      </button>
    </li>
  );
}

export function BoardPage() {
  const { id = '' } = useParams();
  const { t } = useTranslation();
  const { settings } = useSettings();
  const ops = useOperators();
  const [params, setParams] = useSearchParams();
  const type: BoardType = params.get('type') === 'arrivals' ? 'arrivals' : 'departures';
  const [station, setStation] = useState<StationInfo | null>(null);
  const [missing, setMissing] = useState(false);
  const [board, setBoard] = useState<Board | null>(null);
  const [earlier, setEarlier] = useState<BoardRow[] | null>(null);
  const [showEarlier, setShowEarlier] = useState(false);
  const [error, setError] = useState(false);
  const [win, setWin] = useState<Window>('3h');
  const [commuter, setCommuter] = useState(settings.includeCommuter);
  const [opFilter, setOpFilter] = useState<Set<string>>(new Set());
  const [productFilter, setProductFilter] = useState<Set<string>>(new Set());
  const [open, setOpen] = useState<BoardRow | null>(null);
  const now = useNow(1000);

  useEffect(() => {
    setStation(null);
    api.station(id).then(setStation, () => setMissing(true));
    api.stationViewed(id).catch(() => undefined);
  }, [id]);

  // Live board: the stream sends the current board straight away, then after every shared poll.
  useEffect(() => {
    if (!station?.hasBoard) return;
    setBoard(null);
    setEarlier(null);
    setShowEarlier(false);
    setError(false);
    const es = new EventSource(`/api/stations/${id}/board/stream?type=${type}`);
    es.addEventListener('board', (e) => {
      setBoard(JSON.parse((e as MessageEvent<string>).data) as Board);
      setError(false);
    });
    es.onerror = () => setError(true);
    return () => es.close();
  }, [id, type, station?.hasBoard]);

  const loadEarlier = async () => {
    setShowEarlier(true);
    if (!board || earlier) return;
    const to = board.from;
    api.board(id, type, { from: to - 3 * 3600_000, to }).then(
      (b) => setEarlier(b.rows),
      () => setEarlier([]),
    );
  };

  const operatorsHere = useMemo(() => [...new Set((board?.rows ?? []).map((r) => r.operatorId).filter((o): o is string => !!o))], [board]);
  const rows = useMemo(() => {
    const all = [...(showEarlier ? (earlier ?? []) : []), ...(board?.rows ?? [])];
    return all.filter((r) => {
      const time = shownTime(r);
      if (!showEarlier && time < now - PAST_MS && !r.canceled) return false;
      if (!showEarlier && r.canceled && r.advertised < now - PAST_MS) return false;
      if (r.advertised > now + WINDOW_MS[win]) return false;
      if (!commuter && r.product === 'commuter') return false;
      if (opFilter.size && (!r.operatorId || !opFilter.has(r.operatorId))) return false;
      if (productFilter.size && !productFilter.has(r.product)) return false;
      return true;
    });
  }, [board, earlier, showEarlier, now, win, commuter, opFilter, productFilter]);

  const toggle = (set: Set<string>, v: string, apply: (s: Set<string>) => void) => {
    const n = new Set(set);
    if (n.has(v)) n.delete(v);
    else n.add(v);
    apply(n);
  };
  const favorite = async () => {
    if (!station) return;
    const r = await api.setFavorite(station.id, !station.favorite);
    setStation({ ...station, favorite: r.favorite });
  };
  const fresh = board && now - board.updatedAt < 2 * 60_000;

  if (missing)
    return (
      <main className="page">
        <Link to="/stations" className="link-button back-link">
          <ArrowLeft size={18} /> {t('stations.title')}
        </Link>
        <p className="muted">{t('board.notFound')}</p>
      </main>
    );

  return (
    <main className="page board-page">
      <Link to="/stations" className="link-button back-link">
        <ArrowLeft size={18} /> {t('stations.title')}
      </Link>
      <header className="board-head">
        <div>
          <h1 className="detail-route">{station?.name ?? ' '}</h1>
          {station?.county && <p className="caption">{station.county}</p>}
        </div>
        {station?.hasMap && (
          <Link className="icon-button" to={`/stations/${station.id}/map`} aria-label={t('stationMap.open')} title={t('stationMap.open')}>
            <MapIcon size={20} />
          </Link>
        )}
        {station && (
          <button
            className={`icon-button ${station.favorite ? 'fav-on' : ''}`}
            onClick={favorite}
            aria-pressed={station.favorite}
            aria-label={t(station.favorite ? 'stations.unfavorite' : 'stations.favorite')}
          >
            <Star size={20} fill={station.favorite ? 'currentColor' : 'none'} />
          </button>
        )}
      </header>
      {board && (
        <p className="board-status caption">
          {fresh ? (
            <span className="chip live-chip">
              <span className="live-dot" aria-hidden="true" />
              {t('live.chip')}
            </span>
          ) : (
            <span className="chip stale-chip">{t('live.stale', { ago: agoKey(t, board.updatedAt, now) })}</span>
          )}{' '}
          {t('live.updated', { ago: agoKey(t, board.updatedAt, now) })}
        </p>
      )}

      <div className="segmented" role="tablist">
        {(['departures', 'arrivals'] as const).map((k) => (
          <button
            key={k}
            role="tab"
            aria-selected={type === k}
            className={type === k ? 'active' : ''}
            onClick={() => setParams(k === 'arrivals' ? { type: k } : {})}
          >
            {t(`board.${k}`)}
          </button>
        ))}
      </div>

      <div className="chip-row board-filters">
        {(['1h', '3h', 'day'] as const).map((w) => (
          <button key={w} className={win === w ? 'chip-button active' : 'chip-button'} onClick={() => setWin(w)}>
            {t(`board.window.${w}`)}
          </button>
        ))}
        <button className={commuter ? 'chip-button active' : 'chip-button'} onClick={() => setCommuter(!commuter)} aria-pressed={commuter}>
          {t('board.commuter')}
        </button>
        {FILTER_PRODUCTS.filter((p) => board?.rows.some((r) => r.product === p)).map((p) => (
          <button
            key={p}
            className={productFilter.has(p) ? 'chip-button active' : 'chip-button'}
            onClick={() => toggle(productFilter, p, setProductFilter)}
            aria-pressed={productFilter.has(p)}
          >
            {t(`products.${p}`)}
          </button>
        ))}
        {operatorsHere.length > 1 &&
          operatorsHere.map((o) => (
            <button
              key={o}
              className={opFilter.has(o) ? 'chip-button active' : 'chip-button'}
              onClick={() => toggle(opFilter, o, setOpFilter)}
              aria-pressed={opFilter.has(o)}
            >
              {ops.get(o)?.name ?? o}
            </button>
          ))}
      </div>

      {station && !station.hasBoard && <p className="muted">{t('board.noBoard')}</p>}
      {station?.hasBoard && !board && !error && (
        <div className="board-loading">
          <div className="skeleton-row" />
          <div className="skeleton-row" />
          <p className="caption">{t('board.loading')}</p>
        </div>
      )}
      {error && !board && <p className="banner error">{t('board.error')}</p>}

      {board && (
        <>
          {!showEarlier && (
            <button className="link-button" onClick={loadEarlier}>
              {t('board.showEarlier')}
            </button>
          )}
          {rows.length ? (
            <ul className="board-list">
              {rows.map((r) => (
                <Row key={r.id} row={r} type={type} now={now} onOpen={() => setOpen(r)} />
              ))}
            </ul>
          ) : (
            <section className="empty">
              <p>{t('board.empty')}</p>
              {win !== 'day' && (
                <button className="button" onClick={() => setWin(win === '1h' ? '3h' : 'day')}>
                  {t('board.widen')}
                </button>
              )}
            </section>
          )}
        </>
      )}
      {open && station && <RowSheet row={open} type={type} station={station} onClose={() => setOpen(null)} />}
    </main>
  );
}
