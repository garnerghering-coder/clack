//
//  StationScene3DTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

/// Two platforms, an upper level 4 m up reached by stairs, an escalator whose ends sit at one point and a lift; two
/// track shapes without numbers, one beside each platform.
private func testMap() throws -> StationMap {
    let json = """
    {"schema":2,"station_id":"t","name":"Test C","updated":"2026-10-29","quality":"osm_draft","sources":[],"changelog":[],
     "origin":{"lat":57.78,"lon":14.16},
     "levels":[{"id":"L1","name":"Upper","order":1,"height_m":4},{"id":"L0","name":"Platforms","order":0}],
     "shapes":[
       {"level":"L0","kind":"track","name":null,"points":[[-1.5,-50],[-1.5,150]]},
       {"level":"L0","kind":"track","name":null,"points":[[35.7,-50],[35.7,150]]},
       {"level":"L0","kind":"building","name":null,"points":[[50,0],[60,0],[60,10],[50,10],[50,0]]}],
     "platforms":[
       {"id":"p1","ref":"1","tracks":["1"],"level":"L0","geometry":[[[0,0],[4,0],[4,100],[0,100],[0,0]]],"node":"p1",
        "edges":[{"track":"1","points":[[0,0],[0,100]],"_source":"test"}]},
       {"id":"p2","ref":"2","tracks":["2"],"level":"L0","geometry":[[[30,0],[34,0],[34,100],[30,100],[30,0]]],"node":"p2",
        "edges":[{"track":"2","points":[[34,0],[34,100]],"_source":"test"}]}],
     "nodes":[
       {"id":"p1","type":"platform","level":"L0","x":2,"y":50},{"id":"p2","type":"platform","level":"L0","x":32,"y":50},
       {"id":"g1","type":"stairs","level":"L0","x":10,"y":60},{"id":"g2","type":"escalator","level":"L0","x":20,"y":20},
       {"id":"g3","type":"entrance","level":"L0","x":25,"y":80},
       {"id":"u1","type":"junction","level":"L1","x":10,"y":20},{"id":"u2","type":"escalator","level":"L1","x":20,"y":20},
       {"id":"u3","type":"stairs","level":"L1","x":15,"y":40}],
     "edges":[
       {"from":"u1","to":"u2","seconds":10,"step_free":true,"kind":"walk"},
       {"from":"u3","to":"g1","seconds":20,"step_free":false,"kind":"stairs"},
       {"from":"g2","to":"u2","seconds":20,"step_free":false,"kind":"escalator"},
       {"from":"u1","to":"g3","seconds":45,"step_free":true,"kind":"lift"}],
     "pois":[]}
    """
    return try JSONDecoder().decode(StationMap.self, from: Data(json.utf8))
}

private func row(_ number: String, at: Double, platform: String?, canceled: Bool = false) -> BoardRow {
    BoardRow(id: number, trainNumber: number, advertised: at, estimated: nil, actual: nil, done: false, delayMin: nil, platform: platform, platformChange: nil, canceled: canceled, deviations: [], endpoints: ["Malmö C"], via: [], operatorId: "sj", productName: nil, product: "regional", trainType: nil, trip: nil)
}

struct StationScene3DTests {
    @Test func localToWGS84AndBackWithinATenthOfAMetre() throws {
        let map = try testMap()
        for p in [Pt(0, 0), Pt(180, -60), Pt(-260, 95)] {
            let g = StationRouting.toWGS84(map, x: p.x, y: p.y)
            let back = StationRouting.toLocal(map, lat: g.lat, lon: g.lon)
            #expect(hypot(back.x - p.x, back.y - p.y) < 0.1)
        }
        // South is +y: a point south of the origin has a smaller latitude.
        #expect(StationRouting.toWGS84(map, x: 0, y: 100).lat < map.origin.lat)
    }

