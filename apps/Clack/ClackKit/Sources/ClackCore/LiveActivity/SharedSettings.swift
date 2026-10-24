//
//  SharedSettings.swift
//  Clack
//

import Foundation

/// The app settings the trip card (drawn by the widget extension, which can't read the app's own settings) needs: the
/// language and the clock. The app writes them into the App Group's defaults; without the group, the card falls back
/// to the app's defaults (English, 24-hour clock).
public nonisolated enum SharedSettings {
    static let languageKey = "clack.language"
    static let clockKey = "clack.clock"

    /// The App Group's defaults (nil without the group).
    public static var defaults: UserDefaults? { UserDefaults(suiteName: WidgetSnapshot.groupId) }

    public static func language(_ defaults: UserDefaults? = SharedSettings.defaults) -> Language {
        known(defaults?.string(forKey: languageKey)) ?? .en
    }

    public static func clock(_ defaults: UserDefaults? = SharedSettings.defaults) -> ClockFormat {
        known(defaults?.string(forKey: clockKey)) ?? .h24
    }

    /// Writes the settings, only when they changed.
    public static func write(language: Language, clock: ClockFormat, to defaults: UserDefaults? = SharedSettings.defaults) {
        guard let defaults else { return }
        for (key, value) in [(languageKey, language.rawValue), (clockKey, clock.rawValue)] where defaults.string(forKey: key) != value {
            defaults.set(value, forKey: key)
        }
    }

    private static func known<T: OpenEnum>(_ raw: String?) -> T? {
        guard let raw else { return nil }
        return T.knownCases.first { $0.rawValue == raw }
    }
}
