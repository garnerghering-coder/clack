import type { FastifyPluginAsync } from 'fastify';
import type { Db } from '../db/client.js';
import { cleanPlatform, cleanSeatField, createLeg, createManualLeg, deleteLeg, getJourney, getLeg, LegError, listLegs, setCoachSeat, setTrainType, setUserPlatforms, type CreateLegInput, type ManualLegInput } from '../legs/legs.js';
import { trainTypeCatalog } from '../legs/trainTypes.js';
import { refreshLegActuals } from '../legs/actuals.js';
import { answerRide } from '../legs/recording.js';
import { withLogo } from '../import/brands.js';
import { loadBrands } from '../dataFiles.js';
import { legRisk } from '../legs/risk.js';
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
        // A planned journey's legs share a group (any short id the app makes), so they stay one journey.
        if (b.group !== undefined && (typeof b.group !== 'string' || !/^[A-Za-z0-9-]{1,64}$/.test(b.group))) return reply.code(400).send({ error: 'bad group' });
        const id = createLeg(db, req.userId, b);
        hooks.afterCreate?.(id);
        return reply.code(201).send(getLeg(db, req.userId, id));
      } catch (e) {
        if (e instanceof LegError) return reply.code(e.status).send({ error: e.message, ...e.body });
        throw e;
      }
    });

    // A trip added by hand (no timetable has it).
    app.post<{ Body: ManualLegInput }>('/legs/manual', async (req, reply) => {
      try {
        const id = createManualLeg(db, req.userId, req.body ?? ({} as ManualLegInput));
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

    // "Did you take this train?": yes, no, or undo. Statistics are derived from the records, so they follow at once.
    app.post<{ Params: { id: string }; Body: { answer?: string } }>('/legs/:id/ride', async (req, reply) => {
      const a = req.body?.answer;
      if (a !== 'yes' && a !== 'no' && a !== 'undo') return reply.code(400).send({ error: 'answer must be yes, no or undo' });
      if (!answerRide(db, req.userId, req.params.id, a)) return reply.code(404).send({ error: 'not found' });
      return getLeg(db, req.userId, req.params.id);
    });

    // Edits the owner can make to a saved trip: the train type, where they sat, and the platform where they got on or
    // off when no source has one (409 when one does). Absent fields stay as they are; each accepts null to clear.
    app.patch<{
      Params: { id: string };
      Body: { trainType?: string | null; coach?: string | null; seat?: string | null; depPlatform?: string | null; arrPlatform?: string | null };
    }>('/legs/:id', async (req, reply) => {
      const body = req.body ?? {};
      const t = body.trainType;
      let coach: string | null | undefined;
      let seat: string | null | undefined;
      let dep: string | null | undefined;
      let arr: string | null | undefined;
      try {
        coach = cleanSeatField(body.coach, 'coach');
        seat = cleanSeatField(body.seat, 'seat');
        dep = cleanPlatform(body.depPlatform, 'depPlatform');
        arr = cleanPlatform(body.arrPlatform, 'arrPlatform');
      } catch (e) {
        if (e instanceof LegError) return reply.code(e.status).send({ error: e.message });
        throw e;
      }
      if (t === undefined && coach === undefined && seat === undefined && dep === undefined && arr === undefined) return reply.code(400).send({ error: 'nothing to change' });
      if (t !== undefined && t !== null && !trainTypeCatalog().types.some((x) => x.id === t)) return reply.code(400).send({ error: `unknown train type: ${t}` });
      if (dep !== undefined || arr !== undefined) {
        const saved = setUserPlatforms(db, req.userId, req.params.id, { dep, arr });
        if (saved === false) return reply.code(404).send({ error: 'not found' });
        if (saved === 'known') return reply.code(409).send({ error: 'the platform is already known' });
      }
      if (!setCoachSeat(db, req.userId, req.params.id, { coach, seat })) return reply.code(404).send({ error: 'not found' });
      if (t !== undefined) setTrainType(db, req.userId, req.params.id, t);
      return getLeg(db, req.userId, req.params.id);
    });

    app.get<{ Params: { id: string } }>('/journeys/:id', async (req, reply) => getJourney(db, req.userId, req.params.id) ?? reply.code(404).send({ error: 'not found' }));

    app.get('/train-types', async () => trainTypeCatalog().types);
    // Typical on-board amenities per operator and train type, each with its source and check date.
    app.get('/amenities', async () => trainTypeCatalog().amenities ?? []);

    app.delete<{ Params: { id: string } }>('/legs/:id', async (req, reply) => (deleteLeg(db, req.userId, req.params.id) ? reply.code(204).send() : reply.code(404).send({ error: 'not found' })));

    // Ticket links (owner, 2026-10-22): always the operator's own site, never an agent or affiliate.
    const brands = new Map(loadBrands().map((b) => [b.id, b]));
    // Journey risk: warnings from the last hour along the route and this train's own past (legs/risk.ts).
    app.get<{ Params: { id: string } }>('/legs/:id/risk', async (req, reply) => (await legRisk(db, req.userId, req.params.id)) ?? reply.code(404).send({ error: 'not found' }));

    app.get('/operators', async () =>
      (await db.query.operators.findMany()).map((o) => {
        const b = brands.get(o.id);
        return { ...withLogo(o), ticketUrl: b?.tickets === null ? null : (b?.tickets?.url ?? b?.website ?? null), ticketDeepLink: b?.tickets?.deep_link ?? null };
      }),
    );

    app.get<{ Params: { id: string } }>('/operators/:id/logo', async (req, reply) => {
      const f = /^[a-z0-9-]+$/.test(req.params.id) ? logoFile(req.params.id) : null;
      if (!f) return reply.code(404).send({ error: 'no logo' });
      const ext = f.split('.').pop()!;
      return reply.header('Content-Type', CONTENT_TYPES[ext]).header('Cache-Control', 'max-age=86400').send(fs.readFileSync(f));
    });
  };
