//
//  HoursTests.swift
//  ClackTests
//
//  Ported from packages/shared/src/hours.test.ts. The web test writes Stockholm wall-clock with an offset; Swift's
//  ISO parser here takes UTC, so each time is converted (October 2026 is CEST, +02:00; late October and later CET, +01:00).
//

import Foundation
import Testing
@testable import Clack

private func at(_ utc: String) -> Double {
    (Instant.parse(utc)?.timeIntervalSince1970 ?? 0) * 1000
}

struct HoursTests {
    @Test func readsCommonStationShopSyntaxAndRefusesWhatItCannotEvaluate() throws {
        #expect(OpeningHours.parse("24/7") == Hours(rules: [], always: true))
        #expect(OpeningHours.parse("Mo-Fr 06:00-22:00; Sa,Su 08:00-20:00")?.rules.count == 2)
        #expect(OpeningHours.parse("Mo-Fr 06:00-22:00 \"except in summer\"") == nil)
        // ", " before a weekday starts a new rule; between times it doesn't.
        let h = try #require(OpeningHours.parse("Su-Th 09:00-03:00, Fr,Sa 09:00-05:00"))
        #expect(h.rules.count == 2)
        // Saturday 04:30 (02:30 UTC), from Friday night.
        #expect(OpeningHours.isOpen(h, at: at("2026-10-24T02:30:00Z")))
        #expect(OpeningHours.parse("Mo-Fr 06:00-10:00, 12:00-14:00")?.rules.count == 1)
        #expect(OpeningHours.parse("sunrise-sunset") == nil)
        #expect(OpeningHours.parse("") == nil)
        #expect(OpeningHours.parse(nil) == nil)
    }

    @Test func showsTheKioskClosedAt2330OnASunday() {
        // Sunday 2026-10-25, 23:30 CET (22:30 UTC).
        #expect(OpeningHours.openState("Mo-Su 06:00-22:00", from: at("2026-10-25T22:30:00Z")).state == .closed)
        #expect(OpeningHours.openState("Mo-Su 06:00-22:00", from: at("2026-10-25T11:00:00Z")).state == .open)
    }

    @Test func handlesSpansPastMidnight() throws {
        let h = try #require(OpeningHours.parse("Mo-Su 18:00-02:00"))
        #expect(OpeningHours.isOpen(h, at: at("2026-10-21T21:00:00Z")))
        #expect(OpeningHours.isOpen(h, at: at("2026-10-21T23:30:00Z")))
        #expect(!OpeningHours.isOpen(h, at: at("2026-10-22T00:30:00Z")))
    }

    @Test func knowsSwedishPublicHolidaysPHRulesAndDaysMarkedOff() {
        let y = OpeningHours.swedishHolidays(2026)
        for d in ["2026-01-01", "2026-04-03", "2026-04-05", "2026-04-06", "2026-05-14", "2026-06-06", "2026-06-19",
                  "2026-06-20", "2026-10-31", "2026-12-24", "2026-12-25"] {
            #expect(y.contains(d), "\(d)")
        }
        #expect(!y.contains("2026-10-21"))
        // Christmas Day 2026 is a Friday: the PH rule wins over Mo-Fr (12:00 CET = 11:00 UTC).
        #expect(OpeningHours.openState("Mo-Fr 06:00-22:00; PH off", from: at("2026-12-25T11:00:00Z")).state == .closed)
        #expect(OpeningHours.openState("Mo-Fr 06:00-22:00; PH 10:00-16:00", from: at("2026-12-25T11:00:00Z")).state == .open)
        #expect(OpeningHours.openState("Mo-Fr 06:00-22:00; Su off", from: at("2026-10-25T11:00:00Z")).state == .closed)
    }

    @Test func saysWhenSomethingClosesSoonAndOverALayoverWindow() {
        // 21:45 CEST = 19:45 UTC; it closes at 22:00 CEST = 20:00 UTC.
        let s = OpeningHours.openState("Mo-Su 06:00-22:00", from: at("2026-10-21T19:45:00Z"))
        #expect(s.state == .closingSoon)
        #expect(s.closesAt == at("2026-10-21T20:00:00Z"))
        // Layover 21:30 to 22:15: open at first, closes during it.
        let w = OpeningHours.openState("Mo-Su 06:00-22:00", from: at("2026-10-21T19:30:00Z"), to: at("2026-10-21T20:15:00Z"))
        #expect(w.state == .closingSoon)
        #expect(w.closesAt == at("2026-10-21T20:00:00Z"))
        #expect(OpeningHours.openState("Mo-Su 06:00-22:00", from: at("2026-10-21T20:30:00Z"), to: at("2026-10-21T21:00:00Z")).state == .closed)
        #expect(OpeningHours.openState(nil, from: at("2026-10-21T10:00:00Z")).state == .unknown)
    }

    @Test func midsummerEveFallsOnTheFridayBetween19And25June() {
        // 2026: Midsummer Day is Saturday 20 June, so the eve is Friday the 19th.
        #expect(OpeningHours.swedishHolidays(2026).isSuperset(of: ["2026-06-19", "2026-06-20"]))
        // 2025: Midsummer Day is Saturday 21 June.
        #expect(OpeningHours.swedishHolidays(2025).isSuperset(of: ["2025-06-20", "2025-06-21"]))
    }
}
