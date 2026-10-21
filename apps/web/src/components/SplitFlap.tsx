// Split-flap characters (DESIGN §10): each character sits on its own tile. When one changes, the top half of the old
// character falls away and the new one's bottom half drops into place (360 ms, 50 ms stagger left to right), as on
// a departure board. Only changed characters flip; `intro` flips every tile in once on first show. Reduced motion:
// no flip.
import { useEffect, useRef } from 'react';

export function SplitFlap({ value, className = '', label, intro = false }: { value: string; className?: string; label?: string; intro?: boolean }) {
  const prev = useRef<string>(intro ? ' '.repeat(value.length) : value);
  const from = useRef<string>(prev.current);
  const seq = useRef(0);
  if (prev.current !== value) {
    from.current = prev.current;
    seq.current++;
  }
  useEffect(() => {
    prev.current = value;
  }, [value]);
  let n = 0;
  return (
    <span className={`flap ${className}`} aria-label={label ?? value} role="text">
      {[...value].map((c, i) => {
        if (c === ':' || c === ' ' || c === '.') {
          return (
            <span key={i} className="flap-sep" aria-hidden="true">
              {c}
            </span>
          );
        }
        const old = from.current[i] ?? ' ';
        const flip = old !== c && seq.current > 0;
        if (!flip)
          return (
            <span key={i} className="flap-tile" aria-hidden="true">
              {c}
            </span>
          );
        const delay = `${n++ * 50}ms`;
        return (
          // A new key per change restarts the animation.
          <span key={`${i}-${seq.current}`} className="flap-tile flipping" aria-hidden="true" style={{ ['--d' as string]: delay }}>
            <span className="flap-half top">{c}</span>
            <span className="flap-half bottom">{old}</span>
            <span className="flap-leaf top">{old}</span>
            <span className="flap-leaf bottom">{c}</span>
            <span className="flap-sizer">{c}</span>
          </span>
        );
      })}
    </span>
  );
}
