//
//  WidgetSnapshotTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack
@testable import ClackCore

private let m = 60_000.0

private func leg(_ id: String, dep: Double, arr: Double) -> WidgetSnapshot.Leg {
    WidgetSnapshot.Leg(
        id: id, journeyId: "j", operatorName: nil, color: nil, train: nil, from: "A", to: "B", fromTz: "Europe/Stockholm", toTz: "Europe/Stockholm",
        depAt: dep, arrAt: arr, depPlatform: nil, arrPlatform: nil, delayMin: nil, canceled: false, status: nil, progress: nil, nextStop: nil, nextStopAt: nil
    )
}

struct WidgetSnapshotTests {
    private let legs = [leg("a", dep: 100 * m, arr: 200 * m), leg("b", dep: 215 * m, arr: 300 * m)]

    @Test func beforeTheFirstDeparture() {
        #expect(JourneyMoment.at(50 * m, legs: legs) == .before(leg: 0))
    }

    @Test func onTheTrainWithProgress() {
        #expect(JourneyMoment.at(150 * m, legs: legs) == .onTrain(leg: 0, progress: 0.5))
    }

    @Test func atAChangeCountsTheSpareMinutes() {
        #expect(JourneyMoment.at(205 * m, legs: legs) == .changing(next: 1, spareMin: 10))
    }

    @Test func finishedAfterTheLastArrival() {
        #expect(JourneyMoment.at(300 * m, legs: legs) == .finished)
        #expect(JourneyMoment.at(0, legs: []) == .finished)
    }

    @Test func theSnapshotSurvivesEncoding() throws {
        var s = WidgetSnapshot(updatedAt: 5)
        s.journey = legs
        s.boards = [.init(id: "x", name: "X", rows: [])]
        let back = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(s))
        #expect(back == s)
    }
}
