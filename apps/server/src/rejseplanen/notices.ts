// Rejseplanen's service messages (HIM), sorted into what concerns the train and what concerns a station. Read from
// real messages on 2026-10-28 (DENMARK_DATA_FINDINGS.md): a heading ("Elevatoren på Horsens er ude af drift"), a body
// in HTML with links, and at its end the place it concerns in brackets: one station ("(Horsens St.)") or a stretch
// ("(Fredericia St. - CPH Lufthavn)"). Most are station facilities (lifts, walkways, halls), which say nothing about
// the train; the app shows those on a saved trip for its own stations only.
import { normName } from '../lib/geo.js';
import type { DelayCause } from '@clack/shared';

export interface Notice {
  /** The heading, without Rejseplanen's "Serviceinfo:" prefix: the short line the app shows. */
  head: string;
  /** The body as plain text (no HTML or links), without the place in brackets. */
  body: string;
  /** The place it concerns: one station, or the two ends of a stretch; empty when the message doesn't say. */
  where: string[];
  /** About a station's lifts, escalators, walkways, halls or toilets, not about the train. */
  facility: boolean;
}

/**
 * Words that make a message a station-facility notice (Danish, as in DSB's own messages; meanings from Den Danske
 * Ordbog, ordnet.dk): elevator (lift), rulletrappe (escalator), gangbro (footbridge), gangtunnel (pedestrian tunnel),
 * stationshal (station hall), toilet, billetautomat (ticket machine), trappe (stairs), perronadgang (platform access),
 * forplads (station forecourt), handicapservice.
 */
const FACILITY = /\b(elevator\w*|rulletrappe\w*|gangbro\w*|gangtunnel\w*|stationshal\w*|toilet\w*|billetautomat\w*|trappe\w*|perronadgang|forplads\w*|handicapservice)\b/i;

/** Plain text from Rejseplanen's HTML: links and tags dropped, entities and spacing tidied. Pure. */
export function plainText(html: string): string {
  return html
    .replace(/<a\b[^>]*>.*?<\/a>/gis, '')
    .replace(/<br\s*\/?>/gi, ' ')
    .replace(/<[^>]+>/g, '')
    .replace(/\{\{[^}:]*:?/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

/** One message as Rejseplanen sends it (heading, body) → a notice. Pure. */
export function parseNotice(head: string | undefined, text: string | undefined): Notice | null {
  const h = plainText(head ?? '').replace(/^serviceinfo:\s*/i, '');
  let body = plainText(text ?? '');
  let where: string[] = [];
  const place = /\(([^()]+)\)\s*$/.exec(body);
  if (place) {
    where = place[1]!.split(/\s+-\s+/).map((s) => s.trim()).filter(Boolean);
    body = body.slice(0, place.index).trim();
  }
  if (!h && !body) return null;
  return { head: h || body, body, where, facility: FACILITY.test(h) || (!h && FACILITY.test(body)) };
}

/** A stop name as the notices write it ("Horsens St.", "CPH Lufthavn") and ours ("Horsens", "CPH Airport"). */
const placeKey = (s: string) => normName(s.replace(/\s+st\.?$/i, '')).replace(/ lufthavn$/, ' airport');

/**
 * The notices for each stop of a train, in stop order. A train notice goes on the stops of the stretch it names
 * (or all of them when it names none); a facility notice only on the station it names, marked `facility` so the app
 * keeps it off the train's stop list. Pure.
 */
export function noticesByStop(notices: Notice[], stopNames: (string | null)[]): DelayCause[][] {
  const keys = stopNames.map((n) => (n ? placeKey(n) : ''));
  const out: DelayCause[][] = stopNames.map(() => []);
  for (const n of notices) {
    const cause = (facility: boolean): DelayCause => ({ src: 'rejseplanen', text: n.head, body: n.body || undefined, lang: 'da', ...(facility ? { facility: true } : {}) });
    const at = n.where.map((w) => keys.indexOf(placeKey(w)));
    if (n.facility) {
      // A station the train doesn't call at: nothing for this train.
      for (const i of at) if (i >= 0) out[i]!.push(cause(true));
      continue;
    }
    let [from, to] = [0, keys.length - 1];
    if (at.length === 1 && at[0]! >= 0) from = to = at[0]!;
    if (at.length === 2 && at[0]! >= 0 && at[1]! >= 0) [from, to] = [Math.min(at[0]!, at[1]!), Math.max(at[0]!, at[1]!)];
    for (let i = from; i <= to; i++) out[i]!.push(cause(false));
  }
  return out;
}

/** The train notices that concern a station at all (a board row): facilities are the station's own, not the train's. */
export const serviceCauses = (notices: Notice[]): DelayCause[] =>
  notices.filter((n) => !n.facility).map((n) => ({ src: 'rejseplanen', text: n.head, body: n.body || undefined, lang: 'da' }));
