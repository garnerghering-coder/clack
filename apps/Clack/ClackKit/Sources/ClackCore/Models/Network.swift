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
        /// The track between each pair of neighbouring stations (nil from older servers).
        public var stretches: [Stretch]? = nil
        /// The late trains on it, worst first (nil from older servers).
        public var lateTrains: [CorridorTrain]? = nil

        public var id: String { stations.joined(separator: "|") }

        /// Every point of the corridor's track, for fitting the map and drawing the highlight.
        public var lines: [[LatLon]] { (stretches ?? []).compactMap { s in s.polyline.map { Polyline.decode($0) } }.filter { $0.count >= 2 } }

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

    /// One stretch of a corridor: the two stations and the track between them (encoded; nil when not routed).
    public nonisolated struct Stretch: Codable, Hashable, Sendable {
        public let a: String
        public let b: String
        public let aId: String?
        public let bId: String?
        public let polyline: String?
        public init(a: String, b: String, aId: String?, bId: String?, polyline: String?) {
            self.a = a
            self.b = b
            self.aId = aId
            self.bId = bId
            self.polyline = polyline
        }
    }

    /// A late train on a corridor.
    public nonisolated struct CorridorTrain: Codable, Hashable, Sendable, Identifiable {
        public let id: String
        public let number: String
        public let operatorId: String?
        public let delayMin: Int
        public let next: String?
        public let destination: String?
        public let causes: [LegStop.Cause]
        public init(id: String, number: String, operatorId: String?, delayMin: Int, next: String?, destination: String?, causes: [LegStop.Cause]) {
            self.id = id
            self.number = number
            self.operatorId = operatorId
            self.delayMin = delayMin
            self.next = next
            self.destination = destination
            self.causes = causes
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

    /// Cancelled trains on one stretch in the next two hours (both directions): they never run, so the map can't show
    /// them (owner, 2026-11-07: Jönköping C full of cancelled Västtågen, with buses instead, and nothing here).
    public nonisolated struct CancelledGroup: Codable, Hashable, Sendable, Identifiable {
        public let stations: [String]
        public let country: String
        public let trains: Int
        /// How many have a bus instead, as the source says.
        public let bus: Int
        public let operatorIds: [String]
        public let causes: [Cause]
        public let firstAt: Double
        public let numbers: [String]

        public var id: String { stations.joined(separator: "|") + operatorIds.joined() }

        public init(stations: [String], country: String, trains: Int, bus: Int, operatorIds: [String], causes: [Cause], firstAt: Double, numbers: [String]) {
            self.stations = stations
            self.country = country
            self.trains = trains
            self.bus = bus
            self.operatorIds = operatorIds
            self.causes = causes
            self.firstAt = firstAt
            self.numbers = numbers
        }
    }

    public let at: Double
    /// Minutes late that counts as late (10).
    public let lateMin: Int
    public let countries: [String: Country]
    public let corridors: [Corridor]
    public let late: [LateTrain]
    /// Sweden only for now (Trafikverket's announcements); nil from an older server.
    public let cancelled: [CancelledGroup]?
    public let cancelledTrains: Int?
    /// Track work, closures and incidents now (server `livemap/disruptions.ts`); nil from an older server.
    public let disruptions: [Disruption]?

    public init(at: Double, lateMin: Int, countries: [String: Country], corridors: [Corridor], late: [LateTrain], cancelled: [CancelledGroup]? = nil, cancelledTrains: Int? = nil, disruptions: [Disruption]? = nil) {
        self.at = at
        self.lateMin = lateMin
        self.countries = countries
        self.corridors = corridors
        self.late = late
        self.cancelled = cancelled
        self.cancelledTrains = cancelledTrains
        self.disruptions = disruptions
    }

    /// Track work, a closed track or an incident on the network now: Trafikverket's events (Sweden), Digitraffic's
    /// RUMA notices (Finland) and Entur's situations about trains (Norway).
    public nonisolated struct Disruption: Codable, Hashable, Sendable, Identifiable {
        public enum Kind: String, Codable, Sendable { case works, closure, incident }
        public struct Title: Codable, Hashable, Sendable {
            public let sv: String?
            public let en: String?
            public let no: String?
            /// Denmark's messages come in Danish only.
            public let da: String?

            public init(sv: String? = nil, en: String? = nil, no: String? = nil, da: String? = nil) {
                self.sv = sv
                self.en = en
                self.no = no
                self.da = da
            }
        }

        public let id: String
        public let country: String
        public let kind: Kind
        public let title: Title?
        public let places: [String]
        public let from: Double?
        public let to: Double?
        public let lat: Double
        public let lon: Double
        /// Encoded polylines along the track; empty for a pin alone.
        public let lines: [String]
        public let source: String

        public init(id: String, country: String, kind: Kind, title: Title?, places: [String], from: Double?, to: Double?, lat: Double, lon: Double, lines: [String], source: String) {
            self.id = id
            self.country = country
            self.kind = kind
            self.title = title
            self.places = places
            self.from = from
            self.to = to
            self.lat = lat
            self.lon = lon
            self.lines = lines
            self.source = source
        }

        /// The track it covers, decoded.
        public var tracks: [[LatLon]] { lines.map { Polyline.decode($0) }.filter { $0.count >= 2 } }

        /// The source's words in the language asked for, else any (Swedish events only come in Swedish).
        public func words(_ language: Language) -> String? {
            guard let title else { return nil }
            switch language {
            case .sv: return title.sv ?? title.no ?? title.da ?? title.en
            default: return title.en ?? title.sv ?? title.no ?? title.da
            }
        }
    }
}
