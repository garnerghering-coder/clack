//
//  LogicTests.swift
//  ClackTests
//
//  Ported from apps/web/src/format.test.ts, apps/web/src/landing.test.ts and packages/shared/src/delay.test.ts:
//  same inputs, same expected outputs.
//

import Foundation
import Testing
@testable import ClackCore

private func ms(_ iso: String) -> Double {
    (Instant.parse(iso)?.timeIntervalSince1970 ?? 0) * 1000
}

struct FormatTests {
    let t = ms("2026-10-20T17:04:00Z")

    @Test func showsTimesInTheStationTimeZone24hOr12h() {
        #expect(Format.time(t, tz: "Europe/Stockholm", clock: .h24) == "19:04")
        #expect(Format.time(t, tz: "Europe/Stockholm", clock: .h12) == "7:04 pm")
        #expect(Format.time(nil, tz: "Europe/Stockholm", clock: .h24) == "--:--")
    }

    @Test func twelveHourClockAroundMidnightAndNoon() {
        #expect(Format.time(ms("2026-10-20T22:05:00Z"), tz: "Europe/Stockholm", clock: .h12) == "12:05 am")
        #expect(Format.time(ms("2026-10-20T10:30:00Z"), tz: "Europe/Stockholm", clock: .h12) == "12:30 pm")
        #expect(Format.time(ms("2026-10-20T22:05:00Z"), tz: "Europe/Stockholm", clock: .h24) == "00:05")
    }

    @Test func timeFollowsTheZoneNotThePhone() {
        #expect(Format.time(t, tz: "Europe/Oslo", clock: .h24) == "19:04")
        #expect(Format.time(t, tz: "UTC", clock: .h24) == "17:04")
    }

    @Test func formatsDays() {
        #expect(Format.day(t, tz: "Europe/Stockholm", now: t) == "Tue 20 Oct")
        #expect(Format.day(t, tz: "Europe/Stockholm", now: ms("2027-03-01T00:00:00Z")) == "Tue 20 Oct 2026")
    }

    @Test func formatsDurationsDistancesAndDelays() {
        #expect(Format.duration(168) == "2h 48m")
        #expect(Format.duration(45) == "45m")
        #expect(Format.duration(25 * 60 + 5) == "1d 1h")
        #expect(Format.distance(455_300, unit: .km) == "455 km")
        #expect(Format.distance(455_300, unit: .mi) == "283 mi")
        #expect(Format.distance(nil, unit: .km) == "—")
        #expect(Format.delay(39) == "+39")
        #expect(Format.delay(-2) == "−2")
        #expect(Format.delay(0) == "0")
        #expect(Format.delay(nil) == "—")
    }

    @Test func detectsArrivalsOnTheNextDay() {
        #expect(Format.dayOffset(from: ms("2026-10-20T20:00:00Z"), fromTz: "Europe/Stockholm", to: ms("2026-10-20T23:30:00Z"), toTz: "Europe/Stockholm") == 1)
        #expect(Format.dayOffset(from: t, fromTz: "Europe/Stockholm", to: t + 3_600_000, toTz: "Europe/Stockholm") == 0)
    }

    @Test func namesATrainAndJoinsFactsOnALine() {
        #expect(Format.service("SJ", "529") == "SJ 529")
        #expect(Format.service(nil, "529") == "529")
        #expect(Format.service("Vy", nil) == "Vy")
        #expect(Format.service(nil, nil) == "")
        #expect(Format.join(["SJ 529", nil, "", "Platform 4"]) == "SJ 529 · Platform 4")
        #expect(Format.join([]) == "")
        #expect(Format.unknown == "—")
    }

    @Test func localDatesAndDateArithmetic() {
        #expect(Format.localDate(ms("2026-10-20T23:30:00Z"), tz: "Europe/Stockholm") == "2026-10-21")
        #expect(Format.addDaysIso("2026-10-31", days: 1) == "2026-11-01")
        #expect(Format.addDaysIso("2026-03-01", days: -1) == "2026-02-28")
    }
}

