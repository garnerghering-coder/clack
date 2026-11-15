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

## Disruptions: track work, closed track, incidents (build 78)

`livemap/disruptions.ts`, in `/api/live/network` as `disruptions`, each source asked at most every five minutes:

| Country | Source | What counts | Where on the map |
|---|---|---|---|
| Sweden | Trafikverket `OperativeEvent` (ols.open 1.0), and the stretches whose trains carry the "Banarbete" notice (ANA003) in the next two hours | Events with a `TrafficImpact`, not ended; code 16 (Banarbete/transport) is track work, the rest incidents. An event with no end not updated for 24 h is taken as left open (one from May was still open in November). | `EventSection` from and to signatures → stations or Trafikverket locations → the track between |
| Finland | Digitraffic RUMA: `trafficrestriction-notifications?state=SENT`, `trackwork-notifications?state=ACTIVE` | Restrictions in force now (`CLOSED_FROM_TRAFFIC`, `CLOSED_FROM_ELECTRIC_ROLLING_STOCK` are a closed track, the rest track work); track-work notices with a part starting today | The notices' own track geometry |
| Norway | Entur SIRI-SX, the list the archive's 10-minute poll fetched (Entur rate-limits a second ask) | Open situations from a train operator (codespaces NSB, VYG, GOA, FLT, SJN) that name a station we know; Entur's own words make it a closure (Stengt, Buss for tog), track work (vedlikeholdsarbeid, sporarbeid) or an incident; planned ones from a day ahead | A pin at the station named most |
| Denmark | Rejseplanen `HimSearch` (the mgate backend, same request limit as the live map) | Messages whose own Danish words name a rail-replacement bus or no trains (closure) or track work (sporarbejde); lifts and station halls left out; daily windows kept | From and to stations → the track between |

## Not done yet

- Norway's and Denmark's reasons (above).
- Trafikverket's planned engineering works (only overrunning work is an OperativeEvent); RailwayEvent's reason codes
  are archived but not read.
- History: whether a corridor is slow every evening. The observed record has what's needed.
