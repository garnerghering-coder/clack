# Changes after the user test of 2026-11-07

App version after this pass: **1.0 (build 59)**. Server changes are in `apps/server` (deploy with the usual pull + restart). Every merged finding of `report.md` has an entry below, in report order.

## Summary

**Counts by status (96 merged findings):** Fixed 55 · Partly fixed 8 · Deferred 25 · Declined 5 · Harness artefact 1 · No change needed 2. (Three of the "Fixed" entries also name a harness artefact for part of the finding: the `localhost` host, the "?" badge, and the first-launch failures.)

**The decision (step 5).** Clack's first user is the person holding a ticket for a train they have not taken yet, who wants to know if it is late, which platform, and where it is; the log and the Passport are what that accumulates into. So where personas pulled in different directions, the watcher won: the first screen now leads with "Find your train" and says what the app does for tomorrow's train before it mentions years ago; status and verdicts are written in words where the Nervous Connector asked for them (the connection chip, "Alerts are on", "Sharing stopped") even though the Skimmer wanted fewer words; and where the Flighty Switcher wanted gestures and the Craft Skeptic wanted native restraint, the native part won every time (the system navigation bar with its own back button and swipe, system alerts with Cancel, a hold menu on list rows, a `List` selection for operators) rather than hand-made swipes. Appearance now follows the phone; `DESIGN.md` records why.

**The three changes that matter most.**
1. **The search tells the truth about days.** The København H → Malmö C list on Sunday 8 November really starts at 13:44 (the feed carries a reduced weekend timetable; the hosted server returns 37 trains that day against 82 on Monday). The app now says so in a line above the list, every day's first journey carries its day, "Show earlier" names the day it reaches into ("Show earlier · Sat 7 Nov"), the list keeps its place when rows are added above it, and a train number with nothing on that day lists the days it does run as tappable chips ("No train SJ 421 on Sun 8 Nov. It runs on Sat 7 Nov, Mon 9 Nov …"). A bare "421" that only matches a Danish train now says there is no Swedish 421 that day and when there is. Today's already-departed train is shown with "These have already left today" instead of being hidden behind "Show earlier". Five of seven personas were blocked or derailed here.
2. **The trip page is a normal pushed screen again.** The hand-drawn header over the map hid the navigation bar, which killed the edge swipe and let the back arrow scroll away. The system bar is back (transparent over the map, its own back button, the menu and sharing as toolbar items), so swipe-back works, the back button is always there, and the status bar gets the system's edge blur. The alerts question moved above the time tiles so it is seen on the first screen, and once alerts are on the page says so.
3. **The planner stops offering journeys nobody would take, and the journey says whether a change is fine.** A patience rule drops a journey when a later one with no more changes arrives within an hour of it in half the time (the 01:12 Uppsala → Gävle → Stockholm, the 02:20 via Lund), and "night journey" now means the bed is most of the trip, not a one-hour hop on a passing night train. The change chip on a saved journey ends with the change rule's word ("14 min at Nässjö C · Platform 3 → 7 · 4 min walk · Relaxed"), and long waits read "1 h 44 min".

