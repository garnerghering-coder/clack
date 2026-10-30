# Denmark data-source scope: 51 railway stations

Scoping only, no data collected. Research date 2026-10-30. Only WebSearch and WebFetch were used.

**Status markers:**
- **[V]** Verified: I read it on the source page or in the service response in this pass.
- **[P]** Partly verified: the source exists, but a detail is still open.
- **[U]** Unconfirmed: from secondary sources or general knowledge, or inferred. Check before relying on it.

**Login key:**
- **NO-LOGIN**: works anonymously.
- **ACCOUNT**: the user must create a free account and/or token. We cannot do this ourselves.

---

## 1. Laser point cloud and terrain model (Danmarks Højdemodel, DHM)

### 1.1 Product facts

| Item | Finding | Status | Source |
|---|---|---|---|
| Owner | Klimadatastyrelsen (KDS), formerly SDFI/SDFE. Distributed via Dataforsyningen and Datafordeleren. KDS: "stiller Danmarks Højdemodel frit til rådighed på både Datafordeleren og Dataforsyningen". | V | https://www.klimadatastyrelsen.dk/groen-omstilling-og-klimasikring/klimasikring/danmarks-hoejdemodel |
| Licence | **CC BY 4.0**, stated in the official metadata for "Danmarks Højdemodel - Punktsky" (useLimitation/otherConstraints). | V | https://geodata-info.dk/srv/api/records/7ee6e838-151a-4c4a-ac92-883af29c25d4/formatters/xml |
| CRS | Horizontal: EPSG:25832 (ETRS89 / UTM 32N). Heights: DVR90. Compound CRS: EPSG:7416. | V (25832 from the metadata; DVR90 and 7416 from the ESSD paper) | metadata above; https://essd.copernicus.org/articles/14/823/2022/ |
| Point density | 4–5 pts/m² for the 2014/15 data; **8 pts/m² from 2018 onward**. | V | https://confluence.kds.dk/pages/viewpage.action?pageId=182190457 (DHM Datakvalitet) |
| Classes | Classified as "jord, vand, vegetation, bygninger, veje, jernbaner, broer, højspændingsledninger" plus noise and artefacts. Not every LAS class is used. "Ingen garanti for, at de tildelte klasser er korrekte". Numeric codes: ground 2, low/medium/high vegetation 3/4/5, building 6, water 9 (from the ESSD paper on the 2014/15 data). The codes for bridge, railway and road in the current product were not read: the product spec PDF (dhm-prodspec-v1.0.0.pdf) is robots-blocked. A **railway** and a **bridge** class would be directly useful for us. | P | Datakvalitet page above; ESSD paper; spec: https://confluence.kds.dk/download/attachments/25722920/dhm-prodspec-v1.0.0.pdf |
| Tiles | Point cloud and DTM come as **1 km × 1 km tiles**. A third-party guide says these are bundled into 10 km × 10 km ZIPs, named on the Danish square grid (e.g. `10km_623_56`), as LAZ. Older posts also describe 10 km blocks. | P (1 km tiles from ESSD; 10 km zip bundling from a third-party guide) | ESSD; https://lidarvisor.com/download-denmark-dataforsyningen/ (2026-02/03, third party) |
| Formats | Point cloud: LAZ and LAS. Rasters (Terræn, Overflade): GeoTIFF and ECW, 0.4 m grid. | V | https://confluence.kds.dk/pages/viewpage.action?pageId=158368173 (DHM Fildownload) |
| Datasets on Datafordeler Fildownload | Point clouds: `Punktsky` (current, rolling), `Punktsky2023`, `Punktsky2015`, `Punktsky2007`. Rasters: `Terraen`, `Overflade`, `Terraen2023`, `Overflade2023`, `Terraen2015`, `Overflade2015`, Bluespot2007 and Havstigning2007. | V | DHM Fildownload page above |
| Other DHM products | DTM 0.4 m (Terræn), DSM 0.4 m (Overflade; useful for roofs and canopies), contours, and **DHMOprindelse** (polygons giving the flight date of each area; **use this to get the scan date per station**). | V | https://confluence.kds.dk/pages/viewpage.action?pageId=25722920 |

### 1.2 Access methods: all need an account or token

