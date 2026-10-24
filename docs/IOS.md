# Clack on iPhone

The iPhone app (`apps/Clack`, SwiftUI, iPhone only) is the only client of the Clack server. This file describes what
the native parts do: alerts, the Live Activity, ticket import, offline mode and the widgets. How the app was built is in
[SWIFT_PORT.md](SWIFT_PORT.md), what App Review needs is in [APP_STORE.md](APP_STORE.md), and the hosted server is in
[SERVER.md](SERVER.md).

Building and testing from the command line are in `CLAUDE.md`. To put a build on a phone (TestFlight, App Store
Connect, the Apple Developer Program) follow APP_STORE.md and Xcode's Product > Archive; raise the build number
(`CURRENT_PROJECT_VERSION`, the same on the `Clack` and `ClackWidgetsExtension` targets) for every upload.

## Alerts and Live Activities

All native Swift, in the same Xcode project.

- The server (`apps/server/src/push/`) watches every saved trip and sends: a departure reminder at the lead time chosen
  in Settings (off, 30 min, 1 h, 2 h, 3 h; default 1 h), platform announced or changed, delays of 5+ min,
  cancellations and short-turns (time-sensitive), changes between trains ("arrive platform 3, leave platform 5, 11 min
  to spare", tight or likely missed), "get off soon", and a welcome at the end of a whole journey. A `push_log` table
  keeps any alert from going out twice. Texts are in English and Swedish (`push/text.ts`).
- The app (`App/Notifications.swift`, Settings > Alerts) asks iOS for permission only when the person turns alerts on,
  tells the server the phone's Apple address (`PUT /api/devices`; removed with Delete my data) and opens the trip
  when an alert is tapped.
- The trip card (Live Activity: `App/LiveActivities.swift` and the `ClackWidgets` extension) shows the route, delay,
  next stop, platform and a line along the way, on the Lock Screen and in the Dynamic Island. The server updates it
  by push and, on iOS 17.2+, can start it itself half an hour before departure. Without push the app starts it.
- The capabilities Push Notifications, Time Sensitive Notifications and the App Group `group.com.garnerghering.Clack`
  are in `Clack.entitlements` (the paid Apple Developer team is active). Debug builds use Apple's push sandbox,
  TestFlight and App Store builds production; the app tells the server which.
- Push stays off until the key is in the server's `.env`: `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_PATH` (the .p8
  file, kept like a password) and `APNS_TOPIC=com.garnerghering.Clack` (docs/SERVER.md). The server logs
  `push: alerts on` or `push: alerts off (no Apple key in .env)` when it starts.
- Not built: walking times inside change alerts (the walk routing lives in the app) and quiet hours.

Guidelines to keep in mind: widgets and notifications must relate to the app (2.5.16); the app must work without
push permission (4.5.4); no marketing pushes without opt-in.

## Sharing a ticket to Clack

Clack is listed in the iOS share sheet for PDF files and emails (`CFBundleDocumentTypes` in `apps/Clack/Clack/Info.plist`,
rank Alternate). Tapping it opens Clack, which copies the file, reads it on the phone and shows "From your ticket": each
train found, ticked by default, and "Add N trains" saves them (`Logic/TicketReader.swift`,
`Features/Add/TicketImportSheet.swift`). The file is never sent anywhere or kept; only the trips you choose are saved.

- Read so far, from real documents: SJ ticket PDFs (Swedish and English, one train per page) and SJ receipts (no train
  number), also as an .eml with the PDF attached. Anything else says it couldn't read it and offers Add a train.
  Not yet seen, so not read: Wallet passes and other operators' tickets.
- A train is found in the timetable by its two stations, the date and the exact departure minute. The train number is
  only a tie-break: SJ's printed number can differ from the timetable's for regional trains (a ticket's 7225 was the
  timetable's 7205).
- Limit: iOS lists Clack for files, not for plain text, so share the PDF attachment, not the email's text.
- Debug: `-ticket <path>` opens a file as if it had been shared.

## Working offline

Live data is the truth when there is a connection; without one the app shows what it kept and estimates the rest, labelled
"estimated" (owner, 2026-10-24).
- **Kept on the phone** (`API/OfflineCache.swift`): trips, journeys, stations and their maps, operators, settings, the Passport (per year and
  setting) and whether the server has a basemap. While online the app fetches and **pins** the details of every trip running or leaving
  within 36 hours (`App/ArrivalWatcher.swift`), so they are not dropped by the 60-entry limit.
- **Estimated** (`Logic/OfflineEstimate.swift`, `Logic/Progress.swift`): when the phone is offline, or updates for a tracked trip stop for a
  minute, the Trips tab and the trip page work out status and progress from the stops it kept (or the leg's times alone), the last delays
  and dead reckoning from the last GPS fix. A trip that never went live is estimated too. With fresh server updates nothing is estimated.
- **Maps** (`Map/OfflineMaps.swift`): MapLibre's tile cache is 250 MB, and while online the map around each trip in the next 36 hours is
  downloaded (zoom 0 to 10, 9 for long routes). Settings shows how many are saved and can clear them.
- **Not kept:** station boards, search and live positions of other trains; the Live Activity can't receive pushes offline, so its line and
  countdowns run by themselves and it says "estimated" when it goes stale (5 minutes after the last push).

## Widgets

Five Home Screen widgets in `ClackWidgets`: Next journey (small, medium, large, and the three Lock Screen sizes), Passport (small,
medium, large, on the holographic foil), Departures (medium, large; the station is chosen in the widget's settings), Year in rail
(large) and Stats (medium, large; an arrow button flips between operators, train types, stations and countries).

- The app writes `WidgetSnapshot` (one JSON file) into the App Group container (`group.com.garnerghering.Clack`) after each refresh
  (`Widgets/WidgetFeed.swift`, at most every 5 minutes). The widgets read it and work out the rest from the clock, so they follow the
  journey with no connection. Where there is no container (the group missing from a build's entitlements) the widgets show invented
  sample data, each marked SAMPLE.
- `WidgetSnapshot.swift` exists twice, identical (`Clack/Widgets` and `ClackWidgets`). Tapping a widget opens `clack://trip/<id>` or `clack://journey/<id>`.
- Not checked on a device yet (unverified).

## Deep links (coming)

Today the app opens `clack://trip/<id>` and `clack://journey/<id>` (`RootView.openTicket`) and the share sheet for
tickets. The Passport and Departures widgets use `clack://tab/passport` and `clack://tab/explore`, but `openTicket` reads
every `clack://` link as a trip or journey id, so those two taps open a trip page that doesn't exist (a bug to fix with
the rest of the deep links; unverified on a device). More ways in (a train, a station or a board from a link, universal
links on the server's domain) are planned in a later workstream and are not built.

## Watch (coming)

An Apple Watch app is planned in a later workstream. Nothing is built yet.
