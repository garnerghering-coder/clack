# Scope: Finnish station data sources (Helsinki, Pasila, Tampere, Tikkurila)

Scoping only, no data has been collected. Checked 2026-10-30 with WebSearch/WebFetch (no browser).

Legend:
- **[V]** verified: I fetched the page and the fact is stated there.
- **[U]** unconfirmed: from search snippets, inference or memory, or the page did not say.
- **[X]** blocked: the fetch tool refused the URL (robots.txt or a client error), so it could not be checked from here.

Login/key column: "none" means anonymous download. "free account" means the user must register (we cannot). "strong ID" means Finnish bank ID or Suomi.fi login plus payment.

---

## 1. Laser point clouds and terrain models

### 1.1 Maanmittauslaitos (NLS): Laser scanning data 5 p (the dense national product). NOT OPEN.
- Product page: https://www.maanmittauslaitos.fi/en/node/13295 [V]
- **Licence: restricted, not CC BY [V].** You must accept the NLS terms of use. You may use it inside your organisation, but you "cannot publish or transfer" it as such or at a similar accuracy (https://www.maanmittauslaitos.fi/en/node/13554, terms effective 10 Oct 2023) [V]. Overview of licences: https://www.maanmittauslaitos.fi/en/node/398 [V].
- **Price [V]:** €0.026/km² excl. VAT, minimum fee €26.69 excl. VAT (€33.00 incl. VAT).
- **Access [V]:** order through MapSite (Karttapaikka) "Download geospatial data" with Suomi.fi strong authentication and payment (https://www.maanmittauslaitos.fi/en/node/13554, https://maanmittauslaitos.fi/en/node/17213, https://www.maanmittauslaitos.fi/en/node/16768). Sheets are 1 km × 1 km, about 70 MB each (https://maanmittauslaitos.fi/en/node/17390) [V]. **We cannot use this: it needs a Finnish strong ID and payment, and the licence forbids publishing.**
- Specs [V]: at least 5 p/m² (about 0.40 m spacing). LAZ 1.2 for 2020–2023 data, LAZ 1.4 from 2024. CRS ETRS89/TM35FIN (EPSG:3067), heights N2000 (EPSG:3900). Tiles are 1×1 km blocks (1/9 of a UTM 5000 sheet). Accuracy: height standard error ≤10 cm, planimetric ≤45 cm.
- **Classes [V]:** 1 unclassified, 2 ground, 3/4/5 low/medium/high vegetation, 7 low point, 12 overlap, 15 air, 16 isolated, 17 fault. **There is no building class and no bridge class.** This is a big difference from Lantmäteriet's classes.
- Programme: NLS produces "laser5p". From 2026, consultants also produce a "laser20p" product (NLS PAKU slides, 19 May 2026: https://www.maanmittauslaitos.fi/media/32252/download) [V]. I found no licence or product page for 20 p [U].

### 1.2 NLS Laser scanning data 0.5 p (2020-). OPEN, CC BY 4.0. This is the usable national source.
- Product page: https://www.maanmittauslaitos.fi/en/node/13294 [V]
- **Licence: CC BY 4.0 [V].** Attribution must name NLS, the dataset and the delivery date.
- Density [V]: 0.5 p/m², thinned from 5 p (0.3 p/m² in restricted areas under section 14 of the Territorial Surveillance Act). Spacing is about 1.4 m.
- Classes [V]: 1, 2, 3, 4, 5, 7, 12, 15, 16 (fault points 17 are removed). **No building or bridge class.**
- CRS/height [V]: EPSG:3067 + N2000 (EPSG:3900). Format LAZ.
- Tiles [V]: 3 km × 3 km UTM 5000 map sheets (for example M3342B4), built from 1×1 km blocks.
- Updated each year. New scans are usually available early in the year after scanning [V].
- Older open product: Laser scanning data 0.5 p (2008–2019), CC BY 4.0. Its classes include 2 ground, 9 water and 10 bridge (open-water bridges only) (https://www.maanmittauslaitos.fi/en/node/10680) [V].
- **Access options:**
  1. **OGC API Processes "Paikkatiedon tiedostopalvelu"** [V]: https://avoin-paikkatieto.maanmittauslaitos.fi/tiedostopalvelu/ogcproc/v1/ . Free, CC BY 4.0, and **needs an API key** (`?api-key=`). Process `laserkeilausaineisto_05_karttalehti`, body `{"inputs":{"mapSheetInput":["M3342B4"],"fileFormatInput":"LAZ","dataSetInput":"Uusin"}}`. Same API: `korkeusmalli_2m_karttalehti|bbox|polygon` (TIFF), `3d-rakennukset_karttalehti` (CityGML), `ortoilmakuva_karttalehti` (JPEG2000), `maastotietokanta_bbox` (GPKG). Bounding boxes in EPSG:3067 only. Docs: https://www.maanmittauslaitos.fi/paikkatiedon-tiedostopalvelu/tekninen-kuvaus [V].
  2. **Getting the API key needs a free NLS "My Account" registration** (omatili.maanmittauslaitos.fi, email login), after which the user creates the key (https://www.maanmittauslaitos.fi/en/rajapinnat/api-avaimen-ohje) [V]. → **The user must create a free account. We cannot.**
  3. MapSite "Download geospatial data" (open products). I did not confirm whether an email address alone is enough [U].
  4. **Paituli (CSC) mirror without a key:** Paituli serves NLS open data (lidar, 2 m DEM) by https, ftp and rsync, plus a STAC catalogue at https://paituli.csc.fi/stac (endpoint `paituli.csc.fi/geoserver/ogc/stac/v1`). CSC docs say "anybody can download" and most datasets are CC BY 4.0 (https://docs.csc.fi/data/datasets/spatial-data-in-csc-computing-env/) [V for the docs]. The funet mirror paths exist: `https://mirrors.nic.funet.fi/index/geodata/mml/laserkeilaus/2008_latest/` and `.../geodata/mml/dem2m/`. The product PDFs under those paths opened [V], but the directory listings and the STAC API were robots-blocked for my fetch tool [X]. **This is the most likely way to get data with no key: list it with curl/STAC.**
- Overview of NLS open products: https://www.maanmittauslaitos.fi/en/node/398 [V]

### 1.3 Scan year for Helsinki, Vantaa and Tampere
- **Not found [U].** NLS publishes scan status only on the JavaScript map https://tilannekartta.maanmittauslaitos.fi/laserkeilaus, which my tool cannot render. Neither the 2026 programme slides nor the KALLIO news (https://www.maanmittauslaitos.fi/en/node/19982) give a year per region [V].
- Next step: read the year from the LAZ header or the Paituli index map of the sheets that cover each station, or look at the status map in a browser.
- Helsinki city lidar years are known (see 1.5).

### 1.4 Terrain models (DEM/DTM)
- **NLS Elevation model 2 m (korkeusmalli 2 m):** open, CC BY 4.0. GeoTIFF in EPSG:3067 + N2000. Via OGC API Processes (key needed) [V] or the Paituli/funet `dem2m` mirror (no key) [V for the path, X for the listing]. Product PDF: https://mirrors.nic.funet.fi/index/geodata/mml/dem2m/mml_korkeusmalli_2m_2016.pdf.
- Elevation model 10 m: open [V].
- **I found no national 1 m or 0.5 m DTM product [U].** You could build a 1 m DTM yourself from the class-2 ground points of the 0.5 p cloud (about 1.4 m spacing, so 2 m is the honest resolution).
- **Helsinki terrain model** ("Maastomalliaineistot"): XYZ in ETRS-GK25 (EPSG:3879), CC BY 4.0, from https://kartta.hel.fi/ (metadata: https://kartta.hel.fi/paikkatietohakemisto/?id=256) [V]. Resolution not checked [U]. There is also a WCS: https://kartta.hel.fi/ws/geoserver/avoindata/wcs?request=getCapabilities [V that it is listed; content U].

### 1.5 City of Helsinki lidar: the dense, building-classified source (Helsinki and Pasila only)
- Dataset: https://hri.fi/data/en/dataset/helsingin-laserkeilausaineistot [V]. Metadata: https://kartta.hel.fi/paikkatietohakemisto/pth/?id=84 [V]. City open-data page: https://www.hel.fi/fi/paatoksenteko-ja-hallinto/tietoa-helsingista/kartat-ja-paikkatieto/paikkatiedot-tehokayttoon/avoimet-paikkatiedot [V].
- **Open years: 2015, 2017 and 2021, CC BY 4.0, LAZ** [V]. Download from https://kartta.hel.fi/ (layer "Laserkeilausaineistot"). The city page mentions no login [V].
- **Since 2023 the city's scans are no longer open data.** The 2023–2025 scans (60 p/m²) are available only by order or agreement [V on the pth page]. → The newest open scan is **2021** (40 p/m² at nadir [V]).
- CRS [V]: **ETRS-GK25 (EPSG:3879)** + N2000. This needs reprojecting to match NLS EPSG:3067.
- Tiles [V]: all points in 0.5 × 0.5 km tiles, ground points in 1 × 1 km tiles, on the GK25 sheet division.
- Classes [V, from the 2015 spec PDF https://kartta.hel.fi/avoindata/dokumentit/2017-03_Laserpisteet_kuvaus.pdf]: 2 ground, 3–5 vegetation, **6 building**, 9 water, **10 rail**, **11 road surface**, 15 transmission tower, **17 bridge deck**, 20 overlap, and more. The 2015 density was 20 p/m². I did not check the 2021 class list; it is probably the same [U].
- **Helsinki 3D city model** (CC BY 4.0) [V]: CityGML 2.0, LoD1/LoD2 buildings (LoD2 also textured) plus a terrain surface. **Bridges are not modelled yet.** Coordinates ETRS-GK25/N2000. WFS: https://kartta.hel.fi/3d/citydb-wfs/wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities. Viewer and download: https://kartta.hel.fi/3d/. HRI page: https://hri.fi/data/fi/dataset/helsingin-3d-kaupunkimalli. The **reality mesh** (OBJ/3MX, CC BY 4.0, about 20 cm accuracy, probably the 2015 imagery) is at http://3d.hel.ninja/data/mesh/. Overview: https://www.hel.fi/fi/paatoksenteko-ja-hallinto/tietoa-helsingista/kartat-ja-paikkatieto/helsinki-3d [V].
- Vantaa and Tampere: **I found no open city lidar for either city [U]**, so use the NLS 0.5 p for them.

---

## 2. Platform register

### 2.1 Digitraffic Infra-API, platforms ("laiturit")
- API root: https://rata.digitraffic.fi/infra-api/ [V]. It lists the object page **`/latest/laiturit.html`** [V], plus `raiteet` (tracks), `rautatieliikennepaikat` (operating points), `liikennepaikanosat`, `kilometrimerkit`, `tunnelit`, `sillat` and others. Docs are at `/swagger-ui/index.html` and `/scalar`; OpenAPI files for versions 0.2–0.8 are at `/v3/api-docs/{version}`. There are helper services for coordinate, track-km and route lookups.
- Licence: rail Digitraffic data is **CC BY 4.0** ("Creative Commons Nimeä 4.0") (https://www.digitraffic.fi/rautatieliikenne/, https://www.digitraffic.fi/en/railway-traffic/) [V]. No API key is mentioned [V]. The docs do not mention the `Digitraffic-User` header [U]; sending it is good practice.
- **I could not fetch an actual laiturit example.** `laiturit.html` and `/v3/api-docs/0.8` are robots-disallowed for WebFetch [X], and I found no published example JSON. From memory, not verified, the platform objects carry a platform id/OID, operating point, track link, commercial number, length and geometry, and the API also serves `.json` and `.geojson` [U]. I could not confirm a height attribute either way.
  - **Action:** fetch `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` (also try `.geojson` and a filter on liikennepaikka HKI/PSL/TPE/TKL) with curl from the main agent. It is an open API meant for programmatic use.
- Stations metadata: `https://rata.digitraffic.fi/api/v1/metadata/stations` gives stationShortCode, UIC code, lat/lon and passengerTraffic (endpoint documented [V]; the JSON was robots-blocked for WebFetch [X]). Short codes HKI (Helsinki), PSL (Pasila), TPE (Tampere) are confirmed in the docs [V]. **TKL for Tikkurila is unconfirmed [U]**; check it in the stations list.
- Live and historical train data give `commercialTrack` per stop [U for the field name], which you can use to tie tracks to platform numbers.

### 2.2 Network Statement 2027 (Rautateiden verkkoselostus 2027), Väylävirasto
- Main PDF, version of 15.6.2026, **CC BY 4.0** [V]: https://doria.fi/handle/10024/195156 → https://www.doria.fi/bitstream/10024/195156/1/vj_2026-38_978-952-405-414-0.pdf . The earlier version of 12.12.2025 is https://www.doria.fi/handle/10024/193639 [V].
- **The main PDF has no per-platform heights or lengths [V].** It refers to separate annexes on vayla.fi:
  - **Liite 2.2 Rautatieliikennepaikat** (operating points; gives siding lengths),
  - **Liite 7.3.1 Matkustajaliikenteen asemat** (passenger stations),
  - the "verkkoselostuksen karttapalvelu" map service.
  - I could not open any of them. vayla.fi pages returned client errors to WebFetch [X], so **whether any annex lists platform height (265/550 mm) and length is unconfirmed [U]**.
- Useful fact from the 2026 statement [V]: Helsinki platform tracks 1–4 and 13–19 are reserved capacity for Helsinki commuter traffic (section 2.4.1).
- Track diagrams (raiteistokaaviot) are in Väylä's "Ratatieto-palvelu", which **requires registration** (https://vayla.fi/palveluntuottajat/aineistot/ratatieto-palvelu) [V that the statement says so].
- Väylä open WFS (CC BY 4.0, no key): https://avoinapi.vaylapilvi.fi/vaylatiedot/ows . **It has no railway platform layer** [V; the capabilities were truncated]. `taitorakenteet:laituri` is a waterway quay. `ratatiedot:sv_laituripolut_ja_huoltotiet` holds platform paths that cross the tracks.
- Alternative: **ERA RINF** (EU register; platform edges with height and usable length). Knowledge graph at https://graph.data.era.europa.eu/ (robots-blocked [X]). Data licence and Finnish coverage are [U]. The ontology is EUPL 1.2 (https://www.era.europa.eu/de/node/1665) [V].

### 2.3 Fintraffic stop data (Finap / PETI)
- **PETI** (Pysäkki- ja esteettömyystietokanta, the national stop and accessibility database): https://www.fintraffic.fi/fi/digitaalisetpalvelut/fintrafficin-datapalvelut/liikkumisen-tietopalvelut/peti , UI https://peti.fintraffic.fi/ui/ [V]. It covers all public-transport access points [V].
- Fields it can hold at stop and **quay** level [V] (https://www.fintraffic.fi/sites/default/files/2026-03/Esteett%C3%B6myys%20ja%20varusteet.pdf): wheelchair suitability, step-free access, **lift and escalator access**, ticket machines and office, shelter, **WC**, waiting room, passenger information display, raised kerbs, lighting, assistance service and information desk. **No platform height in mm [V].**
- **PETI Read API**: public, read-only, NeTEx XML (https://www.fintraffic.fi/sites/default/files/2026-05/PETI%20Read%20API.pdf) [V]. Base URL, key and licence were not stated [U]. Coverage of the four railway stations is unconfirmed [U].
- Finap stations/terminals notification: https://www.fintraffic.fi/en/digitalservices/Traffic-and-Public-Transport-Data-Services/Finap-service/stations-ports-terminals [V]. Licence and download [U].
- Digitransit (HSL routing API, stop platform codes) **requires registration** for an API key (https://digitransit.fi/en/developers/apis/) [V].

---

## 3. Station facts

### 3.1 Owners and operators
| Station | Building owner / operator | Tracks and platforms | Source |
|---|---|---|---|
| Helsinki | **VR Group** owns the building, as the station's own site says [V] | State rail network, Väylävirasto [U; Wikipedia says "Finnish Transport Agency" owns and VR manages] | https://paarautatieasema.fi/en/info/helsinki-central-railway-station ; https://en.wikipedia.org/wiki/Helsinki_Central_Station |
| Pasila | Station hall is built into **Mall of Tripla**, on pillars above the tracks; opened 17 Oct 2019 [V]. Building owner [U] | Väylävirasto [U] | https://en.wikipedia.org/wiki/Pasila_railway_station |
| Tikkurila | Station services are in the **Dixi** travel centre, which opened 1 Jan 2015; station services are on Dixi's 3rd floor [V, VR page]. Dixi owner [U; NREP was the developer per nrep.com news] | Wikipedia says the Finnish Transport Agency [V as stated there] | https://www.vr.fi/en/railway-stations-and-routes/tikkurila ; https://en.wikipedia.org/wiki/Tikkurila_railway_station |
| Tampere | Wikipedia: owned by the Finnish Transport Agency, building administered by VR since 1995 [V as stated]. VR's 2025 sale list leaves out Helsinki and Tampere [V] | Väylävirasto. **Tampere passenger yard project runs to 01/2031** (Kreate alliance with the City of Tampere, VR and Fintraffic Raide; new platforms, tracks, canopies, underpasses, terminal) [V] | https://en.wikipedia.org/wiki/Tampere_Central_Station ; https://kreate.fi/en/projects/the-development-phase-of-the-tampere-passenger-railway-yard-project/ ; https://www.verkkouutiset.fi/a/vr-luopuu-matkustaja-asemistaan/ |

Senaatti: Senaatin Asema-alueet Oy develops station areas (www.asemanseutu.fi, per the Network Statement) [V]. I found it as owner of none of these four stations [U].

### 3.2 Helsinki Central: the station's own site, paarautatieasema.fi [V]
- Station open daily 05:00–02:00 [V].
- **Services list** with addresses: https://paarautatieasema.fi/en/services. It includes VR Meeting Point, luggage storage, R-kioski, Steissin Apteekki, FOREX, KeyBoy lockers, Otto ATM, public toilet, lost property, SIXT, Kaisantunneli bicycle garage and Rauta-Kukka [V].
- **Restaurants list** (15): https://paarautatieasema.fi/en/restaurants. Starbucks, Bröner, Gateau, Burger King, Päärata Bar, Jungle Juice Bar, Kellotorni brewery restaurant, Taulu, La Komia, Robert's Coffee, Picnic, Pronto, Café Eliel, Olivia, Subway [V].
- Detail pages carry **opening hours but no floor and no map position**. Example: https://paarautatieasema.fi/en/p/82/starbucks shows "Mon–Sun 6–21" [V]. **Positions must come from OSM or photos.**
- FAQ (https://paarautatieasema.fi/en/frequently-asked-questions/) [V]:
  - Public toilets are on the basement floor in the passenger service facilities, opposite the VR service point; €1. The accessible toilet is reached by lift.
  - Luggage lockers are at the Elielinaukio and Asema-aukio entrances. North-end storage is open 04–00, Elielinaukio storage 06–00.
  - The metro has an accessible lift from a separate entrance on Elielinaukio.
  - The assistance point is by platform 11, under the glass roof.
- Accessibility page: https://paarautatieasema.fi/en/info/accessibility [V]. **The site has no station floor plan [V].**
- Platform-area renovation was expected to finish in summer 2026: https://paarautatieasema.fi/en/platform-area-renewal [V]. HSL notice on accessible and night entrances during the works: https://www.hsl.fi/en/hsl/news/service-updates/2025/03/changes-to-accessible-routes-and-nighttime-entrances-at-helsinki-central-railway-station-from-12-march [V].
- VR station page: https://www.vr.fi/en/railway-stations-and-routes/helsinki [V].
  - VR service point Mon–Fri 9–20, Sat–Sun 10–18.
  - Lockers in the west wing 06–24.
  - Waiting room 05–02.
  - Northern underpass closed 22:30–05:30 on Fri–Sun.
  - Assistance by platform 11.
- **HSL Rautatientori area map PDF** (dated 2020): https://www.hsl.fi/sites/default/files/uploads/rautatientori_1730x1180_09102020.pdf. It shows levels −1/−2/−3 (station tunnel, Kompassi level, platform level) and symbols for lifts, stairs and escalators. © HSL with no open licence, so **use it for facts only** [V].
- **HKL metro guide map** for Rautatientori: https://www.hel.fi/static/hkl/metroasema_opaskartat/rautatientori.pdf. It shows levels −1 to −3 and numbered exits, and its base map is © OpenStreetMap contributors [V].

### 3.3 Pasila and Mall of Tripla
- VR page: https://www.vr.fi/en/railway-stations-and-routes/pasila [V].
  - No VR service point; ticket machines in the station building.
  - Toilet available.
  - **Lockers currently out of service.**
  - Waiting room open 24 h.
  - Assistance point at the Pasilansilta entrance.
  - Links to an HSL PDF map of the surroundings.
- Mall: https://malloftripla.fi/ [V].
  - Common areas open 24 h; shops Mon–Sat 9–21, Sun 11–19.
  - Store pages give **floor + area + hours**. Example: K-Market Pasilan asema is on the 4th floor, "Little Manhattan", at the railway station, open Mon–Fri 6–22 and Sat–Sun 9–21 (https://malloftripla.fi/stores-services/270/k-market-pasilan-asema/) [V].
  - The store index and floor map URL returned a client error [X]. The site runs on HyperIn [V], which usually has a JSON store API [U].
- Platforms 1–11 lie under the elevated station and Tripla deck [V: "built on pillars above the tracks"].
- OSM example: platform 11 (way 733305103) is tagged `level=2`, `layer=3`, `local_ref=11`, `wheelchair=yes`, `lit=yes`, with **no height, width or covered tags** [V]: https://www.openstreetmap.org/way/733305103/history/8

### 3.4 Tikkurila and Dixi
- VR page: https://www.vr.fi/en/railway-stations-and-routes/tikkurila [V].
  - No VR service point.
  - Toilets and lockers available.
  - Waiting room 05–02.
  - **Platforms reached by lift or escalator from the Dixi travel centre.**
  - Tactile route, Braille maps, audio signs and hearing loops.
  - Assistance point at Ratatie 11 A, in front of Kotipizza.
  - The bus terminal was closed from 9 Feb (temporary terminals).
  - Airport I-trains use track 5 [V, Wikipedia].
- Dixi: https://dixi.fi/?lang=en [V].
  - Mall hours Mon–Fri 06–22, Sat 07–22, Sun 09–22.
  - **The store directory lists about 46 tenants, most with floor and hours** (for example Arnolds, 1st floor, 05–19): https://dixi.fi/en/shops-and-services/ [V]. The kiosk now trades as "Ärrä", the R-kioski rebrand [V].
  - **Floor plans** as PNG images for floors 1–7: https://dixi.fi/en/shops-and-services/floor-plans/ (files `https://dixi.fi/wp-content/uploads/2024/12/Dixi_pohjakartat_1.png` … `_7.png`) [V that they exist; I did not see their content]. They are © Dixi, so **facts only**.

### 3.5 Tampere
- VR page: https://www.vr.fi/en/railway-stations-and-routes/tampere [V].
  - **No VR service point.**
  - Toilet available.
  - Waiting room 05–24.
  - S/XL lockers and two KeyBoy lockers in the luggage corridor.
  - **Lifts to the platforms.**
  - Platform office on platform 1.
  - Assistance point by the southern underpass doors.
  - The surroundings map is a PDF on Väylävirasto's site.
- No station shop website was found. Shops sit in the **Asematunneli** shopping tunnel (about 20 shops, per Wikipedia [V]) and the station hall.
  - Sources: OSM, individual chain sites, Wikimedia Commons ("Category:Interior of Tampere railway station" exists according to an osmand mirror [U]).
  - OSM building way 128036311 is tagged `opening_hours=Mo-Su 05:00-01:00`, `building:levels=2`, `wheelchair=yes` [V].
- Layout facts [V, Wikipedia]:
  - 3 platforms and 5 tracks; the first two platforms are covered.
  - Asematunneli (1989), Matkakeskustunneli (2008), and the Rongankatu underpass (2012) with lifts and stairs to all platforms.
  - **The yard is under reconstruction until about 2031**, so expect changes to platforms, canopies and tunnels.

### 3.6 Store locators
- The R-kioski chain is rebranding to **Ärrä** (Reitan Convenience Finland). For example, a new Ärrä opened in Dixi (https://www.sttinfo.fi/tiedote/72389624/...) [V]. **I did not find or verify a store-locator URL** (rkioski.fi / arra.fi) [U].
- Other chains such as K-Market, S-Market, Robert's Coffee and Picnic have their own locators [U]. The mall pages already give hours for Pasila and Tikkurila.

### 3.7 OSM indoor coverage at Helsinki (spot-check, partial)
- Overpass and the OSM `/api/0.6/map` endpoint are robots-blocked for WebFetch [X], so **no quantitative check was possible**.
- Evidence [V]: the HSL stop_area relation "Helsinki" (https://www.openstreetmap.org/relation/17303948) has 8 platform ways (platforms 4–11) and 8 stop nodes, with a note that "exact platforms variable/unknown". **It has no indoor or level members.**
- Expectation [U]: shops and cafés exist as POIs, but `indoor=room/corridor` and `level` tagging is sparse. Check with Overpass (bbox 60.1697,24.9395,60.1740,24.9445) from the main agent.

### 3.8 Other possibly useful sources [U]
- Helsinki-region Service Map API (accessibility data, HRI; licence probably CC BY 4.0): https://hri.fi/data/fi/dataset/paakaupunkiseudun-palvelukartan-rest-rajapinta
- Wikimedia Commons categories for each station. I did not fetch them (the Commons fetch failed) [X].

---

## 4. Special cases
- **Helsinki metro:** Rautatientori metro station (opened 1982) lies under the main building and connects through Asematunneli [V, Wikipedia]. A perpendicular underpass of 185 m (1999–2000) reaches all platform tracks by stairs and lifts [V, Wikipedia].
  - **Neither lidar nor the DTM sees anything underground.** Model levels −1/−2/−3 schematically from the HSL and HKL maps (facts only).
- **Pasila has no metro [V].** Its platforms are **under the Tripla and station deck**, so the airborne lidar shows the deck roof, not the platforms. Platform geometry must come from the Infra-API or OSM.
- **Ring Rail (Kehärata) tunnel:** the airport tunnel is out of scope. Tikkurila connects to it through I-trains on track 5 [V].
- **Large roofs:**
  - Helsinki's glass and steel train-shed roof over the central platforms was built in 2001. It is about 165 m long [V, Wikipedia].
  - Tikkurila's Dixi bridge spans the tracks [V, VR].
  - Tampere's platforms 1–2 are covered, and the canopies are being rebuilt [V].
  - NLS classes have **no building class**, so roofs over platforms appear as unclassified or vegetation-free points. Helsinki city lidar class 6/17 helps there.

---

## 5. Per-station table

| | Helsinki (HKI) | Pasila (PSL) | Tikkurila (TKL? [U]) | Tampere (TPE) |
|---|---|---|---|---|
| Municipality | Helsinki | Helsinki | Vantaa | Tampere |
| Best open point cloud | **City of Helsinki 2021, ~40 p/m², classes include 6 building, 10 rail, 17 bridge**, CC BY 4.0, EPSG:3879, no login [V] | Same as Helsinki [V] | NLS 0.5 p, CC BY 4.0, EPSG:3067, no building class [V]; Paituli mirror or NLS key | NLS 0.5 p, same as Tikkurila |
| Scan year | 2021 (city) [V]; NLS year [U] | 2021 (city) [V] | [U] | [U]; site under construction 2025–31 |
| DTM | NLS 2 m [V]; Helsinki XYZ terrain model [V, resolution U] | Same as Helsinki | NLS 2 m [V] | NLS 2 m [V] |
| 3D buildings | Helsinki CityGML LoD2 + mesh [V] | Same as Helsinki | NLS 3D buildings (CityGML; licence [U]) | Same as Tikkurila |
| Platform register | Infra-API laiturit [V exists, attributes U]; NS annexes [U]; OSM platforms 4–11 [V] | Infra-API [U]; OSM platforms carry level and local_ref [V] | Infra-API [U] | Infra-API [U] |
| Station-owner facts | paarautatieasema.fi: services and restaurants with hours, no positions [V]; VR page [V] | VR page [V]; Tripla store pages with floor, area and hours [V] | VR page [V]; Dixi directory with floor and hours, plus PNG floor plans [V] | VR page [V]; no shop site |
| Plans (facts only) | HSL Rautatientori PDF, HKL metro guide map [V] | HSL surroundings PDF (via VR) [U URL] | Dixi PNG plans [V]; HSL PDF [U URL] | Väylä surroundings PDF (via VR) [U URL] |
| Special | Metro underground; glass shed roof; works until summer 2026 | Platforms under the deck | Lifts and escalators from Dixi; airport trains on track 5 | Yard rebuild to about 2031 |

---

## 6. Best plan, expected quality, gaps

**Best plan**
1. **3D pack:**
   - Helsinki and Pasila: City of Helsinki 2021 LAZ (CC BY 4.0, no login), reprojected EPSG:3879 → 3067, plus the Helsinki CityGML LoD2. This is roughly as good as Sweden or better (denser, with building and bridge classes).
   - Tikkurila and Tampere: NLS 0.5 p LAZ plus the NLS 2 m DEM, ideally through the keyless Paituli/funet mirror or STAC (list it first with curl). If the user is willing to create a **free NLS My Account**, use the OGC API Processes key route instead.
   - Do **not** plan on the 5 p data: it is paid, needs strong ID and cannot be published.
2. **Platform register:**
   - Pull `infra-api/latest/laiturit.json|geojson` with curl to confirm the attributes (length, track, geometry; is there height?).
   - Join it to `metadata/stations` and train `commercialTrack`.
   - Get heights from NS annex 2.2/7.3.1 if they contain them (fetch from vayla.fi outside WebFetch), otherwise from RINF/ERA, otherwise "unknown". Finnish standard heights are 550 mm and 265 mm [U]. Do not assume them per platform without a source.
   - Use OSM for the `level`/`local_ref` of platforms.
3. **Station facts:**
   - Use the owner's or mall's pages (paarautatieasema.fi, malloftripla.fi, dixi.fi) for names and hours.
   - Use the VR station pages for toilets, lockers, assistance, lifts and the service point.
   - Use HSL/HKL/Dixi plans for level structure (facts only).
   - Use OSM (ODbL) and Commons for positions.
   - Tampere relies on OSM and VR because it has no shop site.

**Expected quality compared with Sweden**
- 3D: Helsinki and Pasila are **better** (40 p/m², building, bridge and rail classes, and a CityGML model). Tikkurila and Tampere are **clearly worse**: 0.5 p/m² against Sweden's 1–2 p/m² class with buildings, no building or bridge class, and a 2 m DTM rather than 1 m.
- Platform register: probably **comparable or better geometrically** (Infra-API objects), but **heights are not confirmed** and the NS annex could not be checked.
- Station facts: **comparable**. Helsinki has hours but no positions; Tripla and Dixi have floor and hours; Tampere is weakest.

**Gaps and open items**
1. Laiturit attributes. This needs a curl fetch, because robots blocked WebFetch.
2. NS 2027 annex contents (vayla.fi blocked).
3. NLS scan year per station (status map is JavaScript only).
4. Keyless Paituli/funet listing (robots-blocked; verify with curl).
5. OSM indoor coverage (Overpass blocked).
6. PETI API URL and licence.
7. The Tripla store index and floor map (client error).
8. HSL PDF URLs for Pasila and Tikkurila.
9. The Tikkurila short code.
10. Tampere, under reconstruction to about 2031, will drift from any snapshot.

## Verified afterwards (main session, Chrome, 2026-10-30)
- [V] `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` returns HTTP 200 (422 kB, whole network, no key). Each platform
  object has: `tunnus` (e.g. "Laituri ILM L1"), `kuvaus`, `tyyppi` (henkilo), **`korkeus` (height class: matala/korkea)**,
  **`pituus` (length, m)**, **`kaupallinenNumero` (platform number as signposted)**, `rautatieliikennepaikka` (station OID),
  `ratakmvalit` (track-km range), `raiteet` (track OIDs), and `geometria` (polygon/line in ETRS-TM35FIN). Validity times per object.
  This is the Finnish equivalent of BanInfo `Plattform` + Bilaga 2A. Container shell can't reach rata.digitraffic.fi (proxy);
  fetch it from the browser.