    @Test func platformsWithoutAHeightStandAtTheStandardHeightAndSaySo() throws {
        let scene = StationScene3D.build(try testMap())
        #expect(scene.platforms.count == 2)
        #expect(scene.platforms.allSatisfy { $0.isStandardHeight })
        // Heights are above the platform surface: the platform's top is 0, the rails a platform height below.
        #expect(scene.platforms[0].pieces[0].top == 0)
        #expect(scene.platforms[0].pieces[0].bottom == -StationScene3D.standardPlatformHeight)
        #expect(scene.railY == -StationScene3D.standardPlatformHeight)
        #expect(scene.platforms[0].pieces[0].footprint.count == 4)
        #expect(scene.notes.draft && scene.notes.standardPlatformHeight && scene.notes.buildingHeightUnknown && scene.notes.rampSlopeStandard)
        let b = try #require(scene.buildings.first?.prism)
        #expect(abs(b.top - b.bottom - StationScene3D.defaultBuildingHeight) < 1e-9)
        #expect(scene.terrain == nil && scene.notes.flatGround && !scene.notes.lantmateriet)
        #expect(scene.tracks.count == 2)
        #expect(scene.ground.minX == -21.5 && scene.ground.maxZ == 170)
    }

    @Test func stairsRampRunsFromTheLowerLevelToTheUpperOneAtTheStandardSlope() throws {
        let scene = StationScene3D.build(try testMap())
        // The edge runs upper → lower in the data; the ramp starts at the bottom and ends at the upper node.
        let stairs = try #require(scene.ramps.first { $0.kind == .stairs })
        let top = try #require(stairs.points.last)
        #expect(top.x == 15 && top.z == 40 && abs(top.y - 4) < 1e-9)
        #expect(stairs.points.first?.y == 0)
        // Its ends are 20.6 m apart for a 4 m rise: drawn at 30° instead (6.9 m), toward the lower node (10, 60).
        let a = try #require(stairs.points.first), b = try #require(stairs.points.last)
        let run = hypot(b.x - a.x, b.z - a.z)
        #expect(abs(run - 4 / tan(Double.pi / 6)) < 1e-6)
        #expect(a.z > b.z && a.x < b.x)
    }

    @Test func anEscalatorWithBothEndsAtOnePointAndTheLiftAreColumns() throws {
        let scene = StationScene3D.build(try testMap())
        #expect(!scene.ramps.contains { $0.kind == .escalator })
        #expect(scene.columns.count == 2)
        #expect(scene.columns.allSatisfy { $0.bottom == 0 && $0.top == 4 })
    }

    @Test func aLevelWithOnlyWalkwayPointsGetsNoFloor() throws {
        // Nothing is drawn from the walkway nodes alone (owner, 2026-10-30: the inferred hull "isn't actually there").
        #expect(StationScene3D.build(try testMap()).slabs.isEmpty)
    }

    @Test func aTrainOnTrackTwoStandsBesidePlatformTwo() throws {
        let map = try testMap()
        let p2 = try #require(map.platforms.first { $0.id == "p2" })
        let track = try #require(StationScene3D.platformTrack(map, platform: p2))
        #expect(track.allSatisfy { abs($0.x - 35.7) < 1e-6 })
        let middle = StationScene3D.platformMiddle(p2, track: track)
        let cars = StationScene3D.carPlaces(map, track: track, middleM: middle, offsetM: 0, count: 3, carLength: 24)
        #expect(cars.count == 3)
        for c in cars {
            #expect(abs(c.x - 35.7) < 0.2)
            #expect(c.z > 0 && c.z < 100)
        }
        // Centred on the platform: the middle car at y 50.
        #expect(abs(cars[1].z - 50) < 0.5)
        // The track runs south (+z): the cars' length axis points along it.
        #expect(abs(abs(cars[0].yaw) - .pi / 2) < 0.01)
        // Arriving: 100 m back along the track.
        let before = StationScene3D.carPlaces(map, track: track, middleM: middle, offsetM: -100, count: 3, carLength: 24)
        #expect(abs((cars[1].z - before[1].z) - 100) < 0.5)
    }

