// Google service-account sign-in for BigQuery, without a Google library: a signed JWT exchanged for a one-hour access
// token. The key file lives outside the repo (GOOGLE_APPLICATION_CREDENTIALS); nothing here is ever logged.
import crypto from 'node:crypto';
import fs from 'node:fs';

interface ServiceAccountKey {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri: string;
}

let cached: { token: string; until: number; project: string } | null = null;

export function googleKeyPath(): string | null {
  const p = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  return p && fs.existsSync(p) ? p : null;
}

/** An access token and the key's project, refreshed a few minutes before it expires. */
export async function googleToken(scope = 'https://www.googleapis.com/auth/bigquery', fetchImpl: typeof fetch = fetch): Promise<{ token: string; project: string }> {
  if (cached && cached.until > Date.now() + 5 * 60_000) return cached;
  const file = googleKeyPath();
  if (!file) throw new Error('GOOGLE_APPLICATION_CREDENTIALS is not set or the file is missing');
  const key = JSON.parse(fs.readFileSync(file, 'utf8')) as ServiceAccountKey;
  const b64 = (o: unknown) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({ iss: key.client_email, scope, aud: key.token_uri, iat: now, exp: now + 3600 })}`;
  const jwt = `${unsigned}.${crypto.sign('RSA-SHA256', Buffer.from(unsigned), key.private_key).toString('base64url')}`;
  const res = await fetchImpl(key.token_uri, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }),
    signal: AbortSignal.timeout(30_000),
  });
  const body = (await res.json()) as { access_token?: string; expires_in?: number; error?: string; error_description?: string };
  if (!body.access_token) throw new Error(`Google sign-in failed: ${body.error ?? res.status} ${body.error_description ?? ''}`.trim());
  cached = { token: body.access_token, until: Date.now() + (body.expires_in ?? 3600) * 1000, project: key.project_id };
  return cached;
}

export interface BqField {
  name: string;
  type: string;
}

/** Run a standard-SQL query (or a dry run) and return its rows as objects plus the bytes it scanned. */
export async function bigQuery(
  sql: string,
  opts: { dryRun?: boolean; params?: Record<string, string>; fetchImpl?: typeof fetch } = {},
): Promise<{ rows: Record<string, string | null>[]; bytes: number }> {
  const fetchImpl = opts.fetchImpl ?? fetch;
  const { token, project } = await googleToken(undefined, fetchImpl);
  const headers = { authorization: `Bearer ${token}`, 'content-type': 'application/json' };
  const queryParameters = Object.entries(opts.params ?? {}).map(([name, value]) => ({ name, parameterType: { type: 'STRING' }, parameterValue: { value } }));
  const res = await fetchImpl(`https://bigquery.googleapis.com/bigquery/v2/projects/${project}/queries`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ query: sql, useLegacySql: false, dryRun: opts.dryRun ?? false, timeoutMs: 120_000, maxResults: 20_000, parameterMode: 'NAMED', queryParameters }),
    signal: AbortSignal.timeout(300_000),
  });
  type Page = {
    error?: { message: string };
    totalBytesProcessed?: string;
    schema?: { fields: BqField[] };
    rows?: { f: { v: string | null }[] }[];
    pageToken?: string;
    jobComplete?: boolean;
    jobReference?: { jobId: string; location?: string };
  };
  let page = (await res.json()) as Page;
  if (page.error) throw new Error(`BigQuery: ${page.error.message}`);
  const bytes = Number(page.totalBytesProcessed ?? 0);
  if (opts.dryRun) return { rows: [], bytes };
  const job = page.jobReference;
  // Long queries come back unfinished; ask for the results until they are.
  while (!page.jobComplete && job) {
    const r = await fetchImpl(`https://bigquery.googleapis.com/bigquery/v2/projects/${project}/queries/${job.jobId}?timeoutMs=60000&maxResults=20000${job.location ? `&location=${job.location}` : ''}`, { headers });
    page = (await r.json()) as Page;
    if (page.error) throw new Error(`BigQuery: ${page.error.message}`);
  }
  const fields = page.schema?.fields ?? [];
  const rows: Record<string, string | null>[] = [];
  const add = (p: Page) => {
    for (const row of p.rows ?? []) rows.push(Object.fromEntries(fields.map((f, i) => [f.name, row.f[i]?.v ?? null])));
  };
  add(page);
  while (page.pageToken && job) {
    const r = await fetchImpl(
      `https://bigquery.googleapis.com/bigquery/v2/projects/${project}/queries/${job.jobId}?pageToken=${encodeURIComponent(page.pageToken)}&maxResults=20000${job.location ? `&location=${job.location}` : ''}`,
      { headers },
    );
    page = (await r.json()) as Page;
    if (page.error) throw new Error(`BigQuery: ${page.error.message}`);
    add(page);
  }
  return { rows, bytes };
}
