//
//  StationDetailLogicTests.swift
//  ClackCoreTests
//

import Foundation
import Testing
@testable import ClackCore

struct StationDetailLogicTests {
    /// Two tracks running north from 59.0, 18.0: a running line and a siding 20 m east of it.
    private let running = StationDetailLogic.Track(points: [LatLon(59.0, 18.0), LatLon(59.01, 18.0)], service: false)
    private let siding = StationDetailLogic.Track(points: [LatLon(59.0, 18.00035), LatLon(59.01, 18.00035)], service: true)

    @Test func snapsToTheNearestTrackPreferringRunningLines() {
        // 8 m east of the running line, 12 m west of the siding: the running line.
        let hit = StationDetailLogic.nearest(LatLon(59.005, 18.00014), tracks: [running, siding])
        #expect(hit?.track == running)
        #expect(abs((hit?.alongM ?? 0) - 556) < 5)
        #expect(abs((hit?.bearingDeg ?? 99) - 0) < 1)
        // 50 m from both: nothing.
        #expect(StationDetailLogic.nearest(LatLon(59.005, 18.001), tracks: [running, siding]) == nil)
    }

    @Test func laysTheCarsAlongTheTrackFacingTheWayOfTravel() {
        let cars = StationDetailLogic.cars(at: LatLon(59.005, 18.0), bearing: 0, count: 3, carLength: 24, tracks: [running])
        #expect(cars.count == 3)
        #expect(cars[0].isFront)
        // Heading north: the front car's front is north of the middle, the last car's back south of it.
        #expect(cars[0].front.lat > 59.005)
        #expect(cars[2].back.lat < 59.005)
        // The whole train is about 73.6 m long, centred on the point.
        let span = TrainKit.distanceM(cars[2].back, cars[0].front)
        #expect(abs(span - 73.6) < 1)
        // Heading south on the same track: the front is south.
        let south = StationDetailLogic.cars(at: LatLon(59.005, 18.0), bearing: 180, count: 2, carLength: 24, tracks: [running])
        #expect(south[0].front.lat < 59.005)
    }

    @Test func offTheTracksAStraightLineAlongTheBearing() {
        let cars = StationDetailLogic.cars(at: LatLon(59.005, 18.01), bearing: 90, count: 2, carLength: 20, tracks: [running])
        #expect(cars[0].front.lon > 18.01)
        #expect(abs(cars[0].front.lat - 59.005) < 1e-6)
        #expect(StationDetailLogic.cars(at: LatLon(59, 18), bearing: nil, count: 0, carLength: 20, tracks: []).isEmpty)
    }
}