    @Test func eachStateBoundary() throws {
        let map = try testMap()
        let now = 1_800_000_000_000.0
        func state(arr: Double?, dep: Double?) -> StationScene3D.Scene3DTrain? {
            StationScene3D.trainStates(arrivals: arr.map { [row("1", at: now + $0, platform: "2")] } ?? [], departures: dep.map { [row("1", at: now + $0, platform: "2")] } ?? [], now: now, map: map).first
        }
        #expect(state(arr: 61_000, dep: 300_000)?.state == .upcoming)
        #expect(state(arr: 60_000, dep: 300_000)?.state == .arriving)
        #expect(state(arr: 60_000, dep: 300_000)?.offsetM == -StationScene3D.slideMeters)
        #expect(state(arr: 30_000, dep: 300_000)?.offsetM == -StationScene3D.slideMeters / 4)
        #expect(state(arr: 0, dep: 300_000)?.state == .standing)
        #expect(state(arr: -120_000, dep: 300_000)?.state == .standing)
        #expect(state(arr: -120_000, dep: 0)?.state == .leaving)
        #expect(state(arr: -120_000, dep: 0)?.offsetM == 0)
        #expect(state(arr: -120_000, dep: -60_000)?.offsetM == StationScene3D.slideMeters)
        #expect(state(arr: -120_000, dep: -61_000) == nil)
        #expect(state(arr: 31 * 60_000, dep: nil) == nil)
        // Ends here: standing for three minutes, then gone. Starts here: standing for three minutes before.
        #expect(state(arr: -180_000, dep: nil)?.state == .standing)
        #expect(state(arr: -181_000, dep: nil) == nil)
        #expect(state(arr: nil, dep: 180_000)?.state == .standing)
        #expect(state(arr: nil, dep: 181_000)?.state == .upcoming)
        #expect(state(arr: 0, dep: 300_000)?.platformId == "p2")
    }

    @Test func cancelledRowsAreLeftOutAndUnknownPlatformsListedNotPlaced() throws {
        let map = try testMap()
        let now = 1_800_000_000_000.0
        let trains = StationScene3D.trainStates(
            arrivals: [row("1", at: now - 60_000, platform: "2", canceled: true), row("2", at: now - 60_000, platform: nil), row("3", at: now - 60_000, platform: "9")],
            departures: [row("1", at: now + 60_000, platform: "2", canceled: true), row("2", at: now + 60_000, platform: nil), row("3", at: now + 60_000, platform: "9")],
            now: now, map: map
        )
        #expect(trains.map(\.trainNumber) == ["2", "3"])
        #expect(trains.allSatisfy { $0.platformId == nil && $0.state == .standing })
        #expect(StationScene3D.nextChange(trains, now: now) == now + 60_000)
    }

    @Test func prismMeshFacesOutwardAndUp() throws {
        let prism = StationScene3D.Prism(footprint: [Pt(0, 0), Pt(0, 10), Pt(10, 10), Pt(10, 0)], bottom: 0, top: 1)
        let m = StationScene3D.mesh(prism)
        // Two triangles on top, two per wall.
        #expect(m.indices.count == (2 + 8) * 3)
        let ups = m.normals.filter { $0.y > 0.99 }.count
        #expect(ups == 6)
        // A wall normal points away from the middle.
        for (p, n) in zip(m.positions, m.normals) where abs(n.y) < 0.01 {
            #expect((p.x - 5) * n.x + (p.z - 5) * n.z > 0)
        }
        // An L-shape triangulates into four triangles.
        let l = StationScene3D.triangulate([Pt(0, 0), Pt(2, 0), Pt(2, 1), Pt(1, 1), Pt(1, 2), Pt(0, 2)])
        #expect(l.count == 4)
    }

    @Test func carSizesAndCounts() {
        #expect(StationScene3D.carSize(.doubleDeck).height == 4.6)
        #expect(StationScene3D.carSize(.multipleUnit) == (3.0, 3.8))
        let none = StationScene3D.cars(for: nil)
        #expect(none.template == .multipleUnit && none.count == 4 && none.length == 24)
    }

