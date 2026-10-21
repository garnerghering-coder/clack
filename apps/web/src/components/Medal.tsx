// Milestone medals (owner feedback: "like Apple Health or Duolingo"): a ribbon, a metal rim whose metal steps up
// with each level of a milestone family (bronze, silver, gold, platinum), a coloured face per family and the target
// or an icon in the middle. Upcoming ones are greyed out, with a ring showing how far along you are.
import { useId } from 'react';
import { Flag, Globe2, MapPin, Moon, Route, Ticket, TrainFront, type LucideIcon } from 'lucide-react';
import type { Milestone } from '../api';

type Family = Milestone['family'];
const FACE: Record<Family, [string, string]> = {
  journeys: ['#ffe27a', '#d9a400'],
  distanceKm: ['#7db7ff', '#2563d9'],
  stations: ['#7ef0b0', '#1f9e5c'],
  operators: ['#ffb08a', '#e0582a'],
  countries: ['#cfa8ff', '#7d3fd6'],
  borderCrossings: ['#ff8fa3', '#d12a4a'],
  nightTrains: ['#9aa6ff', '#3242b8'],
};
const ICON: Record<Family, LucideIcon> = { journeys: TrainFront, distanceKm: Route, stations: MapPin, operators: Ticket, countries: Globe2, borderCrossings: Flag, nightTrains: Moon };
const METALS = [
  ['#f0b27a', '#9c5a25'], // bronze
  ['#f4f4f4', '#8e8e8e'], // silver
  ['#ffe9a0', '#c48a1c'], // gold
  ['#e9f7ff', '#7fa7c2'], // platinum
] as const;
/** The thresholds per family, to know which level a target is (mirrors MILESTONES on the server). */
const LEVELS: Record<Family, number[]> = {
  journeys: [1, 10, 25, 50, 100, 250],
  distanceKm: [100, 500, 1000, 2500, 5000, 10_000, 40_075],
  stations: [10, 25, 50, 100, 200],
  operators: [3, 5, 10],
  countries: [2, 3, 5],
  borderCrossings: [1],
  nightTrains: [1],
};

function metalFor(m: Milestone) {
  const levels = LEVELS[m.family];
  if (levels.length === 1) return METALS[2]!;
  const i = Math.max(0, levels.indexOf(m.target));
  return METALS[Math.min(METALS.length - 1, Math.floor((i * METALS.length) / levels.length))]!;
}

/** "1k", "2.5k", "10k"; the first ones and once-around-the-Earth get an icon instead of a number. */
function centre(m: Milestone): string | null {
  if (m.target === 1 || m.target >= 40_000) return null;
  if (m.target >= 1000) return `${(m.target / 1000).toLocaleString('en', { maximumFractionDigits: 1 })}k`;
  return String(m.target);
}

export function Medal({ m, locked = false, size = 92 }: { m: Milestone; locked?: boolean; size?: number }) {
  const id = useId().replace(/:/g, '');
  const [f0, f1] = FACE[m.family];
  const [m0, m1] = metalFor(m);
  const Icon = m.target >= 40_000 ? Globe2 : ICON[m.family];
  const text = centre(m);
  const progress = locked && m.value !== undefined ? Math.min(1, m.value / m.target) : null;
  const ring = 2 * Math.PI * 49;
  return (
    <svg className={locked ? 'medal locked' : 'medal'} width={size} height={size * 1.25} viewBox="0 0 120 150" aria-hidden="true">
      <defs>
        <linearGradient id={`rim${id}`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={m0} />
          <stop offset="0.55" stopColor={m1} />
          <stop offset="1" stopColor={m0} />
        </linearGradient>
        <radialGradient id={`face${id}`} cx="0.35" cy="0.3" r="0.9">
          <stop offset="0" stopColor={f0} />
          <stop offset="1" stopColor={f1} />
        </radialGradient>
      </defs>
      {/* Ribbon */}
      <polygon points="30,0 54,0 70,62 48,66" fill={f1} />
      <polygon points="90,0 66,0 50,62 72,66" fill={f0} />
      <polygon points="54,0 66,0 60,24" fill="rgba(0,0,0,0.18)" />
      {/* Progress ring for an upcoming medal */}
      {progress !== null && (
        <>
          <circle cx="60" cy="96" r="49" fill="none" stroke="var(--hairline)" strokeWidth="5" />
          <circle cx="60" cy="96" r="49" fill="none" stroke="var(--accent)" strokeWidth="5" strokeLinecap="round" strokeDasharray={`${ring * progress} ${ring}`} transform="rotate(-90 60 96)" />
        </>
      )}
      <g className="medal-body">
        <circle cx="60" cy="96" r="43" fill={`url(#rim${id})`} />
        <circle cx="60" cy="96" r="34" fill={`url(#face${id})`} />
        <circle cx="60" cy="96" r="34" fill="none" stroke="rgba(255,255,255,0.35)" strokeWidth="1.5" />
        <circle cx="60" cy="96" r="38.5" fill="none" stroke="rgba(0,0,0,0.18)" strokeWidth="1" />
        {text ? (
          <>
            <text x="60" y={text.length > 3 ? 113 : 115} textAnchor="middle" className="medal-number" fontSize={text.length > 3 ? 21 : 26}>
              {text}
            </text>
            <Icon x={53} y={68} width={14} height={14} strokeWidth={2.4} color="rgba(0,0,0,0.55)" />
          </>
        ) : (
          <Icon x={42} y={78} width={36} height={36} strokeWidth={2.2} color="rgba(0,0,0,0.62)" />
        )}
        {/* Shine */}
        <ellipse cx="46" cy="74" rx="18" ry="9" fill="rgba(255,255,255,0.28)" transform="rotate(-30 46 74)" />
      </g>
    </svg>
  );
}
