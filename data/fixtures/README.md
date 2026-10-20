# Test fixtures

Real data saved for tests, mostly because Trafikverket deletes everything after ~4 days.

## `trv/2026-10-20/` — sample trips (captured with `scripts/fixtures/capture-trv.mjs`)

| File | Trip | Why it's a useful test |
|---|---|---|
| `train-306.json` | **Snälltåget 306, Kolding (DK) 13:01 → Nässjö**, scheduled 18:25, arrived **19:04** (+39), track 4, "Spårändrat" | Cross-border: GTFS has the full Padborg → Kolding → … → Stockholm run, but Trafikverket only has the Swedish stops (from Malmö C). The Kolding departure has no actual time, so the leg is partial. |
| `train-7256.json` | **Västtågen 7256, Nässjö 19:20 → Jönköping** (scheduled arrival 19:51) | Ordinary regional leg ending mid-route. First captured while the train was running; re-captured the next morning. |
| `train-3940.json` | Snälltåget 3940, Malmö → Stockholm the same morning | The Swedish continuation of the Berlin night train (GTFS `10300`): a number change mid-journey. |

Each file holds every `TrainAnnouncement` row, including non-advertised passage points, with `captured_at`.
