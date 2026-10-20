// Distance and station-name helpers shared by the station-mapping scripts.

export function haversine(lat1, lon1, lat2, lon2) {
  const R = 6371008.8, rad = Math.PI / 180;
  const a = Math.sin(((lat2 - lat1) * rad) / 2) ** 2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(((lon2 - lon1) * rad) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/** Accent-insensitive, abbreviation-normalised station name. */
export function normName(s) {
  return s
    .toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/\bcentralstation\b|\bcentral\b|\bcentralen\b/g, 'c')
    .replace(/\bstation\b|\bstn\b|\btagstation\b|\bjarnvagsstation\b/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}
export const tokens = (s) => new Set(normName(s).split(' ').filter(Boolean));
export function nameSim(a, b) {
  const A = tokens(a), B = tokens(b);
  if (normName(a) === normName(b)) return 1;
  let inter = 0;
  for (const t of A) if (B.has(t)) inter++;
  return inter / Math.max(A.size, B.size);
}
