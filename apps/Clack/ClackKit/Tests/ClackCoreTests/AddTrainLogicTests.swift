//
//  AddTrainLogicTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

private func hit(_ name: String, id: String = "1") -> StationHit {
    StationHit(id: id, name: name, code: nil, country: "SE", county: nil)
}

private func interpretation(typing: String?, op: String? = nil) -> SearchResponse.Interpretation {
    SearchResponse.Interpretation(
        operator: op.map { SearchResponse.Interpretation.OperatorText(id: "sj", text: $0) }, trainNumber: nil, from: nil, to: nil, typing: typing
    )
}

private func stop(_ seq: Int, noPickup: Bool = false, noDropoff: Bool = false, lat: Double = 57, lon: Double = 14) -> TripStop {
    TripStop(
        seq: seq, stationId: "s\(seq)", name: "S\(seq)", code: nil, country: "SE", tz: "Europe/Stockholm", lat: lat, lon: lon,
        arr: Instant(ms: Double(seq) * 600_000), dep: Instant(ms: Double(seq) * 600_000 + 60_000), noPickup: noPickup, noDropoff: noDropoff
    )
}

struct SearchTextTests {
    @Test func pickingTheFirstStationWritesItAndAnArrow() {
        #expect(AddTrainLogic.query(afterPicking: hit("Stockholm C"), query: "sthlm", interpretation: interpretation(typing: "from")) == "Stockholm C → ")
        #expect(AddTrainLogic.query(afterPicking: hit("Stockholm C"), query: "Snälltåget sthlm", interpretation: interpretation(typing: "from", op: "Snälltåget")) == "Snälltåget Stockholm C → ")
    }

    @Test func pickingTheDestinationReplacesEverythingFromTheSeparator() {
        let typing = interpretation(typing: "to")
        #expect(AddTrainLogic.query(afterPicking: hit("Göteborg C"), query: "Stockholm C → gö", interpretation: typing) == "Stockholm C → Göteborg C")
        #expect(AddTrainLogic.query(afterPicking: hit("Göteborg C"), query: "Stockholm C - gö", interpretation: typing) == "Stockholm C → Göteborg C")
        #expect(AddTrainLogic.query(afterPicking: hit("Göteborg C"), query: "Stockholm to gö", interpretation: typing) == "Stockholm → Göteborg C")
        #expect(AddTrainLogic.query(afterPicking: hit("Göteborg C"), query: "Stockholm till gö", interpretation: typing) == "Stockholm → Göteborg C")
        #expect(AddTrainLogic.query(afterPicking: hit("Göteborg C"), query: "A -> B", interpretation: typing) == "A → Göteborg C")
    }

    @Test func removingAPartRebuildsTheQuery() {
        #expect(AddTrainLogic.rebuilt(operator: "SJ", number: "523", from: nil, to: nil) == "SJ 523")
        #expect(AddTrainLogic.rebuilt(operator: nil, number: nil, from: "Stockholm C", to: "Göteborg C") == "Stockholm C → Göteborg C")
        #expect(AddTrainLogic.rebuilt(operator: "SJ", number: nil, from: "Stockholm C", to: nil) == "SJ Stockholm C →")
        #expect(AddTrainLogic.rebuilt(operator: nil, number: nil, from: nil, to: nil) == "")
    }

