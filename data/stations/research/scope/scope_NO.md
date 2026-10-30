# Scope: Norwegian station data sources (Oslo S and 10 stations around Oslo)

Scoping only, no data has been collected. Checked 2026-10-30 with WebSearch/WebFetch (no browser). Coordinate maths was done locally with pyproj.

Legend:
- **[V]** verified: I fetched the page or service and the fact is stated there.
- **[U]** unconfirmed: from search snippets, inference or memory, or the page did not say.
- **[X]** blocked: the fetch tool refused the URL (robots.txt, client error or URL length), so I could not check it from here.

Login/key column: "none" means anonymous download. "email" means you type an email address and get a download link by mail (no account). "Norge digitalt" means a login for Norwegian public partners or a paid reseller, which **we cannot use**.

Station: Oslo S (hub); Asker, Drammen, Lillestrøm, Lysaker, Moss, Nationaltheatret, Oslo lufthavn (Gardermoen), Sandvika, Ski, Skøyen.

---

## 1. Laser point clouds and terrain models (Kartverket / hoydedata.no)

### 1.1 Høydedata – laser (the point clouds)
- Metadata (machine-readable): https://kartkatalog.geonorge.no/api/getdata/f297e948-8a34-4e6c-9740-54b3a657f8d5 [V]. Also https://geonorge.no/geonetworktest/srv/api/records/f297e948-8a34-4e6c-9740-54b3a657f8d5 [V].
  - AccessConstraints: "Åpne data". OtherConstraints: **"Most laser projects are open, but some have access restrictions. Access is limited through the Norge digitalt user login."** [V]
  - Distribution: LAZ via https://hoydedata.no/LaserInnsyn/ (the page itself is JavaScript; my fetch failed) [V for the metadata, X for the page].
  - Reference systems: EUREF89 UTM 32, 33 and 35 (EPSG:25832/25833/25835) [V].
- Kartverket's own page https://www.kartverket.no/api-og-data/terrengdata [V]:
  - Height and terrain data are **free to download**. The original point clouds download as **LAZ or ZLAS**. Each project on hoydedata.no has a "punktsky" 3D viewer.
  - "Some datasets and WMS layers on hoydedata.no are restricted to Norwegian digital partners and require login."
  - WCS, WFS, WMS and "REST services for scripted downloads and metadata search" exist. I did not find the REST endpoint documentation [U].
