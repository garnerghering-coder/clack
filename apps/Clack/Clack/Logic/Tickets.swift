//
//  Tickets.swift
//  Clack
//

import Foundation

/// The journey a ticket link searches for (apps/web/src/components/Tickets.tsx).
nonisolated struct TicketTrip: Codable, Hashable, Sendable {
    nonisolated struct Stop: Codable, Hashable, Sendable {
        let name: String
        /// Epoch ms.
        let time: Double
        let tz: String
        let seq: Int
    }

    var operatorId: String?
    var trainNumber: String?
    var from: Stop
    var to: Stop
    var tripKey: String?
    var serviceDate: String?
}

nonisolated enum Tickets {
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
    static func href(base: String, deepLink: String?, trip: TicketTrip) -> String {
        guard let deepLink else { return base }
        return deepLink
            .replacingOccurrences(of: "{from}", with: encode(trip.from.name))
            .replacingOccurrences(of: "{to}", with: encode(trip.to.name))
            .replacingOccurrences(of: "{date}", with: Format.localDate(trip.from.time, tz: trip.from.tz))
            .replacingOccurrences(of: "{time}", with: Format.time(trip.from.time, tz: trip.from.tz, clock: .h24))
    }
}
