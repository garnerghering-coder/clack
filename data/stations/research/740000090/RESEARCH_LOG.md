# Jönköping C 3D research: full log

The step-by-step log and every finding of the research pass of 2026-10-29/30, moved here from the playbook
(`docs/STATION_3D_RESEARCH.md`) so that one stays a recipe. Findings report: `3D_SOURCES_FINDINGS.md`.

## Full log, in order

### Step 1. Read the brief
Brief `attachment.txt`: build open, accurate 3D data for Jönköping C (740000090, 57.7843 N, 14.1641 E). Hard rules: free, openly
licensed, mixable with OSM (ODbL), nothing from Google Earth/3D Tiles or Apple Maps, every fact sourced, no LiDAR phone.
Ten questions across Lantmäteriet, Trafikverket, the municipality, photos, the iPhone, trains and licences.

### Step 2. Lantmäteriet laser data — web search
- Searches: "Lantmäteriet Laserdata Nedladdning öppna data CC0", "Byggnad Nedladdning vektor öppna data höjd",
  "Markhöjdmodell Nedladdning grid 1 m öppna data".
- English product pages and the OSM forum still said **CC0**, 1–2 points/m², classes ground/water/bridge/low noise/high noise/
  unclassified, LAZ, SWEREF 99 TM.
- A search result surfaced **new terms dated 2026-05-20** (`anvandningsvillkor-for-laserdata-nedladdning-skog.pdf`). Fetched in
  full: CC BY 4.0; attribution = product name, ©Lantmäteriet, "bearbetad" if processed, CC BY 4.0; may go in documentation if not
  practical next to the data; licensee is GDPR data controller; Lantmäteriet may close access.
- An extended search found the **2026-05-29 news item**: from 1 June 2026 the product is delivered only via a STAC API, LAZ as COPC,
  10 × 10 km tiles (from 2.5 km), ordered as a permission on Geotorget with new terms; laser data is now treated as personal data;
  old download links ended 31 May. Some metadata to follow in autumn.
- Quality description (`kvalitetsbeskrivning_laserdata.pdf`, 2022): absolute height error under 0.1 m on open, flat, hard surfaces.
- Scan programme: started 2018, second round 2018–2024, third round started 2024.

### Step 3. Lantmäteriet buildings and terrain — documents
- **Byggnad Nedladdning, vektor**: product description v1.8 (EN, 2024-02-28) read in full. Attributes per building polygon:
  objektidentitet, versiongiltigfran, lagesosakerhetplan, lagesosakerhethojd, ursprunglig_organisation, objektversion, objekttypnr,
  objekttyp, insamlingslage (Fasad/Takkant/Illustrativt läge/Ospecificerad), byggnadsnamn1–3, husnummer, huvudbyggnad,
  andamal1–5. **No height, no floor count.** Purpose value list includes "Järnvägsstation". Planar error 0.02–50 m; municipal
  geodetic outlines 25–500 mm. Delivery GeoPackage. Completeness ~4 % deviation nationally.
- Terms: **high-value dataset with personal data** — CC BY 4.0, plus purpose application approved by Lantmäteriet (§3.3), only
  necessary personal data (§3.4), storage in EU/EEA unless decided otherwise, US cloud only under the Data Privacy Framework (§3.5),
  spot checks, withdrawal.
- OSM forum thread "Öppna data från Lantmäteriet" page 8: OSMF LWG's view (Jan 2026) that outlines and addresses alone are not
  personal data; Lantmäteriet declined to confirm ODbL redistribution is acceptable (July 2026); import stalled; a member wrote to
  Lantmäteriet in September 2026, no answer by 3 October.
- **Markhöjdmodell**: 1 m grid from laser data; GeoTIFF; quality ~0.1 m on hard flat ground. Product page lists it as a high-value
  dataset.

### Step 4. Jönköpings kommun
- `jonkoping.se` → Kartprodukter: **3D city model from 2016**, photorealistic (oblique and aerial photos draped on ground and
  buildings), Jönköping and Huskvarna, updated only for single important buildings. **Laser data 2016, 6–12 points/m²**, surface
  model. Both sold under the municipal price list (SBK-taxa 2018-08-30). Orthophotos 2011/2012/2014/2016/2020; oblique photos
  2004–2015.
