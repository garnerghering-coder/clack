// Arlanda Express X3 (Alstom Coradia, 4 cars), side view to scale (1 m = 40 units): the cab car and the front of the
// next, facing right. Generated from the owner's photos of X3s (side-on at speed, and 3/4 at Stockholm C): three doors
// on the cab car (a wide one mid-car), black-framed window groups, a short steep nose, the yellow wedge from the roof
// above the wide door to the foot of the nose, black cap and windscreen, yellow step panels on the doors, stainless
// lower edge. Axles 2.56 m apart, 0.92 m wheels (sv.wikipedia X3). No lettering or logos; pantograph not drawn (no
// source shows which car has it). "plain" is the same train unpainted, for an operator whose livery we don't know.
import { useId } from 'react';

export function X3Side({
  livery,
  muted = false,
  className,
  label,
}: {
  livery: 'arlanda-express' | 'plain';
  muted?: boolean;
  className?: string;
  label?: string;
}) {
  const p = useId().replace(/:/g, '');
  const plain = livery === 'plain';
  return (
    <svg className={className} viewBox="110 22 1088 196" role={label ? 'img' : undefined} aria-label={label} aria-hidden={label ? undefined : true}>
      <filter id={`${p}mute`}>
        <feColorMatrix type="saturate" values="0" />
      </filter>
      <g opacity={muted ? 0.35 : 1} filter={muted ? `url(#${p}mute)` : undefined}>
        <defs>
          <linearGradient id={`${p}body`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#fbfbfc" />
            <stop offset="0.6" stopColor="#eceef1" />
            <stop offset="1" stopColor="#d5d9de" />
          </linearGradient>
          <linearGradient id={`${p}yellow`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#ffe24a" />
            <stop offset="0.6" stopColor="#f6d72f" />
            <stop offset="1" stopColor="#e6c420" />
          </linearGradient>
          <linearGradient id={`${p}glass`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#1b2128" />
            <stop offset="0.65" stopColor="#2b343e" />
            <stop offset="1" stopColor="#4a5562" />
          </linearGradient>
          <linearGradient id={`${p}steel`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#d9dde1" />
            <stop offset="1" stopColor="#a9b0b8" />
          </linearGradient>
          <linearGradient id={`${p}roof`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#c7ccd2" />
            <stop offset="1" stopColor="#e3e6ea" />
          </linearGradient>
        </defs>
        <rect x="738" y="34" width="72" height="7" rx="2" fill="#b9bfc6" />
        <clipPath id={`${p}c2`}>
          <path d="M100.0,40 H170.0 Q174.0,40 174.0,44 V172 H100.0 Z" />
        </clipPath>
        <g clipPath={`url(#${p}c2)`}>
          <rect x="100.0" y="40" width="74.0" height="132" fill={`url(#${p}body)`} />
          <rect x="100.0" y="40" width="74.0" height="5" fill={`url(#${p}roof)`} />
          <rect x="-6.0" y="83.6" width="166.0" height="37.0" rx="3" fill="#0b0d10" />
          <rect x="-2.5" y="86.1" width="51.0" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="51.5" y="86.1" width="51.0" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="105.5" y="86.1" width="51.0" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="-50.0" y="54.5" width="38.0" height="103.0" rx="3" fill="none" stroke="#8d949c" strokeWidth="1.6" />
          <rect x="-41.6" y="82.2" width="21.3" height="51.5" rx="4" fill={`url(#${p}glass)`} stroke="#0b0d10" strokeWidth="2" />
          {!plain && <rect x="-48.5" y="143.0" width="35.0" height="13.9" fill={`url(#${p}yellow)`} />}
          <rect x="100.0" y="162.8" width="74.0" height="9.2" fill={`url(#${p}steel)`} />
        </g>
        <rect x="174.0" y="48" width="16" height="118" fill="#2b3037" />
        <line x1="178.0" y1="50" x2="178.0" y2="164" stroke="#41474f" strokeWidth="1.5" />
        <line x1="182.0" y1="50" x2="182.0" y2="164" stroke="#41474f" strokeWidth="1.5" />
        <line x1="186.0" y1="50" x2="186.0" y2="164" stroke="#41474f" strokeWidth="1.5" />
        <clipPath id={`${p}c1`}>
          <path d="M190.0,172 V44 Q190.0,40 194.0,40 H1082.0 Q1092.0,40 1100.0,46 C1120.0,55.8 1162.0,99.4 1184.0,143.0 Q1190,156.2 1190,165.4 L1188,172 Z" />
        </clipPath>
        <g clipPath={`url(#${p}c1)`}>
          <rect x="190.0" y="36" width="1010.0" height="140" fill={`url(#${p}body)`} />
          <rect x="190.0" y="40" width="902.0" height="5" fill={`url(#${p}roof)`} />
          {!plain && <path d="M844.0,36 L844.0,45.2 L1008.0,60.5 L1156.0,172 L1200,172 V36 Z" fill={`url(#${p}yellow)`} />}
          <path d="M1018.0,36 H1200 V102.0 C1168.0,92.8 1140.0,69.0 1116.0,51.9 C1098.0,44.0 1062.0,43 1018.0,42 Z" fill="#14181e" />
          <path
            d="M1118.0,57.2 C1138.0,69.0 1158.0,83.6 1176.0,92.8"
            fill="none"
            stroke="#ffffff"
            strokeOpacity="0.18"
            strokeWidth="2.2"
            strokeLinecap="round"
          />
          <path d="M1156.0,103.4 V172" stroke="#000" strokeOpacity={0.13} strokeWidth="1.2" />
          <ellipse cx="1178.8" cy="127.1" rx="5" ry="3" fill="#f7f9fb" stroke="#4b4f55" strokeWidth="1" />
          <rect x="208.0" y="83.6" width="164.0" height="37.0" rx="3" fill="#0b0d10" />
          <rect x="211.5" y="86.1" width="50.3" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="264.8" y="86.1" width="50.3" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="318.2" y="86.1" width="50.3" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="380.0" y="54.5" width="38.0" height="103.0" rx="3" fill="none" stroke="#8d949c" strokeWidth="1.6" />
          <rect x="388.4" y="82.2" width="21.3" height="51.5" rx="4" fill={`url(#${p}glass)`} stroke="#0b0d10" strokeWidth="2" />
          {!plain && <rect x="381.5" y="143.0" width="35.0" height="13.9" fill={`url(#${p}yellow)`} />}
          <rect x="430.0" y="83.6" width="354.0" height="37.0" rx="3" fill="#0b0d10" />
          <rect x="433.5" y="86.1" width="67.0" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="503.5" y="86.1" width="67.0" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="573.5" y="86.1" width="67.0" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="643.5" y="86.1" width="67.0" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="713.5" y="86.1" width="67.0" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="796.0" y="54.5" width="57.199999999999996" height="103.0" rx="3" fill="none" stroke="#8d949c" strokeWidth="1.6" />
          <rect x="815.2" y="82.2" width="28.0" height="51.5" rx="4" fill={`url(#${p}glass)`} stroke="#0b0d10" strokeWidth="2" />
          {!plain && <rect x="797.5" y="143.0" width="54.199999999999996" height="13.9" fill={`url(#${p}yellow)`} />}
          <rect x="866.0" y="83.6" width="144.0" height="37.0" rx="3" fill="#0b0d10" />
          <rect x="869.5" y="86.1" width="43.7" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="916.2" y="86.1" width="43.7" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="962.8" y="86.1" width="43.7" height="32.0" rx="2" fill={`url(#${p}glass)`} />
          <rect x="1026.0" y="54.5" width="38.0" height="103.0" rx="3" fill="none" stroke="#8d949c" strokeWidth="1.6" />
          <rect x="1034.4" y="82.2" width="21.3" height="51.5" rx="4" fill={`url(#${p}glass)`} stroke="#0b0d10" strokeWidth="2" />
          <rect x="190.0" y="162.8" width="898.0" height="9.2" fill={`url(#${p}steel)`} />
        </g>
        <rect x="230.0" y="172" width="800.0" height="6" fill="#4b5158" />
        <rect x="100.0" y="172" width="34.0" height="6" fill="#4b5158" />
        <rect x="976.8" y="172" width="130.4" height="11" rx="3" fill="#2a2f36" stroke="#3f464f" strokeWidth="1.2" />
        <circle cx="990.8" cy="185" r="18.4" fill="#1b1f25" stroke="#4d5560" strokeWidth="2" />
        <circle cx="990.8" cy="185" r="5" fill="#6d7681" />
        <circle cx="1093.2" cy="185" r="18.4" fill="#1b1f25" stroke="#4d5560" strokeWidth="2" />
        <circle cx="1093.2" cy="185" r="5" fill="#6d7681" />
        <line x1="1030.0" y1="178" x2="1054.0" y2="175" stroke="#6d7681" strokeWidth="2.4" strokeLinecap="round" />
        <rect x="228.8" y="172" width="130.4" height="11" rx="3" fill="#2a2f36" stroke="#3f464f" strokeWidth="1.2" />
        <circle cx="242.8" cy="185" r="18.4" fill="#1b1f25" stroke="#4d5560" strokeWidth="2" />
        <circle cx="242.8" cy="185" r="5" fill="#6d7681" />
        <circle cx="345.2" cy="185" r="18.4" fill="#1b1f25" stroke="#4d5560" strokeWidth="2" />
        <circle cx="345.2" cy="185" r="5" fill="#6d7681" />
        <line x1="282.0" y1="178" x2="306.0" y2="175" stroke="#6d7681" strokeWidth="2.4" strokeLinecap="round" />
        <rect x="4.8" y="172" width="130.4" height="11" rx="3" fill="#2a2f36" stroke="#3f464f" strokeWidth="1.2" />
        <circle cx="18.8" cy="185" r="18.4" fill="#1b1f25" stroke="#4d5560" strokeWidth="2" />
        <circle cx="18.8" cy="185" r="5" fill="#6d7681" />
        <circle cx="121.2" cy="185" r="18.4" fill="#1b1f25" stroke="#4d5560" strokeWidth="2" />
        <circle cx="121.2" cy="185" r="5" fill="#6d7681" />
        <line x1="58.0" y1="178" x2="82.0" y2="175" stroke="#6d7681" strokeWidth="2.4" strokeLinecap="round" />
        <path d="M1098.0,172 H1184 Q1188,172 1184,180 L1166.0,184 H1098.0 Z" fill="#3b4148" />
      </g>
    </svg>
  );
}
