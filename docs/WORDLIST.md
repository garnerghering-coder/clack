# Word list

One word per thing, in English and Swedish. Every string in the String Catalog
(`apps/Clack/ClackKit/Sources/ClackCore/Resources/Localizable.xcstrings`) follows it. Written in polish pass 1
(2026-11-14). Change this list first, then the catalog.

The four rules for every string, in both languages:
1. **Cut filler.** Don't write "simply", "easily", "quickly", "please" or "oops".
2. **Say it once.** A title and its body don't repeat each other.
3. **Lead with the reason.** For example: "To get delay alerts, turn on notifications."
4. **One word per thing**, as in the tables below.

Hint text in a field is a real example ("SJ 523", "Stockholm → Göteborg"), not a description of the field.

## Actions

| Use (en) | Use (sv) | Never use | Meaning |
|---|---|---|---|
| Find a train | Hitta ett tåg | Find your train, Add train, Add a train | Opens the search. The Add sheet's title, the first-run button, the + button's label, the empty states. |
| Add to trips | Lägg till i resor | Add to my trips, Add to Clack, Lägg till i mina resor | Saves a found train (or a journey's trains) as yours. |
| Add it by hand · Add a trip by hand | Lägg till för hand · Lägg till en resa för hand | Add manually | The manual form, and the link to it. Its save button is "Add to trips". |
| Add another | Lägg till ett tåg till | Lägg till ett till | After saving: back to the search, keeping the date. |
| Follow · Stop following | Följ · Sluta följa | Track, Watch, Bevaka | Watch a train you don't ride. |
| Delete | Radera | Remove, Ta bort | Destroys something of yours (a trip, all data). |
| Remove | Ta bort | Delete | Takes something out of a list without destroying it (a favourite, a follow). |
| Close | Stäng | Done (for leaving), ✕ with no label | Leaves a sheet or panel that changed nothing. |
| Done | Klar | Close (after editing) | Finishes an edit or a flow. |
| Cancel | Avbryt | Abort | Leaves an edit, changing nothing. |
| Try again | Försök igen | Retry, Försök igen senare (as a button) | Repeats what failed. |
| Share | Dela | Send, Skicka | Opens the share sheet. |
| Not now | Inte nu | Later, Skip | Turns down an offer that may come back. |

## Things

| Use (en) | Use (sv) | Never use | Meaning |
|---|---|---|---|
| trip | resa | leg, ride (as a noun), train (for a saved ride) | One saved ride on one train, yours. "Trips" is the tab. |
| journey | resväg | trip (for several) | Trips that connect (a change in between). Only when there is more than one train. |
| train | tåg | service, departure (for the train itself) | The vehicle and its number: "SJ 523". |
| operator | tågbolag | operatör, bolag | SJ, Vy, VR, DSB, Öresundståg… |
| train type | tågtyp | slag, typ, model | X2000, Sm5, Re… (a drawing and a name). |
| kind of train | tågslag | slag, kategori | High-speed, Long-distance, Regional, Commuter, Night. |
| platform | spår | track (en), plattform (sv) | Where you board: "Platform 3", "Spår 3". Sector letters stay ("3a"). |
| station | station | stop (for a station you choose) | A place on the map. "Stop" only in a train's list of stops. |
| stop | uppehåll | halt | Where a train calls, in its list. |
| change | byte | transfer, connection (as a noun) | Getting off one train for the next: "6 min to change", "Byte i Malmö C". |
| Passport | Pass | Stats, Statistik | The tab and its cover. |
| medal | medalj | badge, achievement | One step of a milestone. |
| alerts | aviseringar | notifications (in Clack's own words), push | What Clack sends you. iOS's own word "notifications" is only for the system setting. |

## States

| Use (en) | Use (sv) | Never use | Meaning |
|---|---|---|---|
| On time | I tid | Punctual, Enligt tidtabell | 0 min late or early. |
| +8 min / 8 min late | +8 min / 8 min sen | Delayed by | Late, always with the number. |
| Cancelled | Inställd (status of a trip), inställt (of a train) | Canceled (US) | The train doesn't run (or not where you are). |
| Live | Live | Realtime (as a label) | Fresh data with a position or times. |
| Updated 2 min ago | Uppdaterad för 2 min sedan | Last refreshed, Synced | How old what you see is. |
| Estimated | Uppskattad | Approx., Guessed | Worked out from the timetable, not reported. |
| Scheduled | Enligt tidtabell | Planned (for times) | Timetabled times, with no live report. |
| Upcoming · Past | Kommande · Tidigare | Future, History | The two halves of Trips. |
| No connection | Ingen anslutning | Offline mode, No internet | The phone can't reach Clack's server. |

## Errors

A failure says what happened, what still works, and offers **Try again**. It never pretends to be an empty result.

| Use (en) | Use (sv) | Never use |
|---|---|---|
| Couldn't load … | Kunde inte läsa in … | Something went wrong, Oops, Error |
| Couldn't save … Try again. | Kunde inte spara … Försök igen. | Is the server running?, Failed |
| Couldn't refresh · Updated 12 min ago | Kunde inte uppdatera · Uppdaterad för 12 min sedan | Stale data |

## Navigation

| Use (en) | Use (sv) | Never use |
|---|---|---|
| The system back button (with the previous screen's title) | Systemets bakåtknapp | Hand-made "‹ Back", "Back to results" |
| Close (a sheet) | Stäng | ✕ alone without a VoiceOver label |
| Trips · Explore · Passport · Settings | Resor · Utforska · Pass · Inställningar | Home, Map, Stats |

## Words left as they are, and why

- **"Normal" (walking pace) and "Normalt" (comfort of a change)** are both correct Swedish. Each agrees with a different
  word: *gångtakt* is common gender ("normal"), and the comfort is said as an adverb ("det är normalt"). They are two
  things, so they're two words.
- **Swedish licence lines** ("Source: Fintraffic / digitraffic.fi, license CC 4.0 BY") are the licensor's wording.
