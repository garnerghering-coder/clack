# Station 3D research: the playbook

How to find, check and bring in the measured 3D facts for a station (heights of platforms, buildings, roofs and the
ground), written from the Jönköping C pass of 2026-10-29/30 so it can be repeated at any Swedish station. It sits beside
`docs/STATION_MAPPING.md` (how a station map is made); this is the 3D layer on top. The Jönköping C log, findings and
files are in `data/stations/research/740000090/` (`RESEARCH_LOG.md`, `3D_SOURCES_FINDINGS.md`).

Part 1 is the recipe. Part 2 says how the results go into the repo. Part 3 is the code.

**Scope: Sweden only.** Norway, Finland and Denmark have their own mapping agencies and infrastructure managers; each
needs one research pass of its own (what is open, under what terms, what records platform heights) before its stations
are done this way. Don't assume the Swedish answers carry over.

---

## Part 1 — Recipe for the next station

### What you need once
- A free **Geotorget account** (Lantmäteriet) with two permissions ordered at 0 kr: *Laserdata Nedladdning, skog* and
  *Markhöjdmodell Nedladdning*. Done for this account on 2026-10-29 (cases LM2026/164214, LM2026/164215). Permissions sit on the
  account, so they cover every station.
- A browser (here: Claude in Chrome) logged in to Geotorget. The laser files need the Geotorget username and password at an HTTP
  login prompt; once entered, the browser session can read them.
- No account is needed for Trafikverket's BanInfo map service or the Network Statement spreadsheets.
- **Planned, once for the whole country:** steps 1–2 are the same file and service for every station. A script reading
  Bilaga 2A (or BanInfo) once, mapping Trafikverket's station names to Clack's station ids, would set platform height,
  roof and width everywhere. Until it exists, do steps 1–2 per station.

### Per station, in this order (about 30–60 minutes)

| # | Step | Source | Gives | Time |
|---|---|---|---|---|
| 1 | Find the station's row(s) in **JNB Bilaga 2A**, tab "4.) Plattformar" | Trafikverket Network Statement xlsx | Height class, recorded length, roof (Tak/Skydd/Saknas), safety markings, tracks | 2 min |
| 2 | Query **BanInfo WMS** layer `Plattform` with GetFeatureInfo around the station; then `Sparnummer` to name the tracks | Trafikverket, CC0 | Per-platform: height, width, edge material, surface, roof, km range, track-line geometry per track | 10 min |
| 3 | Query **Lantmäteriet STAC** for items intersecting the station | `api.lantmateriet.se/stac-hojd/v1` | Scan date, flight height, density, which 2.5 km laser tiles and which DTM tile | 2 min |
| 4 | Read the **terrain model** (COG) around the station | STAC collection `dtm-cog` | Track-bed height, ground range, slope, profiles | 10 min |
| 5 | Download the 2.5 km **laser tiles** covering the station (browser, Geotorget login) and decode with `laspy[lazrs]` (Part 3.7–3.8) | STAC collection `dsm-skoglig-copc` | Platform surface and track bed, roof heights, canopy heights and footprints, footbridge | 30 min |
| 6 | Search **Wikimedia Commons** by geosearch (400 m) and keyword | Commons API | Photo evidence: canopies, footbridges, stairs, lifts | 10 min |
| 7 | Look at **Mapillary** around the station | mapillary.com/app | Street-level photos and their dates | 5 min |
| 8 | Match every traced roof to a footprint **and** a photo before naming it (canopy, hall, footbridge, train) | OSM + Commons | Correct labels | 10 min |
| 9 | Record everything with source, date and licence | — | Findings file | 10 min |
| 10 | **Write the results into the repo** (Part 2): the edits file, redraft, validate, look at it in the 3D view | — | The station map with measured heights | 20 min |
| 11 | Build the **station pack**: clipped LAZ, ground GeoTIFF + heightmap, block model GLB, station JSON, renders, cross-sections, photos with credits; publish as one page (Part 3.9) | all of the above | Files the app loads directly | 45 min |

### Rules learned the hard way
- **Height classes** (from Bilaga 2A, tab "2.) Förklaringar"): låg 0.35 m, mellan 0.58 m, hög 0.73 m, TSD mellan 0.55 m,
  TSD hög 0.76 m. These are recorded design classes, not surveyed heights.
- **Bilaga 2A lengths can be combined** across several tracks in one row (Jönköping C: one 497.1 m row for tracks 2a, 2b and 1).
  BanInfo splits them per track link.