- Open data portal `data-jonkoping.opendata.arcgis.com`: Hub search API (`/api/search/v1/collections/all/items`) returned 40
  datasets, CC0, mostly leisure (bathing sites, shelters, trails, outdoor gyms, sports halls, MTB, rest areas). Query "byggnad"
  returned 0. Coordinate system SWEREF99 13 30.
- Detaljplaner: a 2025 samrådsredogörelse found uses "högsta nockhöjd" limits; nothing covering the station or Juneporten was located.
- Wikipedia (sv) "Jönköpings resecentrum": 90 m a.s.l.; 4 tracks, 2 for passenger trains; building 1983 by Carl Nyrén, owner
  Jernhusen; waiting hall added 2001; replaced Edelsvärd's 1864 station.

### Step 5. Trafikverket — finding the platform data
- Searches on NJDB/Lastkajen/plattformshöjd. NJDB via **Lastkajen** needs a user account; GeoPackage; "© Trafikverket" requested.
- **BanInfo service description v1.17 (2026-05-19)**: WMS, no fee, **CC0** (since v1.5, 2017). Layers include `Plattform`
  ("a structure for passenger exchange") and "Plattform text" ("platform height and length"), plus `Sparnummer`, `Plats`,
  kilometre posts, STH, bridges, etc. Operations GetMap, GetFeatureInfo, GetLegendGraphic; WMS 1.1.1 and 1.3.0.
- **Network Statement (JNB) Bilaga 2A** "Möteslängder och plattformar": JNB 2021 text says it holds height and usable platform
  length per station. The JNB 2027 consultation response confirms: Jönköpings Länstrafik asked to split row 386 of tab 4 because
  track 1 differs from 2a and 2b; Trafikverket says data comes from BIS and the extract sometimes mixes total and usable length.
  Other operators reported wrong heights (Kungsbacka, Uddevalla, Trollhättan, Herrljunga, Stenungsund queried).
- JNB 2027 page lists `bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx` (196 kB, version 2026-09-24).
- **INSPIRE TN railway service** (also CC0, WMS + WFS): only `numberOfplattforms` on RailwayStationNode — no height or length.
- **JNB karttjänst** (`jnbkarta.trafikverket.se`, WMS proxy `JNBWMS`): traffic places, line categories, signalling, ATC/ETCS,
  detectors, speed/axle-load restrictions — **no platform layer**.

### Step 6. Dead ends while fetching
- Workspace shell: every outbound request except package registries is blocked by the proxy (403 on CONNECT). Downloads must go
  through the browser.
- WebFetch on the xlsx returns "binary data"; on `geobaninfo…` it was refused by robots.txt; on Commons API/category pages it
  returned "url_not_found"; on Geotorget it returns an empty JS shell.
- `geobaninfo.trafikverket.se` (no hyphen) → DNS NXDOMAIN. The correct host `geo-baninfo.trafikverket.se` was found via the
  Länsstyrelsen planning catalogue metadata and the Spatineo directory.
- Navigating Chrome directly to a WMS GetCapabilities or to `dl1.lantmateriet.se` files triggers downloads instead of showing a page,
  so JavaScript must run from another page on a suitable origin (see Part 4).
- The tool output filter blocks strings that look like query strings; strip `?`, `&`, `=` before returning text from the browser.
- Loading an outside JS library (e.g. `copc` from jsDelivr) into the page was **not permitted**. Everything in Part 4 is plain
  browser APIs: `fetch`, `DecompressionStream`, `DataView`, `DOMParser`, canvas.

### Step 7. Bilaga 2A read in the browser (no file saved)
Opened the JNB 2027 page in Chrome, fetched the xlsx same-origin, unzipped it with `DecompressionStream('deflate-raw')`, parsed
`sharedStrings.xml` and the sheet XML (code 4.1). Sheets: 1 Allmän information, 2 Förklaringar, 3 Möteslängder, 4 Plattformar,
5 Kommande ändringar, 6 Ändringslogg. Platform tab header: Bandel, Trafikplats, Spårnr, Längd (m), Plattformshöjd,
Skyddszon och ledstråk, Väderskydd, Anmärkning, Notering. Report dates: platforms 2026-02-04, passing lengths 2025-06-10.

