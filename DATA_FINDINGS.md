# Phase 0 — Data findings (Sweden)

Run on **2026-10-20** against live data. All numbers below come from the scripts in
[`scripts/phase0/`](scripts/phase0/README.md). Raw outputs are reproducible from those scripts. Cached
downloads live in `data/cache/` (gitignored).

**Deliverables:** this file, [`data/station_mapping.draft.csv`](data/station_mapping.draft.csv),
[`data/station_overrides.json`](data/station_overrides.json), [`data/category_overrides.json`](data/category_overrides.json),
[`docs/phase0/route_sample.png`](docs/phase0/route_sample.png).

---

## TL;DR — what changes versus the spec

| # | Spec assumption | What the data says | Proposed change |
|---|---|---|---|
| A | §10: fetch actuals "when the app is opened" | **Trafikverket keeps only ~4 days of history** | A small server-side job snapshots every leg that arrived in the last 3 days (**decided**, see Decisions). |
| B | §5.3: GTFS Sverige 2 fetched with a key, packaging unknown | Keyless public **archive of daily snapshots back to Aug 2012** at `data.samtrafiken.se` | Use the archive for history (no quota). The key is only needed for the newest snapshot. |
| C | §12: prefer GTFS shapes if good | GTFS rail shapes are **straight stop-to-stop lines** for ~95% of trips | OSM routing is the primary geometry: **99.1% of station pairs** route along real track with SE+DK+NO data (the rest are Germany and bus stops). |
| D | §8: rolling window −7 days from GTFS Sweden 3 | GTFS Sweden 3 starts at **yesterday** (runs to Dec 2027) | Never delete past days on import (keep our own history); older dates come from the Sverige 2 archive. |
| E | §11: classify by route_type/agency/name | **Replacement buses are filed under rail route_types and train numbers** | Exclude using Trafikverket `TypeOfTraffic = Buss` and "trip calls at a non-railway stop". |
| F | §5.2: GTFS file is "a download" | `sweden.zip` is **804 MB** (3.9 GB unzipped; `shapes.txt` alone is 3.0 GB) | The import must stream and should skip `shapes.txt`. |
| G | §5.2: Bronze = 50 calls/month | Docs say Bronze = 50/month. The owner says this key allows 60 | Guard assumes 50 (**decided**). |
| H | §10: match by `AdvertisedTrainIdent = train_number` on that date | Train numbers **change mid-journey** (odd/even switches, night train 300 → 3940), **collide** across operators, and GTFS service days ≠ Trafikverket dates after midnight | Match Trafikverket rows by **(station signature, activity, advertised local time)**, using the number only to choose between candidates. |
| I | §7: stations keyed by GTFS stop ids | GTFS Sweden 3 platform ids are feed-specific; Sverige 2 uses **rikshållplats ids**, stable 2012 → 2026 | Key `stations` by rikshållplats id (`stop_area_id`); attach Trafikverket signature and GTFS ids as attributes. |

---

## 1. Trafikverket history window

Script: `trv-history-window.mjs`, plus a global oldest/newest query.

- **Oldest row in the whole `TrainAnnouncement` dataset:** 2026-10-16 00:00 local, i.e. **00:00 four days ago**. Nothing exists before that, for any train.
- **Newest row:** 2026-11-04 (≈ **15 days ahead**).
- Within the window, past advertised stops normally have `TimeAtLocation` (actual) and `TrackAtLocation` (platform). Example: SJ 523 on 2026-10-17/18/19 had 16/16 advertised rows with actual times and tracks. Some regional lines have gaps; see "How complete are actual times?" below.

| days ago | 1 | 2 | 3 | 5 | 7 | 30 | 90 | 365 |
|---|---|---|---|---|---|---|---|---|
| SJ 523 rows with actual times | 99 | 16 | 16 | 0 | 0 | 0 | 0 | 0 |

(Day 1 has 99 rows because it also includes non-advertised passage points. See below.)

