//
//  Timetable.swift
//  Clack
//

import Foundation

/// A stop of a timetable trip as search shows it: the time is the departure for a "from", the arrival for a "to".
public nonisolated struct StopRef: Codable, Hashable, Sendable {
    public let seq: Int
    public let stationId: String
    public let name: String
    public let code: String?
    public let country: String
    public let tz: String
    /// Epoch ms.
    public let time: Double

    public init(seq: Int, stationId: String, name: String, code: String?, country: String, tz: String, time: Double) {
        self.seq = seq
        self.stationId = stationId
        self.name = name
        self.code = code
        self.country = country
        self.tz = tz
        self.time = time
    }
}

/// A train in the timetable (`/search`, `/alternatives`).
public nonisolated struct TripResult: Codable, Hashable, Sendable, Identifiable {
    /// The trip key, e.g. `se3:121120000383764838:ae68fcaa62`; contains colons (APIClient percent-encodes it).
    public let key: String
    /// YYYY-MM-DD (the GTFS service day; can be the day before the departure date after midnight).
    public let serviceDate: String
    public let trainNumber: String?
    public let operatorId: String?
    /// `intercity`, `regional`, `commuter`, `heritage`, `night`.
    public let category: String
    public let product: String
    public let trainType: String?
    public let routeName: String?
    public let from: StopRef
    public let to: StopRef
    public let durationMin: Int
    public let stopsBetween: Int
    /// Other train numbers for the same physical train.
    public let alsoKnownAs: [String]

    public var id: String { "\(key)|\(serviceDate)" }

    public init(key: String, serviceDate: String, trainNumber: String?, operatorId: String?, category: String, product: String, trainType: String?, routeName: String?, from: StopRef, to: StopRef, durationMin: Int, stopsBetween: Int, alsoKnownAs: [String]) {
        self.key = key
        self.serviceDate = serviceDate
        self.trainNumber = trainNumber
        self.operatorId = operatorId
        self.category = category
        self.product = product
        self.trainType = trainType
        self.routeName = routeName
        self.from = from
        self.to = to
        self.durationMin = durationMin
        self.stopsBetween = stopsBetween
        self.alsoKnownAs = alsoKnownAs
    }
}

/// Two trains joined by one change.
public nonisolated struct TimetableConnection: Codable, Hashable, Sendable, Identifiable {
    public nonisolated struct Station: Codable, Hashable, Sendable {
        public let stationId: String
        public let name: String

        public init(stationId: String, name: String) {
            self.stationId = stationId
            self.name = name
        }
    }

    public let first: TripResult
    public let second: TripResult
    public let changeAt: Station
    public let changeMin: Int

    public var id: String { "\(first.id)>\(second.id)" }

    public init(first: TripResult, second: TripResult, changeAt: Station, changeMin: Int) {
        self.first = first
        self.second = second
        self.changeAt = changeAt
        self.changeMin = changeMin
    }
}

/// Other ways for a disrupted trip (`GET /api/alternatives`).
public nonisolated struct Alternatives: Codable, Hashable, Sendable {
    public let direct: [TripResult]
    public let connections: [TimetableConnection]

    public init(direct: [TripResult], connections: [TimetableConnection]) {
        self.direct = direct
        self.connections = connections
    }
}
