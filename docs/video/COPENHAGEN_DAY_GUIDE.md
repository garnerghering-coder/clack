# København H, one weekday: video guide

A guide for making a short looping Instagram video: a whole weekday of trains at København H (Copenhagen Central),
drawn the way the Clack app's Explore map draws them. Everything you need is in the kit folder
(`~/Downloads/clack_video_kit/`, made by `apps/server/src/tools/videoDay.ts`). You don't need the Clack server or the
app, and you need no internet once the kit is local.

Read this whole guide before starting. Where it gives a number, use that number. Where something isn't covered, keep
to the look of the reference screenshots in `brand/reference/`.

---

## 1. What to make

- **File:** `kobenhavn_h_day.mp4`, H.264, 1080 × 1920 (9:16), 30 fps, **12.0 s (360 frames)**, `yuv420p`, no audio
  track. Also export frame 0 as `cover.png` for the post's cover.
- **A perfect loop:** frame 360 would be identical to frame 0. Camera, clock and counters all come back to where they
  started.
- **Look:** Clack's Explore map in dark mode, cleaned up. Near-black land and water, faint roads, thin white tracks,
  white station rings, the station in 3D (platforms, buildings, see-through roofs), and trains as rows of coloured
  car boxes in their operator's colour. On top: a flip-tile clock and two counters.
- **Honest:** this is the **timetable** for Tuesday 10 November 2026, with trains placed on the real tracks by Clack's
  run model. No delays are shown. The video says so in its small caption (section 6).

## 2. The kit

