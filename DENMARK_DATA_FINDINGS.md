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
