// Side-view train drawings, one per family in data/train_types.json ("art"). Our own simplified silhouettes in a
// silver finish with the operator colour as the livery stripe; not copies of any operator's artwork.
import { useId, type ReactElement } from 'react';

type Nose = 'flat' | 'round' | 'sloped' | 'pointy' | 'blunt' | 'cab';
interface Car {
  len: number;
  left: Nose;
  right: Nose;
  kind: 'emu' | 'coach' | 'power' | 'loco' | 'sleeper' | 'double' | 'steam' | 'tender' | 'wood';
}

const TOP = 7;
const BOTTOM = 31;
const H = 40;

function family(art: string): { cars: Car[]; gap: number } {
  const emu = (n: number, len: number, nose: Nose, kind: Car['kind'] = 'emu') =>
    Array.from({ length: n }, (_, i) => ({ len, left: i === 0 ? nose : 'flat', right: i === n - 1 ? nose : 'flat', kind }) as Car);
  switch (art) {
    case 'x2000':
      return {
        gap: 2,
        cars: [
          { len: 46, left: 'cab', right: 'flat', kind: 'coach' },
          ...emu(4, 44, 'flat', 'coach'),
          { len: 38, left: 'flat', right: 'blunt', kind: 'power' },
        ],
      };
    case 'coradia':
      return { gap: 1, cars: emu(4, 40, 'round') };
    case 'regina':
      return { gap: 1, cars: emu(3, 48, 'round') };
    case 'contessa':
      return { gap: 1, cars: emu(3, 48, 'sloped') };
    case 'flirt':
      return { gap: 1, cars: emu(5, 36, 'sloped') };
    case 'x3':
      return { gap: 1, cars: emu(4, 42, 'pointy') };
    case 'double_deck':
      return { gap: 1, cars: emu(4, 44, 'round', 'double') };
    case 'loco':
      return { gap: 2, cars: [...emu(4, 46, 'flat', 'coach'), { len: 30, left: 'flat', right: 'cab', kind: 'loco' }] };
    case 'loco_sleeper':
      return { gap: 2, cars: [...emu(4, 46, 'flat', 'sleeper'), { len: 30, left: 'flat', right: 'cab', kind: 'loco' }] };
    case 'railcar':
      return { gap: 0, cars: [{ len: 52, left: 'cab', right: 'cab', kind: 'emu' }] };
    case 'steam':
      return {
        gap: 2,
        cars: [
          { len: 34, left: 'flat', right: 'flat', kind: 'wood' },
          { len: 34, left: 'flat', right: 'flat', kind: 'wood' },
          { len: 16, left: 'flat', right: 'flat', kind: 'tender' },
          { len: 34, left: 'flat', right: 'flat', kind: 'steam' },
        ],
      };
    default:
      return { gap: 1, cars: emu(3, 44, 'round') };
  }
}

/** Outline of one car with its nose shapes. */
function outline(x: number, len: number, left: Nose, right: Nose, top = TOP): string {
  const b = BOTTOM;
  const r = x + len;
  const mid = top + (b - top) * 0.55;
  const rightEnd: Record<Nose, string> = {
    flat: `L${r - 1.5},${top} Q${r},${top} ${r},${top + 1.5} L${r},${b}`,
    round: `L${r - 12},${top} Q${r},${top} ${r},${mid} L${r},${b}`,
    sloped: `L${r - 16},${top} L${r},${mid + 2} L${r},${b}`,
    pointy: `L${r - 22},${top} Q${r - 4},${top + 4} ${r},${b - 5} L${r},${b}`,
    blunt: `L${r - 10},${top} L${r},${mid} L${r},${b}`,
    cab: `L${r - 6},${top} Q${r - 1},${top} ${r},${top + 6} L${r},${b}`,
  };
  const leftEnd: Record<Nose, string> = {
    flat: `L${x},${top + 1.5} Q${x},${top} ${x + 1.5},${top}`,
    round: `L${x},${mid} Q${x},${top} ${x + 12},${top}`,
    sloped: `L${x},${mid + 2} L${x + 16},${top}`,
    pointy: `L${x},${b - 5} Q${x + 4},${top + 4} ${x + 22},${top}`,
    blunt: `L${x},${mid} L${x + 10},${top}`,
    cab: `L${x},${top + 6} Q${x + 1},${top} ${x + 6},${top}`,
  };
  return `M${x},${b} ${leftEnd[left]} ${rightEnd[right]} Z`;
}

