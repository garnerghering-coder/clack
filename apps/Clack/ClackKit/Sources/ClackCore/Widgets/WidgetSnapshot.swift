//
//  WidgetSnapshot.swift
//  Clack
//

import Foundation

/// What the Home Screen and Lock Screen widgets show (owner, 2026-10-24). The widgets fetch it themselves
/// (`WidgetData.load`), and the app writes it after each refresh as a fast path; either way it is kept as one JSON file in
/// the App Group container, the cache the widgets fall back to with no connection. Both use this one definition, in
/// ClackCore. Without the App Group (a Personal Team can't have one) there is no container and nothing is kept.
public nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    public static let groupId = "group.com.garnerghering.Clack"
    /// Version 2. The earlier file (`widget-snapshot.json`: one journey, no language) is not read, and is deleted.
    public static let fileName = "widget-snapshot-2.json"
    static let oldFileNames = ["widget-snapshot.json"]

    /// When the journey part was fetched (ms since 1970); 0 = never.
    public var updatedAt: Double = 0
    /// The app's language, clock and distance settings (`GET /api/settings`), not the phone's.
    public var language: Language = .en
    public var clock: ClockFormat = .h24
    public var distanceUnit: DistanceUnit = .km
    /// The featured journey (the Trips tab's rule: running now, else the earliest upcoming, else arrived in the last 6
    /// hours), every leg in travel order.
    public var journey: [Leg] = []
    /// The next upcoming journey after that one, so the widget moves on to it when the first ends.
    public var nextJourney: [Leg] = []
    public var passport: PassportBits?
    public var stats: StatsBits?
    public var year: YearBits?
    /// When the Passport, stats and year were fetched; 0 = never.
    public var passportUpdatedAt: Double = 0
    public var boards: [StationBoard] = []

    public init(
        updatedAt: Double = 0, language: Language = .en, clock: ClockFormat = .h24, distanceUnit: DistanceUnit = .km, journey: [Leg] = [],
        nextJourney: [Leg] = [], passport: PassportBits? = nil, stats: StatsBits? = nil, year: YearBits? = nil, passportUpdatedAt: Double = 0,
        boards: [StationBoard] = []
    ) {
        self.updatedAt = updatedAt
        self.language = language
        self.clock = clock
        self.distanceUnit = distanceUnit
        self.journey = journey
        self.nextJourney = nextJourney
        self.passport = passport
        self.stats = stats
        self.year = year
        self.passportUpdatedAt = passportUpdatedAt
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
        /// Whole minutes, negative = early; nil when no source has said.
        public var depDelayMin: Int?
        public var arrDelayMin: Int?
        public var canceled: Bool
        /// The last live status the server sent (`scheduled`, `approaching`, `boarding`, `en_route`, `at_stop`, `arrived`).
        public var status: String?
        public var progress: Double?
        /// The live next stop's name, from the leg's stops; nil when not known.
        public var nextStop: String?
        public var nextStopAt: Double?
        /// Names of the stops ridden, in order.
        public var stops: [String] = []

        public init(
            id: String, journeyId: String? = nil, operatorName: String? = nil, color: String? = nil, train: String? = nil,
            from: String, to: String, fromTz: String, toTz: String, depAt: Double, arrAt: Double, depPlatform: String? = nil,
            arrPlatform: String? = nil, depDelayMin: Int? = nil, arrDelayMin: Int? = nil, canceled: Bool, status: String? = nil,
            progress: Double? = nil, nextStop: String? = nil, nextStopAt: Double? = nil, stops: [String] = []
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
            self.depDelayMin = depDelayMin
            self.arrDelayMin = arrDelayMin
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
        /// `YYYY-MM`.
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
        /// The timetable time (ms since 1970), as the board prints it.
        public var time: Double
        /// When it is expected to leave, when a source has said.
        public var expected: Double?
        public var delayMin: Int?
        public var platform: String?
        public var to: String
        public var train: String
        public var canceled: Bool

        /// When it leaves as best known: the expected time, else the timetable.
        public var leaves: Double { expected ?? time }

        public init(
            id: String, time: Double, expected: Double? = nil, delayMin: Int? = nil, platform: String? = nil, to: String, train: String,
            canceled: Bool
        ) {
            self.id = id
            self.time = time
            self.expected = expected
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
        /// The station's time zone (`GET /api/stations/:id`); the board's times are printed in it.
        public var tz: String?
        /// When the board was fetched (ms since 1970).
        public var updatedAt: Double
        public var rows: [Departure]

        public init(id: String, name: String, tz: String? = nil, updatedAt: Double = 0, rows: [Departure]) {
            self.id = id
            self.name = name
            self.tz = tz
            self.updatedAt = updatedAt
            self.rows = rows
        }
    }

    // MARK: the shared file

    public static var containerURL: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) }

    /// Deletes the stored snapshot ("Delete my data"), so the widgets don't keep showing the old trips.
    public static func clear() {
        guard let dir = containerURL else { return }
        for name in [fileName] + oldFileNames { try? FileManager.default.removeItem(at: dir.appendingPathComponent(name)) }
    }

    public static func load() -> WidgetSnapshot? {
        guard let url = containerURL?.appendingPathComponent(fileName), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// False when there is no App Group to write into.
    @discardableResult
    public func save() -> Bool {
        guard let dir = Self.containerURL, let data = try? JSONEncoder().encode(self) else { return false }
        for name in Self.oldFileNames { try? FileManager.default.removeItem(at: dir.appendingPathComponent(name)) }
        return (try? data.write(to: dir.appendingPathComponent(Self.fileName), options: .atomic)) != nil
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
