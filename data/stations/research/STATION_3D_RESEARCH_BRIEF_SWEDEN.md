# Research brief: measured 3D data for Sweden's hub and mid-size stations

You are repeating, for 33 Swedish stations, the research pass already done for Jönköping C. **Read the
attached playbook `STATION_3D_RESEARCH.md` first**: it is the recipe (Part 1), the rules learned the hard way, how
results go into the app (Part 2) and the code that worked (Part 3). This brief only adds the station list, the batch
order and exactly what to hand back.

## Context

Clack is a free iPhone app for train travel in Sweden, Norway, Finland and Denmark. Its Explore map and its station
view now draw stations in 3D: platforms at their height, buildings and roofs at their measured height, trains as cars
standing at their platforms. Jönköping C (`740000090`) is done. Every other station still has no measured heights.

## Hard rules (unchanged)

- **Free, openly licensed, every fact with a source.** Nothing from Google Earth, Google 3D Tiles or Apple Maps.
- **Measured or recorded, never guessed.** If no source gives a value, leave it out and say so.
- **Never infer a shape.** No floors, decks or roofs drawn round walkway points; an outline needs a source (OSM way or
  a trace from the laser).
- **Airborne laser sees tops only.** Give roof and canopy tops; mark undersides, footbridge decks and floors inside as
  unknown.
- **Trains in the scan are not structures.** Check every "canopy" over a track in a cross-section, and list the trains
  you find (`train_in_scan`).
- **No LiDAR phone.** The owner's iPhone 17 is not a Pro.
- **The laser points may be kept and handed back** (the owner decided 2026-10-30); attribution as in the playbook.

## Batch order

1. **Once, for the whole country (do this first):** read Trafikverket's JNB 2027 Bilaga 2A, tab "4.) Plattformar", and
   BanInfo's `Plattform` layer for **all** platforms of the stations below. One file for all of them (see "What to hand
   back"). This replaces per-station steps 1–2 of the playbook.
2. **Per station, in the order of the table** (hubs first): the terrain model, the laser tiles, structures, photos,
   exactly as playbook Part 1, steps 3–9. About 30–60 minutes each; stop and hand back after every 5–8 stations rather
   than at the end.
3. Stations marked "none yet" or "withheld" in the table still get the laser and terrain work; the app's station map
   will be made from OSM later, so key everything by OSM id as usual.

## The stations (33: hub and mid tier, from Clack's `data/station_tiers.json`, 2026-10-28)

