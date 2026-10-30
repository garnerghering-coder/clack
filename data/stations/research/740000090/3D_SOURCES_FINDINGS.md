# 3D sources for Jönköping C — findings

Research date: 29 October 2026. Station: Jönköping C (740000090), about 57.7843 N, 14.1641 E.

Not legal advice. Licence notes below are a reading of the published terms; where a point is uncertain it says so.

## Summary

- **Biggest change since earlier assumptions:** Lantmäteriet's laser point cloud is **no longer CC0**. Since 1 June 2026 it is
  CC BY 4.0, needs a Geotorget account, is delivered only through a STAC API, and Lantmäteriet now treats it as personal data
  under GDPR, which makes the person who downloads it the data controller.
- **Best single source for platforms:** Trafikverket's own infrastructure register (BIS/NJDB). It records **platform height and
  length per track**, nationwide, and Trafikverket's BanInfo map service publishing it is **CC0, free, no account**. This is the
  route to retiring the "standard 0.55 m" note at every Swedish station.
- **Jönköping C's recorded platform height is "mellan", which Trafikverket defines as 0.58 m** above the rail, for tracks 1, 2a
  and 2b, with a roof ("Tak") recorded. Source: Trafikverket's Network Statement 2027, Bilaga 2A, platform tab, from its
  infrastructure register as of 2026-02-04. That replaces the 0.55 m stand-in (a 3 cm change).
- **Trafikverket's register, read via BanInfo (CC0), describes one 8 m wide island platform** (BIS object 1705), concrete edge,
  asphalt surface, roofed, valid from 2026-10-13. It runs about 457 m along track 2 (2a and 2b) and 88 m along track 1 at the
  east end. Geometry saved as `jonkoping_c_platform_trafikverket.geojson`.
- **Ground is not flat.** Lantmäteriet's terrain model (scanned March 2022) puts the track bed at 90.8–91.2 m along the whole
  platform, but the town side rises to 94–96.6 m within 100 m south of the tracks, and Vättern's shore lies at 88.8 m just north.
  Across a 500 × 200 m box the ground spans 88.7–96.9 m.
- **Laser data decoded for the station** (two 2.5 km tiles, 2022-03-19/20). Measured: platform surface 91.67 m, 0.77 m above
  the ballast/sleeper surface (consistent with the recorded 0.58 m above rail head); one canopy 3.4 m above the platform at the
  west end and, further east, the roof of the 2001 glazed waiting hall (6.1 m) overhanging platform 2b; station building roof ≈8.5 m above its ground; footbridge roof ≈9.1–9.8 m
  above ground. Two trains were standing at the platform during the scan and have been excluded. Results in
  `jonkoping_c_structures_heights.geojson` and `jonkoping_c_heights_overview.png`.
- **No open 3D city model exists** for Jönköping. The municipality's model (2016) and its denser laser data (2016) are sold, not open.
- **The owner's iPhone can measure floor heights roughly, not platform heights.** Camera-only AR drifts by 10–25 cm when walking;
  the barometer class used in phones is about ±0.5 m. Neither resolves a 0.5 m platform edge to useful accuracy.

## Concrete values found for Jönköping C