**Implications**
- "Full delay data" ends **~3 full days after the trip**. A leg added later than that, or a past leg whose actuals were never fetched in time, becomes `scheduled_only`.
- Waiting for the user to open the app (spec §10) will lose data whenever they don't open it within 3 days. **Decided:** a server cron (node-cron, already in the stack) that runs a few times a day and snapshots all `planned` legs whose scheduled arrival has passed. It costs about 1 Trafikverket request per leg.
- Every row also carries non-advertised technical passage points (`Advertised=false`) with actual times. That's useful later for "passed through" and progress, but filter on `Advertised=true` for the stop list.
- Schema versions: **`TrainAnnouncement` 1.9** and **`TrainStation` 1.4** are the newest accepted (1.10 / 1.5 rejected). Times come with offsets (`+02:00`/`+01:00`), so convert to UTC on ingest.
- Useful extra fields not in the spec: `TimeAtLocationWithSeconds`, `TypeOfTraffic` (Tåg/Pendeltåg/Buss), `ProductInformation` (e.g. "SJ Snabbtåg"), `OperationalTrainNumber`, `TrainComposition`, `Deleted`.
- `TrainStation` has 1,756 locations with WGS84 points (`"POINT (lon lat)"`) and includes foreign stations (`Dk.kh`, `No.osl`, `De.dh`, …). It has no deleted objects: closed stations (old Båstad, old Kiruna C) are simply gone.

**How complete are actual times?** (2026-10-19, a fully past day)
- Restricted to trains (not buses), **2.5% of advertised rows have no `TimeAtLocation`**. The gaps are concentrated:

  | Product | Rows without actual |
  |---|---|
  | VTAB (Värmland) | 33% |
  | Västtågen | 11% |
  | Krösatågen | 10% |
  | TiB | 3% |
  | SJ, SL Pendeltåg, Pågatåg, Mälartåg | < 1% |

  These look like stations without train detection (Trafikverket only knows times where track reporting exists). Only 2 trains (the Järnvägsmuseet railbus) had no actuals at all.
- Per GTFS stop event (see §2), **95.5–96.3% of Swedish stop events have an actual time**. So data quality must be **per stop**: a leg can have an actual departure but no actual arrival.
- **Data quality per leg should be:**
  - `full` = actual departure at origin **and** actual arrival at destination.
  - Otherwise the leg is partial. It still counts for distance and CO₂, but is excluded from delay stats when the destination arrival is missing.

**Cancellations and delay reasons**
- `Canceled` is **per stop row**, so partial cancellations exist. That's 1.0–2.5k cancelled rows per day across 112–241 trains. Cancelled rows show `TrackAtLocation: "x"`, and a few (≈2%) still carry a `TimeAtLocation`, so don't treat "has actual" as "ran".
- `Deviation` (code + text) mixes real **delay reasons** with **passenger notices**:
  - Reasons: `ANA015 Elfel`, `ANA034 Fordonsfel`, `ANA050 Signalfel`, `ANA063 Tågkö`, `ANA003 Banarbete`, `ANA040 Obeh. i spår`.
  - Notices: `ANA031 Kort tåg`, `ANA055 Spårändrat`, `ANA012 Dörr 2-13`, `ANA282 Hpl C`.
  - Replacement buses: `ANA006 Buss`, `ANA007 Buss ersätter`, `ANA274 Buss 22K`.
- **`ReasonCode` (schema 1) exists**: 787 codes with a 3-level hierarchy (`Level1Description` "Avvikelse" …). Phase 1 should keep a small whitelist of codes shown as "delay reason" and treat the rest as notices.
- `EstimatedTimeAtLocation` is present on ~24% of rows that lack an actual. `Prel. tid` marks preliminary times.

## 2. Train number in GTFS Sweden 3

Script: `q2-train-numbers.mjs`, run for 2026-10-19 and 2026-10-20.

**The public train number is `trips.samtrafiken_internal_trip_number`** (a Samtrafiken extension column). It is filled for 100% of rail trips. `trip_short_name` is filled for only ~7% of trips, and `route_short_name` is sometimes the line number instead (SL Pendeltåg `40`/`41`/`43`).

