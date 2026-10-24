//
//  Instant.swift
//  Clack
//

import Foundation

/// A moment in time. The server sends ISO strings in some places and epoch milliseconds in others
/// (docs/swift-port/API.md §6); this decodes both and always encodes milliseconds.
public nonisolated struct Instant: Codable, Hashable, Comparable, Sendable {
    public let ms: Double

    public var date: Date { Date(timeIntervalSince1970: ms / 1000) }

    public init(ms: Double) {
        self.ms = ms
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            ms = number
            return
        }
        let text = try container.decode(String.self)
        guard let parsed = Instant.parse(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "not a time: \(text)")
        }
        ms = parsed.timeIntervalSince1970 * 1000
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(ms)
    }

    public static func < (lhs: Instant, rhs: Instant) -> Bool {
        lhs.ms < rhs.ms
    }

    /// ISO 8601 with or without fractional seconds (`2026-10-23T08:12:00.000Z` or `2026-10-23T08:12:00Z`).
    public static func parse(_ text: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) { return date }
        return try? Date.ISO8601FormatStyle().parse(text)
    }
}
