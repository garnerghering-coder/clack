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
    /// `roof`: a roof with open sides or an unknown underside (a platform canopy, a footbridge seen from above).
    case building, hall, room, shop, track, roof
    case unknown(String)

    public static let knownCases: [ShapeKind] = [.building, .hall, .room, .shop, .track, .roof]
    public init(unknown: String) { self = .unknown(unknown) }
    public var rawValue: String {
        switch self {
        case .building: "building"
        case .hall: "hall"
        case .room: "room"
        case .shop: "shop"
        case .track: "track"
        case .roof: "roof"
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
    /// Schema 2: floor height in metres above the reference level (the main platforms), when measured.
    public let heightM: Double?
    /// Schema 2: where the fact comes from ("osm:way/123", "walk:<log>", "plan:…").
    public let source: String?

    public enum CodingKeys: String, CodingKey {
        case id, name, order
        case heightM = "height_m"
        case source = "_source"
    }

    public init(id: String, name: String, order: Int, heightM: Double? = nil, source: String? = nil) {
        self.id = id
        self.name = name
        self.order = order
        self.heightM = heightM
        self.source = source
    }
}

public nonisolated struct StationShape: Codable, Hashable, Sendable {
    public let level: String
    /// "track" is an open line (rails between platforms); the others are polygons.
    public let kind: ShapeKind
    public let name: String?
    public let points: [Pt]
    /// Schema 2: for a track, its number when the rails carry one.
    public let ref: String?
    /// Schema 2: a building's height in metres, when the source gives one.
    public let heightM: Double?
    /// A building's or roof's top, metres above the platform surface (the reference level), measured.
    public let topM: Double?
    /// A building's lowest ground at its outline, metres above the platform surface (negative below it).
    public let baseM: Double?
    public let source: String?

    public enum CodingKeys: String, CodingKey {
        case level, kind, name, points, ref
        case heightM = "height_m"
        case topM = "top_m"
        case baseM = "base_m"
        case source = "_source"
    }

    public init(level: String, kind: ShapeKind, name: String?, points: [Pt], ref: String? = nil, heightM: Double? = nil, topM: Double? = nil, baseM: Double? = nil, source: String? = nil) {
        self.level = level
        self.kind = kind
        self.name = name
        self.points = points
        self.ref = ref
        self.heightM = heightM
        self.topM = topM
        self.baseM = baseM
        self.source = source
    }
}

/// Schema 2: one side of a platform where trains stop, along the rails, with the track it serves when known.
public nonisolated struct PlatformEdge: Codable, Hashable, Sendable {
    /// Nil when the sources don't say which side is which track.
    public let track: String?
    public let points: [Pt]
    public let source: String
    public let note: String?

    public enum CodingKeys: String, CodingKey {
        case track, points, note
        case source = "_source"
    }

    public init(track: String?, points: [Pt], source: String, note: String? = nil) {
        self.track = track
        self.points = points
        self.source = source
        self.note = note
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
    /// Schema 2: platform surface above the rail head, metres, when a source gives it.
    public let heightM: Double?
    /// Schema 2: the platform's edges along the tracks.
    public let edges: [PlatformEdge]?
    public let source: String?

    public enum CodingKeys: String, CodingKey {
        case id, ref, tracks, level, geometry, node, edges
        case heightM = "height_m"
        case source = "_source"
    }

    public init(id: String, ref: String, tracks: [String], level: String, geometry: [[Pt]], node: String, heightM: Double? = nil, edges: [PlatformEdge]? = nil, source: String? = nil) {
        self.id = id
        self.ref = ref
        self.tracks = tracks
        self.level = level
        self.geometry = geometry
        self.node = node
        self.heightM = heightM
        self.edges = edges
        self.source = source
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
    public let source: String?

    public enum CodingKeys: String, CodingKey {
        case id, type, level, x, y, platform, name
        case source = "_source"
    }

    public init(id: String, type: StationNodeType, level: String, x: Double, y: Double, platform: String?, name: String?, source: String? = nil) {
        self.id = id
        self.type = type
        self.level = level
        self.x = x
        self.y = y
        self.platform = platform
        self.name = name
        self.source = source
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
    /// Schema 2: an escalator's direction, from → to ("up", "down", "both"), when the source says.
    public let direction: String?
    /// Schema 2: where the edge comes from ("osm:way/123", "manual:…", "derived:…").
    public let sourceRef: String?

    public enum CodingKeys: String, CodingKey {
        case from, to, seconds, kind, meters, geometry, source, direction
        case stepFree = "step_free"
        case sourceRef = "_source"
    }

    public init(from: String, to: String, seconds: Double, stepFree: Bool, kind: EdgeKind, meters: Double?, geometry: [Pt]?, source: String?, direction: String? = nil, sourceRef: String? = nil) {
        self.from = from
        self.to = to
        self.seconds = seconds
        self.stepFree = stepFree
        self.kind = kind
        self.meters = meters
        self.geometry = geometry
        self.source = source
        self.direction = direction
        self.sourceRef = sourceRef
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
    /// Schema 2: where the place comes from.
    public let source: String?

    public enum CodingKeys: String, CodingKey {
        case id, category, icon, name, level, x, y, node, fee, outline
        case openingHours = "opening_hours"
        case hoursSource = "hours_source"
        case hoursVerified = "hours_verified"
        case source = "_source"
    }

    public init(id: String, category: PoiCategory, icon: String?, name: String, level: String, x: Double, y: Double, node: String, fee: PoiFee?, openingHours: String?, hoursSource: String?, hoursVerified: String?, outline: [Pt]?, source: String? = nil) {
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
        self.source = source
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
    /// 1 (or absent): the original format; 2: sources on every element, heights and platform edges (build 54).
    public let schema: Int?
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
    /// The ground as a grid, when a source gives it (the 3D view).
    public let terrain: Terrain?

    /// Ground heights in metres above the platform surface at (x0 + i·step, y0 + j·step): `heights[j][i]`, nil where
    /// the source has no value.
    public struct Terrain: Codable, Hashable, Sendable {
        public let x0: Double
        public let y0: Double
        public let step: Double
        public let cols: Int
        public let rows: Int
        public let heights: [[Double?]]
        public let source: String?

        public enum CodingKeys: String, CodingKey {
            case x0, y0, step, cols, rows, heights
            case source = "_source"
        }

        public init(x0: Double, y0: Double, step: Double, cols: Int, rows: Int, heights: [[Double?]], source: String? = nil) {
            self.x0 = x0
            self.y0 = y0
            self.step = step
            self.cols = cols
            self.rows = rows
            self.heights = heights
            self.source = source
        }
    }

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
        case schema, name, updated, quality, sources, changelog, origin, view, levels, shapes, platforms, nodes, edges, pois, terrain
        case stationId = "station_id"
    }

    public init(stationId: String, name: String, updated: String, quality: MapQuality, sources: [StationMapSource], changelog: [StationMapChange], origin: LatLonPair, view: View?, levels: [StationLevel], shapes: [StationShape], platforms: [StationPlatform], nodes: [StationNode], edges: [StationEdge], pois: [StationPoi], schema: Int? = nil, terrain: Terrain? = nil) {
        self.schema = schema
        self.terrain = terrain
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