- **BanInfo geometry is the track line**, not the platform edge. BIS objects are linearly referenced to track links.
- **BanInfo host is `geo-baninfo` with a hyphen.** The service description PDF renders without it, and that host does not resolve.
- **The terrain model's flat 88.8 m (or any constant) next to a station is a lake surface**, not ground.
- **Laser tiles named `y…_25` are 2.5 km tiles per scan block**; a station on a tile edge may need four of them. Small file size
  can just mean most of the tile is water.
- **Lantmäteriet's laser data is CC BY 4.0 + GDPR terms since 1 June 2026**, not CC0. Older pages and the OSM wiki still say CC0.
- **Trains standing at the platform show up as roofs.** At Jönköping C two trains were parked during the scan; one was first
  mistaken for a canopy. Check every "canopy" in a cross-section: a train roof sits about 3.8–4.2 m above the track bed, directly
  over a track (outside the platform edges), with the ground hidden underneath. Canopies sit over the platform itself.
- **Laser classes in this product:** 1 unclassified (roofs, canopies, trains, trees, wires), 2 ground, 7 low noise, 9 water,
  17 bridge, 18 high noise. There is no building class, so use footprints (OSM) or raster clustering.
- **A high "canopy" may be a building.** At Jönköping C the 6.1 m roof over platform 2b is the 2001 glazed waiting hall, tagged
  in OSM only as *Jönköpings bussterminal*. Check the OSM footprint and a platform-level photo before calling a roof a canopy.
- **The workspace usually cannot reach Commons, Trafikverket or Lantmäteriet.** Do the fetching in the browser. To bring images
  into the workspace, open each image at a known size in Chrome, take a screenshot saved to disk at scale 1, and crop the
  letterbox using the image's aspect ratio (the Jönköping C log, step 17). Check each photo's pageid against the Commons API afterwards.
- **Published pages only serve web file types.** Binary data (.bin, .glb) is refused; ship it base64-encoded as `.txt` and decode
  in the page (Part 3.9).
- **Platform height from laser** is measured against the ballast/sleeper surface, not the rail head. Expect ~0.15–0.2 m more
  than the platform-above-rail value; treat it as a cross-check.
  If the two disagree by more than about 0.1 m, add the platform to `data/stations/REVIEW.md` with both values rather
  than pick one (operators have reported wrong register heights, e.g. Kungsbacka and Uddevalla).
- **Previews must be 8-bit.** A float GeoTIFF of heights (88–97 m) shows as a blank white image in viewers and chat
  previews. Make a scaled preview with `python3 scripts/stations/terrain_preview.py <file.tif>`; it is for looking at,
  never data.
- **Never draw what was inferred.** A floor drawn as a hull round walkway points looked like a real deck and wasn't
  (owner, 2026-10-30). A floor, roof or building goes in only with an outline from a source. At Jönköping C the "upper
  level" is the town's ground, which the terrain gives.
- **Walk marks are ±10 m.** A stair or escalator between two marks can come out 50 m long; the 3D view draws such a flight
  at 30° from its upper end. Measure positions better (photos, a closer walk) before trusting a ramp's length.
- **Airborne laser sees tops only.** Roof and canopy tops are measured; undersides, footbridge decks and floors inside
  are not. Store the top (`top_m`) and say the rest is unknown; don't fill it in.


---

## Part 2 — Into the repo

The app builds its 3D view from the station map (`data/stations/<id>.json`), not from the pack's model, so every
measured fact goes into the station's edits file and through the drafter (`scripts/stations/draft_from_osm.py`).

**Heights are metres above the platform surface** (the reference level, 0), the convention of `height_m` on levels.
Take the platform surface from the laser (Jönköping C: 91.67 m RH 2000) and subtract it from every RH 2000 value; keep
the RH 2000 figures in the `_source` text.

Keys in `scripts/stations/<id>.edits.json`:

- `platform_heights`: `{"<ref>": {"height_m": 0.58, "_source": "…BIS object, class, JNB row…"}}` per platform number.
- `structures_file` + `structures`: buildings and roofs with measured heights. `structures_file` is the research
  GeoJSON of outlines (`data/stations/research/<id>/…_structures_heights.geojson`); each entry names a feature by OSM id
  (`"from": "w81576737"`) or, for an outline traced from the laser alone, its `kind` (`"hall_roof_laser"`), and gives
  `kind` (`building` or `roof`), `name`, `top_m` (roof-top median minus the platform surface), `base_m` for buildings
  (lowest ground at the outline minus the platform surface) and `_source` (outline, point count, the product line). A
  structure replaces the drafter's own shape for the same OSM way.
