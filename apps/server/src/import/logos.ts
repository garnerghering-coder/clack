// Operator logos (SPEC §18): each brand's own app icon, downloaded from its website onto this computer.
// Logos are trademarks, so they're fetched locally (data/cache/logos/) rather than committed to the repo.
// Brands without a reachable icon keep the coloured initials badge.
import fs from 'node:fs';
import path from 'node:path';
import { loadBrands, type Brand } from '../dataFiles.js';
import { CACHE_DIR } from './downloads.js';

export const LOGO_DIR = path.join(CACHE_DIR, 'logos');
const MAX_BYTES = 1_000_000;
const REFRESH_DAYS = 30;
const TYPES: Record<string, string> = {
  'image/png': 'png',
  'image/svg+xml': 'svg',
  'image/x-icon': 'ico',
  'image/vnd.microsoft.icon': 'ico',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
};
export const CONTENT_TYPES: Record<string, string> = { png: 'image/png', svg: 'image/svg+xml', ico: 'image/x-icon', jpg: 'image/jpeg', webp: 'image/webp' };

/** The logo file for a brand, if one has been downloaded. */
export function logoFile(id: string, dir = LOGO_DIR): string | null {
  for (const ext of Object.keys(CONTENT_TYPES)) {
    const f = path.join(dir, `${id}.${ext}`);
    if (fs.existsSync(f)) return f;
  }
  return null;
}

interface IconLink {
  href: string;
  rel: string;
  size: number;
  type: string;
}

/** Icon links in a page's <head>, best first: apple-touch-icon (made for app-icon tiles), then big PNGs, SVG, ICO. */
export function iconCandidates(html: string, base: string): string[] {
  const links: IconLink[] = [];
  for (const m of html.matchAll(/<link\b[^>]*>/gi)) {
    const tag = m[0];
    const rel = /rel=["']([^"']+)["']/i.exec(tag)?.[1]?.toLowerCase() ?? '';
    if (!rel.includes('icon')) continue;
    const href = /href=["']([^"']+)["']/i.exec(tag)?.[1];
    if (!href) continue;
    const size = Number(/sizes=["'](\d+)x\d+["']/i.exec(tag)?.[1] ?? 0);
    links.push({ href: new URL(href.replace(/&amp;/g, '&'), base).toString(), rel, size, type: /type=["']([^"']+)["']/i.exec(tag)?.[1] ?? '' });
  }
  const score = (l: IconLink) => {
    const ext = l.href.split('?')[0]!.split('.').pop()!.toLowerCase();
    if (l.rel.includes('apple-touch-icon')) return 1000 + (l.size || 180);
    if (ext === 'png' && l.size >= 96) return 500 + l.size;
    if (ext === 'svg' || l.type.includes('svg')) return 400;
    if (ext === 'png') return 100 + l.size;
    return 10 + l.size;
  };
  const out = links.sort((a, b) => score(b) - score(a)).map((l) => l.href);
  out.push(new URL('/apple-touch-icon.png', base).toString(), new URL('/favicon.ico', base).toString());
  return [...new Set(out)];
}

const UA = { 'User-Agent': 'Mozilla/5.0 (Macintosh) Clack/0.1 (personal train logbook)' };

async function download(url: string, fetchImpl: typeof fetch): Promise<{ data: Buffer; ext: string } | null> {
  const res = await fetchImpl(url, { headers: UA, signal: AbortSignal.timeout(15_000), redirect: 'follow' });
  if (!res.ok) return null;
  const type = (res.headers.get('content-type') ?? '').split(';')[0]!.trim().toLowerCase();
  const ext = TYPES[type] ?? (type === '' || type === 'application/octet-stream' ? url.split('?')[0]!.split('.').pop()!.toLowerCase() : null);
  if (!ext || !CONTENT_TYPES[ext]) return null;
  const data = Buffer.from(await res.arrayBuffer());
  if (!data.length || data.length > MAX_BYTES) return null;
  return { data, ext };
}

export async function fetchLogo(brand: Brand, opts: { dir?: string; fetchImpl?: typeof fetch } = {}): Promise<string | null> {
  const dir = opts.dir ?? LOGO_DIR;
  const fetchImpl = opts.fetchImpl ?? fetch;
  let candidates = brand.icon_url ? [brand.icon_url] : [];
  if (!candidates.length && brand.website) {
    const res = await fetchImpl(brand.website, { headers: UA, signal: AbortSignal.timeout(15_000), redirect: 'follow' });
    if (!res.ok) return null;
    candidates = iconCandidates(await res.text(), res.url || brand.website);
  }
  for (const url of candidates) {
    try {
      const got = await download(url, fetchImpl);
      if (!got) continue;
      fs.mkdirSync(dir, { recursive: true });
      for (const ext of Object.keys(CONTENT_TYPES)) fs.rmSync(path.join(dir, `${brand.id}.${ext}`), { force: true });
      const file = path.join(dir, `${brand.id}.${got.ext}`);
      fs.writeFileSync(file, got.data);
      return file;
    } catch {
      // Try the next candidate.
    }
  }
  return null;
}

/** Downloads missing (or month-old) logos. Failures are fine: the badge falls back to initials. */
export async function refreshLogos(log: (m: string) => void = () => {}, opts: { force?: boolean; fetchImpl?: typeof fetch } = {}) {
  let got = 0;
  const missing: string[] = [];
  for (const b of loadBrands()) {
    if (!b.website && !b.icon_url) continue;
    const existing = logoFile(b.id);
    if (existing && !opts.force && Date.now() - fs.statSync(existing).mtimeMs < REFRESH_DAYS * 86400_000) continue;
    try {
      if (await fetchLogo(b, { fetchImpl: opts.fetchImpl })) got++;
      else missing.push(b.name);
    } catch {
      missing.push(b.name);
    }
  }
  if (got || missing.length) log(`Logos: ${got} downloaded${missing.length ? `; none found for ${missing.join(', ')} (initials shown)` : ''}`);
}
