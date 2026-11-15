//
//  LanguagesTests.swift
//  ClackTests
//
//  The eight app languages (build 86): codes, the phone's default, plurals, locales and which source text is shown.
//

import Foundation
import Testing
@testable import ClackCore

@MainActor
struct LanguagesTests {
    @Test func knowsTheEightLanguagesInSettingsOrderAndKeepsUnknownCodes() throws {
        #expect(Language.knownCases.map(\.rawValue) == ["en", "sv", "da", "nb", "fi", "de", "pl", "fr"])
        let decoded = try JSONDecoder().decode([Language].self, from: Data(#"["pl","nb","es"]"#.utf8))
        #expect(decoded == [.pl, .nb, .unknown("es")])
        #expect(String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self) == #"["pl","nb","es"]"#)
    }

    @Test func treatsTheFeedsNorwegianAsBokmal() {
        #expect(Language.same("no", "nb"))
        #expect(Language.same("nob", "nb"))
        #expect(!Language.same("da", "nb"))
        #expect(Language.known("no") == .nb)
        #expect(Language.known("es") == nil)
    }

    @Test func startsInThePhonesFirstLanguageTheAppHas() {
        #expect(Language.preferred(["da-DK", "en-GB"]) == .da)
        #expect(Language.preferred(["nb-NO"]) == .nb)
        #expect(Language.preferred(["no"]) == .nb)
        #expect(Language.preferred(["es-ES", "fr-CA", "en"]) == .fr)
        #expect(Language.preferred(["pl_PL"]) == .pl)
        #expect(Language.preferred(["es-ES", "it"]) == nil)
        #expect(Language.preferred([]) == nil)
    }

    @Test func pluralCategoriesFollowEachLanguage() {
        let pl = [1, 2, 4, 5, 12, 14, 21, 22, 24, 25, 0].map { L10n.pluralCategory($0, language: .pl) }
        #expect(pl == ["one", "few", "few", "many", "many", "many", "many", "few", "few", "many", "many"])
        #expect(L10n.pluralCategory(0, language: .fr) == "one")
        #expect(L10n.pluralCategory(2, language: .fr) == "other")
        #expect(L10n.pluralCategory(1, language: .de) == "one")
        #expect(L10n.pluralCategory(0, language: .fi) == "other")
    }

    @Test func polishPluralsFromTables() {
        let l10n = L10n(language: .pl, tables: [
            "en": ["stops_one": "{{count}} stop", "stops_other": "{{count}} stops"],
            "pl": ["stops_one": "{{count}} przystanek", "stops_few": "{{count}} przystanki", "stops_many": "{{count}} przystanków", "stops_other": "{{count}} przystanku"],
        ])
        #expect(l10n.t("stops", count: 1) == "1 przystanek")
        #expect(l10n.t("stops", count: 2) == "2 przystanki")
        #expect(l10n.t("stops", count: 5) == "5 przystanków")
        #expect(l10n.t("stops", count: 22) == "22 przystanki")
        #expect(l10n.t("stops", count: 12) == "12 przystanków")
    }

    /// The compiled catalog's plural formats (a `.stringsdict` per `.lproj`) pick by the language's own rules.
    @Test func polishPluralsFromABundle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("clack-l10n-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        func write(_ code: String, _ forms: [String: String]) throws {
            let dir = root.appendingPathComponent("\(code).lproj")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var rule: [String: String] = ["NSStringFormatSpecTypeKey": "NSStringPluralRuleType", "NSStringFormatValueTypeKey": "lld"]
            rule.merge(forms) { $1 }
            let dict: [String: Any] = ["stops": ["NSStringLocalizedFormatKey": "%#@n@", "n": rule]]
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
            try data.write(to: dir.appendingPathComponent("Localizable.stringsdict"))
            try Data("\"plain\" = \"\(code) plain\";".utf8).write(to: dir.appendingPathComponent("Localizable.strings"))
        }
        try write("en", ["one": "%lld stop", "other": "%lld stops"])
        try write("pl", ["one": "%lld przystanek", "few": "%lld przystanki", "many": "%lld przystanków", "other": "%lld przystanku"])
        let bundle = try #require(Bundle(path: root.path))

        let pl = L10n(language: .pl, bundle: bundle)
        #expect(pl.t("stops", count: 1) == "1 przystanek")
        #expect(pl.t("stops", count: 2) == "2 przystanki")
        #expect(pl.t("stops", count: 5) == "5 przystanków")
        #expect(pl.t("stops", count: 22) == "22 przystanki")
        #expect(pl.t("plain") == "pl plain")

        // A language with no .lproj yet reads English, with English rules.
        let de = L10n(language: .de, bundle: bundle)
        #expect(de.t("stops", count: 1) == "1 stop")
        #expect(de.t("stops", count: 5) == "5 stops")
        #expect(de.t("plain") == "en plain")
    }

    @Test func theRealCatalogFallsBackToEnglishForEveryNewLanguage() {
        // The language's own text where translated, else English; never the key, and plurals work in each.
        for language in Language.knownCases {
            let l10n = L10n(language: language)
            #expect(l10n.t("trips.title") != "trips.title", "\(language.rawValue)")
            #expect(l10n.t("settings.language") != "settings.language", "\(language.rawValue)")
            #expect(l10n.t("journey.label", count: 3).contains("3"), "\(language.rawValue)")
        }
    }

    @Test func formatsInEachLanguagesLocale() {
        #expect(Format.localeIdentifier(.en) == "en_GB")
        #expect(Format.localeIdentifier(.sv) == "sv_SE")
        #expect(Format.localeIdentifier(.nb) == "nb_NO")
        #expect(Format.localeIdentifier(.da) == "da_DK")
        #expect(Format.localeIdentifier(.fi) == "fi_FI")
        #expect(Format.localeIdentifier(.de) == "de_DE")
        #expect(Format.localeIdentifier(.pl) == "pl_PL")
        #expect(Format.localeIdentifier(.fr) == "fr_FR")
        #expect(Format.localeIdentifier(.unknown("es")) == "en_GB")
        #expect(Format.duration(168, language: .en) == "2h 48m")
        #expect(Format.duration(168, language: .sv) == "2 h 48 min")
        for language in [Language.da, .nb, .fi, .de, .pl, .fr] {
            let text = Format.duration(168, language: language)
            #expect(text.contains("2") && text.contains("48"), "\(language.rawValue): \(text)")
        }
    }

    @Test func disruptionWordsInTheReadersLanguageThenEnglish() {
        func line(_ title: NetworkStatus.Disruption.Title, _ language: Language) -> CauseLine? {
            NetworkStatus.Disruption(id: "x", country: "NO", kind: .works, title: title, places: [], from: nil, to: nil, lat: 0, lon: 0, lines: [], source: "entur").text(language)
        }
        let norway = NetworkStatus.Disruption.Title(en: "Track work", no: "Sporarbeid")
        #expect(line(norway, .nb)?.text == "Sporarbeid")
        #expect(line(norway, .nb)?.lang == "no")
        #expect(line(norway, .sv)?.text == "Track work")
        #expect(line(norway, .pl)?.lang == "en")
        let denmark = NetworkStatus.Disruption.Title(da: "Sporarbejde")
        #expect(line(denmark, .da)?.lang == "da")
        #expect(line(denmark, .fr)?.text == "Sporarbejde")
        let sweden = NetworkStatus.Disruption.Title(sv: "Banarbete", en: "Track work")
        #expect(line(sweden, .sv)?.text == "Banarbete")
        #expect(line(sweden, .de)?.text == "Track work")
        #expect(line(sweden, .unknown("es"))?.lang == "en")
    }
}
