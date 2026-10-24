//
//  L10nTests.swift
//  ClackTests
//

import Foundation
import Testing
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

    /// The real catalog in the package resources: it loads in both languages, plurals follow the count, and every key
    /// has English and Swedish text with the same placeholders.
    @Test func catalogLoadsInBothLanguages() throws {
        let l10n = L10n()
        #expect(l10n.t("trips.title") == "Trips")
        #expect(l10n.t("passport.trainsCount", count: 1) == "1 train")
        #expect(l10n.t("passport.trainsCount", count: 12) == "12 trains")
        #expect(l10n.t("passport.reviewBanner", count: 1).hasPrefix("1 trip "))
        #expect(l10n.t("passport.flavor.earthPct", ["pct": "6"]) == "6% of the way around the Earth")
        l10n.language = .sv
        #expect(l10n.t("trips.title") != "trips.title")
        #expect(l10n.t("trips.title") != "Trips")
        #expect(l10n.t("passport.trainsCount", count: 3).hasPrefix("3 "))
    }

    @Test func catalogHasEveryKeyInBothLanguages() throws {
        // The source file (the built bundle has only the compiled strings).
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/ClackCore/Resources/Localizable.xcstrings")
        let catalog = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        #expect(strings.count > 700)
        let placeholders = { (s: String) in s.matches(of: #/\{\{(\w+)\}\}|%lld/#).map { String($0.output.0) }.sorted() }
        for (key, entry) in strings {
            let loc = entry["localizations"] as? [String: [String: Any]] ?? [:]
            func texts(_ code: String) -> [String] {
                if let unit = loc[code]?["stringUnit"] as? [String: Any], let v = unit["value"] as? String { return [v] }
                let plural = (loc[code]?["variations"] as? [String: Any])?["plural"] as? [String: [String: Any]] ?? [:]
                return ["one", "other"].compactMap { (plural[$0]?["stringUnit"] as? [String: Any])?["value"] as? String }
            }
            let en = texts("en"), sv = texts("sv")
            #expect(!en.isEmpty && en.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }, "\(key) en")
            #expect(sv.count == en.count, "\(key) sv")
            if let e = en.last, let s = sv.last { #expect(placeholders(e) == placeholders(s), "\(key) placeholders") }
        }
    }
}
