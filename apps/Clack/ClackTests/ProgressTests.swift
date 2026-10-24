//
//  ProgressTests.swift
//  ClackTests
//
//  Ported from apps/server/test/liveProgress.test.ts (live view) and apps/server/test/sanitize.test.ts (dead
//  reckoning): same inputs, same expected outputs. The web tests write times as +02:00; here the same instants are
//  in UTC.
//

import Foundation
import Testing
@testable import Clack
@testable import ClackCore

private func T(_ hhmm: String) -> Double {
    let parts = hhmm.split(separator: ":").compactMap { Double($0) }
    let base = (Instant.parse("2026-10-20T00:00:00Z")?.timeIntervalSince1970 ?? 0) * 1000
    // 10:00 at +02:00 is 08:00 UTC.
    return base + (parts[0] - 2) * 3_600_000 + parts[1] * 60_000
}

private func stop(
    _ id: String, _ lon: Double, _ arr: String?, _ dep: String?,
    actualDep: Double? = nil, actualArr: Double? = nil, canceled: Bool = false
) -> LiveStop {
    LiveStop(
        stationId: id, lat: 57, lon: lon, schedArr: arr.map(T), schedDep: dep.map(T), actualArr: actualArr,
        actualDep: actualDep, canceled: canceled
    )
}

/// A to B to C along the 57th parallel, 0.1° (about 6 km) apart.
private let line = [LatLon(57, 14.0), LatLon(57, 14.1), LatLon(57, 14.2)]
private func stops() -> [LiveStop] {
    [stop("A", 14.0, nil, "10:00"), stop("B", 14.1, "10:10", "10:12"), stop("C", 14.2, "10:22", nil)]
}

struct LiveViewTests {
    @Test func isScheduledThenBoardingThirtyMinutesBeforeDeparture() {
        #expect(Progress.liveView(stops: stops(), line: line, gps: nil, now: T("09:00")).status == .scheduled)
        #expect(Progress.liveView(stops: stops(), line: line, gps: nil, now: T("09:45")).status == .boarding)
    }

    @Test func estimatesThePositionHalfwayBetweenStopsAtTheHalfwayTime() {
        var s = stops()
        s[0].actualDep = T("10:00")
        let v = Progress.liveView(stops: s, line: line, gps: nil, now: T("10:05"))
        #expect(v.status == .enRoute)
        #expect(v.positionSource == .estimated)
        #expect(abs((v.lon ?? 0) - 14.05) < 0.005)
        #expect(v.nextStopId == "B")
        #expect(v.eta == T("10:10"))
        #expect(abs((v.progress ?? 0) - 0.25) < 0.005)
    }

    @Test func waitsAtAStopDuringTheDwellAndNamesTheNextOne() {
        var s = stops()
        s[0].actualDep = T("10:00")
        s[1].actualArr = T("10:10")
        let v = Progress.liveView(stops: s, line: line, gps: nil, now: T("10:11"))
        #expect(v.status == .atStop)
        #expect(v.prevStopId == "B")
        #expect(v.nextStopId == "C")
        #expect(abs((v.lon ?? 0) - 14.1) < 0.0005)
    }

    @Test func prefersAFreshGpsFixAndIgnoresAStaleOne() {
        var s = stops()
        s[0].actualDep = T("10:00")
        let gps = GpsFix(lat: 57, lon: 14.03, at: T("10:04"), bearing: 90, speedKmh: 80)
        let fresh = Progress.liveView(stops: s, line: line, gps: gps, now: T("10:05"))
        #expect(fresh.positionSource == .gps)
        #expect(fresh.lon == 14.03)
        #expect(abs((fresh.progress ?? 0) - 0.15) < 0.005)
        #expect(Progress.liveView(stops: s, line: line, gps: gps, now: T("10:09")).positionSource == .estimated)
    }

    @Test func carriesAKnownDelayForwardAndReportsTheArrivalDelay() {
        var s = stops()
        s[0].actualDep = T("10:05")
        let times = Progress.expectedTimes(s)
        #expect(times[1].arr == T("10:15"))
        #expect(times[2].arr == T("10:27"))
        let v = Progress.liveView(stops: s, line: line, gps: nil, now: T("10:06"))
        #expect(v.arrivalDelayMin == 5)
        #expect(v.arrivalEta == T("10:27"))
    }

    @Test func isArrivedOnceTheArrivalIsKnownAndCancelledWhenTheRideIsCancelled() {
        var s = stops()
        s[2].actualArr = T("10:23")
        #expect(Progress.liveView(stops: s, line: line, gps: nil, now: T("10:24")).status == .arrived)
        var c = stops()
        c[2].canceled = true
        let v = Progress.liveView(stops: c, line: line, gps: nil, now: T("10:05"))
        #expect(v.status == .cancelled)
        #expect(v.progress == nil)
    }
}

struct DeadReckoningTests {
    private let straight = [LatLon(57, 14.0), LatLon(57, 14.2)]
    private var twoStops: [LiveStop] {
        [stop("A", 14.0, nil, "10:00", actualDep: T("10:00")), stop("B", 14.2, "10:20", nil)]
    }

    @Test func carriesTheTrainOnFromItsLastFixAtItsLastSpeedNeverPastTheNextStop() {
        // Last fix at 14.10 (about 6 km in) at 10:05, doing 120 km/h; 3 minutes later it's about 6 km further.
        let gps = GpsFix(lat: 57, lon: 14.1, at: T("10:05"), bearing: 90, speedKmh: 120)
        let v = Progress.liveView(stops: twoStops, line: straight, gps: gps, now: T("10:05") + 3 * 60_000)
        #expect(v.positionSource == .estimated)
        #expect((v.lon ?? 0) > 14.19)
        #expect(v.speedKmh == nil)
        let later = Progress.liveView(stops: twoStops, line: straight, gps: gps, now: T("10:05") + 4.5 * 60_000)
        #expect((later.lon ?? 99) <= 14.2)
    }

