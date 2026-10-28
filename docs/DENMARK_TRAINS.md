# Denmark: the train drawings, and when to use each one

Prepared 2026-10-28 for Clack. This replaces the earlier `DENMARK_TRAINS.md`: it adds everything learned while drawing,
and corrects two things that were wrong there (see "Corrections" at the end).

What's in this zip:

- the SVG files are in `assets/trains/` (`dk_*.svg`, and the two Snälltåget files, whose snowploughs were fixed for all Vectrons).
  fixed for all Vectrons).
- `every-danish-train.png`: all of them on one sheet.
- `scripts/`: the drawing scripts. Each one's docstring lists every source and measurement and says what is unverified.
  They belong in `scripts/trains/`; `dk_ir4.py` and `dk_ic2.py` import `end_car` from `dk_ic3.py`.
- `docs/denmark-trains/`: the original research notes (DSB, the smaller operators, Copenhagen urban rail, what the Danish feeds
  contain), each fact with its source URL.

Nothing has been committed.

A caveat about the sources: Wikipedia (en/da), dsb.dk, gocollective.dk and railcolornews.com were mostly blocked from
the session. A few Wikipedia pages could be read raw (`action=raw`); much of the rest comes from search-result summaries.
Where a fact rests on that alone it is marked **unverified**. Every drawing rule below needs a `_source` before it goes
into `data/train_types.json`.

---

## 1. The drawings

Every drawing is a side view, cab to the right, with no logos, lettering, numbers or pictograms, and a `plain`
(unpainted) version. The first-named livery under each model is the default for that model.

| Model id | What it is | Liveries (default first) |
|---|---|---|
| `dk_ic3` | DSB MF "IC3", 3-car diesel unit, rubber front | `dsb` (red), `dsb-silver`, `plain` |
| `dk_ir4` | DSB ER "IR4", 4-car electric unit, same front as the IC3 | `dsb` (red), `dsb-grey`, `plain` |
| `dk_ic2` | IC2, 2-car diesel unit, IC3-style front (Lokaltog) | `lokaltog`, `plain` |
| `dk_stog_sa` | DSB S-tog litra SA (also serves SE) | `dsb` (refurbished), `dsb-old`, `plain` |
| `dk_eb_dd` | DSB EB Vectron + double-deck coach | `dsb`, `plain` |
| `dk_eb_talgo` | DSB EB Vectron + Talgo 230 end car | `dsb`, `plain` |
| `dk_lint41` | Alstom Coradia LINT 41, first generation | `vores-tog`, `gocollective`, `lokaltog`, `plain` |
| `dk_lint41_nj` | Coradia LINT 41, new front (Nordjyske NJ 601–617) | `nordjyske`, `plain` |
| `dk_desiro` | Siemens Desiro Classic (DSB MQ family) | `arriva`, `nordjyske`, `plain` |
| `dk_mireo_b` | Siemens Mireo Plus B battery unit | `midtjyske`, `plain` |
| (existing) `x31` | ET / X31K, for Kystbanen | `oresundstag` (already in the repo) |

### dk_ic3: DSB MF "IC3"

- **What the drawing shows:** the leading end car whole and the start of the middle car.
- **Liveries:**
  - `dsb`: red, with a black window band, a light grey roof and a dark grey sill. This is the 2018–20 overhaul design:
    da.wikipedia says all sets were overhauled 2018–20 with a new exterior and shows "IC3 51 i det nye røde design i
    2018". **Use this one.**
  - `dsb-silver`: stainless with lime-green door panels, from photo 160. No source names this scheme or says how many
    sets wear it, and the logo on that set's face isn't DSB's hexagon, so whose scheme it is remains unverified. Not
    used by any rule; keep it in case it turns out to be real and current.
  - Not drawn: the 2002–07 grey and blue livery, which the overhaul replaced.
- **Measured:**
  - The rubber front and cab are traced from photo 190 (MFB 5251, side-on). The rubber is 0.33 m deep, level with the
    roof, and curls under into a grey lip.
  - The car layout comes from photo 160, straightened, against da.wikipedia's car lengths (20.54 m end cars, 17.74 m
    middle car).
- **Unverified:**
  - the red IC3's passenger door, drawn in body colour
  - the wheel size
  - the bogie positions, estimated
- **Fleet in 2026:** in service. IC5 is to replace it by about 2030.

### dk_ir4: DSB ER "IR4"