struct DelayTests {
    @Test func computesWholeMinutesEarlyAsNegative() {
        func t(_ hhmm: String) -> Double { ms("2026-10-20T\(hhmm):00Z") }
        // The web test uses +02:00; the same instants in UTC are two hours earlier.
        #expect(Delay.minutes(advertised: t("16:25"), actual: t("17:04")) == 39)
        #expect(Delay.minutes(advertised: t("17:20"), actual: t("17:20")) == 0)
        #expect(Delay.minutes(advertised: t("08:23"), actual: t("08:20")) == -3)
        #expect(Delay.minutes(advertised: t("21:58"), actual: ms("2026-10-20T22:03:00Z")) == 5)
        #expect(Delay.minutes(advertised: nil, actual: t("08:00")) == nil)
    }

    @Test func bandsMatchTheDesign() {
        #expect(DelayBand(delayMin: -2) == .onTime)
        #expect(DelayBand(delayMin: 0) == .onTime)
        #expect(DelayBand(delayMin: 1) == .slight)
        #expect(DelayBand(delayMin: 15) == .slight)
        #expect(DelayBand(delayMin: 16) == .late)
        #expect(DelayBand(delayMin: 30) == .late)
        #expect(DelayBand(delayMin: 31) == .veryLate)
        #expect(DelayBand(delayMin: 5, canceled: true) == .cancelled)
        #expect(DelayBand(delayMin: nil) == .unknown)
    }

    @Test func onTimeMeansAtMostFiveMinutesLate() {
        #expect(Delay.isOnTime(5))
        #expect(!Delay.isOnTime(6))
        #expect(!Delay.isOnTime(nil))
    }
}

struct LandingTests {
    let now = ms("2026-10-21T12:00:00Z")

    private func at(_ min: Double) -> Double { now + min * 60_000 }

    private func leg(
        _ depMin: Double, _ arrMin: Double, actualArr: Double? = nil, depDelayMin: Int? = nil, canceled: Bool = false,
        status: LiveStatus? = nil, arrivalEta: Double? = nil
    ) -> Landing.LegTimes {
        Landing.LegTimes(
            schedDep: at(depMin), schedArr: at(arrMin), actualArr: actualArr, depDelayMin: depDelayMin,
            canceled: canceled, liveStatus: status, liveArrivalEta: arrivalEta
        )
    }

    @Test func opensOnTripsWhileATrainIsRunning() {
        #expect(Landing.resolve(legs: [leg(-30, 30)], now: now, lastTab: .passport) == .trips)
    }

    @Test func opensOnTripsForADepartureInsideTheWindowNotOneFurtherOut() {
        #expect(Landing.resolve(legs: [leg(90, 200)], now: now, lastTab: .explore) == .trips)
        #expect(Landing.resolve(legs: [leg(5 * 60, 6 * 60)], now: now, lastTab: .passport) == .passport)
        #expect(Landing.resolve(legs: [leg(5 * 60, 6 * 60)], now: now, lastTab: nil, windowMs: 6 * 3_600_000) == .trips)
    }

    @Test func restoresTheLastTabAndANewUserStartsOnExplore() {
        #expect(Landing.resolve(legs: [], now: now, lastTab: .passport) == .passport)
        #expect(Landing.resolve(legs: [], now: now, lastTab: nil) == .explore)
        #expect(Landing.resolve(legs: [leg(-600, -500)], now: now, lastTab: nil) == .explore)
    }

    @Test func keepsALateTrainActivePastItsTimetabledArrivalAndStopsOnceItHasArrived() {
        #expect(Landing.isActive(leg(-60, -5, status: .enRoute), now: now))
        #expect(Landing.isActive(leg(-60, -5, status: .scheduled, arrivalEta: at(15)), now: now))
        #expect(!Landing.isActive(leg(-60, -5, actualArr: at(-3)), now: now))
        #expect(!Landing.isActive(leg(-60, -30), now: now))
    }

    @Test func handlesDelaysCancellationsAndMissingTimes() {
        // Timetabled 10 min ago, 20 min late: still ahead.
        #expect(Landing.isImminent(leg(-10, 60, depDelayMin: 20), now: now))
        #expect(!Landing.isActive(leg(-10, 60, canceled: true), now: now))
        #expect(Landing.isImminent(leg(30, 90, canceled: true), now: now))
        #expect(!Landing.isImminent(Landing.LegTimes(), now: now))
    }

    @Test func worksForAnOvernightTrain() {
        // 23:15 to 00:30: imminent at 22:30, active at 00:10 the next day.
        let overnight = leg(11 * 60 + 15, 12 * 60 + 30)
        #expect(Landing.resolve(legs: [overnight], now: ms("2026-10-21T22:30:00Z"), lastTab: .explore) == .trips)
        #expect(Landing.isActive(overnight, now: ms("2026-10-22T00:10:00Z")))
        #expect(!Landing.isActive(overnight, now: ms("2026-10-22T01:00:00Z")))
    }

