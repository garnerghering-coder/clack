// Split-flap characters (DESIGN §10): each character sits on its own tile. When one changes, the top half of the old
// character falls away and the new one's bottom half drops into place (360 ms, 50 ms stagger left to right), as on
// a departure board. Only changed characters flip; `intro` flips every tile in once on first show. Reduced motion:
// no flip.
import { useEffect, useRef } from 'react';
import { fmtTime } from '../format';

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

/**
 * A time, on flip cards for the main time on a screen (the featured trip, a trip's departure and arrival, boards)
 * and as plain text elsewhere (owner feedback 2026-10-21). When the expected time differs from the timetable, the
 * timetabled one is struck through beside it and the new one is drawn in the accent colour.
 */
export function FlapTime({
  time,
  sched,
  tz,
  clock,
  size = 'text',
  intro = false,
}: {
  /** The time to show (expected or actual), ms. */
  time: number | null;
  /** The timetabled time, ms: struck through when it differs by a minute or more. */
  sched?: number | null;
  tz: string;
  clock: '24h' | '12h';
  /** text: plain digits (secondary places); sm/md/lg: flip cards (the main time on a screen). */
  size?: 'text' | 'sm' | 'md' | 'lg';
  intro?: boolean;
}) {
  const fmt = (v: number) => fmtTime(v, tz, clock);
  if (time === null) return <span className="flap-missing">—</span>;
  const changed = sched !== null && sched !== undefined && Math.floor(sched / 60_000) !== Math.floor(time / 60_000);
  if (size === 'text')
    return (
      <span className={`flap-text tabular${changed ? ' changed' : ''}`}>
        {changed && <s className="flap-old">{fmt(sched!)}</s>}
        <span className="flap-new">{fmt(time)}</span>
      </span>
    );
  return (
    <span className={`flap-time flap-${size}${changed ? ' changed' : ''}`}>
      {changed && <s className="flap-old">{fmt(sched!)}</s>}
      <SplitFlap value={fmt(time)} intro={intro} label={changed ? `${fmt(time)} (${fmt(sched!)})` : fmt(time)} />
    </span>
  );
}
