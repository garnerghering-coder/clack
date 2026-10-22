// The train's picture: a detailed side view where one has been drawn for that model (scripts/trains, docs/TRAIN_ART.md),
// in the operator's livery when it's been drawn, unpainted when it hasn't; otherwise the simple silhouette (TrainArt).
import type { ComponentType } from 'react';
import { TrainArt } from '../TrainArt';
import { Er1Side } from './Er1';
import { NoFlirtSide } from './NoFlirt';
import { NoType73Side } from './NoType73';
import { NoType76Side } from './NoType76';
import { ReginaSide } from './Regina';
import { X31Side } from './X31';
import { X3Side } from './X3';
import { X40Side } from './X40';
import { X60Side } from './X60';

type Side = ComponentType<{ livery: string; muted?: boolean; className?: string; label?: string }>;

interface Detailed {
  component: Side;
  /** Operators whose livery is drawn for this model; any other operator gets the unpainted version. */
  liveries: string[];
}

/** Keyed by train type id (data/train_types.json), not by art family: Flytoget shares the X3's simple outline. */
const DETAILED: Record<string, Detailed> = {
  x3: { component: X3Side as Side, liveries: ['arlanda-express'] },
  x40: { component: X40Side as Side, liveries: ['sj'] },
  x60: { component: X60Side as Side, liveries: ['sl'] },
  x31: { component: X31Side as Side, liveries: ['oresundstag'] },
  er1: { component: Er1Side as Side, liveries: ['malartag'] },
  // Värmlandstrafik's are mid-repaint (first in the new design March 2026): unpainted.
  regina: { component: ReginaSide as Side, liveries: ['vasttagen', 'tib', 'x-taget'] },
  no_flirt: { component: NoFlirtSide as Side, liveries: ['vy'] },
  // Go-Ahead's stripes are seen only at an angle and Vy's 73Bs are mid-repaint (red to green): both unpainted.
  no_type73: { component: NoType73Side as Side, liveries: ['sj-nord'] },
  // SJ Nord's livery isn't drawn yet: its curved edge shows only on photos too oblique to measure.
  no_type76: { component: NoType76Side as Side, liveries: [] },
};

export const hasDetailedArt = (typeId: string | null | undefined) => !!typeId && typeId in DETAILED;

export function TrainPicture({ type, operatorId, color, height, label }: { type: { id: string; art: string; name: string }; operatorId: string | null | undefined; color: string; height: number; label?: string }) {
  const d = DETAILED[type.id];
  if (!d) return <TrainArt art={type.art} color={color} height={height} label={label} />;
  const Picture = d.component;
  return <Picture livery={operatorId && d.liveries.includes(operatorId) ? operatorId : 'plain'} className="train-side" label={label} />;
}
