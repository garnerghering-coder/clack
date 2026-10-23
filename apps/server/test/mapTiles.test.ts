import fs from 'node:fs';
import Fastify from 'fastify';
import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { BASEMAP_FILE } from '../src/import/basemap.js';
import { mapRoutes } from '../src/routes/map.js';

// Native map libraries (MapLibre Native on the iPhone) get the basemap as plain z/x/y tiles and the label glyphs
// from the server, since they can't use the web app's PMTiles reader or its bundled fonts.
describe('map tiles and glyphs for native maps', () => {
  const app = () => {
    const a = Fastify();
    a.register(mapRoutes(openDb(':memory:')), { prefix: '/api' });
    return a;
  };

  it.skipIf(!fs.existsSync(BASEMAP_FILE))('serves a vector tile from the basemap (Stockholm, z8)', async () => {
    // Stockholm at z8 is tile 140/74.
    const res = await app().inject({ url: '/api/map/tiles/8/140/74.mvt' });
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toBe('application/vnd.mapbox-vector-tile');
    // An uncompressed MVT starts with a layer (field 3, wire type 2 = 0x1a) and names its layers in plain text.
    expect(res.rawPayload[0]).toBe(0x1a);
    expect(res.rawPayload.toString('latin1')).toContain('earth');
  });

  it('rejects coordinates that are not a tile', async () => {
    expect((await app().inject({ url: '/api/map/tiles/3/9/0.mvt' })).statusCode).toBe(BASEMAP_FILE && fs.existsSync(BASEMAP_FILE) ? 400 : 404);
  });

  it('serves the map fonts, and nothing outside them', async () => {
    const ok = await app().inject({ url: '/api/map/fonts/Noto%20Sans%20Regular/0-255.pbf' });
    expect(ok.statusCode).toBe(200);
    expect(ok.rawPayload.length).toBeGreaterThan(1000);
    expect((await app().inject({ url: '/api/map/fonts/..%2F..%2F..%2F.env/0-255.pbf' })).statusCode).toBe(404);
    expect((await app().inject({ url: '/api/map/fonts/Noto%20Sans%20Regular/..%2Fsecret' })).statusCode).toBe(404);
  });
});
