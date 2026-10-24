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
| 3 | **Support contact**: an email address shown on the Privacy screen (`Config.supportEmail`, still `nil`, so nothing is shown) and a **Support URL** in ASC. | 1.5 | You + Code + ASC | A simple page is enough. The privacy page itself can be the Support URL once it has the email; the hosted page (`apps/server/public/privacy`) leaves the contact out until there is one. |
| 4 | **Privacy policy URL** in ASC: `https://clack-garner.duckdns.org/privacy` (Swedish: `/privacy/sv`). | 5.1.1(i) | ASC | The policy is in the app (Settings > Privacy) and the same words are served by the server from `apps/server/public/privacy` (docs/SERVER.md). Enter the URL in ASC once the server has been updated with that page and it answers. |
| 5 | **Apple Developer Program** membership, USD 99 a year. | n/a | You | Needed for TestFlight and the App Store. Running on your own iPhone from Xcode works with a free Apple ID (the app expires after 7 days). Enroll as an individual unless you have a company. |
| 6 | **App name.** "Clack" may already be taken on the App Store; names must be unique and at most 30 characters. | 2.3.7 | You + ASC | Check when creating the app in ASC. A subtitle like "Train log for Sweden & Norway" carries the meaning. |
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
| **Operators' logos** are trademarks. Garner has the operators' approval to use them (2026-10-23), so the Swift app shows them (`Config.showOperatorLogos`). Keep the written approvals: App Review can ask for proof of permission. Without a logo the badge shows the operator's initials in its colour. | 5.2.1, 4.1(c) |
| **No third-party analytics, ads or tracking**, so no App Tracking Transparency prompt is needed. | 5.1.2 |
| **Standard HTTPS only**: `ITSAppUsesNonExemptEncryption = NO`, so no export-compliance paperwork with each upload. | Export rules |
| **A native SwiftUI app built with the current Xcode** (26 or later, as required since April 2026; the project's own upgrade check is Xcode 27.1). | 2.5.1 |
| **The app is native**: no pages are loaded from a website, and no code is downloaded later. Map tiles and train data are data, not code. | 2.5.2 |
| **Ticket links open the operator's own site in Safari.** Train tickets are physical services, so no in-app purchase rules apply. | 3.1.3(e) |
| **App icon** (1024 px, no transparency) and launch screen from the Clack logo. | 2.3 |
| **Each phone sees only its own trips live.** Live trip updates go only to the phone whose trip it is, and "your train" on the live map is worked out per phone. Before, every listener got every tracked trip's updates. | 5.1.1 |
| **A shared server refuses requests without a phone id** (`CLACK_REQUIRE_USER=1`, docs/SERVER.md), so the laptop user's trips can't be read through it. | 5.1.1 |
| **Rate limits** on the server: 300 requests a minute per phone id, 120 per address without an id, a larger separate allowance for map tiles; live streams exempt. The server's inside views (import status, audit, live status, health details) need an admin token. | 1.6 |
| **Portrait iPhone app.** iPads run it in iPhone mode, which Apple allows. | 2.4.1 |
| **The server is online over https** and the app points at it: `Config.apiBase` is `https://clack-garner.duckdns.org` (a Hetzner VM; docs/SERVER.md). No placeholder address is left. | 2.1(a), 2.5.5 |
| **Bundle id** `com.garnerghering.Clack` (the widgets extension is `com.garnerghering.Clack.ClackWidgets`). | n/a |
| **Native touches** beyond a plain app: Home Screen and Lock Screen widgets, a Live Activity for the train you are on, time-sensitive alerts and the iOS share sheet for share cards (docs/IOS.md). | 4.2 |
| **Privacy manifest** (`PrivacyInfo.xcprivacy`): no tracking, the two collected data types below, and the UserDefaults reason. | Apple privacy manifests |
| **Swedish purpose strings** (`sv.lproj/InfoPlist.strings`: location, local network). | 5.1.1(ii) |

## Should do: strengthens the review, not strictly required

| What | Guideline | Who |
|---|---|---|
| **Review notes in ASC.** Say that there's no login, that data comes from Trafikverket and Entur, and how to try it: "Add a train: type SJ 523 for today; open Explore for the live map." | 2.1, 2.3.1 | ASC |

## App Store Connect answers, prepared

- **Privacy "nutrition label".** Data collected, all used for *App Functionality* only, *not* used for tracking:
  - *User Content > Other User Content*: the trips you add, and notes.
  - *Identifiers > User ID*: the random id that keeps a phone's trips together.

  Both are linked to the user (to the random id, not to a person). The random id is kept in the iCloud Keychain so a new iPhone gets the same trips back (the in-app text and the hosted privacy page say so, `privacy.idSync`). That does not change the answers: Apple holds the synced item, not Clack, there is still no account, and the id is not linked to a name, email or phone number. (Unverified: the app's `Identity.swift` does not yet mark the Keychain item as synchronizable, so make that change before the text ships.) Location is not collected (it stays on the phone). No contact info, no usage data, no diagnostics.
- **Age rating**: 4+. No objectionable content, no user-generated content shared with others, no web browsing.
- **Category**: Travel (secondary: Navigation).
- **Price**: free, no in-app purchases.
- **Screenshots**: 6.9-inch iPhone screenshots (1320 × 2868 px, or 1290 × 2796). Take them in the iPhone 17 Pro Max simulator with Cmd+S. They must show the app in use (2.3.3), not marketing art. Use your own trips; no other people's data.
- **Keywords**: describe the app ("train, rail, Sweden, Norway, delays, departures, logbook"). Don't list operator brand names to game search (2.3.7).

## Later (not needed for v1)

- iPad layout (2.4.1 encourages it, doesn't require it).
- Accessibility Nutrition Labels in ASC (optional): check VoiceOver labels and Dynamic Type first.
