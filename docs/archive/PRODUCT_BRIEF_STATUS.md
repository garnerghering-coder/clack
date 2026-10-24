# Product & UI/UX brief: status

Where each part of the "Rail App — Product & UI/UX Prototype Implementation Brief" stands in this codebase. The
owner chose to build this iteration in the existing web app, not native iOS. The server, the data and the rules
below are what a native app would reuse.

The owner also decided how trips are recorded: automatically when the evidence is clear, with a question when it
isn't (2026-10-21).

## Where things live

| Brief | Code |
| --- | --- |
| Landing resolver (§4) | `apps/web/src/landing.ts` (+ `landing.test.ts`); applied once per start in `components/AppShell.tsx` |
| Navigation (§3) | `components/AppShell.tsx`: Trips `/`, Explore `/explore` (`/live` redirects), Passport `/passport`; Settings via the gear on headers |
| Trips (§5) | `pages/TripsPage.tsx`: `Featured`, `NothingAhead`, `LegRow`, `ReviewCard`, `Following` |
| Explore (§6) | `pages/LiveMapPage.tsx`; follows API in `apps/server/src/routes/livemap.ts`, table `followed_trains` |
| Journey stages (§7) | `pages/TripDetailPage.tsx` stage card; connections in `components/Connection.tsx` + `connectionStatus` in `packages/shared/src/station.ts` |
| Trip records (§8) | `apps/server/src/legs/recording.ts` (rules + thresholds, `test/recording.test.ts`); `legs.ride`, `legs.ride_reason` |
| Passport (§9) | `apps/server/src/stats/passport.ts` (`computePassport`, `computeMilestones`, `reviewQueue`); `pages/PassportPage.tsx` |
| Share cards (§10) | `apps/web/src/share/shareCard.ts` (canvas renderer), `share/ShareSheet.tsx` (preview, save, share) |

## The rules, in one place each

- **Landing (§4):**
  - A train running now, or one leaving within `LANDING.attentionWindowMs` (3 h), opens Trips. Cancelled departures count.
  - Otherwise the app opens on the tab you used last.
  - Otherwise it opens on Explore.
  - This is decided once per app start (per browser tab session), only from `/`, and only if you haven't tapped or typed yet.
- **Trip records (§8):**

  | Status | When |
  | --- | --- |
  | `auto` | Trafikverket reported the train's actual departure where you got on and its actual arrival where you got off. These reports are matched by station, activity and minute, so they belong to this train. |
  | `confirmed` | You said yes, or you saved the trip after it had arrived. |
  | `review` | The train was cancelled where you got on or off, or the reports are partial or missing. The app waits `RECORDING.reviewAfterMs` (2 h) for late reports first. It asks straight away if Trafikverket's history no longer has the train. |
  | `not_taken` | You said no. |
  | `pending` | Everything before that. |

  - Your answers are never overridden by later data.
  - A train's position never counts as you being on it, and following a train never creates a trip.
- **Counted trips:**
  - Only `auto` and `confirmed` trips feed the Passport, its statistics, records, milestones and share cards.
  - Everything is derived on each request, so a correction changes the numbers at once and no counters can drift.
- **Connections (§7):**
  - "Easy" needs a walk from a station map, both platforms, and real-time times for both trains.
  - With an estimated walk or timetable-only times, the card shows the margin in minutes ("12 min margin"), not a verdict.
  - "Tight", "likely to miss" and "connection broken" still show, because they are warnings.
- **Explore data (§6.3):**
  - The counter says "trains running", not "live".
  - A position reads "GPS position" only while the fix is under 2 min old. After that it reads "GPS n min old", and trains without GPS read "Estimated position (no GPS)".
  - The map's status shows when data is loading, delayed, unavailable (after 20 s with no data), simulated, or when there are no trains in view.
- **Milestones (§9.3):**
  - Each family has fixed targets (`MILESTONES` in `stats/passport.ts`): journeys, km, stations, operators, countries, border crossings and night trains.
  - They are all-time and use counted trips only. Each records the trip that reached it, and the next three are shown with progress.
- **Share cards (§10):**
  - 1080 × 1350 PNG, with a preview before saving or sharing.
  - Four cards: Year in Rail, All-time, Featured Journey and Medal (one milestone as a token).
  - The map is a real one: an off-screen snapshot of the app's dark basemap and rail network with your routes, with a lines-only fallback.
  - Each card carries the medals that belong to it: that year's, all time, or the ones that trip earned.
  - Cards show distance, counts, time on board, operator and month and year.
  - They never include times, ticket details, train numbers or your current position.
- **CO₂:** you compare with flying, or a car of your choice (petrol or diesel, or electric).

## Acceptance checklist

**Navigation**
- [x] Trips, Explore, Passport are the primary tabs. Settings sits behind the gear on Trips and Passport, and at the foot of the desktop sidebar.
- [x] Landing follows the rules above and never switches screen while you're using the app.

