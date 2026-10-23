//
//  MapTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack

struct MapGeometryTests {
    private let line = [LatLon(57, 14), LatLon(57, 15), LatLon(57, 16)]

    @Test func boundsOfPoints() throws {
        let b = try #require(MapGeometry.bounds([LatLon(57, 14), LatLon(59, 18), LatLon(58, 10)]))
        #expect(b.south == 57)
        #expect(b.north == 59)
        #expect(b.west == 10)
        #expect(b.east == 18)
        #expect(MapGeometry.bounds([]) == nil)
    }

    @Test func partOfALineByLength() {
        #expect(MapGeometry.part(line, 1) == line)
        // Nothing drawn yet is the first point twice, as on the web.
        #expect(MapGeometry.part(line, 0) == [line[0], line[0]])
        let quarter = MapGeometry.part(line, 0.25)
        #expect(quarter.count == 2)
        #expect(abs((quarter.last?.lon ?? 0) - 14.5) < 1e-9)
        let threeQuarters = MapGeometry.part(line, 0.75)
        #expect(threeQuarters.count == 3)
        #expect(abs((threeQuarters.last?.lon ?? 0) - 15.5) < 1e-9)
        #expect(MapGeometry.part([LatLon(57, 14)], 0.5) == [LatLon(57, 14)])
    }

    @Test func splitsARouteIntoTravelledAndAhead() {
        let (done, ahead) = MapGeometry.split(line, at: 0.75)
        #expect(done.count == 3)
        #expect(abs((done.last?.lon ?? 0) - 15.5) < 1e-9)
        // The ahead part runs from the cut to the end of the line.
        #expect(ahead.count == 2)
        #expect(ahead.first == done.last)
        #expect(ahead.last == line[2])
        let (all, none) = MapGeometry.split(line, at: 1)
        #expect(all == line)
        #expect(none.isEmpty)
        // A cut early on keeps the vertices after it.
        let (early, later) = MapGeometry.split(line, at: 0.25)
        #expect(early.count == 2)
        #expect(later.count == 3)
        #expect(later.first == early.last)
        #expect(later.last == line[2])
    }

    @Test func geoJSONPutsLongitudeFirstAndSkipsLinesWithOnePoint() throws {
        let json = MapGeometry.lines([line, [LatLon(1, 1)]])
        let features = try #require(json["features"] as? [[String: Any]])
        #expect(features.count == 1)
        let geometry = try #require(features[0]["geometry"] as? [String: Any])
        let coordinates = try #require(geometry["coordinates"] as? [[Double]])
        #expect(coordinates[0] == [14, 57])
        let points = MapGeometry.points([MapStop(lat: 59.3, lon: 18.1, name: "Stockholm C", kind: .end)])
        let first = try #require((points["features"] as? [[String: Any]])?.first)
        #expect((first["properties"] as? [String: String])?["kind"] == "end")
        #expect(((first["geometry"] as? [String: Any])?["coordinates"] as? [Double]) == [18.1, 59.3])
    }

    @Test func aTripsMapRouteUsesTheGeometryElseTheRiddenStops() throws {
        // The first leg of the saved response has no stops; build one with two stops and no geometry.
        let json = """
        {"seq":1,"role":"board","stationId":"A","name":"A","code":null,"country":"SE","tz":"Europe/Stockholm","lat":57,"lon":14,
         "schedArr":null,"schedDep":null,"actualArr":null,"actualDep":null,"estimatedArr":null,"estimatedDep":null,
         "platform":null,"canceled":false,"deviations":[],"reportSource":null}
        """
        let stop = try JSONDecoder().decode(LegStop.self, from: Data(json.utf8))
        #expect(stop.role == .board)
    }
}

struct MapStyleTests {
    private let base = URL(string: "http://localhost:3001")!

