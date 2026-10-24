//
//  Passport.swift
//  Clack
//

import Foundation

public nonisolated enum MilestoneFamily: OpenEnum {
    case journeys, distanceKm, stations, operators, countries, borderCrossings, nightTrains
    case unknown(String)

    public static let knownCases: [MilestoneFamily] = [.journeys, .distanceKm, .stations, .operators, .countries, .borderCrossings, .nightTrains]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
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
public nonisolated struct Milestone: Codable, Hashable, Sendable {
    public let family: MilestoneFamily
    public let target: Double
    public let at: Instant?
    public let legId: String?
    public let value: Double?

    public init(family: MilestoneFamily, target: Double, at: Instant?, legId: String?, value: Double?) {
        self.family = family
        self.target = target
        self.at = at
        self.legId = legId
        self.value = value
    }
}

/// What a trip did for your Passport (`GET /api/legs/:id/progress`); `counted` is false while it doesn't count.
public nonisolated struct TripProgress: Codable, Hashable, Sendable {
    public nonisolated struct Moved: Codable, Hashable, Sendable {
        public let family: MilestoneFamily
        public let before: Double
        public let after: Double
        public let target: Double

        public init(family: MilestoneFamily, before: Double, after: Double, target: Double) {
            self.family = family
            self.before = before
            self.after = after
            self.target = target
        }
    }

    public nonisolated struct Firsts: Codable, Hashable, Sendable {
        /// Station names.
        public let stations: [String]
        /// An operator id.
        public let `operator`: String?
        /// Country codes.
        public let countries: [String]

        public init(stations: [String], `operator`: String?, countries: [String]) {
            self.stations = stations
            self.operator = `operator`
            self.countries = countries
        }
    }

    public let counted: Bool
    public let unlocked: [Milestone]
    public let moved: [Moved]
    public let firsts: Firsts?

    public init(counted: Bool, unlocked: [Milestone], moved: [Moved], firsts: Firsts?) {
        self.counted = counted
        self.unlocked = unlocked
        self.moved = moved
        self.firsts = firsts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        counted = try c.decode(Bool.self, forKey: .counted)
        unlocked = try c.decodeIfPresent([Milestone].self, forKey: .unlocked) ?? []
        moved = try c.decodeIfPresent([Moved].self, forKey: .moved) ?? []
        firsts = try c.decodeIfPresent(Firsts.self, forKey: .firsts)
    }

    private enum CodingKeys: String, CodingKey { case counted, unlocked, moved, firsts }
}

/// One warning on an upcoming trip (`GET /api/legs/:id/risk`), keyed by `kind`.
public nonisolated enum RiskWarning: Codable, Hashable, Sendable {
    case routeNow(trains: Int, late: Int, canceled: Int, medianMin: Double, windowMin: Double)
    case stationNow(station: String, trains: Int, late: Int, medianMin: Double, windowMin: Double)
    case ahead(station: String, toward: String, trains: Int, late: Int, delays: [Int], windowMin: Double)
    case trainPattern(station: String, days: Int, lateDays: Int, medianMin: Double)
    case unknown(String)

    private enum Keys: String, CodingKey {
        case kind, trains, late, canceled, medianMin, windowMin, station, toward, delays, days, lateDays
    }

    public init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(kind, forKey: .kind)
    }

    /// The `kind` string.
    public var kind: String {
        switch self {
        case .routeNow: "route_now"
        case .stationNow: "station_now"
        case .ahead: "ahead"
        case .trainPattern: "train_pattern"
        case .unknown(let raw): raw
        }
    }
}

public nonisolated struct LegRisk: Codable, Hashable, Sendable {
    public let checkedAt: Instant
    /// What could not be checked: `too_far`, `abroad`, `no_live_data`, `no_history`.
    public let limits: [String]
    public let warnings: [RiskWarning]

    public init(checkedAt: Instant, limits: [String], warnings: [RiskWarning]) {
        self.checkedAt = checkedAt
        self.limits = limits
        self.warnings = warnings
    }
}

