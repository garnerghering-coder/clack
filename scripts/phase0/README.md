# Phase 0 scripts

One-off data-verification tools behind [`DATA_FINDINGS.md`](../../DATA_FINDINGS.md). Plain Node ESM (Node 22+)
with no npm dependencies, plus two small Python tools that need `pip install osmium matplotlib`.

Keys come from `.env` at the repo root (see `.env.example`). Behind an HTTPS proxy, run Node with
`NODE_USE_ENV_PROXY=1` (Node's `fetch` ignores `HTTPS_PROXY` otherwise). Downloads and intermediate files go to
`data/cache/` (gitignored).

Run in this order:

| Step | Command | Notes |
|---|---|---|
| Trafikverket history window (Q1) | `node scripts/phase0/trv-history-window.mjs 423 523` | |
| Download GTFS Sweden 3 | `node scripts/phase0/download.mjs se3` | **Uses quota.** Refuses if < 20 h since the last download (`--force` overrides). Logs to `data/cache/downloads.log` |
| Extract rail subset | `node --max-old-space-size=8000 scripts/phase0/gtfs-extract-rail.mjs` | ~2.5 min; writes `data/cache/phase0/*.json` |
| Trafikverket reference data | `node scripts/phase0/trv-fetch.mjs stations` and `… ann 2026-10-19` | Use dates inside Trafikverket's ~4-day window **and** GTFS Sweden 3's window |
| Train-number fields (Q2) | `node scripts/phase0/q2-train-numbers.mjs <dates…>` | Which GTFS field holds the number |
| Trip matching (Q2, final) | `node --max-old-space-size=8000 scripts/phase0/q2-match.mjs <dates…>` | Station+time matching; needs `trv_ann_*` for neighbouring days and the station mapping |
| Station mapping (Q3) | `curl -o data/cache/sv2_extra/trafikverket_stops.txt https://api.trafiklab.se/v2/samtrafiken/gtfs/extra/trafikverket_stops.txt` then `node scripts/phase0/q3-station-mapping.mjs <dates…>` | Writes `data/station_mapping.draft.csv` |
| Historical stations (Q3) | `node scripts/phase0/q3-historical.mjs <sv2 zip…>` and `node scripts/phase0/q3-riks-stability.mjs <newest zip> <older zip…>` | |
| Sverige 2 snapshots (Q4) | download from `https://data.samtrafiken.se/trafiklab/gtfs-sverige-2/YYYY/MM/` (keyless), then `node scripts/phase0/q4-sverige2-inspect.mjs <zip…>` | |
| Archive survey (Q4) | `node scripts/phase0/q4-archive-survey.mjs [--windows]` | Lists all snapshots; `--windows` downloads one per year (~800 MB total, deleted after reading) |
| Categories (Q5) | `node scripts/phase0/q5-categories.mjs 2026-10-19` then `node scripts/phase0/q5-classify.mjs 2026-10-20` | `q5-classify` runs `data/category_overrides.json` |
| GTFS timetable window | `node scripts/phase0/q-se3-window.mjs` | |
| Shape stats (Q6) | `node --max-old-space-size=8000 scripts/phase0/q6-shape-stats.mjs` | |
| OSM rail graph (Q6) | download `https://download.openstreetmap.fr/extracts/europe/{sweden,denmark,norway}-latest.osm.pbf`, then `python3 scripts/phase0/osm_rail_extract.py data/cache/osm/sweden-latest.osm.pbf data/cache/osm/denmark-latest.osm.pbf data/cache/osm/norway-latest.osm.pbf` | ~15 min for all three |
| OSM routing test (Q6) | `node --max-old-space-size=8000 scripts/phase0/q6-osm-route.mjs 2026-10-20` then `python3 scripts/phase0/plot_route_sample.py` | |

Shared modules: `lib.mjs` (.env, Trafikverket client), `gtfs.mjs` (streaming GTFS reader), `p0data.mjs` (loads the extracted rail subset), `geo.mjs` (distance, name normalisation).
