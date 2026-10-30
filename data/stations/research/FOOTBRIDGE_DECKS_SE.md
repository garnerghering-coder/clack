# Footbridge decks over the platform tracks (Sweden)

Measured 2026-10-30 from each station's laser (`footbridge_decks.json` in each pack, made by `scripts/footbridge_decks.py`).
Heights m RH 2000; 'above platform' = minus the pack's platform surface. Airborne laser sees tops only: a deck is measured
only where Lantmäteriet classed it as bridge deck (class 17). A higher unclassified surface is either an open deck the
classification missed (railings included) or the roof of an enclosed bridge; the laser cannot tell which, so the deck is
left unmeasured there. No clearance or deck thickness is derived. Only bridges that cross a register platform track are listed.

## Jönköping C (asked first)

- Gångbro over the tracks (OSM w81576735): owner Jönköpings kommun, built 2001, Trafikverket BanInfo `Vagbro` BIS 6207 "JÖNKÖPINGS STATION, GÅNGBRO", km 69+300, function GB (read 2026-10-30). BanInfo records no clearance.
- Laser (2022 scan): top surface median **100.74 m** (p95 101.73), **9.07 m above the platform surface 91.67 m**, 9.86 m above the track bed 90.88 m. No bridge-deck class points inside the outline: the deck is **not measured**. The scan has ~1.8 points/m² on the bridge; the few returns between 93.5 and 99.5 m are too sparse and mixed (ends, stair towers, hillside) to read as a floor.
- Known ends: the north end has a lift (OSM n950768989, levels 0;1) from platform/street level; the south end meets Juneporten, where the ground outside the south entrance is 95.3 m (laser). Whether the deck lands flush with that ground is not recorded anywhere I found.
- To settle it: a drawing or the municipality's bridge record (BaTMan), or one measurement on site (floor of the bridge vs platform).

## All stations

