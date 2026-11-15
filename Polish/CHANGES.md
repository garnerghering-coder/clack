# Polish pass 1: what changed

Branch `polish/pass-1`, from build 70 (`ae6bd5d3`) to **build 75**. There are 25 commits; nothing is pushed.

- `Polish/AUDIT.md` is the audit.
- `Polish/DECISIONS.md` has every change with its before, after, how and how to undo it, as you asked.
- `Polish/before/` and `Polish/after/` hold the same 39 screens under the same names.
- `Polish/after/matrix/` holds the device and accessibility checks.
- `Polish/compare/` holds the map-colour A/B.

## The five changes that matter most

1. **Failures stop pretending to be facts.**
   - The app used to report a network failure as:
     - "This train isn't running";
     - "No trains in this window";
     - a journey "not found", or a followed journey "ended";
     - "No map for this station";
     - "Couldn't save: <raw English error>".
   - Every surface now separates *empty* from *couldn't reach the server*. It says which, and offers Try again.
   - Taps that did nothing now answer: deleting, following, favouriting, the ride check, adding a suggested train.

2. **Nothing jumps and nothing holds you.**
   - Cold starts flashed white, because the launch colour lived in the package. Now they are yellow from the first frame.
   - The splash waited for the server, up to about 15 s on a train's connection. It now ends in about half a second or at a tap, at most 1.2 s.
   - Trips, settings and reference data paint from the phone's saved copy first, with "Updated 12 min ago".
   - The Add sheet's confirm step held no place for its map, so the main button moved about 100 pt under a finger. That place is held now.
   - Placeholders have the shape of what replaces them.

3. **Your two bugs.**
   - **The map stayed tilted:**
     - A gesture during the flatten animation left the camera half-tilted, with nothing to correct it.
     - While tilted, the detail check measured the horizon, so leaving the station never flattened the map.
     - Now the real pitch is checked at every view change, and the check uses the map's centre while tilted.
   - **Station-map clusters never split:**
     - A fixed 26 px grid merged places on one spot for ever, and their badges piled up.
     - Now pins are kept 40 pt apart by distance. Places that share one spot open a list ("4 places here").
     - Filtered-out places no longer count.

4. **Trips and journeys as the designer asked.**
   - One scroll with no Upcoming/Past: your train or the next one, then "Next", then history by month, each month with its totals ("7 trips · 1,664 km").
   - A journey is one compact row. Its page is one line of numbers and one rail with the changes between trains.
   - Swipe and hold offer the same actions, Share then Delete.
   - A trip zooms out of its card.
   - A new trip settles into its place.
   - iOS reopening the app brings back the same tab and screen.

5. **One system underneath, and medals that mean something.**
   - **Tokens:** spacing, motion and haptics are tokens. 830 hand-typed spacings became the `Space` scale, and the lint now enforces it.
   - **Motion:** about 20 animation curves became four.
   - **Haptics:** each has one meaning.
   - **Look switches:** your choices are one-line switches in `Look.swift`.
     - One yellow thing per screen.
     - Solid buttons in content, glass only on bars and over maps.
     - System switches.
     - Grey platform tags.
     - System sheets.
   - **Medals:** they have one metal language (bronze a first step, silver a regular, gold dedicated, platinum exceptional), with a legend. There are 17 new families (from early bird to the Moon) and a "2026 in rail" recap.

## Screen by screen

The tables give one line per change and its reason. The full before, after, how and undo for every row is in `DECISIONS.md`, under the ID shown.

### Launch and first run (before/after 01, 02)
| Change | Why |
|---|---|
| Launch screen yellow from the first frame (P1.1) | It flashed white, then yellow |
| Splash ends at about 0.5 s or on a tap, at most 1.2 s; saved settings paint first (P1.2, P1.3) | It held the app until the server answered |
| The landing rule works again (P1.5) | It never ran: the first appearance counted as a touch |
| Suggestions: row-shaped placeholders, Try again, the "Near you" sentence before iOS asks, failures said (P1.6–P1.9) | Grey boxes, silent failures, an unexplained prompt |

### Find a train (03, 04, 33, 43, 52)
| Change | Why |
|---|---|
| The confirm step holds the map's and stops' places (P2.1) | The user test's ~100 pt jump |
| Times never wrap; cards stack at AX sizes (P2.6) | "07:2 / 2" at AX3 |
| One VoiceOver sentence per result; the press style (P2.7, P2.8) | Read in pieces; a faint dim |
| Unpickable stops dimmed and disabled (P2.4) | They looked like the others and did nothing |
| One scrolling row of filter chips in both languages (P2.10) | It wrapped in English and was cut in Swedish |
| Main buttons pinned on every step; system sheets with detents (P2.14, P2.12, L5) | Under the keyboard; clipped at AX sizes |
| A real example as hint text; a ticket-share line (P2.17, P2.18) | The test asked for both |

