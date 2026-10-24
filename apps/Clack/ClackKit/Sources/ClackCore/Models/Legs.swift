//
//  Legs.swift
//  Clack
//

import Foundation

public nonisolated enum LegStatus: OpenEnum {
    case planned, completed, snapshotted
    case unknown(String)

    public static let knownCases: [LegStatus] = [.planned, .completed, .snapshotted]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .planned: "planned"
        case .completed: "completed"
        case .snapshotted: "snapshotted"
        case .unknown(let raw): raw
        }
    }
}

public nonisolated enum DataQuality: OpenEnum {
    case full, partial, scheduledOnly, manual
    case unknown(String)

    public static let knownCases: [DataQuality] = [.full, .partial, .scheduledOnly, .manual]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .full: "full"
        case .partial: "partial"
        case .scheduledOnly: "scheduled_only"
        case .manual: "manual"
        case .unknown(let raw): raw
        }
    }
}

public nonisolated enum TrainTypeSource: OpenEnum {
    case typical, composition, user
    case unknown(String)

    public static let knownCases: [TrainTypeSource] = [.typical, .composition, .user]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .typical: "typical"
        case .composition: "composition"
        case .user: "user"
        case .unknown(let raw): raw
        }
    }
}

/// Whether the rider took the train: only `auto` and `confirmed` count in the Passport.
public nonisolated enum Ride: OpenEnum {
    case pending, auto, confirmed, review, notTaken
    case unknown(String)

    public static let knownCases: [Ride] = [.pending, .auto, .confirmed, .review, .notTaken]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
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

public nonisolated enum LiveStatus: OpenEnum {
    /// `approaching`: the train is on its way to the stop you board at and hasn't reached it (owner, 2026-10-23).
    case scheduled, approaching, boarding, enRoute, atStop, arrived, cancelled
    case unknown(String)

    public static let knownCases: [LiveStatus] = [.scheduled, .approaching, .boarding, .enRoute, .atStop, .arrived, .cancelled]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
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

public nonisolated enum PositionSource: OpenEnum {
    case gps, estimated
    case unknown(String)

    public static let knownCases: [PositionSource] = [.gps, .estimated]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
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
public nonisolated struct OnboardFacts: Codable, Hashable, Sendable {
    public let catering: String?
    /// Where the café is, when the coach order says ("B").
    public let cateringCar: String?
    public let sleeper: Bool
    public let notices: [String]

    public init(catering: String?, cateringCar: String?, sleeper: Bool, notices: [String]) {
        self.catering = catering
        self.cateringCar = cateringCar
        self.sleeper = sleeper
        self.notices = notices
    }
}

/// A station as a leg refers to it.
public nonisolated struct StationRef: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let code: String?
    /// ISO 3166 alpha-2: `SE`, `NO`, `DK`, ...
    public let country: String
    /// IANA zone, e.g. `Europe/Stockholm`. Every time shown is formatted in its station's zone.
    public let tz: String

    public init(id: String, name: String, code: String?, country: String, tz: String) {
        self.id = id
        self.name = name
        self.code = code
        self.country = country
        self.tz = tz
    }
}

/// The operator attached to a leg: the operators-table row plus its logo (no ticket fields).
public nonisolated struct LegOperator: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let shortName: String
    public let company: String?
    public let country: String
    public let brandColor: String
    public let logoPath: String?
    public let logoUrl: String?

    public init(id: String, name: String, shortName: String, company: String?, country: String, brandColor: String, logoPath: String?, logoUrl: String?) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.company = company
        self.country = country
        self.brandColor = brandColor
        self.logoPath = logoPath
        self.logoUrl = logoUrl
    }
}

/// Where a boarding or alighting was seen, in epoch ms.
public nonisolated struct BorderEvidence: Codable, Hashable, Sendable {
    public nonisolated struct Sighting: Codable, Hashable, Sendable {
        public let stationId: String
        public let at: Instant

        public init(stationId: String, at: Instant) {
            self.stationId = stationId
            self.at = at
        }
    }

    public let board: Sighting?
    public let alight: Sighting?

    public init(board: Sighting?, alight: Sighting?) {
        self.board = board
        self.alight = alight
    }
}

