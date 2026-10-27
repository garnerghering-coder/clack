# Denmark: data findings

Checked 2026-10-27, before adding Denmark's timetable. The Rejseplanen API key (real-time) had been applied for and
not yet granted. Some Rejseplanen Labs pages are behind Cloudflare, so facts marked *(snippet)* come from search
results and other developers' notes, not the pages themselves.

## TL;DR

| Capability | What exists | What Clack does |
| --- | --- | --- |
| Stations | Rejseplanen GTFS `stops.txt`. Rail stops carry their UIC number padded to 12 digits (`000008600626` = 8600626, København H), the same number Sweden's feed keys Danish stations by (`860000626`). | Matched by UIC id, else by name and position (`matchStation`), else a new station (`86…` id, or `uic:<number>` abroad), country from the UIC prefix (86 DK, 80 DE, 54 CZ …). "St." is dropped from names. |
| Timetable | Open GTFS at `https://www.rejseplanen.info/labs/GTFS.zip`: 56 MB, no key, CC BY 4.0 *(snippet)*, refreshed **about every two weeks** (Last-Modified 2026-10-19 on 2026-10-27), not daily. | Imported daily when Last-Modified is newer (`import/gtfs-dk.ts`, source `gtfs_dk`). Past dates are kept, so Danish history builds up from 2026-10-27. |
| Real-time | Rejseplanen API 2.0 (`departureBoard`, `journeyDetail`: `rtTime`, cancellations), key needed, ~50,000 calls a month non-commercial *(snippet)*. SIRI-ET for DSB, S-tog and Lokaltog from the national access point (Dataudveksleren), free account (MitID or a Vejdirektoratet login). | Not yet. Danish stops are timetable-only. |
| GPS | API `journeyPos`: another developer got empty results with a Labs key (Oct 2026). | Not yet; to be tested with the key. |
| Platforms | API `rtTrack` (key). Planned `platform_code` in GTFS: the column exists, mostly empty. | Planned platforms kept where given. |
| Boards | API `departureBoard`/`arrivalBoard` (key), one station per call. | Not yet. |
| Disruptions | API `himSearch` (key), free Danish text, no cause codes; no SIRI-SX in Denmark. | Not yet. |
| Archive | No official per-train archive (Banedanmark publishes monthly punctuality only). train-archive.eu has daily files since 2026-09-28; licence not stated. | None; would start when real-time is recorded. |

## The timetable (Rejseplanen GTFS, 2026-10-27)
- **Rail routes:** route_type 2 and 109. In the file:
  - DSB: IC, ICL, RE, ECE, RJ;
  - DSB S-tog: A, B, Bx, C, E, F, H;
  - DSB Vores Tog: 030, 031, RX;
  - Lokaltog A/S: 110R … 960R;
  - Midttrafik: 92, 93;
  - NT: 75, 76;
  - Skånetrafiken: 802–806, route_desc "Öresundståg";
  - Snälltåget AB: 083.

  The Metro (Metroselskabet) and the light rail (Odense Letbane, Hovedstadens Letbane, route_type 0) are left out, as
  in Sweden (SPEC §11).
