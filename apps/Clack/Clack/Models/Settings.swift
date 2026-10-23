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
