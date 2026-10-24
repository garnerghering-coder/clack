//
//  WidgetDataTests.swift
//  ClackCoreTests
//
//  What the widgets fetch and keep (workstream C): which journey is featured and which comes next, the legs as kept, the
//  board rows, and the timeout.
//

import Foundation
import Testing
@testable import ClackCore

private let now: Double = (Instant.parse("2026-10-21T12:00:00Z")?.timeIntervalSince1970 ?? 0) * 1000
private func at(_ min: Double) -> Double { now + min * 60_000 }

private func legJSON(
    _ id: String, dep: Double, arr: Double, from: String = "A", to: String = "B", journey: String? = nil, canceled: Bool = false,
    depDelay: Int? = nil, arrDelay: Int? = nil, live: String? = nil
) -> String {
    """
    {"id":"\(id)","status":"planned","dataQuality":"full","trainNumber":"\(id.count)","category":"regional","serviceDate":"2026-10-21",
    "schedDep":\(at(dep)),"schedArr":\(at(arr)),"actualDep":null,"actualArr":null,
    "depDelayMin":\(depDelay.map(String.init) ?? "null"),"arrDelayMin":\(arrDelay.map(String.init) ?? "null"),
    "depPlatform":"3","arrPlatform":"5","canceled":\(canceled),"distanceM":1000,"isEstimatedGeometry":false,
    "trainType":null,"trainTypeSource":null,"onboard":null,"countryCodes":["SE"],
    "journeyId":\(journey.map { "\"\($0)\"" } ?? "null"),"timetableTripKey":null,"operatorId":"sj",
    "originStationId":"\(from)","destStationId":"\(to)","notes":null,"ride":"auto","rideReason":null,"borderEvidence":null,
    "operator":{"id":"sj","name":"SJ","shortName":"SJ","company":null,"country":"SE","brandColor":"#1d4f91","logoPath":null,"logoUrl":null},
    "origin":{"id":"\(from)","name":"\(from) C","code":null,"country":"SE","tz":"Europe/Stockholm"},
    "destination":{"id":"\(to)","name":"\(to) C","code":null,"country":"NO","tz":"Europe/Oslo"},
    "live":\(live ?? "null")
    """
}

private func leg(
    _ id: String, dep: Double, arr: Double, from: String = "A", to: String = "B", journey: String? = nil, canceled: Bool = false,
    depDelay: Int? = nil, arrDelay: Int? = nil
) throws -> Leg {
    let json = legJSON(id, dep: dep, arr: arr, from: from, to: to, journey: journey, canceled: canceled, depDelay: depDelay, arrDelay: arrDelay) + "}"
    return try JSONDecoder().decode(Leg.self, from: Data(json.utf8))
}

struct WidgetJourneyChoiceTests {
    @Test func theFeaturedJourneyWithAllItsLegsAndTheNextJourney() throws {
        let legs = [
            try leg("later", dep: 600, arr: 700, from: "X", to: "Y"),
            try leg("b", dep: 100, arr: 160, from: "B", to: "C", journey: "j"),
            try leg("a", dep: 30, arr: 90, from: "A", to: "B", journey: "j"),
            try leg("old", dep: -900, arr: -800),
        ]
        let (hero, next) = WidgetData.journeys(legs, details: [:], now: now)
        #expect(hero.map(\.id) == ["a", "b"])
        #expect(next.map(\.id) == ["later"])
    }

    @Test func aJourneyHalfRiddenKeepsItsFirstLeg() throws {
        // On the second leg: the first (arrived) stays, so the widget can tell where the journey is.
        let legs = [try leg("a", dep: -120, arr: -60, journey: "j"), try leg("b", dep: -30, arr: 60, from: "B", to: "C", journey: "j")]
        #expect(WidgetData.journeys(legs, details: [:], now: now).hero.map(\.id) == ["a", "b"])
    }

    @Test func whenTheFeaturedJourneyHasEndedTheNextUpcomingOneIsFeatured() throws {
        // Arrived an hour ago, and another trip later today: the later one is featured (the hero rule), nothing after it.
        let legs = [try leg("done", dep: -120, arr: -60), try leg("tonight", dep: 300, arr: 400, from: "X", to: "Y")]
        let (hero, next) = WidgetData.journeys(legs, details: [:], now: now)
        #expect(hero.map(\.id) == ["tonight"])
        #expect(next.isEmpty)
    }

    @Test func anArrivedJourneyStaysFeaturedWhenNothingIsComing() throws {
        let legs = [try leg("done", dep: -120, arr: -60)]
        #expect(WidgetData.journeys(legs, details: [:], now: now).hero.map(\.id) == ["done"])
        // Not after six hours.
        #expect(WidgetData.journeys([try leg("old", dep: -500, arr: -400)], details: [:], now: now).hero.isEmpty)
    }

    @Test func aCancelledTrainIsNotTheNextJourney() throws {
        let legs = [try leg("now", dep: 10, arr: 60), try leg("off", dep: 100, arr: 200, canceled: true), try leg("then", dep: 300, arr: 400)]
        #expect(WidgetData.journeys(legs, details: [:], now: now).next.map(\.id) == ["then"])
    }