| Channel | URL | Login | Status |
|---|---|---|---|
| Dataforsyningen web download, FTPS (`ftps://ftp.dataforsyningen.dk/dhm_danmarks_hoejdemodel/PUNKTSKY`) and webservices (WMS/WCS) | https://dataforsyningen.dk/data/3931 (dataset page, a JS app that I could not render) | **ACCOUNT.** Docs: "Du skal være oprettet som bruger på Dataforsyningen og være logget ind" to create a token, and "skal token altid sendes med hver forespørgsel… Kald uden token… vil fejle". Only DAWA and INSPIRE OGC services are exempt. Download_Manager uses a bearer token that lasts 24 h. User tokens do not expire. | V (token rule); P (that the FTPS needs the same user) |
| Datafordeler Fildownload | `https://api.datafordeler.dk/FileDownloads/GetFile?...&apikey=` | **ACCOUNT.** "Kendt bruger – der skal oprettes en bruger med e-mail eller MitID". The API key is created in Datafordeler Selvbetjening. | V (stated for the DHM entity downloads; same mechanism assumed for point cloud and rasters) |
| Datafordeler Filudtræk and REST | — | Being **phased out on 15 Jan 2027**. Do not build on these. | V |
| Datafordeler GraphQL, WMS, WMTS, WCS | https://confluence.kds.dk/pages/viewpage.action?pageId=25722934 | ACCOUNT (API key) | P |
| INSPIRE Elevation services | — | Dataforsyningen exempts INSPIRE OGC services from the token rule. Whether a DHM INSPIRE coverage service exists, and at what resolution, was **not found**. | U |
| STAC, COG or anonymous bucket | — | **None found.** Dataforsyningen's STAC covers only oblique photos (skråfoto). Nothing like Lantmäteriet's STAC exists for DHM. | V (absence, as far as searched) |

**Consequence:** the user must create one free Dataforsyningen account (email login) and a token, or a Datafordeler account with an API key. After that, tile downloads can be scripted.

### 1.3 Scan years and versions

- **Rolling cycle, not national campaigns.** About one-fifth of the country is scanned each spring, before the leaves come out (about 11 of 55 blocks per year), on a five-year cycle. **[V]**
  - KDS page: https://www.klimadatastyrelsen.dk/kortlaegning/flyfotos-og-laserscanning
  - Metadata maintenance note (geodata-info record above).
- **First 8 pts/m² cycle, 2018–2022.** Per-region years:
  - 2018: Fyn, Lolland-Falster and eastern Sønderjylland
  - 2019: Sjælland
  - 2020: Syd- and Vestjylland (LOT3)
  - spring 2021: Midtjylland (LOT4)
  - 2022: Nordjylland
  - **Status:** [V] for 2018, 2019 and 2022 (KTC 2020 article; GeoDanmark 2023 article); [P] for 2020 and 2021 (third-party MapMagic wiki).
  - Sources: https://www.ktc.dk/geooest/diskussion/status-opdateret-hoejdemodel, https://www.geodanmark.dk/news/nye-stoettedata-til-kvalitetsloeft-og-opdatering-af-det-hydrologiske-tilpasningslag/, https://mapmagic.dk/wiki/Punktsky
- **"LAD18-19" is not a KDS name I could find.** The 2018–19 scans are simply the first two years of that cycle. Most of our stations are on Sjælland, so they were scanned in **2019**.
- **LAD24-27** ("LiDAR acquisition of Denmark 2024-27") is the tender for the second cycle. **[V]** (tender title)
  - https://eu.eu-supply.com/ctm/Supplier/PublicPurchase/380886/1/0
  - https://stotles.com/explore/notices/a954c2b2-5b2b-4017-9df2-7999e7d2600f/lidar-acquisition-of-denmark-2024-27-lad24-27
  - The KTC article says Sjælland was due again in **2024**. **[V]**
- **Inferred second-cycle years [U]:** Fyn 2023, Sjælland 2024, Syd/Vest 2025, Midt 2026, Nord 2027.
- **What is downloadable now:**
  - `Punktsky` is the current, continuously updated version. A block appears about 1 to 1.5 years after it is flown (MapMagic). **[P]**
  - MapMagic says "Version 2024 er den seneste". The date of that statement is unknown. **[U]**
  - `Punktsky2023` is a frozen snapshot. **[V]** (it exists)
  - Expected for our stations **[U]**:
    - Sjælland stations (most of the list): 2024 scan probably in `Punktsky` by now, otherwise the 2019 scan.
    - Fyn (Odense, Middelfart): 2023 or 2018.
    - Jutland stations: 2020–2022 scans. The 2025–2026 rescans are probably not yet published.
  - **Action:** read DHMOprindelse per tile. The live status map is https://earthmaps.dataforsyningen.dk/lidarStatus (JS, not read).

---

## 2. Platform register

### 2.1 Banedanmark, Netredegørelse 2027, Bilag 3.6 "Perronlængder og -højder" **[V]**

- **Document:** https://banedanmark.dk/-/media/Bane/Dokumenter/Jernbanevirksomhed/Netredegoerelse/2027-Hoeringsversion/Bilag/3_6-Perronlaengder-og-hoejder.pdf
  - The path says "Hoeringsversion" (consultation version) and the table carries a "1. august 2023" header.
  - The NS 2027 main document is v2, dated 17 Mar 2026. It refers to Bilag 3.6 and is valid from 13 Dec 2026 to 11 Dec 2027: https://www.bane.dk/da/Jernbanevirksomhed/Netredegoerelser/-/media/6BB921D2E1FD40F4AEA92EB06A2B2163.ashx
  - Index page: https://banedanmark.dk/da/Jernbanevirksomhed/Netredegoerelser/Netredegoerelse-2027
