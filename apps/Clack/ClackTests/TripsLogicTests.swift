//
//  TripsLogicTests.swift
//  ClackTests
//
//  The Trips rules of docs/swift-port/SCREENS.md §2.1 to §2.2 and §3.6, on small hand-made legs.
//

import Foundation
import Testing
@testable import Clack
@testable import ClackCore

private let now: Double = (Instant.parse("2026-10-21T12:00:00Z")?.timeIntervalSince1970 ?? 0) * 1000

private func at(_ min: Double) -> Double { now + min * 60_000 }

/// A leg between two stations, with times as minutes from `now`.
private func leg(
    _ id: String, dep: Double, arr: Double, from: String = "A", to: String = "B", journey: String? = nil,
    actualArr: Double? = nil, actualDep: Double? = nil, depDelay: Int? = nil, arrDelay: Int? = nil,
    canceled: Bool = false, status: String = "planned", live: String? = nil
) throws -> Leg {
    func ms(_ v: Double?) -> String { v.map { String($0) } ?? "null" }
    let json = """
    {"id":"\(id)","status":"\(status)","dataQuality":"full","trainNumber":"1","category":"regional","serviceDate":"2026-10-21",
    "schedDep":\(at(dep)),"schedArr":\(at(arr)),"actualDep":\(ms(actualDep.map(at))),"actualArr":\(ms(actualArr.map(at))),
    "depDelayMin":\(depDelay.map(String.init) ?? "null"),"arrDelayMin":\(arrDelay.map(String.init) ?? "null"),
    "depPlatform":"1","arrPlatform":"2","canceled":\(canceled),"distanceM":1000,"isEstimatedGeometry":false,
    "trainType":null,"trainTypeSource":null,"onboard":null,"countryCodes":["SE"],
    "journeyId":\(journey.map { "\"\($0)\"" } ?? "null"),"timetableTripKey":null,"operatorId":"sj",
    "originStationId":"\(from)","destStationId":"\(to)","notes":null,"ride":"auto","rideReason":null,"borderEvidence":null,
    "operator":null,
    "origin":{"id":"\(from)","name":"\(from)","code":null,"country":"SE","tz":"Europe/Stockholm"},
    "destination":{"id":"\(to)","name":"\(to)","code":null,"country":"SE","tz":"Europe/Stockholm"},
    "live":\(live ?? "null")}
    """
    return try JSONDecoder().decode(Leg.self, from: Data(json.utf8))
}

private func liveRow(status: String, arrivalEta: Double? = nil) -> String {
    """
    {"updatedAt":\(now),"status":"\(status)","lat":null,"lon":null,"bearing":null,"speedKmh":null,"positionSource":null,
    "positionAt":null,"progress":null,"prevStopId":null,"nextStopId":null,"eta":null,
    "arrivalEta":\(arrivalEta.map { String($0) } ?? "null"),"arrivalDelayMin":null,"reportedAt":null}
    """
}

struct PartitionTests {
    @Test func upcomingIsSoonestFirstAndPastMostRecentFirst() throws {
        let legs = [
            try leg("past-old", dep: -600, arr: -500), try leg("future-late", dep: 600, arr: 700),
            try leg("past-new", dep: -200, arr: -100), try leg("future-soon", dep: 60, arr: 120),
        ]
        let (upcoming, past) = TripsLogic.partition(legs, now: now)
        #expect(upcoming.map(\.id) == ["future-soon", "future-late"])
        #expect(past.map(\.id) == ["past-new", "past-old"])
    }

    @Test func aLateTrainThatIsStillRunningStaysUpcomingUntilItArrives() throws {
        let running = try leg("a", dep: -60, arr: -5, live: liveRow(status: "en_route", arrivalEta: at(15)))
        #expect(TripsLogic.arrivalOf(running) == at(15))
        #expect(TripsLogic.partition([running], now: now).upcoming.count == 1)
        let arrived = try leg("b", dep: -60, arr: -5, actualArr: -2)
        #expect(TripsLogic.partition([arrived], now: now).past.count == 1)
        // An estimate only counts while the train is being followed.
        let stale = try leg("c", dep: -60, arr: -5, live: liveRow(status: "arrived", arrivalEta: at(15)))
        #expect(TripsLogic.arrivalOf(stale) == at(-5))
    }

