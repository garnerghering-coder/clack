// Map data for the web app: the local basemap (PMTiles, served with HTTP range requests), the rail-network
// layer and a status check so the UI can say when the basemap is still downloading.
import fs from 'node:fs';
import type { FastifyPluginAsync } from 'fastify';
import type { Db } from '../db/client.js';
import { BASEMAP_FILE, basemapInfo } from '../import/basemap.js';
import { railGraph } from '../geo/railGraph.js';
import { railNetworkGz } from '../geo/railNetwork.js';

export const mapRoutes =
  (db: Db, opts: { basemapFile?: string } = {}): FastifyPluginAsync =>
  async (app) => {
    const file = opts.basemapFile ?? BASEMAP_FILE;

    app.get('/map/status', async () => {
      const g = railGraph();
      return { basemap: basemapInfo(file), railGraph: g ? { generated: g.generated, attribution: g.attribution } : null };
    });

    app.get('/map/basemap.pmtiles', async (req, reply) => {
      if (!fs.existsSync(file)) return reply.code(404).send({ error: 'basemap not downloaded yet' });
      const size = fs.statSync(file).size;
      reply.header('Accept-Ranges', 'bytes').header('Content-Type', 'application/vnd.pmtiles').header('Cache-Control', 'no-cache');
      const m = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range ?? '');
      if (!m) return reply.header('Content-Length', size).send(fs.createReadStream(file));
      const start = Number(m[1]);
      const end = m[2] ? Math.min(Number(m[2]), size - 1) : size - 1;
      if (start >= size || start > end) return reply.code(416).header('Content-Range', `bytes */${size}`).send();
      return reply
        .code(206)
        .header('Content-Range', `bytes ${start}-${end}/${size}`)
        .header('Content-Length', end - start + 1)
        .send(fs.createReadStream(file, { start, end }));
    });

    app.get('/map/rail-network.geojson', async (_req, reply) => {
      const g = railGraph();
      if (!g) return reply.code(404).send({ error: 'rail graph missing (data/osm/rail-graph.json.gz)' });
      return reply.header('Content-Type', 'application/geo+json').header('Content-Encoding', 'gzip').header('Cache-Control', 'max-age=3600').send(railNetworkGz(db, g));
    });
  };
