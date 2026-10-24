//
//  Reference.swift
//  Clack
//

import Foundation

/// A train operator, from `GET /api/operators` (docs/swift-port/API.md §2.8).
public nonisolated struct Operator: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let shortName: String
    public let company: String?
    public let country: String
    /// CSS hex, e.g. `#1fb14f`.
    public let brandColor: String
    public let logoPath: String?
    /// A server path such as `/api/operators/sj/logo?v=…`; prepend the base URL.
    public let logoUrl: String?
    public let ticketUrl: String?
    /// A template with `{from}`, `{to}`, `{date}` and `{time}` placeholders.
    public let ticketDeepLink: String?

    public init(id: String, name: String, shortName: String, company: String?, country: String, brandColor: String, logoPath: String?, logoUrl: String?, ticketUrl: String?, ticketDeepLink: String?) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.company = company
        self.country = country
        self.brandColor = brandColor
        self.logoPath = logoPath
        self.logoUrl = logoUrl
        self.ticketUrl = ticketUrl
        self.ticketDeepLink = ticketDeepLink
    }
}

/// A train type, from `GET /api/train-types`. Note `max_kmh` is snake_case.
public nonisolated struct TrainType: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let builder: String?
    public let maxKmh: Int?
    /// Year it entered service.
    public let since: Int?
    /// Which drawing the type uses.
    public let art: String
    public let about: String
    public let uncertain: Bool?

    public enum CodingKeys: String, CodingKey {
        case id, name, builder, since, art, about, uncertain
        case maxKmh = "max_kmh"
    }

    public init(id: String, name: String, builder: String?, maxKmh: Int?, since: Int?, art: String, about: String, uncertain: Bool?) {
        self.id = id
        self.name = name
        self.builder = builder
        self.maxKmh = maxKmh
        self.since = since
        self.art = art
        self.about = about
        self.uncertain = uncertain
    }
}

/// What an operator says a train (type) has on board, from `GET /api/amenities`.
public nonisolated struct AmenityEntry: Codable, Hashable, Sendable {
    public nonisolated struct Match: Codable, Hashable, Sendable {
        public let `operator`: String
        public let type: String?

        public init(`operator`: String, type: String?) {
            self.operator = `operator`
            self.type = type
        }
    }

    public let match: Match
    /// Keyed by amenity key: `wifi`, `power`, `quiet_car`, ...
    public let claims: [String: AmenityClaim]

    public init(match: Match, claims: [String: AmenityClaim]) {
        self.match = match
        self.claims = claims
    }
}

public nonisolated struct AmenityClaim: Codable, Hashable, Sendable {
    /// `true`, `false`, `"partial"` or a short text such as `"Bistro"`.
    public let value: AmenityValue
    public let note: String?
    /// A URL.
    public let source: String
    /// YYYY-MM-DD.
    public let verified: String
    /// `"owner"`: the owner read the source page and passed it on.
    public let via: String?

    public init(value: AmenityValue, note: String?, source: String, verified: String, via: String?) {
        self.value = value
        self.note = note
        self.source = source
        self.verified = verified
        self.via = via
    }
}

public nonisolated enum AmenityValue: Codable, Hashable, Sendable {
    case flag(Bool)
    case text(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let flag = try? container.decode(Bool.self) {
            self = .flag(flag)
        } else {
            self = .text(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .flag(let flag): try container.encode(flag)
        case .text(let text): try container.encode(text)
        }
    }
}
