//
//  Tickets.swift
//  Clack
//

import Foundation

/// The journey a ticket link searches for (apps/web/src/components/Tickets.tsx).
public nonisolated struct TicketTrip: Codable, Hashable, Sendable {
    public nonisolated struct Stop: Codable, Hashable, Sendable {
        public let name: String
        /// Epoch ms.
        public let time: Double
        public let tz: String
        public let seq: Int

        public init(name: String, time: Double, tz: String, seq: Int) {
            self.name = name
            self.time = time
            self.tz = tz
            self.seq = seq
        }
    }

    public var operatorId: String?
    public var trainNumber: String?
    public var from: Stop
    public var to: Stop
    public var tripKey: String?
    public var serviceDate: String?

    public init(operatorId: String? = nil, trainNumber: String? = nil, from: Stop, to: Stop, tripKey: String? = nil, serviceDate: String? = nil) {
        self.operatorId = operatorId
        self.trainNumber = trainNumber
        self.from = from
        self.to = to
        self.tripKey = tripKey
        self.serviceDate = serviceDate
    }
}

public nonisolated enum Tickets {
    /// JavaScript's `encodeURIComponent`: everything but letters, digits and `- _ . ! ~ * ' ( )`.
    private static let uriComponentAllowed: CharacterSet = {
        var set = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        set.insert(charactersIn: "-_.!~*'()")
        return set
    }()

    private static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: uriComponentAllowed) ?? text
    }

    /// The link to the operator's site; filled from the journey only where its link format is known to work. The date
    /// is `YYYY-MM-DD` and the time `HH:mm`, both in the boarding station's time zone.
    public static func href(base: String, deepLink: String?, trip: TicketTrip) -> String {
        guard let deepLink else { return base }
        return deepLink
            .replacingOccurrences(of: "{from}", with: encode(trip.from.name))
            .replacingOccurrences(of: "{to}", with: encode(trip.to.name))
            .replacingOccurrences(of: "{date}", with: Format.localDate(trip.from.time, tz: trip.from.tz))
            .replacingOccurrences(of: "{time}", with: Format.time(trip.from.time, tz: trip.from.tz, clock: .h24))
    }
}
