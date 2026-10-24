//
//  StopName.swift
//  Clack
//

import Foundation

/// A stop's name and zone, from the trip's stops.
public nonisolated struct StopName: Hashable, Sendable {
    public let stationId: String
    public let name: String
    public let tz: String

    public init(stationId: String, name: String, tz: String) {
        self.stationId = stationId
        self.name = name
        self.tz = tz
    }
}
