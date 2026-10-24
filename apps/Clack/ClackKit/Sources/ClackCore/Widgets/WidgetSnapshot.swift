//
//  WidgetSnapshot.swift
//  Clack
//

import Foundation

/// What the app hands to the Home Screen and Lock Screen widgets (owner, 2026-10-24). The app writes it after each refresh into the
/// App Group container, and the widgets read it, so they work between refreshes and with no connection. Both use this one
/// definition, in ClackCore. Without the App Group (a Personal Team can't have one) there is no container: the app writes
/// nothing and the widgets show sample data until the group `WidgetSnapshot.groupId` is added to both targets.
public nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    public static let groupId = "group.com.garnerghering.Clack"
    public static let fileName = "widget-snapshot.json"

    public var updatedAt: Double = 0
    /// The next (or running) journey, its legs in order, those not finished yet.
    public var journey: [Leg] = []
    public var passport: PassportBits?
    public var stats: StatsBits?
    public var year: YearBits?
    public var boards: [StationBoard] = []

    public init(
        updatedAt: Double = 0, journey: [Leg] = [], passport: PassportBits? = nil, stats: StatsBits? = nil,
        year: YearBits? = nil, boards: [StationBoard] = []
    ) {
        self.updatedAt = updatedAt
        self.journey = journey
        self.passport = passport
        self.stats = stats
        self.year = year
        self.boards = boards
    }

    public struct Leg: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var journeyId: String?
        public var operatorName: String?
        /// `#rrggbb`.
        public var color: String?
        public var train: String?
        public var from: String
        public var to: String
        public var fromTz: String
        public var toTz: String
        /// Expected times (ms since 1970): actual, else live estimate, else timetable plus delay.
        public var depAt: Double
        public var arrAt: Double
        public var depPlatform: String?
        public var arrPlatform: String?
        public var delayMin: Int?
        public var canceled: Bool
        /// The last live status the server sent (`scheduled`, `approaching`, `boarding`, `en_route`, `at_stop`, `arrived`).
        public var status: String?
        public var progress: Double?
        public var nextStop: String?
        public var nextStopAt: Double?
        /// Names of the stops ridden, in order.
        public var stops: [String] = []

        public init(
            id: String, journeyId: String? = nil, operatorName: String? = nil, color: String? = nil, train: String? = nil,
            from: String, to: String, fromTz: String, toTz: String, depAt: Double, arrAt: Double, depPlatform: String? = nil,
            arrPlatform: String? = nil, delayMin: Int? = nil, canceled: Bool, status: String? = nil, progress: Double? = nil,
            nextStop: String? = nil, nextStopAt: Double? = nil, stops: [String] = []
        ) {
            self.id = id
            self.journeyId = journeyId
            self.operatorName = operatorName
            self.color = color
            self.train = train
            self.from = from
            self.to = to
            self.fromTz = fromTz
            self.toTz = toTz
            self.depAt = depAt
            self.arrAt = arrAt
            self.depPlatform = depPlatform
            self.arrPlatform = arrPlatform
            self.delayMin = delayMin
            self.canceled = canceled
            self.status = status
            self.progress = progress
            self.nextStop = nextStop
            self.nextStopAt = nextStopAt
            self.stops = stops
        }
    }

    public struct PassportBits: Codable, Equatable, Sendable {
        public var km: Double
        public var trains: Int
        public var journeys: Int
        public var stations: Int
        public var countries: Int
        public var minutes: Double
        public var year: Int?
        public var onTimePct: Double?
        public var lateMinutes: Double
        public var co2SavedKg: Double?
        public var co2Comparison: String
        public var nextMedal: String?
        public var nextMedalValue: Double?
        public var nextMedalTarget: Double?

        public init(
            km: Double, trains: Int, journeys: Int, stations: Int, countries: Int, minutes: Double, year: Int? = nil,
            onTimePct: Double? = nil, lateMinutes: Double, co2SavedKg: Double? = nil, co2Comparison: String,
            nextMedal: String? = nil, nextMedalValue: Double? = nil, nextMedalTarget: Double? = nil
        ) {
            self.km = km
            self.trains = trains
            self.journeys = journeys
            self.stations = stations
            self.countries = countries
            self.minutes = minutes
            self.year = year
            self.onTimePct = onTimePct
            self.lateMinutes = lateMinutes
            self.co2SavedKg = co2SavedKg
            self.co2Comparison = co2Comparison
            self.nextMedal = nextMedal
            self.nextMedalValue = nextMedalValue
            self.nextMedalTarget = nextMedalTarget
        }
    }

    public struct Row: Codable, Equatable, Sendable, Identifiable {
        public var name: String
        public var count: Int
        public var color: String?

        public init(name: String, count: Int, color: String? = nil) {
            self.name = name
            self.count = count
            self.color = color
        }
        public var id: String { name }
    }

    public struct StatsBits: Codable, Equatable, Sendable {
        public var operators: [Row]
        public var trainTypes: [Row]
        public var stations: [Row]
        public var countries: [Row]

        public init(operators: [Row], trainTypes: [Row], stations: [Row], countries: [Row]) {
            self.operators = operators
            self.trainTypes = trainTypes
            self.stations = stations
            self.countries = countries
        }
    }

    public struct YearBits: Codable, Equatable, Sendable {
        public var year: Int
        public var km: Double
        public var trains: Int
        public var topRoute: String?
        public var topRouteCount: Int
        public var busiestMonth: String?
        public var busiestMonthCount: Int
        /// Every ride as a thinned line of `[lat, lon]` points.
        public var routes: [[[Double]]]

        public init(
            year: Int, km: Double, trains: Int, topRoute: String? = nil, topRouteCount: Int, busiestMonth: String? = nil,
            busiestMonthCount: Int, routes: [[[Double]]]
        ) {
            self.year = year
            self.km = km
            self.trains = trains
            self.topRoute = topRoute
            self.topRouteCount = topRouteCount
            self.busiestMonth = busiestMonth
            self.busiestMonthCount = busiestMonthCount
            self.routes = routes
        }
    }

    public struct Departure: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var time: Double
        public var delayMin: Int?
        public var platform: String?
        public var to: String
        public var train: String
        public var canceled: Bool

        public init(
            id: String, time: Double, delayMin: Int? = nil, platform: String? = nil, to: String, train: String, canceled: Bool
        ) {
            self.id = id
            self.time = time
            self.delayMin = delayMin
            self.platform = platform
            self.to = to
            self.train = train
            self.canceled = canceled
        }
    }

    public struct StationBoard: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var name: String
        public var rows: [Departure]

        public init(id: String, name: String, rows: [Departure]) {
            self.id = id
            self.name = name
            self.rows = rows
        }
    }

    // MARK: the shared file

    public static var containerURL: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) }

    /// Deletes the stored snapshot ("Delete my data"), so the widgets don't keep showing the old trips.
    public static func clear() {
        guard let url = containerURL?.appendingPathComponent(fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    public static func load() -> WidgetSnapshot? {
        guard let url = containerURL?.appendingPathComponent(fileName), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// False when there is no App Group to write into.
    @discardableResult
    public func save() -> Bool {
        guard let url = Self.containerURL?.appendingPathComponent(Self.fileName), let data = try? JSONEncoder().encode(self) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}

// MARK: where the journey is now

/// The moment of a journey, from the snapshot and the clock alone (so each timeline entry can work it out, offline too).
public nonisolated enum JourneyMoment: Equatable, Sendable {
    /// Before the first departure.
    case before(leg: Int)
    /// On a train: the leg and how far along (0-1).
    case onTrain(leg: Int, progress: Double)
    /// Between two legs: the next leg and the minutes until it leaves.
    case changing(next: Int, spareMin: Int)
    case finished

    public static func at(_ now: Double, legs: [WidgetSnapshot.Leg]) -> JourneyMoment {
        guard let first = legs.first, let last = legs.last else { return .finished }
        if now >= last.arrAt { return .finished }
        if now < first.depAt { return .before(leg: 0) }
        for (i, leg) in legs.enumerated() {
            if now >= leg.depAt && now < leg.arrAt {
                let span = max(1, leg.arrAt - leg.depAt)
                return .onTrain(leg: i, progress: min(1, max(0, (now - leg.depAt) / span)))
            }
            if i + 1 < legs.count, now >= leg.arrAt, now < legs[i + 1].depAt {
                return .changing(next: i + 1, spareMin: Int(((legs[i + 1].depAt - now) / 60_000).rounded(.up)))
            }
        }
        return .finished
    }

    /// The leg the widget talks about.
    public var legIndex: Int? {
        switch self {
        case .before(let i), .onTrain(let i, _), .changing(let i, _): return i
        case .finished: return nil
        }
    }
}
