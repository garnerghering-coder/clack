//
//  RideLogicTests.swift
//  ClackCoreTests
//

import Foundation
import Testing
@testable import ClackCore

struct RideLogicTests {
    /// A straight track north from 59.0, 18.0: about 1112 m per 0.01°, with stops at the start, the middle and the end.
    private var track: RideLogic.Track {
        let pts = (0...10).map { LatLon(59.0 + Double($0) * 0.01, 18.0) }
        let cum = TrainKit.cumulative(pts)
        return RideLogic.Track(points: pts, stopsAt: [1: 0, 2: cum[5], 3: cum[10]])
    }

    @Test func snapsAReportOntoTheTrack() {
        let t = track
        // A point a little east of the line, three tenths of the way: metres along ≈ 30% of the length.
        let m = RideLogic.metresAlong(t, of: LatLon(59.03, 18.002))
        #expect(abs(m - t.length * 0.3) < 5)
        // Before the start and past the end clamp.
        #expect(RideLogic.metresAlong(t, of: LatLon(58.9, 18.0)) == 0)
        #expect(abs(RideLogic.metresAlong(t, of: LatLon(59.2, 18.0)) - t.length) < 0.01)
    }

    @Test func extrapolatesAtSpeedButStopsAtTheNextStopAndTheEnd() {
        let t = track
        // 72 km/h = 20 m/s for 10 s: 200 m on.
        #expect(abs(RideLogic.extrapolate(metres: 1000, reportedAt: 0, speedKmh: 72, now: 10_000, track: t) - 1200) < 0.01)
        // Standing (no speed): stays.
        #expect(RideLogic.extrapolate(metres: 1000, reportedAt: 0, speedKmh: 0, now: 60_000, track: t) == 1000)
        // Never past the next stop (the middle one) even after a long gap.
        let mid = t.stopsAt[2]!
        #expect(RideLogic.extrapolate(metres: mid - 100, reportedAt: 0, speedKmh: 200, now: 100_000, track: t) == mid)
        // Nor past the end.
        #expect(RideLogic.extrapolate(metres: t.length - 50, reportedAt: 0, speedKmh: 200, now: 100_000, track: t) == t.length)
        // At most two minutes of extrapolation.
        #expect(abs(RideLogic.extrapolate(metres: 0, reportedAt: 0, speedKmh: 36, now: 600_000, track: t, maxSeconds: 120) - 1200) < 0.01)
    }

    @Test func buildsATrackFromTripGeometryWithStopsAtSegmentEnds() {
        let a = [LatLon(59.0, 18.0), LatLon(59.01, 18.0)]
        let b = [LatLon(59.01, 18.0), LatLon(59.03, 18.0)]
        let geometry = TripGeometry(segments: [
            .init(fromSeq: 1, toSeq: 2, polyline: Polyline.encode(a), lengthM: 1112, estimated: false),
            .init(fromSeq: 2, toSeq: 3, polyline: Polyline.encode(b), lengthM: 2224, estimated: false),
        ])
        let t = RideLogic.Track(geometry: geometry)
        #expect(t.points.count == 3)
        #expect(t.stopsAt[1] == 0)
        #expect(abs(t.stopsAt[2]! - 1112) < 5)
        #expect(abs(t.stopsAt[3]! - t.length) < 0.01)
    }

    @Test func speedometerPrefersThePhoneOnlyWhenAboard() {
        // Under way, fresh fix, 200 m from the drawn train: the phone's speed.
        #expect(RideLogic.speed(phoneKmh: 143, phoneAgeS: 2, phoneDistanceM: 200, trainKmh: 140, trainEstimated: false, trainAgeS: 5, underWay: true) == .init(kmh: 143, source: .phone))
        // Not under way yet (at the platform): the train's.
        #expect(RideLogic.speed(phoneKmh: 3, phoneAgeS: 2, phoneDistanceM: 50, trainKmh: 0, trainEstimated: false, trainAgeS: 5, underWay: false) == .init(kmh: 0, source: .trainLive))
        // Phone 3 km away (looking at someone else's train): the train's, labelled estimated when it is.
        #expect(RideLogic.speed(phoneKmh: 50, phoneAgeS: 2, phoneDistanceM: 3000, trainKmh: 90, trainEstimated: true, trainAgeS: 30, underWay: true) == .init(kmh: 90, source: .trainEstimated))
        // Stale phone fix: the train's.
        #expect(RideLogic.speed(phoneKmh: 50, phoneAgeS: 40, phoneDistanceM: 100, trainKmh: 90, trainEstimated: false, trainAgeS: 30, underWay: true).source == .trainLive)
        // No fresh information at all.
        #expect(RideLogic.speed(phoneKmh: nil, phoneAgeS: nil, phoneDistanceM: nil, trainKmh: 90, trainEstimated: false, trainAgeS: 400, underWay: true) == .init(kmh: nil, source: .none))
    }

    @Test func cameraPresetsAndPinchRange() {
        #expect(RideLogic.camera(.behind) == .init(pitch: 65, distance: 320, headingOffset: 0, lookAheadM: 0))
        #expect(RideLogic.camera(.side).headingOffset == 90)
        #expect(RideLogic.camera(.driver).lookAheadM > 0)
        // A pinch past the limits is held at them.
        #expect(RideLogic.camera(.above, distance: 10_000).distance == 2500)
        #expect(RideLogic.camera(.driver, distance: 10).distance == 80)
    }
}