**For a human to look at before the next TestFlight build.**
- The trip page's bar now uses the system's automatic background: at rest it is transparent over the map, scrolled it blurs the top. Check it on the Pro Max in dark mode; if the owner prefers no blur at all, add `.toolbarBackground(.hidden, for: .navigationBar)` back (one line in `TripDetailScreen`), at the cost of the status-bar legibility finding.
- `DESIGN.md` §2.1 now says the default appearance is System. The server default changed too (`packages/shared`): new users follow the phone; existing users keep their saved choice.
- Editing a hand-added trip is new on both ends (`PATCH /api/legs/:id` with `date`, `dep`, `arr`, `operatorId`, `trainNumber`, `category`; `EditManualTripSheet` in the app). It was built and compiled but not exercised end to end in the simulator (the tester's flow needs taps); try it on a hand-added trip.
- The operator picker is now a `List(selection:)` sheet with search; it compiled after the design lint asked for a native selection instead of a tick icon, and was not looked at on screen.
- The share text now names the whole journey and the arrival time, and the first share asks once ("Share a live link?"). The link host comes from the server the app talks to: debug builds on the Mac's server still say `localhost`; release builds say `getclack.app`.
- Deferred and worth a plan of their own: import (PDF, Wallet, Interrail, CSV), a recurring commute, widgets and the Live Activity story, "if you miss the change", the station board at the connection time, historical brand names for old timetables.

## Blockers

### The train on the ticket isn't in the results, and the app doesn't say why
- **Source read:** skimmer.md steps at 03/04 (`03-421-results.png`, `04-tomorrow-421.png`); interrailer.md at `18-results-malmo-stockholm.png`; nervous-connector.md at `05-route-results.png`, `10-scrolled.png`, `13-goteborg-oslo.png`; flighty-switcher.md at `09-typed-421.png`, `11-today-sj421.png`; stats-nerd.md at `07-results-scrolled.png`, `08-results-bottom.png`; craft-skeptic.md at `04-421-results-full.png`. Checked the hosted server directly: `SJ 421` has no run on 2026-11-08 and runs 7, 9–13 Nov; København H → Malmö C has 37 trains on Sun 8 Nov, first 13:44, against 82 on Monday.
- **Cause:** the timetable was right (Sunday timetables, a reduced weekend service over the Øresund) but the app said nothing: an empty list for a number, a foreign train for a bare number, a list anchored at 13:44 with no word, and today's departed train hidden behind "Show earlier".
- **Status:** Fixed
- **Change:** `apps/server/src/search/timetable.ts` `daysWithNumber` and `smartSearch.ts`/`routes/search.ts` return `otherDays` (and `otherDaysCountry` when only a foreign train carries the number for someone with a home country; home-country results are also listed first). `AddTrainSheet.swift` shows "No train SJ 421 on Sun 8 Nov · It runs on [chips]" and a hint to check the ticket's date; "No train 421 in Sweden on Sun 8 Nov; the one below is abroad"; a banner "Nothing before 13:44 on Sun 8 Nov in the timetable…" (`AddTrainModel.lateFirstJourney`); "These have already left today" instead of hiding the only results (`AddTrainModel.results`). Strings `add.noTrainOnDay`, `add.runsOn`, `add.noTrainHint`, `add.noTrainAtHome`, `add.noEarlierThatDay`, `add.departedToday`, `add.noJourneyThatDay`.

### No way to import anything: no email, PDF, Interrail pass, Wallet, booking number or CSV
- **Source read:** interrailer.md Goal 2; flighty-switcher.md Goal 1 (`04-settings.png`, `07-longpress-plus.png`); stats-nerd.md Goal 3.
- **Cause:** there is a ticket-file path (share a PDF/pkpass to Clack → `TicketImportSheet`) but nothing offers it from "+" or Settings, and there is no CSV or booking-number import at all.
- **Status:** Deferred
- **Change:** a feature of its own (parsing SJ/DSB/Vy/Interrail tickets, a CSV mapping step). The existing "share a ticket file to Clack" entry should at least be named in the Add sheet; noted for the next pass.

### A trip can't be edited: the "…" menu is only Refresh times / Delete trip
- **Source read:** interrailer.md at `39-more-menu.png`; flighty-switcher.md at `19-more-menu.png`; stats-nerd.md at `64-more-menu.png` and the hand-add flow (`09-manual-form.png`).
- **Cause:** `PATCH /api/legs/:id` only took train type, seat and typed platforms; nothing in the UI could change a hand-added trip's times or operator, or swap a timetable trip for another train.
- **Status:** Fixed (partly: timetable trips are replaced, not field-edited)
- **Change:** server `legs.ts` `editManualLeg` + `routes/legs.ts` (day, times, operator, number, kind for manual trips; stations stay); `LegPatch` carries the fields; new `EditManualTripSheet.swift` opened from "… › Edit trip" on hand-added trips. For timetable trips "… › Another train instead" opens the search for the same route and day; saving deletes the old trip when it was still ahead, else marks it not taken (`Router.openAdd(query:date:replaceLegId:deleteReplaced:)`, `AddTrainModel.deleteReplaced`). "… › Seat and car" jumps to the seat fields.

### The date you pick isn't the date you get: "Show earlier" walks back across days unlabelled, and any future day's list starts at 13:44
- **Source read:** interrailer.md steps 05–14 (`05-results-copenhagen-malmo.png`, `08-earlier-x3.png`, `14-tapped-0914.png`, `22-trips-list.png`); craft-skeptic.md steps at `20-kobenhavn-malmo-full.png`, `23-show-earlier-x4-full.png`, `24-after-scroll-up.png`, `26-sun8-results-full.png`.
- **Cause:** the server plans the whole day for a future date (verified: the window returned is 00:00–24:00), so the 13:44 start was the data (see the first finding). "Show earlier" pages six hours back and crosses midnight by design, but the first journey only got a day line when it wasn't on the searched day, the button never said which day it would reach, and new rows were inserted above the viewport.
- **Status:** Fixed
- **Change:** `AddTrainModel.daySeparator` labels the first journey whenever the list spans more than the searched day; `earlierDay`/`laterDay` name the day the button reaches into ("Show earlier · Sat 7 Nov"); `AddTrainSheet` keeps the previously first card at the top after paging (`ScrollViewReader`), and shows the "Nothing before 13:44 on Sun 8 Nov" banner. Verified on screen (`/tmp/shots/add-cph.png` during the pass).

### A fresh install already contains a stranger's journey, and it leaks into Passport, the widget and the Past tab
- **Source read:** flighty-switcher.md steps at `08-trips-prefilled.png`, `41-passport.png`, `28-widget-on-home.png`, `43-trips-list.png`; commuter.md finding 15.
- **Cause:** the phone's id lives in the Keychain (`Identity.current`), which survives deleting the app, and a simulator device keeps its Keychain between installs. The Flighty Switcher ran on the same iPhone 18 Pro Max simulator the Nervous Connector had used the evening before (same Jönköping → Oslo journey, same OS); the Commuter's two reinstalls came back the same way until the simulator was erased. There is no demo data and no server-side collision.
- **Status:** Harness artefact
- **Change:** none in code. On a real phone the same happens on purpose (a reinstall keeps your trips; "Delete my data" in Settings starts over, and its note now says so). Worth a sentence in the test method next time: erase the simulator between personas.

### Route results lead with absurd itineraries (02:20 night trains via Lund, 5-hour Gävle detours) ahead of the sensible direct train
- **Source read:** nervous-connector.md at `09-nassjo-goteborg.png`, `10-scrolled.png`; commuter.md at `03-i-morgon.png`. Reproduced against the local server: Uppsala C → Stockholm C on 8 Nov listed 01:12 → 06:20 (one change, 5 h 08) second.
- **Cause:** `rank` in `planner.ts` dropped dominated journeys and long detours, but a journey leaving hours earlier than a far better one is never "dominated"; and the 01:12 via Gävle rides a night train for its last hour, which exempted it from the detour rules ("the bed is the point").
- **Status:** Fixed
- **Change:** `apps/server/src/search/planner.ts`: a patience rule (dropped when a later journey with no more changes arrives within an hour of it in half the time) and `night` now means the night legs are at least half the journey. Test added in `apps/server/test/planner.test.ts`. The Uppsala list now goes 00:10, 06:00, 06:39, 07:10 … (53 journeys, was 55).

### Pressing share quietly starts an ongoing "sharing"; the second press shows a red "Stop sharing", and stopping gives no confirmation
- **Source read:** nervous-connector.md steps at `31-share-sheet.png`, `32-after-copy.png`, `35-share-sheet-oslo.png`, `36-after-second-copy.png`, `37-stop-sharing.png`.
- **Cause:** `ShareControl` made the live link on the first tap with no word that it was live or ongoing, turned yellow to mean "shared", became a menu with a red "Stop sharing", and stopping changed nothing visible.
- **Status:** Fixed
- **Change:** `ShareJourney.swift`: the first share on a phone asks "Share a live link?" with what it does and how to stop (once; `clack.share.explained`); while shared the trip page shows a row "Sharing a live link to this journey · Stop" (`SharingRow`); stopping shows "Sharing stopped. The link no longer works." The toolbar button no longer stays yellow.

### No way to say "every weekday": no recurring commute, favourite or "same train tomorrow"
- **Source read:** commuter.md Goal 1 (`06-after-add.png`, `07-visa-resan.png`, `08-more-menu.png`).
- **Cause:** trips are single dated legs; nothing repeats them.
- **Status:** Deferred (a small step taken)
- **Change:** "… › Same train, another day" opens the Add sheet with "Mälartåg 915" typed and the next day chosen, so the daily re-entry is two taps rather than a search and a scroll. A true recurring commute (a pinned card, "+4 min · Spår 7a" at 06:55, a push on change) needs a server-side schedule and its own design.

### Two legs added separately are not a journey
- **Source read:** interrailer.md steps at `21-view-trip.png`, `22-trips-list.png`.
- **Cause:** the two legs landed on different days (Saturday 09:14 and Sunday 10:07) because of the date finding above; the journey rule (`legs/journeys.ts`: next train leaves from the station the previous one arrived at, within 4 hours) joins legs that actually connect, as the Nervous Connector's did.
- **Status:** Fixed (by the date finding)
- **Change:** no change to the join rule. The "Added" screen now names the whole journey when the saved train joined one, so a wrong day shows up at once (see "View trip and Added show one train" below).

### No verdict on whether a saved connection will be made
- **Source read:** nervous-connector.md Goal 2 (`20-trips-tab.png`, `22-journey-scrolled.png`, `23-nassjo-row-tapped.png`).
- **Cause:** `JourneyChangeChip` coloured the chip by the change rule's verdict but never wrote the word; the search list did.
- **Status:** Fixed
- **Change:** `JourneyLegs.swift`: the chip ends with the verdict ("… · 4 min walk · Relaxed"; "Tight"/"Risky" from the walk-based result when the rule has no history). The verdict updates with live times as before.

### Nothing says what happens if you miss the change
- **Source read:** nervous-connector.md Goal 3 (`24-departures.png`, `25-second-train.png`).
- **Cause:** the "next train if you miss it" exists only once a change is actually missed (the disruption card asks `/api/alternatives`); nothing shows the worst case the night before.
- **Status:** Deferred
- **Change:** a line under the change chip ("If you miss it: next train 08:19, arrives 11:30") can reuse `/api/alternatives`; left for a pass that can also test it on departure day.

## High

### Things render behind the floating tab bar: the "Get alerts?" card, the DEPARTURE/ARRIVAL tiles, the connection row, the last Settings rows
- **Source read:** skimmer.md at `07-view-trip.png`; commuter.md at `07-visa-resan.png`; stats-nerd.md at `56-placera-toggle.png`; flighty-switcher.md at `15-trip-detail.png`.
- **Cause:** the pages scroll under the glass tab bar as the system intends, but the alerts card sat exactly at the fold on first view (under the tiles), so the first screen of a new trip looked cut. The Settings switch in the screenshot was mid-scroll, not at the end of the list.
- **Status:** Fixed
- **Change:** `TripDetailLogic.sections(.before)` puts the alerts question right under the status card, above the time tiles (verified on screen: the card's title is visible without scrolling). The bottom inset itself was already there.

### "Add to trips" and "Follow" side by side with no explanation, and "Follow" offered on trains that ran years ago
- **Source read:** commuter.md at `05-tapped-0710.png`; interrailer.md at `28-vy111-detail.png`; stats-nerd.md at `24-421-detail.png`; craft-skeptic.md at `27-oresund-detail-full.png`.
- **Cause:** `PlannedJourneyStep` showed both buttons always, with no copy.
- **Status:** Fixed
- **Change:** Follow is shown only for a journey still to run; a line under the buttons says what each does (`journey.addOrFollowNote` / `journey.addNote`). The number-search path's button now also says "Add to trips" (`add.addToClack` reworded) so the two paths agree.

### The app launches dark on a phone set to light; Appearance ships as "Dark", not "System"
- **Source read:** skimmer.md `00-first-launch.png`; interrailer.md `42-settings.png`; nervous-connector.md `48-settings.png`; craft-skeptic.md `00c-settings-app-appearance.png` and Goal 2.
- **Cause:** `DEFAULT_SETTINGS.theme` was `'dark'` on the server and `.dark` in the app, with `DESIGN.md` saying "default Dark".
- **Status:** Fixed
- **Change:** `packages/shared/src/index.ts`, `ClackCore/Models/Settings.swift`, `AppModel.colorScheme` (and its cached fallback) default to System; `DESIGN.md` §2.1 updated with the reason. Verified: Settings shows System selected and the app follows the simulator's light mode.

### Share produces a "localhost" link with no card, and the text names one train with no times
- **Source read:** skimmer.md `18-share-sheet.png`, `19-after-copy.png`; nervous-connector.md `31-share-sheet.png`, `32-after-copy.png`; flighty-switcher.md `33-share-sheet.png`; craft-skeptic.md `55-share-sheet.png`.
- **Cause:** the link's host is the server's own address as the phone reached it (`routes/share.ts` `baseUrl`), and the debug build in the simulator talks to the Mac's server, hence `localhost`; release builds get `getclack.app`. The text was "Follow my train from A to B" for whichever leg was open.
- **Status:** Fixed (text); Harness artefact (host)
- **Change:** `JourneyShare.text` composes "Jönköping C → Oslo S, Sat 7 Nov. Arrives 15:47 (Vy 388). Follow my train live:" from the whole journey's legs (`ShareControl` now takes `legs`). No image card: the link's page already carries the live map; a share image is a later step.

### Seat and car: never asked on add, buried at the bottom of a collapsed "About this train", letters keyboard, and the keyboard covers the fields and the Save button
- **Source read:** skimmer.md `22-about-train.png`, `23-seat-tap.png`; flighty-switcher.md `37-seat-car.png`–`39-seat-done.png`; craft-skeptic.md `14-seat-car.png`.
- **Cause:** `SeatEditor` used the default keyboard with caps, put Save in the page (under the keyboard), and gave no confirmation.
- **Status:** Fixed
- **Change:** `SeatEditor.swift`: numbers-first keyboard with Done, a Save/Done button in the keyboard bar, saving when the field loses focus, "Saved. It shows at the top of the trip." afterwards; "… › Seat and car" opens About this train at the fields. Asking for the seat during add is left out on purpose (most trips have none).

### The two add paths end differently, and the "Share usage data?" dialog fires mid-task on top of one of them
- **Source read:** interrailer.md `29-added-oslo.png`; flighty-switcher.md `07-longpress-plus.png`; stats-nerd.md `17-added.png`; craft-skeptic.md `07-sj421-today-earlier-full.png`, `28-after-add-2-full.png`.
- **Cause:** `UsageAsk.check` ran on every reload of the trips list, so adding a past trip (a trip that "has ended") fired it at once, over the Add sheet. Every add path does end on the "Added" step in code; the skipped "Added" the Interrailer and Stats Nerd saw was not reproduced and is most likely the dialog landing on top of it.
- **Status:** Fixed (dialog); not reproduced (ending)
- **Change:** `TripsScreen.swift`: the ask runs on the first load of a launch only, so it comes on a later start, never the moment something is added. Labels unified: "Add to trips" on both detail screens, the sheet is "Find your train" on both.

### The first screen reads like a diary and lists five trains leaving soon from cities you're not in
- **Source read:** skimmer.md, interrailer.md, commuter.md, nervous-connector.md first screens (`00-first-launch.png`, `01-first-screen-loaded.png`); stats-nerd.md `01-find-your-train.png` (the button moving).
- **Cause:** `WelcomeView` led with "Log the trains you ride…", then the departures list with primary-yellow Add buttons, then the search button, which moved when the skeletons collapsed.
- **Status:** Fixed
- **Change:** copy says what the app does for the train you're taking (`firstRun.log`, and `trips.emptyBody`); "Find your train" comes first, the departures after it with secondary Add buttons; a failed fetch says "Couldn't fetch departures right now" instead of "No trains leave the big stations".

### The keyboard stays over the result list; a tap on a card can type into the field and wipe the results
- **Source read:** commuter.md `03-i-morgon.png`; flighty-switcher.md `03-add-sheet-scrolled.png`; stats-nerd.md `22-2023-card-tapped.png`.
- **Cause:** nothing dismissed the keyboard when results arrived; the sheet's scroll view didn't dismiss it either.
- **Status:** Fixed
- **Change:** `AddTrainSheet` drops focus when a whole search answers (both stations with journeys, or a number with results); `SheetFrame` scrolls dismiss the keyboard (`.scrollDismissesKeyboard(.immediately)`).

### Tapping the Trips tab reopens the last trip instead of the list, and the share button sits exactly where the Settings cog sits on the list
- **Source read:** skimmer.md `16-trips-tab.png`; nervous-connector.md `47-settings.png`; flighty-switcher.md `49-trips-pull-refresh.png`.
- **Cause:** the `TabView` selection binding only changed tabs; reselecting did nothing.
- **Status:** Fixed
- **Change:** `RootView.swift`: tapping the showing tab clears its stack. The share button is now a system toolbar item beside "…" (a different shape and position from the list's cog), which also addresses the mix-up.

### No back button and no swipe-back on the trip detail: the arrow scrolls away with the map, the edge swipe is dead, and the arrow over the map swallows taps
- **Source read:** skimmer.md `27-trips-list.png`, `28-back-swipe.png`; craft-skeptic.md `17-swipe-back.png`, `47-light-swipeback-full.png`; flighty-switcher.md finding 13.
- **Cause:** `TripDetailScreen` hid the navigation bar (`.toolbar(.hidden, for: .navigationBar)`) and drew its own buttons over the map, which removes the interactive pop gesture and scrolls the back button away.
- **Status:** Fixed
- **Change:** the system bar is back with an empty inline title; back is the system's, "…" / ticket / share are toolbar items; the map still runs full-bleed under it. Verified on screen at default and xxxLarge sizes.

### After Allow, the alerts card vanishes with no "Alerts on", no bell, no toggle, nothing about which trains
- **Source read:** skimmer.md `10-alerts-allowed.png`; nervous-connector.md `40-alerts-allowed.png`; flighty-switcher.md `18-alerts-allowed.png`.
- **Cause:** `AlertsPrompt` rendered nothing once `notify` was on.
- **Status:** Fixed
- **Change:** `AlertsPrompt.swift`: with alerts on, a line "Alerts are on for this train: a reminder, the platform, delays and changes" (or "Done: alerts are on for this train and every train you add" right after turning them on) that opens Settings.

### The train type is named three ways for one train, or "We don't know"
- **Source read:** skimmer.md `04-tomorrow-421.png`, `22-about-train.png`; flighty-switcher.md `35-about-train.png`; craft-skeptic.md `13-about-train-full.png`.
- **Cause:** three different things: the product category ("InterCity") in the header, a typical type for the line on the search card ("X2000"), and the planned composition from Trafikverket on the train card ("SJ 3000 (X55)", labelled "Planned"). The last is the most accurate; the search card presented a guess as a fact.
- **Status:** Partly fixed
- **Change:** the search card says "Usually X2000" (`add.usuallyType`). The header keeps the category word and the train card keeps its "Planned"/"Typical"/"Your choice" chip; replacing the category word with the type would hide the product class. "We don't know" stays where no source says: nothing is made up (CLAUDE.md).

### First launch shows error and empty states while online: "No connection · showing saved data", "Couldn't load your trips. Retry", "No trains leave the big stations in the next hour"
- **Source read:** nervous-connector.md `01-first-screen-loaded.png`; flighty-switcher.md `01-home.png`; stats-nerd.md `01-find-your-train.png`; skimmer-earlier-213859.md.
- **Cause:** the debug build talks to the Mac's dev server, which restarts on every code save (`scripts/supervise.mjs --watch`); a request during a restart fails, which shows the offline strip and "Couldn't load your trips", and a failed departures fetch read as "No trains leave the big stations". That failure is also why the Skimmer's two runs saw two first screens: the welcome needs the trips list to have loaded (`FirstRun.showsWelcome`), so a failed first load showed the bare list with the red box instead.
- **Status:** Fixed (wording and the first screen); Harness artefact (the failures themselves)
- **Change:** `WelcomeView` distinguishes a failed fetch from an empty one; `TripsScreen` shows the welcome on a new phone even when the first load failed, instead of the error box as the first screen.

### The location prompt is decoupled from what you tapped: fires on resume or on opening Explore, not on the "Help place trains" toggle, and allowing it doesn't zoom the map to you
- **Source read:** skimmer.md `14-explore-allowed.png`; flighty-switcher.md `30-reopened.png`; stats-nerd.md `56-placera-toggle.png`, `57-placera-toggle-2.png`.
- **Cause:** the toggle only stored a flag; iOS was asked the next time a map needed a position. Allowing on Explore only placed the dot.
- **Status:** Fixed
- **Change:** `SettingsScreen` asks iOS the moment the toggle goes on (`LocationModel.askIfNeeded`); `ExploreScreen` eases the map to you when permission is first granted while Explore shows.

### The delete flow: "Delete trip" is not red in the menu, doesn't say whether "trip" means this train or the whole journey, the confirm popover has no Cancel and floats mid-screen, and deleting from the list is open → … → Delete
- **Source read:** nervous-connector.md `43-more-menu.png`; craft-skeptic.md `52-more-menu.png`, `53-delete-confirm.png`; flighty-switcher.md `19-more-menu.png`, `44-swipe-card.png`.
- **Cause:** `.tint(Ink.text)` on the menu overrode the destructive red; a `confirmationDialog` anchored to the map button became a popover without Cancel; the list had no shortcut.
- **Status:** Fixed
- **Change:** the menu item reads "Delete this train" inside a journey, red; the confirmation is a system alert naming the route ("Delete Nässjö C → Falköping C from this journey?", "The other trains of the journey stay.") with Cancel; holding a row in the Trips list offers Open and Delete (`TripsScreen.holdMenu`, `TripsModel.delete`).

### Developer tools and a server hash ship in Settings
- **Source read:** interrailer.md `44-settings-bottom.png`; flighty-switcher.md `05-settings-scrolled.png`; craft-skeptic.md `46-settings-bottom-full.png`.
- **Cause:** the test rows are already debug/TestFlight-only (`WalkStore.isTestBuild`, `#if DEBUG`); the personas ran debug builds. The server commit line showed in every build.
- **Status:** Fixed (hash); no change needed (rows)
- **Change:** `VersionFooter` shows the server commit in test builds only.

### Passport numbers disagree with each other
- **Source read:** interrailer.md `32-passport.png`; stats-nerd.md `27-passport.png`, `28-passport-2.png`; craft-skeptic.md `43-passport-stats-full.png`.
- **Cause:** the card rounds kilometres, the medal progress floored them; "Worst delay" showed a negative delay as "−1 min late".
- **Status:** Fixed ("On trains 3h 24m vs 3h 31m" not reproduced)
- **Change:** `PassportScreen.swift` rounds progress the same way; the worst-delay tile only shows when something was late.

### Copy written for live trips appears on past and future ones
- **Source read:** skimmer.md `05-tapped-card.png`; flighty-switcher.md `36-about-train-scrolled.png`; stats-nerd.md `04-oct-14.png`, `65-trip-detail-2.png`.
- **Cause:** tensed strings.
- **Status:** Fixed (titles); Deferred ("No live data here" on old trips)
- **Change:** "Where you get on and off", "Different train? Change it", the sheet is "Find your train" whatever the date. "No live data here" per stop on a weeks-old trip is true but noisy; a one-line note per trip is a later change.

### The operator menu on the hand-add form closes when scrolled; Vy and everything after Snälltåget is unreachable
- **Source read:** stats-nerd.md `11-operator-tap.png`, `12-operator-list.png`.
- **Cause:** a `Picker` inside a `Menu` with 25+ rows.
- **Status:** Fixed
- **Change:** `OperatorPickerButton`/`OperatorPickerSheet` in `AddTrainSheet.swift`: a searchable sheet with a native `List` selection, each operator with its mark, company and country, the home country's first. Used by the hand-add form and the new edit sheet.

### Explore search can't find "Uppsala" or "Uppsala C" although its placeholder says "station"
- **Source read:** commuter.md `12-explore-uppsala.png`, `13-explore-uppsala-c.png`. The hosted server answers `Uppsala C` for `stations/search?q=Uppsala`.
- **Cause:** the results panel said "Nothing matches" whenever the hits array was empty, including while the request was out or when it failed; a slow or dropped request (the dev server restarting) read as no match.
- **Status:** Fixed
- **Change:** `ExploreModel.searchChanged` tracks pending/failed, retries once, and `ExploreScreen` shows "Searching…" or "Couldn't search right now" instead. Verified in the simulator: "Searching…", then "Uppsala C · Station", which opens the station card with departures.

### "View trip" and "Added" after adding show one train, not the journey
- **Source read:** nervous-connector.md `07-after-add.png`, `12-added-second.png`, `17-view-trip.png`.
- **Cause:** `DoneStep` only knew the last saved leg.
- **Status:** Fixed
- **Change:** `DoneStep` loads the saved leg's journey and names it whole ("Jönköping C → Oslo S · Journey · 3 trains · Krösatåg 27604, SJ 159, Vy 388"); the button becomes "View journey" and opens the journey screen.

### The number pad on "Tågnummer" has no Done key, tapping outside doesn't dismiss it, and the submit button is hidden behind it
- **Source read:** stats-nerd.md `15-after-add.png`, `16-keyboard-covers-add.png`.
- **Cause:** a number pad has no return key and nothing offered one.
- **Status:** Fixed
- **Change:** a Done button in the keyboard bar for the number field (hand-add form and edit sheet).

### The crosshair button on the trip map does nothing
- **Source read:** skimmer.md `11-trip-map-top.png`, `12-crosshair.png`.
- **Cause:** the button re-fits the route (or follows a live train); before departure the route is already fitted, so nothing changed.
- **Status:** Fixed
- **Change:** `RouteMapView.swift` shows the button only when there is a live train to follow or the map has been moved off its framing.

## Medium

### Notifications are off by default, nothing in the add flow asks, and the switch is two screens deep in Settings
- **Source read:** skimmer.md `06-after-add.png`; commuter.md `17-settings-scrolled.png`.
- **Cause:** the only ask was the card on the trip page, below the fold.
- **Status:** Fixed
- **Change:** the "Added" step offers "Turn on alerts" for a trip still ahead (iOS's prompt, then "Done: alerts are on…"); the trip page's card moved above the tiles.

### An empty result list with no explanation: Today is the default so a tomorrow train shows nothing, and a departed train hides behind a lone "Show earlier"
- **Source read:** skimmer.md `03-421-results.png`; flighty-switcher.md `11-today-sj421.png`.
- **Cause:** `AddTrainModel.results` hid today's departed trains even when they were all there was.
- **Status:** Fixed
- **Change:** departed trains are shown with "These have already left today" when nothing else matches; a number with nothing that day lists the days it runs (see the first finding).

### Map dots are unhittable at country zoom and there is no cluster tap
- **Source read:** skimmer.md `30-explore-dot.png`; craft-skeptic.md `36-tap-dot.png`.
- **Cause:** a 32 pt hit box; clusters do zoom in on tap, but at country zoom many dots are single.
- **Status:** Partly fixed
- **Change:** `LiveMapView.swift` uses a 44 pt box (the system's hit size). A tap-to-zoom on dense but unclustered areas is deferred.

### No long-press context menu and no swipe actions anywhere; no pull-to-refresh ("Refresh times" is a menu item)
- **Source read:** flighty-switcher.md `44-swipe-card.png`, `45-longpress-card.png`; craft-skeptic.md `57-longpress-card.png`, `59-pull-refresh.png`.
- **Cause:** list rows had no context menu; pull-to-refresh exists on the Trips list and the trip page (`.refreshable`) but the card's preview map swallowed the pull.
- **Status:** Partly fixed
- **Change:** a hold menu (Open, Delete) on trip rows; preview maps no longer take touches (see "Header map…" below), so the pull works. Swipe actions outside a `List` need the iOS 27 API and the app's deployment target is 17: declined for now.

### Share button stays yellow after the sheet closes, and the back button swallows two taps in that window
- **Source read:** skimmer.md `20-more-menu.png`; craft-skeptic.md `54-share.png`, `56-longpress.png`.
- **Cause:** yellow meant "shared now" (`pressed: share.isShared`), which nobody read that way; the swallowed taps were the share sheet's dismissal.
- **Status:** Fixed
- **Change:** the share button is a plain toolbar item; "shared now" is said in the `SharingRow` instead.

### Station map: a "—" where a title should be, the destination platform not visible, green dots and "?" on pins with no legend
- **Source read:** nervous-connector.md `23-nassjo-row-tapped.png`; craft-skeptic.md `39-station-map-full.png`.
- **Cause:** the layover card shows the walking time and prints "—" when no route could be worked out (the destination platform isn't drawn for Nässjö yet).
- **Status:** Partly fixed
- **Change:** the dash is now "Walk not known yet: the other platform isn't on this map." Drawing platform 7 at Nässjö and a legend for the pins are deferred (data and design).

### Settings footnotes are truncated to one line mid-word ("…även när Clac")
- **Source read:** nervous-connector.md `49-settings-scrolled.png`; stats-nerd.md `40-settings-2.png`.
- **Cause:** `InfoNote` kept one line until tapped.
- **Status:** Fixed
- **Change:** `ClackDesign/InfoNote.swift` keeps two lines closed.

### Scrolled content shows through the status bar clock
- **Source read:** skimmer.md `08-trip-scrolled.png`; nervous-connector.md `18-trip-scrolled.png`.
- **Cause:** the hidden navigation bar left the status bar with no edge effect.
- **Status:** Fixed
- **Change:** with the system bar back, the top edge gets the system's soft blur when content scrolls under it (verified on screen).

### "DEPARTURE" truncates to "DEPARTU…" / "DEPART…" on the trip tiles
- **Source read:** nervous-connector.md `17-view-trip.png`; flighty-switcher.md `15-trip-detail.png`.
- **Cause:** `TimeBlock` capped the label at one line beside the platform tag; two tiles side by side at accessibility sizes left no room for the flap digits either.
- **Status:** Fixed
- **Change:** the label wraps to two lines; at accessibility sizes the two tiles stack (`TripDetailScreen.timesRow`). Verified at xxxLarge.

### Map labels clip and pile up
- **Source read:** nervous-connector.md `20-trips-tab.png`; craft-skeptic.md `11-trip-detail-full.png`, `29-oresund-trip-full.png`, `38-malmo-board-full.png`.
- **Cause:** MapLibre label placement on small preview maps.
- **Status:** Deferred
- **Change:** needs padding/label-collision settings per map kind in `MapStyle`.

### Stop rows on the trip page don't open the departure board they're announced as
- **Source read:** commuter.md `22-uppsala-board.png`, `23-uppsala-board-retry.png`.
- **Cause:** the app enables text selection everywhere (`RootView`); the stop name's button label kept it on, so the tap went to selection. (The app's other link buttons disable it for the same reason.)
- **Status:** Fixed
- **Change:** `ClackDesign/StopTimeline.swift` disables selection on the name button.

### "1 trip needs a check before it counts →" sends you to the wrong trip
- **Source read:** flighty-switcher.md `42-needs-check.png`.
- **Cause:** the banner switched to the Trips tab and the Past list but left the trip already pushed on that tab's stack in front.
- **Status:** Fixed
- **Change:** `PassportScreen.swift` clears the Trips stack first.

### Tap targets that look tappable aren't: the yellow platform tags on the tiles
- **Source read:** commuter.md `20-tap-avgang-tile.png`.
- **Cause:** the tag is tappable only when the platform was typed by you (to change it).
- **Status:** Deferred
- **Change:** opening the station map at that platform from the tag needs the station id in `TimeBlock`; worth doing with the station-map findings above.

### Header map and card preview maps eat vertical drags
- **Source read:** craft-skeptic.md `52-more-menu.png`, `59-pull-refresh.png`.
- **Cause:** the preview maps were non-interactive in MapLibre but still in the hit-test chain.
- **Status:** Fixed (previews); Declined (the header map)
- **Change:** `RouteMapView` sets `allowsHitTesting(interactive)`, so a card's map strip scrolls the page. The trip page's header map stays interactive by design (pan, pinch, Follow train); its re-centre button appears once it has been moved.

### SJ trains show a yellow "?" instead of a logo and the number twice ("427 427") in results
- **Source read:** flighty-switcher.md `12-route-tomorrow.png`; skimmer-earlier-213859.md.
- **Cause:** the operators list hadn't loaded (the same dev-server restart as the first-launch errors), so the card fell back to the route name, which for SJ is the number again, and the badge to "?".
- **Status:** Fixed (the doubled number); Harness artefact (the "?")
- **Change:** `ResultCard` leaves the route name out when it is only the number.

### Lost place after lock/unlock: came back on Explore, not the open trip
- **Source read:** flighty-switcher.md `30-reopened.png`, `31-share-tapped.png`.
- **Cause:** not reproduced; the landing rule only runs on a cold start and prefers Trips when a train is running. Most likely the debug build was relaunched by the system.
- **Status:** Deferred
- **Change:** state restoration of the open trip (`SceneStorage`) would cover it; not done in this pass.

### Widget and Live Activity: ten widgets with no large "next trip" one first, station names truncated in the small widget, and nothing anywhere mentions a Live Activity
- **Source read:** flighty-switcher.md `27-clack-widgets.png`, `28-widget-on-home.png`, `29-lock-screen.png`.
- **Status:** Deferred
- **Change:** widget gallery order and the small widget's truncation are a widgets pass; the Live Activity exists (`LiveActivities.swift`) and should be named in the alerts copy once its start rule is confirmed on a device.

### The same journey is "4 trains → Oslo S" under Upcoming and "2 trains → Falköping C" under Past
- **Source read:** flighty-switcher.md `08-trips-prefilled.png`, `43-trips-list.png`.
- **Cause:** Past lists the trains already ridden, Upcoming the whole journey; both are "true" but read as two journeys.
- **Status:** Deferred
- **Change:** a journey under way should appear once (Upcoming) until it ends; needs a change in `TripsLogic.partition`.

### The app assumes you know the companies
- **Source read:** interrailer.md `05-results-copenhagen-malmo.png`, `38-legend.png`.
- **Status:** Partly fixed
- **Change:** the operator picker shows company and country under each mark; result cards still show the brand name alone. A "the company that runs it" caption for a non-home country is deferred.

### The "where I've been" map is a thumbnail below the fold that can't be opened
- **Source read:** interrailer.md `34-passport-map-view.png`, `35-map-tapped.png`.
- **Status:** Deferred
- **Change:** a full-screen map of all routes is a feature; noted.

### The station departure board opens at now, with no date and no way to jump to the connection time
- **Source read:** nervous-connector.md `24-departures.png`.
- **Status:** Deferred
- **Change:** the board is live-only by design; a timetable view at a given time needs a server endpoint.

### The app launched in English on a Swedish phone, then switched to Swedish by itself ~40 s later
- **Source read:** stats-nerd.md `00-first-launch.png`, `01-find-your-train.png`.
- **Cause:** the phone's language was applied only after the server's settings arrived (`AppModel.load`), which on the restarting dev server took a long time.
- **Status:** Fixed
- **Change:** `AppModel.init` sets the phone's language from the first frame the first time; `load` keeps it.

### "Rapportera ett fel" does nothing
- **Source read:** stats-nerd.md `58-rapportera.png`.
- **Cause:** `mailto:` with no mail app set up fails silently.
- **Status:** Fixed
- **Change:** `ReportBugRow` shows the address with a Copy button when the mail link isn't accepted.

### Explore filter shows all four country switches OFF while the map shows all four countries
- **Source read:** stats-nerd.md `72-utforska-filter.png`.
- **Cause:** an empty filter set means "all", and the switches read membership.
- **Status:** Fixed
- **Change:** `ExploreFilterSheet` switches read "shown": all on when the set is empty; turning one off keeps the others; all on again clears the filter. Same for kinds and operators.

### "Hämtar dagens tidtabell… kan ta en halv minut" with no spinner, ~45 s, twice
- **Source read:** stats-nerd.md `03-oct-14.png`, `06-results-wait.png`.
- **Status:** Partly fixed
- **Change:** the banner has a spinner. The wait is the archive import of that day (Trafiklab's historical GTFS); a second search of the same day should be instant, which the Stats Nerd's second wait contradicts: worth a look at `ensureHistory` caching.

### Welcome card layout jumps as skeletons collapse, so the big button moves under your finger
- **Source read:** stats-nerd.md `01-find-your-train.png`.
- **Status:** Fixed
- **Change:** the button is above the list now (see the first-screen finding).

### Time wheels on the hand-add form start at 00:00; two times are ~40 wheel rows
- **Source read:** stats-nerd.md `10-time-wheel.png`.
- **Status:** Fixed
- **Change:** departure starts at 08:00, arrival follows it an hour on until set.

### Hand-add form has no field for actual arrival / delay minutes
- **Source read:** stats-nerd.md finding 27.
- **Status:** Deferred
- **Change:** needs an `actualArr` on manual legs server-side and a row on the form and the edit sheet; small, but not done here.

### Network panel opens on top of the still-open station card; they overlap
- **Source read:** craft-skeptic.md `62-network-status-full.png`.
- **Status:** Fixed
- **Change:** `ExploreScreen` closes the station card when the network panel opens.

### "Where is my train?" means leaving the trip and re-typing the number on Explore
- **Source read:** skimmer.md `11-trip-map-top.png`, `15-explore-search-421.png`.
- **Status:** Deferred
- **Change:** on the day, the trip page's map shows the train (and "On its way"); the night before, a line on the map ("Not running yet · leaves 05:47") is a small addition for the next pass.

### Searching Nov 2023 returns today's timetable with today's brands presented as 29 real 2023 journeys
- **Source read:** stats-nerd.md `21-2023-results.png`.
- **Cause:** not verified. The archive import for old days exists (`import/history.ts`) and the search refuses to answer until it is ready; what the Stats Nerd saw may be the archive's real 2023 timetable (SJ 421 has run in the 06:xx slot for years). Brand names are today's because operators are keyed by today's brand table (MTRX's trains are listed under VR).
- **Status:** Deferred
- **Change:** historical brand names need a dated brand table; checking a 2023 day against a known source is the first step.

## Low

### Passport remembers its scroll position, so the share icon was off-screen on return
- **Status:** Declined. System behaviour; the share button is in the header, one scroll up.

### The glance card has its priorities upside down
- **Status:** Deferred. A design question for the featured card (countdown and platform larger than the timetabled times).

### Cold start shows a solid yellow screen for 2–3 s
- **Status:** Declined. The splash waits for the settings to load (at most a moment on the hosted server); the dev server made it long.

### "Pass" reads as a ticket, means passport badges
- **Status:** Declined. "Pass" is the Swedish for passport.

### "104 min at Göteborg C" instead of 1 h 44 min
- **Status:** Fixed. `Format.minutesWords`; the change chip and the connection captions use it.

### The journey card is headed with the first train's name rather than "Jönköping C → Oslo S"
- **Status:** Fixed. `FeaturedCard` heads a journey with "Journey · 4 trains" and its status; the route is the headline; the trains are the cards below.

### The green circle on "Added" is empty the first time and half-drawn the second
- **Status:** Fixed. The tick is drawn after the view is on screen.

### Small grey "Jönköping" above "Live" on the Nässjö board
- **Status:** Deferred. Not reproduced in this pass (the board shows the train's origin in grey; needs a caption).

### "Relaxed · 30 min to change" then "4 min walk · 30 min to change" on the same change
- **Status:** Fixed. `ConnectionCard` leaves the wait out of the caption when the chip says it.

### At xxxLarge nothing was too small; the problems were things cut off, hidden or overlapping
- **Status:** Fixed. Tiles stack, stop rows put the time under the name, the map credit stays small, footnotes get two lines. Verified at xxxLarge.

### "Between Hässleholm and Hässleholm" in Network now
- **Status:** Fixed. "At Hässleholm" when the feed gives the same stop twice.

### The "Added — View trip / Add another" page is an extra dismiss
- **Status:** Declined. It now carries the journey summary and the alerts offer, which is why it is there.

### "Late turnaround" stamped under every stop of the live train sheet
- **Status:** Deferred. A cause shown per stop should be shown once per train.

### No carriage order / where-my-coach-stops, no booking reference field, no inbound-train status
- **Status:** Deferred. No open data source for carriage order in these countries; the others are features.

### Explore search box keeps old text when you come back
- **Status:** Fixed. Close clears the search.

### Collections pager leaks the next page's text; the Slag footnote off-screen; the selected chip not scrolled into view
- **Status:** Deferred.

### Hand-add form doesn't show the date you picked
- **Status:** Fixed. The day is printed under the title.

### Export is JSON only, hidden under Settings; Passport share is an image, not data
- **Status:** Deferred. A CSV export is small and should come with import.

### Rolling-stock picker lists every type in the Nordics alphabetically
- **Status:** Deferred.

### "—" on trip cards and stop rows is never explained
- **Status:** Deferred (the station map's dash is now words).

### Two red buttons "Delete my data" / "Erase everything and start over" with no line saying how they differ
- **Status:** Fixed. One line under each.

### Same station spelled two ways ("Köpenhamn H" / "København H")
- **Status:** Deferred. The Malmö board shows Trafikverket's Swedish name for the Danish station; normalising via the stations table is a server change.

### "Stockholm C → Götebo…" truncated in the Worst delay tile
- **Status:** Deferred.

### No About / maker / contact anywhere
- **Status:** Fixed. Sources & methodology opens with a maker line; the address is on the Privacy page.

### Vocabulary drift
- **Status:** Partly fixed. "Add to trips" on both detail screens; the sheet is "Find your train" like the welcome button. Operator/train-type words left as they are.

### Swedish localisation seams
- **Status:** Deferred. Durations ("3h 38m") and decimals need a language-aware `Format.duration` and number formatting in the Passport; one pass over `Format`.

### Control and chrome inconsistency
- **Status:** Partly fixed. The trip page uses the system bar and system alerts; the operator picker is a system list. Typefaces and the remaining segmented-control designs are a design pass.

### Decoration with no meaning
- **Status:** Declined. The Passport card, medals and route glow are the owner's design (`DESIGN.md`); not changed on one persona's opinion.

### Split-flap digits are one accessibility element per digit
- **Status:** No change needed. `SplitFlap` already combines its tiles into one element labelled with the whole time.

### "Populära stationer" includes Esbjerg and Pasila; "Snabbast" on one card; "Tåg 2 / Resor 2" unexplained
- **Status:** Deferred.

### Status written as words is good; fewer collapsed sections
- **Status:** No change needed (noted). The seat is now reachable from the menu; "About this train" stays collapsed.

## Also done in this pass
- `SheetFrame` scrolls dismiss the keyboard everywhere.
- Deleting a trip from the trip page uses a system alert with Cancel.
- The planner's ranking has a new test; `npm test` (design lint + vitest), `npm run typecheck` and the ClackKit package tests (`swift test`, 434 tests; the settings fixture now expects the System theme) pass; the app builds for the simulator (iPhone 17 Pro, iOS 27).
- Screens looked at in the simulator during the pass: the welcome, the København H → Malmö C search for Sunday, the "SJ 421" search, the trip page at rest and scrolled at default and xxxLarge sizes, Settings, and Explore's station search (typed "Uppsala").
- A throwaway test user with one trip (Stockholm C → Göteborg C, 8 Nov) was created on the Mac's dev server during verification; harmless, but it is in that database.
- Build number bumped to 59 on `Clack` and `ClackWidgetsExtension`.