/// The REST form of live state (times are ISO strings here; over SSE they are ms. `Instant` takes both).
public nonisolated struct LiveStateRow: Codable, Hashable, Sendable {
    public let legId: String?
    public let updatedAt: Instant
    public let status: LiveStatus
    public let lat: Double?
    public let lon: Double?
    public let bearing: Double?
    public let speedKmh: Double?
    public let positionSource: PositionSource?
    public let positionAt: Instant?
    /// 0 to 1, the share of the ridden route travelled.
    public let progress: Double?
    public let prevStopId: String?
    public let nextStopId: String?
    public let eta: Instant?
    public let arrivalEta: Instant?
    public let arrivalDelayMin: Int?
    public let reportedAt: Instant?
    /// Worked out on the phone from the last report because updates stopped (never sent by the server).
    public var localEstimate = false

    public enum CodingKeys: String, CodingKey {
        case legId, updatedAt, status, lat, lon, bearing, speedKmh, positionSource, positionAt, progress
        case prevStopId, nextStopId, eta, arrivalEta, arrivalDelayMin, reportedAt
    }

    public init(legId: String?, updatedAt: Instant, status: LiveStatus, lat: Double?, lon: Double?, bearing: Double?, speedKmh: Double?, positionSource: PositionSource?, positionAt: Instant?, progress: Double?, prevStopId: String?, nextStopId: String?, eta: Instant?, arrivalEta: Instant?, arrivalDelayMin: Int?, reportedAt: Instant?, localEstimate: Bool = false) {
        self.legId = legId
        self.updatedAt = updatedAt
        self.status = status
        self.lat = lat
        self.lon = lon
        self.bearing = bearing
        self.speedKmh = speedKmh
        self.positionSource = positionSource
        self.positionAt = positionAt
        self.progress = progress
        self.prevStopId = prevStopId
        self.nextStopId = nextStopId
        self.eta = eta
        self.arrivalEta = arrivalEta
        self.arrivalDelayMin = arrivalDelayMin
        self.reportedAt = reportedAt
        self.localEstimate = localEstimate
    }
}

/// One saved train ride, as `GET /api/legs` sends it (docs/swift-port/API.md §2.6).
public nonisolated struct Leg: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let status: LegStatus
    public let dataQuality: DataQuality
    public let trainNumber: String?
    /// `intercity`, `regional`, `commuter`, `heritage`, `night`, and for manual trips `high_speed`.
    public let category: String?
    /// YYYY-MM-DD.
    public let serviceDate: String?
    public let schedDep: Instant?
    public let schedArr: Instant?
    public let actualDep: Instant?
    public let actualArr: Instant?
    /// Whole minutes, negative = early.
    public let depDelayMin: Int?
    public let arrDelayMin: Int?
    public let depPlatform: String?
    public let arrPlatform: String?
    public let canceled: Bool
    /// Metres, along the track once routed.
    public let distanceM: Double?
    public let isEstimatedGeometry: Bool
    public let trainType: String?
    public let trainTypeSource: TrainTypeSource?
    public let onboard: OnboardFacts?
    public let countryCodes: [String]
    public let journeyId: String?
    /// Nil for trips added by hand.
    public let timetableTripKey: String?
    public let operatorId: String?
    public let originStationId: String
    public let destStationId: String
    public let notes: String?
    public var ride: Ride
    public var rideReason: String?
    public let borderEvidence: BorderEvidence?
    public let `operator`: LegOperator?
    public let origin: StationRef?
    public let destination: StationRef?
    /// Replaced as live updates arrive.
    public var live: LiveStateRow?

    public init(id: String, status: LegStatus, dataQuality: DataQuality, trainNumber: String?, category: String?, serviceDate: String?, schedDep: Instant?, schedArr: Instant?, actualDep: Instant?, actualArr: Instant?, depDelayMin: Int?, arrDelayMin: Int?, depPlatform: String?, arrPlatform: String?, canceled: Bool, distanceM: Double?, isEstimatedGeometry: Bool, trainType: String?, trainTypeSource: TrainTypeSource?, onboard: OnboardFacts?, countryCodes: [String], journeyId: String?, timetableTripKey: String?, operatorId: String?, originStationId: String, destStationId: String, notes: String?, ride: Ride, rideReason: String? = nil, borderEvidence: BorderEvidence?, `operator`: LegOperator?, origin: StationRef?, destination: StationRef?, live: LiveStateRow? = nil) {
        self.id = id
        self.status = status
        self.dataQuality = dataQuality
        self.trainNumber = trainNumber
        self.category = category
        self.serviceDate = serviceDate
        self.schedDep = schedDep
        self.schedArr = schedArr
        self.actualDep = actualDep
        self.actualArr = actualArr
        self.depDelayMin = depDelayMin
        self.arrDelayMin = arrDelayMin
        self.depPlatform = depPlatform
        self.arrPlatform = arrPlatform
        self.canceled = canceled
        self.distanceM = distanceM
        self.isEstimatedGeometry = isEstimatedGeometry
        self.trainType = trainType
        self.trainTypeSource = trainTypeSource
        self.onboard = onboard
        self.countryCodes = countryCodes
        self.journeyId = journeyId
        self.timetableTripKey = timetableTripKey
        self.operatorId = operatorId
        self.originStationId = originStationId
        self.destStationId = destStationId
        self.notes = notes
        self.ride = ride
        self.rideReason = rideReason
        self.borderEvidence = borderEvidence
        self.operator = `operator`
        self.origin = origin
        self.destination = destination
        self.live = live
    }
}

/// Where a stop sits in a leg: the trip's stops before you board and after you get off are kept for context.
public nonisolated enum StopRole: OpenEnum {
    case before, board, through, alight, after
    case unknown(String)

    public static let knownCases: [StopRole] = [.before, .board, .through, .alight, .after]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
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
    public var isRidden: Bool { self == .board || self == .through || self == .alight }
}

