// Adding a trip by hand, for a train no timetable we have can find: Norway before yesterday, a heritage run, a train
// abroad. Where you got on and off, the date and times (each station's local time), and optionally who ran it.
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { X } from 'lucide-react';
import { api, type LegDetail, type Operator, type StationHit } from '../api';
import { StationRow } from './StationRow';

function StationField({ label, value, onChange }: { label: string; value: StationHit | null; onChange: (s: StationHit | null) => void }) {
  const { t } = useTranslation();
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<StationHit[]>([]);
  useEffect(() => {
    if (!q.trim()) {
      setHits([]);
      return;
    }
    const ctrl = new AbortController();
    const timer = setTimeout(() => api.searchStations(q, ctrl.signal).then((h) => setHits(h.slice(0, 5)), () => undefined), 150);
    return () => {
      clearTimeout(timer);
      ctrl.abort();
    };
  }, [q]);
  if (value)
    return (
      <div className="row">
        <span>{label}</span>
        <button className="chip-button removable" onClick={() => onChange(null)} aria-label={t('manual.change', { station: value.name })}>
          {value.name} <X size={14} />
        </button>
      </div>
    );
  return (
    <div className="manual-station">
      <input className="search-field" type="search" autoComplete="off" spellCheck={false} placeholder={label} aria-label={label} value={q} onChange={(e) => setQ(e.target.value)} />
      {hits.length > 0 && (
        <ul className="station-list">
          {hits.map((s) => (
            <StationRow
              key={s.id}
              s={s}
              onPick={() => {
                onChange(s);
                setQ('');
              }}
            />
          ))}
        </ul>
      )}
    </div>
  );
}

const CATEGORIES = ['intercity', 'regional', 'commuter', 'night', 'heritage'] as const;

export function ManualTrip({ date, from: initialFrom, to: initialTo, onBack, onSaved }: { date: string; from?: StationHit; to?: StationHit; onBack: () => void; onSaved: (leg: LegDetail) => void }) {
  const { t } = useTranslation();
  const [from, setFrom] = useState<StationHit | null>(initialFrom ?? null);
  const [to, setTo] = useState<StationHit | null>(initialTo ?? null);
  const [dep, setDep] = useState('');
  const [arr, setArr] = useState('');
  const [operators, setOperators] = useState<Operator[]>([]);
  const [operatorId, setOperatorId] = useState('');
  const [trainNumber, setTrainNumber] = useState('');
  const [category, setCategory] = useState<(typeof CATEGORIES)[number]>('intercity');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  useEffect(() => {
    api.operators().then((o) => setOperators([...o].sort((a, b) => a.name.localeCompare(b.name))), () => undefined);
  }, []);
  const ready = from && to && from.id !== to.id && dep && arr;
  const save = () => {
    if (!ready) return;
    setSaving(true);
    setError(null);
    api
      .createManualLeg({ fromStationId: from.id, toStationId: to.id, date, dep, arr, operatorId: operatorId || null, trainNumber: trainNumber || null, category })
      .then(onSaved, (e: Error) => setError(e.message))
      .finally(() => setSaving(false));
  };
  return (
    <section className="manual-trip">
      <button className="link-button" onClick={onBack}>
        {t('common.back')}
      </button>
      <h2>{t('manual.title')}</h2>
      <p className="caption">{t('manual.intro')}</p>
      <div className="card">
        <StationField label={t('manual.from')} value={from} onChange={setFrom} />
        <StationField label={t('manual.to')} value={to} onChange={setTo} />
        <label className="row">
          <span>{t('manual.dep')}</span>
          <input className="text-input" type="time" value={dep} onChange={(e) => setDep(e.target.value)} />
        </label>
        <label className="row">
          <span>{t('manual.arr')}</span>
          <input className="text-input" type="time" value={arr} onChange={(e) => setArr(e.target.value)} />
        </label>
        <label className="row">
          <span>{t('manual.operator')}</span>
          <select value={operatorId} onChange={(e) => setOperatorId(e.target.value)}>
            <option value="">{t('manual.unknown')}</option>
            {operators.map((o) => (
              <option key={o.id} value={o.id}>
                {o.name}
              </option>
            ))}
          </select>
        </label>
        <label className="row">
          <span>{t('manual.number')}</span>
          <input className="text-input" inputMode="numeric" maxLength={10} value={trainNumber} onChange={(e) => setTrainNumber(e.target.value)} />
        </label>
      </div>
      <div className="chip-row" role="radiogroup" aria-label={t('manual.kind')}>
        {CATEGORIES.map((c) => (
          <button key={c} role="radio" aria-checked={category === c} className={category === c ? 'chip-button active' : 'chip-button'} onClick={() => setCategory(c)}>
            {t(`manual.kinds.${c}`)}
          </button>
        ))}
      </div>
      <p className="caption">{t('manual.timesNote')}</p>
      {error && <p className="banner error">{error}</p>}
      <button className="button primary" disabled={!ready || saving} onClick={save}>
        {t('manual.save')}
      </button>
    </section>
  );
}
