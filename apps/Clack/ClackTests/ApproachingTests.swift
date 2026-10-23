//
//  ApproachingTests.swift
//  ClackTests
//
//  The owner's SJ 547 case (2026-10-23): a train running late into the stop you board at is not "boarding", and the
//  same rule on the server (apps/server/test/liveProgress.test.ts) and here.
//

import Foundation
import Testing
@testable import Clack

private func T(_ hhmm: String) -> Double {
    let parts = hhmm.split(separator: ":").compactMap { Double($0) }
    let base = (Instant.parse("2026-10-20T00:00:00Z")?.timeIntervalSince1970 ?? 0) * 1000
    return base + (parts[0] - 2) * 3_600_000 + parts[1] * 60_000
}

private func board(_ extra: (inout LiveStop) -> Void = { _ in }) -> [LiveStop] {
    var b = LiveStop(stationId: "B", lat: 57, lon: 14.1, schedArr: T("10:10"), schedDep: T("10:12"), actualArr: nil, actualDep: nil, canceled: false)
    b.estimatedArr = T("10:30")
    extra(&b)
    var c = LiveStop(stationId: "C", lat: 57, lon: 14.2, schedArr: T("10:22"), schedDep: nil, actualArr: nil, actualDep: nil, canceled: false)
    c.estimatedArr = T("10:42")
    return [b, c]
}

private let ridden = [LatLon(57, 14.1), LatLon(57, 14.2)]
private func fix(_ lon: Double, _ at: String) -> GpsFix { GpsFix(lat: 57, lon: lon, at: T(at), bearing: 90, speedKmh: 120) }

struct ApproachingTests {
    @Test func isNotBoardingJustBecauseTheDepartureIsWithin30Minutes() {
        let v = Progress.liveView(stops: board(), line: ridden, gps: nil, now: T("10:05"))
        #expect(v.status == .approaching)
        #expect(v.eta == T("10:30"))
    }

    @Test func isBoardingOnceTheTrainHasArrivedOrIsAboutTo() {
        #expect(Progress.liveView(stops: board(), line: ridden, gps: nil, now: T("10:29")).status == .boarding)
        #expect(Progress.liveView(stops: board { $0.actualArr = T("10:28") }, line: ridden, gps: nil, now: T("10:29")).status == .boarding)
    }

    @Test func showsWhereTheTrainIsAndDoesNotCallItDepartedWhenALateEstimatePasses() {
        let v = Progress.liveView(stops: board { $0.estimatedDep = T("10:32") }, line: ridden, gps: fix(13.7, "10:32"), now: T("10:32"))
        #expect(v.status == .approaching)
        #expect(v.positionSource == .gps)
        #expect(abs((v.lon ?? 0) - 13.7) < 0.001)
        #expect(v.progress == 0)
        #expect(v.nextStopId == "B")
    }

    @Test func isBoardingAtTheStopAndEnRouteOnceItHasLeft() {
        #expect(Progress.liveView(stops: board(), line: ridden, gps: fix(14.1, "10:29"), now: T("10:29")).status == .boarding)
        #expect(Progress.liveView(stops: board { $0.actualDep = T("10:31") }, line: ridden, gps: fix(14.12, "10:34"), now: T("10:34")).status == .enRoute)
    }

    @Test func aTrainThatStartsAtYourStopBoards30MinutesBefore() {
        let origin = [
            LiveStop(stationId: "B", lat: 57, lon: 14.1, schedArr: nil, schedDep: T("10:12"), actualArr: nil, actualDep: nil, canceled: false),
            LiveStop(stationId: "C", lat: 57, lon: 14.2, schedArr: T("10:22"), schedDep: nil, actualArr: nil, actualDep: nil, canceled: false),
        ]
        #expect(Progress.liveView(stops: origin, line: ridden, gps: nil, now: T("09:40")).status == .scheduled)
        #expect(Progress.liveView(stops: origin, line: ridden, gps: nil, now: T("09:45")).status == .boarding)
    }
}

