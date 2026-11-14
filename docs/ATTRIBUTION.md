# Map attribution: what each licence asks, and where Clack shows it

Checked 2026-11-14 (polish pass 1), when the three-line credit under Explore's map became one line, with the full
credits behind the map's ⓘ (the legend) and in Settings › Sources & methodology.

| Source | Licence | What it asks for placement | Clack |
|---|---|---|---|
| OpenStreetMap | ODbL | The OSMF attribution guideline (https://osmfoundation.org/wiki/Licence/Attribution_Guidelines) prefers the credit visible by default. It may be collapsed on map interaction, after 5 s, or by a dismiss, as long as the licence information stays easy to find, for example behind an "(i)" in the map's corner or an "About" menu item. Name "OpenStreetMap" and make the licence clear; linking "OpenStreetMap" to openstreetmap.org/copyright does that. | "© OpenStreetMap" is always visible on the map and links to /copyright; the full line ("© OpenStreetMap contributors (ODbL)") is behind ⓘ and in Sources & methodology. |
| Protomaps basemap | (built from OSM) | Credited beside OSM. | Always visible: "· Protomaps". |
| Digitraffic (Fintraffic), Rejseplanen, the laser height models (Lantmäteriet, Kartverket, NLS Finland, City of Helsinki, Klimadatastyrelsen) | CC BY 4.0 | Section 3(a)(2) (https://creativecommons.org/licenses/by/4.0/legalcode.en): the conditions may be met "in any reasonable manner based on the medium, means, and context", including a link to a resource with the required information. | Behind ⓘ and in Sources & methodology; while 3D heights show, a short "heights © <owner>" stays on the map's line. |
| Entur | NLOD 2.0 | The licensor's wording, or by default "Contains data under the Norwegian licence for Open Government data (NLOD) distributed by [licensor]". The licence does not say where the statement must go (data.norge.no guidance, https://data.norge.no/nlod/en/2.0). | That sentence, behind ⓘ and in Sources & methodology. |
| Trafiklab GTFS | CC0 (as listed in Sources & methodology) | No attribution required. | Credited behind ⓘ anyway. |
| Trafikverket Open API | **Not verified**: Sources & methodology names the API but not its licence. | Unknown. | Credited behind ⓘ and in Sources & methodology. Check Trafikverket's API terms; if they ask for a visible credit, add "· Trafikverket" to the map line. (Needs Garner.) |

If a source's terms change, put its credit back on the visible line in `ExploreScreen.bottomLeft`.