| Tier | Station | Clack id | Lat, lon | Station map in the app |
|---|---|---|---|---|
| hub | Göteborg C | `740000002` | 57.70930, 11.97366 | yes |
| hub | Stockholm C | `740000001` | 59.33154, 18.05494 | yes |
| mid | Alvesta | `740000004` | 56.89891, 14.55679 | yes |
| mid | Arlanda C | `740000556` | 59.64936, 17.92857 | withheld (no walkable map yet) |
| mid | Burlöv | `740000937` | 55.64081, 13.08016 | withheld (no walkable map yet) |
| mid | Eskilstuna C | `740000170` | 59.36949, 16.50520 | yes |
| mid | Falköping C | `740000060` | 58.17597, 13.55359 | withheld (no walkable map yet) |
| mid | Flemingsberg | `740000031` | 59.21903, 17.94718 | yes |
| mid | Gävle C | `740000210` | 60.67593, 17.15112 | yes |
| mid | Hallsberg | `740000077` | 59.06666, 15.11027 | withheld (no walkable map yet) |
| mid | Herrljunga C | `740000040` | 58.07875, 13.02013 | withheld (no walkable map yet) |
| mid | Hyllie | `740001586` | 55.56279, 12.97583 | yes |
| mid | Hässleholm | `740000006` | 56.15804, 13.76327 | yes |
| mid | Jönköping C | `740000090` | 57.78428, 14.16413 | yes (has measured heights already) |
| mid | Karlstad C | `740000070` | 59.37795, 13.49800 | yes |
| mid | Katrineholm C | `740000166` | 58.99665, 16.20824 | yes |
| mid | Kil | `740000206` | 59.50480, 13.31675 | yes |
| mid | Kumla | `740000192` | 59.12626, 15.14018 | withheld (no walkable map yet) |
| mid | Linköping C | `740000009` | 58.41712, 15.62407 | yes |
| mid | Lund C | `740000120` | 55.70638, 13.18702 | yes |
| mid | Malmö C | `740000003` | 55.60878, 13.00022 | yes |
| mid | Norrköping C | `740000007` | 58.59639, 16.18439 | yes |
| mid | Nässjö C | `740000140` | 57.65263, 14.69376 | yes |
| mid | Skövde C | `740000008` | 58.39091, 13.85269 | yes |
| mid | Södertälje Syd | `740000055` | 59.16235, 17.64363 | withheld (no walkable map yet) |
| mid | Triangeln | `740001587` | 55.59428, 13.00071 | yes |
| mid | Trollhättan | `740000191` | 58.28712, 12.29867 | yes |
| mid | Uppsala C | `740000005` | 59.85859, 17.64705 | yes |
| mid | Varberg C | `740000110` | 57.11117, 12.24907 | yes |
| mid | Västerås C | `740000099` | 59.60855, 16.55350 | yes |
| mid | Örebro C | `740000133` | 59.27744, 15.21055 | yes |
| mid | Örebro S | `740000361` | 59.26957, 15.20272 | withheld (no walkable map yet) |
| mid | Öxnered | `740000173` | 58.35942, 12.27413 | yes |

## What to hand back

One folder per station named by its Clack id, the same files as the Jönköping C pack:

```
<clack id>/
  README.md                              what each file is, its licence, anything unusual at this station
  3D_SOURCES_FINDINGS.md                 values table and sources, as for Jönköping C (short is fine)
  <slug>_structures_heights.geojson      outlines + heights (format below)
  <slug>_ground_1m.tif                   ground, 1 m, EPSG:3006, RH 2000, float32 (+ the _heightmap.json)
  <slug>_ground_1m_preview.png           8-bit grey preview (never only the float GeoTIFF: it previews blank)
  <slug>_laser_station_<year>.laz        laser points clipped to the station box, original classes, trains as class 64
  <slug>_platform_trafikverket.geojson   BanInfo platform track lines with their track numbers
  photos.json                            Commons/Mapillary photos used, with author, licence, link
```

Plus, once for the batch: `trafikverket_platforms_SE.csv`, one row per platform and track:

```
clack_id,station_name,bandel,tracks,bis_object,height_class,height_m,length_m,width_m,roof,valid_from,source_row
740000090,Jönköpings central,711,"2a,2b,1",1705,mellan,0.58,497.1,8,Tak,2026-10-13,"Bilaga 2A tab 4 row 386"
```

`height_m` from the class key in Bilaga 2A tab "2.) Förklaringar" (låg 0.35, mellan 0.58, hög 0.73, TSD mellan 0.55,
TSD hög 0.76). Leave cells empty where the register has nothing.

### The structures GeoJSON (this is what the app reads; keep these property names)

One Polygon feature per structure, coordinates in WGS84 lon/lat, with:

| Property | Meaning |
|---|---|
| `kind` | `building`, `footbridge`, `canopy_osm` (an OSM roof outline), `canopy_laser` / `hall_roof_laser` (outline traced from the laser alone), `train_in_scan` |
| `osm_id` | `w<way id>` or `r<relation id>`; `null` for an outline traced from the laser |
| `name` | what it is ("station building (1983)", "platform canopy over 3"), from OSM or a photo |
| `roof_top_median_m`, `roof_top_p95_m` | roof heights, m RH 2000 (for traced roofs: `top_median_m`, `top_p10_m`, `top_p90_m`) |
| `ground_min_m`, `ground_median_m`, `ground_max_m` | ground at the outline, m RH 2000 |
| `height_above_ground_median_m`, `height_above_ground_p95_m` | for checking |
| `laser_points` | how many points the median comes from |
| `source` | one line: product, scan date, how it was derived |