Results for Jönköping C: row 386, bandel 711, "Jönköpings central", tracks "2a,2b,1", 497.1 m, **mellan**, "S & L", **Tak**.
Passing length tab row 314: 1,470 m, track 2b. Godsbangård row 315: 954 m, track 1. Rocksjön (bandel 715) is listed as a stop
inside Jönköping freight yard. No Jönköping entries in "Kommande ändringar".

### Step 8. BanInfo read in the browser
- GetMap with `LAYERS=Plattform,Sparnummer`, `SRS=EPSG:4326`, bbox 14.1560,57.7820,14.1700,57.7870, 1200 × 800 px rendered fine.
- Rendered `Plattform` alone transparent, scanned the canvas for coloured pixels every 15 px column (51 hits), then ran
  GetFeatureInfo (`INFO_FORMAT=text/html`) at each hit (code 4.2). Features came back with full attributes and line geometry.
- Attributes for BIS object 1705: VALID_FROM 2026-10-13, BisObjektTypNr 10004, Kmtal 69+131 to 69+590, ObjektText "mellan497",
  Höjd mellan, Höjd_beskr "Höjd 0.58 m", Längd_m 497.1, Bredd_m 8, Plattformskant_mtrl betong, Beläggning asfalt, Väderskydd Tak,
  Skyddszon_och_ledstråk S L, Skylt NEJ, Fotsteg NEJ, Brunn_o_lock JA, Skyddsräcken JA, Plattformsutrustning JA,
  Besiktningsklass b3, plus REFLINK_OID, MEASURE_FROM/TO, SIDE per track link.
- Four track-link parts: three on SIDE 2 (161.2 + 62.9 + 233.2 = 457.3 m, matching km 69+131 to 69+590 = 459 m) and one on
  SIDE 1 (88.1 m).
- `Sparnummer` GetFeatureInfo at points along each part named the tracks: 2a (west), 2b (centre/east), 1 (east end). Neighbouring
  tracks seen: 3a, 3b, 4, and switch links 421-422, 423-424, 429-430.
- Saved as `jonkoping_c_platform_trafikverket.geojson`.

### Step 9. Geotorget order
- Logged in by the owner. Product pages: *Laserdata Nedladdning, skog* — fee no, terms "Användningsvillkor för Laserdata
  Nedladdning, skog", legal review no, API STAC, format COPC, endpoint `https://api.lantmateriet.se/stac-hojd/v1`.
  *Markhöjdmodell Nedladdning* — fee no, terms "Användningsvillkor för värdefulla datamängder" (no personal data), legal review no,
  STAC, format COG, same endpoint.
- Added both to the cart (0,00 kr each), ticked the terms box, submitted, confirmed. Receipt page, then emails from
  noreply-geotorget@lm.se: "Lantmäteriet har mottagit din beställning" with *Produkt- och leveransspecifikation* PDFs, and
  "Handläggning av ärende LM2026/164214 / 164215 är klar". Mitt konto → Behörigheter lists both with the STAC endpoint.
- Lantmäteriet's Radiant Earth guide: private users enter their Geotorget login at the download prompt. A QGIS plugin
  "lm_stac_downloader" also exists.

### Step 10. STAC search
- `GET /stac-hojd/v1/collections`: `dsm-skoglig-copc` ("Laserdata Skog", surface point cloud, laz/copc, EPSG:5845, temporal
  2019-10-01 to 2026-10-26, licence link to the laser terms) and `dtm-cog` ("Markhöjdmodell", 1 m GeoTIFF/COG, EPSG:5845, licence
  `CC-BY-4.0`, assets data/metadata ("Ursprung")/breakgeometry).
- `POST /search` with a point or bbox (code 4.3). Items for the station:
  - DTM `640_45`: datetime 2023-10-31, start 2022-03-20, end 2025-06-13, lagesosakerhethojd 0.2, lagesosakerhetplan 1,
    ursprungligtmatdatum 2022-03-20, brytgeometri true, 198.6 MB; neighbour `640_44` 266.2 MB.
  - Laser `22b007-640_45` (10 km, 184,021,837 points, 871.8 MB), `22b006-640_44` (10 km, 245,795,843 points, 1,140 MB), and
    2.5 km tiles listed in the findings report (2.4 MB to 80.8 MB). Scan 2022-03-19/20, flyghojd 3200, punkttathet 1.3.
