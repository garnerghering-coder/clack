// Smart search input parsing (SPEC §9 step 2). Plain rules, no AI. Station texts are only split here;
// resolving them to stations happens in the caller (needs the station index).
import { normName } from '../lib/geo.js';

export interface OperatorAlias {
  id: string;
  aliases: string[];
}

export interface ParsedQuery {
  operatorId?: string;
  /** The operator words as typed, for the interpretation chip. */
  operatorText?: string;
  trainNumber?: string;
  /** Text before a route separator, or the only station text. */
  fromText?: string;
  /** Text after a route separator (may be '' when the user has just typed "Stockholm C →"). */
  toText?: string;
  /** A route separator was typed. */
  hasSeparator: boolean;
  /** Two-or-more words with no separator ("Stockholm Malmö"): the caller may try to split them into two stations. */
  splittable: boolean;
}

// "→", "->", ">", "–", "—", " - ", " to ", " till " (Swedish).
const SEPARATOR = /\s*(?:→|->|=>|>|–|—|\s-\s|\bto\b|\btill\b)\s*/i;

export function buildOperatorMatcher(operators: OperatorAlias[]) {
  const byAlias = new Map<string, string>();
  for (const op of operators) for (const a of [op.id, ...op.aliases]) byAlias.set(normName(a), op.id);
  const maxWords = Math.max(1, ...[...byAlias.keys()].map((k) => k.split(' ').length));
  /** Longest operator alias at the start of `words`: [operatorId, words used]. */
  return (words: string[]): [string, number] | null => {
    for (let n = Math.min(maxWords, words.length); n >= 1; n--) {
      const id = byAlias.get(normName(words.slice(0, n).join(' ')));
      if (id) return [id, n];
    }
    return null;
  };
}

export function parseQuery(input: string, matchOperator: ReturnType<typeof buildOperatorMatcher>): ParsedQuery {
  const q: ParsedQuery = { hasSeparator: false, splittable: false };
  let text = input.trim().replace(/\s+/g, ' ');
  if (!text) return q;

  // "sj523", "SJ523" -> "sj 523"
  text = text.replace(/^([a-zA-ZåäöÅÄÖæøÆØ-]+)(\d{1,6})$/u, '$1 $2');

  const sep = text.match(SEPARATOR);
  let left = sep ? text.slice(0, sep.index) : text;
  const right = sep ? text.slice(sep.index! + sep[0].length) : undefined;
  q.hasSeparator = Boolean(sep);

  let words = left.split(' ').filter(Boolean);
  const op = matchOperator(words);
  if (op) {
    q.operatorId = op[0];
    q.operatorText = words.slice(0, op[1]).join(' ');
    words = words.slice(op[1]);
  }
  // A train number: digits only, at the start (after the operator) or the whole remaining text.
  if (!q.hasSeparator && words.length >= 1 && /^\d{1,6}$/.test(words[0]!)) {
    q.trainNumber = words[0];
    words = words.slice(1);
  }
  left = words.join(' ');
  if (left) q.fromText = left;
  if (right !== undefined) q.toText = right.trim();
  q.splittable = !q.hasSeparator && !q.trainNumber && words.length >= 2;
  return q;
}