| Station | Scan | OSM way | Name | Over tracks | Deck (class 17) m | Deck above platform m | Top surface (unclassified) m | Top above platform m | Note |
|---|---|---|---|---|---|---|---|---|---|
| Stockholm C | 2021-03-23 | w127674527 | Kungsbron | E6n,E6s | 10.59 | 6.11 | – | – |  |
| Stockholm C | 2021-03-23 | w127674528 | Kungsbron | E6n,E6s | 10.60 | 6.12 | – | – |  |
| Stockholm C | 2021-03-23 | w129535734 |  | 10, 11, 14a, 16a, 17a, 19a | 11.92 | 7.44 | – | – |  |
| Stockholm C | 2021-03-23 | w208756524 |  | 4, 6 | – | – | 33.26 | 28.78 | top surface is a building over the tracks, not the bridge |
| Stockholm C | 2021-03-23 | w427926627 |  | 4, 6 | – | – | 33.16 | 28.68 | top surface is a building over the tracks, not the bridge |
| Stockholm C | 2021-03-23 | w587808099 | Kungsbron | E6n,E6s | 10.58 | 6.10 | 16.15 | 11.67 | deck seen (bridge class) and a higher surface over parts of it (roof, canopy or lift tower) |
| Stockholm C | 2021-03-23 | w906374987 |  | 16a, 17a, 19a | – | – | 34.11 | 29.63 | top surface is a building over the tracks, not the bridge |
| Malmö C | 2025-03-07 | w1352062485 | Suellsbron | 2a,2b | 3.30 | 0.10 | – | – |  |
| Alvesta | 2026-03-08 | w235987032 |  | 1a,1b, 2 | – | – | 155.13 | 9.82 | no bridge-deck class: the top surface is either the open deck (unclassified) or the roof of an enclosed bridge; deck level not measured; OSM has no covered tag |
| Alvesta | 2026-03-08 | w1565102356 |  | 1a,1b, 2 | – | – | 155.91 | 10.60 | no bridge-deck class: the top surface is either the open deck (unclassified) or the roof of an enclosed bridge; deck level not measured; OSM has no covered tag |
| Hässleholm C | 2025-02-19 | w55226306 |  | 1b, 4b | – | – | 63.63 | 9.82 | no bridge-deck class: the top surface is either the open deck (unclassified) or the roof of an enclosed bridge; deck level not measured; OSM has no covered tag |
| Flemingsberg | 2020-03-31 | w40858591 |  | 3 | 43.04 | 8.64 | 46.39 | 11.99 | deck seen (bridge class) and a higher surface over parts of it (roof, canopy or lift tower) |
| Flemingsberg | 2020-03-31 | w133331997 |  | 7 | 41.21 | 6.81 | – | – |  |
| Södertälje Syd | 2020-03-31 | w1266209056 | Igelstabron | 6, 8 | 40.71 | 11.76 | 44.45 | 15.50 | deck seen (bridge class) and a higher surface over parts of it (roof, canopy or lift tower) |
| Karlstad C | 2019-10-29 | w1206809262 | Trädgårdslänken | 1a, 4a | – | – | – | – | no deck-class or roof points on the strip (too few points, or the bridge is newer than the scan 2019-10-29) |
| Karlstad C | 2019-10-29 | w1274171384 |  | 1a, 4a | – | – | 53.89 | 5.25 | no bridge-deck class: the top surface is either the open deck (unclassified) or the roof of an enclosed bridge; deck level not measured; OSM has no covered tag |
| Västerås C | 2021-04-05 | w492064173 |  | 5 | – | – | – | – | no deck-class or roof points on the strip (too few points, or the bridge is newer than the scan 2021-04-05) |
| Varberg C | 2020-01-20 | w1415619326 | Alida Svenssons gång- och cykelbro | 2a,2b, 4a,4b, 5a,5b | – | – | 2.44 | – | bridge built after the January 2020 scan: not in the laser |
| Varberg C | 2020-01-20 | w1463599003 | Linda Hanssons Bro | 1a,1b, 2a,2b, 4a,4b, 5a,5b | – | – | 2.30 | – | bridge built after the January 2020 scan: not in the laser |
| Varberg C | 2020-01-20 | w1463599004 | Alida Svenssons gång- och cykelbro | 2a,2b, 4a,4b, 5a,5b | – | – | 2.46 | – | bridge built after the January 2020 scan: not in the laser |
| Lund C | 2025-03-08 | w117617938 | Mittelbron | 1, 3, 4, 6 | – | – | 50.39 | 8.92 | no bridge-deck class: the top surface is either the open deck (unclassified) or the roof of an enclosed bridge; deck level not measured; OSM has no covered tag |
| Lund C | 2025-03-08 | w232485441 | Skyttelbron | 1, 3, 4, 6 | – | – | 51.85 | 10.38 | no bridge-deck class: the top surface is either the open deck (unclassified) or the roof of an enclosed bridge; deck level not measured; OSM has no covered tag |
| Lund C | 2025-03-08 | w334180499 |  | 1, 3, 4, 6 | – | – | 50.32 | 8.85 | no bridge-deck class: the top surface is either the open deck (unclassified) or the roof of an enclosed bridge; deck level not measured; OSM has no covered tag |
| Nässjö C | 2022-03-20 | w185047096 |  | 10n,10s, 8s | – | – | 305.10 | 10.58 | no bridge-deck class: the top surface is either the open deck (unclassified) or the roof of an enclosed bridge; deck level not measured; OSM has no covered tag |
| Öxnered | 2020-03-21 | w45583777 |  | 1, 2 | – | – | 68.89 | 6.43 | no bridge-deck class: the top surface is either the open deck (unclassified) or the roof of an enclosed bridge; deck level not measured; OSM has no covered tag |
| Trollhättan | 2020-03-21 | w310276090 |  | 1, 2 | – | – | 48.53 | 3.93 | no bridge-deck class: the top surface is either the open deck (unclassified) or the roof of an enclosed bridge; deck level not measured; OSM has no covered tag |
| Örebro S | 2023-07-11 | w979570484 |  | 1, 30 | 37.35 | – | – | – |  |

Reading the table:

- **Measured open decks** (class 17): Stockholm C Kungsbron +6.1 m and the footway over tracks 10–17 +7.4 m; Flemingsberg +6.8 m (over track 7) and +8.6 m (over track 3, partly roofed); Södertälje Syd Igelstabron +11.8 m (the railway bridge carrying the upper station); Malmö C Suellsbron +0.1 m (a canal bridge at platform level, not over a track in use). Örebro S's footbridge deck is 37.35 m; its platforms were rebuilt after the 2023 scan, so no measured platform level to subtract (register: tracks 1 and 30).
- **Deck not measured, top surface only**: Alvesta (+9.8/+10.6), Hässleholm (+9.8), Lund Mittelbron (+8.9) and Skyttelbron (+10.4), Nässjö (+10.6), Öxnered (+6.4), Trollhättan (+3.9, too low for a deck over electrified track: probably a canopy or train under the line; check), Karlstad (+5.3; Trädgårdslänken is newer than the 2019 scan). Values of 9–11 m are consistent with enclosed bridges' roofs, ~6–7 m with open decks, but that is not decided here.
- Stations with no OSM footbridge over the register tracks are not listed (tunnel stations, or the bridge is mapped without bridge=*).