    @Test func expectedTimesAreActualElseLiveElseTimetablePlusDelay() throws {
        let a = try leg("a", dep: 10, arr: 70, depDelay: 5, arrDelay: 8)
        #expect(TripsLogic.expected(a).dep == at(15))
        #expect(TripsLogic.expected(a).arr == at(78))
        let b = try leg("b", dep: 10, arr: 70, actualArr: 75, actualDep: 12, depDelay: 5)
        #expect(TripsLogic.expected(b).dep == at(12))
        #expect(TripsLogic.expected(b).arr == at(75))
        let c = try leg("c", dep: 10, arr: 70, arrDelay: 8, live: liveRow(status: "en_route", arrivalEta: at(90)))
        #expect(TripsLogic.expected(c).arr == at(90))
    }
}

struct HeroTests {
    @Test func theTrainYouAreOnBeatsTheNextDeparture() throws {
        let next = try leg("next", dep: -200, arr: -100) // already past, so not upcoming
        let running = try leg("running", dep: -10, arr: 50)
        let later = try leg("later", dep: 60, arr: 120)
        let (upcoming, past) = TripsLogic.partition([next, running, later], now: now)
        let hero = TripsLogic.hero(upcoming: upcoming, past: past, now: now)
        #expect(hero?.leg.id == "running")
        #expect(hero?.state == .active)
    }

    @Test func otherwiseTheNextUpcomingOne() throws {
        let soon = try leg("soon", dep: 120, arr: 180)
        let later = try leg("later", dep: 600, arr: 700)
        let (upcoming, past) = TripsLogic.partition([later, soon], now: now)
        let hero = TripsLogic.hero(upcoming: upcoming, past: past, now: now)
        #expect(hero?.leg.id == "soon")
        #expect(hero?.state == .upcoming)
    }

    @Test func otherwiseOneThatArrivedInTheLastSixHoursAndWasNotCancelled() throws {
        let recent = try leg("recent", dep: -200, arr: -100)
        let old = try leg("old", dep: -900, arr: -800)
        let cancelled = try leg("cancelled", dep: -150, arr: -50, canceled: true)
        let (upcoming, past) = TripsLogic.partition([old, cancelled, recent], now: now)
        let hero = TripsLogic.hero(upcoming: upcoming, past: past, now: now)
        #expect(hero?.leg.id == "recent")
        #expect(hero?.state == .arrived)
        let (u2, p2) = TripsLogic.partition([old], now: now)
        #expect(TripsLogic.hero(upcoming: u2, past: p2, now: now) == nil)
    }
}

struct MeetingTests {
    @Test func twoTripsMeetAtTheSameStationWithinTheWindow() throws {
        let a = try leg("a", dep: 0, arr: 60, from: "A", to: "B")
        #expect(TripsLogic.meets(a, try leg("b", dep: 75, arr: 100, from: "B", to: "C")))
        #expect(TripsLogic.meets(a, try leg("b", dep: 58, arr: 100, from: "B", to: "C")))
        // More than 12 hours later, or more than 2 hours before.
        #expect(!TripsLogic.meets(a, try leg("b", dep: 60 + 12 * 60, arr: 900, from: "B", to: "C")))
        #expect(!TripsLogic.meets(a, try leg("b", dep: 60 - 121, arr: 100, from: "B", to: "C")))
        // Another station.
        #expect(!TripsLogic.meets(a, try leg("b", dep: 75, arr: 100, from: "X", to: "C")))
    }

    @Test func theArrivalUsedIsTheActualOneWhenKnown() throws {
        let a = try leg("a", dep: 0, arr: 60, from: "A", to: "B", actualArr: 70)
        #expect(TripsLogic.meets(a, try leg("b", dep: 70 + 12 * 60 - 1, arr: 900, from: "B", to: "C")))
    }

    @Test func nextInJourneyIsTheEarliestLaterLegOfTheSameJourneyFromThatStation() throws {
        let first = try leg("first", dep: 0, arr: 60, from: "A", to: "B", journey: "j")
        let second = try leg("second", dep: 75, arr: 130, from: "B", to: "C", journey: "j")
        let third = try leg("third", dep: 150, arr: 200, from: "B", to: "D", journey: "j")
        let other = try leg("other", dep: 70, arr: 120, from: "B", to: "E", journey: "k")
        let legs = [third, other, first, second]
        #expect(TripsLogic.nextInJourney(legs, after: first)?.id == "second")
        #expect(TripsLogic.nextInJourney(legs, after: third) == nil)
        #expect(TripsLogic.nextInJourney([first], after: first) == nil)
        let loose = try leg("loose", dep: 0, arr: 10)
        #expect(TripsLogic.nextInJourney(legs, after: loose) == nil)
    }
}

