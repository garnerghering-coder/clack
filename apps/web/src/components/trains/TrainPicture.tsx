// The train's picture: a detailed side view where one has been drawn for that model (scripts/trains, docs/TRAIN_ART.md),
// in the operator's livery when it's been drawn, unpainted when it hasn't; otherwise the simple silhouette (TrainArt).
import type { ComponentType } from 'react';
import { TrainArt } from '../TrainArt';
import { Er1Side } from './Er1';
import { Flytoget71Side } from './Flytoget71';
import { Flytoget78Side } from './Flytoget78';
import { NoFlirtSide } from './NoFlirt';
import { NoType72Side } from './NoType72';
import { NoType73Side } from './NoType73';
import { NoType76Side } from './NoType76';
import { Rc6CoachesSide } from './Rc6Coaches';
import { ReginaSide } from './Regina';
import { X31Side } from './X31';
import { X2000Side } from './X2000';
import { X3Side } from './X3';
import { X40Side } from './X40';
import { X55Side } from './X55';
import { X60Side } from './X60';
import { X61Side } from './X61';
import { X62Side } from './X62';

type Side = ComponentType<{ livery: string; muted?: boolean; className?: string; label?: string }>;

interface Detailed {
  component: Side;
  /** Operators whose livery is drawn for this model; any other operator gets the unpainted version. */
  liveries: string[];
  /** Operators whose trains of this type look different from the drawing (e.g. other door layout): simple outline. */
  notFor?: string[];
}

/** Keyed by train type id (data/train_types.json), not by art family: Flytoget shares the X3's simple outline. */
const DETAILED: Record<string, Detailed> = {
  x3: { component: X3Side as Side, liveries: ['arlanda-express'] },
  // Unpainted: the rebuilt X2C's dark front is seen only at an angle; unrebuilt X2s are bare stainless anyway.
  x2000: { component: X2000Side as Side, liveries: [] },
  x40: { component: X40Side as Side, liveries: ['sj'] },
  x55: { component: X55Side as Side, liveries: ['sj'] },
  rc6_coaches: { component: Rc6CoachesSide as Side, liveries: ['sj'] },
  x60: { component: X60Side as Side, liveries: ['sl'] },
  // Västtåg's are mid-repaint (yellow to blue) and Östgötapendeln's cab-car paint differs between units: unpainted.
  x61: { component: X61Side as Side, liveries: ['pagatag'], notFor: ['vasttagen'] }, // Västtåg's X61s have 7 door pairs
  x62: { component: X62Side as Side, liveries: ['norrtag'] },
  // DSB's ETs ran in Öresundståg paint before going to Skåne (2022–23); its 2000 blue-band livery is gone.
  x31: { component: X31Side as Side, liveries: ['oresundstag', 'dsb'] },
  er1: { component: Er1Side as Side, liveries: ['malartag'] },
  // Picked per train from the set the live feed names; without it ('flytoget') the simple outline.
  flytoget71: { component: Flytoget71Side as Side, liveries: ['flytoget'] },
  flytoget78: { component: Flytoget78Side as Side, liveries: ['flytoget'] },
  // Värmlandstrafik's are mid-repaint (first in the new design March 2026): unpainted.
  regina: { component: ReginaSide as Side, liveries: ['vasttagen', 'tib', 'x-taget'] },
  no_flirt: { component: NoFlirtSide as Side, liveries: ['vy'] },
  // Both still run the paint the sets were delivered in (not Vy's green).
  no_type72: { component: NoType72Side as Side, liveries: ['go-ahead-norge', 'vy'] },
  // Go-Ahead's stripes are seen only at an angle and Vy's 73Bs are mid-repaint (red to green): both unpainted.
  no_type73: { component: NoType73Side as Side, liveries: ['sj-nord'] },
  // SJ Nord's livery isn't drawn yet: its curved edge shows only on photos too oblique to measure.
  no_type76: { component: NoType76Side as Side, liveries: [] },
};

export const hasDetailedArt = (typeId: string | null | undefined, operatorId?: string | null) =>
  !!typeId && typeId in DETAILED && !(operatorId && DETAILED[typeId]!.notFor?.includes(operatorId));

export function TrainPicture({ type, operatorId, color, height, label }: { type: { id: string; art: string; name: string }; operatorId: string | null | undefined; color: string; height: number; label?: string }) {
  const d = DETAILED[type.id];
  if (!d || !hasDetailedArt(type.id, operatorId)) return <TrainArt art={type.art} color={color} height={height} label={label} />;
  const Picture = d.component;
  return <Picture livery={operatorId && d.liveries.includes(operatorId) ? operatorId : 'plain'} className="train-side" label={label} />;
}
