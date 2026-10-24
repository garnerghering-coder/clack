# Cross-border trains: what each source covers

Checked 2026-10-22 against live data. A trip is only as accurate as the source that covers each of its stops, so
every stop of a saved trip records who reports it (`leg_stops.report_source`: `trafikverket`, `entur`, or none).

## Coverage

| Where | Reported live by | Timetable | Notes |
| --- | --- | --- | --- |
| Swedish stations | Trafikverket (actual times, delays, tracks, cancellations, GPS) | Trafiklab GTFS Sweden 3; Sverige 2 archive back to 2012 | Up to and including the border stations (Hyllie, Charlottenberg, Kornsjø side, Riksgränsen side). |
| Norwegian stations, Norwegian operators (Vy, Go-Ahead, SJ Nord, Flytoget) | Entur (Journey Planner actual times; GTFS-RT GPS and delays) | Entur rail GTFS | Vy's GPS keeps reporting in Sweden too (Oslo–Göteborg). |
| Norwegian stations, Swedish operators (SJ Stockholm–Oslo, Snälltåget, Vy Tåg Kiruna–Narvik) | **Nobody.** Entur has these trains but no live data (`realtime: false`), and Trafikverket stops at the border | Entur has Norway's published times | Norway's published time wins at Norwegian stations: SJ 645 is due at Oslo S at 00:14 (Entur), not SJ's own 00:02. |
| Tornio (Finland) – Haparanda (Sweden): IC 401, 402, 407, 408 Oulu–Haaparanta pohjoinen | Finnish stations: Digitraffic (`report_source` `digitraffic`), including the train's stop at Haparanda (`HPA`). Swedish trains at Haparanda: Trafikverket (`Hp`). Trafikverket does not announce the Finnish trains there, so nothing is reported twice | Digitraffic's passenger GTFS (`gtfs_fi`); Haparanda is the existing Swedish station `740000372` | Checked 2026-10-24 ([FINLAND_DATA_FINDINGS.md](FINLAND_DATA_FINDINGS.md)). Finland is one hour ahead (Europe/Helsinki): Haparanda keeps Europe/Stockholm, Tornio is Europe/Helsinki. |
| Danish stations (Öresundståg, SJ to Copenhagen, Snälltåget to Berlin) | **Nobody** (Trafikverket has no Danish announcements; Rejseplanen needs a key) | Sweden's GTFS has the Danish stops | |
| German stations (night trains to Berlin and Hamburg) | **Nobody** | Sweden's GTFS | |

## What the app does at the edges

- **Times:** a stop nobody reports shows its timetable time (Norway's published one in Norway). After the last
  reported stop, the trip and the live map show expected times shifted by the delay there, and say they're expected.
  An expected time never becomes an actual one.
- **Trip records:** a trip that ends (or starts) beyond live data is recorded from the report at the nearest covered
  stop (`border_reports`): a trip to København H counts when Hyllie reported the train leaving. A cancellation still
  asks. The trip's actual arrival stays empty, so delay statistics only use real reports.
- **Live map:** a train past its last Swedish report (or before its first, coming from Copenhagen or Oslo) keeps
  moving along its timetable abroad, drawn as an estimate. Before this, it vanished at the border.
- **Train identity:** a Swedish trip's Norwegian part is found in Entur by stop place, train number and a time within
  90 minutes; a GPS fix is used only if it is on that trip's date and route.
- **Replacement buses** are kept out: SJ 6/7/8xxxx by rule, and every day Trafikverket's `TypeOfTraffic` "Buss"
  takes buses off the dates it runs them (270 trip-dates on 2026-10-22, e.g. 60621 posing as SJ 621).

## What would close the gaps

- **Denmark:** Rejseplanen's API (owned by DSB and the Danish transport authorities) has live data for all Danish
  trains, but needs an access key; it may now be paid. With a key, Danish stops could be reported like Norwegian ones.
- **SJ / Snälltåget / Vy Tåg in Norway:** no public source has their live data on the Norwegian side today.
