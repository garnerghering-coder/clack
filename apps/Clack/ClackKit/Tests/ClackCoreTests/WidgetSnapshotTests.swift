//
//  WidgetSnapshotTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

private let m = 60_000.0

private func leg(_ id: String, dep: Double, arr: Double) -> WidgetSnapshot.Leg {
    WidgetSnapshot.Leg(id: id, journeyId: "j", from: "A", to: "B", fromTz: "Europe/Stockholm", toTz: "Europe/Stockholm", depAt: dep, arrAt: arr, canceled: false)
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
        var s = WidgetSnapshot(updatedAt: 5, language: .sv, clock: .h12)
        s.journey = legs
        s.nextJourney = [leg("c", dep: 400 * m, arr: 500 * m)]
        s.boards = [.init(id: "x", name: "X", tz: "Europe/Oslo", updatedAt: 7, rows: [.init(id: "r", time: 1, expected: 2, to: "Y", train: "9", canceled: false)])]
        let back = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(s))
        #expect(back == s)
    }
}
