//
//  RouteGuideTests.swift
//  ClackTests
//
//  The same fixtures as packages/shared/src/station.test.ts ("walk mode directions").
//

import Foundation
import Testing
@testable import ClackCore

/// One level, a corridor from a platform north 40 m, then (L-shaped) east 30 m to an entrance, a café at the corner on
/// the outside; or (bent) 20° east of north for the last 30 m.
private func corridor(bent: Bool) throws -> StationMap {
    let end = bent ? "[10.3,-68.2]" : "[30,-40]"
    let json = """
    {"station_id":"g","name":"Guide","updated":"2026-11-08","quality":"osm_draft","sources":[],"changelog":[],
     "coord_system":"local_m","origin":{"lat":59,"lon":18},"levels":[{"id":"L0","name":"Platforms","order":0}],"shapes":[],
     "platforms":[{"id":"p1","ref":"1","tracks":["1"],"level":"L0","geometry":[[[-2,-2],[2,-2],[2,2],[-2,2],[-2,-2]]],"node":"p1"}],
     "nodes":[{"id":"p1","type":"platform","level":"L0","x":0,"y":0},{"id":"e","type":"entrance","level":"L0","x":\(bent ? 10.3 : 30),"y":\(bent ? -68.2 : -40)}],
     "edges":[{"from":"p1","to":"e","seconds":54,"step_free":true,"kind":"walk","geometry":[[0,0],[0,-40],\(end)]}],
     "pois":[{"id":"c","category":"cafe","name":"Café","level":"L0","x":-4,"y":-44,"node":"e","hours_source":null,"hours_verified":null}]}
    """
    return try JSONDecoder().decode(StationMap.self, from: Data(json.utf8))
}

struct RouteGuideTests {
    @Test func anLShapedCorridorIsOneTurnWithTheLandmarkOnTheRightSide() throws {
        let map = try corridor(bent: false)
        let route = try #require(StationRouting.route(map, from: "p1", to: "e"))
        let steps = RouteGuide.steps(map, route)
        #expect(steps.count == 2)
        #expect(steps[0].turn == nil)
        #expect(abs(steps[0].distanceM - 40) < 3)
        #expect(steps[1].turn == .right)
        #expect(abs(steps[1].distanceM - 30) < 3)
        // Walking north, the café at (-4, -44) is to the left of the way in.
        #expect(steps[1].landmark?.name == "Café")
        #expect(steps[1].landmark?.side == .left)
        let words = RouteGuide.wording(steps[1], levelName: { $0 }, sideName: { $0.rawValue })
        #expect(words.key == "stationMap.step.turnRight")
        #expect(words.values["m"] == "30")
    }

    @Test func aTwentyDegreeBendIsNoTurn() throws {
        let map = try corridor(bent: true)
        let route = try #require(StationRouting.route(map, from: "p1", to: "e"))
        let steps = RouteGuide.steps(map, route)
        #expect(steps.count == 1)
        #expect(abs(steps[0].distanceM - 70) < 3)
    }

    @Test @MainActor func wordsInEnglishAndSwedish() throws {
        let map = try corridor(bent: false)
        let steps = RouteGuide.steps(map, try #require(StationRouting.route(map, from: "p1", to: "e")))
        for lang in [Language.en, .sv] {
            let l10n = L10n(language: lang)
            let w = RouteGuide.wording(steps[1], levelName: { $0 }, sideName: { l10n.t("stationMap.side.\($0.rawValue)") })
            let text = l10n.t(w.key, w.values)
            #expect(text == (lang == .en ? "Turn right after Café, 30 m" : "Sväng höger efter Café, 30 m"))
        }
    }
}