    @Test func theFiltersGroupProducts() throws {
        func result(_ product: String) throws -> TripResult {
            let json = """
            {"key":"k","serviceDate":"2026-10-23","trainNumber":"1","operatorId":null,"category":"regional","product":"\(product)",
            "trainType":null,"routeName":null,
            "from":{"seq":1,"stationId":"a","name":"A","code":null,"country":"SE","tz":"Europe/Stockholm","time":0},
            "to":{"seq":2,"stationId":"b","name":"B","code":null,"country":"SE","tz":"Europe/Stockholm","time":1},
            "durationMin":1,"stopsBetween":0,"alsoKnownAs":[]}
            """
            return try JSONDecoder().decode(TripResult.self, from: Data(json.utf8))
        }
        #expect(AddTrainLogic.includes(try result("high_speed"), .long))
        #expect(AddTrainLogic.includes(try result("night"), .long))
        #expect(!AddTrainLogic.includes(try result("regional"), .long))
        #expect(AddTrainLogic.includes(try result("heritage"), .regional))
        #expect(AddTrainLogic.includes(try result("commuter"), .commuter))
        #expect(!AddTrainLogic.includes(try result("commuter"), .regional))
        for f in AddTrainLogic.Filter.allCases { #expect(AddTrainLogic.includes(try result("intercity"), f) == (f == .all || f == .long)) }
    }
}

struct StopPickerTests {
    private let picked = AddTrainLogic.Picked(fromSeq: 2, toSeq: 6, picking: .to)

    @Test func pickingWhereYouGotOffMustBeAfterWhereYouGotOnAndAllowPassengersOff() {
        #expect(AddTrainLogic.tap(stop(4), in: picked)?.toSeq == 4)
        #expect(AddTrainLogic.tap(stop(2), in: picked) == nil)
        #expect(AddTrainLogic.tap(stop(1), in: picked) == nil)
        #expect(AddTrainLogic.tap(stop(8, noDropoff: true), in: picked) == nil)
        #expect(AddTrainLogic.tap(stop(8), in: picked)?.toSeq == 8)
    }

    @Test func pickingWhereYouGotOnMustBeBeforeWhereYouGotOffAndThenSwitchesToTheOtherEnd() {
        var picking = picked
        picking.picking = .from
        let next = AddTrainLogic.tap(stop(3), in: picking)
        #expect(next?.fromSeq == 3)
        #expect(next?.picking == .to)
        #expect(AddTrainLogic.tap(stop(6), in: picking) == nil)
        #expect(AddTrainLogic.tap(stop(7), in: picking) == nil)
        #expect(AddTrainLogic.tap(stop(1, noPickup: true), in: picking) == nil)
    }

    @Test func aWholeTrainStartsAtWhereYouGotOnThenWhereYouGotOff() throws {
        // Explore's "Plan a journey" and a board row open the whole train: first stop to last, nothing chosen yet.
        let trip = TimetableTrip(
            key: "k", serviceDate: "2026-10-24", trainNumber: "529", operatorId: "sj", category: "long_distance", product: "high_speed",
            trainType: nil, stops: (1...6).map { stop($0) }
        )
        let result = try #require(AddTrainLogic.result(from: trip, fromSeq: nil, toSeq: nil))
        var state = AddTrainLogic.initialPick(result, originChosen: false)
        #expect(state == AddTrainLogic.Picked(fromSeq: 1, toSeq: 6, picking: .from))
        // Stops after the first can be where you got on; the last can't (nothing after it to get off at).
        #expect(AddTrainLogic.isSelectable(stop(3), in: state))
        #expect(!AddTrainLogic.isSelectable(stop(6), in: state))
        // Choosing where you got on moves to where you got off.
        state = try #require(AddTrainLogic.tap(stop(3), in: state))
        #expect(state == AddTrainLogic.Picked(fromSeq: 3, toSeq: 6, picking: .to))
        #expect(!AddTrainLogic.isSelectable(stop(2), in: state))
        state = try #require(AddTrainLogic.tap(stop(5), in: state))
        #expect(state == AddTrainLogic.Picked(fromSeq: 3, toSeq: 5, picking: .to))
    }

    @Test func whenWhereYouGotOnIsAlreadyChosenThePickerStartsAtWhereYouGotOff() {
        #expect(AddTrainLogic.firstEnd(originChosen: false) == .from)
        #expect(AddTrainLogic.firstEnd(originChosen: true) == .to)
    }

