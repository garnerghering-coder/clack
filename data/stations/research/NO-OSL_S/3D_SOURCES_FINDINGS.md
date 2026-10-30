# Oslo S (`NO-OSL_S`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Bane NOR);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m NN2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **4.27** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **3.39** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -2.67 – 16.03 (median 3.66) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 4.27.

## Platforms (Bane NOR register vs laser)

Register: Bane NOR station page, track table (https://www.banenor.no/en/traffic-and-travel/railway-stations/-o-/oslo-central/, read 2026-10-30): per track the platform length, height (mm above top of rail), width and type; no coordinates, so each platform is drawn on the OSM track centreline (see `x_geometry` per feature). Heights are Bane NOR's per-platform values, not classes. Laser: hoydedata.no project Oslo kommune tynnet laserskanning 2019, scanned 2019-09-14. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| track OS1 | 2,OS1 | 570 (0.57) | 252.0 | 9.3 | None | 3.44 | 4.18 | 0.74 | 0.56 |  |
| track OS3 | 4,OS3 | 570 (0.57) | 252.0 | 9.3 | None | 3.39 | 4.19 | 0.80 | 0.63 |  |
| track OS5 | 6,OS5 | 570 (0.57) | 252.0 | 9.3 | None | 3.32 | 4.23 | 0.91 | 0.74 |  |
| track OS7 | 8,OS7 | 570 (0.57) | 238.0 | 9.3 | None | 3.35 | 4.40 | 1.05 | 0.88 |  |
| track OS9 | 10,OS9 | 700 (0.70) | 238.0 | 9.3 | None | 3.31 | 4.44 | 1.13 | 0.96 |  |
| track OS11 | 12,OS11 | 570 (0.57) | 252.0 | 9.3 | None | 3.39 | 4.37 | 0.98 | 0.80 |  |
| track OS13 | 14,OS13 | 700 (0.70) | 234.0 | 9.3 | None | 3.41 | 4.37 | 0.96 | 0.78 |  |
| track OS15 | 16,OS15 | 570 (0.57) | 234.0 | 9.3 | None | 3.49 | 4.31 | 0.82 | 0.65 |  |
| track OS17 | 18,OS17 | 570 (0.57) | 234.0 | 9.3 | None | 3.39 | 4.19 | 0.80 | 0.63 |  |
| track OS19 | OS19 | 570 (0.57) | 234.0 | 10.0 | None | 3.34 | 4.14 | 0.80 | 0.62 |  |

## Structures

`oslo_s_structures_heights.geojson`, 194 features: 146 building, 5 footbridge, 28 canopy_osm, 10 canopy_laser.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Bane NOR track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w4390874 | Posthuset (commercial) | 93.11 | 100.44 | 4.09 | 88.84 | 5 |
| building | w4390875 | Oslo sentralstasjon (Oslo S) (station building) | 9.70 | 15.94 | 1.26 | 5.43 | 70 |
| building | w4757710 | Galleri Oslo (transportation) | 19.82 | 29.74 | 2.17 | 15.55 | 115 |
| building | w10568050 | Oslo City (office) | 29.84 | 39.90 | 0.91 | 25.57 | 35 |
| building | w83200157 | station building | – | – | 2.98 | – | 4 |
| building | w85472890 | office | 22.11 | 22.79 | 2.03 | 17.84 | 55 |
| building | w111284507 | apartments | 16.20 | 21.18 | 3.10 | 11.93 | 24 |
| building | w111308373 | apartments | 17.78 | 17.89 | 2.99 | 13.51 | 8 |
| building | w111308379 | apartments | 15.90 | 17.76 | 2.81 | 11.63 | 31 |
| building | w111308404 | apartments | – | – | 2.95 | – | 4 |
| building | w111308415 | office | – | – | 3.07 | – | 1 |
| building | w111310700 | warehouse | – | – | 2.77 | – | 3 |
| building | w111310701 | retail | – | – | 2.83 | – | 1 |
| building | w111310709 | commercial | – | – | 2.31 | – | 0 |
| building | w111853222 | office | – | – | 12.81 | – | 1 |
| building | w112051212 | office | – | – | – | – | 0 |
| building | w112051231 | office | – | – | 13.04 | – | 4 |
| building | w112051241 | retail | – | – | – | – | 0 |
| building | w112054964 | hotel | – | – | 5.07 | – | 1 |
| building | w112087242 | building | – | – | – | – | 0 |
| building | w112087245 | retail | – | – | 10.84 | – | 1 |
| building | w112087254 | office | 19.16 | 29.16 | 10.76 | 14.89 | 7 |
| building | w112089111 | office | 29.15 | 29.36 | 12.81 | 24.88 | 15 |
| building | w112089112 | retail | – | – | 14.13 | – | 1 |
| building | w112089113 | retail | – | – | 13.19 | – | 1 |
| building | w112089114 | office | – | – | 12.92 | – | 3 |
| building | w112089123 | office | 21.82 | 26.51 | 13.71 | 17.55 | 6 |
| building | w112089124 | office | – | – | 12.79 | – | 1 |
| building | w112089128 | office | – | – | 13.28 | – | 1 |
| building | w112089130 | retail | – | – | 13.59 | – | 0 |
| building | w112089131 | retail | – | – | 12.37 | – | 2 |
| building | w112089135 | office | – | – | 13.09 | – | 0 |
| building | w112089421 | office | – | – | 2.09 | – | 2 |
| building | w112089428 | tower | – | – | 2.47 | – | 3 |
| building | w112089436 | office | 23.12 | 30.32 | 2.09 | 18.85 | 11 |
| building | w112089439 | office | 22.66 | 23.18 | 2.68 | 18.39 | 13 |
| building | w112195497 | office | 18.34 | 18.47 | 2.89 | 14.07 | 14 |
| building | w112195502 | Tollboden (office) | 21.22 | 21.34 | 1.27 | 16.95 | 31 |
| building | w112195503 | Stenpakkhuset (office) | 12.56 | 12.80 | 1.98 | 8.29 | 13 |
| building | w112233122 | office | – | – | – | – | 0 |
| building | w112233126 | office | – | – | – | – | 0 |
| building | w112237550 | retail | – | – | – | – | 0 |
| building | w112237557 | retail | – | – | 3.83 | – | 0 |
| building | w112237565 | retail | – | – | 4.84 | – | 1 |
| building | w112237586 | office | – | – | 4.38 | – | 2 |
| building | w112491968 | hotel | 23.69 | 23.71 | 4.05 | 19.42 | 6 |
| building | w112491974 | office | – | – | 2.56 | – | 1 |
| building | w112491981 | office | 24.92 | 25.32 | 3.10 | 20.65 | 5 |
| building | w112491996 | office | 24.65 | 25.45 | 2.91 | 20.38 | 13 |
| building | w112495409 | hotel | 21.54 | 21.61 | 2.59 | 17.27 | 5 |
| building | w112495461 | office | – | – | 2.76 | – | 1 |
| building | w112502874 | tower | – | – | 5.13 | – | 0 |
| building | w112502904 | tower | 38.10 | 41.25 | 4.89 | 33.83 | 9 |
| building | w112504966 | Bragegården (office) | 30.02 | 30.15 | 9.81 | 25.75 | 21 |
| building | w112506360 | office | 13.04 | 20.95 | 4.87 | 8.77 | 7 |
| building | w112506383 | office | – | – | 5.63 | – | 4 |
| building | w112509668 | warehouse | 30.19 | 32.88 | 10.75 | 25.92 | 10 |
| building | w131419741 | Østbanehallen (station building) | 12.25 | 13.13 | 1.81 | 7.98 | 14 |
| building | w135175595 | KLP (commercial) | 37.71 | 65.36 | 3.96 | 33.44 | 28 |
| building | w137313681 | office | – | – | 3.38 | – | 4 |
| building | w266134984 | Byporten Shopping (retail) | 28.35 | 31.27 | 3.85 | 24.08 | 39 |
| building | w266134986 | Trafikanten (office) | – | – | 5.94 | – | 2 |
| building | w266134987 | commercial | – | – | 5.94 | – | 2 |
| building | w266134988 | building | 8.71 | 10.61 | 2.17 | 4.44 | 6 |
| building | w266134989 | building | 10.38 | 10.69 | 2.19 | 6.11 | 5 |
| building | w266134990 | building | – | – | 2.81 | – | 0 |
| building | w266134991 | building | 7.95 | 10.74 | 2.18 | 3.68 | 7 |
| building | w266134992 | building | 9.63 | 10.89 | 1.95 | 5.36 | 12 |
| building | w266134993 | building | 8.95 | 9.94 | 2.22 | 4.68 | 10 |
| building | w266134994 | building | – | – | 2.50 | – | 1 |
| canopy_osm | w266171429 | roof | – | – | 6.28 | – | 1 |
| canopy_osm | w308634305 | roof | 7.70 | 7.82 | 3.38 | 3.43 | 15 |
| canopy_osm | w308634307 | roof | 7.83 | 7.95 | 3.57 | 3.56 | 7 |
| canopy_osm | w308634308 | roof | 7.69 | 7.80 | 3.72 | 3.42 | 13 |
| canopy_osm | w308634309 | roof | 7.52 | 7.56 | 3.96 | 3.25 | 15 |
| canopy_osm | w308634310 | roof | 7.98 | 8.11 | 3.88 | 3.71 | 11 |
| canopy_osm | w308634311 | roof | 8.08 | 8.14 | 3.53 | 3.81 | 11 |
| canopy_osm | w308634312 | roof | 7.99 | 8.08 | 3.49 | 3.72 | 11 |
| canopy_osm | w308634313 | roof | 6.89 | 6.93 | 3.09 | 2.62 | 6 |
| canopy_osm | w308634314 | roof | 7.47 | 7.55 | 3.92 | 3.20 | 13 |
| canopy_osm | w308634315 | roof | 7.79 | 7.90 | 2.60 | 3.52 | 5 |
| canopy_osm | w308634316 | roof | – | – | 3.34 | – | 0 |
| canopy_osm | w308634317 | roof | 7.96 | 8.00 | 3.66 | 3.69 | 12 |
| building | w340068408 | Posthuset østre tårn (building) | – | – | 4.09 | – | 1 |
| building | w352083938 | Oslo Østbanestasjon (Oslo Ø) (station building) | 10.82 | 20.13 | 2.05 | 6.55 | 8 |
| bridge | w377766487 | Nylandsbrua (bridge) | – | – | 0.16 | – | 4 |
| bridge | w381749953 | Vaterlands bru (bridge) | – | – | 0.20 | – | 0 |
| building | w394299229 | Amediahuset (office) | – | – | – | – | 0 |
| building | w394299230 | office | – | – | – | – | 0 |
| bridge | w405332454 | bridge | – | – | – | – | 0 |
| building | w435653432 | Oslo bussterminal (building) | 9.55 | 22.55 | 3.19 | 5.29 | 12 |
| bridge | w453102557 | bridge | – | – | 0.12 | – | 0 |
| bridge | w468892278 | Nordenga bru (bridge) | – | – | 2.43 | – | 1 |
| footbridge | w468892289 | Akrobaten (bridge) | 8.77 | 10.63 | 2.75 | 4.50 | 6 |
| footbridge | w505897412 | bridge | – | – | 4.21 | – | 0 |
| footbridge | w505897413 | bridge | – | – | 3.39 | – | 2 |
| building | w545738677 | Stortorvet blomster (kiosk) | – | – | 10.94 | – | 0 |
| canopy_osm | w547519220 | shelter | – | – | 3.72 | – | 0 |
| building | w617659006 | building | – | – | 3.96 | – | 3 |
| building | w617659009 | building | 34.95 | 35.00 | 4.07 | 30.68 | 10 |
| canopy_osm | w619890705 | roof | – | – | – | – | 0 |
| footbridge | w620055381 | bridge | – | – | 0.15 | – | 0 |
| canopy_osm | w620165317 | roof | – | – | – | – | 0 |
| canopy_osm | w669390493 | roof | – | – | 2.54 | – | 1 |
| building | w669476271 | office | 7.95 | 21.72 | 2.66 | 3.68 | 5 |
| building | w669476293 | office | – | – | 5.60 | – | 2 |
| building | w669513082 | office | – | – | 14.37 | – | 1 |
| building | w669513088 | warehouse | – | – | 15.10 | – | 3 |
| building | w669513089 | office | – | – | 14.10 | – | 2 |
| building | w669513091 | office | – | – | 13.63 | – | 0 |
| building | w669513094 | office | 26.78 | 27.05 | 13.53 | 22.51 | 7 |
| building | w669513101 | retail | – | – | 14.77 | – | 0 |
| building | w669513105 | office | – | – | 14.21 | – | 0 |
| building | w669529743 | Glasmagasinet (retail) | 29.78 | 34.61 | 10.28 | 25.51 | 20 |
| footbridge | w698326783 | bridge | – | – | 2.59 | – | 0 |
| building | w727490344 | Clarion Hotel Oslo (hotel) | – | – | – | – | 0 |
| building | w849277764 | apartments | – | – | 2.32 | – | 3 |
| canopy_osm | w865719379 | shelter | – | – | – | – | 0 |
| canopy_osm | w865719380 | shelter | – | – | 3.59 | – | 1 |
| canopy_osm | w865719381 | shelter | – | – | – | – | 0 |
| building | w909011598 | building | – | – | 2.43 | – | 0 |
| building | w909071280 | roof | 10.08 | 10.10 | 1.34 | 5.81 | 17 |
| building | w909071281 | roof | – | – | 1.26 | – | 0 |
| building | w909071282 | roof | – | – | – | – | 0 |
| building | w909071283 | roof | – | – | – | – | 0 |
| building | w909071284 | roof | 5.81 | 9.74 | 2.82 | 1.54 | 5 |
| building | w909140831 | building | – | – | 3.93 | – | 0 |
| building | w909140834 | building | – | – | 3.89 | – | 4 |
| building | w909140835 | building | 31.20 | 31.29 | 3.85 | 26.93 | 26 |
| building | w909140837 | building | – | – | 3.90 | – | 1 |
| building | w909140839 | building | – | – | – | – | 0 |
| building | w909299064 | building | – | – | 2.50 | – | 1 |
| building | w909299065 | building | – | – | 2.54 | – | 0 |
| building | w909299067 | tower | – | – | 2.51 | – | 1 |
| building | w909383104 | building | – | – | 2.51 | – | 4 |
| building | w910115080 | building | 15.50 | 15.69 | 1.26 | 11.23 | 5 |
| canopy_osm | w938568697 | shelter | – | – | 4.66 | – | 0 |
| canopy_osm | w938568708 | shelter | – | – | – | – | 0 |
| canopy_osm | w1030902603 | roof | – | – | 4.45 | – | 1 |
| building | w1030902609 | apartments | 26.64 | 26.72 | 3.21 | 22.37 | 5 |
| building | w1030902610 | apartments | 24.64 | 25.14 | 3.67 | 20.37 | 6 |
| building | w1030903459 | apartments | – | – | 3.53 | – | 3 |
| building | w1030903707 | industrial | 9.40 | 9.66 | 3.26 | 5.13 | 6 |
| building | w1030903710 | retail | 8.57 | 9.80 | 2.53 | 4.30 | 8 |
| building | w1030903713 | retail | – | – | 3.09 | – | 2 |
| canopy_osm | w1040313653 | roof | – | – | – | – | 0 |
| building | w1040647135 | retail | – | – | – | – | 0 |
| building | w1040647137 | building | – | – | 13.29 | – | 0 |
| building | w1040907114 | building | – | – | – | – | 0 |
| building | w1040907115 | building | – | – | – | – | 0 |
| building | w1040907133 | building | 22.29 | 24.57 | 5.17 | 18.02 | 7 |
| building | w1040907134 | building | 30.53 | 41.23 | 4.57 | 26.26 | 20 |
| building | w1040907135 | building | 41.11 | 41.26 | 4.94 | 36.84 | 5 |
| building | w1040907150 | office | – | – | – | – | 0 |
| building | w1040907170 | office | 29.88 | 31.43 | 15.25 | 25.61 | 7 |
| building | w1041933857 | building | – | – | 11.76 | – | 1 |
| building | w1041933873 | retail | – | – | 13.57 | – | 4 |
| canopy_osm | w1125840636 | shelter | – | – | – | – | 0 |
| canopy_osm | w1125840637 | shelter | – | – | – | – | 0 |
| canopy_osm | w1227009142 | roof | – | – | 9.78 | – | 1 |
| canopy_osm | w1227009143 | roof | – | – | 7.98 | – | 0 |
| building | w1286788254 | building | – | – | 3.62 | – | 4 |
| building | w1504440155 | building | – | – | 3.35 | – | 3 |
| building | w1504440156 | building | 9.77 | 19.84 | 2.45 | 5.50 | 29 |
| building | w1504440157 | building | 23.07 | 23.33 | 2.23 | 18.80 | 34 |
| building | w1504440158 | building | – | – | 3.75 | – | 3 |
| building | w1504440159 | building | – | – | 3.41 | – | 0 |
| building | w1504440163 | building | 12.85 | 23.25 | 3.26 | 8.58 | 7 |
| building | w1504440164 | building | 19.88 | 19.90 | 3.34 | 15.61 | 7 |
| building | r7008087 | apartments | 22.17 | 22.35 | 3.57 | 17.90 | 5 |
| building | r7076467 | Stortorvets Gjæstgiveri (commercial) | 20.27 | 20.82 | 11.76 | 16.00 | 17 |
| building | r8596225 | office | 12.87 | 13.44 | 2.98 | 8.60 | 7 |
| building | r8596226 | hotel | 21.88 | 23.39 | 3.64 | 17.61 | 22 |
| building | r8596230 | hotel | 24.60 | 28.59 | 2.94 | 20.33 | 9 |
| building | r9312412 | retail | 28.24 | 30.40 | 10.49 | 23.97 | 14 |
| building | r9312419 | Oslo postgård (civic) | 22.44 | 41.07 | 4.57 | 18.17 | 50 |
| building | r9313002 | office | – | – | 12.71 | – | 4 |
| building | r9313003 | warehouse | 29.05 | 29.24 | 10.69 | 24.78 | 10 |
| building | r9313155 | retail | – | – | – | – | 0 |
| building | r9313158 | office | – | – | 4.88 | – | 1 |
| building | r9313160 | retail | – | – | 5.10 | – | 2 |
| building | r9313164 | retail | – | – | – | – | 0 |
| building | r13923939 | retail | – | – | – | – | 0 |
| building | r13931036 | office | – | – | 4.11 | – | 3 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 9.05 | 11.05 | 3.09 | 4.78 | 1778 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 8.74 | 9.13 | 3.11 | 4.47 | 1493 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 8.73 | 9.13 | 3.07 | 4.46 | 1515 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 8.75 | 9.17 | 3.00 | 4.48 | 1564 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 8.73 | 9.15 | 3.03 | 4.46 | 1611 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 8.68 | 9.14 | 2.93 | 4.41 | 1634 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 8.67 | 9.13 | 2.95 | 4.40 | 1607 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 8.67 | 9.10 | 2.91 | 4.40 | 1677 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 8.61 | 9.09 | 2.87 | 4.34 | 1690 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 8.45 | 8.95 | 1.23 | 4.18 | 1778 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform at track OS1: OSM outline r4121515 runs 381 m along the track, Bane NOR length 252 m (the outline may include ramps or the part beyond the usable length); line drawn to the OSM outline
- Platform at track OS3: OSM outline r4121518 runs 449 m along the track, Bane NOR length 252 m (the outline may include ramps or the part beyond the usable length); line drawn to the OSM outline
- Platform at track OS5: OSM outline r4121521 runs 321 m along the track, Bane NOR length 252 m (the outline may include ramps or the part beyond the usable length); line drawn to the OSM outline
- Platform at track OS11: OSM outline r4121516 runs 361 m along the track, Bane NOR length 252 m (the outline may include ramps or the part beyond the usable length); line drawn to the OSM outline
- Platform at track OS13: OSM outline r4121520 runs 352 m along the track, Bane NOR length 234 m (the outline may include ramps or the part beyond the usable length); line drawn to the OSM outline
- Platform at track OS15: OSM outline r4121517 runs 389 m along the track, Bane NOR length 234 m (the outline may include ramps or the part beyond the usable length); line drawn to the OSM outline
- Platform at track OS17: OSM outline r4121519 runs 389 m along the track, Bane NOR length 234 m (the outline may include ramps or the part beyond the usable length); line drawn to the OSM outline
- Platform at track OS19: OSM outline r6825728 runs 348 m along the track, Bane NOR length 234 m (the outline may include ramps or the part beyond the usable length); line drawn to the OSM outline
- Platform BIS track OS5 (track 6,OS5): laser gives 0.91 m above the track bed (≈0.74 m above rail after −0.15…0.2 m), register class 570 = 0.57 m. Not decided; add to REVIEW.md.
- Platform BIS track OS7 (track 8,OS7): laser gives 1.05 m above the track bed (≈0.88 m above rail after −0.15…0.2 m), register class 570 = 0.57 m. Not decided; add to REVIEW.md.
- Platform BIS track OS9 (track 10,OS9): laser gives 1.13 m above the track bed (≈0.96 m above rail after −0.15…0.2 m), register class 700 = 0.7 m. Not decided; add to REVIEW.md.
- Platform BIS track OS11 (track 12,OS11): laser gives 0.98 m above the track bed (≈0.80 m above rail after −0.15…0.2 m), register class 570 = 0.57 m. Not decided; add to REVIEW.md.
- w4390874 Posthuset (commercial): p95 100.4 m is 7.3 m above the median 93.1 m (a taller neighbour or a mast inside the outline?).
- w4390875 Oslo sentralstasjon (Oslo S) (station building): p95 15.9 m is 6.2 m above the median 9.7 m (a taller neighbour or a mast inside the outline?).
- w4757710 Galleri Oslo (transportation): p95 29.7 m is 9.9 m above the median 19.8 m (a taller neighbour or a mast inside the outline?).
- w352083938 Oslo Østbanestasjon (Oslo Ø) (station building): p95 20.1 m is 9.3 m above the median 10.8 m (a taller neighbour or a mast inside the outline?).
- w435653432 Oslo bussterminal (building): p95 22.6 m is 13.0 m above the median 9.6 m (a taller neighbour or a mast inside the outline?).
- w909071284 roof: p95 9.7 m is 3.9 m above the median 5.8 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w377766487 Nylandsbrua (footway, primary, trunk); w381749953 Vaterlands bru (footway, tertiary); w405332454 (footway, unclassified); w453102557 (cycleway, footway, trunk); w468892278 Nordenga bru (trunk).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (27 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2019-09-14: anything built since is missing from the laser (compare the Bane NOR valid-from dates).

## Sources

- Høydedata, project "Oslo kommune tynnet laserskanning 2019" (id 1175, FKB-Laser 3.0, nominal 0.5 points/m², supplier Terratec AS), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box. https://hoydedata.no/LaserInnsyn2/ (scan 2019-09-14; 1,422,135 points in the box, 1.25 per m²; classes {'1': 686291, '2': 706145, '17': 29699}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Bane NOR station page https://www.banenor.no/en/traffic-and-travel/railway-stations/-o-/oslo-central/ (track table, facts om stasjonen), read 2026-10-30: facts only.
- Entur National Stop Register quays via journey-planner v3 (NLOD), read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=10.741490,59.904990,10.765490,59.916990, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
