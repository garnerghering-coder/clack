//
//  L10n.swift
//  Clack
//

import Foundation
import Observation

/// The app's texts: the web app's `en.json` and `sv.json`, same keys (docs/SWIFT_PORT.md B5).
/// Never write user-facing text in Swift; add a key to both JSON files and run `scripts/ios/sync_assets.py`.
@Observable
final class L10n {
    /// The language setting from the server (`en` default, not the phone's language). Views update when it changes.
    var language: Language

    /// Flattened tables: dot path ("trips.title") to text, per language code.
    private let tables: [String: [String: String]]

    init(language: Language = .en, tables: [String: [String: String]]) {
        self.language = language
        self.tables = tables
    }

    /// Loads `en.json` and `sv.json` from the app bundle.
    convenience init(language: Language = .en, bundle: Bundle = .main) {
        var tables: [String: [String: String]] = [:]
        for code in ["en", "sv"] {
            guard let url = bundle.url(forResource: code, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data) else { continue }
            tables[code] = Self.flatten(object)
        }
        self.init(language: language, tables: tables)
    }

    /// `{ "a": { "b": "x" } }` becomes `["a.b": "x"]`.
    static func flatten(_ object: Any, prefix: String = "") -> [String: String] {
        if let text = object as? String { return prefix.isEmpty ? [:] : [prefix: text] }
        guard let dictionary = object as? [String: Any] else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in dictionary {
            result.merge(flatten(value, prefix: prefix.isEmpty ? key : "\(prefix).\(key)")) { first, _ in first }
        }
        return result
    }

    /// The text for `key` with every `{{name}}` replaced. A missing key falls back to English, then to the key itself.
    func t(_ key: String, _ values: [String: String] = [:]) -> String {
        interpolate(lookup(key), values)
    }

    /// The plural form: `key_one` when `count` is 1, else `key_other`; `count` is also a `{{count}}` value.
    func t(_ key: String, count: Int, _ values: [String: String] = [:]) -> String {
        let suffixed = "\(key)_\(count == 1 ? "one" : "other")"
        var all = values
        all["count"] = String(count)
        return interpolate(lookup(suffixed, fallbackKey: key), all)
    }

    /// Tries the language, then English, for `key`; then the same for `fallbackKey` (the bare key behind a plural).
    private func lookup(_ key: String, fallbackKey: String? = nil) -> String {
        for candidate in [key] + (fallbackKey.map { [$0] } ?? []) {
            for code in [language.rawValue, "en"] {
                if let text = tables[code]?[candidate] { return text }
            }
        }
        return fallbackKey ?? key
    }

    private func interpolate(_ text: String, _ values: [String: String]) -> String {
        guard text.contains("{{") else { return text }
        var result = text
        for (name, value) in values {
            result = result.replacingOccurrences(of: "{{\(name)}}", with: value)
        }
        return result
    }
}