    @Test func measuredBuildingsRoofsAndGround() throws {
        let json = """
        {"schema":2,"station_id":"m","name":"Measured C","updated":"2026-10-30","quality":"osm_draft",
         "sources":[{"type":"lantmateriet"},{"type":"trafikverket"}],"changelog":[],"origin":{"lat":57.78,"lon":14.16},
         "levels":[{"id":"L0","name":"Platforms","order":0}],
         "shapes":[
           {"level":"L0","kind":"building","name":"Station","points":[[0,0],[10,0],[10,10],[0,10]],"top_m":8.4,"base_m":-1.2},
           {"level":"L0","kind":"building","name":"Shed","points":[[20,0],[30,0],[30,10],[20,10]],"top_m":5},
           {"level":"L0","kind":"roof","name":"Canopy","points":[[0,20],[10,20],[10,30],[0,30]],"top_m":3.4},
           {"level":"L0","kind":"roof","name":"No height","points":[[0,40],[10,40],[10,50],[0,50]]}],
         "platforms":[
           {"id":"p1","ref":"1","tracks":["1"],"level":"L0","geometry":[[[0,0],[4,0],[4,100],[0,100]]],"node":"p1","height_m":0.58},
           {"id":"p2","ref":"2","tracks":["2"],"level":"L0","geometry":[[[30,0],[34,0],[34,100],[30,100]]],"node":"p2","height_m":0.58}],
         "nodes":[{"id":"p1","type":"platform","level":"L0","x":2,"y":50},{"id":"p2","type":"platform","level":"L0","x":32,"y":50}],
         "edges":[],"pois":[],
         "terrain":{"x0":0,"y0":0,"step":10,"cols":4,"rows":2,"heights":[[-0.8,-0.8,1.2,null],[-0.8,-0.8,3.2,null]],"_source":"test"}}
        """
        let map = try JSONDecoder().decode(StationMap.self, from: Data(json.utf8))
        let scene = StationScene3D.build(map)
        #expect(scene.railY == -0.58)
        #expect(!scene.notes.standardPlatformHeight && !scene.notes.buildingHeightUnknown && !scene.notes.flatGround)
        #expect(scene.notes.lantmateriet && scene.notes.trafikverket && scene.notes.roofUndersideUnknown)
        let station = try #require(scene.buildings.first { $0.name == "Station" })
        #expect(station.prism.bottom == -1.2 && station.prism.top == 8.4 && station.heightKnown)
        // No base given: from the lowest terrain under its corners (x 20–30: 1.2 at x 20, nothing measured at x 30).
        let shed = try #require(scene.buildings.first { $0.name == "Shed" })
        #expect(abs(shed.prism.bottom - 1.2) < 1e-9 && shed.prism.top == 5)
        // A roof is a sheet under its measured top; one without a top isn't drawn.
        #expect(scene.roofs.count == 1)
        #expect(scene.roofs[0].prism.top == 3.4 && abs(scene.roofs[0].prism.bottom - (3.4 - StationScene3D.roofThickness)) < 1e-9)
        // Two cells have all four corners: four triangles, all facing up.
        let ground = try #require(scene.terrain)
        #expect(ground.indices.count == 4 * 3)
        #expect(ground.normals.allSatisfy { $0.y > 0 })
        #expect(scene.backdropY < -0.8)
        let t = try #require(map.terrain)
        #expect(abs((StationScene3D.terrainHeight(t, x: 15, y: 5) ?? 0) - 0.7) < 1e-9)
        #expect(StationScene3D.terrainHeight(t, x: 20, y: 10) == 3.2)
        // Next to a cell without a value, and off the grid.
        #expect(StationScene3D.terrainHeight(t, x: 25, y: 5) == nil)
        #expect(StationScene3D.terrainHeight(t, x: 35, y: 5) == nil)
    }
}
