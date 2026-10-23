# App Store readiness

Checked on 2026-10-23 against Apple's [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
(last updated 2026-10-16), against the code as it is now. Numbers like **5.1.1(v)** are the guideline sections.

Each item says who does it and where:

- **Done**: already in the code.
- **Code**: still to change in this repository (ask Claude, in Terminal or Xcode).
- **Xcode**: a setting or file in the Xcode project. Easier done there than here.
- **App Store Connect** (ASC): the website where the app's listing, privacy answers and review notes are filled in.
- **You**: a decision, an account, or something only you can provide.

## Blocking: must be done before the first submission

| # | What | Guideline | Who | Notes |
|---|---|---|---|---|
| 1 | **Put the server online over https** and point the app at it (`apps/web/.env.ios`, `VITE_API_BASE`). | 2.1(a) "turn on your back-end service", 2.5.5 | You + Code | Right now the server runs on your laptop. App Review uses the app for real, so the server must be up and reachable by name over https (IPv6 works through Apple's NAT64 as long as it's a hostname). Steps in [IOS.md, step 9](IOS.md#9-put-the-server-online). |
| 2 | **Replace `REPLACE-WITH-YOUR-SERVER`** in `apps/web/.env.ios`. | 2.1(a) no placeholder content | You | The app can't load any data until it's set. |
| 3 | **Support contact**: an email address shown on the Privacy page (`VITE_SUPPORT_EMAIL`) and a **Support URL** in ASC. | 1.5 | You + ASC | A simple page is enough. The privacy page itself can be the Support URL if it has the email. |
| 4 | **Privacy policy URL** in ASC. | 5.1.1(i) | ASC | The policy is in the app (Settings > Your data > Privacy, `apps/web/src/pages/PrivacyPage.tsx`). Host the same page on the server, `https://<your-server>/privacy` (IOS.md step 9), and enter that URL. |
| 5 | **Apple Developer Program** membership, USD 99 a year. | n/a | You | Needed for TestFlight and the App Store. Running on your own iPhone from Xcode works with a free Apple ID (the app expires after 7 days). Enroll as an individual unless you have a company. |
| 6 | **App name.** "Clack" may already be taken on the App Store; names must be unique and at most 30 characters. | 2.3.7 | You + ASC | Check when creating the app in ASC. A subtitle like "Train log for Sweden & Norway" carries the meaning. |
| 7 | **Bundle id** `app.clack` is a placeholder. | n/a | You + Xcode | It must be unique and can't change once the app is in ASC. Use something you own, e.g. `com.<yourname>.clack`. Change it in Xcode (Signing & Capabilities) and in `apps/web/capacitor.config.ts`. |
| 8 | **EU trader status.** To be listed in the EU (Sweden), ASC asks whether you're a "trader" under the Digital Services Act. A free app from a private person is usually "non-trader"; a trader's address and phone number are shown publicly. | DSA, in ASC | You + ASC | Decide before submitting; ASC asks in its Business section, and the app can't be listed in the EU until it's answered. |
| 9 | **Data source terms for a public app.** Confirm that Trafikverket's API, Trafiklab's GTFS feeds and Entur's data allow use in a free public app, and give the attribution each requires (the About page lists all sources). | 5.2.2 | You | OpenStreetMap (ODbL) attribution is on every map. The terms differ per source; read each source's terms page. |
| 10 | **Station plans you supplied** (e.g. Jernhusen's Stockholm C plan, Jan 2026 PDF) were used to draw station maps. Those plans are someone else's copyrighted material. | 5.2.1 | You | Either get permission from the plan owners, or ship only the OpenStreetMap-based maps. The README already notes these plans are not ODbL. |

## Done in this round

| What | Guideline |
|---|---|
| **Per-phone identity, no sign-in.** Each phone makes a random id on first launch; the server keeps its trips under it. Nobody needs an account, so no login screen and no demo account for App Review. Before this, the server treated everyone as one user. | 5.1.1(v), 2.1(a) |
| **Delete my data** (Settings > Your data): removes everything the server has for this phone at once, plus the phone's copies. | 5.1.1(v) account deletion |
| **Privacy policy in the app** (Settings > Your data > Privacy), English and Swedish, matching what the code does. | 5.1.1(i) |
| **Location purpose string.** Only "My location" on a station map asks; the position never leaves the phone. | 5.1.1, 5.1.5 |
| **Operators' logos off in the iOS build** (they're trademarks). The badge shows the operator's initials in its colour instead. Names are fine to use. | 5.2.1, 4.1(c) |
| **No third-party analytics, ads or tracking**, so no App Tracking Transparency prompt is needed. | 5.1.2 |
| **Standard HTTPS only**: `ITSAppUsesNonExemptEncryption = NO`, so no export-compliance paperwork with each upload. | Export rules |
| **Built for Xcode 26 / iOS 26 SDK** (Capacitor 8), as required since April 2026. | 2.5.1 |
| **The app's pages are in the app bundle**, not loaded from a website, and no code is downloaded later. Map tiles and train data are data, not code. | 2.5.2 |
| **Ticket links open the operator's own site in Safari.** Train tickets are physical services, so no in-app purchase rules apply. | 3.1.3(e) |
| **App icon** (1024 px, no transparency) and launch screen from the Clack logo. | 2.3 |
| **Portrait iPhone app.** iPads run it in iPhone mode, which Apple allows. | 2.4.1 |

## Should do: strengthens the review, not strictly required

| What | Guideline | Who |
|---|---|---|
| **Make it feel native, not like a website in a box.** The main risk for an app built this way is 4.2 "Minimum Functionality: elevate it beyond a repackaged website". Clack is a long way past that: offline trips, live maps, live tracking, share cards. Native touches make it obvious: the iOS share sheet for share cards, haptics, a home-screen widget, a Live Activity for the train you're on, and delay notifications. All of these are planned (IOS.md, "Widgets, Live Activities and notifications"). | 4.2 | Code + Xcode |
| **Privacy manifest** (`PrivacyInfo.xcprivacy`) for the app target, declaring no tracking. Capacitor's own frameworks ship theirs. In Xcode: File > New > File > App Privacy. | Apple privacy manifests | Xcode |
| **Swedish purpose string.** The location question shows in English for now. Add `sv.lproj/InfoPlist.strings` with `NSLocationWhenInUseUsageDescription` in Swedish (Xcode: Info.plist > Localize). | 5.1.1(ii) clarity | Xcode |
| **Your own trains on the live map.** On the shared server, "your train" highlighting on the live map still looks only at the laptop user. Make the live-map stream use the asking phone's id. | n/a | Code |
| **Rate limits** on the server: ids are anonymous, so add basic per-id and per-IP request limits before the app is public. | 1.6 | Code |
| **Review notes in ASC.** Say that there's no login, that data comes from Trafikverket and Entur, and how to try it: "Add a train: type SJ 523 for today; open Explore for the live map." | 2.1, 2.3.1 | ASC |

## App Store Connect answers, prepared

- **Privacy "nutrition label".** Data collected, all used for *App Functionality* only, *not* used for tracking:
  - *User Content > Other User Content*: the trips you add, and notes.
  - *Identifiers > User ID*: the random id that keeps a phone's trips together.

  Both are linked to the user (to the random id, not to a person). Location is not collected (it stays on the phone). No contact info, no usage data, no diagnostics.
- **Age rating**: 4+. No objectionable content, no user-generated content shared with others, no web browsing.
- **Category**: Travel (secondary: Navigation).
- **Price**: free, no in-app purchases.
- **Screenshots**: 6.9-inch iPhone screenshots (1320 × 2868 px, or 1290 × 2796). Take them in the iPhone 17 Pro Max simulator with Cmd+S. They must show the app in use (2.3.3), not marketing art. Use your own trips; no other people's data.
- **Keywords**: describe the app ("train, rail, Sweden, Norway, delays, departures, logbook"). Don't list operator brand names to game search (2.3.7).

## Later (not needed for v1)

- iPad layout (2.4.1 encourages it, doesn't require it).
- Accessibility Nutrition Labels in ASC (optional): check VoiceOver labels and Dynamic Type first.
- Operator logos back on, for any operator that gives written permission (one setting: `VITE_OPERATOR_LOGOS`).
