//
//  StationMap.swift
//  Clack
//

import Foundation

/// A point in a station's local frame: metres, x east, y south (so it maps straight onto a drawing). Sent as
/// `[x, y]`.
public nonisolated struct Pt: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        x = try container.decode(Double.self)
        y = try container.decode(Double.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}

public nonisolated enum StationNodeType: OpenEnum {
    case platform, platformAccess, hall, entrance, stairs, escalator, lift, gate, junction
    case unknown(String)

    public static let knownCases: [StationNodeType] = [.platform, .platformAccess, .hall, .entrance, .stairs, .escalator, .lift, .gate, .junction]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
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

public nonisolated enum EdgeKind: OpenEnum {
    case walk, stairs, escalator, lift
    case unknown(String)

    public static let knownCases: [EdgeKind] = [.walk, .stairs, .escalator, .lift]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .walk: "walk"
        case .stairs: "stairs"
        case .escalator: "escalator"
        case .lift: "lift"
        case .unknown(let raw): raw
        }
    }
}

public nonisolated enum PoiCategory: OpenEnum {
    case toilet, cafe, restaurant, kiosk, shop, ticket, locker, waiting, info, pharmacy, atm, taxi, bus, other
    case unknown(String)

    public static let knownCases: [PoiCategory] = [
        .toilet, .cafe, .restaurant, .kiosk, .shop, .ticket, .locker, .waiting, .info, .pharmacy, .atm, .taxi, .bus, .other,
    ]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
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

public nonisolated enum ShapeKind: OpenEnum {
    case building, hall, room, shop, track
    case unknown(String)

    public static let knownCases: [ShapeKind] = [.building, .hall, .room, .shop, .track]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
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
public nonisolated enum MapQuality: OpenEnum {
    case osmDraft, handCurated
    case unknown(String)

    public static let knownCases: [MapQuality] = [.osmDraft, .handCurated]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .osmDraft: "osm_draft"
        case .handCurated: "hand_curated"
        case .unknown(let raw): raw
        }
    }
}

public nonisolated struct StationLevel: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    /// Higher is further up; used for "up" and "down" in directions.
    public let order: Int

    public init(id: String, name: String, order: Int) {
        self.id = id
        self.name = name
        self.order = order
    }
}

public nonisolated struct StationShape: Codable, Hashable, Sendable {
    public let level: String
    /// "track" is an open line (rails between platforms); the others are polygons.
    public let kind: ShapeKind
    public let name: String?
    public let points: [Pt]

    public init(level: String, kind: ShapeKind, name: String?, points: [Pt]) {
        self.level = level
        self.kind = kind
        self.name = name
        self.points = points
    }
}

public nonisolated struct StationPlatform: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    /// Platform number as signed ("14", "15–16").
    public let ref: String
    /// Trafikverket track ids served (without sector letter).
    public let tracks: [String]
    public let level: String
    /// Outline polygons (OSM often maps one platform in a few pieces).
    public let geometry: [[Pt]]
    /// The node a route starts or ends at (the middle of the platform).
    public let node: String

    public init(id: String, ref: String, tracks: [String], level: String, geometry: [[Pt]], node: String) {
        self.id = id
        self.ref = ref
        self.tracks = tracks
        self.level = level
        self.geometry = geometry
        self.node = node
    }
}

public nonisolated struct StationNode: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let type: StationNodeType
    public let level: String
    public let x: Double
    public let y: Double
    public let platform: String?
    public let name: String?

    public init(id: String, type: StationNodeType, level: String, x: Double, y: Double, platform: String?, name: String?) {
        self.id = id
        self.type = type
        self.level = level
        self.x = x
        self.y = y
        self.platform = platform
        self.name = name
    }
}

public nonisolated struct StationEdge: Codable, Hashable, Sendable {
    public let from: String
    public let to: String
    /// Walking seconds at normal pace, no luggage (multipliers apply at runtime).
    public let seconds: Double
    public let stepFree: Bool
    public let kind: EdgeKind
    public let meters: Double?
    /// Polyline for drawing, from to to; straight when missing.
    public let geometry: [Pt]?
    public let source: String?

    public enum CodingKeys: String, CodingKey {
        case from, to, seconds, kind, meters, geometry, source
        case stepFree = "step_free"
    }

    public init(from: String, to: String, seconds: Double, stepFree: Bool, kind: EdgeKind, meters: Double?, geometry: [Pt]?, source: String?) {
        self.from = from
        self.to = to
        self.seconds = seconds
        self.stepFree = stepFree
        self.kind = kind
        self.meters = meters
        self.geometry = geometry
        self.source = source
    }
}

