// Flighty's "Add Flight" sheet, for trains: one smart search field. Step 3 covers station autocomplete;
// train-number and route search arrive in step 4.
import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { api, type StationHit } from '../api';
import { Sheet } from '../components/Sheet';
import { Flag } from '../components/Flag';
import { CloseIcon } from '../components/icons';

function StationRow({ station, onPick }: { station: StationHit; onPick: (s: StationHit) => void }) {
  const { t } = useTranslation();
  return (
    <li>
      <button className="result-row" onClick={() => onPick(station)}>
        <Flag country={station.country} />
        <span className="result-text">
          <span className="result-title">{station.name}</span>
          <span className="result-sub">{[station.code, t(`countries.${station.country}`, { defaultValue: station.country })].filter(Boolean).join(' • ')}</span>
        </span>
      </button>
    </li>
  );
}

export function AddTripPage() {
  const { t } = useTranslation();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<StationHit[] | null>(null);
  const [popular, setPopular] = useState<StationHit[]>([]);
  const [error, setError] = useState(false);
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => {
    input.current?.focus();
    api.popularStations().then(setPopular, () => setError(true));
  }, []);

  useEffect(() => {
    if (!query.trim()) {
      setResults(null);
      return;
    }
    const ctrl = new AbortController();
    // Small debounce so each keystroke doesn't fire a request.
    const timer = setTimeout(() => {
      api.searchStations(query, ctrl.signal).then(
        (r) => {
          setResults(r);
          setError(false);
        },
        (e: Error) => e.name !== 'AbortError' && setError(true),
      );
    }, 120);
    return () => {
      clearTimeout(timer);
      ctrl.abort();
    };
  }, [query]);

  const pick = (s: StationHit) => setQuery(s.name);
  const list = results ?? popular;

  return (
    <Sheet
      full
      title={t('add.title')}
      subtitle={t('add.subtitle')}
      actions={
        <Link to="/" className="round-button" aria-label={t('common.close')}>
          <CloseIcon size={30} />
        </Link>
      }
    >
      <input
        ref={input}
        className="search-field"
        type="search"
        enterKeyHint="search"
        autoComplete="off"
        autoCorrect="off"
        spellCheck={false}
        placeholder={t('add.placeholder')}
        aria-label={t('add.title')}
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />
      {error && <p className="banner error">{t('common.offline')}</p>}
      <h2 className="section-header">{results ? t('add.stations') : t('add.popular')}</h2>
      {results && results.length === 0 ? (
        <p className="muted">{t('add.noResults')}</p>
      ) : (
        <ul className="result-list">
          {list.map((s) => (
            <StationRow key={s.id} station={s} onPick={pick} />
          ))}
        </ul>
      )}
    </Sheet>
  );
}
