//
//  MapStyle.swift
//  Clack
//

import ClackCore
import Foundation

/// The Clack basemap and route styling (DESIGN §2.4), dark and light, as MapLibre style objects: a port of
/// `apps/web/src/map/style.ts`. The basemap is our own slimmed Protomaps extract (land, water, places, borders,
/// motorways), served by the server as plain vector tiles (docs/SWIFT_PORT.md B2).
nonisolated enum MapStyle {
    struct Colors: Sendable {
        let land, water, bg, label, labelHalo, text, border, road, rail, railStation, stopFill: String
        /// Routes and trains of an unknown operator.
        let fallback: String
    }

    static let dark = Colors(
        land: "#151515", water: "#0a0a0a", bg: "#0a0a0a", label: "#9a9a9a", labelHalo: "#0a0a0a", text: "#ffffff",
        border: "rgba(255,255,255,0.12)", road: "rgba(255,255,255,0.06)", rail: "rgba(255,255,255,0.13)",
        railStation: "rgba(255,255,255,0.35)", stopFill: "#ffffff", fallback: "#f8d64a"
    )
    // Signal yellow is too faint on a light map; black is the light theme's strong colour.
    static let light = Colors(
        land: "#f7f7f7", water: "#dfe2e5", bg: "#ffffff", label: "#6b6b6b", labelHalo: "#ffffff", text: "#0a0a0a",
        border: "rgba(0,0,0,0.18)", road: "rgba(0,0,0,0.07)", rail: "rgba(0,0,0,0.16)", railStation: "rgba(0,0,0,0.4)",
        stopFill: "#ffffff", fallback: "#0a0a0a"
    )

    static func colors(dark isDark: Bool) -> Colors { isDark ? dark : light }

    /// An operator's brand colour, or the theme's strong colour when we don't know the operator.
    static func opColor(_ brandColor: String?, dark isDark: Bool) -> String {
        if let brandColor, !brandColor.isEmpty { return brandColor }
        return colors(dark: isDark).fallback
    }

    /// Mixes a hex colour toward white (DESIGN: route core = operator colour lightened 55%).
    static func lighten(_ hex: String, _ amount: Double) -> String {
        guard let n = Int(hex.replacingOccurrences(of: "#", with: ""), radix: 16) else { return hex }
        func channel(_ shift: Int) -> String {
            let c = Double((n >> shift) & 0xFF)
            return String(format: "%02x", Int((c + (255 - c) * amount).rounded()))
        }
        return "#\(channel(16))\(channel(8))\(channel(0))"
    }

    // MARK: building blocks

    private static let nameExpression: [Any] = ["coalesce", ["get", "name"], ["get", "name:en"]]
    private static let round: [String: Any] = ["line-cap": "round", "line-join": "round"]

    private static func emptyCollection() -> [String: Any] { ["type": "FeatureCollection", "features": [Any]()] }

    private static func basemapLayers(_ c: Colors) -> [[String: Any]] {
        [
            ["id": "earth", "type": "fill", "source": "basemap", "source-layer": "earth", "paint": ["fill-color": c.land]],
            [
                "id": "water", "type": "fill", "source": "basemap", "source-layer": "water",
                "filter": ["==", ["geometry-type"], "Polygon"], "paint": ["fill-color": c.water],
            ],
            [
                "id": "borders", "type": "line", "source": "basemap", "source-layer": "boundaries",
                "filter": ["==", ["get", "kind"], "country"],
                "paint": ["line-color": c.border, "line-width": 1, "line-dasharray": [3, 2]],
            ],
            [
                "id": "motorways", "type": "line", "source": "basemap", "source-layer": "roads", "minzoom": 6,
                "paint": ["line-color": c.road, "line-width": ["interpolate", ["linear"], ["zoom"], 6, 0.5, 12, 1.5]],
            ],
            [
                "id": "towns", "type": "symbol", "source": "basemap", "source-layer": "places", "minzoom": 8,
                "filter": ["all", ["==", ["get", "kind"], "locality"], ["==", ["get", "kind_detail"], "town"]],
                "layout": ["text-field": nameExpression, "text-font": ["Noto Sans Regular"], "text-size": 11, "text-max-width": 8],
                "paint": ["text-color": c.label, "text-opacity": 0.7, "text-halo-color": c.labelHalo, "text-halo-width": 1.2],
            ],
            [
                "id": "cities", "type": "symbol", "source": "basemap", "source-layer": "places", "minzoom": 3,
                "filter": ["all", ["==", ["get", "kind"], "locality"], ["==", ["get", "kind_detail"], "city"]],
                "layout": [
                    "text-field": nameExpression, "text-font": ["Noto Sans Regular"],
                    "text-size": ["interpolate", ["linear"], ["zoom"], 4, 11, 10, 13], "text-max-width": 8,
                    "symbol-sort-key": ["-", 20, ["coalesce", ["get", "population_rank"], 0]],
                ],
                "paint": ["text-color": c.label, "text-halo-color": c.labelHalo, "text-halo-width": 1.2],
            ],
        ]
    }

    static func railNetworkLayers(_ c: Colors) -> [[String: Any]] {
        [
            [
                "id": "rail-network", "type": "line", "source": "rail-network", "filter": ["==", ["geometry-type"], "LineString"],
                // Fades out where the station detail (every track at full detail) takes over.
                "paint": ["line-color": c.rail, "line-width": 1, "line-opacity": ["interpolate", ["linear"], ["zoom"], 13, 1, 13.6, 0]],
            ],
            [
                "id": "rail-stations", "type": "circle", "source": "rail-network", "minzoom": 9,
                "filter": ["==", ["geometry-type"], "Point"], "paint": ["circle-radius": 1.6, "circle-color": c.railStation],
            ],
        ]
    }

    /// Glow, body and core strokes (DESIGN §2.4) for the ridden route; a faint line for the rest of the train's route.
    static func routeLayers(color: String, _ c: Colors, dark isDark: Bool) -> [[String: Any]] {
        [
            [
                "id": "route-context", "type": "line", "source": "route-context", "layout": round,
                "paint": ["line-color": color, "line-opacity": 0.3, "line-width": 2, "line-dasharray": [2, 2]],
            ],
            // The part still ahead of a live train: same colour, dashed (6 px dash, 6 px gap at 4 px width).
            [
                "id": "route-ahead", "type": "line", "source": "route-ahead",
                "paint": ["line-color": color, "line-opacity": 0.8, "line-width": 4, "line-dasharray": [1.5, 1.5]],
            ],
            [
                "id": "route-glow", "type": "line", "source": "route", "layout": round,
                "paint": ["line-color": color, "line-opacity": 0.35, "line-width": 12, "line-blur": 6],
            ],
            [
                "id": "route-body", "type": "line", "source": "route", "layout": round,
                "paint": ["line-color": color, "line-opacity": 0.85, "line-width": 4],
            ],
            [
                "id": "route-core", "type": "line", "source": "route", "layout": round,
                "paint": ["line-color": lighten(color, 0.55), "line-width": 1.5],
            ],
            [
                "id": "stops-mid", "type": "circle", "source": "stops", "filter": ["==", ["get", "kind"], "mid"],
                "paint": [
                    "circle-radius": 3, "circle-color": c.stopFill, "circle-stroke-color": isDark ? c.bg : c.text,
                    "circle-stroke-width": 1.5,
                ],
            ],
            [
                "id": "stops-end", "type": "circle", "source": "stops", "filter": ["==", ["get", "kind"], "end"],
                "paint": ["circle-radius": 6, "circle-color": color, "circle-stroke-color": "#ffffff", "circle-stroke-width": 2],
            ],
            [
                "id": "stops-label", "type": "symbol", "source": "stops", "filter": ["==", ["get", "kind"], "end"],
                "layout": [
                    "text-field": ["get", "name"], "text-font": ["Noto Sans Medium"], "text-size": 13,
                    "text-variable-anchor": ["left", "right", "top", "bottom"], "text-radial-offset": 0.9, "text-justify": "auto",
                ],
                "paint": ["text-color": c.text, "text-halo-color": c.bg, "text-halo-width": 1.5],
            ],
        ]
    }

    /// Every ridden route on one map (Passport, journey): each line in its operator colour with a soft glow so lines
    /// ridden many times build up brighter, and station dots that grow with the number of visits.
    static func multiRouteLayers(_ c: Colors) -> [[String: Any]] {
        [
            [
                "id": "routes-glow", "type": "line", "source": "routes", "layout": round,
                "paint": ["line-color": ["get", "color"], "line-opacity": 0.22, "line-width": 10, "line-blur": 5],
            ],
            [
                "id": "routes-body", "type": "line", "source": "routes", "layout": round,
                "paint": ["line-color": ["get", "color"], "line-opacity": 0.75, "line-width": 2.5],
            ],
            [
                "id": "stations", "type": "circle", "source": "stations",
                // Busier (bigger) stations on top, so a small dot never sits over a big one.
                "layout": ["circle-sort-key": ["get", "count"]],
                "paint": [
                    "circle-radius": ["interpolate", ["linear"], ["get", "count"], 1, 3, 10, 7, 50, 11],
                    "circle-color": c.stopFill, "circle-stroke-color": c.bg, "circle-stroke-width": 1.5,
                ],
            ],
        ]
    }

    /// The Explore map's own layers (LiveMapPage.tsx): stations you can tap, and the trains, clustered when zoomed out.
    /// Images (`station`, `cluster`, `tdot-<colour>`, `tpuck-<colour>`) are drawn on demand by the map's delegate.
    /// Station detail from zoom 13 (plan 2026-10-29): every track at full detail, sidings and yards fainter, and
    /// the platforms of the mapped stations with their numbers from zoom 14. Under the trains.
    static func stationDetailLayers(_ c: Colors, dark isDark: Bool) -> [[String: Any]] {
        let round: [String: Any] = ["line-cap": "round", "line-join": "round"]
        let platform = isDark ? "#4a4a4a" : "#d6d6d6"
        return [
            [
                "id": "detail-tracks-minor", "type": "line", "source": "station-detail", "minzoom": 13, "layout": round,
                "filter": ["==", ["get", "cls"], "siding"],
                "paint": ["line-color": c.text, "line-opacity": 0.22, "line-width": ["interpolate", ["linear"], ["zoom"], 13, 1.2, 17, 2.5]],
            ],
            [
                "id": "detail-tracks", "type": "line", "source": "station-detail", "minzoom": 13, "layout": round,
                "filter": ["==", ["get", "cls"], "track"],
                "paint": ["line-color": c.text, "line-opacity": 0.55, "line-width": ["interpolate", ["linear"], ["zoom"], 13, 1.5, 17, 3.5]],
            ],
            [
                "id": "detail-platforms", "type": "fill", "source": "station-platforms", "minzoom": 13,
                "paint": ["fill-color": platform, "fill-opacity": 0.85],
            ],
            [
                "id": "detail-platforms-line", "type": "line", "source": "station-platforms", "minzoom": 13,
                "paint": ["line-color": c.text, "line-opacity": 0.25, "line-width": 0.8],
            ],
            [
                "id": "detail-platform-labels", "type": "symbol", "source": "station-platform-labels", "minzoom": 14,
                "layout": ["text-field": ["get", "plat"], "text-font": ["Noto Sans Medium"], "text-size": 11, "text-allow-overlap": false, "symbol-placement": "point"],
                "paint": ["text-color": c.text, "text-halo-color": c.labelHalo, "text-halo-width": 1],
            ],
        ]
    }

    /// From zoom 14 a train is its cars along the track (`trains-close`, built by the model from TrainKit): lines in
    /// the operator's colour whose width is metres on the ground, the front car a shade lighter.
    static func trainCarLayers(_ c: Colors) -> [[String: Any]] {
        let width: [Any] = ["interpolate", ["exponential", 2], ["zoom"], 14, 2.2, 18, 36]
        return [
            [
                "id": "train-cars", "type": "line", "source": "trains-close", "minzoom": 14, "layout": ["line-cap": "butt", "line-join": "round"],
                "paint": ["line-color": ["get", "color"], "line-width": width],
            ],
            [
                "id": "train-cars-front", "type": "line", "source": "trains-close", "minzoom": 14, "filter": ["==", ["get", "front"], true],
                "layout": ["line-cap": "butt"], "paint": ["line-color": "#ffffff", "line-opacity": 0.35, "line-width": width],
            ],
            [
                "id": "train-cars-edge", "type": "line", "source": "trains-close", "minzoom": 14, "layout": ["line-cap": "butt"],
                "paint": ["line-color": c.bg, "line-opacity": 0.6, "line-width": 0.8, "line-gap-width": width],
            ],
        ]
    }

    private static func liveStationLayers(_ c: Colors) -> [[String: Any]] {
        let dpd: [Any] = ["coalesce", ["get", "dpd"], 0]
        return [
            [
                "id": "live-stations", "type": "symbol", "source": "rail-network", "minzoom": 5,
                "filter": ["all", ["==", ["get", "kind"], "station"], [">=", dpd, ["step", ["zoom"], 60, 6.5, 25, 8, 8, 9.5, 0]]],
                "layout": [
                    "icon-image": "station", "icon-size": ["interpolate", ["linear"], ["zoom"], 5, 0.55, 9, 0.75, 13, 1],
                    "icon-allow-overlap": true, "icon-ignore-placement": true,
                ],
            ],
        ]
    }

    private static func liveStationLabelLayer(_ c: Colors) -> [String: Any] {
        let dpd: [Any] = ["coalesce", ["get", "dpd"], 0]
        // Names of the bigger stations first; all of them only close in, so train numbers stay readable.
        return [
            "id": "live-station-labels", "type": "symbol", "source": "rail-network", "minzoom": 6,
            "filter": ["all", ["==", ["get", "kind"], "station"], [">=", dpd, ["step", ["zoom"], 90, 7.5, 40, 9, 15, 11, 0]]],
            "layout": [
                "text-field": ["get", "name"], "text-font": ["Noto Sans Regular"], "text-size": 10.5, "text-offset": [0, 0.8],
                "text-anchor": "top", "text-optional": true,
            ],
            "paint": ["text-color": c.label, "text-halo-color": c.bg, "text-halo-width": 1.2],
        ]
    }

    /// The late orange of the delay palette, for a corridor's track and the rings on its trains.
    static let corridorColor = ExploreLogic.delayColors.late

    private static func liveTrainLayers(_ c: Colors, dark isDark: Bool, route: [[String: Any]]) -> [[String: Any]] {
        let mine: [Any] = ["==", ["get", "mine"], true]
        func size(_ a: Double, _ b: Double) -> [Any] { ["case", mine, b, a] }
        var layers: [[String: Any]] = [
            // A corridor from the network status (a stretch where most trains are late): its track in the late orange,
            // a soft glow under a firm line, drawn under every train.
            [
                "id": "corridor-glow", "type": "line", "source": "corridor", "layout": ["line-cap": "round", "line-join": "round"],
                "paint": ["line-color": corridorColor, "line-width": ["interpolate", ["linear"], ["zoom"], 5, 8, 10, 16], "line-opacity": 0.25, "line-blur": 4],
            ],
            [
                "id": "corridor-body", "type": "line", "source": "corridor", "layout": ["line-cap": "round", "line-join": "round"],
                "paint": ["line-color": corridorColor, "line-width": ["interpolate", ["linear"], ["zoom"], 5, 2.5, 10, 5], "line-opacity": 0.9],
            ],
            // Zoomed out: a small dot per train in its operator's colour (cheap to draw for a thousand trains); the heading
            // cone and the number come in from zoom 7.
            [
                "id": "train-far", "type": "circle", "source": "trains", "maxzoom": 7,
                "paint": [
                    "circle-radius": ["interpolate", ["linear"], ["zoom"], 3, ["case", mine, 4, 2.2], 5, ["case", mine, 5, 3], 7, ["case", mine, 6, 4]],
                    "circle-color": ["get", "color"], "circle-stroke-color": c.bg, "circle-stroke-width": 0.6,
                ],
            ],
            // Followed trains (watching, not travelling): a white ring, unlike your own trips' yellow halo.
            [
                "id": "train-followed", "type": "circle", "source": "trains", "filter": ["==", ["get", "followed"], true],
                "paint": ["circle-radius": 10, "circle-color": "rgba(0,0,0,0)", "circle-stroke-color": c.text, "circle-stroke-width": 2],
            ],
        ]
        layers += route
        layers += [
            [
                "id": "train-mine", "type": "circle", "source": "trains", "filter": mine,
                "paint": ["circle-radius": 13, "circle-color": "rgba(248,214,74,0.28)", "circle-stroke-color": "#f8d64a", "circle-stroke-width": 2],
            ],
            // The late trains of the corridor on show: an orange ring (the filter is set with the corridor).
            [
                "id": "train-corridor", "type": "circle", "source": "trains", "filter": ["==", ["get", "id"], ""],
                "paint": ["circle-radius": 11, "circle-color": "rgba(0,0,0,0)", "circle-stroke-color": corridorColor, "circle-stroke-width": 2.5],
            ],
            // The selected train: a larger marker under its dot.
            [
                "id": "train-selected", "type": "circle", "source": "trains", "filter": ["==", ["get", "id"], ""],
                "paint": ["circle-radius": 11, "circle-color": ["get", "color"], "circle-opacity": 0.35, "circle-stroke-color": "#ffffff", "circle-stroke-width": 2],
            ],
            [
                // From zoom 14 the cars take over (`train-cars`).
                "id": "train-dot", "type": "symbol", "source": "trains", "minzoom": 7, "maxzoom": 14,
                "layout": [
                    // With a heading cone (rotated to the bearing) when the direction is known, a plain disc when it isn't.
                    "icon-image": ["case", ["==", ["get", "hasBearing"], true], ["concat", "tpuck-", ["get", "color"]], ["concat", "tdot-", ["get", "color"]]],
                    "icon-rotate": ["get", "bearing"], "icon-rotation-alignment": "map", "icon-pitch-alignment": "map",
                    "icon-size": ["interpolate", ["linear"], ["zoom"], 5, size(0.6, 0.72), 9, size(0.78, 0.9), 13, size(0.95, 1.1)],
                    "icon-allow-overlap": true, "icon-ignore-placement": true,
                    "symbol-sort-key": ["case", mine, 1, 0],
                ],
            ],
            [
                // The train's number, and from zoom 11 where it's going under it: written, in the app's ink, no box.
                "id": "train-label", "type": "symbol", "source": "trains", "minzoom": 9,
                "layout": [
                    "text-field": ["step", ["zoom"], ["format", ["get", "number"], ["text-font": ["literal", ["Noto Sans Medium"]]]],
                                   11, ["format", ["get", "number"], ["text-font": ["literal", ["Noto Sans Medium"]]],
                                        "\n", [:] as [String: Any],
                                        ["coalesce", ["get", "dest"], ""], ["text-font": ["literal", ["Noto Sans Regular"]], "font-scale": 0.9, "text-color": c.label]]],
                    "text-font": ["Noto Sans Medium"], "text-size": 12, "text-line-height": 1.15,
                    // Below the dot where there is room, else beside or above it: a train at a busy station keeps its
                    // label next to the station's name instead of losing it.
                    "text-variable-anchor": ["top", "right", "left", "bottom"], "text-radial-offset": 1.1,
                    "text-justify": "auto", "text-optional": true, "text-max-width": 12,
                ],
                "paint": ["text-color": c.text, "text-halo-color": c.bg, "text-halo-width": 1.6, "text-halo-blur": 0.4],
            ],
            liveStationLabelLayer(c),
        ]
        return layers
    }

    // MARK: whole styles

    enum Kind: Sendable {
        /// One route with its stops, an optional faint rest-of-route and the live split.
        case route(color: String)
        /// Many routes and the stations they pass.
        case multiRoute
        /// Explore: every running train, stations, and the selected train's route.
        case live
    }

    /// The style object: the basemap when it's available, otherwise just the background (routes still draw).
    static func style(base: URL, withBasemap: Bool, dark isDark: Bool, railNetwork: Bool, kind: Kind) -> [String: Any] {
        let c = colors(dark: isDark)
        let origin = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var sources: [String: Any] = [:]
        var layers: [[String: Any]] = [
            ["id": "background", "type": "background", "paint": ["background-color": withBasemap ? c.water : c.land]],
        ]
        if withBasemap {
            sources["basemap"] = [
                "type": "vector", "tiles": ["\(origin)/api/map/tiles/{z}/{x}/{y}.mvt"], "minzoom": 0, "maxzoom": 10, "attribution": "",
            ] as [String: Any]
            layers += basemapLayers(c)
        }
        var withRail = railNetwork
        if case .live = kind { withRail = true }
        if withRail {
            sources["rail-network"] = ["type": "geojson", "data": "\(origin)/api/map/rail-network.geojson"] as [String: Any]
            layers += railNetworkLayers(c)
        }
        switch kind {
        case .route(let color):
            for id in ["route-context", "route-ahead", "route", "stops"] { sources[id] = ["type": "geojson", "data": emptyCollection()] as [String: Any] }
            layers += routeLayers(color: color, c, dark: isDark)
        case .multiRoute:
            for id in ["routes", "stations"] { sources[id] = ["type": "geojson", "data": emptyCollection()] as [String: Any] }
            layers += multiRouteLayers(c)
        case .live:
            for id in ["route-context", "route-ahead", "route", "stops"] { sources[id] = ["type": "geojson", "data": emptyCollection()] as [String: Any] }
            sources["trains-pinned"] = ["type": "geojson", "data": emptyCollection()] as [String: Any]
            sources["corridor"] = ["type": "geojson", "data": emptyCollection()] as [String: Any]
            // Tracks and platforms apart: a shape collection that mixes lines and polygons draws nothing on iOS.
            sources["station-detail"] = ["type": "geojson", "data": emptyCollection()] as [String: Any]
            sources["station-platforms"] = ["type": "geojson", "data": emptyCollection()] as [String: Any]
            sources["station-platform-labels"] = ["type": "geojson", "data": emptyCollection()] as [String: Any]
            sources["trains-close"] = ["type": "geojson", "data": emptyCollection()] as [String: Any]
            sources["trains"] = [
                // Not clustered: every train is its own dot at every zoom (owner, 2026-10-27).
                "type": "geojson", "data": emptyCollection(),
            ] as [String: Any]
            layers += stationDetailLayers(c, dark: isDark)
            layers += liveStationLayers(c)
            layers += liveTrainLayers(c, dark: isDark, route: routeLayers(color: c.fallback, c, dark: isDark))
            layers += trainCarLayers(c)
        }
        return ["version": 8, "glyphs": "\(origin)/api/map/fonts/{fontstack}/{range}.pbf", "sources": sources, "layers": layers]
    }

    /// Writes a style to a file MapLibre can load (it takes a URL), and returns that URL.
    static func write(_ style: [String: Any]) throws -> URL {
        let data = try JSONSerialization.data(withJSONObject: style, options: [.sortedKeys])
        let name = "clack-map-style-\(abs(data.hashValue)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}
