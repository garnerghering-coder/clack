// Distance and station-name helpers (ported from the Phase 0 scripts).

export function haversineM(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371008.8;
  const rad = Math.PI / 180;
  const a = Math.sin(((lat2 - lat1) * rad) / 2) ** 2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(((lon2 - lon1) * rad) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/** Lower-case, accent-free, with Swedish station words normalised ("Göteborg Centralstation" -> "goteborg c"). */
export function normName(s: string): string {
  return s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/ø/g, 'o')
    .replace(/æ/g, 'ae')
    .replace(/\bcentralstation\b|\bcentral\b|\bcentralen\b/g, 'c')
    .replace(/\bstation\b|\bstn\b|\btagstation\b|\bjarnvagsstation\b|\bstasjon\b|\bresecentrum\b|\bjvg\b/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

export const nameTokens = (s: string): string[] => normName(s).split(' ').filter(Boolean);

/** Share of tokens in common (1 = same normalised name). */
export function nameSimilarity(a: string, b: string): number {
  if (normName(a) === normName(b)) return 1;
  const A = new Set(nameTokens(a));
  const B = new Set(nameTokens(b));
  let shared = 0;
  for (const t of A) if (B.has(t)) shared++;
  return shared / Math.max(A.size, B.size, 1);
}

/** Optimal-string-alignment edit distance, capped: returns max+1 as soon as it can't be <= max. */
export function editDistance(a: string, b: string, max = 2): number {
  if (Math.abs(a.length - b.length) > max) return max + 1;
  const d: number[][] = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array<number>(b.length).fill(0)]);
  for (let j = 0; j <= b.length; j++) d[0]![j] = j;
  for (let i = 1; i <= a.length; i++) {
    let rowMin = Infinity;
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      let v = Math.min(d[i - 1]![j]! + 1, d[i]![j - 1]! + 1, d[i - 1]![j - 1]! + cost);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) v = Math.min(v, d[i - 2]![j - 2]! + 1);
      d[i]![j] = v;
      rowMin = Math.min(rowMin, v);
    }
    if (rowMin > max) return max + 1;
  }
  return d[a.length]![b.length]!;
}
