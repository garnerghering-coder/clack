//
//  Timetable.swift
//  Clack
//

import Foundation

/// A stop of a timetable trip as search shows it: the time is the departure for a "from", the arrival for a "to".
nonisolated struct StopRef: Codable, Hashable, Sendable {
    let seq: Int
    let stationId: String
    let name: String
    let code: String?
    let country: String
    let tz: String
    /// Epoch ms.
    let time: Double
}

/// A train in the timetable (`/search`, `/alternatives`).
nonisolated struct TripResult: Codable, Hashable, Sendable, Identifiable {
    /// The trip key, e.g. `se3:121120000383764838:ae68fcaa62`; contains colons (APIClient percent-encodes it).
    let key: String
    /// YYYY-MM-DD (the GTFS service day; can be the day before the departure date after midnight).
    let serviceDate: String
    let trainNumber: String?
    let operatorId: String?
    /// `intercity`, `regional`, `commuter`, `heritage`, `night`.
    let category: String
    let product: String
    let trainType: String?
    let routeName: String?
    let from: StopRef
    let to: StopRef
    let durationMin: Int
    let stopsBetween: Int
    /// Other train numbers for the same physical train.
    let alsoKnownAs: [String]

    var id: String { "\(key)|\(serviceDate)" }
}

/// Two trains joined by one change.
nonisolated struct TimetableConnection: Codable, Hashable, Sendable, Identifiable {
    nonisolated struct Station: Codable, Hashable, Sendable {
        let stationId: String
        let name: String
    }

    let first: TripResult
    let second: TripResult
    let changeAt: Station
    let changeMin: Int

    var id: String { "\(first.id)>\(second.id)" }
}

/// Other ways for a disrupted trip (`GET /api/alternatives`).
nonisolated struct Alternatives: Codable, Hashable, Sendable {
    let direct: [TripResult]
    let connections: [TimetableConnection]
}
