// Slims Protomaps vector tiles down to what Clack's dark map draws (DESIGN §2.4): land, water, place names,
// borders and motorways. Works on the protobuf directly (no geometry decoding), so it is fast and lossless for
// the parts it keeps. Vector tile spec: https://github.com/mapbox/vector-tile-spec/tree/master/2.1

/** Layer name -> which features to keep (all, or by `kind`). */
export const KEEP_LAYERS: Record<string, true | string[]> = {
  earth: true,
  water: true,
  places: true,
  boundaries: true,
  roads: ['highway'],
};

interface Field {
  num: number;
  wire: number;
  /** Byte range of the whole field (tag included) in the parent. */
  start: number;
  end: number;
  /** Payload range for length-delimited fields; value for varints. */
  dataStart: number;
  dataEnd: number;
  value: number;
}

function varint(buf: Uint8Array, pos: { i: number }): number {
  let v = 0;
  let mul = 1;
  for (;;) {
    const b = buf[pos.i++]!;
    v += (b & 0x7f) * mul;
    if (b < 0x80) return v;
    mul *= 128;
  }
}

function* fields(buf: Uint8Array, from = 0, to = buf.length): Generator<Field> {
  const p = { i: from };
  while (p.i < to) {
    const start = p.i;
    const tag = varint(buf, p);
    const num = Math.floor(tag / 8);
    const wire = tag & 7;
    let dataStart = p.i;
    let dataEnd = p.i;
    let value = 0;
    if (wire === 0) value = varint(buf, p);
    else if (wire === 1) p.i += 8;
    else if (wire === 5) p.i += 4;
    else if (wire === 2) {
      const len = varint(buf, p);
      dataStart = p.i;
      dataEnd = p.i += len;
    } else throw new Error(`unsupported wire type ${wire}`);
    if (wire !== 2) dataEnd = p.i;
    yield { num, wire, start, end: p.i, dataStart, dataEnd, value };
  }
}

function writeVarint(out: number[], v: number) {
  while (v >= 0x80) {
    out.push((v % 128) | 0x80);
    v = Math.floor(v / 128);
  }
  out.push(v);
}

function lengthDelimited(num: number, payload: Uint8Array[]): Uint8Array {
  const len = payload.reduce((n, b) => n + b.length, 0);
  const head: number[] = [];
  writeVarint(head, num * 8 + 2);
  writeVarint(head, len);
  return Buffer.concat([Uint8Array.from(head), ...payload]);
}

const utf8 = new TextDecoder();

function filterLayer(buf: Uint8Array, f: Field, kinds: string[]): Uint8Array | null {
  const keys: string[] = [];
  const values: (string | null)[] = [];
  for (const g of fields(buf, f.dataStart, f.dataEnd)) {
    if (g.num === 3) keys.push(utf8.decode(buf.subarray(g.dataStart, g.dataEnd)));
    if (g.num === 4) {
      let s: string | null = null;
      for (const h of fields(buf, g.dataStart, g.dataEnd)) if (h.num === 1) s = utf8.decode(buf.subarray(h.dataStart, h.dataEnd));
      values.push(s);
    }
  }
  const kindKey = keys.indexOf('kind');
  const wantedValues = new Set(values.flatMap((v, i) => (v !== null && kinds.includes(v) ? [i] : [])));
  const parts: Uint8Array[] = [];
  let kept = 0;
  for (const g of fields(buf, f.dataStart, f.dataEnd)) {
    if (g.num !== 2) {
      parts.push(buf.subarray(g.start, g.end));
      continue;
    }
    let keep = false;
    for (const h of fields(buf, g.dataStart, g.dataEnd)) {
      if (h.num !== 2 || h.wire !== 2) continue;
      const p = { i: h.dataStart };
      while (p.i < h.dataEnd) {
        const k = varint(buf, p);
        const v = varint(buf, p);
        if (k === kindKey && wantedValues.has(v)) keep = true;
      }
    }
    if (keep) {
      parts.push(buf.subarray(g.start, g.end));
      kept++;
    }
  }
  return kept ? lengthDelimited(3, parts) : null;
}

/** Returns the tile with only KEEP_LAYERS (uncompressed MVT in, uncompressed MVT out). */
export function slimTile(buf: Uint8Array, keep = KEEP_LAYERS): Uint8Array {
  const out: Uint8Array[] = [];
  for (const f of fields(buf)) {
    if (f.num !== 3 || f.wire !== 2) continue;
    let name = '';
    for (const g of fields(buf, f.dataStart, f.dataEnd))
      if (g.num === 1) {
        name = utf8.decode(buf.subarray(g.dataStart, g.dataEnd));
        break;
      }
    const rule = keep[name];
    if (!rule) continue;
    if (rule === true) out.push(buf.subarray(f.start, f.end));
    else {
      const layer = filterLayer(buf, f, rule);
      if (layer) out.push(layer);
    }
  }
  return Buffer.concat(out);
}
