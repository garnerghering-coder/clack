# Finland — data findings (Digitraffic)

Checked 2026-10-24 before building Finland support. Digitraffic Rail (Fintraffic) needs no key. Every request sends
`Digitraffic-User: clack` (static, no personal data) and `Accept-Encoding: gzip`. The data is licensed CC BY 4.0, so
the Sources page and map attribution credit it as: `Source: Fintraffic / digitraffic.fi, license CC 4.0 BY`.

## TL;DR

| Question | Finding | What we do |
| --- | --- | --- |
| Access | REST base `https://rata.digitraffic.fi/api/v1/`, no key. The request header must be exactly `Accept-Encoding: gzip`. With `curl --compressed` (`gzip, deflate, br`) or a default client the API answers HTTP 406 / the body "Use of gzip compression is required with Accept-Encoding: gzip header". Node's `fetch` decompresses the gzip answer itself (checked: JSON and the zip both arrive intact). | `digitraffic/client.ts` sets that header, plus `Digitraffic-User`, on every call (and on the GTFS download). A 4xx is never retried. |
| Limits | 60 requests/min per client (30/min for the infra API), 5 MQTT connections/min. | The client keeps to 40 requests/min with a token bucket, retries 429/5xx with backoff (waits for `Retry-After` on 429), reports to `/api/health` as the feed `digitraffic`. |
| Licence | CC BY 4.0. Credit text: `Source: Fintraffic / digitraffic.fi, license CC 4.0 BY`. | Shown where Entur's and Trafiklab's credits are (app, privacy page: a later step). |
| Rail timetable | `trains/gtfs-passenger.zip`, 5 MB, rebuilt daily (our copy: feed_version 2026-10-24T01:46Z), valid 2026-10-17 to 2027-12-31. 554 routes, 13,884 trips, 422 parent stations (646,000 stop times). Files: agency, routes, trips, calendar, calendar_dates, shapes, stops, stop_times, translations, feed_info. | Import it once a day (download guard: at most one call per 20 h, 40 a month), source `gtfs_fi`, keys `fi:<trip_id>:<hash>`, window yesterday to +90 days, same never-delete-past-dates rule as Sweden and Norway. |
| What is in it | VR long-distance (route_type 102), VR commuter (109, 75 routes) and HSL commuter (109, 21 routes), plus heritage railways (agencies 3184, 3191, 3204, 3163 with 33 routes, all type MUS). Agencies: 10 = VR, 9995 = HSL. Commuter trains are included because Swedish and Norwegian commuter trains already are. | VR (10) → operator `vr-fi`, HSL (9995) → `hsl` (brands in `data/operators.json`). Heritage agencies have no brand: operator null, product `heritage`. Note most commuter lines (`…_HL_10`) belong to agency 10 (VR), not HSL. |
| Calendar | One service per trip (`service_id` = trip id). `calendar.txt` gives weekday patterns (13,884 services) and `calendar_dates.txt` has 4,759 removals (exception 2) and 203 additions (exception 1). Some trips, for example S 13, are one-day services. 10 trip ids end in `_replacement` (a different stop pattern on one day for the same train number). | Dates = weekly pattern inside the window, plus additions, minus removals. Replacement variants are kept as trains (same number, own key). In the import window no train number has two trips on the same date. |
| Train numbers | `trip_id` is `<train number>_<validity end date>` (`8192_20261212`, `401_20261212`). Long-distance `trip_short_name` is `IC 22`, `S 13`; commuter is `A (HL 8192)` where `A` is the line letter and 8192 the train number. Route ids are `<from>_<to>_<number or line>_<TYPE>_<agency>` (`TPE_HKI_22_IC_10`, `LPV_HKI_A_HL_10`). | Number from the trip id prefix (short name as fallback). The commuter line stays in `route_name` ("A Leppävaara - Helsinki"). The train type letters come from the route id. |
| Stations | `/metadata/stations`: 563 stations (`stationShortCode` HKI, `stationUICCode`, `stationName` such as "Helsinki asema", `countryCode` FI/SE/RU, coordinates, `passengerTraffic`); 215 have passenger traffic. GTFS parent `stop_id` is the short code (`JRI`), platforms are `JRI_0` with `parent_station`. All 422 parent stops are known short codes. | New Finnish stations get id `fi:<CODE>`, `stations.fi_id` = the code, `fi_uic` = the UIC code, tz Europe/Helsinki; "asema" is dropped from names. Names fall back to `stops.txt` if the metadata call fails. |
| Haparanda | `HPA` "Haaparanta pohjoinen" has `countryCode SE` and is Haparanda; `TOR` Tornio is Finnish. IC 401, 402, 407, 408 (Oulu to Haaparanta pohjoinen) run daily. Trafikverket only announces Swedish trains at Haparanda (`Hp`), not these, so there is no double reporting. | HPA reuses the existing station `740000372` "Haparanda" (matched by distance, 400 m), which keeps its name, country SE and Europe/Stockholm, and gets `fi_id = HPA`. Tornio is its own station `fi:TOR`. Finnish trains there are reported by Digitraffic, the Swedish side by Trafikverket. |
| Train types | `/metadata/train-types` gives each type's name and category only: Commuter = HL, HV, HLV; Long-distance = H, P, S, IC, IC2, HDM, HSM, AE, PYO, MV, MUS, V, PVS, PVV; Cargo = T, RJ; Locomotive = VET; Shunting = PAR, VEV, VLI, W, MUV, SAA, PAI; On-track machines = TYO; Test drive = LIV. | `finnishProduct()` in `import/gtfs-fi.ts`: Commuter → `commuter`; S → `high_speed`; IC, IC2 → `intercity`; PYO → `night`; MV, MUS, V → `heritage`; other long-distance → `regional`; non-passenger categories are left out; an unknown letter → `regional`, logged. |
| Import result (dry run) | On a copy of the database with the feed of 2026-10-24 and window 2026-10-23 to 2027-01-22: 5,913 trips, 108,223 trip-dates, 222,432 stop times, 420 stations (1 reused: Haparanda; 419 new), 0 left out, 0 without a train number. By product: commuter 3,263, high speed 1,130, intercity 1,367, regional 86, heritage 45, night 22. | A second run changes nothing. |

## Not verified

- What the type letters mean. The API gives only the category. S = Pendolino (high speed), PYO = night train and
  MV/MUS/V = heritage come from VR's public naming, not from the API; every other long-distance letter is mapped to
  regional only as a safe default, not as a claim about the train. The mapping and its source sit in one commented
  table in `import/gtfs-fi.ts`.
- MQTT: the broker address and any credentials were not tried; the plan uses REST polling.
- The infra API (rail line geometry): not used so far, its limit is lower (30/min).
- How far back `/trains/{date}/{number}` reaches (needed for actual times of past trips): not measured yet.
- Whether the replacement variants (`…_replacement`) mean the same train on a replaced route or stop pattern: we only
  know they are separate services on single dates with their own stop times.
- GTFS rows and live data are checked against each other only for IC 401/402/407/408; nothing else.