- **What the drawing shows:** the same end car code as the IC3 (`end_car`), with the ER's own windows, door and paint.
- **Liveries:**
  - `dsb`: red with a black window band, the same scheme as the red IC3. da.wikipedia says "IR4 renoveres fra 2021 til
    2026". **Use this one.**
  - `dsb-grey`: the 2003–05 grey with a navy band. Kept because the refurbishment runs to 2026, so a few sets may still
    be grey. Unverified whether any still are.
- **Measured:** photo 161 (unit 2120), straightened, plus a 2013 Commons panorama (ER 2133) for the car joint. Car
  lengths are from da.wikipedia: 20.53 m and 17.73 m.
- **Fleet in 2026:** 44 sets were built. 43 are in service, because ER 2001 was written off after the Bjerndrup accident
  on 15 Aug 2025 (da.wikipedia).

### dk_ic2: IC2 (Lokaltog)

- **Not a DSB train.** All 13 sets were built for the private railways (Adtranz Randers, 1997) and have been
  Lokaltog's since 2015. DSB's own former "IC2" was a different, short IC4 variant.
- **What the drawing shows:** the FS car, which has the low floor and a cab side window but no cab door, and the start
  of the MF car.
- **Livery:**
  - `lokaltog`: a light body, a dark blue window band, a grey-brown skirt, and a red cab-end panel with a diagonal rear
    edge.
  - No source states the 2026 paint. The photos (FS 1123) date from about 2018, under Lokaltog, by my estimate from
    the stock-photo ID ranges.
- **Measured:** photo 187, straightened. Lengths from da.wikipedia: 20.5 m per car, 41 m per train.
- **Unverified:**
  - the roof box position (about ±1 m)
  - the middle bogie's wheelbase
  - the wheel size
  - the height scale (assumes a 3.00 m body side)
- **Fleet in 2026:** in service. Two sources give different replacements:
  - Region Sjælland (Nov 2025): LINT 41 from about 2029 on Lollandsbanen.
  - Stadler (Oct 2024): 14 FLIRT Akku battery units from 2027–28.

### dk_stog_sa: DSB S-tog SA / SE

- **Liveries:**
  - `dsb`: the refurbished look. Red, with a dark grey band through the windows from the nose seam to the end of the
    car, broken by white door leaves.
  - `dsb-old`: all red, as SA 9197 in July 2024.
  - **Both are in service in 2026.** The refurbishment began in 2024 with 32 sets and is meant to cover the whole fleet
    by 2028 (DSB press release, February 2024; TV2 Kosmopol). Both were seen only through search summaries, so the
    timeline is unverified. The data can't say which one a given train is, so use `dsb` as the default.
- **SE:** the 4-car SE has the same cab car and body, so this drawing serves SA and SE.
- **Measured:**
  - Traced from FUNET's photo of SA 9197 at Hundige (4 Jul 2024), straightened.
  - The new livery's band edges are read by eye from the owner's photo of SA 8132, which wasn't on disk.
- **Unverified:**
  - the roof crown height (3.85 m) and the 83.78 m train length, which together set the scale
  - the wheel size
- **Running gear:** single axles, not bogies: one under the cab car and one at each joint, covered by panels (FUNET).

### dk_eb_dd: DSB EB Vectron + double-deck coach

- **The loco:** the same standard AC Vectron as `snalltaget`, with the geometry copied unchanged and DSB's paint:
  - red sides and a dark grey underframe band
  - a grey roof, with grey cab tops that curve down each cab to just below the windscreen
- **The paint's sources:** where the colours meet comes from the side-on Piko model (photo 169). Photo 170 (EB 3238)
  and photo 180 (EB 3231) confirm it on real locos.
- **The coach:** silver-grey with a navy band and a dark grey skirt. The builder is Bombardier Görlitz (ing.dk).
- **Unverified (coach):** the heights. The roof is assumed at 4.63 m from the related German double-deck coaches, and
  the other heights are read in perspective (±0.15 m).

### dk_eb_talgo: DSB EB Vectron + Talgo 230

- **What the drawing shows:** the same EB loco, plus the first 6.85 m of the Talgo end car with its end bogie.
- **Livery:** red with a black window band, a grey roof, a dark grey underframe and light grey door leaves.
- **Measured:** photo 179, side-on, 40.8 px/m.
- **Unverified:**
  - The 13.3 m / 18.3 m / 3.8 m dimensions are the German ICE L version's; DSB's cars are assumed the same.
  - The underframe is simplified into one continuous skirt. The bogie frame, the wheel size and the coupler are
    estimated.