/// What it costs to use a place: nothing, or an amount.
public nonisolated enum PoiFee: Codable, Hashable, Sendable {
    case free
    case amount(Double, currency: String)

    private struct Amount: Codable {
        public let amount: Double
        public let currency: String
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // The only text the data uses is "free".
        if (try? container.decode(String.self)) != nil {
            self = .free
        } else {
            let amount = try container.decode(Amount.self)
            self = .amount(amount.amount, currency: amount.currency)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .free: try container.encode("free")
        case .amount(let amount, let currency): try container.encode(Amount(amount: amount, currency: currency))
        }
    }
}

public nonisolated struct StationPoi: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let category: PoiCategory
    /// A more specific pictogram than the category ("burger", "bakery", "books"), when the tags say.
    public let icon: String?
    public let name: String
    public let level: String
    public let x: Double
    public let y: Double
    /// The walking-graph node it's reached from.
    public let node: String
    public let fee: PoiFee?
    public let openingHours: String?
    /// `osm`, `manual` or `website`; nil when there are no hours.
    public let hoursSource: String?
    /// When a person last checked the hours; nil = taken from OpenStreetMap as is.
    public let hoursVerified: String?
    /// The place's own outline (a shop's unit), when it is mapped as one; otherwise it's drawn as a pin.
    public let outline: [Pt]?

    public enum CodingKeys: String, CodingKey {
        case id, category, icon, name, level, x, y, node, fee, outline
        case openingHours = "opening_hours"
        case hoursSource = "hours_source"
        case hoursVerified = "hours_verified"
    }

    public init(id: String, category: PoiCategory, icon: String?, name: String, level: String, x: Double, y: Double, node: String, fee: PoiFee?, openingHours: String?, hoursSource: String?, hoursVerified: String?, outline: [Pt]?) {
        self.id = id
        self.category = category
        self.icon = icon
        self.name = name
        self.level = level
        self.x = x
        self.y = y
        self.node = node
        self.fee = fee
        self.openingHours = openingHours
        self.hoursSource = hoursSource
        self.hoursVerified = hoursVerified
        self.outline = outline
    }
}

public nonisolated struct StationMapSource: Codable, Hashable, Sendable {
    /// `osm`, `manual`, `website` or `trafikverket`.
    public let type: String
    public let license: String?
    public let retrieved: String?
    public let url: String?
    public let note: String?

    public init(type: String, license: String?, retrieved: String?, url: String?, note: String?) {
        self.type = type
        self.license = license
        self.retrieved = retrieved
        self.url = url
        self.note = note
    }
}

public nonisolated struct StationMapChange: Codable, Hashable, Sendable {
    public let date: String
    public let who: String
    public let what: String

    public init(date: String, who: String, what: String) {
        self.date = date
        self.who = who
        self.what = what
    }
}

/// A station's indoor map (`GET /api/stations/:id/map`; docs/swift-port/API.md §2.3). Coordinates are metres in a
/// local frame around `origin`: x east, y south.
public nonisolated struct StationMap: Codable, Hashable, Sendable {
    public let stationId: String
    public let name: String
    public let updated: String
    public let quality: MapQuality
    public let sources: [StationMapSource]
    public let changelog: [StationMapChange]
    public let origin: LatLonPair
    /// Default view: rotate so the platforms run up the screen.
    public let view: View?
    public let levels: [StationLevel]
    public let shapes: [StationShape]
    public var platforms: [StationPlatform]
    public var nodes: [StationNode]
    public var edges: [StationEdge]
    public var pois: [StationPoi]

    public struct View: Codable, Hashable, Sendable {
        public let rotation: Double

        public init(rotation: Double) {
            self.rotation = rotation
        }
    }

    public struct LatLonPair: Codable, Hashable, Sendable {
        public let lat: Double
        public let lon: Double

        public init(lat: Double, lon: Double) {
            self.lat = lat
            self.lon = lon
        }
    }

    public enum CodingKeys: String, CodingKey {
        case name, updated, quality, sources, changelog, origin, view, levels, shapes, platforms, nodes, edges, pois
        case stationId = "station_id"
    }

    public init(stationId: String, name: String, updated: String, quality: MapQuality, sources: [StationMapSource], changelog: [StationMapChange], origin: LatLonPair, view: View?, levels: [StationLevel], shapes: [StationShape], platforms: [StationPlatform], nodes: [StationNode], edges: [StationEdge], pois: [StationPoi]) {
        self.stationId = stationId
        self.name = name
        self.updated = updated
        self.quality = quality
        self.sources = sources
        self.changelog = changelog
        self.origin = origin
        self.view = view
        self.levels = levels
        self.shapes = shapes
        self.platforms = platforms
        self.nodes = nodes
        self.edges = edges
        self.pois = pois
    }
}