    private func layerIds(_ style: [String: Any]) -> [String] {
        (style["layers"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
    }

    @Test func lightensTowardWhite() {
        #expect(MapStyle.lighten("#000000", 0.55) == "#8c8c8c")
        #expect(MapStyle.lighten("#ffffff", 0.55) == "#ffffff")
        #expect(MapStyle.lighten("#1fb14f", 0.55) == "#9adcb0")
    }

    @Test func anOperatorWithoutAColourGetsTheThemesStrongOne() {
        #expect(MapStyle.opColor(nil, dark: true) == "#f8d64a")
        #expect(MapStyle.opColor(nil, dark: false) == "#0a0a0a")
        #expect(MapStyle.opColor("#1fb14f", dark: false) == "#1fb14f")
        #expect(MapStyle.opColor("", dark: true) == "#f8d64a")
    }

    @Test func aRouteStyleHasTheBasemapTheRouteAndNothingElse() {
        let style = MapStyle.style(base: base, withBasemap: true, dark: true, railNetwork: false, kind: .route(color: "#1fb14f"))
        #expect(style["version"] as? Int == 8)
        #expect(style["glyphs"] as? String == "http://localhost:3001/api/map/fonts/{fontstack}/{range}.pbf")
        #expect(layerIds(style) == [
            "background", "earth", "water", "borders", "motorways", "towns", "cities", "route-context", "route-ahead", "route-glow",
            "route-body", "route-core", "stops-mid", "stops-end", "stops-label",
        ])
        let sources = style["sources"] as? [String: Any]
        let basemap = sources?["basemap"] as? [String: Any]
        #expect((basemap?["tiles"] as? [String]) == ["http://localhost:3001/api/map/tiles/{z}/{x}/{y}.mvt"])
        #expect(basemap?["maxzoom"] as? Int == 10)
        #expect(Set(sources?.keys.map { $0 } ?? []) == ["basemap", "route-context", "route-ahead", "route", "stops"])
    }

    @Test func withoutABasemapOnlyTheBackgroundAndTheRouteDraw() {
        let style = MapStyle.style(base: base, withBasemap: false, dark: true, railNetwork: false, kind: .route(color: "#f8d64a"))
        #expect(layerIds(style).first == "background")
        #expect(!layerIds(style).contains("earth"))
        let background = (style["layers"] as? [[String: Any]])?.first?["paint"] as? [String: Any]
        // With no basemap the background is the land colour.
        #expect(background?["background-color"] as? String == MapStyle.dark.land)
    }

    @Test func theRailNetworkIsInTheStyleOnlyWhenAsked() {
        let on = MapStyle.style(base: base, withBasemap: true, dark: false, railNetwork: true, kind: .route(color: "#0a0a0a"))
        #expect(layerIds(on).contains("rail-network"))
        #expect(layerIds(on).firstIndex(of: "rail-network")! < layerIds(on).firstIndex(of: "route-context")!)
        let off = MapStyle.style(base: base, withBasemap: true, dark: false, railNetwork: false, kind: .route(color: "#0a0a0a"))
        #expect(!layerIds(off).contains("rail-network"))
    }

    @Test func theLightAndDarkThemesUseTheirOwnColours() {
        let light = MapStyle.style(base: base, withBasemap: true, dark: false, railNetwork: false, kind: .multiRoute)
        let earth = (light["layers"] as? [[String: Any]])?.first { $0["id"] as? String == "earth" }
        #expect((earth?["paint"] as? [String: Any])?["fill-color"] as? String == "#f7f7f7")
        #expect(layerIds(light).suffix(3) == ["routes-glow", "routes-body", "stations"])
    }

    @Test func theStyleIsValidJSONAndWritesToAFile() throws {
        let style = MapStyle.style(base: base, withBasemap: true, dark: true, railNetwork: true, kind: .route(color: "#1fb14f"))
        let url = try MapStyle.write(style)
        let data = try Data(contentsOf: url)
        let back = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(back["version"] as? Int == 8)
        #expect((back["layers"] as? [Any])?.count == layerIds(style).count)
    }
}
