//
//  Search.swift
//  Clack
//

import Foundation

/// A station in search results and lists (`GET /api/stations/search`, `/popular`, `/favorites`, `/recent`).
nonisolated struct StationHit: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let code: String?
    /// ISO 3166 alpha-2: `SE`, `NO`, `DK`, ...
    let country: String
    /// Not sent by the popular, favourites and recent lists.
    let county: String?
}

/// `GET /api/search`: how the smart search read the text, station suggestions, and the trains or connections found.
nonisolated struct SearchResponse: Codable, Hashable, Sendable {
    nonisolated struct Interpretation: Codable, Hashable, Sendable {
        nonisolated struct OperatorText: Codable, Hashable, Sendable {
            let id: String
            let text: String
        }

        let `operator`: OperatorText?
        let trainNumber: String?
        let from: StationHit?
        let to: StationHit?
        /// Which end is being typed: `from` or `to`.
        let typing: String?
    }

    let date: String
    let interpretation: Interpretation
    let suggestions: [StationHit]
    /// Nil when the text isn't a search yet; empty when nothing was found or the date is outside the timetable.
    let results: [TripResult]?
    let connections: [TimetableConnection]?
    let outsideTimetable: Bool
    /// For dates before yesterday: `ready`, `loading` (try again shortly), `failed`, `unavailable` or `norway`.
    let history: String?
}

/// One stop of a timetable trip (`GET /api/timetable/trips/:key`).
nonisolated struct TripStop: Codable, Hashable, Sendable, Identifiable {
    let seq: Int
    let stationId: String
    let name: String
    let code: String?
    let country: String
    let tz: String
    let lat: Double
    let lon: Double
    let arr: Instant?
    let dep: Instant?
    let noPickup: Bool
    let noDropoff: Bool

    var id: Int { seq }
}

nonisolated struct TimetableTrip: Codable, Hashable, Sendable {
    let key: String
    let serviceDate: String
    let trainNumber: String?
    let operatorId: String?
    let category: String
    let product: String
    let trainType: String?
    let stops: [TripStop]
}

/// The route between consecutive stops of a timetable trip (`.../geometry`).
nonisolated struct TripGeometry: Codable, Hashable, Sendable {
    nonisolated struct Segment: Codable, Hashable, Sendable {
        let fromSeq: Int
        let toSeq: Int
        /// Encoded polyline.
        let polyline: String
        /// Metres.
        let lengthM: Double
        let estimated: Bool
    }

    let segments: [Segment]
}

/// What is sent to save a timetable trip (`POST /api/legs`).
nonisolated struct CreateLegBody: Encodable, Sendable {
    let tripKey: String
    let serviceDate: String
    let fromSeq: Int
    let toSeq: Int
    /// Save even if the same train is already saved on that date.
    var force: Bool?
}

/// What is sent to add a trip by hand (`POST /api/legs/manual`); the web always sends all eight keys.
nonisolated struct ManualLegBody: Encodable, Sendable {
    let fromStationId: String
    let toStationId: String
    /// YYYY-MM-DD, local where you board.
    let date: String
    /// HH:MM at the origin.
    let dep: String
    /// HH:MM at the destination; earlier than `dep` means the next day.
    let arr: String
    let operatorId: String?
    let trainNumber: String?
    let category: String?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fromStationId, forKey: .fromStationId)
        try c.encode(toStationId, forKey: .toStationId)
        try c.encode(date, forKey: .date)
        try c.encode(dep, forKey: .dep)
        try c.encode(arr, forKey: .arr)
        try c.encode(operatorId, forKey: .operatorId)
        try c.encode(trainNumber, forKey: .trainNumber)
        try c.encode(category, forKey: .category)
    }

    private enum CodingKeys: String, CodingKey {
        case fromStationId, toStationId, date, dep, arr, operatorId, trainNumber, category
    }
}
