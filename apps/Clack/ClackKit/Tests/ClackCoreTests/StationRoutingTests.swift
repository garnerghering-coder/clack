//
//  StationRoutingTests.swift
//  ClackTests
//
//  Ported from packages/shared/src/station.test.ts, plus the real Stockholm C map saved from the server.
//

import Foundation
import Testing
@testable import ClackCore

/// A tiny two-platform station: a tunnel below with stairs and a slower lift up to each platform.
private func testMap() throws -> StationMap {
    let json = """
    {"station_id":"t","name":"Test C","updated":"2026-10-21","quality":"hand_curated","sources":[],"changelog":[],
     "coord_system":"local_m","origin":{"lat":59,"lon":18},
     "levels":[{"id":"L0","name":"Platforms","order":0},{"id":"L-1","name":"Tunnel","order":-1}],"shapes":[],
     "platforms":[
       {"id":"p1","ref":"1","tracks":["1"],"level":"L0","geometry":[[[0,0],[4,0],[4,100],[0,100],[0,0]]],"node":"p1"},
       {"id":"p2","ref":"2","tracks":["2"],"level":"L0","geometry":[[[30,0],[34,0],[34,100],[30,100],[30,0]]],"node":"p2"}],
     "nodes":[
       {"id":"p1","type":"platform","level":"L0","x":2,"y":50},{"id":"p2","type":"platform","level":"L0","x":32,"y":50},
       {"id":"a","type":"junction","level":"L-1","x":2,"y":50},{"id":"b","type":"junction","level":"L-1","x":32,"y":50}],
     "edges":[
       {"from":"p1","to":"a","seconds":20,"step_free":false,"kind":"stairs"},
       {"from":"p1","to":"a","seconds":45,"step_free":true,"kind":"lift"},
       {"from":"a","to":"b","seconds":25,"step_free":true,"kind":"walk"},
       {"from":"b","to":"p2","seconds":20,"step_free":false,"kind":"stairs"},
       {"from":"b","to":"p2","seconds":45,"step_free":true,"kind":"lift"}],
     "pois":[]}
    """
    return try JSONDecoder().decode(StationMap.self, from: Data(json.utf8))
}

private func withToilet() throws -> StationMap {
    var map = try testMap()
    let poi = """
    {"id":"wc","category":"toilet","name":"","level":"L-1","x":30,"y":52,"node":"b","hours_source":null,"hours_verified":null}
    """
    map.pois.append(try JSONDecoder().decode(StationPoi.self, from: Data(poi.utf8)))
    return map
}

struct StationMapValidationTests {
    @Test func acceptsAConnectedMapAndCatchesUnreachablePlatformsAndMissingSeconds() throws {
        #expect(StationRouting.validate(try testMap()).isEmpty)
        var m = try testMap()
        m.edges = m.edges.filter { $0.to != "p2" }
        #expect(StationRouting.validate(m).contains("platform 2: unreachable"))
        var m2 = try testMap()
        let broken = m2.edges[2]
        m2.edges[2] = StationEdge(
            from: broken.from, to: broken.to, seconds: 0, stepFree: broken.stepFree, kind: broken.kind, meters: nil, geometry: nil, source: nil
        )
        #expect(StationRouting.validate(m2).first?.contains("no seconds") == true)
    }

    @Test func decodesAndValidatesTheRealStockholmCentralMap() throws {
        let url = try #require(Bundle.module.url(forResource: "station-map", withExtension: "json", subdirectory: "Fixtures"))
        let map = try JSONDecoder().decode(StationMap.self, from: Data(contentsOf: url))
        #expect(map.stationId == "740000001")
        #expect(map.name == "Stockholm C")
        #expect(map.view?.rotation == 35)
        #expect(map.platforms.count == 17)
        #expect(map.nodes.count == 161)
        #expect(map.edges.count == 221)
        #expect(map.pois.count == 75)
        #expect(StationRouting.validate(map).isEmpty)
        // A route between two real tracks exists.
        let route = StationRouting.routeTracks(map, from: map.platforms[0].tracks[0], to: map.platforms[5].tracks[0])
        #expect(route != nil)
        #expect((route?.seconds ?? 0) > 0)
    }
}