function windows(c: Car, x: number, glass: string) {
  const out: ReactElement[] = [];
  const inset = (n: Nose) => (n === 'round' ? 13 : n === 'sloped' ? 17 : n === 'pointy' ? 22 : n === 'blunt' ? 9 : n === 'cab' ? 6 : 3);
  const from = x + inset(c.left);
  const to = x + c.len - inset(c.right);
  const row = (y: number, h: number, w: number, step: number, key: string) => {
    for (let wx = from + 1; wx + w <= to - 1; wx += step) out.push(<rect key={`${key}${wx}`} x={wx} y={y} width={w} height={h} rx={0.8} fill={glass} />);
  };
  if (c.kind === 'emu' || c.kind === 'coach') row(12, 6, 4.2, 5.6, 'w');
  if (c.kind === 'double') {
    row(10, 5, 4, 5.4, 'u');
    row(19, 5, 4, 5.4, 'l');
  }
  if (c.kind === 'sleeper') row(12, 4, 2.6, 6.5, 's');
  if (c.kind === 'wood') row(13, 6, 4, 7, 'd');
  // Cab windscreens: a dark band at the nose, clipped to the car outline so it follows the nose shape.
  const depth: Record<Nose, number> = { flat: 0, round: 11, sloped: 15, pointy: 19, blunt: 8, cab: 5 };
  if (c.kind !== 'tender' && c.kind !== 'wood' && c.kind !== 'steam') {
    if (depth[c.left]) out.push(<rect key="cl" x={x - 1} y={TOP + 1.5} width={depth[c.left] + 1} height={8} fill={glass} />);
    if (depth[c.right]) out.push(<rect key="cr" x={x + c.len - depth[c.right]} y={TOP + 1.5} width={depth[c.right] + 1} height={8} fill={glass} />);
  }
  // Doors on passenger cars.
  if (c.kind === 'emu' || c.kind === 'coach' || c.kind === 'double' || c.kind === 'sleeper')
    for (const f of c.len > 40 ? [0.22, 0.78] : [0.5])
      out.push(<rect key={`door${f}`} x={x + c.len * f - 2} y={TOP + 4} width={4} height={BOTTOM - TOP - 6} rx={0.6} fill="rgba(0,0,0,0.16)" />);
  if (c.kind === 'power' || c.kind === 'loco')
    for (let lx = x + 8; lx < x + c.len - 9; lx += 3) out.push(<rect key={`l${lx}`} x={lx} y={12} width={1.2} height={7} fill="rgba(0,0,0,0.18)" />);
  return out;
}

export function TrainArt({
  art,
  color,
  height = 28,
  className = '',
  label,
}: {
  art: string;
  color: string;
  height?: number;
  className?: string;
  label?: string;
}) {
  const id = useId().replace(/:/g, '');
  const { cars, gap } = family(art);
  const width = cars.reduce((n, c) => n + c.len, 0) + gap * (cars.length - 1) + 4;
  let x = 2;
  const steel = `url(#${id}b)`;
  const glass = '#262c35';
  return (
    <svg
      className={`train-art ${className}`}
      viewBox={`0 0 ${width} ${H}`}
      height={height}
      width={(height * width) / H}
      role={label ? 'img' : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    >
      <defs>
        <linearGradient id={`${id}b`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#eef1f5" />
          <stop offset="0.55" stopColor="#c3c9d1" />
          <stop offset="1" stopColor="#8e96a1" />
        </linearGradient>
        <linearGradient id={`${id}w`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#8a5a3c" />
          <stop offset="1" stopColor="#5b3a26" />
        </linearGradient>
      </defs>
      <rect x={0} y={BOTTOM + 4.6} width={width} height={0.8} fill="rgba(255,255,255,0.12)" />
      {cars.map((c, i) => {
        const cx = x;
        x += c.len + gap;
        const top = c.kind === 'double' ? TOP - 4 : c.kind === 'tender' ? TOP + 9 : TOP;
        const fill = c.kind === 'wood' ? `url(#${id}w)` : c.kind === 'steam' || c.kind === 'tender' ? '#2b2f36' : steel;
        return (
          <g key={i}>
            {c.kind === 'steam' ? (
              <>
                <rect x={cx} y={TOP + 2} width={12} height={BOTTOM - TOP - 2} rx={1} fill={fill} />
                <rect x={cx + 2} y={TOP + 5} width={7} height={6} rx={0.8} fill="#e8c46a" opacity={0.85} />
                <rect x={cx + 12} y={TOP + 9} width={c.len - 12} height={BOTTOM - TOP - 11} rx={5} fill={fill} />
                <rect x={cx + c.len - 9} y={TOP} width={4} height={9} rx={0.8} fill={fill} />
                <rect x={cx + 12} y={BOTTOM - 3} width={c.len - 12} height={1.4} fill={color} />
              </>
            ) : (
              <>
                <clipPath id={`${id}c${i}`}>
                  <path d={outline(cx, c.len, c.left, c.right, top)} />
                </clipPath>
                <path d={outline(cx, c.len, c.left, c.right, top)} fill={fill} />
                <g clipPath={`url(#${id}c${i})`}>
                  {c.kind !== 'tender' && c.kind !== 'wood' && <rect x={cx} y={BOTTOM - 5.5} width={c.len} height={2.2} fill={color} />}
                  <rect x={cx} y={BOTTOM - 2.5} width={c.len} height={2.5} fill="rgba(20,24,30,0.45)" />
                  {windows(c, cx, glass)}
                </g>
                {(c.kind === 'power' || c.kind === 'loco' || (c.kind === 'emu' && i === 0)) && (
                  <path d={`M${cx + c.len * 0.4},${top} l3,-3 h6 l3,3`} fill="none" stroke="#5c636d" strokeWidth={0.8} />
                )}
              </>
            )}
            {(c.kind === 'tender' ? [0.3, 0.7] : [0.18, 0.82]).map((f) => (
              <g key={f} fill="#1c2027">
                <circle cx={cx + c.len * f - 2.6} cy={BOTTOM + 2} r={2.2} />
                <circle cx={cx + c.len * f + 2.6} cy={BOTTOM + 2} r={2.2} />
              </g>
            ))}
          </g>
        );
      })}
    </svg>
  );
}
