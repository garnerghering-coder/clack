//
//  OpenEnum.swift
//  Clack
//

import Foundation

/// A string enum that doesn't fail decoding on a value it doesn't know: the value is kept in `.unknown`
/// (docs/SWIFT_PORT.md B3). Conforming types list their known cases and say how to make an unknown one.
public nonisolated protocol OpenEnum: Codable, Hashable, Sendable {
    static var knownCases: [Self] { get }
    var rawValue: String { get }
    init(unknown: String)
}

nonisolated extension OpenEnum {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self.knownCases.first { $0.rawValue == raw } ?? Self(unknown: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
