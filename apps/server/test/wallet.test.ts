import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Fastify from 'fastify';
import yauzl from 'yauzl';
import { afterAll, beforeEach, describe, expect, it, vi } from 'vitest';

// A throwaway signer for the tests only: a self-signed certificate made here, standing in for both Apple's WWDR and
// the Pass Type ID certificate (Wallet would refuse it; the format is what's checked).
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'clack-wallet-'));
const key = path.join(dir, 'key.pem');
const cert = path.join(dir, 'cert.pem');
execFileSync('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', key, '-out', cert, '-days', '1', '-subj', '/CN=Clack test'], { stdio: 'ignore' });

const { walletRoutes } = await import('../src/routes/wallet.js');

const phone = { 'x-clack-user': 'aaaaaaaa-1111-4111-8111-111111111111' };
const everyByte = Buffer.from([...Array(256).keys(), ...[...Array(256).keys()].reverse()]);
const body = {
  issuer: 'dsb', operatorName: 'DSB', trainNumber: '394', from: 'Kolding', to: 'København H',
  depAt: Date.UTC(2025, 11, 12, 14, 46), arrAt: Date.UTC(2025, 11, 12, 16, 38), coach: '10', seat: '32',
  format: 'aztec', barcode: everyByte.toString('base64'), lang: 'en',
};

let logged = '';
async function server() {
  const app = Fastify({ logger: { level: 'trace', stream: { write: (line: string) => { logged += line; } } } });
  app.decorateRequest('userId', '');
  app.addHook('onRequest', async (req) => {
    req.userId = (req.headers['x-clack-user'] as string | undefined) ?? '';
  });
  await app.register(walletRoutes, { prefix: '/api' });
  return app;
}

function configure() {
  vi.stubEnv('WALLET_PASS_TYPE_ID', 'pass.com.example.test');
  vi.stubEnv('WALLET_TEAM_ID', 'ABCDE12345');
  vi.stubEnv('WALLET_CERT_PATH', cert);
  vi.stubEnv('WALLET_KEY_PATH', key);
  vi.stubEnv('WALLET_WWDR_PATH', cert);
}

/** The files in a zip, by name. */
function unzip(buffer: Buffer): Promise<Record<string, Buffer>> {
  return new Promise((resolve, reject) => {
    yauzl.fromBuffer(buffer, { lazyEntries: true }, (err, zip) => {
      if (err || !zip) return reject(err);
      const files: Record<string, Buffer> = {};
      zip.on('entry', (entry) => {
        zip.openReadStream(entry, (e, stream) => {
          if (e || !stream) return reject(e);
          const parts: Buffer[] = [];
          stream.on('data', (c: Buffer) => parts.push(c));
          stream.on('end', () => { files[entry.fileName] = Buffer.concat(parts); zip.readEntry(); });
        });
      });
      zip.on('end', () => resolve(files));
      zip.readEntry();
    });
  });
}

beforeEach(() => {
  vi.unstubAllEnvs();
  logged = '';
});
afterAll(() => fs.rmSync(dir, { recursive: true, force: true }));

describe('Wallet passes for kept tickets', () => {
  it('is off without the certificates, and for requests without a phone id', async () => {
    const app = await server();
    expect((await app.inject({ method: 'POST', url: '/api/wallet/pass', headers: phone, payload: body })).statusCode).toBe(404);
    configure();
    expect((await app.inject({ method: 'POST', url: '/api/wallet/pass', payload: body })).statusCode).toBe(404);
  });

  it('turns down a request that isn\'t a pass', async () => {
    configure();
    const app = await server();
    const bad = await app.inject({ method: 'POST', url: '/api/wallet/pass', headers: phone, payload: { ...body, barcode: 'not base64!' } });
    expect(bad.statusCode).toBe(400);
    expect(bad.body).not.toContain('not base64');
    // Anything else sent (a name, say) is dropped by the schema and never reaches the pass.
    const extra = await app.inject({ method: 'POST', url: '/api/wallet/pass', headers: phone, payload: { ...body, name: 'Passenger Name' } });
    expect((await unzip(extra.rawPayload))['pass.json']!.toString('utf8')).not.toContain('Passenger');
  });

  it('signs a train boarding pass whose code carries every byte of the ticket\'s, and logs none of it', async () => {
    configure();
    const app = await server();
    const res = await app.inject({ method: 'POST', url: '/api/wallet/pass', headers: phone, payload: body });
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toContain('application/vnd.apple.pkpass');
    const files = await unzip(res.rawPayload);
    expect(Object.keys(files)).toEqual(expect.arrayContaining(['pass.json', 'manifest.json', 'signature', 'icon.png', 'icon@2x.png']));
    const pass = JSON.parse(files['pass.json']!.toString('utf8'));
    expect(pass.boardingPass.transitType).toBe('PKTransitTypeTrain');
    expect(pass.boardingPass.primaryFields.map((f: { value: string }) => f.value)).toEqual(['Kolding', 'København H']);
    expect(pass.barcodes[0].format).toBe('PKBarcodeFormatAztec');
    expect(pass.barcodes[0].messageEncoding).toBe('iso-8859-1');
    expect(Buffer.from(pass.barcodes[0].message, 'latin1').equals(everyByte)).toBe(true);
    expect(logged).not.toContain(body.barcode.slice(0, 40));
    expect(logged).not.toContain('Kolding');
  });
});
