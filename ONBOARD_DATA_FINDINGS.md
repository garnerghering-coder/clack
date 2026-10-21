# Feature D spike: on-board amenities

Run on **2026-10-21** against live Trafikverket data, the GTFS files already on disk (`data/cache/gtfs_se3`, fetched 2026-10-20; `data/cache/gtfs_sv2`), Trafiklab's docs and operator websites. Scratch scripts and raw outputs are not committed. The questions come from ADDITIONS_01.md, Feature D.

## TL;DR

| Question | Answer |
|---|---|
| Does an open feed carry amenities per train? | **Catering only.** Trafikverket `TrainAnnouncement.Service` holds `Bistro` / `Servering` / `Kiosk` / `Krog` per train number. It is planned data, it was the same on 3 dates, and `Deviation` "Ej servering" marks the days it is cancelled. Nothing in any feed covers Wi-Fi, power, quiet car, bikes or step-free access. |
| GTFS `bikes_allowed` / `wheelchair_accessible`? | **Missing.** Neither GTFS Sweden 3 nor GTFS Sverige 2 has these columns (0 of 32,915 / 34,203 rail trips). `stops.txt` has no `wheelchair_boarding` either. Nothing is usable as-is. |
| Operator info | Prose web pages only, with no JSON and no open licence. Öresundståg, Arlanda Express and Norrtåg pages could be read and checked today. SJ and SL pages need JavaScript to show any content, Tågab's robots.txt disallows everything, Snälltåget blocks scripted requests (403), and Mälartåg, Krösatåg and X-tåget were unreachable. |
| Which unit/type runs a departure? | **No feed names the vehicle** (`NewEquipment` = 0 on all 33,374 rows). Two partial signals exist. (1) Trafikverket `TrainComposition` "Vagnsordning" gives the planned car count, so SJ Snabbtåg trains split cleanly into 6-car (X2000) and 4-car (SJ 3000) runs. (2) The Oxyfi API sends vehicle IDs for a few regional fleets, mapped by the operator and unverified. |
| **Recommendation** | **Outcome B**: per-type "Typically …" claims from a hand-maintained table with a verified date and source. **Plus one small per-train item (A-like)**: show the catering label from `Service`, removed when "Ej servering" appears. Do not show bike or wheelchair facts from GTFS, because there are none. |

---

## 1. Trafikverket `TrainAnnouncement` 1.9

Samples: all fields at Cst, G, Mc, U, Lp on 2026-10-21 06:00–22:00 (2,857 rows). Also one nationwide query of advertised departures for 2026-10-21 with only the text fields: **33,374 non-bus departure rows, 3,214 trains** (product + train number).

**`Service`** (codes SNA…) is the only structured amenity field. Number of trains per product nationwide on 2026-10-21:

| Product | Trains | With `Service` |
|---|---|---|
| SJ Snabbtåg | 118 | Bistro 117 |
| SJ InterCity | 63 | Servering 24, Bistro 7 |
| SJ Regional | 85 | Kiosk 15 |
| SJ Nattåg | 8 | Bistro 4, Kiosk 2 |
| Snälltåget | 7 | Krog 6, Kiosk 1 |
| Vy Snabbtåg | 15 | Kiosk 15 |
| TiB | 152 | Kiosk 97 |
| VTAB | 66 | Kiosk 32 |
| Krösatågen | 240 | Servering 23 |
| Tågab | 2 | Servering 2 |
| Västtågen 623, Pågatågen 488, Mälartåg 308, Öresundståg 203, Östgötapendel 117, Norrtåg 98, all SL Pendeltåg | | none |

