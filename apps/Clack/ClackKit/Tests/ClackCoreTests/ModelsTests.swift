//
//  ModelsTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct ModelsTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    /// A real `GET /api/legs` answer, saved from the running server on 2026-10-23: SJ 163 and SJ 421, both trips
    /// leaving Stockholm C.
    @Test func decodesARealLegsResponse() throws {
        let legs = try JSONDecoder().decode([Leg].self, from: fixture("legs"))
        #expect(legs.count == 2)

        let leg = try #require(legs.first)
        #expect(leg.id == "705bbd07-749f-41ab-b23a-40941ec18b71")
        #expect(leg.status == .completed)
        #expect(leg.dataQuality == .full)
        #expect(leg.trainNumber == "163")
        #expect(leg.serviceDate == "2026-10-23")
        #expect(leg.schedDep?.ms == 1_792_732_440_000)
        #expect(leg.actualArr?.ms == 1_792_751_340_000)
        #expect(leg.depDelayMin == 0)
        #expect(leg.arrDelayMin == -1)
        #expect(leg.depPlatform == "17b")
        #expect(leg.canceled == false)
        #expect(leg.trainType == "x40")
        #expect(leg.trainTypeSource == .composition)
        #expect(leg.onboard?.sleeper == false)
        #expect(leg.countryCodes == ["SE"])
        #expect(leg.ride == .confirmed)
        #expect(leg.rideReason == "added_after")
        #expect(leg.borderEvidence == nil)
        #expect(leg.operator?.brandColor == "#1fb14f")
        #expect(leg.origin?.name == "Stockholm C")
        #expect(leg.origin?.tz == "Europe/Stockholm")
        #expect(leg.destination?.name == "Göteborg C")
        #expect(leg.live == nil)
    }

    @Test func unknownEnumValuesDoNotFailDecoding() throws {
        let json = #""brand_new_status""#
        let status = try JSONDecoder().decode(LegStatus.self, from: Data(json.utf8))
        #expect(status == .unknown("brand_new_status"))
        #expect(status.rawValue == "brand_new_status")
    }

    @Test func liveStateAcceptsISOStringsAndMilliseconds() throws {
        let rest = #"{"legId":"a","updatedAt":"2026-10-23T08:12:00.000Z","status":"en_route","lat":59.3,"lon":18.0,"bearing":null,"speedKmh":120,"positionSource":"gps","positionAt":"2026-10-23T08:11:50.000Z","progress":0.4,"prevStopId":"1","nextStopId":"2","eta":"2026-10-23T08:30:00.000Z","arrivalEta":null,"arrivalDelayMin":3,"reportedAt":null}"#
        let sse = #"{"updatedAt":1792743120000,"status":"en_route","lat":59.3,"lon":18.0,"bearing":null,"speedKmh":120,"positionSource":"gps","positionAt":1792743110000,"progress":0.4,"prevStopId":"1","nextStopId":"2","eta":1792744200000,"arrivalEta":null,"arrivalDelayMin":3,"reportedAt":null}"#
        let a = try JSONDecoder().decode(LiveStateRow.self, from: Data(rest.utf8))
        let b = try JSONDecoder().decode(LiveStateRow.self, from: Data(sse.utf8))
        #expect(a.status == .enRoute)
        #expect(a.updatedAt == b.updatedAt)
        #expect(a.eta == b.eta)
        #expect(a.legId == "a")
        #expect(b.legId == nil)
    }

    @Test func decodesSettings() throws {
        let json = #"{"displayName":"","language":"en","distanceUnit":"km","clock":"24h","co2Comparison":"car_1","includeCommuter":true,"showRailNetwork":true,"theme":"dark","walkPace":"normal","stepFree":false,"heavyLuggage":false}"#
        let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        #expect(settings == Settings.defaults)
        #expect(settings.co2Comparison.rawValue == "car_1")
    }

    @Test func settingsEncodeBackToTheServersValues() throws {
        var settings = Settings.defaults
        settings.language = .sv
        settings.clock = .h12
        settings.co2Comparison = .carAvg
        let data = try JSONEncoder().encode(settings)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["language"] as? String == "sv")
        #expect(object["clock"] as? String == "12h")
        #expect(object["co2Comparison"] as? String == "car_avg")
    }

    @Test func decodesOperatorsTrainTypesAndAmenities() throws {
        let operators = ##"[{"id":"sj","name":"SJ","shortName":"SJ","company":null,"country":"SE","brandColor":"#1fb14f","logoPath":null,"logoUrl":"/api/operators/sj/logo?v=1","ticketUrl":"https://www.sj.se","ticketDeepLink":null}]"##
        let types = #"[{"id":"x2000","name":"X2000","builder":"ABB / Adtranz","max_kmh":200,"since":1990,"art":"x2000","about":"Tilting.","uncertain":true},{"id":"x","name":"X","builder":null,"max_kmh":null,"since":null,"art":"x","about":""}]"#
        let amenities = #"[{"match":{"operator":"oresundstag","type":"x31"},"claims":{"wifi":{"value":true,"note":"On all trains","source":"https://example.org","verified":"2026-10-21"},"catering":{"value":"Bistro","source":"https://example.org","verified":"2026-10-21","via":"owner"}}},{"match":{"operator":"sj"},"claims":{}}]"#

        let op = try JSONDecoder().decode([Operator].self, from: Data(operators.utf8))
        #expect(op.first?.logoUrl == "/api/operators/sj/logo?v=1")
        #expect(op.first?.ticketDeepLink == nil)

        let train = try JSONDecoder().decode([TrainType].self, from: Data(types.utf8))
        #expect(train.first?.maxKmh == 200)
        #expect(train.first?.uncertain == true)
        #expect(train.last?.maxKmh == nil)
        #expect(train.last?.uncertain == nil)

        let entries = try JSONDecoder().decode([AmenityEntry].self, from: Data(amenities.utf8))
        #expect(entries.first?.match.type == "x31")
        #expect(entries.first?.claims["wifi"]?.value == .flag(true))
        #expect(entries.first?.claims["catering"]?.value == .text("Bistro"))
        #expect(entries.first?.claims["catering"]?.via == "owner")
        #expect(entries.last?.match.type == nil)
    }
}

struct APIClientTests {
    private let client = APIClient(base: URL(string: "http://localhost:3001")!, userID: "11111111-1111-4111-8111-111111111111")

    @Test func pathsAreUnderApi() {
        #expect(client.url(["legs"]).absoluteString == "http://localhost:3001/api/legs")
    }

    @Test func segmentsArePercentEncodedIncludingColonAndBar() {
        #expect(client.url(["timetable", "trips", "se3:740163001231000001:e9f4bde942"]).absoluteString
            == "http://localhost:3001/api/timetable/trips/se3%3A740163001231000001%3Ae9f4bde942")
        #expect(client.url(["live", "trains", "no:123|2026-10-23"]).absoluteString
            == "http://localhost:3001/api/live/trains/no%3A123%7C2026-10-23")
    }

    @Test func queryItemsAreAddedSorted() {
        let url = client.url(["search"], query: ["q": "Stockholm C", "date": "2026-10-23"])
        #expect(url.absoluteString == "http://localhost:3001/api/search?date=2026-10-23&q=Stockholm%20C")
    }
}
