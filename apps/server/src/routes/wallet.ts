// Apple Wallet passes for tickets kept in the app (a test tool for now: docs/TICKET_WALLET_FINDINGS.md). The phone
// sends the train and the code read off its ticket; this signs a boarding pass with the same code and sends it back.
// Nothing is stored and the body is never logged: the code holds the passenger's name. Wallet only takes passes
// signed with a Pass Type ID certificate, whose key can't ship in the app, which is why this runs here.
//
// The code's bytes travel as base64 and go into the pass as an ISO-8859-1 string with messageEncoding "iso-8859-1":
// that encoding maps each byte 0-255 to one character and back, so Wallet draws the same bytes the ticket had (a UIC
// 918.3 code is binary, compressed and signed).
//
// Off (404) unless all of WALLET_PASS_TYPE_ID, WALLET_TEAM_ID, WALLET_CERT_PATH, WALLET_KEY_PATH and WALLET_WWDR_PATH
// are set (WALLET_KEY_PASSPHRASE when the key has one); see docs/SERVER.md.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import type { FastifyPluginAsync } from 'fastify';
import { PKPass } from 'passkit-generator';
import { appString, type StringsLang } from '@clack/shared';
import { REPO_ROOT } from '../env.js';
import { LOCAL_USER_ID } from '../db/client.js';

const ASSETS = path.join(REPO_ROOT, 'apps/server/assets/wallet');
const IMAGES = ['icon.png', 'icon@2x.png', 'icon@3x.png', 'logo.png', 'logo@2x.png', 'logo@3x.png'];
const FORMATS = { aztec: 'PKBarcodeFormatAztec' } as const;
/** A UIC code is at most a few kilobytes; base64 and the rest stay well inside this. */
const BODY_LIMIT = 16 * 1024;

export interface WalletPassBody {
  issuer: 'sj' | 'dsb' | 'db';
  operatorName?: string | null;
  trainNumber?: string | null;
  from: string;
  to: string;
  depAt: number;
  arrAt?: number | null;
  coach?: string | null;
  seat?: string | null;
  format: keyof typeof FORMATS;
  barcode: string;
  lang?: StringsLang;
}

const text = (max: number) => ({ type: ['string', 'null'], maxLength: max });
const bodySchema = {
  type: 'object',
  required: ['issuer', 'from', 'to', 'depAt', 'format', 'barcode'],
  additionalProperties: false,
  properties: {
    issuer: { enum: ['sj', 'dsb', 'db'] },
    operatorName: text(80),
    trainNumber: text(16),
    from: { type: 'string', minLength: 1, maxLength: 80 },
    to: { type: 'string', minLength: 1, maxLength: 80 },
    depAt: { type: 'number' },
    arrAt: { type: ['number', 'null'] },
    coach: text(8),
    seat: text(8),
    format: { enum: Object.keys(FORMATS) },
    barcode: { type: 'string', minLength: 4, maxLength: 12_000, pattern: '^[A-Za-z0-9+/=]+$' },
    lang: { enum: ['en', 'sv'] },
  },
} as const;

interface Signing {
  passTypeIdentifier: string;
  teamIdentifier: string;
  certificates: { wwdr: Buffer; signerCert: Buffer; signerKey: Buffer; signerKeyPassphrase?: string };
}

/** The certificates from the paths in the environment, or null when any is missing. Read on each request (it's rare). */
function signing(): Signing | null {
  const env = process.env;
  const need = [env.WALLET_PASS_TYPE_ID, env.WALLET_TEAM_ID, env.WALLET_CERT_PATH, env.WALLET_KEY_PATH, env.WALLET_WWDR_PATH];
  if (need.some((v) => !v)) return null;
  try {
    return {
      passTypeIdentifier: env.WALLET_PASS_TYPE_ID!,
      teamIdentifier: env.WALLET_TEAM_ID!,
      certificates: {
        wwdr: fs.readFileSync(env.WALLET_WWDR_PATH!),
        signerCert: fs.readFileSync(env.WALLET_CERT_PATH!),
        signerKey: fs.readFileSync(env.WALLET_KEY_PATH!),
        ...(env.WALLET_KEY_PASSPHRASE ? { signerKeyPassphrase: env.WALLET_KEY_PASSPHRASE } : {}),
      },
    };
  } catch {
    return null;
  }
}

const t = (key: string, lang: StringsLang) => appString(key, lang) ?? appString(key, 'en') ?? key;

/** The signed .pkpass for one train. */
export async function buildPass(body: WalletPassBody, sign: Signing): Promise<Buffer> {
  const lang = body.lang ?? 'en';
  const bytes = Buffer.from(body.barcode, 'base64');
  const files: Record<string, Buffer> = {};
  for (const name of IMAGES) files[name] = fs.readFileSync(path.join(ASSETS, name));
  files['pass.json'] = Buffer.from(JSON.stringify({
    formatVersion: 1,
    passTypeIdentifier: sign.passTypeIdentifier,
    teamIdentifier: sign.teamIdentifier,
    organizationName: 'Clack',
    description: t('wallet.pass.description', lang),
    serialNumber: crypto.randomUUID(),
    backgroundColor: 'rgb(24, 24, 27)',
    foregroundColor: 'rgb(250, 250, 250)',
    labelColor: 'rgb(161, 161, 170)',
    boardingPass: { transitType: 'PKTransitTypeTrain' },
  }));
  const pass = new PKPass(files, sign.certificates);
  // pass.json's boardingPass becomes the pass's one type; its fields are filled in here.
  const board = pass.types[0]!;
  pass.setRelevantDate(new Date(body.depAt));
  board.primaryFields.push(
    { key: 'from', label: t('wallet.pass.from', lang), value: body.from },
    { key: 'to', label: t('wallet.pass.to', lang), value: body.to },
  );
  board.secondaryFields.push({ key: 'departs', label: t('wallet.pass.departs', lang), value: new Date(body.depAt).toISOString(), dateStyle: 'PKDateStyleMedium', timeStyle: 'PKDateStyleShort' });
  const train = [body.operatorName, body.trainNumber].filter(Boolean).join(' ');
  if (train) board.secondaryFields.push({ key: 'train', label: t('wallet.pass.train', lang), value: train });
  if (body.coach) board.auxiliaryFields.push({ key: 'coach', label: t('wallet.pass.coach', lang), value: body.coach });
  if (body.seat) board.auxiliaryFields.push({ key: 'seat', label: t('wallet.pass.seat', lang), value: body.seat });
  board.backFields.push({ key: 'note', label: t('wallet.pass.noteLabel', lang), value: t('wallet.pass.note', lang) });
  pass.setBarcodes({ format: FORMATS[body.format], message: bytes.toString('latin1'), messageEncoding: 'iso-8859-1' });
  return pass.getAsBuffer();
}

export const walletRoutes: FastifyPluginAsync = async (app) => {
  app.post<{ Body: WalletPassBody }>(
    '/wallet/pass',
    {
      bodyLimit: BODY_LIMIT,
      schema: { body: bodySchema },
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
      // A body that fails the schema is answered without echoing it.
      attachValidation: true,
    },
    async (req, reply) => {
      const user = (req.userId ?? '').toLowerCase();
      const sign = signing();
      if (!user || user === LOCAL_USER_ID || !sign) return reply.code(404).send({ error: 'not found' });
      if (req.validationError) return reply.code(400).send({ error: 'bad pass request' });
      try {
        const file = await buildPass(req.body, sign);
        return reply.type('application/vnd.apple.pkpass').header('cache-control', 'no-store').send(file);
      } catch {
        return reply.code(500).send({ error: 'could not sign the pass' });
      }
    },
  );
};