- `terrain`: `{"geotiff": "data/stations/research/<id>/…_ground_1m.tif", "reference_m": 91.67, "step_m": 5,
  "_source": "…"}`. The drafter samples the ground every 5 m over the map's extent into `terrain` in the map.
- `sources`: one entry per product, `type` `lantmateriet` or `trafikverket`, with licence and the attribution line.
- `changelog`: what changed, dated.

For a pack built by `scripts/stations/station3d/` (the batch pipeline, see `data/stations/research/HANDOFF_STATION_3D.md`),
`python3 scripts/stations/station3d/to_edits.py <id>` writes all of the above from the pack and the Trafikverket CSV
(the longest register row per track; footbridges from the 5.9 m minimum clearance; `hall_roof_laser`, road bridges and
trains left out for a look). A station whose map is still schema 1 needs its schema-2 redraft first (entrances!).

Then `python3 scripts/stations/draft_from_osm.py <id>`, `npx tsx scripts/stations/validate.ts`, and open the station in
the 3D view (`-open map:<id> -station3D`, Debug). Keep the pack (laser LAZ, ground GeoTIFF, GeoJSONs, station JSON, model,
`photos.json`) in `data/stations/research/<id>/` with a README listing each file's licence. The points are ours to keep
and use under the terms (owner, 2026-10-30).

**Attribution in the app.** The 3D view's panel credits OpenStreetMap (ODbL), Lantmäteriet ("Laserdata Nedladdning,
skog, © Lantmäteriet, bearbetad, CC BY 4.0") whenever the map has a `lantmateriet` source, and Trafikverket for platform
heights. Never upload Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

---

## Part 3 — Code used (browser JavaScript, no external libraries)

### 3.1 Read an xlsx in the page
```js
const buf = new Uint8Array(await (await fetch(XLSX_URL)).arrayBuffer());
const dv = new DataView(buf.buffer);
let eocd = buf.length - 22; while (dv.getUint32(eocd, true) !== 0x06054b50) eocd--;
const n = dv.getUint16(eocd + 10, true); let p = dv.getUint32(eocd + 16, true); const files = {};
for (let i = 0; i < n; i++) {
  const method = dv.getUint16(p + 10, true), csize = dv.getUint32(p + 20, true),
        fnl = dv.getUint16(p + 28, true), exl = dv.getUint16(p + 30, true), cml = dv.getUint16(p + 32, true),
        lho = dv.getUint32(p + 42, true);
  files[new TextDecoder().decode(buf.slice(p + 46, p + 46 + fnl))] = { method, csize, lho };
  p += 46 + fnl + exl + cml;
}
async function read(name) {
  const f = files[name], l = f.lho, off = l + 30 + dv.getUint16(l + 26, true) + dv.getUint16(l + 28, true);
  const data = buf.slice(off, off + f.csize);
  if (f.method === 0) return new TextDecoder().decode(data);
  return new Response(new Blob([data]).stream().pipeThrough(new DecompressionStream('deflate-raw'))).text();
}
// then parse xl/workbook.xml, xl/_rels/workbook.xml.rels, xl/sharedStrings.xml and xl/worksheets/sheetN.xml with regex
```

### 3.2 BanInfo platform query (run from a page on geo-baninfo.trafikverket.se, e.g. a GetMap URL)
```js
const base = '/mapservice/wms.axd/BanInfo_1_5?SERVICE=WMS&VERSION=1.1.1&SRS=EPSG:4326'
  + '&BBOX=' + [W, S, E, N].join(',') + '&WIDTH=1200&HEIGHT=800&STYLES=';
// 1) render the Plattform layer and find coloured pixels
const img = new Image(); img.src = base + '&REQUEST=GetMap&LAYERS=Plattform&FORMAT=image/png&TRANSPARENT=TRUE';
await img.decode();
// draw to a canvas, collect [x,y] where alpha > 100, stepping 15 px in x
// 2) for each pixel:
const html = await (await fetch(base + `&REQUEST=GetFeatureInfo&LAYERS=Plattform&QUERY_LAYERS=Plattform`
  + `&INFO_FORMAT=text/html&X=${x}&Y=${y}&FEATURE_COUNT=10`)).text();
// parse with DOMParser; attributes appear as "cab:<Name><value>"; geometry after "Points"
// 3) same with LAYERS=Sparnummer to get track numbers (IndKod_beskr "Spår nr 2a")
```

