//
//  Settings.swift
//  Clack
//

import Foundation

public nonisolated enum Language: OpenEnum {
    case en, sv
    case unknown(String)

    public static let knownCases: [Language] = [.en, .sv]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .en: "en"
        case .sv: "sv"
        case .unknown(let raw): raw
        }
    }
}

public nonisolated enum DistanceUnit: OpenEnum {
    case km, mi
    case unknown(String)

    public static let knownCases: [DistanceUnit] = [.km, .mi]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .km: "km"
        case .mi: "mi"
        case .unknown(let raw): raw
        }
    }
}

public nonisolated enum ClockFormat: OpenEnum {
    case h24, h12
    case unknown(String)

    public static let knownCases: [ClockFormat] = [.h24, .h12]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .h24: "24h"
        case .h12: "12h"
        case .unknown(let raw): raw
        }
    }
}

public nonisolated enum Co2Comparison: OpenEnum {
    case flight, car1, car2, car3, carAvg, ev1, coach
    case unknown(String)

    public static let knownCases: [Co2Comparison] = [.flight, .car1, .car2, .car3, .carAvg, .ev1, .coach]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
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

public nonisolated enum ThemeSetting: OpenEnum {
    case system, dark, light
    case unknown(String)

    public static let knownCases: [ThemeSetting] = [.system, .dark, .light]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .system: "system"
        case .dark: "dark"
        case .light: "light"
        case .unknown(let raw): raw
        }
    }
}

public nonisolated enum WalkPace: OpenEnum {
    case relaxed, normal, brisk
    case unknown(String)

    public static let knownCases: [WalkPace] = [.relaxed, .normal, .brisk]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .relaxed: "relaxed"
        case .normal: "normal"
        case .brisk: "brisk"
        case .unknown(let raw): raw
        }
    }
}

/// `GET /api/settings` (docs/swift-port/API.md §2.2). The server fills missing keys with its defaults.
public nonisolated struct Settings: Codable, Hashable, Sendable {
    public var displayName: String
    public var language: Language
    public var distanceUnit: DistanceUnit
    public var clock: ClockFormat
    public var co2Comparison: Co2Comparison
    public var includeCommuter: Bool
    public var showRailNetwork: Bool
    public var theme: ThemeSetting
    public var walkPace: WalkPace
    public var stepFree: Bool
    public var heavyLuggage: Bool
    /// Alerts (owner, 2026-10-23). The master switch is off until the person turns it on and allows notifications.
    public var notify: Bool
    /// Minutes before departure for the reminder: 0 (none), 30, 60, 120 or 180.
    public var notifyLeadMin: Int
    public var notifyPlatform: Bool
    /// A delay change of 5 minutes or more.
    public var notifyDelay: Bool
    public var notifyCancel: Bool
    public var notifyChange: Bool
    public var notifyGetOff: Bool
    public var notifyArrival: Bool

    /// The reminder lead times the server accepts (`LEAD_CHOICES`).
    public static let leadChoices = [0, 30, 60, 120, 180]

    /// The server's defaults (`DEFAULT_SETTINGS`), used until the real settings have loaded.
    public static let defaults = Settings(
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
        heavyLuggage: false,
        notify: false,
        notifyLeadMin: 60,
        notifyPlatform: true,
        notifyDelay: true,
        notifyCancel: true,
        notifyChange: true,
        notifyGetOff: true,
        notifyArrival: true
    )

    public init(displayName: String, language: Language, distanceUnit: DistanceUnit, clock: ClockFormat, co2Comparison: Co2Comparison, includeCommuter: Bool, showRailNetwork: Bool, theme: ThemeSetting, walkPace: WalkPace, stepFree: Bool, heavyLuggage: Bool, notify: Bool, notifyLeadMin: Int, notifyPlatform: Bool, notifyDelay: Bool, notifyCancel: Bool, notifyChange: Bool, notifyGetOff: Bool, notifyArrival: Bool) {
        self.displayName = displayName
        self.language = language
        self.distanceUnit = distanceUnit
        self.clock = clock
        self.co2Comparison = co2Comparison
        self.includeCommuter = includeCommuter
        self.showRailNetwork = showRailNetwork
        self.theme = theme
        self.walkPace = walkPace
        self.stepFree = stepFree
        self.heavyLuggage = heavyLuggage
        self.notify = notify
        self.notifyLeadMin = notifyLeadMin
        self.notifyPlatform = notifyPlatform
        self.notifyDelay = notifyDelay
        self.notifyCancel = notifyCancel
        self.notifyChange = notifyChange
        self.notifyGetOff = notifyGetOff
        self.notifyArrival = notifyArrival
    }
}

