//
//  Live.swift
//  Clack
//

import Foundation

/// One train on the live map (`livemap/ingest.ts`; docs/swift-port/API.md §2.9). Times are epoch ms.
nonisolated struct LiveTrain: Codable, Hashable, Sendable, Identifiable {
    /// `<number>|<YYYY-MM-DD>` for Swedish trains, `no:<number>|<YYYY-MM-DD>` for Norwegian ones.
    let id: String
    let number: String
    let date: String
    var lat: Double
    var lon: Double
    var bearing: Double?
    var speedKmh: Double?
    /// When the fix was taken.
    var at: Instant
    /// Position worked out from the timetable, not GPS.
    var estimated: Bool
    let operatorId: String?
    let productName: String?
    let product: String?
    let trainType: String?
    /// Station names.
    let origin: String?
    let destination: String?
    let next: String?
    let nextEta: Instant?
    let delayMin: Int?
    /// One of the asking user's own trips, tracked now.
    let mine: Bool
    let tripKey: String?
    let crossBorder: Bool?
}

/// A train you watch without having ridden it (`GET /api/follows`). Follows never count as trips.
nonisolated struct Follow: Codable, Hashable, Sendable {
    let trainNumber: String
    let serviceDate: String
    let operatorId: String?
    /// For example "Göteborg C → Stockholm C".
    let label: String?
    /// The train while it's on the map.
    let train: LiveTrain?
}

/// One message on `GET /api/live/stream`: the new live state of a tracked trip, and what changed.
nonisolated struct LiveUpdate: Codable, Hashable, Sendable {
    let legId: String
    let live: LiveStateRow
    let events: [LegEvent]
}

/// `GET /api/stations/:id` (docs/swift-port/API.md §2.3).
nonisolated struct StationInfo: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let code: String?
    let country: String
    let tz: String
    let lat: Double
    let lon: Double
    let countyNo: Int?
    let baseTracks: Int?
    let county: String?
    let hasBoard: Bool
    let hasMap: Bool
    /// `small`, `medium` or `large`; nil when unknown.
    let sizeClass: SizeClass?
    let favorite: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        code = try c.decodeIfPresent(String.self, forKey: .code)
        country = try c.decode(String.self, forKey: .country)
        tz = try c.decode(String.self, forKey: .tz)
        lat = try c.decode(Double.self, forKey: .lat)
        lon = try c.decode(Double.self, forKey: .lon)
        countyNo = try c.decodeIfPresent(Int.self, forKey: .countyNo)
        baseTracks = try c.decodeIfPresent(Int.self, forKey: .baseTracks)
        county = try c.decodeIfPresent(String.self, forKey: .county)
        hasBoard = try c.decode(Bool.self, forKey: .hasBoard)
        hasMap = try c.decode(Bool.self, forKey: .hasMap)
        // A size we don't know is shown as no size, not an error.
        sizeClass = (try c.decodeIfPresent(String.self, forKey: .sizeClass)).flatMap(SizeClass.init(rawValue:))
        favorite = try c.decode(Bool.self, forKey: .favorite)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, code, country, tz, lat, lon, countyNo, baseTracks, county, hasBoard, hasMap, sizeClass, favorite
    }
}

/// A leg as a journey lists it: all of `Leg`, plus its route line.
nonisolated struct JourneyLeg: Codable, Hashable, Sendable, Identifiable {
    let leg: Leg
    let geometry: String?

    var id: String { leg.id }

    private enum ExtraKeys: String, CodingKey { case geometry }

    init(from decoder: Decoder) throws {
        leg = try Leg(from: decoder)
        geometry = try decoder.container(keyedBy: ExtraKeys.self).decodeIfPresent(String.self, forKey: .geometry)
    }

    func encode(to encoder: Encoder) throws {
        try leg.encode(to: encoder)
        var container = encoder.container(keyedBy: ExtraKeys.self)
        try container.encodeIfPresent(geometry, forKey: .geometry)
    }
}

/// Several legs grouped as one journey (`GET /api/journeys/:id`), in travel order.
nonisolated struct Journey: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let legs: [JourneyLeg]
}

nonisolated enum RideAnswer: String, Encodable, Sendable {
    case yes, no, undo
}