- **Train numbers:** `trip_short_name`, zero-padded to six digits for DSB, S-tog and Lokaltog ("000100", "611215",
  "250004"), and plain for Midttrafik, NT and Skånetrafiken. Stored without the padding. **Unverified:** whether the
  5–6-digit numbers (DSB's 70101, S-tog's 611215, Lokaltog's 250004) are what tickets and boards show; they are
  Rejseplanen's.
- **Not in the file:** route colours are empty, and there are no long route names.
- **Trains also in Sweden's or Norway's feed** (any stop with a UIC 74 or 76 number: Öresundståg into Sweden, SJ,
  Snälltåget) are left out. Sweden's feed has them in full, and Trafikverket's live times stop at the border.
  Öresundståg runs entirely within Denmark (Østerport–CPH Airport) are kept, under the Öresundståg brand through
  route_desc.
- **RegioJet's Copenhagen–Prague trains** are listed under the DSB agency but aren't DSB's: they get no brand.
- **First import:** 26,383 rail trips in the window, 25,460 kept, 923 left to Sweden's feed, 256,365 train-days,
  463 stations matched and 18 new, 21 trips without a number (Midttrafik's line 93), 11 s.

## Brands
Recorded in data/operators.json. Sources:
- **DSB** `#b01030`: the red of its app icon.
- **Vores Tog** `#383894`: its icon's navy `#181840`, brightened.
- **Lokaltog** `#0057cc`: its manifest theme colour `#00214d`, brightened.
- **NT and Midttrafik** `#8e8e93`: no usable source (NT's icon is black and cream; Midttrafik has none).

## Searching
"Köpenhamn", "Köpenhamn H", "Kastrup flygplats" and "Copenhagen Airport" were missing as station names (data/station_aliases.json),
so SJ tickets to "Köpenhamn H" never resolved; added 2026-10-27.

## Old timetables and the archive without approvals (2026-10-27)

**Old copies of Rejseplanen's GTFS (Mobility Database, mdb-1292).** The free account's token lists 125 copies, from 2016-07
to 2026-10-20 (every two weeks lately; gaps in 2017–18). `npm run import -- denmark-history` downloads each, newest first,
imports it with `importGtfsDenmark(… fillGaps)` (only dates no copy has covered yet, nothing deleted: the newest copy wins
for a date) and deletes the zip; `data/cache/rejseplanen/history.json` records what was done, so a rerun skips it. Copies
from 2016–2019 may be in another shape: a failure is noted there and the run goes on. CC BY 4.0. The token is
`MOBILITY_DB_REFRESH_TOKEN` in `.env`, exchanged for a one-hour access token (`POST /v1/tokens`).

**train-archive.eu.** Garner phoned them on 2026-10-27: Clack may use any of their data, with no limits (verbal; the
Danish source's licence field is empty). Token `TRAIN_ARCHIVE_TOKEN` in `.env`, sent as `X-Api-Key`. The file list is
`https://www.train-archive.eu/api/sources.json` (no token needed); 60-odd sources in Europe, among them Sweden
(se-trafikverket, se-sl), Norway (no-entur), Finland (fi-digitraffic), Germany (de-gtfsde), the Netherlands, Poland and
others, all from 2026-09-28/30. Not imported; listed for later. Denmark: `dk-rejseplanen`, finished days from 2026-09-30,
`https://data.train-archive.eu/daily/provider=dk-rejseplanen/service=TripUpdate/date=YYYY-MM-DD.csv.gz` (redirects to the
storage bucket). A day is ~104,000 rows (one per train and planned stop), ~3,400 trips, 1.3 MB gzipped. Columns:
scheduled and predicted times (local), arrival/departure delay in whole minutes, trip_status (scheduled/cancelled),
stop_status (skipped), delay_source (feed, or propagated from the previous stop: ~2% of rows). `trip_id` is Rejseplanen's
GTFS trip id, so the match to the timetable is exact (3,309 of 3,434 trips on 2026-10-26; the rest are trains the
timetable import leaves out: also in Sweden's feed, or not rail).
`npm run import -- denmark-archive [--from= --to=]` keeps each day raw (write-once, `data/observed/train_archive_dk/`) and
projects it into `observed_runs`/`observed_calls` (country `DK`). A time counts as actual only where delay_source is
feed. The platform is not in the file.

**Not done yet:** the app endpoint (mgate) client, Clack's own recorder, live Danish legs and boards, and searching
Danish observed runs from the app (country `DK` is not in `lib/countries.ts`, so the lookup code does not see it yet).

## Live data from Rejseplanen's app backend (2026-10-27)

No source open today without MitID gives Danish live data officially: the API 2.0 key is pending (months), and
Dataudveksleren's SIRI-ET needs MitID Erhverv or a foreign eID. Checked and not used: Transitous'
`gtfs.spline.de/siri/danmark` (buses only, Movia and Bornholm, 20 min old); train-archive.eu's 15-minute files
(20–35 min behind; fine for a fallback, not for live).

Garner chose the backend Rejseplanen's own app uses (HAFAS mgate, `https://mobilapps.rejseplanen.dk/bin/iphone.exe`, the AID in
hafas-client's `rejseplanen` profile). It is **not granted to us** and may be blocked or changed without notice.
`apps/server/src/rejseplanen/`. Tested 2026-10-27:
- `StationBoard` (København H, 0.6 s): planned and live times (`dTimeS`/`dTimeR`), live platform (`dPltfR`),
  cancellations, train numbers as in the GTFS. One answer holds about 100 trains.
- `JourneyGeoPos` (all of Denmark, products 31, ~1.2 s): ~250 trains (S-Tog, Re, RA, RX, IC, ICL, Lokalbane,
  Pågatog, Snälltåget, ECE, RJ, Togbus). Positions are **calculated by Rejseplanen** from delays (`proc`, `ani`), not
  GPS: Clack draws them as estimated. S-tog runs carry no number here, only the line letter.
- `JourneyDetails` (0.2 s): every stop, planned and live, `PROGNOSED` (from the train) or `CALCULATED` (carried
  forward). Clack counts a past PROGNOSED time as actual; the archive confirms the day the next morning.
- The journey id carries the first and last stop and their times (`1S#8600803#1T#1705#LS#8600677#LT#1814`):
  Clack matches journeys to `gtfs_dk` on those (188 of 249 trains on 2026-10-27; most of the rest are Sweden's
  feed's trains, drawn once with Trafikverket's).

Limits Clack keeps to: 30 requests a minute shared by everything, skip rather than queue, rest 10 minutes after 5
failures, map polled every 20 s only while someone looks, journey details kept 50 s. `REJSEPLANEN_LIVE=off` stops
it; `LIVE_MAP_DENMARK=off` keeps Danish trains off the map. Without it, Danish boards fall back to the timetable
(`live: false`). **Not done yet:** placing Danish trains on the map from the archive's delays while Rejseplanen is
down (they disappear instead), and moving to API 2.0 when the key comes.