And in each station's findings, **the platform surface level** (m RH 2000, from the laser, median along the platform)
and **the track bed level**: the app turns every height into metres above the platform surface with it.

### Flag, don't decide

- The laser cross-check (platform minus track bed, minus about 0.15–0.2 m) differs from Trafikverket's class by more
  than about 0.1 m.
- A roof could be a canopy or a building (Jönköping C's "canopy" over 2b was the glazed waiting hall).
- A structure's p95 is far above its median (often a taller neighbour's points inside the outline).
- Anything you could not get, and why (access, coverage, a tile missing).

## Part 2: what is at the station (the same pass, the same sources)

While you are at each station, also collect what the app's **station map** needs (the walking map with levels,
platforms, stairs, lifts, shops and their hours). It shares sources with the 3D work, so it costs little extra. The
attached `STATION_OPEN_QUESTIONS_SWEDEN.md` lists, per station, what the current map is missing or unsure of (from
Clack's review queue): start there, it is the most useful order.

**Find, each with a source and the date read:**

- **Levels:** their real names as signposted ("Plan 0", "Gångbron", "Nedre plan") and which level each platform,
  entrance and shop is on. Heights only if a source measures them.
- **Platforms:** which side serves which track and sector (2a/2b), where OSM is unsure. Trafikverket's PlatformLine /
  TrackAtLocation and BanInfo give the numbers; a plan or photo gives the side.
- **Ways between levels and to the platforms:** stairs, lifts, escalators, ramps, underpasses and footbridges, and
  which platforms each one reaches. Lifts matter most (step-free routes). Say whether a lift or escalator is confirmed
  by a photo or plan, or only in OSM.
- **Entrances** that OSM lacks, with the street they open to.
- **Amenities:** toilets (and whether they cost), lockers, ticket machines and offices, waiting rooms, cafés, kiosks,
  shops, pharmacy, ATM, parking, taxi and bus stops. For each: name, level, roughly where (next to which platform or
  entrance; never invent coordinates), and **opening hours with their source and the date checked**. Shops' own
  websites and the station owner's page (Jernhusen, the municipality, the regional transport authority) are the usual
  sources; OSM's `opening_hours` counts only if you say it is OSM's.
- **Station plans** published by the operator or owner (Trafikverket, Jernhusen, regional transport authorities like
  JLT, Skånetrafiken, SL). Use them for facts only (what is where); don't copy or trace them, and record their
  licence (most aren't open: then only the facts, cited).

**Hand back, per station, in the same folder:** `station_facts.json`:

```json
{
  "levels": [{ "osm_level": "1", "name": "Gångbron", "_source": "photo commons:12345 (sign), 2026-10-31" }],
  "platform_sides": [{ "platform": "2", "track": "2a", "side": "north", "_source": "..." }],
  "connections": [{ "kind": "lift", "between": ["platform 2", "Gångbron"], "where": "east end of platform 2", "confirmed_by": "photo", "_source": "..." }],
  "entrances": [{ "name": "Juneporten", "street": "...", "level": "1", "where": "...", "_source": "..." }],
  "amenities": [{ "category": "toilet", "name": "Toaletter", "fee": "free", "level": "0", "where": "in the hall, by entrance A",
                  "opening_hours": "Mo-Su 05:00-24:00", "hours_source": "website", "hours_checked": "2026-10-31", "_source": "https://..." }],
  "plans": [{ "title": "...", "publisher": "...", "url": "...", "licence": "not open: facts only", "read": "2026-10-31" }],
  "open": ["what couldn't be settled, and why"]
}
```

`opening_hours` in OSM's opening-hours syntax. Keep `where` as words; the app places things on its map from OSM and
the owner's walks.

## Scope

Sweden only. Norway, Finland and Denmark need their own research pass later; don't carry the Swedish answers over.
