// Sends pushes through Apple (APNs, HTTP/2, token authentication). No dependencies: Node's http2 and crypto.
import crypto from 'node:crypto';
import fs from 'node:fs';
import http2 from 'node:http2';

export interface ApnsConfig {
  keyId: string;
  teamId: string;
  /** The .p8 key, as PEM text. */
  keyPem: string;
  /** The app's bundle id. */
  topic: string;
}

/** Reads the key settings from the environment; without them push is simply off. */
export function loadApnsConfig(env: NodeJS.ProcessEnv = process.env): ApnsConfig | null {
  const { APNS_KEY_ID: keyId, APNS_TEAM_ID: teamId, APNS_KEY_PATH: keyPath, APNS_TOPIC: topic } = env;
  if (!keyId || !teamId || !keyPath || !topic) return null;
  try {
    return { keyId, teamId, keyPem: fs.readFileSync(keyPath, 'utf8'), topic };
  } catch {
    return null;
  }
}

const b64url = (input: Buffer | string) => Buffer.from(input).toString('base64url');

/** The provider token: ES256 JWT with the key id in the header and the team id as issuer. */
export function providerToken(cfg: ApnsConfig, nowSec: number): string {
  const head = b64url(JSON.stringify({ alg: 'ES256', kid: cfg.keyId }));
  const body = b64url(JSON.stringify({ iss: cfg.teamId, iat: nowSec }));
  const sig = crypto.sign('sha256', Buffer.from(`${head}.${body}`), { key: cfg.keyPem, dsaEncoding: 'ieee-p1363' });
  return `${head}.${body}.${b64url(sig)}`;
}

export type Environment = 'sandbox' | 'production';
export const HOSTS: Record<Environment, string> = { sandbox: 'api.sandbox.push.apple.com', production: 'api.push.apple.com' };

export type PushType = 'alert' | 'liveactivity' | 'background' | 'widgets';

/** The topic each push type goes to (Apple, "Sending notification requests to APNs", apns-push-type). */
export function topicFor(bundleId: string, pushType: PushType): string {
  if (pushType === 'liveactivity') return `${bundleId}.push-type.liveactivity`;
  if (pushType === 'widgets') return `${bundleId}.push-type.widgets`;
  return bundleId;
}

export interface PushRequest {
  token: string;
  environment: Environment;
  /**
   * alert: a notification. liveactivity: start, update or end a Live Activity. background: wakes the app to refresh
   * (`content-available`, always priority 5). widgets: tells WidgetKit to reload this app's widgets (iOS 26+).
   */
  pushType: PushType;
  /**
   * 10 = now, 5 = when convenient. Live Activity updates at 10 count against a budget; at 5 they don't. Background pushes
   * must be 5 (Apple: "Using priority 10 is an error"), so that is forced. Widget pushes send no priority unless given,
   * as in Apple's example request.
   */
  priority?: 5 | 10;
  collapseId?: string;
  /** Seconds since 1970 after which Apple stops trying; 0 = try once. */
  expiration?: number;
  payload: Record<string, unknown>;
}

export interface PushResult {
  ok: boolean;
  status: number;
  reason?: string;
  /** Apple says this address is no longer valid: forget it. */
  dead: boolean;
}

export interface TransportRequest {
  host: string;
  path: string;
  headers: Record<string, string>;
  body: string;
}
export type Transport = (r: TransportRequest) => Promise<{ status: number; body: string }>;

/** The headers and body Apple wants for a request. */
export function buildRequest(cfg: ApnsConfig, req: PushRequest, jwt: string): TransportRequest {
  const priority = req.pushType === 'background' ? 5 : req.pushType === 'widgets' ? req.priority : (req.priority ?? 10);
  const headers: Record<string, string> = {
    authorization: `bearer ${jwt}`,
    'apns-topic': topicFor(cfg.topic, req.pushType),
    'apns-push-type': req.pushType,
    ...(priority !== undefined ? { 'apns-priority': String(priority) } : {}),
    'apns-expiration': String(req.expiration ?? 0),
    'content-type': 'application/json',
  };
  if (req.collapseId) headers['apns-collapse-id'] = req.collapseId.slice(0, 64);
  return { host: HOSTS[req.environment], path: `/3/device/${req.token}`, headers, body: JSON.stringify(req.payload) };
}