### Trip detail and arrival (07, 08, 09, 41, 51, 61, 20)
| Change | Why |
|---|---|
| The platform is a grey tag on split-flap tiles; a change flips with one tick (B71.19) | The yellow tag looked tappable and did nothing (signature moment 2) |
| The time block reads as one sentence; it flips and ticks on a live change (B71.20) | VoiceOver read "DEPARTURE", "Platform 3", "+4", "08:07" |
| The status is said once (B71.21) | "Upcoming" over "Departs in…"; "Arrives" twice |
| Countdowns roll; a cancellation buzzes once; failures say so (B71.22–24) | Jumps; no warning; silent failures |
| VoiceOver reaches Follow; the route draws in 0.6 s (B71.26) | Unreachable; 1.2 s |
| Arrival names wrap by word; one haptic (B71.27, H) | They ran off the screen; two haptics in a second (signature moment 5) |

### Trips (05, 06, 30, 40, 50, 60)
| Change | Why |
|---|---|
| One scroll; compact journey rows; month totals (B72.1–4) | The designer's redesign |
| Swipe (iOS 27) and hold: Share, Delete; delete at once, rolled back if refused (B72.5, B72.6) | Your choice; the row waited and failed silently |
| Saved list first with its age; honest failure line (B72.7) | Skeletons for up to 15 s; "Couldn't load" over a full list |
| Zoom transition; a new trip settles into place; restoration (B72.10–12) | Signature moment 3; lost place after iOS closed the app |

### Journey (10)
| Change | Why |
|---|---|
| One line of numbers, one rail (B72.13) | Four tiles plus a bar said the same things twice |
| A 404 means "not found"; any other failure gets Try again; pull to refresh (B72.14) | Offline read as "not found" |

### Passport (11–14, 31, 44, 62)
| Change | Why |
|---|---|
| The on-time bar and number use one rule; a small sample leads with its size (B71.6) | 67 % over a bar saying 50 % |
| CO₂ per country with sources, the method on the card (B71.7) | Danish diesel counted at Sweden's hydro figure |
| One metal language and 17 new medal families (B74.1, B74.2) | Your request |
| Breakdown without repeats; the top five stations as rows (B74.3, B74.4) | It repeated the card; chips looked like filters |
| Medals new since the last visit stamp in; numbers roll with the year (B74.5, B74.6) | Signature moment 4; a cover that said "2025" over all-time numbers |
| "Your 2026 in rail" (B74.8) | The designer's recap |
| No more scrolling under the clock (B71.3) | Content collided with the status bar |

### Explore, station card, Network, station map (15–18, 32, 63)
| Change | Why |
|---|---|
| The tilt fix; distance-based clusters (B71.1, B71.2) | Your bugs |
| One line of credits; full credits behind ⓘ, checked against each licence (B71.5, `docs/ATTRIBUTION.md`) | Three lines above the tab bar |
| Operator colours kept (your choice); a "Late" option added; the location dot is blue (B73.1, B73.2) | The A/B comparison; yellow meant too many things |
| Opens on your next route or your location (B73.6) | Four countries, most of the screen empty |
| The station card is the board in place, countdown first, your visits (B73.7) | It was a signpost |
| The train sheet leads with live facts; one "Add to trips" with Follow in `…` (B73.3, B73.4) | Your choice; two similar buttons |
| Network is a system sheet over a status map, with meters (B73.10) | A dropdown covering the map |
| Station map: essentials first, closed places hidden, floors as a column, notes behind ⓘ, the station's own time zone, readable hours (B73.8, B73.9, B71.11, B71.17) | About 40 dimmed icons; Stockholm time in Finland; raw OSM hours |

### Settings (19, 42, 53)
| Change | Why |
|---|---|
| System switches; one-step export; failures said; values wrap (B75.1–4, V.1) | 15 yellow switches; two-step export; silent delete failure; "From your fir…" |

### Widgets, Live Activity, Siri (21, 22)
| Change | Why |
|---|---|
| Tabular, rolling digits; one VoiceOver sentence on the Lock Screen card; an honest widget error; operator-coloured progress (B75.5–9) | Consistency with the app |
| "When's my train in Clack" (B75.10) | The designer's Siri idea |

### Across the app
| Change | Why |
|---|---|
| The `Space`, `Motion` and `Haptic` tokens; the lint enforces them (T1–T3) | 830 literals, 20 curves, haptics with mixed meanings |
| `Look.swift` switches L1–L5 | Your look choices, each one line to undo |
| One word per thing (`docs/WORDLIST.md`) | Find your train / Find a train / Add train; operatör / bolag; Retry |
| "+4 min", "+1 d", "2 h 48 min" in Swedish, "Platform 9" not "— → 9" (B71.8–13) | Units and copy leaks |

## Left alone, and why
- **"Front train" and "Next departure":** these are Trafikverket's own notice texts (codes ANA022 and ANA039). Rewording them would be guessing.
- **"Normal" and "Normalt":** both are correct Swedish, agreeing with different words (see `WORDLIST.md`).
- **Fonts:** Inter for text, Space Grotesk on the tiles, and Plex-Mono-style outlines in the wordmark. The code was right.
- **Scroll position and an open sheet are not restored.** The open screen is.
- **Network:**
  - "Your trips today: affected" isn't built.
  - Incidents aren't merged by area.
  - There are no numbered pins on the track.

  These need new logic on top of the server's data.
