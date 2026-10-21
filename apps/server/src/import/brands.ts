// Keeps the operators table in step with data/operators.json (names, colours) on every start, so a colour change
// shows without waiting for the next timetable import.
import fs from 'node:fs';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { operators } from '../db/schema.js';
import { loadBrands } from '../dataFiles.js';
import { logoFile } from './logos.js';

export function syncBrands(db: Db) {
  for (const b of loadBrands())
    db.insert(operators)
      .values({ id: b.id, name: b.name, shortName: b.short_name, country: b.country, brandColor: b.color })
      .onConflictDoUpdate({
        target: operators.id,
        set: { name: sql`excluded.name`, shortName: sql`excluded.short_name`, country: sql`excluded.country`, brandColor: sql`excluded.brand_color` },
      })
      .run();
}

/** Operator as sent to the app: adds logoUrl when a logo has been downloaded. */
export function withLogo<T extends { id: string }>(op: T): T & { logoUrl: string | null } {
  const f = logoFile(op.id);
  return { ...op, logoUrl: f ? `/api/operators/${op.id}/logo?v=${Math.floor(fs.statSync(f).mtimeMs)}` : null };
}