const sessions = new Map<string, http2.ClientHttp2Session>();

function session(host: string): http2.ClientHttp2Session {
  const have = sessions.get(host);
  if (have && !have.closed && !have.destroyed) return have;
  const s = http2.connect(`https://${host}`);
  s.on('error', () => sessions.delete(host));
  s.on('close', () => sessions.delete(host));
  s.unref();
  sessions.set(host, s);
  return s;
}

export const http2Transport: Transport = (r) =>
  new Promise((resolve, reject) => {
    const stream = session(r.host).request({ ':method': 'POST', ':path': r.path, ...r.headers });
    let status = 0;
    let body = '';
    const timer = setTimeout(() => {
      stream.close(http2.constants.NGHTTP2_CANCEL);
      reject(new Error('APNs timed out'));
    }, 10_000);
    stream.on('response', (h) => (status = Number(h[':status'])));
    stream.setEncoding('utf8');
    stream.on('data', (c: string) => (body += c));
    stream.on('end', () => {
      clearTimeout(timer);
      resolve({ status, body });
    });
    stream.on('error', (e) => {
      clearTimeout(timer);
      reject(e);
    });
    stream.end(r.body);
  });

export class ApnsClient {
  private jwt: { token: string; at: number } | null = null;

  constructor(
    private cfg: ApnsConfig,
    private transport: Transport = http2Transport,
    private now: () => number = Date.now,
  ) {}

  /** Apple wants the token refreshed no more than every 20 minutes and at least hourly. */
  private token(): string {
    const nowSec = Math.floor(this.now() / 1000);
    if (!this.jwt || nowSec - this.jwt.at > 40 * 60) this.jwt = { token: providerToken(this.cfg, nowSec), at: nowSec };
    return this.jwt.token;
  }

  async send(req: PushRequest): Promise<PushResult> {
    try {
      const r = await this.transport(buildRequest(this.cfg, req, this.token()));
      if (r.status === 200) return { ok: true, status: 200, dead: false };
      let reason: string | undefined;
      try {
        reason = (JSON.parse(r.body) as { reason?: string }).reason;
      } catch {
        /* not JSON */
      }
      const dead = r.status === 410 || reason === 'BadDeviceToken' || reason === 'Unregistered' || reason === 'DeviceTokenNotForTopic';
      return { ok: false, status: r.status, reason, dead };
    } catch (e) {
      return { ok: false, status: 0, reason: (e as Error).message, dead: false };
    }
  }
}

/** A background push: wakes the app to fetch fresh data. `aps` holds only `content-available` (Apple's rule). */
export function backgroundPayload(c: { legId: string; reason: string }): Record<string, unknown> {
  return { aps: { 'content-available': 1 }, clack: { legId: c.legId, reason: c.reason } };
}

/** A WidgetKit push: WidgetKit reloads the app's widget timelines. */
export const WIDGET_PAYLOAD: Record<string, unknown> = Object.freeze({ aps: Object.freeze({ 'content-changed': true }) });

/** The JSON for an alert on the lock screen. `timeSensitive` breaks through Focus (cancellations, missed changes). */
/** The alert sound: SBB's jingle, bundled with the app (Resources/Sounds). */
export const ALERT_SOUND = 'sbb_jingle.wav';

export function alertPayload(a: { title: string; subtitle?: string; body: string; legId: string; kind: string; journeyId?: string | null; timeSensitive?: boolean }): Record<string, unknown> {
  return {
    aps: {
      alert: { title: a.title, ...(a.subtitle ? { subtitle: a.subtitle } : {}), body: a.body },
      sound: ALERT_SOUND,
      'thread-id': a.legId,
      'interruption-level': a.timeSensitive ? 'time-sensitive' : 'active',
    },
    legId: a.legId,
    kind: a.kind,
    ...(a.journeyId ? { journeyId: a.journeyId } : {}),
  };
}