private func leg(depDelay: Int?, live: String? = nil) throws -> Leg {
    let json = """
    {"id":"L","status":"planned","dataQuality":"full","trainNumber":"547","category":"intercity","serviceDate":"2026-10-20",
    "schedDep":\(T("10:12")),"schedArr":\(T("10:22")),"actualDep":null,"actualArr":null,"depDelayMin":\(depDelay.map(String.init) ?? "null"),"arrDelayMin":null,
    "depPlatform":null,"arrPlatform":null,"canceled":false,"distanceM":1000,"isEstimatedGeometry":false,"trainType":null,"trainTypeSource":null,
    "onboard":null,"countryCodes":["SE"],"journeyId":null,"timetableTripKey":null,"operatorId":"sj","originStationId":"B","destStationId":"C",
    "notes":null,"ride":"auto","rideReason":null,"borderEvidence":null,"operator":null,"origin":null,"destination":null,"live":\(live ?? "null")}
    """
    return try JSONDecoder().decode(Leg.self, from: Data(json.utf8))
}

private func liveRow(_ status: String, at: Double) -> LiveStateRow {
    let json = """
    {"legId":"L","updatedAt":\(at),"status":"\(status)","lat":null,"lon":null,"bearing":null,"speedKmh":null,"positionSource":null,"positionAt":null,
    "progress":0,"prevStopId":null,"nextStopId":"B","eta":null,"arrivalEta":null,"arrivalDelayMin":null,"reportedAt":\(at)}
    """
    return try! JSONDecoder().decode(LiveStateRow.self, from: Data(json.utf8))
}

struct TripStatusTests {
    @Test func aDelayedLegIsNotBoardingByTheTimetableAlone() throws {
        // Leaves 10:12 + 20 min delay = 10:32. At 10:00 that is 32 minutes away: upcoming, not boarding.
        let l = try leg(depDelay: 20)
        #expect(LiveRules.statusKey(l, live: nil, now: T("10:00")) == .planned)
        #expect(LiveRules.statusKey(l, live: nil, now: T("10:05")) == .boarding)
    }

    @Test func theLiveStateDecidesWhileItIsFresh() throws {
        let l = try leg(depDelay: nil)
        let now = T("10:00")
        #expect(LiveRules.statusKey(l, live: liveRow("approaching", at: now - 10_000), now: now) == .approaching)
        // The timetable would say boarding (leaves in 12 min), but the server says it hasn't got there.
        #expect(LiveRules.statusKey(l, live: liveRow("scheduled", at: now - 10_000), now: now) == .planned)
        #expect(LiveRules.statusKey(l, live: liveRow("boarding", at: now - 10_000), now: now) == .boarding)
    }

    @Test func anApproachingTrainCountsAsLive() {
        #expect(LiveRules.isLive(liveRow("approaching", at: 1)))
    }
}

struct ExploreRailTests {
    private func stop(_ seq: Int, passed: Bool, dep: Double?, arr: Double? = nil, actualArr: Double? = nil, actualDep: Double? = nil) -> LiveTrainStop {
        let json = """
        {"seq":\(seq),"stationId":"S\(seq)","name":"S\(seq)","arr":\(arr.map { String($0) } ?? "null"),"dep":\(dep.map { String($0) } ?? "null"),
        "actualArr":\(actualArr.map { String($0) } ?? "null"),"actualDep":\(actualDep.map { String($0) } ?? "null"),"estimatedArr":null,"estimatedDep":null,
        "platform":null,"canceled":false,"passed":\(passed)}
        """
        return try! JSONDecoder().decode(LiveTrainStop.self, from: Data(json.utf8))
    }

    @Test func placesTheTrainBetweenTheStopItLeftAndTheOneItIsHeadingFor() {
        let stops = [
            stop(1, passed: true, dep: T("10:00")),
            stop(2, passed: true, dep: T("10:12"), arr: T("10:10")),
            stop(3, passed: false, dep: T("10:40"), arr: T("10:30")),
            stop(4, passed: false, dep: nil, arr: T("11:00")),
        ]
        let fills = ExploreLogic.railFills(stops, now: T("10:21"))
        #expect(fills[0] == 1)
        #expect(abs(fills[1] - 0.5) < 0.01)
        #expect(fills[2] == 0)
    }

    @Test func aTrainStandingAtAStopHasTheStretchIntoItCovered() {
        let stops = [stop(1, passed: true, dep: T("10:00")), stop(2, passed: false, dep: T("10:12"), arr: T("10:10"), actualArr: T("10:11"))]
        #expect(ExploreLogic.railFills(stops, now: T("10:11")) == [1])
    }
}
