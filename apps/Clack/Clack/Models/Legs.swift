//
//  Legs.swift
//  Clack
//

import Foundation

nonisolated enum LegStatus: OpenEnum {
    case planned, completed, snapshotted
    case unknown(String)

    static let knownCases: [LegStatus] = [.planned, .completed, .snapshotted]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .planned: "planned"
        case .completed: "completed"
        case .snapshotted: "snapshotted"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum DataQuality: OpenEnum {
    case full, partial, scheduledOnly, manual
    case unknown(String)

    static let knownCases: [DataQuality] = [.full, .partial, .scheduledOnly, .manual]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .full: "full"
        case .partial: "partial"
        case .scheduledOnly: "scheduled_only"
        case .manual: "manual"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum TrainTypeSource: OpenEnum {
    case typical, composition, user
    case unknown(String)

    static let knownCases: [TrainTypeSource] = [.typical, .composition, .user]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .typical: "typical"
        case .composition: "composition"
        case .user: "user"
        case .unknown(let raw): raw
        }
    }
}

/// Whether the rider took the train: only `auto` and `confirmed` count in the Passport.
nonisolated enum Ride: OpenEnum {
    case pending, auto, confirmed, review, notTaken
    case unknown(String)

    static let knownCases: [Ride] = [.pending, .auto, .confirmed, .review, .notTaken]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .pending: "pending"
        case .auto: "auto"
        case .confirmed: "confirmed"
        case .review: "review"
        case .notTaken: "not_taken"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum LiveStatus: OpenEnum {
    case scheduled, boarding, enRoute, atStop, arrived, cancelled
    case unknown(String)

    static let knownCases: [LiveStatus] = [.scheduled, .boarding, .enRoute, .atStop, .arrived, .cancelled]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .scheduled: "scheduled"
        case .boarding: "boarding"
        case .enRoute: "en_route"
        case .atStop: "at_stop"
        case .arrived: "arrived"
        case .cancelled: "cancelled"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum PositionSource: OpenEnum {
    case gps, estimated
    case unknown(String)

    static let knownCases: [PositionSource] = [.gps, .estimated]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .gps: "gps"
        case .estimated: "estimated"
        case .unknown(let raw): raw
        }
    }
}

/// What Trafikverket says about one departure: catering and "no toilet / no bikes" notices.
/// `catering` is `bistro`, `cafe`, `kiosk`, `refreshments` or `restaurant`; notices are `no_catering`, `no_toilet`,
/// `no_bikes`, `no_first_class`, `changed_type`. Kept as text so a new value can't break decoding.
nonisolated struct OnboardFacts: Codable, Hashable, Sendable {
    let catering: String?
    /// Where the café is, when the coach order says ("B").
    let cateringCar: String?
    let sleeper: Bool
    let notices: [String]
}

/// A station as a leg refers to it.
nonisolated struct StationRef: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let code: String?
    /// ISO 3166 alpha-2: `SE`, `NO`, `DK`, ...
    let country: String
    /// IANA zone, e.g. `Europe/Stockholm`. Every time shown is formatted in its station's zone.
    let tz: String
}

/// The operator attached to a leg: the operators-table row plus its logo (no ticket fields).
nonisolated struct LegOperator: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let shortName: String
    let company: String?
    let country: String
    let brandColor: String
    let logoPath: String?
    let logoUrl: String?
}

/// Where a boarding or alighting was seen, in epoch ms.
nonisolated struct BorderEvidence: Codable, Hashable, Sendable {
    nonisolated struct Sighting: Codable, Hashable, Sendable {
        let stationId: String
        let at: Instant
    }

    let board: Sighting?
    let alight: Sighting?
}

/// The REST form of live state (times are ISO strings here; over SSE they are ms. `Instant` takes both).
nonisolated struct LiveStateRow: Codable, Hashable, Sendable {
    let legId: String?
    let updatedAt: Instant
    let status: LiveStatus
    let lat: Double?
    let lon: Double?
    let bearing: Double?
    let speedKmh: Double?
    let positionSource: PositionSource?
    let positionAt: Instant?
    /// 0 to 1, the share of the ridden route travelled.
    let progress: Double?
    let prevStopId: String?
    let nextStopId: String?
    let eta: Instant?
    let arrivalEta: Instant?
    let arrivalDelayMin: Int?
    let reportedAt: Instant?
}

/// One saved train ride, as `GET /api/legs` sends it (docs/swift-port/API.md §2.6).
nonisolated struct Leg: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let status: LegStatus
    let dataQuality: DataQuality
    let trainNumber: String?
    /// `intercity`, `regional`, `commuter`, `heritage`, `night`, and for manual trips `high_speed`.
    let category: String?
    /// YYYY-MM-DD.
    let serviceDate: String?
    let schedDep: Instant?
    let schedArr: Instant?
    let actualDep: Instant?
    let actualArr: Instant?
    /// Whole minutes, negative = early.
    let depDelayMin: Int?
    let arrDelayMin: Int?
    let depPlatform: String?
    let arrPlatform: String?
    let canceled: Bool
    /// Metres, along the track once routed.
    let distanceM: Double?
    let isEstimatedGeometry: Bool
    let trainType: String?
    let trainTypeSource: TrainTypeSource?
    let onboard: OnboardFacts?
    let countryCodes: [String]
    let journeyId: String?
    /// Nil for trips added by hand.
    let timetableTripKey: String?
    let operatorId: String?
    let originStationId: String
    let destStationId: String
    let notes: String?
    let ride: Ride
    let rideReason: String?
    let borderEvidence: BorderEvidence?
    let `operator`: LegOperator?
    let origin: StationRef?
    let destination: StationRef?
    let live: LiveStateRow?
}
