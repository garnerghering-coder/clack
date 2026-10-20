// Operator badge (DESIGN §4 row anatomy, SPEC §18): rounded square in the brand colour with the short name.
// Logos can replace the text later from apps/web/public/operators/ once permissions are sorted.
import type { Operator } from '../api';

export function OperatorBadge({ operator, size = 36 }: { operator: Operator | null | undefined; size?: number }) {
  const color = operator?.brandColor ?? '#3a4555';
  const label = operator?.shortName ?? '?';
  return (
    <span
      className="op-badge"
      style={{ background: color, width: size, height: size, fontSize: size * (label.length > 2 ? 0.3 : 0.36), borderRadius: Math.round(size * 0.28) }}
      aria-label={operator?.name ?? 'Unknown operator'}
      title={operator?.name}
    >
      {label}
    </span>
  );
}