- It is on **departure rows**: SJ Snabbtåg had it on 134 of 137 departure rows and 0 of 132 arrival rows. Snälltåget has it on both.
- It is **planned, per train number**. At Cst, the 70 long-distance trains present on 2026-10-17, 10-21 and 10-28 had the same `Service` value on all three dates.
- The `ReasonCode` catalogue (787 codes) defines `SNA001`–`SNA010`: Bistro, Ej servering, Kiosk, Restaurang, Servering, Krog, Sovvagn, Sov- o liggv., Liggvagn, Café. None of the sleeper or café codes appeared today. SJ Nattåg trains carry Bistro/Kiosk, not Sovvagn.
- **Missing `Service` does not mean there is no catering.** Norrtåg's own page says "Bistro med servering på längre sträckor", and 5 Norrtåg trains carried `Deviation` "Ej servering" today, yet no Norrtåg train has `Service`. VR Snabbtåg uses free text instead: `TrainComposition` "Café i vagn B" (76 rows, 16 of 18 VR trains at Cst/G).

**Amenity-related notices** (all from `Deviation`, nationwide 2026-10-21): `ANA083` "Ej servering" on 42 rows (Norrtåg 7103, 7108, 7109, 7182, 7183 and SJ 526), `ANA093` "Ej toalett" on 10 rows (Norrtåg 7441, 7444), and `ANA035` "Ändrad tågtyp" on 1 train (SJ IC 643, which does not say what the new type is). The catalogue also has `ANA079` "Ej cykel" and `BNA028` "1:a klass saknas", but they were not seen today.

**Everything else:** a keyword search (wifi, internet, tyst, cykel, rullstol, lift, hiss, familj, eluttag, sov, ligg, toalett …) over all distinct `OtherInformation` (114), `Booking` (7), `TrainComposition` (49) and `Deviation` (40) texts found nothing beyond the items above. `OtherInformation` is about stops, tickets and buses. `Booking` is about reservations ("Hela tåget är obokat."). `TrainComposition` is coach order plus "Långt tåg." and "Bakre delen går låst.".

**Other object types:** `TrainComposition`, `Vehicle`, `TrainConsist`, `TrainMessage` and `OperativeEvent` all return "ObjectType … does not exists." `TrainPosition` 1.1 has no vehicle field (DATA_FINDINGS §8). The data-model docs page (data.trafikverket.se) did not resolve from this environment.

## 2. Rolling-stock identity

- **Trafikverket:** there is no vehicle or unit field, and `NewEquipment` was 0 on all 33,374 rows. However, `TrainComposition` "Vagnsordning …" (planned coach order) is present for 117 of 130 SJ Snabbtåg trains, 45 of 63 SJ InterCity, 51 of 87 SJ Regional, and all VR, SJ Nattåg and Snälltåget trains. The car count identifies the type:
  - **SJ Snabbtåg:** 68 trains run as 6 cars ("1-3-4-5-6-7"), which is X2000 on Cst–G, Cst–Mc and Lp–Mc. 48 trains run as 4 cars ("1-2-3-4"), which is SJ 3000/X55 to Sundsvall, Umeå, Oslo and on G–Mc. 2 trains run as 6+6. **The current rule `sj + high_speed → x2000` is wrong for about 41% of SJ Snabbtåg trains.**
  - **SJ InterCity / Regional:** "Lok-…" means a locomotive with coaches, and 2–3 numbered cars point to X40-type units.
  - This is the *planned* formation, so a substitution shows up only as "Ändrad tågtyp" with no detail.
- **GTFS Sweden 3 / Sverige 2:** no vehicle columns. SE3 `trips.txt` has `route_id, service_id, trip_id, trip_headsign, trip_short_name, direction_id, shape_id, samtrafiken_internal_trip_number`. `attributions.txt` (427,612 rows) gives only `organization_name` and `is_operator` per trip. Trafiklab's own notes say vehicle type is "defined on a route-level" and "might be incorrect" for single trips.
- **GTFS-RT VehiclePositions (GTFS Sweden 3 realtime):** available only for regional operators (SL, UL, Östgötatrafiken, JLT, Kronoberg, KLT, Skåne, Värmland, Örebro, Västmanland, Dalatrafik, X-trafik, Din Tur …). It is **not** available for SJ, Västtrafik, Mälartåg, Snälltåget, VR, Vy or Tågab. Our `TRAFIKLAB_GTFS_SWEDEN3_KEY` gets 403 "Key does not have access to file", because realtime is a separate API with its own key and a Bronze quota of 30,000 calls/month. I did not check whether `vehicle.id` or `label` holds a real unit number.
- **Oxyfi Trainpos (Trafiklab):** a websocket feed of NMEA positions tagged with **vehicleId** (the number painted on the unit) and the train numbers it is serving. The list on the docs page (dated 2021-09-24) covers only Värmlandstrafik, Norrtåg (including X62 62001–62012), TiB, Blekingetrafiken and KLT. The page says the vehicle-to-train mapping comes from the operator and is "not verified to conform to reality". It needs its own key, allows one connection per key, and states no licence. I did not test it.
- **SJ app/booking:** shows the train type per departure on sj.se. I did not scrape it, since it is a client-rendered private API with no reuse terms.
- **Community sites** (järnväg.net forum, fleet lists): fleet facts only. No per-departure source with a licence turned up.