struct WalkingRouteTests {
    @Test func takesTheStairsByDefaultTheLiftWhenStepFreeAndSlowsDownWithLuggage() throws {
        let m = try testMap()
        let r = try #require(StationRouting.routeTracks(m, from: "1", to: "2b"))
        #expect(r.steps.map(\.kind) == [.stairs, .walk, .stairs])
        #expect(r.seconds == 65)
        let sf = try #require(StationRouting.routeTracks(m, from: "1", to: "2", profile: WalkProfile(pace: .normal, stepFree: true, luggage: false)))
        #expect(sf.steps.map(\.kind) == [.lift, .walk, .lift])
        let slow = try #require(StationRouting.routeTracks(m, from: "1", to: "2", profile: WalkProfile(pace: .relaxed, stepFree: false, luggage: true)))
        #expect(slow.seconds > r.seconds)
    }

    @Test func findsNoStepFreeRouteWhenThereIsNoLift() throws {
        var m = try testMap()
        m.edges = m.edges.filter { $0.kind != .lift }
        #expect(StationRouting.routeTracks(m, from: "1", to: "2", profile: WalkProfile(pace: .normal, stepFree: true, luggage: false)) == nil)
    }

    @Test func describesTheRouteFromTemplates() throws {
        let m = try testMap()
        let route = try #require(StationRouting.routeTracks(m, from: "1", to: "2"))
        let keys = StationRouting.instructions(m, route, from: .track("1"), to: .track("2")).map(\.key)
        #expect(keys == [.leave, .stairsDown, .walk, .stairsUp, .arrive])
    }
}

struct EndpointTests {
    @Test func readsTracksAmenitiesNodesAndMeFromTheirURLForm() throws {
        let m = try withToilet()
        let track = StationRouting.resolveEndpoint(m, "2b")
        #expect(track?.kind == .track)
        #expect(track?.track == "2b")
        #expect(track?.node.id == "p2")
        let poi = StationRouting.resolveEndpoint(m, "p:wc")
        #expect(poi?.kind == .poi)
        #expect(poi?.node.id == "b")
        #expect(StationRouting.resolveEndpoint(m, "n:a")?.kind == .node)
        #expect(StationRouting.resolveEndpoint(m, "me:a")?.kind == .me)
        #expect(StationRouting.resolveEndpoint(m, "p:nope") == nil)
        #expect(StationRouting.resolveEndpoint(m, "9") == nil)
    }

    @Test func routesFromATrackToAnAmenityAndWordsTheEndsByKind() throws {
        let m = try withToilet()
        let a = try #require(StationRouting.resolveEndpoint(m, "1"))
        let b = try #require(StationRouting.resolveEndpoint(m, "p:wc"))
        let r = try #require(StationRouting.routeBetween(m, a, b))
        #expect(r.steps.map(\.kind) == [.stairs, .walk])
        #expect(StationRouting.instructions(m, r, from: .endpoint(a), to: .endpoint(b)).map(\.key) == [.leave, .stairsDown, .walk, .reach])
        let back = try #require(StationRouting.routeBetween(m, b, a))
        #expect(StationRouting.instructions(m, back, from: .endpoint(b), to: .endpoint(a)).map(\.key) == [.start, .walk, .stairsUp, .arrive])
    }

    @Test func theSamePlatformIsAShortWalkAndTheSameSpotNone() throws {
        let m = try withToilet()
        let one = try #require(StationRouting.resolveEndpoint(m, "1"))
        #expect(StationRouting.routeBetween(m, one, one)?.seconds == 30)
        let spot = try #require(StationRouting.resolveEndpoint(m, "n:a"))
        #expect(StationRouting.routeBetween(m, spot, spot)?.seconds == 0)
    }

    @Test func snapsAPositionToTheNearestNodeOnItsLevel() throws {
        let m = try testMap()
        let p = StationRouting.toLocal(m, lat: 59 - 50 / 110_574, lon: 18 + 31 / (111_320 * cos(59 * Double.pi / 180)))
        #expect(abs(p.x - 31) < 0.001)
        #expect(abs(p.y - 50) < 0.001)
        #expect(StationRouting.nearestNode(m, level: "L0", x: p.x, y: p.y)?.id == "p2")
        #expect(StationRouting.nearestNode(m, level: "L-1", x: p.x, y: p.y)?.id == "b")
        #expect(StationRouting.nearestNode(m, level: "L0", x: 500, y: 500, maxMeters: 100) == nil)
    }

