# Platform register for the 33 Swedish hub and mid stations (batch step 1)

Read 2026-10-30. Licence: Trafikverket data (Network Statement annex and BanInfo, CC0). Credit "Trafikverket".

| File | What it is |
|---|---|
| `trafikverket_platforms_SE.csv` | One row per Bilaga 2A platform row, joined with the matching BanInfo `Plattform` object; then BanInfo objects that have no Bilaga row. Columns as in the brief, plus a trailing `remark` (Bilaga's Anmärkning/Notering and the flags below). |
| `bilaga2a_raw.txt` | The 139 rows of JNB 2027 Bilaga 2A tab "4.) Plattformar" (report dated 2026-02-04) for these stations, with their xlsx row numbers. |
| `baninfo_platforms_raw.txt` | Every BanInfo `Plattform` object found round each station (BIS number, class, length, width, roof, edge, surface, km range, valid-from), with the track from the `Sparnummer` layer matched by track link. |
| `stac_index_SE.txt` | Lantmäteriet STAC per station: laser scan block, date, density, flight height, the 2.5 km tiles and sizes, and the terrain-model tile. |

## How the CSV was made
- `height_m` from the key in tab "2.) Förklaringar" (låg 0.35, mellan 0.58, hög 0.73, TSD mellan 0.55, TSD hög 0.76). Empty for "ej norm".
- `bis_object`, `width_m`, `valid_from` come from BanInfo. A Bilaga row matches a BanInfo object with the same class, length within 1 m and an overlapping track. BanInfo width 0 is written as empty (not recorded).
- `roof` is Bilaga's Väderskydd (Tak / Skydd / Saknas); for BanInfo-only rows, BanInfo's.
- BanInfo references each platform to one track link, so its track is one of the tracks Bilaga lists.

## Flags (not decided)
- **Arlanda C:** not in Bilaga 2A (Arlandabanan is outside it). BanInfo has three `hög` (0.73 m) objects on tracks 1, 4 and 6 with no length, width or roof. BIS 2306 lies 0.3 km north of the station point: check whether it is Arlanda C.
- **Stockholm C, tracks 1–2 (Arlanda Express):** class "ej norm", Bilaga's remark gives 1150 mm. Listed twice in Bilaga (rows 828 and 833). height_m left empty.
- **Stockholm C, E6/E7 and C2S–C4S rows (829–832):** Bilaga files them under Stockholms central, but the BanInfo objects lie 0.4–1 km north-west of the hall. Row 832 (E7s,E6s, 355 m) found no BanInfo object.
- **Stockholm C, tab 5:** platform 6 (tracks 13–14) to be lengthened to 370 m, planned 2026-11-27.
- **Stockholm City** BanInfo objects (tracks 2 and 3, hög) fell inside the Stockholm C search box and were left out: separate station.
- **Örebro S:** Bilaga row 1141 (tracks 2,30, mellan, 207 m) is out of date. Tab 5 says the middle platform goes and track 30 gets a new 240 m mellan side platform (planned 2026-05-30); BanInfo has that platform (BIS 2618, valid from 2026-06-26) plus BIS 1219 (track 1, låg, 188 m).
- **Göteborg C, tracks 22 and 23:** new BanInfo objects valid from 2026-10-29 (mellan, 250 m, 14.2 m wide, steel edge), not in Bilaga 2A.
- **Eskilstuna C:** two "ej norm" objects on tracks 12 and 14, 0.7–0.9 km north-west, kept as BanInfo-only rows. Bilaga row 161 (track 4, 142 m, Tak) found no BanInfo object.
- **Uppsala C:** two "ej norm" objects on tracks z9/z10 at km 114, another line; kept as BanInfo-only rows.
- **Södertälje Syd** is two places in Bilaga: *undre* (bandel 412, tracks 3 and 4, hög) and *övre* (bandel 418, tracks 5–8, mellan).
- **Malmö C** includes the Citytunneln platforms (bandel 960, tracks 1a–4a/2a–4b).
- The laser cross-check against these classes is per station, still to do.
