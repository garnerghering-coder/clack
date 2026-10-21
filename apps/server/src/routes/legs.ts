import type { FastifyPluginAsync } from 'fastify';
import type { Db } from '../db/client.js';
import { createLeg, deleteLeg, getLeg, LegError, listLegs, setTrainType, type CreateLegInput } from '../legs/legs.js';
import { trainTypeCatalog } from '../legs/trainTypes.js';
import { refreshLegActuals } from '../legs/actuals.js';
import { withLogo } from '../import/brands.js';
import { CONTENT_TYPES, logoFile } from '../import/logos.js';
import fs from 'node:fs';

export const legRoutes =
  (db: Db, hooks: { afterCreate?: (legId: string) => void } = {}): FastifyPluginAsync =>
  async (app) => {
    app.get('/legs', async (req) => listLegs(db, req.userId));

    app.get<{ Params: { id: string } }>('/legs/:id', async (req, reply) => getLeg(db, req.userId, req.params.id) ?? reply.code(404).send({ error: 'not found' }));

    app.post<{ Body: CreateLegInput }>('/legs', async (req, reply) => {
      const b = req.body ?? ({} as CreateLegInput);
      if (typeof b.tripKey !== 'string' || typeof b.serviceDate !== 'string' || !Number.isInteger(b.fromSeq) || !Number.isInteger(b.toSeq))
        return reply.code(400).send({ error: 'tripKey, serviceDate, fromSeq and toSeq are required' });
      try {
        const id = createLeg(db, req.userId, b);
        hooks.afterCreate?.(id);
        return reply.code(201).send(getLeg(db, req.userId, id));
      } catch (e) {
        if (e instanceof LegError) return reply.code(e.status).send({ error: e.message, ...e.body });
        throw e;
      }
    });

    // Pull to refresh (DESIGN §4): fetch actual times now.
    app.post<{ Params: { id: string } }>('/legs/:id/refresh', async (req, reply) => {
      if (!getLeg(db, req.userId, req.params.id)) return reply.code(404).send({ error: 'not found' });
      await refreshLegActuals(db, req.params.id);
      return getLeg(db, req.userId, req.params.id);
    });

    // Edits the owner can make to a saved trip. Only the train type for now.
    app.patch<{ Params: { id: string }; Body: { trainType?: string | null } }>('/legs/:id', async (req, reply) => {
      const t = req.body?.trainType;
      if (t === undefined) return reply.code(400).send({ error: 'nothing to change' });
      if (t !== null && !trainTypeCatalog().types.some((x) => x.id === t)) return reply.code(400).send({ error: `unknown train type: ${t}` });
      if (!setTrainType(db, req.userId, req.params.id, t)) return reply.code(404).send({ error: 'not found' });
      return getLeg(db, req.userId, req.params.id);
    });

    app.get('/train-types', async () => trainTypeCatalog().types);

    app.delete<{ Params: { id: string } }>('/legs/:id', async (req, reply) => (deleteLeg(db, req.userId, req.params.id) ? reply.code(204).send() : reply.code(404).send({ error: 'not found' })));

    app.get('/operators', async () => (await db.query.operators.findMany()).map(withLogo));

    app.get<{ Params: { id: string } }>('/operators/:id/logo', async (req, reply) => {
      const f = /^[a-z0-9-]+$/.test(req.params.id) ? logoFile(req.params.id) : null;
      if (!f) return reply.code(404).send({ error: 'no logo' });
      const ext = f.split('.').pop()!;
      return reply.header('Content-Type', CONTENT_TYPES[ext]).header('Cache-Control', 'max-age=86400').send(fs.readFileSync(f));
    });
  };
