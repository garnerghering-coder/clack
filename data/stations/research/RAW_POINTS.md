# Where the laser points are

Each pack's `<slug>_laser_station_<year>.laz` (the clipped point cloud, trains as class 64) is **not in git** (owner,
2026-10-30: 687 MB, one file over GitHub's 100 MB limit). They are kept on the owner's Mac in the git-ignored
`data/research-raw/<pack folder>/`, under the same name as the pack's README lists. Everything the app uses (structures with
heights, the ground GeoTIFF, register lines, `station_facts.json`) is in git; the points are only needed to rebuild a pack
(`scripts/stations/station3d/run_station.sh`, and the Norwegian and Finnish builders). Back up `data/research-raw/`.

Swedish packs committed before 2026-10-30 still have their `.laz` in git history (removed from the tree then).
Licences as in each pack: Lantmäteriet (CC BY 4.0, GDPR terms), the City of Helsinki and NLS (CC BY 4.0), Kartverket
(CC BY 4.0).
