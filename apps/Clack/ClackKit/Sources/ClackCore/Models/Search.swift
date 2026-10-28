//
//  Search.swift
//  Clack
//

import Foundation

/// A station in search results and lists (`GET /api/stations/search`, `/popular`, `/favorites`, `/recent`).
public nonisolated struct StationHit: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let code: String?
    /// ISO 3166 alpha-2: `SE`, `NO`, `DK`, ...
    public let country: String
    /// Not sent by the popular, favourites and recent lists.
    public let county: String?

    public init(id: String, name: String, code: String?, country: String, county: String?) {
        self.id = id
        self.name = name
        self.code = code
        self.country = country
        self.county = county
    }
}

/// `GET /api/history/prepare`: where fetching an older day's Swedish timetable stands (ready, loading, failed, unavailable).
public nonisolated struct HistoryPrepared: Codable, Hashable, Sendable {
    public let sweden: String
}

/// `GET /api/search`: how the smart search read the text, station suggestions, and the trains or connections found.
public nonisolated struct SearchResponse: Codable, Hashable, Sendable {
    public nonisolated struct Interpretation: Codable, Hashable, Sendable {
        public nonisolated struct OperatorText: Codable, Hashable, Sendable {
            public let id: String
            public let text: String

            public init(id: String, text: String) {
                self.id = id
                self.text = text
            }
        }

        public let `operator`: OperatorText?
        public let trainNumber: String?
        public let from: StationHit?
        public let to: StationHit?
        /// Which end is being typed: `from` or `to`.
        public let typing: String?

        public init(`operator`: OperatorText?, trainNumber: String?, from: StationHit?, to: StationHit?, typing: String?) {
            self.operator = `operator`
            self.trainNumber = trainNumber
            self.from = from
            self.to = to
            self.typing = typing
        }
    }

    public let date: String
    public let interpretation: Interpretation
    public let suggestions: [StationHit]
    /// Nil when the text isn't a search yet; empty when nothing was found or the date is outside the timetable.
    public let results: [TripResult]?
    public let connections: [TimetableConnection]?
    /// Journeys with up to two changes, direct trains among them, by departure (the planner; nil from older servers).
    public let journeys: [PlannedJourney]?
    public let outsideTimetable: Bool
    /// For dates before yesterday: `ready`, `loading` (try again shortly), `failed`, `unavailable`, `norway` or
    /// `finland` (before that country's record starts).
    public let history: String?
    /// With `norway` or `finland`: the first day that country's trains are on record (YYYY-MM-DD).
    public let historyFrom: String?

    public init(date: String, interpretation: Interpretation, suggestions: [StationHit], results: [TripResult]?, connections: [TimetableConnection]?, outsideTimetable: Bool, history: String?, historyFrom: String? = nil, journeys: [PlannedJourney]? = nil) {
        self.journeys = journeys
        self.date = date
        self.interpretation = interpretation
        self.suggestions = suggestions
        self.results = results
        self.connections = connections
        self.outsideTimetable = outsideTimetable
        self.history = history
        self.historyFrom = historyFrom
    }
}

/// One stop of a timetable trip (`GET /api/timetable/trips/:key`).
public nonisolated struct TripStop: Codable, Hashable, Sendable, Identifiable {
    public let seq: Int
    public let stationId: String
    public let name: String
    public let code: String?
    public let country: String
    public let tz: String
    public let lat: Double
    public let lon: Double
    public let arr: Instant?
    public let dep: Instant?
    public let noPickup: Bool
    public let noDropoff: Bool

    public var id: Int { seq }

    public init(seq: Int, stationId: String, name: String, code: String?, country: String, tz: String, lat: Double, lon: Double, arr: Instant?, dep: Instant?, noPickup: Bool, noDropoff: Bool) {
        self.seq = seq
        self.stationId = stationId
        self.name = name
        self.code = code
        self.country = country
        self.tz = tz
        self.lat = lat
        self.lon = lon
        self.arr = arr
        self.dep = dep
        self.noPickup = noPickup
        self.noDropoff = noDropoff
    }
}

