//
//  TripCardTests.swift
//  ClackTests
//
//  The trip card (Live Activity) rules on the phone: one card per journey, the end rule, the state the app builds, the
//  request bodies (a missing push-to-start address is left out) and the push environment read from the profile.
//

import Foundation
import Testing
@testable import ClackCore

private let now: Double = (Instant.parse("2026-10-21T12:00:00Z")?.timeIntervalSince1970 ?? 0) * 1000

private func at(_ min: Double) -> Double { now + min * 60_000 }

/// A leg between two stations, with times as minutes from `now`.
private func leg(
    _ id: String, dep: Double, arr: Double, from: String = "A", to: String = "B", journey: String? = nil,
    actualArr: Double? = nil, actualDep: Double? = nil, arrDelay: Int? = nil, canceled: Bool = false, live: String? = nil,
    depPlatform: String = "1", arrPlatform: String = "2"
) throws -> Leg {
    func ms(_ v: Double?) -> String { v.map { String($0) } ?? "null" }
    let json = """
    {"id":"\(id)","status":"planned","dataQuality":"full","trainNumber":"7205","category":"regional","serviceDate":"2026-10-21",
    "schedDep":\(at(dep)),"schedArr":\(at(arr)),"actualDep":\(ms(actualDep.map(at))),"actualArr":\(ms(actualArr.map(at))),
    "depDelayMin":null,"arrDelayMin":\(arrDelay.map(String.init) ?? "null"),
    "depPlatform":"\(depPlatform)","arrPlatform":"\(arrPlatform)","canceled":\(canceled),"distanceM":1000,"isEstimatedGeometry":false,
    "trainType":null,"trainTypeSource":null,"onboard":null,"countryCodes":["SE"],
    "journeyId":\(journey.map { "\"\($0)\"" } ?? "null"),"timetableTripKey":null,"operatorId":"sj",
    "originStationId":"\(from)","destStationId":"\(to)","notes":null,"ride":"auto","rideReason":null,"borderEvidence":null,
    "operator":null,
    "origin":{"id":"\(from)","name":"\(from) C","code":null,"country":"SE","tz":"Europe/Stockholm"},
    "destination":{"id":"\(to)","name":"\(to) C","code":null,"country":"SE","tz":"Europe/Oslo"},
    "live":\(live ?? "null")}
    """
    return try JSONDecoder().decode(Leg.self, from: Data(json.utf8))
}

private func live(_ status: String, next: String? = nil, eta: Double? = nil, arrivalDelay: Int? = nil, progress: Double? = nil) -> String {
    """
    {"legId":null,"updatedAt":\(now),"status":"\(status)","lat":null,"lon":null,"bearing":null,"speedKmh":null,
    "positionSource":null,"positionAt":null,"progress":\(progress.map { String($0) } ?? "null"),"prevStopId":null,
    "nextStopId":\(next.map { "\"\($0)\"" } ?? "null"),"eta":\(eta.map { String(at($0)) } ?? "null"),"arrivalEta":null,
    "arrivalDelayMin":\(arrivalDelay.map(String.init) ?? "null"),"reportedAt":null}
    """
}

@Suite("Trip card: when to start")
struct TripCardStartTests {
    @Test func startsFromHalfAnHourBefore() throws {
        #expect(try TripCard.isDue(leg("a", dep: 29, arr: 60), now: now))
        #expect(try !TripCard.isDue(leg("a", dep: 31, arr: 60), now: now))
        #expect(try TripCard.isDue(leg("a", dep: -10, arr: 20), now: now))
        #expect(try !TripCard.isDue(leg("a", dep: -60, arr: -1), now: now))
        #expect(try !TripCard.isDue(leg("a", dep: 10, arr: 40, canceled: true), now: now))
        #expect(try !TripCard.isDue(leg("a", dep: -40, arr: 10, actualArr: -1), now: now))
    }

    @Test func oneCardPerJourney() throws {
        let legs = try [
            leg("a", dep: -20, arr: 5, from: "A", to: "B", journey: "j1"),
            leg("b", dep: 15, arr: 50, from: "B", to: "C", journey: "j1"),
            leg("c", dep: 10, arr: 40, from: "X", to: "Y"),
        ]
        let start = TripCard.toStart(legs, running: [], started: [], now: now)
        #expect(start.map(\.id) == ["a", "c"])
    }

