# Finland: platform heights, laser vs register (review list)

Laser 'surface − bed' minus 0.175 m (ballast to rail head, playbook 0.15–0.2 m) compared with the register class height (korkea 0.55 m, matala 0.265 m above rail). Listed when they differ by more than 0.125 m. Nothing here is decided: each line needs a look (photo, newer scan, or the network statement).

| Station | Platform | Track | Class (m) | Bed (m N2000) | Surface (m) | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|
| fi:HKI | HKI L6 | 6 | korkea (0.55) | 3.22 | 4.12 | 0.9 | 0.72 |  |
| fi:HKI | HKI L8 | 8 | korkea (0.55) | 3.22 | 4.1 | 0.88 | 0.7 |  |
| fi:HKI | HKI L11 | 11 | korkea (0.55) | 3.23 | 4.09 | 0.86 | 0.68 |  |
| fi:HKI | HKI L12 | 12 | korkea (0.55) | 3.22 | 4.09 | 0.87 | 0.7 |  |
| fi:HKI | HKI L17 | 17 | korkea (0.55) | 3.21 | 4.1 | 0.89 | 0.72 |  |
| fi:HKI | HKI L18 | 18 | korkea (0.55) | 3.14 | 4.1 | 0.96 | 0.78 |  |
| fi:HKI | HKI L19 | 19 | korkea (0.55) | 3.21 | 4.06 | 0.85 | 0.68 |  |
| fi:HKI | HKI L5 | 5 | korkea (0.55) | 3.25 | 4.11 | 0.87 | 0.69 |  |
| fi:HL | HL L2 | 2 | korkea (0.55) | 83.58 | 84.44 | 0.86 | 0.68 |  |
| fi:JNS | JNS L1 | 1 | korkea (0.55) | 80.68 | 81.26 | 0.58 | 0.4 |  |
| fi:KUO | KUO L1 | 1 | korkea (0.55) | 95.46 | 96.38 | 0.92 | 0.74 |  |
| fi:KV | KV L6 | 6 | korkea (0.55) | 71.5 | 72.36 | 0.86 | 0.68 |  |
| fi:KV | KV L7 | 7 | korkea (0.55) | 71.52 | 72.37 | 0.85 | 0.68 |  |
| fi:PM | PM L4 | 4 | matala (0.265) | 121.67 | 122.38 | 0.7 | 0.53 |  |
| fi:PSL | PSL L5 | 5 | korkea (0.55) | 23.73 | 24.77 | 1.04 | 0.87 |  |
| fi:PSL | PSL L6 | 6 | korkea (0.55) | 23.88 | 24.78 | 0.9 | 0.73 |  |
| fi:PSL | PSL L10 | 10 | matala (0.265) | 23.62 | 24.37 | 0.75 | 0.57 |  |
| fi:SK | SK L2 | 2 | matala (0.265) | 44.55 | 45.25 | 0.7 | 0.52 |  |
| fi:TKL | TKL L4 | 4 | korkea (0.55) | 19.09 | 19.95 | 0.86 | 0.68 |  |
| fi:TL | TL L1 | 1 | korkea (0.55) | 89.69 | 90.58 | 0.89 | 0.72 |  |
| fi:TL | TL L2 | 2 | korkea (0.55) | 89.69 | 90.58 | 0.89 | 0.71 |  |
| fi:TL | TL L4 | 4 | korkea (0.55) | 89.72 | 90.58 | 0.86 | 0.68 |  |
| fi:TPE | TPE L2 | 2 | korkea (0.55) | 95.16 | 96.01 | 0.85 | 0.68 |  |
| fi:TPE | TPE L4 | 4 | korkea (0.55) | 95.37 | 96.27 | 0.9 | 0.72 |  |
| fi:TPE | TPE L5 | 5 | korkea (0.55) | 95.42 | 96.29 | 0.87 | 0.7 |  |

25 of 95 platforms differ by more than 0.125 m.

## Notes

- Helsinki (2021 city lidar, ~40 pts/m²): platforms read 0.80–0.96 m above the bed against 0.55 m in the register. The ballast-to-rail step at Helsinki's terminal tracks (concrete slab / deep sleepers) may be larger than the playbook's 0.15–0.2 m; the bed class there may also catch the slab top. Check with one photo of a track end before changing anything.
- National 0.5 p laser (all other stations): 0.5 points/m² gives few ground points per platform; values with fewer than ~30 points are weak (see `platform_points` in each `_report.json`).
- Turku: the Logomo platforms in the register postdate the 2023 scan; no levels measured.
