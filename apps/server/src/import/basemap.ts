// Self-hosted basemap (SPEC §4, DESIGN §2.4): cuts the Nordic region out of Protomaps' free daily planet build
// with HTTP range requests and writes it as a local PMTiles file. Nothing to install, no API key, no cost.
// The same thing `pmtiles extract <url> out.pmtiles --bbox=… --maxzoom=…` does, in plain Node.
//
// PMTiles v3: https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { bytesToHeader, zxyToTileId, type Header } from 'pmtiles';
import { CACHE_DIR } from './downloads.js';
import { slimTile } from './mvtFilter.js';

export const BASEMAP_FILE = path.join(CACHE_DIR, 'basemap/nordics.pmtiles');
const BUILDS_URL = 'https://build-metadata.protomaps.dev/builds.json';
const BUILD_BASE = 'https://build.protomaps.com/';

/** Sweden, Norway, Denmark and Finland, plus northern Germany for the Hamburg/Berlin trains. */
export const NORDIC_BBOX = { minLon: 3.5, minLat: 52.2, maxLon: 32, maxLat: 71.5 };
/** Everything is shown at low zoom so zooming out never hits a blank world. */
const WORLD_MAX_ZOOM = 4;
/** z10: ~470 MB to download once, ~80 MB on disk after slimming. MapLibre over-zooms vector tiles beyond it. */
export const DEFAULT_MAX_ZOOM = 10;

interface Entry {
  tileId: number;
  offset: number;
  length: number;
  runLength: number;
}

const MERGE_GAP = 64 * 1024;
const MAX_CHUNK = 16 * 1024 * 1024;
const CONCURRENCY = 6;

async function range(url: string, offset: number, length: number): Promise<Uint8Array> {
  if (!/^https?:/.test(url)) {
    // A local archive (tests, or re-slimming a file you already have).
    const fd = fs.openSync(url, 'r');
    const buf = Buffer.alloc(length);
    fs.readSync(fd, buf, 0, length, offset);
    fs.closeSync(fd);
    return buf;
  }
  for (let attempt = 1; ; attempt++) {
    try {
      const res = await fetch(url, { headers: { Range: `bytes=${offset}-${offset + length - 1}` }, signal: AbortSignal.timeout(120_000) });
      if (res.status !== 206) throw new Error(`HTTP ${res.status} for a range request`);
      const buf = new Uint8Array(await res.arrayBuffer());
      if (buf.length !== length) throw new Error(`short read (${buf.length} of ${length} bytes)`);
      return buf;
    } catch (e) {
      if (attempt >= 4) throw e;
      await new Promise((r) => setTimeout(r, 1000 * 2 ** attempt));
    }
  }
}

function readVarint(buf: Uint8Array, pos: { i: number }): number {
  let v = 0;
  let shift = 1;
  for (;;) {
    const b = buf[pos.i++]!;
    v += (b & 0x7f) * shift;
    if (b < 0x80) return v;
    shift *= 128;
  }
}

function writeVarint(out: number[], v: number) {
  while (v >= 0x80) {
    out.push((v % 128) | 0x80);
    v = Math.floor(v / 128);
  }
  out.push(v);
}

export function deserializeDirectory(raw: Uint8Array): Entry[] {
  const buf = zlib.gunzipSync(raw);
  const p = { i: 0 };
  const n = readVarint(buf, p);
  const e: Entry[] = Array.from({ length: n }, () => ({ tileId: 0, offset: 0, length: 0, runLength: 0 }));
  let last = 0;
  for (const x of e) x.tileId = last += readVarint(buf, p);
  for (const x of e) x.runLength = readVarint(buf, p);
  for (const x of e) x.length = readVarint(buf, p);
  e.forEach((x, i) => {
    const v = readVarint(buf, p);
    x.offset = v === 0 && i > 0 ? e[i - 1]!.offset + e[i - 1]!.length : v - 1;
  });
  return e;
}

export function serializeDirectory(entries: Entry[]): Buffer {
  const out: number[] = [];
  writeVarint(out, entries.length);
  let last = 0;
  for (const e of entries) {
    writeVarint(out, e.tileId - last);
    last = e.tileId;
  }
  for (const e of entries) writeVarint(out, e.runLength);
  for (const e of entries) writeVarint(out, e.length);
  entries.forEach((e, i) => writeVarint(out, i > 0 && e.offset === entries[i - 1]!.offset + entries[i - 1]!.length ? 0 : e.offset + 1));
  return zlib.gzipSync(Buffer.from(out));
}