    @Test func noCardWhenTheJourneyHasOne() throws {
        let legs = try [
            leg("a", dep: -20, arr: 5, journey: "j1"),
            leg("b", dep: 15, arr: 50, from: "B", to: "C", journey: "j1"),
        ]
        // The server's card, started on leg a and moved on to leg b.
        let running = [TripCard.Running(legId: "b", journeyId: "j1", startLegId: "a")]
        #expect(TripCard.toStart(legs, running: running, started: [], now: now).isEmpty)
        // A card for a single leg (no journey) matches by leg.
        let single = try [leg("s", dep: 5, arr: 40)]
        #expect(TripCard.toStart(single, running: [TripCard.Running(legId: "s", journeyId: nil)], started: [], now: now).isEmpty)
    }

    @Test func aDismissedCardDoesNotComeBack() throws {
        let legs = try [leg("a", dep: 5, arr: 40, journey: "j1")]
        #expect(TripCard.toStart(legs, running: [], started: ["j:j1"], now: now).isEmpty)
        #expect(TripCard.journeyKey(legId: "a", journeyId: nil) == "l:a")
        #expect(TripCard.Running(legId: "b", journeyId: "j1", startLegId: "a").journeyKey == "j:j1")
    }
}

@Suite("Trip card: when to end")
struct TripCardEndTests {
    @Test func keepsTheCardThroughAChange() throws {
        let legs = try [
            leg("a", dep: -40, arr: -5, from: "A", to: "B", journey: "j1", actualArr: -5),
            leg("b", dep: 10, arr: 50, from: "B", to: "C", journey: "j1"),
        ]
        #expect(!TripCard.isFinished(TripCard.Running(legId: "a", journeyId: "j1"), legs: legs))
        #expect(!TripCard.isFinished(TripCard.Running(legId: "b", journeyId: "j1", startLegId: "a"), legs: legs))
    }

    @Test func endsWhenTheLastLegArrives() throws {
        let legs = try [
            leg("a", dep: -90, arr: -60, journey: "j1", actualArr: -60),
            leg("b", dep: -50, arr: -2, from: "B", to: "C", journey: "j1", actualArr: -2),
        ]
        #expect(TripCard.isFinished(TripCard.Running(legId: "b", journeyId: "j1", startLegId: "a"), legs: legs))
        // Even with the first leg's arrival never reported.
        let missing = try [
            leg("a", dep: -90, arr: -60, journey: "j1"),
            leg("b", dep: -50, arr: -2, from: "B", to: "C", journey: "j1", actualArr: -2),
        ]
        #expect(TripCard.isFinished(TripCard.Running(legId: "a", journeyId: "j1"), legs: missing))
    }

    @Test func endsWhenTheLegItShowsIsCancelled() throws {
        let legs = try [
            leg("a", dep: 10, arr: 40, journey: "j1", canceled: true),
            leg("b", dep: 50, arr: 90, from: "B", to: "C", journey: "j1"),
        ]
        #expect(TripCard.isFinished(TripCard.Running(legId: "a", journeyId: "j1"), legs: legs))
    }

    @Test func aCancelledLastLegWaitsForTheRideToEnd() throws {
        let riding = try [
            leg("a", dep: -10, arr: 20, journey: "j1"),
            leg("b", dep: 30, arr: 60, from: "B", to: "C", journey: "j1", canceled: true),
        ]
        #expect(!TripCard.isFinished(TripCard.Running(legId: "a", journeyId: "j1"), legs: riding))
        let over = try [
            leg("a", dep: -40, arr: -5, journey: "j1", actualArr: -5),
            leg("b", dep: 30, arr: 60, from: "B", to: "C", journey: "j1", canceled: true),
        ]
        #expect(TripCard.isFinished(TripCard.Running(legId: "a", journeyId: "j1"), legs: over))
    }

    @Test func aSingleLeg() throws {
        #expect(try !TripCard.isFinished(TripCard.Running(legId: "s", journeyId: nil), legs: [leg("s", dep: -10, arr: 20)]))
        #expect(try TripCard.isFinished(TripCard.Running(legId: "s", journeyId: nil), legs: [leg("s", dep: -40, arr: -1, actualArr: -1)]))
        // A trip that was deleted.
        #expect(try TripCard.isFinished(TripCard.Running(legId: "gone", journeyId: nil), legs: [leg("s", dep: -10, arr: 20)]))
    }
}