/// Who reports a stop's times live; nil means nobody does, so its times are the timetable.
public nonisolated enum ReportSource: OpenEnum {
    case trafikverket, entur
    case unknown(String)

    public static let knownCases: [ReportSource] = [.trafikverket, .entur]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .trafikverket: "trafikverket"
        case .entur: "entur"
        case .unknown(let raw): raw
        }
    }
}

/// One stop of the whole trip, with its role in this leg (`GET /api/legs/:id`).
public nonisolated struct LegStop: Codable, Hashable, Sendable, Identifiable {
    public let seq: Int
    public let role: StopRole
    public let stationId: String
    public let name: String
    public let code: String?
    public let country: String
    public let tz: String
    public let lat: Double
    public let lon: Double
    public let schedArr: Instant?
    public let schedDep: Instant?
    public let actualArr: Instant?
    public let actualDep: Instant?
    public let estimatedArr: Instant?
    public let estimatedDep: Instant?
    public let platform: String?
    public let canceled: Bool
    /// Trafikverket's Swedish deviation texts.
    public let deviations: [String]
    public let reportSource: ReportSource?

    public var id: Int { seq }

    public init(seq: Int, role: StopRole, stationId: String, name: String, code: String?, country: String, tz: String, lat: Double, lon: Double, schedArr: Instant?, schedDep: Instant?, actualArr: Instant?, actualDep: Instant?, estimatedArr: Instant?, estimatedDep: Instant?, platform: String?, canceled: Bool, deviations: [String], reportSource: ReportSource?) {
        self.seq = seq
        self.role = role
        self.stationId = stationId
        self.name = name
        self.code = code
        self.country = country
        self.tz = tz
        self.lat = lat
        self.lon = lon
        self.schedArr = schedArr
        self.schedDep = schedDep
        self.actualArr = actualArr
        self.actualDep = actualDep
        self.estimatedArr = estimatedArr
        self.estimatedDep = estimatedDep
        self.platform = platform
        self.canceled = canceled
        self.deviations = deviations
        self.reportSource = reportSource
    }
}

public nonisolated enum LegEventType: OpenEnum {
    case delayed, platformSet, platformChanged, cancelled, shortTurned, departed, arrived
    case unknown(String)

    public static let knownCases: [LegEventType] = [.delayed, .platformSet, .platformChanged, .cancelled, .shortTurned, .departed, .arrived]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
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
public nonisolated struct LegEventPayload: Codable, Hashable, Sendable {
    /// `delayed` and `arrived`: the arrival delay in minutes.
    public var delayMin: Int?
    /// `delayed`: what it was before.
    public var previousDelayMin: Int?
    /// `platform_set` and `platform_changed`: `departure` or `arrival`, and the tracks.
    public var which: String?
    public var from: String?
    public var to: String?
    /// `short_turned`: the stations it no longer reaches.
    public var stationIds: [String]?
    /// `departed` and `arrived`: when.
    public var at: Instant?

    public init(delayMin: Int? = nil, previousDelayMin: Int? = nil, which: String? = nil, from: String? = nil, to: String? = nil, stationIds: [String]? = nil, at: Instant? = nil) {
        self.delayMin = delayMin
        self.previousDelayMin = previousDelayMin
        self.which = which
        self.from = from
        self.to = to
        self.stationIds = stationIds
        self.at = at
    }
}

public nonisolated struct LegEvent: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let legId: String?
    public let ts: Instant
    public let type: LegEventType
    public let payload: LegEventPayload

    public init(id: Int, legId: String?, ts: Instant, type: LegEventType, payload: LegEventPayload) {
        self.id = id
        self.legId = legId
        self.ts = ts
        self.type = type
        self.payload = payload
    }
}

/// A leg with everything the detail screen needs (`GET /api/legs/:id`): all of `Leg`, plus the route line, every
/// stop of the trip and the latest events.
public nonisolated struct LegDetail: Codable, Hashable, Sendable, Identifiable {
    public let leg: Leg
    /// An encoded polyline of the ridden route along the track.
    public let geometry: String?
    /// The whole trip, ordered by `seq`.
    public let stops: [LegStop]
    /// Newest first, at most 50.
    public let events: [LegEvent]

    public var id: String { leg.id }

    private enum ExtraKeys: String, CodingKey {
        case geometry, stops, events
    }

    public init(from decoder: Decoder) throws {
        leg = try Leg(from: decoder)
        let container = try decoder.container(keyedBy: ExtraKeys.self)
        geometry = try container.decodeIfPresent(String.self, forKey: .geometry)
        stops = try container.decode([LegStop].self, forKey: .stops)
        events = try container.decode([LegEvent].self, forKey: .events)
    }

    public func encode(to encoder: Encoder) throws {
        try leg.encode(to: encoder)
        var container = encoder.container(keyedBy: ExtraKeys.self)
        try container.encodeIfPresent(geometry, forKey: .geometry)
        try container.encode(stops, forKey: .stops)
        try container.encode(events, forKey: .events)
    }
}
