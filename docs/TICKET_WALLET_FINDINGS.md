# Tickets and Apple Wallet: what makes a ticket valid

Written 2026-11-02, to decide whether Clack may turn a shared ticket into an Apple Wallet pass that carries the same
code (docs/IOS.md, "Sharing a ticket to Clack"). Every claim has its source; what couldn't be confirmed is marked
**Unverified**. Quotes are the operators' own words, with a translation.

## What the codes on the sample tickets are (read by Clack itself)

Read from the owner's own tickets with `TicketReaderDumpTests` (11 files, 2023 to 2026):

| Operator | Code | What it holds |
|---|---|---|
| DSB, Print Selv-billet | Aztec, 467 to 551 bytes | UIC 918.3, header `#UT01`, company code 1186 |
| DB, Online-Ticket | Aztec, 301 to 392 bytes | UIC 918.3, header `#UT02`, company code 1080 (the ticket prints "CIV 1080") |
| SJ (Snälltåget legs) | Aztec, 12 bytes | The ticket number printed on the ticket ("XXXXXX-00001"), nothing else |
| SJ (Västtrafik legs on an SJ booking) | none found | |

UIC 918.3 is a signed container: "#UT", a version, the signing company's code, a key id, a DSA signature and a
compressed payload (ERA, TAP TSI technical document B12:
https://www.era.europa.eu/system/files/2022-10/Recommendation%20on%20TAP%20TSI%20Revision%20-%20Technical%20Document%20-%20B12.pdf).
The signature stops anyone making or changing a code; it does not stop a copy, which still verifies
(https://community.kde.org/KDE_PIM/KItinerary/Barcode_Formats). So a byte-exact copy scans as the original, which is
also why operators control how a ticket may be shown.

## DSB

- **On a phone:** allowed. "Du kan enten printe den vedhæftede Print Selv-billet eller vise den på din mobil, tablet
  eller pc" (you can print it or show it on your phone, tablet or PC), and "Billetten skal vises i sin helhed, og det
  skal være muligt at scanne koden" (the ticket must be shown in full, and the code must be scannable).
  https://www.dsb.dk/betingelser/printselv/ On a screen it is "only valid for journeys via DSB trains and S-trains".
  https://www.dsb.dk/netbutik/terms-and-conditions-in-english/
- **ID:** "The DSB Print At Home ticket is only valid together with your chosen Print Yourself ID" (the card named on
  the ticket; the samples print "Print Selv-ID … Pas"). https://www.dsb.dk/netbutik/terms-and-conditions-in-english/
- **Copies:** "Enhver kopiering og misbrug af Print Selv-billetter er strafbart" (any copying and misuse of Print Selv
  tickets is punishable). https://www.dsb.dk/betingelser/printselv/ The national travel rules are said to accept "kopi
  af Print Selv-billet" (a copy of a Print Selv ticket) as the one exception to "copies or pictures are not accepted";
  **Unverified**: that comes from a search snippet, the rules PDF didn't load.
  https://dinoffentligetransport.dk/kundeservice/raad-og-regler/alle-rejseregler/
- **DSB's own Wallet passes:** none found; tickets bought in the DSB app are shown in the app (**Unverified**, from a
  summary of the app terms). https://www.dsb.dk/om-dsb/virksomheden/forretningsbetingelser/dsb-app/Betingelser-for-brug-af-DSB-App/
- **Conclusion:** a Wallet copy is **not offered**. DSB's own terms forbid copying, and require the ticket in full.

## Deutsche Bahn

Source for the first three points: the conditions of carriage, Beförderungsbedingungen der DB AG, as of 01.02.2026.
https://assets.static-bahn.de/dam/jcr:2cfba82b-5d9a-4afc-9e56-2080fa18acc7/Bef%C3%B6rderungsbedingungen%20der%20DB%20AG%20-%20Stand%2001.02.2026.pdf

- **On a phone:** only as the PDF. §6.3.3: "Wird das Online-Ticket auf dem Display eines mobilen Endgerätes über ein
  pdf-Anzeigeprogramm vorgezeigt müssen der Barcode in Originalgröße und die kompletten Fahrkartendaten bei aktivierter
  Hintergrundbeleuchtung sichtbar sein" (shown on a phone through a PDF viewer, the barcode at original size and the
  complete ticket data must be visible with the backlight on).
- **ID:** §2.8, identity shown "durch einen amtlichen Lichtbildausweis" (with official photo ID); §6.3.3, "Die ID-Karte
  ist zur visuellen Kontrolle auszuhändigen" (the ID card is handed over for a visual check). §2.2: digital tickets are
  personal and not transferable.
- **Copies:** no clause on copies as such; §2.9, a ticket "unbefugt abgeändert" (altered without permission) is invalid,
  and §6.3.3 treats repeated use as misuse. The code is read by a device that decodes it and keeps a record of the check.
  https://www.bahn.de/bahnbusiness/faq/pk/service/buchung/online-ticket
- **DB's own Wallet passes:** "Kann ich mein Ticket in eine Brieftaschen-App (z. B. Wallet) laden? … Das ist zurzeit
  leider nicht möglich" (can I load my ticket into a wallet app? That isn't possible at the moment).
  https://www.bahn.de/bahnbusiness/faq/gk/info-services/dbnavigator/funktionen
- **Conclusion:** a Wallet copy is **not valid**: the only screen form allowed is the PDF in a PDF viewer showing all the
  ticket data.

## SJ

- **On a phone:** allowed, "i mobilen eller datorn ombord, eller skriva ut" (on the phone or computer on board, or
  printed); **Unverified** wording (from a summary; the page is drawn by script).
  https://www.sj.se/om-sj/regler-och-villkor/kopvillkor-juli-2026 For Resplus PDF tickets: "Observera att en
  bild/skärmdump inte är en giltig biljett" (a picture or screenshot is not a valid ticket).
  https://samtrafiken.se/tjanster/resplus/resplus-for-resenar/
- **ID:** personal tickets with "en av SJ godtagbar och giltig identitetshandling" (an ID SJ accepts).
  https://www.sj.se/om-sj/regler-och-villkor/resevillkor
- **Form of a ticket:** §4.1, "En biljett ska ha den form, det innehåll och det utseende i övrigt, som SJ … bestämmer"
  (a ticket has the form, content and look SJ decides); §4.9, a ticket altered without permission is invalid
  (**Unverified** wording, from search snippets of the same page).
  https://www.sj.se/om-sj/regler-och-villkor/resevillkor
- **SJ's own Wallet passes:** the app's listing mentions Wallet, a forum post from October 2024 says the option was
  removed; **Unverified** either way. https://apps.apple.com/se/app/sj-biljetter-och-trafikinfo/id442994825
- **Conclusion:** **unclear**. The code is only the ticket number, but SJ decides what form a ticket takes.

## What Clack does with this

- The ticket viewer in the app is what all three accept: the whole PDF, in a PDF viewer (PDFKit), the code at its size
  on the page, at full brightness. That is the feature for everyone.
- The Wallet pass stays a test tool (Settings, test builds only, off by default), to try the signing and the code
  copy. It is labelled on its back as a copy, not the ticket.
- **Can users be offered this: no.** DB's conditions rule it out, DSB's forbid copying, SJ's are unclear. Revisit only
  with an operator's written permission, or for an operator whose terms allow it.
- Before any wider use the privacy text would also have to say that the code (which holds the passenger's name on
  UIC tickets) passes through the server for a moment and is not kept.
