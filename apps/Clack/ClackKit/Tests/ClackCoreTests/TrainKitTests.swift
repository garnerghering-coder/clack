//
//  TrainKitTests.swift
//  ClackTests
//

import Testing
@testable import ClackCore

struct TrainKitTests {
    @Test func eachArtFamilyGetsADesign() {
        #expect(TrainKit.template(forArt: "x2000") == .highSpeed)
        #expect(TrainKit.template(forArt: "double_deck") == .doubleDeck)
        #expect(TrainKit.template(forArt: "loco_sleeper") == .locoCoaches)
        #expect(TrainKit.template(forArt: "dk_railcar") == .railcar)
        #expect(TrainKit.template(forArt: "coradia") == .multipleUnit)
        #expect(TrainKit.template(forArt: nil) == .multipleUnit)
    }

    @Test func theFeedsCarCountWinsThenTheTypesThenADefault() {
        #expect(TrainKit.carCount(live: 7, typical: 4, template: .multipleUnit) == (7, true))
        #expect(TrainKit.carCount(live: nil, typical: 4, template: .multipleUnit) == (4, false))
        #expect(TrainKit.carCount(live: 0, typical: nil, template: .locoCoaches) == (5, false))
    }

    @Test func carsFollowTheTrackAndBendWithIt() {
        // A straight line north, then east: 1 km each leg (about 0.009° lat, 0.0164° lon at 57° N).
        let track = [LatLon(57.0, 14.0), LatLon(57.009, 14.0), LatLon(57.009, 14.0165)]
        let poses = TrainKit.carPoses(track: track, headM: 1050, count: 4, carLength: 24, gap: 1)
        #expect(poses.count == 4)
        // The front car is on the eastward leg, the last cars still on the northward one.
        #expect(abs(poses[0].headingDeg - 90) < 3)
        #expect(abs(poses[3].headingDeg - 0) < 3 || abs(poses[3].headingDeg - 360) < 3)
        // Cars sit one behind the other.
        #expect(TrainKit.distanceM(poses[0].center, poses[1].center) > 20)
        // A train at its origin doesn't hang off the start of the track.
        let start = TrainKit.carPoses(track: track, headM: 10, count: 3, carLength: 24)
        #expect(start.allSatisfy { $0.center.lat >= 57.0 })
        #expect(abs(TrainKit.trainLength(count: 4, carLength: 24, gap: 1) - 99) < 0.001)
    }
}
