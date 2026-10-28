# Denmark: what identifies a train, and how type rules could work

Read from origin/main (2026-10-28). Paths are repo paths on `origin/main`.

## 1. Fields Clack actually gets

| Field | GTFS timetable (`import/gtfs-dk.ts`) | Rejseplanen mgate live (`rejseplanen/client.ts`, `boards/denmark.ts`, `livemap/denmark.ts`) | Archive fallback (`livemap/denmarkFallback.ts`) |
| --- | --- | --- | --- |
| Operator | `agency_name` -> brand via `data/operators.json` `gtfs_operators` (dsb = "DSB"+"DSB S-tog"; vores-tog = "DSB Vores Tog"; lokaltog = "Lokaltog A/S"; nt; midttrafik). Stored `operator_id` + raw `gtfs_operator`. RegioJet under DSB gets no brand. | `opL[].name` via `oprX`, else admin code (`prodCtx.admin` or middle of `lineId`): 000002 DSB, 000022 DSB S-tog, 000087 DSB Vores Tog, 001202 Skånetrafiken, 003051 Snälltåget (`ADMIN`, livemap/denmark.ts:23). GeoPos often omits the operator. No admin codes recorded for Lokaltog/NT/Midttrafik. | `operator_id` from the matched `gtfs_dk` trip only. |
| Route short name | `route_short_name`: IC, ICL, RE, ECE, RJ; S-tog A B Bx C E F H; Vores Tog 030, 031, RX; Lokaltog 110R…960R; Midttrafik 92, 93; NT 75, 76; Skånetrafiken 802–806. Stored only inside `route_name` (short name + headsign). | `prodCtx.catOutL` (category: IC, ICL, Re, RA, RX, S-Tog, ECE, RJ, Lokalbane, Snälltåget, Togbus, "DSB Udland") and `line` (S-tog letter, else = number). | none |
| Route long name / colour | Empty in the file (DENMARK_DATA_FINDINGS.md "Not in the file"). | none | none |
| Product | `danishCategory()` (gtfs-dk.ts:59): route_type 109 -> commuter; IC-family -> intercity (or night if ≥20:00 and ≥6 h); else regional. | `productOfCategory()` (boards/denmark.ts:18): IC/ICL/EC/ICE -> intercity; S-Tog -> commuter; everything else (Re, RA, RX, Lokalbane…) -> regional. **IC and ICL collapse to one product.** | `productOf(route_type, category)` from the timetable. |
| Train number | `trip_short_name`, zero padding stripped ("000100" -> 100). Midttrafik line 93: 21 trips with none. Unverified whether 5–6-digit numbers are what boards/tickets show. | `prodCtx.num`. S-tog: `number` is the line letter, `num` is a 6-digit run id (611151…651251). GeoPos gives no number (falls back to the matched GTFS trip). NT numbers repeat ("Re 75" ×4 at once). | GTFS `train_number`. |
| Origin / destination | First/last stop (UIC id), headsign. | Journey id carries first/last UIC + times (`1S#8600803#…#LS#8600677#…`); `dirTxt` direction. | First/last stop with an update (not always the true ends). |
| Vehicle id / label | **None.** | **None** (no vehicle, no unit number in StationBoard, JourneyDetails or JourneyGeoPos fixtures). | **None** (TripUpdate rows only). |
| Composition | **None.** | **None.** Only remarks (`remL`): "Toget har lav indstigning" (low-floor), "Mulighed for internet", "Cykelreservering kræves", "Reservering anbefales" (board-kh.json). | None. |

Example identifiers in fixtures (`apps/server/test/fixtures/rejseplanen/*.json`, 2026-10-27):
- DSB IC: 185, 846, 50144. DSB ICL: 6, 46. DSB Re: 1265, 1289, 2467, 3446, 51544, 52244, 52567, 54267, 54544.
- Skånetrafiken Re (Öresundståg, admin 001202): 1099–1188, 21378, 21379. Togbus 6802.
- Vores Tog: RA 4653, RX 5647. Snälltåget 31, 307. ECE 390, RJ 382, DSB Udland 521.
- S-tog run ids: A 611151/612251, B 621151/622251, Bx 625251, C 631251, E 641251, H 651251 (second digit = line).
- Findings: IC 100, Vores Tog 5701, S-tog 611215, Lokaltog 250004 (DENMARK_DATA_FINDINGS.md; gtfs-dk.ts:11).

## 2. What can tell models apart

- **Nothing in the feeds names a vehicle or a composition.** `typeFromComposition` and `typeFromVehicle` (legs/trainTypes.ts) never fire for Denmark; only `typicalTrainType` (operator, product, number range, ends/both_ends) can.
- **Operator**: separates fleets cleanly where one operator has one model (S-tog: one generation in service; NT/Midttrafik/Lokaltog lines — needs a source per line).
- **Category IC vs ICL**: in the data but lost: both become product `intercity`, and rules have no field for the category/route short name. ICL (lyntog) vs IC would need a new `route`/`category` match field, or number ranges if a source ties them (not found).
- **Number ranges**: present, but no source yet says which DSB numbers are IC3, IR4, IC5 or loco + coaches. DSB mixes IC3/IR4 (and couples them) on the same IC runs, so per-number certainty is unlikely even with a source.
- **Ends / both_ends**: usable for single-model lines (Lokaltog, NT, Midttrafik branch lines; Kystbanen) — Danish station names, "St." dropped.
- **ME vs EB locos**: nothing distinguishes them; a loco-hauled DSB Re could only ever be "ME or EB + coaches".
- Missing: vehicle/unit ids, composition, long route names, route colours, operator in GeoPos, admin codes for Lokaltog/NT/Midttrafik, Rejseplanen API 2.0 (key pending), SIRI-ET (needs MitID). SIRI-ET from Dataudveksleren is the one source that might carry `VehicleRef`/formation; unchecked.

## 3. Sketch of Danish rules (existing format, `data/train_types.json`)

Types would be new (`dk_…`), each with `_source`; none below is sourced yet, so they are placeholders, not facts.

```json
{ "_source": "NEEDED: DSB S-tog fleet page (one generation in service)",
  "match": { "operator": "dsb", "product": "commuter" }, "type": "dk_stog_sa" }

{ "_source": "NEEDED: a source naming the units on this line, e.g. Lokaltog's fleet list",
  "match": { "operator": "lokaltog", "both_ends": ["Hillerød", "Gilleleje", "Helsingør", "Tisvildeleje"] },
  "type": "dk_lint41" }

{ "_source": "NEEDED: DSB fleet; no source says which unit runs a given IC",
  "match": { "operator": "dsb", "product": "intercity" }, "type": "dk_ic3_ir4" }
```

with the type itself marked as the honest two-model one:

```json
{ "id": "dk_ic3_ir4", "uncertain": true, "name": "IC3 or IR4", "art": "…",
  "about": "DSB runs IC3 and IR4 sets (often coupled) on its InterCity trains; no source says which train is which." }
```

Where only an `uncertain` type is honest: DSB IC/ICL (IC3/IR4, later IC5), DSB loco-hauled Re ("ME or EB + coaches"), any operator with two models on the same line. Order matters: line rules (`both_ends`) before operator-wide fallbacks. NT "Re 75/76" and Midttrafik 92/93 can't use route names, only `both_ends`.