### 3.3 STAC search (run from a page on api.lantmateriet.se)
```js
const r = await fetch('/stac-hojd/v1/search', { method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ intersects: { type: 'Point', coordinates: [LON, LAT] }, limit: 20 }) });
const items = (await r.json()).features;   // collection, properties (datetime, pc:count, punkttathet, flyghojd…), assets.data.href
// protected files: fetch(href, { credentials: 'include', headers: { Range: 'bytes=0-1023' } })  → 206 after login
```

### 3.4 Read the DTM COG (deflate + floating-point predictor)
```js
// parse IFD (tags 256/257 size, 259 compression, 317 predictor, 322/323 tile size, 324/325 tile offsets/bytecounts,
// 33922 tiepoint, 42113 nodata), then per tile:
const raw = new Uint8Array(await new Response(new Blob([tileBytes]).stream()
  .pipeThrough(new DecompressionStream('deflate'))).arrayBuffer());
const W = 512, out = new Float32Array(W * 512), tmp = new DataView(new ArrayBuffer(4));
for (let r = 0; r < 512; r++) {
  const row = raw.subarray(r * W * 4, (r + 1) * W * 4);
  for (let j = 1; j < row.length; j++) row[j] = (row[j] + row[j - 1]) & 255;      // undo byte differencing
  for (let x = 0; x < W; x++) { for (let b = 0; b < 4; b++) tmp.setUint8(b, row[b * W + x]); out[r * W + x] = tmp.getFloat32(0, false); }
}
// pixel for (E, N): col = floor(E - 450000), row = floor(6410000 - N) for tile 640_45
```

### 3.5 WGS84 → SWEREF 99 TM (Lantmäteriet Gauss–Krüger)
```js
function tm(lat, lon) {
  const a = 6378137, f = 1 / 298.257222101, lon0 = 15, k0 = 0.9996, FE = 500000;
  const e2 = f * (2 - f), n = f / (2 - f), ah = a / (1 + n) * (1 + n * n / 4 + n ** 4 / 64);
  const A = e2, B = (5 * e2 * e2 - e2 ** 3) / 6, C = (104 * e2 ** 3 - 45 * e2 ** 4) / 120, D = 1237 * e2 ** 4 / 1260;
  const b1 = n / 2 - 2 * n * n / 3 + 5 * n ** 3 / 16 + 41 * n ** 4 / 180, b2 = 13 * n * n / 48 - 3 * n ** 3 / 5 + 557 * n ** 4 / 1440,
        b3 = 61 * n ** 3 / 240 - 103 * n ** 4 / 140, b4 = 49561 * n ** 4 / 161280;
  const r = Math.PI / 180, ph = lat * r, dl = (lon - lon0) * r, s = Math.sin(ph);
  const ps = ph - s * Math.cos(ph) * (A + B * s * s + C * s ** 4 + D * s ** 6);
  const xi = Math.atan(Math.tan(ps) / Math.cos(dl)), eta = Math.atanh(Math.cos(ps) * Math.sin(dl));
  const N = k0 * ah * (xi + b1 * Math.sin(2 * xi) * Math.cosh(2 * eta) + b2 * Math.sin(4 * xi) * Math.cosh(4 * eta)
          + b3 * Math.sin(6 * xi) * Math.cosh(6 * eta) + b4 * Math.sin(8 * xi) * Math.cosh(8 * eta));
  const E = k0 * ah * (eta + b1 * Math.cos(2 * xi) * Math.sinh(2 * eta) + b2 * Math.cos(4 * xi) * Math.sinh(4 * eta)
          + b3 * Math.cos(6 * xi) * Math.sinh(6 * eta) + b4 * Math.cos(8 * xi) * Math.sinh(8 * eta)) + FE;
  return [E, N];
}
```

### 3.6 COPC header and hierarchy (no decompression needed)
```js
// header: 375 bytes (LAS 1.4); point format at 104, record length 105, scale 131/139/147, offset 155/163/171,
// bounds 179–226, point count (uint64) 247. COPC info VLR content at 375+54:
// centre x,y,z (f64), halfsize (f64), spacing (f64), root_hier_offset (u64), root_hier_size (u64).
// Each 32-byte hierarchy entry: depth,x,y,z (i32), offset (u64), byteSize (i32), pointCount (i32).
// Node extent: side = 2*halfsize / 2**depth; x0 = cx - halfsize + x*side; y0 = cy - halfsize + y*side.
```

