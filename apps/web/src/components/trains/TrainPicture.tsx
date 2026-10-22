// The train's picture: a detailed side view where one has been drawn for that model (components/trains), in the
// operator's livery when we know it, unpainted when we don't; otherwise the simple silhouette (TrainArt).
import type { ReactElement } from 'react';
import { TrainArt } from '../TrainArt';
import { X3Side } from './X3';

interface Detailed {
  /** Operators whose livery is drawn for this model; any other operator gets the unpainted version. */
  liveries: string[];
  draw: (livery: string, opts: { className: string; label?: string; muted?: boolean }) => ReactElement;
}

/** Keyed by train type id (data/train_types.json), not by art family: Flytoget shares the X3's simple outline. */
const DETAILED: Record<string, Detailed> = {
  x3: { liveries: ['arlanda-express'], draw: (l, o) => <X3Side livery={l as 'arlanda-express' | 'plain'} {...o} /> },
};

export const hasDetailedArt = (typeId: string | null | undefined) => !!typeId && typeId in DETAILED;

export function TrainPicture({
  type,
  operatorId,
  color,
  height,
  label,
}: {
  type: { id: string; art: string; name: string };
  operatorId: string | null | undefined;
  color: string;
  height: number;
  label?: string;
}) {
  const d = DETAILED[type.id];
  if (!d) return <TrainArt art={type.art} color={color} height={height} label={label} />;
  const livery = operatorId && d.liveries.includes(operatorId) ? operatorId : 'plain';
  return d.draw(livery, { className: 'train-side', label });
}
