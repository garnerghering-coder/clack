//
//  PassportTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

@MainActor
struct PassportTests {
    @Test func decodesARealServerResponse() throws {
        let url = try #require(Bundle.module.url(forResource: "passport", withExtension: "json", subdirectory: "Fixtures"))
        let passport = try JSONDecoder().decode(Passport.self, from: Data(contentsOf: url))
        #expect(passport.totals.trains >= 0)
        #expect(passport.map.count <= passport.totals.trains)
        #expect(passport.delays.bands.onTime >= 0)
    }

    @Test func decodesTheHomeCountryAndNewMilestoneFamilies() throws {
        let url = try #require(Bundle.module.url(forResource: "passport", withExtension: "json", subdirectory: "Fixtures"))
        let passport = try JSONDecoder().decode(Passport.self, from: Data(contentsOf: url))
        #expect(passport.home == "NO")
        #expect(passport.flavor.homeLengths != nil)
        #expect(passport.flavor.europeLengths != nil)
        #expect(passport.milestones.achieved.first?.family == .longestTrainKm)
        #expect(passport.milestones.next.contains { $0.family == .homeLength })
        // A family a newer server sends decodes as unknown rather than failing.
        #expect(passport.milestones.next.contains { $0.family == .unknown("someFutureKind") })
    }

    @Test func anOlderServerWithoutTheHomeCountryStillDecodes() throws {
        let json = #"{"earthLaps":0.1,"swedenLengths":0.5,"topRoute":null,"busiestMonth":null,"lateMinutes":0}"#
        let flavor = try JSONDecoder().decode(Passport.Flavor.self, from: Data(json.utf8))
        #expect(flavor.homeLengths == nil)
        #expect(flavor.europeLengths == nil)
    }

    @Test func everyMilestoneFamilyHasALabel() {
        let l10n = L10n(language: .en)
        func label(_ f: MilestoneFamily, _ target: Double, home: String? = nil) -> String {
            l10n.milestoneLabel(Milestone(family: f, target: target, at: nil, legId: nil, value: nil), language: .en, home: home)
        }
        #expect(label(.borderCrossings, 1) == "First border crossing")
        #expect(label(.borderCrossings, 5) == "5 border crossings")
        #expect(label(.nightTrains, 25) == "25 night trains")
        #expect(label(.longestTrainKm, 1000) == "1,000 km on one train")
        #expect(label(.hoursOnBoard, 10) == "10 hours on board")
        #expect(label(.trainTypes, 5) == "5 train types")
        #expect(label(.kindsOfTrain, 5) == "Every kind of train")
        #expect(label(.arcticCircle, 1) == "Crossed the Arctic Circle")
        #expect(label(.homeLength, 1, home: "NO") == "Once the length of Norway")
        #expect(label(.homeLength, 1) == "Once the length of Sweden")
        #expect(label(.europeLength, 1) == "Once the length of Europe")
        #expect(label(.unknown("future"), 3) == "Milestone")
        for family in MilestoneFamily.knownCases {
            #expect(!label(family, 5).hasPrefix("passport.milestone."), "missing text for \(family.rawValue)")
        }
    }

    @Test func swedishLabelsUseTheGenitive() {
        let l10n = L10n(language: .sv)
        let medal = Milestone(family: .homeLength, target: 1, at: nil, legId: nil, value: nil)
        #expect(l10n.milestoneLabel(medal, language: .sv, home: "NO") == "En gång Norges längd")
        #expect(l10n.milestoneLabel(medal, language: .sv, home: "FI") == "En gång Finlands längd")
    }

    @Test func homeCountryIsPatchedAndDecoded() throws {
        let patched = Settings.defaults.applying(SettingsPatch(homeCountry: .fi))
        #expect(patched?.homeCountry == .fi)
        #expect(Settings.defaults.homeCountry == nil)
        let body = try JSONEncoder().encode(SettingsPatch(homeCountry: .no))
        #expect(String(decoding: body, as: UTF8.self) == #"{"homeCountry":"NO"}"#)
    }
}
