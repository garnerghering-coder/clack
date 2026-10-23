//
//  LogicTests2.swift
//  ClackTests
//
//  Ported from packages/shared/src/polyline.test.ts, settings.test.ts, apps/server/test/onboard.test.ts (typical
//  amenities), apps/web/src/tickets.test.ts, and the cases in docs/swift-port/SCREENS.md §3.3.
//

import Foundation
import Testing
@testable import Clack

private func ms(_ iso: String) -> Double {
    (Instant.parse(iso)?.timeIntervalSince1970 ?? 0) * 1000
}

struct PolylineTests {
    @Test func matchesTheReferenceEncoding() {
        // Example from Google's polyline documentation.
        let points = [LatLon(38.5, -120.2), LatLon(40.7, -120.95), LatLon(43.252, -126.453)]
        #expect(Polyline.encode(points) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        #expect(Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@") == points)
    }

    @Test func roundTripsAtAboutOneMetre() {
        let points = [LatLon(57.78, 14.16), LatLon(57.7826, 14.1618), LatLon(59.33, 18.06)]
        #expect(Polyline.decode(Polyline.encode(points)) == points)
    }

    @Test func emptyAndSinglePoint() {
        #expect(Polyline.encode([]) == "")
        #expect(Polyline.decode("") == [])
        #expect(Polyline.decode(Polyline.encode([LatLon(0, 0)])) == [LatLon(0, 0)])
    }
}

struct SettingsTests {
    @Test func appliesValidChanges() {
        let next = Settings.defaults.applying(SettingsPatch(distanceUnit: .mi, includeCommuter: false))
        var expected = Settings.defaults
        expected.distanceUnit = .mi
        expected.includeCommuter = false
        #expect(next == expected)
    }

    @Test func trimsTheNameAndRefusesOneOverSixtyCharacters() {
        #expect(Settings.defaults.applying(SettingsPatch(displayName: "  Garner  "))?.displayName == "Garner")
        #expect(Settings.defaults.applying(SettingsPatch(displayName: String(repeating: "a", count: 60))) != nil)
        #expect(Settings.defaults.applying(SettingsPatch(displayName: String(repeating: "a", count: 61))) == nil)
    }

    @Test func doesNotMutateTheOriginal() {
        let before = Settings.defaults
        _ = Settings.defaults.applying(SettingsPatch(clock: .h12))
        #expect(Settings.defaults == before)
    }

    @Test func aPatchSendsOnlyTheFieldsThatAreSet() throws {
        let data = try JSONEncoder().encode(SettingsPatch(clock: .h12, theme: .light))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["clock", "theme"])
        #expect(object["clock"] as? String == "12h")
    }

    @Test func offersFlyingAndAPetrolCar() {
        #expect(Settings.co2Choices == [.flight, .car1])
    }
}

struct OnboardTests {
    let src = (source: "https://example.se", verified: "2026-10-21")
    let now = ms("2026-10-22T12:00:00Z")

    private func claim(_ value: AmenityValue, source: String = "https://example.se", verified: String = "2026-10-21") -> AmenityClaim {
        AmenityClaim(value: value, note: nil, source: source, verified: verified, via: nil)
    }

    private var table: [AmenityEntry] {
        [
            AmenityEntry(match: .init(operator: "norrtag", type: nil), claims: ["wifi": claim(.flag(true)), "catering": claim(.text("Bistro"))]),
            AmenityEntry(match: .init(operator: "norrtag", type: "regina"), claims: ["step_free": claim(.text("partial"))]),
            AmenityEntry(match: .init(operator: "norrtag", type: "x62"), claims: ["step_free": claim(.flag(true))]),
            AmenityEntry(match: .init(operator: "sj", type: "x2000"), claims: ["wifi": claim(.flag(true), source: "https://sj.se", verified: "2024-01-01")]),
        ]
    }

    @Test func layersTheTypeOverTheOperator() {
        let regina = Onboard.typicalAmenities(table, operatorId: "norrtag", typeId: "regina", now: now)
        #expect(regina.keys.sorted() == ["catering", "step_free", "wifi"])
        #expect(regina["step_free"]?.value == .text("partial"))
        #expect(Onboard.typicalAmenities(table, operatorId: "norrtag", typeId: "x62", now: now)["step_free"]?.value == .flag(true))
    }

    @Test func hidesClaimsNobodyHasCheckedForAYearAndGuessesNothingForUnknownTrains() {
        #expect(Onboard.typicalAmenities(table, operatorId: "sj", typeId: "x2000", now: now).isEmpty)
        #expect(Onboard.typicalAmenities(table, operatorId: nil, typeId: nil, now: now).isEmpty)
    }

    @Test func aTypeOnlyAppliesToItsOwnOperatorAndOnlyWhenTheTripHasThatType() {
        #expect(Onboard.typicalAmenities(table, operatorId: "norrtag", typeId: nil, now: now).keys.sorted() == ["catering", "wifi"])
        #expect(Onboard.typicalAmenities(table, operatorId: "vy", typeId: "regina", now: now).isEmpty)
    }
}