    @Test func rolesAndWhichStopsCanBeChosen() {
        #expect(AddTrainLogic.role(stop(2), in: picked) == .from)
        #expect(AddTrainLogic.role(stop(6), in: picked) == .to)
        #expect(AddTrainLogic.role(stop(4), in: picked) == .between)
        #expect(AddTrainLogic.role(stop(9), in: picked) == .outside)
        #expect(AddTrainLogic.isSelectable(stop(7), in: picked))
        #expect(!AddTrainLogic.isSelectable(stop(7, noDropoff: true), in: picked))
        #expect(!AddTrainLogic.isSelectable(stop(2), in: picked))
    }

    @Test func aTimetableTripBecomesASearchResultWithDefaultsToTheFirstAndLastStop() throws {
        let trip = TimetableTrip(key: "k", serviceDate: "2026-10-23", trainNumber: "523", operatorId: "sj", category: "intercity", product: "intercity", trainType: nil, stops: (1...5).map { stop($0) })
        let all = try #require(AddTrainLogic.result(from: trip, fromSeq: nil, toSeq: nil))
        #expect(all.from.seq == 1)
        #expect(all.to.seq == 5)
        #expect(all.stopsBetween == 3)
        #expect(all.from.time == 660_000) // departure of stop 1
        #expect(all.to.time == 3_000_000) // arrival of stop 5
        let part = try #require(AddTrainLogic.result(from: trip, fromSeq: 2, toSeq: 4))
        #expect(part.stopsBetween == 1)
        #expect(part.durationMin == Int(((2_400_000.0 - 1_260_000.0) / 60_000).rounded()))
        #expect(AddTrainLogic.result(from: TimetableTrip(key: "k", serviceDate: "d", trainNumber: nil, operatorId: nil, category: "", product: "", trainType: nil, stops: []), fromSeq: nil, toSeq: nil) == nil)
    }
}

struct TripDistanceTests {
    private let stops = [stop(1, lon: 14.0), stop(2, lon: 14.1), stop(3, lon: 14.2)]

    @Test func withoutGeometryTheStraightLineBetweenStopsIsApproximate() {
        let d = AddTrainLogic.distance(stops: stops, geometry: nil, fromSeq: 1, toSeq: 3)
        #expect(d.approximate)
        #expect(abs(d.metres - 2 * 6_062) < 80)
        #expect(AddTrainLogic.distance(stops: stops, geometry: nil, fromSeq: 1, toSeq: 2).metres < d.metres)
    }

    @Test func withGeometryTheSegmentLengthsInsideTheRiddenRangeAdd() {
        let geometry = TripGeometry(segments: [
            .init(fromSeq: 1, toSeq: 2, polyline: Polyline.encode([LatLon(57, 14), LatLon(57, 14.1)]), lengthM: 6_100, estimated: false),
            .init(fromSeq: 2, toSeq: 3, polyline: Polyline.encode([LatLon(57, 14.1), LatLon(57, 14.2)]), lengthM: 6_200, estimated: true),
        ])
        #expect(AddTrainLogic.distance(stops: stops, geometry: geometry, fromSeq: 1, toSeq: 2) == (6_100, false))
        #expect(AddTrainLogic.distance(stops: stops, geometry: geometry, fromSeq: 1, toSeq: 3) == (12_300, true))
        let map = AddTrainLogic.mapRoute(stops: stops, geometry: geometry, fromSeq: 2, toSeq: 3)
        #expect(map.route.count == 2)
        #expect(map.context[0].count == 2)
        #expect(map.context[1].isEmpty)
    }
}

struct AddDateTests {
    @Test func aDateIsNoonInStockholmAndBack() throws {
        let date = try #require(AddTrainLogic.date(fromIso: "2026-10-23"))
        #expect(AddTrainLogic.iso(from: date) == "2026-10-23")
        #expect(AddTrainLogic.date(fromIso: "nonsense") == nil)
    }
}