    @Test func findsThePlatformForATrackWithASectorLetter() throws {
        let m = try testMap()
        #expect(StationRouting.platform(forTrack: "2B", in: m)?.id == "p2")
        #expect(StationRouting.platform(forTrack: "9", in: m) == nil)
        #expect(StationRouting.platform(forTrack: nil, in: m) == nil)
    }
}

struct ConnectionStatusTests {
    private func t(_ min: Double) -> Double {
        (Instant.parse("2026-10-21T12:00:00Z")?.timeIntervalSince1970 ?? 0) * 1000 + min * 60_000
    }

    private var base: ConnectionInput {
        ConnectionInput(arrival: t(0), departure: t(20), arrivalPlatform: "1", departurePlatform: "2", walkSeconds: 120)
    }

    @Test func easyTightAndLikelyToMiss() {
        #expect(StationRouting.connectionStatus(base).status == .easy)
        var tight = base
        tight.departure = t(6)
        #expect(StationRouting.connectionStatus(tight).status == .tight)
        var miss = base
        miss.departure = t(3)
        #expect(StationRouting.connectionStatus(miss).status == .miss)
        let expectedSlack: Double = 20 * 60 - 120 - 90
        #expect(StationRouting.connectionStatus(base).slackSeconds == Optional(expectedSlack))
    }

    @Test func unknownWithoutAPlatformBrokenWhenATrainIsCancelled() {
        var noPlatform = base
        noPlatform.departurePlatform = nil
        #expect(StationRouting.connectionStatus(noPlatform).status == .unknown)
        var cancelled = base
        cancelled.canceledB = true
        #expect(StationRouting.connectionStatus(cancelled).status == .broken)
    }

    @Test func neverGreenOnAnEstimateOrOnTimetableOnlyTimesJustTheMargin() {
        var est = base
        est.walkSeconds = nil
        est.sizeClass = .large
        let result = StationRouting.connectionStatus(est)
        #expect(result.status == .margin)
        #expect(result.estimated)
        #expect(result.walkSeconds == 420)
        var later = est
        later.departure = t(40)
        #expect(StationRouting.connectionStatus(later).status == .margin)
        var near = est
        near.departure = t(12)
        #expect(StationRouting.connectionStatus(near).status == .tight)
        var soon = est
        soon.departure = t(5)
        #expect(StationRouting.connectionStatus(soon).status == .miss)
        var timetableOnly = base
        timetableOnly.timesLive = false
        #expect(StationRouting.connectionStatus(timetableOnly).status == .margin)
        timetableOnly.departure = t(6)
        #expect(StationRouting.connectionStatus(timetableOnly).status == .tight)
    }

    @Test func sizeClassFromTheNumberOfBaseTracks() {
        #expect(StationRouting.sizeClass(baseTracks: 4) == .small)
        #expect(StationRouting.sizeClass(baseTracks: 10) == .medium)
        #expect(StationRouting.sizeClass(baseTracks: 11) == .large)
    }
}

struct RampTests {
    @Test func aRampIsStepFreeAndReadsAsARamp() throws {
        let json = """
        {"station_id":"r","name":"Ramp","updated":"2026-10-30","quality":"osm_draft","sources":[],"changelog":[],
         "origin":{"lat":59,"lon":18},
         "levels":[{"id":"L0","name":"Street","order":0},{"id":"L-1","name":"Tunnel","order":-1}],"shapes":[],"platforms":[],
         "nodes":[{"id":"a","type":"junction","level":"L-1","x":0,"y":0},{"id":"b","type":"entrance","level":"L0","x":20,"y":0}],
         "edges":[{"from":"a","to":"b","seconds":15,"step_free":true,"kind":"ramp"}],"pois":[]}
        """
        let map = try JSONDecoder().decode(StationMap.self, from: Data(json.utf8))
        let route = try #require(StationRouting.route(map, from: "a", to: "b", profile: WalkProfile(stepFree: true)))
        #expect(route.steps.first?.kind == .ramp)
        let keys = StationRouting.instructions(map, route).map(\.key)
        #expect(keys.contains(.rampUp))
    }
}

