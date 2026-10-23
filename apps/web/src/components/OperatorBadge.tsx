// Operator badge (DESIGN §4 row anatomy, SPEC §18): the brand's own app icon when it has been downloaded,
// otherwise a rounded square in the brand colour with the short name.
import { useState } from 'react';
import type { Operator } from '../api';
import { apiUrl } from '../apiBase';

/**
 * Operators' logos are their trademarks (App Review 5.2.1): the App Store build turns them off (VITE_OPERATOR_LOGOS=false
 * in .env.ios) and shows the initials badge, until an operator gives permission.
 */
const LOGOS = import.meta.env.VITE_OPERATOR_LOGOS !== 'false';

export function OperatorBadge({ operator, size = 36 }: { operator: Operator | null | undefined; size?: number }) {
  const [broken, setBroken] = useState(false);
  const color = operator?.brandColor ?? '#3a4555';
  const label = operator?.shortName ?? '?';
  const radius = Math.round(size * 0.28);
  if (LOGOS && operator?.logoUrl && !broken)
    return (
      <img
        className="op-badge op-logo"
        src={apiUrl(operator.logoUrl)}
        width={size}
        height={size}
        style={{ borderRadius: radius }}
        alt={operator.name}
        title={operator.name}
        onError={() => setBroken(true)}
      />
    );
  return (
    <span
      className="op-badge"
      style={{ background: color, width: size, height: size, fontSize: size * (label.length > 2 ? 0.3 : 0.36), borderRadius: radius }}
      aria-label={operator?.name ?? 'Unknown operator'}
      title={operator?.name}
    >
      {label}
    </span>
  );
}
