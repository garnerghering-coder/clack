// Map data for the app: the local basemap (a PMTiles archive on disk, served as plain z/x/y vector tiles), the label
// fonts, the rail-network layer and a status check so the app can say when the basemap is still downloading.
import fs from 'node:fs';
import path from 'node:path';
import type { FastifyPluginAsync } from 'fastify';
import { PMTiles, type RangeResponse, type Source } from 'pmtiles';
import { REPO_ROOT } from '../env.js';
import type { Db } from '../db/client.js';
import { BASEMAP_FILE, basemapInfo } from '../import/basemap.js';
import { parseBbox, stationDetailGz } from '../geo/stationDetail.js';
import { railGraph } from '../geo/railGraph.js';
import { railNetworkGz } from '../geo/railNetwork.js';

/** Reads a PMTiles archive from disk (the pmtiles library fetches over HTTP otherwise). */
class FileSource implements Source {
  constructor(private file: string) {}
  getKey() {
    return this.file;
  }
  async getBytes(offset: number, length: number): Promise<RangeResponse> {
    const fd = await fs.promises.open(this.file, 'r');
    try {
      const buf = Buffer.alloc(length);
      const { bytesRead } = await fd.read(buf, 0, length, offset);
      return { data: buf.buffer.slice(buf.byteOffset, buf.byteOffset + bytesRead) };
    } finally {
      await fd.close();
    }
  }
}

/** The map labels' glyphs (Noto Sans, OFL). */
const FONTS_DIR = path.join(REPO_ROOT, 'apps/server/assets/map-fonts');
const FONT_STACKS = new Set(['Noto Sans Regular', 'Noto Sans Medium']);

export const mapRoutes =
  (db: Db, opts: { basemapFile?: string } = {}): FastifyPluginAsync =>
  async (app) => {
    const file = opts.basemapFile ?? BASEMAP_FILE;

    app.get('/map/status', async () => {
      const g = railGraph();
      return { basemap: basemapInfo(file), railGraph: g ? { generated: g.generated, attribution: g.attribution } : null };
    });

    // The basemap as ordinary vector tiles (Mapbox Vector Tile, uncompressed), for MapLibre Native on the iPhone:
    // source { type: 'vector', tiles: ['<base>/api/map/tiles/{z}/{x}/{y}.mvt'], maxzoom: 10 }. Above z10 the map
    // library over-zooms. 204 where the archive has no tile (open sea, outside the Nordics above z4).
    let archive: { file: string; mtime: number; pm: PMTiles } | null = null;
    app.get<{ Params: { z: string; x: string; y: string } }>('/map/tiles/:z/:x/:y.mvt', async (req, reply) => {
      if (!fs.existsSync(file)) return reply.code(404).send({ error: 'basemap not downloaded yet' });
      const [z, x, y] = [req.params.z, req.params.x, req.params.y].map(Number) as [number, number, number];
      if (![z, x, y].every(Number.isInteger) || z < 0 || z > 22 || x < 0 || y < 0 || x >= 2 ** z || y >= 2 ** z) {
        return reply.code(400).send({ error: 'z/x/y must be tile coordinates' });
      }
      const mtime = fs.statSync(file).mtimeMs;
      if (!archive || archive.file !== file || archive.mtime !== mtime) archive = { file, mtime, pm: new PMTiles(new FileSource(file)) };
      const tile = await archive.pm.getZxy(z, x, y);
      if (!tile) return reply.code(204).header('Cache-Control', 'max-age=86400').send();
      return reply.header('Content-Type', 'application/vnd.mapbox-vector-tile').header('Cache-Control', 'max-age=86400').send(Buffer.from(tile.data));
    });

    app.get<{ Params: { stack: string; range: string } }>('/map/fonts/:stack/:range', async (req, reply) => {
      const { stack, range } = req.params;
      if (!FONT_STACKS.has(stack) || !/^\d+-\d+\.pbf$/.test(range)) return reply.code(404).send({ error: 'no such glyphs' });
      const f = path.join(FONTS_DIR, stack, range);
      if (!fs.existsSync(f)) return reply.code(404).send({ error: 'no such glyphs' });
      return reply.header('Content-Type', 'application/x-protobuf').header('Cache-Control', 'max-age=604800').send(fs.createReadStream(f));
    });

    // Station detail at close zoom: every track in a small box at full detail (service tracks flagged) and the
    // platform outlines of the mapped stations in it. `bbox=W,S,E,N`, at most about 3 × 3 km.
    app.get<{ Querystring: { bbox?: string } }>('/map/station-detail', async (req, reply) => {
      const g = railGraph();
      if (!g) return reply.code(404).send({ error: 'rail graph missing (data/osm/rail-graph.json.gz)' });
      const b = parseBbox(req.query.bbox);
      if (!b) return reply.code(400).send({ error: 'bbox must be W,S,E,N and at most 0.06° wide and 0.03° tall' });
      return reply.header('Content-Type', 'application/geo+json').header('Content-Encoding', 'gzip').header('Cache-Control', 'max-age=600').send(stationDetailGz(db, g, b));
    });

    app.get('/map/rail-network.geojson', async (_req, reply) => {
      const g = railGraph();
      if (!g) return reply.code(404).send({ error: 'rail graph missing (data/osm/rail-graph.json.gz)' });
      return reply.header('Content-Type', 'application/geo+json').header('Content-Encoding', 'gzip').header('Cache-Control', 'max-age=3600').send(railNetworkGz(db, g));
    });
  };