- Files are on `dl1.lantmateriet.se`: `/hojd/data/...` needs login; `/hojd/pub/...` (info.json, thumbnails, ursprung) is open.
- From a page on `api.lantmateriet.se`, `fetch(…, {credentials:'include'})` with a `Range` header returned 206 and the `LASF`
  signature after the owner had logged in once; without credentials it returned 401. CORS allows this.

### Step 11. Terrain model read in the browser
- TIFF header of `m640_45.tif` (code 4.4): little-endian classic TIFF, 10000 × 10000, float32, compression 8 (deflate),
  predictor 3 (floating point), 512 × 512 tiles (400), origin E 450000 N 6410000, 1 m pixels, nodata "-9999".
- Decoded the needed tiles with `DecompressionStream('deflate')` and undid predictor 3 by hand.
- Converted lat/lon to SWEREF 99 TM with Lantmäteriet's Gauss–Krüger formulas (code 4.5). Station centre → E 450294.6,
  N 6405002.8. Platform west end → E 450032.8, N 6405091.5; east end → E 450474.4, N 6404976.4.
- Results in Part 3.

### Step 12. Laser point cloud — where it stopped
- Read the COPC header and root hierarchy page in the browser (code 4.6): point format 6, 30-byte records, scale 0.01,
  offset (535000, 6715000, 0); small tile cube centre 451250/6406250, half-size 1250, spacing 19.5; 10 km tile half-size 5000.
- Root hierarchy of `y22b007-64050_4500_25` (17 nodes): the node covering E 450000–450625, N 6405000–6405625 holds 146,461
  points; nodes over the lake hold a few thousand. The station's north half lies in that node.
- Decoding LAZ point data needs a LAZ decompressor. Loading one from a CDN was not allowed, and the workspace can't reach
  Lantmäteriet, so the remaining step is: attach the two 2.5 km files to the chat and decode with Python (`pip install
  "laspy[lazrs]"`), or run PDAL/QGIS locally.

### Step 12b. Laser point cloud decoded (after the owner attached the files)
- Files attached to the chat: `y22b007-64050_4500_25.copc.laz` (2.4 MB, 662,935 points) and `y22b007-64025_4500_25.copc.laz`
  (45 MB, 10,443,998 points). LAS 1.4, point format 6. `pip install "laspy[lazrs]" pyproj scipy shapely matplotlib`.
- Cropped E 449980–450620, N 6404820–6405220: 298,592 points (≈1.17/m², water included). Classes: 1 → 109,123; 2 → 155,724;
  7 → 263; 9 → 31,296; 17 → 1,532 (a bridge at E ≈450555–450585, z ≈91, east of the station); 18 → 654. The strip west of
  E 450000 is in another tile (`22b006-64050_4475_25`) and was not used.
- Ground grid: 1 m cells, median of class 2+9 points, linear interpolation between cells, nearest-neighbour at the edges.
  Height above ground = point z minus grid. A max-height raster showed buildings, canopies and wires.
- Cross-sections: projected every point onto the Trafikverket track-2 line (along-track s, signed offset d, d>0 = lake side)
  and plotted z against d in 60 m slices (Part 4.8). This showed the platform (91.67 m between d −8 and −2), the track-2 bed
  (90.88 m), the track-1 bed at the east end (d ≈ −12…−9), canopy 1 at 95.0 m, a higher roof at 97–98 m, the footbridge at
  ≈100.8 m spanning the tracks at s ≈160–175, and catenary dots at 99–100 m.
- Measurements in 20 m and 5 m bins along the track: platform level 91.63–91.71 from s 5 to s 455; edge at d ≈ −2.0 (z drops
  from 91.63 to 90.97 between d −2.25 and −1.75); platform minus track bed 0.76 m median (IQR 0.73–0.79).