- **Station map:**
  - Platform numbers aren't always on.
  - There's no lighter concourse and no named entrances.

  These depend on each station's data.
- **Explore's clustered dots at country zoom and bigger dots from zoom 9:** these need feel on a device. The 44 pt hit box stays.
- **The trip detail's four one-second clocks:** not batched yet; that waits until Instruments shows what they cost.
- **The tip-tap of the flap is the system's light impact,** not Core Haptics, so there's no Haptics switch in Settings.

## Instruments numbers

**Not measured.** I could not run Instruments in this environment: `xctrace` is denied its own temporary folder, even outside the command sandbox. No numbers are made up here. To measure on your phone:
1. In Xcode, run **Product › Profile** (⌘I) on your iPhone.
2. Choose **SwiftUI**, then repeat with **Animation Hitches**.
3. Record each of these for 15 s:
   - Trips, a fast scroll to the bottom and back (58 trips is a good load);
   - Passport, a scroll and a change of year;
   - Explore, panning at country zoom and at zoom 14+.
4. Note the hitch ratio (ms/s) and the view-body updates per view.

The hotspots the audit expects, from reading the code:
- `ExploreModel.render` at 10 Hz from zoom 14;
- `BoardLogic.page` each second;
- Trip detail's per-second ticks.

## Needs Garner
1. ~~**Push, then update the hosted server.**~~ Done 2026-11-15: the server runs `polish/pass-1`. The medals, CO₂ per country and punctuality bands are server changes. Until the server is updated, the app shows the new medal families as locked and Danish CO₂ at the old figure.
2. ~~**Trafikverket's API licence.**~~ Answered: no credit needed. It isn't recorded in the app's sources. If it requires a visible credit, add "· Trafikverket" to the map's line (`docs/ATTRIBUTION.md`).
3. ~~**One exception to "every string in ClackKit's catalog".**~~ Answered: keep it; CLAUDE.md now says so. App Intents read titles only from the app's own bundle, so the Siri shortcut's title and description are in `apps/Clack/Clack/Localizable.xcstrings`, and its phrases are in `AppShortcuts.xcstrings`. OK to keep, or should CLAUDE.md say so?
4. ~~**Denmark's CO₂ figure.**~~ Answered: an estimate is fine; 42 stays. I used 42 g/pkm, the low end of the ministry's 42–132 g range for diesel regional trains, as the estimate for non-S-tog DSB trips. A higher figure would be more cautious.
5. **Medal tiers.** Which levels are bronze, silver, gold or platinum is my judgement (`MILESTONE_TIERS`). Have a look.
6. ~~**The "Late" colour option**~~ Answered: keep it. on Explore is new, a by-product of the A/B. Keep it, or remove it (one line in `ColorBy`)?
7. **The designer's remaining items**, for a later pass:
   - "your trips affected" on Network, incidents merged, numbered pins;
   - platform-first station maps;
   - Explore clustering.

## On your phone: what to try (I can't feel haptics or judge 120 Hz in a simulator)
1. **Cold start:** close Clack fully and open it. The screen should be yellow from the first frame with no white. Tap the splash: it should go at once.
2. **The clack (signature 2):** open a trip that's live. When its time or platform changes, the changed tiles should flip and you should feel one light tick. Nothing should tick on opening the trip.
3. **Adding a train (signature 3):**
   - Trips › **+** › add any train, then close the sheet. The new row should settle into place with a small bounce.
   - You should feel one success haptic, on Add only.
4. **The stamp (signature 4):** earn a medal (add a past trip that crosses a threshold), then open **Passport**. Only the new medal should press in, with one success haptic.
5. **Arrival (signature 5):** at the end of a journey you should feel one soft tap, or success if a medal came with it, never two.
6. **Haptics that should *not* happen:**
   - Opening a station you've favourited.
   - Returning to Explore.
   - A successful delete.
   - Scrolling.
7. **Tilt:**
   1. Zoom into Jönköping C or Stockholm C on Explore until it tilts.
   2. Pinch out quickly while it's flattening: it should end flat.
   3. Tilted, pan away from the station: it should flatten.
8. **København H station map:** zoom fully in. Any count bubble should either split or open a list ("4 places here"). Bubbles should never overlap.
9. **Swipe on Trips (iOS 27):** swipe a trip left for Share and Delete. Long-press: the same, in the same order.
10. **Zoom transition:** tap a trip card. It should zoom open; swipe back from the edge, or down, and it should zoom back into the card.
11. **Restoration:** open a trip, lock the phone, and open many heavy apps so iOS closes Clack. Reopen it: you should be on the same trip.
12. **Siri:** say "When's my train in Clack". In Swedish: "När går mitt tåg i Clack".
13. **Reduce Motion** (Settings › Accessibility › Motion): the flap should swap without flipping, cards shouldn't zoom or shrink on press, and the map shouldn't animate its tilt.
14. **Reduce Transparency and Increase Contrast** (Accessibility › Display & Text Size): check that the tab bar, the map buttons and the segmented switches stay readable. I could only set Increase Contrast in the simulator (`after/matrix/17pro-contrast-*`).
