//
//  Network.swift
//  Clack
//

import Foundation

/// `GET /api/live/network`: where trains are running late now (server `livemap/network.ts`, docs/NETWORK_STATUS.md).
public nonisolated struct NetworkStatus: Codable, Hashable, Sendable {
    public nonisolated struct Country: Codable, Hashable, Sendable {
        public let trains: Int
        /// Trains whose delay is known.
        public let known: Int
        public let late: Int

        public init(trains: Int, known: Int, late: Int) {
            self.trains = trains
            self.known = known
            self.late = late
        }
    }

    /// A cause, with how many of the late trains give it.
    public nonisolated struct Cause: Codable, Hashable, Sendable {
        public let src: String
        public let code: String?
        public let text: String?
        public let trains: Int

        public init(src: String, code: String?, text: String?, trains: Int) {
            self.src = src
            self.code = code
            self.text = text
            self.trains = trains
        }

        public var cause: LegStop.Cause { LegStop.Cause(src: src, code: code, text: text) }
    }

    /// Stations next to each other where most trains are late, joined where they touch.
    public nonisolated struct Corridor: Codable, Hashable, Sendable, Identifiable {
        /// In order along the line, when the corridor is one.
        public let stations: [String]
        public let country: String
        public let trains: Int
        public let late: Int
        public let medianDelay: Int
        public let maxDelay: Int
        public let lat: Double
        public let lon: Double
        public let causes: [Cause]
        public let trainIds: [String]

        public var id: String { stations.joined(separator: "|") }

        public init(stations: [String], country: String, trains: Int, late: Int, medianDelay: Int, maxDelay: Int, lat: Double, lon: Double, causes: [Cause], trainIds: [String]) {
            self.stations = stations
            self.country = country
            self.trains = trains
            self.late = late
            self.medianDelay = medianDelay
            self.maxDelay = maxDelay
            self.lat = lat
            self.lon = lon
            self.causes = causes
            self.trainIds = trainIds
        }
    }

    /// A late train outside the corridors.
    public nonisolated struct LateTrain: Codable, Hashable, Sendable, Identifiable {
        public let id: String
        public let number: String
        public let operatorId: String?
        public let delayMin: Int
        public let prev: String?
        public let next: String?
        public let destination: String?
        public let causes: [LegStop.Cause]

        public init(id: String, number: String, operatorId: String?, delayMin: Int, prev: String?, next: String?, destination: String?, causes: [LegStop.Cause]) {
            self.id = id
            self.number = number
            self.operatorId = operatorId
            self.delayMin = delayMin
            self.prev = prev
            self.next = next
            self.destination = destination
            self.causes = causes
        }
    }

    public let at: Double
    /// Minutes late that counts as late (10).
    public let lateMin: Int
    public let countries: [String: Country]
    public let corridors: [Corridor]
    public let late: [LateTrain]

    public init(at: Double, lateMin: Int, countries: [String: Country], corridors: [Corridor], late: [LateTrain]) {
        self.at = at
        self.lateMin = lateMin
        self.countries = countries
        self.corridors = corridors
        self.late = late
    }
}
