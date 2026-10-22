# Station maps

One file per station, `<station_id>.json`, in the format of `packages/shared/src/station.ts` (ADDITIONS_01 C).

- **Made by** `npm run stations:draft -- <station_id>` (`scripts/stations/draft_from_osm.py`) from the OpenStreetMap
  extract, plus the hand edits in `scripts/stations/<station_id>.edits.json` (missing connections, level names,
  dropped objects). Edit the edits file and re-run the draft; don't hand-edit the JSON, or the next draft loses it.
- **Stations without level tags** (most smaller ones: tunnels and footbridges are only `tunnel`/`bridge` + `layer`
  in OSM) use opt-in edits keys: `paths_by_layer` (an untagged tunnel's or bridge's layer is its level, and a lift
  with no level tag serves the levels of the paths it joins), `path_radius` (untagged paths within that many metres
  of a platform are kept, not only those inside the station building), `platform_refs` (`{"<way id>": "2"}` for
  platforms OSM left unnumbered) and `drop_platform_ways`. Check a draft against the station's plan with
  `python3 scripts/stations/preview.py <station_id> [--level L0] [--labels] [--box x0 x1 y0 y1]`.
- **Checked by** `npm run stations:validate` and `npm test`: every platform and amenity must be reachable, and every
  walking edge needs seconds.
- **Shop outlines:** a place mapped in OSM as its own room (a shop's unit) keeps that outline (`outline` on the POI)
  and is drawn in its real shape; others are pins. Hand-drawn outlines go in the edits file's `outlines`
  (`[{ "poi": id, "points": [[x, y], …] }]`), or whole places with an `outline` in its `pois`.
- **Station plans the owner supplied** (Jernhusen's Stockholm C plan, January 2026; the regional transport
  authorities' terminal maps) are used, at the owner's decision (2026-10-22), for which shop is in which unit, the
  units' outlines, and for checking platforms, lifts, stairs and entrances. Each map's `sources` says which plan
  and how it was placed. Those parts are **not** covered by the ODbL below: the plans' owners haven't licensed them,
  so ask them before the maps are published beyond this demo.
- **Walking seconds** are normal pace without luggage: 1.3 m/s on foot, stairs at least 18 s a flight, escalators
  20 s, lifts 45 s. They're worked out from the map, not timed on site.

## Licence

The station maps are derived from OpenStreetMap and are made available under the
[Open Database License (ODbL) 1.0](https://opendatacommons.org/licenses/odbl/1-0/).
© OpenStreetMap contributors (https://www.openstreetmap.org/copyright). Owner's decision, 2026-10-21.
Facts checked against station operators' pages (e.g. Jernhusen) are hand-checked only, never copied in bulk.