| Item | Value | Source | Status |
|---|---|---|---|
| Track-bed ground height along the platform | 90.82–91.19 m RH 2000 (7 points from west end 14.1597 E to east end 14.1672 E) | Lantmäteriet Markhöjdmodell, tile 640_45, 1 m grid, read 2026-10-29 | Stated uncertainty 0.2 m height, 1 m plan; source scan 2022-03-20. Bare ground (ballast), not rail head |
| Ground across the station (500 × 200 m box centred 57.7843 N, 14.1641 E) | min 88.73, median 91.02, 95th pct 96.06, max 96.92 m RH 2000; best-fit plane falls 2.3 m per 100 m northward, 0.8 m per 100 m eastward | same | 88.8 m is the flattened lake surface (Vättern) |
| North–south ground profiles across the tracks | At 14.1601 E: 96.3 m on the town side, dropping ~5 m within 20 m to 91.3 m at the tracks. At 14.1626 E: 94.6 m falling gently to 90.7 m. At 14.1652 E: 92.9 m falling to 90.9 m | same, sampled every 10 m | Shows a raised town edge (wall or embankment) at the west end |
| Station ground elevation | 90 m above sea level | [Swedish Wikipedia, Jönköpings resecentrum](https://sv.wikipedia.org/wiki/J%C3%B6nk%C3%B6pings_resecentrum) | Consistent with the terrain model (≈91 m) |
| Platform record | BIS object 1705: height class mellan (0.58 m), width 8 m, edge concrete, surface asphalt, roof "Tak", km 69+131 to 69+590 (459 m), valid from 2026-10-13 | [Trafikverket BanInfo WMS](http://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5), layer Plattform, GetFeatureInfo | CC0 |
| Track served and run length | Track 2a and 2b: about 457 m (161 + 63 + 233 m on three track links). Track 1: about 88 m, east end only (14.1657–14.1671 E) | same, track numbers from layer Sparnummer; lengths computed from the returned geometry | Geometry is the track line the platform runs along, not the platform edge |
| Tracks | 4 tracks, 2 used by passenger trains | same | Secondary |
| Building | Built 1983, architect Carl Nyrén, owner Jernhusen; bus/train waiting hall added 2001 | same | No height given |
| **Platform height** | **"mellan" = 0.58 m** above rail, tracks 2a, 2b and 1 | [JNB 2027 Bilaga 2A](https://bransch.trafikverket.se/contentassets/05cfe3edce764ca4b2a3c53b4ed9a69c/bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx), tab "4.) Plattformar", row 386 (bandel 711); height key from tab "2.) Förklaringar" | Recorded design category from Trafikverket's register (report dated 2026-02-04), not a survey of the built surface |
| Platform length | 497.1 m, one combined figure for tracks 2a, 2b and 1 | same row | Not split per track. Jönköpings Länstrafik has asked Trafikverket to split it because track 1 differs from 2a/2b ([samrådssvar JNB 2027](https://bransch.trafikverket.se/contentassets/9a597b4de2ba4013985f0d345181534c/redovisning-av-samradssvar-om-jarnvagsnatsbeskrivning-2027.pdf)); likely the sum of platform edges, not one platform's length |
| Platform roof | "Tak" (roof) recorded | same row | Presence only; no extent or height |
| Platform safety markings | "S & L" (protection zone and tactile guidance path) | same row | — |
| Longest track for passing (möteslängd) | 1,470 m, track 2b | same file, tab "3.) Möteslängder", row 314 | Signal-to-signal length, not platform length |
| Laser scan date and coverage | Flown 19–20 March 2022 from 3,200 m, scan blocks 22B007 (east of 450000 E) and 22B006 (west); nominal 1.3 points/m² | Lantmäteriet STAC API, collection dsm-skoglig-copc | The station straddles four 2.5 km tiles (list in section 1) |
| Platform surface (laser) | 91.67 m (bins 91.63–91.71 along the whole platform); platform ends at about 14.1598 E and 14.1671 E (≈450 m along track 2) | Laser ground points, 5–20 m bins along track 2 | Edge about 2.0 m from the track-2 centreline (Trafikverket line) |
| Track bed (laser) | 90.88 m median (90.82–90.99 by 20 m bin) | same | Ballast/sleeper surface; rail head sits higher |
| Platform above track bed | 0.77 m median (IQR 0.73–0.79) | laser | Rail head is typically ~0.15–0.2 m above the sleeper surface, so ≈0.57–0.62 m above rail: consistent with the recorded 0.58 m (estimate, not a rail-head measurement) |
| Canopy 1 (west, over platform 2a) | Top 95.04 m = **3.4 m above platform**; 708 m²; ≈14.1602–14.1623 E | laser, traced; matches OSM roof w401108813 (720 m²) | Top surface; underside not seen |
| Waiting hall roof, 2001 (east of station building; first traced as "canopy 2") | Top 97.77 m = **6.1 m above platform**, sloping ≈98.1 → 96.9 m; 761 m²; ≈14.1635–14.1655 E; the glazed hall along platform 2b, its roof overhanging the platform's town-side half; no ground visible underneath | laser, traced; same outline as OSM w133653929 (tagged *Jönköpings bussterminal*); Commons photos 62899901 and 99563715 show the glass hall along 2b | Not a free-standing canopy: model it as a building whose roof overhangs the platform |
| East part of platform (≈14.1655–14.1671 E) | **No canopy** | laser | Points first traced here were a train on track 1 (see below) |
| Trains in the scan | Two parked trains, each ≈55 m: track 2 at ≈14.1646–14.1655 E (alongside the lake side of the waiting hall's east half) and track 1 at ≈14.1659–14.1668 E; roofs 94.75–94.80 m (≈3.9 m above track bed). Marked as `train_in_scan` in the GeoJSON | laser cross-sections: points over the tracks, ground hidden underneath | Not structures; excluded |
| Station building (OSM w81576737) | Ground 91.6–91.7 m (= platform level); roof top median 100.08 m, p95 100.89 m; **≈8.5 m above ground** | laser points inside OSM footprint (2,569 pts) | |
| Footbridge (OSM w81576735, building=bridge) | Roof top median 100.74 m, p95 101.73 m; ground below 90.7–91.9 m; **≈9.1 m above ground** | laser (307 pts) | Deck height not visible from above; elevator at north end tagged level 0;1 in OSM |
| Waiting hall / bus terminal (OSM w133653929) | Roof top median 96.98 m over the whole OSM footprint; ≈5.5 m above ground (91.6 m) | laser (2,529 pts) | Same structure as the row above; the 97.77 m figure is the traced roof over the platform, 96.98 m the footprint median |
| Juneporten block (OSM r13095414) | Ground slopes from ≈90.7 m (north, street in front of the station) to ≈95.3 m (south entrance, town level); roof median 104.8 m, p95 122.2 m | laser; Juneporten identified from Commons photo camera positions inside the block | Town level is ≈3.6 m above the platform and ≈4.6 m above the station street: consistent with an "upper level about 3.3 m up", not a measurement of its floor |
| Hotel (OSM w986647231, height 61) | Roof top median 154.9 m, ≈59.7 m above ground (95.1 m) | laser | OSM's 61 m agrees |

## Source by source

### 1. Lantmäteriet — Laserdata Nedladdning, skog (airborne laser point cloud)

- **What:** national airborne laser scan, classified point cloud.
  [Product page](https://www.lantmateriet.se/sv/geodata/vara-produkter/produktlista/laserdata-nedladdning-skog/) ·
  [Terms of use, 2026-05-20](https://www.lantmateriet.se/globalassets/geodata/geodataprodukter/anvandningsvillkor-for-laserdata-nedladdning-skog.pdf) ·
  [Access change notice, 2026-05-29](https://www.lantmateriet.se/sv/geodata/vara-produkter/Produktnyheter/Geografisk-information/uppdatering-angaende-tillhandahallandet-av-laserdata-nedladdning-skog/)
- **Licence:** CC BY 4.0 (was CC0 until 31 May 2026; older pages and the OSM wiki still say CC0). When published or spread, the
  terms require: the source as "Laserdata Nedladdning, skog", "©Lantmäteriet", a note that it has been processed (if so), and that
  CC BY 4.0 applies. If that cannot sit next to the data it may go in accompanying documentation or metadata.
- **Extra terms:** Lantmäteriet now considers laser data personal data; the licensee becomes data controller under GDPR and must
  not process it contrary to GDPR. Lantmäteriet may close access on security or privacy grounds.
- **Cost and access:** free. Since 1 June 2026, access is ordered as a permission on [Geotorget](https://geotorget.lantmateriet.se/)
  (account needed, new terms accepted at ordering), then data is fetched via a STAC API. The old download-link delivery ended 31 May 2026.
- **Format:** LAZ, organised as COPC (Cloud Optimized Point Cloud), so a ~500 × 200 m area can be streamed rather than downloading
  whole tiles. SWEREF 99 TM + RH 2000 (EPSG:5845). STAC endpoint `https://api.lantmateriet.se/stac-hojd/v1` (search is open);
  files on `dl1.lantmateriet.se` need the Geotorget login (HTTP login prompt; for a private account, the Geotorget username and
  password). Both 10 × 10 km and 2.5 × 2.5 km tiles are published. The station straddles four 2.5 km tiles:

  | Tile (STAC id) | Covers (SWEREF 99 TM) | Points | File size |
  |---|---|---|---|
  | 22b007-64050_4500_25 | E 450000–452500, N 6405000–6407500 (station north half, mostly lake) | 662,935 | 2.4 MB |
  | 22b007-64025_4500_25 | E 450000–452500, N 6402500–6405000 (station south half, town) | 10,443,998 | 45.1 MB |
  | 22b006-64050_4475_25 | E 447500–450000, N 6405000–6407500 (west ~30 m of platform) | 12,511,852 | 58.3 MB |
  | 22b006-64025_4475_25 | E 447500–450000, N 6402500–6405000 | 14,599,461 | 80.8 MB |

  The first two cover everything east of 14.1592 E, i.e. the whole station except the platform's west tip.
- **Density and accuracy:** 1–2 points/m². Absolute height error (medelfel) under 0.1 m on open, flat, hard surfaces
  ([Kvalitetsbeskrivning laserdata](https://www2.lantmateriet.se/globalassets/geodata/geodataprodukter/hojddata/kvalitetsbeskrivning_laserdata.pdf)).
- **Classes:** ground, water, bridge, low noise, high noise, unclassified. **There is no building class**: roofs and canopies fall
  in "unclassified".
- **Date at Jönköping:** **19–20 March 2022**, flight altitude 3,200 m, nominal density 1.3 points/m² (STAC item metadata).
  Before leaf-out, which suits roofs and canopies.
- **What it could measure at Jönköping C:**
  - *Building heights and simple roof shapes:* yes, roughly. At 1–2 points/m² a large roof gets hundreds of points; take unclassified
    points inside each outline minus ground. Fine detail (parapets, small roof features) is not resolved.
  - *Platform canopies:* probably visible as a band of unclassified points above each platform, giving canopy height and footprint to
    within about a metre in plan. Thin or glass roofs may return few points.
  - *Platform height above rail:* **not reliable.** The platform surface can be averaged well, but laser points rarely hit the rail head
    (a 7 cm wide rail); "ground" points between rails are ballast, which sits below rail level. Use only as a cross-check.
- **Verdict:** use, for building and canopy heights, once the account and GDPR terms are accepted. Store only derived values
  (heights, outlines), not raw points, in the app's data.

### 2. Lantmäteriet — Byggnad Nedladdning, vektor (building outlines)

- **What:** national building polygons. [Product page](https://www.lantmateriet.se/sv/geodata/vara-produkter/produktlista/byggnad-nedladdning-vektor/) ·
  [Product description (EN)](https://www.lantmateriet.se/globalassets/geodata/geodataprodukter/e-pb-byggnad-nedladdning-vektor.pdf)
- **Licence and access:** free "high-value dataset" under
  [terms for high-value datasets containing personal data](https://www.lantmateriet.se/globalassets/geodata/geodataprodukter/anvandningsvillkor_for_vardefulla_datamangder_pu.pdf):
  CC BY 4.0, with attribution of product name, ©Lantmäteriet, processing note, and CC BY 4.0. On top of that: an application stating
  the purpose, which Lantmäteriet must approve (§3.3); personal data only for the approved purpose; storage only in the EU/EEA unless
  the decision says otherwise (§3.5); spot checks and possible withdrawal.
- **Attributes:** **no height and no floor count** on building polygons. It carries type, purpose (e.g. "Järnvägsstation"), name,
  planimetric error in metres, and a capture-position flag saying whether the outline is the façade or the roof edge.
- **Accuracy:** per-building error attribute; 0.025–0.5 m for municipal geodetic measurements, up to 50 m for illustrative outlines.
- **Better than OSM at Jönköping C?** Not checked (data not downloaded). In large towns outlines usually come from the municipality,
  so they are likely good; the error attribute will say.
- **Verdict:** skip for now. It adds no heights, and the purpose-approval and EU-storage conditions are heavy for an app on a global
  store. The Swedish OSM community has had imports of this data stalled since 2025 over these terms
  ([OSM forum thread](https://community.openstreetmap.org/t/oppna-data-fran-lantmateriet/72615?page=8)).

### 3. Lantmäteriet — Markhöjdmodell Nedladdning (terrain model)

- **What:** bare-ground terrain grid, 1 m cells, interpolated from the laser data.
  [Product page](https://www.lantmateriet.se/sv/geodata/vara-produkter/produktlista/markhojdmodell-nedladdning/) ·
  [Product description grid 1+](https://www.lantmateriet.se/globalassets/geodata/geodataprodukter/hojddata/e_mhm1_plus.pdf)
- **Licence:** [terms for high-value datasets](https://www.lantmateriet.se/globalassets/geodata/geodataprodukter/anvandningsvillkor_for_vardefulla_datamangder.pdf)
  (the variant **without** personal data), CC BY 4.0; the STAC collection is labelled `CC-BY-4.0`. No GDPR controller role.
- **Access:** ordered on Geotorget (0 kr, no legal review). STAC collection `dtm-cog`; Cloud Optimized GeoTIFF, float32, 10 × 10 km
  tiles in 512 px blocks, so the station area can be read with a few range requests. Station tile: `640_45` (E 450000–460000,
  N 6400000–6410000); the west neighbour is `640_44`.
- **Accuracy at Jönköping:** tile metadata states height uncertainty 0.2 m and plan uncertainty 1 m; source laser scan 2022-03-20.
- **Slope at the station (measured):** the track bed is near level (90.8–91.2 m over 450 m), but the surroundings are not:
  the town side rises to 94–96.6 m within 100 m south of the tracks, with a ~5 m step at the west end, and Vättern's shore
  (88.8 m) is just north. Flat is fine for the platform itself, wrong for the scene around it.
- **Verdict:** **use now.** Drape the ground on this grid and set the platform base from it.

### 4. Trafikverket — platform records (BIS / NJDB, BanInfo, JNB Bilaga 2A, Lastkajen)

- **What is recorded:** Trafikverket's infrastructure register (BIS) holds a *Plattform* object per platform, and BanInfo's
  "Plattform text" layer gives **the platform's height and length**. The same data feeds the Network Statement appendix
  **Bilaga 2A, "Möteslängder och plattformar"**, whose platform tab lists height and usable length per station and track.
  Heights there are given as categories, defined in the file's explanations tab as: låg 0.35 m, mellan 0.58 m, hög 0.73 m,
  TSD mellan 0.55 m, TSD hög 0.76 m. The platform tab also records length, protection-zone markings and weather protection
  ("Väderskydd": Tak / Skydd / Saknas).
  - [BanInfo service description v1.17 (2026-05-19)](https://bransch.trafikverket.se/contentassets/673d929ff8d147f6b9b694a7b8059f9f/baninfo_tjanstebeskr_1_17.pdf)
  - [JNB 2027 page with Bilaga 2A, version 2026-09-24 (xlsx)](https://bransch.trafikverket.se/for-dig-i-branschen/jarnvag/jarnvagsnatsbeskrivningen-jnb/jarnvagsnatsbeskrivning-2027/)
- **Coverage:** all of Trafikverket's network (Jönköping C is Trafikverket-owned track). The "Plattform" layer is marked as not part of
  NJDB, so privately managed track may be missing. Roofs are **not** recorded in any layer listed.
- **Known quality issues:** Trafikverket admits the extract sometimes mixes total and usable platform length, and operators reported
  wrong heights at a few stations (Kungsbacka, Uddevalla). For Jönköping C the row merges track 1 with tracks 2a/2b, so the
  497.1 m length cannot be assigned to one platform; keep the OSM outline for length and use 0.58 m for height.
- **Reading the file at scale:** the xlsx has about 1,000 platform rows covering every Trafikverket station, keyed by
  station name and track. A one-off import script could set platform height for every Swedish station in the app.
- **Licence and access:**
  - *BanInfo* WMS: **CC0, no fee, no account**. WMS only (map images plus GetFeatureInfo per point), so reading values means clicking each
    platform, e.g. in QGIS. Endpoint: `http://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5` (the PDF's rendering drops the hyphen; the host
    without it does not resolve). Read for Jönköping C on 2026-10-29: see the values table.
  - *Lastkajen* (bulk NJDB in GeoPackage): free, but **needs a user account** and accepting licence terms; Trafikverket's data products
    ask for the source line "© Trafikverket".
  - *Bilaga 2A* xlsx: freely downloadable public document; no licence stated. Facts are fine to cite; prefer taking the numbers from
    the CC0 service to be safe.
- **Verdict:** **use first.** This is the authoritative "as recorded by the infrastructure manager" value, for every station at once.
  Keep the TSI 0.55 m only as a fallback where no record exists.

### 5. Jönköpings kommun — 3D city model, laser data, open data

- **3D model:** exists, photorealistic, ground plus buildings in Jönköping and Huskvarna draped with oblique and aerial photos,
  **from 2016**, updated only for single important buildings. Used for planning; **not open data** — offered as a product under the
  municipal price list ([Kartprodukter](https://www.jonkoping.se/kommun--politik/fakta-kartor-och-statistik/kartor-och-geografisk-information/kartprodukter)).
  Format, level of detail and whether canopies are included: not published.
- **Municipal laser data:** 2016 surface model, **6–12 points/m²** — far denser than Lantmäteriet's — but also a priced product, same page.
- **Open data portal:** [data-jonkoping.opendata.arcgis.com](https://data-jonkoping.opendata.arcgis.com/), CC0 per dataset. 40 datasets,
  mostly leisure (bathing sites, trails); a search for "byggnad" returned nothing. Nothing useful for the station.
- **Verdict:** skip under the "free" rule. Worth one email asking whether they would release the station-area laser cut or model
  extract as open data (open question 4).

### 6. Detaljplaner (planning documents)

- Not resolved in this session; no plan covering the station or Juneporten with floor heights was located. Any figure from a plan
  (e.g. "högsta nockhöjd") is a **maximum allowed**, not what was built, and must be stored as a limit.
- **Verdict:** low priority; laser data or a walk gives as-built values.

### 7. Photos — Mapillary and Wikimedia Commons

- **Wikimedia Commons:** 18 photos selected from the geosearch and from category *Jönköpings centralstation* (40 files), all
  checked 2026-10-29/30. Copies (≤1100 px) are in the station pack as `photo_<pageid>.jpg`, listed in `photos.json` with author,
  licence and source URL; each must be credited as shown:

  | File (page id) | Shows | Date | Author, licence |
  |---|---|---|---|
  | Jönköpings centralstation.jpg (1620775) | Platform 2a looking west towards the footbridge and its stair tower; canopy on the right. | 2007-01-31 | Moralist, CC BY 2.5 |
  | JvmKDAE04591 Jönköping Central.jpg (130733497) | The 1864 Edelsvärd station building, demolished 1983. | 1980s | Seved Walther, CC BY-SA 4.0 |
  | Stationen Jönköping2.JPG (37230708) | Station area seen from Vättern: a train at the platform, arched roofs and offices behind. | 2008-02-28 | Moralist, CC BY-SA 4.0 |
  | Jönköpings resecentrum 01.jpg (186826575) | 1983 station building by Carl Nyrén, clock tower, street side. | 2012-05-25 | Bengt Oberger, CC BY 4.0 |
  | Sweden. Jönköping 002.JPG (10207028) | Station building and clock tower from the street. | undated | Albert Jankowski, Public domain |
  | Sweden. Jönköping 001.JPG (10206769) | "Resecentrum" entrance, part of the 2001 waiting hall. | undated | Albert Jankowski, Public domain |
  | Juneportenexteriör.jpg (148691178) | Juneporten street entrance on the town side (≈95.3 m). | 2024-05-24 | Berikande, CC BY-SA 4.0 |
  | Juneporteninteriör.jpg (148691224) | Inside Juneporten: the glass-roofed passage between the town and the station. | 2024-05-24 | Berikande, CC BY-SA 4.0 |
  | Jönköping - KMB - 16001000304844.jpg (62888390) | Platform 2a under the timber canopy, train on track 2a, Vättern behind. | 2011-05-03 | Bengt A. Lundberg, CC BY 2.5 |
  | Jönköping - KMB - 16001000304745.jpg (62899901) | Glass wall of the waiting hall along platform 2b, roof overhang with louvres, footbridge in the distance. | 2011-05-03 | Bengt A. Lundberg, CC BY 2.5 |
  | Jönköping station 2019 5.jpg (99563715) | Platform 2b beside the waiting hall glass wall; Krösatåg train on track 2b. | 2019-06-18 | Smiley.toerist, CC BY-SA 4.0 |
  | 2019-06-14 4627 Västtrafik X53 3265 i Jönköping.jpg (192277611) | Track 2a under the canopy, departure board, Västtåg X53. | 2019-06-14 | G och J, CC BY 4.0 |
  | 10.05.22 Jönköping Centralstation X50 3289 (52094002443).jpg (119110324) | Canopy over 2a, lake-side tracks and Vättern, seven weeks after the laser scan. | 2022-05-10 | Phil Richards, CC BY-SA 2.0 |
  | Jönköping station 2019 2.jpg (80407393) | From under the footbridge looking east along 2b: canopy, waiting hall, lake-side tracks. | 2019-06-18 | Smiley.toerist, CC BY-SA 4.0 |
  | Jönköping station 2019 3.jpg (80407395) | Along the platform beside the end of the waiting hall. | 2019-06-18 | Smiley.toerist, CC BY-SA 4.0 |
  | Jönköping station 2019 1.jpg (80407396) | Platform end with railing, looking along the station throat. | 2019-06-17 | Smiley.toerist, CC BY-SA 4.0 |
  | Jönköping Central Station - panoramio.jpg (59238338) | Night view from the footbridge looking west: canopy roof, platform, tracks, Vättern on the right. | 2010s | Olof Lagerkvist, CC BY 3.0 |
  | Västtågen at Jönköping Centralstation - panoramio.jpg (57582206) | Västtåg at the platform at night, seen through the waiting hall glass. | 2010s | Olof Lagerkvist, CC BY 3.0 |

  Not found: clear views of the escalators or lift. The Juneporten photos show a ground-level glass-roofed passage, which is
  worth checking against the brief's "upper level about 3.3 m up" during the walk.
- **Mapillary:** coverage at the station is thin and old. Image key `238630658055349` (2015-05-24) shows the station entrance
  doors; other sequences follow the lakeside path and surrounding streets, not the platform. Use only for confirmation.
- **Verdict:** use for confirmation only, as intended; the owner can browse both in a few minutes (open question 5).

### 8. The owner's iPhone 17 (no LiDAR)

- **Apple accuracy figures:** none found; Apple does not publish ARKit measurement accuracy.
- **Camera-only ARKit drift (measured study):** iPhone 11 without LiDAR, ARKit 5: about 2 cm drift when the view is briefly lost,
  about 9 cm after moving with the camera away, and about **15–25 cm after walking away** and back; a LiDAR iPhone stayed under 3 cm
  ([Scargill et al., "Here To Stay"](https://par.nsf.gov/servlets/purl/10358173)).
- **What that means (inference, not tested):**
  - *Platform edge, ~0.5 m:* if both the track bed and the platform top are detected as planes from one spot without walking, error
    is likely a few cm. In practice the track bed is ballast and sleepers, not a clean plane, and the rail head is narrow, so plane
    detection measures the wrong surface. Not reliable for platform height.
  - *Floor, 3–4 m via escalator or stairs:* the walk between marks puts it in the 10–25 cm drift range. Good enough to confirm the
    3.3 m figure to about ±0.2 m.
- **Barometer:** phone-class sensors such as Bosch's BMP380 are specified at ±0.06 hPa relative accuracy, about **±0.5 m**
  ([eeNews Europe](https://www.eenewseurope.com/en/barometric-pressure-sensor-accurate-altitude-tracking-for-consumer-devices/)).
  Apple does not name the iPhone 17's sensor. Useless for 0.5 m; a rough check only for 3 m, and only if both readings are taken
  within a minute (weather drift).
- **Tape measure:** accurate to about 1 cm, but measuring platform-top to rail-top means reaching out over the track. Do **not**
  step down or lean over the edge. Prefer the Trafikverket record; use a tape for stair risers, escalator landings and the
  upper-level floor (count steps × riser height).
- **Verdict:** use the walk for upper-level height and for positions of stairs, lifts and escalators; do not use it for platform height.

### 9. Train car dimensions

Manufacturer or operator spec sheets were not found in the time spent; figures below are from secondary sources and should be
replaced before release.

| Type | Figure found | Source | Notes |
|---|---|---|---|
| X40 (SJ, double-deck) | 2-car 55.1 m, 3-car 81.5 m | [Wikipedia, SJ X40](https://en.wikipedia.org/wiki/SJ_X40) | Uncited on the page; no width or height |
| X61 (Coradia Nordic) | 4 cars, ~74 m, width 3.56 m | [Wikipedia, X61](https://en.wikipedia.org/wiki/X61_(railcar)) | Uncited |
| X2000 | 24.95 m per car; 6 cars + power car | [Mediarail.be](https://ledicoferroviaire.mediarail.be/x2c-x2000-en/) | No width or height |
| Y31 / Y32 (Itino, Krösatåg) | 2-car 38.4 m, 3-car 54.7 m | [Wikipedia, Bombardier Itino](https://en.wikipedia.org/wiki/Bombardier_Itino) | Uncited |
| X60, ER1, X31, X11 | — | not found | — |

Fleets seen around Jönköping: Krösatåg Y31/Y32 and X10/X14, with CAF Civity units arriving from 2026
([Mediarail.be, Krösatågen](https://ledicoferroviaire.mediarail.be/krosatagen-en/)). The brief's list should be checked against
what actually stops at Jönköping C. Better primary sources to try: Transitio's vehicle pages (it owns many regional fleets),
Alstom/Stadler/CAF product sheets, and ERA's register of authorised vehicle types.

**Verdict:** keep the current typical values until primary sheets are in hand; add per-type lengths first (they matter most visually).

## Station pack (usable data, built 30 October 2026)

Everything above, turned into files the app can load directly. Published as the page *Jönköping C Station Pack*
(plan, 3D point cloud, 3D model, cross-sections, photo gallery, values, licences).

| File | What it is | Licence / attribution |
|---|---|---|
| `jonkoping_c_station.json` | One file with every value: levels, platform outline and heights, roofs, buildings, stairs/lift (OSM), trains in the scan, terrain grid reference, which stand-in each value replaces, sources and the attribution lines | CC BY 4.0 (Lantmäteriet) + ODbL (OSM) + CC0 (Trafikverket) |
| `jonkoping_c_model.glb` | 17-part block model plus ground (platform, canopy 2a, waiting hall, station building, footbridge, bus terminal, Juneporten block, hotel, neighbours). Local metres: x east, y up, −z north; origin E 450294.6 N 6405002.8 at 90.0 m (RH 2000). Footbridge underside 97.2 m is an **assumption** | as above |
| `jonkoping_c_ground_1m.tif` | Ground surface 1 m GeoTIFF, 480 × 190, EPSG:3006 / RH 2000, origin E 450030 N 6405120 | CC BY 4.0, Lantmäteriet |
| `jonkoping_c_ground_1m_heightmap.png` + `.json` | Same grid as 16-bit PNG for engines: height = value / 1000 + 85 m | CC BY 4.0, Lantmäteriet |
| `jonkoping_c_laser_station_2022.laz` | Laser points clipped to the station (116,646 points, 2022-03-19/20), original classes; trains marked class 64 | CC BY 4.0, Lantmäteriet (GDPR terms apply) |
| `pointcloud_station.bin` + `.json` | Same points packed for the web: per point uint16 x, y (dm from E 450030 N 6404930), uint16 z (cm above 88 m), uint8 class, uint8 intensity | CC BY 4.0, Lantmäteriet |
| `jonkoping_c_structures_heights.geojson`, `jonkoping_c_platform_trafikverket.geojson` | Outlines with heights; Trafikverket platform track lines | as above |
| `laser_heights.png`, `laser_intensity.png`, `terrain.png` | Rendered rasters, E 450020–450520 N 6404880–6405140 at 0.5 m | CC BY 4.0, Lantmäteriet |
| `xsec_A.png` … `xsec_D.png` | Four laser cross-sections across the platform (canopy 2a, footbridge, waiting hall, east end with train) | CC BY 4.0, Lantmäteriet |
| `photo_<pageid>.jpg`, `photos.json` | The 18 Commons photos above with credits | per photo (table in section 7) |

## Licences together with OpenStreetMap (ODbL)

| Source | Licence | Mix into an ODbL-based data file? | Attribution the app should show |
|---|---|---|---|
| OpenStreetMap | ODbL 1.0 | — | "© OpenStreetMap contributors" |
| Trafikverket BanInfo / NJDB | CC0 | Yes, no conditions | Not required; courtesy line "Järnvägsdata: © Trafikverket" (Lastkajen terms ask for it) |
| Trafikverket JNB Bilaga 2A | Public document, no licence stated | Facts (height category) are fine to store; switch to the CC0 register copy when convenient | "Plattformsdata: Trafikverket, Järnvägsnätsbeskrivning 2027" |
| Jönköpings kommun open data | CC0 (per dataset) | Yes | Not required |
| Lantmäteriet laser, terrain, buildings | CC BY 4.0 + Lantmäteriet's extra terms | Possible, with care | e.g. "Höjddata: Laserdata Nedladdning, skog och Markhöjdmodell Nedladdning, © Lantmäteriet, bearbetad, CC BY 4.0" (one line per product used) |
| Mapillary | CC BY-SA 4.0 | Not stored (confirmation only) | None needed if nothing is copied |

Points to weigh for Lantmäteriet data:

- **Database vs. contribution.** Storing derived heights in the app's own file next to OSM data is different from adding them to OSM.
  The OSM Foundation needs an explicit waiver for CC BY 4.0 data in OSM, which the Swedish community has not obtained.
  So keep Lantmäteriet-derived values in a separate layer, never upload them to OSM.
- **CC BY 4.0 "no technological measures" clause (§2(a)(5)(B)).** App Store delivery uses encryption. Whether that counts is
  unsettled; shipping derived facts (numbers) rather than the dataset itself reduces exposure.
- **GDPR controller role** for laser data: Lantmäteriet places it on the downloader. Processing the cloud on a machine in the EU and
  keeping only per-building heights is the conservative path.

## Recommended order

1. **Trafikverket platform records** — done for Jönköping C. *Platform height* becomes 0.58 m; the platform is one 8 m island
   along track 2 (~457 m) with a short track 1 face (~88 m); *Platform roofs* confirmed. Next: one script over Bilaga 2A
   (or BanInfo) for every Swedish station.
2. **Lantmäteriet Markhöjdmodell** — done for the station area. Replaces *Ground: flat*: drape the 1 m grid; track bed ≈91 m,
   town side up to ≈96.6 m.
3. **Lantmäteriet laser point cloud** — done for the station. Replaces *Building heights and shapes: 4 m box* (station building
   ≈8.5 m, bus terminal ≈5.5 m, footbridge ≈9.1 m, Juneporten block, hotel) and adds *Platform roofs*: canopy 1 at +3.4 m,
   the waiting hall roof at +6.1 m overhanging platform 2b, none on the east part.
4. **One phone walk.** Replaces *Upper level height* (±0.2 m) and tightens *Escalator and stairs positions*. Check on site whether
   Juneporten is really 3.3 m up or a ground-level passage (the 2024 Commons photos suggest the latter).
5. **Train spec sheets** for the types confirmed in the brief. Replaces *Train car sizes*.
6. Skip for now: Byggnad Nedladdning, the municipal 3D model and laser data, detaljplaner.

## Open questions for the owner

1. **Point cloud — done.** Two 2.5 km tiles decoded; the platform's west ~20 m (west of 14.1592 E) lies in tile
   `22b006-64050_4475_25` (58 MB), not yet used. Canopy underside heights and the footbridge deck still need the walk.
2. **The walk** (next visit): mark lower and upper floor in AR with little walking between marks; count stair risers and tape one;
   photograph escalators and lift; never measure over the platform edge.
3. **Per-track platform lengths** are now answered from BanInfo (see the values table); nothing to do.
