//
//  Reference.swift
//  Clack
//

import Foundation

/// A train operator, from `GET /api/operators` (docs/swift-port/API.md §2.8).
nonisolated struct Operator: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let shortName: String
    let company: String?
    let country: String
    /// CSS hex, e.g. `#1fb14f`.
    let brandColor: String
    let logoPath: String?
    /// A server path such as `/api/operators/sj/logo?v=…`; prepend the base URL.
    let logoUrl: String?
    let ticketUrl: String?
    /// A template with `{from}`, `{to}`, `{date}` and `{time}` placeholders.
    let ticketDeepLink: String?
}

/// A train type, from `GET /api/train-types`. Note `max_kmh` is snake_case.
nonisolated struct TrainType: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let builder: String?
    let maxKmh: Int?
    /// Year it entered service.
    let since: Int?
    /// Which drawing the type uses.
    let art: String
    let about: String
    let uncertain: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, builder, since, art, about, uncertain
        case maxKmh = "max_kmh"
    }
}

/// What an operator says a train (type) has on board, from `GET /api/amenities`.
nonisolated struct AmenityEntry: Codable, Hashable, Sendable {
    nonisolated struct Match: Codable, Hashable, Sendable {
        let `operator`: String
        let type: String?
    }

    let match: Match
    /// Keyed by amenity key: `wifi`, `power`, `quiet_car`, ...
    let claims: [String: AmenityClaim]
}

nonisolated struct AmenityClaim: Codable, Hashable, Sendable {
    /// `true`, `false`, `"partial"` or a short text such as `"Bistro"`.
    let value: AmenityValue
    let note: String?
    /// A URL.
    let source: String
    /// YYYY-MM-DD.
    let verified: String
    /// `"owner"`: the owner read the source page and passed it on.
    let via: String?
}

nonisolated enum AmenityValue: Codable, Hashable, Sendable {
    case flag(Bool)
    case text(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let flag = try? container.decode(Bool.self) {
            self = .flag(flag)
        } else {
            self = .text(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .flag(let flag): try container.encode(flag)
        case .text(let text): try container.encode(text)
        }
    }
}
