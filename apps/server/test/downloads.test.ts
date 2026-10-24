import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { openDb, type Db } from '../src/db/client.js';
import { importLog } from '../src/db/schema.js';
import { FINLAND_DATASET, MIN_HOURS_BETWEEN_DOWNLOADS, QuotaError, callsThisMonth, ensureDataset, type Dataset } from '../src/import/downloads.js';

const NOW = Date.parse('2026-10-20T12:00:00Z');
let db: Db;
let ds: Dataset;
let calls: number;
const fakeFetch = (status = 200) =>
  (async () => {
    calls++;
    return new Response(status === 200 ? 'zipbytes' : 'nope', { status });
  }) as unknown as typeof fetch;

let dir = '';
beforeEach(() => {
  db = openDb(':memory:');
  dir = fs.mkdtempSync(path.join(os.tmpdir(), 'clack-dl-'));
  ds = { source: 'test', url: 'https://example.invalid/feed.zip', key: () => 'k', file: path.join(dir, 'feed.zip'), monthlyQuota: 3 };
  calls = 0;
});
// The progress test writes 250 MB: every run left it behind in the temp folder until the disk filled.
afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

describe('quota-guarded downloads', () => {
  it('downloads when nothing is cached, logs it, and then serves the cache', async () => {
    const r1 = await ensureDataset(db, ds, { now: NOW, fetchImpl: fakeFetch() });
    expect(r1.downloaded).toBe(true);
    expect(fs.readFileSync(ds.file, 'utf8')).toBe('zipbytes');
    const r2 = await ensureDataset(db, ds, { now: NOW + 5 * 3600_000, fetchImpl: fakeFetch() });
    expect(r2.downloaded).toBe(false);
    expect(calls).toBe(1);
    expect(callsThisMonth(db, 'test', NOW)).toBe(1);
  });

  it('downloads again after 20 hours, or when forced', async () => {
    await ensureDataset(db, ds, { now: NOW, fetchImpl: fakeFetch() });
    expect((await ensureDataset(db, ds, { now: NOW + 21 * 3600_000, fetchImpl: fakeFetch() })).downloaded).toBe(true);
    expect((await ensureDataset(db, ds, { now: NOW + 22 * 3600_000, force: true, fetchImpl: fakeFetch() })).downloaded).toBe(true);
    expect(calls).toBe(3);
  });

  it('refuses once the monthly quota is used, and counts failed calls', async () => {
    await expect(ensureDataset(db, ds, { now: NOW, fetchImpl: fakeFetch(500) })).rejects.toThrow('HTTP 500');
    expect(callsThisMonth(db, 'test', NOW)).toBe(1);
    for (let i = 1; i <= 2; i++) await ensureDataset(db, ds, { now: NOW + i * 21 * 3600_000, fetchImpl: fakeFetch() });
    await expect(ensureDataset(db, ds, { now: NOW + 3 * 21 * 3600_000, fetchImpl: fakeFetch() })).rejects.toBeInstanceOf(QuotaError);
    expect(calls).toBe(3);
  });

  it('uses a fresh file on disk even when the log is empty (e.g. a copied cache)', async () => {
    fs.writeFileSync(ds.file, 'cached');
    const r = await ensureDataset(db, ds, { fetchImpl: fakeFetch() });
    expect(r.downloaded).toBe(false);
    expect(db.select().from(importLog).all()).toHaveLength(0);
  });
});

describe('download progress', () => {
  it('reports progress every 100 MB and records the bytes', async () => {
    const big = new Uint8Array(250e6 / 10);
    const body = new ReadableStream({
      start(c) {
        for (let i = 0; i < 10; i++) c.enqueue(big);
        c.close();
      },
    });
    const lines: string[] = [];
    const fetchImpl = (async () => new Response(body, { headers: { 'content-length': String(250e6) } })) as unknown as typeof fetch;
    const r = await ensureDataset(db, ds, { now: NOW, fetchImpl, log: (m) => lines.push(m) });
    expect(r.downloaded).toBe(true);
    expect(lines).toEqual(['test: downloading (1/3 this month)…', 'test: 100 MB of 250 MB downloaded', 'test: 200 MB of 250 MB downloaded']);
    // Writes 250 MB to disk, which can pass the default 5 s when every test file runs at once.
  }, 30_000);
});

describe('Finland dataset', () => {
  it('is Digitraffic\'s passenger GTFS with the exact gzip header and no key', () => {
    expect(FINLAND_DATASET.url).toBe('https://rata.digitraffic.fi/api/v1/trains/gtfs-passenger.zip');
    expect(FINLAND_DATASET.key).toBeUndefined();
    expect(FINLAND_DATASET.headers!()).toMatchObject({ 'Accept-Encoding': 'gzip', 'Digitraffic-User': 'clack' });
    expect(FINLAND_DATASET.file).toMatch(/data\/cache\/digitraffic\/gtfs-passenger\.zip$/);
    expect(FINLAND_DATASET.monthlyQuota).toBe(40);
  });
  it('is downloaded once a day, sending those headers', async () => {
    const seen: (HeadersInit | undefined)[] = [];
    const fetchImpl = (async (_u: string, init?: RequestInit) => {
      seen.push(init?.headers);
      return new Response('zipbytes');
    }) as unknown as typeof fetch;
    const fin = { ...FINLAND_DATASET, file: path.join(dir, 'gtfs-passenger.zip') };
    expect((await ensureDataset(db, fin, { now: NOW, fetchImpl })).downloaded).toBe(true);
    expect((await ensureDataset(db, fin, { now: NOW + (MIN_HOURS_BETWEEN_DOWNLOADS - 1) * 3600_000, fetchImpl })).downloaded).toBe(false);
    expect(seen).toHaveLength(1);
    expect((seen[0] as Record<string, string>)['Accept-Encoding']).toBe('gzip');
  });
});
