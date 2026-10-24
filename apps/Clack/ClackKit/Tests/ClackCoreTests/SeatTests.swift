//
//  SeatTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

struct SeatTests {
    private func json(_ patch: LegPatch) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(patch), as: UTF8.self)
    }

    @Test func aPatchSendsOnlyWhatChanges() throws {
        #expect(try json(LegPatch(coach: .some("4"))) == #"{"coach":"4"}"#)
        // Clearing sends null: the key has to be there.
        #expect(try json(LegPatch(seat: .some(nil))) == #"{"seat":null}"#)
        #expect(try json(LegPatch(trainType: .some(nil))) == #"{"trainType":null}"#)
        #expect(try json(LegPatch(coach: .some("4"), seat: .some("23"))) == #"{"coach":"4","seat":"23"}"#)
        #expect(LegPatch().isEmpty)
    }

    @Test func cleanTrimsAndLimits() {
        #expect(Seat.clean("  12A ") == "12A")
        #expect(Seat.clean("   ") == nil)
        #expect(Seat.clean(nil) == nil)
        #expect(Seat.clean("123456789") == "12345678")
    }

    private func leg(coach: String?, seat: String?) throws -> Leg {
        let text = """
        {"id":"a","status":"planned","dataQuality":"full","trainNumber":"423","category":"intercity","serviceDate":"2026-10-24",
        "schedDep":"2026-10-24T06:03:00Z","schedArr":"2026-10-24T08:51:00Z","actualDep":null,"actualArr":null,"depDelayMin":null,
        "arrDelayMin":null,"depPlatform":null,"arrPlatform":null,"canceled":false,"distanceM":null,"isEstimatedGeometry":false,
        "trainType":null,"trainTypeSource":null,"onboard":null,"countryCodes":["SE"],"journeyId":null,"timetableTripKey":"k",
        "operatorId":"sj","originStationId":"Cst","destStationId":"G","notes":null,
        "coach":\(coach.map { "\"\($0)\"" } ?? "null"),"seat":\(seat.map { "\"\($0)\"" } ?? "null"),
        "ride":"pending","rideReason":null,"borderEvidence":null,"operator":null,"origin":null,"destination":null,"live":null}
        """
        return try JSONDecoder().decode(Leg.self, from: Data(text.utf8))
    }

    @Test func aLegCarriesItsCoachAndSeat() throws {
        let l = try leg(coach: "4", seat: "23")
        #expect(l.coach == "4")
        #expect(l.seat == "23")
    }

    @Test func theWidgetKeepsTheSeat() throws {
        let kept = WidgetData.leg(try leg(coach: "4", seat: "23"), detail: nil)
        #expect(kept?.coach == "4")
        #expect(kept?.seat == "23")
    }

    @Test func anOlderServerWithoutTheFieldsStillDecodes() throws {
        let text = """
        {"id":"a","status":"planned","dataQuality":"full","trainNumber":null,"category":null,"serviceDate":null,"schedDep":null,
        "schedArr":null,"actualDep":null,"actualArr":null,"depDelayMin":null,"arrDelayMin":null,"depPlatform":null,"arrPlatform":null,
        "canceled":false,"distanceM":null,"isEstimatedGeometry":false,"trainType":null,"trainTypeSource":null,"onboard":null,
        "countryCodes":[],"journeyId":null,"timetableTripKey":null,"operatorId":null,"originStationId":"A","destStationId":"B",
        "notes":null,"ride":"pending","rideReason":null,"borderEvidence":null,"operator":null,"origin":null,"destination":null}
        """
        let l = try JSONDecoder().decode(Leg.self, from: Data(text.utf8))
        #expect(l.coach == nil)
        #expect(l.seat == nil)
    }

    @Test func savingTheFieldsPatchesOnlyTheChangedOnes() throws {
        let l = try leg(coach: "4", seat: nil)
        // Nothing changed (blank stays blank): nothing to send.
        #expect(Seat.patch(coach: " 4 ", seat: "  ", was: l) == nil)
        #expect(Seat.patch(coach: "4", seat: "23", was: l) == LegPatch(seat: .some("23")))
        // Emptying a field clears it.
        #expect(Seat.patch(coach: "", seat: nil, was: l) == LegPatch(coach: .some(nil)))
    }

    @Test func aTicketCreateSendsTheSeatOnlyWhenKnown() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let without = String(decoding: try encoder.encode(CreateLegBody(tripKey: "k", serviceDate: "2026-10-24", fromSeq: 1, toSeq: 2)), as: UTF8.self)
        #expect(!without.contains("coach") && !without.contains("seat"))
        let with = String(decoding: try encoder.encode(CreateLegBody(tripKey: "k", serviceDate: "2026-10-24", fromSeq: 1, toSeq: 2, coach: "4", seat: "23")), as: UTF8.self)
        #expect(with.contains(#""coach":"4""#) && with.contains(#""seat":"23""#))
    }
}
