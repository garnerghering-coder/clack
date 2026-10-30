# Station mapping: the method

How a station map (`data/stations/<id>.json`, schema 2, format in `packages/shared/src/station.ts`) is made, checked and
kept honest. Written after the seven reference stations (Stockholm C, Göteborg C, Malmö C, Jönköping C, Oslo S,
København H, Helsinki), so that the remaining hub and mid-tier stations (`data/station_tiers.json`) can be done the
same way, about 30 per session, without judgement calls that aren't written down here.

## What a map is for

- The station map screen (levels, platforms, stairs, lifts, the walk between two platforms with its time).
- Positioning: a train reported standing at a platform is drawn at that platform's point.
- The 3D station view: its measured heights (platforms, buildings, roofs, ground) come by `docs/STATION_3D_RESEARCH.md`.

Every element carries `_source`. Unverified things are said to be unverified (the review queue). Nothing is drawn that
no source gives.

## Sources, in the order they are used

1. **OpenStreetMap** (ODbL, © OpenStreetMap contributors): platforms with `ref`, levels, footways, steps, escalators,
   lifts, entrances, shops and amenities. Fetched for the station's box from Overpass by the drafter and cached in
   `data/cache/stations/<id>-osm.json` (one request per station; re-fetch by deleting the cache file).
2. **The operator's published station plan** (Trafikverket, Bane NOR, Banedanmark/DSB, Väylä/VR): facts only, never
   traced: platform numbers and which tracks they serve, level names, where lifts are. Cite the page or PDF and the
   date read.
3. **Photos with open licences:** Mapillary (token `MAPILLARY_TOKEN` in `.env`, CC BY-SA) and Wikimedia Commons. Used
   to confirm a specific fact (a platform number, a lift's existence). Cite the image id.
4. **Garner's station videos** (`~/Downloads/station-videos/<id>/`, frames already extracted to `frames/` with
   `index.json` of scene changes). **Do not read frames one by one.** Look at a handful per station at most, chosen at
   scene changes, only when a specific fact needs confirming. Cite as
   `video supplied by the owner: <file> @ mm:ss`. Facts only (what exists, where roughly); never distances or heights.
   Frames and videos never enter the repo.
5. **Garner's AR walks** (uploaded walk logs, `data/walklogs/*.walk` on the hosted server; raw-deflate JSON). The only
   source for heights: barometer `relAlt` and ARKit `ar[].p[1]` at the marks. Jönköping C's upper level is +3.3 m
   (barometer +3.5, ARKit +3.1). Marks' GPS gives positions to about ±10 m outdoors; indoors use the AR path.
   **A mark is made a few steps from the thing it names** (Garner cannot stand in an escalator or a doorway), so a
   mark says "this exists, within a few metres of here": snap it to the nearest OSM node of that kind, or to the AR
   path, and never treat the mark's own point as the object's position.

## Steps per station

