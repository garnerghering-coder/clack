# Addition 01: what already exists to reuse (step 1)

Written 2026-10-21 after reading `ADDITIONS_01.md`, `SPEC.md`, `DESIGN.md`, `DATA_FINDINGS.md` and the current code.
Nothing for Addition 01 has been built yet.

## Reusable today

| Need (feature) | What exists | Where |
|---|---|---|
| Station search (B, C) | Accent/case-insensitive fuzzy search over ~670 rail stations, popularity ranking, aliases ("Gbg", "Sthlm", "Arlanda"), flags for foreign stations, `/api/stations/search` and `/api/stations/popular` | `apps/server/src/search/stations.ts`, `data/station_aliases.json`, `routes/stations.ts` |
| Station identity | Stations keyed by rikshållplats id, with the Trafikverket signature (`Cst`, `G`) for querying announcements | `db/schema.ts` `stations` |
| Announcement normalisation (B) | Trafikverket `TrainAnnouncement` 1.9 client, row type, planned/actual/estimated times, platform, deviations, cancellation; delay bands and on-time rule | `trafikverket/client.ts`, `legs/actuals.ts`, `packages/shared/src/delay.ts` |
| What counts as a train (B, A) | Category rules plus "TypeOfTraffic = Buss" exclusion (Phase 0 §5) | `data/category_overrides.json`, `import/classify.ts` |
| Operator branding (B, A) | Brands with colours, logos downloaded locally, alias matcher that maps "SJ Snabbtåg", "Pågatågen"… to a brand | `data/operators.json`, `import/logos.ts`, `search/parse.ts` |
| Train types (B rows, D) | 18 typical types per operator/product with drawings; user-correctable per trip. D's outcome B ("typically…") fits straight into this file | `data/train_types.json`, `legs/trainTypes.ts`, `components/TrainArt.tsx` |
| Add-to-trips handoff (B, A) | Confirm step takes a timetable trip (`key` + service date) and preselected stops | `pages/AddTripPage.tsx` `Confirm`, `POST /api/legs` |
| Live positions (A) | `TrainPosition` 1.1 query, GPS freshness rule (< 2 min, Active), estimated position along a route between stops | `live/tracker.ts`, `live/progress.ts` |
| Server → client push | SSE endpoint `/api/live/stream` and a shared `EventSource` in the web app | `routes/live.ts`, `web/src/live.ts` |
| Route geometry (A, C) | OSM rail graph routing, cached per station pair; whole-trip geometry per timetable trip | `geo/railGraph.ts`, `geo/trackSegments.ts`, `GET /api/timetable/trips/:key/geometry` |
| Maps (A) | MapLibre + self-hosted PMTiles basemap, dark style, rail-network layer, glow route strokes, train marker with halo, multi-route map | `web/src/map/*` |
| Journeys and connections (C3) | Auto-grouping (SPEC §13), transfer connector with planned/actual/tight/missed, journey view | `legs/journeys.ts`, `components/Journey.tsx`, `pages/JourneyPage.tsx` |
| Settings | Per-user JSON settings validated in one place | `packages/shared/src/index.ts` `mergeSettings`, `routes/settings.ts` |
| Fixtures | Capture script and three recorded trains from 2026-10-20 | `scripts/fixtures/capture-trv.mjs`, `data/fixtures/trv/` |

## Where the document and the code differ (needs a nod before I build)

1. **Live tracking today polls, it doesn't stream.** The tracker polls Trafikverket every 20 s, once per tracked leg.
   - For boards: one poll per open station every 20 s, ref-counted, with a short cache. That's what the document asks.
   - For the live map: one Trafikverket **SSE** stream for `TrainPosition` (Phase 0 §9 verified it), with a `changeid` catch-up after reconnects, held in memory.
2. **The SSE to the browser broadcasts everything.** There's one user today, so it's fine. Boards and the live map need per-subscription filtering, and an EventSource can't change its filter. So I'll open one stream per board and one per map viewport, reconnecting (debounced) when you pan. I'll also add user filtering to the existing stream before any multi-user launch.
3. **Settings are one JSON blob, not a `user_settings` table.** The walking profile (`walk_pace`, `step_free_only`, `heavy_luggage`, the two buffers) goes into that blob. Favourites, recents and station-map requests get real tables with `user_id`.
4. **Train identity.** A trip in Clack is a GTFS trip pattern plus a service date. Board rows come from Trafikverket, whose numbers change mid-journey and collide, so I'll resolve each row the way actual-times matching already does: station + activity + advertised minute.
   - About 230–300 Trafikverket trains a day have no GTFS match (Phase 0 §2, mostly short-notice Västtågen variants). Those rows can't be added to trips, and the button will say why.
5. **"Shape ids".** Geometry is per station pair, and per trip via the existing endpoint, so a trip's shape id is its key plus date. The client fetches it only for the selected train, as asked.
6. **Split-flap digits don't exist yet** (they were planned for the polish step). I'll build the component once, for board times.
7. **Swedish.** The app is English-only. The document asks for en + sv, so I'll add `sv.json` for all strings. A native read-through before launch is worth it.
8. **Estimated positions for every train on the live map** would need announcements for all running trains plus routing each one. GPS already covers 86% of trains (Phase 0 §8). So A ships GPS-only first; estimated trains follow behind `LIVE_MAP_INCLUDE_ESTIMATED`.
9. **Train type file name.** It's `data/train_types.json` (underscore), not `train-types.json`. I'll keep it, since the code and Phase 1 docs use it.
10. **Station "county or town".** It isn't stored yet. Trafikverket `TrainStation` has a county number, so I'll add it to the weekly station import plus a small county-name table.

## Already answered for the C0 spike

- **GTFS Sweden 3 has no `pathways.txt` or `levels.txt`.** I checked the zip on disk: `areas`, `stop_areas`, `transfers`, `booking_rules` and the usual files only. So there's no ready-made station graph.
- **OSM extracts for Sweden, Denmark and Norway (2026-10-19) are on disk here**, so C0 can query platforms, indoor ways and POIs offline with pyosmium instead of hammering Overpass.

## Proposal for the open questions

- **Navigation:** no fourth tab. The Trips header gets two round buttons next to "+": **Stations** (search icon) and **Live** (radar icon). The desktop sidebar gets "Stations" and "Live map" entries. Stop names in a trip and in the timeline link to that station's board.
- **Pilot station:** decided after C0 (Stockholm C or Göteborg C).
- **Walking profile:** all three controls in Settings, under a "Changing trains" group; defaults are normal pace, no step-free, no luggage.
- **"Report a problem":** store a `reports` table now (cheap), with no UI until C2.

## Expected Trafikverket load (fair use, no hard limit; DATA_FINDINGS §7)

- Live tracking: 1 query per tracked leg + 1 position query every 20 s, only while a trip is in its window.
- Boards: 1 query per *open* station every 20 s, shared by all viewers, stopped when nobody watches.
- Live map: 1 SSE stream (positions) + 1 catch-up query per reconnect, only while someone has the map open.

All intervals will be env-configurable and listed in the README.

## Order

B (boards) → A (live map) → C0 spike + `STATION_DATA_FINDINGS.md`, then stop and report. In parallel: D spike + `ONBOARD_DATA_FINDINGS.md`, then stop and report. Then C1 → C2 → C3 → fallback → C4.