- OSM footprints fetched in Chrome from the OSM API (`/api/0.6/map.json?bbox=14.1590,57.7828,14.1700,57.7864` and
  `/api/0.6/relation/<id>/full.json`; Overpass was blocked by the page's security policy): 68 features incl. station building
  w81576737, footbridge w81576735 (building=bridge, layer 2), roof w401108813 over platform 2a, platforms w39376129 (1),
  w39376130 (2b), w39376131 (2a), bus terminal w133653929, hotel w986647231 (height 61), elevator n950768989 (level 0;1),
  steps w1425083737, w1524292832, w1105535069, Juneporten block r13095414. Points inside each footprint gave roof medians and
  95th percentiles. Juneporten was identified from Commons camera coordinates (interior photo at 57.78362, 14.16225).
- Canopies traced as connected 1 m cells with non-ground points 2.2–8.5 m above the platform inside the platform polygons
  buffered by 2.5 m. **First pass found three; the user pointed out there is no canopy at the east end.** Cross-sections
  confirmed the east "canopy" was a train on track 1 (points at d −11…−8, z 94.75–94.9, ground hidden) and that the second roof had
  also absorbed a train on track 2 (d −2…+1, z 94.5–94.8). Fix: drop points over a track (d > −2.2 or d < −8.2) at ≤ 95.4 m
  (386 points), and discard patches under 100 m². Result: two roofs over the platform (708 m² at 95.04 m; 761 m² at 97.77 m). The second was later identified as the 2001 waiting hall, not a canopy (see Step 17).
- The user then noticed a second train east of the second roof (the waiting hall). A full scan of both track bands (5 m bins, roof points at 93.6–95.8 m,
  Part 4.8) confirmed exactly two parked trains, ≈55 m each, both already excluded; they were added to the GeoJSON as
  `train_in_scan` and drawn on the map. Lesson: list trains explicitly rather than only filtering them out.
- Outputs: `jonkoping_c_structures_heights.geojson` (19 features incl. 2 trains, attribution for Lantmäteriet and OSM in each feature) and
  `jonkoping_c_heights_overview.png`.

### Step 13. Photos
- Commons API from a Commons page in Chrome: `list=geosearch` (400 m, 100 files) and `list=search` in the File namespace;
  `prop=imageinfo` with `extmetadata` for date, licence, author and description; thumbnails shown in a grid and screenshotted.
  Selected files are tabled in the findings report. Older photo "Jönköpings centralstation.jpg" shows a footbridge with stair
  towers at the west end. Juneporten photos (2024) show a ground-level glass-roofed passage.
- Mapillary web app at the station: sequences along the lakeside path and streets; one image at the entrance doors, key
  238630658055349, dated 2015-05-24, by user "traveller". The API needs a token; the web app does not.
- Other Commons photos found by keyword (trains at Jönköping, useful for train types): X61 61301 (2011, 2013), X53 3265 (2019),
  Y31 1405 and Y32 1410 (2019), X14 3233 (2013), X52 9076 (2024), Krösatåg 8542 (2008), GC Rd2 1044 (2013), X50 3289 (2022),
  freight with GC T44 331 (2006). A 1919 view of the old station by Folke Zettervall also exists.

### Step 14. Phone measurement
- No Apple accuracy figure for ARKit was found.
- Scargill et al., *Here To Stay* (NSF PAR 10358173): iPhone 11 (no LiDAR) ARKit 4/5 virtual-object drift ~1–2 cm after brief
  loss of view, ~9–10 cm after moving, **15–25 cm after walking away**; iPhone 13 Pro Max (LiDAR) under 3 cm. All phones 5–15 cm
  for most actions except focused moves.
- Barometer: Bosch BMP380 relative accuracy ±0.06 hPa ≈ **±0.5 m** (eeNews Europe). Vanini et al.: Galaxy Nexus (BMP180,
  ±0.12 hPa) detected floor transitions with 82 % accuracy (MIN_SAMPLES=2); ~1 hPa between floors in their building. Apple does
  not name the iPhone 17's sensor.

### Step 15. Trains
- Primary spec sheets were not found in the time spent. Secondary figures: X40 2-car 55.1 m / 3-car 81.5 m (en.wikipedia, uncited);
  X61 4 cars ~74 m, width 3.56 m (en.wikipedia, uncited); X2000 24.95 m per car, 6 cars + power car (Mediarail.be); Itino Y31
  38.4 m / Y32 54.7 m (en.wikipedia, uncited). Krösatågen use Y31/Y32, X10/X14, and CAF Civity from 2026 (Mediarail.be).
  sv.wikipedia train pages could not be fetched. Transitio's Coradia page has no technical data.
- Better sources to try: Transitio "Spårfordon" pages, manufacturer sheets, ERA's ERATV register, and the Commons photos above to
  confirm which types call.

### Step 16. Licences with ODbL
- CC0 sources (BanInfo, kommun open data) mix freely.
- CC BY 4.0 Lantmäteriet data: keep in a separate layer; never upload to OSM (no OSMF waiver); note §2(a)(5)(B) on technological
  measures (App Store encryption is an open question); keep only derived values.
- Bilaga 2A: public document without a stated licence; cite it, or take the same facts from CC0 BanInfo.

### Step 17. Station pack: photos, laser images, model and data files (30 October 2026)
The owner asked for the images and laser data to be included directly, not only described.
- **Photos.** The Commons category *Jönköpings centralstation* (40 files) was read with `list=categorymembers` and
  `prop=imageinfo|extmetadata`. 18 photos were chosen to cover the platform, canopy 2a, waiting hall, footbridge, station building,
  Juneporten, the view from Vättern and two historical views (the 1864 building, demolished 1983; a 2007 view). Because the
  workspace cannot reach `upload.wikimedia.org`, each thumbnail (≤1100 px) was opened alone in a Chrome tab and captured with a
  screenshot saved to disk (`save_to_disk`, scale 1, files land in `/tmp/claude-chrome-screenshots-*/`); the grey letterbox was
  cropped from the known width/height ratio. Titles were first mapped to the wrong pageids; fixed by re-querying the API by
  pageid. Captions were then checked against each photo: 59238338 looks **west** from the footbridge, not east; the 2022 photo was
  taken seven weeks after the scan; claims about Juneporten's height and the arched roofs were removed where the photo did not
  show them. Credits (author, licence, URL) are in `photos.json`.
- **Waiting hall.** Photos 62899901 (2011) and 99563715 (2019) show a glass-walled hall along platform 2b with a roof overhang
  and louvres; its outline matches the 761 m² roof traced at 97.77 m and OSM w133653929. The roof formerly called "canopy 2" was
  relabelled the 2001 waiting hall in every file. It slopes from ≈98.1 m to ≈96.9 m.
- **Laser images.** From the two decoded tiles: a 0.5 m height-above-ground raster and an intensity raster
  (E 450020–450520, N 6404880–6405140), a hillshaded terrain image with the lake masked (water = nearest point class 9 or more
  than 4 m from any point), and four cross-sections across the platform (A canopy 2a, B footbridge, C waiting hall, D east end with
  the train on track 1). Trains drawn in a separate colour.
- **Point cloud.** 116,646 points within the station box, trains re-classed 64; saved as LAZ and as a compact 8-byte-per-point
  binary for the web viewer.
- **Block model.** 17 parts plus a ground mesh (1 m grid, triangulated), extruded from OSM/Trafikverket outlines to laser heights
  with `trimesh` + `mapbox_earcut`, exported as GLB in a local frame (origin E 450294.6 N 6405002.8, 90.0 m; x east, y up,
  −z north). Footbridge deck underside 97.2 m is an assumption until the walk.
- **Ground.** 1 m GeoTIFF (float32, EPSG:3006) and a 16-bit PNG heightmap (value / 1000 + 85 m) for engines.
- **Station JSON.** One file holding every value with its source, which stand-in it replaces, the OSM lift (n950768989, levels
  0;1) and steps (w1425083737, w1524292832, w1105535069), the trains, terrain reference and attribution lines.
- **Page.** Published as *Jönköping C Station Pack*: a plan with switchable laser backgrounds, train and photo-position toggles;
  a three.js point cloud viewer (height, class, intensity); the GLB model with tap-to-identify; cross-sections; the photo gallery;
  value and file tables; open items; licences. First publish was refused because `.bin` and `.glb` are not served types; both were
  re-shipped as base64 `.txt` and decoded in the page.

---

## Part 3 — Every finding for Jönköping C

### Platform (Trafikverket)
| Item | Value | Source |
|---|---|---|
| Height | mellan = 0.58 m above rail | Bilaga 2A row 386; BanInfo object 1705 |
| Recorded length | 497.1 m (combined) | same |
| Width | 8 m | BanInfo |
| Edge / surface | concrete / asphalt | BanInfo |
| Roof | Tak | Bilaga 2A; BanInfo |
| Safety | S & L (protection zone and tactile path) | same |
| Equipment | railings yes, equipment yes, manholes yes, signs no, steps no | BanInfo |
| Km range | 69+131 to 69+590 | BanInfo |
| Track 2a + 2b run | ≈457 m (161.2 + 62.9 + 233.2) | BanInfo geometry |
| Track 1 run | ≈88 m, east end | BanInfo geometry |
| Valid from | 2026-10-13 | BanInfo |
| Bandel | 711 | Bilaga 2A |
| Longest passing length | 1,470 m, track 2b | Bilaga 2A tab 3 |

### Ground (Lantmäteriet Markhöjdmodell, tile 640_45)
Track line samples (lon → height, m RH 2000): 14.1597 → 90.89; 14.1603 → 90.83; 14.1611 → 90.82; 14.1623 → 90.91;
14.1633 → 90.95; 14.1659 → 90.88; 14.1672 → 91.19.

500 × 200 m box around 57.7843 N, 14.1641 E (25,000 samples every 2 m, no nodata): min 88.73, p5 88.81, median 91.02,
p95 96.06, max 96.92. Plane fit: 91.22 m at centre, −0.80 m per 100 m east, −2.27 m per 100 m north. Quadrant means:
west-north 90.91, east-north 89.39, west-south 93.62, east-south 91.18.

Profiles south→north (N offset from 6405000 m : height):
- E 450100: −120:96.4 … −30:95.2, −20:96.3, 0:96.3, 10:94.1, 20:92.6, 30:91.3 … 90:90.8, 100:90.3, 110+:88.8
- E 450250: −120:94.8 … −40:91.1, −30:90.7, 0:91.8 … 30:91.7, 40:90.9 … 60:90.7, 70+:88.8
- E 450400: −120:92.9 … −70:90.9, −20:91.4, 0:90.9 … 30:90.8, 40+:88.8

### Laser scan
19–20 March 2022, 3,200 m flight height, 1.3 points/m² nominal, blocks 22B007 and 22B006. Tile list in the findings report.

### Laser-derived heights (RH 2000)
| Item | Value |
|---|---|
| Platform surface | 91.67 m; ends ≈14.1598 E and ≈14.1671 E; edge ≈2.0 m from track-2 line |
| Track bed | 90.88 m |
| Platform above track bed | 0.77 m (≈0.57–0.62 m above rail head, estimated) |
| Canopy 1 (west) | 95.04 m top, +3.4 m, 708 m² |
| Waiting hall roof (2001, OSM w133653929 "bussterminal"; was "canopy 2") | 97.77 m top, +6.1 m, sloping 98.1→96.9, 761 m²; overhangs platform 2b |
| East platform | no canopy |
| Trains in scan | two, ≈55 m each: track 2 ≈14.1646–14.1655 E; track 1 ≈14.1659–14.1668 E; roofs ≈94.8 m |
| Station building | ground 91.6–91.7, roof 100.08 (p95 100.89), ≈8.5 m |
| Footbridge | roof 100.74 (p95 101.73), ≈9.1 m above ground |
| Bus terminal | roof 96.98, ≈5.5 m |
| Juneporten block | ground 90.7 (north) → 95.3 (south entrance); roof 104.8 (p95 122.2) |
| Hotel | roof 154.9, ≈59.7 m (OSM height 61) |
| Street in front of station | 90.7 m; lakeside at footbridge north end 90.8 m |

### Licences and terms
Laser: CC BY 4.0 + GDPR controller role (terms 2026-05-20). DTM: CC BY 4.0, high-value terms without personal data.
Byggnad: CC BY 4.0 + purpose approval, EU storage. BanInfo, INSPIRE TN: CC0. Lastkajen: free account, "© Trafikverket".
Kommun open data: CC0. Commons photos: per file (CC BY 2.5 to CC BY-SA 4.0). Mapillary: CC BY-SA 4.0.

## Every finding

### Platform (Trafikverket)
| Item | Value | Source |
|---|---|---|
| Height | mellan = 0.58 m above rail | Bilaga 2A row 386; BanInfo object 1705 |
| Recorded length | 497.1 m (combined) | same |
| Width | 8 m | BanInfo |
| Edge / surface | concrete / asphalt | BanInfo |
| Roof | Tak | Bilaga 2A; BanInfo |
| Safety | S & L (protection zone and tactile path) | same |
| Equipment | railings yes, equipment yes, manholes yes, signs no, steps no | BanInfo |
| Km range | 69+131 to 69+590 | BanInfo |
| Track 2a + 2b run | ≈457 m (161.2 + 62.9 + 233.2) | BanInfo geometry |
| Track 1 run | ≈88 m, east end | BanInfo geometry |
| Valid from | 2026-10-13 | BanInfo |
| Bandel | 711 | Bilaga 2A |
| Longest passing length | 1,470 m, track 2b | Bilaga 2A tab 3 |

### Ground (Lantmäteriet Markhöjdmodell, tile 640_45)
Track line samples (lon → height, m RH 2000): 14.1597 → 90.89; 14.1603 → 90.83; 14.1611 → 90.82; 14.1623 → 90.91;
14.1633 → 90.95; 14.1659 → 90.88; 14.1672 → 91.19.

500 × 200 m box around 57.7843 N, 14.1641 E (25,000 samples every 2 m, no nodata): min 88.73, p5 88.81, median 91.02,
p95 96.06, max 96.92. Plane fit: 91.22 m at centre, −0.80 m per 100 m east, −2.27 m per 100 m north. Quadrant means:
west-north 90.91, east-north 89.39, west-south 93.62, east-south 91.18.

Profiles south→north (N offset from 6405000 m : height):
- E 450100: −120:96.4 … −30:95.2, −20:96.3, 0:96.3, 10:94.1, 20:92.6, 30:91.3 … 90:90.8, 100:90.3, 110+:88.8
- E 450250: −120:94.8 … −40:91.1, −30:90.7, 0:91.8 … 30:91.7, 40:90.9 … 60:90.7, 70+:88.8
- E 450400: −120:92.9 … −70:90.9, −20:91.4, 0:90.9 … 30:90.8, 40+:88.8

### Laser scan
19–20 March 2022, 3,200 m flight height, 1.3 points/m² nominal, blocks 22B007 and 22B006. Tile list in the findings report.

### Laser-derived heights (RH 2000)
| Item | Value |
|---|---|
| Platform surface | 91.67 m; ends ≈14.1598 E and ≈14.1671 E; edge ≈2.0 m from track-2 line |
| Track bed | 90.88 m |
| Platform above track bed | 0.77 m (≈0.57–0.62 m above rail head, estimated) |
| Canopy 1 (west) | 95.04 m top, +3.4 m, 708 m² |
| Waiting hall roof (2001, OSM w133653929 "bussterminal"; was "canopy 2") | 97.77 m top, +6.1 m, sloping 98.1→96.9, 761 m²; overhangs platform 2b |
| East platform | no canopy |
| Trains in scan | two, ≈55 m each: track 2 ≈14.1646–14.1655 E; track 1 ≈14.1659–14.1668 E; roofs ≈94.8 m |
| Station building | ground 91.6–91.7, roof 100.08 (p95 100.89), ≈8.5 m |
| Footbridge | roof 100.74 (p95 101.73), ≈9.1 m above ground |
| Bus terminal | roof 96.98, ≈5.5 m |
| Juneporten block | ground 90.7 (north) → 95.3 (south entrance); roof 104.8 (p95 122.2) |
| Hotel | roof 154.9, ≈59.7 m (OSM height 61) |
| Street in front of station | 90.7 m; lakeside at footbridge north end 90.8 m |

### Licences and terms
Laser: CC BY 4.0 + GDPR controller role (terms 2026-05-20). DTM: CC BY 4.0, high-value terms without personal data.
Byggnad: CC BY 4.0 + purpose approval, EU storage. BanInfo, INSPIRE TN: CC0. Lastkajen: free account, "© Trafikverket".
Kommun open data: CC0. Commons photos: per file (CC BY 2.5 to CC BY-SA 4.0). Mapillary: CC BY-SA 4.0.