### 3.7 Decode the point cloud (Python)
```python
# pip install "laspy[lazrs]"
import laspy, numpy as np
las = laspy.read("y22b007-64025_4500_25.copc.laz")
m = (las.x > 450000) & (las.x < 450600) & (las.y > 6404900) & (las.y < 6405150)
pts = np.c_[las.x[m], las.y[m], las.z[m]]; cls = np.asarray(las.classification)[m]
# subtract a ground grid built from class 2 (+9) points; unclassified (class 1) points > 2.5 m above ground inside a building
# outline → roof height; over the platform → canopy height and footprint
```

### 3.8 Along/across-track coordinates and train filter (Python)
```python
from shapely.geometry import LineString, Point
L = LineString(track2_xy)                      # Trafikverket track line in SWEREF 99 TM
def sd(px, py):
    si = L.project(Point(px, py))
    p0, p1 = L.interpolate(max(si - 1, 0)), L.interpolate(min(si + 1, L.length))
    tx, ty = p1.x - p0.x, p1.y - p0.y; n = (tx*tx + ty*ty) ** .5; q = L.interpolate(si)
    return si, (px - q.x) * (-ty / n) + (py - q.y) * (tx / n)   # s along, d across (+ = left of travel direction)
# platform between d = -8.2 and -2.2 at Jönköping C; drop "canopy" points over a track at train-roof height:
is_train = ((d > -2.2) | (d < -8.2)) & (z <= track_bed + 4.5)
```

### 3.9 Station pack outputs (Python)
```python
# Compact point cloud for the web (8 bytes/point)
import numpy as np
oE, oN = 450030, 6404930
rec = np.zeros(n, dtype=[('x','<u2'),('y','<u2'),('z','<u2'),('c','u1'),('i','u1')])
rec['x'] = np.round((x - oE) * 10); rec['y'] = np.round((y - oN) * 10); rec['z'] = np.round((z - 88) * 100)
rec['c'] = np.where(is_train, 64, cls); rec['i'] = np.clip(intensity / intensity.max() * 255, 0, 255)
rec.tofile('pointcloud_station.bin')

# Block model: extrude a footprint (SWEREF) between two heights into a local y-up frame
import trimesh, shapely.geometry as sg
O = (450294.6, 6405002.8, 90.0)
def block(poly_xy, z0, z1, name):
    m = trimesh.creation.extrude_polygon(sg.Polygon([(x - O[0], y - O[1]) for x, y in poly_xy]), z1 - z0)  # needs mapbox_earcut
    m.apply_translation([0, 0, z0 - O[2]])
    m.apply_transform(trimesh.transformations.rotation_matrix(-np.pi / 2, [1, 0, 0]))  # z-up -> y-up, north -> -z
    m.metadata['name'] = name; return m
scene = trimesh.Scene(); # scene.add_geometry(block(...), node_name='waiting_hall') ...
scene.export('jonkoping_c_model.glb')

# Ground GeoTIFF + 16-bit heightmap
import rasterio; from rasterio.transform import from_origin
with rasterio.open('jonkoping_c_ground_1m.tif', 'w', driver='GTiff', height=H, width=W, count=1, dtype='float32',
                   crs='EPSG:3006', transform=from_origin(450030, 6405120, 1, 1), compress='deflate') as d: d.write(grid, 1)
from PIL import Image; Image.fromarray(np.round((grid - 85) * 1000).astype('uint16')).save('jonkoping_c_ground_1m_heightmap.png')
```
```javascript
// In the published page: binaries ship as base64 .txt
function b64buf(s){const b=atob(s.trim()),u=new Uint8Array(b.length);for(let i=0;i<b.length;i++)u[i]=b.charCodeAt(i);return u.buffer}
fetch('jonkoping_c_model.b64.txt').then(r=>r.text()).then(b64buf).then(buf=>new THREE.GLTFLoader().parse(buf,'',onLoad,onError));
```

---