**Conclusion:** per-train facts are not possible in general. The type can be *inferred* per departure for SJ (from car count) and known per unit for a handful of Oxyfi fleets. Everything else stays at the per-type level.

## 3. GTFS amenity fields

| Feed | Rail trips (route_type 2, 100–117) | `bikes_allowed` | `wheelchair_accessible` | Other |
|---|---|---|---|---|
| GTFS Sweden 3 (2026-10-20) | 32,915 | column absent | column absent | `stops.txt` has no `wheelchair_boarding`; `booking_rules.txt` is for demand-responsive buses |
| GTFS Sverige 2 | 34,203 | column absent | column absent | `trips.txt` has only 5 columns |

ADDITIONS_01 assumed these fields were "likely present". They are not, so there is nothing free and factual to show.

## 4. Operator pages (checked 2026-10-21)

| Operator | Reachable / format | Notes |
|---|---|---|
| Öresundståg | Yes, server-rendered prose | [Våra tåg](https://www.oresundstag.se/om-oresundstag/vara-tag), [Ombord](https://www.oresundstag.se/reseinfo/ombord), [Tillgänglighet](https://www.oresundstag.se/reseinfo/tillganglighet). No reuse terms on "Om webbplatsen". |
| Arlanda Express | Yes, prose; robots.txt allows all | [Upplevelse ombord](https://www.arlandaexpress.se/vara-tjanster/upplevelse-ombord), [Tillgänglighet](https://www.arlandaexpress.se/hjalp-och-support/tillganglighet) |
| Norrtåg | Yes, prose with per-type lists | [Tillgänglighet](https://norrtag.se/allt-om-resan/tillgangligheten/) lists X62, X11 and X52 Regina separately. **Norrtåg runs 3 types**, but our rule maps everything to x62. |
| Västtrafik (Västtågen) | Yes, prose | [Cykel](https://www.vasttrafik.se/resa-med-oss/under-resan/cykel/): bikes are allowed and free on Västtåg in the car with the bike symbol, with no per-type detail |
| Vy | Yes, prose FAQ | Wi-Fi and food answers are inside a collapsed FAQ. Not extracted. |
| SJ | robots.txt allows; pages render only with JS | `/allt-om-resan/vara-tag`, `/nya-x-2000`, `/mat-pa-taget/*`, `/reseklasser/2-klass-lugn` exist in the sitemap but return an empty app shell. **Nothing could be verified without a browser.** |
| SL | JS-only | Not verified |
| Tågab | robots.txt `Disallow: /` | Not read |
| Snälltåget | 403 to scripted requests | Not read |
| Mälartåg | Redirects to `www.malardalstrafik.se`, which did not resolve | Not verified (search snippets mention Wi-Fi, power and 6 bikes on ER1, but I did not count that as verified) |
| Krösatåg, X-tåget | Proxy 502 | Not verified |

None of these pages is structured data and none has an open licence. Facts such as "has Wi-Fi" can be restated in our own words with a link to the source. We should not copy their text or images, and we should not scrape: a person checks and dates each claim by hand.

## 5. Licences

| Source | Licence | Checked |
|---|---|---|
| Trafikverket Open API | CC0, per SPEC and third-party sources (OSM wiki: Trafikverket moved to CC0 on 2017-04-03) | data.trafikverket.se was unreachable here. Confirm once in a browser. |
| GTFS Sweden 3 / GTFS Regional (incl. realtime) | **CC0 1.0** | Trafiklab pages, 2026-10-21 |
| GTFS Sverige 2 | CC0 (Trafiklab, per SPEC) | not rechecked |
| Oxyfi Trainpos | not stated; key per subscriber | Trafiklab page, 2026-10-21 |
| Operator web pages | no open licence; normal copyright | facts only, own words, cite URL |

## 6. Decision table

| Source | Gives | Per-train or per-type | Quality | Licence |
|---|---|---|---|---|
| TRV `Service` | Bistro/Servering/Kiosk/Krog | **per train number** (planned) | Good for SJ, Snälltåget, Vy, TiB, VTAB. Missing for Norrtåg and VR. | CC0 |
| TRV `Deviation` ANA083/093/079 | "Ej servering", "Ej toalett", "Ej cykel" today | per train, per day | Rare (52 rows nationwide), but real | CC0 |
| TRV `TrainComposition` | coach order, "Café i vagn B" | per train (planned) | Car count is a good type hint for SJ | CC0 |
| GTFS SE3 / SV2 | nothing (no bike or wheelchair columns) | – | – | CC0 |
| GTFS-RT VehiclePositions | vehicle id (not verified) | per vehicle, regional only | Not available with our key | CC0 |
| Oxyfi Trainpos | vehicleId ↔ train number | per unit, 5 regional fleets | Operator-reported, unverified | unstated |
| Operator pages | Wi-Fi, power, quiet car, bikes, wheelchair | per type (sometimes per operator+type) | Prose, needs manual upkeep | copyright, facts only |

## 7. Recommendation: outcome B, with catering per train

1. **Per-type table (B).** Extend `data/train_types.json` with operator-specific amenity claims (see below). The app shows them as "Typically: Wi-Fi, power at seats", with the verified date and a source link on tap, and never as a promise.
2. **Catering per departure (the A part).** Add `Service`, `Deviation` and `TrainComposition` to the INCLUDE lists in `boards/board.ts` and `legs/actuals.ts`. Show "Bistro" (or "Café", from "Café i vagn B") as a fact for that departure. Remove it when `Deviation` "Ej servering" appears. Show "No toilet" when "Ej toalett" appears. When `Service` is absent, show the typical claim (if any) or nothing. Never show "no catering".
3. **Bikes and wheelchair:** there is no GTFS data. Only per-type operator claims are possible, and `Deviation` "Ej cykel" is honoured when it appears.
4. **Side fix for `trainTypes.ts`** (not D, but found here): use the `TrainComposition` car count to choose between x2000 (6 cars) and x55 (4 cars) for SJ Snabbtåg. Norrtåg needs number- or line-based rules for X62, X11 and X52.

Amenities depend on **operator + type**, not type alone (for example, a Regina at Norrtåg differs from one at Västtågen). So claims hang off an `amenities` list keyed like `rules`, not off `types`.

### Proposed schema (additive; existing `types` and `rules` are unchanged)

```jsonc
"amenities": [
  { "match": { "operator": "oresundstag", "type": "x31" },
    "claims": {
      "<key>": { "value": true | false | "text", "note": "short own-words detail", "source": "https://…", "verified": "YYYY-MM-DD" }
    } }
]
```

The claim keys are a fixed set: `wifi`, `power`, `catering`, `quiet_car`, `first_class`, `pets_area`, `bikes`, `wheelchair_space`, `step_free`, `accessible_toilet`, `sleeper`. A missing key means unknown. `false` is allowed only when the operator says so. Claims older than 12 months are hidden until someone re-verifies them.

### Example entries (only facts read on the operator page on 2026-10-21)

```json
{ "match": { "operator": "oresundstag", "type": "x31" }, "claims": {
  "wifi":              { "value": true, "note": "On all 111 trains", "source": "https://www.oresundstag.se/reseinfo/ombord", "verified": "2026-10-21" },
  "power":             { "value": true, "note": "220 V AC outlet at every seat group", "source": "https://www.oresundstag.se/om-oresundstag/vara-tag", "verified": "2026-10-21" },
  "quiet_car":         { "value": true, "note": "Car 14 (24, 34)", "source": "https://www.oresundstag.se/reseinfo/ombord", "verified": "2026-10-21" },
  "first_class":       { "value": true, "note": "Car 11 (21, 31)", "source": "https://www.oresundstag.se/reseinfo/ombord", "verified": "2026-10-21" },
  "pets_area":         { "value": true, "note": "Car 13 (23, 33)", "source": "https://www.oresundstag.se/reseinfo/ombord", "verified": "2026-10-21" },
  "bikes":             { "value": true, "note": "Up to 6, space permitting; from 1 Nov 2026 no boarding with a bike in Skåne on weekdays 06:00–08:00 and 15:30–17:30", "source": "https://www.oresundstag.se/reseinfo/ombord", "verified": "2026-10-21" },
  "step_free":         { "value": "partial", "note": "Lower entry in the middle car; staff ramp on request", "source": "https://www.oresundstag.se/reseinfo/tillganglighet", "verified": "2026-10-21" },
  "accessible_toilet": { "value": true, "note": "Middle car", "source": "https://www.oresundstag.se/reseinfo/tillganglighet", "verified": "2026-10-21" } } },
{ "match": { "operator": "arlanda-express", "type": "x3" }, "claims": {
  "wifi":              { "value": true, "note": "Free", "source": "https://www.arlandaexpress.se/vara-tjanster/upplevelse-ombord", "verified": "2026-10-21" },
  "power":             { "value": true, "source": "https://www.arlandaexpress.se/vara-tjanster/upplevelse-ombord", "verified": "2026-10-21" },
  "step_free":         { "value": true, "note": "No step between platform and train; ramp on request", "source": "https://www.arlandaexpress.se/hjalp-och-support/tillganglighet", "verified": "2026-10-21" },
  "wheelchair_space":  { "value": true, "note": "In one of the middle cars", "source": "https://www.arlandaexpress.se/hjalp-och-support/tillganglighet", "verified": "2026-10-21" },
  "accessible_toilet": { "value": true, "source": "https://www.arlandaexpress.se/hjalp-och-support/tillganglighet", "verified": "2026-10-21" } } },
{ "match": { "operator": "norrtag", "type": "x62" }, "claims": {
  "wifi":              { "value": true, "note": "Free", "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" },
  "power":             { "value": true, "note": "At every seat", "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" },
  "catering":          { "value": "Bistro", "note": "On longer routes", "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" },
  "step_free":         { "value": true, "note": "Entry level with the platform", "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" },
  "wheelchair_space":  { "value": true, "note": "3 places", "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" },
  "accessible_toilet": { "value": true, "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" } } },
{ "match": { "operator": "norrtag", "type": "regina" }, "claims": {
  "wifi":              { "value": true, "note": "Free", "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" },
  "power":             { "value": true, "note": "At every seat", "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" },
  "catering":          { "value": "Bistro", "note": "On longer routes", "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" },
  "step_free":         { "value": "partial", "note": "One door at platform height with an internal wheelchair lift (yellow stripe)", "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" },
  "wheelchair_space":  { "value": true, "note": "2 places", "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" },
  "accessible_toilet": { "value": true, "source": "https://norrtag.se/allt-om-resan/tillgangligheten/", "verified": "2026-10-21" } } }
```

The Norrtåg Regina entry only matters once the rules can send a Norrtåg leg to `regina` (point 4). SJ entries (X2000 bistro, Wi-Fi and the "2 klass lugn" quiet section) must wait until someone checks sj.se in a browser, because nothing was verifiable by script today.

## 8. Open points

- Confirm the Trafikverket licence on data.trafikverket.se in a browser.
- Decide whether a realtime GTFS key and an Oxyfi key are worth requesting just to learn unit numbers for a few regional fleets. My view: not for D.
- Name drift: ADDITIONS_01 says `data/train-types.json`, but the real file is `data/train_types.json`.
