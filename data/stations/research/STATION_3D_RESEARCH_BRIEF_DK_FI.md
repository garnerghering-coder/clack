# Research brief: Denmark and Finland, hub and mid-size stations

The next pass after Sweden (all 33 Swedish stations are done and in the app). Same recipe, same outputs: **read the
playbook `STATION_3D_RESEARCH.md`** (Part 1 the recipe, Part 2 how results go into the app, Part 3 the code) and the
Sweden brief `STATION_3D_RESEARCH_BRIEF_SWEDEN.md` (its hard rules, output layout and `station_facts.json` format apply
unchanged). Your own scoping notes are the source guide for each country: `data/stations/research/scope/scope_DK.md` and
`scope_FI.md`. Norway (`scope_NO.md`) comes after these.

## What changed since your scoping

- **The station lists are new** (owner, 2026-10-30). Denmark's mid tier was inflated by coastal and local lines; Finland's
  was far too short. Use the tables below, not the 51 Danish / 4 Finnish stations your scoping assumed. Stations dropped
  from Denmark's list (the Øresund coast line, the Lokaltog stations) don't need packs now.
- **Facts from the Swedish pass that carry over:**
  - list every train in the scan (`train_in_scan`) and every shape that could be a building (`hall_roof_laser`);
  - never infer a floor, deck or outline from walkway points;
  - laser sees tops only: give tops, mark undersides unknown;
  - footbridge decks: give what any source says (none did in Sweden);
  - platform sides and tracks per platform are what lets the app place a train at its platform: give them for every
    platform, with sectors (a/b) where signposted;
  - amenities: give a position (an OSM node or the building's point) whenever you can; descriptions alone are placed
    only approximately.
- **Underground platforms** (København Nørreport's S-tog/metro levels, Ørestad's metro, Helsinki's metro): measure the
  surface (buildings, roofs, ground) and say the platforms are underground; don't measure them.

## Accounts the owner must create (free), before you start

- **Denmark:** a Dataforsyningen account and token (or Datafordeler with an API key) for Danmarks Højdemodel (your
  scope_DK.md §1.2). Tell the owner exactly which and where; never store the token in the repo.
- **Finland:** an NLS (Maanmittauslaitos) API key for the open 0.5 p laser and the DEM (scope_FI.md §1.2–1.4).
- Say in the handoff which account each step used; the owner logs in, you don't.

## Denmark (27: 1 hub, 26 mid)

| Tier | Station | Clack id | Lat, lon | Station map in the app |
|---|---|---|---|---|
| hub | København H | `860000626` | 55.67269, 12.56463 | yes |
| mid | Aalborg | `860000020` | 57.04304, 9.91704 | withheld |
| mid | Aarhus H | `860000053` | 56.15044, 10.20476 | withheld |
| mid | CPH Airport | `860000858` | 55.62943, 12.64970 | yes |
| mid | Esbjerg | `860000215` | 55.46792, 8.45819 | withheld |
| mid | Fredericia | `860000079` | 55.56822, 9.74063 | withheld |
| mid | Helsingør | `860000669` | 56.03362, 12.61417 | withheld |
| mid | Herning | `860000275` | 56.13333, 8.97786 | withheld |
| mid | Hillerød | `860000683` | 55.92692, 12.31093 | withheld |
| mid | Hjørring | `860000009` | 57.45648, 9.98539 | withheld |
| mid | Holbæk | `860000719` | 55.71575, 11.70860 | withheld |
| mid | Höje Taastrup | `gtfs:72888` | 55.64860, 12.26940 | withheld |
| mid | Kolding | `860000083` | 55.49060, 9.48080 | yes |
| mid | Köbenhavn Syd | `860000783` | 55.65250, 12.51670 | yes |
| mid | København Nørreport | `860000646` | 55.68402, 12.57281 | withheld |
| mid | København Østerport | `860000650` | 55.69288, 12.58803 | yes |
| mid | Køge | `860000803` | 55.45755, 12.18633 | yes |
| mid | Køge Nord | `860000797` | 55.49919, 12.17399 | withheld |
| mid | Middelfart | `860000501` | 55.50198, 9.73404 | withheld |
| mid | Næstved | `860000810` | 55.23124, 11.76705 | yes |
| mid | Odense | `860000512` | 55.40170, 10.38670 | yes |
| mid | Ringsted | `860000611` | 55.43839, 11.78638 | yes |
| mid | Roskilde | `860000617` | 55.63909, 12.08855 | yes |
| mid | Skanderborg | `860000061` | 56.04337, 9.92536 | yes |
| mid | Slagelse | `860000605` | 55.40731, 11.34900 | yes |
| mid | Vejle | `860000073` | 55.70673, 9.53648 | yes |
| mid | Ørestad | `860000856` | 55.62868, 12.57955 | yes |

Platform register: Banedanmark's Netredegørelse 2027, Bilag 3.6 "Perronlængder og -højder", plus Banedanmark Open Data
(your scope_DK.md §2). Write it as `banedanmark_platforms_DK.csv` with the same columns as `trafikverket_platforms_SE.csv`.

## Finland (17: 1 hub, 16 mid)

| Tier | Station | Clack id | Lat, lon | Station map in the app |
|---|---|---|---|---|
| hub | Helsinki | `fi:HKI` | 60.17136, 24.94144 | yes |
| mid | Hämeenlinna | `fi:HL` | 61.00237, 24.47885 | none yet |
| mid | Joensuu | `fi:JNS` | 62.59954, 29.77703 | none yet |
| mid | Jyväskylä | `fi:JY` | 62.24146, 25.75498 | none yet |
| mid | Kouvola | `fi:KV` | 60.86561, 26.70459 | none yet |
| mid | Kuopio | `fi:KUO` | 62.89722, 27.67958 | none yet |
| mid | Lahti | `fi:LH` | 60.97647, 25.65740 | none yet |
| mid | Oulu | `fi:OL` | 65.01241, 25.48612 | none yet |
| mid | Pasila | `fi:PSL` | 60.19869, 24.93352 | yes |
| mid | Pieksämäki | `fi:PM` | 62.30125, 27.16753 | none yet |
| mid | Riihimäki | `fi:RI` | 60.73608, 24.78124 | none yet |
| mid | Seinäjoki | `fi:SK` | 62.79202, 22.84422 | none yet |
| mid | Tampere | `fi:TPE` | 61.49824, 23.77345 | yes |
| mid | Tikkurila | `fi:TKL` | 60.29217, 25.04406 | yes |
| mid | Toijala | `fi:TL` | 61.17061, 23.86090 | none yet |
| mid | Turku | `fi:TKU` | 60.45649, 22.26087 | none yet |
| mid | Vaasa | `fi:VS` | 63.09779, 21.62182 | none yet |

Platform register: the Digitraffic Infra-API platforms ("laiturit") and Väylävirasto's network statement 2027
(scope_FI.md §2). Write it as `vayla_platforms_FI.csv`, same columns. Helsinki and Pasila: the City of Helsinki's denser
lidar is allowed if its licence is open (check, scope_FI.md §1.5).

## Hand back

The same per-station folders as Sweden (`data/stations/research/<clack id>/`, safe ids with `_` for `:`), the country
CSV, a `REVIEW_platform_heights_<CC>.md` of laser-vs-register disagreements, and an updated
`HANDOFF_STATION_3D.md` section per country. Hand back after every 5–8 stations.
