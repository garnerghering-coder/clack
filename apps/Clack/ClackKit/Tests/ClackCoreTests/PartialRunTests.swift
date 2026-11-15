//
//  PartialRunTests.swift
//  ClackCoreTests
//
//  A train cancelled for part of its way (build 86), as each country's feed gives it once the server has made the
//  stops' flags per role: Sweden (Trafikverket), Denmark (Rejseplanen), Norway (Entur), Finland (Digitraffic). Mirrors
//  packages/shared/src/disruption.test.ts.
//

import Foundation
import Testing
@testable import ClackCore

struct PartialRunTests {
    let now = (Instant.parse("2026-11-15T12:00:00Z")?.timeIntervalSince1970 ?? 0) * 1000

    private func stop(_ id: String, _ role: StopRole, canceled: Bool = false, arr: Bool? = nil, dep: Bool? = nil, lon: Double = 13, schedArr: Double? = nil, schedDep: Double? = nil) -> LegStop {
        var s = LegStop(
            seq: 0, role: role, stationId: id, name: "Name \(id)", code: nil, country: "SE", tz: "Europe/Stockholm", lat: 55.6, lon: lon,
            schedArr: schedArr.map { Instant(ms: $0) }, schedDep: schedDep.map { Instant(ms: $0) }, actualArr: nil, actualDep: nil,
            estimatedArr: nil, estimatedDep: nil, platform: nil, canceled: canceled, deviations: [], reportSource: .trafikverket
        )
        s.arrCanceled = arr
        s.depCanceled = dep
        return s
    }

    @Test func swedenTurnsBackBeforeWhereYouGetOff() {
        // Malmö C → Göteborg C, turning at Helsingborg C: its arrival runs, so it isn't a cancelled stop.
        let stops = [stop("M", .board), stop("Hb", .through, arr: false, dep: true), stop("Ä", .through, canceled: true), stop("G", .alight, canceled: true)]
        let run = Disruption.cancellation(of: stops)
        #expect(run == PartialRun(kind: .partial, runsTo: "Hb", runsToName: "Name Hb", endsThere: true))
        #expect(Disruption.assess(DisruptionInput(canceled: true, partial: run, schedDep: now + 3_600_000), now: now).kinds == [.endsEarly])
    }

    @Test func denmarkStartsLaterThanWhereYouGetOn() {
        let stops = [stop("KH", .board, canceled: true), stop("CPH", .through, canceled: true), stop("Kastrup", .through, arr: true, dep: false), stop("Malmö", .alight)]
        let run = Disruption.cancellation(of: stops)
        #expect(run?.kind == .partial)
        #expect(run?.runsFrom == "Kastrup")
        #expect(run?.startsThere == true)
        #expect(Disruption.assess(DisruptionInput(partial: run, schedDep: now + 3_600_000), now: now).kinds == [.startsLater])
    }

    @Test func norwaySkipsWhereYouGetOffAndRunsOn() {
        let stops = [stop("OSL", .board), stop("LLS", .through), stop("SKI", .alight, canceled: true), stop("MOSS", .after)]
        let run = Disruption.cancellation(of: stops)
        #expect(run?.runsTo == "LLS")
        #expect(run?.endsThere == false)
        #expect(Disruption.assess(DisruptionInput(partial: run, schedDep: now + 3_600_000), now: now).kinds == [.skipsAlight])
    }

    @Test func finlandHasNoTrainBetweenTwoStopsOrNoneOfYourPart() {
        // IC 142 Kuopio → Tampere on 2026-10-23: no train Pieksämäki–Jyväskylä.
        let gap = [stop("KUO", .board, dep: false), stop("PM", .through, arr: false, dep: true), stop("HKS", .through, canceled: true), stop("JY", .through, arr: true, dep: false), stop("TPE", .alight, arr: false)]
        let run = Disruption.cancellation(of: gap)
        #expect(run?.gaps == [PartialRun.Gap(from: "PM", to: "JY", fromName: "Name PM", toName: "Name JY")])
        #expect(Disruption.assess(DisruptionInput(partial: run, schedDep: now + 3_600_000), now: now).kinds == [.gap])
        let none = [stop("HKI", .board, canceled: true), stop("PSL", .through), stop("TPE", .alight, canceled: true)]
        #expect(Disruption.cancellation(of: none)?.kind == .full)
        #expect(Disruption.assess(DisruptionInput(partial: Disruption.cancellation(of: none), schedDep: now + 3_600_000), now: now).kinds == [.canceled])
    }

    @Test func aStopSkippedInTheMiddleIsNotAPartWayTrain() {
        #expect(Disruption.cancellation(of: [stop("A", .board), stop("B", .through, canceled: true), stop("C", .alight)]) == nil)
        // Not reported cancelled before yours: it may only skip your stop.
        let skip = [stop("X", .before), stop("A", .board, canceled: true), stop("B", .through), stop("C", .alight)]
        #expect(Disruption.cancellation(of: skip)?.startsThere == false)
        #expect(Disruption.assess(DisruptionInput(partial: Disruption.cancellation(of: skip), schedDep: now + 3_600_000), now: now).kinds == [.skipsBoard])
    }

