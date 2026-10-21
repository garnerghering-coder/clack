// The train you rode (owner request 2026-10-21): illustration, type and a few facts. Types are typical guesses
// (no open data says which vehicle ran), so they're labelled and the owner can correct them.
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api, type LegDetail } from '../api';
import { useTrainTypes } from '../data';
import { TrainArt } from './TrainArt';
import { opColor } from '../map/style';

export function TrainCard({ leg, onChange }: { leg: LegDetail; onChange: (l: LegDetail) => void }) {
  const { t } = useTranslation();
  const types = useTrainTypes();
  const [picking, setPicking] = useState(false);
  const [saving, setSaving] = useState(false);
  const color = opColor(leg.operator?.brandColor);
  const type = leg.trainType ? types.get(leg.trainType) : undefined;

  const choose = async (id: string | null) => {
    setSaving(true);
    try {
      onChange(await api.setTrainType(leg.id, id));
      setPicking(false);
    } finally {
      setSaving(false);
    }
  };

  return (
    <section className="card train-card">
      <h2 className="section-header">{t('train.title')}</h2>
      {type ? (
        <>
          <div className="train-art-wrap">
            <TrainArt art={type.art} color={color} height={46} label={type.name} />
          </div>
          <p className="train-name">
            <span className="strong">{type.name}</span>{' '}
            <span className="chip">{t(leg.trainTypeSource === 'user' ? 'train.yourChoice' : leg.trainTypeSource === 'composition' ? 'train.planned' : 'train.typical')}</span>
          </p>
          <p className="caption">{type.about}</p>
          {leg.trainTypeSource !== 'user' && <p className="caption muted">{t(leg.trainTypeSource === 'composition' ? 'train.plannedNote' : 'train.typicalNote')}</p>}
          <dl className="train-facts">
            {type.max_kmh && (
              <div>
                <dt className="caption upper">{t('train.topSpeed')}</dt>
                <dd className="tabular">{type.max_kmh} km/h</dd>
              </div>
            )}
            {type.since && (
              <div>
                <dt className="caption upper">{t('train.since')}</dt>
                <dd className="tabular">{type.since}</dd>
              </div>
            )}
            {type.builder && (
              <div>
                <dt className="caption upper">{t('train.builder')}</dt>
                <dd>{type.builder}</dd>
              </div>
            )}
          </dl>
        </>
      ) : (
        <p className="caption">{t('train.unknown')}</p>
      )}
      <button className="link-button" onClick={() => setPicking(!picking)}>
        {picking ? t('train.cancel') : t('train.change')}
      </button>
      {picking && (
        <ul className="train-picker">
          {[...types.values()].map((x) => (
            <li key={x.id}>
              <button className={`train-option ${x.id === leg.trainType ? 'active' : ''}`} onClick={() => choose(x.id)} disabled={saving}>
                <TrainArt art={x.art} color={color} height={18} />
                <span>{x.name}</span>
              </button>
            </li>
          ))}
          {leg.trainTypeSource === 'user' && (
            <li>
              <button className="train-option" onClick={() => choose(null)} disabled={saving}>
                <span>{t('train.resetTypical')}</span>
              </button>
            </li>
          )}
        </ul>
      )}
    </section>
  );
}
