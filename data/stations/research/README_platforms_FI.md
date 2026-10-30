# Platform register for the 17 Finnish stations

Read 2026-10-30 from Digitraffic infra-api (Väylävirasto / Fintraffic), CC BY 4.0, credit "Väylävirasto / Fintraffic, Digitraffic".

| File | What it is |
|---|---|
| `vayla_platforms_FI.csv` | One row per platform object (`laiturit`) of the 17 stations, in the columns of `trafikverket_platforms_SE.csv`: `bandel` = Väylä track section (ratanumero), `tracks` = the signposted platform/track number (kaupallinenNumero), `bis_object` = register id, height class and m, length, valid-from; `width_m` and `roof` are empty (not in the register); `remark` has the infra-api oid and the rail-km range. |
| `_sources/FI/clack_fi_infra_platforms.json` | The raw download: `laiturit.json`, `rautatieliikennepaikat.json`, `liikennepaikanosat.json` (`?time=2026-10-30T00:00:00Z/2026-10-30T00:00:00Z`). |
| `_sources/FI/fi_stations.json` | The 17 stations: code, name, position, platform bounds (EPSG:3067), laser sheets. |
| `_sources/FI/mml05_sheet_meta.json` | Scan date, project and flight height of each national laser sheet used (NLS file service order 0599290996). |

- `height_m`: `korkea` 0.55 m, `matala` 0.265 m above rail (Finnish standard; Väylävirasto Network Statement 2021 appendix 3B, cited by Wikipedia "Platform height", read 2026-10-30). Check against the current Network Statement annex before relying on it.
- The register has no width and no roof.
- Platform objects are listed under their traffic place: Pasila's `PSL` platforms sit under Helsinki (`Hel`) in the register; Tikkurila's object set also holds Hiekkaharju (`HKH`), left out here.
- The register's line geometry runs along the platform track's centre (checked against OSM rails at Helsinki: 0.0–0.2 m), so the 3D pass measures bed and surface exactly as for Trafikverket's BanInfo lines.
- Turku: the register's platforms are the new Logomo platforms (tracks 1–3 from 2024-08-05, 4–6 from 2025-09-29); the 2023 laser predates them, so no platform levels were measured there.

- Station ids follow the brief (`fi:HKI`); folders and file names use `_` for `:` (`fi_HKI`).
