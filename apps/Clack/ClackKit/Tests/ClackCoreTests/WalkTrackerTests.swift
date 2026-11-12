//
//  WalkTrackerTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

/// Platform level 0, a 30 m walk to stairs up 6 m to a hall, then 20 m to an entrance.
private func twoLevels() throws -> StationMap {
    let json = """
    {"station_id":"w","name":"Walk","updated":"2026-11-08","quality":"osm_draft","sources":[],"changelog":[],
     "coord_system":"local_m","origin":{"lat":59,"lon":18},
     "levels":[{"id":"L0","name":"Platforms","order":0,"height_m":0},{"id":"L1","name":"Hall","order":1,"height_m":6}],"shapes":[],
     "platforms":[{"id":"p1","ref":"1","tracks":["1"],"level":"L0","geometry":[[[-2,-2],[2,-2],[2,2],[-2,2],[-2,-2]]],"node":"p1"}],
     "nodes":[{"id":"p1","type":"platform","level":"L0","x":0,"y":0},{"id":"s0","type":"stairs","level":"L0","x":0,"y":-30},
              {"id":"s1","type":"stairs","level":"L1","x":0,"y":-38},{"id":"e","type":"entrance","level":"L1","x":0,"y":-58}],
     "edges":[{"from":"p1","to":"s0","seconds":23,"step_free":true,"kind":"walk"},{"from":"s0","to":"s1","seconds":20,"step_free":false,"kind":"stairs"},
              {"from":"s1","to":"e","seconds":15,"step_free":true,"kind":"walk"}],
     "pois":[]}
    """
    return try JSONDecoder().decode(StationMap.self, from: Data(json.utf8))
}

struct WalkTrackerTests {
    @Test func walksForwardChangesLevelByTheBarometerAndFinishes() throws {
        let map = try twoLevels()
        let route = try #require(StationRouting.route(map, from: "p1", to: "e"))
        var t = WalkTracker(map: map, route: route, now: 0)
        #expect(t.steps.map(\.key) == [.walk, .stairsUp, .walk])
        #expect(t.level == "L0")
        t.walked(20, now: 15)
        #expect(t.index == 0)
        #expect(abs(t.remaining - 10) < 0.5)
        t.walked(12, now: 25)
        // On the stairs: walking alone doesn't finish them.
        #expect(t.isLevelChange)
        t.walked(30, now: 30)
        #expect(t.isLevelChange)
        // A flat walk's barometer noise does nothing; 4 m up (60 % of 6 m is 3.6) does.
        t.altitude(0.2, now: 31)
        t.altitude(1.0, now: 35)
        #expect(t.isLevelChange)
        t.altitude(4.4, now: 40)
        #expect(!t.isLevelChange)
        #expect(t.level == "L1")
        t.walked(25, now: 60)
        #expect(t.done)
    }

    @Test func aGoodFixNudgesAndABadOneIsIgnoredAndTheConfirmIsOffered() throws {
        let map = try twoLevels()
        let route = try #require(StationRouting.route(map, from: "p1", to: "e"))
        var t = WalkTracker(map: map, route: route, now: 0)
        #expect(t.estimated(now: 0))
        t.fix(Pt(0, -20), accuracy: 40, now: 1)
        #expect(t.along == 0)
        t.fix(Pt(1, -20), accuracy: 8, now: 2)
        #expect(abs(t.along - 6) < 0.1)
        #expect(!t.estimated(now: 10))
        #expect(t.estimated(now: 30))
        t.walked(30, now: 20)
        #expect(t.isLevelChange)
        t.tick(now: 30)
        #expect(!t.askConfirm)
        t.tick(now: 60)
        #expect(t.askConfirm)
        t.confirmLevel(now: 61)
        #expect(t.level == "L1")
        #expect(!t.askConfirm)
    }

    @Test func aGoodFixAtAWalksEndFinishesIt() throws {
        let map = try twoLevels()
        let route = try #require(StationRouting.route(map, from: "p1", to: "e"))
        var t = WalkTracker(map: map, route: route, now: 0)
        // The nudge alone only closes 30 % of the gap; a fix at the stairs' foot is the end of the walk.
        t.fix(Pt(0, -29.5), accuracy: 5, now: 1)
        #expect(t.index == 1)
        #expect(t.isLevelChange)
    }

    @Test func stairsWithinOneLevelArePartOfTheWalk() throws {
        let json = """
        {"station_id":"s","name":"Steps","updated":"2026-11-12","quality":"osm_draft","sources":[],"changelog":[],
         "coord_system":"local_m","origin":{"lat":59,"lon":18},
         "levels":[{"id":"L0","name":"Hall","order":0,"height_m":0}],"shapes":[],"platforms":[],
         "nodes":[{"id":"a","type":"entrance","level":"L0","x":0,"y":0},{"id":"s0","type":"stairs","level":"L0","x":0,"y":-10},
                  {"id":"s1","type":"stairs","level":"L0","x":0,"y":-14},{"id":"b","type":"entrance","level":"L0","x":0,"y":-30}],
         "edges":[{"from":"a","to":"s0","seconds":8,"step_free":true,"kind":"walk"},{"from":"s0","to":"s1","seconds":4,"step_free":false,"kind":"stairs"},
                  {"from":"s1","to":"b","seconds":12,"step_free":true,"kind":"walk"}],
         "pois":[]}
        """
        let map = try JSONDecoder().decode(StationMap.self, from: Data(json.utf8))
        let route = try #require(StationRouting.route(map, from: "a", to: "b"))
        var t = WalkTracker(map: map, route: route, now: 0)
        // No sensor could finish a change of level that doesn't change level, so there is none.
        #expect(t.steps.allSatisfy { $0.key == .walk })
        t.walked(31, now: 25)
        #expect(t.done)
    }

    @Test func withinMeasuresAlongAPlatformNotOnlyToItsEnds() throws {
        let json = """
        {"station_id":"l","name":"Long","updated":"2026-11-12","quality":"osm_draft","sources":[],"changelog":[],
         "coord_system":"local_m","origin":{"lat":59,"lon":18},
         "levels":[{"id":"L0","name":"Platforms","order":0}],"shapes":[],
         "platforms":[{"id":"p1","ref":"1","tracks":["1"],"level":"L0","geometry":[[[0,-200],[0,200]]],"node":"p1"}],
         "nodes":[{"id":"p1","type":"platform","level":"L0","x":0,"y":0}],"edges":[],"pois":[]}
        """
        let map = try JSONDecoder().decode(StationMap.self, from: Data(json.utf8))
        let metresPerDegree = 111_320 * cos(59 * Double.pi / 180)
        // 100 m beside the platform's middle: 224 m from either end, but well within 150 m of the platform.
        #expect(StationSceneLogic.within(map, lat: 59, lon: 18 + 100 / metresPerDegree, meters: 150))
        #expect(!StationSceneLogic.within(map, lat: 59, lon: 18 + 200 / metresPerDegree, meters: 150))
    }
}