    @Test func neverPutsTheEstimateBehindWhereTheGpsLastSawIt() {
        // A slow timetable estimate would say 14.05 at 10:05; the train was last seen further on, with no speed.
        let gps = GpsFix(lat: 57, lon: 14.15, at: T("10:04"), bearing: 90, speedKmh: nil)
        #expect((Progress.liveView(stops: twoStops, line: straight, gps: gps, now: T("10:05")).lon ?? 0) > 14.14)
    }

    @Test func aSpeedIsOnlyShownFromAFreshFix() {
        let gps = GpsFix(lat: 57, lon: 14.1, at: T("10:05"), speedKmh: 90)
        #expect(Progress.shownSpeed(gps, now: T("10:05") + 59_000) == 90)
        #expect(Progress.shownSpeed(gps, now: T("10:05") + 61_000) == nil)
        #expect(Progress.shownSpeed(nil, now: 0) == nil)
        // A fix that came without a speed keeps the last reading, with its own time.
        let held = GpsFix(lat: 57, lon: 14.1, at: T("10:05") + 90_000, speedKmh: 90, speedAt: T("10:05"))
        #expect(Progress.shownSpeed(held, now: T("10:05") + 90_000) == nil)
    }
}

struct GeometryTests {
    @Test func cumulativeDistanceUsesAEarthRadiusOf6371008Metres() {
        // One degree of latitude is 111 195 m at R = 6 371 008.8.
        let cum = Progress.cumulative([LatLon(57, 14), LatLon(58, 14)])
        #expect(cum.count == 2)
        #expect(abs(cum[1] - 111_195) < 1)
    }

    @Test func locateFindsTheClosestPointAlongTheLineAndNeverGoesBackwards() {
        let cum = Progress.cumulative(line)
        let atB = Progress.locate(line, cum, lat: 57.001, lon: 14.1)
        #expect(abs(atB - cum[1]) < 150)
        #expect(Progress.locate(line, cum, lat: 57, lon: 14.0, from: cum[1]) >= cum[1])
    }

    @Test func pointAtGivesThePositionAndTheBearing() {
        let cum = Progress.cumulative(line)
        let p = Progress.pointAt(line, cum, cum[2] / 2)
        #expect(abs(p.lon - 14.1) < 0.0001)
        // Due east.
        #expect(abs(p.bearing - 90) < 0.1)
    }
}

struct LocalLiveTests {
    /// The first leg of the saved `/api/legs` response, with the detail fields added: two stops, A and B, 20 minutes
    /// apart along the 57th parallel.
    private func detail(geometry: String?) throws -> LegDetail {
        let url = try #require(Bundle(for: LocalToken.self).url(forResource: "legs", withExtension: "json"))
        let legs = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        let stopsJSON = """
        [{"seq":1,"role":"board","stationId":"A","name":"A","code":null,"country":"SE","tz":"Europe/Stockholm","lat":57,"lon":14.0,
          "schedArr":null,"schedDep":"2026-10-20T08:00:00.000Z","actualArr":null,"actualDep":"2026-10-20T08:00:00.000Z",
          "estimatedArr":null,"estimatedDep":null,"platform":null,"canceled":false,"deviations":[],"reportSource":"trafikverket"},
         {"seq":2,"role":"alight","stationId":"B","name":"B","code":null,"country":"SE","tz":"Europe/Stockholm","lat":57,"lon":14.2,
          "schedArr":"2026-10-20T08:20:00.000Z","schedDep":null,"actualArr":null,"actualDep":null,
          "estimatedArr":null,"estimatedDep":null,"platform":null,"canceled":false,"deviations":[],"reportSource":null}]
        """
        var object = legs[0]
        object["geometry"] = geometry ?? NSNull()
        object["stops"] = try JSONSerialization.jsonObject(with: Data(stopsJSON.utf8))
        object["events"] = [Any]()
        return try JSONDecoder().decode(LegDetail.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func live(status: LiveStatus = .enRoute, updatedAt: Double) -> LiveStateRow {
        LiveStateRow(
            legId: "a", updatedAt: Instant(ms: updatedAt), status: status, lat: 57, lon: 14.1, bearing: 90, speedKmh: nil,
            positionSource: .gps, positionAt: Instant(ms: updatedAt), progress: 0.5, prevStopId: "A", nextStopId: "B",
            eta: nil, arrivalEta: nil, arrivalDelayMin: nil, reportedAt: nil
        )
    }

    @Test func workOutsThePositionItselfAndMarksItAsALocalEstimate() throws {
        let leg = try detail(geometry: Polyline.encode([LatLon(57, 14.0), LatLon(57, 14.2)]))
        let last = live(updatedAt: T("10:05"))
        let now = T("10:12")
        let result = Progress.localLive(leg: leg, live: last, now: now)
        #expect(result.localEstimate)
        #expect(result.updatedAt == last.updatedAt)
        #expect(result.status == .enRoute)
        #expect(result.positionSource == .estimated)
        #expect((result.lon ?? 0) > 14.1)
    }

    @Test func fallsBackToTheStopsCoordinatesWhenThereIsNoRouteLine() throws {
        let leg = try detail(geometry: nil)
        let result = Progress.localLive(leg: leg, live: live(updatedAt: T("10:05")), now: T("10:10"))
        #expect(result.localEstimate)
        #expect(result.nextStopId == "B")
    }
}

private final class LocalToken {}