| File | What it is |
|---|---|
| `trains.json` | Every train that comes within 6 km of København H that day (1,535). For each: `number`, `operator`, `category` (`commuter` = S-tog, `regional`, `intercity`), `color` (#rrggbb), `type`, `cars`, `carLengthM`, `here` (its arrival `arr`, departure `dep` and `platform` at København H, in seconds after midnight), and `samples`. |
| `samples` | `[seconds after local midnight, lon, lat, bearing°]` every 5 s while the train is within 6 km. A `bearing` of `-1` means it's standing at a platform: keep its last moving bearing. Seconds can go past 86,400 (after midnight, same service day). |
| `counts.json` | Departures and arrivals at København H per minute (`departures[i]`, `arrivals[i]`, i = minutes after midnight, up to 26 h). Totals: 1,423 departures, 1,422 arrivals. |
| `station.geojson` | København H in 3D. Platforms (`kind: platform`, `height` in metres) and laser-measured buildings and roofs (`kind: structure`, `cls: building`/`roof`, `base` and `height` in metres above the rails). Also lines across platforms where lettered sectors meet (`cls: sector`); ignore those. |
| `tracks.geojson` | Every track around the station (`cls: track`, or `siding` for yards and sidings). |
| `rail-network.geojson` | Station markers with `name` and `dpd` (departures per day: bigger means more important). |
| `basemap/{z}/{x}/{y}.mvt` | Vector map tiles for the area (zoom 5–10, layers `earth`, `water`, `roads`, `places`, `boundaries`). MapLibre overzooms them past 10. |
| `glyphs/` | Map label fonts (Noto Sans). |
| `style.json` | A ready MapLibre style with all of the above, in Explore's dark colours. Use it as is, and add the train layers (section 5). |
| `brand/colors.json` | Clack's colours (map, station 3D, flip tiles, ink). |
| `brand/fonts/` | Space Grotesk Bold (times, numbers, flip tiles) and Inter (small text), with their licences. |
| `brand/reference/` | Screenshots from the app: Explore in dark mode with a train's flip-tile times, København H in 3D on Explore, and a preview of the whole day's paths. |
| `meta.json` | Station, centre (55.672692, 12.564631), date, counts, credits. |

## 3. How to render

Use a static web page, rendered frame by frame in a headless browser. Don't screen-record it in real time: a
frame-by-frame render is the only way to get an exact, smooth loop.

1. **Serve the kit:** from inside it, run `python3 -m http.server 8080`, and put your page (`index.html` plus your
   script) in the kit folder.
2. **The map:** MapLibre GL JS (v4 or newer), `style: 'style.json'`, a 1080 × 1920 container, and
   `preserveDrawingBuffer: true`. Don't add attribution or controls (the credits go in the caption, section 6). Set
   `interactive: false`.
3. **Step the frames yourself:** expose a function `renderFrame(i)` that
   1. works out the video time `t = i / 30`;
   2. sets the camera (section 4) with `map.jumpTo`;
   3. updates the train sources for the clock time (section 5);
   4. updates the overlay (section 6);
   5. resolves when `map.once('idle')` has fired.

   Never use `requestAnimationFrame` timing or CSS animations: every frame must depend only on `i`.
4. **Capture:** use Puppeteer (or Playwright). Launch Chrome with a WebGL-capable flag
   (`--use-angle=swiftshader --enable-unsafe-swiftshader` when there's no GPU), set the viewport to 1080 × 1920 with
   device scale 1, and for i = 0…359 call `renderFrame(i)` then take a screenshot of the page (map and HTML overlay
   together) to `frames/0000.png`…`0359.png`.
5. **Encode:**
   `ffmpeg -framerate 30 -i frames/%04d.png -c:v libx264 -pix_fmt yuv420p -crf 17 -preset slow -movflags +faststart kobenhavn_h_day.mp4`

## 4. Storyboard, camera and clock

The centre throughout is København H: **lon 12.564631, lat 55.672692**. Times are video seconds.

| Video time | Camera | Clock |
|---|---|---|
| 0.0 – 2.0 s | **3D, close:** zoom 16.6, pitch 60°, bearing turning 0° → +30° (15°/s). The station's platforms, hall and roofs fill the middle third. | 00:00 → 00:02, at about 1 minute per video second. |
| 2.0 – 3.5 s | **Rising out:** zoom 16.6 → 12.4 and pitch 60° → 0°, with an ease-in-out. Bearing +30° → 0°. | Speeding up. |
| 3.5 – 10.0 s | **Overhead:** zoom 12.4, pitch 0°, bearing 0°, north up. All the lines into the station show, and trains read as short coloured rows of cars. Hold still. | The day, fast. |
| 10.0 – 12.0 s | **Back down:** zoom 12.4 → 16.6, pitch 0° → 60° (ease-in-out, done by 11.5 s), bearing −22.5° → 0° (15°/s, the same turn as the opening, so the loop is seamless). | Slowing to 1 minute per video second, reaching 24:00 (= 00:00) at exactly 12.0 s. |

**Clock mapping** (clock time `T` in seconds after midnight, as a function of video time `t`):

- **Speed, in day-seconds per video-second:**
  - 0 – 2 s: 60;
  - 2 – 3.5 s: rises smoothly (smoothstep) from 60 to `V`;
  - 3.5 – 10 s: `V`;
  - 10 – 11.5 s: falls smoothly from `V` to 60;
  - 11.5 – 12 s: 60.
- **T(t)** is the integral of that speed from 0. Solve for `V` (numerically) so that T(12) = 86,400 exactly. `V` comes
  out at about 10,770 day-seconds per video second (the integral is 240 + 8V).
- **Check:** T(0) = 0 and T(12) = 86,400. At 30 fps the middle of the day moves about 6 minutes per frame.

## 5. Trains

For each frame, with clock time `T`:

- **Which trains:** a train is shown when it has a sample within 5 s of `T`, or of `T + 86,400` (that picks up last
  night's service still running just after midnight). Use whichever matches, and interpolate linearly between its two
  samples around that time.
- **Cars:** draw `cars` boxes, each `carLengthM` long and 3.0 m wide, along the train's path **behind** its head. Walk
  back through the samples before `T` to get the path. Leave a 1 m gap between cars.
  - Draw them as `fill-extrusion` polygons from 0.4 m to 3.8 m high, in the train's `color`.
  - Draw the front car 35% lighter (mix with white), as the app does.
  - In the close 3D shots these read as real trains. At zoom 12.4 a 200 m train is about 10 px long: small, but
    visible. That's the intent.
- **Light trails:** behind each train, a line along its path over the last **`D = max(120 s, 8 × day-seconds per frame)`**
  of clock time.
  - Width 3 px, in the train's colour lightened 20%.
  - Fade from opacity 0.9 at the head to 0 at the tail: use a GeoJSON source with `lineMetrics: true` and a
    `line-gradient`, or several short segments with falling opacity.
  - Add a soft glow under it: the same line at width 9 px, opacity 0.25, `line-blur` 4.
  - Through the fast middle of the day, the trails are what the eye follows. Every line into the station lights up and
    fades, brightest in the morning (07–09) and afternoon (15–18) peaks.
- **Layer order, bottom to top:**
  1. basemap;
  2. tracks;
  3. platform fills;
  4. trail glow;
  5. trails;
  6. 3D platforms, buildings and roofs (roofs at 0.45 opacity, so trains under them show);
  7. car boxes;
  8. station rings and names.
- **No labels on trains.** It's too busy at this speed.

## 6. Overlay (HTML on top of the map)

All of the overlay sits inside Instagram's safe area: nothing above y = 220 px or below y = 1600 px except the
caption.

### Flip-tile clock

- **Position:** top centre, the tiles' top at y = 260.
- **Content:** `HH` `:` `MM`, as four tiles plus a colon.
- **Each tile:** 150 × 210 px, radius 12 px, gap 12 px between the tiles of a pair and 36 px around the colon.
  - The top half is `#222222` and the bottom half `#1a1a1a`.
  - A 2 px hinge line across the middle, `rgba(0,0,0,0.6)`.
  - The digit is Space Grotesk Bold, 150 px, white, centred, `font-variant-numeric: tabular-nums`.
  - A soft shadow under the tile: `0 6px 18px rgba(0,0,0,0.5)`.
- **Colon:** two 14 px white dots.
- **Matching the app:** look at the times in `brand/reference/explore_dark_train_sheet.png` and match that flap look,
  scaled up.
- **The flip:** where a digit changes and the clock is slow (the first and last 2 s), animate the flip across 6 frames.
  - The top half of the old digit folds down over the bottom half, showing the new digit's top behind it.
  - Then the new bottom half lands.
  - Work out the flip's progress from the frame number, not from CSS. In the fast middle, just show the new digits
    with no flip animation.

### Counters

- **Position:** a row 48 px under the clock: `DEPARTURES` on the left half, `ARRIVALS` on the right half.
- **Label:** Inter SemiBold 30 px, letter-spacing 0.06 em, colour `#9a9a9a`.
- **Number:** Space Grotesk Bold 84 px, white, `tabular-nums`, with a thin space as the thousands separator (1 423).
- **The totals:** the sum of `counts.json` `departures` (and `arrivals`) from minute 0 up to `floor(T/60)`. For
  T ≥ 86,400 use the full day's totals, which are 1,423 and 1,422.
- **At the loop:** the numbers show the full day at the end and 0 again at frame 0, like the start of a new day.
  That's intended.

### Caption

- **Position:** bottom, from y = 1640.
- **Station line:** `København H · one weekday, from the timetable` in Inter Medium 34 px, white at 0.9.
- **Credits:** under it, in Inter 20 px, `#9a9a9a`:
  `© OpenStreetMap contributors · Protomaps · Rejseplanen · Banedanmark · Danmarks Højdemodel © Klimadatastyrelsen (CC BY 4.0) · Trafiklab`.
  These are required by the data's licences; don't drop them.
- **Brand:** the word **clack** in Space Grotesk Bold 44 px, in Clack yellow `#ffd400`, right-aligned on the same row
  as the station line.

## 7. Rules (these come from how Clack works)

- **Nothing made up.** Show only what's in the kit. Don't add trains, change times, invent delays or add stations. If
  something looks wrong in the data, leave it and note it (section 8). Don't fix it by hand.
- **Colours:**
  - Trains: their own `color` only.
  - Clack yellow (`#ffd400` or `#f8d64a`): only for the brand word and the few trains that already have it.
  - Everything else: the dark palette in `brand/colors.json`.
- **No pills:** no fully rounded badges or 999 px radii. Use the radius values in `brand/colors.json` (tiles 12, cards
  16).
- **Fonts:** Space Grotesk for numbers and times, Inter for words, Noto Sans for map labels. No other fonts.
- **Keep the caption.** "one weekday, from the timetable" stays in the video.

## 8. Check before handing over

- [ ] 360 frames, 1080 × 1920, 30 fps, 12.0 s, no audio track.
- [ ] Frame 0 and frame 359 flow into each other: same camera path, the clock reads 23:59 then 00:00, no jump in
      zoom, pitch or bearing.
- [ ] The opening shows København H's platforms and buildings in 3D, with trains standing at the platforms as boxes.
- [ ] In the overhead part all the lines into the station are visible: the coast line to the north, west towards
      Valby, and south-east towards the airport and the Øresund bridge. Trains and trails stay on the tracks.
- [ ] The clock never shows a time that goes backwards. The counters only go up, and they end at 1 423 and 1 422.
- [ ] All text sits inside the safe area. The credits are readable at full size.
- [ ] Hand back: `kobenhavn_h_day.mp4`, `cover.png`, your `index.html` and script, and a short note of anything in the
      data that looked wrong (with the train number and the time).

## 9. If you want more

- **Longer:** 15 s, with the same beats and the overhead hold stretched to 9.5 s (re-solve `V`).
- **Captions in Swedish:** `København H · en vardag, enligt tidtabellen`, labels `AVGÅNGAR` and `ANKOMSTER`.
- **Another station or day:** re-run
  `npx tsx apps/server/src/tools/videoDay.ts <station id> <YYYY-MM-DD> <out dir>` in the Clack repo (Malmö C is
  `740000003`, Stockholm C `740000001`).
