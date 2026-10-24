import { afterEach, describe, expect, it } from 'vitest';
import en from '../../../packages/shared/locales/en.json';
import sv from '../../../packages/shared/locales/sv.json';
import { buildApp } from '../src/app.js';
import { openDb } from '../src/db/client.js';

// The hosted privacy page (App Store privacy URL): static HTML that repeats the app's privacy.* strings.
describe('privacy page', () => {
  let app: ReturnType<typeof buildApp>;
  afterEach(() => app.close());

  const text = (html: string) => html.replace(/&quot;/g, '"').replace(/&#(?:x27|39);/g, "'").replace(/&amp;/g, '&');

  for (const [url, lang, strings] of [['/privacy', 'en', en.privacy], ['/privacy/sv', 'sv', sv.privacy]] as const) {
    it(`serves ${url} in ${lang} with every privacy string`, async () => {
      app = buildApp(openDb(':memory:'));
      const res = await app.inject({ url });
      expect(res.statusCode).toBe(200);
      expect(res.headers['content-type']).toContain('text/html');
      const body = text(res.body);
      expect(body).toContain(`<html lang="${lang}">`);
      expect(body).toContain(`<title>${strings.title} · Clack</title>`);
      for (const key of ['intro', 'storedBody', 'phoneBody', 'idSync', 'locationBody', 'notCollectedBody', 'sharingBody', 'deletionBody', 'alertsBody'] as const) {
        expect(body, key).toContain(strings[key]);
      }
    });
  }

  it('serves the same page with a trailing slash', async () => {
    app = buildApp(openDb(':memory:'));
    expect((await app.inject({ url: '/privacy/' })).statusCode).toBe(200);
    expect((await app.inject({ url: '/privacy/sv/' })).statusCode).toBe(200);
  });
});
