//
//  StationSceneLogicTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack

private final class SceneBundleToken {}

struct StationSceneLogicTests {
    private func stockholm() throws -> StationMap {
        let url = try #require(Bundle(for: SceneBundleToken.self).url(forResource: "station-map", withExtension: "json"))
        return try JSONDecoder().decode(StationMap.self, from: Data(contentsOf: url))
    }

    @Test func rotatesAPointAroundTheOrigin() {
        let p = StationSceneLogic.rotate(1, 0, degrees: 90)
        #expect(abs(p.x) < 1e-9 && abs(p.y - 1) < 1e-9)
    }

    @Test func foldsDiacriticsAndCase() {
        #expect(StationSceneLogic.fold("Övre Hallen") == "ovre hallen")
        #expect(StationSceneLogic.fold("Café") == "cafe")
    }

    @Test func levelLabelsAreSignedExceptZero() {
        #expect(StationSceneLogic.levelLabel(StationLevel(id: "a", name: "", order: 2)) == "+2")
        #expect(StationSceneLogic.levelLabel(StationLevel(id: "a", name: "", order: 0)) == "0")
        #expect(StationSceneLogic.levelLabel(StationLevel(id: "a", name: "", order: -1)) == "-1")
    }

    @Test func zoomKeepsThePointUnderTheFingerStillAndClamps() {
        let start = StationSceneLogic.View(tx: 10, ty: 20, k: 2)
        let zoomed = StationSceneLogic.zoom(start, by: 2, aroundX: 100, y: 200)
        // The world point under (100, 200) is the same before and after.
        #expect(abs((100 - start.tx) / start.k - (100 - zoomed.tx) / zoomed.k) < 1e-9)
        #expect(StationSceneLogic.zoom(start, by: 1000, aroundX: 0, y: 0).k == 40)
        #expect(StationSceneLogic.zoom(start, by: 0.0001, aroundX: 0, y: 0).k == 0.3)
    }

    @Test func compassNamesTheDirectionFromTheMiddle() {
        func node(_ x: Double, _ y: Double) -> StationNode { StationNode(id: "n", type: .entrance, level: "L0", x: x, y: y, platform: nil, name: nil) }
        // y runs south, so a smaller y is further north.
        #expect(StationSceneLogic.compass(of: node(0, -10), from: (0, 0)) == "n")
        #expect(StationSceneLogic.compass(of: node(10, 0), from: (0, 0)) == "e")
        #expect(StationSceneLogic.compass(of: node(0, 10), from: (0, 0)) == "s")
        #expect(StationSceneLogic.compass(of: node(-10, -10), from: (0, 0)) == "nw")
    }

    @Test func stepLevelsFollowTheLastLevelChange() {
        let steps = [
            Instruction(key: .leave, level: nil, seconds: 0, track: "1"),
            Instruction(key: .stairsUp, level: "L1", seconds: 20),
            Instruction(key: .walk, level: nil, seconds: 60),
            Instruction(key: .arrive, level: nil, seconds: 0, track: "5"),
        ]
        #expect(StationSceneLogic.stepLevels(steps, routeStart: "L0", fallback: "L0") == ["L0", "L1", "L1", "L1"])
    }

    @Test func opensOnTheMainLevelUnlessTheWalkStartsElsewhere() throws {
        let map = try stockholm()
        #expect(StationSceneLogic.initialLevel(map, startLevel: nil, current: nil) == "L0")
        #expect(StationSceneLogic.initialLevel(map, startLevel: "L1", current: "L0") == "L1")
        #expect(StationSceneLogic.initialLevel(map, startLevel: nil, current: "L-1") == "L-1")
    }

    @Test func fitsTheAmenitiesWithoutARouteAndTheRouteWhenThereIsOne() throws {
        let map = try stockholm()
        let insets = StationSceneLogic.Insets(top: 140, bottom: 150)
        let overview = try #require(StationSceneLogic.fit(map: map, level: "L0", route: nil, marks: [], pins: [], width: 393, height: 700, insets: insets))
        #expect(overview.k >= 0.5 && overview.k <= 40)
        let route = try #require(StationRouting.routeBetween(map, StationRouting.resolveEndpoint(map, "13"), StationRouting.resolveEndpoint(map, "4")))
        let fitted = try #require(StationSceneLogic.fit(map: map, level: "L0", route: route, marks: [], pins: [], width: 393, height: 700, insets: insets))
        #expect(fitted.k <= 9)
    }

    @Test func oneChipPerPlatformAndAMarkedChipWinsOverNeighbours() throws {
        let map = try stockholm()
        let plain = StationSceneLogic.platformChips(map: map, level: "L0", marks: [], k: 1)
        #expect(!plain.isEmpty)
        let platform = try #require(map.platforms.first { $0.level == "L0" })
        let mark = StationSceneLogic.PlatformMark(platformId: platform.id, label: "Arrive · Track \(platform.ref)", color: "#123456")
        let marked = StationSceneLogic.platformChips(map: map, level: "L0", marks: [mark], k: 1)
        #expect(marked.last?.mark == mark)
    }

    @Test func declutteringKeepsOnePinPerCellAndNamesOnlyWhenZoomedIn() throws {
        let map = try stockholm()
        let out = StationSceneLogic.shownPois(map: map, level: "L0", k: 0.5, state: { _ in .unknown }, dim: { _ in false })
        let all = map.pois.filter { $0.level == "L0" }.count
        #expect(out.shown.count <= all)
        #expect(out.named.isEmpty)
        let zoomed = StationSceneLogic.shownPois(map: map, level: "L0", k: 6, state: { _ in .unknown }, dim: { _ in false })
        #expect(zoomed.shown.count >= out.shown.count)
        #expect(zoomed.named.isSubset(of: zoomed.shown))
    }
}
