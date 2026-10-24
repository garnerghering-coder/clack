//
//  RefreshScheduleTests.swift
//  ClackTests
//
//  When the app asks to be woken in the background (45 minutes before the next departure, else the next morning), and
//  the widgets' push address in `PUT /api/devices`.
//

import Foundation
import Testing
@testable import ClackCore

private let stockholm = TimeZone(identifier: "Europe/Stockholm")!
/// 2026-10-21 12:00 in Stockholm (CEST, UTC+2).
private let now: Double = (Instant.parse("2026-10-21T10:00:00Z")?.timeIntervalSince1970 ?? 0) * 1000
private let minute: Double = 60_000

private func iso(_ s: String) -> Double { (Instant.parse(s)?.timeIntervalSince1970 ?? 0) * 1000 }

/// A leg leaving `dep` minutes from `now`.
private func leg(_ id: String, dep: Double, canceled: Bool = false, departed: Bool = false, depDelay: Int? = nil) throws -> Leg {
    let schedDep = now + dep * minute
    let json = """
    {"id":"\(id)","status":"planned","dataQuality":"full","trainNumber":"7205","category":"regional","serviceDate":"2026-10-21",
    "schedDep":\(schedDep),"schedArr":\(schedDep + 60 * minute),"actualDep":\(departed ? String(schedDep) : "null"),"actualArr":null,
    "depDelayMin":\(depDelay.map(String.init) ?? "null"),"arrDelayMin":null,
    "depPlatform":"1","arrPlatform":"2","canceled":\(canceled),"distanceM":1000,"isEstimatedGeometry":false,
    "trainType":null,"trainTypeSource":null,"onboard":null,"countryCodes":["SE"],
    "journeyId":null,"timetableTripKey":null,"operatorId":"sj",
    "originStationId":"A","destStationId":"B","notes":null,"ride":"auto","rideReason":null,"borderEvidence":null,
    "operator":null,
    "origin":{"id":"A","name":"A C","code":null,"country":"SE","tz":"Europe/Stockholm"},
    "destination":{"id":"B","name":"B C","code":null,"country":"SE","tz":"Europe/Stockholm"},
    "live":null}
    """
    return try JSONDecoder().decode(Leg.self, from: Data(json.utf8))
}

@Suite("Background refresh: when")
struct RefreshScheduleTests {
    private let tomorrowSix = iso("2026-10-22T04:00:00Z")

    @Test func nothingAheadMeansTomorrowMorning() {
        #expect(RefreshSchedule.next([], now: now, timeZone: stockholm) == tomorrowSix)
    }

    @Test func fortyFiveMinutesBeforeTheNextDeparture() throws {
        let legs = try [leg("late", dep: 300), leg("soon", dep: 120)]
        #expect(RefreshSchedule.next(legs, now: now, timeZone: stockholm) == now + 75 * minute)
    }

    @Test func theDelayMovesIt() throws {
        // Leaves at +120 scheduled, 20 min late: wake at +95.
        #expect(try RefreshSchedule.next([leg("a", dep: 120, depDelay: 20)], now: now, timeZone: stockholm) == now + 95 * minute)
    }

    @Test func soonDepartureIsClampedToTheMinimumGap() throws {
        // Leaving in 30 min: not in the past, but 15 min from now.
        #expect(try RefreshSchedule.next([leg("a", dep: 30)], now: now, timeZone: stockholm) == now + 15 * minute)
        // Leaving in 10 min: too late to help, so the morning (or the next train).
        #expect(try RefreshSchedule.next([leg("a", dep: 10)], now: now, timeZone: stockholm) == tomorrowSix)
        #expect(try RefreshSchedule.next([leg("a", dep: 10), leg("b", dep: 200)], now: now, timeZone: stockholm) == now + 155 * minute)
    }

    @Test func cancelledDepartedAndPastLegsDontCount() throws {
        let legs = try [leg("c", dep: 120, canceled: true), leg("d", dep: 120, departed: true), leg("p", dep: -60)]
        #expect(RefreshSchedule.next(legs, now: now, timeZone: stockholm) == tomorrowSix)
    }

    @Test func theMorningWinsOverALaterDeparture() throws {
        // A train two days away: tomorrow's 06:00 comes first.
        #expect(try RefreshSchedule.next([leg("far", dep: 48 * 60)], now: now, timeZone: stockholm) == tomorrowSix)
    }

    @Test func morningIsInThePhonesTimeZone() {
        // 05:00 in Stockholm: this morning's six.
        let early = iso("2026-10-21T03:00:00Z")
        #expect(RefreshSchedule.nextMorning(after: early, timeZone: stockholm) == iso("2026-10-21T04:00:00Z"))
        // Exactly six: the next one.
        #expect(RefreshSchedule.nextMorning(after: iso("2026-10-21T04:00:00Z"), timeZone: stockholm) == tomorrowSix)
        // The clocks go back on 2026-10-25: six that morning is 05:00 UTC.
        #expect(RefreshSchedule.nextMorning(after: iso("2026-10-24T20:00:00Z"), timeZone: stockholm) == iso("2026-10-25T05:00:00Z"))
        let utc = TimeZone(identifier: "UTC")!
        #expect(RefreshSchedule.nextMorning(after: now, timeZone: utc) == iso("2026-10-22T06:00:00Z"))
    }
}

@Suite("Widget push address")
struct WidgetPushTests {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func defaults() -> UserDefaults {
        let name = "clack.test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func widgetTokenLeftOutUnlessKnown() throws {
        let keep = try json(DeviceRegistration(token: "ab", environment: "sandbox", startToken: .set("cd"), widgetToken: TokenUpdate(nil)))
        #expect(Set(keep.keys) == ["token", "environment", "startToken"])
        let set = try json(DeviceRegistration(token: "ab", environment: "sandbox", widgetToken: TokenUpdate("ef")))
        #expect(set["widgetToken"] as? String == "ef")
        #expect(!set.keys.contains("startToken"))
        let clear = try json(DeviceRegistration(token: "ab", environment: "sandbox", widgetToken: .clear))
        #expect(clear["widgetToken"] is NSNull)
    }

    @Test func extensionSendsOnlyForARegisteredPhone() throws {
        let d = defaults()
        #expect(WidgetPush.registration(widgetToken: "ef", defaults: d) == nil)
        WidgetPush.setToken("ef", defaults: d)
        #expect(WidgetPush.token(d) == "ef")
        WidgetPush.setRegistered(token: "ab", environment: "production", defaults: d)
        let body = try #require(WidgetPush.registration(widgetToken: "ef", defaults: d))
        #expect(body == DeviceRegistration(token: "ab", environment: "production", widgetToken: .set("ef")))
        let sent = try json(body)
        #expect(Set(sent.keys) == ["token", "environment", "widgetToken"])
        WidgetPush.clearRegistered(d)
        #expect(WidgetPush.registration(widgetToken: "ef", defaults: d) == nil)
    }
}
