# Copenhagen urban rail (and Danish light rail): findings for Clack

Read 2026-10-28. Wikipedia, dsb.dk, railway-news.com and urban-transport-magazine.com could NOT be fetched from
this session (blocked hosts), so most facts below come from search-result summaries of those pages, not from
pages read in full. Treat everything as "to verify against the page" before it goes into `data/`.

## DSB S-tog (S-train)

- **Lines:** seven lines: A, B, Bx, C, E, F, H. Six of them pass København H, towards Hillerød, Klampenborg, Farum,
  Frederikssund, Høje Taastrup and Køge. F is the ring line, Hellerup to Ny Ellebjerg, and does not pass København H.
  Source: DSB station pages, e.g. https://www.dsb.dk/trafikinformation/stationer/hareskov/ and
  https://www.dsb.dk/trafikinformation/stationer/fuglebakken/ (search summary).
- **Termini per line (from mixed sources; UNVERIFIED for the 2026 timetable):**
  - A: Hillerød to Køge (via Solrød Strand). https://routes.tracestrack.com/route/5612119 (OSM route data, secondary)
  - B: Farum to Høje Taastrup. https://en.wikipedia.org/wiki/B_(S-train)
  - Bx: Farum line peak-hour variant; a 2020 Folketing paper says Bx was shortened to Buddinge for the 2021 timetable.
    https://www.eu.dk/samling/20201/almdel/TRU/bilag/473/2443172.pdf
  - C: Frederikssund to Klampenborg. https://routes.tracestrack.com/route/5612119 (secondary)
  - E: Holte to Køge (secondary, OSM route data). Termini may differ by time of day.
  - F: Hellerup to Ny Ellebjerg. DSB station pages (above).
  - H: Østerport to Ballerup / Frederikssund. https://en.wikipedia.org/wiki/H_(S-train)
  Best check for Clack: the GTFS from Rejseplanen/Trafiklab-equivalent, or DSB's current line map.
- **Fleet (4th generation):** Litra SA (8-car) and Litra SE (4-car short units). Commonly quoted: 104 SA and 31 SE
  sets; the only page that showed those numbers was a low-quality mirror (https://cavac.at/cavacopedia/S-train%20%28Copenhagen%29),
  so UNVERIFIED. The SE short units can run singly in quiet hours. Builder: Alstom LHB, Salzgitter (with Siemens);
  one photo record shows SA 8162 built by Alstom LHB in 2002 (https://railgallery.ru/railcar/113567?lang=en).
  Introduced from 1996 (from memory, UNVERIFIED). Fleet is being refurbished
  (https://railcolornews.com/2024/03/04/passenger-dsb-renews-the-trains-of-s-tog/, paywalled).
- **Livery:** red (DSB S-tog red) with grey/white details. UNVERIFIED: no source read this session. Needs a
  photo-backed source per docs/TRAIN_ART.md before painting.
- **New automated fleet:** DSB tendered at least 226 fully automated (GoA4, driverless) S-trains; Alstom, CAF and
  Siemens Mobility + Stadler were prequalified (Sept 2023).
  https://www.dsb.dk/om-dsb/presse/pressemeddelelser/tre-togproducenter-kan-byde-pa-fremtidens-fuldautomatiske-s-tog/
  The contract went to a **Siemens Mobility + Stadler** consortium: at least 226 trains plus 30 years of maintenance,
  about DKK 23 billion.
  https://www.urban-transport-magazine.com/en/dsb-orders-fully-automated-s-trains-siemens-mobility-and-stadler-to-deliver-next-generation-fleet-for-copenhagen/
  https://railway-news.com/siemens-and-stadler-to-supply-fully-automated-s-tog-trains-in-copenhagen/
  Award date, model name and in-service date: UNVERIFIED (could not open the articles). Earlier DSB material talked
  of testing from about 2028. None are carrying passengers in 2026: riders in 2026 log SA/SE only.

## Copenhagen Metro (M1, M2, M3 Cityringen, M4)

- **Model:** Hitachi Rail Italy Driverless Metro (formerly AnsaldoBreda Driverless Metro). Copenhagen (2002) was
  the first system to use it. https://en.wikipedia.org/wiki/Hitachi_Rail_Italy_Driverless_Metro
- M3/M4 use a later batch of the same family (UNVERIFIED: the split of the fleet across lines was not found).
- **Train or not:** a heavy-rail, grade-separated driverless metro. Rail logbooks usually log metros under
  "metro", separately from mainline trains. Owner's decision.

## Light rail

- **Hovedstadens Letbane (Ring 3):** 29 Siemens Avenio four-section low-floor vehicles (36.9 m). The southern part
  (Ishøj to Rødovre Nord) opened 26 Oct 2025; the full 28 km, 29-station line to Lundtofte opened 22 Aug 2026.
  https://railwaynews.net/copenhagen-opens-28-kilometre-ring-3-light-rail-line.html
  https://deeparrival.com/news/copenhagen-orbital-light-rail-completed-august-2026/ (secondary sites; dates provisional)
- **Odense Letbane:** 16 Stadler Variobahn trams.
  https://www.railway-technology.com/news/newsstadler-to-deliver-16-trams-to-denmarks-odense-city-5846556/
- **Aarhus Letbane:** 12 Stadler Tango (faster units, also on the old railway lines to Grenaa/Odder) and 14 Stadler
  Variobahn (city section). https://en.wikipedia.org/wiki/Aarhus_Light_Rail (search summary)
- **Train or not:** these are trams/light rail. Most rail logbooks either leave them out or put them in a separate
  "tram" category. The exception is the Aarhus Tango units on the former mainline routes to Grenaa and Odder, which
  run like regional trains. Owner's decision.
