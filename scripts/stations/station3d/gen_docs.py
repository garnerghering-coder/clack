"""Write README.md and 3D_SOURCES_FINDINGS.md for one station pack from its _report.json and files.

Usage: python3 gen_docs.py <pack dir> <station name> [extra notes markdown file]
"""
import json, sys, os, glob

P, NAME = sys.argv[1], sys.argv[2]
extra = open(sys.argv[3]).read().strip() if len(sys.argv) > 3 and os.path.exists(sys.argv[3]) else ''
r = json.load(open(f'{P}/_report.json'))
slug, cid = r['slug'], r['clack_id']
S = json.load(open(f'{P}/{slug}_structures_heights.geojson'))
ph = json.load(open(f'{P}/photos.json'))['photos']
las = r['laser']
laz = os.path.basename(glob.glob(f'{P}/*_laser_station_*.laz')[0])
REF, BED = r['platform_surface_m'], r['track_bed_m']
fmt = lambda v, n=2: '–' if v is None else f'{v:.{n}f}'
scan_block = las['tiles'][0].split('-')[0].lstrip('y') if las['tiles'] else '?'
LM = 'Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0'

def size(f):
    b = os.path.getsize(f'{P}/{f}')
    return f'{b / 1e6:.1f} MB' if b > 1e6 else f'{b / 1e3:.0f} kB'

readme = f"""# {NAME} (`{cid}`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E {r['ground']['box_sweref'][0]}–{r['ground']['box_sweref'][2]}, N {r['ground']['box_sweref'][1]}–{r['ground']['box_sweref'][3]}
({r['ground']['size_m'][0]} × {r['ground']['size_m'][1]} m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `{slug}_structures_heights.geojson` ({size(slug + '_structures_heights.geojson')}) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: {LM} |
| `{slug}_ground_1m.tif` ({size(slug + '_ground_1m.tif')}) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model {', '.join(r['ground']['tiles'])}) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `{slug}_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `{slug}_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `{laz}` ({size(laz)}) | Laser points clipped to the station box, original classes, **trains as class 64** ({las['train_points_class64']} points) | {LM} |
| `{slug}_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).
"""
unusual = [x for x in r['notes']] + ([extra] if extra else [])
if unusual:
    readme += '\n## Unusual at this station\n\n' + '\n'.join(f'- {x}' for x in unusual) + '\n'
open(f'{P}/README.md', 'w').write(readme)

rows = []
for p in r['platforms']:
    rows.append(f"| {p['bis_object']} | {p['track'] or '?'} | {p['height_class']} ({fmt(p['class_height_m'])}) | {fmt(p['length_m'], 1)} | {fmt(p['width_m'], 1)} | {p['roof']} "
                f"| {fmt(p['track_bed_m'])} | {fmt(p['platform_surface_m'])} | {fmt(p.get('surface_minus_bed_m'))} | {fmt(p.get('laser_estimate_above_rail_m'))} | {p.get('note', '')} |")
srows = []
for f in S['features']:
    q = f['properties']
    top = q.get('roof_top_median_m', q.get('top_median_m'))
    p95 = q.get('roof_top_p95_m', q.get('top_p90_m'))
    srows.append(f"| {q['kind']} | {q['osm_id'] or '(laser)'} | {q['name']} | {fmt(top)} | {fmt(p95)} | {fmt(q.get('ground_min_m'))} | "
                 f"{fmt(q.get('top_above_platform_m', None) if q['kind'] != 'train_in_scan' else q.get('top_above_track_bed_m'))} | {q.get('laser_points', 0)} |")
trains = [f for f in S['features'] if f['properties']['kind'] == 'train_in_scan']
rel = [p for p in ph if p.get('station_related')]
find = f"""# {NAME} (`{cid}`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **{fmt(REF)}** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **{fmt(BED)}** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | {fmt(r['ground']['min_m'])} – {fmt(r['ground']['max_m'])} (median {fmt(r['ground']['median_m'])}) | terrain model {', '.join(r['ground']['tiles'])} |

Every height in the structures file becomes metres above the platform by subtracting {fmt(REF)}.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: {scan_block}, scanned {las['scan_date']}. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
""" + '\n'.join(rows) + f"""

## Structures

`{slug}_structures_heights.geojson`, {len(S['features'])} features: {', '.join(f'{v} {k}' for k, v in r['structures'].items() if v)}.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
""" + '\n'.join(srows) + f"""

## Trains in the scan

{len(trains)} found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

""" + ('\n'.join(f'- {x}' for x in r['flags']) if r['flags'] else '- none') + f"""

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: {len(ph)} files found ({len(rel)} station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date {las['scan_date']}: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- {LM}. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles {', '.join(las['tiles'])}
  (scan {las['scan_date']}, nominal {las['density_pts_m2_nominal']} points/m², flight height {las['flight_height_m']} m; {las['points_in_box']:,} points in the box,
  {las['density_in_box']} per m²; classes {las['classes']}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles {', '.join(r['ground']['tiles'])}, read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap ({r.get('osm_source', 'Overpass API')}, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
"""
open(f'{P}/3D_SOURCES_FINDINGS.md', 'w').write(find)
print('ok', len(rows), 'platforms', len(srows), 'structures')
