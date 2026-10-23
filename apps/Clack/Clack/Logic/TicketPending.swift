//
//  TicketPending.swift
//  Clack
//

import Foundation

/// A ticket hand-off waiting for you to come back: the train you looked up on an operator's site, kept for a few hours so
/// the app can offer to add it (Tickets.tsx). Opening a booking site never means you bought a ticket, so nothing is
/// saved without you saying so.
nonisolated struct TicketPending: Codable, Hashable, Sendable {
    var trip: TicketTrip
    /// Epoch ms when the link was tapped.
    var at: Double
    /// The operator's site, as shown ("sj.se").
    var site: String
}

nonisolated enum TicketPendingStore {
    private static let key = "clack.ticketPending"
    static let maxAgeMs: Double = 3 * 3_600_000
    /// A moment to let the tap itself pass: leaving for the site fires a change of state before you've gone anywhere.
    static let settleMs: Double = 5_000

    static func write(_ pending: TicketPending?, _ defaults: UserDefaults = .standard) {
        if let pending, let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    /// The waiting hand-off, if it's under three hours old.
    static func read(now: Double, _ defaults: UserDefaults = .standard) -> TicketPending? {
        guard let data = defaults.data(forKey: key), let pending = try? JSONDecoder().decode(TicketPending.self, from: data) else { return nil }
        return now - pending.at < maxAgeMs ? pending : nil
    }

    /// The hand-off to offer now: waiting, and written more than five seconds ago.
    static func offer(now: Double, _ defaults: UserDefaults = .standard) -> TicketPending? {
        guard let pending = read(now: now, defaults), now - pending.at > settleMs else { return nil }
        return pending
    }

    /// The site's name for a link, without "www.".
    static func host(of url: String) -> String {
        guard let host = URL(string: url)?.host else { return url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