    @Test func theStopFlagFollowsItsRole() {
        #expect(Disruption.stopCanceled(role: .board, arr: false, dep: true))
        #expect(!Disruption.stopCanceled(role: .board, arr: true, dep: false))
        #expect(Disruption.stopCanceled(role: .alight, arr: true, dep: nil))
        #expect(!Disruption.stopCanceled(role: .through, arr: false, dep: true))
        #expect(Disruption.stopCanceled(role: .through, arr: true, dep: true))
        #expect(!Disruption.stopCanceled(role: .after, arr: nil, dep: nil))
    }

    @Test func aPartWayTrainIsFollowedNotCancelled() throws {
        let leg = try JSONDecoder().decode(Leg.self, from: Data(Self.legJSON.utf8))
        #expect(leg.canceled)
        let run = PartialRun(kind: .partial, runsTo: "Hb", runsToName: "Helsingborg C", endsThere: true)
        #expect(LiveRules.statusKey(leg, live: nil, now: now, partial: run) != .cancelled)
        #expect(LiveRules.statusKey(leg, live: nil, now: now) == .cancelled)
        #expect(LiveRules.statusKey(leg, live: nil, now: now, partial: PartialRun(kind: .full)) == .cancelled)
        #expect(Disruption.fullyCanceled(leg, partial: run) == false)
    }

    @Test func theServersPartialRunDecodesWithWhatItLeavesOut() throws {
        let run = try JSONDecoder().decode(PartialRun.self, from: Data(#"{"kind":"partial","runsTo":"Hb","runsToName":"Helsingborg C","endsThere":true}"#.utf8))
        #expect(run.runsTo == "Hb")
        #expect(run.gaps.isEmpty)
        #expect(run.startsThere == false)
    }

    @Test func theRailNeverDrawsTheTrainGoingBack() {
        let hold = TripDetailLogic.TrainHold()
        #expect(TripDetailLogic.steadyTrain(1000, gps: false, key: "a", hold: hold) == 1000)
        // The phone's estimate ran ahead; the next report is a little behind: the train stays where it was drawn.
        #expect(TripDetailLogic.steadyTrain(1500, gps: false, key: "a", hold: hold) == 1500)
        #expect(TripDetailLogic.steadyTrain(1200, gps: true, key: "a", hold: hold) == 1500)
        #expect(TripDetailLogic.steadyTrain(1200, gps: false, key: "a", hold: hold) == 1500)
        // A GPS fix well behind (more than a kilometre) is the truth.
        #expect(TripDetailLogic.steadyTrain(300, gps: true, key: "a", hold: hold) == 300)
        // Another trip starts afresh.
        #expect(TripDetailLogic.steadyTrain(100, gps: false, key: "b", hold: hold) == 100)
        #expect(TripDetailLogic.steadyTrain(50, gps: false, key: "b", hold: nil) == 50)
    }

    @Test func theStopRailHoldsTheTrainBetweenRedraws() {
        let t0 = now
        let stops = [
            stop("A", .board, lon: 13.0, schedDep: t0), stop("B", .through, lon: 13.1, schedArr: t0 + 600_000, schedDep: t0 + 660_000),
            stop("C", .alight, lon: 13.2, schedArr: t0 + 1_200_000),
        ]
        let route = [LatLon(55.6, 13.0), LatLon(55.6, 13.1), LatLon(55.6, 13.2)]
        let hold = TripDetailLogic.TrainHold()
        let ahead = TripDetailLogic.segmentFills(stops: stops, route: route, shown: nil, stage: .during, now: t0 + 450_000, hold: hold, key: "leg")
        // An earlier clock (a later live report putting it behind): the fill doesn't go back.
        let behind = TripDetailLogic.segmentFills(stops: stops, route: route, shown: nil, stage: .during, now: t0 + 300_000, hold: hold, key: "leg")
        #expect(abs(ahead[0] - 0.75) < 0.02)
        #expect(behind == ahead)
        // Without a hold it does (the pure function, as before).
        let free = TripDetailLogic.segmentFills(stops: stops, route: route, shown: nil, stage: .during, now: t0 + 300_000)
        #expect(abs(free[0] - 0.5) < 0.02)
    }

    static let legJSON = #"""
    {"id":"l1","status":"planned","dataQuality":"partial","trainNumber":"1047","category":"regional","serviceDate":"2026-11-15",
     "schedDep":"2026-11-15T13:00:00Z","schedArr":"2026-11-15T15:00:00Z","actualDep":null,"actualArr":null,"depDelayMin":null,
     "arrDelayMin":null,"depPlatform":null,"arrPlatform":null,"canceled":true,"distanceM":null,"isEstimatedGeometry":false,
     "trainType":null,"trainTypeSource":null,"onboard":null,"countryCodes":["SE"],"journeyId":null,"timetableTripKey":"k",
     "operatorId":null,"originStationId":"M","destStationId":"G","notes":null,"ride":"pending","borderEvidence":null,
     "operator":null,"origin":null,"destination":null,"originTier":null,"trainCountry":null,"coach":null,"seat":null}
    """#
}
