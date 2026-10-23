//
//  Passport.swift
//  Clack
//

import Foundation

nonisolated enum MilestoneFamily: OpenEnum {
    case journeys, distanceKm, stations, operators, countries, borderCrossings, nightTrains
    case unknown(String)

    static let knownCases: [MilestoneFamily] = [.journeys, .distanceKm, .stations, .operators, .countries, .borderCrossings, .nightTrains]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .journeys: "journeys"
        case .distanceKm: "distanceKm"
        case .stations: "stations"
        case .operators: "operators"
        case .countries: "countries"
        case .borderCrossings: "borderCrossings"
        case .nightTrains: "nightTrains"
        case .unknown(let raw): raw
        }
    }
}

/// A Passport milestone: achieved (`at`, `legId`) or upcoming (`value`, how far along). Targets per family are in
/// docs/swift-port/API.md §2.10.
nonisolated struct Milestone: Codable, Hashable, Sendable {
    let family: MilestoneFamily
    let target: Double
    let at: Instant?
    let legId: String?
    let value: Double?
}

/// What a trip did for your Passport (`GET /api/legs/:id/progress`); `counted` is false while it doesn't count.
nonisolated struct TripProgress: Codable, Hashable, Sendable {
    nonisolated struct Moved: Codable, Hashable, Sendable {
        let family: MilestoneFamily
        let before: Double
        let after: Double
        let target: Double
    }

    nonisolated struct Firsts: Codable, Hashable, Sendable {
        /// Station names.
        let stations: [String]
        /// An operator id.
        let `operator`: String?
        /// Country codes.
        let countries: [String]
    }

    let counted: Bool
    let unlocked: [Milestone]
    let moved: [Moved]
    let firsts: Firsts?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        counted = try c.decode(Bool.self, forKey: .counted)
        unlocked = try c.decodeIfPresent([Milestone].self, forKey: .unlocked) ?? []
        moved = try c.decodeIfPresent([Moved].self, forKey: .moved) ?? []
        firsts = try c.decodeIfPresent(Firsts.self, forKey: .firsts)
    }

    private enum CodingKeys: String, CodingKey { case counted, unlocked, moved, firsts }
}

/// One warning on an upcoming trip (`GET /api/legs/:id/risk`), keyed by `kind`.
nonisolated enum RiskWarning: Codable, Hashable, Sendable {
    case routeNow(trains: Int, late: Int, canceled: Int, medianMin: Double, windowMin: Double)
    case stationNow(station: String, trains: Int, late: Int, medianMin: Double, windowMin: Double)
    case ahead(station: String, toward: String, trains: Int, late: Int, delays: [Int], windowMin: Double)
    case trainPattern(station: String, days: Int, lateDays: Int, medianMin: Double)
    case unknown(String)

    private enum Keys: String, CodingKey {
        case kind, trains, late, canceled, medianMin, windowMin, station, toward, delays, days, lateDays
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "route_now":
            self = .routeNow(
                trains: try c.decode(Int.self, forKey: .trains), late: try c.decode(Int.self, forKey: .late),
                canceled: try c.decode(Int.self, forKey: .canceled), medianMin: try c.decode(Double.self, forKey: .medianMin),
                windowMin: try c.decode(Double.self, forKey: .windowMin)
            )
        case "station_now":
            self = .stationNow(
                station: try c.decode(String.self, forKey: .station), trains: try c.decode(Int.self, forKey: .trains),
                late: try c.decode(Int.self, forKey: .late), medianMin: try c.decode(Double.self, forKey: .medianMin),
                windowMin: try c.decode(Double.self, forKey: .windowMin)
            )
        case "ahead":
            self = .ahead(
                station: try c.decode(String.self, forKey: .station), toward: try c.decode(String.self, forKey: .toward),
                trains: try c.decode(Int.self, forKey: .trains), late: try c.decode(Int.self, forKey: .late),
                delays: try c.decode([Int].self, forKey: .delays), windowMin: try c.decode(Double.self, forKey: .windowMin)
            )
        case "train_pattern":
            self = .trainPattern(
                station: try c.decode(String.self, forKey: .station), days: try c.decode(Int.self, forKey: .days),
                lateDays: try c.decode(Int.self, forKey: .lateDays), medianMin: try c.decode(Double.self, forKey: .medianMin)
            )
        default:
            self = .unknown(kind)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(kind, forKey: .kind)
    }

    /// The `kind` string.
    var kind: String {
        switch self {
        case .routeNow: "route_now"
        case .stationNow: "station_now"
        case .ahead: "ahead"
        case .trainPattern: "train_pattern"
        case .unknown(let raw): raw
        }
    }
}

nonisolated struct LegRisk: Codable, Hashable, Sendable {
    let checkedAt: Instant
    /// What could not be checked: `too_far`, `abroad`, `no_live_data`, `no_history`.
    let limits: [String]
    let warnings: [RiskWarning]
}
