// The train's picture: a detailed side view where one has been drawn for that model (scripts/trains, docs/TRAIN_ART.md),
// in the operator's livery when it's been drawn, unpainted when it hasn't; otherwise the nearest drawn model, unpainted
// and faded, as a stand-in.
import type { ComponentType } from 'react';
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
import { X74Side } from './X74';
import { Y31Side } from './Y31';
import { X40Side } from './X40';
import { X55Side } from './X55';
import { X60Side } from './X60';
import { X11Side } from './X11';
import { X61Side } from './X61';
import { X61VTSide } from './X61VT';
import { X62Side } from './X62';

type Side = ComponentType<{ livery: string; muted?: boolean; className?: string; label?: string }>;

interface Detailed {
  component: Side;
  /** Operators whose livery is drawn for this model; any other operator gets the unpainted version. */
  liveries: string[];
  /** Operators whose trains of this type look different from the drawing (e.g. other door layout): a stand-in. */
  notFor?: string[];
  /** Operators whose livery has its own id in the drawing (one operator, two schemes: the more common one). */
  liveryOf?: Record<string, string>;
}

/** Keyed by train type id (data/train_types.json), not by art family: Flytoget shares the X3's simple outline. */
const DETAILED: Record<string, Detailed> = {
  x3: { component: X3Side as Side, liveries: ['arlanda-express'] },
  // Two SJ schemes: unrebuilt X2 (grey, about 21 sets in Dec 2025) and rebuilt X2C (dark front, about 10 then, 4–5 more a
  // year; Järnvägar.nu 2025-12-03). Nothing says which set runs which train: the more common one.
  x2000: { component: X2000Side as Side, liveries: ['sj'], liveryOf: { sj: 'sj-x2' } },
  x40: { component: X40Side as Side, liveries: ['sj'] },
  x55: { component: X55Side as Side, liveries: ['sj'] },
  rc6_coaches: { component: Rc6CoachesSide as Side, liveries: ['sj'] },
  x60: { component: X60Side as Side, liveries: ['sl'] },
  // Västtåg's are mid-repaint (yellow to blue) and Östgötapendeln's cab-car paint differs between units: unpainted.
  x61: { component: X61Side as Side, liveries: ['pagatag'] },
  // Västtrafik's X61s: the X60's door layout. Unpainted while the yellow-to-blue repaint is under way and no side-on
  // photo of the blue one exists.
  x61_vt: { component: X61VTSide as Side, liveries: [] },
  x62: { component: X62Side as Side, liveries: ['norrtag'] },
  x74: { component: X74Side as Side, liveries: ['vr'] },
  // Värmlandstrafik's: the newest dated photos (2016–20) show the old paint, and its repaint started in 2026: unpainted.
  y31: { component: Y31Side as Side, liveries: ['krosatag', 'vasttagen'] },
  // DSB's ETs ran in Öresundståg paint before going to Skåne (2022–23); its 2000 blue-band livery is gone.
  x31: { component: X31Side as Side, liveries: ['oresundstag', 'dsb'] },
  x11: { component: X11Side as Side, liveries: ['krosatag'] },
  er1: { component: Er1Side as Side, liveries: ['malartag'] },
  // Picked per train from the set the live feed names; without it ('flytoget') the simple outline.
  flytoget71: { component: Flytoget71Side as Side, liveries: ['flytoget'] },
  flytoget78: { component: Flytoget78Side as Side, liveries: ['flytoget'] },
  // Värmlandstrafik's new design is drawn but only 2 of 8 units are confirmed repainted (Oct 2026): unpainted for now.
  regina: { component: ReginaSide as Side, liveries: ['vasttagen', 'tib', 'x-taget', 'sj', 'malartag'] },
  no_flirt: { component: NoFlirtSide as Side, liveries: ['vy'] },
  // Both still run the paint the sets were delivered in (not Vy's green).
  no_type72: { component: NoType72Side as Side, liveries: ['go-ahead-norge', 'vy'] },
  // Vy's 73Bs are mid-repaint (red to green): unpainted.
  no_type73: { component: NoType73Side as Side, liveries: ['sj-nord', 'go-ahead-norge'] },
  no_type76: { component: NoType76Side as Side, liveries: ['sj-nord'] },
};

export const hasDetailedArt = (typeId: string | null | undefined, operatorId?: string | null) =>
  !!typeId && typeId in DETAILED && !(operatorId && DETAILED[typeId]!.notFor?.includes(operatorId));

/**
 * The drawn model nearest to each family ("art" in data/train_types.json), shown unpainted and faded when the train's
 * own model isn't drawn (owner, 2026-10-23: "an unbranded version of one of the trains we already have based on
 * whatever is closest"). Steam and night trains have no closer drawing than a locomotive with coaches.
 */
const STAND_IN: Record<string, string> = {
  x2000: 'x2000',
  x3: 'x3',
  coradia: 'x60',
  regina: 'regina',
  contessa: 'x11',
  flirt: 'no_flirt',
  double_deck: 'x40',
  railcar: 'y31',
  loco: 'rc6_coaches',
  loco_sleeper: 'rc6_coaches',
  steam: 'rc6_coaches',
};
/** No type at all: the most common kind of train here, a regional electric unit. */
const UNKNOWN_STAND_IN = 'x60';

/**
 * Defaults when we know less (owner, 2026-10-22 and 2026-10-23):
 * - a drawn model run by an operator whose livery isn't drawn: the model unpainted;
 * - a type without a drawing: the nearest drawn model (STAND_IN), unpainted and faded;
 * - a type that names two models (no source says which) or no type at all: the same, fainter.
 */
export function TrainPicture({ type, operatorId, label }: { type: { id: string; art: string; name: string; uncertain?: boolean } | null | undefined; operatorId: string | null | undefined; label?: string }) {
  const d = type && !type.uncertain ? DETAILED[type.id] : undefined;
  if (d && hasDetailedArt(type!.id, operatorId)) {
    const livery = operatorId && d.liveries.includes(operatorId) ? (d.liveryOf?.[operatorId] ?? operatorId) : 'plain';
    return <d.component livery={livery} className="train-side" label={label} />;
  }
  const standIn = DETAILED[(type && STAND_IN[type.art]) ?? UNKNOWN_STAND_IN] ?? DETAILED[UNKNOWN_STAND_IN]!;
  const Picture = standIn.component;
  return (
    <span className={`train-stand-in ${!type || type.uncertain ? 'unknown' : ''}`}>
      <Picture livery="plain" className="train-side" label={label} />
    </span>
  );
}
