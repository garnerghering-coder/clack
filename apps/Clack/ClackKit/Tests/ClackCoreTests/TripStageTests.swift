//
//  TripStageTests.swift
//  ClackTests
//
//  What a trip's page shows at each stage: which sections, and which stops.
//

import Foundation
import Testing
@testable import ClackCore

private func stop(_ seq: Int, _ role: StopRole, _ id: String) -> LegStop {
    LegStop(
        seq: seq, role: role, stationId: id, name: id, code: nil, country: "SE", tz: "Europe/Stockholm", lat: 57, lon: 14 + Double(seq) / 10,
        schedArr: nil, schedDep: nil, actualArr: nil, actualDep: nil, estimatedArr: nil, estimatedDep: nil, platform: nil, canceled: false,
        deviations: [], reportSource: .trafikverket
    )
}

/// Z before, then A (board), C, D, E, F through, B (alight), then Y after.
private let trip: [LegStop] = [
    stop(1, .before, "Z"), stop(2, .board, "A"), stop(3, .through, "C"), stop(4, .through, "D"), stop(5, .through, "E"),
    stop(6, .through, "F"), stop(7, .alight, "B"), stop(8, .after, "Y"),
]

private func live(next: String?) -> LiveStateRow {
    LiveStateRow(
        legId: "a", updatedAt: Instant(ms: 0), status: .enRoute, lat: nil, lon: nil, bearing: nil, speedKmh: nil, positionSource: nil,
        positionAt: nil, progress: 0.5, prevStopId: nil, nextStopId: next, eta: nil, arrivalEta: nil, arrivalDelayMin: nil, reportedAt: nil
    )
}

struct TripStageTests {
    private func ids(_ stops: [LegStop]) -> [String] { stops.map(\.stationId) }

    @Test func beforeLeavingOnlyWhereYouGetOnAndOff() {
        #expect(ids(TripDetailLogic.timelineStops(trip, stage: .before, shown: nil, fullRoute: false)) == ["A", "B"])
    }

    @Test func onTheTrainTheStopsAroundIt() {
        // Next stop E: where you got on, the stop before E, then E to where you get off.
        #expect(ids(TripDetailLogic.timelineStops(trip, stage: .during, shown: live(next: "E"), fullRoute: false)) == ["A", "D", "E", "F", "B"])
        // Next stop C, right after boarding: the whole ride.
        #expect(ids(TripDetailLogic.timelineStops(trip, stage: .during, shown: live(next: "C"), fullRoute: false)) == ["A", "C", "D", "E", "F", "B"])
        // Not known where it is: the whole ride.
        #expect(ids(TripDetailLogic.timelineStops(trip, stage: .during, shown: live(next: nil), fullRoute: false)) == ["A", "C", "D", "E", "F", "B"])
        // A next stop outside the ride (it hasn't reached you): the whole ride.
        #expect(ids(TripDetailLogic.timelineStops(trip, stage: .during, shown: live(next: "Z"), fullRoute: false)).count == 6)
    }

    @Test func afterEveryStopRidden() {
        #expect(ids(TripDetailLogic.timelineStops(trip, stage: .after, shown: nil, fullRoute: false)) == ["A", "C", "D", "E", "F", "B"])
    }

    @Test func theFullRouteIsEverything() {
        for stage in [TripDetailLogic.Stage.before, .during, .after] {
            #expect(TripDetailLogic.timelineStops(trip, stage: stage, shown: live(next: "E"), fullRoute: true).count == trip.count)
        }
    }

    @Test func aShortRideIsAlwaysWhole() {
        let short = [stop(1, .board, "A"), stop(2, .alight, "B"), stop(3, .after, "Y")]
        #expect(ids(TripDetailLogic.timelineStops(short, stage: .before, shown: nil, fullRoute: false)) == ["A", "B"])
        // A manual trip with no roles known still shows its stops.
        let unknown = [stop(1, .unknown("x"), "A"), stop(2, .unknown("x"), "B")]
        #expect(TripDetailLogic.timelineStops(unknown, stage: .before, shown: nil, fullRoute: false).count == 2)
    }

    @Test func getOffWhenTheNextStopIsYours() {
        #expect(TripDetailLogic.getOffNext(trip, shown: live(next: "B"), stage: .during))
        #expect(!TripDetailLogic.getOffNext(trip, shown: live(next: "F"), stage: .during))
        #expect(!TripDetailLogic.getOffNext(trip, shown: live(next: "B"), stage: .before))
    }

    @Test func eachStageAnswersItsOwnQuestionFirst() {
        // Before: when and which platform. During: where it is. After: how it went.
        #expect(TripDetailLogic.sections(.before).first == .countdown)
        #expect(TripDetailLogic.sections(.during).first == .live)
        #expect(TripDetailLogic.sections(.after).first == .result)
        // Directions, the risk and the alerts prompt are for a trip still ahead.
        for section in [TripDetailLogic.Section.directions, .risk, .alertsPrompt] {
            #expect(TripDetailLogic.sections(.before).contains(section))
            #expect(!TripDetailLogic.sections(.during).contains(section))
            #expect(!TripDetailLogic.sections(.after).contains(section))
        }
        // Everything else about the train is behind one disclosure, at every stage.
        for stage in [TripDetailLogic.Stage.before, .during, .after] {
            #expect(TripDetailLogic.sections(stage).contains(.about))
        }
    }
}