| Field | Filled | Number + an advertised time match Trafikverket |
|---|---|---|
| `samtrafiken_internal_trip_number` | 4157/4157 | **3240 (77.9%)** |
| `trip_short_name` | 300/4157 | 291 (7.0%) |
| `route_short_name` | 4157/4157 | 2388 (57.4%) |

First pass, number only (2026-10-19), using `samtrafiken_internal_trip_number`. This is superseded by the final method below:
- **100% match:** Västtågen, SL Pendeltåg, Pågatåg, Mälartåg, SJ, VR Sverige (Öresundståg), Tåg i Bergslagen, Krösatåg (all), Östgötapendeln, Norrtåg, Värmlandstrafik, Tågkompaniet, X-Tåget, Vygruppen.
- **0% (expected: not in Trafikverket at all):**
  - Roslagsbanan (Transdev, 493 trips) and Saltsjöbanan (AB Stockholms Spårvägar, 231). These are not on Trafikverket's network.
  - **Arlanda Express** (180). Trafikverket's own station text says "Arlanda Express visas ej".
  - These will always be `scheduled_only`.
- **Partial:** Snälltåget 57% and a few Öresundståg/MTRX. GTFS uses a leading extra digit for date or route variants (`90306`, `10300`, `93940`, `51053`). Dropping the first digit finds Trafikverket's `306`, `300`, `3940`, `1053`. But `90306` is actually a connecting bus on another route and `10300` continues as `3940`, so stripping alone is unsafe. The final method below requires matching stations *and* times.
- 229–305 Trafikverket trains per day have no GTFS counterpart. They're mostly short-notice Västtågen variants (`63594`…), buses (`TypeOfTraffic=Buss`) and the Järnvägsmuseet railbus. A train-number search should therefore also query Trafikverket for dates inside its window.

**Final matching method (`q2-match.mjs`).** Three things make "number on a date" unreliable on its own:
1. **Numbers change mid-journey.**
   - Swedish trains switch between odd and even numbers at certain points (SJ 158 ↔ 159, Tågkompaniet 8901 ↔ 8906).
   - Snälltåget's Berlin night train is GTFS `10300` but Trafikverket `300` (Malmö arrival only) and then `3940` (Malmö 08:18 → Stockholm 13:17).
2. **Numbers collide.** Roslagsbanan has its own trip `2031` on the same day as MTRX train 2031.
3. **Service day vs calendar day.** GTFS puts Öresundståg's after-midnight run on the previous service day as `51168` at "26:27"; Trafikverket files it as `1168` on the calendar day at 02:27.

So the matcher keys on **(Trafikverket signature, Ankomst/Avgang, advertised local minute)** from the station mapping and accepts any Trafikverket train sharing ≥ 2 such events with the GTFS trip. The GTFS number, or the number minus its first digit, is tried first. Events at stops where boarding is forbidden (`pickup_type=1`) or alighting is forbidden (`drop_off_type=1`) are skipped, because Trafikverket doesn't advertise them either (e.g. Norrtåg at Umeå C).

| Date | Trips matched* | Swedish stop events matched | …with an actual time |
|---|---|---|---|
| 2026-10-18 | 2173/2196 (99.0%) | 99.41% | 96.30% |
| 2026-10-19 | 3235/3245 (99.7%) | 99.22% | 95.46% |
| 2026-10-20 | 3313/3321 (99.8%) | 99.52% | (day not finished) |

\*Excludes Roslagsbanan, Saltsjöbanan and Arlanda Express, which aren't in Trafikverket.

