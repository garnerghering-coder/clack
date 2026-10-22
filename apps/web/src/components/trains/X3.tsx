// Arlanda Express X3 (Alstom Coradia, 4 cars), side view: the cab car and part of the next, facing right.
// Drawn from a photo of an X3 at Stockholm C (Wikimedia Commons, "X3 Stockholm Central.jpg"): silver body, the
// yellow nose sweeping back over the cab to the first door, black windscreen band, yellow step markers on the doors,
// dark skirt. Pantograph and roof equipment are left off: no source shows which car carries them. No lettering or
// logos. "plain" is the same train unpainted, for an operator whose livery we don't know.
import { useId } from "react";

export function X3Side({
  livery,
  muted = false,
  className,
  label,
}: {
  livery: "arlanda-express" | "plain";
  muted?: boolean;
  className?: string;
  label?: string;
}) {
  const p = useId().replace(/:/g, "");
  const plain = livery === "plain";
  const paint = plain ? `url(#${p}body)` : `url(#${p}yellow)`;
  return (
    <svg
      className={className}
      viewBox="0 54 1000 200"
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    >
      <filter id={`${p}mute`}>
        <feColorMatrix type="saturate" values="0" />
      </filter>
      <g
        opacity={muted ? 0.35 : 1}
        filter={muted ? `url(#${p}mute)` : undefined}
      >
        <defs>
          {/* Silver body: light at the top, cooler towards the floor, as in the photo under station lights. */}
          <linearGradient id={`${p}body`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#f7f8fa" />
            <stop offset="0.55" stopColor="#e3e6ea" />
            <stop offset="1" stopColor="#b9bfc7" />
          </linearGradient>
          <linearGradient id={`${p}yellow`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#f6dc3a" />
            <stop offset="0.6" stopColor="#ecd02c" />
            <stop offset="1" stopColor="#d7b81e" />
          </linearGradient>
          <linearGradient id={`${p}glass`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#0b0e12" />
            <stop offset="0.7" stopColor="#1f262f" />
            <stop offset="1" stopColor="#3a4552" />
          </linearGradient>
          <linearGradient id={`${p}skirt`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#6c737c" />
            <stop offset="1" stopColor="#4a5058" />
          </linearGradient>
          <linearGradient id={`${p}roofsheen`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#ffffff" stopOpacity="0.9" />
            <stop offset="1" stopColor="#ffffff" stopOpacity="0" />
          </linearGradient>
          {/* Cab car outline: flat roof, then the long nose sloping down to the coupler. */}
          <clipPath id={`${p}cab`}>
            <path
              id={`${p}cabpath`}
              d="M372,72 H812 C860,72 900,86 932,112 C962,136 984,160 992,184 C995,194 994,204 988,210 L984,214 H372 Z"
            />
          </clipPath>
          <clipPath id={`${p}mid`}>
            <path d="M-10,72 H352 Q358,72 358,78 V214 H-10 Z" />
          </clipPath>
        </defs>

        {/* ===== Second car (cut off at the left, like SJ's drawings) ===== */}
        <g clipPath={`url(#${p}mid)`}>
          <rect
            x="-10"
            y="72"
            width="370"
            height="142"
            fill={`url(#${p}body)`}
          />
          <rect
            x="-10"
            y="72"
            width="370"
            height="10"
            fill={`url(#${p}roofsheen)`}
            opacity="0.6"
          />
          {/* windows */}
          <rect
            x="18"
            y="106"
            width="78"
            height="44"
            rx="6"
            fill={`url(#${p}glass)`}
            stroke="#5b6672"
            strokeWidth="1.5"
          />
          <rect
            x="104"
            y="106"
            width="78"
            height="44"
            rx="6"
            fill={`url(#${p}glass)`}
            stroke="#5b6672"
            strokeWidth="1.5"
          />
          <rect
            x="190"
            y="106"
            width="78"
            height="44"
            rx="6"
            fill={`url(#${p}glass)`}
            stroke="#5b6672"
            strokeWidth="1.5"
          />
          {/* door near the car end, with the yellow step marker */}
          <rect
            x="296"
            y="88"
            width="40"
            height="118"
            rx="4"
            fill="none"
            stroke="#9aa1aa"
            strokeWidth="2"
          />
          <rect
            x="309"
            y="102"
            width="14"
            height="46"
            rx="4"
            fill={`url(#${p}glass)`}
          />
          {!plain && (
            <rect x="300" y="182" width="32" height="20" rx="2" fill={paint} />
          )}
          <rect x="-10" y="160" width="370" height="2" fill="#c3c8cf" />
          <rect x="-10" y="72" width="370" height="5" fill="#d3d7dc" />
          {/* lower skirt */}
          <rect
            x="-10"
            y="196"
            width="370"
            height="18"
            fill={`url(#${p}skirt)`}
          />
        </g>
        {/* gangway bellows between the cars */}
        <rect x="356" y="84" width="18" height="128" rx="3" fill="#2a2f36" />
        <g stroke="#3d434b" strokeWidth="2">
          <line x1="360" y1="88" x2="360" y2="208" />
          <line x1="365" y1="88" x2="365" y2="208" />
          <line x1="370" y1="88" x2="370" y2="208" />
        </g>

        {/* ===== Cab car ===== */}
        <g clipPath={`url(#${p}cab)`}>
          <rect
            x="360"
            y="60"
            width="650"
            height="160"
            fill={`url(#${p}body)`}
          />
          <rect
            x="372"
            y="72"
            width="460"
            height="10"
            fill={`url(#${p}roofsheen)`}
            opacity="0.6"
          />
          {/* belt line under the windows and the roof edge */}
          <rect x="360" y="160" width="620" height="2" fill="#c3c8cf" />
          <rect x="360" y="72" width="460" height="5" fill="#d3d7dc" />
          {/* yellow nose: covers the front and sweeps back over the cab roof to the cab door, then down and forward to
         the front bogie (photo: X3 at Stockholm C) */}
          <path
            d="M690,60 C720,60 748,66 770,80 C820,112 870,160 908,214 H1010 V60 Z"
            fill={paint}
          />
          <path
            d="M690,60 C720,60 748,66 770,80 C820,112 870,160 908,214"
            fill="none"
            stroke={plain ? "#c3c8cf" : "#b99d14"}
            strokeWidth="1.6"
            opacity="0.55"
          />
          {/* windscreen and the black cap above it: one dark area over the front of the cab */}
          <path
            d="M846,74 C884,78 912,92 936,114 C956,132 970,150 978,168 C960,165 944,160 930,152 C910,136 886,121 856,110 C850,98 848,86 846,74 Z"
            fill={`url(#${p}glass)`}
          />
          <path
            d="M864,98 C890,106 912,120 930,136"
            fill="none"
            stroke="#ffffff"
            strokeOpacity="0.18"
            strokeWidth="3"
            strokeLinecap="round"
          />
          {/* passenger windows */}
          <rect
            x="452"
            y="106"
            width="78"
            height="44"
            rx="6"
            fill={`url(#${p}glass)`}
            stroke="#5b6672"
            strokeWidth="1.5"
          />
          <rect
            x="538"
            y="106"
            width="78"
            height="44"
            rx="6"
            fill={`url(#${p}glass)`}
            stroke="#5b6672"
            strokeWidth="1.5"
          />
          <rect
            x="624"
            y="106"
            width="64"
            height="44"
            rx="6"
            fill={`url(#${p}glass)`}
            stroke="#5b6672"
            strokeWidth="1.5"
          />
          {/* doors: one at the car's inner end (yellow step marker), one just behind the cab */}
          <rect
            x="400"
            y="88"
            width="40"
            height="118"
            rx="4"
            fill="none"
            stroke="#9aa1aa"
            strokeWidth="2"
          />
          <rect
            x="413"
            y="102"
            width="14"
            height="46"
            rx="4"
            fill={`url(#${p}glass)`}
          />
          {!plain && (
            <rect x="404" y="182" width="32" height="20" rx="2" fill={paint} />
          )}
          <rect
            x="712"
            y="84"
            width="40"
            height="122"
            rx="4"
            fill="none"
            stroke="#9aa1aa"
            strokeWidth="2"
          />
          <rect
            x="725"
            y="98"
            width="14"
            height="50"
            rx="4"
            fill={`url(#${p}glass)`}
          />
          {/* headlight */}
          <ellipse
            cx="968"
            cy="182"
            rx="10"
            ry="5"
            fill="#fbfcfd"
            stroke={plain ? "#9aa1aa" : "#8a7a1a"}
            strokeWidth="1"
          />
          {/* lower skirt, and the white chevrons on it */}
          <rect
            x="360"
            y="196"
            width="650"
            height="18"
            fill={`url(#${p}skirt)`}
          />
          <g fill="#e8ebee" opacity="0.85">
            <path d="M560,198 l8,0 l-8,14 l-8,0 z" />
            <path d="M572,198 l8,0 l-8,14 l-8,0 z" />
            <path d="M584,198 l8,0 l-8,14 l-8,0 z" />
          </g>
        </g>
        {/* nose fairing below the coupler line */}
        <path
          d="M900,214 H984 C990,214 992,220 986,226 L960,232 H900 Z"
          fill="#3a4048"
        />

        {/* ===== Bogies and wheels ===== */}
        <g>
          {/* second car: one bogie visible */}
          <rect
            x="200"
            y="208"
            width="120"
            height="20"
            rx="5"
            fill="#22272e"
            stroke="#3b424b"
            strokeWidth="1.5"
          />
          {/* cab car */}
          <rect
            x="440"
            y="208"
            width="120"
            height="20"
            rx="5"
            fill="#22272e"
            stroke="#3b424b"
            strokeWidth="1.5"
          />
          <rect
            x="800"
            y="208"
            width="120"
            height="20"
            rx="5"
            fill="#22272e"
            stroke="#3b424b"
            strokeWidth="1.5"
          />
          <g fill="#1a1e24" stroke="#4a525c" strokeWidth="2">
            <circle cx="228" cy="230" r="18" />
            <circle cx="292" cy="230" r="18" />
            <circle cx="468" cy="230" r="18" />
            <circle cx="532" cy="230" r="18" />
            <circle cx="828" cy="230" r="18" />
            <circle cx="892" cy="230" r="18" />
          </g>
          <g fill="#6b747f">
            <circle cx="228" cy="230" r="6" />
            <circle cx="292" cy="230" r="6" />
            <circle cx="468" cy="230" r="6" />
            <circle cx="532" cy="230" r="6" />
            <circle cx="828" cy="230" r="6" />
            <circle cx="892" cy="230" r="6" />
          </g>
          {/* axlebox / damper detail */}
          <g stroke="#59616b" strokeWidth="3" strokeLinecap="round">
            <line x1="250" y1="216" x2="270" y2="212" />
            <line x1="490" y1="216" x2="510" y2="212" />
            <line x1="850" y1="216" x2="870" y2="212" />
          </g>
        </g>
      </g>
    </svg>
  );
}
