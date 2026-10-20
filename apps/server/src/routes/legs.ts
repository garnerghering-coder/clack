import type { FastifyPluginAsync } from 'fastify';
import type { Db } from '../db/client.js';
import { createLeg, deleteLeg, getLeg, LegError, listLegs, type CreateLegInput } from '../legs/legs.js';
import { refreshLegActuals } from '../legs/actuals.js';

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

    app.delete<{ Params: { id: string } }>('/legs/:id', async (req, reply) => (deleteLeg(db, req.userId, req.params.id) ? reply.code(204).send() : reply.code(404).send({ error: 'not found' })));

    app.get('/operators', async () => db.query.operators.findMany());
  };
