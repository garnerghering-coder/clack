//
//  NetworkLogicTests.swift
//  Clack
//

@testable import ClackCore
import Foundation
import Testing

/// Network now, about your own trains (build 82).
struct NetworkLogicTests {
    private let now = Date(timeIntervalSince1970: 1_794_729_600).timeIntervalSince1970 * 1000 // 2026-11-15 10:00 Stockholm

    private func leg(_ id: String, depMin: Double, delay: Int? = nil, canceled: Bool = false, from: String = "Stockholm C", to: String = "Malmö C") throws -> Leg {
        let json = """
        {"id":"\(id)","status":"planned","dataQuality":"full","trainNumber":"5\(id)","category":"intercity","serviceDate":"2026-11-15",
        "schedDep":\(now + depMin * 60_000),"schedArr":\(now + (depMin + 240) * 60_000),"actualDep":null,"actualArr":null,
        "depDelayMin":\(delay.map(String.init) ?? "null"),"arrDelayMin":null,"depPlatform":null,"arrPlatform":null,"canceled":\(canceled),
        "distanceM":null,"isEstimatedGeometry":false,"trainType":null,"trainTypeSource":null,"onboard":null,
        "countryCodes":[],"journeyId":null,"timetableTripKey":null,"operatorId":null,"originStationId":"1",
        "destStationId":"2","notes":null,"ride":"auto","rideReason":null,"borderEvidence":null,"operator":null,
        "origin":{"id":"1","name":"\(from)","code":null,"country":"SE","tz":"Europe/Stockholm"},
        "destination":{"id":"2","name":"\(to)","code":null,"country":"SE","tz":"Europe/Stockholm"},"live":null}
        """
        return try JSONDecoder().decode(Leg.self, from: Data(json.utf8))
    }

    private func status(disruptionAt place: String? = nil) -> NetworkStatus {
        let d = place.map { p in [NetworkStatus.Disruption(id: "x", country: "SE", kind: .works, title: nil, places: [p, "Hässleholm C"], from: nil, to: nil, lat: 0, lon: 0, lines: [], source: "trafikverket")] }
        return NetworkStatus(at: now, lateMin: 10, countries: [:], corridors: [], late: [], disruptions: d)
    }

    @Test func todayIsTheTrainsLeftToRunToday() throws {
        let legs = [try leg("a", depMin: 60), try leg("b", depMin: -600), try leg("c", depMin: 60 * 24)]
        #expect(NetworkLogic.today(legs, now: now).map(\.id) == ["a"])
    }

    @Test func aTrainIsAffectedWhenCancelledLateOrAtAStationWithTrouble() throws {
        let fine = try leg("a", depMin: 60)
        let late = try leg("b", depMin: 60, delay: 12)
        let gone = try leg("c", depMin: 60, canceled: true)
        let near = try leg("d", depMin: 60, to: "Hässleholm C")
        let out = NetworkLogic.affected([fine, late, gone, near], status: status(disruptionAt: "Lund C"))
        #expect(out.map(\.leg.id) == ["b", "c", "d"])
        #expect(out.map(\.why) == [.late(12), .canceled, .near("Hässleholm C")])
        #expect(NetworkLogic.affected([fine], status: status()).isEmpty)
    }
}