- **Columns:** TIB nr (route), Stationsnavn, Perronnummer, **Spornummer**, **Perronlængde (m)**, **Perronhøjde (cm over skinneoverkant)**.
  - This gives a numeric height in cm, which is better than the Swedish height classes.
  - **No width and no roof.**
- **Coverage:** all 51 of our stations except **Hårlev, Kagerup** (Lokaltog infrastructure) and possibly the Lokaltog platforms at Hillerød, Køge and Tølløse.
  - **København Syd** is listed under its old name **"Ny Ellebjerg"**. DSB: "København Syd (tidligere Ny Ellebjerg)".
  - **CPH Airport** appears to be listed as **"Kastrup"**: TIB 11, 2 × 322 m at 55 cm. This matches Sund & Bælt's "about 320 m" station. DSB's URL slug is `kobenhavns-lufthavn-kastrup`. **[P]**
- **Licence:** none stated. Treat it as the IM's own published facts with attribution, as in Sweden. **[V]** (no licence text)
- **Caveat:** my values were extracted by an LLM-based fetch. Parse the PDF directly before use.

### 2.2 Banedanmark Open Data (ArcGIS Hub) **[V]**

- **Portal:** https://geodata-banedanmark.opendata.arcgis.com/ (27 layers).
- **Catalogue entry:** CC BY 4.0, "Creative Commons Kreditering 4.0 International": https://datavejviser-indtastning.digst.govcloud.dk/dataset/banedanmarks-abne-data
- **Access:** ArcGIS REST FeatureServer, NO-LOGIN, EPSG:25832, 1,000 records per request (page through). Exports as GeoJSON, Shapefile, GPKG or CSV from the Hub.

**Befæstede arealer (paved surfaces), polygons:**
- Service: https://services1.arcgis.com/QcgJt0vVxSaqMKl7/arcgis/rest/services/Befaestede_arealer_OpenData2/FeatureServer/0
- Fields: `befaestet_formaal` (values include **Perron, Trappe, Rampe, Tunnel, Gangbro_Spang, Overgang**, Plads, Sti_Fortov, Parkering, Vej), `stednavn`, `ejes_af`, `vedligeholdes_af`, `befaestet_type`, `kommentar`.
- **906 Perron polygons across 307 place names.** Covered: København H, Nørreport, Østerport, Ny Ellebjerg, Hellerup, Valby, all of Kystbanen, Høje Taastrup, Hedehusene, Trekroner, Roskilde, Ringsted, Sorø, Slagelse, Holbæk, Tølløse, Køge, Køge Nord, Ølby, Næstved, Hillerød, Odense, Middelfart, Fredericia, Kolding, Vejle, Skanderborg, Viby J, Århus H, Bramming, Esbjerg, Herning, Skørping, Aalborg, "Aalborg Vestby by", Lindholm, "Hjørring by".
- **Missing:** Ørestad, Tårnby, CPH Airport/Kastrup, Kagerup and Hårlev (these stations are not owned by Banedanmark).
- These polygons give **platform outline, which gives width**. They are the counterpart to the Swedish WMS platform objects.
- Caveat: polygons are split into surface patches. At København H about 50 Perron pieces carry `ejes_af=Banedanmark`.

**Other layers:**
- **Adgangskonstruktioner** (points; Trappe etc. with `bredde_cm`, `laengde_m`, `raekvaerk_hoejde_cm`). These look like trackside access steps, not passenger stairs. **[P]**
- **Broer og tunneller**: the `bygart` domain includes **"Perrontunnel" (code 42)**, which is useful for underpasses.
- **Sporforløb** (track centrelines with `SPORNUMMER`, polylines): https://services1.arcgis.com/QcgJt0vVxSaqMKl7/arcgis/rest/services/Sporforloeb_OD/FeatureServer/0. Use it to tie Bilag 3.6 track numbers to the geometry.
- **The "Platforme" layer is NOT passenger platforms.** It holds points for maintenance standing platforms (Sikringsskab, Teknikhytte, Signal, Elskab). Do not use it.
- **No roof (perrontag) layer exists.**

### 2.3 Other Banedanmark documents

- **TIB-S "Strækningsoversigter"**, valid from 20.07.2026. **[V]**
  - Schematic track diagrams per route section, with station codes (e.g. "Roskilde (Ro) km 31,3") and track numbers.
  - No platform lengths. Useful for cross-checking track numbers.
  - https://bane.dk/da/Jernbanevirksomhed/Sikkerhed/Trafikale-regler/SR/TIB_S/-/media/A979101643474EA4B288069A3745A125.ashx
