//
//  ArrivalLogicTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack
@testable import ClackCore

private let now: Double = (Instant.parse("2026-10-21T12:00:00Z")?.timeIntervalSince1970 ?? 0) * 1000

private func at(_ min: Double) -> Double { now + min * 60_000 }

private func leg(
    _ id: String, dep: Double, arr: Double, journey: String? = nil, actualArr: Double? = nil, arrDelay: Int? = nil,
    canceled: Bool = false, distance: String = "1000", ride: String = "auto", live: String? = nil
) throws -> Leg {
    let json = """
    {"id":"\(id)","status":"planned","dataQuality":"full","trainNumber":"1","category":"regional","serviceDate":"2026-10-21",
    "schedDep":\(at(dep)),"schedArr":\(at(arr)),"actualDep":null,"actualArr":\(actualArr.map { String(at($0)) } ?? "null"),
    "depDelayMin":null,"arrDelayMin":\(arrDelay.map(String.init) ?? "null"),
    "depPlatform":"1","arrPlatform":"2","canceled":\(canceled),"distanceM":\(distance),"isEstimatedGeometry":false,
    "trainType":null,"trainTypeSource":null,"onboard":null,"countryCodes":["SE"],
    "journeyId":\(journey.map { "\"\($0)\"" } ?? "null"),"timetableTripKey":null,"operatorId":"sj",
    "originStationId":"A","destStationId":"B","notes":null,"ride":"\(ride)","rideReason":null,"borderEvidence":null,
    "operator":null,
    "origin":{"id":"A","name":"A","code":null,"country":"SE","tz":"Europe/Stockholm"},
    "destination":{"id":"B","name":"B","code":null,"country":"SE","tz":"Europe/Stockholm"},
    "live":\(live ?? "null")}
    """
    return try JSONDecoder().decode(Leg.self, from: Data(json.utf8))
}

struct ArrivalLogicTests {
    @Test func theFinalLegOfAJourneyIsItsLastDeparture() throws {
        let legs = [try leg("a", dep: -300, arr: -200, journey: "j"), try leg("b", dep: -190, arr: -100, journey: "j"), try leg("c", dep: -50, arr: -10)]
        #expect(Set(ArrivalLogic.finalLegs(legs).map(\.id)) == ["b", "c"])
    }

    @Test func noLiveDataCountsAsArrivedTwoMinutesAfterTheExpectedTime() throws {
        let l = try leg("a", dep: -60, arr: -1)
        #expect(ArrivalLogic.arrivedAt(l, now: now) == nil)
        let m = try leg("b", dep: -60, arr: -3)
        #expect(ArrivalLogic.arrivedAt(m, now: now) != nil)
    }

    @Test func anActualArrivalWins() throws {
        let l = try leg("a", dep: -60, arr: 30, actualArr: -5)
        #expect(ArrivalLogic.arrivedAt(l, now: now) == at(-5))
    }

    @Test func onlyWatchedJourneysCelebrate() throws {
        let l = try leg("a", dep: -90, arr: -10)
        #expect(ArrivalLogic.due([l], now: now, watched: [], shown: []) == nil)
        #expect(ArrivalLogic.due([l], now: now, watched: ["a"], shown: [])?.id == "a")
    }

    @Test func aShownJourneyDoesNotRepeat() throws {
        let l = try leg("a", dep: -90, arr: -10)
        #expect(ArrivalLogic.due([l], now: now, watched: ["a"], shown: ["a"]) == nil)
    }

    @Test func theWindowIsTwoHours() throws {
        let inside = try leg("a", dep: -200, arr: -119)
        let outside = try leg("b", dep: -300, arr: -125)
        #expect(ArrivalLogic.due([inside], now: now, watched: ["a"], shown: [])?.id == "a")
        #expect(ArrivalLogic.due([outside], now: now, watched: ["b"], shown: []) == nil)
    }

    @Test func cancelledAndNotRiddenTripsDoNotCelebrate() throws {
        let cancelled = try leg("a", dep: -90, arr: -10, canceled: true)
        let skipped = try leg("b", dep: -90, arr: -10, ride: "not_taken")
        #expect(ArrivalLogic.due([cancelled, skipped], now: now, watched: ["a", "b"], shown: []) == nil)
    }

    @Test func aJourneyIsNotDoneUntilItsLastLegArrives() throws {
        let legs = [try leg("a", dep: -200, arr: -100, journey: "j"), try leg("b", dep: -90, arr: 30, journey: "j")]
        #expect(ArrivalLogic.due(legs, now: now, watched: ["a", "b"], shown: []) == nil)
        #expect(ArrivalLogic.toWatch(legs, now: now) == ["b"])
    }

    @Test func summaryTotalsTheJourney() throws {
        let legs = [try leg("a", dep: -200, arr: -100, journey: "j"), try leg("b", dep: -90, arr: -10, journey: "j", arrDelay: 4)]
        let s = ArrivalLogic.summary(legs)
        #expect(s.minutesOnBoard == 184)
        #expect(s.distanceM == 2000)
        #expect(s.trains == 2)
        #expect(s.arrDelayMin == 4)
    }

    @Test func distanceIsHiddenWhenOneLegHasNone() throws {
        let legs = [try leg("a", dep: -200, arr: -100, journey: "j"), try leg("b", dep: -90, arr: -10, journey: "j", distance: "null")]
        #expect(ArrivalLogic.summary(legs).distanceM == nil)
    }

    @Test func mergingProgressUnionsMedalsAndSpansTheMoves() {
        func medal(_ f: MilestoneFamily, _ t: Double) -> Milestone { Milestone(family: f, target: t, at: nil, legId: nil, value: nil) }
        let first = TripProgress(
            counted: true, unlocked: [medal(.stations, 10)],
            moved: [.init(family: .stations, before: 8, after: 9, target: 10), .init(family: .distanceKm, before: 100, after: 200, target: 500)],
            firsts: .init(stations: ["X"], operator: nil, countries: ["SE"])
        )
        let second = TripProgress(
            counted: true, unlocked: [medal(.stations, 10)],
            moved: [.init(family: .distanceKm, before: 200, after: 350, target: 500), .init(family: .stations, before: 9, after: 10, target: 10)],
            firsts: .init(stations: ["X", "Y"], operator: "sj", countries: ["SE", "NO"])
        )
        let merged = ArrivalLogic.merge([first, second])
        #expect(merged.unlocked.count == 1)
        #expect(merged.moved.count == 1)
        #expect(merged.moved.first?.before == 100)
        #expect(merged.moved.first?.after == 350)
        #expect(merged.firsts?.stations == ["X", "Y"])
        #expect(merged.firsts?.countries == ["SE", "NO"])
        #expect(merged.firsts?.operator == "sj")
    }
}
