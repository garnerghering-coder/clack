# Design reference: follow Flighty very closely

The owner wants the app to look and feel almost identical to Flighty (decided 2026-10-20). Screenshots are in
[`reference/`](reference/). **They are Flighty's artwork: keep them out of any public repo, and before public
launch review the design so it's "in the style of", with our own name, icon and colours.**

## Structure (every main screen)

- **Full-screen map behind everything** (satellite-like terrain, dark blue sea). Round black buttons with white icons
  stacked top-right (globe / layers / tower).
- **Bottom sheet** over the map: `#18181a`, top corners ~40px radius, starts ~43% down and can be dragged up.
- **Sheet header:** huge heavy title (SF Pro, weight 800–900, ~44px) left. Right: a round outlined share button (thin
  light border, dark fill) and an initials avatar (lavender `#ab98f0` circle, white bold initials).
- **Floating tab bar** inside the sheet bottom: capsule `#101010` with a thin light border. Items have an icon over
  a bold small label. The active item sits on a `#313131` pill, with icon and label tinted `#9de3ff`. A separate
  round search button (same style) to the right **opens Add**.

## My Flights → My Trips list

- **Left column:** big bold countdown number (~48px, white) over a small caps grey label `DAYS` (`#8c8b8e`).
- **Right column:**
  - Line 1: tiny operator logo, then train number in grey (`BA 809` → `SJ 523`); date right-aligned in grey (`Sat, Dec 19`).
  - Line 2: bold title `Copenhagen to London`, with "to" in a lighter weight.
  - Line 3: departure icon (grey circle, arrow up-right) + `CPH 12:20`, then arrival icon (arrow down-right) + `LHR 13:30`. `+1` is superscripted for next day. Code in grey, time in white, semibold.
- **Connection row** between legs of a journey: `2h 55m at LHR` left, `🚶 Relaxed ›` right. Thin separators start at the
  right column, not the screen edge.

## Add Flight → Add Trip

- Full-height sheet. Huge title `Add Flight`, grey semibold subtitle `Enter airline, airport, or flight`, and a round outlined
  close (X) button.
- **Search field:** `#26282c`, radius ~20px, ~56px tall, bold placeholder in grey with examples (`SAS, CPH, or SK123`
  → e.g. `SJ, Göteborg, or SJ 523`).
- **Section headers:** caps, semibold, letter-spaced, `#acacb0` (`FREQUENTLY USED`, `MORE`).
- **Rows:**
  - Leading round icon (airline logo / circular country flag), then a bold white title.
  - A grey subtitle with bullets (`CPH • EKCH • Copenhagen`).
  - Optional trailing outlined rounded-rect arrow button.

## Passport

- **Year chips:** `All-Time` selected (outlined pill, dark fill), others plain grey bold text; horizontally scrollable.
- **Card:**
  - Indigo gradient (`#10125c` → `#0a1d6b`), radius ~28px.
  - Title in uppercase, light and slightly condensed with wide tracking (`ALL-TIME FLIGHTY PASSPORT`), plus a small caps line with a passport icon (`PASSPORT • PASS • PASAPORTE`). A share icon sits top-right.
  - **Stats:** caps lavender labels (`FLIGHTS`, `DISTANCE`, `FLIGHT TIME`, `AIRPORTS`, `AIRLINES`), huge heavy white values (`72`, `103,332 mi`, `10d 12h`) and lavender sub-labels (`16 Long Haul`, `4,1x around the world`).
  - **Button:** translucent `All Flight Stats ›` (`#33488c`-ish). Further cards (red gradient) stack below.
- **Full-screen passport:**
  - Violet background `#1d015c` → `#160042`. Round dark close and share buttons, centred bold title, year tabs (selected `#371a78` rounded rect).
  - A ticker strip of plane icons and airport codes.
  - World map: continents `#6900fe` on `#28017e`, routes as white curved arcs, stations as orange/yellow dots.
  - A row of overlapping circular country flags, then a dashed divider.
  - Stats in a lighter weight with big numbers, then a passport-style **machine-readable zone** in monospace (`ALLTIME<<NAME<SURNAME<<MEMBER07JAN26<<…`), and a chevron down.

## Train adaptations

- Flighty's airport codes (CPH/LHR) become station short codes or short names. **Open question for the owner** when
  building the list (step 7): Trafikverket signatures (`Cst`, `G`) look like codes but most people don't know them.
- Airline logo → operator brand logo/badge (spec §18). Country flags for foreign stations.
- "Friends" is out of scope for Phase 1, so the tab bar has My Trips + Passport, with the avatar opening Settings.