    @Test func detailsAreFetchedForTheFeaturedLegAndTheNextLegOfItsJourney() throws {
        let legs = [
            try leg("a", dep: 30, arr: 90, from: "A", to: "B", journey: "j"),
            try leg("b", dep: 100, arr: 160, from: "B", to: "C", journey: "j"),
            try leg("c", dep: 170, arr: 200, from: "C", to: "D", journey: "j"),
        ]
        #expect(WidgetData.detailIds(legs, now: now) == ["a", "b"])
        #expect(WidgetData.detailIds([], now: now).isEmpty)
    }
}

struct WidgetLegTests {
    @Test func keepsTheTimeZonesDelaysAndPlatforms() throws {
        let l = try #require(WidgetData.leg(try leg("a", dep: 30, arr: 90, depDelay: 4, arrDelay: 6), detail: nil))
        #expect(l.fromTz == "Europe/Stockholm" && l.toTz == "Europe/Oslo")
        #expect(l.depDelayMin == 4 && l.arrDelayMin == 6)
        #expect(l.depAt == at(34) && l.arrAt == at(96))
        #expect(l.depPlatform == "3" && l.arrPlatform == "5")
        #expect(l.from == "A C" && l.to == "B C")
        #expect(l.nextStop == nil)
    }

    @Test func anUnknownDelayStaysUnknown() throws {
        let l = try #require(WidgetData.leg(try leg("a", dep: 30, arr: 90), detail: nil))
        #expect(l.depDelayMin == nil && l.arrDelayMin == nil)
    }

    @Test func theNextStopIsNamedFromTheLegsStops() throws {
        let live = """
        {"updatedAt":\(now),"status":"en_route","lat":null,"lon":null,"bearing":null,"speedKmh":null,"positionSource":null,
        "positionAt":null,"progress":0.4,"prevStopId":"A","nextStopId":"M","eta":\(at(20)),"arrivalEta":null,"arrivalDelayMin":null,"reportedAt":null}
        """
        func stop(_ seq: Int, _ role: String, _ id: String) -> String {
            """
            {"seq":\(seq),"role":"\(role)","stationId":"\(id)","name":"\(id) station","code":null,"country":"SE","tz":"Europe/Stockholm",
            "lat":59,"lon":18,"schedArr":null,"schedDep":null,"actualArr":null,"actualDep":null,"estimatedArr":null,"estimatedDep":null,
            "platform":null,"canceled":false,"deviations":[],"reportSource":null}
            """
        }
        let json = legJSON("a", dep: -10, arr: 50, live: live)
            + #","geometry":null,"events":[],"stops":["# + [stop(1, "board", "A"), stop(2, "through", "M"), stop(3, "alight", "B"), stop(4, "after", "Z")].joined(separator: ",") + "]}"
        let detail = try JSONDecoder().decode(LegDetail.self, from: Data(json.utf8))
        let l = try #require(WidgetData.leg(detail.leg, detail: detail))
        #expect(l.nextStop == "M station")
        #expect(l.nextStopAt == at(20))
        #expect(l.stops == ["A station", "M station", "B station"])
        #expect(l.status == "en_route" && l.progress == 0.4)
    }
}

struct WidgetBoardTests {
    private func row(_ id: String, advertised: Double, estimated: Double? = nil, done: Bool = false) -> BoardRow {
        BoardRow(
            id: id, trainNumber: id, advertised: at(advertised), estimated: estimated.map(at), actual: nil, done: done, delayMin: nil,
            platform: "2", platformChange: nil, canceled: false, deviations: [], endpoints: ["Malmö C"], via: [], operatorId: nil,
            productName: nil, product: "regional", trainType: nil, trip: nil
        )
    }

    @Test func keepsTheTrainsStillToLeaveInBoardOrder() {
        let board = Board(stationId: "s", type: "departures", from: 0, to: 0, updatedAt: now, rows: [
            row("gone", advertised: -10), row("done", advertised: 5, done: true), row("late", advertised: -5, estimated: 4),
            row("b", advertised: 20), row("a", advertised: 10),
        ])
        let rows = WidgetData.departures(board, now: now)
        #expect(rows.map(\.id) == ["late", "a", "b"])
        #expect(rows[0].time == at(-5) && rows[0].expected == at(4) && rows[0].leaves == at(4))
        #expect(rows[0].to == "Malmö C")
    }

    @Test func keepsAtMostEnoughRowsForHalfAnHour() {
        let board = Board(stationId: "s", type: "departures", from: 0, to: 0, updatedAt: now, rows: (0..<60).map { row("r\($0)", advertised: Double($0)) })
        #expect(WidgetData.departures(board, now: now).count == WidgetData.boardRows)
    }
}

struct WidgetTimeoutTests {
    @Test func givesUpAfterTheTimeout() async {
        let result: Int? = await WidgetData.within(0.05) {
            try? await Task.sleep(for: .seconds(5))
            return 1
        }
        #expect(result == nil)
    }

    @Test func returnsTheAnswerInTime() async {
        #expect(await WidgetData.within(5) { 7 } == 7)
    }
}