nonisolated extension Settings {
    private enum Keys: String, CodingKey {
        case displayName, language, distanceUnit, clock, co2Comparison, includeCommuter, showRailNetwork, theme, walkPace
        case stepFree, heavyLuggage, notify, notifyLeadMin, notifyPlatform, notifyDelay, notifyCancel, notifyChange
        case notifyGetOff, notifyArrival
    }

    /// A copy saved before the alert settings existed still loads: the missing ones take their defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let d = Settings.defaults
        displayName = try c.decode(String.self, forKey: .displayName)
        language = try c.decode(Language.self, forKey: .language)
        distanceUnit = try c.decode(DistanceUnit.self, forKey: .distanceUnit)
        clock = try c.decode(ClockFormat.self, forKey: .clock)
        co2Comparison = try c.decode(Co2Comparison.self, forKey: .co2Comparison)
        includeCommuter = try c.decode(Bool.self, forKey: .includeCommuter)
        showRailNetwork = try c.decode(Bool.self, forKey: .showRailNetwork)
        theme = try c.decode(ThemeSetting.self, forKey: .theme)
        walkPace = try c.decode(WalkPace.self, forKey: .walkPace)
        stepFree = try c.decode(Bool.self, forKey: .stepFree)
        heavyLuggage = try c.decode(Bool.self, forKey: .heavyLuggage)
        notify = try c.decodeIfPresent(Bool.self, forKey: .notify) ?? d.notify
        notifyLeadMin = try c.decodeIfPresent(Int.self, forKey: .notifyLeadMin) ?? d.notifyLeadMin
        notifyPlatform = try c.decodeIfPresent(Bool.self, forKey: .notifyPlatform) ?? d.notifyPlatform
        notifyDelay = try c.decodeIfPresent(Bool.self, forKey: .notifyDelay) ?? d.notifyDelay
        notifyCancel = try c.decodeIfPresent(Bool.self, forKey: .notifyCancel) ?? d.notifyCancel
        notifyChange = try c.decodeIfPresent(Bool.self, forKey: .notifyChange) ?? d.notifyChange
        notifyGetOff = try c.decodeIfPresent(Bool.self, forKey: .notifyGetOff) ?? d.notifyGetOff
        notifyArrival = try c.decodeIfPresent(Bool.self, forKey: .notifyArrival) ?? d.notifyArrival
    }
}

/// A change to the settings: only the fields that are set are sent (`PATCH /api/settings`). The server validates the
/// same way (`mergeSettings`); this checks what the app can know before sending.
public nonisolated struct SettingsPatch: Encodable, Sendable, Equatable {
    public var displayName: String?
    public var language: Language?
    public var distanceUnit: DistanceUnit?
    public var clock: ClockFormat?
    public var co2Comparison: Co2Comparison?
    public var includeCommuter: Bool?
    public var showRailNetwork: Bool?
    public var theme: ThemeSetting?
    public var walkPace: WalkPace?
    public var stepFree: Bool?
    public var heavyLuggage: Bool?
    public var notify: Bool?
    public var notifyLeadMin: Int?
    public var notifyPlatform: Bool?
    public var notifyDelay: Bool?
    public var notifyCancel: Bool?
    public var notifyChange: Bool?
    public var notifyGetOff: Bool?
    public var notifyArrival: Bool?

    public init(displayName: String? = nil, language: Language? = nil, distanceUnit: DistanceUnit? = nil, clock: ClockFormat? = nil, co2Comparison: Co2Comparison? = nil, includeCommuter: Bool? = nil, showRailNetwork: Bool? = nil, theme: ThemeSetting? = nil, walkPace: WalkPace? = nil, stepFree: Bool? = nil, heavyLuggage: Bool? = nil, notify: Bool? = nil, notifyLeadMin: Int? = nil, notifyPlatform: Bool? = nil, notifyDelay: Bool? = nil, notifyCancel: Bool? = nil, notifyChange: Bool? = nil, notifyGetOff: Bool? = nil, notifyArrival: Bool? = nil) {
        self.displayName = displayName
        self.language = language
        self.distanceUnit = distanceUnit
        self.clock = clock
        self.co2Comparison = co2Comparison
        self.includeCommuter = includeCommuter
        self.showRailNetwork = showRailNetwork
        self.theme = theme
        self.walkPace = walkPace
        self.stepFree = stepFree
        self.heavyLuggage = heavyLuggage
        self.notify = notify
        self.notifyLeadMin = notifyLeadMin
        self.notifyPlatform = notifyPlatform
        self.notifyDelay = notifyDelay
        self.notifyCancel = notifyCancel
        self.notifyChange = notifyChange
        self.notifyGetOff = notifyGetOff
        self.notifyArrival = notifyArrival
    }
}

nonisolated extension Settings {
    /// The longest `displayName` the server accepts.
    public static let displayNameMaxLength = 60

    /// What the app offers for the CO₂ comparison (owner, 2026-10-21: flying or a petrol car); the rest stay valid
    /// for old settings.
    public static let co2Choices: [Co2Comparison] = [.flight, .car1]

    /// These settings with `patch` applied, as the server will merge it. A name is trimmed, and one over 60
    /// characters is refused (nil) like the server does.
    public func applying(_ patch: SettingsPatch) -> Settings? {
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
        if let value = patch.notify { next.notify = value }
        if let value = patch.notifyLeadMin {
            guard Self.leadChoices.contains(value) else { return nil }
            next.notifyLeadMin = value
        }
        if let value = patch.notifyPlatform { next.notifyPlatform = value }
        if let value = patch.notifyDelay { next.notifyDelay = value }
        if let value = patch.notifyCancel { next.notifyCancel = value }
        if let value = patch.notifyChange { next.notifyChange = value }
        if let value = patch.notifyGetOff { next.notifyGetOff = value }
        if let value = patch.notifyArrival { next.notifyArrival = value }
        return next
    }
}
