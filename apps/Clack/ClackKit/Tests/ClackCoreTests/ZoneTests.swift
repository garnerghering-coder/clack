//
//  ZoneTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

/// Finland is on Europe/Helsinki, an hour ahead of Sweden and Norway: a time or a day shown in the wrong zone is wrong.
struct ZoneTests {
    private func ms(_ iso: String) -> Double { (Instant.parse(iso)?.timeIntervalSince1970 ?? 0) * 1000 }

    @Test func aHelsinkiDepartureShowsItsOwnClockNotStockholms() {
        let dep = ms("2026-10-24T20:30:00Z")
        #expect(Format.time(dep, tz: "Europe/Helsinki", clock: .h24) == "23:30")
        #expect(Format.time(dep, tz: "Europe/Stockholm", clock: .h24) == "22:30")
    }

    @Test func aDepartureJustAfterMidnightInHelsinkiIsTheNextDayThere() {
        let dep = ms("2026-10-24T21:30:00Z")
        #expect(Format.time(dep, tz: "Europe/Helsinki", clock: .h24) == "00:30")
        #expect(Format.localDate(dep, tz: "Europe/Helsinki") == "2026-10-25")
        #expect(Format.localDate(dep, tz: "Europe/Stockholm") == "2026-10-24")
    }

    @Test func aZoneThePhoneDoesNotKnowFallsBackToStockholm() {
        #expect(Format.zone(nil) == "Europe/Stockholm")
        #expect(Format.zone("Not/AZone") == "Europe/Stockholm")
        #expect(Format.zone("Europe/Helsinki") == "Europe/Helsinki")
        #expect(Format.time(ms("2026-10-24T20:30:00Z"), tz: "Not/AZone", clock: .h24) == "22:30")
    }

    @Test func aPlaceThatOnlyKnowsItsCountryOrStationIdGetsTheRightZone() {
        #expect(Format.zone(country: "FI") == "Europe/Helsinki")
        #expect(Format.zone(country: "SE") == "Europe/Stockholm")
        #expect(Format.zone(country: nil) == "Europe/Stockholm")
        #expect(Format.zone(stationId: "fi:HKI") == "Europe/Helsinki")
        #expect(Format.zone(stationId: "no:NSR:StopPlace:337") == "Europe/Oslo")
        #expect(Format.zone(stationId: "abc123") == "Europe/Stockholm")
    }

    @Test func theLegsZoneIsItsOriginsAndStockholmWhenThereIsNone() throws {
        func leg(origin: String) throws -> Leg {
            let json = """
            {"id":"l","status":"planned","dataQuality":"full","trainNumber":"9","category":"intercity","serviceDate":"2026-10-24",
            "schedDep":0,"schedArr":1,"actualDep":null,"actualArr":null,"depDelayMin":null,"arrDelayMin":null,
            "depPlatform":null,"arrPlatform":null,"canceled":false,"distanceM":1000,"isEstimatedGeometry":false,
            "trainType":null,"trainTypeSource":null,"onboard":null,"countryCodes":["FI"],"journeyId":null,"timetableTripKey":null,
            "operatorId":"vr-fi","originStationId":"fi:HKI","destStationId":"fi:TPE","notes":null,"ride":"auto","rideReason":null,
            "borderEvidence":null,"operator":null,
            "origin":\(origin),"destination":null,"live":null}
            """
            return try JSONDecoder().decode(Leg.self, from: Data(json.utf8))
        }
        let helsinki = #"{"id":"fi:HKI","name":"Helsinki","code":null,"country":"FI","tz":"Europe/Helsinki"}"#
        #expect(TripsLogic.tz(try leg(origin: helsinki)) == "Europe/Helsinki")
        #expect(TripsLogic.tz(try leg(origin: "null")) == "Europe/Stockholm")
    }

    @Test func theDatePickerUsesTheStartStationsDay() {
        // Noon in Helsinki on the 25th is still the 25th when read back in Helsinki, and the round trip is exact.
        let noon = AddTrainLogic.date(fromIso: "2026-10-25", tz: "Europe/Helsinki")
        #expect(noon.map { AddTrainLogic.iso(from: $0, tz: "Europe/Helsinki") } == "2026-10-25")
        #expect(noon.map { $0.timeIntervalSince1970 } == ms("2026-10-25T10:00:00Z") / 1000)
        let stockholm = AddTrainLogic.date(fromIso: "2026-10-25")
        #expect(stockholm.map { $0.timeIntervalSince1970 } == ms("2026-10-25T11:00:00Z") / 1000)
    }

    @Test func aTicketForAFinnishTrainUsesHelsinkiTime() {
        func stop(_ id: String, seq: Int) -> LiveTrainStop {
            LiveTrainStop(seq: seq, stationId: id, name: id, arr: nil, dep: nil, actualArr: nil, actualDep: nil, estimatedArr: nil, estimatedDep: nil, platform: nil, canceled: false, passed: false)
        }
        let trip = ExploreLogic.ticketTrip(operatorId: "vr-fi", number: "9", from: stop("fi:HKI", seq: 0), to: stop("fi:TPE", seq: 1), trip: nil)
        #expect(trip.from.tz == "Europe/Helsinki")
        #expect(trip.to.tz == "Europe/Helsinki")
    }
}
