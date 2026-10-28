# Network status

Explore's network status (the pulse button beside the filters) answers "where is the network struggling right now?".
It is read off the live map, so it is as fresh as the map and costs nothing extra to run.

## What it shows

- **Per country:** how many trains on the map are 10 or more minutes late, of how many running.
- **Where it's slow:** corridors where most trains are late. Each train's last stop and next stop name the stretch it is
  on (both directions count as the same track). A stretch is flagged when at least 2 trains are on it and more than
  half of them are 10+ minutes late. Flagged stretches that share a station are joined into one corridor
  ("Hässleholm C – Lund C – Malmö C"). Tapping one fits the map to its late trains.
- **Late trains:** the 12 most late trains outside the corridors, each with the stretch it is on and its reason. On a
  calm day this list is the whole story.
- **Reasons:** only what a feed states, translated with the delay-cause table (`data/delay_causes.json`). With none,
  the panel says "No reason given yet".

Thresholds live in `apps/server/src/livemap/network.ts` (`LATE_MIN`, `MIN_TRAINS`, `LATE_LIST`). Endpoint:
`GET /api/live/network`, worked out at most every 15 s.

## What each country publishes, and what is used

| Country | Delays | Reasons | Used now |
|---|---|---|---|
| Sweden | Trafikverket TrainAnnouncement, every stop | `Deviation` codes and texts per stop ("Signalfel", "Olycka") | Delays and reasons at the last and next stop |
| Norway | Entur SIRI-ET (trip updates) | SIRI-SX situations, archived, but linked to lines and stops rather than trains | Delays only; linking situations to stretches is next |
| Finland | Digitraffic live trains | Cause codes on the rows passed (`causes`, category codes) | Delays and reasons |
| Denmark | Rejseplanen journey positions | Rejseplanen HIM messages, per journey | Delays only; HIM messages are next |

## Not done yet

- Norway's and Denmark's reasons (above).
- Disruptions with no trains moving (a closed line shows no trains, so no corridor): Trafikverket's
  TrainMessage/OperativeEvent and Entur's situations describe those, and could be shown as their own list.
- History: whether a corridor is slow every evening. The observed record has what's needed.