- **Remaining unmatched events:**
  - Värmlandstrafik and SJ replacement-bus segments.
  - Snälltåget night-train running days where GTFS and Trafikverket disagree (GTFS says `10300` runs on days Trafikverket doesn't list).
  - Small timetable differences (MTRX 2031: GTFS Alingsås 15:00 vs Trafikverket 14:58).
- **Lowest actual-time coverage:**
  - Värmlandstrafik 40–63% and Tågkompaniet 57–62%.
  - Krösatåg KLT 66–76% and Krösa Nord 84–87%.
  - Västtågen 88–93%.
- **Replacement buses by number:**
  - On 2026-10-20 **all 224 Trafikverket bus numbers were 5-digit numbers starting with 5–9**. Only 2 trains used such numbers (`7xxxx`); 391 other 5-digit trains start with 1–3.
  - GTFS rail trips with such numbers were buses whenever Trafikverket knew them (Värmlandstrafik 25–28 per day, SJ 14–16 per day).
  - But GTFS `51168` (5-prefix) is a real train, so the prefix is a strong hint, not a rule. Trafikverket `TypeOfTraffic` decides inside its window.

**Operator vs brand:** `attributions.txt` (`organization_name`) is the reliable operator field. `agency.txt` names are often just numbers ("187", "110"). The two sources disagree on Öresundståg: GTFS says "VR Sverige AB", Trafikverket says "ARRIVA". **Display the brand/product** (Öresundståg, Pågatåg, SJ Snabbtåg) and keep the company as secondary data.

## 3. Station ID mapping

Script: `q3-station-mapping.mjs` → **`data/station_mapping.draft.csv`** (735 rows, one per GTFS parent station used by rail).

Three independent methods, cross-checked:

1. **official** — `stop_areas.txt` (GTFS station → rikshållplats) plus Trafiklab's keyless [`trafikverket_stops.txt`](https://api.trafiklab.se/v2/samtrafiken/gtfs/extra/trafikverket_stops.txt) (rikshållplats → signature, 1,038 rows, upper-case signatures).
2. **geo_name** — the spec's method: nearest Trafikverket station ≤ 300 m with a similar accent-insensitive name ("Centralstation" ≈ "C").
3. **timetable** — for trains matched by number on a date, the Trafikverket location whose advertised time equals the GTFS stop time. Trusted only with ≥ 3 votes, ≥ 60% share and ≤ 2 km. Coincidental votes happen: Östervik got "Cst" from 2 votes.
4. **geo_only** (fallback) — nearest Trafikverket location ≤ 100 m whatever its name. This catches Danish stations (Trafikverket uses Swedish names: "Köpenhamn H") and `x`-prefixed halts (Lennakatten, Roslagsbanan).

| Result | Stations | Share |
|---|---|---|
| Mapped (any method, incl. overrides) | **689 / 735** | **93.7%** |
| …weighted by stop visits | | **99.83%** |
| via timetable evidence | 553 | 75.2% |
| via official file | 581 | 79.0% |
| via geo+name ≤ 300 m | 621 | 84.5% |
| via hand-checked override | 4 | `data/station_overrides.json` |
| All available methods agree | 686 | 93.3% |
| Conflicts | 3 | Stockholm City (geo picked Cst), Ramlösa (Hbgb vs Ram), Nyköping C (Nk vs Nkc). The timetable choice is right in all three |

**Unmatched (46), none left for review:**
- **20 foreign, not in Trafikverket:** Norwegian stations (Fredrikstad, Rygge, Meråker…) and Austrian ones (Snälltåget to Salzburg).
- **26 bus stops inside "rail" trips:**
  - Ski buses: Funäsdalen, Ramundberget, Vemdalsskalet, Lindvallen…
  - Replacement/connecting-bus stops: Tingsryd terminal, Linnedal Kil, Cityterminalen, Kungsplan, Centrum väst, Nyckelbyvägen.
  - These identify buses (see §5).
- **The 8 review cases are resolved** in [`data/station_overrides.json`](data/station_overrides.json). Østerport → `Dk.kk`: Trafikverket's coordinate is ~1 km off, so only the name matches. Moga → `xMg`, Zell am See → `At.zel`, Dresden → `De.dh`, and the four stops above are marked bus stops.

**Historical stations (`q3-historical.mjs`, `q3-riks-stability.mjs`).** Sverige 2 `stop_id`s are rikshållplats ids (7 digits until 2016, `74xxxxx` → `7400xxxxx`):

| Snapshot | Rail stops | Mapped to a Trafikverket signature | Stop events mapped |
|---|---|---|---|
| 2012-08-31 | 619 | 96.9% | 98.30% |
| 2016-06-01 | 654 | 96.5% | 99.63% |
| 2019-06-03 | 671 | 97.5% | 99.82% |
| 2026-10-18 | 714 | 96.9% | 99.92% |

- **Unmapped:** foreign stations, plus stations since closed or moved (old Båstad, old Kiruna C, Norberg, Högfors), which Trafikverket no longer lists.
- **That's acceptable:** historical legs never get actual times, so they only need a stable station identity and coordinates.
- **The rikshållplats id is stable.** Where a 2012 id still exists in 2026, 99% have a similar name and lie within 500 m. ~10% of 2012 rail-stop ids no longer exist (closures, and Danish/Norwegian ids renumbered).
- **Consequence:** the `stations` table is **keyed by rikshållplats id**, and must accept history-only stations created from the snapshot's own `stops.txt`.

**Recommendation for the import:** use official + timetable + geo, plus the hand-maintained overrides. Flag new unmatched stations on each import (spec §8.4). The 300 m radius is tight for big stations: Stockholm C's parent stop is 218 m from Trafikverket's point. Keep ≤ 300 m with a name match, and ≤ 100 m without.

## 4. GTFS Sverige 2 (history)

Script: `q4-sverige2-inspect.mjs`.

- **Archive:** `https://data.samtrafiken.se/trafiklab/gtfs-sverige-2/YYYY/MM/` is a plain directory listing, **no key, no quota**. It holds roughly one snapshot per weekday from **2012-08** to **yesterday** (the newest feed is only on the keyed API).
- **File names:** `trafiklab-YYYYMMDD.zip` (2012–2016) and `sweden-YYYYMMDD.zip` (later). There's a matching `trafiklab-extra-YYYYMMDD.zip` (≈2–3 MB, contains a nested `extra.zip`). 2012–2016 zips keep files under a `samtrafiken-gtfs-sverige-…/gtfs-sweden/` folder.
- **Size:** 33 MB (2012) → 54 MB (2016) → 58–63 MB (2019) → 44–62 MB (2026) per snapshot.
- **Window per snapshot** (service dates covered):

| Snapshot | Window | Rail trips | Train number field |
|---|---|---|---|
| 2012-08-31 | 2012-08-10 … 2012-12-08 (~4 months) | 6,485 (route_type 2) | `trip_short_name` (99%) |
| 2016-06-01 | 2016-05-30 … 2016-08-21 (~3 months) | 11,916 (route_type 2) | `trip_short_name` (100%) |
| 2019-06-03 | 2019-05-30 … 2019-08-18 (~2.5 months) | 15,271 (101/102/106) | `trip_short_name` (65%) + extra |
| 2026-10-18 | 2026-10-15 … 2027-10-15 (1 year) | 31,510 (101/102/106) | **`extra.zip/trips_technical.txt`** (100%); `trip_short_name` empty |

- **It truly goes back to 2012:** SJ 523 is found in 2012 (Stockholm C 07:14 → Malmö C 11:50), 2016 and 2019 (then extended to København H). Older snapshots use basic `route_type 2` for all rail and one route per product ("SJ X2000"). Newer ones use extended types and one route per train.
- **No `shapes.txt`** in any Sverige 2 snapshot, so geometry is always OSM-routed.
- Stop IDs changed from 7 to 9 digits in 2016 (`74xxxxx` → `7400xxxxx`) per Trafiklab docs. Station matching for history goes through the rikshållplats ID, which `trafikverket_stops.txt` also covers.
- **The key works.** One test call to `api.resrobot.se/gtfs/sweden.zip` returned the 2026-10-20 feed (62.5 MB). Bronze is 1 call/minute, 50/month.
- **On-demand rule:** for a past date D outside GTFS Sweden 3, download the latest archive snapshot dated ≤ D (≈ 50 MB), cache it, and parse only rail trips active on D. Most windows are ≥ 2.5 months, so one snapshot serves many nearby dates.

**Archive completeness (`q4-archive-survey.mjs`):**
- **2,858 snapshots from 2012-08-31 to 2026-10-18.** Per year: 21 (2012), 78–134 (2013–2017), 220–350 (2018 onward).
- **Largest gaps between snapshots:** 123 days (2016-12-30 → 2017-05-02), then 23 days (May 2023). All others are ≤ 17 days.
- **Windows per snapshot:** one snapshot per year was sampled, plus those before the largest gaps. They cover 62–315 days, starting 1–21 days *before* the snapshot date. The 2016-12-30 snapshot runs to 2017-06-11, which bridges the 123-day gap.
- **So every date from 2012-08-10 to today is covered** by "latest snapshot ≤ D". Nothing before 2012-08-10 exists.
- **2019 train numbers:** `trip_short_name` is filled on 65%; adding `trips_technical.txt` from the extra zip brings it to **86.8%**. The only gap is **2019 SL Pendeltåg**, which had no train numbers, so historical commuter legs are found by route, not number.

## 5. Rail filtering and categories

Scripts: `q5-categories.mjs` (inventory), `q5-classify.mjs` (runs the rules). Rules: [`data/category_overrides.json`](data/category_overrides.json).

- **GTFS Sweden 3 route_types in use:**
  - 100 (generic railway), 101 (high speed), 103 (inter-regional), 105 (sleeper), 106 (regional)
  - 900 (tram), 401 (metro), 700 (bus), 1000 (water), 1501 (taxi)
- **Rail = 100–199**, plus SL's narrow-gauge lines filed as **900**: Saltsjöbanan 25/26 and Roslagsbanan 27/27S/28/28S/29.
- **What each type contains:**
  - **101:** SJ Snabbtåg, MTRX/VR Snabbtåg, Vy Oslo–Göteborg, and *Arlanda Express*.
  - **103:** SJ InterCity.
  - **105:** SJ and Snälltåget night trains.
  - **106:** all regional and commuter: SL Pendeltåg, Pågatåg, Västtågen, Mälartåg, Krösatåg, Norrtåg, X-Tåget, Öresundståg (short trips), Östgötapendeln.
  - **100:** a mix: SJ, Snälltåget, Öresundståg via VR Sverige, Tågkompaniet, Krösatåg KLT, SJ Norge, Tågab, Lennakatten, TJF.
- **Trafikverket `TypeOfTraffic`** is the cleanest signal when available: `Tåg` (42.8k rows/day), `Pendeltåg` (24.8k: SL Pendeltåg and commuter Västtågen) and `Buss` (1.1k).
- **Buses inside rail route_types must be excluded.** Patterns found:
  - SJ `6xxxx` replacement buses via Cityterminalen and Nils Ericson Terminalen.
  - Snälltåget ski buses (prefixed numbers `2/3/4xxxx`, `13908`) and replacement buses (`90306` via Tingsryd).
  - MTRX `2032` via Nyckelbyvägen.
  - A Värmlandstrafik on-demand **taxi** ("Anrop") filed as route_type 100.
- **Detection rules:** Trafikverket `TypeOfTraffic = Buss` inside its window, otherwise "the trip calls at a stop with no railway station within 1 km" (from the station mapping).
- **Heritage:** Lennakatten and TJF Smalspåret (GTFS), and Järnvägsmuseet "Rälsbuss" (Trafikverket only). Inlandsbanan appears in Sverige 2 but not in Sweden 3 this week.
- **The rules file runs cleanly.** `q5-classify.mjs` gives every rail trip on 2026-10-20 a category, with 0 unclassified:

  | Category | Operators |
  |---|---|
  | intercity | SJ Snabbtåg/InterCity/Nattåg, MTRX, Snälltåget, Vy |
  | regional | Mälartåg, Krösatåg, Norrtåg, Öresundståg, TiB, X-Tåget, Värmland, Arlanda Express, SJ Regional |
  | commuter | SL Pendeltåg, Roslagsbanan, Saltsjöbanan, Pågatåg, Östgötapendeln, and 300 of 620 Västtågen |
  | excluded | 14 SJ, 25 Värmlandstrafik and 4 Snälltåget buses, plus 8 taxi trips |

- **Live vs historical classification** (the same trips classified without Trafikverket facts) differs on only 39 trips. All 39 are replacement buses calling at real stations, which only Trafikverket can identify. For historical legs those would be kept as trains, roughly 1% of trips.

## 6. Shapes / geometry

Scripts: `q6-shape-stats.mjs`, `osm_rail_extract.py`, `q6-osm-route.mjs`, `plot_route_sample.py`.

**GTFS Sweden 3 shapes are not usable as track geometry for most trains.** For 25,531 rail shapes:
- Västtågen, Pågatåg, SL Pendeltåg, Mälartåg, Arlanda Express, Norrtåg, Snälltåget, MTRX, Krösatåg, Öresundståg (106) and most SJ have **no more points than stops** (0.0–0.3 points/km, median gaps 8–350 km). They are straight lines between stations.
- Detailed shapes exist only for VR Sverige (Öresundståg, 11 pts/km), Roslagsbanan (55), Saltsjöbanan (64), Tågkompaniet (22) and a few SJ. Where present they're **track-accurate** (see the OSM comparison below).
- Some shapes contain bogus far-away points (gaps up to ~5,900 km), so validate before using any.

**OSM routing works.** Extracts from `download.openstreetmap.fr` dated 2026-10-19: Sweden 1.0 GB, Denmark 0.55 GB, Norway 1.4 GB. Keeping `railway=rail|light_rail|narrow_gauge` across all three gives 47,984 ways and 552k nodes, 25 MB as JSON. It took ~15 min to build with pyosmium.

Lessons from tuning the router (`q6-osm-route.mjs`):
- **Keep service track** (`service=yard|siding|spur`) in the graph with a 5× cost penalty. Dropping it disconnects Borlänge–Falun and Hallsberg–Kumla inside stations.
- **Snap each station to every running-line node within 400 m**, and run one multi-source/multi-target Dijkstra with the snap distance added to the cost. Snapping to only the nearest node sometimes picked a parallel or freight line and produced detours.
- **Fix bad station coordinates first.** GTFS puts Notviken (Luleå) 54 km away, and Rottneros, Såneby, Sunne and Bäckebron 0.6–1.5 km off. When GTFS and Trafikverket disagree by > 300 m, use whichever point is closer to the track. That applied to 6 stations; the import should do the same and log it.

**Result for all 867 station pairs used on 2026-10-20:**

| Outcome | Pairs | Notes |
|---|---|---|
| Routed cleanly | **859 (99.1%)** | track length median 1.01×, p95 1.26× the straight line |
| Long but correct | 4 | Oleby–Torsby (the line loops north before entering Torsby), Sundsvall C–Timrå and Timrå–Sundsvalls västra (round the bay via the western triangle), Boden–Kalix (via Morjärv). Checked against the OSM plot |
| Station not near track | 4 | Köbenhavn Syd–Berlin (Germany not loaded) and Snälltåget's Tingsryd bus stops (correctly not rail) |
| No path | 0 | Halden–Ed and the Copenhagen/Oslo segments work with DK+NO data |

- **Example: SJ 423 Stockholm C → Göteborg C routes 451.9 km** (real line ≈ 455 km). Straight stop-to-stop GTFS geometry gives 397.5 km, which would understate distance and CO₂ by ~12%. SJ 523 → Malmö: 592.5 km routed vs 533.3 km straight. See `docs/phase0/route_sample.png`.
- **The detailed GTFS shapes are track-accurate** once Denmark and Norway are loaded: median 6–12 m from OSM track for every operator that has them, p95 18–93 m.
- **Decision:** OSM routing is the primary geometry (spec §12 step 2), cached per station pair in `track_segments`. Use GTFS shapes only when detailed (≥ 50 points and validated against OSM). Fall back to straight lines with `is_estimated_geometry`.
- **Germany/Austria:** only Snälltåget's few Berlin/Salzburg night trains need them. The mirror offers only a full Germany file (~4.5 GB) and Austria (0.97 GB). Same method; add them when those trains matter.
- **Environment note:** `download.geofabrik.de` connections were reset from this cloud environment. `download.openstreetmap.fr` worked.

## 7. Quotas and caching

| Source | Documented limit | Used in Phase 0 | Notes |
|---|---|---|---|
| GTFS Sweden 3 static (`opendata.samtrafiken.se`) | Bronze 10/min, **50/month** (Silver 250). `sweden_extra.zip` counts against the same quota | **1** | The owner says this key allows 60; the guard assumes 50 (decided). Updated daily ~05:00–06:00 (the 2026-10-20 file was `Last-Modified 03:24 UTC`) |
| GTFS Sverige 2 API (`api.resrobot.se`) | Bronze **1/min, 50/month** | **1** | Only needed for the newest feed. The archive is keyless |
| GTFS Sverige 2 archive (`data.samtrafiken.se`) | none | ~25 files + 180 listings | Plain HTTP directory listing |
| Trafiklab extras (`api.trafiklab.se/.../extra/*.txt`) | none (keyless) | 2 | `trafikverket_stops.txt`, `agency_stops.txt` |
| Trafikverket Open API | no hard quota; fair use (Trafiklab support: only sustained abuse, e.g. tens of req/s, gets keys disabled) | ~70 queries | A full day of announcements is ~100k rows, fine in 5 queries |

**Caching works:**
- `scripts/phase0/download.mjs` refuses to re-download a dataset fetched < 20 h ago without `--force`. This was verified: a second `se3` call printed "Cached copy is 0.0h old … Not downloading".
- It logs every call, including failures (they still count), to `data/cache/downloads.log` with timestamp, status and bytes.
- It counts calls per month per quota group.
- It streams to disk. That was verified byte-identical on a keyless archive file, using ~22 MB of memory. The 804 MB first download in this session was buffered in memory before this fix.

---

## Other things worth knowing

- **Node + proxy:** Node's `fetch` ignores `HTTPS_PROXY`. Run scripts with `NODE_USE_ENV_PROXY=1` when behind a proxy, as in this cloud environment.
- **Copenhagen / Oslo:** Öresundståg runs into Denmark on most trips. `TrainStation` lists Danish locations (`Dk.kh` …), but **`TrainAnnouncement` has no rows at Danish stops at all**; they appear only as `ToLocation`. On 2026-10-19 there were just 11 Norwegian rows, none with an actual time. So a leg ending in Copenhagen or Oslo gets no actual arrival from Trafikverket; it needs Rejseplanen (Phase 2) or Norwegian data. Routing is fine: the Denmark and Norway extracts are included.
- **DST:** GTFS times are local service-day times (can exceed 24:00); Trafikverket times carry an offset. Convert both to UTC with the station's tz (`Europe/Stockholm` for all Swedish stations).
- **Sizes for the import:** rail-only extract of GTFS Sweden 3 = 34,796 trips, 400k stop_times, 735 stations (~90 MB of JSON). Parsing the full zip by streaming takes ~2.5 min.

## Decisions (owner, 2026-10-20)

The owner chose brand display and delegated the rest to Claude's judgement:

1. **Brand over operating company** (owner). Show "Öresundståg", "Pågatåg", "SJ Snabbtåg". The company (VR Sverige, Arriva, SJ AB) is stored but secondary. Recorded in `data/category_overrides.json` → `display`.
2. **Background snapshot job: yes.** The server runs a small scheduled job (node-cron, a few times a day) that fetches Trafikverket actuals for every `planned` leg whose scheduled arrival has passed, while still inside the ~4-day window. Opening the app also triggers it. This changes spec §10, which said Phase 1 has no background tracking; without it, delay data is lost for any trip not opened within ~3 days.
3. **History from the keyless Sverige 2 archive: yes.** `data.samtrafiken.se/trafiklab/gtfs-sverige-2/` is the primary source for dates before GTFS Sweden 3's window. The keyed endpoint is used only when the newest snapshot is needed.
4. **Categories:**
   - **Pågatåg = commuter** (as spec §11 says).
   - **Östgötapendeln = commuter.**
   - **Arlanda Express = regional**, so the commuter toggle doesn't hide airport trips.
   - **Västtågen** is commuter only for the Göteborg commuter lines. That's detected by "every stop is in the commuter station set", which reproduced Trafikverket's Pendeltåg label exactly on a held-out day (303/303, 0 false positives) and works for historical legs.
5. **GTFS Sweden 3 quota: plan for 50 calls/month** (the documented Bronze limit), even though the key may allow 60. Normal use is ~31/month (one per day).
