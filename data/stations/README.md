# Station maps

One file per station, `<station_id>.json`, in the format of `packages/shared/src/station.ts` (ADDITIONS_01 C).

- **Made by** `npm run stations:draft -- <station_id>` (`scripts/stations/draft_from_osm.py`) from the OpenStreetMap
  extract, plus the hand edits in `scripts/stations/<station_id>.edits.json` (missing connections, level names,
  dropped objects). Edit the edits file and re-run the draft; don't hand-edit the JSON, or the next draft loses it.
- **Checked by** `npm run stations:validate` and `npm test`: every platform and amenity must be reachable, and every
  walking edge needs seconds.
- **Shop outlines:** a place mapped in OSM as its own room (a shop's unit) keeps that outline (`outline` on the POI)
  and is drawn in its real shape; others are pins. Hand-drawn outlines go in the edits file's `outlines`
  (`[{ "poi": id, "points": [[x, y], …] }]`), only from a source we may use (a survey, or a plan whose owner agreed).
- **Walking seconds** are normal pace without luggage: 1.3 m/s on foot, stairs at least 18 s a flight, escalators
  20 s, lifts 45 s. They're worked out from the map, not timed on site.

## Licence

The station maps are derived from OpenStreetMap and are made available under the
[Open Database License (ODbL) 1.0](https://opendatacommons.org/licenses/odbl/1-0/).
© OpenStreetMap contributors (https://www.openstreetmap.org/copyright). Owner's decision, 2026-10-21.
Facts checked against station operators' pages (e.g. Jernhusen) are hand-checked only, never copied in bulk.
