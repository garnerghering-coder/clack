// Split-flap digits (DESIGN §motion): each character sits on its own tile; when it changes, the tile flips
// (280 ms, 40 ms stagger left to right). Only changed characters flip. Reduced motion: no flip.
import { useEffect, useRef } from 'react';

export function SplitFlap({ value, className = '', label }: { value: string; className?: string; label?: string }) {
  const prev = useRef(value);
  const changed = useRef<boolean[]>([]);
  if (prev.current !== value) {
    changed.current = [...value].map((c, i) => prev.current[i] !== c);
  }
  useEffect(() => {
    prev.current = value;
  }, [value]);
  let n = 0;
  return (
    <span className={`flap ${className}`} aria-label={label ?? value} role="text">
      {[...value].map((c, i) => {
        const flip = changed.current[i] ?? false;
        const delay = flip ? n++ * 40 : 0;
        return c === ':' || c === ' ' ? (
          <span key={i} className="flap-sep" aria-hidden="true">
            {c}
          </span>
        ) : (
          <span key={`${i}-${c}`} className={`flap-tile ${flip ? 'flip' : ''}`} style={{ animationDelay: `${delay}ms` }} aria-hidden="true">
            {c}
          </span>
        );
      })}
    </span>
  );
}
