# Positioning: how trains are placed, and how well

The live map's positions since build 54 (docs/buildout/BUILDOUT.md §A). Code: `apps/server/src/live/positioning.ts`
(the rules, pure), `live/locate.ts` (one place a train between two stops is worked out for every feed),
`live/placement.ts` (platforms and track points), `live/quality.ts` (the counters), and the feeds in
`apps/server/src/livemap/`. Tests: `apps/server/test/positioning.test.ts`.

## The model

Every train on the map carries, besides its position: `state` (`running` between `prevId` and `nextId`, `standing`
at a station, or `waiting` at its first stop before departure), `atStation` and `platform` when it stands,
`progress` (0–1 along prev → next) and, when the shown position was carried forward from a GPS fix, `fixAt` (the
fix's own time; `at` is then the time the position is for). `GET /api/live/segment?from&to` gives the track between
two ids (ours, or `trv:<signature>` for a Swedish location without one), the same polyline the server places the
train on. Apps from before build 54 ignore the new fields; the "moved" tuple grew from 7 to 9 entries at the end.

### Standing (§A.2)

A train stands when its feed says it has arrived and not left (Trafikverket's last report an arrival; Norway,
Finland and Denmark: now between the arrival and the departure at a stop), or when its GPS says it is slower than
3 km/h within 400 m of a station. It is drawn at its platform when the station has a map
(`data/stations/<id>.json`) and the feed names the track (Trafikverket `TrackAtLocation`, Entur's quay code,
Digitraffic `commercialTrack`, Rejseplanen's platform): the platform's middle node, turned back into WGS84. Without
a map, at the station's point snapped onto the nearest running track, so it sits on rails and not on the building.
With a fix and no mapped platform, the fix itself.

### Running (§A.3)

- **GPS:** the fix is projected onto the routed prev → next track when within 60 m (`snapToLine`); the heading is
  the track's direction there, towards the next stop. The position is carried forward along the track by the
  delivery lag (now − the fix's timestamp) at the fix's speed, never past the next stop (`advanceM`). A fix further
  than 60 m from the track is shown where it is.
- **No GPS:** a run profile instead of a constant fraction of the time: a trapezoid (accelerate at 0.5 m/s², cruise,
  brake at 0.6 m/s²) solved so the train reaches the *approach* (50 m short of the station) exactly at its expected
  arrival (`runProfile`, `estimateAlong`). The two accelerations are the plan's values, in the range of modern EMUs
  in service; they are not yet checked against a Trafikverket running-time rule, which Phase 3 (F4) does against the
  speeds the GPS feeds report.
- **Overdue:** past the expected arrival with no arrival reported, the train creeps the last 50 m over 90 s, then
  stands at the platform. Nothing freezes at 95% any more, in any country, and the estimate never steps back.
- **Stale GPS (2–30 min old):** the train is carried on along the track from the last fix at its last speed for up
  to 5 min (`DEAD_RECKONING_MS`), then blended into the estimate over 30 s (`blendM`) instead of jumping.
- **Before departure:** a Swedish train is drawn `waiting` at its first stop from 10 minutes before its advertised
  departure (`WAITING_BEFORE_MS`, a chosen window), on its platform when the announcement names the track. Norway
  and Finland keep their feeds' 2-minute window; the state is `waiting` there too.

### Line ends (§A.4)

Routed segments now start and end on the track at the stations (the snapped points), not at the station centroids.
The `track_segments` cache on the hosted server was cleared at the build 54 deploy so every pair is re-routed.
Oslo S – Bergen shortened by 528 m and Stockholm C – Göteborg C by 106 m from this alone.

### Parallel tracks (§A.5)

Where two running tracks lie within 12 m, the train is drawn on the one for its country's running side, given the
direction of travel (`pickTrack`): **Sweden left; Norway, Denmark and Finland right.** Sources (read 2026-10-28):
Wikipedia, "Left- and right-hand traffic", rail section ("Sweden … did not switch the direction of its trains, but
the line from the north of Malmö, which leads to the border with Denmark and further south uses RHT"; "In Finland,
several lines of Helsinki commuter rail, like the line to Helsinki Airport uses LHT, while the metro and the rest of
lines uses RHT"), and Norwegian Wikipedia, "Høyre- og venstrekjøring", Jernbane ("Norge og Danmark har høyrekjøring
og må bytte side nær grensen til Sverige"). The plan had Norway and Denmark on the left; the sources say right, so
the sources win. Where a source names an exception without saying exactly where it starts, the rule is off and the
nearest track is used: the Öresund link (Malmö C to the bridge) and the Helsinki commuter area (`SIDE_EXCEPTIONS`).
The quality counters record per country how often the raw fix lay nearer the chosen track than the other one; a
share well under one half means the rule is wrong there and should be turned off.

### Finland and Denmark (§A.6–A.7)

Digitraffic's `accuracy` is read and a fix worse than 200 m is dropped (`MAX_ACCURACY_M`; the count is on the
feed). Rejseplanen's positions are dated by the answer's own reference time (`posAt`), not by our poll, and put on
our track between the stop left and the next (snapped when within 60 m; never advanced, since Rejseplanen gives
no speed).

## GPS lag (§A.8)

Two numbers, per source, counted while the server runs (`live/quality.ts`; admin-only `GET /api/live/quality`;
saved to `data/cache/live-quality.json` every 5 minutes so a restart keeps the day):

- **Delivery lag:** receive time minus the fix's own timestamp, a histogram per source.
- **Timestamp offset:** whether the fix's clock is itself early or late. For each passage the feed reports to the
  second (Trafikverket `TimeAtLocationWithSeconds`, Digitraffic `actualTime`), the run of fixes is compared: an
  arrival with the fixes first coming within 150 m of the station's point (`crossingTime` in), a departure with their
  last leaving it (out), and a passage without a stop (Finland's non-stopping rows) with the closest approach
  (`passageTime`). Positive means the fixes' clock runs late. Norway's trip updates carry delays, not recorded
  times, so Norway has no offset measurement yet.

Correction: every fix is carried forward by the delivery lag plus `TIMESTAMP_OFFSET_S[source]`, which is 0 for all
four sources until the offset histograms have a week of data (Phase 3, F4). If the median offset turns out under
2 s for a source, only the delivery lag is corrected and this file will say so.

## The position check ("Measuring it")

Every GPS fix for a Swedish train that could also have been estimated is a sample: both rules, the old one (a
constant fraction of the time between the stops, capped at 95%) and the new one (the run profile), are worked out
at the fix's own time from the same announcements, and the distance from each to the fix is recorded, one sample
per train per minute, per product. For a train the feed reports standing at a mapped station with a track, the
distance from the platform point to the fix is recorded (standing placement). The CLI:

```
npm run import -- position-check --minutes=12                      # listen to Trafikverket here, then print
npm run import -- position-check --server=https://getclack.app --admin=TOKEN   # the hosted server's counters
```

## Numbers

### 2026-10-28, 23:08–23:20 CET, Sweden only, run on the owner's Mac (`position-check --minutes=12`)

Evening traffic: about 150 trains on the map at a time, 9 292 fixes accepted from 161 trains. Full tables are in
the command's output; the summary:

| What | Result |
|---|---|
| Delivery lag, Trafikverket (receive − fix timestamp) | median 7.8 s, p90 14.1 s (n 9 292); 16 fixes over 144 s |
| Timestamp offset, arrivals (first within 150 m vs `TimeAtLocationWithSeconds`) | commuter median +0.6 s (n 68); regional +0.7 s (n 64); spread wide (p90 15–49 s) |
| Timestamp offset, departures (last leaving 150 m vs reported departure) | commuter median +11.2 s (n 67); regional +10.7 s (n 63) |
| Position check, old rule → new rule, median (p90), metres | commuter 452 → 386 (1 191 → 1 133), n 173; regional 1 104 → 995 (4 370 → 4 552), n 518; night 2 786 → 2 332, n 57; high-speed 3 886 → 2 244 (p90 unchanged ~16 km), n 69; intercity 2 479 → 2 065, n 5 |
| Standing placement, platform point vs fix (mapped stations) | Stockholm C 15 m (n 1); Malmö C 193 m median (n 2); Hässleholm 269 m (n 3); Lund C 9 km median (n 12, see below) |
| Track side, raw fix nearer the chosen track than the parallel one, Sweden | 65% agree (2 922 vs 1 562) |

What this says, and what it doesn't yet:

- **The run profile is better than the constant fraction in every product's median** (12–40% smaller error), as
  the plan required before shipping. The p90s are about the same: the big misses are not about the shape of the
  run but about the inputs. The high-speed and night p90 of ~16 km means the segment or the times were wrong for
  some trains (a wrong `nextEta` after a skipped report, or a route through a different line); F4 should look at
  the worst samples by train.
- **Delivery lag is ~8 s** for Trafikverket, so the forward correction already moves a train at 160 km/h about
  350 m closer to where it is. **The timestamp itself looks right for arrivals (median under 1 s)**: the fixes
  reach the 150 m circle when the report says the train arrived. Departures read ~11 s "late", which is more
  likely the measure than the clock (the circle is 150 m from the station point, and a train leaving a long
  platform takes about that long to clear it). With under 2 s on arrivals, `TIMESTAMP_OFFSET_S` stays 0 for
  Trafikverket; F4 should repeat this with a week of data and a platform point instead of the station point.
- **Lund C's standing check is broken, not the trains:** 7 of 12 samples are over 3 km, which means the platform
  point and the fix are at different places. The cause is not investigated yet. Open: inspect those samples' train
  numbers and `TrackAtLocation` before trusting Lund C's platform placement. Hässleholm's and Malmö C's 190–270 m suggest the platform node (the middle of a 300 m platform) is
  far from where a short train actually stands; a platform *edge* and the train's length (F3's compositions) would
  place it better.
- **Track side: 65% agreement is not a clean yes.** Part of it is the measure (a 12 m rule applied to fixes with
  several metres of error, and single-track stations counted when a siding lies within 12 m), part may be real
  (right-hand running on some double-track stretches). Not enough to turn the Swedish rule off; enough to say the
  side choice is unverified until F4 checks it per line with a week of data. Norway, Finland and Denmark had no
  samples in this run (Sweden only).
- Nothing here is from the hosted server yet: it starts counting at the build 54 deploy, and
  `GET /api/live/quality` (admin) has the live numbers for all four sources from then on.

### 2026-10-29, hosted server at b6e4ac4, 07:28 to 12:14 UTC (4.8 hours, not days)

Read from a copy of `data/cache/live-quality.json` (`position-check --file=`; the admin route also wants a user id the
CLI does not send). The counters file was last saved 12:14 UTC and the server was not asked again; `since` is
07:28 UTC, not the 06:48 first thought. Everything here is a few hours of one day: read it as a first look.
Rejseplanen (Denmark) has no delivery or passage samples at all, and Entur has delivery only (no passage offsets);
Digitraffic and Trafikverket have both.

| What | Result |
|---|---|
| Delivery lag (receive − fix time), median (p90), n | Trafikverket 6.9 s (12.4), 30 260; Digitraffic 4.6 s (7.6), 15 475; Entur 17.7 s (28.1), 3 559; Rejseplanen none |
| Offset, passing without a stop (the cleanest measure; Digitraffic only) | commuter 0 s (n 143), intercity -1.8 s (n 72), high-speed -2.5 s (n 49, p90 28: thin) |
| Offset, arrivals (first within 150 m vs reported) | Trafikverket commuter +2.8 s (n 140), regional +2.1 s (213), intercity +8.8 (11), high-speed +2.7 (9); Digitraffic commuter -25.6 s (176), intercity -25.1 (15) |
| Offset, departures (last leaving 150 m) | Trafikverket commuter +15.9 s (147), regional +11.6 (193); Digitraffic commuter +15.3 (170) |
| Position check, old rule → run profile, median (p90), metres | commuter 649 → 521 (1 998 → 1 909), n 533; regional 1 319 → 1 091 (5 302 → 5 285), n 2 027; intercity 2 746 → 2 508, n 205; high-speed 3 231 → 2 797 (p90 ~15.4 km both), n 398; night n 1 (too thin) |
| Standing placement, platform point vs fix, median metres (n) | Lund C 120 (22), Jönköping C 74 (13), Stockholm C 177 (12), Malmö C 193 (19), Helsingborg C 5 (3), Växjö 69 (4), Hässleholm 931 (4), Alvesta 499 (6), Katrineholm C 287 (8); under 5 samples is too thin |
| Track side, share where the raw fix lay nearer the chosen track | SE 68% (10 039 vs 4 619), NO 64% (1 828 vs 1 033), FI 61% (2 156 vs 1 392), DK 42% (1 897 vs 2 576) |

What was decided, and why:

- **Timestamp offsets stay 0 for all four sources.** Trafikverket's arrival medians (+2.1 to +2.8 s) clear 2 s on
  paper, but the p90 is 30 to 43 s, so the median's own uncertainty is about 2 s: not distinguishable from 0. The
  arrival and departure rows measure the 150 m circle as much as the clock (Digitraffic arrivals read -25 s, because
  Fintraffic reports arrival at standstill, after the train has crossed the circle; departures read +12 to +16 s for
  the reverse). Digitraffic's passes, which have no stop to confuse them, read 0 and -1.8 s: the timestamp is
  right. Trafikverket has no passes in the counters; adding a pass measure for it (a `Passage` row) would settle it.
  Entur and Rejseplanen have no samples.
- **Accelerations (0.5 and 0.6 m/s2) are unchanged.** The data does not measure acceleration. The run profile beats
  the constant fraction in every product (median 5 to 21% smaller, p90 about the same); that supports having the
  profile, not a change of its constants.
- **The Lund C 9 km was not the station id; it was which fixes were counted.** The standing check took any fix of a
  train whose last report was an arrival, with no check that the fix came after the arrival or that the train was
  still: a fix from the approach, or from a train that had left whose departure report was late, was measured against
  the platform. Now only a fix at or after the arrival report with a speed under 3 km/h counts (`countsAsStanding`).
  In this window Lund C already reads 120 m median (p90 235, 1 of 22 over 3.2 km), but Alvesta (p90 79 km),
  Hässleholm, Katrineholm C, Malmö C (p90 16 km) and Kristianstad C still show the same far outliers, which this
  fix should remove; check after the next deploy.
- **Denmark's side rule is off.** 42% agreement over 4 473 samples is below the 50% of a coin flip, so the sources'
  "right" does not fit this feed (the fix may be coarse, or the track data may be wrong there). `RUNNING_SIDE.DK`
  is `null` and the nearest track is used. Sweden (68%), Norway (64%) and Finland (61%) are above chance but well
  short of clean; left as they are. The samples are one morning; the earlier Sweden-only run read 65%. Sweden's
  Öresund and Finland's Helsinki areas are already excepted.

Needs more days of data: a weekday-and-weekend week of Trafikverket and Digitraffic offsets (and a Trafikverket pass
measure); any Entur and Rejseplanen offsets; high-speed and night position checks (the p90 of ~15 km is bad inputs,
not shape); per-line track side for Norway and Finland, and why Denmark disagrees; the Alvesta-type standing outliers
after the fix.
