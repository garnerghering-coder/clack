import type { ReactElement } from 'react';

// Circular country flags (Flighty shows round flags next to airports). Drawn as SVG so they look the same everywhere.
const flags: Record<string, ReactElement> = {
  SE: (
    <>
      <rect width="32" height="32" fill="#006aa7" />
      <rect x="9" width="5" height="32" fill="#fecc00" />
      <rect y="13.5" width="32" height="5" fill="#fecc00" />
    </>
  ),
  DK: (
    <>
      <rect width="32" height="32" fill="#c8102e" />
      <rect x="9" width="4.5" height="32" fill="#fff" />
      <rect y="13.75" width="32" height="4.5" fill="#fff" />
    </>
  ),
  NO: (
    <>
      <rect width="32" height="32" fill="#ba0c2f" />
      <rect x="8" width="8" height="32" fill="#fff" />
      <rect y="12" width="32" height="8" fill="#fff" />
      <rect x="10" width="4" height="32" fill="#00205b" />
      <rect y="14" width="32" height="4" fill="#00205b" />
    </>
  ),
  DE: (
    <>
      <rect width="32" height="11" fill="#000" />
      <rect y="10.67" width="32" height="11" fill="#dd0000" />
      <rect y="21.33" width="32" height="11" fill="#ffce00" />
    </>
  ),
  AT: (
    <>
      <rect width="32" height="32" fill="#ed2939" />
      <rect y="10.67" width="32" height="10.67" fill="#fff" />
    </>
  ),
};

/** `decorative` hides it from screen readers when the country is already written next to it. */
export function Flag({ country, size = 44, decorative = false }: { country: string; size?: number; decorative?: boolean }) {
  return (
    <svg className="flag" viewBox="0 0 32 32" width={size} height={size} {...(decorative ? { 'aria-hidden': true } : { role: 'img', 'aria-label': country })}>
      <defs>
        <clipPath id={`flag-clip-${country}`}>
          <circle cx="16" cy="16" r="16" />
        </clipPath>
      </defs>
      <g clipPath={`url(#flag-clip-${country})`}>{flags[country] ?? <rect width="32" height="32" fill="#555" />}</g>
    </svg>
  );
}
