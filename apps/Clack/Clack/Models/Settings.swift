//
//  Settings.swift
//  Clack
//

import Foundation

nonisolated enum Language: OpenEnum {
    case en, sv
    case unknown(String)

    static let knownCases: [Language] = [.en, .sv]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .en: "en"
        case .sv: "sv"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum DistanceUnit: OpenEnum {
    case km, mi
    case unknown(String)

    static let knownCases: [DistanceUnit] = [.km, .mi]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .km: "km"
        case .mi: "mi"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum ClockFormat: OpenEnum {
    case h24, h12
    case unknown(String)

    static let knownCases: [ClockFormat] = [.h24, .h12]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .h24: "24h"
        case .h12: "12h"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum Co2Comparison: OpenEnum {
    case flight, car1, car2, car3, carAvg, ev1, coach
    case unknown(String)

    static let knownCases: [Co2Comparison] = [.flight, .car1, .car2, .car3, .carAvg, .ev1, .coach]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .flight: "flight"
        case .car1: "car_1"
        case .car2: "car_2"
        case .car3: "car_3"
        case .carAvg: "car_avg"
        case .ev1: "ev_1"
        case .coach: "coach"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum ThemeSetting: OpenEnum {
    case system, dark, light
    case unknown(String)

    static let knownCases: [ThemeSetting] = [.system, .dark, .light]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .system: "system"
        case .dark: "dark"
        case .light: "light"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum WalkPace: OpenEnum {
    case relaxed, normal, brisk
    case unknown(String)

    static let knownCases: [WalkPace] = [.relaxed, .normal, .brisk]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .relaxed: "relaxed"
        case .normal: "normal"
        case .brisk: "brisk"
        case .unknown(let raw): raw
        }
    }
}

/// `GET /api/settings` (docs/swift-port/API.md §2.2). The server fills missing keys with its defaults.
nonisolated struct Settings: Codable, Hashable, Sendable {
    var displayName: String
    var language: Language
    var distanceUnit: DistanceUnit
    var clock: ClockFormat
    var co2Comparison: Co2Comparison
    var includeCommuter: Bool
    var showRailNetwork: Bool
    var theme: ThemeSetting
    var walkPace: WalkPace
    var stepFree: Bool
    var heavyLuggage: Bool

    /// The server's defaults (`DEFAULT_SETTINGS`), used until the real settings have loaded.
    static let defaults = Settings(
        displayName: "",
        language: .en,
        distanceUnit: .km,
        clock: .h24,
        co2Comparison: .car1,
        includeCommuter: true,
        showRailNetwork: true,
        theme: .dark,
        walkPace: .normal,
        stepFree: false,
        heavyLuggage: false
    )
}

/// A change to the settings: only the fields that are set are sent (`PATCH /api/settings`). The server validates the
/// same way (`mergeSettings`); this checks what the app can know before sending.
nonisolated struct SettingsPatch: Encodable, Sendable, Equatable {
    var displayName: String?
    var language: Language?
    var distanceUnit: DistanceUnit?
    var clock: ClockFormat?
    var co2Comparison: Co2Comparison?
    var includeCommuter: Bool?
    var showRailNetwork: Bool?
    var theme: ThemeSetting?
    var walkPace: WalkPace?
    var stepFree: Bool?
    var heavyLuggage: Bool?
}

nonisolated extension Settings {
    /// The longest `displayName` the server accepts.
    static let displayNameMaxLength = 60

    /// What the app offers for the CO₂ comparison (owner, 2026-10-21: flying or a petrol car); the rest stay valid
    /// for old settings.
    static let co2Choices: [Co2Comparison] = [.flight, .car1]

    /// These settings with `patch` applied, as the server will merge it. A name is trimmed, and one over 60
    /// characters is refused (nil) like the server does.
    func applying(_ patch: SettingsPatch) -> Settings? {
        var next = self
        if let name = patch.displayName {
            guard name.count <= Self.displayNameMaxLength else { return nil }
            next.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let value = patch.language { next.language = value }
        if let value = patch.distanceUnit { next.distanceUnit = value }
        if let value = patch.clock { next.clock = value }
        if let value = patch.co2Comparison { next.co2Comparison = value }
        if let value = patch.includeCommuter { next.includeCommuter = value }
        if let value = patch.showRailNetwork { next.showRailNetwork = value }
        if let value = patch.theme { next.theme = value }
        if let value = patch.walkPace { next.walkPace = value }
        if let value = patch.stepFree { next.stepFree = value }
        if let value = patch.heavyLuggage { next.heavyLuggage = value }
        return next
    }
}