### dk_lint41: Coradia LINT 41, first generation

- **Liveries** (the Lokaltog one is described under "Measured" below):
  - `vores-tog`:
    - The paint: Arriva's teal, with a cream sweep over the cab (rounded corners) and a yellow sill line that breaks at
      the doors.
    - Why it's the default: photo 166 (2026) shows Vores Tog stickers on this paint, so DSB Vores Tog kept it after
      taking over on 1 Sep 2026. All 43 sets were delivered in teal, and I found no fleet repaint programme.
    - **Unverified:** this is a judgement, not a count.
  - `gocollective`:
    - The paint: white with a dark grey window band, a grey cap over the cab, yellow doors with a yellow stripe up to
      the roof, and a dark grey nose bottom.
    - Source: photo 191 (AR 2043). The only other repaint evidence is one GoCollective news item about a
      crash-repaired set "in new clothes". A minority paint.
- **Measured:**
  - The body, nose, windows and door are traced from photo 164 (AR 1012, near side-on).
  - The Lokaltog livery edges (`lokaltog`) are traced from Lokaltog's own 2025 drone photo. The livery is a yellow cab
    end sweeping into a white body, a light grey band, a dark grey skirt, and dark grey above the windscreen.
  - Length: 41.81 m, from Alstom's data sheet.
- **Unverified:**
  - the wheel size and bogie wheelbases
  - heights (±0.1 m) and the windscreen edge (±0.15 m)
  - the plough under the nose

### dk_lint41_nj: Nordjyske's newer Coradia LINT 41 (NJ 601–617)

- **A different front** from the first generation: the post-2011 crash-optimised nose.
- **Livery:** `nordjyske` (today's paint):
  - a light-blue upper band sweeping down the nose
  - dark ultramarine below
  - a dark-blue outline stripe around the nose
  - rounded corners where the colours meet
- **Measured:**
  - the layout and nose from jernbanen.dk's side drawing of LM 605
  - the paint and positions from jernbanen.dk's near side-on photo of LM 609 (Aalbæk, 2025), straightened; they agree
    with the drawing to within 0.1 m
  - 42.17 m long, 16.5 m bogie centres (de.wikipedia)
- **Unverified:**
  - the exact shape of the light-blue sweep around the nose (it follows the side drawing)
  - the width of the dark-blue stripe
  - the wheel size
  - LM 611, which has dark blue on the lower cab where the others are light blue (the majority is drawn)

### dk_desiro: Siemens Desiro Classic

- **Liveries:**
  - `arriva`:
    - The paint: white with a navy window band, a grey cap and rim, and a grey skirt. It's DSB's MQ scheme as Arriva
      kept it.
    - Photo sources: 192 and 193, plus a 2012 Commons panorama of DSB MQ 4912 with the same layout.
    - Why not called `vores-tog`: DSB took over these lines on 1 Sep 2026 (Altinget), but no dated photo shows what
      the Desiros wear since.
  - `nordjyske`:
    - The paint: ultramarine blue, a grey cap running down the nose into the windscreen frame, a grey skirt, and a
      yellow strip on the doors.
    - Photo sources: 174–177.
    - Left out: the thin light-blue and gold swirls on the sides. They differ from unit to unit (each unit is named
      after a local artist) and no photo shows a whole side.
  - Not drawn: Midtjyske's MQ 4111–4114, for lack of a photo in their current paint.
- **Measured:**
  - Length and floor height: 41.7 m and 575 mm at the doors (de.wikipedia "Siemens Desiro Classic" and "DSB MQ").
  - The window and door layout comes from photo 173, straightened (a Czech unit, used for the body shape only).
  - The nose outline comes from the Commons panorama, the only truly side-on source.
- **Unverified:**
  - the cab window positions, set 0.4 m further back than the panorama to match the proportions in 175/176
  - the coupler length (overall scale ±2%)
  - the wheelbases and wheel size
  - whether the NJ and Arriva paints are still on the units in 2026
- **The weakest drawing of the set.** A clean side-on Desiro photo would settle the front.

### dk_mireo_b: Siemens Mireo Plus B (Midtjyske Jernbaner)

- **Livery:** `midtjyske`, as on the real MJB 10A (photo 185):
  - orange at the top fading to red, with a white top edge
  - white sweeping down over the cab, with a red patch under the cab side window
  - a rolling white band along the bottom over a black skirt
  - black doors, dome and windscreen surround
  - Left out: the line-art illustrations and the front chevron.
- **Measured:**
  - The layout comes from the side drawing in Siemens' Mireo Plus B (Ortenau) data sheet, at 46.56 m over couplers.
  - The wheels and doorways come from the Mireo Smart data sheet: 880 mm wheels, 1.3 m doorways.
  - The positions are checked against photo 185, straightened, to within 0.2 m.
- **Unverified:**
  - the coupler length and the Jacobs bogie wheelbase
  - the exact nose and windscreen edges
  - the colours: the photo is overcast, so the orange was taken from the render (184)

---

## 2. What Clack knows about a Danish train

Danish data comes from the GTFS timetable and Rejseplanen's live data (details in `research/feeds.md`).

What Clack gets:
- **Operator:**
  - DSB, DSB S-tog, DSB Vores Tog, Lokaltog, NT (Nordjyske), Midttrafik (Midtjyske Jernbaner's trains appear under
    this operator)
  - on the live side also Skånetrafiken (Øresundståg) and Snälltåget
- **Category / route short name:**
  - IC, ICL, Re, RA, RX, ECE, RJ
  - the S-tog letters A B Bx C E F H
  - Lokaltog 110R–960R, NT 75/76, Midttrafik 92/93
- **Train number**, and the **first and last station** of the trip.

What it does **not** get:
- **No vehicle or unit id, and no composition.** This is the big difference from Sweden, where SJ's planned coach order
  names the train.
- **IC and ICL** both become the product `intercity`, so rules can't tell them apart (a small code change would add a
  `category` match).

