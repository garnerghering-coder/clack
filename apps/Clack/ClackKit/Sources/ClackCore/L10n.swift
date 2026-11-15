//
//  L10n.swift
//  Clack
//

import Foundation
import Observation

/// The app's texts, from the String Catalog `Resources/Localizable.xcstrings` (one `.lproj` per `Language`: English,
/// Swedish, Danish, Norwegian Bokmål, Finnish, German, Polish, French). Keys are dot paths ("trips.title");
/// `{{name}}` placeholders are filled in here, and plural keys use the catalog's plural variations, chosen by each
/// language's own rules (Polish has one, few, many and other). A text not yet in a language falls back to English.
/// Never write user-facing text in Swift: add the key to the catalog, in English and Swedish at least.
@MainActor
@Observable
public final class L10n {
    /// The language setting from the server (a new install starts in the phone's language when the app has it, else
    /// English). Views update when it changes.
    public var language: Language

    /// Where each language's compiled strings are (`en.lproj`, `sv.lproj`, … in this package's resources). A language
    /// whose `.lproj` isn't there yet (no texts translated) reads English.
    private let bundles: [String: Bundle]
    /// Texts given directly (tests): dot path to text, per language code. Looked up before the bundles.
    private let tables: [String: [String: String]]

    public init(language: Language = .en, tables: [String: [String: String]]) {
        self.language = language
        self.tables = tables
        self.bundles = [:]
    }

    /// The bundle the catalog ships in (this package's resources).
    public nonisolated static var resources: Bundle { .module }

    /// Reads the catalog from this package's resources unless told otherwise.
    public init(language: Language = .en, bundle: Bundle = L10n.resources) {
        self.language = language
        self.tables = [:]
        var bundles: [String: Bundle] = [:]
        for code in Language.knownCases.map(\.rawValue) {
            if let path = bundle.path(forResource: code, ofType: "lproj"), let b = Bundle(path: path) { bundles[code] = b }
        }
        self.bundles = bundles
    }

    /// The text for `key` with every `{{name}}` replaced. A missing key falls back to English, then to the key itself.
    public func t(_ key: String, _ values: [String: String] = [:]) -> String {
        interpolate(lookup(key) ?? key, values)
    }

    /// The plural form for `count` (the catalog's plural variations, by the language's rules); `count` is also a
    /// `{{count}}` value. A key without plural forms is looked up as it is.
    public func t(_ key: String, count: Int, _ values: [String: String] = [:]) -> String {
        var all = values
        all["count"] = String(count)
        if let table = tables[language.rawValue] ?? tables["en"], table["\(key)_one"] != nil || table["\(key)_other"] != nil {
            let category = Self.pluralCategory(count, language: language)
            return interpolate(lookup("\(key)_\(category)") ?? lookup("\(key)_other") ?? lookup(key) ?? key, all)
        }
        guard let (format, code) = found(key) else { return key }
        guard format.contains("%") else { return interpolate(format, all) }
        // The compiled catalog's plural format picks its variation by the locale's rules, so the locale is the
        // language the text came from (English rules for an English fallback, Polish rules for Polish).
        return interpolate(String(format: format, locale: Locale(identifier: code), count), all)
    }

    /// The CLDR plural category of a whole number in `language` (used for texts given directly; the bundle's plural
    /// formats get the same from Foundation). English, Swedish, Danish, Norwegian, Finnish and German: "one" for 1;
    /// French: "one" for 0 and 1; Polish: "one" for 1, "few" for 2–4, 22–24, … (not 12–14), "many" for the rest.
    public nonisolated static func pluralCategory(_ count: Int, language: Language) -> String {
        let n = abs(count)
        switch language {
        case .fr:
            return n <= 1 ? "one" : "other"
        case .pl:
            if n == 1 { return "one" }
            if (2...4).contains(n % 10), !(12...14).contains(n % 100) { return "few" }
            return "many"
        default:
            return n == 1 ? "one" : "other"
        }
    }

    /// Tries the language, then English.
    private func lookup(_ key: String) -> String? { found(key)?.text }

    /// The text and the language code it was found in: the language, then English.
    private func found(_ key: String) -> (text: String, code: String)? {
        for code in [language.rawValue, "en"] {
            if let text = tables[code]?[key] { return (text, code) }
            if let bundle = bundles[code] {
                let text = bundle.localizedString(forKey: key, value: Self.missing, table: nil)
                if text != Self.missing { return (text, code) }
            }
        }
        return nil
    }

    private static let missing = "\u{1}missing"

    private func interpolate(_ text: String, _ values: [String: String]) -> String {
        guard text.contains("{{") else { return text }
        var result = text
        for (name, value) in values {
            result = result.replacingOccurrences(of: "{{\(name)}}", with: value)
        }
        return result
    }
}
