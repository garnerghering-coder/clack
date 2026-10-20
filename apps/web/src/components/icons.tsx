// Line icons in the Flighty style (rounded strokes). All decorative: callers supply aria-labels.
import type { ReactNode } from 'react';

const Icon = ({ children, size = 24 }: { children: ReactNode; size?: number }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    {children}
  </svg>
);

export const TrainIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <rect x="5" y="3" width="14" height="14" rx="4" />
    <path d="M5 11h14M9 21l1.5-4M15 21l-1.5-4" />
    <circle cx="9" cy="14" r="0.6" fill="currentColor" />
    <circle cx="15" cy="14" r="0.6" fill="currentColor" />
  </Icon>
);
export const PassportIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <rect x="5" y="2.5" width="14" height="19" rx="2.5" />
    <circle cx="12" cy="10.5" r="3.5" />
    <path d="M8.5 10.5h7M12 7v7M9 17.5h6" />
  </Icon>
);
export const SearchIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <circle cx="10.5" cy="10.5" r="6.5" />
    <path d="m20 20-4.8-4.8" />
  </Icon>
);
export const ShareIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <path d="M12 3v12M7.5 7.5 12 3l4.5 4.5" />
    <path d="M8 11H6.5A1.5 1.5 0 0 0 5 12.5v7A1.5 1.5 0 0 0 6.5 21h11a1.5 1.5 0 0 0 1.5-1.5v-7a1.5 1.5 0 0 0-1.5-1.5H16" />
  </Icon>
);
export const CloseIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <path d="M6 6l12 12M18 6 6 18" />
  </Icon>
);
export const ChevronRight = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <path d="m9 5 7 7-7 7" />
  </Icon>
);
export const ChevronLeft = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <path d="m15 5-7 7 7 7" />
  </Icon>
);