- **Licence. Mixed signals, so treat it per project:**
  - Kartverket's general terms: "Kartverkets gratisprodukt er lisensierte etter CC BY 4.0", attribution "© Kartverket" (https://www.kartverket.no/api-og-data/vilkar-for-bruk) [V].
  - DTM1 is listed as **CC BY 4.0** (1.3 below) [V]. The DTM ATOM feed says **NLOD 2.0** [V]. The OpenTopography record of the same national model says CC BY 4.0 [V].
  - **But single project records still say "Norge digitalt-lisens"**: for example "Høydedata Oslo Byggesonen tynnet 2014" (https://geonorge.no/geonetworktest/srv/api/records/221bb62b-eafe-4aad-ba09-de70e37b81b3) and "Høydedata Rogaland 10pkt Øst 2025" (https://data.norge.no/en/datasets/55edc302-1e86-3589-a4c3-cd8079c82a40/hoydedata-rogaland-10pkt-ost-2025) [V]. Those records are probably stale templates, but I could not confirm that [U].
  - → For each project we use, check the open/restricted flag (`TILGANG`, `BEST_OPEN`, see 1.2) and whether hoydedata.no lets us export it without a login.
- **Classes, from the FKB-Laser 3.0 product spec** (https://register.geonorge.no/data/documents/Produktspesifikasjoner_fkb-laser_v9_fkb-laser-v30-2021-01-01_.pdf) [V]:
  - **Mandatory: 1 unclassified, 2 ground, 7 low noise, 17 bridge deck.**
  - **Optional, only if ordered: 3/4/5 vegetation, 6 building, 9 water, 10 rail, 11 road surface**, 13–16 power line/mast, 24 snow, 25 boulders, and 26–31 bathymetric classes.
  - → **Building class 6 is not guaranteed** (in Sweden it was always there). The class list must be checked per project, either from the LAZ header or the project report. The older Oslo projects use the "FKB-Laser 2.0" catalogue [V], whose class list I did not check [U].
  - Format: LAS 1.2, point format 1 (3 if RGB was ordered), compressed to LAZ. LAS 1.3/1.4 only by agreement [V].
  - Delivery tiles: **1:1000 map sheet index** (FKB-Laser A/B/C), named like `32-1-507-212-16.laz` [V]. Density classes: A ≥10 p/m², B ≥5, C ≥2, D <2 [V].
  - Height datum: the municipality's official system, NN2000 (EPSG:5941) or NN54 [V]. All Oslo-area projects I saw are tagged `HOYDESYSTEM 5941` = **NN2000** [V].
- **Access method: export by email, no login, for open projects** [V]. Source: the step-by-step guide by Statsforvalteren i Innlandet (https://inte.statsforvalteren.no/siteassets/fm-innlandet/06-miljo-og-klima/veileder-for-bruk-av-arcgis-pro-i-myrrestaurering.pdf, pp. 3–9). It states "Du skal ikke trenge å logge deg inn for å laste ned data herfra." The steps:
  1. Open hoydedata.no and tick the project.
  2. Go to Menu → Eksport, and draw a rectangle.
  3. Choose product "Punktsky", format LAZ or ZLAS, and CRS UTM32/UTM33.
  4. Click "klargjør eksport" and enter an email address.
  5. A second email arrives with a link to a delivery folder holding a zip.
  - **This needs a working email inbox** (no account). It is a manual, JavaScript UI step. We cannot do it unattended unless someone receives the mail; the user would have to run it or forward the link.
  - A forum post says exports are capped at 4×4 km (https://forum.v1e.com/t/making-topographical-carving-print-using-norwegian-hoydedata-service/34631) [U]. That is enough for one station each.
- **Plain HTTP for point clouds: not found.** I found no static LAZ tile URL or open STAC/ATOM for point clouds; the ATOM feed holds only the DTM1/DOM1 grids [V]. The project WFS has a `POTREE_PATH` attribute (e.g. `/Potree_vol1/8/<guid>`), which suggests the 3D viewer reads Potree octree files over HTTP from hoydedata.no [V that the field exists; U whether they can be fetched, and what licence or classes they carry]. A possible fallback, but not a clean source.

### 1.2 Project index: scan year and density per station
- **Project-boundary WFS (no login)** [V]: https://wfs.geonorge.no/skwms1/wfs.hoyde-hoydedata-metadata-prosjekt?service=wfs&request=getcapabilities
  - Feature types `metadata_prosjekt:Prosjektavgrensning` and `metadata_prosjekt:Flystriper`. EPSG:25833. Output GML, GeoJSON, CSV, GPKG (GeoJSON/CSV only in WFS 2.0.0) [V]. Licence "noConditionsApply" [V].
  - **Attributes [V]:** LAS_PROJECT_NAME, LAS_PROJECT_ID, AARSTALL (year), SISTEFLYDATO (last flight date), PUNKTTETTHET (p/m²), FKB_LASERSTANDARD, OBJEKTKATALOG, KOORDINATSYSTEM, HOYDESYSTEM, TILGANG, BEST, BEST_OPEN, PUBLISERT, POTREE_PATH, LEVERANDOR, OPPLOSNING, RAPPORT (internal UNC path), and others.
  - Working query (WFS 1.1.0, bbox E,N in EPSG:25833) [V]: `...wfs.hoyde-hoydedata-metadata-prosjekt?service=WFS&version=1.1.0&request=GetFeature&typeName=metadata_prosjekt:Prosjektavgrensning&srsName=EPSG:25833&bbox=262400,6649000,262700,6649250,EPSG:25833`
- **Oslo S result: 9 projects overlap** [V numberOfFeatures=9]. I could read only the first two, because the polygons are huge and my fetch tool truncates [X for the other 7]:

| Project | Year | p/m² | Catalogue | CRS | TILGANG | BEST_OPEN |
|---|---|---|---|---|---|---|
| Oslo Byggesonen 2014 | 2014 (flown 2014-07-11) | 10 | FKB-Laser 2.0 | 25832 | 2 | 0 |
| Oslo 2011 | 2011 | 5 | FKB-Laser 2.0 | 25832 | 2 | 0 |

  - Projects elsewhere have TILGANG=1 and BEST_OPEN=1 (e.g. Rogaland 5pkt 2015) [V]. So **TILGANG=2 / BEST_OPEN=0 probably means "restricted" or "not the best open"** [U]. The newest open project over each station is still unknown.
  - **Next step (needs curl or a script, not WebFetch):** run the query for each station, drop the geometry (WFS 2.0 `outputFormat=GEOJSON` + jq), sort by AARSTALL and keep `BEST_OPEN=1`. The station coordinates I used (EPSG:25833, approximate, ±100 m [U]):
    - Oslo S 262573,6649119; Nationaltheatret 261433,6649617; Skøyen 258525,6650677; Lysaker 256303,6649728
    - Sandvika 249524,6647523; Asker 244212,6641664; Drammen 230603,6632246; Lillestrøm 279179,6652767
    - Ski 265833,6627505; Moss 253835,6596215; Oslo lufthavn 283673,6679347
- Point-density WMS (no login, 10 m grid of actual p/m²) [V]: https://wms.geonorge.no/skwms1/wms.hoyde-dom-prosjekt-punkttetthet?request=GetCapabilities&service=WMS
- Project outline WMS (CC BY 4.0; GetFeatureInfo returns project metadata) [V for metadata]: https://wms.geonorge.no/skwms1/wms.hoyde-prosjekter?request=GetCapabilities&service=WMS. The capabilities came back as binary to my tool [X].
- Second metadata WFS with layers `NHM-prosjektdekning`, `NHM-prosjektalder`, `Bestilt_punkttetthet`, `Prioritet_1..3`, `Prosjekttype` [V capabilities]: https://wfs.geonorge.no/skwms1/wfs.hoyde-hoydedata-metadata?service=wfs&request=getcapabilities. My bbox queries at Oslo S returned 0 features, and the axis order looks N,E [U].
- Context [V, OpenTopography https://object.cloud.sdsc.edu/v1/AUTH_opentopography/www/metadata/NO_1mDEM_metadata.pdf and Kartverket Oslo's fylkesgeodataplan 2024–27]:
  - The national detailed height model (NDH) was completed in 2022. Most scanning was 2014–2019.
  - In built-up areas NDH **reused existing Geovekst laser data** (57,000 km²).
  - Rescanning after large terrain changes is planned "continuously" for 2024–27.
  - → For Oslo/Akershus the "best" scan may be from 2014–2019. That predates the rebuilt stations (Ski 2022, Drammen, Moss construction) **[U, must be checked]**.

### 1.3 DTM at 1 m
- **Høyde DTM1** (Kartverket): **CC BY 4.0** [V] (https://data.norge.no/en/datasets/1a7327eb-1fa5-3432-8dea-fc198a5ede13/hoyde-dtm1). Built from the ground points of the hoydedata.no projects, gridded to 1 m (also 10 m and 50 m) [V].
- **ATOM feed, plain HTTP, no login** [V]: https://nedlasting.geonorge.no/geonorge/ATOM/hoydedata/Hoydedata_ServiceFeed.atom → DTM1 https://nedlasting.geonorge.no/geonorge/ATOM/hoydedata/datasett/DTM1.atom and DOM1 (…/DOM1.atom).
  - Rights: NLOD 2.0. CRS **EPSG:25833**, GeoTIFF [V].
  - Tile URL pattern [V]: `https://nedlasting.geonorge.no/hoydedata/DTM1/33-<col>-<row>.tif`, in **15 km tiles of about 1.0–1.2 GB each** [V, sizes from the feed].
  - My fetch tool refused to download a .tif (client_error, probably size) [X]. The feed is public and lists direct links, so curl should work [U].
  - The grid I derived from two feed polygons: x_min ≈ −1,599,575 + 15,000·col and y_min ≈ 4,925,995 + 15,000·row [V for those two tiles]. Station tiles (inferred) [U]:
    - **33-124-114**: Oslo S, Nationaltheatret
    - **33-123-114**: Skøyen, Lysaker, Sandvika
    - **33-122-114**: Asker
    - **33-122-113**: Drammen (on a tile edge, col fraction 0.01)
    - **33-125-115**: Lillestrøm
    - **33-124-113**: Ski
    - **33-123-111**: Moss
    - **33-125-116**: Oslo lufthavn
- **WCS, free, "AccessConstraints: None"** [V]: https://wcs.geonorge.no/skwms1/wcs.hoyde-dtm-nhm-25833?service=WCS&request=GetCapabilities
  - Coverage `nhm_dtm_topo_25833` (plus a hillshade). GeoTIFF/JPEG2000/NetCDF, EPSG:25833/4326. WCS 1.0–1.1.2 (2.0.1 advertised).
  - **This is the best way to cut a 1 km × 1 km DTM per station without downloading 1 GB tiles.** I assume native 1 m, but did not check DescribeCoverage [U].
- Vertical datum **NN2000** (EPSG:5941) [V via OpenTopography and project records].
- DOM1 (surface model, 1 m) uses the same feed. It is useful for roofs and canopies when building points are missing [V that it exists].

---

## 2. Platform register

### 2.1 Bane NOR station pages: the per-platform table (the main source)
- Each banenor.no station page has a **"Sporplan" image plus a track/platform table** [V]. The columns:
  - Spor Nr. | Type | Lengde (m) | Kryssingssporlengde (m) | Forlenget (m)
  - **Plattform: Lengde (m) | Høyde | Bredde (m)**
  - Merknader (platform type and which tracks it serves, e.g. "Mellomplattform Dekker spor 1 og 2", "Sideplattform").
  - The Norwegian header says "Høyde (m)" and the English one says "Height (mm)". The values look like mm (760, 700, 570, 560, 340/100) [V values, U unit]. → **Parse the HTML table, not my rendered text**: the merged headers made the column order ambiguous in my tool.
- **Roof is not in the table** [V for every page I opened]. Roofs must come from laser/DOM1 or OSM (`covered=yes`, `building=roof`).
- URL pattern (EN) [V]: `https://www.banenor.no/en/traffic-and-travel/railway-stations/-<first letter>-/<slug>/`. The NO equivalent is `https://banenor.no/reise-og-trafikk/stasjoner/-<letter>-/<slug>` (e.g. `-t-/trondheim-s` [V]). The NO Oslo S URL failed [X], but the EN page works.
  - Track plan image pattern [V]: `/globalassets/stasjonssider-felles-innhold/sporplan-stasjoner/-t-/trondheim-stasjon_....png`
- What I checked:
  - **Oslo S** (EN slug `-o-/oslo-central`) [V]:
    - Tracks are labelled **OS1–OS19** (plus FB/ØB codes).
    - Platform rows, e.g. OS1 "369 | 252 | 570 | 9,30" (platform 252 m, height 570, width 9.30 m) and OS9 "246 | 238 | 700 | 9,30".
    - Island platforms OS1/2 … OS17/18, and side platform OS19 (height 570, width 10).
  - **Lysaker** [V]: tracks 1–4; island platforms 2/1 and 3/4, "280 | 700 | 13" and "266 | 700 | 13".
  - **Sandvika** [V]: tracks 1–4; island platforms 1/2 and 4/3, length 268, height 700, width 10.
  - **Ski** [V]: island platforms 2/1, 3/4 and 6/5: 350 m, 760, widths 7/7/5. Platforms 12/13 are for stabling (340/100).
  - **Lillestrøm** [V]: island platforms 2/1, 3/4 (350, 700, ~9–10.3), 6/7 (350, 560, 11.70) and 8/9 (250, 560, 11).
  - **Moss** (old station) [V]: side platform track 1 and island 2/3. The page says the station is "not adapted", with low platforms and a level crossing with steps.
  - **Oslo lufthavn** (EN slug `-o-/oslo-airport`) [V]: tracks 1–4, island platforms 1/2 and 4/3, values incl. 760 and widths 12/8.
  - **Nationaltheatret** [V]: **no table**. Text only: tracks 1–2 (westbound) are in the old hall and 3–4 (eastbound) in the new hall.
  - Asker, Drammen, Skøyen: pages not opened; likely present [U].
- Licence: these are the owner's published facts (no open licence stated) [V that no licence is stated].

### 2.2 Network Statement 2027 (Bane NOR)
- https://oppslagsverk.banenor.no/en/network-statement/2027/infrastructure/ [V]:
  - "For information about a specific station, **including track table and track plan**, see our overview of stations" (the banenor.no pages above).
  - **There is no separate platform annex** like the Swedish one [V; the 2027 download page lists only the two NS PDFs: https://oppslagsverk.banenor.no/en/network-statement/2027/download].
  - "At the start of R27, Bane NOR plans to use **RINF** as the main source of infrastructure information", but the link is "coming" [V].
  - The infrastructure database is **Maximo** ("contact Maximo in Bane NOR"), which is not public [V].
- NS 2027 EN PDF: https://oppslagsverk.banenor.no/siteassets/network-statement/network-statement-2027-en.pdf [U, URL from search, not opened].
- **RINF / ERA Knowledge Graph:** the ERA KG dump is on Zenodo under CC BY 4.0 (https://zenodo.org/records/16413403/latest) [V]. ERA has platform-edge entities (length, height). **Whether Norway's platforms are in it is unconfirmed** [U]. If Bane NOR loaded RINF for R27, this could become an open, licensed platform register; check with SPARQL.

### 2.3 Geonorge / Bane NOR open GIS
- **Jernbane – Banenettverk** (Bane NOR, **NLOD**, no login) [V]: https://data.norge.no/en/datasets/5b43a7f6-297b-3d6e-aef7-1def52938093
  - WFS https://wfs.geonorge.no/skwms1/wfs.banenettverk?request=GetCapabilities&service=WFS, WMS (same path, `wms.`) and ATOM http://nedlasting.geonorge.no/geonorge/ATOM-feeds/Banenettverk_AtomFeedGML.xml.
  - Feature types: **Banelenke, Stasjonsnode, Kilometerpunkt, Banekjedebrudd. No platforms** [V]. Useful for track centre-lines and station nodes only.
- **FKB-Bane** (tracks **and platforms** as geometry) [V]: https://dokument.geonorge.no/produktark/fkb-bane/2025-01-07/fkb-bane.pdf. **Norge digitalt licence; download only for Norge digitalt parties, private users buy via reseller → not usable.**
- "Jernbanedatabasen"/"banedata": I found no public download. Bane NOR's banedata catalogue (proing.banenor.no) is technical documentation. The "Digital Infrastructure Model (DIM)" only shows a dev URL (https://dim-dev.review.apps.banenor.no/) [V link on the Jernbanedirektoratet page; U for access].
- Jernbanedirektoratet infrastructure model (railML 2.4nor/3.2 via NorRailView) [V]: https://www.jernbanedirektoratet.no/en/infrastructure-model-a-digital-description-of-the-railway/. The models are for future/planning scenarios, the licence is not stated, and existing infrastructure is in Bane NOR's DIM [V]. Not a register source.

### 2.4 Entur National Stop Place Registry (NSR)
- **Licence: NLOD** [V] (https://developer.entur.org/stops-and-timetable-data, https://developer.entur.org/pages-nsr-nsr).
- **NeTEx exports, nightly, plain HTTP, no login** [V]:
  - https://storage.googleapis.com/marduk-production/tiamat/Current_latest.zip
  - …/CurrentAndFuture_latest.zip
  - …/Full_latest.zip
  - a rail-only export **RailStations_latest.zip** in the same path [V that it is listed]
- **REST API** `https://api.entur.io/stop-places/v1/read` (docs https://developer.entur.no/apis/stop-place-v1-read) [V]. **My call worked without a key**: https://api.entur.io/stop-places/v1/read/stop-places/NSR:StopPlace:337 [V]. Entur asks clients to send an `ET-Client-Name` header [U, from memory; the docs page I read did not say].
- What it gives for **Oslo S (NSR:StopPlace:337, RAIL_STATION)** [V]:
  - **19 quays**; `publicCode` = track number (1, 2, 3, 4, …); one lat/lon per quay (e.g. NSR:Quay:565, track 1, 59.911095, 10.755664).
  - `wheelchairAccess`/`stepFreeAccess` = TRUE; escalator/lift/audible/visual = UNKNOWN.
  - **Boarding positions A–H** (sectors) on 4 quays.
  - Stop-place equipment: SanitaryEquipment (1 toilet), WaitingRoomEquipment (100 seats), TicketingEquipment (17 machines, ticket office).
  - No quay descriptions, and no lift/escalator objects.
- → Use NSR for **track numbers, platform point coordinates, sector letters and accessibility flags**. It has no heights, lengths, widths or roofs.

---

## 3. Station facts

### 3.1 Owners and operators
- **Bane NOR SF owns the stations** [V]: Wikipedia infoboxes for Nationaltheatret (https://en.wikipedia.org/wiki/Nationaltheatret_station) and Oslo Airport station (https://en.wikipedia.org/wiki/Oslo_Airport_Station; ownership moved from NSB Gardermobanen to the rail administration in 2001).
- Moss: owned by Bane NOR, operated by Vy (https://en.wikipedia.org/wiki/Moss_Station) [V].
- **Bane NOR Eiendom** runs the commercial property. oslo-s.no links to banenoreiendom.no in its footer [V], and its homepage lists no other station-centre sites for these stations (only Trondheim's) [V].
- **Oslo lufthavn:** Bane NOR owns the station under the terminal, Avinor (Oslo lufthavn AS) runs the terminal and its shops, and Flytoget runs the airport express [V for the station; U for the exact Avinor legal entity].

### 3.2 Station pages with facilities, shops and hours
- **oslo-s.no** (Oslo S only) [V]: https://oslo-s.no/
  - **25 eateries** (https://oslo-s.no/spisesteder/) and **21 shops** (https://oslo-s.no/butikker/), one page each (`/butikker/<slug>/`).
  - Shop pages give **hours + hall + level**. Example, https://oslo-s.no/butikker/narvesen/ [V]: "Narvesen Hovedhallen, plan 1, open every day 05:00–21:00". It also says there are 2 units in Hovedhallen plan 1 and 1 in Flytogterminalen.
  - Joker has a page (https://oslo-s.no/butikker/joker/) [V that it exists].
  - Hall names used: Hovedhallen, Østbanehallen, Flytogterminalen, levels "plan 1" and "plan U" [V].
  - Practical info: toilets (Hovedhallen level U, opposite La Baguette, 20 NOK, attended), luggage storage, tickets [V] — https://oslo-s.no/praktisk-info/
  - **Floor plan image**: https://oslo-s.no/wp-content/uploads/sites/4/2024/04/Kart-Oslo-S-2025_mars-1.jpg [V]. Use it for facts only (positions); it is copyrighted.
- **banenor.no station pages** (all stations) [V]:
  - Facility lists: lift, WC/HC WC, ticket machines (count), waiting room hours, lockers ("storage boxes"), ATM, parking and bike hotel.
  - Shops are only "Refreshments / several coffee shops", **with no names or hours**. Ticket office hours are given only at Oslo S (Mon–Fri 06:30–23:15, Sat–Sun 10:00–18:00) [V].
  - Checked: Oslo S, Lysaker (waiting room 05:30–23:30), Sandvika (waiting room Mon–Fri 06:30–18:00), Ski, Lillestrøm ("Open 04.00–02.00"), Moss, Oslo lufthavn, Nationaltheatret (3 street entrances: Johanne Dybwads plass, Ruseløkkveien, Parkveien/Henrik Ibsens gate).
- **Avinor, Oslo lufthavn** [V]:
  - Shops/food list: https://www.avinor.no/flyplass/oslo/shopping-og-mat/. Each outlet has a location line ("Ankomstområdet – Ankomsthallen", "Innland – Gate A10"); hours appear for only a few.
  - Maps: https://www.avinor.no/flyplass/oslo/info/kart/ (static JPG for departures and arrivals; **the train station level is not shown**; © Avinor).
- **No station-specific sites found** for Lillestrøm, Drammen, Asker, Sandvika, Ski, Lysaker, Skøyen or Moss [U]. Shops there sit in the station building or in nearby malls (e.g. Sandvika, Lillestrøm), and will have to come from chain locators + OSM.

### 3.3 Published station plans (PDF)
- **No PDF station plans found** for any of the 11 stations [V for Bane NOR, oslo-s.no and Avinor pages, which link images only; U that none exist].
- Bane NOR sporplan images (track layout PNG) exist per station [V].
- The oslo-s.no floor plan JPG [V] and the Avinor terminal JPGs [V] are the only "maps".
- **Ruter interchange maps:** none found. Ruter publishes timetables and a tourist map PDF (https://ruter.no/globalassets/rutetabeller/turistkart/turistkart-2024.pdf) [V that it exists]; I found no station or interchange plans [U]. I did not check Brakar (Drammen) or Østfold kollektivtrafikk (Moss) [U].

### 3.4 Chain store locators
- **7-Eleven** https://www.7-eleven.no/butikker [V]:
  - Gives name, street address and an hours toggle (the hours are in the HTML), plus an "Åpne i Google Maps" link (**do not use**). **No coordinates and no in-station position.**
  - Station units listed: "Nationaltheatret jbst. Abelhaugen", "Flytogterminalen, Oslo", "Jernbanehallen, Oslo" (both Jernbanetorget 1).
  - The "Drammen" entry is at Bragernes torg, not the station.
- **Narvesen** https://www.narvesen.no/butikker [X, fetch failed]. Oslo S units are covered by oslo-s.no [V].
- **Deli de Luca, Joker, Rema 1000:** locators not checked [U]. Joker Oslo S is on oslo-s.no [V].
- → Chain locators give **hours but not position inside the station**. Position must come from oslo-s.no (hall/level), OSM, or the plan image.

### 3.5 OSM and Wikimedia Commons
- **OSM spot-check at Oslo S: not possible from here [X].** overpass-api.de and api.openstreetmap.org are robots-blocked for my tool, and the kumi/private.coffee mirrors errored. OSM is ODbL, which is allowed under the rules. Query to run with curl (Overpass), within ~150 m of 59.9109,10.7525:
  `[out:csv(::id,name,shop,amenity,level,opening_hours;true;"|")];nwr(around:150,59.9109,10.7525)[~"^(shop|amenity)$"~"."];out;`
  Count how many have `level` and `opening_hours`. Then compare with the 46 outlets on oslo-s.no.
- **Commons:** direct fetch failed [X]. A mirror shows "Category:Interiors of railway stations in Norway" and "Category:Train station platforms in Norway" exist [U]. Expect good photo coverage for Oslo S and Nationaltheatret [U].

---

## 4. Special cases (laser limits, underground, shared modes)

| Station | Issue | Status |
|---|---|---|
| **Nationaltheatret** | Fully underground, about 30 m deep in the Oslo Tunnel; 2 island platforms, 4 tracks (242 m and 250 m). The metro station of the same name is separate, above and offset. **Laser gives only street level and the 3 entrances; the platforms need register + plans.** | [V] Wikipedia + Bane NOR |
| **Oslo lufthavn** | Station directly below the terminal; tracks continue north in a tunnel. **Laser useless for platforms**; reached by escalators/lifts from the arrival hall. | [V] |
| **Oslo S** | 19 tracks with island platforms. Large platform canopies (sparse ground points under them). Shared hub with metro (Jernbanetorget), tram and bus terminal. Platform modernisation is being tendered, so the laser may predate changes. | [V] tracks; [U] canopy extent, modernisation timing |
| **Ski** | Rebuilt for the Follo Line (opened Dec 2022), with a large new roof. The Follo tunnel portal is north of the station. **Any scan before 2022 shows a construction site.** | [V] tracks; [U] scan date |
| **Moss** | A new station about 300 m south is "severely delayed" (unstable ground). The Bane NOR page still describes the old station (low platforms, level crossing). **Register and laser must be for the station in service on the reference date.** | [V] |
| **Drammen** | Station recently rebuilt [U]; check that the scan year is after completion. Page not opened. | [U] |
| **Lysaker** | Major interchange with bus. A future Fornebubanen metro is under construction nearby; some platform areas lie under road decks. | [U] |
| **Lillestrøm, Sandvika, Asker, Skøyen** | Surface stations with canopies and bus terminals. Skøyen has protected 1916 platform cover/stairwell for tracks 3/4 and 1/2 (Bane NOR heritage list, https://www.banenor.no/contentassets/ae771adc1e734d2dade953123754ffb4/katalog-1-oslo-navet-feb24-e.f.pdf). | [V] Skøyen heritage; rest [U] |

General laser limits:
- Building class 6 is optional in FKB-Laser [V].
- Older Oslo projects (2011/2014) are FKB-Laser 2.0 and possibly restricted [V for the fields].
- Tunnels and below-terminal stations get no returns [V for the layout].

---

## 5. Per-station summary

| Station | Owner / operator | Platform register | Facts sources | Laser / DTM | Special issues |
|---|---|---|---|---|---|
| Oslo S | Bane NOR; Bane NOR Eiendom (oslo-s.no) | banenor.no table OS1–OS19 [V]; NSR 19 quays + sectors [V] | **oslo-s.no: 46 outlets with hours + hall/level** [V]; plan JPG [V]; Bane NOR facilities [V] | ≥9 projects; 2014 10 p and 2011 5 p seen, both TILGANG=2 [V]; DTM1 tile 33-124-114 [U] | Canopies; metro/tram/bus hub |
| Nationaltheatret | Bane NOR [V] | **No table on the page** [V]; NSR quays [U] | Bane NOR facilities, 3 entrances [V]; 7-Eleven in the station [V] | Surface only | **Underground, 30 m deep** |
| Skøyen | Bane NOR [U] | banenor.no table [U] | Bane NOR page [U]; OSM | DTM1 33-123-114 [U] | Protected platform covers; tram |
| Lysaker | Bane NOR [U] | table [V] (280/266 m, 700, 13 m) | Bane NOR (waiting room hours, 3 ticket machines) [V] | 33-123-114 [U] | Road decks [U]; bus |
| Sandvika | Bane NOR [U] | table [V] (268 m, 700, 10 m) | Bane NOR [V]; nearby mall via OSM | 33-123-114 [U] | Bus terminal |
| Asker | Bane NOR [U] | table [U] | Bane NOR page [U] | 33-122-114 [U] | — |
| Drammen | Bane NOR [U] | table [U] | Bane NOR page [U] | 33-122-113, tile edge [U] | Recent rebuild [U] |
| Lillestrøm | Bane NOR [U] | table [V] (350/250 m, 700/560) | Bane NOR (open 04–02) [V] | 33-125-115 [U] | Bus terminal |
| Ski | Bane NOR [U] | table [V] (350 m, 760, 7/5 m) | Bane NOR [V] | 33-124-113 [U] | **Rebuilt 2022, check scan date** |
| Moss | Bane NOR / Vy [V] | table [V] (old station) | Bane NOR [V] | 33-123-111 [U] | **New station delayed** |
| Oslo lufthavn | Bane NOR station; Avinor terminal; Flytoget | table [V] (760, 12/8 m) | Avinor shop list + JPG maps [V]; Bane NOR [V] | Not useful (under terminal) | **Below terminal** |

---

## 6. Best plan, quality compared with Sweden, and gaps

**Plan**
1. **Platform register:**
   - Scrape the banenor.no station tables (HTML) for track, platform length, height and width, plus the comment for island/side platform and paired tracks.
   - Join them to **Entur NSR quays** (NLOD) for track publicCode, coordinates, sector letters and step-free flags. Use the nightly `RailStations_latest.zip`.
   - Nationaltheatret: build from NSR + text.
   - Roof: from DOM1/laser or OSM.
   - Check ERA RINF/KG for Norwegian platform edges as a licensed backup.
2. **Terrain:** take DTM1 from the **WCS** `nhm_dtm_topo_25833` (no login, free, NN2000, EPSG:25833) as 1 km clips per station. The ATOM tiles (1 GB each) are the fallback.
3. **Point clouds:**
   - First run the project WFS per station (curl), keep the newest `BEST_OPEN=1` project, and check its year against the station rebuild dates.
   - Then **export LAZ by email from hoydedata.no (no login)**. This needs a person with an inbox; with the user's agreement, the session's email connector could pick up the link.
   - Read the classes from the LAZ header; expect 2/7/17, and maybe 6.
   - Transform to EPSG:25833 if the export came in 25832.
4. **Station facts:**
   - oslo-s.no for Oslo S (hours + hall/level, plan JPG for position).
   - Bane NOR pages for facilities at every station.
   - Avinor list for OSL.
   - OSM (Overpass via curl) for positions at the other stations.
   - Chain locators for hours (7-Eleven, ignoring the Google link).
   - Commons for photos.

**Expected quality compared with Sweden**
- Platform register: **about as good, or better**, on length, height and width (station tables, plus NSR sectors and coordinates under NLOD). **Roof is missing** (Sweden had it), and there is no machine-readable annex or WMS with platform polygons (FKB-Bane is restricted).
- Laser: **worse access** (manual email export rather than a STAC API; no plain-HTTP LAZ found). **Classification is less certain** (building class optional), and **scan dates may predate rebuilt stations**. The density is probably similar or better (10 p/m² urban).
- DTM: **equal or better** (1 m, open, WCS, no login).
- Shops/hours: **better at Oslo S** (official directory with levels), **weaker elsewhere** (Bane NOR lists no shops; it depends on OSM).

**Gaps / open items**
1. The newest open laser project and its year/classes per station [U]. This needs a curl query to the project WFS; my tool truncates the polygons.
2. The licence wording conflict (CC BY 4.0 / NLOD vs "Norge digitalt-lisens" on project records). Confirm with hoydedata@kartverket.no, or by checking whether an anonymous export succeeds.
3. No plain-HTTP point-cloud path. The email export needs a human or inbox; the Potree path is unverified.
4. Platform roofs and Nationaltheatret dimensions beyond the Wikipedia lengths.
5. OSM indoor coverage, Commons, the Narvesen/Deli de Luca/Rema locators, and Ruter/Brakar/Østfold maps were not checked [X/U].
6. Moss and Ski: decide the reference state (old vs new Moss) and check the laser date for Ski.
