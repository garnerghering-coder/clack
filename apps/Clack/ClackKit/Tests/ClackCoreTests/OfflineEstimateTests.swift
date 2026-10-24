//
//  OfflineEstimateTests.swift
//  ClackTests
//
//  Working offline (owner, 2026-10-24): estimates from the timetable and the last delays, trips kept on the phone.
//

import Foundation
import Testing
@testable import ClackCore

private let day = (Instant.parse("2026-10-20T00:00:00Z")?.timeIntervalSince1970 ?? 0) * 1000
private func T(_ hhmm: String) -> Double {
    let p = hhmm.split(separator: ":").compactMap { Double($0) }
    return day + (p[0] - 2) * 3_600_000 + p[1] * 60_000
}

private func leg(dep: String = "10:00", arr: String = "11:00", live: String? = nil, depDelay: Int? = nil) throws -> Leg {
    let json = """
    {"id":"L","status":"planned","dataQuality":"full","trainNumber":"547","category":"intercity","serviceDate":"2026-10-20",
    "schedDep":\(T(dep)),"schedArr":\(T(arr)),"actualDep":null,"actualArr":null,"depDelayMin":\(depDelay.map(String.init) ?? "null"),"arrDelayMin":null,
    "depPlatform":null,"arrPlatform":null,"canceled":false,"distanceM":1000,"isEstimatedGeometry":false,"trainType":null,"trainTypeSource":null,
    "onboard":null,"countryCodes":["SE"],"journeyId":null,"timetableTripKey":null,"operatorId":"sj","originStationId":"A","destStationId":"B",
    "notes":null,"ride":"auto","rideReason":null,"borderEvidence":null,"operator":null,"origin":null,"destination":null,"live":\(live ?? "null")}
    """
    return try JSONDecoder().decode(Leg.self, from: Data(json.utf8))
}

private func liveJSON(status: String, updatedAt: Double) -> String {
    """
    {"legId":"L","updatedAt":\(updatedAt),"status":"\(status)","lat":null,"lon":null,"bearing":null,"speedKmh":null,"positionSource":null,"positionAt":null,
    "progress":0.2,"prevStopId":null,"nextStopId":null,"eta":null,"arrivalEta":null,"arrivalDelayMin":null,"reportedAt":\(updatedAt)}
    """
}

struct OfflineEstimateTests {
    @Test func aTripThatNeverWentLiveIsStillEstimatedWhenOffline() throws {
        let l = try leg()
        // Halfway: running, half way along by the clock, though the server never reported it.
        let e = try #require(OfflineEstimate.live(for: l, detail: nil, offline: true, now: T("10:30")))
        #expect(e.status == .enRoute)
        #expect(e.localEstimate)
        #expect(abs((e.progress ?? 0) - 0.5) < 0.01)
        #expect(e.lat == nil)
    }

    @Test func offlineItSaysBoardingInTheLastHalfHourAndArrivedAfter() throws {
        let l = try leg()
        #expect(OfflineEstimate.live(for: l, detail: nil, offline: true, now: T("09:26"))?.status == .scheduled)
        #expect(OfflineEstimate.live(for: l, detail: nil, offline: true, now: T("09:31"))?.status == .boarding)
        #expect(OfflineEstimate.live(for: l, detail: nil, offline: true, now: T("11:05"))?.status == .arrived)
    }

    @Test func aKnownDelayMovesTheEstimate() throws {
        let l = try leg(depDelay: 20)
        // The timetable says 10:00, but it is 20 min late: at 10:10 it has not left.
        let e = try #require(OfflineEstimate.live(for: l, detail: nil, offline: true, now: T("10:10")))
        #expect(e.status == .boarding)
    }

    @Test func nothingIsEstimatedWhenTheServerIsGivingFreshUpdates() throws {
        let now = T("10:30")
        let l = try leg(live: liveJSON(status: "en_route", updatedAt: now - 20_000))
        #expect(OfflineEstimate.live(for: l, detail: nil, offline: false, now: now) == nil)
        #expect(OfflineEstimate.live(for: l, detail: nil, offline: true, now: now) == nil)
    }

    @Test func updatesThatStoppedAreCoveredEvenOnline() throws {
        let now = T("10:30")
        let l = try leg(live: liveJSON(status: "en_route", updatedAt: now - 5 * 60_000))
        #expect(OfflineEstimate.live(for: l, detail: nil, offline: false, now: now)?.localEstimate == true)
    }

    @Test func onlineATripThatWasNeverTrackedIsLeftToTheTimetable() throws {
        #expect(OfflineEstimate.live(for: try leg(), detail: nil, offline: false, now: T("10:30")) == nil)
    }

    @Test func farFromTheTripThereIsNothingToSay() throws {
        let l = try leg()
        #expect(OfflineEstimate.live(for: l, detail: nil, offline: true, now: T("06:00")) == nil)
        #expect(OfflineEstimate.live(for: l, detail: nil, offline: true, now: T("12:00")) == nil)
    }
}

struct OfflineCacheKeepingTests {
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("clack-keep-\(UUID().uuidString)", isDirectory: true) }

    @Test func pinnedTripsSurviveWhenOldOnesAreDropped() async {
        let cache = OfflineCache(directory: directory())
        await cache.store("/legs/keep", Data("a".utf8))
        await cache.setPinned(["/legs/keep"])
        for i in 0..<(OfflineCache.maxEntries + 5) { await cache.store("/legs/other-\(i)", Data("b".utf8)) }
        #expect(await cache.read("/legs/keep") != nil)
        #expect(await cache.read("/legs/other-0") == nil)
    }

    @Test func thePassportIsKeptPerChoice() async {
        let cache = OfflineCache(directory: directory())
        let all = APIClient.cacheKey("/passport", ["year": "all", "commuter": "true", "comparison": "car_1"])
        let year = APIClient.cacheKey("/passport", ["year": "2026", "commuter": "true", "comparison": "car_1"])
        #expect(all != year)
        #expect(all == APIClient.cacheKey("/passport", ["comparison": "car_1", "commuter": "true", "year": "all"]))
        await cache.store(all, Data("x".utf8))
        #expect(await cache.read(all) != nil)
        #expect(await cache.read(year) == nil)
        #expect(APIClient.cacheKey("/legs", [:]) == "/legs")
    }
}
