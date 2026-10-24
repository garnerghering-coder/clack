//
//  L10n.swift
//  Clack
//

import Foundation
import Observation

/// The app's texts, from the String Catalog `Resources/Localizable.xcstrings` (English and Swedish). Keys are dot paths
/// ("trips.title"); `{{name}}` placeholders are filled in here, and plural keys use the catalog's plural variations.
/// Never write user-facing text in Swift: add the key to the catalog, in both languages.
@MainActor
@Observable
public final class L10n {
    /// The language setting from the server (`en` default, not the phone's language). Views update when it changes.
    public var language: Language

    /// Where each language's compiled strings are (`en.lproj`, `sv.lproj` in this package's resources).
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
        for code in ["en", "sv"] {
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
            let suffixed = "\(key)_\(count == 1 ? "one" : "other")"
            return interpolate(lookup(suffixed) ?? lookup(key) ?? key, all)
        }
        guard let format = lookup(key) else { return key }
        guard format.contains("%") else { return interpolate(format, all) }
        let code = bundles[language.rawValue] != nil ? language.rawValue : "en"
        return interpolate(String(format: format, locale: Locale(identifier: code), count), all)
    }

    /// Tries the language, then English.
    private func lookup(_ key: String) -> String? {
        for code in [language.rawValue, "en"] {
            if let text = tables[code]?[key] { return text }
            if let bundle = bundles[code] {
                let text = bundle.localizedString(forKey: key, value: Self.missing, table: nil)
                if text != Self.missing { return text }
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
