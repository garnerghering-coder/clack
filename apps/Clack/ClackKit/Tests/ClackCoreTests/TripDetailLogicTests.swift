//
//  TripDetailLogicTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

private let now: Double = (Instant.parse("2026-10-20T08:20:00Z")?.timeIntervalSince1970 ?? 0) * 1000

struct TripDetailLogicTests {
    private func detail(live: String = "null", actualArr: String = "null", schedArr: Double? = nil) throws -> LegDetail {
        let url = try #require(Bundle.module.url(forResource: "legs", withExtension: "json", subdirectory: "Fixtures"))
        let legs = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        var object = legs[0]
        object["schedArr"] = schedArr ?? (now + 3_600_000)
        object["actualArr"] = try JSONSerialization.jsonObject(with: Data(actualArr.utf8), options: .fragmentsAllowed)
        object["live"] = try JSONSerialization.jsonObject(with: Data(live.utf8), options: .fragmentsAllowed)
        object["geometry"] = NSNull()
        object["events"] = [Any]()
        let stop = { (seq: Int, role: String, id: String, country: String, source: Any, lon: Double) -> [String: Any] in
            ["seq": seq, "role": role, "stationId": id, "name": id, "code": NSNull(), "country": country, "tz": "Europe/Stockholm",
             "lat": 57.0, "lon": lon, "schedArr": NSNull(), "schedDep": NSNull(), "actualArr": NSNull(), "actualDep": NSNull(),
             "estimatedArr": NSNull(), "estimatedDep": NSNull(), "platform": NSNull(), "canceled": false, "deviations": [String](),
             "reportSource": source]
        }
        object["stops"] = [
            stop(1, "before", "Z", "SE", "trafikverket", 13.9), stop(2, "board", "A", "SE", "trafikverket", 14.0),
            stop(3, "through", "M", "DK", NSNull(), 14.1), stop(4, "alight", "B", "DK", NSNull(), 14.2), stop(5, "after", "Y", "DK", NSNull(), 14.3),
        ]
        return try JSONDecoder().decode(LegDetail.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func liveRow(_ status: LiveStatus, updatedAgoMs: Double = 5_000, arrivalEta: Double? = nil) -> LiveStateRow {
        LiveStateRow(
            legId: "a", updatedAt: Instant(ms: now - updatedAgoMs), status: status, lat: 57, lon: 14.1, bearing: 90, speedKmh: nil,
            positionSource: .gps, positionAt: Instant(ms: now - updatedAgoMs), progress: 0.4, prevStopId: "A", nextStopId: "B",
            eta: nil, arrivalEta: arrivalEta.map { Instant(ms: $0) }, arrivalDelayMin: nil, reportedAt: nil
        )
    }

    @Test func beforeDuringAndAfter() throws {
        let leg = try detail()
        #expect(TripDetailLogic.stage(leg.leg, live: nil, shown: nil, now: now) == .before)
        let running = liveRow(.enRoute)
        #expect(TripDetailLogic.stage(leg.leg, live: running, shown: running, now: now) == .during)
        let waiting = liveRow(.atStop)
        #expect(TripDetailLogic.stage(leg.leg, live: waiting, shown: waiting, now: now) == .during)
        let arrived = liveRow(.arrived)
        #expect(TripDetailLogic.stage(leg.leg, live: arrived, shown: arrived, now: now) == .after)
    }

    @Test func afterOnceTheScheduledArrivalHasPassedUnlessALateTrainIsStillRunning() throws {
        let past = try detail(schedArr: now - 60_000)
        #expect(TripDetailLogic.stage(past.leg, live: nil, shown: nil, now: now) == .after)
        // Tracking with a later estimate: the arrival is the estimate, so it isn't over yet.
        let boarding = liveRow(.boarding, arrivalEta: now + 600_000)
        #expect(TripDetailLogic.stage(past.leg, live: boarding, shown: boarding, now: now) == .before)
        let arrivedLeg = try detail(actualArr: String(now - 1000))
        #expect(TripDetailLogic.stage(arrivedLeg.leg, live: nil, shown: nil, now: now) == .after)
    }

    @Test func thePhoneMovesTheTrainItselfAfterAMinuteWithoutAnUpdate() throws {
        let leg = try detail()
        let fresh = liveRow(.enRoute, updatedAgoMs: 30_000)
        #expect(TripDetailLogic.shown(leg, live: fresh, now: now)?.localEstimate == false)
        let stale = liveRow(.enRoute, updatedAgoMs: 61_000)
        #expect(TripDetailLogic.shown(leg, live: stale, now: now)?.localEstimate == true)
        // A leg that isn't tracked is left as it is, however old.
        let scheduled = liveRow(.scheduled, updatedAgoMs: 600_000)
        #expect(TripDetailLogic.shown(leg, live: scheduled, now: now)?.localEstimate == false)
        #expect(TripDetailLogic.shown(leg, live: nil, now: now) == nil)
    }

    @Test func stopsNobodyReportsLiveAreNamedByCountry() throws {
        let leg = try detail()
        #expect(TripDetailLogic.beyondCountries(leg.stops) == ["DK"])
    }

    @Test func theFullRouteAddsTheStopsBeforeAndAfter() throws {
        let leg = try detail()
        #expect(TripDetailLogic.visibleStops(leg.stops, fullRoute: false).map(\.stationId) == ["A", "M", "B"])
        #expect(TripDetailLogic.visibleStops(leg.stops, fullRoute: true).map(\.stationId) == ["Z", "A", "M", "B", "Y"])
    }

    @Test func theDelayTileExplainsLateEarlyOnTimeAndUnknown() {
        #expect(TripDetailLogic.explanation(arrDelayMin: nil) == .unknown)
        #expect(TripDetailLogic.explanation(arrDelayMin: 7) == .late(7))
        #expect(TripDetailLogic.explanation(arrDelayMin: -2) == .early(2))
        #expect(TripDetailLogic.explanation(arrDelayMin: 0) == .onTime)
    }

    @Test func aBoardStopReadsItsDepartureAndOthersTheirArrival() throws {
        let leg = try detail()
        let board = leg.stops[1]
        #expect(TripDetailLogic.stopTimes(board).sched == nil)
        let times = TripDetailLogic.StopTimes(sched: 600_000, real: nil, estimate: 780_000)
        #expect(times.actual == 780_000)
        #expect(times.delay == 3)
        let real = TripDetailLogic.StopTimes(sched: 600_000, real: 600_000, estimate: 780_000)
        #expect(real.actual == 600_000)
        #expect(real.delay == 0)
    }
}
