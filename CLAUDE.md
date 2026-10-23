# Clack: notes for Claude

Clack logs the trains you ride in Sweden and Norway, shows them on the real tracks and builds a passport of your rail
history. The owner is Garner (he/him).

## Layout

- `apps/server`: Fastify + SQLite (Drizzle), run with tsx. Train data from Trafikverket, Trafiklab and Entur.
- `apps/web`: React 19 + Vite + MapLibre. The same build is the iPhone app.
- `apps/web/ios`: the Xcode project (Capacitor 8). Open `apps/web/ios/App/App.xcodeproj`.
- `packages/shared`: types and constants both apps use.
- `data/`: hand-made data (operators, train types, station maps), each fact with its source.
- `scripts/`: imports, station-map tools, and `scripts/trains/*.py`, which generate the train drawings.

## Which document wins

- `SPEC.md` wins on data and behaviour; `DESIGN.md` wins on anything visual. Read the relevant one before changing
  either.
- `docs/TRAIN_ART.md`: how train drawings are made (measured from photos, never guessed). Read it before touching
  `scripts/trains` or `apps/web/src/components/trains`.
- `docs/IOS.md`: the iPhone app, the server online, widgets and notifications. `docs/APP_STORE.md`: what App Review
  needs, what's done and what's still open.
- `*_FINDINGS.md`: what was learned about each data source. Check there before assuming what a feed contains.

## Standing rules

- **Accuracy first. Nothing made up.** Every train type, livery, line, amenity or station fact needs a source
  (`_source` in the data, or the script's docstring). If no source says it, show less (an unpainted train, "Train type
  not known") rather than guess. Say what's unverified.
- Status is written, not boxed: no pill-shaped badges, no 999px radii. Use the radius tokens (`--r-tag`,
  `--r-control-sm`, `--r-input`, `--r-card`, `--r-sheet`) and the ink colours in `apps/web/src/styles.css`.
- Every user-facing string goes through i18n, in both `apps/web/src/i18n/locales/en.json` and `sv.json`.
- API keys live only in `.env` (see `.env.example`). Never commit them.
- Zero running costs: no paid services.
- Don't put the owner's email address in requests, headers or user agents.

## Commands

- `npm run dev`: server and web app (http://localhost:5173).
- `npm test`: all tests (vitest). `npm run typecheck`.
- `cd apps/web && npm run ios`: build the web app for the phone and copy it into the Xcode project; then Cmd+R in
  Xcode. `CLACK_DEV_URL=http://localhost:5173 npx cap sync ios` makes the simulator load the live dev server instead.
- `python3 scripts/trains/<model>.py --tsx`: regenerate a train drawing's component; then
  `python3 scripts/trains/export_svg.py` to refresh the SVG files in `assets/trains/`.

## Commits

- Run the tests and the typecheck before committing.
- Commit only files you changed, by path. Short subject, a body that says why.
- No AI model names or ids in commits, code or docs.