@Suite("Trip card: what it shows")
struct TripCardStateTests {
    @Test func moments() throws {
        #expect(try TripCard.moment(leg("a", dep: 90, arr: 120), next: nil, now: now).phase == "scheduled")
        #expect(try TripCard.moment(leg("a", dep: 20, arr: 60), next: nil, now: now).phase == "leaveSoon")
        #expect(try TripCard.moment(leg("a", dep: 5, arr: 60, live: live("boarding")), next: nil, now: now).phase == "boarding")
        #expect(try TripCard.moment(leg("a", dep: 5, arr: 60, live: live("approaching")), next: nil, now: now).phase == "approaching")
        #expect(try TripCard.moment(leg("a", dep: -5, arr: 30, live: live("en_route", next: "X", eta: 5)), next: nil, now: now).phase == "enRoute")
        #expect(try TripCard.moment(leg("a", dep: -25, arr: 8, live: live("en_route", next: "B", eta: 8)), next: nil, now: now).phase == "getOffSoon")
        #expect(try TripCard.moment(leg("a", dep: 5, arr: 60, canceled: true), next: nil, now: now).phase == "cancelled")
    }

    @Test func changingThenMovingOn() throws {
        let first = try leg("a", dep: -40, arr: -2, from: "A", to: "B", journey: "j1", actualArr: -2)
        let second = try leg("b", dep: 12, arr: 50, from: "B", to: "C", journey: "j1", depPlatform: "5")
        let m = TripCard.moment(first, next: second, now: now)
        #expect(m.phase == "changing")
        #expect(m.changePlatform == "5")
        #expect(m.changeAt == at(12))
        // While changing, the card still shows the first leg.
        let legs = [first, second]
        #expect(TripCard.currentLeg(TripCard.Running(legId: "a", journeyId: "j1"), legs: legs, now: now)?.id == "a")
        // More than an hour to the next train: the card moves on to it.
        let far = try leg("b", dep: 75, arr: 110, from: "B", to: "C", journey: "j1")
        #expect(TripCard.currentLeg(TripCard.Running(legId: "a", journeyId: "j1"), legs: [first, far], now: now)?.id == "b")
        // The next leg leaves from somewhere else: no change to show, on to it.
        let elsewhere = try leg("b", dep: 12, arr: 50, from: "D", to: "C", journey: "j1")
        #expect(TripCard.currentLeg(TripCard.Running(legId: "a", journeyId: "j1"), legs: [first, elsewhere], now: now)?.id == "b")
    }

    @Test func stateCarriesTheLegAndTheLiveDelay() throws {
        let l = try leg("a", dep: -10, arr: 30, from: "A", to: "B", actualDep: -9, arrDelay: 3,
                        live: live("en_route", next: "B", eta: 28, arrivalDelay: 7, progress: 0.4))
        let s = try #require(TripCard.state(for: l, legs: [l], now: now))
        #expect(s.legId == "a")
        #expect(s.train == "7205")
        #expect(s.from == "A C")
        #expect(s.to == "B C")
        #expect(s.fromTz == "Europe/Stockholm")
        #expect(s.toTz == "Europe/Oslo")
        #expect(s.delayMin == 7)
        #expect(s.status == "en_route")
        #expect(s.phase == "enRoute")
        #expect(s.platform == "2")
        #expect(s.platformFor == "arrival")
        #expect(s.nextStop == "B C")
        #expect(s.nextStopAt == at(28))
        #expect(s.progress == 0.4)
        #expect(s.departAt == at(-9))
    }

    @Test func unknownDelayStaysUnknown() throws {
        let l = try leg("a", dep: 20, arr: 60)
        let s = try #require(TripCard.state(for: l, legs: [l], now: now))
        #expect(s.delayMin == nil)
        #expect(s.phase == "leaveSoon")
        #expect(s.platform == "1")
        #expect(s.platformFor == "departure")
        // A stop that isn't one of the leg's ends isn't named.
        let mid = try leg("b", dep: -10, arr: 30, live: live("en_route", next: "X", eta: 5))
        #expect(TripCard.state(for: mid, legs: [mid], now: now)?.nextStop == nil)
    }

