# C0 — Station data findings (feasibility spike)

Run on **2026-10-21**. Sources: the Geofabrik extract `data/cache/osm/sweden-latest.osm.pbf` (2026-10-19, read offline with pyosmium 4.3.2, no Overpass calls), GTFS Sweden 3 (`data/cache/gtfs_se3/sweden.zip`), live Trafikverket API calls, and the Jernhusen website. Spike scripts and raw outputs are in the session scratchpad (`c0/extract.py`, `c0/analyze.py`, `c0/jh_parse.py`). They are not committed.

---

## TL;DR

- **Platform numbers are solved.** Trafikverket `TrainStation.PlatformLine` lists every track id, and `TrainAnnouncement.TrackAtLocation` gives the live track per departure. OSM platform `ref`/`local_ref` covers **every track used on 2026-10-20 at all 10 stations** once the `a`/`b` sector suffix is dropped (OSM rarely maps sectors).
- **The walking graph is partial everywhere.** It is a good starting draft, but no station can be used without hand editing. On the pedestrian-only graph, platforms that reach the station building or an entrance: 10/10 stations are at 3/5 or better, and 7 of them are at 100%. Level data is only rich at **Stockholm C**: 567 of 1,342 walk ways have `level`, plus 49 lifts, 104 escalator/moving-walkway ways and 743 `indoor=*` features. Göteborg C is next (162 `indoor=*`, but `level` on only 29 walk ways).
- **Amenities: OSM is decent, Jernhusen is better but not open.** At Stockholm, Göteborg and Malmö, OSM has about 70% of the outlets that Jernhusen lists. Of all POIs within the radii, **61% carry `opening_hours`, and 99.6% of those parse** with a standard parser. Jernhusen's station pages hold the fullest shop/hours/toilet info (as embedded JSON with Swedish free-text hours), but they carry no licence. Treat them as a **manual curation source**.
- **GTFS has no `pathways.txt`/`levels.txt`.** Trafikverket has no platform geometry. No source gives a ready-made station graph.
- **Recommendation: pilot on Stockholm C** (main-line halls and tracks 1–19 first; Stockholm City later). Budget **~16 h** of hand editing for the pilot on top of an OSM draft, plus a ~2 h site walk to time the edges.
- **Licensing catch:** a station JSON drafted from OSM is an ODbL *derivative database*. Publishing it means offering it under ODbL. Decide this before C1 (see Risks).

---

## 1. OpenStreetMap: platforms, indoor, connectivity, POIs