So in Denmark the model is decided by **operator + line (both ends)**, never by vehicle. Where one operator runs one
model on a line, that's certain. Where two models share the same trains, the honest answer is a two-model **uncertain**
type, like Sweden's "X11 or X14".

### Which livery

The livery follows the operator, with one default per model, because the data can't tell repainted units apart:

| Operator | Livery used |
|---|---|
| DSB | `dsb` |
| DSB Vores Tog | LINT → `vores-tog` (teal); Desiro → `arriva` |
| Lokaltog | `lokaltog` |
| Nordjyske | `nordjyske` |
| Midttrafik / Midtjyske | `midtjyske` |

The other liveries (`dsb-silver`, `dsb-grey`, `dsb-old`, `gocollective`) are real but are never picked by a rule. They
exist for the minority of units that wear them, and for a later override if a feed ever names the unit.

---

## 3. The rules, most specific first

Clack applies `data/train_types.json` rules in order, so line rules come before operator-wide fallbacks. "Ends" means
the trip's first and last stations (`both_ends`), with Danish names and "St." dropped.

| # | Operator | Match | Type (art) | Confidence and reasoning |
|---|---|---|---|---|
| 1 | DSB S-tog | operator DSB S-tog, or DSB with product commuter (S-tog letters) | **S-tog SA/SE** (`dk_stog_sa-dsb`) | **Certain.** One generation in service in 2026. The new driverless fleet (Siemens + Stadler) carries no passengers yet. |
| 2 | DSB | category ECE / EC, Copenhagen–Hamburg | **EB + Talgo 230** (`dk_eb_talgo-dsb`) | **High.** The Talgo sets started 3 Nov 2025 and are reported to cover all departures from about May 2026. Some Prague-linked runs may use Czech stock (sources conflict); RJ trains are not covered. |
| 3 | DSB | both ends on Kystbanen: Helsingør, Snekkersten, Espergærde, Humlebæk, Nivå, Kokkedal, Rungsted Kyst, Vedbæk, Skodsborg, Klampenborg, Hellerup, Østerport, Nørreport, København H | **ET** (`x31-oresundstag`) | **Medium. Needs checking, see Corrections.** en.wikipedia gives Kystbanen's stock as ET-FT-ET, but the X31 research found that all DSB's ETs passed to Skånetrafiken in 2022–23. Kystbanen trains also run on past København H into Zealand, so `both_ends` may not catch them. |
| 4 | DSB | regional (Re) with both ends on **electrified** Zealand lines: København–Roskilde–Holbæk, København–Ringsted–Næstved (–Nykøbing F) | **EB + double-deck coaches** (`dk_eb_dd-dsb`) | **High for the train type, medium for the line list.** Since the ME diesel locos retired (Dec 2021), every DSB loco is an EB Vectron, and the EB is electric, so it can only work electrified lines. Roskilde–Holbæk was electrified in 2021. Whether Næstved–Nykøbing F is electrified in 2026 is unverified. |
| 5 | DSB | IC/ICL/Re with an end on a **non-electrified** line: Holbæk–Kalundborg, and in Jutland e.g. Aarhus–Aalborg–Frederikshavn, Struer, Thisted, Skjern, Sønderborg (list to verify against Banedanmark's electrification map) | **IC3** (`dk_ic3-dsb`) | **Medium.** The IR4 and EB are electric, IC4 is being withdrawn, and IC5 isn't in service, so a DSB train on a non-electrified line is an IC3. A Folketing answer (2021–22) confirms DSB couldn't run double-deck trains Roskilde–Kalundborg because it isn't electrified, and used IC3/IC4 there instead. Exactly which lines are still unelectrified in 2026 needs a source. |
| 6 | DSB | any other IC/ICL | **"IC3 or IR4"** (uncertain; art `dk_ic3-dsb`) | **Honest default.** Both run the same IC services and are often coupled together, and nothing in the data says which. Both are red, so the picture is right either way. |
| 7 | DSB | any other Re | **"IC3 or IR4"** (uncertain) | Same reasoning. EB + double-deck only where rule 4 matched. |
| 8 | DSB Vores Tog | both ends on Svendborgbanen (Odense–Svendborg) | **Desiro** (`dk_desiro-arriva`) | **Medium.** Desiros have run Odense–Svendborg since 2008 (DSB MQ). The 2026 assignment comes from an older secondary source. |
| 9 | DSB Vores Tog | both ends on Vejle–Struer or Struer–Thisted | **"LINT 41 or Desiro"** (uncertain) | **Low.** An older source puts Desiros on these lines, alongside LINTs. Midtjyske Jernbaner may run Thybanen as DSB's subcontractor from Oct 2026 (single source), with unknown stock. |
| 10 | DSB Vores Tog | any other line (Aarhus–Herning–Struer, Aarhus–Langå–Viborg–Struer, Esbjerg–Skjern–Herning, Varde–Nørre Nebel, Esbjerg–Niebüll) | **LINT 41** (`dk_lint41-vores-tog`) | **Medium-high.** About 43 of the ~58 sets are LINT 41, and these are the LINT lines. Teal is the default paint (see section 1). |
| 11 | Lokaltog | both ends on Nærumbanen (Jægersborg–Nærum) | **RegioSprinter**: **not drawn yet**, so use a fallback | **High.** The 4 RegioSprinters run only there (Region Hovedstaden, 2019). Until a drawing exists, use the faded unpainted stand-in, `dk_lint41-plain`. |
| 12 | Lokaltog | both ends on Lollandsbanen (Nykøbing F–Nakskov) or Tølløsebanen (Holbæk–Tølløse–Slagelse) | **IC2** (`dk_ic2-lokaltog`) | **Medium.** da.wikipedia puts the IC2s on Lollandsbanen and Odsherredsbanen/Tølløsebanen, and Region Sjælland says Lollandsbanen keeps them until about 2029. Odsherredsbanen is also documented with LINT 41, so leave it to rule 13. Østbanen/Lille Syd may mix (unverified). |
| 13 | Lokaltog | any other line (Hornbækbanen, Gribskovbanen, Frederiksværkbanen, Odsherredsbanen, Østbanen, Køge–Roskilde) | **LINT 41** (`dk_lint41-lokaltog`) | **High.** 41 LINT 41 sets make up most of the fleet (Folketing paper, 2018–19). |
| 14 | NT (Nordjyske) | any line (Skagensbanen, Hirtshalsbanen, Aalborg–Frederikshavn, Aalborg–Skørping/Hobro) | **"LINT 41 or Desiro"** (uncertain; art `dk_lint41_nj-nordjyske`) | **Honest.** NJ runs 17 new-generation LINT 41 (NJ 601–617) and 8 Desiros, mixed, and no source assigns them by line. The LINT is the art because it is two-thirds of the fleet. |
| 15 | Midttrafik (Midtjyske Jernbaner) | rail routes 92/93, or both ends on Vemb–Lemvig–Thyborøn / Holstebro–Skjern | **Mireo Plus B** (`dk_mireo_b-midtjyske`) | **High.** 7 Mireo Plus B replaced the Desiros from Dec 2025 (Midtjyske's press release, ing.dk; exact start date unverified). Match on rail only, so Aarhus Letbane trams under Midttrafik aren't caught. |
| 16 | Skånetrafiken (Öresundståg) | any trip in Denmark | **X31** (`x31-oresundstag`) | **Certain.** Same as in Sweden. |
| 17 | Snälltåget | any | **Vectron + coach** (`snalltaget-snalltaget`) | **Certain.** Stockholm–Copenhagen since Oct 2025, on to Hamburg since May 2026. |
| 18 | SJ | X2000 Stockholm–Copenhagen | **X2000** (existing) | Paused 2024 and due back autumn 2026; restart unverified. |

### Suggested uncertain types

Mark these `"uncertain": true`, as in Sweden:

- **`dk_ic3_ir4`**, "IC3 or IR4": "DSB runs IC3 and IR4 sets, often coupled together, on the same InterCity and
  regional trains; nothing in the data says which set a given train is." Art: `dk_ic3-dsb`.
- **`dk_lint41_desiro_nj`**, "LINT 41 or Desiro": "Nordjyske Jernbaner runs both on its lines." Art:
  `dk_lint41_nj-nordjyske`.
- **`dk_lint41_desiro_vt`**, "LINT 41 or Desiro": for Vores Tog's Vejle–Struer and Struer–Thisted. Art:
  `dk_lint41-vores-tog`.

### Trains without a drawing (use the fallback)

| Train | Status | Suggested stand-in |
|---|---|---|
| RegioSprinter | Nærumbanen | `dk_lint41-plain`, faded |
| IC4 (MG) | Being withdrawn; may already be gone | `dk_ic3-plain`, faded, only if a trip is ever matched to it |
| IC5 | No passengers until 2027 | none needed yet |
| Metro, Ring 3, Odense and Aarhus light rail | Trams/metro, out of scope | leave out (your call; the Aarhus Tango units on the Grenaa/Odder lines run like regional trains) |

---

## 4. What would make the Danish logic better

1. **SIRI-ET from Dataudveksleren** (Denmark's official live feed; needs a MitID login). It's the only source that
   might name the actual vehicle or formation (`VehicleRef`). If it does, Clack could tell IC3 from IR4 per train, and
   repainted units, like SJ in Sweden. Not checked.
2. **A `category` match field** for rules (IC vs ICL vs Re vs RA/RX), so ICL stays visible and rules get simpler.
3. **Allow the blocked sites** (da.wikipedia.org, dsb.dk, gocollective.dk, railcolornews.com) in the environment's
   network settings, then verify the unverified points above. The most important ones:
   - what stock runs Kystbanen in 2026
   - which lines are non-electrified in 2026
   - which paint most Vores Tog LINTs wear
   - whether Næstved–Nykøbing F is electrified

---

## 5. Corrections to the earlier research document

1. **Copenhagen–Kalundborg is not an EB + double-deck line.**
   - The earlier document said it was. The line is electrified only as far as Holbæk (since 2021), and the EB is an
     electric loco.
   - A Folketing answer (2021–22) says DSB couldn't run double-deck trains Roskilde–Kalundborg and used IC3/IC4
     instead.
   - So trains to Kalundborg are IC3 (rule 5), and EB + double-deck covers only the electrified Zealand lines (rule 4).
2. **Kystbanen's ETs.**
   - The earlier document said Danish ETs run Kystbanen as DSB trains. The X31 drawing's research found that DSB sold
     all its ETs to Skånetrafiken/Region Skåne in Dec 2022 and May 2023 (järnväg.net, sv.wikipedia).
   - en.wikipedia still lists ET-FT-ET for Kystbanen, so the stock may be leased back.
   - Treat rule 3 as medium confidence until a 2026 source settles it.
3. **The IC2 isn't ex-DSB.**
   - It was built for the private railways in 1997 and has been Lokaltog's since 2015.
   - DSB's own former "IC2" (retired in 2016) was a short IC4 variant, which is a different train.

Sources checked again while writing this: [en.wikipedia Kystbanen](https://en.wikipedia.org/wiki/Kystbanen),
[Northwest Line (Denmark)](https://en.wikipedia.org/wiki/Northwest_Line_(Denmark)),
[Folketing answer on Roskilde–Kalundborg](https://ft.dk/samling/20211/almdel/tru/spm/119/svar/1844036/2509050.pdf),
[ing.dk on battery trains to Kalundborg](https://ing.dk/artikel/ministeriet-og-dsb-kan-vi-koere-batteritog-til-kalundborg).
Every other source is in the scripts' docstrings and in `research/`.