    @Test func remembersTheLastTab() throws {
        let defaults = try #require(UserDefaults(suiteName: "clack.tests.landing"))
        defaults.removePersistentDomain(forName: "clack.tests.landing")
        #expect(Landing.readLastTab(defaults) == nil)
        Landing.saveLastTab(.passport, defaults)
        #expect(Landing.readLastTab(defaults) == .passport)
        defaults.set("nonsense", forKey: "clack.lastTab")
        #expect(Landing.readLastTab(defaults) == nil)
    }
}

struct JourneyReachedTests {
    private let dep = 1_000_000_000.0
    private let arr = 1_000_000_000.0 + 3_600_000
    private func r(_ now: Double, actualDep: Double? = nil, actualArr: Double? = nil, _ status: LiveStatus? = nil, prev: Bool = false) -> (departed: Bool, arrived: Bool) {
        TripsLogic.reached(actualDep: actualDep, actualArr: actualArr, expDep: dep, expArr: arr, liveStatus: status, hasPrevStop: prev, now: now)
    }

    @Test func aTrackedTrainIsNotReachedOnTheClock() {
        let late = r(arr + 3_600_000, .enRoute)
        #expect(late.departed && !late.arrived)
        #expect(!r(dep + 3_600_000, .boarding).departed)
        #expect(!r(dep + 3_600_000, .atStop).departed)
        #expect(r(dep + 1, .atStop, prev: true).departed)
    }

    @Test func actualTimesAndAnArrivedStateCount() {
        #expect(r(0, actualDep: dep).departed)
        #expect(r(0, actualDep: dep, actualArr: arr).arrived)
        #expect(r(0, .arrived).arrived)
    }

    @Test func withNoLiveDataTheClockPlusTenMinutesDoes() {
        #expect(!r(dep + 9 * 60_000).departed)
        #expect(r(dep + 10 * 60_000).departed)
        #expect(!r(arr + 9 * 60_000).arrived)
        #expect(r(arr + 10 * 60_000).arrived)
    }
}

struct JourneyNowTests {
    private let now = ms("2026-10-21T12:00:00Z")

    private func leg(_ id: String, dep: Double, arr: Double, actualArr: Double? = nil) throws -> Leg {
        let json = """
        {"id":"\(id)","status":"planned","dataQuality":"full","trainNumber":null,"category":null,"serviceDate":null,
        "schedDep":\(now + dep * 60_000),"schedArr":\(now + arr * 60_000),"actualDep":null,
        "actualArr":\(actualArr.map { String(now + $0 * 60_000) } ?? "null"),
        "depDelayMin":null,"arrDelayMin":null,"depPlatform":null,"arrPlatform":null,"canceled":false,
        "distanceM":null,"isEstimatedGeometry":false,"trainType":null,"trainTypeSource":null,"onboard":null,
        "countryCodes":[],"journeyId":null,"timetableTripKey":null,"operatorId":null,"originStationId":"1",
        "destStationId":"2","notes":null,"ride":"auto","rideReason":null,"borderEvidence":null,"operator":null,
        "origin":null,"destination":null,"live":null}
        """
        return try JSONDecoder().decode(Leg.self, from: Data(json.utf8))
    }

    @Test func picksTheRunningLegThenTheNextOneAndNothingOutsideTheWindow() throws {
        let legs = [try leg("a", dep: -30, arr: 20), try leg("b", dep: 30, arr: 90)]
        #expect(TripsLogic.nowLegIndex(legs, now: now) == 0)
        let between = [try leg("a", dep: -60, arr: -10, actualArr: -10), try leg("b", dep: 30, arr: 90)]
        #expect(TripsLogic.nowLegIndex(between, now: now) == 1)
        #expect(TripsLogic.nowLegIndex([try leg("a", dep: 120, arr: 200)], now: now) == nil)
        #expect(TripsLogic.nowLegIndex([try leg("a", dep: 30, arr: 90)], now: now) == 0)
        #expect(TripsLogic.nowLegIndex([try leg("a", dep: -90, arr: -10, actualArr: -10)], now: now) == nil)
    }
}
