//
//  SharedTests.swift
//  ClackCoreTests
//
//  A journey shared by link: the links that open it, the copy a follower reads, and the sentences about it.
//

import Foundation
import Testing
@testable import ClackCore

private func link(_ string: String) -> DeepLink? { URL(string: string).flatMap(DeepLink.parse) }

private let token = "Pa_ueLSGAL-X3wx1ro-aWg"

struct SharedLinkTests {
    @Test func aSharedJourneyOpensFromTheAppsLinkAndFromTheWebAddress() {
        #expect(link("clack://share/\(token)") == .shared(token: token))
        #expect(link("https://\(Config.shareHost)/j/\(token)") == .shared(token: token))
        // The older free name still opens (links made before getclack.app).
        #expect(link("https://clack-garner.duckdns.org/j/\(token)") == .shared(token: token))
        #expect(link("https://\(Config.shareHost)/j/\(token)/?lang=sv") == .shared(token: token))
        #expect(link("https://\(Config.shareHost)/j/\(token)")?.tab == .trips)
    }

    @Test func aLinkThatIsNotOursOrNotWellFormedOpensNothing() {
        #expect(link("https://example.com/j/\(token)") == nil)
        #expect(link("https://\(Config.shareHost)/privacy") == nil)
        #expect(link("https://\(Config.shareHost)/j/short") == nil)
        #expect(link("https://\(Config.shareHost)/j/\(token)%2F..") == nil)
        #expect(link("clack://share") == nil)
        #expect(link("clack://share/has%20space-0123456789") == nil)
    }

    @Test func anAlertForAFollowerOpensTheSharedJourney() {
        #expect(DeepLink.forAlert(legId: "l1", journeyId: nil, kind: "delay", shareToken: token) == .shared(token: token))
        #expect(DeepLink.forAlert(legId: "l1", journeyId: nil, kind: "delay", shareToken: "bad") == .trip("l1"))
        #expect(DeepLink.forAlert(legId: "l1", journeyId: nil, kind: "delay") == .trip("l1"))
    }

    @Test func theAppsLinkComesBackFromItsUrl() {
        #expect(DeepLink.shared(token: token).url.absoluteString == "clack://share/\(token)")
        #expect(DeepLink.parse(DeepLink.shared(token: token).url) == .shared(token: token))
    }
}

/// A follower's copy: a train under way and one to change to.
private let sample = """
{
  "token": "\(token)", "expiresAt": 1793030944396,
  "summary": { "phase": "underway", "legIndex": 0, "from": "Nässjö C", "to": "Göteborg C", "departureAt": 1792749600000, "arrivalAt": 1792756800000,
               "arrivalDelayMin": 8, "arrivalPlatform": "4", "between": { "from": "Alvesta", "to": "Hässleholm C" } },
  "legs": [
    { "operator": { "id": "sj", "name": "SJ", "shortName": "SJ", "brandColor": "#1fb14f", "logoUrl": "/api/operators/sj/logo?v=1" },
      "trainNumber": "547", "serviceDate": "2026-10-25", "from": { "name": "Nässjö C", "tz": "Europe/Stockholm" }, "to": { "name": "Hässleholm C", "tz": "Europe/Stockholm" },
      "schedDep": 1792749600000, "schedArr": 1792753200000, "expDep": 1792749600000, "expArr": 1792753680000, "depPlatform": "2", "arrPlatform": "1",
      "depDelayMin": 0, "arrDelayMin": 8, "canceled": false, "departed": true, "arrived": false, "geometry": null,
      "live": { "status": "en_route", "lat": 56.9, "lon": 14.5, "bearing": null, "positionSource": "gps", "progress": 0.5, "nextStop": "Hässleholm C", "nextStopAt": 1792753680000, "updatedAt": 1792751000000 },
      "stops": [ { "name": "Nässjö C", "tz": "Europe/Stockholm", "arr": null, "dep": 1792749600000, "schedArr": null, "schedDep": 1792749600000, "platform": "2", "canceled": false, "passed": true } ] },
    { "operator": null, "trainNumber": null, "serviceDate": null, "from": { "name": "Hässleholm C", "tz": "Europe/Stockholm" }, "to": { "name": "Göteborg C", "tz": "Europe/Stockholm" },
      "schedDep": 1792754400000, "schedArr": 1792756800000, "expDep": 1792754400000, "expArr": 1792756800000, "depPlatform": null, "arrPlatform": "4",
      "depDelayMin": null, "arrDelayMin": null, "canceled": false, "departed": false, "arrived": false, "geometry": null, "live": null, "stops": [] }
  ],
  "changes": [ { "index": 0, "station": "Hässleholm C", "sameStation": true, "spareMin": 12, "arrPlatform": "1", "depPlatform": null, "status": "ok" } ]
}
"""

@MainActor
struct SharedJourneyTests {
    private func journey() throws -> SharedJourney {
        try JSONDecoder().decode(SharedJourney.self, from: Data(sample.utf8))
    }

    @Test func theCopyDecodesAndHasNothingOfTheTraveller() throws {
        let j = try journey()
        #expect(j.id == token)
        #expect(j.legs.map(\.service) == ["SJ 547", ""])
        #expect(j.summary.phase == .underway)
        #expect(j.changes.first?.status == .ok)
        // Only what a follower needs: the model has no field for a seat, a coach, a ticket or an id of the traveller's.
        let names = Mirror(reflecting: j.legs[0]).children.compactMap(\.label)
        for forbidden in ["seat", "coach", "notes", "userId", "legId", "journeyId", "ticket"] { #expect(!names.contains(forbidden)) }
    }

    @Test func theStatusIsSaidInWordsInBothLanguages() throws {
        let j = try journey()
        let en = L10n(language: .en)
        let sv = L10n(language: .sv)
        #expect(SharedLogic.statusLine(j, l10n: en, clock: .h24) == "Between Alvesta and Hässleholm C")
        #expect(SharedLogic.statusLine(j, l10n: sv, clock: .h24) == "Mellan Alvesta och Hässleholm C")
        #expect(SharedLogic.arrivalLine(j, l10n: en, clock: .h24)?.hasPrefix("Arrives Göteborg C ") == true)
        #expect(SharedLogic.arrivalLine(j, l10n: en, clock: .h24)?.hasSuffix(", platform 4") == true)
        #expect(SharedLogic.delayWord(8, l10n: en) == "8 min late")
        #expect(SharedLogic.delayWord(0, l10n: sv) == "I tid")
        #expect(SharedLogic.delayWord(nil, l10n: en) == nil)
        #expect(SharedLogic.changeTitle(j.changes[0], in: j, l10n: en) == "Change at Hässleholm C · 12 min")
    }

    @Test func followingTakesEachTrainThatHasANumberAndADay() throws {
        let bodies = SharedLogic.followBodies(try journey())
        #expect(bodies.count == 1)
        #expect(bodies[0].trainNumber == "547")
        #expect(bodies[0].serviceDate == "2026-10-25")
        #expect(bodies[0].operatorId == "sj")
        #expect(bodies[0].label == "Nässjö C → Hässleholm C")
    }

    @Test func aLinkExpiresWhenItsTimeHasCome() throws {
        let j = try journey()
        #expect(!SharedLogic.hasExpired(j, now: j.expiresAt - 1))
        #expect(SharedLogic.hasExpired(j, now: j.expiresAt))
    }
}