struct MonthsTests {
    @Test func groupsPastTripsByMonthAndGathersAJourneyIntoOneItem() throws {
        let day: Double = 24 * 60
        // Dates in minutes from 2026-10-21 12:00: -3 days = October; -30 days = September.
        let legs = [
            try leg("oct-b", dep: -3 * day + 120, arr: -3 * day + 180, from: "B", to: "C", journey: "j"),
            try leg("oct-a", dep: -3 * day, arr: -3 * day + 60, from: "A", to: "B", journey: "j"),
            try leg("sep", dep: -30 * day, arr: -30 * day + 60),
        ]
        let (_, past) = TripsLogic.partition(legs, now: now)
        let months = TripsLogic.months(past, language: .en)
        #expect(months.map(\.label) == ["October 2026", "September 2026"])
        #expect(months[0].items.count == 1)
        #expect(months[0].items[0].map(\.id) == ["oct-a", "oct-b"])
        #expect(months[1].items[0].map(\.id) == ["sep"])
    }
}

struct TransferTests {
    @Test func plannedTransferAndActualWhenBothAreKnown() throws {
        let a = try leg("a", dep: 0, arr: 60, actualArr: 62)
        let b = try leg("b", dep: 75, arr: 130, actualDep: 77)
        let t = TripsLogic.transfer(from: a, to: b)
        #expect(t.planned == 15)
        #expect(t.actual == 15)
        #expect(!t.missed)
        #expect(!t.tight)
    }

    @Test func tightBelowTenMinutesAndMissedWhenTheArrivalIsAfterTheDeparture() throws {
        let a = try leg("a", dep: 0, arr: 60)
        let tight = TripsLogic.transfer(from: a, to: try leg("b", dep: 66, arr: 100))
        #expect(tight.planned == 6)
        #expect(tight.tight)
        let late = try leg("late", dep: 0, arr: 60, actualArr: 80)
        let missed = TripsLogic.transfer(from: late, to: try leg("b", dep: 75, arr: 100))
        #expect(missed.missed)
        #expect(!missed.tight)
    }
}

struct ConnectionTimesTests {
    @Test func usesActualThenLiveEstimateThenTimetablePlusDelay() throws {
        let a = try leg("a", dep: 0, arr: 60, arrDelay: 4)
        let b = try leg("b", dep: 75, arr: 100, depDelay: 3)
        let planned = TripsLogic.connectionTimes(a, b)
        #expect(planned.arrival == at(64))
        #expect(planned.departure == at(78))
        #expect(!planned.live)

        let actual = try leg("a", dep: 0, arr: 60, actualArr: 66)
        let leaving = try leg("b", dep: 75, arr: 100, actualDep: 80)
        let real = TripsLogic.connectionTimes(actual, leaving)
        #expect(real.arrival == at(66))
        #expect(real.departure == at(80))
        #expect(real.live)
    }

    @Test func aBoardingTrainsEtaIsItsExpectedDeparture() throws {
        let a = try leg("a", dep: 0, arr: 60, actualArr: 61)
        let b = try leg("b", dep: 75, arr: 100, live: liveRow(status: "boarding").replacingOccurrences(of: "\"eta\":null", with: "\"eta\":\(at(79))"))
        let times = TripsLogic.connectionTimes(a, b)
        #expect(times.departure == at(79))
        #expect(times.live)
    }

    @Test func theConnectionFallsBackToTheSizeEstimateWithoutAMap() throws {
        let a = try leg("a", dep: 0, arr: 60, actualArr: 60)
        let b = try leg("b", dep: 90, arr: 120, actualDep: 90)
        let result = TripsLogic.connection(a, b, map: nil, info: nil, profile: .default)
        // 30 min layover, a medium station's 240 s walk: plenty, but an estimate, so just a margin.
        #expect(result.result.status == .margin)
        #expect(result.result.estimated)
        #expect(result.result.walkSeconds == 240)
        #expect(!result.noPath)
    }
}