const lon2x = (lon: number, z: number) => Math.floor(((lon + 180) / 360) * 2 ** z);
const lat2y = (lat: number, z: number) => {
  const r = (lat * Math.PI) / 180;
  return Math.floor(((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * 2 ** z);
};

/** Sorted tile ids we want: the whole world up to WORLD_MAX_ZOOM, then the bbox. */
export function wantedTileIds(bbox: typeof NORDIC_BBOX, maxZoom: number): Float64Array {
  const ids: number[] = [];
  for (let z = 0; z <= maxZoom; z++) {
    const n = 2 ** z;
    const [x0, x1, y0, y1] =
      z <= WORLD_MAX_ZOOM ? [0, n - 1, 0, n - 1] : [lon2x(bbox.minLon, z), lon2x(bbox.maxLon, z), lat2y(bbox.maxLat, z), lat2y(bbox.minLat, z)];
    for (let x = x0; x <= x1; x++) for (let y = y0; y <= y1; y++) ids.push(zxyToTileId(z, x, y));
  }
  return Float64Array.from(ids).sort();
}

/** Index of the first id >= v. */
function lowerBound(a: Float64Array, v: number): number {
  let lo = 0;
  let hi = a.length;
  while (lo < hi) {
    const m = (lo + hi) >> 1;
    if (a[m]! < v) lo = m + 1;
    else hi = m;
  }
  return lo;
}

export async function latestBuildUrl(): Promise<string> {
  const res = await fetch(BUILDS_URL, { signal: AbortSignal.timeout(30_000) });
  if (!res.ok) throw new Error(`Protomaps builds list: HTTP ${res.status}`);
  const builds = (await res.json()) as { key: string }[];
  const key = builds.map((b) => b.key).filter((k) => /^\d{8}\.pmtiles$/.test(k)).sort().at(-1);
  if (!key) throw new Error('No Protomaps build found');
  return BUILD_BASE + key;
}

export interface BasemapOptions {
  url?: string;
  out?: string;
  maxZoom?: number;
  bbox?: typeof NORDIC_BBOX;
  log?: (m: string) => void;
}

export async function extractBasemap(opts: BasemapOptions = {}): Promise<{ file: string; bytes: number; tiles: number; source: string }> {
  const log = opts.log ?? console.log;
  const url = opts.url ?? (await latestBuildUrl());
  const out = opts.out ?? BASEMAP_FILE;
  const maxZoom = opts.maxZoom ?? DEFAULT_MAX_ZOOM;
  const bbox = opts.bbox ?? NORDIC_BBOX;
  log(`Basemap: reading ${url}`);

  const head = await range(url, 0, 16384);
  const header: Header = bytesToHeader(head.buffer as ArrayBuffer, undefined);
  if (header.specVersion !== 3) throw new Error(`Unsupported PMTiles version ${header.specVersion}`);
  if (header.internalCompression !== 2) throw new Error('Expected gzip-compressed directories');
  const wanted = wantedTileIds(bbox, Math.min(maxZoom, header.maxZoom));
  const anyWanted = (from: number, to: number) => {
    const i = lowerBound(wanted, from);
    return i < wanted.length && wanted[i]! < to;
  };

  // Walk the directory tree, keeping tile entries for wanted ids and fetching only the leaves that hold some.
  const tiles: Entry[] = [];
  let leafFetches = 0;
  const walk = async (dir: Entry[]) => {
    const leaves: { e: Entry; to: number }[] = [];
    dir.forEach((e, i) => {
      const to = i + 1 < dir.length ? dir[i + 1]!.tileId : Number.MAX_SAFE_INTEGER;
      if (e.runLength === 0) {
        if (anyWanted(e.tileId, to)) leaves.push({ e, to });
        return;
      }
      // A run covers ids [tileId, tileId + runLength) with identical content (e.g. open sea): keep the wanted ones.
      let i0 = lowerBound(wanted, e.tileId);
      while (i0 < wanted.length && wanted[i0]! < e.tileId + e.runLength) {
        let i1 = i0;
        while (i1 + 1 < wanted.length && wanted[i1 + 1] === wanted[i1]! + 1 && wanted[i1 + 1]! < e.tileId + e.runLength) i1++;
        tiles.push({ tileId: wanted[i0]!, offset: e.offset, length: e.length, runLength: i1 - i0 + 1 });
        i0 = i1 + 1;
      }
    });
    for (let i = 0; i < leaves.length; i += CONCURRENCY) {
      const batch = leaves.slice(i, i + CONCURRENCY);
      const dirs = await Promise.all(batch.map(({ e }) => range(url, header.leafDirectoryOffset + e.offset, e.length)));
      leafFetches += batch.length;
      for (const d of dirs) await walk(deserializeDirectory(d));
    }
  };
  await walk(deserializeDirectory(head.subarray(header.rootDirectoryOffset, header.rootDirectoryOffset + header.rootDirectoryLength)));
  tiles.sort((a, b) => a.tileId - b.tileId);
  log(`Basemap: ${tiles.length} tile entries from ${leafFetches} directory reads`);

  // Unique tile contents in source order, fetched in merged ranges and appended to the new file's data section.
  const contents = [...new Map(tiles.map((t) => [t.offset, t.length])).entries()].sort((a, b) => a[0] - b[0]);
  const chunks: { start: number; end: number; items: [number, number][] }[] = [];
  for (const [off, len] of contents) {
    const c = chunks.at(-1);
    if (c && off - c.end <= MERGE_GAP && off + len - c.start <= MAX_CHUNK) {
      c.end = Math.max(c.end, off + len);
      c.items.push([off, len]);
    } else chunks.push({ start: off, end: off + len, items: [[off, len]] });
  }
  const totalBytes = contents.reduce((n, [, l]) => n + l, 0);
  log(`Basemap: downloading ${(totalBytes / 1e6).toFixed(0)} MB of tiles in ${chunks.length} requests`);

  fs.mkdirSync(path.dirname(out), { recursive: true });
  const tmp = `${out}.part`;
  const dataFile = `${out}.data`;
  const fd = fs.openSync(dataFile, 'w');
  // Source offset -> where the slimmed tile went; identical slimmed tiles (open sea, empty land) are stored once.
  const placed = new Map<number, { offset: number; length: number }>();
  const byHash = new Map<string, { offset: number; length: number }>();
  let written = 0;
  let fetched = 0;
  let lastLog = 0;
  const gz = header.tileCompression === 2;
  try {
    for (let i = 0; i < chunks.length; i += CONCURRENCY) {
      const batch = chunks.slice(i, i + CONCURRENCY);
      const bufs = await Promise.all(batch.map((c) => range(url, header.tileDataOffset + c.start, c.end - c.start)));
      batch.forEach((c, k) => {
        for (const [off, len] of c.items) {
          const raw = bufs[k]!.subarray(off - c.start, off - c.start + len);
          const slim = slimTile(gz ? zlib.gunzipSync(raw) : raw);
          const data = gz ? zlib.gzipSync(slim, { level: 9 }) : Buffer.from(slim);
          const hash = crypto.createHash('sha1').update(data).digest('hex');
          let at = byHash.get(hash);
          if (!at) {
            at = { offset: written, length: data.length };
            fs.writeSync(fd, data);
            written += data.length;
            byHash.set(hash, at);
          }
          placed.set(off, at);
          fetched += len;
        }
      });
      if (fetched - lastLog > 25e6) {
        lastLog = fetched;
        log(`Basemap: ${(fetched / 1e6).toFixed(0)} / ${(totalBytes / 1e6).toFixed(0)} MB`);
      }
    }
  } finally {
    fs.closeSync(fd);
  }

  // Re-sort by new offset isn't needed: entries stay in tile-id order, and the directory format allows any offsets.
  const entries = mergeRuns(tiles.map((t) => ({ ...t, ...placed.get(t.offset)! })));
  const { root, leaves } = buildDirectories(entries);
  const metaRaw = await range(url, header.jsonMetadataOffset, header.jsonMetadataLength);
  const meta = JSON.parse(zlib.gunzipSync(metaRaw).toString('utf8')) as Record<string, unknown>;
  const metadata = zlib.gzipSync(JSON.stringify({ ...meta, clack_source: url, clack_bbox: bbox, clack_extracted: new Date().toISOString() }));

  const HEADER_LEN = 127;
  const rootOff = HEADER_LEN;
  const metaOff = rootOff + root.length;
  const leafOff = metaOff + metadata.length;
  const dataOff = leafOff + leaves.length;
  const addressed = entries.reduce((n, e) => n + e.runLength, 0);
  const h = Buffer.alloc(HEADER_LEN);
  h.write('PMTiles', 0, 'ascii');
  h.writeUInt8(3, 7);
  const u64 = (pos: number, v: number) => h.writeBigUInt64LE(BigInt(v), pos);
  u64(8, rootOff);
  u64(16, root.length);
  u64(24, metaOff);
  u64(32, metadata.length);
  u64(40, leafOff);
  u64(48, leaves.length);
  u64(56, dataOff);
  u64(64, written);
  u64(72, addressed);
  u64(80, entries.length);
  u64(88, byHash.size);
  h.writeUInt8(0, 96); // not clustered: deduplicated tiles break strict tile-id order
  h.writeUInt8(2, 97); // internal compression gzip
  h.writeUInt8(header.tileCompression, 98);
  h.writeUInt8(header.tileType, 99);
  h.writeUInt8(0, 100);
  h.writeUInt8(Math.min(maxZoom, header.maxZoom), 101);
  const e7 = (pos: number, v: number) => h.writeInt32LE(Math.round(v * 1e7), pos);
  e7(102, bbox.minLon);
  e7(106, bbox.minLat);
  e7(110, bbox.maxLon);
  e7(114, bbox.maxLat);
  h.writeUInt8(5, 118);
  e7(119, 15.5);
  e7(123, 61);

  const outFd = fs.openSync(tmp, 'w');
  try {
    for (const b of [h, root, metadata, leaves]) fs.writeSync(outFd, b);
    const rd = fs.openSync(dataFile, 'r');
    const buf = Buffer.alloc(8 * 1024 * 1024);
    let n: number;
    while ((n = fs.readSync(rd, buf, 0, buf.length, null)) > 0) fs.writeSync(outFd, buf, 0, n);
    fs.closeSync(rd);
  } finally {
    fs.closeSync(outFd);
    fs.rmSync(dataFile, { force: true });
  }
  fs.renameSync(tmp, out);
  const bytes = fs.statSync(out).size;
  log(`Basemap: wrote ${path.relative(process.cwd(), out)} (${(bytes / 1e6).toFixed(0)} MB, ${addressed} tiles)`);
  return { file: out, bytes, tiles: addressed, source: url };
}

/** Neighbouring entries with the same content become one run (after slimming, much of the sea is identical). */
function mergeRuns(entries: Entry[]): Entry[] {
  const out: Entry[] = [];
  for (const e of entries) {
    const last = out.at(-1);
    if (last && last.offset === e.offset && last.tileId + last.runLength === e.tileId) last.runLength += e.runLength;
    else out.push({ ...e });
  }
  return out;
}

/** Root directory must fit in the first 16 KB; bigger indexes go into leaf directories. */
function buildDirectories(entries: Entry[]): { root: Buffer; leaves: Buffer } {
  const root = serializeDirectory(entries);
  if (root.length <= 16384 - 127) return { root, leaves: Buffer.alloc(0) };
  for (let size = 4096; ; size *= 2) {
    const leafBufs: Buffer[] = [];
    const rootEntries: Entry[] = [];
    let off = 0;
    for (let i = 0; i < entries.length; i += size) {
      const b = serializeDirectory(entries.slice(i, i + size));
      rootEntries.push({ tileId: entries[i]!.tileId, offset: off, length: b.length, runLength: 0 });
      leafBufs.push(b);
      off += b.length;
    }
    const r = serializeDirectory(rootEntries);
    if (r.length <= 16384 - 127) return { root: r, leaves: Buffer.concat(leafBufs) };
  }
}

/** Basic facts about the local basemap, for the status endpoint. */
export function basemapInfo(file = BASEMAP_FILE) {
  if (!fs.existsSync(file)) return null;
  const st = fs.statSync(file);
  return { bytes: st.size, modified: st.mtime.toISOString() };
}

