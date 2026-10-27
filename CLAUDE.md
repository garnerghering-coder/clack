# Clack: notes for Claude

Clack logs the trains you ride in Sweden, Norway and Finland (and Denmark, timetable only for now), shows them on the real tracks and builds a passport of your rail
history. The owner is Garner (he/him).

## Layout

- `apps/server`: Fastify + SQLite (Drizzle), run with tsx. Train data from Trafikverket, Trafiklab, Entur, Digitraffic (Fintraffic) and Rejseplanen (Denmark). It also
  serves the privacy page. The hosted copy: docs/SERVER.md.
- `apps/Clack`: the native SwiftUI iPhone app, the only client (docs/SWIFT_PORT.md). Open `apps/Clack/Clack.xcodeproj`.
  `apps/Clack/ClackKit` is a Swift package with the targets ClackCore (logic, API, strings) and ClackDesign (tokens
  and components); code is moving into it from the app target.
- `packages/shared`: types and constants the server uses.
- `data/`: hand-made data (operators, train types, station maps), each fact with its source.
- `assets/trains`: the train drawings (SVG). `fi_*.svg` (Finland) are hand-made and owner-supplied, with no generator
  in `scripts/trains`; where they were measured from is not recorded here, and `export_svg.py` leaves them alone.
- `scripts/`: imports, station-map tools, `scripts/trains/*.py` (generate the train drawings) and `scripts/ios/`
  (copy strings and drawings into the app, make its icons and colours).

## Which document wins

- `SPEC.md` wins on data and behaviour; `DESIGN.md` wins on anything visual. Read the relevant one before changing
  either.
- `docs/TRAIN_ART.md`: how train drawings are made (measured from photos, never guessed). Read it before touching
  `scripts/trains` or `assets/trains`.
- `docs/SWIFT_PORT.md`: the plan for the native app, step by step, with its references in `docs/swift-port/`.
- `docs/IOS.md`: the app's native parts (alerts, Live Activities, tickets, offline, widgets). `docs/SERVER.md`: the
  hosted server. `docs/APP_STORE.md`: what App Review needs, what's done and what's still open.
- `*_FINDINGS.md`: what was learned about each data source. Check there before assuming what a feed contains.

## Standing rules

- **Accuracy first. Nothing made up.** Every train type, livery, line, amenity or station fact needs a source
  (`_source` in the data, or the script's docstring). If no source says it, show less (an unpainted train, "Train type
  not known") rather than guess. Say what's unverified.
- Status is written, not boxed: no pill-shaped badges, no 999px radii. Use the radius tokens (`--r-tag`,
  `--r-control-sm`, `--r-input`, `--r-card`, `--r-sheet`) and the ink colours in `apps/Clack/Clack/Design/Tokens.swift` (moving to `ClackKit/ClackDesign`).
- Every user-facing string goes in the String Catalog `apps/Clack/ClackKit/Sources/ClackCore/Resources/Localizable.xcstrings`,
  in English and Swedish (keys are dot paths, read with `L10n.t`). The server reads the same catalog for delay causes and
  the privacy page (`packages/shared/src/strings.ts`).
- API keys live only in `.env` (see `.env.example`). Never commit them.
- Zero running costs: no paid services.
- Don't put the owner's email address in requests, headers or user agents.

## Commands

- `npm run dev`: the server (http://localhost:3001). `npm test`: all tests (vitest). `npm run typecheck`.
- App build: `xcodebuild -project apps/Clack/Clack.xcodeproj -scheme Clack -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/clack-sim build`;
  the same with `test` instead of `build` runs the app's tests. `swift test` in `apps/Clack/ClackKit` runs the package's.
- `python3 scripts/ios/sync_assets.py`: copy the train drawings and the delay-cause table into the app (after changing either).
  `python3 scripts/ios/make_icon.py` (app icon), `python3 scripts/ios/make_colors.py` and
  `node scripts/ios/make_icons.mjs` (colours and Lucide icons) when those change.
- `python3 scripts/ios/lint_design.py`: the design lint (coming in a later workstream; not there yet).
- `python3 scripts/trains/<model>.py`: print a train drawing; then `python3 scripts/trains/export_svg.py` to refresh
  the SVG files in `assets/trains/`.

## Commits

- Run the tests and the typecheck before committing.
- Commit only files you changed, by path. Short subject, a body that says why.
- No AI model names or ids in commits, code or docs.