public nonisolated struct TimetableTrip: Codable, Hashable, Sendable {
    public let key: String
    public let serviceDate: String
    public let trainNumber: String?
    public let operatorId: String?
    public let category: String
    public let product: String
    public let trainType: String?
    public let stops: [TripStop]

    public init(key: String, serviceDate: String, trainNumber: String?, operatorId: String?, category: String, product: String, trainType: String?, stops: [TripStop]) {
        self.key = key
        self.serviceDate = serviceDate
        self.trainNumber = trainNumber
        self.operatorId = operatorId
        self.category = category
        self.product = product
        self.trainType = trainType
        self.stops = stops
    }
}

/// The route between consecutive stops of a timetable trip (`.../geometry`).
public nonisolated struct TripGeometry: Codable, Hashable, Sendable {
    public nonisolated struct Segment: Codable, Hashable, Sendable {
        public let fromSeq: Int
        public let toSeq: Int
        /// Encoded polyline.
        public let polyline: String
        /// Metres.
        public let lengthM: Double
        public let estimated: Bool

        public init(fromSeq: Int, toSeq: Int, polyline: String, lengthM: Double, estimated: Bool) {
            self.fromSeq = fromSeq
            self.toSeq = toSeq
            self.polyline = polyline
            self.lengthM = lengthM
            self.estimated = estimated
        }
    }

    public let segments: [Segment]

    public init(segments: [Segment]) {
        self.segments = segments
    }
}

/// What is sent to save a timetable trip (`POST /api/legs`).
public nonisolated struct CreateLegBody: Encodable, Sendable {
    public let tripKey: String
    public let serviceDate: String
    public let fromSeq: Int
    public let toSeq: Int
    /// Save even if the same train is already saved on that date.
    public var force: Bool?
    /// Where you sit, from a ticket ("16", "37"); left out when not known.
    public var coach: String?
    public var seat: String?
    /// Legs saved together from one planned journey share this, so they stay one journey whatever the wait.
    public var group: String?

    public init(tripKey: String, serviceDate: String, fromSeq: Int, toSeq: Int, force: Bool? = nil, coach: String? = nil, seat: String? = nil, group: String? = nil) {
        self.tripKey = tripKey
        self.serviceDate = serviceDate
        self.fromSeq = fromSeq
        self.toSeq = toSeq
        self.force = force
        self.coach = coach
        self.seat = seat
        self.group = group
    }
}

/// What is sent to add a trip by hand (`POST /api/legs/manual`); the web always sends all eight keys.
public nonisolated struct ManualLegBody: Encodable, Sendable {
    public let fromStationId: String
    public let toStationId: String
    /// YYYY-MM-DD, local where you board.
    public let date: String
    /// HH:MM at the origin.
    public let dep: String
    /// HH:MM at the destination; earlier than `dep` means the next day.
    public let arr: String
    public let operatorId: String?
    public let trainNumber: String?
    public let category: String?
    /// Where you sit; left out when not known.
    public var coach: String? = nil
    public var seat: String? = nil

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fromStationId, forKey: .fromStationId)
        try c.encode(toStationId, forKey: .toStationId)
        try c.encode(date, forKey: .date)
        try c.encode(dep, forKey: .dep)
        try c.encode(arr, forKey: .arr)
        try c.encode(operatorId, forKey: .operatorId)
        try c.encode(trainNumber, forKey: .trainNumber)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(coach, forKey: .coach)
        try c.encodeIfPresent(seat, forKey: .seat)
    }

    private enum CodingKeys: String, CodingKey {
        case fromStationId, toStationId, date, dep, arr, operatorId, trainNumber, category, coach, seat
    }

    public init(fromStationId: String, toStationId: String, date: String, dep: String, arr: String, operatorId: String?, trainNumber: String?, category: String?) {
        self.fromStationId = fromStationId
        self.toStationId = toStationId
        self.date = date
        self.dep = dep
        self.arr = arr
        self.operatorId = operatorId
        self.trainNumber = trainNumber
        self.category = category
    }
}

