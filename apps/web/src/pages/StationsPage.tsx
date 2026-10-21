// Station search (ADDITIONS_01 B): one field, favourites and recent stations when it's empty.
import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, Star } from 'lucide-react';
import { api, type StationHit } from '../api';
import { StationRow } from '../components/StationRow';

export function StationsPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<StationHit[] | null>(null);
  const [favorites, setFavorites] = useState<StationHit[]>([]);
  const [recent, setRecent] = useState<StationHit[]>([]);
  const [popular, setPopular] = useState<StationHit[]>([]);
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => {
    input.current?.focus();
    api.favoriteStations().then(setFavorites, () => undefined);
    api.recentStations().then(setRecent, () => undefined);
    api.popularStations().then(setPopular, () => undefined);
  }, []);

  useEffect(() => {
    if (!q.trim()) {
      setHits(null);
      return;
    }
    const ctrl = new AbortController();
    const timer = setTimeout(() => api.searchStations(q, ctrl.signal).then(setHits, () => undefined), 120);
    return () => {
      clearTimeout(timer);
      ctrl.abort();
    };
  }, [q]);

  const open = (s: StationHit) => navigate(`/stations/${s.id}`);
  const favIds = new Set(favorites.map((f) => f.id));
  const section = (title: string, list: StationHit[]) =>
    list.length > 0 && (
      <section>
        <h2 className="section-header">{title}</h2>
        <ul className="station-list">
          {list.map((s) => (
            <StationRow
              key={s.id}
              s={s}
              onPick={() => open(s)}
              trailing={favIds.has(s.id) ? <Star size={16} className="fav-star" aria-label={t('stations.favorite')} /> : undefined}
            />
          ))}
        </ul>
      </section>
    );

  return (
    <main className="page">
      <Link to="/" className="link-button back-link">
        <ArrowLeft size={18} /> {t('nav.trips')}
      </Link>
      <header className="page-header">
        <h1>{t('stations.title')}</h1>
      </header>
      <input
        ref={input}
        className="search-field"
        type="search"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder={t('stations.placeholder')}
        aria-label={t('stations.placeholder')}
        autoComplete="off"
      />
      {hits !== null ? (
        hits.length ? (
          <ul className="station-list">
            {hits.map((s) => (
              <StationRow key={s.id} s={s} onPick={() => open(s)} />
            ))}
          </ul>
        ) : (
          <p className="muted">{t('stations.noMatch')}</p>
        )
      ) : (
        <>
          {section(t('stations.favorites'), favorites)}
          {section(
            t('stations.recent'),
            recent.filter((r) => !favIds.has(r.id)),
          )}
          {section(
            t('stations.popular'),
            popular.filter((p) => !favIds.has(p.id) && !recent.some((r) => r.id === p.id)),
          )}
        </>
      )}
    </main>
  );
}