    @Test func decodesTheServersContentState() throws {
        // Old shape (no leg fields) and the new one.
        let old = #"{"status":"scheduled","delayMin":null,"platformFor":"departure","canceled":false,"phase":"leaveSoon"}"#
        let a = try JSONDecoder().decode(TripCardState.self, from: Data(old.utf8))
        #expect(a.legId == nil)
        #expect(a.moment == "leaveSoon")
        let new = #"{"status":"en_route","delayMin":4,"nextStop":null,"nextStopAt":null,"platform":"3","platformFor":"arrival","progress":0.5,"departAt":1,"arriveAt":2,"canceled":false,"phase":"enRoute","note":null,"changePlatform":null,"changeAt":null,"legId":"b","train":"42","from":"Malmö C","to":"Lund C","fromTz":"Europe/Stockholm","toTz":"Europe/Stockholm","extra":1}"#
        let b = try JSONDecoder().decode(TripCardState.self, from: Data(new.utf8))
        #expect(b.legId == "b")
        #expect(b.train == "42")
        #expect(b.from == "Malmö C")
        // Without a phase, the moment comes from the status.
        #expect(TripCardState(status: "at_stop", platformFor: "arrival", canceled: false).moment == "enRoute")
        #expect(TripCardState(status: "scheduled", platformFor: "departure", canceled: true).moment == "cancelled")
    }
}

@Suite("Push request bodies and environment")
struct PushBodyTests {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func startTokenLeftOutUnlessKnown() throws {
        let keep = try json(DeviceRegistration(token: "ab", environment: "sandbox", startToken: TokenUpdate(nil)))
        #expect(Set(keep.keys) == ["token", "environment"])
        let set = try json(DeviceRegistration(token: "ab", environment: "sandbox", startToken: TokenUpdate("cd")))
        #expect(set["startToken"] as? String == "cd")
        let clear = try json(DeviceRegistration(token: "ab", environment: "production", startToken: .clear))
        #expect(clear.keys.contains("startToken"))
        #expect(clear["startToken"] is NSNull)
    }

    @Test func activityBodyCarriesThePhone() throws {
        let with = try json(ActivityRegistration(token: "aa", legId: "l1", environment: "sandbox", deviceToken: "bb"))
        #expect(with["deviceToken"] as? String == "bb")
        #expect(with["legId"] as? String == "l1")
        let without = try json(ActivityRegistration(token: "aa", legId: "l1", environment: "sandbox"))
        #expect(!without.keys.contains("deviceToken"))
        #expect(hexToken(Data([0x0a, 0xff, 0x10])) == "0aff10")
    }

    /// A provisioning profile as Apple ships it: binary signature bytes around a plain XML property list.
    private func profile(aps: String?) -> Data {
        let entitlement = aps.map { "<key>aps-environment</key><string>\($0)</string>" } ?? ""
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>Name</key><string>Clack</string><key>Entitlements</key><dict>\(entitlement)
        <key>application-identifier</key><string>ABCDE12345.com.garnerghering.Clack</string></dict></dict></plist>
        """
        return Data([0x30, 0x82, 0x4e, 0x1f, 0x06, 0x09, 0x2a, 0x86]) + Data(xml.utf8) + Data([0xa0, 0x82, 0x0b, 0x00, 0xff])
    }

    @Test func environmentFromTheProfile() {
        #expect(PushEnvironment.apsEnvironment(inProfile: profile(aps: "development")) == "development")
        #expect(PushEnvironment.resolve(profile: profile(aps: "development")) == "sandbox")
        #expect(PushEnvironment.resolve(profile: profile(aps: "production")) == "production")
        // A profile without push, or one that can't be read: not production.
        #expect(PushEnvironment.resolve(profile: profile(aps: nil)) == "sandbox")
        #expect(PushEnvironment.resolve(profile: Data([1, 2, 3])) == "sandbox")
        // No profile in the bundle: App Store or TestFlight.
        #expect(PushEnvironment.resolve(profile: nil) == "production")
    }

    @Test func sharedSettings() throws {
        let defaults = try #require(UserDefaults(suiteName: "clack.test.\(UUID().uuidString)"))
        #expect(SharedSettings.language(defaults) == .en)
        #expect(SharedSettings.clock(defaults) == .h24)
        SharedSettings.write(language: .sv, clock: .h12, to: defaults)
        #expect(SharedSettings.language(defaults) == .sv)
        #expect(SharedSettings.clock(defaults) == .h12)
        #expect(SharedSettings.language(nil) == .en)
    }
}