**Trips**
- [x] The featured card is one tappable link, with a route map on top and the journey under it.
  - Upcoming: a route preview only.
  - Active: the train marker and the travelled split appear only with a fresh position.
  - Arrived: a static route and a Passport hint.
- [x] The featured trip isn't repeated in the list.
- [x] Empty, upcoming, active, cancelled and past states are designed.

**Explore**
- [x] Explore is one tap away. Clusters show at country scale and single markers with direction further in. Stations are squares.
- [x] Follow train and Plan a journey are separate actions. "In your trips" replaces Plan when the trip already exists. Closing the panel keeps the map where it is.
- [x] Missing or stale data is labelled, never shown as live.

**Journey lifecycle**
- [x] Planned, followed, pending, needs-a-check, counted and not-taken trips can be told apart.
- [x] Transfers are structured: legs grouped into journeys, with connection cards between them.
- [x] Connection advice is qualified, as described above.

**Automatic capture**
- [x] Following alone never creates a trip. Records are idempotent. Uncertain trips can be confirmed or corrected, and the correction can be undone.
- [x] Delays (actual arrival), cancellations, missing reports and transfers are handled.
- [n/a] Location-based tracking isn't built, so no permission is ever requested. The station map's "My location" asks only when you tap it.

**Passport**
- [x] Distance and journeys come first, then the map, milestones, collections, records, the log, and finally delays and CO₂ (with the method link).
- [x] Every statistic comes from counted trips. The empty state explains how trips get in.

**Share cards**
- [x] Year in Rail, All-time Passport, Featured Journey and Medal are all built, each with a preview, save and share. They cope with long names (shrink, then wrap) and a missing map (lines only, or a drawn motif).

**General**
- [x] Existing features kept. Tests cover:
  - landing rules
  - trip records and milestones
  - the follow API
  - connection statuses
  - the existing suites
- [x] Tap targets are at least 44 px, and the sheets sit above the tab bar and safe areas.

## Backend round (2026-10-22)

- **Older trips:** Swedish dates back to 2012-08-10 come from the Sverige 2 archive on demand (`import/history.ts`); Norwegian or anything else no timetable has can be added by hand (`POST /legs/manual`, `components/ManualTrip.tsx`).
- **Which train is yours:** the trip tracker takes a GPS fix only if it runs on the trip's date and is on or near its route (`pickFix` in `live/tracker.ts`); Norwegian trains are matched by Entur's service-journey id; a Swedish trip's Norwegian twin must share a stop at the same minute.
- **Search:** a route with no trains also tries the towns' other stations (Stockholm → Stockholm City for commuter trains); station rows no longer show Trafikverket codes.
- **Amenities:** Norwegian operators' typical amenities, each from the operator's own page.
- **Station maps:** Göteborg C and Malmö C added (Malmö's City Tunnel platforms from OSM layers, exits and lifts placed from Skånetrafiken's terminal map); walk steps name their level and switch the plan to it.

## Known limits

- **Native iOS:** not started, by owner decision. The web app installs to the home screen.
- **Explore search:** train numbers only find trains running right now, because they're looked up on the live map. Stations search the station index. Route search ("Göteborg → Stockholm") isn't on Explore yet; Add train covers it.
- **Followed trains:** kept for their operating day and the next, matched by train number and date. They don't follow a train across a change of number.
- **Featured map position:** the train marker uses the trip tracker's position. With an estimated position it says so; with no fresh position the card falls back to the route preview.
- **Share card maps:** they need the basemap download (first start). Without it they show the rail network and your routes on a plain background.
- **Matching:** uses Trafikverket for Swedish stops and Entur's Journey Planner for Norwegian ones (matched by stop place and minute). Other foreign stops (for example Kolding) have no reports, so such a trip shows as `partial_reports` and is asked about unless you saved it after it ran. SJ's own Stockholm–Oslo trains aren't in Entur's data, so their Norwegian stops have no reports either.
- **Norway:**
  - Journey Planner keeps actual times only for the day the train runs, so a Norwegian trip first seen later stays scheduled-only and is asked about.
  - Norwegian trips older than yesterday can't come from a timetable (Entur has no archive).
  - On the live map, a train without GPS is placed only when Entur sends a trip update for it (SJ Nord sent neither at night on 2026-10-22; to recheck in daytime).
  - CO₂ uses Sweden's factors until a Norwegian source is checked.
  - Train types are typical ones from the line and operator.
  - Go-Ahead's website refuses automated requests; its logo and amenities come from the owner (`data/logos/`, claims marked `via: "owner"`).
- **Station maps:** Stockholm C, Göteborg C and Malmö C. Malmö C has two levels (street and City Tunnel); no in-between floors are modelled and the escalator and lift times are estimates. Oslo S maps tracks as `platform_edge` lines, which the draft script doesn't read yet.
- **Archive timetables:** the first search in a new period downloads a ~50 MB snapshot (about half a minute); snapshots are kept in `data/cache/sverige2/`.
- **Accessibility:** large text sizes were checked by layout, not with a screen reader pass.