/// One departure or arrival on a station board (`GET /api/stations/:id/board`). Times are epoch milliseconds.
public nonisolated struct BoardRow: Codable, Hashable, Sendable, Identifiable {
    public nonisolated struct PlatformChange: Codable, Hashable, Sendable {
        public let from: String?
        public let at: Double?

        public init(from: String?, at: Double?) {
            self.from = from
            self.at = at
        }
    }

    public nonisolated struct Trip: Codable, Hashable, Sendable {
        public let key: String
        public let serviceDate: String
        public let seq: Int

        public init(key: String, serviceDate: String, seq: Int) {
            self.key = key
            self.serviceDate = serviceDate
            self.seq = seq
        }
    }

    public let id: String
    public let trainNumber: String
    public let advertised: Double
    public let estimated: Double?
    public let actual: Double?
    public let done: Bool
    public let delayMin: Int?
    public let platform: String?
    public let platformChange: PlatformChange?
    public let canceled: Bool
    public let deviations: [String]
    /// The same notices with their source's codes; nil from older servers.
    public let causes: [LegStop.Cause]?
    public let endpoints: [String]
    public let via: [String]
    public let operatorId: String?
    public let productName: String?
    /// `high_speed`, `intercity`, `regional`, `commuter`, `night` (or something newer).
    public let product: String
    public let trainType: String?
    public let trip: Trip?

    /// The causes to show: the structured ones, else the plain texts of an older server.
    public var allCauses: [LegStop.Cause] { causes ?? deviations.map { LegStop.Cause(src: "trv", text: $0) } }

    /// What the board shows: when it happened, else when it's expected, else the timetable.
    public var shown: Double { actual ?? estimated ?? advertised }

    public init(id: String, trainNumber: String, advertised: Double, estimated: Double?, actual: Double?, done: Bool, delayMin: Int?, platform: String?, platformChange: PlatformChange?, canceled: Bool, deviations: [String], causes: [LegStop.Cause]? = nil, endpoints: [String], via: [String], operatorId: String?, productName: String?, product: String, trainType: String?, trip: Trip?) {
        self.id = id
        self.trainNumber = trainNumber
        self.advertised = advertised
        self.estimated = estimated
        self.actual = actual
        self.done = done
        self.delayMin = delayMin
        self.platform = platform
        self.platformChange = platformChange
        self.canceled = canceled
        self.deviations = deviations
        self.causes = causes
        self.endpoints = endpoints
        self.via = via
        self.operatorId = operatorId
        self.productName = productName
        self.product = product
        self.trainType = trainType
        self.trip = trip
    }
}

public nonisolated struct Board: Codable, Hashable, Sendable {
    public let stationId: String
    public let type: String
    public let from: Double
    public let to: Double
    public let updatedAt: Double
    /// False when the rows are the timetable alone (no live source for the station, or it is unavailable). Older
    /// servers don't send it: their boards are all live.
    public let live: Bool?
    public let rows: [BoardRow]

    public var isLive: Bool { live ?? true }

    public init(stationId: String, type: String, from: Double, to: Double, updatedAt: Double, live: Bool? = nil, rows: [BoardRow]) {
        self.stationId = stationId
        self.type = type
        self.from = from
        self.to = to
        self.updatedAt = updatedAt
        self.live = live
        self.rows = rows
    }
}

/// A real train leaving within the hour (`GET /api/trains/soon`): the first screen's one-tap trips. A whole run from
/// `from` to the train's last stop, ready for `createLeg`.
public nonisolated struct SoonTrain: Codable, Hashable, Sendable, Identifiable {
    public struct Place: Codable, Hashable, Sendable { public let id: String; public let name: String }
    public let tripKey: String
    public let serviceDate: String
    public let fromSeq: Int
    public let toSeq: Int
    public let trainNumber: String?
    public let operatorId: String?
    public let category: String
    public let from: Place
    public let to: Place
    /// Epoch ms, timetable.
    public let dep: Double
    public let arr: Double

    public var id: String { "\(tripKey)|\(fromSeq)" }
    public var body: CreateLegBody { CreateLegBody(tripKey: tripKey, serviceDate: serviceDate, fromSeq: fromSeq, toSeq: toSeq) }
}
