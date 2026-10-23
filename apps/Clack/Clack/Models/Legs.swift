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
    /// `approaching`: the train is on its way to the stop you board at and hasn't reached it (owner, 2026-10-23).
    case scheduled, approaching, boarding, enRoute, atStop, arrived, cancelled
    case unknown(String)

    static let knownCases: [LiveStatus] = [.scheduled, .approaching, .boarding, .enRoute, .atStop, .arrived, .cancelled]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .scheduled: "scheduled"
        case .approaching: "approaching"
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
    /// Worked out on the phone from the last report because updates stopped (never sent by the server).
    var localEstimate = false

    enum CodingKeys: String, CodingKey {
        case legId, updatedAt, status, lat, lon, bearing, speedKmh, positionSource, positionAt, progress
        case prevStopId, nextStopId, eta, arrivalEta, arrivalDelayMin, reportedAt
    }
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
    var ride: Ride
    var rideReason: String?
    let borderEvidence: BorderEvidence?
    let `operator`: LegOperator?
    let origin: StationRef?
    let destination: StationRef?
    /// Replaced as live updates arrive.
    var live: LiveStateRow?
}

/// Where a stop sits in a leg: the trip's stops before you board and after you get off are kept for context.
nonisolated enum StopRole: OpenEnum {
    case before, board, through, alight, after
    case unknown(String)

    static let knownCases: [StopRole] = [.before, .board, .through, .alight, .after]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .before: "before"
        case .board: "board"
        case .through: "through"
        case .alight: "alight"
        case .after: "after"
        case .unknown(let raw): raw
        }
    }

    /// The stops you ride: board, the ones between, and alight.
    var isRidden: Bool { self == .board || self == .through || self == .alight }
}

/// Who reports a stop's times live; nil means nobody does, so its times are the timetable.
nonisolated enum ReportSource: OpenEnum {
    case trafikverket, entur
    case unknown(String)

    static let knownCases: [ReportSource] = [.trafikverket, .entur]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .trafikverket: "trafikverket"
        case .entur: "entur"
        case .unknown(let raw): raw
        }
    }
}

/// One stop of the whole trip, with its role in this leg (`GET /api/legs/:id`).
nonisolated struct LegStop: Codable, Hashable, Sendable, Identifiable {
    let seq: Int
    let role: StopRole
    let stationId: String
    let name: String
    let code: String?
    let country: String
    let tz: String
    let lat: Double
    let lon: Double
    let schedArr: Instant?
    let schedDep: Instant?
    let actualArr: Instant?
    let actualDep: Instant?
    let estimatedArr: Instant?
    let estimatedDep: Instant?
    let platform: String?
    let canceled: Bool
    /// Trafikverket's Swedish deviation texts.
    let deviations: [String]
    let reportSource: ReportSource?

    var id: Int { seq }
}

nonisolated enum LegEventType: OpenEnum {
    case delayed, platformSet, platformChanged, cancelled, shortTurned, departed, arrived
    case unknown(String)

    static let knownCases: [LegEventType] = [.delayed, .platformSet, .platformChanged, .cancelled, .shortTurned, .departed, .arrived]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .delayed: "delayed"
        case .platformSet: "platform_set"
        case .platformChanged: "platform_changed"
        case .cancelled: "cancelled"
        case .shortTurned: "short_turned"
        case .departed: "departed"
        case .arrived: "arrived"
        case .unknown(let raw): raw
        }
    }
}

/// What an event carries; which fields are set depends on its type (docs/swift-port/API.md §2.6).
nonisolated struct LegEventPayload: Codable, Hashable, Sendable {
    /// `delayed` and `arrived`: the arrival delay in minutes.
    var delayMin: Int?
    /// `delayed`: what it was before.
    var previousDelayMin: Int?
    /// `platform_set` and `platform_changed`: `departure` or `arrival`, and the tracks.
    var which: String?
    var from: String?
    var to: String?
    /// `short_turned`: the stations it no longer reaches.
    var stationIds: [String]?
    /// `departed` and `arrived`: when.
    var at: Instant?
}

nonisolated struct LegEvent: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let legId: String?
    let ts: Instant
    let type: LegEventType
    let payload: LegEventPayload
}

/// A leg with everything the detail screen needs (`GET /api/legs/:id`): all of `Leg`, plus the route line, every
/// stop of the trip and the latest events.
nonisolated struct LegDetail: Codable, Hashable, Sendable, Identifiable {
    let leg: Leg
    /// An encoded polyline of the ridden route along the track.
    let geometry: String?
    /// The whole trip, ordered by `seq`.
    let stops: [LegStop]
    /// Newest first, at most 50.
    let events: [LegEvent]

    var id: String { leg.id }

    private enum ExtraKeys: String, CodingKey {
        case geometry, stops, events
    }

    init(from decoder: Decoder) throws {
        leg = try Leg(from: decoder)
        let container = try decoder.container(keyedBy: ExtraKeys.self)
        geometry = try container.decodeIfPresent(String.self, forKey: .geometry)
        stops = try container.decode([LegStop].self, forKey: .stops)
        events = try container.decode([LegEvent].self, forKey: .events)
    }

    func encode(to encoder: Encoder) throws {
        try leg.encode(to: encoder)
        var container = encoder.container(keyedBy: ExtraKeys.self)
        try container.encodeIfPresent(geometry, forKey: .geometry)
        try container.encode(stops, forKey: .stops)
        try container.encode(events, forKey: .events)
    }
}
