//
//  L10nTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack
@testable import ClackCore

@MainActor
struct L10nTests {
    static let tables: [String: [String: String]] = [
        "en": [
            "trips.title": "Trips",
            "trips.platform": "Platform {{platform}}",
            "trips.route": "{{from}} to {{to}}",
            "trips.both": "{{x}} and {{x}}",
            "add.stopsBetween_one": "{{count}} stop",
            "add.stopsBetween_other": "{{count}} stops",
            "only.english": "Only in English",
        ],
        "sv": [
            "trips.title": "Resor",
            "trips.platform": "Spår {{platform}}",
            "add.stopsBetween_one": "{{count}} stopp",
            "add.stopsBetween_other": "{{count}} stopp",
        ],
    ]

    @Test func looksUpDotPaths() {
        let l10n = L10n(language: .en, tables: Self.tables)
        #expect(l10n.t("trips.title") == "Trips")
    }

    @Test func interpolatesValues() {
        let l10n = L10n(language: .en, tables: Self.tables)
        #expect(l10n.t("trips.platform", ["platform": "17b"]) == "Platform 17b")
        #expect(l10n.t("trips.route", ["from": "Stockholm C", "to": "Göteborg C"]) == "Stockholm C to Göteborg C")
    }

    @Test func repeatedPlaceholderIsReplacedEverywhere() {
        let l10n = L10n(language: .en, tables: Self.tables)
        #expect(l10n.t("trips.both", ["x": "A"]) == "A and A")
    }

    @Test func missingValueLeavesPlaceholder() {
        let l10n = L10n(language: .en, tables: Self.tables)
        #expect(l10n.t("trips.platform") == "Platform {{platform}}")
    }

    @Test func pluralOneAndOther() {
        let l10n = L10n(language: .en, tables: Self.tables)
        #expect(l10n.t("add.stopsBetween", count: 1) == "1 stop")
        #expect(l10n.t("add.stopsBetween", count: 3) == "3 stops")
        #expect(l10n.t("add.stopsBetween", count: 0) == "0 stops")
    }

    @Test func swedishTextsAndSwitchingLiveChangesThem() {
        let l10n = L10n(language: .en, tables: Self.tables)
        #expect(l10n.t("trips.title") == "Trips")
        l10n.language = .sv
        #expect(l10n.t("trips.title") == "Resor")
        #expect(l10n.t("trips.platform", ["platform": "3"]) == "Spår 3")
        #expect(l10n.t("add.stopsBetween", count: 2) == "2 stopp")
    }

    @Test func missingKeyFallsBackToEnglishThenToTheKey() {
        let l10n = L10n(language: .sv, tables: Self.tables)
        #expect(l10n.t("only.english") == "Only in English")
        #expect(l10n.t("no.such.key") == "no.such.key")
    }

    @Test func pluralWithoutPluralKeysFallsBackToBareKey() {
        let l10n = L10n(language: .en, tables: Self.tables)
        #expect(l10n.t("trips.title", count: 2) == "Trips")
        #expect(l10n.t("no.such.key", count: 2) == "no.such.key")
    }

    @Test func flattenTurnsNestedJSONIntoDotPaths() throws {
        let json = #"{"a":{"b":"x","c":{"d":"y"}},"e":"z"}"#
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        #expect(L10n.flatten(object) == ["a.b": "x", "a.c.d": "y", "e": "z"])
    }

    /// The real files the sync script puts in the package resources: both load, and they have the same keys.
    @Test func bundledFilesLoadWithTheSameKeys() throws {
        let en = try loadBundled("en")
        let sv = try loadBundled("sv")
        #expect(en.count > 700)
        #expect(Set(en.keys) == Set(sv.keys))
        let l10n = L10n()
        #expect(l10n.t("trips.title") == "Trips")
        l10n.language = .sv
        #expect(l10n.t("trips.title") != "trips.title")
        #expect(l10n.t("trips.title") != "Trips")
    }

    private func loadBundled(_ code: String) throws -> [String: String] {
        let url = try #require(L10n.resources.url(forResource: code, withExtension: "json"))
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return L10n.flatten(object)
    }
}
