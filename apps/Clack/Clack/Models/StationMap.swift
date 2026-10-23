//
//  StationMap.swift
//  Clack
//

import Foundation

/// A point in a station's local frame: metres, x east, y south (so it maps straight onto a drawing). Sent as
/// `[x, y]`.
nonisolated struct Pt: Codable, Hashable, Sendable {
    let x: Double
    let y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        x = try container.decode(Double.self)
        y = try container.decode(Double.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}

nonisolated enum StationNodeType: OpenEnum {
    case platform, platformAccess, hall, entrance, stairs, escalator, lift, gate, junction
    case unknown(String)

    static let knownCases: [StationNodeType] = [.platform, .platformAccess, .hall, .entrance, .stairs, .escalator, .lift, .gate, .junction]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .platform: "platform"
        case .platformAccess: "platform_access"
        case .hall: "hall"
        case .entrance: "entrance"
        case .stairs: "stairs"
        case .escalator: "escalator"
        case .lift: "lift"
        case .gate: "gate"
        case .junction: "junction"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum EdgeKind: OpenEnum {
    case walk, stairs, escalator, lift
    case unknown(String)

    static let knownCases: [EdgeKind] = [.walk, .stairs, .escalator, .lift]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .walk: "walk"
        case .stairs: "stairs"
        case .escalator: "escalator"
        case .lift: "lift"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum PoiCategory: OpenEnum {
    case toilet, cafe, restaurant, kiosk, shop, ticket, locker, waiting, info, pharmacy, atm, taxi, bus, other
    case unknown(String)

    static let knownCases: [PoiCategory] = [
        .toilet, .cafe, .restaurant, .kiosk, .shop, .ticket, .locker, .waiting, .info, .pharmacy, .atm, .taxi, .bus, .other,
    ]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .toilet: "toilet"
        case .cafe: "cafe"
        case .restaurant: "restaurant"
        case .kiosk: "kiosk"
        case .shop: "shop"
        case .ticket: "ticket"
        case .locker: "locker"
        case .waiting: "waiting"
        case .info: "info"
        case .pharmacy: "pharmacy"
        case .atm: "atm"
        case .taxi: "taxi"
        case .bus: "bus"
        case .other: "other"
        case .unknown(let raw): raw
        }
    }
}

nonisolated enum ShapeKind: OpenEnum {
    case building, hall, room, shop, track
    case unknown(String)

    static let knownCases: [ShapeKind] = [.building, .hall, .room, .shop, .track]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .building: "building"
        case .hall: "hall"
        case .room: "room"
        case .shop: "shop"
        case .track: "track"
        case .unknown(let raw): raw
        }
    }
}

/// "hand_curated" once someone has checked a map end to end; "osm_draft" straight from the draft script.
nonisolated enum MapQuality: OpenEnum {
    case osmDraft, handCurated
    case unknown(String)

    static let knownCases: [MapQuality] = [.osmDraft, .handCurated]
    init(unknown: String) { self = .unknown(unknown) }
    var rawValue: String {
        switch self {
        case .osmDraft: "osm_draft"
        case .handCurated: "hand_curated"
        case .unknown(let raw): raw
        }
    }
}

nonisolated struct StationLevel: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    /// Higher is further up; used for "up" and "down" in directions.
    let order: Int
}

nonisolated struct StationShape: Codable, Hashable, Sendable {
    let level: String
    /// "track" is an open line (rails between platforms); the others are polygons.
    let kind: ShapeKind
    let name: String?
    let points: [Pt]
}

nonisolated struct StationPlatform: Codable, Hashable, Sendable, Identifiable {
    let id: String
    /// Platform number as signed ("14", "15–16").
    let ref: String
    /// Trafikverket track ids served (without sector letter).
    let tracks: [String]
    let level: String
    /// Outline polygons (OSM often maps one platform in a few pieces).
    let geometry: [[Pt]]
    /// The node a route starts or ends at (the middle of the platform).
    let node: String
}

nonisolated struct StationNode: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let type: StationNodeType
    let level: String
    let x: Double
    let y: Double
    let platform: String?
    let name: String?
}

nonisolated struct StationEdge: Codable, Hashable, Sendable {
    let from: String
    let to: String
    /// Walking seconds at normal pace, no luggage (multipliers apply at runtime).
    let seconds: Double
    let stepFree: Bool
    let kind: EdgeKind
    let meters: Double?
    /// Polyline for drawing, from to to; straight when missing.
    let geometry: [Pt]?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case from, to, seconds, kind, meters, geometry, source
        case stepFree = "step_free"
    }
}

/// What it costs to use a place: nothing, or an amount.
nonisolated enum PoiFee: Codable, Hashable, Sendable {
    case free
    case amount(Double, currency: String)

    private struct Amount: Codable {
        let amount: Double
        let currency: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // The only text the data uses is "free".
        if (try? container.decode(String.self)) != nil {
            self = .free
        } else {
            let amount = try container.decode(Amount.self)
            self = .amount(amount.amount, currency: amount.currency)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .free: try container.encode("free")
        case .amount(let amount, let currency): try container.encode(Amount(amount: amount, currency: currency))
        }
    }
}

nonisolated struct StationPoi: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let category: PoiCategory
    /// A more specific pictogram than the category ("burger", "bakery", "books"), when the tags say.
    let icon: String?
    let name: String
    let level: String
    let x: Double
    let y: Double
    /// The walking-graph node it's reached from.
    let node: String
    let fee: PoiFee?
    let openingHours: String?
    /// `osm`, `manual` or `website`; nil when there are no hours.
    let hoursSource: String?
    /// When a person last checked the hours; nil = taken from OpenStreetMap as is.
    let hoursVerified: String?
    /// The place's own outline (a shop's unit), when it is mapped as one; otherwise it's drawn as a pin.
    let outline: [Pt]?

    enum CodingKeys: String, CodingKey {
        case id, category, icon, name, level, x, y, node, fee, outline
        case openingHours = "opening_hours"
        case hoursSource = "hours_source"
        case hoursVerified = "hours_verified"
    }
}

nonisolated struct StationMapSource: Codable, Hashable, Sendable {
    /// `osm`, `manual`, `website` or `trafikverket`.
    let type: String
    let license: String?
    let retrieved: String?
    let url: String?
    let note: String?
}

nonisolated struct StationMapChange: Codable, Hashable, Sendable {
    let date: String
    let who: String
    let what: String
}

/// A station's indoor map (`GET /api/stations/:id/map`; docs/swift-port/API.md §2.3). Coordinates are metres in a
/// local frame around `origin`: x east, y south.
nonisolated struct StationMap: Codable, Hashable, Sendable {
    let stationId: String
    let name: String
    let updated: String
    let quality: MapQuality
    let sources: [StationMapSource]
    let changelog: [StationMapChange]
    let origin: LatLonPair
    /// Default view: rotate so the platforms run up the screen.
    let view: View?
    let levels: [StationLevel]
    let shapes: [StationShape]
    var platforms: [StationPlatform]
    var nodes: [StationNode]
    var edges: [StationEdge]
    var pois: [StationPoi]

    struct View: Codable, Hashable, Sendable {
        let rotation: Double
    }

    struct LatLonPair: Codable, Hashable, Sendable {
        let lat: Double
        let lon: Double
    }

    enum CodingKeys: String, CodingKey {
        case name, updated, quality, sources, changelog, origin, view, levels, shapes, platforms, nodes, edges, pois
        case stationId = "station_id"
    }
}
