//
//  DisruptionTests.swift
//  ClackTests
//
//  Ported from packages/shared/src/disruption.test.ts.
//

import Foundation
import Testing
@testable import ClackCore

struct DisruptionTests {
    let now = (Instant.parse("2026-10-22T12:00:00Z")?.timeIntervalSince1970 ?? 0) * 1000
    private var base: DisruptionInput { DisruptionInput(schedDep: now + 3_600_000) }

    @Test func staysQuietWhenNothingIsWrong() {
        let quiet = Disruption.assess(base, now: now)
        #expect(quiet.kinds.isEmpty)
        #expect(quiet.urgency == nil)
        var slight = base
        slight.arrDelayMin = 9
        #expect(Disruption.assess(slight, now: now).kinds.isEmpty)
    }

    @Test func asksYouToActOnACancellationSoonAndOnlyLetsYouKnowAboutOneDaysAway() {
        var input = base
        input.canceled = true
        let soon = Disruption.assess(input, now: now)
        #expect(soon.kinds == [.canceled])
        #expect(soon.urgency == .actNow)
        input.schedDep = now + 24 * 3_600_000
        #expect(Disruption.assess(input, now: now).urgency == .headsUp)
        input.schedDep = now + 5 * 86_400_000
        #expect(Disruption.assess(input, now: now).urgency == .info)
        input.arrived = true
        input.schedDep = now + 3_600_000
        #expect(Disruption.assess(input, now: now).urgency == .info)
    }

    @Test func readsStopsItSkipsReplacementBusesDelaysAndABrokenChange() {
        var input = base
        input.alightCanceled = true
        input.deviations = ["Ersättningsbuss Hallsberg–Örebro"]
        input.arrDelayMin = 22
        input.connection = "miss"
        let result = Disruption.assess(input, now: now)
        #expect(result.kinds == [.skipsAlight, .replacement, .delayed, .connectionMissed])
        #expect(result.urgency == .actNow)

        var late = base
        late.depDelayMin = 18
        #expect(Disruption.assess(late, now: now).urgency == .headsUp)

        var tight = base
        tight.connection = "tight"
        #expect(Disruption.assess(tight, now: now).kinds == [.connectionAtRisk])
    }

    @Test func aCancelledTrainReportsNothingElseFromTheTrainButStillTheConnection() {
        var input = base
        input.canceled = true
        input.alightCanceled = true
        input.arrDelayMin = 40
        input.connection = "broken"
        #expect(Disruption.assess(input, now: now).kinds == [.canceled, .connectionMissed])
    }

    @Test func recognisesReplacementBusWordingInBothLanguages() {
        for text in ["Buss ersätter tåg", "Bussar ersätter tåg", "Ersätts med buss", "Replacement bus service"] {
            var input = base
            input.deviations = [text]
            #expect(Disruption.assess(input, now: now).kinds == [.replacement], "\(text)")
        }
    }
}

struct PassengerRightsTests {
    @Test func usesTheEURulesFrom150KmAndAcrossBorders() {
        #expect(Disruption.passengerRights(countries: ["SE"], journeyKm: 455, arrDelayMin: 75, canceled: false) == .eu(.compensation25))
        #expect(Disruption.passengerRights(countries: ["SE"], journeyKm: 455, arrDelayMin: 130, canceled: false) == .eu(.compensation50))
        #expect(Disruption.passengerRights(countries: ["SE", "DK"], journeyKm: 40, arrDelayMin: 45, canceled: false) == .eu(nil))
        #expect(Disruption.passengerRights(countries: ["SE"], journeyKm: 455, arrDelayMin: nil, canceled: true) == .eu(.refundOrReroute))
    }

    @Test func usesSwedens20MinuteRuleForShorterTripsAndTheOperatorsTermsInNorway() {
        #expect(Disruption.passengerRights(countries: ["SE"], journeyKm: 43, arrDelayMin: 21, canceled: false) == .seShort(priceReduction: true))
        #expect(Disruption.passengerRights(countries: ["SE"], journeyKm: 43, arrDelayMin: 12, canceled: false) == .seShort(priceReduction: false))
        #expect(Disruption.passengerRights(countries: ["NO"], journeyKm: 300, arrDelayMin: 90, canceled: false) == .operator)
    }
}