## Sources
- Lantmäteriet: [laser terms 2026-05-20](https://www.lantmateriet.se/globalassets/geodata/geodataprodukter/anvandningsvillkor-for-laserdata-nedladdning-skog.pdf) ·
  [STAC change notice 2026-05-29](https://www.lantmateriet.se/sv/geodata/vara-produkter/Produktnyheter/Geografisk-information/uppdatering-angaende-tillhandahallandet-av-laserdata-nedladdning-skog/) ·
  [high-value terms with personal data](https://www.lantmateriet.se/globalassets/geodata/geodataprodukter/anvandningsvillkor_for_vardefulla_datamangder_pu.pdf) ·
  [Villkor och avgifter](https://www.lantmateriet.se/sv/geodata/vara-produkter/Villkor-och-avgifter/) ·
  [Building Download product description](https://www.lantmateriet.se/globalassets/geodata/geodataprodukter/e-pb-byggnad-nedladdning-vektor.pdf) ·
  [Kvalitetsbeskrivning laserdata](https://www2.lantmateriet.se/globalassets/geodata/geodataprodukter/hojddata/kvalitetsbeskrivning_laserdata.pdf) ·
  [Radiant Earth guide](https://www.lantmateriet.se/contentassets/6b85c93c6954407e855c896da5a415f2/guide_radiant_earth_laserdata_nedladdning_skog.pdf) ·
  [Geotorget](https://geotorget.lantmateriet.se/) · STAC `https://api.lantmateriet.se/stac-hojd/v1`
- Trafikverket: [BanInfo description 1.17](https://bransch.trafikverket.se/contentassets/673d929ff8d147f6b9b694a7b8059f9f/baninfo_tjanstebeskr_1_17.pdf) ·
  [JNB 2027 page](https://bransch.trafikverket.se/for-dig-i-branschen/jarnvag/jarnvagsnatsbeskrivningen-jnb/jarnvagsnatsbeskrivning-2027/) ·
  [Bilaga 2A xlsx](https://bransch.trafikverket.se/contentassets/05cfe3edce764ca4b2a3c53b4ed9a69c/bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx) ·
  [JNB 2027 consultation responses](https://bransch.trafikverket.se/contentassets/9a597b4de2ba4013985f0d345181534c/redovisning-av-samradssvar-om-jarnvagsnatsbeskrivning-2027.pdf) ·
  [INSPIRE TN description](https://bransch.trafikverket.se/contentassets/f4d7a64a5cb84b6f919d5e4645e868c7/tjanstebeskrivning_inspire_tn_giltig-version.pdf) ·
  [BanInfo endpoint in Länsstyrelsen catalogue](https://ext-geodatakatalog-forv.lansstyrelsen.se/PlaneringsKatalogen/GetMetaDataById?id=3d5bfbbe-de59-4a91-b01e-0c9f11219fb6_C) ·
  [Spatineo BanInfo](https://directory.spatineo.com/service/23290/) · [JNB karta](https://jnbkarta.trafikverket.se/?year=2027)
- Jönköpings kommun: [Kartprodukter](https://www.jonkoping.se/kommun--politik/fakta-kartor-och-statistik/kartor-och-geografisk-information/kartprodukter) ·
  [Öppna geodata](https://data-jonkoping.opendata.arcgis.com/)
- OSM: [Öppna data från Lantmäteriet, page 8](https://community.openstreetmap.org/t/oppna-data-fran-lantmateriet/72615?page=8)
- Phone: [Scargill et al.](https://par.nsf.gov/servlets/purl/10358173) · [eeNews Europe BMP380](https://www.eenewseurope.com/en/barometric-pressure-sensor-accurate-altitude-tracking-for-consumer-devices/) ·
  [Vanini et al.](https://cse.usf.edu/~mlabrador/Share/workshops/papers/p2-vanini.pdf)
- Trains: [SJ X40](https://en.wikipedia.org/wiki/SJ_X40) · [X61](https://en.wikipedia.org/wiki/X61_(railcar)) ·
  [Bombardier Itino](https://en.wikipedia.org/wiki/Bombardier_Itino) · [Mediarail X2000](https://ledicoferroviaire.mediarail.be/x2c-x2000-en/) ·
  [Mediarail Krösatågen](https://ledicoferroviaire.mediarail.be/krosatagen-en/)
- Station: [sv.wikipedia Jönköpings resecentrum](https://sv.wikipedia.org/wiki/J%C3%B6nk%C3%B6pings_resecentrum) ·
  Wikimedia Commons files listed in the findings report · Mapillary image 238630658055349