**Method.**
- **Station points:** taken from `data/app.db` `stations` (opened read-only).
- **Areas:** a radius around each point. 350 m by default. **Stockholm C: 650 m**, which includes Stockholm City (pendeltåg, separate Trafikverket station `Sci`, ~570 m east), T-Centralen and Cityterminalen. **Göteborg C and Malmö C: 500 m**, which includes Nils Ericson terminalen and the Citytunneln platforms under Malmö C.
- **Extraction:** one pass with a `KeyFilter` (railway, highway, indoor, amenity, shop, level, …) and `locations=True`. It took 211 s and kept 11,345 nodes, 14,900 ways and 944 relations.
- **Platforms:** `railway=platform`, or `public_transport=platform` + `train=yes`. Bus, tram and subway platforms are excluded. These are OSM **objects**: one physical platform is often split into several pieces (Stockholm's track 15/16 platform has 5).
- **Walking graph:** ways tagged `highway=footway|path|steps|corridor|pedestrian|elevator|living_street`, `conveying=*`, `indoor=corridor|area` and platform outlines. Nodes are joined when ways share them (union-find). Roads are excluded.
- **"Connected":** the platform shares a component with a station entrance or a hall. A station entrance is `railway=train_station_entrance`, or an `entrance=*` node on the station building outline. A hall is a walk-graph node inside a station polygon (`building=train_station|transportation`, `railway=station`, `public_transport=station`).
- **"In-station" POIs:** POIs inside those polygons. Bus stops and taxi ranks are left out of POI totals.
- **Track match:** compared with the `TrackAtLocation` values seen on 2026-10-20.

| Station (radius) | Platform objects | with ref | with level | Tracks used 10-20 / matched | Connected to hall/entrance | Walk ways (with level) | indoor=* | Steps / lifts / conveying | In-station POIs (hours / level) | In-station toilets |
|---|---|---|---|---|---|---|---|---|---|---|
| Stockholm C (650 m) | 51 | 43 | 45 | 29 / 29 | 41/51 | 1342 (567) | 743 | 209 / 49 / 104 | 59 (42 / 42) | 2 |
| Göteborg C (500 m) | 16 | 16 | 0 | 16 / 16 | 16/16 | 530 (29) | 162 | 22 / 0 / 5 | 50 (29 / 40) | 2 |
| Malmö C (500 m) | 11 | 11 | 0 | 21 / 21 | 11/11 | 499 (4) | 54 | 18 / 9 / 6 | 38 (19 / 11) | 1 |
| Uppsala C | 10 | 10 | 8 | 13 / 13 | 10/10 | 263 (29) | 23 | 11 / 3 / 1 | 13 (8 / 8) | 1 |
| Hässleholm C | 13 | 13 | 0 | 12 / 12 | 13/13 | 171 (0) | 12 | 16 / 0 / 1 | 4 (2 / 0) | 2 |
| Linköping C | 5 | 5 | 0 | 5 / 5 | **3/5** | 264 (0) | 1 | 18 / 0 / 0 | 7 (5 / 0) | 1 |
| Örebro C | 4 | 4 | 0 | 4 / 4 | 4/4 | 153 (0) | 9 | 19 / 3 / 0 | 0 | 0 |
| Norrköping C | 11 | 11 | 0 | 9 / 9 | 10/11 | 106 (0) | 1 | **0** / 0 / 0 | 3 (2 / 0) | 0 |
| Lund C | 11 | 6 | 0 | 7 / 7 | 11/11 | 521 (9) | 30 | 57 / 16 / 8 | 13 (5 / 0) | 2 |
| Västerås C | 9 | 9 | 0 | 9 / 9 | 9/9 | 109 (22) | 21 | 6 / 4 / 1 | 4 (3 / 0) | 1 |

**Platforms.**
- **Matching rule:** strip a trailing sector letter (`17b` → `17`). Two stations also need the reverse: Trafikverket announces `7` (Norrköping) and `4` (Västerås), where OSM has only `7a`/`7b` and `4a`/`4b`.
- **Sector letters are inconsistent.** OSM models sectors at Hässleholm, Norrköping, Västerås and Örebro (`1a`, `1b`, …), but not at Stockholm C, where Trafikverket uses `12a`–`19b` heavily: 207 of 371 Cst rows on 10-20.
- **Stockholm C refs:** the main-line platforms carry `local_ref` (1–19, one per platform side) rather than `ref`. There are also 2 unexplained objects, `local_ref=E6;E7`.
- **Stockholm City:** OSM has 2 platform areas at `level=-2` with no ref. Trafikverket lists tracks 1–4.
- **T-Centralen (metro):** has `train=yes` platforms at `level=-4` with `ref` 5/6. This is mis-tagging that the draft script must filter out.
- **Lund C:** 5 of 11 platform objects have no ref. All are 100–260 m from the main platforms.
- **Norrköping:** 2 objects are bus-style bays (`D1`, `D2`) tagged `railway=platform`.
- **Track `x` means no track.** On 10-20 there were 117 `x` rows at Göteborg (all `TypeOfTraffic=Buss`, i.e. replacement buses) and 53 at Stockholm City (cancelled pendeltåg).

**Walking graph.**
- **Unconnected platforms are real gaps, not script errors:**
  - Stockholm C: all 5 pieces of the track 15/16 island are unconnected. So are 4 unnamed or `E6;E7` objects.
  - Linköping C: the island platforms for tracks 4 and 5 are unconnected, because the underpass is not joined to them.
  - Norrköping: `D1` is unconnected.
- **Connectivity is optimistic.** Footways in Sweden join the street sidewalk network, so "connected" can mean "via the street outside". It shows the graph exists, not that it is correct. Every edge needs `seconds` added by hand or computed, and checked.
- **Levels:**
  - Only Stockholm C has level-tagged indoor corridors at scale.
  - Göteborg C's platforms are at grade with the concourse (a terminus), so missing levels matter less there.
  - Malmö's Citytunneln platforms (tracks 1a–4b, the busiest: ≥ 705 of 872 Mc rows on 10-20) have **no `level` tag**, and only 4 walk ways have one.
  - `repeat_on` is used only at Göteborg (6 objects). `level:ref` is not used anywhere.
  - Norrköping has no steps mapped at all.

**POIs and opening hours.**
- **Within the radii:** 2,022 POIs (excluding bus/taxi). 1,232 (61%) have `opening_hours`. 1,227 of those (99.6%) parse with `opening-hours-py`. The 5 failures use non-standard separators (`Mo-Fr 10:00-20:00,Sa-Su 10:00-18:00`, `Mo-Fri`).
- **In-station POIs** have hours at a rate of 42/59 (Stockholm), 29/50 (Göteborg) and 19/38 (Malmö).
- **Toilets:** 44 of 55 toilets carry `fee=*`. Some have `charge=10 SEK`, and one has a non-standard `level=övre plan`.
- **OSM vs Jernhusen hours** (same outlet, both sources):
  - Stockholm C's paid toilet (`operator=Rena sitsen`, level -1): OSM says `Mo-Fr 05:00-01:15`, Jernhusen says 05.00–01.00. They disagree.
  - Göteborg C's toilet: OSM and Jernhusen agree exactly.
- **Freshness check:** first-word name match of Jernhusen's shop/restaurant list against OSM in-station names. Stockholm 31/44, Göteborg 23/31, Malmö 20/27, Uppsala 6/8, Lund 3/5. Missing outlets are mostly new food concepts (e.g. "Holy Greens", "Pocket Shop").

## 2. GTFS Sweden 3 pathways/levels

**Absent.** `unzip -l sweden.zip` (feed of 2026-10-20) lists 14 files: agency, areas, attributions, booking_rules, calendar, calendar_dates, feed_info, routes, shapes, stop_areas, stop_times, stops, transfers, trips. There is no `pathways.txt` or `levels.txt`.

## 3. Trafikverket

- **`TrainStation` 1.4 (Cst) returns these fields:** `Advertised`, `AdvertisedLocationName`, `AdvertisedShortLocationName`, `CountryCode`, `CountyNo`, `Deleted`, `Geometry` (`SWEREF99TM`, `WGS84`: **one station point only**), `LocationInformationText`, `LocationSignature`, `OfficialLocationName`, `PlatformLine`, `Prognosticated`, `ModifiedTime`. There is no platform geometry, level or equipment field.
- **`PlatformLine` is the authoritative list of track ids.**
  - Number of entries: Cst 34 (1–19 with a/b), G 16, Mc 33, U 17, Hm 16, Lp 7, Ör 5, Nr 12, Lu 8, Vå 11, Sci 4.
  - Its length is a cheap station-size signal for the no-map fallback.
  - Every station except Sci carries the text "Spåruppgifterna är preliminära och kan ändras", so tracks must be treated as live and changeable.
- **`TrainAnnouncement.TrackAtLocation`** is the per-departure platform. All 10 stations were fetched for one day in one query (5,081 rows, 4.7 s). Every row had a value. The values match `PlatformLine` spelling (lower-case sector letters).
- **`TrainStationMessage` 1.0** exists:
  - 2,559 active messages: `Monitor` 1,796, `Utrop` 407, `Plattformsskylt` 356.
  - Messages are free text, with `PlatformSignAttributes.TrackList` (upper case, e.g. `2B`).
  - 25 active messages mention lifts ("Hissen vid spår 1 kommer att vara avstängd 21/9 - 30/10", Boden C).
  - This is a possible P2 "lift out of order" source. It is unstructured.
- **Other object types:** `Platform`, `StationEquipment` and `Elevator` do not exist ("ObjectType … does not exists"). `RailCrossing` exists but is irrelevant. The data-model page (`data.trafikverket.se/documentation/datacache/data-model`) is a JavaScript app and was not readable with curl. No platform or equipment object was found.

## 4. Station owners and websites

- **Jernhusen.**
  - **Ownership:** their own page says they own **35 stations**. Station *buildings* are Jernhusen's, while tracks and platforms are Trafikverket's (Jernhusen consultation response, quoted via search). Confirmed by named sources: Stockholm C, Göteborg C, Malmö C, Uppsala C, Örebro C and Linköping C. Not verified in this spike: Hässleholm, Norrköping, Lund, Västerås.
  - **"Hitta din station" (`jernhusen.se/hitta-din-station`)** lists 129 stations, including all 10 of ours. Being listed does not mean Jernhusen owns the station.
  - **Subpages** per station: mat-och-butiker, toalett, förvaringsboxar, tillgänglighet, karta, and more.
- **Structured data on Jernhusen pages.**
  - The pages are Next.js/DatoCMS. There is no schema.org JSON-LD. The page payload embeds `ShopRestaurantModelRecord` objects with `title`, `type` (shop/restaurant), `link`, `coordinates` and `openingHours` as Swedish rich text ("Mån–fre 06.00-21.00\nLör-sön 07.00-20.00", some with "11:30 – Sent" or phone numbers).
  - **Coordinates are not usable for placement.** Most outlets share the station address point: Stockholm has 4 distinct coordinates for 44 outlets.
  - **Outlets per station** (with hours, approx.): Stockholm 44 (44), Göteborg 31 (28), Malmö 27 (27), Uppsala 8 (5), Linköping 4 (2), Lund 5 (~2), Norrköping 3 (2), Hässleholm 2 (2), Västerås 2 (1). Örebro's food page is at a different path and was not parsed.
  - **Toilet pages give prose:**
    - Stockholm C: card payment, 10 kr (shower 40 kr), in Nedre hallen, hours given.
    - Göteborg C: staffed toilet with hours. Nils Ericson terminalen has unstaffed toilets.
    - Malmö C: staffed toilets at track 5, plus Gröna hallen, hours given.
    - Uppsala C: operated by One Hundred Restrooms, on the upper level.
    - The other stations only say "toilet and accessible toilet, card payment". No price or hours.
  - **Downloadable maps:** PDF floor maps exist for Stockholm C (5 PDFs: whole station, Centralhallen, Nedre hallen, Övre hallen, Cityterminalen) and Malmö C (1). The other stations only have an area map page. The PDFs are copyrighted: use them to check facts, and never copy or trace them.
- **robots.txt and terms:**
  - `jernhusen.se/robots.txt` is `User-agent: * / Allow: /`.
  - No terms-of-use or licence page was found. The footer only links data protection and cookies, and `/anvandarvillkor` returns 404.
  - So the content is all rights reserved by default. Swedish copyright law protects catalogues (*katalogskydd*, URL 49 §) against copying substantial parts.
  - **Verdict:** a manual curation source. Copy individual facts, verify them, and never bulk-harvest.
- **Stations' own websites:**
  - stockholmcentral.se fails TLS (certificate for another host).
  - stockholmcentralstation.se, goteborgcentral.se, malmocentral.se and uppsalacentral.se gave no response.
  - Jernhusen is the de facto station website.
- **SJ:** none of the 796 URLs in its sitemap is a per-station page (only FAQs). SJ is not a station data source.

## 5. Licensing per source

| Source | Licence / terms | What it means for us |
|---|---|---|
| OpenStreetMap | ODbL 1.0 | "© OpenStreetMap contributors" on the map and the Sources page. A station JSON drafted from OSM and edited is a **derivative database**. Using it publicly means offering that database (or the method to recreate it) under ODbL. |
| Trafikverket API | **CC0 1.0**. trafikverket.se's API page links "Licens – senaste versionen" to `creativecommons.org/publicdomain/zero/1.0`, and registration requires accepting it | Free to use. Attribution is courteous, not required. |
| GTFS Sweden 3 | Not relevant here (no pathways) | — |
| Jernhusen web pages and PDFs | No licence stated, so copyright and *katalogskydd* apply. robots.txt allows crawling, but that is not a licence | Manual fact checks only. To use their data systematically, ask Jernhusen for permission or a feed. |
| SJ | Not used | — |

---

## C0 summary table: best source and quality per station

"Platform numbers": Trafikverket for ids and live tracks, OSM for where each platform is. "Walking graph": OSM draft plus hand edits; "good" would mean usable without hand work, and no station reaches that. "Hours": quality of the best available source for in-station outlets.

| Station | Platform numbers | Walking graph | Toilets | Shops | Opening hours |
|---|---|---|---|---|---|
| Stockholm C | TRV + OSM `local_ref`: **good** (no a/b sectors in OSM) | OSM: **partial**, the richest (levels, 49 lifts, 104 escalators). Track 15/16 island unconnected | OSM 2 + Jernhusen (fee, hours, level): **good** | OSM 59 in-station, ~70% of Jernhusen's 44: **partial/good** | OSM 42/59 + Jernhusen 44/44 (manual): **partial/good** |
| Göteborg C | TRV + OSM `ref`: **good** | OSM: **partial**. 16/16 connected, at-grade terminus, few levels | OSM 2 (one matches Jernhusen exactly) + Jernhusen: **good** | OSM 50 + Jernhusen 31: **partial/good** | OSM 29/50 + Jernhusen 28/31: **partial/good** |
| Malmö C | TRV + OSM: **good** | OSM: **partial**. Connected, but Citytunneln has no levels | OSM 1 + Jernhusen: **partial** | OSM 38 + Jernhusen 27: **partial** | OSM 19/38 + Jernhusen 27/27: **partial** |
| Uppsala C | TRV + OSM: **good** | OSM: **partial** | OSM 1 + Jernhusen: **partial** | OSM 13 + Jernhusen 8: **partial** | OSM 8/13: **partial** |
| Hässleholm C | TRV + OSM (sectors mapped): **good** | OSM: **partial**. No levels | OSM 2 + Jernhusen (no price): **partial** | OSM 4 + Jernhusen 2: **partial** | **partial** |
| Linköping C | TRV + OSM: **good** | OSM: **partial**. 3/5, tracks 4–5 unreachable | OSM 1 + Jernhusen: **partial** | OSM 7 + Jernhusen 4: **partial** | **partial** |
| Örebro C | TRV + OSM: **good** | OSM: **partial** | Jernhusen only (prose): **partial** | OSM 0 in-station: **none** (Jernhusen, manual) | **none** in OSM |
| Norrköping C | TRV + OSM: **good** | OSM: **partial**. No steps mapped | Jernhusen only: **partial** | OSM 3 + Jernhusen 3: **partial** | **partial** |
| Lund C | TRV + OSM (6/11 objects with ref): **good** | OSM: **partial**. 16 lifts, 57 steps | OSM 2 + Jernhusen: **partial** | OSM 13 + Jernhusen 5: **partial** | OSM 5/13: **partial** |
| Västerås C | TRV + OSM: **good** | OSM: **partial**. 22 walk ways with levels | OSM 1 (fee, hours) + Jernhusen: **partial** | OSM 4 + Jernhusen 2: **partial** | **partial** |

**Verdict:** the data is good enough to proceed with C1, without stopping. No station has a ready-made graph, so every map is hand-curated, as the spec expects.

## Recommended pilot: Stockholm C

- **It has the best OSM indoor data by a wide margin:**
  - 743 `indoor=*` features vs 162 at Göteborg.
  - `level` on 567 walk ways vs 29.
  - 49 lifts and 104 escalator ways, which Göteborg has almost none of.
  - That is what the level switcher, step-free routing and lift glyphs need to be tested against.
- **The supporting sources are richest:** 5 floor-map PDFs to check facts against, 44 outlets with hours, a toilet page with price and location, and 19 tracks with heavy a/b sector use. Sector handling would surface early.
- **It is the busiest of the 10:** about 371 advertised Cst departures and arrivals on 10-20, plus City.
- **Scope the pilot** to the main-line station: Centralhallen, Nedre hallen, Övre hallen and tracks 1–19. Add Stockholm City and T-Centralen as a later extension, after deciding Cst↔Sci transfers (see open questions).
- **Fallback pilot: Göteborg C.** All 16 platforms are connected, at grade off one concourse, so it is about half the work. But it would not exercise levels or lifts.

## Time to author one station (hand-editing an OSM draft)

This assumes `draft-from-osm` and the preview page already exist. It covers data work only.

| Task | Stockholm C | Göteborg C | Mid-size (Linköping, Örebro, …) |
|---|---|---|---|
| Clean the draft, simplify outlines, define levels | 3 h | 1.5 h | 0.5 h |
| Platforms: merge OSM pieces, add a/b sector nodes, map refs to Trafikverket ids | 2 h | 1 h | 0.5 h |
| Nodes and edges, fix gaps (e.g. the 15/16 island), set `seconds` and `step_free` | 5 h | 2.5 h | 1–1.5 h |
| POIs: check against Jernhusen and OSM, convert Swedish hours to OSM syntax, fees | 3 h | 2 h | 0.5–1 h |
| QA in `/dev/station/:id` (clicking platform pairs) | 2 h | 1 h | 0.5 h |
| **Total (desk)** | **~15–16 h** | **~8 h** | **~3–4 h** |
| Site walk to time edges (for the ±1 min acceptance test) | +2 h | +1.5 h | +1 h |

**Fallback for stations without a map** (no geometry is invented):
- Platform numbers and live platform changes still come from Trafikverket.
- The connection card uses the spec's size-class walk estimate, labelled "Estimated, no station map". The class can come from the number of distinct base tracks in `PlatformLine`: ≤ 4 small, 5–10 medium, > 10 large. For example, Ör = 3 base tracks (small), Lp = 5 (medium), Cst = 18 (large).
- An optional "amenities list without map" can be built from hand-curated facts with hours. It needs no geometry, so curation is cheap (~0.5 h per station).

## Risks and open questions for the owner

1. **ODbL share-alike:** do we accept that `data/stations/*.json` (OSM-derived) is published under ODbL? The alternative is to keep OSM-derived geometry and hand-curated facts in separable files. Mixing in Jernhusen-sourced text makes this harder.
2. **Jernhusen permission:** should we email Jernhusen to ask for reuse rights or a feed? Their CMS already has structured outlets and hours. Without permission we copy facts by hand only.
3. **Sectors (a/b):** Trafikverket announces half-platform sectors (`17b`). On a 300 m platform that can mean 1–2 min of walking. Proposal: model sector nodes by hand. When the announcement has no sector, use the platform midpoint.
4. **Stockholm City:** include Cst↔Sci transfers (via Nedre hallen / Centralen tunnel) in the pilot or later? OSM's City platforms have no refs.
5. **Freshness:** about 30% of Jernhusen outlets are missing in OSM, and the two sources can disagree (toilet hours at Cst). `hours_verified` dates and the 12-month stale label are needed from day one.
6. **Tracks are preliminary** and `x` means none (replacement bus or cancelled). The Layover chip must handle both: show "Unknown".
7. **Lift outages** exist only as free text in `TrainStationMessage`. This is P2. It must not drive step-free routing automatically.
8. **Ownership:** not verified for Hässleholm, Norrköping, Lund and Västerås. It only matters if we approach owners for data.

## Decisions (owner, 2026-10-21)

- **Pilot:** Stockholm C, main-line station first (tracks 1–19, halls); Stockholm City later.
- **No site work:** walking times come from the map (distance, stairs, escalators, lifts) and are labelled as
  estimates from the map, not timed on site. `quality` stays `osm_draft` until someone checks it in person.
- **Licence:** accepted. `data/stations/*.json` is offered under the ODbL with OpenStreetMap attribution
  (`data/stations/README.md`, the Sources page, and on the map).
- **Jernhusen:** used to check facts by hand only; nothing copied in bulk.
- **Gaps in OSM** are filled in `scripts/stations/740000001.edits.json` with a note on each: platform 10 and the
  south ends of 2–6 joined to the hall, and stairs assumed from the tunnel to the 15/16 island (no lift assumed, so
  step-free routes there show as "not mapped").

