// Encoded polylines (Google's format, precision 5 ≈ 1 m). Points are [lat, lon].
export type LatLon = [number, number];

export function encodePolyline(points: readonly LatLon[]): string {
  let out = '';
  let pLat = 0;
  let pLon = 0;
  const enc = (v: number) => {
    let x = v < 0 ? ~(v << 1) : v << 1;
    while (x >= 0x20) {
      out += String.fromCharCode((0x20 | (x & 0x1f)) + 63);
      x >>= 5;
    }
    out += String.fromCharCode(x + 63);
  };
  for (const [lat, lon] of points) {
    const a = Math.round(lat * 1e5);
    const o = Math.round(lon * 1e5);
    enc(a - pLat);
    enc(o - pLon);
    pLat = a;
    pLon = o;
  }
  return out;
}

export function decodePolyline(s: string): LatLon[] {
  const out: LatLon[] = [];
  let i = 0;
  let lat = 0;
  let lon = 0;
  const dec = () => {
    let shift = 0;
    let result = 0;
    let b: number;
    do {
      b = s.charCodeAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return result & 1 ? ~(result >> 1) : result >> 1;
  };
  while (i < s.length) {
    lat += dec();
    lon += dec();
    out.push([lat / 1e5, lon / 1e5]);
  }
  return out;
}