1. **Edits file** `scripts/stations/<safe id>.edits.json` (`fi:HKI` → `fi_HKI`). Start from a reference file of the
   same kind: `740000090` (small, one hall), `760000100` (multipolygon platforms, Norwegian floor numbers),
   `860000626` (hall above platforms, metro below), `fi_HKI` (large, many levels). Keys:
   - `levels`: the OSM level values to keep, each with `id`, `name`, `order`, and `height_m` + `height_source` where
     measured. Norway numbers the ground floor `1`: set `default_level` accordingly.
   - `default_level`: the OSM level untagged platforms, paths and buildings belong to (`"0"` unless the country numbers
     the ground floor differently).
   - `multipolygons`: on when platforms or the station house are OSM relations.
   - `path_radius`: keep untagged paths within this many metres of a platform (stations reached from the street).
   - `paths_by_layer`: untagged tunnels and footbridges take their `layer` as level.
   - `layer_as_level`: platforms without `level` take their `layer` (Malmö C's underground platforms).
   - `platform_refs`: way id → platform number when OSM has none. `platform_levels`: way id → level.
   - `platform_edges`: which side of a platform serves which track, from the plan or a video.
   - `platform_heights`: platform `height_m` with its source.
   - `connections`: hand links OSM lacks (`from`/`to` as a point and level, a node id, or a platform edge), with
     `kind` (walk/stairs/escalator/lift), `seconds`, `note`, `_source`.
   - `entrances`: entrances OSM lacks, as a point and level, with `name` and `_source`.
   - `drop_ways`, `drop_platforms`, `drop_pois`, `drop_entrances`: OSM objects that are wrong or not public.
   - `pois`: amenities OSM lacks, each with `_source`.
   - `sources` and `changelog`: what was read, and what changed when.
   A station with nothing known yet starts from the minimal file (the O5 batches began this way): `radius` 400,
   `paths_by_layer`, `path_radius` 30 (60 in Norway, with `default_level` "1" and `multipolygons`), one level
   `{"osm": "0", "id": "L0", "name": "Level 0", "order": 0}`, `sources` (OSM via Overpass, the date) and a
   `changelog` line. The drafter needs `levels`; everything else is optional. A batch runs as a shell loop over the
   ids (one Overpass request per station, about a minute each; a 502 from Overpass is retried later by running the
   same command again, since the cache file is written only on success).
   A station with nothing known yet starts from the minimal file (the O5 batches began this way): `radius` 400,
   `paths_by_layer`, `path_radius` 30 (60 in Norway, with `default_level` "1" and `multipolygons`), one level
   `{"osm": "0", "id": "L0", "name": "Level 0", "order": 0}`, `sources` (OSM via Overpass, the date) and a
   `changelog` line. The drafter needs `levels`; everything else is optional. A batch runs as a shell loop over the
   ids (one Overpass request per station, about a minute each, with a pause between them; a 502 from Overpass is
   retried by running the same command again, since the cache file is written only on success).
2. **Draft:** `npm run stations:draft -- <id>` (the station id as in the database, colon included for Finland). The
   drafter writes `data/stations/<safe id>.json` and prints what didn't connect.
3. **Validate:** `npm run stations:validate -- --review`. Every map must pass (sources on everything, no walk across
   levels, every platform reaches an entrance). `data/stations/REVIEW.md` lists what each map still needs: platforms
   without track sides, unnamed levels, unconnected platforms, missing heights.
4. **Fix what the review lists** from sources 2–5, in the edits file, and draft again. A platform that stays
   unconnected after OSM and the plan have been read gets a hand connection with its source, or stays on the review
   list; it is never guessed.
5. **Check on screen:** open the station map in the simulator (`-open station:<id>` on a Debug build) and look at every
   level.
6. **Check positioning:** `npm run import -- position-check` prints "Standing placement" distances for trains reported
   standing at mapped platforms; a mapped station should show up there within a day of running on the hosted server.
7. **Commit by path:** the edits file, the map, `REVIEW.md`.

## Rules

- `_source` on every element; `manual:` sources name the edits file and entry.
- Level names come from the operator's plan or signage seen in a video or photo, else "Level N".
- Tracks are kept without their sector letter ("2a" is track 2); the platform's ref keeps the letter.
- When OSM tags no entrance, the drafter lets the walking network's loose ends away from the platforms (where a
  footway leaves the station area) stand in as exits, each sourced as such. That is read off OSM, not a door that was
  seen; a plan or a walk replaces them with the real entrances. A draft whose platforms still reach no exit is
  withheld (its edits file says so in the changelog) rather than shipped.
- Heights only from measurement (AR walk) or a published plan; otherwise `height_m` stays unset.
- Time constants (walking 1.3 m/s, stairs 0.55 m/s, escalator 0.75 m/s, lift 45 s + 8 s per extra level) are in the
  drafter; change them only with a measured reason (`data/walking_model.json` when it exists).
- The map says "Draft from OpenStreetMap" in the app until a walk or a plan has confirmed it (the `osm_draft` status in
  the review).
