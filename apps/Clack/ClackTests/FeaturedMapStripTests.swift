//
//  FeaturedMapStripTests.swift
//  ClackTests
//

import ClackCore
import Testing
@testable import Clack

@MainActor
struct FeaturedMapStripTests {
    private let route = FeaturedMapStrip.Route(route: [LatLon(59, 18), LatLon(58, 16)], stops: [])

    @Test func theSameInputsAreEqualSoTheClockDoesNotRedrawTheMap() {
        let a = FeaturedMapStrip(color: "#fff", geo: route, train: nil, progress: 0.4)
        let b = FeaturedMapStrip(color: "#fff", geo: route, train: nil, progress: 0.4)
        #expect(a == b)
    }

    @Test func aMovedTrainOrNewProgressIsADifferentStrip() {
        let a = FeaturedMapStrip(color: "#fff", geo: route, train: MapTrain(lat: 59, lon: 18, bearing: nil, estimated: false), progress: 0.4)
        #expect(a != FeaturedMapStrip(color: "#fff", geo: route, train: MapTrain(lat: 58.9, lon: 18, bearing: nil, estimated: false), progress: 0.4))
        #expect(a != FeaturedMapStrip(color: "#fff", geo: route, train: a.train, progress: 0.5))
    }
}