- **BaneGISX** (the IM's GIS register named in NS 2027, "data i BaneGISX er vejledende"). Internal; needs an X-user, so effectively ACCOUNT, and not for us. The open Hub in 2.2 is its public outlet. **[P]**
- **ERA RINF knowledge graph**, CC BY 4.0. **[P]**
  - SPARQL endpoint `https://rinf.data.era.europa.eu/api/v1/sparql/rinf` works NO-LOGIN.
  - Roskilde exists as OP `DK00017` with 25 tracks.
  - The ontology has `PlatformEdge` with `platformHeight`, `lengthOfPlatform` and `platformId`.
  - **I could not confirm that Danish platform edges are populated.** A search for DK platform-edge URIs returned nothing; the more targeted queries failed in WebFetch.
  - Dump: https://zenodo.org/records/16413403/latest (v10, Aug 2026).

### 2.4 NeTEx and stop places (Rejseplanen / NAP)

| Source | What it gives | Licence | Login | Status |
|---|---|---|---|---|
| Rejseplanen stoppestedsdata (CSV, all stops, plus an S-tog-only file; updated about every 14 days) | stop id (86xxxxx for DK stations), name, x/y in WGS84. **No quays or tracks.** | **CC BY 4.0** | resource pages on the CKAN catalogue. A Labs page says access is described "her" (not readable) | V (licence, fields); P (download path). https://datavejviser-indtastning.digst.govcloud.dk/dataset/rejseplanen-stoppestedsdata, https://labs.rejseplanen.dk/hc/en-us/articles/21639781805853-Om-stoppestedsdata |
| Rejseplanen NeTEx (XML), on the Danish NAP "Dataudveksleren" (dataset 242), first published 2025-01-22 | timetables and stops. Quay or track content **not confirmed** | not stated | NAP: "Alle kan oprette profil/logge ind med MitID". **ACCOUNT likely** | P. https://datavejviser.dk/katalog/rejsekort-rejseplan-a-s/3d0e7287-4ff7-4e56-96f4-94be51fad81a, https://du-portal-ui.dataudveksler.app.vd.dk/data/242/overview (JS), https://itsdanmark.dk/media/jtmm12pj/itsdanmark-aarsmoede-2024-national-adgangspunkt-for-aabne-mobilitetsdata.pdf |
| Rejseplanen GTFS (`https://www.rejseplanen.info/labs/GTFS.zip`) | stops, routes. `platform_code` **not confirmed** | "Unknown" in the public-transport.earth index | probably NO-LOGIN | U. https://eu.data.public-transport.earth/ |
| "Den Nationale Stoppestedsdatabase" | **No Danish national stop register like Norway's NSR was found.** | — | — | V (absence, as far as searched) |

**Conclusion:** use Bilag 3.6 for track ↔ platform. Use NeTEx or GTFS only for stop IDs.

### 2.5 Metro (Metroselskabet): scope decision

Nørreport, Østerport, CPH Airport and Ørestad each have a **separate Metro station**:
- Nørreport M1/M2: underground.
- Østerport M3/M4: underground.
- Lufthavnen M2: at the end of Terminal 3. CPH says it lies "i direkte forlængelse af Terminal 3", with a first-floor footbridge of about 100 m. **[V]** https://www.cph.dk/parkering-transport/bus-tog-metro-taxi/metro
- Ørestad M1: elevated, above the regional-train cutting.

No open per-platform Metro register was found. Metro platforms sit behind platform screen doors and are not in Bilag 3.6. **[U]** (metro register)

**Recommendation:**
- **In scope:** the DSB/Banedanmark platforms (S-tog and regional).
- **Metro:** record only the transfer entrance and lift as a station-facts item (with a source: m.dk, OSM).
- **Out of scope:** Metro platforms in the platform register and the 3D pack.

### 2.6 Lokaltog and Movia (Hillerød, Kagerup, Hårlev, Køge, Tølløse)

- Lokaltog A/S both operates the trains and manages its own infrastructure:
  - Gribskovbanen: Hillerød–Kagerup–Gilleleje/Tisvildeleje.
  - Frederiksværkbanen: from Hillerød.
  - Østbanen: Køge–Hårlev–Faxe Ladeplads/Rødvig. Service resumed 9 Sep 2024 after renewal. **[V]** https://www.lokaltog.dk/projekt-oestbanen/
  - Tølløsebanen: Tølløse–Slagelse.
  - Movia is the purchasing transport authority. **[U]** for the Movia role (general knowledge).
- **No Lokaltog network statement or platform table was found.** lokaltog.dk station pages could not be fetched (client error). **[U]**
- Bilag 3.6 only covers Banedanmark-managed platforms: Køge, Tølløse, and S-tog Hillerød (track 1/11/3/4 at 92 cm).
- Kagerup: one platform and two tracks (Wikipedia; it names the old owner, Hovedstadens Lokalbaner, which merged into Lokaltog). **[U]**
- **Fallback for Kagerup, Hårlev and the Lokaltog platforms:** height and length from the laser data, plus OSM and Commons photos.

---

## 3. (Not requested; numbering follows the brief)

---

## 4. Station facts

### 4.1 Ownership and operators

- **"Ejerskabet til stationerne er delt mellem DSB og Banedanmark".** DSB generally owns the station buildings and concourses, and Banedanmark the platforms and access. **[V]**
  - Source: Transport Ministry contract annex: https://www.trm.dk/media/52znyove/bilag-5-stationer.pdf
  - At København H the open-data Perron polygons carry `ejes_af=Banedanmark`. Some walkways are flagged `Overdrages_til_DSB`. **[V]**
- **S-bane:** NS 2027 §2.3 states the **S-bane is being transferred to DSB as infrastructure manager on 1 January 2027**. Bill L 8 (2025-26): "DSB kan blive infrastrukturforvalter på S-banen i stedet for Banedanmark." **[V]**
  - So from 2027 the S-tog platforms at our S-tog stations change IM. Bilag 3.6 values stay valid as facts, but the attribution changes.
  - https://www.ft.dk/ripdf/samling/20251/lovforslag/l8/20251_l8_fremsaettelsestale.pdf
- **Øresund line:** "By & Havn owns Ørestad Station". Sund & Bælt owns Tårnby and Copenhagen Airport. **[V]**
  - https://sundogbaelt.dk/en/road-and-rail-links/oresund/stations-on-the-oresund-line/
  - Airport station facts there: about 320 m long, **platforms 6.5 m wide**, four double travelators, stairs and lifts in the middle up to the terminal, end stairs to the apron.
- **Lokaltog:** Kagerup, Hårlev, and the Lokaltog parts of Hillerød, Køge and Tølløse. **[P]**
- **Operators [U]** (general knowledge, not checked in this pass):
  - DSB: IC/RE, S-tog, Øresundståg/Kystbanen.
  - Nordjyske Jernbaner: regional trains Aalborg–Hjørring/Frederikshavn and Skørping.
  - Arriva: Jutland regional lines through Esbjerg, Bramming, Herning and Skanderborg.
  - Lokaltog.
  - Midttrafik (Aarhus Letbane at Aarhus H) is a transport authority, not a station owner.

### 4.2 DSB station pages: owner's facts, NO-LOGIN **[V]**

- Pattern: `https://www.dsb.dk/trafikinformation/stationer/<slug>/`
- Checked: kobenhavn-h, osterport, orestad, kobenhavns-lufthavn-kastrup, ny-ellebjerg (= København Syd), plus search hits for most others.
- **Gives:** access lines (Elevator / Trapper / Rulletrapper, present or absent only), toilets (with price and hours, e.g. Østerport "kr 5… kl 6-22"), ticket office hours, ticket machines, bagagecenter and lockers, DSB 7-Eleven hours, other named shops (e.g. Østerport: Espresso House, Joe & The Juice, no hours), waiting-room hours, parking.
- København H example: DSB Salg & Service Mon–Fri 07–20, Sat–Sun 08–18; DSB 7-Eleven Mon–Fri 05–01, Sat–Sun 24 h; Bagagecenter & GLS 05:30–01.
- CPH Airport example: toilets "Under terminal 3 (kælderniveau)"; ticket machines at DSB Salg & Service in T3.
- **Does not give:** positions, levels, which platform a lift reaches, or **station plans or PDF maps** (none linked on any page checked).

### 4.3 Station plans and maps

- **No DSB station-plan PDFs found.** **[V]** (absence on the pages checked)
- DSB's København H modernisation page shows only construction illustrations.
- **Gap:** level and lift-to-platform mapping must come from OSM, Commons photos, Bilag 3.6 and laser data.

### 4.4 7-Eleven Denmark store list **[V]**

- https://www.7-eleven.dk/find-butik: an HTML list with name/label, address, phone and **day-by-day opening hours**. NO-LOGIN. No coordinates and no API seen.
- **In-station position: coarse labels only.** Examples: "Nørreport Perron", "Århus H" and "Århus H IC" (two units), "Odense IC" (address "OBC, Østre Stationsvej 27,2"), and 12 airport units such as "CPH Lufthavn, Terminal 3, Landside".
- The fetched list was about 118 entries and may be truncated: København H and Høje Taastrup did not appear. Re-check with the browser agent.
- Station stores use the DSB customer-centre phone number, so they are DSB-franchise units.

### 4.5 København H shop list

- DSB's station page names only DSB-run units.
- The modernisation page lists the hall shops that stay open: **DSB Billetsalg, 7-Eleven, Lagkagehuset, Joe & The Juice, McDonald's, Max Burger, Starbucks, Dunkin' Donuts**. **[V]** https://www.dsb.dk/om-dsb/baredygtighed/virksomheden/modernisering-af-kbh-h/
- **Construction:** outdoor from 23 Mar 2026, indoor from 10 Apr 2026. **Three of the four hall shop areas are fenced off until mid-2028.** The fourth (the 7-Eleven area) runs until H2 2028. Toilets and entrances stay open, step-free. **[V]**
- **No full per-shop hours list found.** Hours must come from each shop's own site or OSM, and the layout is changing during the snapshot period.

### 4.6 CPH Airport

- cph.dk has per-outlet pages, e.g. https://cph.dk/en/shopping-dining/dining/steffs-place/steffs-place-terminal-3. **[P]**
- They give the terminal only. Hours and the map are behind JS ("Activate map").
- The DSB page and the 7-Eleven list give landside units in T3 with hours. **[V]**

### 4.7 OSM and Wikimedia Commons

- **OSM indoor spot-check at København H: NOT DONE.**
  - overpass-api.de, overpass.openstreetmap.ru and api.openstreetmap.org are robots-blocked for WebFetch.
  - The kumi.systems and private.coffee mirrors errored or rate-limited.
  - Recommend the browser agent, or a curl to Overpass, for: `nwr(around:150,55.6727,12.5646)[~"^(shop|amenity|indoor)$"~"."]`
- No Danish community indoor project for stations was found. **[U]**
- Wikimedia Commons is assumed usable as in Sweden (category per station). **[U]**

---

## 5. Special cases: underground, roofs, laser limits

General note: any platform under a deck, building or tunnel has **no ground points** there. Use Bilag 3.6 for length and height, plus OSM, instead of laser.

| Station | Issue | Status |
|---|---|---|
| **Nørreport** | Mainline and S-tog platforms are in the underground Boulevardbanen tunnel. Laser sees only the street-level pavilions. Metro is separate and deeper. | U (geometry); V (platform data in Bilag 3.6: P1 203 m/55 cm, P2 177 m/92 cm) |
| **Østerport** | Platforms in a cutting, partly under structures. Metro M3/M4 underground. | U |
| **CPH Airport** | Station is under Terminal 3 (DSB: toilets "kælderniveau"). The line runs underground north of the hangars. **No laser on the platforms.** Sund & Bælt gives 320 m × 6.5 m. | V (location, dimensions) |
| **Ørestad** | Regional platforms in an open cutting under the elevated metro and a covered footbridge ("overdækkede gangbro… åben hele døgnet"). Partial occlusion. | P |
| **København H** | Platforms in a cutting below street level, with individual canopies; road bridges cross the platform ends. Hall renovation 2026–28. | P |
| **Aarhus H / Odense** | Tracks partly beneath the Bruun's Galleri and OBC deck structures (7-Eleven "Odense IC" address "OBC… 27,2"). Expect occlusion. | U |
| **Høje Taastrup, Køge Nord, Ny Ellebjerg/København Syd** | Bridge and footbridge stations that occlude parts of the platforms. København Syd is multi-level (S-tog over regional). | U |
| **Roofs** | No roof attribute in Bilag 3.6 or the open data. Derive from DHM building class and the 0.4 m Overflade (DSM), plus Commons photos. GeoDanmark buildings (via Dataforsyningen, token) are a possible extra. | V (absence); U (GeoDanmark detail) |
| **Scan date vs change** | Stations rebuilt after their scan year will be stale. Examples: Køge Nord and Ølby (new platforms for the Ringsted line), Viby J (the 107 m platforms suggest a new stop), København Syd. Check DHMOprindelse. | U |

---

## 6. Per-station table

**Column key:**
- **3.6** = Bilag 3.6 platform heights in cm (✓ = present).
- **BDK** = Banedanmark open-data Perron polygons present.
- **DSB** = DSB station page exists (S = seen in search or fetched).
- **7E** = 7-Eleven station unit seen in the list.
- **Blk** = probable DHM scan block in the first cycle → second cycle **[U]**: S = Sjælland 2019→2024; F = Fyn 2018→2023; SV = Syd/Vestjylland 2020→2025; M = Midtjylland 2021→2026; N = Nordjylland 2022→2027.

**Operators** are [U] (general knowledge), as noted in 4.1.

| # | Station | Owner / main operators | 3.6 | BDK | DSB | 7E | Blk | Special |
|---|---|---|---|---|---|---|---|---|
| 1 | København H | DSB building, BDK platforms. DSB, Øresundståg, S-tog | ✓ 55/72/92 | ✓ | S | (U) | S | Hall works 2026–28; cutting; canopies |
| 2 | Aalborg | DSB/BDK. DSB, Nordjyske | ✓ 50 | ✓ | S | ✓ | N | 2022 scan |
| 3 | Aalborg Vestby | BDK. Nordjyske | ✓ 55 | ✓ ("…by") | U | – | N | |
| 4 | Aarhus H | DSB/BDK. DSB, Arriva; Letbane nearby | ✓ 50/55 | ✓ ("Århus H") | S | ✓ ×2 | M | Partly under deck |
| 5 | Bramming | BDK. DSB, Arriva | ✓ 55 | ✓ | U | – | SV | |
| 6 | CPH Airport | Sund & Bælt. DSB, Øresundståg | ✓ as "Kastrup" 55 (P) | ✗ | S | ✓ (T3) | S | Underground; no laser on platforms |
| 7 | Esbjerg | DSB/BDK. DSB, Arriva | ✓ 26/55 | ✓ | U | U | SV | |
| 8 | Espergærde | BDK. Kystbanen | ✓ 35/55 | ✓ | U | – | S | |
| 9 | Fredericia | DSB/BDK. DSB | ✓ 26/55 | ✓ | S | U | SV? | 14 rows |
| 10 | Hedehusene | BDK. DSB RE | ✓ 55 | ✓ | U | – | S | |
| 11 | Hellerup | DSB/BDK. S-tog, Kystbanen | ✓ 55/92 | ✓ | U | ✓ | S | S-bane IM → DSB 2027 |
| 12 | Helsingør | DSB/BDK. Kystbanen, Lokaltog (Hornbækbanen) | ✓ 50–72 | ✓ | S | U | S | Lokaltog platform not checked |
| 13 | Herning | DSB/BDK. DSB, Arriva | ✓ 55 | ✓ | S | U | M | |
| 14 | Hillerød | DSB/BDK + Lokaltog. S-tog, Lokaltog | ✓ S-tog 92 only | ✓ | S | U | S | Lokaltog platforms missing |
| 15 | Hjørring | BDK. Nordjyske | ✓ 55 | ✓ ("…by") | U | U | N | |
| 16 | Holbæk | DSB/BDK. DSB | ✓ 55 | ✓ | S | U | S | |
| 17 | Humlebæk | BDK. Kystbanen | ✓ 50/55 | ✓ | U | – | S | |
| 18 | Hårlev | Lokaltog (Østbanen) | ✗ | ✗ | U | – | S | No register; laser + OSM only |
| 19 | Høje Taastrup | DSB/BDK. DSB, S-tog | ✓ 55/92 | ✓ | U | U | S | Bridge station |
| 20 | Kagerup | Lokaltog (Gribskovbanen) | ✗ | ✗ | – | – | S | No register |
| 21 | Klampenborg | BDK. S-tog, Kystbanen | ✓ 55/92 | ✓ | U | U | S | |
| 22 | Kokkedal | BDK. Kystbanen | ✓ 55 | ✓ | U | – | S | |
| 23 | Kolding | DSB/BDK. DSB | ✓ 50 | ✓ | U | U | SV? | |
| 24 | København Syd | BDK. S-tog, regional | ✓ as "Ny Ellebjerg" 55/92 | ✓ (Ny Ellebjerg) | S | ✓ | S | Multi-level; renamed |
| 25 | Nørreport | DSB/BDK. S-tog, Kystbanen; Metro separate | ✓ 55/92 | ✓ | U | ✓ "Perron" | S | Underground |
| 26 | Østerport | DSB/BDK. S-tog, Kystbanen; Metro separate | ✓ 55/92 | ✓ | S | ✓ | S | Partly covered; Metro underground |
| 27 | Køge | DSB/BDK + Lokaltog. S-tog, Lille Syd, Østbanen | ✓ 35/55/92 | ✓ | U | U | S | Lokaltog platform unclear |
| 28 | Køge Nord | BDK. S-tog, DSB IC | ✓ 55/92 | ✓ | U | – | S | Footbridge station; new |
| 29 | Lindholm | BDK. Nordjyske | ✓ 55 | ✓ | U | – | N | |
| 30 | Middelfart | DSB/BDK. DSB | ✓ 55 | ✓ | U | U | F | |
| 31 | Nivå | BDK. Kystbanen | ✓ 50/55 | ✓ | U | – | S | |
| 32 | Næstved | DSB/BDK. DSB, Lokaltog (Lille Syd) | ✓ 55/72 | ✓ | S | U | S | |
| 33 | Odense | DSB/BDK. DSB | ✓ 55 | ✓ | S | ✓ ×2 | F | Partly under OBC |
| 34 | Ringsted | DSB/BDK. DSB | ✓ 55/72 | ✓ | S | U | S | |
| 35 | Roskilde | DSB/BDK. DSB | ✓ 55 | ✓ | U | ✓ | S | RINF OP DK00017 |
| 36 | Rungsted Kyst | BDK. Kystbanen | ✓ 55 | ✓ | U | – | S | |
| 37 | Skanderborg | DSB/BDK. DSB, Arriva | ✓ 55 | ✓ | U | U | M | |
| 38 | Skodsborg | BDK. Kystbanen | ✓ 55 | ✓ | U | – | S | |
| 39 | Skørping | BDK. DSB, Nordjyske | ✓ 26 | ✓ | U | – | N | Low platforms |
| 40 | Slagelse | DSB/BDK. DSB, Lokaltog (Tølløsebanen) | ✓ 55 | ✓ | S | U | S | |
| 41 | Snekkersten | BDK. Kystbanen | ✓ 55 | ✓ | U | – | S | |
| 42 | Sorø | BDK. DSB | ✓ 55 | ✓ | U | – | S | |
| 43 | Trekroner | BDK. DSB RE | ✓ 55 | ✓ | U | – | S | |
| 44 | Tårnby | Sund & Bælt. Øresundståg, DSB | ✓ 55 | ✗ | U | – | S | No open polygons |
| 45 | Tølløse | BDK + Lokaltog. DSB, Lokaltog | ✓ 26/55 | ✓ | U | – | S | Lokaltog side unclear |
| 46 | Valby | DSB/BDK. S-tog, DSB | ✓ 35/92 | ✓ | U | – | S | |
| 47 | Vedbæk | BDK. Kystbanen | ✓ 55 | ✓ | U | – | S | |
| 48 | Vejle | DSB/BDK. DSB, Arriva | ✓ 35/50 | ✓ | S | U | SV/M? | |
| 49 | Viby Jylland | BDK (DSB building per TRM annex). DSB, Arriva | ✓ 55 (107–109 m) | ✓ ("Viby J") | U | – | M | New? Check scan date |
| 50 | Ølby | BDK. S-tog, regional | ✓ 50/92 | ✓ | U | – | S | New platforms? |
| 51 | Ørestad | By & Havn. DSB, Øresundståg; Metro above | ✓ 55 | ✗ | S | – | S | Cutting under the elevated metro |

---

## 7. Best plan, expected quality, gaps

**(a) 3D pack**
- Ask the user once to create a free **Dataforsyningen** account and token (or a Datafordeler account and API key).
- Then script downloads of the 1 km LAZ tiles (`Punktsky`), DTM 0.4 m (`Terraen`) and DSM (`Overflade`) around each station, in EPSG:25832 + DVR90 heights. Licence CC BY 4.0, same as Sweden.
- Read **DHMOprindelse** to record the scan date per station.
- Quality: 8 pts/m² since 2018. **Probably denser than the Swedish national laser data** (unverified comparison) and it includes bridge and railway classes.
- Blocker: the login. Without the token there is no 3D for Denmark.

**(b) Platform register**
- Parse Bilag 3.6 (NS 2027) for track, length and height in cm: 49 of 51 stations.
- Add widths and outlines from Banedanmark Open Data "Befæstede arealer" `Perron` polygons. NO-LOGIN, CC BY 4.0, 46 of 51 stations.
- Join to `Sporforløb` track numbers.
- **Better than Sweden on height** (cm, not class). **Equal on length.** Width comes from the polygons instead of a register field.
- **Roof: no source.** Derive it from laser and photos and flag it as "derived".
- **Gaps:**
  - Kagerup and Hårlev: no register.
  - Lokaltog platforms at Hillerød, Køge and Tølløse.
  - Polygons for Ørestad, Tårnby and CPH Airport (Sund & Bælt gives CPH as 320 × 6.5 m).

**(c) Station facts**
- Use the DSB station pages (facilities and hours) and the 7-Eleven list (hours, coarse position). Positions, levels and lift-to-platform links come from OSM plus Commons. cph.dk for the airport.
- **Weaker than Sweden:**
  - No DSB plans or PDFs.
  - DSB lists lifts only as present or absent.
  - The København H shop set is in flux (renovation 2026–28).
  - The OSM indoor depth at København H is **unverified**: run Overpass via the browser agent or curl.
- Small stations (Kystbanen, Nordjylland, Lokaltog) will have only basic facts.

**Accounts needed from the user:**
1. Dataforsyningen or Datafordeler, for DHM: required.
2. The Danish NAP (MitID or profile), only if NeTEx quays are wanted. Optional: Bilag 3.6 already gives the tracks.

**Unverified items to close first:**
1. DHM class codes (prodspec PDF).
2. Exact scan year per station (DHMOprindelse).
3. That "Kastrup" in Bilag 3.6 = CPH Airport station.
4. OSM coverage.
5. 7-Eleven list completeness.
6. Whether RINF has Danish PlatformEdge data.
7. Lokaltog platform data.
8. Operator list.