/// `GET /api/passport` (docs/swift-port/API.md §2.10): everything you've ridden, for a year or all time.
public nonisolated struct Passport: Codable, Hashable, Sendable {
    public nonisolated struct Scope: Codable, Hashable, Sendable {
        public let year: Int?
        public let includeCommuter: Bool

        public init(year: Int?, includeCommuter: Bool) {
            self.year = year
            self.includeCommuter = includeCommuter
        }
    }

    public nonisolated struct Totals: Codable, Hashable, Sendable {
        public let distanceM: Double
        public let minutes: Double
        public let trains: Int
        public let journeys: Int
        public let stations: Int
        public let countries: Int
        public let borderCrossings: Int
        public let cancellations: Int

        public init(distanceM: Double, minutes: Double, trains: Int, journeys: Int, stations: Int, countries: Int, borderCrossings: Int, cancellations: Int) {
            self.distanceM = distanceM
            self.minutes = minutes
            self.trains = trains
            self.journeys = journeys
            self.stations = stations
            self.countries = countries
            self.borderCrossings = borderCrossings
            self.cancellations = cancellations
        }
    }

    public nonisolated struct RouteCount: Codable, Hashable, Sendable {
        /// `A ⇄ B`, the names sorted.
        public let route: String
        public let count: Int

        public init(route: String, count: Int) {
            self.route = route
            self.count = count
        }
    }

    public nonisolated struct Flavor: Codable, Hashable, Sendable {
        public let earthLaps: Double
        public let swedenLengths: Double
        public let topRoute: RouteCount?
        public nonisolated struct Month: Codable, Hashable, Sendable {
            /// `YYYY-MM`.
            public let month: String
            public let count: Int
        }
        public let busiestMonth: Month?
        public let lateMinutes: Double

        public init(earthLaps: Double, swedenLengths: Double, topRoute: RouteCount?, busiestMonth: Month?, lateMinutes: Double) {
            self.earthLaps = earthLaps
            self.swedenLengths = swedenLengths
            self.topRoute = topRoute
            self.busiestMonth = busiestMonth
            self.lateMinutes = lateMinutes
        }
    }

    /// One trip picked out for a record.
    public nonisolated struct LegRef: Codable, Hashable, Sendable {
        public let legId: String
        public let from: String
        public let to: String
        public let distanceM: Double
        public let minutes: Double
        public let dep: Instant
        public let arr: Instant
        public let delayMin: Int?

        public init(legId: String, from: String, to: String, distanceM: Double, minutes: Double, dep: Instant, arr: Instant, delayMin: Int?) {
            self.legId = legId
            self.from = from
            self.to = to
            self.distanceM = distanceM
            self.minutes = minutes
            self.dep = dep
            self.arr = arr
            self.delayMin = delayMin
        }
    }

    public nonisolated struct BusiestStation: Codable, Hashable, Sendable {
        public let id: String
        public let name: String
        public let country: String
        public let lat: Double
        public let lon: Double
        public let count: Int

        public init(id: String, name: String, country: String, lat: Double, lon: Double, count: Int) {
            self.id = id
            self.name = name
            self.country = country
            self.lat = lat
            self.lon = lon
            self.count = count
        }
    }

    public nonisolated struct Records: Codable, Hashable, Sendable {
        public let longestDistance: LegRef?
        public let longestDuration: LegRef?
        public let biggestDelay: LegRef?
        public let mostRiddenRoute: RouteCount?
        public let busiestStation: BusiestStation?
        public let earliestDeparture: LegRef?
        public let latestArrival: LegRef?

        public init(longestDistance: LegRef?, longestDuration: LegRef?, biggestDelay: LegRef?, mostRiddenRoute: RouteCount?, busiestStation: BusiestStation?, earliestDeparture: LegRef?, latestArrival: LegRef?) {
            self.longestDistance = longestDistance
            self.longestDuration = longestDuration
            self.biggestDelay = biggestDelay
            self.mostRiddenRoute = mostRiddenRoute
            self.busiestStation = busiestStation
            self.earliestDeparture = earliestDeparture
            self.latestArrival = latestArrival
        }
    }

    public nonisolated struct CountRow: Codable, Hashable, Sendable {
        public let key: String
        public let count: Int
        public let distanceM: Double

        public init(key: String, count: Int, distanceM: Double) {
            self.key = key
            self.count = count
            self.distanceM = distanceM
        }
    }

    public nonisolated struct Delays: Codable, Hashable, Sendable {
        public nonisolated struct Bands: Codable, Hashable, Sendable {
            public let onTime: Int
            public let slight: Int
            public let late: Int
            public let veryLate: Int

            public enum CodingKeys: String, CodingKey {
                case onTime = "on_time", slight, late
                case veryLate = "very_late"
            }
        }

        public let basedOn: Int
        public let onTimePct: Double?
        public let totalLateMin: Double
        public let averageMin: Double?
        public let worst: LegRef?
        public let bands: Bands
        public let cancellations: Int

        public init(basedOn: Int, onTimePct: Double?, totalLateMin: Double, averageMin: Double?, worst: LegRef?, bands: Bands, cancellations: Int) {
            self.basedOn = basedOn
            self.onTimePct = onTimePct
            self.totalLateMin = totalLateMin
            self.averageMin = averageMin
            self.worst = worst
            self.bands = bands
            self.cancellations = cancellations
        }
    }

    public nonisolated struct CountryRow: Codable, Hashable, Sendable {
        public let code: String
        public let legs: Int

        public init(code: String, legs: Int) {
            self.code = code
            self.legs = legs
        }
    }

    public nonisolated struct StationVisit: Codable, Hashable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let country: String
        public let lat: Double
        public let lon: Double
        public let count: Int

        public init(id: String, name: String, country: String, lat: Double, lon: Double, count: Int) {
            self.id = id
            self.name = name
            self.country = country
            self.lat = lat
            self.lon = lon
            self.count = count
        }
    }

    public nonisolated struct Co2: Codable, Hashable, Sendable {
        public let comparison: String
        public let trainKg: Double
        public let comparisonKg: Double
        public let savedKg: Double

        public init(comparison: String, trainKg: Double, comparisonKg: Double, savedKg: Double) {
            self.comparison = comparison
            self.trainKg = trainKg
            self.comparisonKg = comparisonKg
            self.savedKg = savedKg
        }
    }

    /// One ridden route for the map: its operator, its routed geometry, or the first and last stop.
    public nonisolated struct MapRoute: Codable, Hashable, Sendable {
        public let legId: String
        public let operatorId: String?
        public let geometry: String?
        /// `[lat, lon]` of the first and last stop.
        public let stops: [[Double]]

        public init(legId: String, operatorId: String?, geometry: String?, stops: [[Double]]) {
            self.legId = legId
            self.operatorId = operatorId
            self.geometry = geometry
            self.stops = stops
        }
    }

    public nonisolated struct Milestones: Codable, Hashable, Sendable {
        /// Newest first.
        public let achieved: [Milestone]
        /// Up to three, closest first.
        public let next: [Milestone]

        public init(achieved: [Milestone], next: [Milestone]) {
            self.achieved = achieved
            self.next = next
        }
    }

    public nonisolated struct Review: Codable, Hashable, Sendable {
        public let legId: String
        public let reason: String?
        public let dep: Instant?
        public let from: String
        public let to: String
        public let trainNumber: String?

        public init(legId: String, reason: String?, dep: Instant?, from: String, to: String, trainNumber: String?) {
            self.legId = legId
            self.reason = reason
            self.dep = dep
            self.from = from
            self.to = to
            self.trainNumber = trainNumber
        }
    }

    public nonisolated struct Refs: Codable, Hashable, Sendable {
        public let operators: [String: LegOperator]
        public let trainTypes: [String: TrainType]

        public init(operators: [String: LegOperator], trainTypes: [String: TrainType]) {
            self.operators = operators
            self.trainTypes = trainTypes
        }
    }

    /// Years with counted trips, newest first.
    public let years: [Int]
    public let scope: Scope
    public let totals: Totals
    public let flavor: Flavor
    public let records: Records
    public let operators: [CountRow]
    public let products: [CountRow]
    public let trainTypes: [CountRow]
    public let delays: Delays
    public let countries: [CountryRow]
    public let stations: [StationVisit]
    public let co2: Co2
    public let map: [MapRoute]
    public let milestones: Milestones
    public let review: [Review]
    public let refs: Refs

    public init(years: [Int], scope: Scope, totals: Totals, flavor: Flavor, records: Records, operators: [CountRow], products: [CountRow], trainTypes: [CountRow], delays: Delays, countries: [CountryRow], stations: [StationVisit], co2: Co2, map: [MapRoute], milestones: Milestones, review: [Review], refs: Refs) {
        self.years = years
        self.scope = scope
        self.totals = totals
        self.flavor = flavor
        self.records = records
        self.operators = operators
        self.products = products
        self.trainTypes = trainTypes
        self.delays = delays
        self.countries = countries
        self.stations = stations
        self.co2 = co2
        self.map = map
        self.milestones = milestones
        self.review = review
        self.refs = refs
    }
}
