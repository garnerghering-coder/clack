//
//  Live.swift
//  Clack
//

import Foundation

/// One train on the live map (`livemap/ingest.ts`; docs/swift-port/API.md §2.9). Times are epoch ms.
public nonisolated struct LiveTrain: Codable, Hashable, Sendable, Identifiable {
    /// `<number>|<YYYY-MM-DD>` for Swedish trains, `no:<number>|<YYYY-MM-DD>` for Norwegian ones.
    public let id: String
    public let number: String
    public let date: String
    public var lat: Double
    public var lon: Double
    public var bearing: Double?
    public var speedKmh: Double?
    /// When the fix was taken.
    public var at: Instant
    /// Position worked out from the timetable, not GPS.
    public var estimated: Bool
    public let operatorId: String?
    public let productName: String?
    public let product: String?
    public let trainType: String?
    /// Station names.
    public let origin: String?
    public let destination: String?
    public let next: String?
    public let nextEta: Instant?
    public let delayMin: Int?
    /// One of the asking user's own trips, tracked now.
    public let mine: Bool
    public let tripKey: String?
    public let crossBorder: Bool?
    /// Cars today where the feed says (Sweden's coach order, Finland's composition); nil elsewhere or from older servers.
    public var cars: Int? = nil

    public init(id: String, number: String, date: String, lat: Double, lon: Double, bearing: Double? = nil, speedKmh: Double? = nil, at: Instant, estimated: Bool, operatorId: String?, productName: String?, product: String?, trainType: String?, origin: String?, destination: String?, next: String?, nextEta: Instant?, delayMin: Int?, mine: Bool, tripKey: String?, crossBorder: Bool?) {
        self.id = id
        self.number = number
        self.date = date
        self.lat = lat
        self.lon = lon
        self.bearing = bearing
        self.speedKmh = speedKmh
        self.at = at
        self.estimated = estimated
        self.operatorId = operatorId
        self.productName = productName
        self.product = product
        self.trainType = trainType
        self.origin = origin
        self.destination = destination
        self.next = next
        self.nextEta = nextEta
        self.delayMin = delayMin
        self.mine = mine
        self.tripKey = tripKey
        self.crossBorder = crossBorder
    }
}

/// A train you watch without having ridden it (`GET /api/follows`). Follows never count as trips.
public nonisolated struct Follow: Codable, Hashable, Sendable {
    public let trainNumber: String
    public let serviceDate: String
    public let operatorId: String?
    /// For example "Göteborg C → Stockholm C".
    public let label: String?
    /// The train while it's on the map.
    public let train: LiveTrain?
    /// Followed as part of a planned journey: its group and name ("Jönköping C → Kolding").
    public let journeyGroup: String?
    public let journeyLabel: String?

    public init(trainNumber: String, serviceDate: String, operatorId: String?, label: String?, train: LiveTrain?, journeyGroup: String? = nil, journeyLabel: String? = nil) {
        self.trainNumber = trainNumber
        self.serviceDate = serviceDate
        self.operatorId = operatorId
        self.label = label
        self.train = train
        self.journeyGroup = journeyGroup
        self.journeyLabel = journeyLabel
    }
}

/// One message on `GET /api/live/stream`: the new live state of a tracked trip, and what changed.
public nonisolated struct LiveUpdate: Codable, Hashable, Sendable {
    public let legId: String
    public let live: LiveStateRow
    public let events: [LegEvent]

    public init(legId: String, live: LiveStateRow, events: [LegEvent]) {
        self.legId = legId
        self.live = live
        self.events = events
    }
}

/// `GET /api/stations/:id` (docs/swift-port/API.md §2.3).
public nonisolated struct StationInfo: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let code: String?
    public let country: String
    public let tz: String
    public let lat: Double
    public let lon: Double
    public let countyNo: Int?
    public let baseTracks: Int?
    public let county: String?
    public let hasBoard: Bool
    public let hasMap: Bool
    /// `small`, `medium` or `large`; nil when unknown.
    public let sizeClass: SizeClass?
    public var favorite: Bool

    public init(from decoder: Decoder) throws {
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
public nonisolated struct JourneyLeg: Codable, Hashable, Sendable, Identifiable {
    public let leg: Leg
    public let geometry: String?

    public var id: String { leg.id }

    private enum ExtraKeys: String, CodingKey { case geometry }

    public init(from decoder: Decoder) throws {
        leg = try Leg(from: decoder)
        geometry = try decoder.container(keyedBy: ExtraKeys.self).decodeIfPresent(String.self, forKey: .geometry)
    }

    public func encode(to encoder: Encoder) throws {
        try leg.encode(to: encoder)
        var container = encoder.container(keyedBy: ExtraKeys.self)
        try container.encodeIfPresent(geometry, forKey: .geometry)
    }
}

/// Several legs grouped as one journey (`GET /api/journeys/:id`), in travel order.
public nonisolated struct Journey: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let legs: [JourneyLeg]

    public init(id: String, legs: [JourneyLeg]) {
        self.id = id
        self.legs = legs
    }
}

public nonisolated enum RideAnswer: String, Encodable, Sendable {
    case yes, no, undo
}