struct TicketsTests {
    let trip = TicketTrip(
        operatorId: "sj", trainNumber: "421",
        from: .init(name: "Stockholm C", time: ms("2026-10-23T05:13:00Z"), tz: "Europe/Stockholm", seq: 1),
        to: .init(name: "Göteborg C", time: ms("2026-10-23T08:13:00Z"), tz: "Europe/Stockholm", seq: 5),
        tripKey: "k", serviceDate: "2026-10-23"
    )

    @Test func isTheOperatorsOwnPageWhenNoLinkFormatHasBeenChecked() {
        #expect(Tickets.href(base: "https://www.sj.se", deepLink: nil, trip: trip) == "https://www.sj.se")
    }

    @Test func fillsACheckedFormatWithTheJourneyInLocalTime() {
        #expect(
            Tickets.href(base: "https://x.se", deepLink: "https://x.se/s?f={from}&t={to}&d={date}&h={time}", trip: trip)
                == "https://x.se/s?f=Stockholm%20C&t=G%C3%B6teborg%20C&d=2026-10-23&h=07:13"
        )
    }
}

struct LiveStatusTests {
    let now = ms("2026-10-21T12:00:00Z")

    private func at(_ min: Double) -> Instant { Instant(ms: now + min * 60_000) }

    private func live(_ status: LiveStatus, updated: Double = 0, reported: Double? = nil) -> LiveStateRow {
        LiveStateRow(
            legId: nil, updatedAt: at(updated), status: status, lat: nil, lon: nil, bearing: nil, speedKmh: nil,
            positionSource: nil, positionAt: nil, progress: nil, prevStopId: nil, nextStopId: nil, eta: nil,
            arrivalEta: nil, arrivalDelayMin: nil, reportedAt: reported.map(at)
        )
    }

    private func leg(dep: Double, arr: Double, status: LegStatus = .planned, canceled: Bool = false) throws -> Leg {
        let json = """
        {"id":"a","status":"\(status.rawValue)","dataQuality":"full","trainNumber":null,"category":null,"serviceDate":null,
        "schedDep":\(now + dep * 60_000),"schedArr":\(now + arr * 60_000),"actualDep":null,"actualArr":null,
        "depDelayMin":null,"arrDelayMin":null,"depPlatform":null,"arrPlatform":null,"canceled":\(canceled),
        "distanceM":null,"isEstimatedGeometry":false,"trainType":null,"trainTypeSource":null,"onboard":null,
        "countryCodes":[],"journeyId":null,"timetableTripKey":null,"operatorId":null,"originStationId":"1",
        "destStationId":"2","notes":null,"ride":"auto","rideReason":null,"borderEvidence":null,"operator":null,
        "origin":null,"destination":null,"live":null}
        """
        return try JSONDecoder().decode(Leg.self, from: Data(json.utf8))
    }

    @Test func cancelledWinsOverEverything() throws {
        #expect(LiveRules.statusKey(try leg(dep: -10, arr: 50, canceled: true), live: live(.enRoute), now: now) == .cancelled)
        #expect(LiveRules.statusKey(try leg(dep: -10, arr: 50), live: live(.cancelled), now: now) == .cancelled)
    }

    @Test func freshLiveDataDecides() throws {
        let trip = try leg(dep: -10, arr: 50)
        #expect(LiveRules.statusKey(trip, live: live(.boarding), now: now) == .boarding)
        #expect(LiveRules.statusKey(trip, live: live(.enRoute), now: now) == .live)
        #expect(LiveRules.statusKey(trip, live: live(.atStop), now: now) == .live)
        #expect(LiveRules.statusKey(trip, live: live(.arrived), now: now) == .completed)
    }

    @Test func staleLiveDataFallsBackToTheClock() throws {
        let stale = live(.arrived, updated: -3)
        #expect(!LiveRules.isFresh(stale, now: now))
        #expect(LiveRules.statusKey(try leg(dep: -10, arr: 50), live: stale, now: now) == .live)
        // The time the feeds last answered counts, not the time our server last ticked.
        let reported = live(.enRoute, updated: 0, reported: -5)
        #expect(!LiveRules.isFresh(reported, now: now))
    }

    @Test func theClockDecidesWithoutLiveData() throws {
        #expect(LiveRules.statusKey(try leg(dep: 120, arr: 200), live: nil, now: now) == .planned)
        #expect(LiveRules.statusKey(try leg(dep: 30, arr: 100), live: nil, now: now) == .boarding)
        #expect(LiveRules.statusKey(try leg(dep: 31, arr: 100), live: nil, now: now) == .planned)
        #expect(LiveRules.statusKey(try leg(dep: -5, arr: 100), live: nil, now: now) == .live)
        #expect(LiveRules.statusKey(try leg(dep: -100, arr: -5), live: nil, now: now) == .completed)
        #expect(LiveRules.statusKey(try leg(dep: 60, arr: 100, status: .completed), live: nil, now: now) == .completed)
    }

    @Test func isLiveMeansTrackedAndNotArrived() {
        #expect(LiveRules.isLive(live(.boarding)))
        #expect(LiveRules.isLive(live(.enRoute)))
        #expect(LiveRules.isLive(live(.atStop)))
        #expect(!LiveRules.isLive(live(.arrived)))
        #expect(!LiveRules.isLive(live(.scheduled)))
        #expect(!LiveRules.isLive(nil))
    }
}
